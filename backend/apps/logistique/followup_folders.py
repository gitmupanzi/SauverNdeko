"""Dossiers de suivi : sélections dynamiques et classements privés, sans effet sur le stock."""
import json
import re
from django.conf import settings
from django.db import transaction, IntegrityError
from rest_framework.views import APIView
from psycopg.types.json import Jsonb
from apps.core import db
from apps.core.permissions import IsERPAdmin
from apps.core.registry import view
from apps.core.repository import positive, page, get_record, audit, clean
from apps.core.responses import APIError, ok
from .reads import read_scope, register_source, row_source, QUERY_KEYS, INDICATORS, INVOICE

COLOURS = {"vert":"Vert", "rouge":"Rouge", "orange":"Orange", "bleu":"Bleu", "violet":"Violet", "ardoise":"Ardoise"}
TYPES = {"article": ("V_Article", "ID_Article", "ID_ArticleFk", "NomArticle"), "bon": ("V_Commande", "ID_Commande", "ID_CommandeFk", "CodeCmd"), "facture": ("V_Commande", "ID_Commande", "ID_CommandeFk", "CodeFacture")}
ARTICLE_RULES = {"q","categorieId","typeId","uniteId","statut","stockState","peremption"}
DOCUMENT_RULES = {"q","client","typeId","statutId","etatBon"}
INVOICE_RULES = {"q","client","etatFacture"}
STATES = {"bon": {"attente":"commandesEnAttente","en-cours":"commandesEnCours","entree":"commandesEntree","sortie":"commandesSortie","non-facture":"commandesNonFacturees","sans-lignes":"commandesSansDetails"}, "facture":{"soldee":"facturesSoldees","partielle":"facturesPartielles","a-regler":"facturesARegler","retard":"facturesEnRetard"}}
AUTOMATIC = [
 {"key":"ruptures","name":"Produits en rupture","objectType":"article","category":"Stock","colour":"rouge","rules":{"stockState":"rupture"},"description":"Stock nul ou négatif."},
 {"key":"stock-faible","name":"Produits en stock faible","objectType":"article","category":"Stock","colour":"orange","rules":{"stockState":"faible"},"description":"Stock positif inférieur ou égal au seuil minimum."},
 {"key":"peremption-proche","name":"Péremption proche","objectType":"article","category":"Conservation","colour":"orange","rules":{"peremption":"alerte"},"description":"Articles en alerte de péremption, non encore périmés."},
 {"key":"articles-perimes","name":"Articles périmés","objectType":"article","category":"Conservation","colour":"rouge","rules":{"peremption":"perime"},"description":"Date de péremption dépassée."},
 {"key":"bons-en-attente","name":"Bons en attente","objectType":"bon","category":"À traiter","colour":"orange","rules":{"etatBon":"attente"},"description":"Bons de stock en attente de traitement."},
 {"key":"bons-en-cours","name":"Bons en cours","objectType":"bon","category":"À traiter","colour":"bleu","rules":{"etatBon":"en-cours"},"description":"Bons de stock en cours de traitement."},
 {"key":"bons-non-factures","name":"Bons non facturés","objectType":"bon","category":"Facturation","colour":"violet","rules":{"etatBon":"non-facture"},"description":"Bons sans référence de facture."},
 {"key":"bons-sans-lignes","name":"Bons sans lignes","objectType":"bon","category":"À traiter","colour":"orange","rules":{"etatBon":"sans-lignes"},"description":"Bons ne comportant aucune ligne d’article."},
 {"key":"factures-a-regler","name":"Factures à régler","objectType":"facture","category":"Facturation","colour":"orange","rules":{"etatFacture":"a-regler"},"description":"Factures présentant un solde restant positif."},
 {"key":"factures-en-retard","name":"Factures en retard","objectType":"facture","category":"À traiter","colour":"rouge","rules":{"etatFacture":"retard"},"description":"Factures à solde positif dont l’échéance est dépassée."},
 {"key":"factures-partielles","name":"Factures partiellement réglées","objectType":"facture","category":"Facturation","colour":"violet","rules":{"etatFacture":"partielle"},"description":"Factures réglées en partie, avec un solde restant positif."},
]
OBJECTS = ["V_DossierSuivi","V_CategorieDossierSuivi","V_DossierSuiviMembre","T_DossierSuivi","T_CategorieDossierSuivi","T_DossierSuiviMembre"]

