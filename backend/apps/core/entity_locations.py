"""Localisations d'une entreprise : même transaction que sa fiche et son logo."""
from decimal import Decimal, InvalidOperation
from . import db
from .responses import APIError
from .repository import audit,clean,positive

FIELDS={'IdNiveau_3_Fk','IdNiveau_4_Fk','IdNiveau_5_Fk','Latitude','Longitude','AdresseDetaillee'}
COLLECTION_REVISION_SQL='md5(COALESCE(jsonb_agg(jsonb_build_array(l."IdEntiteLocalisation",l.xmin::text,to_jsonb(l)) ORDER BY l."IdEntiteLocalisation"),\'[]\'::jsonb)::text)'

def snapshot_projection():
    """Projection latérale : points et révision issus du même instantané SQL."""
    fields=sorted(FIELDS|{'IdEntiteLocalisation'})
    values=','.join("'"+key+"',l."+db.ident(key) for key in fields)+",'_version',l.xmin::text"
    return COLLECTION_REVISION_SQL+' AS "CollectionRevision",COALESCE(jsonb_agg(jsonb_build_object('+values+') ORDER BY l."IdEntiteLocalisation"),\'[]\'::jsonb) AS "Localisations"'

def profile_revision(entity,parent_revision,collection_revision=None):
    """Révision opaque du parent ET de sa collection, y compris les lignes omises.

    Le verrou de l'entreprise sérialise les écritures de ses points. Le contenu
    est inclus avec xmin afin de détecter également les modifications réalisées
    plusieurs fois dans une même transaction PostgreSQL.
    """
    if collection_revision is None:
        collection_revision=db.one('SELECT '+COLLECTION_REVISION_SQL+' AS revision FROM systeme."T_Entite_Localisation" l WHERE l."IdEntiteFk"=%s',[entity])['revision']
    return 'entity:'+str(parent_revision)+':'+collection_revision

def lock_legacy_owners(obj,actor,body,keys):
    """Même ordre parent/enfants pour l'ancienne route et la fiche imbriquée."""
    from .repository import get_record
    before=get_record(obj,actor,keys) if keys else None
    owners={before['IdEntiteFk']} if before else set()
    if isinstance(body,dict) and body.get('IdEntiteFk') is not None:
        owners.add(positive(body['IdEntiteFk'],'Entreprise'))
    elif not before and not actor.global_admin:
        owners.add(actor.organisation)
    for owner in sorted(value for value in owners if value is not None):
        db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR UPDATE',[owner])
    return owners

def locations(entity):
    return clean(db.query('SELECT "IdEntiteLocalisation",'+','.join(db.ident(key) for key in sorted(FIELDS))+',xmin::text AS "_version" FROM systeme."T_Entite_Localisation" WHERE "IdEntiteFk"=%s ORDER BY "IdEntiteLocalisation"',[entity]))

def geographical_references():
    result={}
    for n in (3,4,5):
        parent=(',"ID_Niveau_3_Fk" AS "parent3"' if n==4 else ',"ID_Niveau_3_Fk" AS "parent3","ID_Niveau_4_Fk" AS "parent4"' if n==5 else '')
        if n==5:
            result['niveaux5']=db.query('SELECT n."ID_Niveau_5" AS id,n."NomNiveau_5" AS label,COALESCE(n."ID_Niveau_3_Fk",p."ID_Niveau_3_Fk") AS "parent3",n."ID_Niveau_4_Fk" AS "parent4" FROM geolocalisation."T_Niveau_5" n LEFT JOIN geolocalisation."T_Niveau_4" p ON p."ID_Niveau_4"=n."ID_Niveau_4_Fk" ORDER BY label,n."ID_Niveau_5"')
            continue
        result['niveaux'+str(n)]=db.query('SELECT "ID_Niveau_'+str(n)+'" AS id,"NomNiveau_'+str(n)+'" AS label'+parent+' FROM geolocalisation."T_Niveau_'+str(n)+'" ORDER BY label,"ID_Niveau_'+str(n)+'"')
    return result

