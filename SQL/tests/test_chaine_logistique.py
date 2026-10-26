"""Recette intégrée réception→vente→retours→facture→encaissement→avoir.
Relie les services et leurs vues sur une installation privée migrée jusqu'au 20261026_08.
Aucun repli vers DATABASE_URL, aucun envoi d'e-mail ni transfert bancaire.
"""
import json,os,sys,uuid,secrets,threading,argparse
from pathlib import Path
from decimal import Decimal
from datetime import datetime,date,timedelta,timezone
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit
from types import SimpleNamespace
import psycopg

root=Path(__file__).resolve().parents[2]
dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');url=urlsplit(dsn)
if url.scheme not in {'postgres','postgresql'} or url.hostname not in {'localhost','127.0.0.1'} or not url.path[1:].startswith('sauverndeko_test_'):
 raise RuntimeError('Base de recette locale sauverndeko_test_* explicitement requise, sans repli.')
with psycopg.connect(dsn) as guard:
 if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):raise RuntimeError('Base de recette dédiée requise.')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=dsn,SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_SECRET_KEY=secrets.token_urlsafe(40),JWT_SECRET=secrets.token_urlsafe(40),JWT_REFRESH_SECRET=secrets.token_urlsafe(40))
sys.path.insert(0,str(root/'backend'))
import django;django.setup()
from django.db import close_old_connections,transaction
from rest_framework.test import APIClient
from django.core.files.uploadedfile import SimpleUploadedFile
from apps.accounts.authentication import actor_by_id
from apps.core import db,repository
from apps.core.responses import APIError
from apps.core.tenancy import bind_context
from apps.core.application_licences import save_license_modules,catalogue_rows
from apps.core.module_access import access_snapshot
from apps.logistique import receipts,order_composer,stock_returns,invoices,payments,credit_notes,documents

checks=[];tag=uuid.uuid4().hex[:10];artifacts={}
def check(value,name):
 assert value,name
 checks.append(name)
def equal(value,expected,name):check(Decimal(str(value))==Decimal(str(expected)),name)
def insert(schema,table,data,key):
 return db.one('INSERT INTO '+db.qualified(schema,table)+' ('+','.join(db.ident(k) for k in data)+') VALUES ('+','.join(['%s']*len(data))+') RETURNING '+db.ident(key)+' id',list(data.values()))['id']
def ref(category,abbr=None):
 clause=' AND lower("AbrGenerique")=lower(%s)' if abbr else ''
 row=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "ValideGenerique" IS TRUE'+clause+' ORDER BY "ID_Generique" LIMIT 1',[category,*([abbr] if abbr else [])])
 if not row:raise RuntimeError('Dictionnaire de recette incomplet : '+str(category)+'/'+str(abbr))
 return row['id']
def now():return datetime.now(timezone.utc).isoformat(timespec='seconds')
def reject(fn,name,status=None):
 try:fn()
 except APIError as error:
  if status:check(error.status_code==status,name+' HTTP')
  else:check(True,name)
 else:raise AssertionError(name+' accepté')
def race(fn):
 gate=threading.Barrier(2)
 def worker(i):
  close_old_connections();gate.wait()
  try:return ('ok',fn(i))
  except APIError as error:return ('error',error.default_code)
  finally:close_old_connections()
 with ThreadPoolExecutor(2) as executor:return list(executor.map(worker,range(2)))
def client(actor):
 c=APIClient();c.force_authenticate(actor);return c

