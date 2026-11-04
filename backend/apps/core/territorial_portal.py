"""Organisation territoriale : vues existantes, critères et identités fermés.

La géographie est partagée. Le contexte entreprise ne lui invente pas un
propriétaire ; seules les habilitations du module et les gardes globales
autorisent lecture, export et mutation.
"""
import hashlib
import json
import re
import uuid
import unicodedata
from datetime import datetime
from decimal import Decimal, InvalidOperation
from tempfile import SpooledTemporaryFile

from django.conf import settings
from django.db import DatabaseError, IntegrityError, connection, transaction
from django.http import FileResponse
from rest_framework.views import APIView
from . import db
from .module_access import require_module, access_snapshot
from .permissions import IsERPAdmin
from .registry import model, view
from .repository import clean, page, positive, predicate, mutate, audit, coerce
from .responses import APIError, ExactEncoder, ExactJSONRenderer, ok
from apps.logistique.excel import ExcelDownloadView, CSVFileRenderer, XLSX_MEDIA_TYPE, MAX_EXPORT_ROWS
from apps.logistique.table_queries import document_zone
from . import territorial_contacts

SOURCES = {
    'niveaux0': ('geolocalisation','V_Niveau_0','ID_Niveau_0','NomNiveau_0'),
    'niveaux1-historique': ('geolocalisation','V_Niveau_1_Old','ID_Niveau_1_Old','NomNiveau_1_Old'),
    **{f'niveaux{n}': ('geolocalisation',f'V_Niveau_{n}',f'ID_Niveau_{n}',f'NomNiveau_{n}') for n in range(1,6)},
    'as-sans-site': ('geolocalisation','V_AS_sans_Site','_rowId','NomNiveau_4'),
    'zs-sans-as': ('geolocalisation','V_ZS_sans_AS','_rowId','NomNiveau_3'),
    'population-sites': ('geolocalisation','V_Pop_N3_Couverte_Sites','_rowId','NomNiveau_3'),
    'reseau-as': ('geolocalisation','V_RESEAU_AS_par_ZS','_rowId','NomNiveau_3'),
    'statistiques-provinces': ('geolocalisation','V_Stats_N1_N2','_rowId','NomNiveau_1'),
    'statistiques-zones': ('geolocalisation','V_Stats_N3_Structures','_rowId','NomNiveau_3'),
}
MODELS = {kind:name.replace('V_','T_',1) for kind,(_,name,pk,_) in SOURCES.items() if pk!='_rowId'}
MODEL_KINDS={name:kind for kind,name in MODELS.items()}
INTERFACE_KEYS = {kind:'territoires.'+{'niveaux0':'niveaux-zero','niveaux1-historique':'niveaux-un-historique','niveaux1':'niveaux-un','niveaux2':'niveaux-deux','niveaux3':'niveaux-trois','niveaux4':'niveaux-quatre','niveaux5':'niveaux-cinq'}.get(kind,kind) for kind in SOURCES}
TITLES = {'niveaux0':'Pays et territoires','niveaux1-historique':'Ancien découpage provincial','niveaux1':'Provinces et DPS','niveaux2':'Antennes et subdivisions','niveaux3':'Zones de santé','niveaux4':'Aires de santé','niveaux5':'Structures et sites','as-sans-site':'Aires de santé sans site','zs-sans-as':'Zones de santé sans aire','population-sites':'Population déclarée des sites','reseau-as':'Réseau des aires de santé','statistiques-provinces':'Répartition des subdivisions','statistiques-zones':'Répartition des structures'}
GRAINS = {'as-sans-site':['ID_Niveau_4'],'zs-sans-as':['ID_Niveau_3'],'population-sites':['ID_Niveau_3','ID_TypeNiveau_5_Fk'],'reseau-as':['ID_Niveau_3'],'statistiques-provinces':['ID_Niveau_1','ID_TypeNiveau_2_Fk'],'statistiques-zones':['ID_Niveau_3','ID_TypeNiveau_4_Fk','ID_TypeNiveau_5_Fk']}
NOTES = {'population-sites':'Population déclarée cumulée des sites par zone et type. Les périmètres peuvent se recouvrir ; ces valeurs ne constituent pas un taux de couverture.', 'statistiques-zones':'Une ligne représente une zone, un type d’aire et un type de site. Les comptes d’aires peuvent se répéter entre types de sites.', 'niveaux1-historique':'Ancien découpage conservé pour les rattachements historiques.'}
LABELS = {'_rowId':'Identifiant de la ligne','SITE':'Site','CodeSNIS':'Code SNIS','iso':'Code ISO','uidSNIS':'Identifiant SNIS','RESEAU':'Réseau','VOIE_AS_ZS':'Voie d’accès ZS–AS','VOIE_AS_Site':'Voie d’accès ZS–site','STATUT_AS':'Statut','STATUT_Site':'Statut','STATUT_DEPLOI':'Déploiement','Statut_Deploiement':'Déploiement','KmAntenneBCZS':'Distance antenne–zone (km)','KmDPSBCZS':'Distance DPS–zone (km)','KmDPSANT':'Distance DPS–antenne (km)','KmZoneSanteAS':'Distance zone–aire (km)','KmZoneSanteNiveau_5':'Distance zone–site (km)','Voie_Acces_DPS':'Voie d’accès DPS','Voie_ANTBCZ':'Voie d’accès antenne–zone','Voie_DPSBCZS':'Voie d’accès DPS–zone','Pop_Cum_Sites':'Population déclarée des sites','Nb_AS':'Aires de santé','Nb_AS_Avec_Reseau':'Aires avec réseau','Pct_AS_Avec_Reseau':'Avec réseau (%)','Nb_Niveau_2':'Subdivisions','Pop_Niveau_2':'Population des subdivisions','Nb_Aires_Sante':'Aires de santé','Nb_Structures_Sante':'Structures de santé','NomNiveau_1_Old':'Ancienne province','ID_Niveau_1_Old':'Identifiant historique','ID_Niveau_1_Old_Fk':'Ancienne province','surfaceNiveau_1_Old':'Surface','geometryNiveau_1_Old':'Géométrie historique','ID_StatusDeploiFk':'Identifiant déploiement','ID_StatutDeploieFk':'Identifiant déploiement','ID_StatutDeploiementFk':'Identifiant déploiement','ID_TypeToitFk':'Identifiant type de toit','ID_VoieAccesDPSANTFk':'Identifiant voie DPS–antenne','ID_VoieAccesANTBCZFk':'Identifiant voie antenne–zone','ID_VoieAccesDPSBCZFk':'Identifiant voie DPS–zone','ID_VoieAccesZsASFk':'Identifiant voie zone–aire','ID_VoieAccesZsSiteFk':'Identifiant voie zone–site'}
LEVEL_NAMES={0:'Pays / territoire',1:'Province / DPS',2:'Antenne / subdivision',3:'Zone de santé',4:'Aire de santé',5:'Structure / site'}
for _n in range(6):
    for _prefix,_label in {'ID_Niveau_':'Identifiant','NomNiveau_':LEVEL_NAMES[_n],'CodeNiveau_':'Code','AbreNiveau_':'Abréviation','PopulationNiveau_':'Population','LatitudeNiveau_':'Latitude','LongitudeNiveau_':'Longitude','AltitudeNiveau_':'Altitude','surfaceNiveau_':'Surface','geometryNiveau_':'Géométrie','EtenduNiveau_':'Étendue','ObsNiveau_':'Observations','SelectNiveau_':'Sélectionné','Type_Niveau_':'Type','Statut_Niveau_':'Statut','ID_TypeNiveau_':'Identifiant type','ID_StatutNiveau_':'Identifiant statut','ID_DispoReseauNiveau_':'Identifiant réseau'}.items():
        LABELS[_prefix+str(_n)]=_label
    LABELS[f'ID_Niveau_{_n}_Fk']=LEVEL_NAMES[_n]+' parent'
    LABELS[f'ID_Niveau_{_n}_FK']=LEVEL_NAMES[_n]+' parent'
    LABELS[f'ID_TypeNiveau_{_n}_Fk']='Identifiant type'
    LABELS[f'ID_StatutNiveau_{_n}_Fk']='Identifiant statut'
