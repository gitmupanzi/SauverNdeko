"""Modèle et lecture Excel des caisses, avant toute écriture du panier."""
from io import BytesIO

from django.core.files.uploadhandler import MemoryFileUploadHandler
from django.http import FileResponse
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.worksheet.datavalidation import DataValidation
from rest_framework.parsers import MultiPartParser

from apps.core import db
from apps.core.batch_excel import build_template, read_uploaded_workbook
from apps.core.reference_labels import reference_label
from apps.core.responses import APIError, ok
from apps.logistique import article_xlsx as xlsx
from apps.logistique.excel import ExcelFileRenderer, XLSX_MEDIA_TYPE

from . import services
from .batches import MAX_ROWS
from .views import CashView


HEADERS = ('Caisse', 'Devise', 'Type de caisse', 'Responsable', 'Active', 'Motif')
HEADER_FIELDS = {
    'caisse': 'NomCaisse', 'nomdelacaisse': 'NomCaisse', 'nomcaisse': 'NomCaisse',
    'devise': 'IdDeviseFk', 'iddevisefk': 'IdDeviseFk',
    'typedecaisse': 'IdTypeCaisseFk', 'idtypecaissefk': 'IdTypeCaisseFk',
    'responsable': 'IdResponsableFk', 'idresponsablefk': 'IdResponsableFk',
    'active': 'Actif', 'actif': 'Actif', 'etat': 'Actif', 'motif': 'motif',
}

JOURNAL_FIELDS = {
    'ecritures': [
        ('IdCaisseFk', 'Caisse', 'caisses'), ('DatePaiement', 'Date et heure', None),
        ('SensMouvement', 'Mouvement', None), ('LibellePaiement', 'Libellé', None),
        ('MontantPaiement', 'Montant', None), ('IdTypePaiementFk', 'Type d’opération', 'typesPaiements'),
        ('IdTiersFk', 'Tiers', 'tiers'), ('ReferenceExterne', 'Référence', None),
        ('ObsPaiement', 'Observations', None), ('motif', 'Motif', None),
    ],
    'clotures': [('IdCaisseFk', 'Caisse', 'caisses'), ('ClotureLe', 'Date et heure du comptage', None),
                 ('MontantCompte', 'Montant compté', None), ('motif', 'Motif', None)],
}
JOURNAL_REQUIRED = {
    'ecritures': {'IdCaisseFk', 'DatePaiement', 'SensMouvement', 'LibellePaiement', 'MontantPaiement'},
    'clotures': {'IdCaisseFk', 'ClotureLe', 'MontantCompte', 'motif'},
}
JOURNAL_SHEETS = {'ecritures': 'Ecritures', 'clotures': 'Clotures'}


def _journal_kind(kind):
    if kind not in JOURNAL_FIELDS:
        raise APIError('Registre inconnu.', 'NOT_FOUND', 404)
    return JOURNAL_FIELDS[kind]


def build_journal_template(actor, kind):
    fields = _journal_kind(kind)
    references = services.references(actor)
    columns = []
    for key, label, source in fields:
        choices = []
        for row in references.get(source, []) if source else []:
            if row.get('disabled') or row.get('incompatible') or row.get('active') is False or row.get('Actif') is False:
                continue
            if source == 'caisses':
                choices.append({'value': str(row['IdCaisse']),
                                'label': ' · '.join(str(row[name]) for name in ('CodeCaisse', 'NomCaisse', 'DeviseCode') if row.get(name))})
            else:
                choices.append({'value': str(row['id']), 'label': reference_label(row)})
        if key == 'SensMouvement':
            choices = [{'value': '1', 'label': 'Encaissement'}, {'value': '-1', 'label': 'Décaissement'}]
        columns.append({'key': key, 'label': label, 'required': key in JOURNAL_REQUIRED[kind],
                        'width': 48 if key in {'ObsPaiement', 'motif'} else 30,
                        **({'choices': choices} if choices else {})})
    return build_template(sheet_name=JOURNAL_SHEETS[kind], columns=columns, notes=[
        ('Périmètre', 'Les opérations restent liées à l’entreprise active et aux caisses autorisées.'),
        ('Obligatoire', ', '.join(label for key, label, _ in fields if key in JOURNAL_REQUIRED[kind])),
        ('Date et heure', 'AAAA-MM-JJTHH:MM:SS ou JJ/MM/AAAA HH:MM:SS ; heure de Kinshasa. Aucune date n’est inventée pour une ligne importée.'),
        ('Montants', 'Montant positif, avec deux décimales au maximum ; le comptage peut être nul. La devise est celle de la caisse choisie.'),
        ('Validation', 'L’import prépare les lignes dans le panier. Le mode de validation de l’entreprise s’applique à l’enregistrement.'
            if kind == 'ecritures' else 'Les soldes théoriques et révisions ne viennent pas du fichier. Vérifiez les soldes et les comptages puis confirmez la clôture avant enregistrement.'),
        ('Codes et soldes', 'N’ajoutez ni code, solde théorique, révision ni option de validation au fichier. Ces informations restent sous contrôle du serveur.'),
        ('Contrôle', 'Le panier est modifiable avant enregistrement de l’ensemble. Une erreur annule toutes ses écritures.'),
    ], max_rows=MAX_ROWS)


