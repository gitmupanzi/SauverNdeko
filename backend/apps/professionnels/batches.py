"""Profils professionnels : Excel vers brouillons et panier transactionnel.

L'import ne publie ni profil ni photo, ne crée aucun compte ni référentiel et
ne change jamais l'entreprise. La confirmation réutilise le service individuel.
"""
import hashlib
import json
import re
import uuid

from django.db import DatabaseError, transaction
from django.http import FileResponse

from apps.core.batch_excel import ExcelPreviewMixin, build_template, read_uploaded_workbook
from apps.core.permissions import HasModuleAccess
from apps.core.responses import APIError, ExactEncoder, ok
from apps.logistique.excel import ExcelDownloadView, XLSX_MEDIA_TYPE
from . import services as service
from .views import ProfessionalView

MAX_ROWS = 100
SHEET = 'Profils'
FIELDS = [
    ('IdUserFk', 'Utilisateur', 'users'),
    ('IdSecteurFk', 'Secteur', 'secteurs'),
    ('IdTypeProfessionnelFk', 'Profession', 'types'),
    ('IdSpecialiteFk', 'Spécialité', 'specialites'),
    ('TitrePublic', 'Titre professionnel', None),
    ('PresentationPublique', 'Présentation', None),
    ('LocalitePublique', 'Localité ou zone d’intervention', None),
    ('ExperienceAns', 'Années d’expérience', None),
    ('NumeroIdentification', 'Identification professionnelle', None),
    ('ObsProfessionnel', 'Observations internes', None),
    ('ContactAutorise', 'Autoriser les contacts', None),
    ('competenceIds', 'Compétences', 'competences'),
    ('prestationIds', 'Services proposés', 'prestations'),
]
HEADERS = {alias: key for key, label, _ in FIELDS for alias in (key, label)}
REQUIRED = {'IdUserFk', 'IdSecteurFk', 'IdTypeProfessionnelFk', 'TitrePublic'}
ROW_FIELDS = {'data', 'competenceIds', 'prestationIds', 'affiliations'}
BUSINESS_STATES = {'P0001', '23514', '23503', '23505', '40001', '40P01', '55P03'}


def invalid(rows=None, header=None):
    raise APIError({'rows': rows or {}, 'header': header or {}}, 'PROFESSIONAL_BATCH_VALIDATION', 422)


def _row_errors(detail):
    if not isinstance(detail, dict):
        return {'_line': str(detail)}
    result = {}
    for field, message in detail.items():
        field = field.removeprefix('data.').split('.')[0]
        field = {'IdCompetenceFk': 'competenceIds', 'IdPrestationFk': 'prestationIds'}.get(field, field)
        if field not in service.PROFILE_FIELDS | {'competenceIds', 'prestationIds', 'affiliations'}:
            field = '_line'
        text = ' '.join(map(str, message)) if isinstance(message, list) else str(message)
        result[field] = (result[field] + ' ' if field in result else '') + text
    return result