def object_type(value):
    if not isinstance(value,str) or value not in TYPES: raise APIError("Type de dossier invalide.")
    return value

def storage_ready():
    names = ['logistique."'+name+'"' for name in OBJECTS]
    return db.one("SELECT bool_and(to_regclass(name) IS NOT NULL) AS ready FROM unnest(%s::text[]) AS t(name)",[names])["ready"]

def require_storage():
    if not storage_ready():
        raise APIError("Les dossiers personnalisés ne sont pas encore activés.","FOLDERS_NOT_INSTALLED",503)

def owner_scope(actor, alias="d"):
    return alias+'."ID_UserFk"=%s AND '+alias+'."IdEntiteFk" IS NOT DISTINCT FROM %s',[actor.pk,actor.organisation]

def categories(actor):
    where,params=owner_scope(actor,"c")
    return db.query('SELECT c.* FROM logistique."V_CategorieDossierSuivi" c WHERE '+where+' AND c."Actif" ORDER BY lower(c."Nom"),c."ID_CategorieDossierSuivi"',params)

def custom_definition(row):
    return {"key":"dossier-"+str(row["ID_DossierSuivi"]),"id":row["ID_DossierSuivi"],"name":row["Nom"],"description":row["Description"],"colour":row["Couleur"],"category":row["CategorieDossier"] or "Sans catégorie","categoryId":row["ID_CategorieDossierSuiviFk"],"objectType":row["TypeObjet"],"mode":row["Mode"],"rules":row["Regles"],"system":False,"active":row["Actif"],"version":row["Version"]}

def definitions(actor, archived=False):
    where,params=owner_scope(actor)
    rows=db.query('SELECT d.* FROM logistique."V_DossierSuivi" d WHERE '+where+' AND d."Actif"=%s ORDER BY lower(d."Nom"),d."ID_DossierSuivi"',[*params,not archived])
    return [custom_definition(row) for row in rows]

def get_definition(actor,key,include_archived=False,lock=False):
    standard=next((item for item in AUTOMATIC if item["key"]==key),None)
    if standard:
        if lock: raise APIError("Ce dossier standard ne peut pas être modifié.","SYSTEM_FOLDER",403)
        return {**standard,"mode":"automatique","system":True,"active":True,"version":None,"categoryId":None}
    match=re.fullmatch(r"dossier-([1-9][0-9]*)",str(key))
    if not match: raise APIError("Dossier introuvable.","NOT_FOUND",404)
    require_storage()
    where,params=owner_scope(actor)
    source='logistique."T_DossierSuivi"' if lock else 'logistique."V_DossierSuivi"'
    row=db.one('SELECT d.* FROM '+source+' d WHERE '+where+' AND d."ID_DossierSuivi"=%s'+('' if include_archived else ' AND d."Actif"')+(' FOR UPDATE' if lock else ''),[*params,positive(match[1])])
    if not row: raise APIError("Dossier introuvable.","NOT_FOUND",404)
    if lock: row["CategorieDossier"]=""
    return custom_definition(row)

def validate_rules(rules, mode, kind="article"):
    object_type(kind)
    allowed = ARTICLE_RULES if kind=="article" else DOCUMENT_RULES if kind=="bon" else INVOICE_RULES
    if not isinstance(rules,dict) or set(rules)-allowed: raise APIError("Critères du dossier invalides pour ce type.")
    result={}
    for key,value in rules.items():
        if not isinstance(value,(str,int)) or type(value) is bool: raise APIError("Valeur de critère invalide.")
        if value in ("","all"): continue
        if key in {"typeId","categorieId","uniteId","statutId","client"}: result[key]=str(positive(value))
        elif key=="q":
            if not isinstance(value,str) or len(value.strip())>300: raise APIError("Recherche invalide.")
            if value.strip(): result[key]=value.strip()
        else:
            choices={"statut":{"true","false"},"stockState":{"rupture","faible","disponible"},"peremption":{"valide","alerte","perime","non-renseignee"},"etatBon":set(STATES["bon"]),"etatFacture":set(STATES["facture"])}
            if value not in choices[key]: raise APIError("État de classement invalide.")
            result[key]=value
    if mode=="manuel" and result: raise APIError("Un dossier manuel utilise des rattachements explicites.")
    if mode=="automatique" and not result: raise APIError("Choisissez au moins un critère pour le dossier automatique.")
    return result

