"""Ventilation par lot des mouvements existants : le trigger de ligne garde l’unique effet de stock."""
from datetime import date
from decimal import Decimal
from apps.core import db
from apps.core.responses import APIError
from apps.core.repository import positive
from .quantities import quantity as exact_quantity

def expiry_storage_ready():
    return db.one("SELECT to_regclass('logistique.\"V_ArticlePeremption\"') IS NOT NULL AS ready")['ready']

def line_lots(commande_id,article_id):
    fields=',ml."MotifDerogationPeremption",ml."ID_DerogationUserFk",ml."DateDerogationPeremption"' if expiry_storage_ready() else ''
    return db.query('''SELECT l."ID_LotArticle",l."NumeroLot",l."DatePeremptionLot",ml."Quantite"'''+fields+'''
        FROM logistique."T_Mouvement" m JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
        JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk"
        WHERE m."ID_cmdFk"=%s AND m."ID_ArticleFk"=%s ORDER BY l."NumeroLot",l."ID_LotArticle"''',[commande_id,article_id])

def normalize(rows,quantity,*,allow_partial=False):
    if not isinstance(rows,list) or len(rows)>50:raise APIError("Indiquez au maximum 50 lots par ligne.","LOT_VALIDATION",400)
    result=[];seen=set()
    for row in rows:
        if not isinstance(row,dict) or set(row)-{"NumeroLot","Quantite","DatePeremptionLot","MotifDerogationPeremption"}:raise APIError("Informations de lot invalides.","LOT_VALIDATION",400)
        number=row.get("NumeroLot")
        if not isinstance(number,str) or not number.strip() or len(number.strip())>100:raise APIError("Renseignez un numéro de lot de 100 caractères au maximum.","LOT_VALIDATION",400)
        number=number.strip();key=number.casefold()
        if key in seen:raise APIError("Un numéro de lot ne doit apparaître qu’une fois dans la ligne.","LOT_VALIDATION",400)
        seen.add(key);qty=exact_quantity(row.get("Quantite"),"Quantite")
        expiry=row.get("DatePeremptionLot")
        try:expiry=date.fromisoformat(expiry) if expiry else None
        except (ValueError,TypeError):raise APIError("Date de péremption du lot invalide.","LOT_VALIDATION",400)
        reason=row.get("MotifDerogationPeremption")
        if reason not in (None,"") and (not isinstance(reason,str) or not 10<=len(reason.strip())<=1000):raise APIError("Le motif de dérogation doit contenir de 10 à 1000 caractères.","EXPIRY_REASON_REQUIRED",400)
        result.append({"NumeroLot":number,"Quantite":qty,"DatePeremptionLot":expiry,**({"MotifDerogationPeremption":reason.strip()} if reason else {})})
    allocated=sum(row["Quantite"] for row in result)
    if result and (allocated>quantity or not allow_partial and allocated!=quantity):raise APIError("La somme des quantités par lot doit correspondre à la quantité de la ligne." if not allow_partial else "La quantité ventilée par lot dépasse celle de la ligne.","LOT_QUANTITY_MISMATCH",400)
    return result

def unchanged(rows,previous,quantity):
    values=normalize(rows,quantity,allow_partial=True)
    def signature(items):
        return sorted((str(row["NumeroLot"]).strip().casefold(),Decimal(str(row["Quantite"])),
            row["DatePeremptionLot"].isoformat() if hasattr(row.get("DatePeremptionLot"),"isoformat") else row.get("DatePeremptionLot"),str(row.get("MotifDerogationPeremption") or "").strip()) for row in items)
    return signature(values)==signature(previous)