global_id=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Chaîne','EmailUser':tag+'-global@example.invalid','MotdepasseUser':'compte-recette-inutilisable','SexeUser':'M','ValideUser':True,'Is_Admin':True},'IdUser')
global_actor=actor_by_id(global_id)
active=db.one('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE lower(c."NomCategorieGenerique")='statut licence' AND lower(g."NomGenerique") IN ('active','actif') AND g."ValideGenerique" IS TRUE''')['id']
def company(label):
 entity=insert('systeme','T_Entite',{'NomEntite':'Entreprise fictive '+label+' '+tag,'EmailEntite':tag+'-'+label.lower()+'@example.invalid','AdresseEntite':'Adresse de recette fictive','ValideEntite':True},'IdEntite')
 stamp=db.one("SELECT LOCALTIMESTAMP-interval '1 day' start,LOCALTIMESTAMP+interval '5 years' finish")
 licence=insert('systeme','T_Licence',{'IdEntiteFk':entity,'DateDebut':stamp['start'],'DateFin':stamp['finish'],'IdStatutLicenceFk':active,'ValideLicence':True},'IdLicence')
 save_license_modules(global_actor,licence,{'enabled':['logistique'],'versions':{r['CodeModule']:0 for r in catalogue_rows() if not r['EstSocle']}})
 uid=insert('systeme','T_Utilisateurs',{'NomUser':'Gestionnaire','PrenomUser':label,'EmailUser':tag+'-'+label+'-manager@example.invalid','MotdepasseUser':'compte-recette-inutilisable','SexeUser':'M','IdEntiteFk':entity,'ValideUser':True,'Is_Admin':False,'Is_staff':True},'IdUser')
 actor=actor_by_id(uid)
 tier=insert('logistique','T_Client',{'IdEntiteFk':entity,'Nature':'entreprise','ID_TypeClientFk':ref(30,'Client'),'Nom':'Client fictif '+label+' '+tag,'CreeParUserFk':uid,'ModifieParUserFk':uid,'Actif':True},'ID_Client')
 return entity,uid,actor,tier
entity_a,uid_a,a,tier_a=company('A');entity_b,uid_b,b,tier_b=company('B')
identity_enabled=bool(db.one("SELECT to_regclass('systeme.\"V_IdentiteDocumentaire\"') IS NOT NULL available")['available'])
if identity_enabled:
 from apps.logistique import entity_documents
 for local_actor,label in [(a,'A'),(b,'B')]:
  profile=entity_documents.profile(local_actor)
  body={**{key:profile.get(key) for key in entity_documents.FIELDS},'IdEntite':local_actor.organisation,'_version':profile['_version'],'requestId':str(uuid.uuid4()),'motif':'Profil documentaire fictif de recette','IdentifiantsLegauxEntite':[{'libelle':'Registre','valeur':'FICTIF-'+tag+'-'+label}],'MentionDocumentaireEntite':'Mention de recette\nSans régime fiscal imposé'}
  updated,replayed=entity_documents.save(local_actor,body)
  check(not replayed and updated['canConfigure'],'gestionnaire local licencié configure le profil '+label)
  check(updated['IdentifiantsLegauxEntite']==body['IdentifiantsLegauxEntite'],'identifiants du profil enregistrés '+label)
  check(entity_documents.save(local_actor,body)[1],'rejeu du profil sans nouvelle écriture '+label)
  if label=='A':identity_payload=body
 reject(lambda:entity_documents.save(b,identity_payload),'profil autre entreprise refusé',403)
 reject(lambda:entity_documents.save(a,{**identity_payload,'NomEntite':'Profil changé'}),'UUID de profil réutilisé avec contenu changé refusé',409)
check(not a.global_admin and not b.global_admin and a.admin and b.admin,'deux gestionnaires locaux sans privilège global')
check(access_snapshot(a)['modules']['logistique']['canManage'] and access_snapshot(b)['modules']['logistique']['canManage'],'licences autorisent la logistique des deux entreprises')
ordinary_id=insert('systeme','T_Utilisateurs',{'NomUser':'Lecture','PrenomUser':'Sans droit','EmailUser':tag+'-reader@example.invalid','MotdepasseUser':'inutilisable','SexeUser':'M','IdEntiteFk':entity_a,'ValideUser':True,'Is_Admin':False,'Is_staff':False},'IdUser')
ordinary=actor_by_id(ordinary_id)
def supplier(entity,uid,label):
 return insert('logistique','T_Client',{'IdEntiteFk':entity,'Nature':'entreprise','ID_TypeClientFk':ref(30,'Fournisseur'),'Nom':'Fournisseur fictif '+label+' '+tag,'CreeParUserFk':uid,'ModifieParUserFk':uid,'Actif':True},'ID_Client')
