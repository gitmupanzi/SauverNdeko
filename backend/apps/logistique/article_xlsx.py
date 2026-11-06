"""Lecture bornée d’un classeur d’articles avant l’ajout au panier."""
import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from io import StringIO
from posixpath import join, split
from struct import error as StructError
from unicodedata import normalize
from xml.etree.ElementTree import ParseError
from zipfile import BadZipFile, ZIP_DEFLATED, ZIP_STORED, ZipFile
from zlib import error as CompressionError

from defusedxml.common import DefusedXmlException
from defusedxml.ElementTree import DefusedXMLParser
from django.core.files.uploadhandler import MemoryFileUploadHandler
from openpyxl import load_workbook
from openpyxl.utils.cell import column_index_from_string, get_column_letter
from openpyxl.utils.exceptions import InvalidFileException
from openpyxl.xml.constants import ARC_CONTENT_TYPES, ARC_WORKBOOK_RELS, CONTYPES_NS, PKG_REL_NS, XLSX
from rest_framework.parsers import MultiPartParser
from rest_framework.views import APIView

from apps.core.permissions import IsERPAdmin
from apps.core.responses import APIError, ok
from apps.core.tenancy import require_entity

from .batch_creation import MAX_OPENING_ROWS


MAX_UPLOAD_BYTES = 4 * 1024 * 1024
MAX_EXPANDED_BYTES = 12 * 1024 * 1024
MAX_PARTS = 256
MAX_XML_ELEMENTS = 150_000
MAX_SCAN_ROWS = 5_000
MAX_COLUMNS = 64
MAX_CELL_LENGTH = 10_000
MAX_TOTAL_LENGTH = 1_000_000
SPREADSHEET_NS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
XML_EXTENSIONS = ('.xml', '.rels')
CELL_COORDINATE = re.compile(r'([A-Za-z]{1,3})([1-9][0-9]{0,6})\Z')
REQUIRED_FALLBACK_HEADERS = {'article', 'categorie', 'type', 'unite', 'stockinitial'}
IDENTIFIER_HEADERS = {
    'codeinterne', 'codearticleinterne', 'codeexterne', 'codearticleexterne',
    'reference', 'refarticle', 'ndelot', 'nlot', 'numerolot',
}
ROW_NUMBER_HEADER = re.compile(r'N\s*[°º]', re.IGNORECASE)


def invalid_workbook(message='Ce classeur Excel est illisible. Utilisez un fichier .xlsx valide.'):
    return APIError(message, 'ARTICLE_EXCEL_INVALID')


def _invalid_cell(coordinate, issue):
    return invalid_workbook(f'La cellule {coordinate} contient {issue}. Remplacez-la par une valeur.')


def upload_too_large():
    return APIError('Le fichier Excel ne doit pas dépasser 4 Mo.', 'ARTICLE_EXCEL_SIZE', 413)


class _WorkbookUploadHandler(MemoryFileUploadHandler):
    """Borne le fichier en mémoire et évite l’écriture temporaire sur disque."""

    def handle_raw_input(self, input_data, META, content_length, boundary, encoding=None):
        self.activated = True

    def receive_data_chunk(self, raw_data, start):
        if start + len(raw_data) > MAX_UPLOAD_BYTES:
            raise upload_too_large()
        return super().receive_data_chunk(raw_data, start)