for _key,_label in {'Alt1_Niveau_1':'Alias 1','Alt2_Niveau_1':'Alias 2','Alt1_NomNiveau_2':'Alias','Alt_Niveau_3':'Alias','timezoneNiveau_1':'Fuseau horaire','wikidataNiveau_1':'Wikidata','FusionNiveau_1':'Fusion','VisibleNiveau_1':'Visible dans le découpage','VisibleNiveau_5':'Visible pour les sites'}.items():LABELS[_key]=_label
DEFAULTS = {
    'niveaux0':['NomNiveau_0','CodeNiveau_0','iso','Nb_Niveau_1'],
    'niveaux1-historique':['NomNiveau_1_Old','surfaceNiveau_1_Old'],
    'niveaux1':['NomNiveau_1','NomNiveau_0','AbreNiveau_1','CodeNiveau_1','PopulationNiveau_1','VisibleNiveau_1','Nb_Niveau_2'],
    'niveaux2':['NomNiveau_2','Type_Niveau_2','NomNiveau_1','CodeNiveau_2','PopulationNiveau_2','Statut_Niveau_2','Nb_Niveau_3'],
    'niveaux3':['NomNiveau_3','Type_Niveau_3','NomNiveau_2','NomNiveau_1','CodeNiveau_3','PopulationNiveau_3','Statut_Niveau_3','Nb_Niveau_4','Nb_Niveau_5'],
    'niveaux4':['NomNiveau_4','Type_Niveau_4','NomNiveau_3','NomNiveau_1','CodeNiveau_4','PopulationNiveau_4','STATUT_AS','Nb_Niveau_5'],
    'niveaux5':['NomNiveau_5','Type_Niveau_5','NomNiveau_3','NomNiveau_1','CodeNiveau_5','PopulationNiveau_5','STATUT_Site'],
    'as-sans-site':['NomNiveau_4','NomNiveau_3','NomNiveau_2','NomNiveau_1'],
    'zs-sans-as':['NomNiveau_3','NomNiveau_2','NomNiveau_1'],
    'population-sites':['NomNiveau_3','NomNiveau_1','Type_Niveau_5','Pop_Cum_Sites'],
    'reseau-as':['NomNiveau_3','NomNiveau_1','Nb_AS','Nb_AS_Avec_Reseau','Pct_AS_Avec_Reseau'],
    'statistiques-provinces':['NomNiveau_1','Type_Niveau_2','Nb_Niveau_2','Pop_Niveau_2'],
    'statistiques-zones':['NomNiveau_3','NomNiveau_1','Type_Niveau_4','Type_Niveau_5','Nb_Aires_Sante','Nb_Structures_Sante'],
}
LABELS.update({'Nb_Niveau_1':'Provinces / DPS','Nb_Niveau_2':'Antennes / subdivisions','Nb_Niveau_3':'Zones de santé','Nb_Niveau_4':'Aires de santé','Nb_Niveau_5':'Structures / sites','ID_TypeNiveau_4_Fk':'Identifiant type d’aire','AvecReseau':'Avec réseau déclaré','StructuresZone':'Zone du rapport','StructuresTypeSite':'Type de site du rapport','prov_uid':'Identifiant de province','Type_Toit':'Type de toit'})
LABELS.update({'AdresseTerritoire':'Adresse','TelephoneTerritoire':'Téléphone principal',
    'TelephoneSecondaireTerritoire':'Téléphone secondaire','EmailTerritoire':'Adresse e-mail',
    'SiteWebTerritoire':'Site web','InformationsAccueilTerritoire':'Informations d’accueil',
    'HorairesOuvertureTerritoire':'Horaires d’ouverture','PublierCoordonneesAnnuaire':'Publier les coordonnées dans l’annuaire des structures et territoires',
    'CoordonneesModifieLe':'Coordonnées mises à jour le'})