suppliers={entity_a:supplier(entity_a,uid_a,'A'),entity_b:supplier(entity_b,uid_b,'B')}
unit=insert('referentiel','T_Generique',{'ID_CategorieGeneriqueFk':34,'NomGenerique':'Kilogramme de recette '+tag,'AbrGenerique':'kg','DecimalesStock':3,'ValideGenerique':True},'ID_Generique')
category,kind,currency,entry,outgoing,mode=ref(40),ref(46),ref(42,'USD'),ref(64,'Entrée'),ref(64,'Sortie'),ref(36)
def article(actor,label):
 return repository.mutate('T_Article',actor,{'NomArticle':label+' '+tag,'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'QteArticle':'0','PUArticle':'4.00','PVArticle':'8.00','ValideArticle':True})['ID_Article']
aid=article(a,'Produit fractionnaire A');bid=article(b,'Produit fractionnaire B')
def stock(pk):return db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[pk])['q']
def mcount(pk):return db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[pk])['n']
def receive(actor,pk,qty,number):
 payload={'requestId':str(uuid.uuid4()),'ID_TypeCmdFk':entry,'ID_DeviseFk':currency,'DateCmd':now(),'QteCmdDetail':qty,'PUCmdDetail':'4.00','ID_TiersFk':suppliers[actor.organisation],'Lots':[{'NumeroLot':number,'Quantite':qty,'DatePeremptionLot':(date.today()+timedelta(days=180)).isoformat()}]}
 return payload,receipts.receive_article(actor,pk,payload)
receipt_payload,reception=receive(a,aid,'10.500','LOT-A-'+tag);entry_id=reception['bon']['ID_Commande']
check(reception['bon']['ID_TiersFk']==suppliers[entity_a],'réception liée au fournisseur de son entreprise');equal(stock(aid),'10.500','réception fractionnaire exacte');check(mcount(aid)==1,'un seul mouvement à la réception')
check(receipts.receive_article(a,aid,receipt_payload)['replayed'] and mcount(aid)==1,'rejeu réception sans doublon')
reject(lambda:receipts.receive_article(a,aid,{**receipt_payload,'PUCmdDetail':'5.00'}),'rejeu réception modifié refusé',409)
b_payload={'requestId':str(uuid.uuid4()),'ID_TypeCmdFk':entry,'ID_DeviseFk':currency,'DateCmd':now(),'QteCmdDetail':'5.125','PUCmdDetail':'4.00','ID_TiersFk':suppliers[entity_b],'Lots':[{'NumeroLot':'LOT-B-'+tag,'Quantite':'5.125','DatePeremptionLot':(date.today()+timedelta(days=180)).isoformat()}]}
br=race(lambda i:receipts.receive_article(actor_by_id(uid_b),bid,b_payload))
check(all(x[0]=='ok' for x in br) and sorted(x[1]['replayed'] for x in br)==[False,True],'réception concurrente même UUID sérialisée')
equal(stock(bid),'5.125','stock entreprise B exact');check(mcount(bid)==1,'réception concurrente un mouvement')
lot_id=db.one('SELECT "ID_LotArticle" id FROM logistique."T_LotArticle" WHERE "ID_ArticleFk"=%s AND "NumeroLot"=%s',[aid,'LOT-A-'+tag])['id']
def sale(actor,pk,tier,qty,lot=None):
 payload={'requestId':str(uuid.uuid4()),'bon':{'ID_TypeCmdFk':outgoing,'ID_DeviseFk':currency,'DateCmd':now(),'ID_TiersFk':tier},'lignes':[{'ID_ArticleFk':pk,'QteCmdDetail':qty,'PUCmdDetail':'8.00','Lots':[{'NumeroLot':db.one('SELECT "NumeroLot" n FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=%s',[lot])['n'],'Quantite':qty}] if lot else []}]}
 result=order_composer.compose_order(actor,payload)
 return payload,result
sale_payload,sale_result=sale(a,aid,tier_a,'6.250',lot_id);sale_id=sale_result['bon']['ID_Commande']
equal(stock(aid),'4.250','sortie fractionnaire exacte');check(mcount(aid)==2,'sortie un seul mouvement supplémentaire')
check(order_composer.compose_order(a,sale_payload)['replayed'] and mcount(aid)==2,'rejeu panier sans double sortie')
def returned(actor,pk,cmd,qty,lot):
 _,meta=stock_returns.preview_returns(actor,cmd)
 payload={'requestId':str(uuid.uuid4()),'_version':meta['revision'],'DateCmd':now(),'motif':'Retour fictif de recette','lignes':[{'ID_ArticleFk':pk,'QteRetour':qty,'Lots':[{'ID_LotArticle':lot,'Quantite':qty}]}]}
 return payload,stock_returns.record_return(actor,cmd,payload)
