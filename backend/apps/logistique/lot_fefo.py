"""Péremption propre au lot et suggestion FEFO ; aucune écriture ni affectation implicite."""
from decimal import Decimal
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.repository import get_record, positive, clean
from apps.core.registry import model
from apps.core.responses import APIError, ok
from apps.core.tenancy import assert_document
from .quantities import for_unit


def proposal(actor,article_id,params):
    require_module(actor,'logistique','read')
    article=get_record(model('T_Article'),actor,{'ID_Article':positive(article_id)})
    assert_document(actor,article)
    amount=for_unit(params.get('quantite'),article['ID_UniteFk'],'quantite')
    include=params.get('inclurePerimes','false')
    if include not in ('true','false'):raise APIError('Choix de péremption invalide.')
    from .expiry import policy
    rules=policy(actor)
    if include=='true' and rules['BloquerLotsPerimes'] and not actor.global_admin:raise APIError('Les lots périmés sont bloqués dans cette entreprise.','EXPIRED_LOT_BLOCKED',409)
    rows=db.query('''SELECT * FROM logistique."V_LotDisponibilite" WHERE "ID_ArticleFk"=%s AND "Actif" IS TRUE AND "StockLot">0
       ORDER BY "DatePeremptionLot" NULLS LAST,"NumeroLot","ID_LotArticle"''',[article_id])
    left=amount;selected=[]
    for row in rows:
        if left==0:break
        if row['EstPerime'] and include!='true':continue
        take=min(left,row['StockLot']);left-=take
        selected.append({'ID_LotArticle':row['ID_LotArticle'],'NumeroLot':row['NumeroLot'],'DatePeremptionLot':row['DatePeremptionLot'],
          'Quantite':take,'StockLot':row['StockLot'],'EstPerime':row['EstPerime'],'EtatPeremptionLot':row['EtatPeremptionLot']})
    return clean({'politiquePeremption':rules,'ID_Article':article_id,'quantiteDemandee':amount,'quantiteProposee':amount-left,'resteSansAffectation':left,
       'Lots':selected,'lotsDisponibles':rows,'inclutPerimes':any(row['EstPerime'] for row in selected),
       'message':'Proposition à confirmer. Vérifiez les lots réellement prélevés.'})


class LotFefoView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk):return ok(proposal(request.user,positive(pk),request.query_params))