def sync_movement(article_id,movement_id,rows,quantity,*,actor=None):
    movement=db.one('SELECT "ID_ArticleFk","SigneStock" FROM logistique."V_MouvementStock" WHERE "ID_Mvt"=%s',[movement_id])
    if not movement or movement["ID_ArticleFk"]!=article_id:raise APIError("Mouvement de lot introuvable.","LOT_MOVEMENT_MISSING",409)
    from .depots import is_internal_transfer
    values=normalize(rows,quantity,allow_partial=movement["SigneStock"]==-1 or is_internal_transfer())
    current=db.one('SELECT EXISTS(SELECT 1 FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=%s) AS present',[movement_id])["present"]
    if current and not values and movement["SigneStock"]!=-1:raise APIError("Conservez la ventilation de cette ligne ou corrigez ses lots.","LOT_REQUIRED",409)
    db.query('DELETE FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=%s',[movement_id])
    for row in sorted(values,key=lambda item:item["NumeroLot"].casefold()):
        lot=db.one('SELECT * FROM logistique."T_LotArticle" WHERE "ID_ArticleFk"=%s AND lower(btrim("NumeroLot"))=lower(%s) FOR NO KEY UPDATE',[article_id,row["NumeroLot"]])
        if lot:
            if not lot["Actif"]:raise APIError("Ce numéro de lot est archivé.","LOT_INACTIVE",409)
            if row["DatePeremptionLot"] is not None and lot["DatePeremptionLot"]!=row["DatePeremptionLot"]:raise APIError("La date reçue diffère de celle déjà enregistrée pour ce lot.","LOT_EXPIRY_CONFLICT",409)
        elif movement["SigneStock"]==1:
            lot=db.one('INSERT INTO logistique."T_LotArticle" ("ID_ArticleFk","NumeroLot","DatePeremptionLot") VALUES (%s,%s,%s) RETURNING *',[article_id,row["NumeroLot"],row["DatePeremptionLot"]])
        else:raise APIError("Ce lot n’a pas été reçu pour cet article.","LOT_NOT_RECEIVED",409)
        reason=row.get("MotifDerogationPeremption")
        if not expiry_storage_ready():
            if reason:raise APIError("Le contrôle de péremption n’est pas encore installé.","EXPIRY_UNAVAILABLE",503)
            db.query('INSERT INTO logistique."T_MouvementLot" ("ID_MvtFk","ID_LotArticleFk","Quantite") VALUES (%s,%s,%s)',[movement_id,lot["ID_LotArticle"],row["Quantite"]])
            continue
        if reason and (actor is None or not actor.global_admin):raise APIError("Une dérogation de péremption exige un administrateur de plateforme.","EXPIRY_OVERRIDE_FORBIDDEN",403)
        if movement["SigneStock"]==-1:
            policy=db.one('SELECT e."BloquerLotsPerimes" blocked,(%s::date<(CURRENT_TIMESTAMP AT TIME ZONE \'Africa/Kinshasa\')::date) IS TRUE expired FROM logistique."T_Article" a JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk" WHERE a."ID_Article"=%s',[lot.get("DatePeremptionLot"),article_id])
            if policy and policy['expired'] and policy['blocked'] and not reason:raise APIError("La sortie d’un lot périmé est bloquée dans cette entreprise. Une dérogation motivée est requise.","EXPIRED_LOT_BLOCKED",409)
        db.query('''INSERT INTO logistique."T_MouvementLot" ("ID_MvtFk","ID_LotArticleFk","Quantite","MotifDerogationPeremption","ID_DerogationUserFk") VALUES (%s,%s,%s,%s,%s)''',[movement_id,lot["ID_LotArticle"],row["Quantite"],reason,actor.pk if reason else None])

def initial_lots(article,rows):
    if not rows:return
    movement=db.one('''SELECT m."ID_Mvt" FROM logistique."T_Mouvement" m
        JOIN logistique."T_Commande" c ON c."ID_Commande"=m."ID_cmdFk"
        WHERE m."ID_ArticleFk"=%s AND c."ID_ArticleInitialFk"=m."ID_ArticleFk" AND c."OrigineBon"='stock_initial'
        ORDER BY m."ID_Mvt" LIMIT 1''',[article["ID_Article"]])
    if not movement:raise APIError("Un stock initial positif est requis pour renseigner ses lots.","LOT_INITIAL_QUANTITY",400)
    sync_movement(article["ID_Article"],movement["ID_Mvt"],rows,article["QteArticle"])


