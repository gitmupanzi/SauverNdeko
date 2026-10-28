"""Recette du moteur PDF sans connexion ni écriture métier.

Python backend ; pypdf de recette peut être fourni via
SAUVERNDEKO_TEST_PDF_PACKAGES. Les PDF fictifs restent dans .runtime.
"""
import hashlib
import io
import json
import os
import sys
from copy import deepcopy
from decimal import Decimal
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'backend'))
if os.environ.get('SAUVERNDEKO_TEST_PDF_PACKAGES'):
    sys.path.append(os.environ['SAUVERNDEKO_TEST_PDF_PACKAGES'])
os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.settings')
os.environ['SAUVERNDEKO_DB_READ_ONLY']='1'
import django
django.setup()
from PIL import Image
from pypdf import PdfReader
from apps.logistique.documents import render_pdf

OUT=ROOT/'.runtime/pdf-mise-en-page07'
OUT.mkdir(parents=True,exist_ok=True)
checks=[]
def check(value,label):
    assert value,label
    checks.append(label)
def image(width,height):
    output=io.BytesIO()
    picture=Image.new('RGBA',(width,height),(28,87,114,255))
    picture.putpixel((0,0),(0,0,0,0))
    picture.save(output,format='PNG')
    return output.getvalue()

base={
  'emitter':{'NomEntite':'ENTREPRISE FICTIVE DE RECETTE','AdresseEntite':'Adresse fictive, Kinshasa',
     'PhoneEntite':'+243 000 000 000','EmailEntite':'recette@example.invalid','SiteWebEntite':'https://example.invalid',
     'IdentifiantsLegauxEntite':[{'libelle':'RCCM','valeur':'RÉFÉRENCE FICTIVE DE RECETTE'}],
     'MentionDocumentaireEntite':'MENTION DU PIED FICTIF'},
  'currency':'USD','title':'Bon de livraison','documentType':'livraison','code':'BS-RECETTE',
  'date':'2026-10-28T12:23:00+01:00','reference':'Référence fictive',
  'recipient':'DESTINATAIRE FICTIF','lines':[],
  'totals':[('Montant du bon',Decimal('525.75'))],'notes':['Document fictif, sans opération réelle.'],
}
def row(index):
    return {'name':f'Article fictif {index:03d}','reference':f'Référence-{index:03d}',
      'quantity':Decimal('1.250'),'unit':'kg','price':Decimal('12.50'),'amount':Decimal('15.625')}
files=[]
def generate(name,data):
    blob=render_pdf(data)
    path=OUT/(name+'.pdf');path.write_bytes(blob)
    reader=PdfReader(io.BytesIO(blob))
    texts=[page.extract_text() for page in reader.pages]
    text='\n'.join(texts)
    check(' '.join(data['emitter']['NomEntite'].split()) in ' '.join(text.split()),name+' : nom courant visible')
    check('\u25a0' not in text and '\ufffd' not in text,name+' : caractères embarqués intacts')
    for page in reader.pages:
        check(abs(float(page.mediabox.width)-595.2756)<.01 and abs(float(page.mediabox.height)-841.8898)<.01,name+' : A4')
    header=data['emitter'].get('AfficherEnteteDocument') is not False
    footer=data['emitter'].get('AfficherPiedDocument') is not False
    check(('Adresse fictive' in text)==header,name+' : adresse selon en-tête')
    check(('MENTION DU PIED FICTIF' in text)==footer,name+' : mentions selon pied')
    check(('Page 1 sur' in text)==footer,name+' : pagination selon pied')
    images=sum(len(page.images) for page in reader.pages)
    check((images>0)==(header and bool(data['emitter'].get('LogoEntite'))),name+' : logo proportionné présent selon option')
    if data['documentType']=='livraison':
        check(all('Réceptionnaire / visa' not in value for value in texts[:-1]),name+' : signatures dernière page seulement')
        check('Réceptionnaire / visa' in texts[-1],name+' : signatures conservées')
        check(any(marker in texts[-1] for marker in ['Article fictif','Montant du bon','Document fictif']),name+' : aucune page avec signatures seules')
    files.append({'path':str(path),'pages':len(reader.pages)})
    return text,texts

for size,label in [((240,60),'paysage'),((60,240),'portrait'),(None,'sans-logo')]:
    data=deepcopy(base);data['lines']=[row(i) for i in range(1,4)]
    if size:data['emitter']['LogoEntite']=image(*size)
    generate('court-'+label,data)

for header in (False,True):
    for footer in (False,True):
        data=deepcopy(base)
        data['emitter'].update(AfficherEnteteDocument=header,AfficherPiedDocument=footer,LogoEntite=image(240,60))
        data['emitter']['NomEntite']='ENTREPRISE FICTIVE DE RECETTE – Réseau de distribution, approvisionnement et services associés'
        data['emitter']['AdresseEntite']='Adresse fictive : avenue de démonstration, bâtiment de recette\n'+('Quartier fictif et localisation détaillée. '*8)
        data['emitter']['IdentifiantsLegauxEntite']=[{'libelle':'Identifiant fictif '+str(i),'valeur':'Référence légale exclusivement fictive '+str(i)+' — '+('ABCD ' * 10)} for i in range(1,7)]
        data['emitter']['MentionDocumentaireEntite']='MENTION DU PIED FICTIF\n'+('Mentions de recette sans aucune valeur contractuelle. '*6)
        data['lines']=[row(i) for i in range(1,49)]
        data['lines'][18]['name']='Article fictif 019 — '+('désignation détaillée avec accents et référence longue. '*30)
        text,texts=generate(f'long-{int(header)}{int(footer)}',data)
        check(len(texts)>1,'Long : plusieurs pages')
        for i in (1,19,48):check(f'Article fictif {i:03d}' in text,f'Long : article{i} non perdu')
        check(text.count('Prix unitaire')>=2,'Long : titres des colonnes répétés')
        check('15,63 USD' in text,'Long : arrondi monétaire et devise')

for count in (13,14,15,30,60):
    data=deepcopy(base);data['lines']=[row(i) for i in range(1,count+1)]
    generate('signatures-'+str(count),data)

data=deepcopy(base)
data['emitter']={'NomEntite':base['emitter']['NomEntite']}
data['lines']=[row(1)]
blob=render_pdf(data)
text='\n'.join(page.extract_text() for page in PdfReader(io.BytesIO(blob)).pages)
check(all(value not in text for value in ['Téléphone :','RCCM :','Site web :','Adresse :','Tiers : —','Destination : —']),'Informations facultatives absentes sans libellé vide')
check('Page 1 sur' in text,'Options absentes : défaut actif')
data=deepcopy(base);data.update(title='Reçu de règlement',documentType='recu',lines=[{'name':'Règlement de facture fictive','reference':'Espèces','amount':Decimal('25'),'quantity':None}])
text,_=generate('recu',data)
check('Mode de règlement' in text and 'Prix unitaire' not in text and 'Quantité' not in text,'Reçu : colonnes adaptées sans quantité vide')

report={'result':'PASS','checks':len(checks),'details':checks,'files':files,
 'documentSha256':hashlib.sha256((ROOT/'backend/apps/logistique/documents.py').read_bytes()).hexdigest(),
 'databaseAccess':False}
(OUT/'verification.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf8')
print(json.dumps({'result':'PASS','checks':len(checks),'files':len(files),'pages':sum(item['pages'] for item in files)}))