def folder_scope(actor,folder,raw=None):
    raw=raw or {}
    if set(raw)-(QUERY_KEYS|{"columns"}): raise APIError("Critère non autorisé.")
    kind=object_type(folder["objectType"])
    rules=folder["rules"] if folder["mode"]=="automatique" else {}
    base_rules={key:value for key,value in rules.items() if key not in {"etatBon","etatFacture"}}
    obj,condition,fixed=register_source("articles" if kind=="article" else "commandes",base_rules)
    if kind=="facture": obj={**obj,"_date_field":"DateFacture"}; condition+=" AND ("+INVOICE+")"
    state=rules.get("etatBon" if kind=="bon" else "etatFacture") if kind!="article" else None
    if state: condition+=" AND ("+INDICATORS[STATES[kind][state]][1]+")"
    params,where,values,order,sort,direction,applied=read_scope(obj,actor,raw,condition,fixed,population_query=rules.get("q"))
    if folder["mode"]=="manuel":
        field=TYPES[kind][2]
        where+=' AND EXISTS (SELECT 1 FROM logistique."V_DossierSuiviMembre" m WHERE m."ID_DossierSuiviFk"=%s AND m.'+db.ident(field)+'=v.'+db.ident(TYPES[kind][1])+' AND m."Actif")'
        values=[*values,folder["id"]]
    return obj,params,where,values,order,sort,direction,applied

def counts(actor,folders):
    result={}
    for kind in TYPES:
        group=[folder for folder in folders if folder["objectType"]==kind]
        if not group: continue
        fields,values=[],[]
        for index,folder in enumerate(group):
            obj,_,where,params,*_=folder_scope(actor,folder)
            fields.append('COUNT(*) FILTER (WHERE '+where+') AS '+db.ident('f'+str(index)));values.extend(params)
        _,base,params,*_=read_scope(obj,actor)
        row=db.one('SELECT '+','.join(fields)+' FROM '+row_source(obj)+' WHERE '+base,[*values,*params])
        result.update({folder["key"]:row['f'+str(index)] for index,folder in enumerate(group)})
    return result

def catalogue(actor,archived=False):
    ready=storage_ready()
    folders=[] if archived else [{**item,"system":True,"mode":"automatique","active":True,"version":None,"categoryId":None} for item in AUTOMATIC]
    if ready: folders.extend(definitions(actor,archived))
    numbers=counts(actor,folders)
    return {"folders":[{**folder,"count":numbers[folder["key"]]} for folder in folders],"categories":categories(actor) if ready else [],"customAvailable":ready,"canWrite":ready and not settings.DB_READ_ONLY,"archived":archived,"colours":[{"key":key,"label":label} for key,label in COLOURS.items()]}

def record_folders(actor,kind,record_id):
    object_type(kind)
    ready=storage_ready()
    folders=[{**item,"system":True,"mode":"automatique","active":True,"version":None,"categoryId":None} for item in AUTOMATIC if item["objectType"]==kind]
    if ready: folders.extend(folder for folder in definitions(actor) if folder["objectType"]==kind)
    obj=view("logistique",TYPES[kind][0])
    owner_field="ID_UserFK" if kind=="article" else "ID_UserFk"
    fields,values=['v.'+db.ident(owner_field)+' IS NOT NULL AS has_owner'],[]
    for index,folder in enumerate(folders):
        obj,_,where,params,*_=folder_scope(actor,folder)
        fields.append('('+where+') AS '+db.ident('f'+str(index)));values.extend(params)
    _,scope,params,*_=read_scope(obj,actor)
    row=db.one('SELECT '+','.join(fields)+' FROM '+row_source(obj)+' WHERE '+scope+' AND v.'+db.ident(TYPES[kind][1])+'=%s',[*values,*params,positive(record_id)])
    if row is None: raise APIError("Enregistrement introuvable.","NOT_FOUND",404)
    return {"items":[{key:folder[key] for key in ("key","name","colour","category","objectType","mode","system")} for index,folder in enumerate(folders) if row['f'+str(index)]],"customAvailable":ready,"canWrite":ready and not settings.DB_READ_ONLY and row["has_owner"],"requiresOwner":not row["has_owner"]}

