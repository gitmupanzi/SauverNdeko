# Structure et migrations PostgreSQL SauverNdeko

Les schémas métier sont alignés sur la base locale vérifiée le 24 octobre 2026. La version courante inclut la migration 20261024_04 : 31 tables métier, 48 vues, contrôles de stock et de licences, vues géographiques corrigées, socle analytics et commentaires PostgreSQL.

## Choisir le fichier adapté

| Fichier | Usage |
|---|---|
| SauverNdeko_Metier_Structure.sql | Structure des huit schémas métier, sans données. Pour une base vide ; les tables natives public sont créées séparément par les migrations Django. |
| SauverNdeko_Structure.sql | Référence complète de structure : 41 tables dont dix natives Django. Sans données ni historique django_migrations ; ce fichier n’est pas un installateur applicatif complet. |
| Dossiers 0 à 7, fichiers Tables et View/views | Extraits canoniques par domaine : tables, séquences, contraintes, index, fonctions, triggers et vues commentées. Le domaine operations ne possède actuellement aucune vue et conserve uniquement son fichier Tables. Les dépendances entre domaines exigent le fichier global pour une installation complète. |
| migrations/20261024_04_coherence_schemas_metier.sql | Évolution contrôlée d’une base existante au socle précédent ; déjà appliquée à la base locale. Aucun DML sur les données métier existantes. |
| migrations/rollback/20261024_04_coherence_schemas_metier.sql | Retour arrière logique testé. Refuse de supprimer analytics si des événements existent et conserve les validations de clés étrangères. Revenir aussi au backend compatible avant de l’utiliser. |
| controles/Verifier_Commentaires_PostgreSQL.sql | Contrôle des commentaires en lecture seule. |
| tests/test_metier_postgresql.py et tests/test_api_postgresql.py | Recettes actuelles vérifiées, exclusivement sur une base dédiée contenant la structure et des données fictives. |

Les exports canoniques ne remplacent pas une sauvegarde de données. Les restaurations de structure complète et métier ont été vérifiées dans deux bases vides, ensuite supprimées. Le fichier métier restaure 31 tables et 48 vues ; le fichier complet restaure 41 tables et 48 vues.

## Base existante

Appliquer uniquement l’évolution nécessaire, avec contrôle des préconditions, sauvegarde adaptée au périmètre, limites de verrouillage et vérification avant/après. Ne pas rejouer les extraits canoniques sur la base courante. Les migrations historiques 01, 02 et 03 gardent leur contenu ; leur réapplication après la version 04 peut rétablir des définitions anciennes.

La migration 04 est transactionnelle et réexécutable. Son retour arrière ne constitue pas une restauration de données. Une sauvegarde de la seule structure précède cette intervention ; aucune nouvelle copie des données privées n’a été créée.

## Nouvelle installation

Utiliser une base vide et les outils PostgreSQL 18 compatibles. Le fichier métier s’exécute avec psql -X -v ON_ERROR_STOP=1 --dbname NOM_BASE --file SQL/SauverNdeko_Metier_Structure.sql. Il ne charge aucun compte, dictionnaire, organisation, article ni événement.

Configurer ensuite le backend vers cette base et installer le socle natif public avec manage.py migrate, dans une fenêtre d’écriture explicitement choisie. Ne pas charger les tables natives vides du fichier complet avant cette migration : elles seraient présentes sans historique django_migrations. Les référentiels et paramètres nécessaires à l’exploitation restent à initialiser selon l’organisation ; aucune donnée client n’est incluse dans ces fichiers.

## Recettes sur données fictives

Préparer une base locale nommée sauverndeko_test_* avec la structure métier et les contraintes à jour. Définir SAUVERNDEKO_TEST_DATABASE_URL vers cette base, distincte de la base applicative. Les scripts n’utilisent jamais DATABASE_URL comme repli.

Depuis la racine du projet :

~~~powershell
.\backend\.venv\Scripts\python.exe .\SQL\tests\test_metier_postgresql.py
.\backend\.venv\Scripts\python.exe .\SQL\tests\test_api_postgresql.py
~~~

Le premier script couvre 36 scénarios PostgreSQL, dont écritures et concurrence. Le second vérifie une connexion par mot de passe sur compte fictif et 19 échanges Django : créations, conflits, stock, licences, discussions et accès analytics. Son mode d’écriture est limité au processus de recette et à la base dont le nom a été vérifié ; la configuration applicative reste en lecture seule.

Les recettes Python sont conservées parce qu’elles vérifient les règles de stock, les transactions, les droits et la concurrence. Leur base dédiée est facultative et n’est jamais utilisée par le démarrage de l’application, qui vise SauverNdeko.

## Nettoyage des sources

Treize fichiers SQL ont été retirés le 24 octobre 2026 : huit anciens exemples de test, l’alignement logistique antérieur aux migrations versionnées, trois scripts géographiques ponctuels remplacés par les contraintes canoniques et la migration 04, et un fichier de vues operations sans définition. Le cache Python de recette a également été supprimé. Aucun de ces scripts n’a été exécuté pendant ce nettoyage.

Les fichiers conservés ont un rôle distinct :

