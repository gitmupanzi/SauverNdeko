"""Support : périmètres, formulaires et opérations atomiques sur les vues PostgreSQL.

Les statuts et leurs transitions sont conservés dans le circuit figé du dossier.
Les déclencheurs contrôlent les invariants et écrivent l'audit commun ; ce service
ajoute l'autorisation, la révision et le rejeu vérifié de chaque demande HTTP.
"""
import hashlib
import json
import re
import uuid
from datetime import date, datetime, time, timedelta
from pathlib import Path
from tempfile import SpooledTemporaryFile

from django.conf import settings
from django.db import DatabaseError, connection, transaction
from django.http import FileResponse
from django.utils import timezone
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.views import APIView

from apps.core import db
from apps.core.field_references import document_reference_actor, reference_context, reference_options
from apps.core.module_access import access_snapshot, require_module
from apps.core.permissions import HasModuleAccess
from apps.core.repository import clean, page, set_admin_actor
from apps.core.responses import APIError, ExactEncoder, ExactJSONRenderer, ok
from apps.core.tenancy import read_entity, require_entity
from apps.logistique.documents import (DocumentDownloadView, binary_response, filename,
                                       validate_upload)
from apps.logistique.excel import CSVFileRenderer, ExcelDownloadView, MAX_EXPORT_ROWS, XLSX_MEDIA_TYPE
from apps.logistique.table_queries import document_zone

LABELS = {
    'ID_Support': 'Identifiant du dossier', 'IdEntiteFk': 'Identifiant entreprise',
    'NumeroSupport': 'N° dossier', 'Objet': 'Objet', 'Description': 'Description',
    'Entreprise': 'Entreprise', 'Demandeur': 'Demandeur', 'Createur': 'Créé par',
    'Responsable': 'Responsable', 'ServiceConcerne': 'Service concerné',
    'TypeSupport': 'Type', 'CategorieSupport': 'Catégorie', 'Priorite': 'Priorité',
    'Statut': 'Statut', 'StatutCode': 'Étape du circuit', 'CanalOrigine': 'Canal',
    'DateCreation': 'Créé le', 'DateModification': 'Modifié le',
    'DateEcheance': 'Échéance', 'DateResolution': 'Résolu le', 'DateCloture': 'Clôturé le',
    'VersionEnregistrement': 'Révision', 'Archive': 'Archivé',
    'ID_DemandeurFk': 'Identifiant demandeur', 'ID_CreateurFk': 'Identifiant créateur',
    'ID_ResponsableFk': 'Identifiant responsable', 'ID_ServiceConcerneFk': 'Identifiant service',
    'ID_TypeSupportFk': 'Identifiant type', 'ID_CategorieSupportFk': 'Identifiant catégorie',
    'ID_PrioriteFk': 'Identifiant priorité', 'ID_StatutFk': 'Identifiant statut',
    'ID_CanalOrigineFk': 'Identifiant canal', 'ID_ImmobilisationFk': 'Identifiant immobilisation',
    'ID_CommandeFk': 'Identifiant bon', 'ID_ArticleFk': 'Identifiant article',
    'Immobilisation': 'Immobilisation', 'BonStock': 'Bon de stock', 'Article': 'Article',
    'EnRetard': 'En retard',
    'CodeImmobilisation':'Code d’inventaire',
    'NbResolutions':'Résolutions proposées',
}
DEFAULTS = ['NumeroSupport', 'Objet', 'Demandeur', 'Responsable', 'Priorite', 'Statut',
            'DateCreation', 'DateEcheance']
REFERENCE_FIELDS = {
    'ID_TypeSupportFk': 'types', 'ID_CategorieSupportFk': 'categories',
    'ID_PrioriteFk': 'priorities', 'ID_StatutFk': 'statuses',
    'ID_CanalOrigineFk': 'channels', 'ID_ServiceConcerneFk': 'services',
}
EDIT_FIELDS = {'Objet', 'Description', 'ID_DemandeurFk', 'ID_ResponsableFk',
               'ID_ServiceConcerneFk', 'ID_TypeSupportFk', 'ID_CategorieSupportFk',
               'ID_PrioriteFk', 'ID_CanalOrigineFk', 'DateEcheance',
               'ID_ImmobilisationFk', 'ID_CommandeFk', 'ID_ArticleFk'}
FILTERS = {'IdEntiteFk', 'ID_DemandeurFk', 'ID_CreateurFk', 'ID_ResponsableFk',
           *REFERENCE_FIELDS, 'Archive', 'ID_ImmobilisationFk', 'ID_CommandeFk', 'ID_ArticleFk'}
READ_KEYS = {'q', 'take', 'skip', 'sortBy', 'sortDir', 'filters', 'dateFrom', 'dateTo',
             'indicator', 'columns', 'selection', 'timeZone', 'archive'}
ACTION_LABELS = {'start': 'Prendre en charge', 'pause': 'Mettre en attente',
                 'resume': 'Reprendre le traitement', 'resolve': 'Proposer une résolution',
                 'verify': 'Vérifier la résolution', 'close': 'Clôturer le dossier',
                 'reopen': 'Rouvrir le dossier', 'archive': 'Archiver', 'restore': 'Restaurer'}


def identifier(value, label='Identifiant'):
    if type(value) is bool or not re.fullmatch(r'[1-9][0-9]*', str(value)):
        raise APIError(label+' invalide.', 'SUPPORT_VALIDATION', 422)
    value = int(value)
    if value > 9223372036854775807:
        raise APIError(label+' hors limites.', 'SUPPORT_VALIDATION', 422)
    return value


def capabilities(actor):
    require_module(actor, 'support')
    rights = access_snapshot(actor)['modules']['support']
    manage = bool(rights['canManage'] and actor.admin)
    writable = bool(manage and not settings.DB_READ_ONLY and read_entity(actor))
    return {'canCreate': writable, 'canManage': writable, 'canVerify': writable,
            'canReadInternal': manage, 'canExport': bool(rights['canExport']),
            'entityId': read_entity(actor), 'platformAdmin': actor.global_admin,
            'readOnly': settings.DB_READ_ONLY}


def scope(actor, alias='v'):
    require_module(actor, 'support')
    entity = read_entity(actor)
    if actor.global_admin and entity is None:
        return 'TRUE', []
    if not entity:
        raise APIError('Une entreprise est requise.', 'ORGANISATION_REQUIRED', 403)
    return alias+'."IdEntiteFk"=%s', [entity]


