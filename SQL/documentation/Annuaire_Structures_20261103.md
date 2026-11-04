# Annuaire Structures — contrat PostgreSQL

> Document historique du parcours d’entreprises ERP du 3 novembre 2026. Depuis la correction du 4 novembre, `/pharmacies` utilise l’annuaire des structures et territoires N3/N4/N5 décrit dans [le contrat actuel](Annuaire_Sanitaire_Territorial_20261104.md). Les descriptions de publication d’entreprise, de profils, de logos et de contact par Discussions ci-dessous ne définissent plus cette page. Les objets ERP et leurs usages propres sont conservés.

La migration `20261103_03_annuaire_structures.sql` distingue l’entreprise administrée de sa fiche professionnelle publiée. Elle ne crée pas de table de pharmacies, ne transforme pas les entreprises existantes en pharmacies et ne modifie pas les offres d’articles publiées.

## Publication

`systeme.T_Entite.VisibleAnnuaireEntite` est un booléen obligatoire, `false` par défaut pour les entreprises existantes et nouvelles. La publication exige simultanément `ValideEntite = true` et `VisibleAnnuaireEntite = true`. Son retrait s’applique immédiatement aux lectures, détails et logos contrôlés par les API. Cette autorisation reste distincte de `PartageArticlesPublicParDefaut` et de `T_Article.VisibleCatalogue`.

`PresentationPubliqueEntite` est un texte facultatif de 5 000 caractères au maximum. Le frontend l’affiche comme du texte, sans interpréter du HTML. Aucune entreprise existante ne reçoit une présentation ou un consentement inventé.

## Projections fermées

`systeme.V_StructurePublique` expose exactement :

| Champ | Usage |
|---|---|
| IdEntite | Clé du détail publié |
| NomEntite | Nom professionnel actuel |
| IdTypeEntiteFk | Référence centrale déjà enregistrée |
| TypeEntite | Abréviation centrale, sinon nom |
| AdresseEntite | Adresse professionnelle déclarée |
| PhoneEntite | Téléphone professionnel déclaré |
| SiteWebEntite | Site web facultatif déclaré |
| PresentationPubliqueEntite | Présentation facultative |
| HasLogo | Présence d’un logo validé par les contraintes existantes |
| LogoMimeEntite | Type MIME du logo |
| LogoSha256Entite | Empreinte de révision du logo |

Sont exclus : e-mail, identifiants fiscaux et légaux, paramètres documentaires, TVA, comptes et données RH, auteurs et dates techniques, octets ou chemin privé du logo. Une lecture publique de logo doit vérifier à nouveau cette projection avant de servir les octets privés validés.

`systeme.V_StructureLocalisation` expose seulement `IdEntite, label, address, zone, area, site`. Elle réutilise les points existants de `V_Entite_Localisation_Detail`, rattachés explicitement à l’entreprise actuellement publiée. Aucun point n’est inventé ; un point ne contenant que des coordonnées brutes n’est pas publié comme adresse. Les parents territoriaux absents ne sont pas inférés. Aucune latitude, longitude, clé de point, identité d’auteur ou mesure de distance n’est exposée.

`systeme.V_Entite_Public` conserve son contrat historique réel de **six** colonnes, dans le même ordre et avec les mêmes types : `IdEntite, NomEntite, PhoneEntite, AdresseEntite, ValideEntite, T_Generique`. Son périmètre impose désormais le même consentement explicite. Le nom historique d’une route `pharmacies` ne qualifie pas toutes ces structures de pharmacies.

## Référentiel transversal

La catégorie de type d’entreprise est résolue par `referentiel.fn_categories_champ('systeme','T_Entite','IdTypeEntiteFk',NULL)`. Aucun identifiant de catégorie n’est fixé dans cette migration. Une famille unique, commune et active est requise ; un réglage absent, ambigu ou privé provoque un refus explicite.

Huit types utiles sont ajoutés dans cette famille s’ils sont absents : Pharmacie, Dépôt pharmaceutique, Établissement de santé, Agence immobilière, Promoteur immobilier, Entreprise de construction, Bureau d’études et Cabinet d’architecture. Les identifiants et les libellés/code antérieurs restent conservés, notamment École et Université. Aucun type n’est affecté automatiquement à une entreprise. Le contrôle de doublon réutilise la normalisation centrale ; un conflit ambigu ou une valeur existante inactive est signalé sans réactivation silencieuse.

Le paquet d’installation exporte déjà les dictionnaires communs via `common_dictionary_seed`. Il transporte les types communs installés ; aucun paquet contenant des entreprises ou des fiches publiées n’est ajouté.

## Droits et effets

La migration n’accorde aucun droit `PUBLIC`, n’ouvre aucune route anonyme, ne change aucune licence et ne publie aucun article. Les API conservent les contrôles de module Structures et des éventuels modules liés. Une affiliation de professionnel doit rester explicite, actuelle et publiée ; le propriétaire d’un compte n’est pas une affiliation implicite.

Les tables métier, les mouvements, les prix, les quantités, les affectations et les triggers existants restent inchangés. Les seuls ajouts de données sont les huit types centraux manquants. Les deux colonnes nouvelles reçoivent une valeur par défaut ou `NULL` sans réécriture des autres champs.

## Recette

