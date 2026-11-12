"""Sources fermées des registres multi-dépôts, communes aux listes et exports.

Les préférences ne modifient ni le périmètre de l'entreprise ni les droits du
module. Les vues restent la source des quantités, sans recalcul dans l'export.
"""
from tempfile import SpooledTemporaryFile

from django.db import connection
from django.http import FileResponse
from django.utils import timezone
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.repository import clean, page, positive
from apps.core.responses import APIError, ExactJSONRenderer, ok
from apps.core.tabular_exports import selected_scope, write_tabular
from apps.core.table_preferences import export_keys
from .excel import ExcelDownloadView, ExcelFileRenderer, CSVFileRenderer, XLSX_MEDIA_TYPE
from .table_queries import document_zone


INVENTORY_REGISTERS = {'inventaires', 'lignes-inventaires'}
KINDS = {'depots', 'stocks-depots', 'transferts'} | INVENTORY_REGISTERS
LABELS = {
    'ID_Depot': 'N° dépôt', 'CodeDepot': 'Code', 'NomDepot': 'Dépôt',
    'AdresseDepot': 'Adresse', 'Principal': 'Principal', 'Actif': 'État',
    'NomEntite': 'Entreprise', 'NbArticles': 'Articles', 'CreeLe': 'Créé le',
    'ModifieLe': 'Modifié le', 'NomArticle': 'Article', 'AbrUnite': 'Unité',
    'StockPhysique': 'Stock physique', 'StockDisponible': 'Disponible',
    'StockReserve': 'Réservé', 'StockIndisponible': 'Indisponible',
    'StockSansLot': 'Sans lot', 'StockEntreprise': 'Stock entreprise',
    'CodeTransfert': 'Transfert', 'DateTransfert': 'Date et heure',
    'DepotSource': 'Dépôt source', 'DepotDestination': 'Dépôt destination',
    'EtatCode': 'État', 'NbLignes': 'Lignes', 'Motif': 'Motif',
    'ReferenceTransfert': 'Référence', 'QteTransit': 'En transit',
    'QteExpediee': 'Expédié', 'QteRecue': 'Reçu', 'QteRetournee': 'Retourné',
    'QteEcart': 'Écart', 'CodeInventaire': 'Inventaire',
    'DateInventaire': 'Date et heure', 'NbEcarts': 'Écarts', 'Etat': 'État',
    'ValideLe': 'Validé le', 'AnnuleLe': 'Annulé le',
    'MotifAnnulation': 'Motif d’annulation',
    'EtatInventaire': 'État de l’inventaire', 'CodeArticleInterne': 'Code article',
    'Unite': 'Unité', 'QteTheorique': 'Quantité théorique', 'QteComptee': 'Quantité physique',
    'Ecart': 'Écart', 'Justification': 'Justification', 'CodeCorrection': 'Bon de correction',
    'CodeAnnulation': 'Bon d’annulation',
}

# Identifiants stables, explicitement distincts des secrets/preuves techniques.
FIELDS = {
    'depots': {
        'ID_Depot': 'bigint', 'CodeDepot': 'text', 'NomDepot': 'text',
        'AdresseDepot': 'text', 'Principal': 'boolean', 'Actif': 'boolean',
        'NomEntite': 'text', 'NbArticles': 'bigint', 'StockPhysique': 'numeric',
        'StockReserve': 'numeric', 'CreeLe': 'timestamp with time zone',
        'ModifieLe': 'timestamp with time zone',
    },
    'stocks-depots': {
        'NomArticle': 'text', 'NomDepot': 'text', 'StockPhysique': 'numeric',
        'StockDisponible': 'numeric', 'StockReserve': 'numeric',
        'StockIndisponible': 'numeric', 'StockEntreprise': 'numeric',
        'StockSansLot': 'numeric', 'CodeDepot': 'text', 'AbrUnite': 'text',
    },
    'transferts': {
        'CodeTransfert': 'text', 'DateTransfert': 'timestamp with time zone',
        'DepotSource': 'text', 'DepotDestination': 'text', 'EtatCode': 'text',
        'NbLignes': 'bigint', 'Motif': 'text', 'ReferenceTransfert': 'text',
        'QteTransit': 'numeric', 'QteExpediee': 'numeric', 'QteRecue': 'numeric',
        'QteRetournee': 'numeric', 'QteEcart': 'numeric',
        'CreeLe': 'timestamp with time zone', 'ModifieLe': 'timestamp with time zone',
    },
    'inventaires': {
        'CodeInventaire': 'text', 'DateInventaire': 'timestamp with time zone',
        'Motif': 'text', 'NbArticles': 'bigint', 'NbEcarts': 'bigint', 'Etat': 'text',
        'ValideLe': 'timestamp with time zone', 'AnnuleLe': 'timestamp with time zone',
        'MotifAnnulation': 'text', 'CreeLe': 'timestamp with time zone',
        'ModifieLe': 'timestamp with time zone',
    },
    'lignes-inventaires': {
        'CodeInventaire': 'text', 'DateInventaire': 'timestamp with time zone',
        'NomDepot': 'text', 'NomArticle': 'text', 'CodeArticleInterne': 'text',
        'QteTheorique': 'numeric', 'QteComptee': 'numeric', 'Unite': 'text',
        'Ecart': 'numeric', 'Justification': 'text', 'EtatInventaire': 'text',
        'Motif': 'text', 'CodeCorrection': 'text', 'CodeAnnulation': 'text',
    },
}
VIEWS = {'depots': 'V_Depot', 'stocks-depots': 'V_StockDepot',
         'transferts': 'V_TransfertDepot', 'inventaires': 'V_Inventaire',
         'lignes-inventaires': 'V_InventaireLigne'}
