"""Recherche paginée de lieux existants ; aucun identifiant déduit d'un nom libre."""
from rest_framework.views import APIView
from apps.core import db
from apps.core.permissions import IsERPAdmin
from apps.core.repository import positive,clean,page
from apps.core.responses import APIError,ok

def validate_destination(data,old=None):
    if 'ID_DestinationFk' not in data or data['ID_DestinationFk'] is None or old and data['ID_DestinationFk']==old.get('ID_DestinationFk'):return
    row=db.one('SELECT id,label,"EstCoherente" FROM geolocalisation."V_DestinationLogistique" WHERE id=%s',[positive(data['ID_DestinationFk'])])
    if not row or not row['EstCoherente']:raise APIError({'ID_DestinationFk':'Choisissez une destination de la liste dont la hiérarchie est complète.'},'DESTINATION_INVALID',400)

class DestinationsView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        raw=request.query_params
        if set(raw)-{'q','take','skip','id'}:raise APIError('Critère de destination non autorisé.')
        take,skip=page(raw);where='"EstCoherente"';args=[]
        if raw.get('q'):
            q=raw['q'].strip()
            if len(q)>200:raise APIError('La recherche est trop longue.')
            where+=' AND (label ILIKE %s OR "CodeNiveau_5" ILIKE %s)';args.extend(['%'+q+'%']*2)
        if raw.get('id'):where+=' AND id=%s';args.append(positive(raw['id']))
        total=db.one('SELECT count(*) AS n FROM geolocalisation."V_DestinationLogistique" WHERE "EstCoherente"')['n']
        count=db.one('SELECT count(*) AS n FROM geolocalisation."V_DestinationLogistique" WHERE '+where,args)['n']
        rows=db.query('SELECT id,label FROM geolocalisation."V_DestinationLogistique" WHERE '+where+' ORDER BY label,id LIMIT %s OFFSET %s',[*args,take,skip])
        return ok(clean(rows),meta={'totalCount':total,'filteredCount':count,'take':take,'skip':skip})