return_before_payload,return_before=returned(a,aid,sale_id,'1.250',lot_id)
equal(stock(aid),'5.500','retour avant facture réintègre exactement la quantité');check(return_before['bonRetour']['ID_TiersFk']==tier_a,'restitution conserve le tiers du bon source')
check(stock_returns.record_return(a,sale_id,return_before_payload)['replayed'] and mcount(aid)==3,'rejeu retour avant facture sans mouvement supplémentaire')
invoice_info=invoices.context(a,sale_id);equal(invoice_info['data']['totaux']['MontantFacture'],'40.00','facturation nette du retour avant émission')
line=invoice_info['data']['lignes'][0];equal(line['QteSortie'],'6.250','quantité initiale conservée');equal(line['QteRetourAvantFacture'],'1.250','retour avant facture figé');equal(line['QteFacturee'],'5.000','quantité nette facturée exacte')
def issue_invoice(actor,cmd):
 info=invoices.context(actor,cmd)
 payload={'requestId':str(uuid.uuid4()),'_version':info['meta']['revision'],'DateFacture':now(),'ID_ModePaiementFk':mode,'ID_ConditionPaiementFk':None,'DateEcheancePaiement':(datetime.now(timezone.utc)+timedelta(days=14)).isoformat(timespec='seconds')}
 return payload,invoices.write_invoice(actor,cmd,payload,'issue')
invoice_payload,invoice=issue_invoice(a,sale_id);code=invoice['facture']['CodeFacture']
if identity_enabled:
 emitter=documents.document_data(a,'facture',sale_id,'facture')['emitter']
 check(emitter['IdentifiantsLegauxEntite']==identity_payload['IdentifiantsLegauxEntite'],'facture émise fige les identifiants déclarés')
 check(emitter['MentionDocumentaireEntite']==identity_payload['MentionDocumentaireEntite'],'facture émise fige la mention multiligne')
check(code.startswith('fac-'),'numérotation facture courte');check(invoices.write_invoice(a,sale_id,invoice_payload,'issue')['replayed'],'rejeu émission facture')
def invoice_row(cmd):return db.one('SELECT * FROM logistique."V_Facture" WHERE "ID_CommandeFk"=%s',[cmd])
equal(invoice_row(sale_id)['Reste'],'40.00','solde initial facture exact')
def payment_payload(actor,cmd,amount):
 data,meta=payments.preparation(actor,cmd)
 return {'requestId':str(uuid.uuid4()),'_version':meta['revision'],'CodeFactureFk':data['defaults']['CodeFactureFk'],'DateReglement':datetime.now().isoformat(timespec='seconds'),'ID_ModeReglementFk':mode,'MontantRegle':amount}
