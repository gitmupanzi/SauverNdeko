"""Portail Caisse : routes fermées, mêmes périmètres pour listes et exports."""
from datetime import datetime
from tempfile import SpooledTemporaryFile

from django.db import DatabaseError
from django.http import FileResponse
from rest_framework.views import APIView

from apps.core import db
from apps.core.parsers import ExactJSONParser
from apps.core.permissions import HasModuleAccess
from apps.core.responses import APIError, ExactJSONRenderer, ok
from apps.core.tabular_exports import selected_scope, write_tabular
from apps.logistique.excel import ExcelDownloadView, CSVFileRenderer, ExcelFileRenderer, MAX_EXPORT_ROWS, XLSX_MEDIA_TYPE
from . import services as service, validation
from .batches import CREATE, create_batch

LABELS = {
 'IdCaisse':'Identifiant caisse','CodeCaisse':'Code caisse','NomCaisse':'Caisse','NomEntite':'Entreprise',
 'DeviseCode':'Devise','DeviseLibelle':'Libellé devise','IdDeviseFk':'Identifiant devise','TypeCaisse':'Type de caisse',
 'Responsable':'Responsable','Actif':'Active','MontantCaisse':'Solde enregistré','SoldeTheorique':'Solde théorique',
 'EcartsRapprochement':'Écart de rapprochement','NombreEcritures':'Écritures validées','NbBrouillons':'Brouillons',
 'DerniereClotureLe':'Dernière clôture','CreeLe':'Créé le','ModifieLe':'Modifié le',
 'IdPaiement':'Identifiant écriture','CodePaiement':'Écriture','DatePaiement':'Date et heure',
 'LibellePaiement':'Libellé','ReferenceExterne':'Référence','SensMouvement':'Sens (+1 entrée / −1 sortie)',
 'EtatEcriture':'État','MontantPaiement':'Montant','MontantSigne':'Montant signé','SoldeApres':'Solde après',
 'TypePaiement':'Type de paiement','NomTiers':'Tiers','Auteur':'Auteur','Validateur':'Validé par','ValideLe':'Validé le',
 'ObsPaiement':'Observations','ValidePaiement':'Active','CodeFactureFk':'Facture',
 'CodePaiementOrigine':'Écriture d’origine','CodeCompensateur':'Contrepassation','IdReglementFk':'Identifiant règlement',
 'ID_ClotureCaisse':'Identifiant clôture','ClotureLe':'Date et heure de clôture','MontantCompte':'Montant compté',
 'Ecart':'Écart de clôture','Motif':'Motif',
 'ModeValidation':'Mode de validation','MecanismeValidation':'Mécanisme de validation',
 'ValidationDesigneeRequise':'Agent désigné requis','EntreesBrouillon':'Entrées en brouillon',
 'SortiesBrouillon':'Sorties en brouillon','SoldePrevisionnel':'Solde prévisionnel',
}


class CashView(APIView):
    permission_classes = [HasModuleAccess]
    parser_classes = [ExactJSONParser]

    def create(self, request, kind):
        if isinstance(request.data, dict) and 'rows' in request.data:
            result, replayed = create_batch(request.user, kind, request.data)
            return ok(result, status=200 if replayed else 201, meta={'replayed': replayed})
        return ok(CREATE[kind](request.user, request.data), status=201)

    def handle_exception(self, exc):
        if isinstance(exc,DatabaseError) and getattr(exc.__cause__,'sqlstate',None) in {'P0001','23514','23503','23505','55000','40001','40P01','55P03'}:
            # Aucun détail technique SQL ni donnée d’une autre entreprise.
            exc = APIError('Opération refusée. Vérifiez le solde disponible, les références, la clôture et l’état de la fiche.','CAISSE_CONFLICT',409)
        return super().handle_exception(exc)


class ContextView(CashView):
    def get(self,request): return ok(service.capabilities(request.user))


class EntitiesView(CashView):
    def get(self,request): return ok(service.entities(request.user))


class ReferencesView(CashView):
    def get(self,request): return ok(service.references(request.user))


class SynthesisView(CashView):
    def get(self,request): return ok(service.synthesis(request.user,request.query_params.dict()))


class RegisterView(CashView):
    def get(self,request,kind): return ok(service.list_data(request.user,kind,request.query_params.dict()))


class CashAccountsView(CashView):
    def get(self,request,pk=None): return ok(service.detail(request.user,'caisses',pk) if pk else service.list_data(request.user,'caisses',request.query_params.dict()))
    def post(self,request,pk=None):
        if pk: raise APIError('Créez la caisse depuis le registre.','METHOD_NOT_ALLOWED',405)
        return self.create(request,'caisses')
    def put(self,request,pk=None):
        if not pk: raise APIError('Identifiant caisse requis.','METHOD_NOT_ALLOWED',405)
        return ok(service.modify(request.user,'caisses',pk,request.data))


