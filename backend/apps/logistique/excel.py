"""Exports XLSX natifs : lecture unique de la même vue et du même périmètre que la liste."""
import json
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from tempfile import SpooledTemporaryFile
import xlsxwriter
from django.conf import settings
from django.db import connection
from django.http import FileResponse
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.renderers import BaseRenderer
from rest_framework.response import Response
from apps.core import db
from apps.core.permissions import IsERPAdmin
from apps.core.responses import APIError, ExactJSONRenderer
from .reads import resolve_indicator, register_source, read_scope, row_source
from .table_queries import LABELS, NUMERIC, DATES, document_zone

ROOT = Path(settings.BASE_DIR).parent
ASSETS = ROOT / "skills" / "document-mise-en-forme" / "assets"
MAX_EXPORT_ROWS = 100000
DEFAULT_FIELDS = {
    "V_Article":["CodeArticleInterne","NomArticle","TypeArticle","CategorieArticle","Unite","QteArticle","QteMinArticle","PUArticle","PVArticle","DatePeremptionArticle","EtatStock","EtatPeremption"],
    "V_Commande":["CodeCmd","RefCmd","DateCmd","TypeCmd","StatutCmd","NomClientSaisi","NbLignes","MontantHT","MontantTTC","CodeFacture","DateFacture","MontantRegleFacture","MontantResteFacture","EtatPaiement"],
    "V_SuiviReglements":["CodeFacture","CodeCmd","DateFacture","DateEcheancePaiement","NomClientSaisi","MontantTTC","TotalRegle","Reste","EtatReglement"],
    "V_AuditStock":["NomArticle","StockArticle","StockMouvements","Ecart","EtatAuditStock"],
    "V_CouvertureStock":["NomArticle","StockActuel","ConsoMoyMensuelle","CouvertureMois","EtatCouverture"],
}

def export_columns(obj, raw):
    available = {c["column_name"]:c for c in obj["columns"]}
    wanted = raw.get("columns")
    if wanted:
        try:
            wanted = json.loads(wanted)
        except (ValueError, TypeError):
            raise APIError("Colonnes d’export invalides.")
    else:
        wanted = DEFAULT_FIELDS.get(obj["name"],[])
    if not isinstance(wanted,list) or not wanted or len(wanted)>40 or any(not isinstance(k,str) for k in wanted) or len(set(wanted)) != len(wanted):
        raise APIError("Colonnes d’export invalides.")
    if any(k not in available or k not in LABELS for k in wanted):
        raise APIError("Colonne d’export non autorisée.")
    wanted = list(wanted)
    # Les quantités restent numériques ; leur unité accompagne le tableau exporté.
    quantities = {"QteArticle","QteMinArticle","QteACommander","StockActuel","StockArticle","StockMouvements","ConsoMensuelle","ConsoMoyMensuelle","QteCmdDetail","QteMvtSigned"}
    if quantities.intersection(wanted) and not {"Unite","AbrUnite"}.intersection(wanted):
        unit = next((key for key in ("Unite","AbrUnite") if key in available),None)
        if unit:
            position = max(index for index,key in enumerate(wanted) if key in quantities)+1
            wanted.insert(position,unit)
    if "PoidsUnitaire" in wanted and "UnitePoids" in available and "UnitePoids" not in wanted:
        wanted.insert(wanted.index("PoidsUnitaire")+1,"UnitePoids")
    return [{**available[k],"label":LABELS[k]} for k in wanted]

