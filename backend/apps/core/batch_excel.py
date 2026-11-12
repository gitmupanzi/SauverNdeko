"""Modèles XLSX et lecture bornée vers un panier, sans écriture métier.

Les vues appelantes contrôlent leurs permissions avant de lire request.data.
Les références et les règles métier sont revérifiées lors de l'enregistrement.
"""
from datetime import datetime
from io import BytesIO

from django.core.files.uploadhandler import MemoryFileUploadHandler
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.worksheet.datavalidation import DataValidation
from rest_framework.parsers import MultiPartParser

from apps.logistique import article_xlsx as xlsx

from .responses import APIError


MAX_UPLOAD_BYTES = xlsx.MAX_UPLOAD_BYTES


def invalid(message='Ce classeur Excel est illisible. Utilisez un fichier .xlsx valide.'):
    return APIError(message, 'BATCH_EXCEL_INVALID')


def too_large():
    return APIError('Le fichier Excel ne doit pas dépasser 4 Mo.', 'BATCH_EXCEL_SIZE', 413)


class _BoundedUploadHandler(MemoryFileUploadHandler):
    def handle_raw_input(self, input_data, META, content_length, boundary, encoding=None):
        self.activated = True

    def receive_data_chunk(self, raw_data, start):
        if start + len(raw_data) > MAX_UPLOAD_BYTES:
            raise too_large()
        return super().receive_data_chunk(raw_data, start)


class ExcelPreviewMixin:
    parser_classes = [MultiPartParser]

    def initialize_request(self, request, *args, **kwargs):
        request.upload_handlers = [_BoundedUploadHandler(request)]
        return super().initialize_request(request, *args, **kwargs)


def read_uploaded_workbook(request, *, allowed_fields=(), file_field='fichier', **kwargs):
    """Un seul fichier ; les champs d'en-tête autorisés sont explicites."""
    try:
        length = int(request.META.get('CONTENT_LENGTH') or 0)
    except (TypeError, ValueError):
        raise invalid('La taille du fichier est invalide.')
    if length > MAX_UPLOAD_BYTES + 64 * 1024:
        raise too_large()
    if length < 0:
        raise invalid('La taille du fichier est invalide.')
    if set(request.data) - {file_field, *allowed_fields}:
        raise invalid('Le fichier contient des paramètres non autorisés.')
    if set(request.FILES) != {file_field} or len(request.FILES.getlist(file_field)) != 1:
        raise invalid('Choisissez un seul fichier Excel à importer.')
    if hasattr(request.data, 'getlist') and any(len(request.data.getlist(key)) != 1 for key in request.data):
        raise invalid('Les paramètres du fichier ne doivent pas être répétés.')
    return read_workbook(request.FILES[file_field], **kwargs)


