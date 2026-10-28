"""Photos privées d’articles : fichiers contrôlés, noms métier et compensation en cas d’échec."""
import io
import hashlib
import hmac
import json
import re
import unicodedata
import uuid
import warnings
from decimal import Decimal
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError
from django.conf import settings
from django.http import FileResponse
from django.db import transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.permissions import IsERPAdmin, HasModuleAccess
from apps.core.registry import model
from apps.core.repository import get_record, mutate, positive, check_global_write, clean
from apps.core.responses import APIError, ExactEncoder
from .article_rules import check_revision

MAX_BYTES=8*1024*1024
def stored_photo(value):
    return isinstance(value,str) and re.fullmatch(r"Article/[a-zA-Z0-9_-]+_[a-f0-9]{32}\.jpg",value) is not None

def photo_path(value):
    if not stored_photo(value):raise APIError("Photo indisponible.","NOT_FOUND",404)
    root=Path(settings.ARTICLE_MEDIA_ROOT).resolve()
    target=(root/value).resolve()
    if not target.is_relative_to(root/"Article"):raise APIError("Photo indisponible.","NOT_FOUND",404)
    return target

def normalize_photo(upload):
    if upload.size>MAX_BYTES:raise APIError({"photo":"L’image ne doit pas dépasser 8 Mo."},"ARTICLE_VALIDATION",400)
    blob=upload.read(MAX_BYTES+1)
    if len(blob)>MAX_BYTES:raise APIError({"photo":"L’image ne doit pas dépasser 8 Mo."},"ARTICLE_VALIDATION",400)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error",Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(blob)) as source:
                if source.format not in {"JPEG","PNG","WEBP"} or source.width*source.height>24000000:raise ValueError()
                source.load()
                source=ImageOps.exif_transpose(source)
                source.thumbnail((1600,1600))
                rgba=source.convert("RGBA")
                image=Image.new("RGB",rgba.size,"white");image.paste(rgba,mask=rgba.getchannel("A"))
                output=io.BytesIO();image.save(output,format="JPEG",quality=88,optimize=True)
                return output.getvalue()
    except (UnidentifiedImageError,ValueError,OSError,Image.DecompressionBombError,Image.DecompressionBombWarning) as exc:
        raise APIError({"photo":"Choisissez une image JPEG, PNG ou WebP valide de 24 millions de pixels au maximum."},"ARTICLE_VALIDATION",400) from exc

def request_data(request):
    if request.content_type.startswith("multipart/form-data"):
        if set(request.data)-{"payload","photo"}:raise APIError("Contenu de formulaire non autorisé.")
        try:
            raw=request.data.get("payload","")
            if not isinstance(raw,str) or len(raw)>262144:raise ValueError()
            body=json.loads(raw,parse_float=Decimal)
        except (ValueError,TypeError):
            raise APIError("Formulaire article invalide.")
        return body,request.FILES.get("photo")
    return request.data,None