def folder_rows(actor,key,raw):
    folder=get_definition(actor,key)
    obj,params,where,values,order,sort,direction,applied=folder_scope(actor,folder,raw)
    take,skip=page(params)
    total=db.one('SELECT COUNT(*) AS n FROM '+row_source(obj)+' WHERE '+where,values)["n"]
    rows=db.query('SELECT v.* FROM '+row_source(obj)+' WHERE '+where+' ORDER BY '+order+' LIMIT %s OFFSET %s',[*values,take,skip])
    _,_,base,base_values,*_=folder_scope(actor,folder,{})
    count=db.one('SELECT COUNT(*) AS n FROM '+row_source(obj)+' WHERE '+base,base_values)["n"]
    return clean(rows),{"columns":[c["column_name"] for c in obj["columns"]],"columnTypes":{c["column_name"]:c["data_type"] for c in obj["columns"]},"totalCount":count,"filteredCount":total,"count":len(rows),"take":take,"skip":skip,"sortBy":sort,"sortDir":direction,"columnFilters":applied,"folder":folder}

def text_value(value,limit,label,required=True):
    if not isinstance(value,str) or len(value.strip())>limit or (required and not value.strip()): raise APIError(label+" invalide.")
    return value.strip()

def ensure_colour(value):
    if not isinstance(value,str) or value not in COLOURS: raise APIError("Couleur invalide.")
    return value

def validate_body(body,existing=None):
    if not isinstance(body,dict) or set(body)-{"name","description","colour","categoryId","objectType","mode","rules","version"}: raise APIError("Paramètres du dossier invalides.")
    result={"name":text_value(body.get("name"),120,"Nom du dossier"),"description":text_value(body.get("description",""),1000,"Description",False),"colour":ensure_colour(body.get("colour","bleu")),"categoryId":None if body.get("categoryId") in (None,"") else positive(body["categoryId"]),"mode":body.get("mode","manuel"),"objectType":object_type(body.get("objectType","article"))}
    if not isinstance(result["mode"],str) or result["mode"] not in {"manuel","automatique"}: raise APIError("Mode de dossier invalide.")
    if existing and result["mode"]!=existing["mode"]: raise APIError("Le mode du dossier ne peut pas être changé.","IMMUTABLE_MODE",409)
    if existing and result["objectType"]!=existing["objectType"]: raise APIError("Le type de dossier ne peut pas être changé.","IMMUTABLE_TYPE",409)
    result["rules"]=validate_rules(body.get("rules",{}),result["mode"],result["objectType"])
    return result

def lock_owner(actor):
    # Sérialise noms et quotas d’un même contexte sans verrouiller les articles.
    db.one("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",["followup-folders:"+str(actor.pk)+":"+str(actor.organisation)])

def category_exists(actor,pk):
    if pk is None:return
    where,values=owner_scope(actor,"c")
    if not db.one('SELECT c."ID_CategorieDossierSuivi" FROM logistique."V_CategorieDossierSuivi" c WHERE '+where+' AND c."Actif" AND c."ID_CategorieDossierSuivi"=%s',[*values,pk]): raise APIError("Catégorie introuvable.","NOT_FOUND",404)

def create_category(actor,body):
    db.ensure_writable();require_storage()
    if not isinstance(body,dict) or set(body)-{"name","colour"}:raise APIError("Catégorie invalide.")
    name=text_value(body.get("name"),80,"Nom de catégorie");colour=ensure_colour(body.get("colour","bleu"))
    try:
        with transaction.atomic():
            lock_owner(actor)
            if len(categories(actor))>=100:raise APIError("La limite de 100 catégories est atteinte.")
            row=db.one('INSERT INTO logistique."T_CategorieDossierSuivi" ("ID_UserFk","IdEntiteFk","Nom","Couleur") VALUES (%s,%s,%s,%s) RETURNING *',[actor.pk,actor.organisation,name,colour])
            audit({"schema":"logistique","name":"T_CategorieDossierSuivi"},"INSERT",new=row,actor=actor)
            return clean(row)
    except IntegrityError as exc:raise APIError("Une catégorie porte déjà ce nom.","DUPLICATE",409) from exc