payment_one_payload=payment_payload(a,sale_id,'12.00');payment_one=payments.mutate_payment(a,payment_one_payload)
check(payments.mutate_payment(a,payment_one_payload)['replayed'],'rejeu règlement sans double encaissement');equal(invoice_row(sale_id)['Reste'],'28.00','règlement partiel et solde')
payment_two_payload=payment_payload(a,sale_id,'28.00')
pr=race(lambda i:payments.mutate_payment(actor_by_id(uid_a),{**payment_two_payload,'requestId':str(uuid.uuid4())}))
check(sum(r[0]=='ok' for r in pr)==1 and sum(r[0]=='error' for r in pr)==1,'deux encaissements concurrents du même solde : un seul succès')
equal(invoice_row(sale_id)['TotalRegle'],'40.00','aucun sur-encaissement concurrent');equal(invoice_row(sale_id)['Reste'],'0.00','facture soldée')
return_after_payload,return_after=returned(a,aid,sale_id,'2.000',lot_id)
equal(stock(aid),'7.500','retour après facture réintègre la quantité');equal(invoice_row(sale_id)['MontantTTC'],'40.00','facture émise immuable après retour')
credit_info=credit_notes.context(a,sale_id);equal(credit_info['data']['MontantEnAttente'],'16.00','avoir attendu uniquement pour le retour après émission')
credit_payload={'requestId':str(uuid.uuid4()),'_version':credit_info['meta']['revision'],'DateAvoir':now(),'Motif':'Avoir fictif après restitution'}
movements_before=mcount(aid);credit=credit_notes.issue(a,sale_id,credit_payload)['avoir'];credit_id=credit['ID_Avoir']
equal(credit['MontantTTC'],'16.00','avoir émis à valeur exacte');equal(credit['Disponible'],'16.00','avoir disponible sur facture déjà réglée')
check(credit_notes.issue(a,sale_id,credit_payload)['replayed'] and mcount(aid)==movements_before,'rejeu avoir sans mouvement ni document supplémentaire')
check(not credit_notes.context(a,sale_id)['meta']['canIssue'],'retour déjà crédité ne crée pas un deuxième avoir')
# Nouvelle facture du même tiers : l'avoir est imputable, sans aucun transfert de stock financier.
second_payload,second=sale(a,aid,tier_a,'1.000',lot_id);second_id=second['bon']['ID_Commande'];_,second_invoice=issue_invoice(a,second_id)
def note():return db.one('SELECT * FROM logistique."V_Avoir" WHERE "ID_Avoir"=%s',[credit_id])
allocation_payload={'requestId':str(uuid.uuid4()),'_version':credit_notes.note_revision(note()),'ID_CommandeCibleFk':second_id,'Montant':'6.00'}
allocated=credit_notes.settle(a,credit_id,'affectation',allocation_payload)['avoir']
equal(allocated['Disponible'],'10.00','imputation diminue le disponible');equal(invoice_row(second_id)['Reste'],'2.00','imputation diminue exactement le solde cible')
check(credit_notes.settle(a,credit_id,'affectation',allocation_payload)['replayed'],'rejeu imputation')
refund_payload={'requestId':str(uuid.uuid4()),'_version':credit_notes.note_revision(note()),'Montant':'10.00','DateRemboursement':now(),'ID_ModePaiementFk':mode,'ReferenceRemboursement':'Recette locale sans transfert bancaire'}
rr=race(lambda i:credit_notes.settle(actor_by_id(uid_a),credit_id,'remboursement',refund_payload))
check(all(r[0]=='ok' for r in rr) and sorted(r[1]['replayed'] for r in rr)==[False,True],'remboursement concurrent même demande unique')
equal(note()['Disponible'],'0.00','avoir entièrement utilisé');check(db.one('SELECT count(*) n FROM logistique."T_Remboursement" WHERE "ID_AvoirFk"=%s',[credit_id])['n']==1,'un seul remboursement enregistré')
check(mcount(aid)==movements_before+1,'imputation et remboursement sans mouvement physique')
reject(lambda:credit_notes.settle(a,credit_id,'remboursement',{**refund_payload,'requestId':str(uuid.uuid4()),'_version':credit_notes.note_revision(note()),'Montant':'0.01'}),'remboursement au-delà du disponible refusé')
# Facture encore ouverte : l'avoir s'impute d'abord sur la facture d'origine.
_,return_small=returned(a,aid,second_id,'0.500',lot_id)
second_credit_info=credit_notes.context(a,second_id)
second_credit=credit_notes.issue(a,second_id,{'requestId':str(uuid.uuid4()),'_version':second_credit_info['meta']['revision'],'DateAvoir':now(),'Motif':'Retour de recette avec solde ouvert'})['avoir']
equal(second_credit['MontantTTC'],'4.00','deuxième avoir exact');equal(second_credit['Disponible'],'2.00','avoir impute seulement le solde origine restant')
equal(invoice_row(second_id)['Reste'],'0.00','imputation automatique sur solde source')
equal(stock(aid),'7.000','stock final cohérent sur toute la chaîne')
net_sales=invoice_row(sale_id)['MontantTTC']+invoice_row(second_id)['MontantTTC']-Decimal(str(credit['MontantTTC']))-Decimal(str(second_credit['MontantTTC']))
net_cash=invoice_row(sale_id)['TotalRegle']-Decimal('10.00')
equal(net_sales,'28.00','ventes nettes des avoirs égales à 28 USD')
equal(net_cash-Decimal(str(second_credit['Disponible'])),net_sales,'encaissement net moins crédit client disponible égale les ventes nettes')
lot=db.one('SELECT * FROM logistique."V_RegistreLots" WHERE "ID_LotArticle"=%s',[lot_id]);equal(lot['StockLot'],'7.000','lot final cohérent avec stock')
equal(stock(bid),'5.125','autre entreprise inchangée par la chaîne A')
check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[aid])['n']==6,'six mouvements seulement : réception sortie retour sortie retour retour')
# Isolation réelle des services, des menus, de l'API et des documents privés.
reject(lambda:receipts.receipt_defaults(b,aid),'réception autre entreprise refusée',404)
reject(lambda:invoices.context(b,sale_id),'facture autre entreprise refusée',404)
reject(lambda:payments.preparation(b,sale_id),'règlement autre entreprise refusé',404)
reject(lambda:credit_notes.credit_record(b,credit_id),'avoir autre entreprise refusé',404)
reject(lambda:credit_notes.settle(b,credit_id,'remboursement',{**refund_payload,'requestId':str(uuid.uuid4())}),'remboursement autre entreprise refusé',404)
reject(lambda:receipts.receive_article(ordinary,aid,receipt_payload),'compte sans gestion ne reçoit pas',403)
reject(lambda:invoices.write_invoice(ordinary,sale_id,invoice_payload,'issue'),'compte sans gestion ne facture pas',403)
reject(lambda:payments.mutate_payment(ordinary,payment_one_payload),'compte sans gestion ne règle pas',403)
reject(lambda:receipts.receive_article(global_actor,aid,receipt_payload),'administrateur global doit choisir l’entreprise')
# La valorisation reste au coût d'achat : ni facturation ni remboursement ne la modifient.
from apps.logistique.valuation import snapshot as valuation
position=valuation(a,aid)['positions'][0]
equal(position['QteValorisee'],'7.000','quantité valorisée identique au stock final')
equal(position['CoutUnitaireMoyen'],'4.000000','CUMP conservé au prix d’achat historique')
equal(position['ValeurStock'],'28.00','valeur finale au coût, distincte du prix de vente')
check(not invoices.context(a,sale_id)['meta']['canEdit'],'facture réglée et créditée protégée en modification')
_,payment_policy=payments.get_payment(a,payment_one['ID_Reglement'])
check(not payment_policy['canDelete'] and not payment_policy['canEdit'],'règlement lié à un avoir conservé')
reject(lambda:payments.mutate_payment(a,{'requestId':str(uuid.uuid4()),'_version':payment_policy['revision']},{'ID_Reglement':payment_one['ID_Reglement']},'delete'),'suppression règlement lié à un avoir refusée',409)
reject(lambda:credit_notes.settle(a,credit_id,'affectation',{**allocation_payload,'Montant':'5.00'}),'UUID imputation avec contenu différent refusé',409)
reject(lambda:bind_context(a,SimpleNamespace(headers={'X-Entite-ID':str(entity_b)})),'gestionnaire local ne choisit pas une autre entreprise',403)
ca,cb=client(a),client(b)
for kind,pk,format_name in [('bon',entry_id,'entree'),('bon',sale_id,'sortie'),('bon',sale_id,'livraison'),('facture',sale_id,'facture'),('reglement',payment_one['ID_Reglement'],'recu'),('avoir',credit_id,'avoir')]:
 path=f'/api/logistique/documents/{kind}/{pk}/{format_name}.pdf'
 response=ca.get(path,HTTP_ACCEPT='application/pdf');check(response.status_code==200 and response['Content-Type'].startswith('application/pdf') and response.content.startswith(b'%PDF'),'PDF authentifié '+format_name)
 artifacts[format_name]=response.content
 denied=cb.get(path,HTTP_ACCEPT='application/pdf');check(denied.status_code==404,'PDF autre entreprise refusé '+format_name)
 check('no-store' in response.get('Cache-Control',''),'PDF privé sans cache '+format_name)