def save_article(actor,body,upload=None,pk=None):
    db.ensure_writable()
    if not isinstance(body,dict):raise APIError("Objet JSON attendu.")
    data=dict(body)
    request_id=data.pop("requestId",None)
    if pk is None:
        try:request_id=str(uuid.UUID(str(request_id)))
        except (ValueError,TypeError,AttributeError):raise APIError("Identifiant de création requis. Rouvrez le formulaire.","ARTICLE_REQUEST_REQUIRED",400)
    elif request_id is not None:raise APIError("Identifiant de création inattendu à la modification.","ARTICLE_VALIDATION",400)
    old=get_record(model("T_Article"),actor,{"ID_Article":positive(pk)}) if pk is not None else None
    if old:check_revision(old,data.get("_version"))
    if "PhotoArticle" in data:
        if data["PhotoArticle"] not in (None,"",(old or {}).get("PhotoArticle")):raise APIError({"photo":"Ajoutez la photo avec le sélecteur d’image."},"ARTICLE_VALIDATION",400)
        data.pop("PhotoArticle")
    remove=data.pop("_removePhoto",False)
    if type(remove) is not bool:raise APIError("Choix de photo invalide.")
    if remove and upload:raise APIError("Choisissez une seule action pour la photo.")
    initial=data.pop("LotsInitiaux",None)
    if old and initial is not None:raise APIError("Les lots se renseignent depuis les bons de stock.","LOT_INITIAL_ONLY",400)
    new_path=None
    try:
        encoded=normalize_photo(upload) if upload else None
        with transaction.atomic():
            metadata=None
            if pk is None:
                from apps.core.tenancy import require_entity
                entity=require_entity(actor)
                check_global_write(model("T_Article"),actor)
                fingerprint=hashlib.sha256(json.dumps({"body":data,"removePhoto":remove,"LotsInitiaux":initial,
                    "photo":hashlib.sha256(encoded).hexdigest() if encoded is not None else None},
                    cls=ExactEncoder,sort_keys=True,ensure_ascii=False,separators=(",",":")).encode("utf8")).hexdigest()
                db.query("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",[f"article-create:{entity}:{actor.pk}:{request_id}"])
                replay=db.one('''SELECT * FROM logistique."T_Article" WHERE "IdEntiteFk"=%s AND "ID_UserFK"=%s AND "CreationRequestId"=%s''',[entity,actor.pk,request_id])
                if replay is not None:
                    if not hmac.compare_digest(replay.get("CreationPayloadHash") or "",fingerprint):
                        raise APIError("Cette demande a déjà été utilisée avec un autre contenu.","ARTICLE_REQUEST_CONFLICT",409)
                    return clean(replay)
                metadata={"CreationRequestId":request_id,"CreationPayloadHash":fingerprint}
            if encoded is not None:
                name=str(data.get("NomArticle") or (old or {}).get("NomArticle") or "article")
                name=unicodedata.normalize("NFKD",name).encode("ascii","ignore").decode()
                name=re.sub(r"[^a-zA-Z0-9_-]+","-",name).strip("-_")[:90] or "article"
                relative="Article/"+name+"_"+uuid.uuid4().hex+".jpg"
                new_path=photo_path(relative);new_path.parent.mkdir(parents=True,exist_ok=True)
                with new_path.open("xb") as destination:destination.write(encoded)
                data["PhotoArticle"]=relative
            elif remove:data["PhotoArticle"]=None
            row=mutate("T_Article",actor,data,{"ID_Article":positive(pk)} if pk else None,"update" if pk else "create",_creation_metadata=metadata)
            if initial:
                from .lots import initial_lots
                initial_lots(row,initial)
            return row
    except BaseException:
        if new_path is not None:new_path.unlink(missing_ok=True)
        raise

class ArticlePhotoView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk):
        record=get_record(model("T_Article"),request.user,{"ID_Article":positive(pk)})
        return image_response(record.get("PhotoArticle"))

class PublicArticlePhotoView(APIView):
    permission_classes=[HasModuleAccess]
    def get(self,request,pk,kind=None):
        # Même projection active que le catalogue authentifié ; aucun accès aux fichiers arbitraires.
        record=db.one('SELECT "PhotoArticle" FROM logistique."V_Article" WHERE "ID_Article"=%s AND "ValideArticle" IS TRUE',[positive(pk)])
        if not record:raise APIError("Photo indisponible.","NOT_FOUND",404)
        return image_response(record["PhotoArticle"])

def image_response(value):
    target=photo_path(value)
    try:response=FileResponse(target.open("rb"),content_type="image/jpeg",as_attachment=False,filename=target.name)
    except FileNotFoundError:raise APIError("Photo indisponible.","NOT_FOUND",404)
    response["Cache-Control"]="no-store, private"
    response["X-Content-Type-Options"]="nosniff"
    return response