def table_source(actor=None):
    if actor is not None:
        require_module(actor, 'support')
    columns = db.query("SELECT column_name,data_type,is_nullable,character_maximum_length,"
                       "numeric_precision,numeric_scale FROM information_schema.columns "
                       "WHERE table_schema='support' AND table_name='V_Support' ORDER BY ordinal_position")
    if not columns:
        raise APIError('Le module Support doit être installé.', 'SUPPORT_NOT_INSTALLED', 503)
    # Le circuit constitue un contrôle métier, jamais une colonne exportable.
    columns = [column for column in columns if column['column_name'] in LABELS]
    return {'schema': 'support', 'name': 'V_Support', 'columns': columns,
            'primaryKey': ['ID_Support'], 'relations': []}


def selection(actor, raw, action='read'):
    require_module(actor, 'support', action)
    if set(raw)-READ_KEYS:
        raise APIError('Critère Support non autorisé.')
    where, params = scope(actor)
    try:
        filters = json.loads(raw['filters']) if isinstance(raw.get('filters'), str) else dict(raw.get('filters') or {})
    except (ValueError, TypeError):
        raise APIError('Filtres invalides.')
    if not isinstance(filters, dict) or set(filters)-FILTERS:
        raise APIError('Filtre Support non autorisé.')
    clauses = [where]
    if raw.get('archive') not in (None,'','all','true','false'):raise APIError('Filtre d’archive invalide.')
    if raw.get('archive') in {'true','false'}:filters['Archive']=raw['archive']=='true'
    if 'Archive' not in filters and raw.get('archive')!='all':
        clauses.append('NOT v."Archive"')
    for key, value in filters.items():
        if value is None:
            clauses.append('v.'+db.ident(key)+' IS NULL')
        elif key == 'Archive':
            if type(value) is not bool:
                raise APIError('Le filtre d’archive doit être booléen.')
            clauses.append('v."Archive"=%s'); params.append(value)
        else:
            clauses.append('v.'+db.ident(key)+'=%s'); params.append(identifier(value))
    q = str(raw.get('q') or '').strip()
    if len(q)>300:
        raise APIError('Recherche trop longue.')
    if q:
        fields = ['NumeroSupport', 'Objet', 'Description', 'Demandeur', 'Responsable', 'Entreprise']
        clauses.append('('+' OR '.join('v.'+db.ident(key)+' ILIKE %s' for key in fields)+')')
        params.extend(['%'+q+'%']*len(fields))
    for key, operator in [('dateFrom', '>='), ('dateTo', '<')]:
        if raw.get(key):
            try:
                value = date.fromisoformat(raw[key])
                if key=='dateTo': value += timedelta(days=1)
            except (TypeError, ValueError, OverflowError):
                raise APIError('Période invalide.')
            clauses.append('v."DateCreation"'+operator+'%s'); params.append(timezone.make_aware(datetime.combine(value,time.min)))
    indicator = raw.get('indicator')
    indicators = {'ouverts': 'v."StatutCode" NOT IN (\'resolved\',\'closed\')',
                  'attente': 'v."StatutCode"=\'pending\'', 'enAttente': 'v."StatutCode"=\'pending\'',
                  'retard': 'v."DateEcheance"<statement_timestamp() AND v."StatutCode" NOT IN (\'resolved\',\'closed\')',
                  'enRetard': 'v."DateEcheance"<statement_timestamp() AND v."StatutCode" NOT IN (\'resolved\',\'closed\')',
                  'resolus': 'v."StatutCode"=\'resolved\'', 'clotures': 'v."StatutCode"=\'closed\''}
    if indicator:
        if indicator not in indicators: raise APIError('Indicateur inconnu.')
        clauses.append(indicators[indicator])
    obj = table_source(actor)
    columns = {column['column_name'] for column in obj['columns']}
    sort = raw.get('sortBy') or 'DateCreation'
    direction = str(raw.get('sortDir') or 'desc').lower()
    if sort not in columns or direction not in {'asc','desc'}:
        raise APIError('Tri Support non autorisé.')
    order = 'v.'+db.ident(sort)+' '+direction.upper()+' NULLS LAST'+(',v."ID_Support" DESC' if sort!='ID_Support' else '')
    return obj, ' AND '.join(clauses), params, order, sort, direction


def list_records(actor, raw):
    obj, where, params, order, sort, direction = selection(actor, raw)
    take, skip = page(raw)
    rows = db.query('SELECT v.* FROM support."V_Support" v WHERE '+where+' ORDER BY '+order+' LIMIT %s OFFSET %s', [*params,take,skip])
    count = db.one('SELECT count(*) n FROM support."V_Support" v WHERE '+where,params)['n']
    total_where,total_values=scope(actor)
    total=db.one('SELECT count(*) n FROM support."V_Support" v WHERE '+total_where+' AND NOT v."Archive"',total_values)['n']
    rows=[public_record(row) for row in rows]
    return clean(rows), {'totalCount':total,'filteredCount':count,'count':len(rows),'take':take,'skip':skip,
        'sortBy':sort,'sortDir':direction,'pk':'ID_Support',
        'columns':[{'key':c['column_name'],'column_name':c['column_name'],'data_type':c['data_type'],'label':LABELS[c['column_name']]} for c in obj['columns']],**capabilities(actor)}


def public_record(row):
    # Les comptes bruts de la vue incluent aussi les notes et pièces internes.
    # Ne pas en révéler l'existence dans une projection commune/exportable.
    return {**{key:value for key,value in row.items() if key not in {'CircuitSnapshot','NbCommentaires','NbDocuments'}},
            '_version':str(row['VersionEnregistrement'])}


def record(actor, pk, lock=False):
    where,params=scope(actor,'s'); pk=identifier(pk)
    row=db.one('SELECT s.* FROM support."T_Support" s WHERE s."ID_Support"=%s AND '+where+(' FOR UPDATE OF s' if lock else ''),[pk,*params])
    if row is None: raise APIError('Dossier introuvable.','NOT_FOUND',404)
    return row


def _option_rows(actor, table, pk, label, *, current=None, active=None):
    entity=read_entity(actor)
    condition='TRUE' if actor.global_admin and entity is None else '"IdEntiteFk"=%s'
    values=[] if condition=='TRUE' else [entity]
    if active: condition+=' AND ('+db.ident(active)+' IS TRUE'+(' OR '+db.ident(pk)+'=%s' if current else '')+')';values.extend([current] if current else [])
    return db.query('SELECT '+db.ident(pk)+' AS id,'+label+' AS label'+(','+db.ident(active)+' IS NOT TRUE AS disabled' if active else '')+' FROM '+table+' WHERE '+condition+' ORDER BY lower('+label+'),'+db.ident(pk),values)