IDENTITIES = {'depots': 'ID_Depot', 'stocks-depots': ['ID_ArticleFk', 'ID_DepotFk'],
              'transferts': 'ID_TransfertDepot', 'inventaires': 'ID_Inventaire',
              'lignes-inventaires': ['ID_InventaireFk', 'ID_ArticleFk']}
TITLES = {'depots': 'Dépôts', 'stocks-depots': 'Stocks par dépôt',
          'transferts': 'Transferts internes', 'inventaires': 'Inventaires physiques',
          'lignes-inventaires': 'Lignes d’inventaire'}

INVENTORY_LINE_SOURCE = '''
    (SELECT l."ID_InventaireFk", l."ID_ArticleFk", h."IdEntiteFk", h."ID_DepotFk",
            h."CodeInventaire", h."DateInventaire", h."Etat" AS "EtatInventaire", h."Motif",
            d."NomDepot", l."NomArticle", l."CodeArticleInterne", l."Unite", l."Decimales",
            l."QteTheorique", l."QteComptee", l."Ecart", l."Justification",
            l."ID_CommandeCorrectionFk", l."CodeCorrection",
            l."ID_CommandeAnnulationFk", l."CodeAnnulation"
     FROM logistique."V_InventaireLigne" l
     JOIN logistique."V_Inventaire" h
       ON h."ID_Inventaire"=l."ID_InventaireFk" AND h."IdEntiteFk"=l."IdEntiteFk"
     LEFT JOIN logistique."T_Depot" d
       ON d."ID_Depot"=h."ID_DepotFk" AND d."IdEntiteFk"=h."IdEntiteFk") v
'''


def register_access(actor, kind):
    if kind in INVENTORY_REGISTERS:
        from .inventories import access
    else:
        from .depots import access
    return access(actor)


def source(actor, kind):
    """Le catalogue de présentation n'étend jamais cette liste autorisée."""
    if kind not in KINDS:
        raise APIError('Registre inconnu.', 'NOT_FOUND', 404)
    register_access(actor, kind)
    return {'schema': 'logistique', 'name': VIEWS[kind],
            'primaryKey': IDENTITIES[kind],
            'columns': [{'column_name': key, 'data_type': typ} for key, typ in FIELDS[kind].items()]}


