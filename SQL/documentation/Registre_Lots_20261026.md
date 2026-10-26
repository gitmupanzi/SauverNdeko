# Lots de stock — registre transversal

## Source et périmètre

La migration `20261026_07_registre_lots.sql`, après `20261026_03` et `20261026_05`, ajoute deux vues commentées, sans table supplémentaire et sans effet de stock :

- `logistique.V_RegistreLots` : tous les lots des articles, y compris les lots épuisés et archivés. Solde réel depuis `V_LotDisponibilite`, catégorie/type depuis le référentiel générique, abréviation d’unité et entreprise propriétaire durable de l’article.
- `logistique.V_RegistreMouvementLot` : une ligne par mouvement et lot, avec quantités signées, unité, sens et bon d’origine. Les compensations restent des écritures distinctes.

Les alertes de péremption restent celles de SQL05. Le registre garde la date d’un lot épuisé pour la traçabilité ; les compteurs « périmés en stock » et « proches de péremption en stock » exigent un solde strictement positif. Aucune somme de quantités entre unités différentes n’est affichée.

## Parcours

L’onglet **Lots de stock** suit **Articles**. Il réutilise RegisterSurface, DataTableToolbar, SearchSelect, SimpleTable, le menu de ligne et DrawerDialog. **Lot 360** présente Synthèse et Mouvements ; Produit 360 et le bon d’origine restent accessibles. Les écritures de stock passent par les bons existants.

Filtres serveur : article (recherche distante paginée), catégorie, type d’article, solde disponible/épuisé/négatif, péremption, archivage du lot, état de l’article, création du/au et filtres de colonnes. Recherche, tri stable et pagination sont communs à la liste et à l’export. Les nouveaux critères restent à appliquer avant export.

## API

- `GET /api/logistique/registre/lots` : registre paginé et compteurs de lots/articles.
- `GET /api/logistique/registre/lots/export.xlsx` : tous les résultats filtrés, limite commune de 100 000 lignes.
- `GET /api/logistique/lots/{id}` : en-tête d’un lot autorisé.
- `GET /api/logistique/lots/{id}/mouvements` : journal paginé limité à ce lot, sans chargement de tous les mouvements de l’entreprise.
- `GET /api/logistique/lots/{id}/mouvements/export.xlsx` : même journal complet et mêmes critères.

Le périmètre est l’Entité propriétaire, indépendamment de l’auteur. Le compte global peut lire toutes les Entités ou celle du contexte sélectionné. Une fiche étrangère, même avec journal vide, retourne 404. Export réservé au droit serveur `logistique.canExport` ; aucune écriture n’est proposée par ces routes.

Les fichiers Excel sont natifs : en-tête à la première ligne, quantités numériques avec unité imposée, dates natives, référence de lot en texte. Le menu ⋯ propose la fiche Excel du lot ; aucun PDF artificiel n’est ajouté.

## Vérification

`SQL/tests/test_registre_lots.py` exige explicitement `SAUVERNDEKO_TEST_DATABASE_URL` vers une base dont le nom commence par `sauverndeko_test_`. Aucun repli vers la base réelle. Il crée des données fictives uniquement dans cette base privée.

Recette du 26/10/2026 : **65 contrôles réussis** sur `sauverndeko_test_registre_lots_20261026`, incluant recherche/tri/pages distinctes, lots épuisés et archivés, péremption, scopes de deux entreprises + administrateur global, quantités fractionnaires avec kg, parité Excel, unité forcée, droits HTTP JSON/XLSX et absence de nouveau mouvement après consultation/export. Le build Vite passe avec le registre chargé à la demande. Une recette UI à réponses API simulées confirme le menu Excel, le sélecteur de péremption, le journal du lot et une fenêtre mobile à 390 px sans débordement du document ni erreur JavaScript.

L’installation dans SauverNdeko et la recette visuelle sur la session réelle relèvent du déploiement coordonné ; ces vérifications privées ne l’attestent pas.