class EntriesView(CashView):
    def get(self,request,pk=None): return ok(service.detail(request.user,'ecritures',pk) if pk else service.list_data(request.user,'ecritures',request.query_params.dict()))
    def post(self,request,pk=None):
        if pk: raise APIError('Créez l’écriture depuis le journal.','METHOD_NOT_ALLOWED',405)
        return self.create(request,'ecritures')
    def put(self,request,pk=None):
        if not pk: raise APIError('Identifiant écriture requis.','METHOD_NOT_ALLOWED',405)
        return ok(service.modify(request.user,'ecritures',pk,request.data))


class EntryActionView(CashView):
    def post(self,request,pk,action): return ok(service.entry_action(request.user,pk,action,request.data))


class ValidationSettingsView(CashView):
    def get(self, request):
        return ok(validation.configuration(request.user))

    def put(self, request):
        return ok(validation.configure(request.user, request.data))


class ValidationPreviewView(CashView):
    def post(self, request):
        return ok(validation.preview(request.user, request.data))


class ValidationSelectionView(CashView):
    def post(self, request):
        return ok(validation.confirm(request.user, request.data))


class ClosuresView(CashView):
    def get(self,request,pk=None): return ok(service.detail(request.user,'clotures',pk) if pk else service.list_data(request.user,'clotures',request.query_params.dict()))
    def post(self,request,pk=None):
        if pk: raise APIError('Créez la clôture depuis le registre.','METHOD_NOT_ALLOWED',405)
        return self.create(request,'clotures')


class ClosurePreparationView(CashView):
    def get(self,request):
        return ok(service.closure_preparation(
            request.user, request.query_params.get('caisseId'),
            request.query_params.get('date'), request.query_params.get('montantCompte'),
        ))


class RegisterExportView(ExcelDownloadView):
    permission_classes = [HasModuleAccess]
    renderer_classes = [ExactJSONRenderer,ExcelFileRenderer,CSVFileRenderer]

    def get(self,request,kind,file_format):
        raw = request.query_params.dict()
        view,key,available,where,params,order,filters = service.read_source(request.user,kind,raw,export=True)
        from apps.core.table_preferences import export_keys
        chosen = export_keys(request.user,'caisse.'+kind,raw)
        if isinstance(chosen, list) and 'columns' not in raw:
            hidden = service.hidden_fields(request.user, kind, 'export')
            chosen = [field for field in chosen if field not in hidden]
        if not isinstance(chosen,list) or not chosen or len(chosen)>100 or any(not isinstance(field,str) or field not in available or field not in LABELS for field in chosen) or len(set(chosen))!=len(chosen):
            service.fail('Colonne d’export non autorisée.')
        suffix,values = selected_scope(raw,key)
        where += suffix; params += values
        source = db.qualified('operations',view)
        count = db.one('SELECT count(*) n FROM '+source+' v WHERE '+where,params)['n']
        if count>MAX_EXPORT_ROWS: service.fail('L’export dépasse 100 000 lignes. Affinez les filtres.',code='EXPORT_TOO_LARGE',status=413)
        rows = [service.public_record(request.user, kind, row, 'export') for row in
                db.query('SELECT v.* FROM '+source+' v WHERE '+where+' ORDER BY '+order,params)]
        columns = [{**available[field],'label':LABELS[field]} for field in chosen]
        # Le moteur commun reconnaît les montants par leur nom, sans confondre
        # cet écart monétaire avec Ecart (quantité) des inventaires physiques.
        money_keys = {'SoldeTheorique','SoldeApres','EcartsRapprochement','Ecart','MontantCaisse'}
        for column in columns:
            field = column['column_name']
            if field in money_keys:
                alias = 'MontantExport'+field
                column['column_name'] = alias
                for row in rows: row[alias] = row.get(field)
        generated = datetime.now(service.ZONE)
        context = {'title':{'caisses':'Caisses','ecritures':'Journal de caisse','clotures':'Clôtures de caisse'}[kind],
            'tz':service.ZONE,'zone':'Africa/Kinshasa','generated':generated.strftime('%d/%m/%Y %H:%M'),
            'scope': 'Entreprise #'+str(service.read_entity(request.user)) if service.read_entity(request.user) else 'Toutes les entreprises autorisées',
            'source':'operations.'+view,'raw':raw,'order':order,'filters':{}}
        target = SpooledTemporaryFile(max_size=8*1024*1024,mode='w+b')
        try:
            exported = write_tabular(target,columns,rows,context,file_format)
            target.seek(0)
            response = FileResponse(target,as_attachment=True,filename='SauverNdeko_Caisse_'+kind+'_'+generated.strftime('%Y-%m-%d')+'.'+file_format,
                content_type=XLSX_MEDIA_TYPE if file_format=='xlsx' else 'text/csv; charset=utf-8')
            response['X-Export-Row-Count'] = str(exported)
            response['Cache-Control'] = 'no-store, private'
            return response
        except Exception:
            target.close()
            raise
