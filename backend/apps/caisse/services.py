"""Accès autorisés au socle SQL de caisse, sans recalcul de solde en Python.

Les écritures validées sont immuables. La validation, la compensation et les
clôtures utilisent les fonctions PostgreSQL sous le même verrou transactionnel.
"""
import hashlib
import hmac
import json
import re
import uuid
from datetime import date, datetime, time, timedelta
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import DatabaseError, transaction

from apps.core import db
from apps.core.field_references import reference_context, reference_options
from apps.core.module_access import access_snapshot, can_read_tab, can_use_tab, require_module, require_tab
from apps.core.reference_integration import entity_actor
from apps.core.repository import positive, set_admin_actor
from apps.core.responses import APIError, ExactEncoder
from apps.core.tenancy import read_entity, require_entity

ZONE = ZoneInfo('Africa/Kinshasa')
SOURCES = {
    'caisses': ('V_Caisse', 'T_Caisse', 'IdCaisse', 'CreeLe'),
    'ecritures': ('V_JournalCaisse', 'T_Paiement', 'IdPaiement', 'DatePaiement'),
    'clotures': ('V_ClotureCaisse', 'T_ClotureCaisse', 'ID_ClotureCaisse', 'ClotureLe'),
}
SENSITIVE = {'CreationRequestId', 'CreationPayloadHash', 'ValidationRequestId', 'ValidationPayloadHash'}
CASH_FIELDS = {'NomCaisse', 'IdDeviseFk', 'IdTypeCaisseFk', 'IdResponsableFk', 'Actif'}
ENTRY_FIELDS = {'IdCaisseFk', 'DatePaiement', 'LibellePaiement', 'ReferenceExterne', 'MontantPaiement',
                'SensMouvement', 'IdTypePaiementFk', 'IdTiersFk', 'ObsPaiement', 'ValidePaiement'}
FILTER_FIELDS = {
    'caisses': {'IdDeviseFk', 'Actif', 'IdResponsableFk'},
    'ecritures': {'IdCaisseFk', 'IdDeviseFk', 'SensMouvement', 'EtatEcriture', 'IdTiersFk', 'ValidePaiement'},
    'clotures': {'IdCaisseFk', 'IdDeviseFk'},
}


def fail(message, field=None, code='CAISSE_VALIDATION', status=422):
    raise APIError({field: message} if field else message, code, status)


def public(row, hidden):
    return {key: value for key, value in row.items() if key not in hidden}


