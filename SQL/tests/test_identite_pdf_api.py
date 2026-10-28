"""Sept PDF métier réels, données fictives et base locale sauverndeko_test_*.

Exécuter avec le Python backend et pypdf installé, ou indiquer le dossier des
paquets PDF de recette dans SAUVERNDEKO_TEST_PDF_PACKAGES. Aucun repli production.
"""
import hashlib
import io
import json
import os
import sys
import uuid
from pathlib import Path

pdf_packages = os.environ.get('SAUVERNDEKO_TEST_PDF_PACKAGES')
if pdf_packages:
    sys.path.append(pdf_packages)
from pypdf import PdfReader
from PIL import Image
from django.core.files.uploadedfile import SimpleUploadedFile
from test_bons_commande_api import BonsCommandeAPI, ROOT, DSN, location
from apps.core.responses import ExactEncoder
from apps.logistique import entity_documents, documents
from rest_framework.test import APIClient
from django.db import connections

checks = []
def check(value, message):
    assert value, message
    checks.append(message)

def response_data(response, status=200):
    check(response.status_code == status, 'HTTP attendu ' + str(status) + (' : ' + str(getattr(response, 'data', {})) if response.status_code != status else ''))
    return response.data

def digest(value):
    return hashlib.sha256(json.dumps(value, cls=ExactEncoder, sort_keys=True, ensure_ascii=False).encode()).hexdigest()

def logo(color):
    output = io.BytesIO()
    Image.new('RGBA', (64, 32), (*color, 255)).save(output, format='PNG')
    return SimpleUploadedFile('logo-fictif.png', output.getvalue(), content_type='image/png')

BonsCommandeAPI.setUpClass()
fixture = BonsCommandeAPI(methodName='runTest')
c, actor, client = fixture.connection, fixture.actor(), fixture.client()
tag = uuid.uuid4().hex[:8]
out = ROOT / '.runtime/identite-pdf-api'
out.mkdir(parents=True, exist_ok=True)

def profile_body(**changes):
    profile = entity_documents.profile(actor)
    body = {key: profile.get(key) for key in entity_documents.FIELDS}
    body.update(IdEntite=actor.organisation, _version=profile['_version'], motif='Profil fictif pour recette PDF', requestId=str(uuid.uuid4()))
    body.update(changes)
    return body

old_company, current_company = 'EMETTEUR AVANT PDF ' + tag, 'EMETTEUR ACTUEL PDF ' + tag
current_address, current_site = 'Adresse actuelle fictive ' + tag, 'https://example.invalid/' + tag
second_phone = '+243 81 000 00 00'
footer_marker = 'MENTION ACTUELLE PDF ' + tag
entity_documents.save(actor, profile_body(NomEntite=old_company, AdresseEntite='Adresse antérieure fictive', logoAction='replace'), logo((211, 21, 11)))
# Les fixtures isolées peuvent contenir plusieurs variantes Entrée : conserver
# l’option canonique choisie par le même catalogue avant les restitutions.
c.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_CategorieGeneriqueFk"=64 AND "AbrGenerique" ILIKE \'entr%%\' AND "ID_Generique"<>%s', [fixture.be])
c.execute('INSERT INTO referentiel."T_CategorieGenerique" ("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES (30,\'Type de personne\',true),(36,\'Mode de paiement\',true) ON CONFLICT DO NOTHING')
def reference(category, name, code):
    row = c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "AbrGenerique"=%s AND "ValideGenerique" IS TRUE ORDER BY 1 LIMIT 1', [category, code]).fetchone()
    return row['id'] if row else c.execute('INSERT INTO referentiel."T_Generique" ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES (%s,%s,%s,true) RETURNING "ID_Generique" id', [category, name, code]).fetchone()['id']
tier_type, mode = reference(30, 'Client fictif PDF', 'Client'), reference(36, 'Espèces fictives PDF', 'TEST-PDF-CASH')
tier_name = 'TIERS HISTORIQUE PDF ' + tag
tier = c.execute('INSERT INTO logistique."T_Client" ("IdEntiteFk","Nature","ID_TypeClientFk","Nom","CreeParUserFk","ModifieParUserFk","Actif") VALUES (%s,\'entreprise\',%s,%s,%s,%s,true) RETURNING "ID_Client" id', [actor.organisation, tier_type, tier_name, actor.pk, actor.pk]).fetchone()['id']
article = fixture.article()
receipt = {'requestId': str(uuid.uuid4()), 'ID_TypeCmdFk': fixture.be, 'ID_DeviseFk': fixture.currency,
    'DateCmd': '2026-10-28T10:00:00', 'QteCmdDetail': '10', 'PUCmdDetail': '8', 'Lots': []}