def _drill(kind,filters,**extra):
    return {'kind':kind,'filters':{key:({'field':value} if isinstance(value,str) else {'value':value}) for key,value in filters.items()},**extra}


DRILLDOWNS = {
    'niveaux0':{'Nb_Niveau_1':_drill('niveaux1',{'ID_Niveau_0_Fk':'ID_Niveau_0'})},
    'niveaux1':{'Nb_Niveau_2':_drill('niveaux2',{'ID_Niveau_1_FK':'ID_Niveau_1'})},
    'niveaux2':{'Nb_Niveau_3':_drill('niveaux3',{'ID_Niveau_2_FK':'ID_Niveau_2'})},
    'niveaux3':{'Nb_Niveau_4':_drill('niveaux4',{'ID_Niveau_3_Fk':'ID_Niveau_3'}),'Nb_Niveau_5':_drill('niveaux5',{'ID_Niveau_3':'ID_Niveau_3'})},
    'niveaux4':{'Nb_Niveau_5':_drill('niveaux5',{'ID_Niveau_4_Fk':'ID_Niveau_4'})},
    'statistiques-provinces':{'Nb_Niveau_2':_drill('niveaux2',{'ID_Niveau_1_FK':'ID_Niveau_1','ID_TypeNiveau_2_Fk':'ID_TypeNiveau_2_Fk'}),'Pop_Niveau_2':_drill('niveaux2',{'ID_Niveau_1_FK':'ID_Niveau_1','ID_TypeNiveau_2_Fk':'ID_TypeNiveau_2_Fk'},mode='sources',label='Voir les subdivisions sources')},
    'statistiques-zones':{'Nb_Aires_Sante':_drill('niveaux4',{'StructuresZone':'ID_Niveau_3','StructuresTypeSite':'ID_TypeNiveau_5_Fk','ID_TypeNiveau_4_Fk':'ID_TypeNiveau_4_Fk'}),'Nb_Structures_Sante':_drill('niveaux5',{'ID_Niveau_3':'ID_Niveau_3','ID_TypeNiveau_4_Fk':'ID_TypeNiveau_4_Fk','ID_TypeNiveau_5_Fk':'ID_TypeNiveau_5_Fk'})},
    'reseau-as':{'Nb_AS':_drill('niveaux4',{'ID_Niveau_3_Fk':'ID_Niveau_3'}),'Nb_AS_Avec_Reseau':_drill('niveaux4',{'ID_Niveau_3_Fk':'ID_Niveau_3','AvecReseau':True}),'Pct_AS_Avec_Reseau':_drill('niveaux4',{'ID_Niveau_3_Fk':'ID_Niveau_3'},mode='sources',label='Voir les aires sources')},
    'population-sites':{'Pop_Cum_Sites':_drill('niveaux5',{'ID_Niveau_3':'ID_Niveau_3','ID_TypeNiveau_5_Fk':'ID_TypeNiveau_5_Fk'},mode='sources',label='Voir les sites sources')},
}

def _column(name,kind='integer'):
    return {'column_name':name,'data_type':kind,'is_nullable':'YES','character_maximum_length':None,'numeric_precision':None,'numeric_scale':None,'column_default':None,'is_identity':'NO'}

def source(actor,kind,action='read'):
    require_module(actor,'territoires',action)
    if kind not in SOURCES:raise APIError('Registre territorial indisponible.','NOT_FOUND',404)
    schema,name,pk,sort=SOURCES[kind];obj={**view(schema,name)};columns=list(obj['columns'])
    additions=[]
    if kind=='niveaux2':additions=[_column('ID_Niveau_0'),_column('ID_Niveau_1')]
    if kind=='niveaux3':additions=[_column('ID_Niveau_0'),_column('NomNiveau_0','text'),_column('ID_Niveau_1'),_column('NomNiveau_1','text'),_column('ID_Niveau_2'),_column('NomNiveau_2','text')]
    if kind in GRAINS:additions=[_column('_rowId','text')]
    if kind=='niveaux4':additions.append(_column('AvecReseau','boolean'))
    if kind=='niveaux5':additions.append(_column('ID_TypeNiveau_4_Fk'))
    known={c['column_name'] for c in columns};derived=[c for c in additions if c['column_name'] not in known];columns.extend(derived)
    obj.update(columns=columns,primaryKey=[pk],territorialKind=kind,territorialDerived={c['column_name'] for c in derived})
    return obj,pk,sort,None