@transaction.atomic
def create_batch(actor, body):
    service.writable(actor)
    if not isinstance(body, dict) or set(body) != {'requestId', 'rows'}:
        invalid(header={'rows': 'Vérifiez le format du panier.'})
    try:
        request_id = uuid.UUID(str(body.get('requestId')))
    except (AttributeError, TypeError, ValueError):
        invalid(header={'requestId': 'Identifiant de demande invalide.'})
    rows = body.get('rows')
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_ROWS:
        invalid(header={'rows': 'Ajoutez de 1 à 100 profils.'})
    seen, users, issues = set(), {}, {}
    for row in rows:
        if not isinstance(row, dict) or not {'clientRowId', 'data'}.issubset(row) or set(row)-{'clientRowId', *ROW_FIELDS}:
            invalid(header={'rows': 'Chaque ligne attend son identifiant et ses informations.'})
        row_id = row['clientRowId']
        if not isinstance(row_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,100}', row_id) or row_id in seen:
            invalid(header={'rows': 'Les identifiants de ligne doivent être distincts.'})
        seen.add(row_id)
        values = row['data']
        if not isinstance(values, dict) or set(values)-service.PROFILE_FIELDS:
            invalid({row_id: {'_line': 'Vérifiez les informations du profil.'}})
        problems = {}
        for key in REQUIRED:
            value = values.get(key)
            if value is None or isinstance(value, str) and not value.strip():
                problems[key] = 'Ce champ est obligatoire.'
        user = str(values.get('IdUserFk') or '')
        if re.fullmatch(r'[1-9][0-9]*', user):
            if user in users:
                problems['IdUserFk'] = 'Ce compte possède déjà une ligne dans le panier.'
                issues.setdefault(users[user], {})['IdUserFk'] = 'Ce compte possède déjà une ligne dans le panier.'
            else:
                users[user] = row_id
        if problems:
            issues.setdefault(row_id, {}).update(problems)
    if issues:
        invalid(issues)
    try:
        canonical = json.dumps(body, cls=ExactEncoder, sort_keys=True, ensure_ascii=False,
                               separators=(',', ':'), allow_nan=False).encode('utf8')
    except (TypeError, ValueError, UnicodeError):
        invalid(header={'rows': 'Le panier contient une valeur invalide.'})
    if len(canonical) > 2 * 1024 * 1024:
        raise APIError('Le panier dépasse 2 Mo. Enregistrez moins de profils à la fois.', 'PROFESSIONAL_BATCH_TOO_LARGE', 413)
    digest = hashlib.sha256(canonical).hexdigest()
    records, replays = [], []
    for index, row in enumerate(rows):
        payload = {key: value for key, value in row.items() if key != 'clientRowId'}
        payload['requestId'] = str(uuid.uuid5(request_id, f'professionnels:{actor.pk}:{index}'))
        try:
            # Savepoint par ligne : une contrainte ne casse pas la lecture des
            # autres erreurs. L'exception finale annule le lot et ses audits.
            with transaction.atomic():
                result = service.create(actor, payload, _batch_digest=digest)
        except APIError as exc:
            if exc.status_code in {401, 403, 503} or exc.default_code.startswith('IDEMPOTENCY_'):
                raise
            issues[row['clientRowId']] = _row_errors(exc.detail)
        except DatabaseError as exc:
            sqlstate = getattr(exc.__cause__, 'sqlstate', None)
            if sqlstate not in BUSINESS_STATES:
                raise
            if sqlstate in {'40001', '40P01', '55P03'}:
                raise APIError('Une autre opération est en cours. Réessayez l’enregistrement du panier.',
                               'PROFESSIONAL_CONFLICT', 409) from exc
            issues[row['clientRowId']] = {'_line': 'Profil non enregistré. Vérifiez le compte, les références et les structures ; un seul profil est permis par compte.'}
        else:
            records.append({'clientRowId': row['clientRowId'], 'id': result['record']['IdProfessionnel']})
            replays.append(result.get('replayed') is True)
    if issues:
        invalid(issues)
    return {'requestId': str(request_id), 'count': len(records), 'records': records}, all(replays)


class ProfessionalTemplateView(ExcelDownloadView):
    permission_classes = [HasModuleAccess]

    def get(self, request):
        service.writable(request.user)
        if request.query_params:
            raise APIError('Critère non autorisé.')
        references = service.references(request.user)
        columns = []
        for key, label, source in FIELDS:
            choices = [{'value': str(item['id']), 'label': item['label']}
                       for item in references.get(source, [])
                       if not item.get('disabled') and not item.get('incompatible')] if source else []
            if key == 'ContactAutorise':
                choices = [{'value': 'Oui', 'label': 'Autoriser les contacts'},
                           {'value': 'Non', 'label': 'Ne pas autoriser les contacts'}]
            columns.append({'key': key, 'label': label, 'required': key in REQUIRED,
                            'width': 48 if key in {'PresentationPublique', 'ObsProfessionnel'} else 28,
                            **({'choices': choices} if choices else {})})
        stream = build_template(sheet_name=SHEET, columns=columns, notes=[
            ('Périmètre', 'Les profils appartiennent à l’entreprise active. Aucun compte utilisateur n’est créé par cet import.'),
            ('Obligatoire', 'Utilisateur, Secteur, Profession et Titre professionnel.'),
            ('Plusieurs choix', 'Séparez les compétences et services par ; (point-virgule). Utilisez les identifiants de la feuille Options ou leurs libellés exacts.'),
            ('Publication', 'Tous les profils sont créés en brouillon ; la publication reste une action explicite.'),
            ('Compte', 'Un seul profil par compte. Les comptes et références doivent être autorisés pour l’entreprise.'),
            ('Détails', 'Vérifiez les champs dans le panier. Les affiliations sont modifiables dans ses détails ; ajoutez les photos ensuite dans la fiche individuelle.'),
            ('Limites', 'Titre : 180 caractères ; présentation : 10 000 ; observations internes : 5 000 ; expérience entière de 0 à 100 ans.'),
        ], max_rows=MAX_ROWS)
        response = FileResponse(stream, as_attachment=True, filename='SauverNdeko_Modele_Profils_professionnels.xlsx', content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class ProfessionalExcelPreviewView(ExcelPreviewMixin, ProfessionalView):
    http_method_names = ['post', 'options']

    def post(self, request):
        service.writable(request.user)
        if request.query_params:
            raise APIError('Critère non autorisé.')
        matrix = read_uploaded_workbook(request, sheet_name=SHEET, headers=HEADERS,
                                        required_headers=REQUIRED, max_rows=MAX_ROWS)
        return ok({'matrix': matrix})


class ProfessionalBatchView(ProfessionalView):
    http_method_names = ['post', 'options']

    def post(self, request):
        result, replayed = create_batch(request.user, request.data)
        return ok(result, status=200 if replayed else 201, meta={'replayed': replayed})
