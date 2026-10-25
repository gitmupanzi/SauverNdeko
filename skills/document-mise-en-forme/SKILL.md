---
name: document-mise-en-forme
description: Structurer, mettre en forme et vérifier les fichiers Excel, Word et PDF de SauverNdeko et de ses organisations utilisatrices. Utiliser pour les exports ERP, stocks, commandes, livraisons, factures, règlements et rapports, avec charte commune, données typées et parité des formats.
---

# Documents SauverNdeko

## Finalité

Appliquer la charte de SauverNdeko aux documents et exports de l’ERP, en conservant le périmètre autorisé et les valeurs du backend. La mise en forme ne calcule ni stock, ni facture, ni taxe, ni règlement. Ce skill définit les règles et modèles ; il ne rend pas automatiquement conformes les exporteurs existants.

## Références à lire selon le besoin

- Pour tout document : [charte commune](references/charte_documentaire.md), puis [catalogue des livrables](references/documents_types.md).
- Pour Excel : [classeur et cellules natives](references/excel.md).
- Pour Word/PDF : [mise en page et rendu](references/word_pdf.md) et [tableaux](references/tableaux.md).
- Pour un export applicatif : [intégration réelle](references/integration_plateforme.md), [parité et traçabilité](references/exports_et_tracabilite.md) et [contrôle qualité](references/controle_qualite.md).
- Pour un rapport de pilotage : [lecture opérationnelle et direction](references/rapports_business_analytics.md), puis [graphiques](references/graphiques_analytiques.md) si nécessaire.
- Pour une analyse statistique explicitement demandée : [restitution des résultats fournis](references/resultats_statistiques.md). Aucune méthode ou fonction statistique n’est présumée implémentée dans l’ERP.
- Pour la diffusion : [données et destinataires autorisés](references/confidentialite_diffusion.md).

La [configuration de charte](assets/charte_sauverndeko.json) porte les valeurs communes et le [logo](assets/sauverndeko-logo.jpg) est une copie exacte de frontend/public/sauverndeko-logo.jpg. Ne pas importer l’identité d’une autre organisation.

## Invariants du projet

1. Identifier le document, l’organisation émettrice, son destinataire, la portée, la période/date de situation et les données disponibles. SauverNdeko est le logiciel ; il ne remplace pas l’identité de l’organisation sur une facture ou un bon de livraison.
2. Utiliser les vues et services communs de SauverNdeko. Un indicateur, son détail et son export reprennent les mêmes critères appliqués. Un export de page ne se présente pas comme un registre complet.
3. Conserver les identifiants et références en texte, les montants/quantités en nombres et les dates en dates natives dans Excel. Ne pas convertir un code contenant des zéros initiaux ou un texte ressemblant à une formule.
4. Absence, zéro observé, non-applicable et erreur restent distincts. Une devise ou unité non fournie reste non renseignée ; le USD codé en dur dans un ancien helper n’est pas une preuve de devise. Ne pas additionner des unités ou devises différentes.
5. Restituer les montants HT, TTC, réglés et restants reçus. La routine logistique actuelle fixe HT et TTC au même total de lignes : ne pas en déduire une exonération ou un taux de taxe. Le stock courant n’est pas un stock historique reconstruit.
6. Produire de vrais fichiers .xlsx, .docx et .pdf. Un tableau HTML renommé .xls, un CSV ou une fenêtre d’impression n’est pas une preuve de conformité des trois formats.
7. Word utilise styles, listes, en-têtes et champs de pagination natifs. Les tableaux restent dans la zone imprimable, avec en-têtes répétés ; les données chiffrées sont alignées à droite.
8. Réutiliser la charte commune, en adaptant seulement les données d’identité autorisées et les besoins du document. Ne pas inventer une adresse, une signature, un numéro de facture ou une validation.
9. Vérifier le rendu des fichiers effectivement générés : toutes les pages Word/PDF des cas de recette, cellules et impression Excel. Une génération ou une extraction de texte réussie ne prouve pas le rendu.

Pour les exports Excel de listes, appliquer la préférence explicite du 25/10/2026 : en-têtes à la première ligne, données dès la deuxième, gris clair et texte sombre. Aucun logo ou bloc de présentation au-dessus du tableau ; conserver le contexte dans Informations. Cette règle remplace la présentation bleue antérieure pour Excel.

## Sources et intégration

Lire [le skill ERP](../sauverndeko-erp/SKILL.md), [le backend](../../backend/skill/SKILL.md) ou [le frontend](../../frontend/skill/SKILL.md) selon la couche touchée. Conserver Django/DRF, PostgreSQL et React existants ; aucun exporteur ou système de jobs d’un autre projet n’est supposé disponible.

Les modèles de [rapport](modeles/rapport_direction.md), [commande](modeles/bon_commande.md), [livraison](modeles/bon_livraison.md) et [facture/règlement](modeles/facture_reglement.md) sont des plans de contenu. Ils ne sont pas des fichiers Office binaires ou des fonctionnalités déjà raccordées.

## Validation du skill

Exécuter scripts/verifier_dossier.py --strict-external puis python -m unittest discover -s tests -p "test_*.py" -v. Le contrôle vérifie fichiers, liens, charte, logo et empreintes ; les tests utilisent des données ERP fictives. Ils ne remplacent pas les tests des exporteurs ni le contrôle visuel de vrais documents. Consigner le niveau réellement vérifié dans [le bilan](CONTROLE_LIVRAISON.md).