def source_sql(obj):
    kind=obj['territorialKind'];base=db.qualified(obj['schema'],obj['name']);derived=obj['territorialDerived']
    if kind=='niveaux2' and derived:return '(SELECT v.*,'+','.join({'ID_Niveau_0':'p."ID_Niveau_0_Fk" AS "ID_Niveau_0"','ID_Niveau_1':'v."ID_Niveau_1_FK" AS "ID_Niveau_1"'}[key] for key in sorted(derived))+' FROM '+base+' v LEFT JOIN geolocalisation."T_Niveau_1" p ON p."ID_Niveau_1"=v."ID_Niveau_1_FK") v'
    if kind=='niveaux3' and derived:
        projections={'ID_Niveau_0':'p."ID_Niveau_0_Fk" AS "ID_Niveau_0"','NomNiveau_0':'c."NomNiveau_0"','ID_Niveau_1':'p."ID_Niveau_1"','NomNiveau_1':'p."NomNiveau_1"','ID_Niveau_2':'a."ID_Niveau_2"','NomNiveau_2':'a."NomNiveau_2"'}
        return '(SELECT v.*,'+','.join(projections[key] for key in sorted(derived))+' FROM '+base+' v LEFT JOIN geolocalisation."T_Niveau_2" a ON a."ID_Niveau_2"=v."ID_Niveau_2_FK" LEFT JOIN geolocalisation."T_Niveau_1" p ON p."ID_Niveau_1"=a."ID_Niveau_1_FK" LEFT JOIN geolocalisation."T_Niveau_0" c ON c."ID_Niveau_0"=p."ID_Niveau_0_Fk") v'
    if kind=='niveaux4' and derived:return '(SELECT v.*,EXISTS(SELECT 1 FROM referentiel."T_Generique" g WHERE g."ID_Generique"=v."ID_DispoReseauNiveau_4" AND g."AbrGenerique" IS NOT NULL AND g."AbrGenerique"::text<>\'Sans reseau\') AS "AvecReseau" FROM '+base+' v) v'
    if kind=='niveaux5' and derived:return '(SELECT v.*,a."ID_TypeNiveau_4_Fk" FROM '+base+' v LEFT JOIN geolocalisation."T_Niveau_4" a ON a."ID_Niveau_4"=v."ID_Niveau_4_Fk") v'
    if kind in GRAINS:return '(SELECT v.*,jsonb_build_array('+','.join('v.'+db.ident(key) for key in GRAINS[kind])+')::text AS "_rowId" FROM '+base+' v) v'
    return base+' v'

def capabilities(actor,kind=None):
    rights=access_snapshot(actor)['modules']['territoires'];manage=actor.global_admin and rights['canManage'] and not settings.DB_READ_ONLY
    return {'canManage':bool(manage and kind in MODELS),'canCreate':bool(manage and kind in MODELS),'canDelete':bool(manage and kind in MODELS),'canExport':rights['canExport'],'platformAdmin':actor.global_admin,'shared':True}

def selection(actor,kind,raw,action='read'):
    if set(raw)-{'q','filters','sortBy','sortDir','take','skip','columns','selection','timeZone'}:raise APIError('Critère territorial non autorisé.')
    obj,pk,default,_=source(actor,kind,action)
    try:filters=json.loads(raw['filters']) if isinstance(raw.get('filters'),str) else dict(raw.get('filters') or {})
    except (ValueError,TypeError):raise APIError('Filtres invalides.')
    if not isinstance(filters,dict):raise APIError('Filtres invalides.')
    provenance={key:filters.pop(key) for key in ('StructuresZone','StructuresTypeSite') if key in filters}
    if provenance and (kind!='niveaux4' or set(provenance)!={'StructuresZone','StructuresTypeSite'}):raise APIError('Le filtre de provenance des structures est incomplet ou indisponible.')
    blocked={c['column_name'] for c in obj['columns'] if c['column_name'].startswith('geometry')}
    if set(filters)&blocked:raise APIError('Filtre de géométrie non disponible.')
    search_obj={**obj,'columns':[c for c in obj['columns'] if c['column_name'] not in blocked]}
    where,values=predicate(search_obj,actor,{'q':raw.get('q',''),'filters':filters})
    if provenance:
        zone=positive(provenance['StructuresZone'],'Zone du rapport');site_type=positive(provenance['StructuresTypeSite'],'Type de site') if provenance['StructuresTypeSite'] is not None else None
        where+=' AND EXISTS(SELECT 1 FROM geolocalisation."T_Niveau_4" a LEFT JOIN geolocalisation."T_Niveau_5" s ON s."ID_Niveau_4_Fk"=a."ID_Niveau_4" WHERE a."ID_Niveau_4"=v."ID_Niveau_4" AND COALESCE(s."ID_Niveau_3_Fk",a."ID_Niveau_3_Fk")=%s AND s."ID_TypeNiveau_5_Fk" IS NOT DISTINCT FROM %s)';values.extend([zone,site_type])
    columns={c['column_name'] for c in obj['columns']};sort=raw.get('sortBy') or default;direction=str(raw.get('sortDir','asc')).lower()
    if sort not in columns or sort in blocked or direction not in {'asc','desc'}:raise APIError('Tri territorial non autorisé.')
    order='v.'+db.ident(sort)+' '+direction.upper()+' NULLS LAST'+(',v.'+db.ident(pk)+' ASC' if sort!=pk else '')
    return obj,where,values,order,sort,direction

