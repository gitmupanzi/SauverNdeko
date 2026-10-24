"""Conventions SauverNdeko sur données ERP fictives ; aucun test d'exporteur réel."""
from __future__ import annotations
import copy
import json
from decimal import Decimal
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import restitution_exemple as r
FIXTURE = json.loads((ROOT / "tests/fixtures/cas_documentaires.json").read_text(encoding="utf-8"))
DEVISES = FIXTURE["devises_autorisees"]


class RestitutionERPTest(unittest.TestCase):
    def test_donnees_explicitement_fictives(self):
        self.assertEqual(FIXTURE["mode"], "synthetique")
        self.assertIn("NON DÉCISIONNEL", FIXTURE["avertissement"])

    def test_affichage_des_cas_fournis(self):
        fonctions = {"montant": r.montant, "quantite": r.quantite,
                     "pourcentage": r.pourcentage, "points": r.points, "p": r.valeur_p}
        for cas in FIXTURE["restitution"]:
            with self.subTest(cas=cas):
                args = {"motif": cas.get("motif")}
                if cas["type"] == "montant":
                    args.update(devise=cas["unite"], devises_autorisees=DEVISES)
                elif cas["type"] == "quantite":
                    args["unite"] = cas["unite"]
                self.assertEqual(fonctions[cas["type"]](cas["valeur"], **args), cas["attendu"])

    def test_zero_et_absence_distincts(self):
        self.assertEqual(r.montant("0", "USD", devises_autorisees=DEVISES), "0,00 USD")
        self.assertNotEqual(r.montant("0", None), r.montant(None, None, "Source absente"))

    def test_absence_sans_motif_refusee(self):
        for fonction, args in [(r.montant, (None, None)), (r.quantite, (None, None)), (r.date_fr, (None,))]:
            with self.subTest(fonction=fonction.__name__), self.assertRaises(ValueError):
                fonction(*args)

    def test_aucune_devise_par_defaut(self):
        self.assertEqual(r.montant("1250", None), "1 250,00 — devise non renseignée")

    def test_devise_issue_de_la_configuration(self):
        self.assertEqual(r.montant("100", "EUR", devises_autorisees=DEVISES), "100,00 EUR")
        self.assertEqual(r.montant("100", "ALL", devises_autorisees=DEVISES), "100,00 ALL")
        for devise in ["CDF+USD", "", "usd", "XYZ"]:
            with self.subTest(devise=devise), self.assertRaises(ValueError):
                r.montant("100", devise, devises_autorisees=DEVISES)
        with self.assertRaises(ValueError):
            r.montant("100", "USD")

    def test_non_finis_booleens_flottants_refuses(self):
        for valeur in ["NaN", "Infinity", "-Infinity", True, 0.1]:
            with self.subTest(valeur=valeur), self.assertRaises(ValueError):
                r.decimal_fini(valeur)

    def test_quantite_source_non_tronquee(self):
        self.assertEqual(r.quantite("1.125", "kg"), "1,125 kg")
        self.assertEqual(r.quantite("0", "PCE"), "0,000 PCE")

    def test_arrondi_demonstratif_et_valeur_negative(self):
        self.assertEqual(r.nombre_fr("-12.345"), "-12,35")
        self.assertEqual(r.nombre_fr("-0.001"), "0,00")
        for decimales in [-1, 13, True]:
            with self.subTest(decimales=decimales), self.assertRaises(ValueError):
                r.nombre_fr("1", decimales)

    def test_identifiants_et_grandes_references(self):
        for valeur in ["000012", "CMD-0007", "12345678901234567890"]:
            self.assertEqual(r.identifiant(valeur), valeur)
        for valeur in [True, 1.5, ""]:
            with self.subTest(valeur=valeur), self.assertRaises(ValueError):
                r.identifiant(valeur)

    def test_texte_ressemblant_a_une_formule(self):
        for valeur in ["=2+2", "+0012", "-CODE", "@article", "<article>"]:
            self.assertEqual(r.cellule_texte(valeur), {"valeur": valeur, "type": "texte"})

    def test_dates_sans_conversion_de_fuseau(self):
        self.assertEqual(r.date_fr("2026-10-24"), "24/10/2026")
        self.assertEqual(r.date_fr("2026-10-24T23:10:00-04:00", avec_heure=True), "24/10/2026 23:10")
        with self.assertRaises(ValueError):
            r.date_fr("2026-10-24", avec_heure=True)
        with self.assertRaises(ValueError):
            r.date_fr("2026-02-30")

    def test_parite_des_trois_manifestes(self):
        for format_ in ["word", "pdf", "excel"]:
            rendu = dict(copy.deepcopy(FIXTURE["resultat_reference"]), format=format_)
            self.assertEqual(r.differences_demo(FIXTURE["resultat_reference"], rendu), [])

    def test_changement_d_organisation_detecte(self):
        source = FIXTURE["resultat_reference"]
        self.assertIn("organisation_id", r.differences_demo(source, dict(source, organisation_id="AUTRE")))

    def test_page_ne_devient_pas_export_complet(self):
        source = FIXTURE["resultat_reference"]
        self.assertIn("portee", r.differences_demo(source, dict(source, portee="page_affichee")))
        self.assertIn("lignes", r.differences_demo(source, dict(source, lignes=[])))

    def test_filtres_dates_et_unites_conserves(self):
        source = FIXTURE["resultat_reference"]
        for champ, autre in [("filtres_appliques", {}), ("periode", {}), ("unite", "kg"), ("date_situation", "2026-10-23"), ("devise", "USD")]:
            with self.subTest(champ=champ):
                self.assertIn(champ, r.differences_demo(source, dict(source, **{champ: autre})))

    def test_totaux_et_limites_non_reinterpretes(self):
        source = FIXTURE["resultat_reference"]
        totaux = dict(source["totaux"], MontantTTC="44.25")
        self.assertIn("totaux", r.differences_demo(source, dict(source, totaux=totaux)))
        self.assertIn("limites", r.differences_demo(source, dict(source, limites=[])))

    def test_approbation_non_inventee(self):
        source = FIXTURE["resultat_reference"]
        self.assertEqual(source["statut_validation"], "non_effectuee")
        self.assertIn("statut_validation", r.differences_demo(source, dict(source, statut_validation="approuvee")))

    def test_champ_requis_du_manifeste_manquant(self):
        source = FIXTURE["resultat_reference"]
        rendu = copy.deepcopy(source)
        del rendu["unite"]
        self.assertIn("unite", r.differences_demo(source, rendu))

    def test_resultat_statistique_fourni_seulement(self):
        self.assertEqual(r.valeur_p("0.00000042"), "4,2e-7")
        for valeur in ["0", "-0.2", "1.1"]:
            with self.subTest(valeur=valeur), self.assertRaises(ValueError):
                r.valeur_p(valeur)
        self.assertEqual(r.intervalle_fourni("-0.25", "5.25", "0.95", "Exemple fictif fourni", "unités"),
                         "IC 95,00 % [-0,25 ; 5,25] unités — Exemple fictif fourni")
        with self.assertRaises(ValueError):
            r.intervalle_fourni("4", "1", "0.95", "Exemple", "unités")


if __name__ == "__main__":
    unittest.main()