def invalid(message='Ce classeur Excel est illisible. Utilisez un fichier .xlsx valide.'):
    return APIError(message, 'CAISSE_EXCEL_INVALID')


def too_large():
    return APIError('Le fichier Excel ne doit pas dépasser 4 Mo.', 'CAISSE_EXCEL_SIZE', 413)


class CashWorkbookUploadHandler(MemoryFileUploadHandler):
    """Un seul fichier borné en mémoire, sans fichier temporaire sur disque."""

    def handle_raw_input(self, input_data, META, content_length, boundary, encoding=None):
        self.activated = True

    def receive_data_chunk(self, raw_data, start):
        if start + len(raw_data) > xlsx.MAX_UPLOAD_BYTES:
            raise too_large()
        return super().receive_data_chunk(raw_data, start)


def _cash_cells(worksheet, styled_numbers):
    worksheet.reset_dimensions()
    cells, fields = [], []
    total_length = 0
    for line, source in enumerate(worksheet.iter_rows(min_col=1, max_col=xlsx.MAX_COLUMNS), 1):
        if line > xlsx.MAX_SCAN_ROWS:
            raise invalid('La feuille Caisses s’étend sur trop de lignes. Copiez les données dans le modèle.')
        row = [xlsx._cell_text(cell, styled_numbers.get((line, column))
                if line > 1 and column <= len(fields) and fields[column - 1].startswith('Id') else None)
            for column, cell in enumerate(source, 1)]
        while row and row[-1] == '':
            row.pop()
        if line == 1:
            if not row:
                raise invalid('Placez les en-têtes sur la première ligne de la feuille Caisses.')
            fields = [HEADER_FIELDS.get(xlsx._header_key(header), '') for header in row]
            if not all(fields) or len(set(fields)) != len(fields):
                raise invalid('Vérifiez les noms des colonnes et retirez les en-têtes en double. Utilisez le modèle Caisses.')
            if not {'NomCaisse', 'IdDeviseFk'}.issubset(fields):
                raise invalid('Les colonnes Caisse et Devise sont obligatoires. Utilisez le modèle Caisses.')
        elif not row:
            continue
        elif len(row) > len(fields):
            raise invalid(f'La ligne {line} contient une cellule sans en-tête.')
        if any(len(value) > xlsx.MAX_CELL_LENGTH for value in row):
            raise invalid(f'Une cellule de la ligne {line} dépasse {xlsx.MAX_CELL_LENGTH} caractères.')
        total_length += sum(map(len, row))
        if total_length > xlsx.MAX_TOTAL_LENGTH:
            raise invalid('Les données de la feuille Caisses sont trop volumineuses.')
        cells.append(row)
        if len(cells) > MAX_ROWS + 1:
            raise invalid(f'Importez au maximum {MAX_ROWS} caisses à la fois.')
    if len(cells) <= 1:
        raise invalid('La feuille Caisses est vide. Ajoutez vos caisses sous les en-têtes.')
    return cells


def read_cash_workbook(upload):
    if upload.size > xlsx.MAX_UPLOAD_BYTES:
        raise too_large()
    if not upload.name.lower().endswith('.xlsx') or not upload.size:
        raise invalid('Choisissez un fichier Excel .xlsx non vide.')
    try:
        # Même défense ZIP/XML que les articles : expansion, macros, liens,
        # entités XML, profondeur et coordonnées de cellules contrôlés.
        xlsx._check_archive(upload)
        upload.seek(0)
        workbook = load_workbook(upload, read_only=True, data_only=False, keep_links=False)
        try:
            if 'Caisses' not in workbook.sheetnames and len(workbook.sheetnames) != 1:
                raise invalid('La feuille Caisses est introuvable. Utilisez le modèle Excel proposé.')
            worksheet = workbook['Caisses'] if 'Caisses' in workbook.sheetnames else workbook.active
            if not hasattr(worksheet, 'iter_rows'):
                raise invalid('La feuille Caisses est introuvable. Utilisez le modèle Excel proposé.')
            guard = xlsx._WorkbookXMLGuard(article_sheet=True)
            with xlsx.ZipFile(upload) as archive:
                xlsx._check_xml_part(archive, archive.getinfo(worksheet._worksheet_path), guard)
            return _cash_cells(worksheet, guard.styled_numbers)
        finally:
            workbook.close()
    except APIError as exc:
        if exc.default_code.startswith('ARTICLE_EXCEL_'):
            raise invalid(str(exc.detail).replace('Articles', 'Caisses')) from exc
        raise
    except (
        AttributeError, xlsx.BadZipFile, xlsx.CompressionError, xlsx.DefusedXmlException,
        IndexError, xlsx.InvalidFileException, xlsx.InvalidOperation, KeyError, OSError,
        OverflowError, xlsx.ParseError, RuntimeError, xlsx.StructError, TypeError, ValueError,
    ) as exc:
        raise invalid() from exc


