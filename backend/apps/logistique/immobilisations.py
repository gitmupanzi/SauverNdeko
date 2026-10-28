"""Registre des immobilisations : patrimoine tenant, distinct du stock marchand.

Les libellés et valeurs proviennent des vues PostgreSQL. Le trigger assure
l'identité, les contraintes et l'audit ; aucun mouvement ni amortissement ici.
"""
import hashlib
import hmac
import json
import unicodedata
import uuid
from decimal import Decimal, InvalidOperation
from datetime import datetime
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import transaction
from django.http import FileResponse
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import access_snapshot, require_module
from apps.core.permissions import IsERPAdmin, scope_for
from apps.core.registry import model, view
from apps.core.repository import clean, coerce, positive, set_admin_actor
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.tenancy import read_entity, require_entity
from .currency import currency_references, default_currency, validate_currency

TABLE = 'T_Immobilisation'
VIEW = 'V_Immobilisation'
KEY = 'ID_Immobilisation'
INTERFACE = 'logistique.immobilisations'
FIELDS = {'NomImmobilisation', 'Reference', 'Caracteristiques', 'Quantite', 'SuiviIndividuel',
    'PrixUnitaire', 'ID_DeviseFk', 'ID_CategorieFk', 'ID_EtatFk', 'ID_ResponsableFk', 'ID_ServiceFk',
    'ID_LocalisationFk', 'LocalisationComplement', 'DateEntree', 'DateAcquisition', 'NumeroSerie', 'Observations', 'Actif'}
FK_FIELDS = {'ID_DeviseFk', 'ID_CategorieFk', 'ID_EtatFk', 'ID_ResponsableFk', 'ID_ServiceFk', 'ID_LocalisationFk'}
TEXT_LIMITS = {'NomImmobilisation': 200, 'Reference': 255, 'NumeroSerie': 255,
    'Caracteristiques': 4000, 'Observations': 4000, 'LocalisationComplement': 255}
REFERENCE_RULES = {
    'types': ('ID_CategorieFk', 'logistique.immobilisations.categories', 'Type de matériel'),
    'etats': ('ID_EtatFk', 'logistique.immobilisations.etats', 'Etat'),
    'services': ('ID_ServiceFk', 'logistique.immobilisations.services', 'Service'),
}
QUERY_KEYS = {'q', 'take', 'skip', 'sortBy', 'sortDir', 'columnFilters', 'filters', 'dateFrom', 'dateTo',
    'timeZone', 'typeId', 'categorieId', 'etatId', 'serviceId', 'responsableId', 'localisationId', 'actif', 'deviseId', 'suiviIndividuel'}


def fail(message, field=None, code='IMMOBILISATION_VALIDATION', status=400):
    raise APIError({field: message} if field else message, code, status)


def source():
    return {**view('logistique', VIEW), 'primaryKey': [KEY], '_date_field': 'DateEntree'}


def register_source(raw, for_export=False):
    if set(raw) - QUERY_KEYS - ({'columns', 'selection'} if for_export else set()):
        fail('Critère non autorisé.')
    obj = source()
    columns = {col['column_name']: col for col in obj['columns']}
    filters = {}
    try:
        given = raw.get('filters', {})
        given = json.loads(given) if isinstance(given, str) else given
    except (TypeError, ValueError):
        fail('Filtres invalides.')
    if not isinstance(given, dict) or set(given) - (FK_FIELDS | {'Actif', 'SuiviIndividuel'}):
        fail('Filtre catégoriel non autorisé.')
    for key, value in given.items():
        filters[key] = coerce(columns[key], value)
    mapping = {'typeId': 'ID_CategorieFk', 'categorieId': 'ID_CategorieFk', 'etatId': 'ID_EtatFk',
        'serviceId': 'ID_ServiceFk', 'responsableId': 'ID_ResponsableFk', 'localisationId': 'ID_LocalisationFk', 'deviseId': 'ID_DeviseFk'}
    missing = {'responsableId': 'sans-affectation', 'serviceId': 'sans-service', 'localisationId': 'sans-localisation'}
    for key, field in mapping.items():
        value = raw.get(key)
        if value in (None, '', 'all'):
            continue
        selected = None if value == missing.get(key, object()) else positive(value, 'Référence')
        if field in filters and filters[field] != selected:
            fail('Deux critères contradictoires ciblent le même champ.')
        filters[field] = selected
    for key, field, default in [('actif', 'Actif', 'true'), ('suiviIndividuel', 'SuiviIndividuel', 'all')]:
        value = raw.get(key, 'all' if field in filters else default)
        if value in ('', None):
            value = default
        if value not in {'true', 'false', 'all'}:
            fail('Choisissez un état valide.', field)
        if value != 'all':
            selected = value == 'true'
            if field in filters and filters[field] != selected:
                fail('Deux critères contradictoires ciblent le même champ.')
            filters[field] = selected
    return obj, 'TRUE', filters