def list_records(actor,kind,raw):
    obj,where,params,order,sort,direction=selection(actor,kind,raw);take,skip=page(raw);sql=source_sql(obj)
    count=db.one('SELECT count(*) AS n FROM '+sql+' WHERE '+where,params)['n'];total=db.one('SELECT count(*) AS n FROM '+sql)['n']
    fields=','.join('v.'+db.ident(c['column_name']) for c in obj['columns'])
    rows=db.query('SELECT '+fields+' FROM '+sql+' WHERE '+where+' ORDER BY '+order+' LIMIT %s OFFSET %s',[*params,take,skip])
    names={c['column_name'] for c in obj['columns']};records={}
    for n in range(6):
        name='NomNiveau_'+str(n);identifier=next((key for key in ('ID_Niveau_'+str(n),'ID_Niveau_'+str(n)+'_Fk','ID_Niveau_'+str(n)+'_FK') if key in names),None)
        if name in names and identifier:records[name]={'kind':'niveaux'+str(n),'idField':identifier}
    if kind=='niveaux1-historique':records['NomNiveau_1_Old']={'kind':kind,'idField':'ID_Niveau_1_Old'}
    return clean(rows),{'columns':[{'key':c['column_name'],'column_name':c['column_name'],'label':LABELS.get(c['column_name'],c['column_name']),'data_type':c['data_type']} for c in obj['columns']], 'pk':SOURCES[kind][2],'count':len(rows),'filteredCount':count,'totalCount':total,'take':take,'skip':skip,'sortBy':sort,'sortDir':direction,'note':NOTES.get(kind,''),'drilldowns':DRILLDOWNS.get(kind,{}),'records':records,'filterLabels':{key:LABELS[key] for key in ('StructuresZone','StructuresTypeSite','AvecReseau')},'filterGroups':[['StructuresZone','StructuresTypeSite']] if kind=='niveaux4' else [],'filterSources':{'StructuresZone':'niveaux3','StructuresTypeSite':'niveau5Types'} if kind=='niveaux4' else {},**capabilities(actor,kind)}

def record(actor,kind,pk,lock=False):
    source(actor,kind)
    if kind not in MODELS:raise APIError('Ce rapport est en consultation.','READ_ONLY_REGISTER',405)
    obj=model(MODELS[kind]);key=obj['primaryKey'][0]
    table=db.qualified(obj['schema'],obj['name']);identifier=positive(pk)
    if kind in territorial_contacts.KINDS:
        # Obtenir le verrou avant le nouvel instantané parent/enfant : une
        # édition SQL directe des contacts prend le même verrou via son trigger.
        if lock:db.one('SELECT '+db.ident(key)+' FROM '+table+' WHERE '+db.ident(key)+'=%s FOR UPDATE',[identifier])
        row=db.one('SELECT v.*,'+territorial_contacts.projection()+' FROM '+table+' v LEFT JOIN '+territorial_contacts.TABLE
            +' c ON c.'+db.ident(territorial_contacts.foreign_key(kind))+'=v.'+db.ident(key)+' WHERE v.'+db.ident(key)+'=%s',[identifier])
    else:
        row=db.one('SELECT v.*,v.xmin::text AS "_version" FROM '+table+' v WHERE v.'+db.ident(key)+'=%s'+(' FOR UPDATE' if lock else ''),[identifier])
    if not row:raise APIError('Territoire introuvable.','NOT_FOUND',404)
    return clean(row)

GENERIC_ALIASES={'ID_TypeNiveau_2_Fk':{2:'niveau2Types',3:'niveau3Types'},'ID_TypeNiveau_4_Fk':'niveau4Types','ID_TypeNiveau_5_Fk':'niveau5Types','ID_StatutNiveau_2':'niveau2Statuses','ID_StatutNiveau_3_Fk':'niveau3Statuses','ID_StatutNiveau_4':'niveau4Statuses','ID_StatutNiveau_5':'niveau5Statuses','ID_StatusDeploiFk':'deploymentStatuses','ID_StatutDeploieFk':'deploymentStatuses','ID_StatutDeploiementFk':'deploymentStatuses','ID_DispoReseauNiveau_4':'networkAvailabilities','ID_DispoReseauNiveau_5':'networkAvailabilities','ID_VoieAccesDPSANTFk':'dpsAccessRoutes','ID_VoieAccesANTBCZFk':'antBczAccessRoutes','ID_VoieAccesDPSBCZFk':'dpsBczAccessRoutes','ID_VoieAccesZsASFk':'zsAsAccessRoutes','ID_VoieAccesZsSiteFk':'zsSiteAccessRoutes','ID_TypeToitFk':'roofTypes'}

def references(actor,kind,current_id=None):
    source(actor,kind);options={};field_refs={};current=record(actor,kind,current_id) if current_id and kind in MODELS else {}
    # Les parents sont les seules listes hiérarchiques nécessaires aux formulaires.
    for n in range(5):
        table='T_Niveau_'+str(n);name='NomNiveau_'+str(n);pk='ID_Niveau_'+str(n)
        columns=model(table)['columns'];names={c['column_name'] for c in columns};parent=next((key for key in names if re.fullmatch(r'ID_Niveau_[0-4]_[Ff][Kk]',key)),None)
        rows=db.query('SELECT '+db.ident(pk)+' AS id,'+db.ident(name)+' AS label'+(','+db.ident(parent)+' AS "parentId"' if parent else '')+' FROM geolocalisation.'+db.ident(table)+' ORDER BY '+db.ident(name)+','+db.ident(pk))
        options['niveaux'+str(n)]=[{**row,**({'parentKey':parent,parent:row['parentId']} if parent else {})} for row in rows]
    options['niveaux1Old']=db.query('SELECT "ID_Niveau_1_Old" AS id,"NomNiveau_1_Old" AS label FROM geolocalisation."T_Niveau_1_Old" ORDER BY label,id')
    if kind in MODELS or kind in {'population-sites','statistiques-provinces','statistiques-zones'}:
        from .field_references import reference_context,reference_options
        from .reference_integration import territorial_type_visibility
        tables=([MODELS[kind]]+(['T_Niveau_4'] if kind=='niveaux5' else ['T_Niveau_5'] if kind=='niveaux4' else [])) if kind in MODELS else ['T_Niveau_5'] if kind=='population-sites' else ['T_Niveau_2'] if kind=='statistiques-provinces' else ['T_Niveau_4','T_Niveau_5']
        fields=db.query('SELECT "TableName","ColumnName" FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=\'geolocalisation\' AND "TableName"=ANY(%s::text[]) ORDER BY "TableName","ColumnName"',[tables])
        for item in fields:
            table=item['TableName'];level=int(table[-1])
            if kind not in MODELS and not item['ColumnName'].startswith('ID_TypeNiveau_'):continue
            if kind in MODELS and table!=MODELS[kind] and item['ColumnName']!='ID_TypeNiveau_'+str(level)+'_Fk':continue
            column=item['ColumnName'];context=reference_context(actor,'geolocalisation',table,column)
            visibility={'VisibleVoie':False} if column=='ID_VoieAccesDPSANTFk' else None
            choices=reference_options(actor,'geolocalisation',table,column,current.get(column),visibility)
            field_refs[column]={**context,'options':choices}
            visibility_key=territorial_type_visibility('geolocalisation',table,column)
            if visibility_key:
                available=sum(not item.get('disabled') for item in choices)
                field_refs[column].update(visibility={visibility_key:True},availableCount=available,
                    choiceMessage='' if available else 'Aucun type actif n’est proposé au niveau '+str(level)
                        +'. Dans Référentiels, vérifiez la catégorie du champ et la visibilité « Niveau territorial '+str(level)+' » des valeurs.')
            alias=GENERIC_ALIASES.get(column,column);alias=alias.get(level,column) if isinstance(alias,dict) else alias
            options[alias]=choices
            options[column]=choices
    return {'options':clean(options),'fieldReferences':clean(field_refs),'shared':True,**capabilities(actor,kind)}

