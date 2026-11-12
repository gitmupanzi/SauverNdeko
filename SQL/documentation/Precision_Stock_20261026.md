# Précision du stock par unité — migration 20261026_10

Migration installée et vérifiée dans SauverNdeko le 26 octobre 2026 à 17:31:59 UTC, après sauvegarde vérifiée et arrêt ciblé du backend. Ne pas la rejouer.

## Décision

La politique de quantité appartient à `logistique."T_PrecisionStock"`. La table possède exactement quatre colonnes : `ID_PrecisionStock`, `ID_UniteFk`, `DecimalesStock` et `ModifieLe`.

`ID_UniteFk` est une clé étrangère réelle vers `referentiel."T_Generique"."ID_Generique"`, comme l’unité des articles. Une contrainte unique impose une politique au plus par unité ; le trigger impose la catégorie **Unités (34)**. Le référentiel conserve les libellés et abréviations, sans colonnes de précision logistique.

La vue `logistique."V_PrecisionStock"` fournit la lecture commune au grain unité. Une nouvelle unité sans politique garde le défaut entier (zéro décimale). L’absence de politique est visible par un identifiant et une date NULL ; elle n’invente aucun réglage antérieur.

## Reprise et protection

L’inspection de SauverNdeko en transaction READ ONLY a trouvé huit unités, aucune précision explicite et aucune date de précision. Les colonnes se trouvent réellement sur `T_Generique`, pas sur `T_CategorieGenerique`.

La migration crée une ligne pour chaque unité active. Elle conserve toute précision et date explicites, y compris pour une unité devenue inactive ; sinon elle initialise zéro décimale et la date réelle de la migration. Elle compare les valeurs reprises avant de retirer les deux anciennes colonnes avec RESTRICT. Les stocks, prix, documents, mouvements et identifiants d’unités ne sont pas réécrits.

Les contrôles PostgreSQL conservent le verrou commun sur l’unité. Les politiques ne sont pas supprimées et leur unité/identité reste immuable. Une réduction de précision incompatible avec le stock, son seuil, les lignes de bons, mouvements, ventilations de lots, comptages, instantanés de facture, avoirs ou arrêtés CUMP est refusée. Un changement de libellé de l’unité reste possible ; une unité utilisée ne peut pas être reclassée.

## Dépendances adaptées

- `logistique.fn_verifier_quantite(integer,numeric)` garde sa signature et lit la vue commune.
- `V_InventaireLigne` garde les colonnes consommées, notamment l’alias `Decimales`.
- `quantities.policy`, le catalogue de comptage et le réglage des unités lisent la nouvelle vue.
- L’API `/api/logistique/inventaires/unites` conserve `ID_UniteFk` et `Decimales`, ajoute `ID_PrecisionStock` à sa lecture et écrit dans la table avec audit.
- Le modèle Django reste unmanaged ; aucune migration Django métier n’est créée.
- Le paquet d’installation vierge inclut cette politique partagée dans sa liste fermée de dictionnaire, sans compte ni document client.

## Livraison et recette

La migration versionnée est `backend/database/migrations/20261026_10_precision_stock_table.sql`. Elle est unique, transactionnelle et refuse un état source incomplet ou déjà converti. Ne pas la rejouer.

`SQL/3. Schema logistique/PrecisionStock_Tables_views.sql` décrit les définitions cibles sans DML de reprise. Il complète les instantanés historiques des domaines ; ceux-ci restent le socle ancien et ne doivent pas être rejoués sur une base existante. Une installation neuve utilise le paquet courant ou l’ordre complet des migrations.

Avant application : conserver une sauvegarde complète vérifiée et la copie ciblée des réglages/définitions, mettre le service en maintenance, vérifier la migration sur une base privée locale, puis appliquer une fois et contrôler la reprise. Un timeout ou une dépendance imprévue annule la transaction ; aucun DROP CASCADE ne masque ces écarts.

Le snapshot ciblé privé et son empreinte sont conservés dans `.runtime/precision-stock-preparation/`. Ils documentent la source et facilitent le contrôle, mais ne remplacent pas une sauvegarde complète.

La recette dédiée `SQL/tests/test_precision_stock_table.py` exige une base locale `sauverndeko_test_*`, ne crée pas de base et annule ses données fictives. Les recettes d’inventaire, chaîne logistique, registre de lots et CUMP utilisent désormais la politique dédiée. Les sept suites ont réellement été exécutées sur des clones privés séparés, issus de la structure et du dictionnaire de SauverNdeko sans données clients : 28 contrôles de précision, 8 de concurrence, 25 de contrat API et audit, 31 d’annulation d’inventaire, 112 de chaîne logistique, 65 du registre des lots et 45 de CUMP, soit 314 contrôles réussis. Les deux sens de concurrence entre configuration et validation sont vérifiés. La reprise des huit unités, dont une précision et sa date explicites introduites uniquement sur le clone, est conservée exactement. Le cluster de recette est arrêté.


## Sauvegarde préalable vérifiée

Une sauvegarde complète privée a été réalisée avant l’application prévue : `.runtime/backups/avant-precision-stock-20261026-171642`. Les 63 tables utilisent un instantané cohérent en lecture seule ; le catalogue et le décodage intégral du dump sont vérifiés, ainsi que les empreintes du dump et des médias. Empreinte SHA-256 du dump : `d5f0e9a217a44c3aba20daf257d444e569c015b56d2639a252c36a4a49c728c1`. Cette vérification n’est pas une restauration complète de données clients.

Les 62 catégories, 799 valeurs génériques et neuf modules de la source ont aussi été comparés à l’extraction antérieure aux essais : empreintes identiques. Aucun essai n’a inséré de données fictives dans SauverNdeko.

Le wrapper privé a vérifié l’empreinte de migration revue et la fraîcheur de la sauvegarde, arrêté uniquement le backend géré, comparé les empreintes métier dans la transaction avant commit, puis relancé le backend dans finally. L’application réelle est terminée ; le frontend est resté sur 5174 et le contrôle de santé du backend sur 5000 est réussi.


## Contrôles après application

La table possède exactement les quatre colonnes demandées et huit lignes. La contrainte réelle `precision_stock_unite_fk` pointe vers T_Generique ; chaque ligne désigne une unité de la catégorie 34. Les anciennes colonnes DecimalesStock et PrecisionStockModifieLe ont été retirées du référentiel. Les huit politiques sont initialisées à zéro décimale ; leurs dates correspondent à cette initialisation, sans inventer un réglage antérieur.

Les empreintes des 63 tables source sont identiques avant/après, en excluant uniquement les deux colonnes retirées de T_Generique. Stocks, bons, lignes, mouvements, lots, factures, règlements, avoirs et valorisation n’ont subi aucune variation. La migration ne crée aucun mouvement.

Quatre GET ont été exécutés directement avec APIClient Django sur la base réelle, dans une transaction PostgreSQL effectivement READ ONLY : réglages des unités (huit lignes, 200), catalogue de comptage (deux articles, 200), inventaires (trois lignes, 200) et export XLSX des devises (trois valeurs, 200, en-têtes à la première ligne). Aucun PUT réel ni navigation navigateur n’a été réalisé pour cette recette. Les preuves privées sont conservées sous `.runtime/precision-stock-preparation/application-verifiee.json` et `verification-api-readonly.json`.