def outgoing_type(type_id):
    """Le sens est résolu dans le référentiel serveur, jamais reçu comme drapeau client."""
    row=db.one("SELECT logistique.fn_nature_bon(%s)='sortie' AS outgoing",[type_id])
    return bool(row and row["outgoing"])


def stock_document_types(actor,*,lock=False):
    """Types d'écart effectifs : même configuration que le formulaire des bons."""
    from apps.core.field_references import reference_options
    rows=reference_options(actor,'logistique','T_Commande','ID_TypeCmdFk')
    result={}
    for item in sorted(rows,key=lambda row:row['id']):
        sign=item.get('stockEffect')
        if sign in (1,-1) and not item.get('disabled'):
            result.setdefault(sign,item['id'])
    if lock and result:
        db.query('SELECT g."ID_Generique" FROM referentiel."T_Generique" g JOIN '
            'referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" '
            'WHERE g."ID_Generique"=ANY(%s::integer[]) ORDER BY g."ID_Generique" FOR SHARE OF g,c',
            [sorted(result.values())])
    return result


def stock_state(article_id,depot_id=None):
    """État exhaustif des lots, indépendant des filtres et de la pagination de consultation."""
    if depot_id is not None:
        from .depots import stock
        local=stock(article_id,depot_id)
        return {'stockTotal':local['StockPhysique'],'stockAllocated':local['StockPhysique']-local['StockSansLot'],'stockWithoutLot':local['StockSansLot'],'stockAvailable':local['StockDisponible'],'stockReserved':local['StockReserve'],'depotId':depot_id}
    row=db.one('''SELECT a."QteArticle" AS "stockTotal",COALESCE(sum(l."StockLot"),0) AS "stockAllocated"
        FROM logistique."T_Article" a LEFT JOIN logistique."V_LotArticleStock" l ON l."ID_ArticleFk"=a."ID_Article"
        WHERE a."ID_Article"=%s GROUP BY a."ID_Article",a."QteArticle"''',[article_id])
    if row is None:raise APIError("Article introuvable.","NOT_FOUND",404)
    return {**row,"stockWithoutLot":row["stockTotal"]-row["stockAllocated"] if row["stockTotal"] is not None else None}


def validate_stock(article_id,depot_id=None):
    """Vérifie l’état final sous le verrou article, avant l’audit et le commit différé.
    Les triggers gardent les effets de stock et leur contrôle final de défense.
    """
    negative=db.one('''SELECT EXISTS(SELECT 1 FROM logistique."V_LotArticleStock"
        WHERE "ID_ArticleFk"=%s AND "StockLot"<0) AS present''',[article_id])["present"]
    if negative:raise APIError({"Lots":"La quantité dépasse le stock disponible d’un lot. Corrigez la ventilation."},"LOT_STOCK_CONFLICT",409)
    exceeded=db.one('''SELECT EXISTS(SELECT 1 FROM logistique."T_Mouvement" m
        JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
        WHERE m."ID_ArticleFk"=%s GROUP BY m."ID_Mvt",m."QteMvt" HAVING sum(ml."Quantite")>m."QteMvt") AS present''',[article_id])["present"]
    if exceeded:raise APIError({"Lots":"La quantité ventilée par lot dépasse celle de la ligne. Corrigez les lots."},"LOT_STOCK_CONFLICT",409)
    state=stock_state(article_id)
    if state["stockWithoutLot"] is not None and state["stockWithoutLot"]<0:
        raise APIError({"Lots":"Le stock disponible sans lot ne suffit pas. Précisez ou corrigez les lots de cette ligne."},"LOT_STOCK_CONFLICT",409)
    if depot_id is not None:
        from .depots import stock
        local=stock(article_id,depot_id)
        if local['StockPhysique']<0 or local['StockSansLot']<0:
            raise APIError({'Lots':'Le stock disponible de ce dépôt ne suffit pas. Vérifiez la quantité et les lots.'},'DEPOT_STOCK_CONFLICT',409)