def references(actor, current=None):
    from apps.core.reference_labels import reference_label_sql
    require_module(actor,'support')
    selected=current or {}
    scoped=document_reference_actor(actor,selected['IdEntiteFk']) if selected else actor
    choices={};fields={}
    for key,alias in REFERENCE_FIELDS.items():
        context=reference_context(scoped,'support','T_Support',key)
        options=reference_options(scoped,'support','T_Support',key,selected.get(key))
        choices[alias]=options;fields[key]={**context,'options':options}
    resolution_context=reference_context(scoped,'support','T_ResolutionSupport','ID_ResultatVerificationFk')
    choices['resultats']=reference_options(scoped,'support','T_ResolutionSupport','ID_ResultatVerificationFk')
    if selected:
        # Le circuit capturé reste utilisable même après remplacement de sa
        # famille dans les réglages. Les autres champs suivent les choix actuels.
        ids=list(selected['CircuitSnapshot']['verification'].values())
        choices['resultats']=db.query('SELECT "ID_Generique" AS id,'+reference_label_sql()+' AS label,"AbrGenerique" AS abbr FROM referentiel."T_Generique" WHERE "ID_Generique"=ANY(%s::integer[]) AND referentiel.fn_reference_visible("ID_Generique",%s) ORDER BY "ID_Generique"',[ids,selected['IdEntiteFk']])
    fields['ID_ResultatVerificationFk']={**resolution_context,'options':choices['resultats']}
    users=_option_rows(scoped,'systeme."T_Utilisateurs"','IdUser',"concat_ws(' ',\"PrenomUser\",\"NomUser\")",current=selected.get('ID_ResponsableFk'),active='ValideUser')
    # Le compte global qui réalise le traitement peut être affecté explicitement.
    if scoped.global_admin and not any(user['id']==actor.pk for user in users):
        users.insert(0,{'id':actor.pk,'label':' '.join(str(actor.row.get(key) or '') for key in ('PrenomUser','NomUser')).strip(),'disabled':False})
    requesters=_option_rows(scoped,'logistique."T_Client"','ID_Client','"Nom"',current=selected.get('ID_DemandeurFk'),active='Actif')
    links={'articles':_option_rows(scoped,'logistique."T_Article"','ID_Article','"NomArticle"',current=selected.get('ID_ArticleFk'),active='ValideArticle'),
           'bons':_option_rows(scoped,'logistique."T_Commande"','ID_Commande','COALESCE("CodeCmd",\'Bon sans code\')'),
           'immobilisations':_option_rows(scoped,'logistique."T_Immobilisation"','ID_Immobilisation','"CodeImmobilisation"||\' · \'||"NomImmobilisation"',current=selected.get('ID_ImmobilisationFk'),active='Actif')}
    defaults={}
    for field,alias,code in [('ID_TypeSupportFk','types','support.type.assistance'),('ID_PrioriteFk','priorities','support.priority.normal'),('ID_CanalOrigineFk','channels','support.channel.app'),('ID_CategorieSupportFk','categories','support.category.general')]:
        value=next((item['id'] for item in choices[alias] if item.get('abbr')==code and not item.get('disabled')),None)
        if value is not None:defaults[field]=value
    return {'references':choices,'fieldReferences':fields,'users':users,'requesters':requesters,'links':links,
            'requiredFields':['Objet','Description','ID_TypeSupportFk','ID_PrioriteFk','ID_CanalOrigineFk'],
            'defaults':defaults,**capabilities(actor)}


def transition_options(actor, row):
    if not capabilities(actor)['canManage']: return []
    if row['Archive']:return [{'key':'restore','label':ACTION_LABELS['restore'],'requiresReason':True,'requiresResolution':False,'requiresVerification':False}]
    circuit=row['CircuitSnapshot'];current=next((key for key,value in circuit['states'].items() if value==row['ID_StatutFk']),None)
    actions=[edge['action'] for edge in circuit['transitions'] if edge.get('from')==current and edge.get('action') in ACTION_LABELS]
    latest=db.one('SELECT "ID_ResultatVerificationFk","ID_ProposeParFk" FROM support."T_ResolutionSupport" WHERE "ID_SupportFk"=%s ORDER BY "ID_ResolutionSupport" DESC LIMIT 1',[row['ID_Support']]) if current=='resolved' else None
    if current=='resolved' and latest:
        if latest['ID_ResultatVerificationFk'] is None:
            if latest['ID_ProposeParFk']!=actor.pk:actions.append('verify')
            actions=[key for key in actions if key!='close']
        elif latest['ID_ResultatVerificationFk']!=circuit['verification']['accepted']:
            actions=[key for key in actions if key!='close']
    if current=='closed':actions.append('archive')
    return [{'key':key,'label':ACTION_LABELS[key],'requiresReason':key in {'pause','reopen','archive','restore'},
             'requiresResolution':key=='resolve','requiresVerification':key=='verify'} for key in actions]