def _read_cells(worksheet, styled_numbers, *, headers, required_headers, max_rows, sheet_name,
                max_cell_length, with_row_numbers=False):
    aliases = {xlsx._header_key(str(label)): key for label, key in headers.items()}
    # Les noms physiques sont aussi acceptés, sans réécrire les en-têtes du fichier.
    aliases.update({xlsx._header_key(str(key)): key for key in headers.values()})
    worksheet.reset_dimensions()
    matrix, fields, total_length = [], [], 0
    row_numbers = []
    for line, source in enumerate(worksheet.iter_rows(min_col=1, max_col=xlsx.MAX_COLUMNS), 1):
        if line > xlsx.MAX_SCAN_ROWS:
            raise invalid(f'La feuille {sheet_name} s’étend sur trop de lignes. Copiez les données dans le modèle.')
        row = []
        for column, cell in enumerate(source, 1):
            stored = styled_numbers.get((line, column)) if (
                line > 1 and column <= len(fields) and str(fields[column - 1]).lower().startswith('id')
            ) else None
            if stored is None and isinstance(cell.value, datetime) and cell.data_type not in {'f', 'e'}:
                # Conserver l'heure des comptages, tickets ou entrées datés.
                value = cell.value.isoformat(timespec='seconds')
            else:
                value = xlsx._cell_text(cell, stored)
            row.append(value)
        while row and row[-1] == '':
            row.pop()
        if line == 1:
            if not row:
                raise invalid(f'Placez les en-têtes sur la première ligne de la feuille {sheet_name}.')
            fields = [aliases.get(xlsx._header_key(label)) for label in row]
            if not all(fields):
                raise invalid('Des noms de colonnes sont inconnus. Utilisez les en-têtes du modèle Excel proposé.')
            if len(set(fields)) != len(fields):
                raise invalid('Retirez les en-têtes en double avant l’import.')
            if not set(required_headers).issubset(fields):
                raise invalid('Des colonnes obligatoires sont absentes. Utilisez le modèle Excel proposé.')
        elif not row:
            continue
        elif len(row) > len(fields):
            raise invalid(f'La ligne {line} contient une cellule sans en-tête.')
        if any(len(value) > max_cell_length for value in row):
            raise invalid(f'Une cellule de la ligne {line} dépasse {max_cell_length} caractères.')
        total_length += sum(map(len, row))
        if total_length > xlsx.MAX_TOTAL_LENGTH:
            raise invalid('Les données du fichier sont trop volumineuses.')
        matrix.append(list(fields) if line == 1 else row)
        if with_row_numbers:
            row_numbers.append(line)
        if len(matrix) > max_rows + 1:
            raise invalid(f'Importez au maximum {max_rows} lignes à la fois.')
    if len(matrix) <= 1:
        raise invalid(f'La feuille {sheet_name} est vide. Ajoutez vos lignes sous les en-têtes.')
    return (matrix, row_numbers) if with_row_numbers else matrix


def read_workbook(upload, *, sheet_name, headers, required_headers=(), max_rows=100,
                  max_cell_length=xlsx.MAX_CELL_LENGTH, with_row_numbers=False):
    """Retourne [[champ canonique, ...], [valeur texte, ...], ...]."""
    if upload.size > MAX_UPLOAD_BYTES:
        raise too_large()
    if not upload.name.lower().endswith('.xlsx') or not upload.size:
        raise invalid('Choisissez un fichier Excel .xlsx non vide.')
    try:
        xlsx._check_archive(upload)
        upload.seek(0)
        book = load_workbook(upload, read_only=True, data_only=False, keep_links=False)
        try:
            if sheet_name not in book.sheetnames and len(book.sheetnames) != 1:
                raise invalid(f'La feuille {sheet_name} est introuvable. Utilisez le modèle Excel proposé.')
            sheet = book[sheet_name] if sheet_name in book.sheetnames else book.active
            if not hasattr(sheet, 'iter_rows'):
                raise invalid(f'La feuille {sheet_name} est introuvable.')
            guard = xlsx._WorkbookXMLGuard(article_sheet=True)
            with xlsx.ZipFile(upload) as archive:
                xlsx._check_xml_part(archive, archive.getinfo(sheet._worksheet_path), guard)
            return _read_cells(sheet, guard.styled_numbers, headers=headers,
                required_headers=required_headers, max_rows=max_rows, sheet_name=sheet_name,
                max_cell_length=max_cell_length, with_row_numbers=with_row_numbers)
        finally:
            book.close()
    except APIError as exc:
        if exc.default_code.startswith('ARTICLE_EXCEL_'):
            raise invalid(str(exc.detail).replace('Articles', sheet_name)) from exc
        raise
    except (
        AttributeError, xlsx.BadZipFile, xlsx.CompressionError, xlsx.DefusedXmlException,
        IndexError, xlsx.InvalidFileException, xlsx.InvalidOperation, KeyError, OSError,
        OverflowError, xlsx.ParseError, RuntimeError, xlsx.StructError, TypeError, ValueError,
    ) as exc:
        raise invalid() from exc


def _text(sheet, row, column, value):
    cell = sheet.cell(row, column, '' if value is None else str(value))
    cell.data_type = 's'
    cell.number_format = '@'


