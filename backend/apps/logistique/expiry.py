"""Politique de conservation propre à l’entreprise ; les vues et triggers en sont le socle."""
from django.db import transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.permissions import IsERPAdmin
from apps.core.module_access import require_module
from apps.core.repository import audit,clean
from apps.core.responses import APIError,ok
from apps.core.tenancy import require_entity


def policy(actor):
    require_module(actor,'logistique','read')
    entity=require_entity(actor)
    return clean(db.one('''SELECT "IdEntite","NomEntite","AlertePeremptionJours","BloquerLotsPerimes",xmin::text AS "_version" FROM systeme."T_Entite" WHERE "IdEntite"=%s''',[entity]))


def update(actor,data):
    require_module(actor,'logistique','manage');db.ensure_writable()
    if not actor.global_admin:raise APIError('Ce paramétrage est réservé à l’administrateur de plateforme.','GLOBAL_ADMIN_REQUIRED',403)
    entity=require_entity(actor)
    if not isinstance(data,dict) or set(data)!={'IdEntite','AlertePeremptionJours','BloquerLotsPerimes','_version'}:raise APIError('Paramétrage de péremption invalide.')
    if type(data['IdEntite']) is not int or data['IdEntite']!=entity:raise APIError('L’entreprise active a changé. Rechargez la fiche.','ENTITY_MISMATCH',403)
    days=data['AlertePeremptionJours'];blocked=data['BloquerLotsPerimes'];version=data['_version']
    if type(days) is not int or not 0<=days<=3650 or type(blocked) is not bool or not isinstance(version,str):raise APIError('Indiquez un délai de 0 à 3650 jours et une règle de sortie valide.')
    with transaction.atomic():
        old=db.one('''SELECT "IdEntite","NomEntite","AlertePeremptionJours","BloquerLotsPerimes",xmin::text AS "_version" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR UPDATE''',[entity])
        if old['_version']!=version:raise APIError('Le paramétrage a changé. Rechargez la fiche.','VERSION_CONFLICT',409)
        db.query('''UPDATE systeme."T_Entite" SET "AlertePeremptionJours"=%s,"BloquerLotsPerimes"=%s WHERE "IdEntite"=%s''',[days,blocked,entity])
        row=policy(actor)
        audit({'schema':'systeme','name':'T_Entite'},'EXPIRY_POLICY',old,row,actor)
        return row


class ExpiryPolicyView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):return ok(policy(request.user))
    def put(self,request):return ok(update(request.user,request.data),message='Règles de péremption enregistrées.')