def save_folder(actor,body,key=None):
    db.ensure_writable();require_storage()
    try:
        with transaction.atomic():
            lock_owner(actor)
            existing=get_definition(actor,key,include_archived=True,lock=True) if key else None
            data=validate_body(body,existing)
            category_exists(actor,data["categoryId"])
            if existing:
                if not existing["active"]:raise APIError("Restaurez le dossier avant de le modifier.","ARCHIVED",409)
                if type(body.get("version")) is not int or body["version"]!=existing["version"]:raise APIError("Ce dossier a été modifié. Rechargez la liste.","CONFLICT",409)
                row=db.one('UPDATE logistique."T_DossierSuivi" SET "Nom"=%s,"Description"=%s,"Couleur"=%s,"ID_CategorieDossierSuiviFk"=%s,"Regles"=%s,"Version"="Version"+1 WHERE "ID_DossierSuivi"=%s RETURNING *',[data["name"],data["description"],data["colour"],data["categoryId"],Jsonb(data["rules"]),existing["id"]])
            else:
                if len(definitions(actor))>=200:raise APIError("La limite de 200 dossiers actifs est atteinte.")
                row=db.one('INSERT INTO logistique."T_DossierSuivi" ("ID_UserFk","IdEntiteFk","Nom","Description","Couleur","ID_CategorieDossierSuiviFk","Mode","Regles","TypeObjet") VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *',[actor.pk,actor.organisation,data["name"],data["description"],data["colour"],data["categoryId"],data["mode"],Jsonb(data["rules"]),data["objectType"]])
            audit({"schema":"logistique","name":"T_DossierSuivi"},"UPDATE" if existing else "INSERT",old=existing,new=row,actor=actor)
            return get_definition(actor,"dossier-"+str(row["ID_DossierSuivi"]))
    except IntegrityError as exc:raise APIError("Un dossier porte déjà ce nom dans ce contexte.","DUPLICATE",409) from exc

def archive_folder(actor,key,body):
    db.ensure_writable();require_storage()
    if not isinstance(body,dict) or set(body)-{"version","active"} or type(body.get("active")) is not bool:raise APIError("État de dossier invalide.")
    with transaction.atomic():
        lock_owner(actor)
        existing=get_definition(actor,key,include_archived=True,lock=True)
        if type(body.get("version")) is not int or body["version"]!=existing["version"]:raise APIError("Le dossier a changé. Rechargez la liste.","CONFLICT",409)
        if body["active"] and not existing["active"] and len(definitions(actor))>=200:raise APIError("La limite de 200 dossiers actifs est atteinte.")
        try:
            with transaction.atomic():
                row=db.one('UPDATE logistique."T_DossierSuivi" SET "Actif"=%s,"Version"="Version"+1 WHERE "ID_DossierSuivi"=%s RETURNING *',[body["active"],existing["id"]])
        except IntegrityError as exc:raise APIError("Un dossier actif porte déjà ce nom.","DUPLICATE",409) from exc
        audit({"schema":"logistique","name":"T_DossierSuivi"},"UPDATE",old=existing,new=row,actor=actor)
        return {"key":key,"active":row["Actif"],"version":row["Version"]}

