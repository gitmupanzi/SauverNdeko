"""Registres métier fondés sur les vues communes, sans nouvelle table ni effet de stock."""
from datetime import date
from apps.core import db
from apps.core.registry import view
from apps.core.permissions import scope_for
from apps.core.repository import positive
from apps.core.responses import APIError
from .currency import amounts_by_currency
from .table_queries import document_zone

KINDS={'mouvements','factures','reglements'}
COMMON={'q','dateFrom','dateTo','take','skip','sortBy','sortDir','columnFilters','timeZone','deviseId'}
SPECIFIC={'mouvements':{'articleId','commandeId','typeId','origine','sens','categorieId','articleTypeId'},'factures':{'commandeId','client','payment','late','dueFrom','dueTo'},'reglements':{'commandeId','client','modeId','codeFacture'}}
INVOICE=""""CodeFacture" IS NOT NULL AND BTRIM("CodeFacture")<>''"""


def column(name,kind):
    return {'column_name':name,'data_type':kind,'is_nullable':'YES','numeric_precision':None,'numeric_scale':None,'character_maximum_length':None}


def source(kind):
    if kind=='mouvements':
        base=view('logistique','V_Mouvement');extras=[column('AbrUnite','character varying'),column('MontantMvtSigned','numeric'),column('RefArticle','character varying'),column('CategorieArticle','character varying'),column('TypeArticle','character varying'),column('ID_CategorieArticleFk','integer'),column('ID_TypeArticleFk','integer'),column('StockActuel','numeric'),column('ValideArticle','boolean')]
        sql='''(SELECT m.*,a."AbrUnite",a."RefArticle",a."CategorieArticle",a."TypeArticle",a."ID_CategorieArticleFk",a."ID_TypeArticleFk",a."QteArticle" AS "StockActuel",a."ValideArticle",CASE WHEN m."PUMvt" IS NOT NULL AND m."QteMvt" IS NOT NULL AND m."SigneStock" IN (-1,1)
          THEN m."MontantMvt"*m."SigneStock" ELSE NULL END AS "MontantMvtSigned"
          FROM logistique."V_Mouvement" m LEFT JOIN logistique."V_Article" a ON a."ID_Article"=m."ID_ArticleFk") v'''
        return {**base,'columns':[*base['columns'],*extras],'primaryKey':['ID_Mvt'],'_row_source':sql,'_date_field':'DateMvt'}
    if kind=='factures':
        base=view('logistique','V_SuiviReglements')
        return {**base,'columns':[*base['columns'],column('ID_ClientFk','integer')],'primaryKey':['ID_Commande'],
          '_row_source':'(SELECT f.*,c."ID_ClientFk" FROM logistique."V_SuiviReglements" f JOIN logistique."T_Commande" c ON c."ID_Commande"=f."ID_Commande") v',
          '_date_field':'DateFacture','_base_condition':INVOICE}
    if kind=='reglements':
        base=view('logistique','V_Reglements');extras=[column('ID_Commande','integer'),column('CodeCmd','character varying'),column('NomClientSaisi','character varying'),column('ModeReglement','character varying')]
        return {**base,'columns':[*base['columns'],*extras],'primaryKey':['ID_Reglement'],'_date_field':'DateReglement',
          '_row_source':'''(SELECT p.*,c."ID_Commande",c."CodeCmd",c."NomClientSaisi",g."NomGenerique" AS "ModeReglement"
          FROM logistique."V_Reglements" p LEFT JOIN logistique."V_Commande" c ON c."CodeFacture"=p."CodeFactureFk"
          LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=p."ID_ModeReglementFk") v'''}
    raise APIError('Registre introuvable.','NOT_FOUND',404)


