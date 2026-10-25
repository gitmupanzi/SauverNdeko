"""Ventilation par lot des mouvements existants : le trigger de ligne garde l’unique effet de stock."""
from datetime import date
from decimal import Decimal
from apps.core import db
from apps.core.responses import APIError
from apps.core.repository import positive

def line_lots(commande_id,article_id):
    return db.query('''SELECT l."ID_LotArticle",l."NumeroLot",l."DatePeremptionLot",ml."Quantite"
        FROM logistique."T_Mouvement" m JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
        JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk"
        WHERE m."ID_cmdFk"=%s AND m."ID_ArticleFk"=%s ORDER BY l."NumeroLot",l."ID_LotArticle"''',[commande_id,article_id])

def normalize(rows,quantity):
    if not isinstance(rows,list) or len(rows)>50:raise APIError("Indiquez au maximum 50 lots par ligne.","LOT_VALIDATION",400)
    result=[];seen=set()
    for row in rows:
        if not isinstance(row,dict) or set(row)-{"NumeroLot","Quantite","DatePeremptionLot"}:raise APIError("Informations de lot invalides.","LOT_VALIDATION",400)
        number=row.get("NumeroLot")
        if not isinstance(number,str) or not number.strip() or len(number.strip())>100:raise APIError("Renseignez un numéro de lot de 100 caractères au maximum.","LOT_VALIDATION",400)
        number=number.strip();key=number.casefold()
        if key in seen:raise APIError("Un numéro de lot ne doit apparaître qu’une fois dans la ligne.","LOT_VALIDATION",400)
        seen.add(key);qty=positive(row.get("Quantite"),"Quantité du lot")
        expiry=row.get("DatePeremptionLot")
        try:expiry=date.fromisoformat(expiry) if expiry else None
        except (ValueError,TypeError):raise APIError("Date de péremption du lot invalide.","LOT_VALIDATION",400)
        result.append({"NumeroLot":number,"Quantite":qty,"DatePeremptionLot":expiry})
    if result and sum(row["Quantite"] for row in result)!=quantity:raise APIError("La somme des quantités par lot doit correspondre à la quantité de la ligne.","LOT_QUANTITY_MISMATCH",400)
    return result

def sync_movement(article_id,movement_id,rows,quantity):
    values=normalize(rows,quantity)
    movement=db.one('SELECT "ID_ArticleFk","SigneStock" FROM logistique."V_MouvementStock" WHERE "ID_Mvt"=%s',[movement_id])
    if not movement or movement["ID_ArticleFk"]!=article_id:raise APIError("Mouvement de lot introuvable.","LOT_MOVEMENT_MISSING",409)
    current=db.one('SELECT EXISTS(SELECT 1 FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=%s) AS present',[movement_id])["present"]
    if current and not values:raise APIError("Conservez la ventilation de cette ligne ou corrigez ses lots.","LOT_REQUIRED",409)
    db.query('DELETE FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=%s',[movement_id])
    for row in sorted(values,key=lambda item:item["NumeroLot"].casefold()):
        lot=db.one('SELECT * FROM logistique."T_LotArticle" WHERE "ID_ArticleFk"=%s AND lower(btrim("NumeroLot"))=lower(%s) FOR NO KEY UPDATE',[article_id,row["NumeroLot"]])
        if lot:
            if not lot["Actif"]:raise APIError("Ce numéro de lot est archivé.","LOT_INACTIVE",409)
            if row["DatePeremptionLot"] is not None and lot["DatePeremptionLot"]!=row["DatePeremptionLot"]:raise APIError("La date reçue diffère de celle déjà enregistrée pour ce lot.","LOT_EXPIRY_CONFLICT",409)
        elif movement["SigneStock"]==1:
            lot=db.one('INSERT INTO logistique."T_LotArticle" ("ID_ArticleFk","NumeroLot","DatePeremptionLot") VALUES (%s,%s,%s) RETURNING *',[article_id,row["NumeroLot"],row["DatePeremptionLot"]])
        else:raise APIError("Ce lot n’a pas été reçu pour cet article.","LOT_NOT_RECEIVED",409)
        db.query('INSERT INTO logistique."T_MouvementLot" ("ID_MvtFk","ID_LotArticleFk","Quantite") VALUES (%s,%s,%s)',[movement_id,lot["ID_LotArticle"],row["Quantite"]])

def initial_lots(article,rows):
    if not rows:return
    movement=db.one('SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s AND "ID_cmdFk" IS NULL ORDER BY "ID_Mvt" LIMIT 1',[article["ID_Article"]])
    if not movement:raise APIError("Un stock initial positif est requis pour renseigner ses lots.","LOT_INITIAL_QUANTITY",400)
    sync_movement(article["ID_Article"],movement["ID_Mvt"],rows,article["QteArticle"])