def detail(actor, pk):
    row=record(actor,pk); view=db.one('SELECT * FROM support."V_Support" WHERE "ID_Support"=%s',[row['ID_Support']]);row=view
    internal=capabilities(actor)['canReadInternal']
    restriction='' if internal else ' AND "Visibilite"=\'public\''
    comments=db.query('SELECT * FROM support."V_CommentaireSupport" WHERE "ID_SupportFk"=%s'+restriction+' ORDER BY "DateCreation","ID_CommentaireSupport"',[row['ID_Support']])
    resolutions=db.query('SELECT * FROM support."V_ResolutionSupport" WHERE "ID_SupportFk"=%s ORDER BY "DateProposition" DESC,"ID_ResolutionSupport" DESC',[row['ID_Support']])
    documents=db.query('SELECT * FROM support."V_PieceSupport" WHERE "ID_SupportFk"=%s AND NOT "Archive"'+restriction+' ORDER BY "CreeLe" DESC,"ID_PieceFk" DESC',[row['ID_Support']])
    history=[]
    if internal:
        history=db.query('''SELECT a."IdLog",a."Operation" AS "Action",a."ChangedAt" AS "DateAction",a."NewData"->>'_motif' AS "Motif",
          concat_ws(' ',u."PrenomUser",u."NomUser") AS "Auteur",a."OldData" AS "AnciennesValeurs",a."NewData" AS "NouvellesValeurs"
          FROM systeme."T_Audit_Log" a LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=(a."NewData"#>>'{_actor,IdUser}')::integer
          WHERE a."TableName" LIKE 'support.%%' AND a."IdEntiteFk"=%s
          AND (a."NewData"->>'ID_Support'=%s OR a."NewData"->>'ID_SupportFk'=%s)
          ORDER BY a."ChangedAt" DESC,a."IdLog" DESC''',[row['IdEntiteFk'],str(row['ID_Support']),str(row['ID_Support'])])
        for event in history:
            for field in ('AnciennesValeurs','NouvellesValeurs'):
                if isinstance(event[field],dict):event[field]={key:value for key,value in event[field].items() if key not in {'CircuitSnapshot','payloadHash','requestId','operation','_actor','_motif'}}
        # Un historique lisible expose les seules données métier modifiées,
        # avec leurs libellés, sans demander au client d'interpréter le JSON.
        generic_ids=set();user_ids=set();client_ids=set()
        generic_fields=set(REFERENCE_FIELDS)|{'ID_ResultatVerificationFk'}
        user_fields={'ID_ResponsableFk','ID_CreateurFk','ID_AuteurFk','ID_ProposeParFk','ID_VerifieParFk'}
        for event in history:
            for value in (event['AnciennesValeurs'] or {},event['NouvellesValeurs'] or {}):
                for key,item in value.items():
                    if type(item) is int:
                        if key in generic_fields:generic_ids.add(item)
                        elif key in user_fields:user_ids.add(item)
                        elif key=='ID_DemandeurFk':client_ids.add(item)
        from apps.core.reference_labels import reference_label_sql
        generic_names={str(item['id']):item['label'] for item in db.query('SELECT "ID_Generique" id,'+reference_label_sql()+' label FROM referentiel."T_Generique" WHERE "ID_Generique"=ANY(%s::integer[])',[list(generic_ids)])} if generic_ids else {}
        user_names={str(item['id']):item['label'] for item in db.query('SELECT "IdUser" id,concat_ws(\' \',"PrenomUser","NomUser") label FROM systeme."T_Utilisateurs" WHERE "IdUser"=ANY(%s::integer[])',[list(user_ids)])} if user_ids else {}
        client_names={str(item['id']):item['label'] for item in db.query('SELECT "ID_Client" id,"Nom" label FROM logistique."T_Client" WHERE "ID_Client"=ANY(%s::bigint[]) AND "IdEntiteFk"=%s',[list(client_ids),row['IdEntiteFk']])} if client_ids else {}
        diff_labels={**LABELS,'ID_ResponsableFk':'Responsable','ID_DemandeurFk':'Demandeur',
                     'ID_StatutFk':'Statut','ID_TypeSupportFk':'Type','ID_CategorieSupportFk':'Catégorie',
                     'ID_PrioriteFk':'Priorité','ID_CanalOrigineFk':'Canal','ID_ServiceConcerneFk':'Service concerné',
                     'Contenu':'Message','Visibilite':'Visibilité','CauseIdentifiee':'Cause identifiée',
                     'SolutionAppliquee':'Solution appliquée','ID_ResultatVerificationFk':'Résultat de vérification',
                     'CommentaireVerification':'Commentaire de vérification'}
        def display(field,value):
            names=generic_names if field in generic_fields else user_names if field in user_fields else client_names if field=='ID_DemandeurFk' else {}
            if names:return names.get(str(value),value)
            if type(value) is bool:return 'Oui' if value else 'Non'
            return value
        for event in history:
            before=event['AnciennesValeurs'] or {};after=event['NouvellesValeurs'] or {}
            event['Changements']=[{'field':field,'label':diff_labels[field],'before':display(field,before.get(field)),
                                   'after':display(field,after.get(field))} for field in diff_labels
                                  if field in EDIT_FIELDS|{'ID_StatutFk','Archive','Contenu','Visibilite','CauseIdentifiee','SolutionAppliquee','ID_ResultatVerificationFk','CommentaireVerification'}
                                  and before.get(field)!=after.get(field)]
    refs=references(actor,row)
    editable=refs['canManage'] and not row['Archive'] and view['StatutCode']!='closed'
    return clean({'record':public_record(view),'comments':comments,'resolutions':resolutions,'history':history,
                  'documents':documents,'transitions':transition_options(actor,row),
                  'canEdit':editable,'canComment':editable,'canUpload':editable,
                  'verificationResults':refs['references']['resultats'],
                  'circuitVersion':row['CircuitSnapshot']['version'],'circuitSettingId':row['CircuitSnapshot'].get('settingId'),
                  'context':refs,**refs})


def _text(value, label, maximum, required=False):
    if value in (None,'') and not required: return None
    if not isinstance(value,str) or not value.strip() or len(value)>maximum or any(ord(c)<32 and c not in '\n\r\t' for c in value):
        raise APIError({label:'Renseignez un texte valide de '+str(maximum)+' caractères maximum.'},'SUPPORT_VALIDATION',422)
    return value.strip()