def validate_body(kind,data,old=None):
    """Valider les nouvelles saisies sans invalider un historique inchangé."""
    obj=model(MODELS[kind]);columns={c['column_name']:c for c in obj['columns']};pk=obj['primaryKey'][0]
    if not isinstance(data,dict) or set(data)-set(columns) or pk in data:raise APIError('Un champ territorial n’est pas modifiable.','TERRITORIAL_VALIDATION',422)
    result=dict(data);effective={**(old or {}),**result};errors={};name='NomNiveau_1_Old' if kind=='niveaux1-historique' else 'NomNiveau_'+kind[-1]
    if old is None or name in data:
        value=data.get(name)
        if not isinstance(value,str) or not value.strip():errors[name]='Renseignez le nom.'
        else:result[name]=value.strip()
    for key,value in data.items():
        if value is None:
            if columns[key]['is_nullable']!='YES':errors[key]='Renseignez ce champ obligatoire.'
            continue
        if old is not None and value==old.get(key):continue
        if key.startswith(('Population','Km','Latitude','Longitude','Altitude')):
            try:
                if isinstance(value,bool):raise ValueError()
                number=Decimal(str(value))
                if not number.is_finite():raise ValueError()
                if key.startswith(('Population','Km')) and number<0:raise ValueError()
                if key.startswith('Population') and number!=number.to_integral_value():raise ValueError()
                if key.startswith('Latitude') and abs(number)>90 or key.startswith('Longitude') and abs(number)>180:raise ValueError()
                result[key]=number
            except (ValueError,InvalidOperation):errors[key]='Renseignez une valeur valide pour ce champ.'
        if isinstance(value,str) and any(unicodedata.category(c)=='Cs' or ord(c)<32 and c not in '\r\n\t' for c in value):errors[key]='Retirez les caractères de contrôle.'
    for key,value in tuple(result.items()):
        if key in errors:continue
        try:
            if columns[key]['data_type']=='numeric' and value is not None:
                number=Decimal(str(value));sign,digits,exponent=number.as_tuple();digits=list(digits)
                if not number.is_finite():raise ValueError()
                while len(digits)>1 and digits[-1]==0:digits.pop();exponent+=1
                value=Decimal((sign,tuple(digits),exponent)) if number else Decimal(0)
            result[key]=coerce(columns[key],value)
        except (APIError,InvalidOperation,ValueError) as exc:errors[key]=str(getattr(exc,'detail','Renseignez une valeur valide pour ce champ.'))
    effective={**(old or {}),**result}
    if kind in {f'niveaux{n}' for n in range(1,6)}:
        n=int(kind[-1]);parent=f'ID_Niveau_{n-1}_'+('Fk' if n in {1,4,5} else 'FK')
        changed=lambda key:key in result and (old is None or result[key]!=old.get(key))
        if n!=5 and (old is None or changed(parent)) and effective.get(parent) is None:errors[parent]='Choisissez le rattachement parent.'
        if n==5 and effective.get('ID_Niveau_4_Fk') is not None and (old is None or changed('ID_Niveau_4_Fk') or changed('ID_Niveau_3_Fk')):
            area=db.one('SELECT "ID_Niveau_3_Fk" FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=%s',[positive(effective['ID_Niveau_4_Fk'])])
            if not area:errors['ID_Niveau_4_Fk']='Choisissez une aire existante.'
            elif 'ID_Niveau_4_Fk' in result and ('ID_Niveau_3_Fk' not in result or effective.get('ID_Niveau_3_Fk') is None):result['ID_Niveau_3_Fk']=area['ID_Niveau_3_Fk']
            elif effective.get('ID_Niveau_3_Fk') is not None and effective['ID_Niveau_3_Fk']!=area['ID_Niveau_3_Fk']:errors['ID_Niveau_3_Fk']='La zone doit correspondre à l’aire choisie.'
        if n==5 and (old is None or changed('ID_Niveau_3_Fk') or changed('ID_Niveau_4_Fk')) and not result.get('ID_Niveau_3_Fk',effective.get('ID_Niveau_3_Fk')):errors['ID_Niveau_3_Fk']='Choisissez la zone de santé du site.'
        if n==4 and old and changed('ID_Niveau_3_Fk'):
            if db.one('SELECT 1 AS linked FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_4_Fk"=%s AND "ID_Niveau_3_Fk" IS NOT NULL AND "ID_Niveau_3_Fk" IS DISTINCT FROM %s LIMIT 1',[old['ID_Niveau_4'],result['ID_Niveau_3_Fk']]):errors['ID_Niveau_3_Fk']='Cette aire possède des sites rattachés à une autre zone. Corrigez leurs rattachements avant de déplacer l’aire.'
        lat='LatitudeNiveau_'+str(n);lon='LongitudeNiveau_'+str(n)
        if changed(lat) or changed(lon):
            if (effective.get(lat) is None)!=(effective.get(lon) is None):errors[lat]='Renseignez ensemble latitude et longitude.'
    if errors:raise APIError(errors,'TERRITORIAL_VALIDATION',422)
    return result