def update_members(actor,key,body):
    db.ensure_writable();require_storage()
    if not isinstance(body,dict) or set(body)-{"recordIds","objectType","operation"}:raise APIError("Rattachement invalide.")
    ids=body.get("recordIds")
    if not isinstance(ids,list) or not 1<=len(ids)<=100:raise APIError("Sélectionnez entre 1 et 100 enregistrements.")
    if any(type(value) is bool for value in ids): raise APIError("Identifiant invalide.")
    ids=[positive(value) for value in ids]
    if len(set(ids))!=len(ids):raise APIError("La sélection contient des doublons.")
    operation=body.get("operation","ajouter")
    if not isinstance(operation,str) or operation not in {"ajouter","retirer"}:raise APIError("Opération invalide.")
    with transaction.atomic():
        folder=get_definition(actor,key,lock=True)
        if folder["mode"]!="manuel":raise APIError("Ce dossier est alimenté automatiquement.","AUTOMATIC_FOLDER",409)
        kind=folder["objectType"]
        if body.get("objectType")!=kind:raise APIError("La sélection ne correspond pas au type du dossier.","TYPE_MISMATCH",409)
        name,pk,member_pk,_=TYPES[kind]
        obj=view("logistique",name);_,where,params,*_=read_scope(obj,actor,condition=INVOICE if kind=="facture" else "TRUE")
        allowed=db.query('SELECT v.'+db.ident(pk)+' AS id,v.'+db.ident('ID_UserFK' if kind=='article' else 'ID_UserFk')+' IS NOT NULL AS has_owner FROM '+row_source(obj)+' WHERE '+where+' AND v.'+db.ident(pk)+'=ANY(%s::integer[])',[*params,ids])
        if {row["id"] for row in allowed}!=set(ids):raise APIError("Un enregistrement de la sélection n’est pas accessible.","NOT_FOUND",404)
        if any(not row["has_owner"] for row in allowed):raise APIError("Renseignez le responsable de chaque enregistrement avant de le classer.","OWNER_REQUIRED",409)
        if operation=="ajouter":
            rows=db.query('INSERT INTO logistique."T_DossierSuiviMembre" AS m ("ID_DossierSuiviFk",'+db.ident(member_pk)+') SELECT %s,id FROM unnest(%s::integer[]) AS t(id) ON CONFLICT ("ID_DossierSuiviFk",'+db.ident(member_pk)+') DO UPDATE SET "Actif"=true WHERE NOT m."Actif" RETURNING '+db.ident(member_pk),[folder["id"],sorted(ids)])
        else:
            rows=db.query('UPDATE logistique."T_DossierSuiviMembre" SET "Actif"=false WHERE "ID_DossierSuiviFk"=%s AND '+db.ident(member_pk)+'=ANY(%s::integer[]) AND "Actif" RETURNING '+db.ident(member_pk),[folder["id"],ids])
        audit({"schema":"logistique","name":"T_DossierSuiviMembre"},"UPDATE",new={"folder":folder["id"],"objectType":kind,"operation":operation,"records":ids,"changed":len(rows)},actor=actor)
        return {"changed":len(rows),"operation":operation}

class FoldersView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,key=None):
        if key:
            rows,meta=folder_rows(request.user,key,request.query_params.dict())
            return ok(rows,meta=meta)
        raw=request.query_params.dict()
        if set(raw)-{"archived"} or raw.get("archived","") not in {"","true","false"}:raise APIError("Filtre invalide.")
        return ok(catalogue(request.user,raw.get("archived")=="true"))
    def post(self,request,key=None):
        if key:raise APIError("Route invalide.","NOT_FOUND",404)
        return ok(save_folder(request.user,request.data),status=201)
    def put(self,request,key=None):
        if not key:raise APIError("Route invalide.","NOT_FOUND",404)
        return ok(save_folder(request.user,request.data,key))
    def patch(self,request,key=None):
        if not key:raise APIError("Route invalide.","NOT_FOUND",404)
        return ok(archive_folder(request.user,key,request.data))

class FolderCategoriesView(APIView):
    permission_classes=[IsERPAdmin]
    def post(self,request):return ok(create_category(request.user,request.data),status=201)

class FolderMembersView(APIView):
    permission_classes=[IsERPAdmin]
    def put(self,request,key):return ok(update_members(request.user,key,request.data))

class FolderPreviewView(APIView):
    permission_classes=[IsERPAdmin]
    def post(self,request):
        body=request.data
        if not isinstance(body,dict) or set(body)!={"rules","objectType"}:raise APIError("Critères d’aperçu invalides.")
        kind=object_type(body["objectType"])
        rules=validate_rules(body["rules"],"automatique",kind)
        obj,_,where,values,order,*_=folder_scope(request.user,{"mode":"automatique","objectType":kind,"rules":rules})
        count=db.one('SELECT COUNT(*) AS n FROM '+row_source(obj)+' WHERE '+where,values)["n"]
        rows=db.query('SELECT v.'+db.ident(TYPES[kind][1])+' AS id,v.'+db.ident(TYPES[kind][3])+' AS label FROM '+row_source(obj)+' WHERE '+where+' ORDER BY '+order+' LIMIT 5',values)
        return ok({"count":count,"records":rows,"objectType":kind})