# Identité documentaire émise figée malgré un changement de l'entreprise ensuite.
frozen=documents.document_data(a,'facture',sale_id,'facture')['emitter'];frozen_tier=documents.document_data(a,'facture',sale_id,'facture')['thirdParty']
db.query('UPDATE systeme."T_Entite" SET "NomEntite"=%s WHERE "IdEntite"=%s',['Entreprise fictive A renommée '+tag,entity_a])
check(documents.document_data(a,'facture',sale_id,'facture')['emitter']==frozen,'identité de facture émise conservée')
db.query('UPDATE logistique."T_Client" SET "Nom"=%s WHERE "ID_Client"=%s',['Client renommé fictif '+tag,tier_a])
check(documents.document_data(a,'facture',sale_id,'facture')['thirdParty']==frozen_tier,'identité du tiers facturé conservée')
# Les pièces jointes sont privées et ne passent pas par une URL de fichier publique.
path=f'/api/logistique/documents/bon/{sale_id}/pieces'
upload=ca.post(path,{'file':SimpleUploadedFile('preuve.pdf',artifacts['livraison'],content_type='application/pdf')},format='multipart')
check(upload.status_code==201,'justificatif PDF téléversé')
piece_id=upload.data['data']['ID_Piece'];piece_path=path+'/'+str(piece_id)
fetched=ca.get(piece_path,HTTP_ACCEPT='application/pdf')
check(fetched.status_code==200 and fetched.content==artifacts['livraison'],'justificatif restitué à l’octet près')
check(cb.get(piece_path,HTTP_ACCEPT='application/pdf').status_code==404,'justificatif autre entreprise refusé')
check(APIClient().get(piece_path,HTTP_ACCEPT='application/pdf').status_code==401,'justificatif anonyme refusé')
archived=ca.delete(piece_path);check(archived.status_code==200,'justificatif archivé')
check(ca.get(piece_path,HTTP_ACCEPT='application/pdf').status_code==404,'justificatif archivé absent des téléchargements')
check(db.one('SELECT "Archive" active FROM logistique."T_PieceJustificative" WHERE "ID_Piece"=%s',[piece_id])['active'],'archive conserve la pièce en base')
# Une licence inactive bloque aussi les téléchargements et les données financières.
with transaction.atomic():
 db.query('UPDATE systeme."T_Licence" SET "ValideLicence"=false WHERE "IdEntiteFk"=%s',[entity_a])
 blocked=client(actor_by_id(uid_a)).get(f'/api/logistique/commandes/{sale_id}/facture')
 check(blocked.status_code==403,'licence inactive refuse les données financières')
 blocked=client(actor_by_id(uid_a)).get(f'/api/logistique/documents/facture/{sale_id}/facture.pdf',HTTP_ACCEPT='application/pdf')
 check(blocked.status_code==403,'licence inactive refuse les documents privés')
 transaction.set_rollback(True)
