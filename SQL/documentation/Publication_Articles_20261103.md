# Publication volontaire des articles — 3 novembre 2026

## Contrat de données

La migration `20261103_01_publication_articles.sql` ajoute deux choix persistants :

| Objet | Champ | Règle |
|---|---|---|
| `systeme.T_Entite` | `PartageArticlesPublicParDefaut` | Booléen non nul, vrai par défaut. Proposé uniquement aux nouveaux articles de cette entreprise. |
| `logistique.T_Article` | `VisibleCatalogue` | Booléen non nul. Les articles historiques restent privés, avec la valeur faux. |

Le déclencheur `logistique.tr_publication_article_defaut`, appelé par `ab_publication_article` avant insertion, hérite du choix de l'entreprise propriétaire si le champ est omis. Il s'exécute après les gardes `aa_*` de propriété. Un booléen individuel explicite remplace ce défaut, y compris vrai lorsque le défaut de l'entreprise est faux. Une modification ultérieure du défaut ne modifie aucun article existant.

L'ajout initial de `VisibleCatalogue` utilise un défaut constant faux pour les lignes historiques, puis supprime ce défaut SQL : les insertions suivantes sont traitées par le déclencheur. Aucun `UPDATE` de reprise des articles ne déclenche de mouvement de stock. La migration est transactionnelle et rejouable ; elle ne modifie ni quantité, ni prix, ni lot, ni bon ni auteur existant. La colonne est ajoutée à la fin de `V_Article`, sans déplacer ses colonnes précédentes.

Les clés étrangères, catégories centrales, règles de validité et de visibilité, licences et permissions existantes sont conservées. Tous les nouveaux objets et champs SQL sont commentés.

## Projection partagée et confidentialité

`logistique.V_OffreArticle` retient uniquement les articles dont `VisibleCatalogue`, `ValideArticle` et la validité de l'entreprise propriétaire sont vrais. Le défaut de l'entreprise n'est pas une condition de cette vue.

Son grain est un article local d'une entreprise, sans prétendre constituer un produit médical normalisé commun à plusieurs sociétés. Les colonnes SQL sont :

`ID_Article`, `NomArticle`, `RefArticle`, `PVArticle`, `ID_DeviseFk`, `DeviseCode`, `DeviseLibelle`, `Unite`, `EtatDisponibilite`, `PhotoArticle`, `IdEntite`, `NomEntite`, `AdresseEntite`, `PhoneEntite`.

La réponse JSON du catalogue omet l'identifiant technique de devise. La photo est remplacée par une route binaire contrôlée, jamais par un chemin de stockage. Aucun prix d'achat, quantité exacte, note, information complémentaire interne, compte auteur ou coordonnée personnelle de l'auteur n'est exposé. La recherche porte sur désignation, référence, entreprise et adresse publiée ; les informations internes ne sont pas recherchables.

`Stock déclaré` signifie seulement que la quantité enregistrée est positive ; `Stock nul déclaré` indique l'absence de stock positif déclaré. Aucun de ces libellés ne garantit la disponibilité vendable, la qualité ou la péremption des lots. Aucune heure de confirmation ou de fraîcheur n'est inventée à partir de la date de création ou d'un mouvement.

## Contrat des API

| Parcours | Comportement |
|---|---|
| Fiche Entreprise, Administration et Paramètres | `PartageArticlesPublicParDefaut` est lu et enregistré par le service commun de fiche entreprise, avec motif, révision, audit et identifiant de requête existants. L'absence du champ dans un ancien formulaire conserve la valeur enregistrée. |
| Création d'entreprise | Le contrat de valeurs initiales propose `PartageArticlesPublicParDefaut: true`. |
| `GET /api/logistique/references` | `defaultArticleVisibility` contient le booléen de l'entreprise active ; il vaut `null` dans le contexte global sans entreprise choisie. |
| Ajout et modification d'article | `VisibleCatalogue` est accepté avec les autres champs métier. Une création sans ce champ hérite du choix SQL. Le champ participe à la révision de fiche. |
| Panier d'articles | Chaque ligne possède son choix individuel ; une valeur omise hérite du propriétaire commun du panier. Les règles d'atomicité et de rejeu restent applicables. |
| `GET /api/public/articles` | Liste la projection minimale, avec `q`, `take`, `skip`, tri stable et nombre total réel. |
| `GET /api/public/articles/{id}/photo` | Vérifie la même publication à chaque requête, puis fournit l'image locale autorisée. Une dépublication rend cette route indisponible. |
| `GET /api/public/stats` | Compte les offres réellement publiées. `structuresCount` représente des structures ; il n'est pas nommé nombre de pharmacies sans classification prouvée. Les annonces fictives et la promesse de réponse rapide sont retirées. |