def validate_fields(actor, body, old=None):
    if not isinstance(body,dict) or set(body)-EDIT_FIELDS:
        raise APIError('Un champ du dossier n’est pas modifiable.','SUPPORT_VALIDATION',422)
    entity=require_entity(actor);effective={**(old or {}),**body};result={}
    for field,value in body.items():
        if field in {'Objet','Description'}:
            result[field]=_text(value,field,200 if field=='Objet' else 20000,required=True)
        elif field=='DateEcheance':
            if value in (None,''):result[field]=None
            elif not isinstance(value,str):raise APIError({field:'Choisissez une date ISO valide.'},'SUPPORT_VALIDATION',422)
            else:
                try:
                    result[field]=datetime.fromisoformat(value.replace('Z','+00:00'))
                    if result[field].tzinfo is None: result[field]=timezone.make_aware(result[field])
                except (ValueError,OverflowError):raise APIError({field:'Choisissez une date valide.'},'SUPPORT_VALIDATION',422)
        else:result[field]=None if value in (None,'') else identifier(value,field)
    if old is None:
        for field in ('Objet','Description','ID_TypeSupportFk','ID_PrioriteFk','ID_CanalOrigineFk'):
            if not result.get(field):raise APIError({field:'Ce champ est obligatoire.'},'SUPPORT_VALIDATION',422)
    effective.update(result)
    for field in REFERENCE_FIELDS:
        if field not in result:continue
        value=result[field]
        if value is None or old and old.get(field)==value:continue
        choices=reference_options(actor,'support','T_Support',field)
        if not any(item['id']==value and not item.get('disabled') for item in choices):
            raise APIError({field:'Cette valeur ne fait pas partie des références actives de l’entreprise.'},'SUPPORT_REFERENCE_INVALID',422)
    objects={'ID_DemandeurFk':('logistique','T_Client','ID_Client','Actif'),
             'ID_ResponsableFk':('systeme','T_Utilisateurs','IdUser','ValideUser'),
             'ID_ImmobilisationFk':('logistique','T_Immobilisation','ID_Immobilisation','Actif'),
             'ID_CommandeFk':('logistique','T_Commande','ID_Commande',None),
             'ID_ArticleFk':('logistique','T_Article','ID_Article','ValideArticle')}
    for field,(schema,table,pk,active) in objects.items():
        if field not in result or result[field] is None or old and result[field]==old.get(field):continue
        linked=db.one('SELECT "IdEntiteFk"'+(','+db.ident(active)+' AS active' if active else '')+(' ,"Is_Admin"' if field=='ID_ResponsableFk' else '')+' FROM '+db.qualified(schema,table)+' WHERE '+db.ident(pk)+'=%s FOR SHARE',[result[field]])
        global_responsible=bool(field=='ID_ResponsableFk' and linked and linked['Is_Admin'] is True and actor.global_admin and result[field]==actor.pk)
        if not linked or linked['IdEntiteFk']!=entity and not global_responsible:
            raise APIError({field:'Choisissez une fiche de cette entreprise.'},'SUPPORT_LINK_SCOPE',422)
        if active and linked['active'] is not True:
            raise APIError({field:'Cette fiche n’est plus active.'},'SUPPORT_LINK_INACTIVE',422)
    return result


def _write_access(actor, row=None):
    require_module(actor,'support','manage');db.ensure_writable();entity=require_entity(actor)
    if not actor.admin:raise APIError('Votre rôle ne permet pas de traiter les dossiers.','SUPPORT_MANAGE_REQUIRED',403)
    if row and row['IdEntiteFk']!=entity:raise APIError('Choisissez l’entreprise du dossier avant de le modifier.','SUPPORT_ENTITY_MISMATCH',403)
    return entity


def _mutation_begin(actor, body, operation, pk=None):
    if not isinstance(body,dict):raise APIError('Objet JSON attendu.')
    try:request_id=str(uuid.UUID(str(body.get('requestId'))))
    except (ValueError,TypeError,AttributeError):raise APIError('Identifiant de demande obligatoire.','REQUEST_ID_REQUIRED',422)
    canonical={'entity':read_entity(actor),'operation':operation,'pk':str(pk) if pk is not None else None,
               'payload':{key:value for key,value in body.items() if key!='requestId'}}
    digest=hashlib.sha256(json.dumps(canonical,cls=ExactEncoder,sort_keys=True,separators=(',',':')).encode('utf8')).hexdigest()
    db.query("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",['support:'+str(actor.pk)+':'+request_id])
    events=db.query('''SELECT "NewData","IdEntiteFk" FROM systeme."T_Audit_Log"
        WHERE "TableName" LIKE 'support.%%' AND "NewData"->>'requestId'=%s
        AND "NewData"#>>'{_actor,IdUser}'=%s ORDER BY "IdLog"''',[request_id,str(actor.pk)])
    if events:
        if any(event['NewData'].get('payloadHash')!=digest or event['IdEntiteFk']!=read_entity(actor) for event in events):
            raise APIError('Cette demande a déjà été utilisée avec un autre contenu.','IDEMPOTENCY_CONFLICT',409)
        event=events[-1]['NewData'];parent=event.get('ID_Support') or event.get('ID_SupportFk')
        if not parent:raise APIError('La preuve de cette demande doit être vérifiée.','IDEMPOTENCY_PROOF_INVALID',409)
        return identifier(parent),True
    set_admin_actor(actor)
    meta={'requestId':request_id,'payloadHash':digest,'operation':operation,'motif':body.get('motif') or ''}
    db.query("SELECT set_config('support.mutation',%s,true)",[json.dumps(meta,separators=(',',':'))])
    return None,False


def _revision(row,body):
    if str(body.get('_version',''))!=str(row['VersionEnregistrement']):
        raise APIError('Ce dossier a été modifié. Rechargez sa fiche avant de poursuivre.','SUPPORT_VERSION_CONFLICT',409)


def _touch(pk):
    db.query('UPDATE support."T_Support" SET "DateModification"=CURRENT_TIMESTAMP WHERE "ID_Support"=%s',[pk])


def _database_error(exc):
    state=getattr(exc.__cause__,'sqlstate',None)
    if state in {'23503','23505','23514','P0001','22023'}:
        # Les erreurs métier connues viennent des gardes du module, jamais d'une
        # concaténation SQL utilisateur. Ne retourner que leur message primaire.
        diag=getattr(exc.__cause__,'diag',None);message=getattr(diag,'message_primary',None)
        raise APIError(message or 'Le dossier ne peut pas être enregistré dans cet état.','SUPPORT_BUSINESS_CONFLICT',409) from exc
    raise exc


def save(actor,body,pk=None):
    with transaction.atomic():
        _write_access(actor)
        if not isinstance(body,dict) or set(body)-EDIT_FIELDS-{'requestId','_version','motif'}:
            raise APIError('Un champ du dossier n’est pas modifiable.','SUPPORT_VALIDATION',422)
        existing,replayed=_mutation_begin(actor,body,'update' if pk else 'create',pk)
        if replayed:return public_record(db.one('SELECT * FROM support."V_Support" WHERE "ID_Support"=%s',[record(actor,existing)['ID_Support']])),True
        old=record(actor,pk,True) if pk else None
        if old:
            _write_access(actor,old);_revision(old,body)
            if old['Archive']:raise APIError('Restaurez ce dossier avant de le modifier.','SUPPORT_ARCHIVED',409)
            if old['ID_StatutFk']==old['CircuitSnapshot']['states']['closed']:
                raise APIError('Rouvrez le dossier avant de le modifier.','SUPPORT_CLOSED',409)
        prepared=validate_fields(actor,{key:value for key,value in body.items() if key in EDIT_FIELDS},old)
        if not prepared:raise APIError('Aucune modification à enregistrer.','SUPPORT_VALIDATION',422)
        try:
            with transaction.atomic():
                if old:
                    db.query('UPDATE support."T_Support" SET '+','.join(db.ident(key)+'=%s' for key in prepared)+' WHERE "ID_Support"=%s',[*prepared.values(),old['ID_Support']]);identifier_=old['ID_Support']
                else:
                    prepared.update(IdEntiteFk=require_entity(actor),ID_CreateurFk=actor.pk)
                    identifier_=db.one('INSERT INTO support."T_Support"('+','.join(db.ident(key) for key in prepared)+') VALUES('+','.join('%s' for _ in prepared)+') RETURNING "ID_Support"',list(prepared.values()))['ID_Support']
        except DatabaseError as exc:_database_error(exc)
        return public_record(db.one('SELECT * FROM support."V_Support" WHERE "ID_Support"=%s',[identifier_])),False