def capabilities(actor):
    require_module(actor, 'caisse')
    snapshot = access_snapshot(actor)
    rights = snapshot['modules']['caisse']
    entity = read_entity(actor)
    active = db.one('SELECT "ValideEntite" active FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity]) if entity else None
    manage = bool(actor.admin and rights['canManage'] and entity and active and active['active'] is not False and not settings.DB_READ_ONLY)
    tabs = snapshot.get('tabs', {}).get('caisse', {})
    tab_rights = {key: {right: bool(rights[right] and tabs.get(key, rights)[right])
                        for right in ('canRead', 'canManage', 'canExport')}
                  for key in ('tableau-de-bord', *SOURCES)}
    return {'entityId': entity, 'platformAdmin': actor.global_admin, 'canRead': True,
            'canManage': manage, 'canExport': bool(rights['canExport']), 'readOnly': settings.DB_READ_ONLY,
            'tabs': {key: {**item, 'canManage': manage and item['canManage']} for key, item in tab_rights.items()},
            'hiddenFields': {kind: sorted(hidden_fields(actor, kind) - SENSITIVE) for kind in SOURCES},
            'hiddenExportFields': {kind: sorted(hidden_fields(actor, kind, 'export') - SENSITIVE) for kind in SOURCES},
            'policyReason': '' if manage else 'Choisissez une entreprise active pour enregistrer.' if actor.global_admin and not entity else 'Consultation uniquement.'}


def writable(actor, kind):
    require_tab(actor, 'caisse', kind, 'manage')
    db.ensure_writable()
    if not actor.admin:
        fail('Votre rôle ne permet pas la gestion de caisse.', code='CAISSE_FORBIDDEN', status=403)
    return require_entity(actor)


def scope(actor, alias='v'):
    entity = read_entity(actor)
    if entity is None and actor.global_admin:
        return 'TRUE', []
    if entity is None:
        fail('Votre compte doit être rattaché à une entreprise.', code='ENTITY_REQUIRED', status=403)
    return alias+'."IdEntiteFk"=%s', [entity]


def descriptor(kind):
    if kind not in SOURCES:
        fail('Registre inconnu.', code='NOT_FOUND', status=404)
    return SOURCES[kind]


def hidden_fields(actor, kind, action='read'):
    fields = SENSITIVE.copy()
    if kind == 'caisses':
        if not can_use_tab(actor, 'caisse', 'ecritures', action):
            fields.update({'NombreEcritures', 'NbBrouillons'})
        if not can_use_tab(actor, 'caisse', 'clotures', action):
            fields.add('DerniereClotureLe')
    elif kind == 'ecritures':
        if not can_use_tab(actor, 'logistique', 'tiers', action):
            fields.update({'IdTiersFk', 'NomTiers'})
        if not can_use_tab(actor, 'logistique', 'reglements', action):
            fields.add('IdReglementFk')
        if not can_use_tab(actor, 'logistique', 'factures', action):
            fields.add('CodeFactureFk')
    return fields


def linked_entry_text(actor, kind, action='read'):
    if kind != 'ecritures':
        return {}
    fields = {}
    if not can_use_tab(actor, 'logistique', 'factures', action):
        fields['LibellePaiement'] = 'Règlement'
    if not can_use_tab(actor, 'logistique', 'commandes', action):
        fields['ReferenceExterne'] = None
    return fields


def public_record(actor, kind, row, action='read'):
    result = public(row, hidden_fields(actor, kind, action))
    if row.get('IdReglementFk'):
        result.update(linked_entry_text(actor, kind, action))
    return result


def columns(kind, actor=None, action='read'):
    view = descriptor(kind)[0]
    hidden = hidden_fields(actor, kind, action) if actor is not None else SENSITIVE
    return {row['column_name']: row for row in db.query('''SELECT column_name,data_type
       FROM information_schema.columns WHERE table_schema='operations' AND table_name=%s ORDER BY ordinal_position''', [view])
       if row['column_name'] not in hidden}


def _scoped_record(actor, kind, pk, lock=False):
    view, table, key, _ = descriptor(kind)
    predicate, params = scope(actor)
    row = db.one('SELECT v.* FROM '+db.qualified('operations', table if lock else view)
        +' v WHERE '+predicate+' AND v.'+db.ident(key)+'=%s'+(' FOR UPDATE' if lock else ''), [*params, positive(pk)])
    if row is None:
        fail('Enregistrement introuvable dans cette entreprise.', code='NOT_FOUND', status=404)
    return row


def detail(actor, kind, pk, replayed=False):
    require_tab(actor, 'caisse', kind)
    row = _scoped_record(actor, kind, pk)
    rights = capabilities(actor)
    manage = rights['tabs'][kind]['canManage'] and rights['entityId'] == row['IdEntiteFk']
    active = kind == 'ecritures' and manage and _scoped_record(actor, 'caisses', row['IdCaisseFk'])['Actif']
    return {'record': public_record(actor, kind, row), '_version': str(row.get('Revision', '')),
        'canManage': bool(manage and (kind == 'caisses' or kind == 'ecritures' and row['EtatEcriture'] == 'DRAFT' and row['ValidePaiement'])),
        'canValidate': bool(manage and active and kind == 'ecritures' and row['EtatEcriture'] == 'DRAFT' and row['ValidePaiement']),
        'canReverse': bool(manage and active and kind == 'ecritures' and row['EtatEcriture'] == 'POSTED'
            and row['ValidePaiement'] and not row.get('IdPaiementOrigineFk') and not row.get('IdCompensateurFk') and not row.get('IdReglementFk')),
        'replayed': replayed}


def closure_preparation(actor, pk):
    writable(actor, 'clotures')
    row = _scoped_record(actor, 'caisses', pk)
    return {'record': {key: row[key] for key in ('IdCaisse', 'Actif', 'DeviseCode', 'SoldeTheorique')},
            '_version': str(row['Revision']), 'canManage': True}


def parse_date(raw, field, day_end=False):
    if not isinstance(raw, str) or len(raw) > 40:
        fail('Renseignez une date et une heure valides.', field)
    try:
        if re.fullmatch(r'\d{4}-\d{2}-\d{2}', raw):
            value = datetime.combine(date.fromisoformat(raw), time.min, ZONE)
            return value + timedelta(days=1) if day_end else value
        value = datetime.fromisoformat(raw.replace('Z', '+00:00'))
        return value.replace(tzinfo=ZONE) if value.tzinfo is None else value
    except (ValueError, OverflowError):
        fail('Renseignez une date et une heure valides.', field)


def money(raw, field='MontantPaiement', zero=False):
    if raw is None or isinstance(raw, (bool, float)):
        fail('Renseignez un montant exact, avec deux décimales au maximum.', field)
    try:
        value = Decimal(str(raw))
        if not value.is_finite() or value < 0 or not zero and value == 0 or value >= Decimal('10000000000000000') or value != value.quantize(Decimal('0.01')):
            raise ValueError()
        return value.quantize(Decimal('0.01'))
    except (ValueError, InvalidOperation):
        fail('Le montant doit être positif et comporter deux décimales au maximum.', field)


def text_value(raw, field, limit=255, required=False):
    if raw is None and not required:
        return None
    if not isinstance(raw, str) or len(raw.strip()) > limit or any(ord(c)<32 and c not in '\n\t\r' for c in raw):
        fail('Texte invalide ou trop long.', field)
    value = raw.strip()
    if required and not value:
        fail('Ce champ est obligatoire.', field)
    return value or None


def revision(raw, row):
    if not isinstance(raw, str) or not re.fullmatch(r'[1-9][0-9]*', raw) or not hmac.compare_digest(raw, str(row['Revision'])):
        fail('Cette fiche a changé. Rechargez-la avant d’enregistrer.', code='STALE_REVISION', status=409)
    return int(raw)


def envelope(actor, body, operation, pk=None, require_motif=False, batch_digest=None):
    if not isinstance(body, dict) or set(body)-{'data','requestId','motif','_version','valider'}:
        fail('Demande invalide.')
    try:
        request_id = str(uuid.UUID(str(body.get('requestId'))))
    except (ValueError, TypeError):
        fail('Identifiant de demande requis.', 'requestId')
    motif = text_value(body.get('motif'), 'motif', 1000, require_motif)
    content = {'actor': actor.pk, 'entity': read_entity(actor), 'operation': operation, 'id': pk, 'body': body}
    if batch_digest is not None:
        content['batch'] = batch_digest
    digest = hashlib.sha256(json.dumps(content, sort_keys=True, ensure_ascii=False, cls=ExactEncoder).encode()).hexdigest()
    return request_id, digest, motif


def request_lock(actor, request_id, digest, motif):
    db.query("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", ['caisse:'+str(actor.pk)+':'+request_id])
    set_admin_actor(actor)
    db.query("SELECT set_config('operations.request_id',%s,true),set_config('operations.payload_hash',%s,true),set_config('operations.motif',%s,true)", [request_id, digest, motif or ''])


def replay(kind, request_id, digest, column='CreationRequestId'):
    _, table, key, _ = descriptor(kind)
    hash_column = 'ValidationPayloadHash' if column == 'ValidationRequestId' else 'CreationPayloadHash'
    row = db.one('SELECT '+db.ident(key)+' id,'+db.ident(hash_column)+' hash FROM '+db.qualified('operations',table)+' WHERE '+db.ident(column)+'=%s', [request_id])
    if row:
        if row['hash'] != digest:
            fail('Cette demande a déjà été utilisée avec un autre contenu.', code='IDEMPOTENCY_CONFLICT', status=409)
        return row['id']
    return None


def update_replay(actor, kind, pk, request_id, digest):
    table = descriptor(kind)[1]
    row = db.one('''SELECT "NewData" proof FROM systeme."T_Audit_Log"
      WHERE "TableName"=%s AND "NewData"->>'_requestId'=%s
      ORDER BY "IdLog" DESC LIMIT 1''', ['operations.'+table,request_id])
    if not row:
        return False
    proof = row['proof']
    if proof.get('_payloadHash') != digest or str(proof.get(descriptor(kind)[2])) != str(pk):
        fail('Cette demande a déjà été utilisée avec un autre contenu.', code='IDEMPOTENCY_CONFLICT',status=409)
    return True


def validate_reference(actor, table, field, value, previous=None):
    if value is None:
        return
    if previous is not None and value == previous:
        return  # conserve une ancienne valeur, jamais une réattribution implicite
    choices = reference_options(actor, 'operations', table, field)
    if not any(choice['id'] == value and choice.get('active', True) and not choice.get('disabled') and not choice.get('incompatible') for choice in choices):
        fail('Choisissez une valeur active de la catégorie configurée.', field)


def cash_values(actor, data, old=None):
    if not isinstance(data, dict) or set(data)-CASH_FIELDS:
        fail('Champ de caisse non autorisé.')
    values = {}
    for field in CASH_FIELDS & data.keys():
        raw = data[field]
        if field == 'NomCaisse': values[field] = text_value(raw,field,160,True)
        elif field == 'Actif':
            if type(raw) is not bool: fail('Choisissez Oui ou Non.',field)
            values[field] = raw
        else: values[field] = None if raw in (None,'') and field != 'IdDeviseFk' else positive(raw,field)
    effective = {**(old or {}), **values}
    if not effective.get('NomCaisse') or not effective.get('IdDeviseFk'):
        fail('Le nom et la devise sont obligatoires.')
    if old and 'IdDeviseFk' in values and values['IdDeviseFk'] != old['IdDeviseFk']:
        fail('La devise d’une caisse ne peut plus être modifiée.', 'IdDeviseFk')
    for field in ('IdDeviseFk','IdTypeCaisseFk'):
        validate_reference(actor,'T_Caisse',field,effective.get(field),(old or {}).get(field))
    owner = effective.get('IdResponsableFk')
    if owner is not None and owner != (old or {}).get('IdResponsableFk'):
        eligible = db.one('SELECT "IdUser" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s AND "IdEntiteFk"=%s AND "ValideUser" IS TRUE',[owner,require_entity(actor)])
        if not eligible: fail('Choisissez un responsable actif de cette entreprise.','IdResponsableFk')
    return values


def entry_values(actor, data, old=None):
    if not isinstance(data,dict) or set(data)-ENTRY_FIELDS:
        fail('Champ d’écriture non autorisé.')
    values = {}
    for field in ENTRY_FIELDS & data.keys():
        raw = data[field]
        if field in {'LibellePaiement','ReferenceExterne','ObsPaiement'}:
            values[field] = text_value(raw,field,4000 if field == 'ObsPaiement' else 255,field=='LibellePaiement')
        elif field == 'MontantPaiement': values[field] = money(raw)
        elif field == 'DatePaiement': values[field] = parse_date(raw,field)
        elif field == 'SensMouvement':
            if type(raw) is bool or str(raw) not in {'1','-1'}: fail('Choisissez Entrée ou Sortie.',field)
            values[field] = int(raw)
        elif field == 'ValidePaiement':
            if type(raw) is not bool: fail('Choisissez un état valide.',field)
            values[field] = raw
        else: values[field] = None if raw in (None,'') and field!='IdCaisseFk' else positive(raw,field)
    effective = {**(old or {}),**values}
    for field in ('LibellePaiement','MontantPaiement','DatePaiement','IdCaisseFk','SensMouvement'):
        if effective.get(field) is None: fail('Ce champ est obligatoire.',field)
    cash = _scoped_record(actor,'caisses',effective['IdCaisseFk'],lock=True)
    if cash['IdEntiteFk'] != require_entity(actor): fail('Caisse hors entreprise.',code='ENTITY_MISMATCH',status=403)
    if not cash['Actif']: fail('Cette caisse est désactivée.',code='CAISSE_INACTIVE',status=409)
    if old and effective['IdCaisseFk'] != old['IdCaisseFk']: fail('La caisse du brouillon ne peut pas être modifiée.','IdCaisseFk')
    values['IdDeviseFk'] = cash['IdDeviseFk']
    validate_reference(actor,'T_Paiement','IdTypePaiementFk',effective.get('IdTypePaiementFk'),(old or {}).get('IdTypePaiementFk'))
    tiers = effective.get('IdTiersFk')
    if 'IdTiersFk' in values and not can_read_tab(actor, 'logistique', 'tiers'):
        if values['IdTiersFk'] is not None and values['IdTiersFk'] != (old or {}).get('IdTiersFk'):
            require_tab(actor, 'logistique', 'tiers')
        values.pop('IdTiersFk')
    if 'IdTiersFk' in values and tiers is not None and tiers != (old or {}).get('IdTiersFk'):
        if not db.one('SELECT "ID_Client" FROM logistique."T_Client" WHERE "ID_Client"=%s AND "IdEntiteFk"=%s AND "Actif" IS TRUE',[tiers,cash['IdEntiteFk']]):
            fail('Choisissez un tiers actif de cette entreprise.','IdTiersFk')
    return values


def insert(table, values, key):
    return db.one('INSERT INTO '+db.qualified('operations',table)+' ('+','.join(map(db.ident,values))+') VALUES ('+','.join(['%s']*len(values))+') RETURNING '+db.ident(key)+' id', list(values.values()))['id']


def update(table, key, pk, values):
    if values:
        db.query('UPDATE '+db.qualified('operations',table)+' SET '+','.join(db.ident(field)+'=%s' for field in values)+' WHERE '+db.ident(key)+'=%s', [*values.values(),pk])


@transaction.atomic
def create_cash(actor, body, *, batch_digest=None):
    entity = writable(actor, 'caisses')
    request_id,digest,motif = envelope(actor,body,'create-cash',batch_digest=batch_digest)
    request_lock(actor,request_id,digest,motif)
    found = replay('caisses',request_id,digest)
    if found: return detail(actor,'caisses',found,True)
    data = cash_values(entity_actor(actor,entity),body.get('data'))
    pk = insert('T_Caisse',{**data,'IdEntiteFk':entity,'CreationRequestId':request_id,'CreationPayloadHash':digest},'IdCaisse')
    return detail(actor,'caisses',pk)


@transaction.atomic
def modify(actor, kind, pk, body):
    entity = writable(actor, kind)
    if kind not in {'caisses','ecritures'}: fail('Modification non autorisée.',status=405)
    request_id,digest,motif = envelope(actor,body,'modify-'+kind,int(pk))
    request_lock(actor,request_id,digest,motif)
    old = _scoped_record(actor,kind,pk,lock=True)
    if old['IdEntiteFk'] != entity: fail('Entreprise différente.',status=403)
    if update_replay(actor,kind,pk,request_id,digest): return detail(actor,kind,pk,True)
    revision(body.get('_version'),old)
    if kind == 'ecritures' and old['EtatEcriture'] != 'DRAFT':
        fail('Une écriture validée se corrige par contrepassation.',code='POSTED_IMMUTABLE',status=409)
    values = cash_values(actor,body.get('data'),old) if kind=='caisses' else entry_values(actor,body.get('data'),old)
    _,table,key,_ = descriptor(kind)
    update(table,key,pk,values)
    return detail(actor,kind,pk)


@transaction.atomic
def create_entry(actor, body, *, batch_digest=None):
    entity = writable(actor, 'ecritures')
    request_id,digest,motif = envelope(actor,body,'create-entry',batch_digest=batch_digest)
    if type(body.get('valider',False)) is not bool: fail('Choisissez un mode d’enregistrement valide.','valider')
    request_lock(actor,request_id,digest,motif)
    found = replay('ecritures',request_id,digest)
    if found: return detail(actor,'ecritures',found,True)
    data = entry_values(actor,body.get('data'))
    pk = insert('T_Paiement',{**data,'IdEntiteFk':entity,'IdUserFk':actor.pk,'EtatEcriture':'DRAFT',
        'CreationRequestId':request_id,'CreationPayloadHash':digest},'IdPaiement')
    if body.get('valider'):
        old = _scoped_record(actor,'ecritures',pk,lock=True)
        sql_action('valider',pk,actor,motif or 'Validation lors de la création',request_id,digest,old['Revision'])
    return detail(actor,'ecritures',pk)


def sql_action(action, pk, actor, motif, request_id, digest, version):
    name = {'valider':'fn_caisse_valider','contrepasser':'fn_caisse_contrepasser'}[action]
    return db.one('SELECT operations.'+name+'(%s,%s,%s,%s::uuid,%s,%s) id',[pk,actor.pk,motif,request_id,digest,version])['id']


@transaction.atomic
def entry_action(actor, pk, action, body):
    entity = writable(actor, 'ecritures')
    request_id,digest,motif = envelope(actor,body,action,int(pk),True)
    request_lock(actor,request_id,digest,motif)
    old = _scoped_record(actor,'ecritures',pk,lock=True)
    if old['IdEntiteFk'] != entity: fail('Entreprise différente.',status=403)
    found = replay('ecritures',request_id,digest,'ValidationRequestId' if action=='valider' else 'CreationRequestId')
    if found: return detail(actor,'ecritures',found,True)
    version = revision(body.get('_version'),old)
    return detail(actor,'ecritures',sql_action(action,int(pk),actor,motif,request_id,digest,version))


@transaction.atomic
def close_cash(actor, body, *, batch_digest=None):
    entity = writable(actor, 'clotures')
    request_id,digest,motif = envelope(actor,body,'close-cash',batch_digest=batch_digest)
    request_lock(actor,request_id,digest,motif)
    found = replay('clotures',request_id,digest)
    if found: return detail(actor,'clotures',found,True)
    data = body.get('data')
    if not isinstance(data,dict) or set(data)!={'IdCaisseFk','ClotureLe','MontantCompte'}: fail('Complétez les informations de clôture.')
    cash = _scoped_record(actor,'caisses',positive(data['IdCaisseFk']),lock=True)
    if cash['IdEntiteFk'] != entity: fail('Entreprise différente.',status=403)
    version = revision(body.get('_version'),cash)
    pk = db.one('SELECT operations.fn_caisse_cloturer(%s,%s,%s,%s,%s,%s::uuid,%s,%s) id',[
        cash['IdCaisse'],actor.pk,parse_date(data['ClotureLe'],'ClotureLe'),money(data['MontantCompte'],'MontantCompte',True),motif,request_id,digest,version])['id']
    return detail(actor,'clotures',pk)


def read_source(actor, kind, raw, export=False):
    require_tab(actor,'caisse',kind,'export' if export else 'read')
    allowed = {'q','page','take','sort','direction','filters'} | ({'columns','selection'} if export else set())
    if set(raw)-allowed: fail('Critère de lecture non autorisé.')
    view,_,key,date_field = descriptor(kind)
    action = 'export' if export else 'read'
    available = columns(kind, actor, action)
    predicate,params = scope(actor)
    filters = raw.get('filters',{})
    try: filters = json.loads(filters) if isinstance(filters,str) else filters
    except (TypeError,ValueError): fail('Filtres invalides.')
    if not isinstance(filters,dict) or set(filters)-(FILTER_FIELDS[kind]|{'dateMin','dateMax'}): fail('Filtre non autorisé.')
    clauses = [predicate]
    for field,value in filters.items():
        if value in (None,'','all'): continue
        if field in {'dateMin','dateMax'}:
            clauses.append('v.'+db.ident(date_field)+('>=%s' if field=='dateMin' else '<%s' if re.fullmatch(r'\d{4}-\d{2}-\d{2}',str(value)) else '<=%s'))
            params.append(parse_date(value,field,field=='dateMax'))
        else:
            if field not in available:
                fail('Ce filtre nécessite l’accès au registre lié.', code='TAB_ACTION_FORBIDDEN', status=403)
            if field in {'Actif','ValidePaiement'}:
                if value in ('true','false'): value = value=='true'
                if type(value) is not bool: fail('État invalide.',field)
            elif field=='EtatEcriture':
                if value not in {'DRAFT','POSTED'}: fail('État invalide.',field)
            elif field=='SensMouvement':
                if type(value) is bool or str(value) not in {'-1','1'}: fail('Sens invalide.',field)
                value = int(value)
            else: value = positive(value,field)
            clauses.append('v.'+db.ident(field)+'=%s'); params.append(value)
    q = str(raw.get('q','')).strip()
    if len(q)>500: fail('Recherche trop longue.')
    masked_text = linked_entry_text(actor, kind, action)

    def visible_column(field):
        column = 'v.'+db.ident(field)
        if field in masked_text:
            # Les deux textes synthétiques sont dérivés de la facture et du bon.
            replacement = "'Règlement'" if masked_text[field] else 'NULL'
            return 'CASE WHEN v."IdReglementFk" IS NULL THEN '+column+' ELSE '+replacement+' END'
        return column

    search = [field for field,col in available.items() if col['data_type'] in {'text','character varying'}]
    if q and search:
        clauses.append('('+' OR '.join(visible_column(field)+' ILIKE %s' for field in search)+')')
        params += ['%'+q.replace('\\','\\\\').replace('%','\\%').replace('_','\\_')+'%']*len(search)
    sort = raw.get('sort') or date_field
    direction = str(raw.get('direction','desc')).upper()
    if sort not in available or direction not in {'ASC','DESC'}: fail('Tri non autorisé.')
    order = visible_column(sort)+' '+direction+' NULLS LAST'+(',v.'+db.ident(key)+' '+direction if sort!=key else '')
    return view,key,available,' AND '.join(clauses),params,order,filters


def list_data(actor,kind,raw):
    view,key,available,where,params,order,_ = read_source(actor,kind,raw)
    take = positive(raw.get('take',25),'Nombre de lignes')
    page = positive(raw.get('page',1),'Page')
    if take>200: fail('Choisissez au maximum 200 lignes par page.')
    source = db.qualified('operations',view)
    total = db.one('SELECT count(*) n FROM '+source+' v WHERE '+where,params)['n']
    rows = db.query('SELECT v.* FROM '+source+' v WHERE '+where+' ORDER BY '+order+' LIMIT %s OFFSET %s',[*params,take,(page-1)*take])
    records = [public_record(actor, kind, row) for row in rows]
    if kind == 'ecritures':
        for row, record in zip(rows, records):
            record['ContrepassationAutorisee'] = not bool(row.get('IdReglementFk'))
    return {'rows':records,'total':total,'page':page,'take':take}


def references(actor):
    rights = capabilities(actor)['tabs']
    cash = rights['caisses']['canRead']
    entries = rights['ecritures']['canRead']
    closures = rights['clotures']['canRead']
    result,meta = {},{}
    fields = [('devises','T_Caisse','IdDeviseFk')]
    if cash:
        fields.append(('typesCaisses','T_Caisse','IdTypeCaisseFk'))
    if entries:
        fields.append(('typesPaiements','T_Paiement','IdTypePaiementFk'))
    for key,table,field in fields:
        result[key] = reference_options(actor,'operations',table,field)
        meta[key] = reference_context(actor,'operations',table,field)
    predicate,params = scope(actor)
    # Le sélecteur a besoin de l’identité de la caisse et de sa devise.
    # Un comptage requiert aussi un solde et une révision pour chaque caisse.
    balances = ',v."SoldeTheorique",v."Revision"::text "_version"' if rights['clotures']['canManage'] else ''
    result['caisses'] = db.query(
        'SELECT v."IdCaisse",v."IdDeviseFk",v."CodeCaisse",v."NomCaisse",v."DeviseCode",v."Actif"'+balances+
        ' FROM operations."V_Caisse" v WHERE '+predicate+' ORDER BY v."NomCaisse",v."IdCaisse"',params
    ) if entries or closures else []
    result['responsables'] = db.query('SELECT "IdUser" id,concat_ws(\' \',"PrenomUser","NomUser") label FROM systeme."T_Utilisateurs" v WHERE '+predicate+' AND "ValideUser" IS TRUE ORDER BY label',params) if cash else []
    result['tiers'] = db.query('SELECT "ID_Client" id,"Nom" label FROM logistique."T_Client" v WHERE '+predicate+' AND "Actif" IS TRUE ORDER BY label',params) if entries and can_read_tab(actor, 'logistique', 'tiers') else []
    result['referenceMeta'] = meta
    return result


def entities(actor):
    require_module(actor,'caisse')
    return db.query('SELECT "IdEntite" id,"NomEntite" label,"ValideEntite" active FROM systeme."T_Entite" WHERE '+('TRUE' if actor.global_admin else '"IdEntite"=%s')+' ORDER BY lower("NomEntite"),"IdEntite"',[] if actor.global_admin else [actor.organisation])


def synthesis(actor,raw):
    require_tab(actor, 'caisse', 'tableau-de-bord')
    read_cash = can_read_tab(actor, 'caisse', 'caisses')
    read_entries = can_read_tab(actor, 'caisse', 'ecritures')
    # Le solde est toujours la position actuelle ; la période concerne les flux.
    if set(raw)-{'q','filters'}: fail('Critère de synthèse non autorisé.')
    flow, dates, balances = [], [], []
    if read_entries:
        _,_,_,where,params,_,filters = read_source(actor,'ecritures',raw)
        # L'identité de devise agrège les montants ; le code historique reste
        # conservé dans le journal sans fragmenter les totaux après un renommage.
        flow = db.query('''SELECT v."IdDeviseFk",coalesce(nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",g."NomGenerique"::text "DeviseLibelle",
          COALESCE(sum(v."MontantPaiement") FILTER(WHERE v."SensMouvement"=1 AND v."EtatEcriture"='POSTED'),0) "Entrees",
          COALESCE(sum(v."MontantPaiement") FILTER(WHERE v."SensMouvement"=-1 AND v."EtatEcriture"='POSTED'),0) "Sorties",
          count(*) FILTER(WHERE v."EtatEcriture"='POSTED') "NombreEcritures",
          count(*) FILTER(WHERE v."EtatEcriture"='DRAFT') "NombreBrouillons"
          FROM operations."V_JournalCaisse" v JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."IdDeviseFk" WHERE '''+where+''' AND v."ValidePaiement" IS TRUE
          GROUP BY v."IdDeviseFk",g."ID_Generique"''',params)
        dates = db.query('''SELECT (v."DatePaiement" AT TIME ZONE 'Africa/Kinshasa')::date "DateJour",v."IdDeviseFk",coalesce(nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",
          COALESCE(sum(v."MontantPaiement") FILTER(WHERE v."SensMouvement"=1),0) "Entrees",
          COALESCE(sum(v."MontantPaiement") FILTER(WHERE v."SensMouvement"=-1),0) "Sorties",sum(v."MontantSigne") "Net"
          FROM operations."V_JournalCaisse" v JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."IdDeviseFk" WHERE '''+where+''' AND v."EtatEcriture"='POSTED' AND v."ValidePaiement" IS TRUE
          GROUP BY 1,2,3 ORDER BY 1,2''',params)
    else:
        try:
            filters = raw.get('filters') or {}
            if isinstance(filters, str):
                filters = json.loads(filters)
        except (TypeError, ValueError):
            fail('Filtres invalides.')
        if not isinstance(filters, dict) or raw.get('q') or set(filters) - {'IdDeviseFk'}:
            fail('Ces filtres nécessitent l’accès au journal de caisse.', code='TAB_ACTION_FORBIDDEN', status=403)
    if read_cash:
        cash_filters = {field: value for field, value in filters.items() if field == 'IdDeviseFk'}
        _,_,_,cash_where,cash_params,_,_ = read_source(actor,'caisses',{'filters':cash_filters})
        if filters.get('IdCaisseFk'):
            cash_where += ' AND v."IdCaisse"=%s'; cash_params.append(positive(filters['IdCaisseFk']))
        balances = db.query('''SELECT v."IdDeviseFk",v."DeviseCode",v."DeviseLibelle",sum(v."SoldeTheorique") "Solde",
            count(*) "NombreCaisses" FROM operations."V_Caisse" v WHERE '''+cash_where+''' GROUP BY v."IdDeviseFk",v."DeviseCode",v."DeviseLibelle"''',cash_params)
    by_id = {row['IdDeviseFk']: {**row} for row in balances}
    if read_entries:
        for row in by_id.values():
            row.update(Entrees=Decimal(0), Sorties=Decimal(0), NombreEcritures=0, NombreBrouillons=0)
    for row in flow:
        balance = {'Solde': Decimal(0), 'NombreCaisses': 0} if read_cash else {}
        by_id.setdefault(row['IdDeviseFk'], balance).update(row)
    return {'totals': sorted(by_id.values(), key=lambda row: row['DeviseCode'] or ''), 'flux': dates}


@transaction.atomic
def record_reglement(actor,caisse_id,reglement_row,parent_row,request_id):
    """Enregistre l’encaissement optionnel d’un règlement déjà inséré, sans le dupliquer."""
    entity = writable(actor, 'ecritures')
    cash = _scoped_record(actor,'caisses',positive(caisse_id),lock=True)
    if cash['IdEntiteFk'] != entity or parent_row['IdEntiteFk'] != entity or cash['IdDeviseFk'] != parent_row['ID_DeviseFk']:
        fail('Choisissez une caisse de cette entreprise dans la devise de la facture.',code='CAISSE_CURRENCY_MISMATCH',status=409)
    if not cash['Actif']: fail('Cette caisse est désactivée.',status=409)
    request_id = str(uuid.uuid5(uuid.UUID(str(request_id)),'caisse'))
    source = {'actor':actor.pk,'caisse':cash['IdCaisse'],'reglement':reglement_row,'document':parent_row}
    digest = hashlib.sha256(json.dumps(source,sort_keys=True,cls=ExactEncoder).encode()).hexdigest()
    request_lock(actor,request_id,digest,'Encaissement du règlement')
    found = replay('ecritures',request_id,digest)
    if found: return public_record(actor, 'ecritures', _scoped_record(actor, 'ecritures', found))
    value = reglement_row['DateReglement']
    if value.tzinfo is None: value = value.replace(tzinfo=ZONE)
    pk = insert('T_Paiement',{'IdCaisseFk':cash['IdCaisse'],'IdEntiteFk':entity,'IdDeviseFk':cash['IdDeviseFk'],
        'IdUserFk':actor.pk,'LibellePaiement':'Règlement '+str(parent_row.get('CodeFacture') or ''),
        'ReferenceExterne':parent_row.get('CodeCmd'),'DatePaiement':value,
        'MontantPaiement':money(reglement_row['MontantRegle']),'SensMouvement':1,'EtatEcriture':'POSTED',
        'IdTiersFk':reglement_row.get('ID_TiersFk'),'IdReglementFk':reglement_row['ID_Reglement'],
        'CreationRequestId':request_id,'CreationPayloadHash':digest,
        'IdValidateurFk':actor.pk,'ValidationRequestId':request_id,'ValidationPayloadHash':digest},'IdPaiement')
    return public_record(actor, 'ecritures', _scoped_record(actor, 'ecritures', pk))