entry = response_data(client.post(f'/api/logistique/articles/{article}/receptions', receipt, format='json'), 201)['data']['bon']['ID_Commande']
sale_body = fixture.payload(article, kind=fixture.bs, quantity='3', price='12')
sale_body['bon'].update(ID_TiersFk=tier, RefCmd='REFERENCE FICTIVE PDF ' + tag)
sold = fixture.create(sale_body)['bon']['ID_Commande']
planned = fixture.create(fixture.payload(article, quantity='7', price='11'))['bon']['ID_Commande']
context = response_data(client.get(f'/api/logistique/commandes/{sold}/facture'))
invoice = response_data(client.post(f'/api/logistique/commandes/{sold}/facture', {'requestId': str(uuid.uuid4()), '_version': context['meta']['revision'], 'DateFacture': '2026-10-28T12:00:00', 'DateEcheancePaiement': '2026-11-28T12:00:00'}, format='json'), 201)['data']['facture']
prepared = response_data(client.get('/api/logistique/reglements/preparation', {'commandeId': sold}))
payment = response_data(client.post('/api/logistique/reglements', {'requestId': str(uuid.uuid4()), '_version': prepared['meta']['revision'], 'CodeFactureFk': invoice['CodeFacture'], 'ID_ModeReglementFk': mode, 'DateReglement': '2026-10-28T12:30:00', 'MontantRegle': '5'}, format='json'), 201)['data']['ID_Reglement']
returns = response_data(client.get(f'/api/logistique/commandes/{sold}/retours'))
response_data(client.post(f'/api/logistique/commandes/{sold}/retours', {'requestId': str(uuid.uuid4()), '_version': returns['meta']['revision'], 'DateCmd': '2026-10-28T13:00:00', 'motif': 'Retour fictif de recette PDF', 'lignes': [{'ID_ArticleFk': article, 'QteRetour': '1', 'Lots': []}]}, format='json'), 201)
context = response_data(client.get(f'/api/logistique/commandes/{sold}/avoirs'))
credit = response_data(client.post(f'/api/logistique/commandes/{sold}/avoirs', {'requestId': str(uuid.uuid4()), '_version': context['meta']['revision'], 'DateAvoir': '2026-10-28T13:30:00', 'Motif': 'Avoir fictif de recette PDF'}, format='json'), 201)['data']['avoir']['ID_Avoir']
variants = [('bon', entry, 'entree'), ('bon', sold, 'sortie'), ('bon', sold, 'livraison'), ('bon', planned, 'commande'), ('facture', sold, 'facture'), ('reglement', payment, 'recu'), ('avoir', credit, 'avoir')]

def business_state():
    state = {}
    for table in ['T_Commande', 'T_CommandeDetail', 'T_Mouvement', 'T_LotArticle', 'T_MouvementLot', 'T_Facture', 'T_FactureLigne', 'T_Reglements', 'T_RetourBon', 'T_Avoir', 'T_AvoirLigne', 'T_DocumentIdentite', 'T_BonCodeHistorique']:
        state[table] = digest(c.execute('SELECT to_jsonb(t) AS row FROM logistique."' + table + '" t ORDER BY to_jsonb(t)::text').fetchall())
    return state

before = business_state()
before_data = {(kind, key, variant): documents.document_data(actor, kind, key, variant) for kind, key, variant in variants}
audit_max = c.execute('SELECT max("IdLog") id FROM systeme."T_Audit_Log"').fetchone()['id']
audit_hash = digest(c.execute('SELECT to_jsonb(t) row FROM systeme."T_Audit_Log" t WHERE "IdLog"<=%s ORDER BY "IdLog"', [audit_max]).fetchall())
entity_documents.save(actor, profile_body(NomEntite=current_company, AdresseEntite=current_address, SiteWebEntite=current_site,
    PhoneSecondaireEntite=second_phone,
    IdentifiantsLegauxEntite=[{'libelle': 'RCCM', 'valeur': 'FICTIF-RCCM-' + tag}, {'libelle': 'ID national', 'valeur': 'FICTIF-ID-' + tag}],
    MentionDocumentaireEntite=footer_marker, logoAction='replace'), logo((21, 111, 211)))
