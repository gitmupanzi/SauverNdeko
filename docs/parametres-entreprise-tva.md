# Paramètres de l’entreprise et TVA

Le module **Paramètres**, accessible à `/parametres` depuis Vos applications, centralise les coordonnées, informations légales, documents, localisations et paramètres fiscaux de l’entreprise. Il utilise la même fiche que Administration → Entreprises et l’identité documentaire de Logistique. Aucune seconde copie du nom, du logo ou des coordonnées n’est créée.

Ce module appartient au socle de l’application. Son accès ne nécessite pas une licence Logistique. Chaque utilisateur consulte l’entreprise autorisée ; les administrateurs habilités peuvent modifier ses paramètres. L’administrateur global choisit une entreprise avant de modifier sa fiche. La création d’entreprises ainsi que leur type et leur état restent gérés dans Administration.

## Définir la TVA

1. Ouvrir **Paramètres** et sélectionner l’entreprise si nécessaire.
2. Cliquer **Modifier**, puis ouvrir **Fiscalité**.
3. Renseigner le **taux de TVA (%)**, entre 0 et 100, avec quatre décimales au maximum. La virgule de saisie est acceptée.
4. Indiquer le motif de modification et enregistrer.

Le taux est conservé dans `systeme.T_Entite.TauxTVAEntite`. Son défaut est **0 %**, pour les entreprises actuelles et futures. Une modification depuis Paramètres, Administration ou la fiche documentaire utilise la même source et les mêmes contrôles de révision. Le paramètre ne détermine pas automatiquement un régime fiscal ou une exonération.

## Factures et avoirs

Les prix unitaires des lignes forment la base hors taxes. Lors d’une nouvelle émission, PostgreSQL calcule la base HT, la taxe arrondie par ligne et le total TTC, puis conserve le taux et les montants sur la facture. Les interfaces, exports et PDF reprennent ces valeurs. Les prix et montants de lignes des factures et avoirs sont identifiés comme HT.

Exemple fictif de contrôle : une base de 100 USD et un taux saisi de 16 % produisent une TVA de 16 USD et un total de 116 USD. Ce taux illustre le calcul ; il n’est pas installé sur les entreprises.

Changer le taux de l’entreprise ne modifie aucune facture émise. Si la préparation d’une nouvelle facture était déjà ouverte, l’enregistrement demande de recharger ses données lorsque le taux a changé. Un rejeu après réponse incertaine conserve le même contenu et ne crée pas une seconde facture.

Une restitution avant facturation réduit les quantités facturées. Une restitution après émission produit un avoir qui reprend le taux de la facture d’origine, avec contrôle des arrondis cumulés : les retours successifs ne peuvent pas rembourser plus que le montant facturé. Les règlements et soldes utilisent les montants TTC. Le taux ne modifie pas les mouvements de stock ni les coûts physiques des bons.

Ce périmètre fournit un taux commun par entreprise pour les nouvelles factures. Il ne configure pas des taux différents par article ou plusieurs taxes cumulées.

## Installation et vérifications du 2 novembre 2026

La migration `20261102_01_entite_tva.sql` a été appliquée dans SauverNdeko après sauvegarde et restauration de contrôle. Les anciennes données métier et leurs colonnes existantes sont préservées. Les entreprises ont reçu le défaut 0 ; aucun exemple à taux positif ni document fictif n’a été inséré dans la base applicative.

Vérifications réalisées sur bases privées :

- 114 assertions PostgreSQL : anciennes factures et avoirs, défauts, bornes, deux entreprises, arrondis, retours, immutabilité, vues et catalogue des colonnes.
- 16 tests API Paramètres, 13 tests d’identité entreprise et 29 tests Administration.
- 12 tests API de facturation : préparation, émission, taux modifié, rejeu, restitutions, avoirs, solde, refus interentreprises, modification des métadonnées, PDF et export Excel des colonnes fiscales.
- Facture et avoir PDF générés, texte vérifié puis pages rendues et inspectées visuellement.
- Exports CSV et Excel des factures et bons vérifiés avec TVA et avoir, y compris après changement du taux de l’entreprise.
- 362 assertions d’interface sur API/DOM simulés et 304 contrôles CSS ; compilation Vite vérifiée.
- Diagnostic en lecture seule de la base SauverNdeko : 323 routes GET réussies sur 323, sans écriture métier.
- Deux restaurations SQL et une installation complète sur une base privée vide : structures, commentaires, défaut TVA 0 et module Paramètres vérifiés.

Les contrats SQL sont détaillés dans [Paramètres et TVA](../SQL/documentation/Parametres_TVA_20261102.md). Les preuves locales de sauvegarde, tests et installation sont conservées dans `.runtime`, hors Git. La recette interactive du navigateur reste distincte des tests simulés : son accès automatisé à localhost était bloqué lors de cette intervention.
