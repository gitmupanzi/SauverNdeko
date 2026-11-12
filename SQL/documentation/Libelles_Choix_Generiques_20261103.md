# Libellés des choix génériques — 3 novembre 2026

## Contrat commun

Les listes catégorielles adossées à `referentiel."T_Generique"` affichent la valeur non vide et nettoyée de `AbrGenerique`. La valeur enregistrée reste `ID_Generique` : le changement de libellé ne change aucune clé étrangère, catégorie, visibilité ou permission.

Si l’abréviation manque, le libellé devient `Valeur sans abréviation #<ID_Generique>`. Aucun repli sur `NomGenerique` ne masque une abréviation manquante. Le nom demeure disponible pour l’édition du dictionnaire, la recherche, les synonymes et les règles métier existantes.

Une ancienne valeur conservée après un changement de catégorie reprend son abréviation actuelle et conserve ses indicateurs `disabled` / `incompatible`. Si la visibilité empêche sa présence dans les options, les formulaires utilisent le libellé neutre identifié et gardent la valeur enregistrée. Les options non génériques — entreprises, utilisateurs, lieux — gardent leur propre libellé.

## Chemins harmonisés

| Consommateur | Source / adaptation |
|---|---|
| Administration | `core.field_references.reference_options`, options de rôles et de types d’entreprise ; fonctions/services du personnel normalisés dans l’éditeur commun. |
| Logistique | Même fournisseur central pour articles, bons, tiers, factures et immobilisations ; normalisation du panier et des choix de devises. |
| Caisse | Fournisseur central, normalisation `caisseOptions` et affichage des choix monétaires. |
| Territoires | Fournisseur central avec conservation des flags de visibilité et des anciennes références. Les rattachements géographiques restent des choix non génériques. |
| Professionnels | Fournisseur central, `_label` / `expertOptions` / `expertLabels`, réglages des références et anciens mappers publics. |
| Paramètres | Types d’entreprise obtenus par le même référencement de champs que l’administration. |
| Support | Suppression de deux surcharges qui remplaçaient le libellé central par le nom ; résultats de vérification, historique et colonnes Kanban utilisent l’abréviation. |

Les helpers communs sont `backend/apps/core/reference_labels.py` et `frontend/src/utils/referenceOptions.js`. Les choix de devises utilisent ce contrat pour leur libellé ; leur code métier, la normalisation monétaire et les instantanés historiques restent inchangés.

## Migration

`backend/database/migrations/20261103_06_libelles_choix_generiques.sql` met à jour les projections catégorielles de `support."V_Support"` et `support."V_ResolutionSupport"` sans changer leurs types de colonnes ni les règles du circuit Support. Chaque colonne modifiée reçoit un commentaire. La migration est transactionnelle et rejouable ; elle ne réécrit aucune ligne métier ou valeur du dictionnaire.

SHA-256 : `0671413986953240b07d14c0956a79cd5d401661f07c150f25bb9498ec029803`.

## Vérifications exécutées

Sur PostgreSQL privé local `sauverndeko_test_reference_labels_20261103`, cloné depuis `sauverndeko_test_contacts_fresh_d48309d8` :

- migration 06 appliquée puis rejouée une deuxième fois ;
- Support : **34 tests API** réussis, dont `NomGenerique` différent de `AbrGenerique`, conservation du même ID et du code de statut, puis abréviation nulle ;
- référencement des champs : **27 tests API** réussis, dont catégorie effective, valeur historique incompatible affichée par son abréviation, visibilité, droits, isolation entre entreprises, restauration et absence de modification des données métier ;
- Professionnels : **29 tests API** réussis ;
- Caisse : **12 tests API** réussis, dont identité monétaire préservée.

Tests JavaScript avec les véritables helpers et composants et des doublures du transport / DOM : **126 assertions** référencement, **158** Support, **83** Caisse, **79** Professionnels, **106** panier Administration et **51** profil/tableau de bord Administration réussies. Les assertions ciblent aussi le panier logistique, les mappers, les devises et une référence conservée portant le même identifiant et un nom différent.

La recette Structures réalisée par l’agent principal comprend en outre **13 tests API** réussis, dont le contact public historique affiché avec une abréviation différente du nom et un ID conservé (`.runtime/structures-final-labels-api.log`).

Les journaux privés sont conservés dans `.runtime/reference-labels-*-api.log`. Ces recettes n’ont écrit ni dans la base SauverNdeko ni dans sa copie de sauvegarde. Elles ne constituent pas une recette visuelle dans un navigateur. Le script optionnel `experts-react.cjs` n’a pas été exécuté faute de chemin fourni vers son renderer temporaire ; les recettes Professionnels API et composants ci-dessus ont été exécutées.

## Périmètre volontairement préservé

Les noms du dictionnaire restent éditables et exportables comme données descriptives. Les règles d’authentification et de privilèges basées sur les noms/codes de rôles, l’interprétation des délais de paiement, les alias de recherche et les instantanés de documents financiers ne sont pas renommés. Cette correction porte sur les libellés proposés dans les choix catégoriels et sur les projections Support nécessaires à leur cohérence, pas sur une réécriture générale de tous les champs descriptifs SQL.