def perform_action(actor,pk,body):
    allowed={'action','requestId','_version','motif','CauseIdentifiee','SolutionAppliquee','ID_ResultatVerificationFk','CommentaireVerification'}
    if not isinstance(body,dict) or set(body)-allowed:raise APIError('Action invalide.','SUPPORT_VALIDATION',422)
    action=body.get('action')
    if action not in ACTION_LABELS:raise APIError('Action inconnue.','SUPPORT_ACTION_INVALID',422)
    with transaction.atomic():
        _write_access(actor);existing,replayed=_mutation_begin(actor,body,action,pk)
        if replayed:return detail(actor,existing),True
        row=record(actor,pk,True);_write_access(actor,row);_revision(row,body)
        if row['Archive'] and action!='restore':raise APIError('Restaurez ce dossier avant de le traiter.','SUPPORT_ARCHIVED',409)
        permitted={item['key'] for item in transition_options(actor,row)}
        if action not in permitted and action not in {'archive','restore'}:raise APIError('Cette action n’est pas disponible à cette étape.','SUPPORT_TRANSITION_INVALID',409)
        reason=_text(body.get('motif'),'motif',2000,required=action in {'pause','reopen','archive','restore'})
        states=row['CircuitSnapshot']['states'];current=next((key for key,value in states.items() if value==row['ID_StatutFk']),None)
        edge=next((edge for edge in row['CircuitSnapshot']['transitions'] if edge.get('from')==current and edge.get('action')==action),None)
        try:
            with transaction.atomic():
                if action=='archive':
                    if row['ID_StatutFk']!=states['closed']:raise APIError('Clôturez le dossier avant de l’archiver.','SUPPORT_NOT_CLOSED',409)
                    db.query('UPDATE support."T_Support" SET "Archive"=true WHERE "ID_Support"=%s',[row['ID_Support']])
                elif action=='restore':
                    if not row['Archive']:raise APIError('Ce dossier n’est pas archivé.','SUPPORT_NOT_ARCHIVED',409)
                    db.query('UPDATE support."T_Support" SET "Archive"=false WHERE "ID_Support"=%s',[row['ID_Support']])
                elif action=='resolve':
                    cause=_text(body.get('CauseIdentifiee'),'CauseIdentifiee',10000,True)
                    solution=_text(body.get('SolutionAppliquee'),'SolutionAppliquee',20000,True)
                    db.query('INSERT INTO support."T_ResolutionSupport"("ID_SupportFk","CauseIdentifiee","SolutionAppliquee","ID_ProposeParFk") VALUES(%s,%s,%s,%s)',[row['ID_Support'],cause,solution,actor.pk])
                    db.query('UPDATE support."T_Support" SET "ID_StatutFk"=%s WHERE "ID_Support"=%s',[states[edge['to']],row['ID_Support']])
                elif action=='verify':
                    result=identifier(body.get('ID_ResultatVerificationFk'),'Résultat de vérification')
                    if result not in row['CircuitSnapshot']['verification'].values():raise APIError({'ID_ResultatVerificationFk':'Choisissez un résultat du circuit de ce dossier.'},'SUPPORT_REFERENCE_INVALID',422)
                    comment=_text(body.get('CommentaireVerification'),'CommentaireVerification',10000,True)
                    resolution=db.one('SELECT * FROM support."T_ResolutionSupport" WHERE "ID_SupportFk"=%s ORDER BY "ID_ResolutionSupport" DESC LIMIT 1 FOR UPDATE',[row['ID_Support']])
                    if not resolution:raise APIError('Proposez une résolution avant de la vérifier.','SUPPORT_RESOLUTION_REQUIRED',409)
                    if resolution['ID_ProposeParFk']==actor.pk:raise APIError('La vérification doit être faite par une autre personne habilitée.','SUPPORT_SECOND_VERIFIER_REQUIRED',409)
                    if resolution['DateVerification'] is not None:raise APIError('Cette tentative a déjà été vérifiée. Rouvrez le dossier pour proposer une nouvelle solution.','SUPPORT_ALREADY_VERIFIED',409)
                    db.query('UPDATE support."T_ResolutionSupport" SET "ID_ResultatVerificationFk"=%s,"ID_VerifieParFk"=%s,"CommentaireVerification"=%s WHERE "ID_ResolutionSupport"=%s',[result,actor.pk,comment,resolution['ID_ResolutionSupport']])
                    _touch(row['ID_Support'])
                else:
                    if action=='start' and not row['ID_ResponsableFk']:raise APIError('Affectez un responsable avant la prise en charge.','SUPPORT_RESPONSIBLE_REQUIRED',422)
                    db.query('UPDATE support."T_Support" SET "ID_StatutFk"=%s WHERE "ID_Support"=%s',[states[edge['to']],row['ID_Support']])
        except DatabaseError as exc:_database_error(exc)
        return detail(actor,row['ID_Support']),False


def add_comment(actor,pk,body):
    if not isinstance(body,dict) or set(body)-{'Contenu','Visibilite','requestId','_version'}:raise APIError('Commentaire invalide.','SUPPORT_VALIDATION',422)
    content=_text(body.get('Contenu'),'Contenu',20000,True)
    visibility=body.get('Visibilite','public')
    if visibility not in {'public','interne'}:raise APIError('Visibilité invalide.','SUPPORT_VALIDATION',422)
    with transaction.atomic():
        _write_access(actor);existing,replayed=_mutation_begin(actor,body,'comment',pk)
        if replayed:return detail(actor,existing),True
        row=record(actor,pk,True);_write_access(actor,row);_revision(row,body)
        if row['Archive'] or row['ID_StatutFk']==row['CircuitSnapshot']['states']['closed']:raise APIError('Rouvrez le dossier pour ajouter un échange.','SUPPORT_CLOSED',409)
        try:
            with transaction.atomic():
                db.query('INSERT INTO support."T_CommentaireSupport"("ID_SupportFk","ID_AuteurFk","Contenu","Visibilite") VALUES(%s,%s,%s,%s)',[row['ID_Support'],actor.pk,content,visibility]);_touch(row['ID_Support'])
        except DatabaseError as exc:_database_error(exc)
        return detail(actor,row['ID_Support']),False