def register_source(kind,raw,for_export=False):
    if set(raw)-(COMMON|SPECIFIC[kind]|({'columns'} if for_export else set())):raise APIError('Critère non autorisé.')
    obj=source(kind);filters={};conditions=[obj.get('_base_condition','TRUE')]
    mapping=({'articleId':'ID_ArticleFk','commandeId':'ID_cmdFk','typeId':'ID_TypeMvtFk','categorieId':'ID_CategorieArticleFk','articleTypeId':'ID_TypeArticleFk'} if kind=='mouvements' else {'commandeId':'ID_Commande','client':'ID_ClientFk'} if kind=='factures' else {'commandeId':'ID_Commande','client':'ID_ClientFk','modeId':'ID_ModeReglementFk'})
    for key,field in mapping.items():
        if raw.get(key) not in (None,'','all'):filters[field]=positive(raw[key])
    if kind=='mouvements':
        senses={'all':'TRUE','entree':'"SigneStock"=1','sortie':'"SigneStock"=-1','neutre':'COALESCE("SigneStock",0)=0'};selected=raw.get('sens') or 'all'
        if selected not in senses:raise APIError('Sens de mouvement invalide.')
        conditions.append(senses[selected]);origin=raw.get('origine')
        if origin not in (None,'','all'):
            if not isinstance(origin,str) or len(origin)>100:raise APIError('Origine de mouvement invalide.')
            filters['OrigineMouvement']=origin
    elif kind=='factures':
        states={'all':'TRUE','reglee':'"Reste"<=0','partielle':'"TotalRegle">0 AND "Reste">0','non-reglee':'"TotalRegle"<=0 AND "Reste">0','retard':'"EstEnRetard"=true'};selected=raw.get('payment') or 'all'
        if selected not in states:raise APIError('État de paiement invalide.')
        conditions.append(states[selected]);late=raw.get('late') or 'all'
        if late not in {'all','true','false'}:raise APIError('État de retard invalide.')
        if late!='all':filters['EstEnRetard']=late=='true'
        if raw.get('dueFrom') or raw.get('dueTo'):obj={**obj,'_extra_period':('DateEcheancePaiement',raw.get('dueFrom'),raw.get('dueTo'))}
    else:
        code=raw.get('codeFacture')
        if code not in (None,''):
            if not isinstance(code,str) or len(code)>255:raise APIError('Référence de facture invalide.')
            filters['CodeFactureFk']=code
    return obj,' AND '.join('('+item+')' for item in conditions),filters


def period_clause(obj,field,begin,end,raw):
    dates=[]
    for value in (begin,end):
        try:dates.append(date.fromisoformat(value) if value else None)
        except (ValueError,TypeError):raise APIError('Date de filtre invalide.')
    if dates[0] and dates[1] and dates[0]>dates[1]:raise APIError('La date de fin doit suivre la date de début.')
    kind=next((item['data_type'] for item in obj['columns'] if item['column_name']==field),None)
    if kind not in {'timestamp with time zone','timestamp without time zone','date'}:raise APIError('Date de filtre indisponible.')
    clauses=[];values=[]
    for index,day in enumerate(dates):
        if day is None:continue
        operator='>=' if index==0 else '<';value='%s::date' if index==0 else "(%s::date+INTERVAL '1 day')"
        if kind=='timestamp with time zone':value='('+(value+'::timestamp' if index==0 else value)+' AT TIME ZONE %s)';values.extend([day,str(document_zone(raw))])
        else:values.append(day)
        clauses.append('v.'+db.ident(field)+operator+value)
    return ' AND '.join(clauses),values


def annotate_metadata(kind,obj,actor,raw,where,values,meta):
    from .reads import row_source
    source_sql=row_source(obj)
    if kind=='mouvements':
        expression='COUNT(*) AS total,COUNT(*) FILTER(WHERE "SigneStock"=1) AS entrees,COUNT(*) FILTER(WHERE "SigneStock"=-1) AS sorties,COUNT(DISTINCT "ID_ArticleFk") AS articles,COUNT(DISTINCT "ID_cmdFk") AS bons'
        scope,scope_values=scope_for(obj,actor)
        options=db.query('SELECT DISTINCT "OrigineMouvement" AS value FROM '+source_sql+' WHERE '+scope+' AND "OrigineMouvement" IS NOT NULL ORDER BY value',scope_values)
        labels={'Commande':'Bon de stock','Hors commande':'Stock initial ou ajustement'};meta['options']={'origines':[{'value':row['value'],'label':labels.get(row['value'],row['value'])} for row in options]}
    elif kind=='factures':
        from .invoices import storage_ready
        meta['features']={'invoices':storage_ready()}
        expression='COUNT(*) AS total,COUNT(*) FILTER(WHERE "Reste"<=0) AS soldees,COUNT(*) FILTER(WHERE "TotalRegle">0 AND "Reste">0) AS partielles,COUNT(*) FILTER(WHERE "Reste">0) AS "aRegler",COUNT(*) FILTER(WHERE "EstEnRetard") AS "enRetard",COUNT(*) FILTER(WHERE "AvoirAEtablir") AS avoirs'
        meta['amountsByCurrency']={field:amounts_by_currency(obj,source_sql,where,values,'SUM(v.'+db.ident(field)+')') for field in ('MontantFacture','TotalRegle','Reste','MontantAvoirAEtablir')}
    else:
        expression='COUNT(*) AS total,COUNT(DISTINCT "CodeFactureFk") AS factures';meta['amountsByCurrency']={'MontantRegle':amounts_by_currency(obj,source_sql,where,values,'SUM(v."MontantRegle")')}
    meta['summary']=db.one('SELECT '+expression+' FROM '+source_sql+' WHERE '+where,values)
    return meta
