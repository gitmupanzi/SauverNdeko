"""Fiche lot et journal paginé : aucune modification du stock ou de ses ventilations."""
from django.http import FileResponse
from rest_framework.views import APIView
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import view
from apps.core.repository import clean,get_record,positive
from apps.core.responses import APIError,ok
from .reads import QUERY_KEYS,read_page,read_scope
from .excel import ExcelDownloadView,XLSX_MEDIA_TYPE,scope_workbook


def lot_detail(actor,pk):
    require_module(actor,'logistique')
    return clean(get_record(view('logistique','V_RegistreLots'),actor,{'ID_LotArticle':positive(pk)}))


def movement_source(actor,pk,raw,export=False):
    # L’accès au lot est vérifié même pour un journal vide. Aucun journal d’un autre lot n’est lu.
    lot_detail(actor,pk)
    if set(raw)-(QUERY_KEYS|{'sens'}|({'columns'} if export else set())):raise APIError('Critère de lot non autorisé.')
    senses={'all':'TRUE','entree':'"SigneStock"=1','sortie':'"SigneStock"=-1','neutre':'COALESCE("SigneStock",0)=0'}
    sense=raw.get('sens') or 'all'
    if sense not in senses:raise APIError('Sens de mouvement invalide.')
    # Identifiant validé numériquement ; ce prédicat limite aussi le compteur total du journal.
    condition='"ID_LotArticleFk"='+str(positive(pk))
    obj={**view('logistique','V_RegistreMouvementLot'),'_date_field':'DateMvt','_base_condition':condition}
    return obj,condition+' AND ('+senses[sense]+')'


def lot_movements(actor,pk,raw):
    obj,condition=movement_source(actor,pk,raw)
    rows,meta,_=read_page(obj,actor,raw,condition)
    return rows,meta


def lot_movement_workbook(actor,pk,raw):
    obj,condition=movement_source(actor,pk,raw,True)
    _,where,values,order,sort,direction,applied=read_scope(obj,actor,raw,condition)
    return scope_workbook(actor,'lot-'+str(positive(pk)),obj,raw,where,values,order,sort,direction,applied,'Mouvements du lot')


class LotDetailView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk):
        if request.query_params:raise APIError('Aucun critère attendu pour la fiche lot.')
        return ok(lot_detail(request.user,pk))


class LotMovementsView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk):
        rows,meta=lot_movements(request.user,pk,request.query_params.dict())
        return ok(rows,meta=meta)


class LotMovementsExcelView(ExcelDownloadView):
    def get(self,request,pk):
        stream,count,filename=lot_movement_workbook(request.user,pk,request.query_params.dict())
        response=FileResponse(stream,as_attachment=True,filename=filename,content_type=XLSX_MEDIA_TYPE)
        response['X-Export-Row-Count']=str(count)
        response['Cache-Control']='no-store, private'
        return response