def _text_cell(sheet, row, column, value):
    cell = sheet.cell(row, column, str(value) if value is not None else '')
    cell.data_type = 's'  # Un libellé commençant par « = » reste du texte.
    cell.number_format = '@'
    return cell


def _style_sheet(sheet, widths):
    border = Border(bottom=Side(style='thin', color='E5E7EB'))
    for row in sheet:
        for cell in row:
            cell.font = Font(name='Aptos', size=11, color='252525')
            cell.alignment = Alignment(vertical='top', wrap_text=True)
    for cell in sheet[1]:
        cell.font = Font(name='Aptos', size=11, bold=True, color='374151')
        cell.fill = PatternFill('solid', fgColor='F3F4F6')
        cell.border = border
    for index, width in enumerate(widths, 1):
        sheet.column_dimensions[get_column_letter(index)].width = width
    sheet.row_dimensions[1].height = 32
    sheet.freeze_panes = 'A2'
    sheet.auto_filter.ref = sheet.dimensions
    sheet.sheet_properties.pageSetUpPr.fitToPage = True
    sheet.page_setup.orientation = 'landscape'
    sheet.page_setup.paperSize = sheet.PAPERSIZE_A4
    sheet.page_setup.fitToWidth = 1
    sheet.page_setup.fitToHeight = 0
    sheet.print_title_rows = '1:1'
    sheet.print_options.horizontalCentered = True
    sheet.oddFooter.right.text = 'Page &P / &N'


