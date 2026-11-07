"""Contrat documentaire multi-dépôts, sans connexion à une base métier.

Exécuter avec Python backend ; les PDF fictifs restent dans .runtime.
"""
import io
import os
import sys
import unittest
from copy import deepcopy
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
if os.environ.get('SAUVERNDEKO_TEST_PDF_PACKAGES'):
    sys.path.append(os.environ['SAUVERNDEKO_TEST_PDF_PACKAGES'])
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
os.environ['SAUVERNDEKO_DB_READ_ONLY'] = '1'
import django
django.setup()
from pypdf import PdfReader
from apps.core.responses import APIError
from apps.logistique.documents import render_pdf, stock_location_details


class DepotDocuments(unittest.TestCase):
    def test_depot_is_read_with_the_authorised_company(self):
        with patch('apps.logistique.documents.db.one', return_value={'CodeDepot': 'D-1', 'NomDepot': 'Entrepôt central'}) as query:
            self.assertEqual(stock_location_details({'ID_DepotFk': 17}, 9), [('Dépôt', 'D-1 · Entrepôt central')])
            self.assertEqual(query.call_args.args[1], [17, 9])

    def test_inconsistent_depot_blocks_document_generation(self):
        with patch('apps.logistique.documents.db.one', return_value=None):
            with self.assertRaises(APIError):
                stock_location_details({'ID_DepotFk': 17}, 9)

    def test_transfer_context_requires_the_same_company(self):
        answers = [{'CodeDepot': 'D-1', 'NomDepot': 'Central'}, None]
        with patch('apps.logistique.documents.db.one', side_effect=answers) as query:
            with self.assertRaises(APIError):
                stock_location_details({'ID_DepotFk': 17, 'ID_TransfertDepotFk': 25}, 9)
            self.assertEqual(query.call_args.args[1], [25, 9])

    def test_multi_page_transfer_keeps_locations_lots_and_company(self):
        output = ROOT / '.runtime' / 'multi-depots-20261107' / 'pdf'
        output.mkdir(parents=True, exist_ok=True)
        base = {
            'emitter': {'NomEntite': 'ENTREPRISE FICTIVE DE RECETTE', 'AdresseEntite': 'Avenue de recette, Kinshasa'},
            'title': 'Bon de sortie', 'documentType': 'sortie', 'code': 'BS-TEST',
            'date': '2026-11-07T12:00:00+01:00', 'currency': 'USD',
            'details': [('Dépôt', 'CENTRAL · Entrepôt principal'), ('Transfert interne', 'TRF-TEST'),
                        ('Dépôt source', 'CENTRAL · Entrepôt principal'),
                        ('Dépôt destinataire', 'SUD · ' + 'Site de réception avec adresse détaillée ' * 5)],
            'lines': [{'name': f'Article de recette {i:03d}',
                       'reference': f'Référence {i:03d}\nLot LOT-{i:03d} · 1,25 · Péremption 30/06/2028',
                       'quantity': Decimal('1.25'), 'unit': 'kg', 'price': Decimal('10'),
                       'amount': Decimal('12.50')} for i in range(1, 46)],
            'totals': [('Montant du bon', Decimal('562.50'))],
            'notes': ['Transfert interne à l’entreprise. Ce bon ne constitue ni une vente ni une facture.'],
        }
        for header in (False, True):
            for footer in (False, True):
                data = deepcopy(base)
                data['emitter'].update(AfficherEnteteDocument=header, AfficherPiedDocument=footer)
                blob = render_pdf(data)
                (output / f'transfert-{int(header)}{int(footer)}.pdf').write_bytes(blob)
                reader = PdfReader(io.BytesIO(blob))
                pages = [page.extract_text() for page in reader.pages]
                text = '\n'.join(pages)
                self.assertGreater(len(pages), 1)
                for marker in ('ENTREPRISE FICTIVE DE RECETTE', 'TRF-TEST', 'CENTRAL', 'SUD', 'LOT-001', 'LOT-045', 'Article de recette 045', '562,50 USD'):
                    self.assertIn(marker, text)
                self.assertGreaterEqual(text.count('Prix unitaire'), 2)
                self.assertIn('N°', text)
                self.assertTrue(all(page.count('Prix unitaire') <= 1 for page in pages), 'Un seul en-tête de tableau par page')
                self.assertEqual('Page 1 sur' in text, footer)
                self.assertNotIn('\ufffd', text)


if __name__ == '__main__':
    unittest.main(verbosity=2)