def prepared(row):
    if not isinstance(row,dict) or set(row)-FIELDS-{'IdEntiteLocalisation','_version'}:raise APIError('Une localisation contient un champ non autorisé.','ENTITY_LOCATION_VALIDATION',422)
    data={};errors={}
    for key in FIELDS:
        value=row.get(key)
        if key.startswith('IdNiveau'):
            data[key]=positive(value,'Localisation') if value not in (None,'') else None
        elif key in {'Latitude','Longitude'}:
            if value in (None,''):data[key]=None;continue
            try:
                if type(value) is bool:raise ValueError()
                number=Decimal(str(value));maximum=90 if key=='Latitude' else 180
                if not number.is_finite() or abs(number)>maximum or number.as_tuple().exponent < -6:raise ValueError()
                data[key]=number
            except (ValueError,InvalidOperation):errors[key]='Utilisez une coordonnée valide avec six décimales au maximum.'
        else:
            if value is not None and (not isinstance(value,str) or len(value)>2000):errors[key]='Utilisez au maximum 2 000 caractères.'
            else:data[key]=value.strip() or None if isinstance(value,str) else None
    if (data.get('Latitude') is None)!=(data.get('Longitude') is None):errors['Latitude']='Renseignez ensemble la latitude et la longitude.'
    parents={}
    for n in (3,4,5):
        value=data.get('IdNiveau_'+str(n)+'_Fk')
        if value is None:continue
        parent=(',"ID_Niveau_3_Fk" AS p3' if n==4 else ',"ID_Niveau_3_Fk" AS p3,"ID_Niveau_4_Fk" AS p4' if n==5 else '')
        found=db.one('SELECT "ID_Niveau_'+str(n)+'" AS id'+parent+' FROM geolocalisation."T_Niveau_'+str(n)+'" WHERE "ID_Niveau_'+str(n)+'"=%s',[value])
        if found and n==5 and found.get('p3') is None and found.get('p4') is not None:
            inherited=db.one('SELECT "ID_Niveau_3_Fk" AS p3 FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=%s',[found['p4']])
            found['p3']=(inherited or {}).get('p3')
        if not found:errors['IdNiveau_'+str(n)+'_Fk']='Choisissez une localisation existante.'
        else:parents[n]=found
    if 4 in parents and data.get('IdNiveau_3_Fk') is not None and parents[4]['p3']!=data['IdNiveau_3_Fk']:errors['IdNiveau_4_Fk']='Ce niveau ne dépend pas du niveau 3 sélectionné.'
    if 5 in parents:
        for n in (3,4):
            if data.get('IdNiveau_'+str(n)+'_Fk') is not None and parents[5]['p'+str(n)]!=data['IdNiveau_'+str(n)+'_Fk']:errors['IdNiveau_5_Fk']='Ce niveau ne dépend pas des parents sélectionnés.'
    if not any(data.get(key) is not None for key in FIELDS):errors['AdresseDetaillee']='Renseignez au moins une adresse ou une localisation.'
    if errors:raise APIError({'Localisations':errors},'ENTITY_LOCATION_VALIDATION',422)
    return data

def save_locations(actor,entity,rows):
    """La liste reçue remplace les points de la seule entreprise déjà autorisée."""
    from django.db import IntegrityError
    if not isinstance(rows,list) or len(rows)>100:raise APIError({'Localisations':'Ajoutez au maximum 100 localisations.'},'ENTITY_LOCATION_VALIDATION',422)
    old=db.query('SELECT *,xmin::text AS "_version" FROM systeme."T_Entite_Localisation" WHERE "IdEntiteFk"=%s ORDER BY "IdEntiteLocalisation" FOR UPDATE',[entity]);by_id={r['IdEntiteLocalisation']:r for r in old}
    seen=set();staged=[]
    for row in rows:
        data=prepared(row);identifier=row.get('IdEntiteLocalisation')
        if identifier is not None:
            identifier=positive(identifier,'Localisation')
            if identifier in seen or identifier not in by_id:raise APIError({'Localisations':'Une localisation est dupliquée ou appartient à une autre entreprise.'},'ENTITY_LOCATION_VALIDATION',422)
            if not isinstance(row.get('_version'),str) or row['_version']!=by_id[identifier]['_version']:raise APIError('Une localisation a changé. Rechargez la fiche.','ENTITY_LOCATION_CONFLICT',409)
            seen.add(identifier)
        elif row.get('_version') is not None:raise APIError('Une nouvelle localisation ne comporte pas de révision.')
        staged.append((identifier,data))
    obj={'schema':'systeme','name':'T_Entite_Localisation'}
    for row in old:
        if row['IdEntiteLocalisation'] in seen:continue
        try:
            from django.db import transaction
            with transaction.atomic():db.query('DELETE FROM systeme."T_Entite_Localisation" WHERE "IdEntiteLocalisation"=%s',[row['IdEntiteLocalisation']])
        except IntegrityError as error:raise APIError({'Localisations':'Cette localisation est utilisée. Conservez-la ou déplacez d’abord les affectations liées.'},'ENTITY_LOCATION_IN_USE',409) from error
        audit(obj,'DELETE',old=row,actor=actor)
    for identifier,data in staged:
        before=by_id.get(identifier)
        if before and all(before.get(key)==value for key,value in data.items()):continue
        fields=sorted(data)
        if identifier:
            saved=db.one('UPDATE systeme."T_Entite_Localisation" SET '+','.join(db.ident(key)+'=%s' for key in fields)+' WHERE "IdEntiteLocalisation"=%s RETURNING *',[*[data[key] for key in fields],identifier])
        else:
            saved=db.one('INSERT INTO systeme."T_Entite_Localisation" ("IdEntiteFk",'+','.join(db.ident(key) for key in fields)+') VALUES ('+','.join(['%s']*(len(fields)+1))+') RETURNING *',[entity,*[data[key] for key in fields]])
        audit(obj,'UPDATE' if before else 'INSERT',old=before,new=saved,actor=actor)