def query_scope(actor, kind, raw):
    """Filtres et tri uniques pour la pagination et l'extraction complète."""
    obj = source(actor, kind)
    from .depots import requested_depot
    owner = register_access(actor, kind)
    clauses, values = ['TRUE'], []
    if owner is not None:
        clauses.append('v."IdEntiteFk"=%s'); values.append(owner)
    q = str(raw.get('q', '')).strip()[:200]
    sorts = dict(FIELDS[kind])
    if kind == 'depots':
        if q:
            clauses.append('(v."NomDepot" ILIKE %s OR v."CodeDepot" ILIKE %s OR v."AdresseDepot" ILIKE %s)')
            values.extend(['%' + q + '%'] * 3)
        active = raw.get('actif', 'all')
        if active not in ('all', 'true', 'false'):
            raise APIError('État du dépôt invalide.')
        if active != 'all':
            clauses.append('v."Actif"=%s'); values.append(active == 'true')
        default_sort, default_dir = 'NomDepot', 'asc'
    else:
        selected = requested_depot(actor, raw)
        if selected:
            if kind == 'transferts':
                clauses.append('(v."ID_DepotSourceFk"=%s OR v."ID_DepotDestinationFk"=%s)')
                values.extend([selected, selected])
            else:
                clauses.append('v."ID_DepotFk"=%s'); values.append(selected)
        if kind == 'stocks-depots':
            if raw.get('articleId'):
                clauses.append('v."ID_ArticleFk"=%s'); values.append(positive(raw['articleId']))
            search = ['NomArticle', 'NomDepot']
            default_sort, default_dir = 'NomArticle', 'asc'
        elif kind == 'transferts':
            search = ['CodeTransfert', 'Motif', 'ReferenceTransfert']
            if raw.get('etat'):
                clauses.append('v."EtatCode"=%s'); values.append(raw['etat'])
            for parameter, column in [('depotSourceId', 'ID_DepotSourceFk'), ('depotDestinationId', 'ID_DepotDestinationFk')]:
                if raw.get(parameter):
                    # Une référence d'une autre entreprise n'est pas exploitable,
                    # même pour choisir le périmètre d'une extraction.
                    identifier = requested_depot(actor, {'depotId': raw[parameter]})
                    clauses.append('v.' + db.ident(column) + '=%s'); values.append(identifier)
            sorts['ID_TransfertDepot'] = 'bigint'
            default_sort, default_dir = 'DateTransfert', 'desc'
        elif kind == 'lignes-inventaires':
            for parameter, key, label in (('inventaireId', 'ID_InventaireFk', 'Inventaire'),
                                          ('articleId', 'ID_ArticleFk', 'Article')):
                if raw.get(parameter) not in (None, '', 'all'):
                    clauses.append('v.' + db.ident(key) + '=%s')
                    values.append(positive(raw[parameter], label))
            state = raw.get('etat') or 'all'
            if state not in ('all', 'brouillon', 'valide', 'annule'):
                raise APIError('État de l’inventaire invalide.')
            if state != 'all':
                clauses.append('v."EtatInventaire"=%s')
                values.append(state)
            differences = {'all': 'TRUE', 'avec': 'v."Ecart"<>0', 'sans': 'v."Ecart"=0',
                           'positif': 'v."Ecart">0', 'negatif': 'v."Ecart"<0'}
            difference = raw.get('ecart') or 'all'
            if difference not in differences:
                raise APIError('Filtre d’écart invalide.')
            clauses.append(differences[difference])
            from .ledger_registers import period_clause
            period, period_values = period_clause(obj, 'DateInventaire', raw.get('dateFrom'), raw.get('dateTo'), raw)
            if period:
                clauses.append(period)
                values.extend(period_values)
            search = ['CodeInventaire', 'Motif', 'NomDepot', 'NomArticle', 'CodeArticleInterne', 'Justification']
            default_sort, default_dir = 'DateInventaire', 'desc'
        else:
            search = ['CodeInventaire', 'Motif']
            default_sort, default_dir = 'DateInventaire', 'desc'
        if q:
            clauses.append('(' + ' OR '.join('v.' + db.ident(key) + ' ILIKE %s' for key in search) + ')')
            values.extend(['%' + q + '%'] * len(search))
    sort, direction = raw.get('sortBy', default_sort), raw.get('sortDir', default_dir)
    if sort not in sorts or direction not in ('asc', 'desc'):
        raise APIError('Tri invalide.')
    if kind == 'stocks-depots':
        relation = '''(SELECT s.*,a."NomArticle",a."QteArticle" AS "StockEntreprise",
          u."AbrGenerique" AS "AbrUnite",d."NomDepot",d."CodeDepot"
          FROM logistique."V_StockDepot" s
          JOIN logistique."T_Article" a ON a."ID_Article"=s."ID_ArticleFk"
          JOIN logistique."T_Depot" d ON d."ID_Depot"=s."ID_DepotFk"
          LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk") v'''
    elif kind == 'lignes-inventaires':
        relation = INVENTORY_LINE_SOURCE
    else:
        relation = 'logistique.' + db.ident(VIEWS[kind]) + ' v'
    identity = IDENTITIES[kind]
    keys = [identity] if isinstance(identity, str) else identity
    order = 'v.' + db.ident(sort) + ' ' + direction + ' NULLS LAST,' + ','.join('v.' + db.ident(key) + ' DESC' for key in keys)
    return relation, ' AND '.join(clauses), values, order, sort, direction