def save(actor,kind,body,pk=None,delete=False):
    source(actor,kind,'manage');db.ensure_writable()
    if kind not in MODELS:raise APIError('Rapport en lecture seule.','READ_ONLY_REGISTER',405)
    if not actor.global_admin:raise APIError('Le découpage partagé est géré par la plateforme.','GLOBAL_ADMIN_REQUIRED',403)
    if not isinstance(body,dict):raise APIError('Objet JSON attendu.')
    data=dict(body);request_id=data.pop('requestId',None);revision=data.pop('_version',None)
    try:
        if not isinstance(request_id,str) or str(uuid.UUID(request_id))!=request_id.lower():raise ValueError()
    except ValueError:raise APIError('Identifiant de demande invalide.')
    request_id=request_id.lower()
    operation='TERRITORIAL_'+('DELETE' if delete else 'UPDATE' if pk else 'CREATE');obj=model(MODELS[kind]);key=obj['primaryKey'][0]
    fingerprint=hashlib.sha256(json.dumps({'kind':kind,'pk':str(pk) if pk is not None else None,'data':data,'revision':revision,'delete':delete},sort_keys=True,separators=(',',':'),cls=ExactEncoder).encode()).hexdigest()
    with transaction.atomic():
        hierarchy_lock()
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',['territoires:'+str(actor.pk)+':'+request_id])
        previous=db.one('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData" @> %s::jsonb ORDER BY "IdLog" DESC LIMIT 1',[operation,json.dumps({'requestId':request_id,'_actor':{'IdUser':actor.pk}})])
        if previous:
            if previous['NewData'].get('fingerprint')!=fingerprint:raise APIError('Cette demande a déjà un autre contenu.','REQUEST_CONFLICT',409)
            return previous['NewData']['result'],True
        old=record(actor,kind,pk,lock=True) if pk is not None else None
        if old and (not isinstance(revision,str) or old['_version']!=revision):raise APIError('La fiche a changé. Rechargez-la avant de confirmer.','VERSION_CONFLICT',409)
        if not old and revision is not None:raise APIError('Révision inattendue à la création.')
        if delete and data:raise APIError('La suppression ne comporte pas de modification de champs.')
        try:
            if delete:
                territorial_contacts.save(actor,kind,positive(pk),{},delete=True)
                result=mutate(obj['name'],actor,keys={key:positive(pk)},operation='delete',hard=True)
            else:
                parent_data,contacts=territorial_contacts.split(kind,data,old)
                prepared=validate_body(kind,parent_data,old)
                result=mutate(obj['name'],actor,prepared,keys={key:positive(pk)} if pk else None,operation='update' if pk else 'create')
                territorial_contacts.save(actor,kind,result[key],contacts)
                result=record(actor,kind,result[key])
        except IntegrityError as exc:
            state=getattr(exc.__cause__,'sqlstate',None)
            if state=='23503':raise APIError('Ce territoire est lié à d’autres enregistrements. Vérifiez les rattachements avant de poursuivre.','TERRITORIAL_LINKED',409) from exc
            if state=='23505':raise APIError('Ce code ou identifiant existe déjà. Vérifiez la fiche.','TERRITORIAL_DUPLICATE',409) from exc
            raise
        audit(obj,operation,new={'requestId':request_id,'fingerprint':fingerprint,'result':result},actor=actor)
        return result,False

def hierarchy_lock():
    """Ordre commun aux nouvelles fiches et aux routes géographiques historiques."""
    db.query("SELECT pg_advisory_xact_lock(hashtextextended('geolocalisation:hierarchy-writes',0))")

def workbook(actor,kind,raw,file_format='xlsx'):
    from .table_preferences import export_keys
    from .tabular_exports import write_tabular
    wanted=export_keys(actor,INTERFACE_KEYS.get(kind,'territoires.invalid'),raw)
    obj,where,params,order,sort,direction=selection(actor,kind,raw,'export');available={c['column_name']:c for c in obj['columns']}
    if not wanted or any(key not in available for key in wanted):raise APIError('Colonnes d’export invalides.')
    if raw.get('selection') is not None:
        try:selected=json.loads(raw['selection'])
        except (ValueError,TypeError):raise APIError('Sélection invalide.')
        if not isinstance(selected,list) or not 1<=len(selected)<=1000:raise APIError('Sélectionnez de 1 à 1 000 lignes.')
        pk=SOURCES[kind][2]
        if pk=='_rowId':
            if any(not isinstance(value,str) or len(value)>300 for value in selected):raise APIError('Sélection invalide.')
            where+=' AND v."_rowId"=ANY(%s::text[])';params.append(selected)
        else:where+=' AND v.'+db.ident(pk)+'=ANY(%s::integer[])';params.append([positive(value) for value in selected])
    fields=[{**available[key],'label':LABELS.get(key,key),**({'data_type':'text'} if key.lower().startswith(('id','code','uid','iso')) else {})} for key in wanted]
    zone=document_zone(raw);generated=datetime.now(zone);stream=SpooledTemporaryFile(max_size=8*1024*1024,mode='w+b')
    context={'title':TITLES[kind],'scope':'Référentiel territorial partagé','generated':generated.strftime('%d/%m/%Y %H:%M'),'zone':str(zone),'tz':zone,'source':obj['schema']+'.'+obj['name'],'raw':raw,'filters':{},'order':LABELS.get(sort,sort)+' '+direction}
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT '+','.join('v.'+db.ident(key) for key in wanted)+' FROM '+source_sql(obj)+' WHERE '+where+' ORDER BY '+order+' LIMIT %s',[*params,MAX_EXPORT_ROWS+1])
            def rows():
                while batch:=cursor.fetchmany(500):
                    for values_row in batch:yield dict(zip(wanted,values_row))
            count=write_tabular(stream,fields,rows(),context,file_format)
        stream.seek(0);return stream,count,'SauverNdeko_Territoires_'+kind+'_'+generated.strftime('%Y-%m-%d')+'.'+file_format
    except Exception:stream.close();raise

