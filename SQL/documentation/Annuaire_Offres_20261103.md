# Annuaire Produits — contrat de lecture

## Sources et portée

La migration `20261103_02_annuaire_offres_articles.sql` complète la projection `logistique.V_OffreArticle` avec les identifiants et libellés des catégories et types déjà enregistrés. Ses quatorze premières colonnes sont conservées. Les libellés réutilisent `referentiel.T_Generique.AbrGenerique`, puis `NomGenerique` lorsque l'abréviation manque. Les identifiants métier et les associations de catégories ne sont pas réécrits.

Une ligne représente toujours **l'article local d'une entreprise**, et non un produit normalisé entre sociétés. Des désignations identiques ne provoquent aucun regroupement. Les filtres s'appliquent aux valeurs centrales enregistrées, sans création de famille médicale ou de qualification thérapeutique.

La publication exige simultanément `VisibleCatalogue`, la validité de l'article et celle de son entreprise. Le défaut de publication de l'entreprise ne filtre pas ses articles existants. Les offres publiées sont consultables transversalement par les comptes disposant de l'accès Produits ; le contexte d'entreprise ne donne aucun droit de modifier les articles d'une autre société. Le CRUD, les quantités et les coûts restent dans Logistique.

Les routes exigent authentification et licence via le module `produits`. Un compte ordinaire licencié peut consulter l'annuaire sans rôle de gestionnaire. Il n'existe pas de lecture métier anonyme.

## API

| Route GET | Données dans `data` |
|---|---|
| `/api/produits/references` | `categories`, `types`, `companies`, `currencies`, `availability`, `canContact` |
| `/api/produits/offres` | `rows`, `total`, `take`, `skip` |
| `/api/produits/offres/{id}` | `record`, `locations`, `canContact` |

Les listes de références contiennent `{id,label}` et proviennent exclusivement des offres actuellement publiées. Elles ne révèlent pas de dictionnaire privé n'ayant aucune offre publiée. Les états disponibles sont `positive` et `zero`.

La liste accepte uniquement :

- `q` : recherche de 300 caractères maximum sur désignation, référence, entreprise, adresse générale, catégorie et type ;
- `categoryId`, `typeId`, `companyId`, `currencyId` : identifiants exacts ;
- `availability` : `positive` ou `zero` ;
- `take` : de 1 à 100 ; `skip` : entier positif ou nul ;
- `sortBy` : `name` ou `company` ; `sortDir` : `asc` ou `desc`.

Les critères inconnus ou répétés sont refusés. Les valeurs sont paramétrées ; seuls des identifiants SQL et sens de tri issus de listes fermées sont utilisés. `%` et `_` saisis sont des caractères littéraux, pas des jokers. La recherche utilise la collation PostgreSQL ICU `pg_catalog."und-x-icu"` pour rapprocher É/é, y compris après restauration dans une base de locale C. Les accents ne sont pas supprimés. Cette collation est contrôlée sur les serveurs source et de recette ; le diagnostic `verifier_backend` exécute aussi une recherche pour vérifier cette dépendance.

Le total est calculé sur toute la population filtrée. Compteur et page partagent une instruction SQL et un même instantané ; le tri utilise l'identifiant d'article comme départage stable. Aucune comparaison globale de prix n'est proposée entre des devises ou unités différentes.

Chaque offre expose les champs de publication existants, plus `ID_CategorieArticleFk`, `CategorieArticle`, `ID_TypeArticleFk`, `TypeArticle` et `ID_DeviseFk`. Elle ne contient ni quantité exacte, ni coût d'achat, ni note ou information interne, ni auteur. Le prix de vente conserve sa devise et son unité déclarées, sans conversion.

`Stock déclaré` et `Stock nul déclaré` restent des informations déclaratives, sans promesse de disponibilité vendable ou de fraîcheur. Aucun horodatage de confirmation n'est fabriqué.

## Localisations, photo et contact

`logistique.V_OffreArticleLocalisation` réutilise les vrais points de `systeme.V_Entite_Localisation_Detail` rattachés à l'entreprise d'une offre publiée. Elle expose `ID_Article` et les seuls textes `label`, `address`, `zone`, `area`, `site`. La réponse de détail omet même l'identifiant d'article répété dans chaque localisation.

Les niveaux 3, 4 et 5 sont ceux explicitement enregistrés sur le point ; aucun parent non renseigné, pays, province, GPS ou distance n'est déduit. Il n'est pas affirmé que l'article se trouve physiquement sur chaque site de l'entreprise. Une entreprise sans point déclaré donne `locations: []` ; son adresse générale reste disponible dans la fiche de l'offre.