Le terme historique `/api/public` désigne des projections partagées : **ces routes exigent toujours un compte autorisé et les licences correspondantes**. Aucune API de gestion n'est ouverte anonymement. Un utilisateur peut lire une offre publiée par une autre société si sa licence le permet, mais ne reçoit aucun droit de gestion sur cet article ou sa société. Les photos répondent avec `Cache-Control: no-store, private` et `X-Content-Type-Options: nosniff`.

Les images déjà enregistrées sous forme d'adresse externe ne sont pas recopiées dans l'offre partagée. Un dépôt de photo par le sélecteur existant est nécessaire pour utiliser la route locale contrôlée ; l'ancienne référence privée est préservée.

Les identifiants de création et empreintes prennent en compte le choix soumis. Rejouer le même panier ou la même création ne crée aucun second article ou mouvement ; réutiliser un identifiant avec un choix changé provoque un conflit. Les modifications concurrentes d'un article publié ou d'une fiche entreprise restent protégées par les révisions existantes.

## Vérifications exécutées sur bases privées

Les scripts refusent toute base autre qu'une base locale `sauverndeko_test_*`. Ils utilisent exclusivement des entreprises, comptes et articles fictifs pour les écritures de recette.

| Vérification | Résultat |
|---|---|
| `SQL/tests/test_publication_articles_postgresql.py` | 12 tests réussis : héritage, exceptions individuelles, absence d'effet rétroactif, publication conditionnelle, liste fermée de colonnes, mouvements non doublés et rejeu de migration. |
| `SQL/tests/test_publication_articles_api.py` | 10 tests réussis : vraies licences et rôles, défaut entreprise et références, création/édition/panier, transaction intégrale en erreur, rejeu, conflits de révision, isolation des sociétés, confidentialité, devises, pagination, photos et refus anonyme/sans licence. |
| `SQL/tests/test_identite_entreprise_api.py` | 13 tests de non-régression entreprise/logo réussis, dont concurrence, motifs, révisions et compatibilité des anciens formulaires. |
| `backend/manage.py check` | Aucun problème détecté. |
| Restaurations des deux fichiers SQL globaux | 77 et 67 tables restaurées sans données ; définitions et commentaires identiques au clone migré. |

Les preuves locales sont dans `.runtime/publication-tests/verification.json` et `.runtime/publication-canonicals/verification.json`. Elles ne sont pas des données métier et restent hors versionnement.

La recette API utilise une copie privée indépendante. Elle ne vaut pas recette manuelle complète dans le navigateur.

### Installation dans SauverNdeko

Le 3 novembre 2026, la migration a été appliquée à la base SauverNdeko après sauvegarde vérifiée et restauration exacte de ses 77 tables et de ses médias. Elle a d’abord été rejouée deux fois sur cette copie restaurée. Juste avant l’application source, les empreintes des 77 tables correspondaient toujours à la sauvegarde.

Après application, les empreintes de toutes les colonnes antérieures restent identiques, les définitions des autres triggers Article et le nombre de lignes de `V_Article` sont préservés. Les trois articles antérieurs ont `VisibleCatalogue=false` ; aucune offre n’est publiée automatiquement. Le rôle d’exécution possède l’accès SELECT à la nouvelle vue, sans ajout de droit `PUBLIC`. Une entrée d’audit trace l’installation. Preuve locale : `.runtime/publication-source-applied-20261103.json`.

SHA256 de la migration : `ceb91a4cf19dc9d19c6f0a2e42211d248ed819e383b55dd4bfacf785010d8140`.

## Limites conservées explicitement

Cette évolution ne crée pas de recherche scientifique automatique, de diagnostic, de mesure de mortalité, de commande patient ni de preuve de vente ou dispensation. Elle n'ajoute pas de classification pharmacie aux entreprises existantes, de correspondance territoriale internationale ni de produit maître médical. Ces développements restent décrits dans la feuille de route du projet.