def add_document(actor, pk, data, upload):
    if set(data)-{'file','requestId','_version','Visibilite','ID_CommentaireSupportFk'}:raise APIError('Justificatif invalide.')
    _write_access(actor)
    blob,mime,extension=validate_upload(upload)
    name=filename(Path(str(upload.name).replace('\\','/')).stem,extension)
    digest=hashlib.sha256(blob).hexdigest();visibility=data.get('Visibilite') or 'public'
    if visibility not in {'public','interne'}:raise APIError('Visibilité invalide.')
    comment_id=identifier(data['ID_CommentaireSupportFk']) if data.get('ID_CommentaireSupportFk') else None
    body={'requestId':data.get('requestId'),'_version':data.get('_version'),'Visibilite':visibility,
          'ID_CommentaireSupportFk':comment_id,'sha256':digest,'size':len(blob),'name':name,'mime':mime}
    with transaction.atomic():
        existing,replayed=_mutation_begin(actor,body,'document',pk)
        if replayed:return detail(actor,existing),True
        row=record(actor,pk,True);_write_access(actor,row);_revision(row,body)
        if row['Archive'] or row['ID_StatutFk']==row['CircuitSnapshot']['states']['closed']:raise APIError('Rouvrez le dossier pour ajouter un justificatif.','SUPPORT_CLOSED',409)
        if comment_id:
            comment=db.one('SELECT "Visibilite" FROM support."T_CommentaireSupport" WHERE "ID_CommentaireSupport"=%s AND "ID_SupportFk"=%s',[comment_id,row['ID_Support']])
            if not comment:raise APIError('Le commentaire ne fait pas partie du dossier.','SUPPORT_COMMENT_SCOPE',422)
            if comment['Visibilite']=='interne' and visibility!='interne':raise APIError('Une pièce d’une note interne doit rester interne.','SUPPORT_DOCUMENT_VISIBILITY',422)
        try:
            with transaction.atomic():
                piece=db.one('''INSERT INTO logistique."T_PieceJustificative"("TypeObjet","ID_Objet","IdEntiteFk","ID_UserFk","NomFichier","MimeType","TailleOctets","Sha256","Contenu")
                    VALUES('support',%s,%s,%s,%s,%s,%s,%s,%s) RETURNING "ID_Piece"''',[row['ID_Support'],row['IdEntiteFk'],actor.pk,name,mime,len(blob),digest,blob])['ID_Piece']
                db.query('INSERT INTO support."T_PieceSupport"("ID_PieceFk","ID_SupportFk","ID_CommentaireSupportFk","Visibilite") VALUES(%s,%s,%s,%s)',[piece,row['ID_Support'],comment_id,visibility]);_touch(row['ID_Support'])
        except DatabaseError as exc:_database_error(exc)
        return detail(actor,row['ID_Support']),False


def document(actor,pk,piece_id):
    row=record(actor,pk);internal=capabilities(actor)['canReadInternal']
    value=db.one('''SELECT p."Contenu",p."NomFichier",p."MimeType",p."Sha256",p."TailleOctets"
        FROM support."T_PieceSupport" l JOIN logistique."T_PieceJustificative" p ON p."ID_Piece"=l."ID_PieceFk"
        WHERE l."ID_SupportFk"=%s AND l."ID_PieceFk"=%s AND p."IdEntiteFk"=%s AND p."TypeObjet"='support'
          AND p."ID_Objet"=%s AND NOT p."Archive"'''+('' if internal else ' AND l."Visibilite"=\'public\''),[row['ID_Support'],identifier(piece_id),row['IdEntiteFk'],row['ID_Support']])
    if value is None:raise APIError('Pièce introuvable.','NOT_FOUND',404)
    blob=bytes(value['Contenu'])
    if len(blob)!=value['TailleOctets'] or hashlib.sha256(blob).hexdigest()!=value['Sha256']:
        raise APIError('L’intégrité du justificatif doit être vérifiée.','SUPPORT_DOCUMENT_INTEGRITY',409)
    return blob,value['MimeType'],value['NomFichier']


def workbook(actor,raw,file_format='xlsx'):
    from apps.core.table_preferences import export_keys
    from apps.core.tabular_exports import selected_scope, write_tabular
    obj,where,values,order,sort,direction=selection(actor,raw,'export')
    columns=export_keys(actor,'support.tickets',raw);available={column['column_name']:column for column in obj['columns']}
    if not columns or any(key not in available or key not in LABELS for key in columns):raise APIError('Colonnes non exportables.')
    selected,params=selected_scope(raw,'ID_Support');where+=selected;values.extend(params)
    fields=[{**available[key],'label':LABELS[key],**({'data_type':'text'} if key.startswith(('ID_','Id','Numero')) else {})} for key in columns]
    zone=document_zone(raw);generated=datetime.now(zone);stream=SpooledTemporaryFile(max_size=8*1024*1024,mode='w+b')
    context={'title':'Dossiers Support','scope':'Entreprise '+str(read_entity(actor)) if read_entity(actor) else 'Toutes les entreprises autorisées',
        'generated':generated.strftime('%d/%m/%Y %H:%M'),'zone':str(zone),'tz':zone,'source':'support.V_Support',
        'raw':raw,'filters':{},'order':LABELS[sort]+' '+direction}
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT '+','.join('v.'+db.ident(key) for key in columns)+' FROM support."V_Support" v WHERE '+where+' ORDER BY '+order+' LIMIT %s',[*values,MAX_EXPORT_ROWS+1])
            def rows():
                while batch:=cursor.fetchmany(500):
                    for row in batch:yield dict(zip(columns,row))
            count=write_tabular(stream,fields,rows(),context,file_format)
        stream.seek(0);return stream,count,'SauverNdeko_Support_'+generated.strftime('%Y-%m-%d')+'.'+file_format
    except Exception:stream.close();raise