class _WorkbookXMLGuard:
    """Contrôle les parties XML sans construire leur arborescence en mémoire."""

    def __init__(self, *, article_sheet=False):
        self.elements = 0
        self.workbook_rels = ARC_WORKBOOK_RELS
        self.article_sheet = article_sheet
        self.styled_numbers = {}
        self.number_value = None

    def start_part(self, name):
        self.part = name
        self.depth = 0
        self.worksheet = False
        self.in_row = False
        self.row = self.column = 0

    def start(self, tag, attrs):
        self.depth += 1
        self.elements += 1
        if self.depth > 64 or self.elements > MAX_XML_ELEMENTS:
            raise invalid_workbook('Ce classeur Excel est trop complexe. Utilisez le modèle Articles.')
        if self.depth == 1:
            self.worksheet = tag == SPREADSHEET_NS + 'worksheet'
        if self.part == ARC_CONTENT_TYPES and tag == f'{{{CONTYPES_NS}}}Override':
            self.check_part_type(attrs)
        if self.part == self.workbook_rels and tag == f'{{{PKG_REL_NS}}}Relationship':
            if attrs.get('TargetMode') == 'External' or not attrs.get('Target', '').lower().endswith('.xml'):
                raise invalid_workbook()
        if self.worksheet and tag == SPREADSHEET_NS + 'row':
            row = int(attrs['r']) if 'r' in attrs else self.row + 1
            if self.depth != 3 or not self.row < row <= 1_048_576:
                raise invalid_workbook()
            self.row, self.column = row, 0
            self.in_row = True
        if self.in_row and self.depth == 4:
            if tag != SPREADSHEET_NS + 'c':
                raise invalid_workbook()
            column = self.column + 1
            if 'r' in attrs:
                coordinate = CELL_COORDINATE.fullmatch(attrs['r'])
                if coordinate is None or int(coordinate[2]) != self.row:
                    raise invalid_workbook()
                column = column_index_from_string(coordinate[1])
            # Le lecteur XLSX suppose les coordonnées uniques et ordonnées.
            if not self.column < column <= 16_384:
                raise invalid_workbook()
            self.column = column
            self.styled_number = attrs.get('t', 'n') == 'n' and 's' in attrs
        if self.article_sheet and self.in_row and self.depth == 5:
            if tag == SPREADSHEET_NS + 'f':
                coordinate = f'{get_column_letter(self.column)}{self.row}'
                raise _invalid_cell(coordinate, 'une formule')
            if self.column > MAX_COLUMNS and tag in (SPREADSHEET_NS + 'v', SPREADSHEET_NS + 'is'):
                raise invalid_workbook(f'La ligne {self.row} de la feuille Articles dépasse {MAX_COLUMNS} colonnes.')
            if tag == SPREADSHEET_NS + 'v' and self.styled_number and 1 < self.row <= MAX_SCAN_ROWS:
                self.number_value = StringIO()

    def data(self, value):
        if self.number_value is not None:
            if self.number_value.tell() + len(value) > MAX_CELL_LENGTH:
                raise invalid_workbook(f'Une cellule de la ligne {self.row} dépasse {MAX_CELL_LENGTH} caractères.')
            self.number_value.write(value)

    def check_part_type(self, attrs):
        content_type = attrs.get('ContentType', '')
        name = attrs.get('PartName', '').lstrip('/')
        if 'macroenabled' in content_type.lower() or (
            content_type.endswith(('+xml', '/xml')) and not name.lower().endswith(XML_EXTENSIONS)
        ):
            raise invalid_workbook()
        if content_type == XLSX:
            directory, filename = split(name)
            self.workbook_rels = join(directory, '_rels', filename + '.rels')

    def end(self, tag):
        if self.number_value is not None and self.depth == 5:
            self.styled_numbers[self.row, self.column] = self.number_value.getvalue()
            self.number_value = None
        if tag == SPREADSHEET_NS + 'row':
            self.in_row = False
        self.depth -= 1


def _check_xml_part(archive, part, guard):
    guard.start_part(part.filename)
    parser = DefusedXMLParser(target=guard, forbid_dtd=True)
    with archive.open(part) as stream:
        while chunk := stream.read(64 * 1024):
            parser.feed(chunk)
    parser.close()


def _check_archive(upload):
    with ZipFile(upload) as archive:
        parts = archive.infolist()
        if len(parts) > MAX_PARTS or sum(part.file_size for part in parts) > MAX_EXPANDED_BYTES:
            raise invalid_workbook('Ce classeur Excel contient trop de données. Utilisez le modèle Articles.')
        names = set()
        guard = _WorkbookXMLGuard()
        # Lire le manifeste avant les relations du classeur.
        for part in sorted(parts, key=lambda entry: entry.filename != ARC_CONTENT_TYPES):
            name = part.filename
            if (
                name in names or name.startswith('/') or '\\' in name or '..' in name.split('/')
                or part.flag_bits & 1 or part.compress_type not in {ZIP_STORED, ZIP_DEFLATED}
                or name.lower().endswith('/vbaproject.bin')
            ):
                raise invalid_workbook()
            names.add(name)
            if name.lower().endswith(XML_EXTENSIONS):
                _check_xml_part(archive, part, guard)


def _cell_text(cell, stored_number=None):
    if stored_number:
        # Un identifiant numérique mis en forme comme date reste un identifiant.
        # Limiter l'exposant avant de développer la notation scientifique.
        number = Decimal(stored_number)
        if number.is_finite() and abs(number.adjusted()) < MAX_CELL_LENGTH and abs(number.as_tuple().exponent) < MAX_CELL_LENGTH:
            return format(number, 'f')
        raise invalid_workbook(f'La cellule {cell.coordinate} contient un numéro non pris en charge.')
    if cell.data_type in {'f', 'e'}:
        issue = 'une formule' if cell.data_type == 'f' else 'une erreur Excel'
        raise _invalid_cell(cell.coordinate, issue)
    value = cell.value
    if value is None:
        return ''
    if isinstance(value, str):
        return value if value.strip() else ''
    if isinstance(value, bool):
        return 'TRUE' if value else 'FALSE'
    if isinstance(value, datetime):
        return value.date().isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, (int, float)):
        number = Decimal(str(value))
        if number.is_finite():
            return format(number, 'f')
    raise invalid_workbook(f'La cellule {cell.coordinate} contient une valeur Excel non prise en charge.')


def _header_key(header):
    return re.sub('[^a-z0-9]', '', normalize('NFD', header.lower()))