class TerritorialRegisterView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,kind,pk=None):
        if pk is not None:
            if request.query_params:raise APIError('La fiche ne comporte pas de filtre.')
            return ok(record(request.user,kind,pk),meta=capabilities(request.user,kind))
        rows,meta=list_records(request.user,kind,request.query_params.dict());return ok(rows,meta=meta)
    def post(self,request,kind):
        result,replay=save(request.user,kind,request.data);return ok(result,status=200 if replay else 201,meta={'replayed':replay})
    def put(self,request,kind,pk):
        result,replay=save(request.user,kind,request.data,pk);return ok(result,meta={'replayed':replay})
    patch=put
    def delete(self,request,kind,pk):
        result,replay=save(request.user,kind,request.data,pk,delete=True);return ok(result,meta={'replayed':replay})

class TerritorialReferencesView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,kind):
        if set(request.query_params)-{'currentId'}:raise APIError('Critère non autorisé.')
        return ok(references(request.user,kind,request.query_params.get('currentId')))

class TerritorialExcelView(ExcelDownloadView):
    def get(self,request,kind):
        stream,count,filename=workbook(request.user,kind,request.query_params.dict())
        result=FileResponse(stream,as_attachment=True,filename=filename,content_type=XLSX_MEDIA_TYPE);result['X-Export-Row-Count']=str(count);result['Cache-Control']='no-store, private';return result

class TerritorialCSVView(TerritorialExcelView):
    renderer_classes=[ExactJSONRenderer,CSVFileRenderer]
    def get(self,request,kind):
        stream,count,filename=workbook(request.user,kind,request.query_params.dict(),'csv')
        result=FileResponse(stream,as_attachment=True,filename=filename,content_type='text/csv; charset=utf-8');result['X-Export-Row-Count']=str(count);result['Cache-Control']='no-store, private';return result

class TerritorialOverviewView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        if set(request.query_params)-{'timeZone'}:raise APIError('Critère non autorisé.')
        actor=request.user;require_module(actor,'territoires');zone=document_zone(request.query_params.dict())
        # Une requête SQL compose les effectifs sans multiplier les lignes de vues agrégées.
        metric_kinds={**{f'niveaux{n}':f'niveaux{n}' for n in range(6)},'asSansSite':'as-sans-site','zsSansAs':'zs-sans-as'}
        targets={key:{'kind':kind,'filters':{}} for key,kind in metric_kinds.items()}
        expressions=[]
        for key,kind in metric_kinds.items():
            obj,*_=source(actor,kind);expressions.append('(SELECT count(*) FROM '+source_sql(obj)+') AS '+db.ident(key))
        chart_source=source_sql(source(actor,'niveaux5')[0])
        for key,field in {'sitesSansAire':'ID_Niveau_4_Fk','sitesSansZone':'ID_Niveau_3_Fk'}.items():
            expressions.append('(SELECT count(*) FROM '+chart_source+' WHERE v.'+db.ident(field)+' IS NULL) AS '+db.ident(key));targets[key]={'kind':'niveaux5','filters':{field:None}}
        province_sql='SELECT v."ID_Niveau_1",v."NomNiveau_1",count(*) AS count FROM '+chart_source+' GROUP BY v."ID_Niveau_1",v."NomNiveau_1" ORDER BY count DESC,v."NomNiveau_1" NULLS LAST'
        type_sql='SELECT v."ID_TypeNiveau_5_Fk",v."Type_Niveau_5",count(*) AS count FROM '+chart_source+' GROUP BY v."ID_TypeNiveau_5_Fk",v."Type_Niveau_5" ORDER BY count DESC,v."Type_Niveau_5" NULLS LAST'
        expressions += ['(SELECT COALESCE(jsonb_agg(to_jsonb(c)),\'[]\'::jsonb) FROM ('+province_sql+') c) AS "provinceChart"','(SELECT COALESCE(jsonb_agg(to_jsonb(c)),\'[]\'::jsonb) FROM ('+type_sql+') c) AS "typeChart"']
        row=db.one('SELECT '+','.join(expressions));provinces=row.pop('provinceChart');types=row.pop('typeChart')
        return ok({'metrics':row,'metricTargets':targets,'charts':{'structuresParProvince':provinces,'sitesParType':types},'generatedAt':datetime.now(zone),'shared':True,'note':'Les données territoriales sont communes aux entreprises. Les rapports de population sont présentés séparément sans totaliser des périmètres potentiellement recouvrants. Une aire est facultative pour un site ; « sans zone » désigne l’absence de zone directement enregistrée, même si son aire permet un rattachement hérité.'},meta=capabilities(actor))