check(client(actor_by_id(uid_a)).get(f'/api/logistique/commandes/{sale_id}/facture').status_code==200,'retour licence active après rollback privé')
# Le registre doit annoncer les actions réellement raccordées aux services.
from apps.logistique.reads import register as read_register
registry_rows,registry_meta=read_register(a,'commandes',{'take':'25','skip':'0'})
check(registry_meta.get('features',{}).get('invoices') is True,'action facture exposée dans Bons de stock')
check(registry_meta.get('features',{}).get('returns') is True,'action restitution exposée dans Bons de stock')
check(all('returnContext' in row for row in registry_rows),'éligibilité restitution fournie par ligne autorisée')
print(json.dumps({'checks':len(checks),'privateDatabase':url.path[1:],'entities':[entity_a,entity_b],'stockA':str(stock(aid)),'stockB':str(stock(bid))},ensure_ascii=True))
parser=argparse.ArgumentParser();parser.add_argument('--artifacts');args=parser.parse_args()
if args.artifacts:
 folder=Path(args.artifacts).resolve();folder.mkdir(parents=True,exist_ok=True)
 for name,blob in artifacts.items():(folder/(name+'.pdf')).write_bytes(blob)
 (folder/'recette-chaine.json').write_text(json.dumps({'checks':checks,'database':url.path[1:],'fictitious':True},ensure_ascii=False,indent=2),encoding='utf8')
print('PASS '+str(len(checks))+' contrôles chaîne logistique complète en base privée.')
