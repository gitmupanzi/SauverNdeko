"""Routes fermées de l'annuaire et de la gestion des professionnels."""
import io
from django.conf import settings
from django.db import DatabaseError
from django.http import FileResponse
from rest_framework.views import APIView

from apps.core.parsers import ExactJSONParser
from apps.core.permissions import HasModuleAccess
from apps.core.responses import APIError, ExactJSONRenderer, ok
from apps.accounts.photos import ProfilePhotoFileRenderer
from . import services as service


class ProfessionalJSONParser(ExactJSONParser):
    def parse(self, stream, media_type=None, parser_context=None):
        # Le JSON est borné avant son décodage, y compris sans Content-Length.
        # DATA_UPLOAD_MAX_MEMORY_SIZE n'est pas appliqué automatiquement aux
        # parseurs JSON qui lisent directement le flux WSGI.
        content = stream.read(settings.DATA_UPLOAD_MAX_MEMORY_SIZE+1)
        if len(content) > settings.DATA_UPLOAD_MAX_MEMORY_SIZE:
            raise APIError('Le formulaire dépasse la taille maximale autorisée.', 'PROFESSIONAL_BODY_TOO_LARGE', 413)
        return super().parse(io.BytesIO(content), media_type, parser_context)


class ProfessionalView(APIView):
    permission_classes = [HasModuleAccess]
    parser_classes = [ProfessionalJSONParser]

    def handle_exception(self, error):
        if isinstance(error, DatabaseError) and getattr(error.__cause__, 'sqlstate', None) in {'P0001', '23514', '23503', '23505', '40001', '40P01', '55P03'}:
            error = APIError('Enregistrement refusé. Vérifiez le compte, les références, la publication et l’affiliation du profil.', 'PROFESSIONAL_CONFLICT', 409)
        return super().handle_exception(error)


class ContextView(ProfessionalView):
    def get(self, request):
        return ok(service.capabilities(request.user))


class EntitiesView(ProfessionalView):
    def get(self, request):
        return ok(service.entities(request.user))


class ReferencesView(ProfessionalView):
    def get(self, request):
        if set(request.query_params)-{'profileId'}:
            raise APIError('Paramètre non autorisé.')
        return ok(service.references(request.user, request.query_params.get('profileId')))


class DirectoryView(ProfessionalView):
    def get(self, request, pk=None):
        return ok(service.directory_detail(request.user, pk) if pk else service.directory(request.user, request.query_params.dict()))


class ProfilesView(ProfessionalView):
    def get(self, request, pk=None):
        return ok(service.detail(request.user, pk) if pk else service.register(request.user, request.query_params.dict()))

    def post(self, request, pk=None):
        if pk:
            raise APIError('Créez le profil depuis le registre.', 'METHOD_NOT_ALLOWED', 405)
        return ok(service.create(request.user, request.data), status=201)

    def put(self, request, pk=None):
        if not pk:
            raise APIError('Identifiant du profil requis.', 'METHOD_NOT_ALLOWED', 405)
        return ok(service.modify(request.user, pk, request.data))


class ProfileActionView(ProfessionalView):
    def post(self, request, pk):
        return ok(service.action(request.user, pk, request.data))


class PublicPhotoView(ProfessionalView):
    renderer_classes = [ExactJSONRenderer, ProfilePhotoFileRenderer]
    def get(self, request, pk):
        from apps.accounts.photos import photo_path
        row = service.public_record(pk, actor=request.user)
        user = row.get('T_Utilisateurs') or {}
        path = photo_path(user.get('UrlPhoto'), user.get('IdUser'))
        try:
            response = FileResponse(path.open('rb'), content_type='image/jpeg', as_attachment=False, filename='professionnel.jpg')
        except FileNotFoundError as error:
            raise APIError('Photo indisponible.', 'NOT_FOUND', 404) from error
        response['Cache-Control'] = 'no-store, private'
        response['X-Content-Type-Options'] = 'nosniff'
        response['Content-Security-Policy'] = "default-src 'none'; sandbox"
        return response


class ManagementPhotoView(PublicPhotoView):
    def get(self, request, pk):
        from apps.accounts.photos import photo_path
        row = service.record(request.user, pk)
        path = photo_path(row.get('UrlPhoto'), row.get('IdUserFk'))
        try:
            response = FileResponse(path.open('rb'), content_type='image/jpeg', as_attachment=False, filename='professionnel.jpg')
        except FileNotFoundError as error:
            raise APIError('Photo indisponible.', 'NOT_FOUND', 404) from error
        response['Cache-Control'] = 'no-store, private'
        response['X-Content-Type-Options'] = 'nosniff'
        response['Content-Security-Policy'] = "default-src 'none'; sandbox"
        return response