def listing(actor, kind, raw):
    relation, where, values, order, sort, direction = query_scope(actor, kind, raw)
    take, skip = page(raw)
    if kind in INVENTORY_REGISTERS:
        take = min(take, 100)
    count = db.one('SELECT count(*) n FROM ' + relation + ' WHERE ' + where, values)['n']
    rows = db.query('SELECT v.* FROM ' + relation + ' WHERE ' + where + ' ORDER BY ' + order + ' LIMIT %s OFFSET %s', [*values, take, skip])
    meta = {'filteredCount': count, 'take': take, 'skip': skip, 'sortBy': sort, 'sortDir': direction}
    if kind == 'depots':
        for row in rows:
            row.update(id=row['ID_Depot'], label=row['NomDepot'], principal=row['Principal'], active=row['Actif'], revision=str(row['Version']))
    if kind == 'transferts':
        from .transfers import capabilities
        for row in rows:
            row['capabilities'] = capabilities(actor, row)
    if kind in ('depots', 'transferts'):
        from .depots import can_manage
        from apps.core.module_access import can_use_tab
        allowed = can_manage(actor) and can_use_tab(actor, "logistique", kind, "manage")
        meta.update(canManage=allowed, canCreate=allowed)
    return clean(rows), meta


def workbook(actor, kind, raw, file_format):
    require_module(actor, 'logistique', 'export')
    obj = source(actor, kind)
    wanted = export_keys(actor, 'logistique.' + kind, raw)
    fields = [{**field, 'label': LABELS[field['column_name']],
               **({'data_type': 'text'} if field['column_name'].startswith('ID_') else {})}
              for key in wanted for field in obj['columns'] if field['column_name'] == key]
    relation, where, values, order, sort, direction = query_scope(actor, kind, raw)
    selection, selection_values = selected_scope(raw, IDENTITIES[kind])
    where += selection; values.extend(selection_values)
    zone = document_zone(raw)
    from apps.core.tenancy import read_entity
    entity = read_entity(actor)
    company = db.one('SELECT "NomEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity]) if entity is not None else None
    context = {'title': TITLES[kind], 'scope': company['NomEntite'] if company else 'Entreprises autorisées',
               'generated': timezone.now().astimezone(zone).strftime('%d/%m/%Y %H:%M'),
               'zone': str(zone), 'tz': zone, 'source': 'logistique.' + VIEWS[kind],
               'raw': raw, 'filters': {key: raw[key] for key in ('actif', 'depotId', 'articleId', 'etat', 'depotSourceId', 'depotDestinationId', 'inventaireId', 'ecart') if raw.get(key)},
               'filterLabels': {'actif': 'État du dépôt', 'depotId': 'Dépôt · identifiant',
                                'articleId': 'Article · identifiant',
                                'etat': 'État de l’inventaire' if kind == 'lignes-inventaires' else 'État du transfert',
                                'inventaireId': 'Inventaire · identifiant', 'ecart': 'Écart',
                                'depotSourceId': 'Dépôt source · identifiant', 'depotDestinationId': 'Dépôt destination · identifiant'},
               'order': LABELS.get(sort, sort) + ' ' + direction}
    target = SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode='w+b')
    try:
        with connection.cursor() as cursor:
            from .excel import MAX_EXPORT_ROWS
            cursor.execute('SELECT ' + ','.join('v.' + db.ident(key) for key in wanted) + ' FROM ' + relation + ' WHERE ' + where + ' ORDER BY ' + order + ' LIMIT %s', [*values, MAX_EXPORT_ROWS + 1])
            keys = [item[0] for item in cursor.description]
            def rows():
                while True:
                    batch = cursor.fetchmany(500)
                    if not batch:
                        return
                    for row in batch:
                        yield dict(zip(keys, row))
            count = write_tabular(target, fields, rows(), context, file_format)
        target.seek(0)
        name = 'SauverNdeko_Logistique_' + kind.replace('-', '_') + '_' + timezone.now().astimezone(zone).strftime('%Y-%m-%d') + ('_Selection' if raw.get('selection') else '_Complet') + '.' + file_format
        return target, count, name
    except Exception:
        target.close()
        raise


class DepotRegisterExportView(ExcelDownloadView):
    renderer_classes = [ExactJSONRenderer, ExcelFileRenderer, CSVFileRenderer]

    def get(self, request, kind, file_format):
        stream, count, filename = workbook(request.user, kind, request.query_params.dict(), file_format)
        response = FileResponse(stream, as_attachment=True, filename=filename,
                                content_type=XLSX_MEDIA_TYPE if file_format == 'xlsx' else 'text/csv; charset=utf-8')
        response['X-Export-Row-Count'] = str(count)
        response['Cache-Control'] = 'no-store, private'
        return response


class InventoryLinesView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        rows, meta = listing(request.user, 'lignes-inventaires', request.query_params)
        return ok(rows, meta=meta)