class SupportContextView(APIView):
    permission_classes=[HasModuleAccess]
    def get(self,request):
        if set(request.query_params)-{'currentId'}:raise APIError('Critère non autorisé.')
        current=record(request.user,request.query_params['currentId']) if request.query_params.get('currentId') else None
        return ok(references(request.user,current))


class SupportEntitiesView(APIView):
    permission_classes=[HasModuleAccess]
    def get(self,request):
        require_module(request.user,'support')
        if request.query_params:raise APIError('Critère non autorisé.')
        where='TRUE' if request.user.global_admin else '"IdEntite"=%s'
        rows=db.query('SELECT "IdEntite" AS id,"NomEntite" AS label,"ValideEntite" AS active FROM systeme."T_Entite" WHERE '+where+' ORDER BY lower("NomEntite"),"IdEntite"',[] if request.user.global_admin else [request.user.organisation])
        return ok(rows,meta={'entityId':read_entity(request.user),'platformAdmin':request.user.global_admin})


class SupportTicketsView(APIView):
    permission_classes=[HasModuleAccess]
    http_method_names=['get','post','put','patch','options']
    def get(self,request,pk=None):
        if pk is not None:
            if request.query_params:raise APIError('La fiche ne comporte pas de filtre.')
            return ok(detail(request.user,pk))
        rows,meta=list_records(request.user,request.query_params.dict());return ok(rows,meta=meta)
    def post(self,request,pk=None):
        if pk is not None:raise APIError('Utilisez les actions du dossier.','METHOD_NOT_ALLOWED',405)
        row,replay=save(request.user,request.data);return ok(row,status=200 if replay else 201,meta={'replayed':replay})
    def put(self,request,pk=None):
        if pk is None:raise APIError('Choisissez un dossier à modifier.','METHOD_NOT_ALLOWED',405)
        row,replay=save(request.user,request.data,pk);return ok(row,meta={'replayed':replay})
    patch=put


class SupportActionsView(APIView):
    permission_classes=[HasModuleAccess]
    http_method_names=['post','options']
    def post(self,request,pk):
        row,replay=perform_action(request.user,pk,request.data);return ok(row,meta={'replayed':replay})


class SupportCommentsView(APIView):
    permission_classes=[HasModuleAccess]
    http_method_names=['post','options']
    def post(self,request,pk):
        row,replay=add_comment(request.user,pk,request.data);return ok(row,status=200 if replay else 201,meta={'replayed':replay})


class SupportDocumentsView(DocumentDownloadView):
    permission_classes=[HasModuleAccess]
    parser_classes=[MultiPartParser,FormParser]
    http_method_names=['get','post','options']
    def get(self,request,pk):return ok(detail(request.user,pk)['documents'])
    def post(self,request,pk):
        if len(request.FILES.getlist('file'))!=1:raise APIError('Choisissez un fichier.','SUPPORT_DOCUMENT_VALIDATION',422)
        row,replay=add_document(request.user,pk,request.data,request.FILES.get('file'));return ok(row,status=200 if replay else 201,meta={'replayed':replay})


class SupportDocumentDownloadView(DocumentDownloadView):
    permission_classes=[HasModuleAccess]
    http_method_names=['get','options']
    def get(self,request,pk,piece_id):
        if request.query_params:raise APIError('Critère non autorisé.')
        return binary_response(*document(request.user,pk,piece_id))


class SupportDashboardView(APIView):
    permission_classes=[HasModuleAccess]
    def get(self,request):
        actor=request.user;obj,where,values,*_=selection(actor,request.query_params.dict())
        row=db.one('''SELECT count(*) AS total,
            count(*) FILTER(WHERE v."StatutCode" NOT IN ('resolved','closed')) AS ouverts,
            count(*) FILTER(WHERE v."StatutCode"='pending') AS "enAttente",
            count(*) FILTER(WHERE v."DateEcheance"<statement_timestamp() AND v."StatutCode" NOT IN ('resolved','closed')) AS "enRetard",
            count(*) FILTER(WHERE v."StatutCode"='resolved') AS resolus,
            count(*) FILTER(WHERE v."StatutCode"='closed') AS clotures FROM support."V_Support" v WHERE '''+where,values)
        charts={}
        for name,field,label in [('parStatut','ID_StatutFk','Statut'),('parPriorite','ID_PrioriteFk','Priorite')]:
            charts[name]=db.query('SELECT v.'+db.ident(field)+' AS id,v.'+db.ident(label)+' AS label,count(*) AS count FROM support."V_Support" v WHERE '+where+' GROUP BY v.'+db.ident(field)+',v.'+db.ident(label)+' ORDER BY count DESC,label NULLS LAST,id',values)
        return ok({'metrics':row,'charts':charts,**capabilities(actor)})


class SupportKanbanView(APIView):
    permission_classes=[HasModuleAccess]
    def get(self,request):
        actor=request.user;obj,where,values,order,*_=selection(actor,request.query_params.dict())
        groups=db.query('SELECT v."ID_StatutFk" AS id,v."Statut" AS label,count(*) AS count FROM support."V_Support" v WHERE '+where+' GROUP BY v."ID_StatutFk",v."Statut" ORDER BY label,id',values)
        known={row['id'] for row in groups}
        for option in reference_options(actor,'support','T_Support','ID_StatutFk'):
            if option['id'] not in known:groups.append({'id':option['id'],'label':option['label'],'count':0})
        take=20
        for group in groups:
            group['rows']=[public_record(row) for row in db.query('SELECT v.* FROM support."V_Support" v WHERE '+where+' AND v."ID_StatutFk"=%s ORDER BY '+order+' LIMIT %s',[*values,group['id'],take])]
            group['hasMore']=group['count']>len(group['rows'])
        return ok({'columns':groups,'take':take,**capabilities(actor)})


class SupportExcelView(ExcelDownloadView):
    permission_classes=[HasModuleAccess]
    def get(self,request):
        stream,count,name=workbook(request.user,request.query_params.dict())
        result=FileResponse(stream,as_attachment=True,filename=name,content_type=XLSX_MEDIA_TYPE)
        result['X-Export-Row-Count']=str(count);result['Cache-Control']='private, no-store';return result


class SupportCSVView(SupportExcelView):
    renderer_classes=[ExactJSONRenderer,CSVFileRenderer]
    def get(self,request):
        stream,count,name=workbook(request.user,request.query_params.dict(),'csv')
        result=FileResponse(stream,as_attachment=True,filename=name,content_type='text/csv; charset=utf-8')
        result['X-Export-Row-Count']=str(count);result['Cache-Control']='private, no-store';return result