- migrations/ et migrations/rollback/ : historique des évolutions et retours arrière contrôlés ; ne pas supprimer les anciennes versions au seul motif qu’elles sont déjà appliquées.
- controles/ et tests/ : contrôle documentaire en lecture seule et recettes métier sur base isolée.
- documentation/ : décisions et résultats des interventions.
- Dossiers de domaine : sources canoniques, scénarios métier et illustrations de conception. Les images et diagrammes restent des références historiques, sans garantie de refléter la version courante.
- 1. Schema systeme/Systeme_FK_Correspondance_Seed_Defaults.sql : initialisation explicite des correspondances de configuration. Ce fichier remplace les correspondances globales des types qu’il gère et suppose les catégories référentielles attendues ; ne pas le rejouer sur une configuration personnalisée sans examen.
- SauverNdeko.backup : sauvegarde existante conservée. Son contenu et sa restaurabilité n’ont pas été vérifiés pendant ce nettoyage ; elle ne remplace pas les exports de structure actuels.

Le nettoyage porte uniquement sur les fichiers du projet : la base PostgreSQL et ses données n’ont pas été modifiées.

Voir le [bilan de l’audit et des corrections](documentation/Audit_Metier_20261024.md) pour les résultats et les limites.

## Évolutions du 25 octobre 2026

Les exports canoniques ci-dessus restent des instantanés du socle du 24 octobre. Sur une installation issue de ces fichiers, appliquer ensuite, dans cet ordre :

1. migrations/20261025_01_dossiers_suivi.sql : trois tables, trois vues et les contrôles de classement dans logistique.
2. migrations/20261025_02_modules_entites.sql : trois tables, trois vues, une fonction et deux triggers dans systeme pour les applications des licences d’Entité.
3. migrations/20261025_03_articles_poids_lots.sql : poids unitaire, unité de masse, InformationArticle, deux tables et deux vues de ventilation par lot, contrôles et commentaires ; extension de V_Article sans changement des colonnes historiques.

Ces migrations sont installées sur la base locale SauverNdeko. Ne pas les rejouer sur cette base. La migration 02 conserve les licences, leurs dates, les utilisateurs et les privilèges ; elle reprend seulement les six applications optionnelles sur chaque licence existante avec Origine=reprise. L’accès effectif reste conditionné à l’Entité active, à la validité de la licence et au rôle.

Les objets et toutes leurs colonnes métier sont commentés par COMMENT ON. Les vues V_LicenceModule et V_EntiteModuleActif évaluent la période à la lecture ; aucun traitement planifié de renouvellement ou de paiement n’est ajouté. Le socle est déclaré dans T_ModuleApplication et les restrictions dans T_RoleModule. Les activations sont gérées par le service de plateforme, pas par le CRUD générique.

Le rollback de la migration 02 est séparé dans migrations/rollback/ et refuse la suppression si des réglages ont été modifiés après la reprise initiale. Revenir au backend compatible avant tout retour arrière. La sauvegarde complète SauverNdeko_avant_modules_20261025_032147.dump a été contrôlée par empreinte et lecture de son catalogue ; elle n’est pas une preuve de restauration complète.

Les anciens scripts de recette sur base dédiée décrivent le socle historique. Ils ne constituent pas la recette de la politique de licences ajoutée le 25 octobre. Pour ce lot, la base applicative a été interrogée en lecture seule ; les changements de configuration et d’interface ont été vérifiés en simulation sans créer de base de test ni de données métier fictives dans SauverNdeko.

## Articles et lots — 25 octobre 2026

La migration 20261025_03 est installée dans SauverNdeko après sauvegarde complète vérifiée par empreinte et catalogue : SauverNdeko_avant_articles_lots_20261025_040824.dump. Les empreintes des six tables existantes contrôlées sont identiques avant/après, en excluant seulement les trois nouvelles colonnes NULL de T_Article. Aucun lot historique n’est inventé.

Les numéros reçus sont identifiés par article, puis ventilés sur les mouvements déjà créés par le stock. Une sortie ne peut pas rendre un lot négatif. Les données anciennes sans numéro restent sans lot. La migration n’est pas réexécutable : contrôler les préconditions plutôt que la rejouer. Les colonnes ajoutées sont conservées en fin de table pour préserver les dépendances ; leur ordre de présentation est défini dans le formulaire. Aucun retour arrière destructeur automatique n’est fourni.

La recette tests/test_articles_postgresql.py couvre le CRUD Article, les révisions concurrentes, le poids, les informations, les photos privées et les lots : création, réception, sortie, correction, annulation, quantités incorrectes et concurrence sur un lot épuisé. Définir SAUVERNDEKO_TEST_DATABASE_URL vers une base dédiée à jour, puis exécuter avec le Python du backend. Les photos fictives sont écrites dans un répertoire temporaire. Ne jamais viser la base applicative pour ces écritures.

Recette de livraison : 36 scénarios PostgreSQL, 19 échanges API et 70 assertions Articles/lots/photos passent sur un cluster PostgreSQL indépendant sans données clients. Le diagnostic réel verifier_backend passe sur 146 routes GET en lecture seule. Ces résultats ne constituent pas une validation de tous les modules ERP ni une preuve de restauration complète de la sauvegarde.

Les images de production sont des fichiers privés dans backend/media/Article (ou ARTICLE_MEDIA_ROOT/Article). Elles ne sont pas contenues dans pg_dump : sauvegarder et restaurer ce dossier avec la base. Les anciens fichiers remplacés restent conservés ; leur purge n’est pas automatique.
