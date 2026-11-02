"""TVA : parcours HTTP, factures, retours et PDF sur base privée obligatoire.

Les données sont fictives. La préparation commune des bons conserve ses gardes
localhost et sauverndeko_test_* ; aucune connexion source n'est acceptée.
"""
import io
import json
import os
import sys
import unittest
import uuid
import zipfile
from decimal import Decimal
from xml.etree import ElementTree

import test_bons_commande_api as fixtures
from apps.core import db
from apps.logistique import documents


class TVAInvoiceAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.BonsCommandeAPI.setUpClass()
        cls.fixture=fixtures.BonsCommandeAPI(methodName='runTest')
        cls.sql=cls.fixture.connection

    @classmethod
    def tearDownClass(cls):
        fixtures.BonsCommandeAPI.tearDownClass()

    def setUp(self):
        self.client=self.fixture.client()
        self.rate('0')

    def rate(self,value,entity=0):
        self.sql.execute('UPDATE systeme."T_Entite" SET "TauxTVAEntite"=%s WHERE "IdEntite"=%s',
                         [value,self.fixture.entities[entity]])

    def result(self,response,status=200):
        self.assertEqual(response.status_code,status,getattr(response,'data',None))
        return response.data

    def source(self,quantity='4',price='25.00'):
        article=self.fixture.article()
        self.fixture.create(self.fixture.payload(article,kind=self.fixture.be,quantity='20',price='10'))
        sold=self.fixture.create(self.fixture.payload(article,kind=self.fixture.bs,quantity=quantity,price=price))['bon']['ID_Commande']
        return article,sold

    def preparation(self,command):
        return self.result(self.client.get(f'/api/logistique/commandes/{command}/facture'))

    def issue(self,command,prepared=None,body=None,status=201):
        prepared=prepared or self.preparation(command)
        body=body or {'requestId':str(uuid.uuid4()),'_version':prepared['meta']['revision'],
                      'DateFacture':'2026-11-02T09:00:00','DateEcheancePaiement':'2026-12-02T09:00:00'}
        response=self.client.post(f'/api/logistique/commandes/{command}/facture',body,format='json')
        return self.result(response,status)['data'],body

    def return_goods(self,command,article,quantity):
        prepared=self.result(self.client.get(f'/api/logistique/commandes/{command}/retours'))
        return self.result(self.client.post(f'/api/logistique/commandes/{command}/retours',
            {'requestId':str(uuid.uuid4()),'_version':prepared['meta']['revision'],
             'DateCmd':'2026-11-02T10:00:00','motif':'Restitution fictive pour contrôler la TVA',
             'lignes':[{'ID_ArticleFk':article,'QteRetour':quantity,'Lots':[]}]},format='json'),201)

    def credit(self,command):
        prepared=self.result(self.client.get(f'/api/logistique/commandes/{command}/avoirs'))
        issued=self.result(self.client.post(f'/api/logistique/commandes/{command}/avoirs',
            {'requestId':str(uuid.uuid4()),'_version':prepared['meta']['revision'],
             'DateAvoir':'2026-11-02T11:00:00','Motif':'Avoir fictif lié à la restitution'},format='json'),201)
        return prepared['data'],issued['data']['avoir']

    def amounts(self,row,ht,tax,total,rate=None):
        self.assertEqual(Decimal(str(row['MontantHT'])),Decimal(ht))
        self.assertEqual(Decimal(str(row['MontantTVA'])),Decimal(tax))
        self.assertEqual(Decimal(str(row['MontantTTC'])),Decimal(total))
        if rate is not None:self.assertEqual(Decimal(str(row['TauxTVA'])),Decimal(rate))

    def test_01_zero_default_does_not_create_a_second_stock_effect(self):
        article,command=self.source()
        before=self.fixture.state(article)
        prepared=self.preparation(command)
        self.amounts(prepared['data']['totaux'],'100','0','100','0')
        issued,_=self.issue(command,prepared)
        self.amounts(issued['facture'],'100','0','100','0')
        self.assertEqual(self.fixture.state(article),before)

    def test_02_company_rate_preview_issue_and_real_payment_balance(self):
        self.rate('16')
        article,command=self.source()
        self.amounts(self.preparation(command)['data']['totaux'],'100','16','116','16')
        before=self.fixture.state(article)
        issued,_=self.issue(command)
        self.amounts(issued['facture'],'100','16','116','16')
        balance=db.one('SELECT * FROM logistique."V_SuiviReglements" WHERE "ID_Commande"=%s',[command])
        self.assertEqual(balance['MontantFacture'],Decimal('116'))
        self.assertEqual(balance['Reste'],Decimal('116'))
        self.assertEqual(self.fixture.state(article),before)

    def test_03_rate_change_invalidates_the_prepared_invoice(self):
        self.rate('16')
        _,command=self.source()
        old=self.preparation(command)
        self.rate('18')
        body={'requestId':str(uuid.uuid4()),'_version':old['meta']['revision'],
              'DateFacture':'2026-11-02T09:00:00','DateEcheancePaiement':'2026-12-02T09:00:00'}
        response=self.client.post(f'/api/logistique/commandes/{command}/facture',body,format='json')
        self.result(response,409)
        self.assertFalse(db.one('SELECT EXISTS(SELECT FROM logistique."T_Facture" WHERE "ID_CommandeFk"=%s) n',[command])['n'])
        self.amounts(self.issue(command)[0]['facture'],'100','18','118','18')

    def test_04_issued_snapshot_and_exact_replay_ignore_a_later_company_rate(self):
        self.rate('16')
        _,command=self.source()
        issued,body=self.issue(command)
        self.rate('25')
        replay,_=self.issue(command,body=body,status=200)
        self.assertTrue(replay['replayed'])
        self.amounts(replay['facture'],'100','16','116','16')
        self.amounts(self.preparation(command)['data']['totaux'],'100','16','116','16')
        self.assertEqual(issued['facture']['ID_Facture'],replay['facture']['ID_Facture'])

    def test_05_returns_before_issue_reduce_the_taxable_quantity(self):
        self.rate('16')
        article,command=self.source(quantity='3',price='10')
        self.return_goods(command,article,'1')
        prepared=self.preparation(command)
        self.amounts(prepared['data']['totaux'],'20','3.20','23.20','16')
        self.amounts(self.issue(command,prepared)[0]['facture'],'20','3.20','23.20','16')

    def test_06_credit_uses_original_rate_after_company_rate_change(self):
        self.rate('16')
        article,command=self.source()
        self.issue(command)
        self.rate('30')
        self.return_goods(command,article,'2')
        prepared,credit=self.credit(command)
        self.assertEqual(Decimal(str(prepared['MontantEnAttente'])),Decimal('58'))
        self.assertEqual(Decimal(str(prepared['MontantTVAEnAttente'])),Decimal('8'))
        self.amounts(credit,'50','8','58','16')
        self.assertEqual(db.one('SELECT "Reste" FROM logistique."V_SuiviReglements" WHERE "ID_Commande"=%s',[command])['Reste'],Decimal('58'))

    def test_07_successive_credits_reconcile_the_last_cent(self):
        self.rate('16')
        article,command=self.source(quantity='3',price='0.07')
        self.amounts(self.issue(command)[0]['facture'],'0.21','0.03','0.24','16')
        totals=[]
        for quantity in ('1','1','1'):
            self.return_goods(command,article,quantity)
            _,credit=self.credit(command)
            totals.append(credit)
        self.assertEqual(sum(Decimal(str(row['MontantHT'])) for row in totals),Decimal('0.21'))
        self.assertEqual(sum(Decimal(str(row['MontantTVA'])) for row in totals),Decimal('0.03'))
        self.assertEqual(sum(Decimal(str(row['MontantTTC'])) for row in totals),Decimal('0.24'))
        self.assertEqual(db.one('SELECT "Reste" FROM logistique."V_SuiviReglements" WHERE "ID_Commande"=%s',[command])['Reste'],Decimal('0'))

    def test_08_browser_cannot_override_the_tax_snapshot(self):
        _,command=self.source()
        prepared=self.preparation(command)
        body={'requestId':str(uuid.uuid4()),'_version':prepared['meta']['revision'],
              'DateFacture':'2026-11-02T09:00:00','DateEcheancePaiement':'2026-12-02T09:00:00','TauxTVA':'99'}
        self.result(self.client.post(f'/api/logistique/commandes/{command}/facture',body,format='json'),400)

    def test_09_pdf_invoice_and_credit_reuse_tax_snapshots(self):
        packages=os.environ.get('SAUVERNDEKO_TEST_PDF_PACKAGES')
        if packages:sys.path.append(packages)
        from pypdf import PdfReader
        self.rate('16')
        article,command=self.source()
        self.issue(command)
        self.return_goods(command,article,'2')
        _,credit=self.credit(command)
        self.rate('24')
        for kind,key,variant,expected in [('facture',command,'facture','116,00'),('avoir',credit['ID_Avoir'],'avoir','58,00')]:
            data=documents.document_data(self.fixture.actor(),kind,key,variant)
            labels=[label for label,_ in data['totals']]
            self.assertIn('TVA (16 %)',labels)
            binary=documents.render_pdf(data)
            text='\n'.join(page.extract_text() or '' for page in PdfReader(io.BytesIO(binary)).pages)
            self.assertIn('TVA (16 %)',text)
            self.assertIn(expected,text)
            self.assertNotIn('TVA (24 %)',text)
            output=fixtures.ROOT/'.runtime/tva01-documents'
            output.mkdir(parents=True,exist_ok=True)
            (output/(kind+'-tva.pdf')).write_bytes(binary)

    def test_10_other_company_cannot_read_or_issue_the_invoice(self):
        self.rate('16')
        _,command=self.source()
        self.result(self.fixture.client(1,global_admin=False).get(f'/api/logistique/commandes/{command}/facture'),404)

    def test_11_optional_tax_columns_export_exact_snapshot_numbers(self):
        self.rate('16')
        _,command=self.source()
        self.issue(command)
        self.rate('28')
        columns=['CodeFacture','MontantHTFacture','TauxTVA','MontantTVA','MontantFacture']
        response=self.client.get('/api/logistique/registre/factures/export.xlsx',
            {'columns':json.dumps(columns),'selection':json.dumps([command])},
            HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertEqual(response.status_code,200,getattr(response,'data',None))
        binary=b''.join(response.streaming_content) if getattr(response,'streaming',False) else response.content
        ns={'x':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        with zipfile.ZipFile(io.BytesIO(binary)) as workbook:
            sheet=ElementTree.fromstring(workbook.read('xl/worksheets/sheet1.xml'))
        values={cell.attrib['r']:cell.find('x:v',ns).text for cell in sheet.findall('.//x:row[@r="2"]/x:c',ns) if cell.find('x:v',ns) is not None}
        self.assertEqual([Decimal(values[key]) for key in ['B2','C2','D2','E2']],
                         [Decimal('100'),Decimal('16'),Decimal('16'),Decimal('116')])

    def test_12_metadata_edit_keeps_the_original_invoice_tax(self):
        self.rate('16')
        _,command=self.source()
        issued,_=self.issue(command)
        self.rate('28')
        prepared=self.preparation(command)
        self.assertTrue(prepared['meta']['canEdit'])
        old=issued['facture']
        result=self.result(self.client.put(f'/api/logistique/commandes/{command}/facture',
            {'requestId':str(uuid.uuid4()),'_version':prepared['meta']['revision'],
             'DateFacture':old['DateFacture'],'DateEcheancePaiement':'2026-12-03T09:00:00',
             'ID_ModePaiementFk':None,'ID_ConditionPaiementFk':None},format='json'))
        self.amounts(result['data']['facture'],'100','16','116','16')


if __name__=='__main__':
    unittest.main(verbosity=2)