def _style(sheet, widths):
    for row in sheet:
        for cell in row:
            cell.font = Font(name='Aptos', size=11, color='252525')
            cell.alignment = Alignment(vertical='top', wrap_text=True)
    for cell in sheet[1]:
        cell.font = Font(name='Aptos', size=11, bold=True, color='374151')
        cell.fill = PatternFill('solid', fgColor='F3F4F6')
        cell.border = Border(bottom=Side(style='thin', color='D1D5DB'))
    for index, width in enumerate(widths, 1):
        sheet.column_dimensions[get_column_letter(index)].width = width
    sheet.freeze_panes = 'A2'
    sheet.auto_filter.ref = sheet.dimensions
    sheet.row_dimensions[1].height = 32
    sheet.sheet_properties.pageSetUpPr.fitToPage = True
    sheet.page_setup.orientation = 'landscape'
    sheet.page_setup.paperSize = sheet.PAPERSIZE_A4
    sheet.page_setup.fitToWidth = 1
    sheet.page_setup.fitToHeight = 0
    sheet.print_title_rows = '1:1'
    sheet.print_area = sheet.dimensions
    sheet.oddFooter.right.text = 'Page &P / &N'


def build_template(*, sheet_name, columns, notes=(), max_rows=100):
    """Feuille de saisie vide, listes autorisées et consignes séparées."""
    book = Workbook()
    sheet = book.active
    sheet.title = sheet_name
    for column, spec in enumerate(columns, 1):
        _text(sheet, 1, column, spec['label'])
        for row in range(2, max_rows + 2):
            _text(sheet, row, column, '')
    _style(sheet, [spec.get('width', 26) for spec in columns])
    options = None
    option_column = 0
    for index, spec in enumerate(columns, 1):
        choices = spec.get('choices') or []
        if not choices:
            continue
        if options is None:
            options = book.create_sheet('Options')
        option_column += 1
        first = option_column
        _text(options, 1, first, spec['label'] + ' — identifiant ou valeur')
        _text(options, 1, first + 1, spec['label'] + ' — libellé')
        for row, choice in enumerate(choices, 2):
            value = choice.get('value', choice.get('id', ''))
            _text(options, row, first, value)
            _text(options, row, first + 1, choice.get('label', value))
        letter = get_column_letter(first)
        name = f'Choix_{index}'
        book.defined_names.add(DefinedName(name,
            attr_text=f"'Options'!${letter}$2:${letter}${len(choices) + 1}"))
        validation = DataValidation(type='list', formula1=name, allow_blank=not spec.get('required', False))
        validation.errorTitle = 'Valeur à vérifier'
        validation.error = 'Utilisez une valeur de la feuille Options.'
        # Les libellés exacts restent acceptés par l'import : Excel peut avertir,
        # mais ne doit pas interdire la correction libre d'une liste.
        validation.showErrorMessage = True
        validation.errorStyle = 'warning'
        sheet.add_data_validation(validation)
        validation.add(f'{get_column_letter(index)}2:{get_column_letter(index)}{max_rows + 1}')
        option_column += 1
    if options is not None:
        _style(options, [32] * option_column)
    info = book.create_sheet('Informations')
    items = [
        ('Information', 'Consigne'),
        ('Saisie', f'Complétez la feuille {sheet_name} sous ses en-têtes ; ne changez pas les noms des colonnes.'),
        ('Import', 'Importez le fichier, vérifiez et corrigez le panier, puis enregistrez l’ensemble. L’import seul ne crée aucun enregistrement.'),
        ('Limites', f'{max_rows} lignes par fichier, .xlsx de 4 Mo maximum. Remplacez les formules par leurs valeurs.'),
        ('Listes', 'Utilisez les identifiants ou valeurs de la feuille Options, ou un libellé exact proposé par le formulaire.'),
        *[(f'Consigne {index}', note) if isinstance(note, str) else note for index, note in enumerate(notes, 1)],
    ]
    for row, values in enumerate(items, 1):
        for column, value in enumerate(values, 1):
            _text(info, row, column, value)
    _style(info, [28, 110])
    for row in range(2, len(items) + 1):
        info.row_dimensions[row].height = 42
    target = BytesIO()
    book.save(target)
    book.close()
    target.seek(0)
    return target
