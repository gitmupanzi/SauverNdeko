# Recette du module Référentiels — 30 octobre 2026

## Fonctionnalités livrées

Le module présente quatre onglets : **Valeurs de référence**, **Catégories**, **Référencement des champs**, **Tableaux et exports**. Le schéma contient cinq tables : les deux tables de présentation, `T_InterfaceTableau` et `T_PreferenceTableau`, sont réunies dans le dernier onglet pour réutiliser les réglages communs.

- Un seul bouton **Nouvelle valeur** ou **Nouvelle catégorie** ouvre le panier. Une seule ligne permet un ajout individuel ; plusieurs lignes permettent un enregistrement groupé.
- Modification et retrait des lignes, annulation du panier, collage Excel, validations par ligne, détection des doublons et conservation de la saisie en cas d’erreur. Limite de 200 lignes par enregistrement.
- Transaction unique pour le panier et son audit ; une erreur annule toutes ses insertions. Une réponse réseau incertaine peut être vérifiée avec le même identifiant de demande, sans double création.
- Références communes ou propres à une entreprise. Un gestionnaire local ne peut modifier que les références de son entreprise selon ses permissions. Les références existantes restent communes, sans réattribution.
- Association persistante du champ physique à sa catégorie, restauration du défaut, identifiants et libellés visibles dans les réglages Logistique. Les clés étrangères et valeurs métier existantes sont conservées ; une ancienne valeur incompatible est signalée.
- Recherche, filtres, tri, pagination, actions sur la bonne clé et exports Excel/CSV. Le catalogue des tableaux est consultable ; chaque compte modifie ses propres préférences d’affichage et d’export, indépendantes par usage et entreprise.
- Réutilisation des catégories configurées dans les listes des réceptions, factures, règlements, remboursements et inventaires. Les lectures historiques reconnaissent les références enregistrées même après un changement de catégorie.
- Skills actualisés : un seul point d’entrée pour une ou plusieurs lignes, partout où ce parcours convient ; en-tête/détails si les lignes partagent un parent.
- Les tableaux partagés utilisent la même présentation moderne dans les pages et les fenêtres latérales, avec ou sans barre d’outils. En-têtes, cellules fixes, actions, sélection et survol utilisent les couleurs du thème ; les caches blancs et gradients hérités sont neutralisés.

## Base et préservation

Les migrations `20261030_01_referentiels_transversaux.sql` et `20261030_02_lectures_logistiques_dynamiques.sql` ont été appliquées à **SauverNdeko**, chacune après sauvegarde vérifiée. Comparaison des **69 tables** : anciennes données, propriétaires, stocks, documents, préférences et clés étrangères préservés. La seconde migration modifie huit vues et une fonction de protection des factures, sans écriture métier ; leurs résultats historiques restent identiques.

Les 17 exports SQL canoniques sont actualisés. Deux restaurations de structure dans des bases privées vides ont été vérifiées : structure complète de 69 tables, 84 vues, 163 triggers et 170 routines ; structure métier de 59 tables, 84 vues, 163 triggers et 139 routines. Les commentaires et contrats de colonnes sont contrôlés.

## Tests réellement exécutés

| Vérification | Résultat | Conditions |
|---|---:|---|
| Socle PostgreSQL transversal | 129 contrôles réussis | Base privée locale ; doublons, concurrence, transaction, périmètres et précision des unités |
| Lectures logistiques dynamiques | 21 contrôles réussis | Base privée ; références privées, historiques, signes et montants |
| API référentiels | 34 tests réussis | Base privée ; panier, rejeu, droits, erreurs, paiement et facture réels, inventaire puis annulation |
| Régression référencement des champs | 27 tests réussis | Base privée ; configuration, restauration, anciennes valeurs et permissions |
| Régression bons de commande | 10 tests réussis | Base privée ; règles CMD et mouvements |
| Catalogue des tableaux et dépendances | 6 tests réussis | Base privée ; préférences isolées, vrais XLSX/CSV, précision privée et catalogue santé |
| Interface de saisie | 119 contrôles réussis | Code réel, hooks/SSR et doubles API/auth ; classe de tableau moderne vérifiée dans le tiroir sans barre d’outils ; pas de navigateur |
| Registres et bouton unique | 57 contrôles réussis | Quatre onglets, filtres, clés d’actions, réglages et export ; pas de navigateur |
| Régression frontend du référencement | 111 contrôles réussis | Code réel avec doubles API/auth ; pas de navigateur |
| Présentation et thèmes des tableaux partagés | 780 contrôles réussis | Cascade CSS réelle, deux ordres de feuilles, pages/tiroirs, clair/sombre/contraste ; contraste des textes au moins 4,5 ; pas de navigateur |
| Compilation frontend finale | Réussie, 346 modules | Build Vite de la version au bouton unique |
| Vérification Django | Réussie | `manage.py check` |
| Diagnostic de la base source | 245 GET réussis | Transaction en lecture seule, aucune donnée de test créée dans SauverNdeko |
| Serveur après redémarrage utilisateur | Vérifié | Backend 5001 et proxy 5174 : santé 200, nouveaux endpoints protégés 401 en anonyme, route inexistante témoin 404 |
| Installation neuve | Réussie | Vrais paquet, plan et application ; 18 migrations Django ; références privées exclues |
| Skills modifiés | Validés | Vérification du format et revue des règles |

Les tests d’installation vérifient aussi les identifiants communs, l’exclusion des références privées, les gardes réactivées, les correspondances initiales fermées et l’absence de comptes/documents copiés. Les données fictives utilisées pour les tests fonctionnels restent exclusivement dans les bases privées locales.

## Limites et points à vérifier

- La recette visuelle et les clics dans un vrai navigateur n’ont pas été exécutés : l’accès du navigateur à localhost est bloqué. Les tests frontend mentionnés ci-dessus ne la remplacent pas.
- Trois champs historiques hors Logistique n’ont pas de défaut déterminé : `operations.T_Paiement.IdTypePaiementFk`, `professionnel.T_Professionnel.IdTypeProfessionnelFk`, `professionnel.T_Professionnel_Entite.IdTypeLienFk`. Ils restent explicitement non configurés ; une nouvelle sélection nécessite leur paramétrage dans Référencement des champs. Aucune catégorie n’a été inventée pour eux.
- Les doublons hérités sont conservés avec leurs identifiants. Les nouvelles collisions sont refusées ; une fusion d’anciennes valeurs serait une opération distincte avec contrôle de toutes leurs utilisations.
- Un changement explicite d’entreprise ferme les éditeurs ouverts ; aucune saisie de l’ancienne entreprise n’est envoyée dans la nouvelle.
- Les services ont rechargé le code après le redémarrage effectué par l’utilisateur. Le lanceur a retenu les ports backend 5001 et frontend 5174. La protection qui refuse d’arrêter un processus dont l’identité est inaccessible n’a pas été désactivée.

Cette recette technique ne constitue pas une déclaration de livraison complète de tous les modules ERP. Voir le [guide utilisateur](guide-referentiels.md) et la [documentation PostgreSQL](../SQL/documentation/Referentiels_Transversaux_20261030.md).