def _article_cells(worksheet, styled_numbers, *, fallback):
    # Les dimensions déclarées par Excel peuvent être erronées.
    worksheet.reset_dimensions()
    cells = []
    total_length = 0
    ignored_column = None
    identifier_columns = set()
    for line, source in enumerate(worksheet.iter_rows(min_col=1, max_col=MAX_COLUMNS), 1):
        if line > MAX_SCAN_ROWS:
            raise invalid_workbook('La feuille Articles s’étend sur trop de lignes. Copiez les données dans le modèle.')
        row = [
            _cell_text(cell, styled_numbers.get((line, column)) if column in identifier_columns else None)
            for column, cell in enumerate(source, 1)
            if column != ignored_column
        ]
        if line == 1:
            keys = [_header_key(header) for header in row]
            if fallback and not REQUIRED_FALLBACK_HEADERS.issubset(keys):
                raise invalid_workbook('La feuille Articles est introuvable. Utilisez le modèle Excel proposé.')
            identifier_columns = {column for column, key in enumerate(keys, 1) if key in IDENTIFIER_HEADERS}
            if ROW_NUMBER_HEADER.fullmatch(row[0].strip()):
                ignored_column = 1
                row.pop(0)
        while row and row[-1] == '':
            row.pop()
        if line == 1 and not row:
            raise invalid_workbook('Placez les en-têtes sur la première ligne de la feuille Articles.')
        if not row:
            continue
        if any(len(value) > MAX_CELL_LENGTH for value in row):
            raise invalid_workbook(f'Une cellule de la ligne {line} dépasse {MAX_CELL_LENGTH} caractères.')
        total_length += sum(map(len, row))
        if total_length > MAX_TOTAL_LENGTH:
            raise invalid_workbook('Les données de la feuille Articles sont trop volumineuses.')
        cells.append(row)
        if len(cells) > MAX_OPENING_ROWS + 1:
            raise invalid_workbook(f'Importez au maximum {MAX_OPENING_ROWS} articles à la fois.')
    if len(cells) <= 1:
        raise invalid_workbook('La feuille Articles est vide. Ajoutez vos articles sous les en-têtes.')
    return cells


def read_article_workbook(upload):
    if upload.size > MAX_UPLOAD_BYTES:
        raise upload_too_large()
    if not upload.name.lower().endswith('.xlsx') or not upload.size:
        raise invalid_workbook('Choisissez un fichier Excel .xlsx non vide.')
    try:
        _check_archive(upload)
        upload.seek(0)
        workbook = load_workbook(upload, read_only=True, data_only=False, keep_links=False)
        try:
            fallback = 'Articles' not in workbook.sheetnames
            if fallback and len(workbook.sheetnames) != 1:
                raise invalid_workbook('La feuille Articles est introuvable. Utilisez le modèle Excel proposé.')
            worksheet = workbook.active if fallback else workbook['Articles']
            if not hasattr(worksheet, 'iter_rows'):
                raise invalid_workbook('La feuille Articles est introuvable. Utilisez le modèle Excel proposé.')
            # Réutiliser la cible résolue par openpyxl, sans relire les autres
            # feuilles pour les bornes du panier ni tronquer des cellules.
            guard = _WorkbookXMLGuard(article_sheet=True)
            with ZipFile(upload) as archive:
                part = archive.getinfo(worksheet._worksheet_path)
                _check_xml_part(archive, part, guard)
            return _article_cells(worksheet, guard.styled_numbers, fallback=fallback)
        finally:
            workbook.close()
    except (
        AttributeError, BadZipFile, CompressionError, DefusedXmlException, IndexError, InvalidFileException,
        InvalidOperation, KeyError, OSError, OverflowError, ParseError, RuntimeError, StructError, TypeError,
        ValueError,
    ) as exc:
        raise invalid_workbook() from exc


class ArticleExcelPreviewView(APIView):
    permission_classes = [IsERPAdmin]
    parser_classes = [MultiPartParser]
    http_method_names = ['post', 'options']

    def initialize_request(self, request, *args, **kwargs):
        request.upload_handlers = [_WorkbookUploadHandler(request)]
        return super().initialize_request(request, *args, **kwargs)

    def post(self, request):
        require_entity(request.user)
        # L’enveloppe multipart est bornée avant lecture, y compris ses champs texte.
        try:
            content_length = int(request.META.get('CONTENT_LENGTH') or 0)
        except ValueError:
            content_length = 0
        if content_length > MAX_UPLOAD_BYTES + 64 * 1024:
            raise upload_too_large()
        if content_length <= 0:
            raise invalid_workbook('Choisissez un fichier Excel .xlsx.')
        if set(request.data) != {'file'} or len(request.data.getlist('file')) != 1 or 'file' not in request.FILES:
            raise invalid_workbook('Choisissez un seul fichier Excel .xlsx.')
        return ok({'cells': read_article_workbook(request.FILES['file'])})