La recette `SQL/tests/test_annuaire_structures_postgresql.py` refuse toute base qui n’est pas locale et nommée `sauverndeko_test_*`. Les fiches et points fictifs de chaque test sont annulés par transaction. Elle contrôle les valeurs par défaut, la publication et le retrait, les projections fermées et historiques, la présentation, les anciennes FK, les lieux réellement déclarés, l’indépendance du partage des articles, les commentaires SQL, le référentiel, l’absence de droit PUBLIC et le rejeu de migration.

Contrôles effectivement exécutés le 3 novembre 2026 :

- 16 recettes PostgreSQL réussies sur une première copie privée, puis les mêmes 16 réussies sur une copie de la sauvegarde fraîche restaurée par comparaison exacte : `sauverndeko_test_structures_fresh_eabd6363`. Journaux locaux : `.runtime/structures-sql/tests.log` et `tests-fresh.log`.
- Migration rejouée deux fois sur la copie fraîche. Les 77 tables conservent exactement leurs anciennes données ; seules les deux nouvelles colonnes et huit nouvelles valeurs communes sont ajoutées. Tous les triggers existants restent identiques. Aucune entreprise antérieure n’est publiée. Preuve locale : `.runtime/structures-sql/fresh-preservation.json`.
- Deux nouvelles restaurations des structures canoniques, avec 77 tables pour la structure complète et 67 tables pour la structure métier. Elles contiennent zéro ligne de données ; définitions, colonnes, contraintes, vues, routines, triggers et commentaires sont comparés à la copie migrée. Preuve locale : `.runtime/structures-canonicals/verification.json`.
- SHA-256 de la migration contrôlée : `9bf52a59476cc4d425f4adc75951fdc403ce3976aac443546f688d607859ef8e`.

L’installation locale source a ensuite été effectuée par le responsable de livraison après sauvegarde/restauration vérifiée : `.runtime/structures-source-applied-20261103.json`. Les 77 tables antérieures, les triggers et les trois offres publiées sont conservés ; les huit types sont ajoutés et aucune entreprise antérieure n’est publiée automatiquement. Cette preuve locale ne vaut pas installation chez un autre client.

## Contrat API et profils privés

Les nouvelles routes authentifiées `/api/structures/references`, `/annuaire` et `/annuaire/<id>` relèvent explicitement du module Structures. L’annuaire utilise les filtres `q`, `typeId`, `locality`, `take`, `skip`, `sortBy=name|type` et `sortDir=asc|desc`. Total et page partagent un même instantané SQL ; pagination de 1 à 100 lignes et ordre stable par identifiant après le tri demandé. La recherche porte uniquement sur les textes publics. Le filtre de localité réutilise les adresses et lieux déclarés, sans distance calculée.

Les réponses publiques ne comportent que `id, name, typeId, type, address, phone, website, summary, logoUrl`. Les lieux ont le contrat fermé `label, address, zone, area, site`. Le logo `/annuaire/<id>/logo` exige la même publication actuelle, un compte et le module Structures ; ses pixels PNG et son empreinte sont vérifiés. Le navigateur ne reçoit ni binaire dans le JSON, ni e-mail privé, numéro fiscal ou coordonnées d’auteur.

Les sous-listes `/annuaire/<id>/offres` et `/professionnels` sont paginées côté serveur. Elles exigent aussi les droits de Produits ou Professionnels. Les offres restent issues de `V_OffreArticle` et imposent l’entreprise du parent. Les professionnels doivent être publiés et posséder un rattachement explicite actuellement valide ; le propriétaire de leur fiche n’est pas considéré comme un rattachement. Un refus d’accès n’est jamais remplacé par une liste vide.

`/contexte`, `/entreprises`, `/profils` et `/profils/<id>` servent la gestion privée de l’entreprise existante. Un gestionnaire disposant du module Structures peut lire et modifier sa propre fiche sans licence Logistique. L’administrateur global peut consulter le registre global, mais choisit l’entreprise active avant d’enregistrer. Les créations de nouvelles entreprises et les changements de type/état restent dans Administration. Le service commun `entity_documents` conserve motif obligatoire, révision du parent et des localisations, protection du rejeu et audit transactionnel. Les anciens formulaires qui omettent les deux nouveaux champs ne les effacent pas.

Un nouveau contact par Discussions nécessite Structures et Discussions, ainsi qu’une publication actuelle : fiche Structures publiée, ou offre volontairement publiée pour un lecteur disposant aussi du module Produits. Retirer la fiche de Structures ne retire donc pas les offres indépendantes. En l’absence de toute publication autorisée, un contact direct par identifiant est refusé. Les conversations déjà existantes restent consultables par leurs participants autorisés après retrait de publication ; aucun message n’est créé par les lectures de l’annuaire.

Recettes API réellement exécutées : **76 tests réussis** sur la copie privée fraîche `sauverndeko_test_structures_api_fresh_09f53414` : 12 Structures, 10 Publication, 12 Produits, 13 Identité d’entreprise et 29 Professionnels. Elles couvrent notamment 107 fiches paginées, confidentialité, champs longs, retrait, photos/logos, licences, permissions locales/globales, révision, rejeu, affiliations et historique des discussions. Journaux : `.runtime/structures-api-tests/verification.json` et fichiers texte de ce dossier. Le diagnostic `verifier_backend` inclut les nouvelles lectures si leur schéma est installé.

Limites volontaires de cette version : types centraux transversaux, sans nouvelle classification automatique par secteur ; aucun agrément vérifié, horaire garanti, calcul de proximité, paiement ni collecte analytique implicite. La fiche Structures conserve le grain entreprise et ne crée pas arbitrairement une entreprise distincte pour chaque site territorial.