def record(actor, pk, *, lock=False):
    require_module(actor, 'logistique')
    obj = model(TABLE) if lock else source()
    where, values = scope_for(obj, actor)
    row = db.one('SELECT v.*' + (',xmin::text AS "_version"' if lock else '') + ' FROM '
        + db.qualified('logistique', TABLE if lock else VIEW) + ' v WHERE (' + where + ') AND v.'
        + db.ident(KEY) + '=%s' + (' FOR UPDATE OF v' if lock else ''), [*values, positive(pk)])
    if not row:
        fail('Immobilisation introuvable dans votre entreprise.', code='NOT_FOUND', status=404)
    return row


def rights(actor, row=None):
    access = access_snapshot(actor)['modules']['logistique']
    writable = bool(actor.admin and access['canManage'] and not settings.DB_READ_ONLY)
    selected = read_entity(actor)
    writable = writable and selected is not None and (row is None or selected == row['IdEntiteFk'])
    if writable:
        owner = db.one('SELECT "ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [selected])
        writable = bool(owner and owner['ValideEntite'] is not False)
    return {'canWrite': writable, 'canEdit': writable, 'canArchive': writable and bool(row and row['Actif']),
        'canRestore': writable and bool(row and not row['Actif']), 'canExport': access['canExport'],
        'revision': (row or {}).get('_version'), 'entityId': selected}


def list_data(actor, raw):
    require_module(actor, 'logistique')
    from .reads import read_page, row_source
    obj, condition, filters = register_source(raw)
    rows, meta, (where, params) = read_page(obj, actor, raw, condition, filters)
    # Valeur par bien calculée par la vue ; aucune somme entre devises et aucun
    # zéro fictif lorsque tous les prix d’un groupe sont inconnus.
    groups = db.query('''SELECT v."ID_DeviseFk" AS id,v."DeviseCode" AS code,v."DeviseLibelle" AS label,
        sum(v."ValeurAcquisition") AS value,count(*) AS count,
        count(*) FILTER (WHERE v."ValeurAcquisition" IS NULL) AS "unknownCount"
        FROM ''' + row_source(obj) + ' WHERE ' + where
        + ' GROUP BY v."ID_DeviseFk",v."DeviseCode",v."DeviseLibelle" ORDER BY code NULLS LAST,id NULLS LAST', params)
    return clean(rows), {**meta, **rights(actor), 'amountsByCurrency': groups, 'source': 'logistique.' + VIEW}


def normalized(value):
    return ''.join(char for char in unicodedata.normalize('NFKD', str(value or '')) if not unicodedata.combining(char)).strip().casefold()


def references(actor, current=None):
    from apps.core.field_references import reference_context, reference_options
    from apps.core.reference_integration import entity_actor
    require_module(actor, 'logistique')
    entity = (current or {}).get('IdEntiteFk') or read_entity(actor)
    context_actor = entity_actor(actor, entity)
    result, meta = {}, {}
    for key, (field, source_key, label) in REFERENCE_RULES.items():
        result[key] = reference_options(context_actor, 'logistique', TABLE, field, current=(current or {}).get(field))
        meta[key] = {**reference_context(context_actor, 'logistique', TABLE, field),
                     'schemaName': 'logistique', 'tableName': TABLE,
                     'fieldName': field, 'sourceKey': source_key, 'fieldLabel': label}
    # L’affectation RH passée/future n’est pas une affectation matérielle. Seuls
    # les comptes actuellement affectables peuvent être choisis à nouveau.
    scope, params = ('u."IdEntiteFk"=%s', [entity]) if entity else ('TRUE', [])
    result['responsables'] = db.query('''SELECT u."IdUser" AS id,concat_ws(' ',u."PrenomUser",u."NomUser") AS label,
        u."MatriculeUser" AS matricule,u."IdEntiteFk" AS "entityId",u."ID_ServiceFk" AS "serviceId"
        FROM systeme."T_Utilisateurs" u WHERE ''' + scope + ''' AND u."ValideUser" IS TRUE
        AND (u."DateEmbauche" IS NULL OR u."DateEmbauche"<=CURRENT_DATE)
        AND (u."DateFinEmploi" IS NULL OR u."DateFinEmploi">=CURRENT_DATE)
        ORDER BY lower(u."NomUser"),lower(u."PrenomUser"),u."IdUser"''', params)
    result['localisations'] = db.query('''SELECT l."IdEntiteLocalisation" AS id,l."IdEntite" AS "entityId",
        COALESCE(NULLIF(concat_ws(' · ',NULLIF(l."AdresseDetaillee",''),NULLIF(l."NomNiveau_3",''),NULLIF(l."NomNiveau_4",''),NULLIF(l."NomNiveau_5",'')),''),'Localisation #'||l."IdEntiteLocalisation"::text) AS label
        FROM systeme."V_Entite_Localisation_Detail" l WHERE l."IdEntiteLocalisation" IS NOT NULL AND ''' + ('l."IdEntite"=%s' if entity else 'TRUE')
        + ' ORDER BY label,l."IdEntiteLocalisation"', [entity] if entity else [])
    for field, key, sql in [('ID_ResponsableFk', 'responsables', 'SELECT "IdUser" AS id,concat_ws(\' \',"PrenomUser","NomUser") AS label FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s AND "IdEntiteFk"=%s'),
        ('ID_LocalisationFk', 'localisations', 'SELECT "IdEntiteLocalisation" AS id,COALESCE(NULLIF("AdresseDetaillee",\'\'),\'Localisation #\'||"IdEntiteLocalisation"::text) AS label FROM systeme."T_Entite_Localisation" WHERE "IdEntiteLocalisation"=%s AND "IdEntiteFk"=%s')]:
        retained = (current or {}).get(field)
        if retained is not None and not any(row['id'] == retained for row in result[key]):
            old = db.one(sql, [retained, entity])
            if old:
                result[key].append({**old, 'disabled': True})
    result['currencies'] = currency_references(context_actor, table=TABLE)
    retained_currency = (current or {}).get('ID_DeviseFk')
    if retained_currency is not None and not any(item['id'] == retained_currency for item in result['currencies']):
        result['currencies'].append({**validate_currency(retained_currency, unchanged=True, actor=context_actor, table=TABLE), 'disabled': True})
    result['defaultCurrencyId'] = default_currency(context_actor, table=TABLE)['id']
    result['referenceMeta'] = meta
    can_write = rights(actor)['canWrite']
    result.update({'canCreate': can_write, 'canWrite': can_write})
    return clean(result)


def validate(actor, body, old=None):
    columns = {column['column_name']: column for column in model(TABLE)['columns']}
    values = {}
    for field in FIELDS.intersection(body):
        raw = body[field]
        if field in TEXT_LIMITS:
            if raw is not None and not isinstance(raw, str):
                fail('Renseignez une valeur texte.', field)
            text = (raw or '').replace('\r\n', '\n')
            multiline = field in {'Caracteristiques', 'Observations'}
            if len(text) > TEXT_LIMITS[field] or any(unicodedata.category(char) in {'Cc', 'Cs', 'Zl', 'Zp'} and not (multiline and char == '\n') for char in text):
                fail('Texte trop long ou contenant des caractères de contrôle.', field)
            values[field] = text.strip() or None
        elif field in {'Actif', 'SuiviIndividuel'}:
            if not isinstance(raw, bool):
                fail('Choisissez un état valide.', field)
            values[field] = raw
        elif field == 'Quantite':
            try:
                if isinstance(raw, bool):
                    raise ValueError()
                number = Decimal(str(raw))
                if not number.is_finite() or number != number.to_integral_value() or not 1 <= number <= 999999999999999999:
                    raise ValueError()
            except (ValueError, InvalidOperation):
                fail('Indiquez une quantité entière positive de dix-huit chiffres au maximum.', field)
            values[field] = number
        elif field in FK_FIELDS:
            values[field] = positive(raw, 'Référence') if raw not in (None, '') else None
        else:
            values[field] = coerce(columns[field], raw)
            if field == 'DateEntree' and isinstance(values[field], datetime) and values[field].tzinfo is None:
                values[field] = values[field].replace(tzinfo=ZoneInfo(settings.TIME_ZONE))
    if old is None:
        values.setdefault('Quantite', Decimal(1))
        values.setdefault('SuiviIndividuel', True)
        values.setdefault('Actif', True)
    effective = {**(old or {}), **values}
    if not effective.get('NomImmobilisation'):
        fail('Indiquez la désignation du bien.', 'NomImmobilisation')
    if effective.get('ID_CategorieFk') is None:
        fail('Choisissez un type de matériel.', 'ID_CategorieFk')
    if (effective.get('SuiviIndividuel') is True or effective.get('NumeroSerie')) and effective.get('Quantite') != 1:
        fail('Un bien suivi individuellement ou portant un numéro de série a une quantité de 1.', 'Quantite')
    if values.get('PrixUnitaire') is not None and values['PrixUnitaire'] < 0:
        fail('Le prix ne peut pas être négatif.', 'PrixUnitaire')
    if old is None and 'ID_DeviseFk' not in values:
        values['ID_DeviseFk'] = default_currency(actor, table=TABLE)['id']
    currency = values.get('ID_DeviseFk', (old or {}).get('ID_DeviseFk'))
    if currency is None and effective.get('PrixUnitaire') is not None:
        fail('Choisissez une devise pour ce prix.', 'ID_DeviseFk')
    if currency is not None and ('ID_DeviseFk' in values or old is None):
        validate_currency(currency, unchanged=old is not None and currency == old.get('ID_DeviseFk'), actor=actor, table=TABLE)
    effective.update(values)
    refs = references(actor)
    for field, key in [('ID_CategorieFk', 'types'), ('ID_EtatFk', 'etats'), ('ID_ServiceFk', 'services'), ('ID_ResponsableFk', 'responsables'), ('ID_LocalisationFk', 'localisations')]:
        value = effective.get(field)
        if value is None or old is not None and value == old.get(field):
            continue
        if not any(item['id'] == value and not item.get('disabled') for item in refs[key]):
            fail('Choisissez une référence active de cette entreprise.', field, 'IMMOBILISATION_REFERENCE')
    return values


def save(actor, body, pk=None, *, archive=False):
    require_module(actor, 'logistique', 'manage')
    db.ensure_writable()
    entity = require_entity(actor)
    if not actor.admin:
        fail('Accès réservé aux gestionnaires.', code='FORBIDDEN', status=403)
    allowed = {'requestId', 'motif', '_version'} | (set() if archive else FIELDS)
    if not isinstance(body, dict) or set(body) - allowed:
        fail('Un champ du formulaire n’est pas autorisé.')
    try:
        request_id = str(uuid.UUID(body.get('requestId')))
    except (TypeError, ValueError, AttributeError):
        fail('Rouvrez le formulaire pour obtenir un identifiant de demande.')
    reason = body.get('motif')
    if not isinstance(reason, str) or not reason.strip() or len(reason) > 1000 or any(unicodedata.category(char) in {'Cc', 'Cs', 'Zl', 'Zp'} for char in reason):
        fail('Précisez un motif de 1 à 1000 caractères, sans caractère de contrôle.', 'motif')
    if pk is None and '_version' in body:
        fail('La révision n’est attendue qu’en modification.')
    pk = positive(pk) if pk is not None else None
    submitted = {key: value for key, value in body.items() if key not in {'requestId', '_version'}}
    payload_hash = hashlib.sha256(json.dumps({'entity': entity, 'id': pk, 'archive': archive, 'data': submitted}, cls=ExactEncoder, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()).hexdigest()
    with transaction.atomic():
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) locked', ['immobilisation:' + str(actor.pk) + ':' + request_id])
        previous = db.one('''SELECT "NewData" proof FROM systeme."T_Audit_Log"
            WHERE "TableName"='logistique.T_Immobilisation' AND "NewData"->>'requestId'=%s
            AND "NewData"->'_actor'->>'IdUser'=%s ORDER BY "IdLog" DESC LIMIT 1''', [request_id, str(actor.pk)])
        if previous:
            proof = previous['proof']
            if proof.get('IdEntiteFk') != entity or not hmac.compare_digest(str(proof.get('payloadHash', '')), payload_hash):
                fail('Cette demande est déjà utilisée pour un autre contenu.', code='IMMOBILISATION_REQUEST_CONFLICT', status=409)
            row = record(actor, proof[KEY])
            return row, {**rights(actor, row), 'replayed': True}, False
        old = record(actor, pk, lock=True) if pk is not None else None
        if old and (not isinstance(body.get('_version'), str) or not hmac.compare_digest(old['_version'], body['_version'])):
            fail('Cette fiche a changé. Rechargez-la avant de confirmer.', code='IMMOBILISATION_VERSION_CONFLICT', status=409)
        if old and old['IdEntiteFk'] != entity:
            fail('Choisissez l’entreprise de cette fiche avant de modifier.', code='ENTITY_MISMATCH', status=403)
        data = {'Actif': False} if archive else validate(actor, body, old)
        if archive and old is None:
            fail('Identifiant de la fiche requis.')
        if archive and old['Actif'] is False:
            fail('Cette immobilisation est déjà archivée.', code='IMMOBILISATION_ALREADY_ARCHIVED', status=409)
        operation = 'CREATE' if old is None else 'ARCHIVE' if data.get('Actif') is False and old['Actif'] is True else 'RESTORE' if data.get('Actif') is True and old['Actif'] is False else 'UPDATE'
        if old is not None and not data:
            fail('Aucune modification à enregistrer.')
        set_admin_actor(actor)
        db.one("SELECT set_config('logistique.immobilisation_request',%s,true) context", [json.dumps({'requestId': request_id, 'payloadHash': payload_hash, 'operation': operation, 'motif': reason.strip()})])
        if old is None:
            data['IdEntiteFk'] = entity
            fields = sorted(data)
            identifier = db.one('INSERT INTO logistique."T_Immobilisation" (' + ','.join(map(db.ident, fields))
                + ') VALUES (' + ','.join(['%s'] * len(fields)) + ') RETURNING ' + db.ident(KEY), [data[key] for key in fields])[KEY]
        else:
            fields = sorted(data)
            db.one('UPDATE logistique."T_Immobilisation" SET ' + ','.join(db.ident(key) + '=%s' for key in fields)
                + ' WHERE "ID_Immobilisation"=%s RETURNING "ID_Immobilisation"', [*[data[key] for key in fields], pk])
            identifier = pk
        row = record(actor, identifier)
        return row, {**rights(actor, row), 'replayed': False}, old is None


def history(actor, pk, raw=None):
    parent = record(actor, pk)
    raw = raw or {}
    if set(raw) - {'take', 'skip', 'sortBy', 'sortDir'}:
        fail('Critère non autorisé.')
    from apps.core.repository import page
    take, skip = page({'take': raw.get('take', 50), 'skip': raw.get('skip', 0)})
    take = min(take, 200)
    sort = raw.get('sortBy') or 'ChangedAt'
    direction = str(raw.get('sortDir', 'desc')).lower()
    sorts = {'ChangedAt': 'a."ChangedAt"', 'IdLog': 'a."IdLog"', 'Operation': 'a."Operation"',
        'Auteur': 'concat_ws(\' \',u."PrenomUser",u."NomUser")', 'motif': 'a."NewData"->>\'_motif\''}
    if sort not in sorts or direction not in {'asc', 'desc'}:
        fail('Tri de l’historique non autorisé.')
    params = [parent['IdEntiteFk'], str(parent[KEY]), str(parent[KEY])]
    predicate = '''a."TableName"='logistique.T_Immobilisation' AND a."IdEntiteFk"=%s
          AND (a."NewData"->>'ID_Immobilisation'=%s OR a."OldData"->>'ID_Immobilisation'=%s)'''
    count = db.one('SELECT count(*) n FROM systeme."T_Audit_Log" a WHERE ' + predicate, params)['n']
    def assignment(snapshot, alias):
        # Ces noms sont des constantes internes. Les anciennes affectations
        # restent lisibles après désaffectation sans exposer une autre entreprise
        # si le responsable ou le lieu a été transféré depuis cet événement.
        image = 'a.' + db.ident(snapshot)
        return ''' LEFT JOIN LATERAL (SELECT CASE WHEN ''' + image + ''' IS NULL THEN NULL ELSE jsonb_build_object(
          'responsable',CASE WHEN ''' + image + '''->>'ID_ResponsableFk' IS NULL THEN NULL
            ELSE COALESCE(NULLIF(concat_ws(' ',person."PrenomUser",person."NomUser"),''),'Libellé indisponible') END,
          'service',CASE WHEN ''' + image + '''->>'ID_ServiceFk' IS NULL THEN NULL ELSE COALESCE(service."NomGenerique",'Libellé indisponible') END,
          'etat',CASE WHEN ''' + image + '''->>'ID_EtatFk' IS NULL THEN NULL ELSE COALESCE(state."NomGenerique",'Libellé indisponible') END,
          'localisation',NULLIF(concat_ws(' · ',CASE WHEN ''' + image + '''->>'ID_LocalisationFk' IS NULL THEN NULL
            ELSE COALESCE(NULLIF(concat_ws(' · ',NULLIF(place."AdresseDetaillee",''),NULLIF(place."NomNiveau_5",''),NULLIF(place."NomNiveau_4",''),NULLIF(place."NomNiveau_3",'')),''),
              CASE WHEN place."IdEntiteLocalisation" IS NULL THEN 'Libellé indisponible' ELSE 'Localisation sans libellé' END) END,
            NULLIF(''' + image + '''->>'LocalisationComplement','')),'')) END AS data
          FROM (VALUES(1)) AS snapshot_anchor(n)
          LEFT JOIN systeme."T_Utilisateurs" person ON person."IdUser"::text=''' + image + '''->>'ID_ResponsableFk' AND person."IdEntiteFk"=a."IdEntiteFk"
          LEFT JOIN referentiel."T_Generique" service ON service."ID_Generique"::text=''' + image + '''->>'ID_ServiceFk'
          LEFT JOIN referentiel."T_Generique" state ON state."ID_Generique"::text=''' + image + '''->>'ID_EtatFk'
          LEFT JOIN systeme."V_Entite_Localisation_Detail" place ON place."IdEntiteLocalisation"::text=''' + image + '''->>'ID_LocalisationFk' AND place."IdEntite"=a."IdEntiteFk"
          ) ''' + alias + ' ON TRUE '
    rows = db.query('''SELECT a."IdLog",a."ChangedAt",a."Operation",a."OldData",a."NewData",
        before_assignment.data AS "AffectationAvant",after_assignment.data AS "AffectationApres",
        concat_ws(' ',u."PrenomUser",u."NomUser") AS "Auteur"
        FROM systeme."T_Audit_Log" a LEFT JOIN systeme."T_Utilisateurs" u
          ON u."IdUser"::text=COALESCE(a."NewData"->'_actor'->>'IdUser',a."OldData"->'_actor'->>'IdUser')'''
        + assignment('OldData', 'before_assignment') + assignment('NewData', 'after_assignment') + '''
        WHERE ''' + predicate + ' ORDER BY ' + sorts[sort] + ' ' + direction.upper()
        + ' NULLS LAST,a."IdLog" DESC LIMIT %s OFFSET %s', [*params, take, skip])
    return clean(rows), {'count': len(rows), 'totalCount': count, 'filteredCount': count, 'take': take, 'skip': skip, 'sortBy': sort, 'sortDir': direction}


class ImmobilisationsView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, pk=None):
        if pk is not None:
            if request.query_params:
                fail('Aucun critère attendu pour une fiche.')
            row = record(request.user, pk)
            return ok(clean(row), meta=rights(request.user, row))
        rows, meta = list_data(request.user, request.query_params.dict())
        return ok(rows, meta=meta)

    def post(self, request):
        row, meta, created = save(request.user, request.data)
        return ok(clean(row), meta=meta, status=201 if created else 200)

    def put(self, request, pk):
        row, meta, _ = save(request.user, request.data, pk)
        return ok(clean(row), meta=meta)

    patch = put

    def delete(self, request, pk):
        row, meta, _ = save(request.user, request.data, pk, archive=True)
        return ok(clean(row), meta=meta)


class ImmobilisationReferencesView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        if set(request.query_params) - {'immobilisationId'}:
            fail('Critère non autorisé.')
        current = record(request.user, positive(request.query_params['immobilisationId'])) if request.query_params.get('immobilisationId') else None
        return ok(references(request.user, current))


class ImmobilisationHistoryView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, pk):
        rows, meta = history(request.user, pk, request.query_params.dict())
        return ok(rows, meta=meta)


from .excel import ExcelDownloadView, CSVFileRenderer, XLSX_MEDIA_TYPE, register_workbook
from apps.core.responses import ExactJSONRenderer


class ImmobilisationExportView(ExcelDownloadView):
    renderer_classes = [ExactJSONRenderer, CSVFileRenderer, *ExcelDownloadView.renderer_classes[1:]]

    def get(self, request, file_format):
        stream, count, filename = register_workbook(request.user, 'immobilisations', request.query_params.dict(), file_format)
        response = FileResponse(stream, as_attachment=True, filename=filename,
            content_type='text/csv; charset=utf-8' if file_format == 'csv' else XLSX_MEDIA_TYPE)
        response['X-Export-Row-Count'] = str(count)
        response['Cache-Control'] = 'no-store, private'
        return response