def write_workbook(target, columns, rows, context):
    charter = json.loads((ASSETS / "charte_sauverndeko.json").read_text(encoding="utf-8"))
    palette = charter["palette"]
    book = xlsxwriter.Workbook(target, {"constant_memory":True,"strings_to_formulas":False,"strings_to_urls":False,"default_date_format":"dd/mm/yyyy hh:mm"})
    count, precise_text = 0, 0
    try:
        book.set_properties({"title":context["title"],"subject":"Liste filtrée complète","author":"SauverNdeko","comments":"Valeurs issues de la vue autorisée, sans recalcul métier."})
        sheet = book.add_worksheet("Données")
        base = {"font_name":charter["excel"]["police"],"font_size":11,"font_color":palette["texte"],"valign":"vcenter"}
        info_fmt = book.add_format({**base,"font_size":10,"font_color":palette["texte_secondaire"],"text_wrap":True})
        header_fmt = book.add_format({**base,"bold":True,"font_color":charter["excel"]["entete_texte"],"bg_color":charter["excel"]["entete_fond"],"text_wrap":True,"border":1,"border_color":charter["excel"]["bordure"]})
        styles = {}
        for zebra in [False,True]:
            bg = charter["excel"]["fond_alterne"] if zebra else palette["fond"]
            common = {**base,"bg_color":bg,"bottom":1,"bottom_color":charter["excel"]["bordure"]}
            for kind, num_fmt, align in [("text","@","left"),("number","#,##0.###","right"),("integer","#,##0","right"),("weight","#,##0.######","right"),("amount","#,##0.00","right"),("date","dd/mm/yyyy","left"),("datetime","dd/mm/yyyy hh:mm","left")]:
                styles[zebra,kind] = book.add_format({**common,"num_format":num_fmt,"align":align,"text_wrap":kind=="text"})
        last_column = len(columns)-1
        header_row = 0
        for col, field in enumerate(columns):
            sheet.write_string(header_row,col,field["label"],header_fmt)
            width = 30 if field["column_name"] in {"NomArticle","NomClientSaisi"} else 23 if field["data_type"] in DATES else 21
            sheet.set_column(col,col,width)
        sheet.set_row(header_row,32)
        sheet.freeze_panes(header_row+1,1)
        for row in rows:
            count += 1
            if count > MAX_EXPORT_ROWS:
                raise APIError("L’export dépasse 100 000 lignes. Affinez les filtres.","EXPORT_TOO_LARGE",413)
            line = header_row + count
            height = 24
            for col, field in enumerate(columns):
                key, typ = field["column_name"],field["data_type"]
                value = row.get(key)
                zebra = count % 2 == 0
                kind = "amount" if key.startswith(("Montant","PU","PV","Valeur","TotalRegle","Reste","Marge")) else "number"
                if value is None:
                    sheet.write_blank(line,col,None,styles[zebra,"number" if typ in NUMERIC else "text"])
                elif typ in NUMERIC:
                    number = Decimal(str(value))
                    if not number.is_finite():
                        raise APIError("Valeur numérique non exportable.")
                    if len(number.normalize().as_tuple().digits) > 15:
                        sheet.write_string(line,col,str(value),styles[zebra,"text"])
                        precise_text += 1
                    else:
                        if kind == "number":
                            kind = "integer" if number == number.to_integral_value() else "weight" if key == "PoidsUnitaire" else "number"
                        sheet.write_number(line,col,float(number),styles[zebra,kind])
                elif isinstance(value,datetime):
                    if timezone.is_aware(value):
                        value = value.astimezone(context["tz"]).replace(tzinfo=None)
                    sheet.write_datetime(line,col,value,styles[zebra,"datetime"])
                elif isinstance(value,date):
                    sheet.write_datetime(line,col,datetime.combine(value,datetime.min.time()),styles[zebra,"date"])
                else:
                    text = ("Oui" if value else "Non") if isinstance(value,bool) else str(value)
                    if len(text)>32767:
                        raise APIError("Une valeur dépasse la limite d’une cellule Excel.","EXPORT_CELL_TOO_LONG",413)
                    sheet.write_string(line,col,text,styles[zebra,"text"])
                    height = max(height,min(90,18*(1+len(text)//28)))
            sheet.set_row(line,height)
        sheet.autofilter(header_row,0,header_row+count,len(columns)-1)
        sheet.set_landscape()
        sheet.set_paper(9)
        sheet.fit_to_pages(1,0)
        sheet.repeat_rows(header_row)
        sheet.print_area(0,0,header_row+count,last_column)
        sheet.set_margins(.4,.4,.6,.6)
        sheet.set_footer("&LSauverNdeko&CPage &P sur &N&R"+context["generated"])
        info = book.add_worksheet("Informations")
        info.set_column(0,0,28)
        info.set_column(1,1,100)
        records = [("Document",context["title"]),("Logiciel","SauverNdeko"),("Périmètre",context["scope"]),("Portée","Tous les résultats filtrés"),("Lignes exportées",count),("Généré le",context["generated"]),("Fuseau horaire",context["zone"]),("Source",context["source"]),("Recherche de l’indicateur",context["raw"].get("populationQ",context["raw"].get("q",""))),("Recherche dans la liste",context["raw"].get("q","")),("Du",context["raw"].get("dateFrom","")),("Au",context["raw"].get("dateTo","")),("Tri",context["order"]),("Colonnes",", ".join(f["label"] for f in columns)),("Charte",charter["version"]),("Devise","Non renseignée")]
        for key, value in context["filters"].items():
            records.append(("Filtre · "+LABELS[key],value))
        if context.get("folder"):
            for label,value in [("Type de dossier",context["folder"]["objectType"]),("Alimentation",context["folder"]["mode"]),("Critères du dossier",json.dumps(context["folder"]["rules"],ensure_ascii=False))]:
                records.append((label,value))
        raw = context["raw"]
        for key,label in {"categorieId":"Catégorie · identifiant","typeId":"Type · identifiant","uniteId":"Unité · identifiant","statut":"Article actif","stockState":"État du stock","peremption":"Péremption","statutId":"Statut · identifiant","client":"Tiers · identifiant","sansDetails":"Sans lignes","payment":"Paiement","control":"Contrôle"}.items():
            if raw.get(key) not in (None,"","all"):
                records.append(("Critère · "+label,str(raw[key])))
        if precise_text:
            records.append(("Précision",str(precise_text)+" valeur(s) de plus de 15 chiffres conservée(s) en texte pour éviter une perte de précision Excel."))
        for row,(label,value) in enumerate(records):
            info.write_string(row,0,label,header_fmt)
            if isinstance(value,int): info.write_number(row,1,value,styles[False,"number"])
            else: info.write_string(row,1,str(value),styles[False,"text"])
            info.set_row(row,32)
        info.freeze_panes(0,1)
        info.set_portrait()
        info.set_paper(9)
        info.fit_to_pages(1,0)
        book.set_custom_property("Source",context["source"])
        book.set_custom_property("Lignes exportées",count)
        book.set_custom_property("Charte",charter["version"])
    finally:
        book.close()
    return count

def indicator_workbook(actor, key, raw):
    obj,condition,_,label,_,_,fixed = resolve_indicator(key,raw)
    _,where,values,order,sort,direction,applied = read_scope(obj,actor,raw,condition,fixed,raw.get("populationQ"))
    return scope_workbook(actor,key,obj,raw,where,values,order,sort,direction,applied,label)

def register_workbook(actor, kind, raw):
    obj,condition,fixed = register_source(kind,raw,for_export=True)
    _,where,values,order,sort,direction,applied = read_scope(obj,actor,raw,condition,fixed)
    label = "Registre des articles" if kind == "articles" else "Registre des bons de stock"
    return scope_workbook(actor,kind,obj,raw,where,values,order,sort,direction,applied,label)

def scope_workbook(actor, key, obj, raw, where, values, order, sort, direction, applied, label):
    folder_context = label if isinstance(label,dict) else None
    if folder_context: label=folder_context["title"]
    fields = export_columns(obj,raw)
    zone = document_zone(raw)
    generated = datetime.now(zone)
    scope = "Toutes les organisations autorisées" if actor.global_admin else "Organisation autorisée du compte"
    context = {"title":label,"scope":scope,"generated":generated.strftime("%d/%m/%Y %H:%M"),"zone":str(zone),"tz":zone,"source":obj["schema"]+"."+obj["name"],"raw":raw,"filters":applied,"order":LABELS.get(sort,sort)+" "+direction.upper(),"folder":folder_context}
    output = SpooledTemporaryFile(max_size=8*1024*1024,mode="w+b")
    try:
        with connection.cursor() as cursor:
            sql = "SELECT " + ",".join("v."+db.ident(f["column_name"]) for f in fields) + " FROM " + row_source(obj) + " WHERE " + where + " ORDER BY " + order + " LIMIT %s"
            cursor.execute(sql,[*values,MAX_EXPORT_ROWS+1])
            def rows():
                names = [f["column_name"] for f in fields]
                while batch := cursor.fetchmany(500):
                    for row in batch:
                        yield dict(zip(names,row))
            count = write_workbook(output,fields,rows(),context)
        output.seek(0)
        return output,count,"SauverNdeko_"+key+"_"+generated.strftime("%Y-%m-%d")+"_Complet.xlsx"
    except Exception:
        output.close()
        raise

XLSX_MEDIA_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


class ExcelFileRenderer(BaseRenderer):
    """Accepte le type Excel demandé par le navigateur avant la création du fichier."""
    media_type = XLSX_MEDIA_TYPE
    format = "xlsx"
    charset = None
    render_style = "binary"

    def render(self, data, accepted_media_type=None, renderer_context=None):
        if data is None:
            return b""
        if not isinstance(data, (bytes, bytearray, memoryview)):
            raise TypeError("Le rendu Excel attend un fichier binaire.")
        return bytes(data)


class ExcelDownloadView(APIView):
    """Fichier XLSX en succès ; réponses structurées, notamment les refus, en JSON."""
    permission_classes = [IsERPAdmin]
    renderer_classes = [ExactJSONRenderer, ExcelFileRenderer]

    def finalize_response(self, request, response, *args, **kwargs):
        # FileResponse garde son type natif. Une erreur ne devient jamais un faux .xlsx.
        if isinstance(response, Response):
            request.accepted_renderer = ExactJSONRenderer()
            request.accepted_media_type = "application/json"
        return super().finalize_response(request, response, *args, **kwargs)


class IndicatorExcelView(ExcelDownloadView):
    permission_classes = [IsERPAdmin]
    def get(self,request,key):
        stream,count,filename = indicator_workbook(request.user,key,request.query_params.dict())
        response = FileResponse(stream,as_attachment=True,filename=filename,content_type=XLSX_MEDIA_TYPE)
        response["X-Export-Row-Count"] = str(count)
        response["Cache-Control"] = "no-store, private"
        return response

class RegisterExcelView(ExcelDownloadView):
    permission_classes = [IsERPAdmin]
    def get(self,request,kind):
        stream,count,filename = register_workbook(request.user,kind,request.query_params.dict())
        response = FileResponse(stream,as_attachment=True,filename=filename,content_type=XLSX_MEDIA_TYPE)
        response["X-Export-Row-Count"] = str(count)
        response["Cache-Control"] = "no-store, private"
        return response

class FolderExcelView(ExcelDownloadView):
    permission_classes = [IsERPAdmin]
    def get(self,request,key):
        from .followup_folders import get_definition, folder_scope
        folder = get_definition(request.user,key)
        obj,_,where,values,order,sort,direction,applied = folder_scope(request.user,folder,request.query_params.dict())
        stream,count,filename = scope_workbook(request.user,key,obj,request.query_params.dict(),where,values,order,sort,direction,applied,{"title":folder["name"],"objectType":folder["objectType"],"mode":folder["mode"],"rules":folder["rules"]})
        response = FileResponse(stream,as_attachment=True,filename=filename,content_type=XLSX_MEDIA_TYPE)
        response["X-Export-Row-Count"] = str(count)
        response["Cache-Control"] = "no-store, private"
        return response
