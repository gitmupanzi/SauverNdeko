"""Contexte d'entreprise vérifié, distinct du compte authentifié."""
from apps.core import db
from apps.core.responses import APIError

ROOTS={'T_Article','T_Commande','T_Client'}

def bind_context(actor,request):
    raw=request.headers.get('X-Entite-ID')
    if raw in (None,''):return actor
    if not str(raw).isascii() or not str(raw).isdigit() or int(raw)<=0:
        raise APIError('Choisissez une entreprise valide.','ENTITY_CONTEXT_INVALID',400)
    entity=int(raw)
    if not actor.global_admin and entity!=actor.row.get('IdEntiteFk'):
        raise APIError('Cette entreprise ne fait pas partie de votre accès.','ENTITY_CONTEXT_FORBIDDEN',403)
    row=db.one('SELECT "IdEntite","ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s',[entity])
    if not row:raise APIError('Entreprise introuvable.','ENTITY_CONTEXT_INVALID',404)
    actor._context_entity=entity
    actor._context_active=row['ValideEntite'] is not False
    return actor

def require_entity(actor):
    if actor.global_admin and not hasattr(actor,'_context_entity'):
        raise APIError('Choisissez une entreprise avant d’enregistrer.','ENTITY_REQUIRED',409)
    value=actor.organisation
    if not value:raise APIError('Une entreprise est requise.','ENTITY_REQUIRED',409)
    row=db.one('SELECT "ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s',[value])
    if not row or row['ValideEntite'] is False:
        raise APIError('Les écritures de cette entreprise sont désactivées.','ENTITY_INACTIVE',409)
    return value

def document_entity(row):
    value=row.get('IdEntiteFk')
    if value is None:raise APIError('Le rattachement de cet enregistrement doit être vérifié.','ENTITY_UNRESOLVED',409)
    return value

def assert_document(actor,row):
    entity=require_entity(actor)
    if document_entity(row)!=entity:raise APIError('Cet enregistrement appartient à une autre entreprise.','ENTITY_MISMATCH',403)
    return entity

def read_entity(actor):
    return actor.organisation if not actor.global_admin or hasattr(actor,'_context_entity') else None

def validate_tiers(actor,data,old=None):
    effective={**(old or {}),**data};key=effective.get('ID_TiersFk')
    if key is None:return
    row=db.one('SELECT "ID_Client","IdEntiteFk","Nom","Actif" FROM logistique."T_Client" WHERE "ID_Client"=%s',[key])
    if not row or row['IdEntiteFk']!=effective.get('IdEntiteFk',actor.organisation):
        raise APIError({'ID_TiersFk':'Choisissez un tiers de cette entreprise.'},'TIERS_SCOPE',403)
    if (not old or old.get('ID_TiersFk')!=key) and not row['Actif']:
        raise APIError({'ID_TiersFk':'Ce tiers est archivé.'},'TIERS_ARCHIVED',409)
    if not old or old.get('ID_TiersFk')!=key or not effective.get('NomClientSaisi'):data['NomClientSaisi']=row['Nom']