c.execute('UPDATE logistique."T_Client" SET "Nom"=%s WHERE "ID_Client"=%s', ['TIERS ACTUEL PDF ' + tag, tier])

artifacts = []
for show_head, show_foot in [(True, True), (True, False), (False, True), (False, False)]:
    entity_documents.save(actor, profile_body(AfficherEnteteDocument=show_head, AfficherPiedDocument=show_foot))
    for kind, key, variant in variants:
        data = documents.document_data(actor, kind, key, variant)
        check(data['emitter']['NomEntite'] == current_company, variant + ' émetteur courant après renommage')
        if kind in {'facture', 'reglement', 'avoir'}:
            retained = {name: value for name, value in data.items() if name != 'emitter'}
            previous = {name: value for name, value in before_data[kind, key, variant].items() if name != 'emitter'}
            check(retained == previous, variant + ' tiers, référence, lignes et montants historiques inchangés')
            check((data.get('thirdParty') or {}).get('Nom') == tier_name, variant + ' tiers figé après changement du client')
        response = client.get(f'/api/logistique/documents/{kind}/{key}/{variant}.pdf', HTTP_ACCEPT='application/pdf')
        check(response.status_code == 200, variant + ' export PDF HTTP200 : ' + str(getattr(response, 'data', '')))
        check(response['Content-Type'] == 'application/pdf' and 'no-store' in response['Cache-Control'], variant + ' téléchargement privé PDF')
        reader = PdfReader(io.BytesIO(response.content))
        text = '\n'.join(page.extract_text() or '' for page in reader.pages)
        check(current_company in text and old_company not in text, variant + ' identité courante imprimée')
        check((current_address in text) == show_head and (current_site in text) == show_head, variant + ' coordonnées selon option en-tête persistée')
        check((second_phone in text) == show_head, variant + ' second téléphone selon option en-tête persistée')
        check((footer_marker in text) == show_foot and ('FICTIF-RCCM-' + tag in text) == show_foot, variant + ' mentions selon option pied persistée')
        check(('Page 1 sur' in text) == show_foot, variant + ' pagination masquée avec le pied')
        images = [image.image for page in reader.pages for image in page.images]
        check(bool(images) == show_head, variant + ' logo selon option en-tête')
        if show_head:
            check(any(image.convert('RGB').getpixel((0, 0)) == (21, 111, 211) for image in images), variant + ' nouveau logo actuel, ancien remplacé')
        path = out / f'{variant}-entete{int(show_head)}-pied{int(show_foot)}.pdf'
        path.write_bytes(response.content)
        artifacts.append(str(path))

other = fixture.client(1, global_admin=False)
for kind, key, variant in variants:
    response_data(other.get(f'/api/logistique/documents/{kind}/{key}/{variant}.pdf'), 404)
restricted = fixture.actor(global_admin=False)
restricted._module_access['modules']['logistique']['canExport'] = False
blocked = APIClient()
blocked.force_authenticate(restricted)
response_data(blocked.get(f'/api/logistique/documents/bon/{entry}/entree.pdf'), 403)
anonymous = APIClient()
check(anonymous.get(f'/api/logistique/documents/bon/{entry}/entree.pdf').status_code in {401, 403}, 'PDF anonyme refusé')
response_data(client.get(f'/api/logistique/documents/bon/{planned}/sortie.pdf'), 409)
response_data(client.get(f'/api/logistique/documents/facture/{planned}/facture.pdf'), 409)
check(business_state() == before, 'Tous les documents, montants, stocks, mouvements, journaux de code et instantanés restent inchangés')
check(digest(c.execute('SELECT to_jsonb(t) row FROM systeme."T_Audit_Log" t WHERE "IdLog"<=%s ORDER BY "IdLog"', [audit_max]).fetchall()) == audit_hash, 'Audits antérieurs conservés sans réécriture')
proof = {'result': 'PASS', 'checks': len(checks), 'details': checks, 'database': location.path[1:], 'productionWrites': False,
    'pdfs': artifacts, 'forms': 7, 'combinations': 4, 'businessSnapshotsPreserved': True, 'originalAuditPreserved': True,
    'sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in [ROOT / 'backend/apps/logistique/documents.py', ROOT / 'backend/apps/logistique/entity_documents.py']}}
(out / 'verification.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding='utf8')
fixture.tearDownClass()
connections.close_all()
print('PASS', len(checks), 'contrôles API PDF ; 7 formes × 4 options persistées, données fictives privées.')