La photo utilise la route contrôlée existante `/api/public/articles/{id}/photo`, avec JWT, licence et nouvelle vérification de publication. Les adresses externes et chemins privés ne sont pas exposés.

`canContact` exige le droit de gestion Discussions, le droit de consultation Structures et un serveur autorisant les écritures. Il prépare uniquement l'ouverture du parcours de discussion existant. La recherche ou l'ouverture d'une fiche ne crée ni discussion ni message et n'accorde aucun droit supplémentaire sur les coordonnées ou comptes personnels.

## Recette et limites

- 12 tests API de l'annuaire : pagination de 107 offres, filtres combinés, références, recherche Unicode, tris stables, détail minimal, localisations, retrait de publication, activité, licences, utilisateur ordinaire, droits de contact, critères malveillants et absence d'écriture.
- 10 tests API de non-régression Publication : défaut entreprise, exceptions individuelles, versions, rejeu, panier atomique, confidentialité, photo, licences et stock préservé.
- 9 tests SQL : ordre des colonnes, liste fermée, référentiels, localisations déclarées, publication et rejeu de migration sans modification des données métier ou triggers.

Les écritures fictives de préparation sont limitées à des clones locaux `sauverndeko_test_*`. Preuves locales : `.runtime/produits-api-tests/verification.json`, `.runtime/produits-sql/tests.log` et le rapport de restauration des fichiers SQL canoniques. La migration source et sa preuve de préservation relèvent de l'installation contrôlée, distincte de ces recettes.

La migration a ensuite été installée dans la source par le processus de livraison, après sauvegarde et restauration vérifiées de 77 tables et trois médias. Elle a été rejouée deux fois sur la copie exacte avant application. La comparaison des 77 tables source, des triggers existants et des quatorze colonnes historiques de la projection est inchangée. Les zéro offres publiées présentes lors de l'installation restent zéro : aucune publication n'a été activée pour alimenter la démonstration. Les droits de lecture du rôle PostgreSQL d'exécution ont été vérifiés et l'installation auditée. Preuve : `.runtime/produits-source-applied-20261103.json`.

SHA256 de la migration installée : `ed296bbee75cc6ab970c5d6bdac183973469e0d2ffccf474af8e88a32f16680e`.

Les routes historiques `/api/public/articles` conservent leur contrat. L'annuaire ne normalise pas les produits entre entreprises, n'identifie pas des pharmacies certifiées et ne mesure ni achat, maladie ou mortalité. Aucune collecte analytique de recherche, localisation ou message n'est ajoutée ; le socle `analytics.T_Recherche` est inchangé.

### Interface et contrôles après redémarrage

`/produits` utilise un module dédié et ses lectures propres, sans hériter de l'ancienne liste limitée aux vingt premiers articles. Cartes et tableau présentent une seule population et conservent la même barre de recherche et de filtres, même avec un résultat non vide. Les filtres brouillons ne remplacent les critères appliqués qu'à validation. Les liens de fiche et les liens paginés restent utilisables hors de la première page ; la fermeture restaure le contexte et le focus. La fiche Offre de produit utilise DrawerDialog et la photo contrôlée, sans ouvrir le Produit 360 privé.

Contrôles exécutés : 132 assertions fonctionnelles Produits, 53 de publication/photo, 78 de navigation/catalogue, 514 de cascade CSS dans les thèmes clair, sombre et contraste élevé, et compilation Vite (329 modules). Les contrats responsive couvrent 320, 375, 768, 1440 et 1920 pixels. Les 20 tests API du Guide utilisateur passent avec les tutoriels actualisés ; les skills frontend/backend sont validés.

Le lanceur du projet a redémarré Django et Vite. Dix-sept contrôles HTTP ont confirmé la disponibilité des listes, références, recherche Unicode, guide et ressources frontend, ainsi que les refus anonymes, de mutation, de critères invalides et de fiche/photo non publiée. Les empreintes des données métier sont identiques avant/après ces lectures. Le diagnostic `verifier_backend` réussit ses 354 contrôles GET en connexion READ ONLY. Preuves : `.runtime/produits-live-http-20261103.json` et `.runtime/produits-diagnostic-20261103.log`.

Aucun article source n'a été publié pour simuler une liste remplie. Le choix de publication reste une opération réelle de l'entreprise dans Logistique → Articles. Les cas avec plus de cent offres ont été testés uniquement dans les bases privées de recette. Les tests React et CSS ne remplacent pas une vérification visuelle interactive : l'accès navigateur ayant été refusé dans cette session, cette vérification reste à effectuer.