def build_cash_template(actor, entity):
    """Lecture des seules listes du formulaire, dans l’entreprise autorisée."""
    scoped = services.entity_actor(actor, entity)
    groups = []
    for key, field in (('Devises', 'IdDeviseFk'), ('Types', 'IdTypeCaisseFk')):
        options = services.reference_options(scoped, 'operations', 'T_Caisse', field)
        groups.append((key, [(str(option['id']), reference_label(option)) for option in options
            if option.get('active', True) and not option.get('disabled') and not option.get('incompatible')]))
    owners = db.query('SELECT "IdUser" id,concat_ws(\' \',"PrenomUser","NomUser") label '
        'FROM systeme."T_Utilisateurs" WHERE "IdEntiteFk"=%s AND "ValideUser" IS TRUE ORDER BY label', [entity])
    groups.append(('Responsables', [(str(row['id']), row['label']) for row in owners]))
    organisation = db.one('SELECT "NomEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity])

    book = Workbook()
    sheet = book.active
    sheet.title = 'Caisses'
    sheet.append(HEADERS)
    # Cent lignes réellement vides, préparées en texte, jamais d’exemple à importer.
    for row in range(2, MAX_ROWS + 2):
        for column in range(1, len(HEADERS) + 1):
            _text_cell(sheet, row, column, '')
    _style_sheet(sheet, [34, 22, 24, 28, 16, 48])
    sheet.auto_filter.ref = f'A1:F{MAX_ROWS + 1}'
    sheet.print_area = f'A1:F{MAX_ROWS + 1}'
    sheet.oddFooter.left.text = 'Modèle de caisses'
    options_sheet = book.create_sheet('Options')
    options_sheet.append(['Identifiant devise', 'Devise', 'Identifiant type', 'Type de caisse',
        'Identifiant responsable', 'Responsable', 'État'])
    for index, (name, choices) in enumerate(groups):
        first_column = index * 2 + 1
        for row, (identifier, label) in enumerate(choices, 2):
            _text_cell(options_sheet, row, first_column, identifier)
            _text_cell(options_sheet, row, first_column + 1, label)
        if choices:
            letter = get_column_letter(first_column)
            range_name = 'Caisses_' + name
            book.defined_names.add(DefinedName(range_name, attr_text=f"'Options'!${letter}$2:${letter}${len(choices) + 1}"))
            validation = DataValidation(type='list', formula1=range_name, allow_blank=index != 0)
            validation.errorTitle = 'Valeur à vérifier'
            validation.error = 'Choisissez un identifiant de la feuille Options.'
            validation.showErrorMessage = True
            sheet.add_data_validation(validation)
            validation.add(f'{get_column_letter(index + 2)}2:{get_column_letter(index + 2)}{MAX_ROWS + 1}')
    _text_cell(options_sheet, 2, 7, 'Active')
    _text_cell(options_sheet, 3, 7, 'Inactive')
    state = DataValidation(type='list', formula1='"Active,Inactive"', allow_blank=True)
    sheet.add_data_validation(state)
    state.add(f'E2:E{MAX_ROWS + 1}')
    _style_sheet(options_sheet, [23, 28, 23, 28, 26, 36, 16])
    options_sheet.print_area = options_sheet.dimensions

    info = book.create_sheet('Informations')
    for row in [
        ('Information', 'Valeur'),
        ('Document', 'Modèle d’import des caisses'),
        ('Entreprise', (organisation or {}).get('NomEntite') or f'Entreprise #{entity}'),
        ('Entreprise — identifiant', str(entity)),
        ('Utilisation', 'Complétez Caisses sous les en-têtes, puis importez le fichier et vérifiez le panier avant d’enregistrer.'),
        ('Champs obligatoires', 'Caisse et Devise. Le motif est facultatif pour une nouvelle caisse.'),
        ('Listes', 'Utilisez les identifiants de la feuille Options ou les abréviations et noms proposés dans le formulaire.'),
        ('État', 'Active ou Inactive. Une cellule vide conserve le défaut du formulaire.'),
        ('Limites', f'{MAX_ROWS} caisses par fichier ; fichier .xlsx de 4 Mo maximum ; aucune formule dans Caisses.'),
        ('Solde et code', 'Le code est attribué à l’enregistrement. Le solde commence à zéro ; une reprise se fait par une écriture justifiée.'),
        ('Confidentialité', 'Les options correspondent à l’entreprise choisie. Les droits et références sont revérifiés à l’enregistrement.'),
    ]:
        info.append(row)
        for column, value in enumerate(row, 1):
            _text_cell(info, info.max_row, column, value)
    _style_sheet(info, [28, 105])
    for row in range(2, info.max_row + 1):
        info.row_dimensions[row].height = 34 if row >= 5 else 24
    info.print_area = info.dimensions
    target = BytesIO()
    book.save(target)
    book.close()
    target.seek(0)
    return target


class CashExcelTemplateView(CashView):
    renderer_classes = [*CashView.renderer_classes, ExcelFileRenderer]
    http_method_names = ['get', 'options']

    def get(self, request, kind='caisses'):
        entity = services.writable(request.user, kind)
        if request.query_params:
            raise APIError('Critère non autorisé.')
        stream = build_cash_template(request.user, entity) if kind == 'caisses' else build_journal_template(request.user, kind)
        sheet = 'Caisses' if kind == 'caisses' else JOURNAL_SHEETS[kind]
        response = FileResponse(stream, as_attachment=True,
            filename='SauverNdeko_Modele_'+sheet+'.xlsx', content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class CashExcelPreviewView(CashView):
    parser_classes = [MultiPartParser]
    http_method_names = ['post', 'options']

    def initialize_request(self, request, *args, **kwargs):
        request.upload_handlers = [CashWorkbookUploadHandler(request)]
        return super().initialize_request(request, *args, **kwargs)

    def post(self, request, kind='caisses'):
        services.writable(request.user, kind)
        if request.query_params:
            raise APIError('Critère non autorisé.')
        if kind != 'caisses':
            fields = _journal_kind(kind)
            headers = {alias: key for key, label, _ in fields for alias in (key, label)}
            cells = read_uploaded_workbook(request, sheet_name=JOURNAL_SHEETS[kind], headers=headers,
                                          required_headers=JOURNAL_REQUIRED[kind], max_rows=MAX_ROWS)
            return ok({'cells': cells})
        try:
            content_length = int(request.META.get('CONTENT_LENGTH') or 0)
        except ValueError:
            content_length = 0
        if content_length > xlsx.MAX_UPLOAD_BYTES + 64 * 1024:
            raise too_large()
        if content_length <= 0:
            raise invalid('Choisissez un fichier Excel .xlsx.')
        if set(request.data) != {'fichier'} or len(request.data.getlist('fichier')) != 1 or 'fichier' not in request.FILES:
            raise invalid('Choisissez un seul fichier Excel .xlsx.')
        return ok({'cells': read_cash_workbook(request.FILES['fichier'])})
