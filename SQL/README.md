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

## Devises logistiques — 25 octobre 2026

La migration `migrations/20261025_04_devises_logistique.sql` est installée dans **SauverNdeko**, après sauvegarde complète `SauverNdeko_avant_devises_20261025_113840.dump` vérifiée par SHA-256 et lecture de son catalogue. Cette vérification ne constitue pas une restauration complète de la sauvegarde.

Le propriétaire a confirmé le rattachement de tous les montants existants à USD : un article, quatre bons, cinq mouvements, aucune écriture de règlement. Les empreintes des cinq tables Article, Commande, CommandeDetail, Mouvement et Règlements sont identiques avant/après, hors nouvelle référence de devise. Prix, quantités, dates et autres valeurs sont conservés. Le défaut USD des créations est résolu depuis le référentiel actif, sans identifiant numérique fixe. Les codes EUR/EURO sont normalisés à la lecture ; aucune conversion ni taux de change n’est créé.

Quatre colonnes `ID_DeviseFk` et leurs FK protègent le catalogue, les bons/factures et les instantanés monétaires des mouvements/règlements. Les vues existantes sont étendues sans modification des colonnes historiques ; `V_Reglements` et `V_ConsoMensuelleDevise` complètent les lectures. La consommation physique reste au grain article/mois et expose les montants séparément par devise. Les nouveaux objets/colonnes/fonctions/triggers/contraintes sont commentés. Les références utilisées et devises des documents avec historique sont protégées ; les prix de ligne sont exprimés dans la devise du bon.

Installation neuve : appliquer cette migration après les migrations 01, 02 et 03 du 25 octobre. **Ne pas la rejouer** sur la base locale : elle refuse un catalogue déjà enrichi. Un retour arrière après usage multidevise exige une restauration contrôlée ; supprimer les colonnes ferait perdre leur signification aux montants.

Recette : 27 scénarios PostgreSQL sur structure réelle restaurée dans un cluster indépendant sans données clients, 40 contrôles backend isolés, 26 contrôles monétaires frontend et vérifications réelles GET/Excel en lecture seule. Le cluster de recette est arrêté et supprimé. Ces contrôles ne certifient ni une fonction de change ni une comptabilité multidevise complète.


## Retours physiques et factures — 25 octobre 2026

Les migrations 20261025_06_retours_physiques.sql puis 20261025_07_factures_snapshots.sql sont installées dans SauverNdeko, dans une transaction commune. La sauvegarde complète locale sauverndeko_avant_restitutions_20261025T151736.dump a été vérifiée par SHA-256, lecture du catalogue et décodage intégral ; cela ne constitue pas un essai complet de restauration. Les empreintes des sept tables métier contrôlées sont identiques avant/après. Aucun retour ni aucune facture fictive n’a été créé dans la base client.

06 ajoute un registre immuable de restitutions partielles ou complètes, plusieurs événements par bon, avec budgets par article/lot et fraction historique sans lot. Chaque événement possède un bon d’entrée compensateur ; les triggers existants restent seuls responsables du stock. L’origine et les contre-documents conservent leur historique et le PU réellement sorti.

07 ajoute l’instantané de facture : quantités nettes après retours déjà enregistrés, lignes et numéro conservés après émission. Les retours ultérieurs signalent un avoir à établir sans diminuer la facture ni rembourser implicitement. MontantFacture est distinct de la valeur du bon d’origine. Les factures antérieures sans instantané restent consultables et requièrent une reprise contrôlée pour modification. L’émission d’avoirs et le remboursement restent des parcours distincts à construire.

Recette indépendante : 62 contrôles PostgreSQL/API de composition/restitution et 43 scénarios PostgreSQL de facture, avec données fictives sur un cluster séparé contenant uniquement la structure. Vérifications supplémentaires des gardes et formulaires hors base client. Les nouveaux objets, colonnes et protections sont commentés. Ces migrations ne sont pas réexécutables : vérifier les préconditions et leur présence avant intervention. Aucun retour arrière destructeur automatique n’est fourni après utilisation.

## Numérotation courte des documents — 25 octobre 2026

La migration [20261025_08_numerotation_documents.sql](migrations/20261025_08_numerotation_documents.sql) est installée dans **SauverNdeko**. Elle a renommé les sept bons présents au moment de l’application, y compris le bon dont le code était absent. Aucun instantané de facture, règlement ni retour n’existait alors dans la base. Les nouvelles références sont `cmd-ID_Commande` pour les bons et `fac-ID_Commande` pour leur facture, sans zéros ajoutés. La référence de facture reste absente avant son émission.

Les fonctions PostgreSQL sont la source d’autorité : `fn_reserver_identite_commande()` réserve l’identité existante et retourne le code du bon ; `fn_code_commande(id)` produit `cmd-id` et `fn_code_facture(idBon)` produit `fac-idBon` sans réserver une seconde identité. Les triggers attribuent et protègent les codes, puis tracent leur première attribution dans l’audit existant, même pour une création SQL directe. Les identités déjà utilisées dans les documents ou l’audit ne sont pas réutilisées. L’API conserve aussi ses contrôles d’immutabilité et de rejeu.

La renumérotation conserve les liens par identifiant et met à jour ensemble les numéros des instantanés, leur miroir et les références des règlements lorsqu’ils existent. La correspondance ancien/nouveau est ajoutée à `T_Audit_Log` avec la version `20261025_08` ; les audits antérieurs et leurs empreintes de requête restent intacts. Deux phases sous verrous traitent les collisions entre anciens codes ; les cinq fonctions de protection et la différabilité de la FK sont restaurées avant validation. Aucun mécanisme de contournement de session n’est ajouté.

Les empreintes métier avant/après sont identiques hors codes et référence de facture des règlements. Prix, montants, dates, stocks, mouvements, lots et liens de restitution restent inchangés ; la séquence des bons n’a pas été consommée par la migration. La sauvegarde complète locale `sauverndeko_avant_numerotation_20261025T160644.dump` a été vérifiée par SHA-256 (`8ab543f38b8926c2fe8c2cef2effc6c7086519fa3ea826c4d99838a6eea6c981`), lecture du catalogue et décodage intégral. Ces vérifications ne constituent pas un essai de restauration.

Recette sur le cluster privé sans données clients : **50 contrôles PostgreSQL** — 21 contrôles SQL et 29 contrôles de services — ainsi que **99 contrôles isolés** du backend. Les cas couvrent notamment collisions, factures clôturées ou payées, références des règlements, attribution SQL directe, non-réutilisation après suppression, immutabilité et six rejeux de demandes antérieures sans nouvelle allocation. Aucune écriture fictive n’a été effectuée dans la base client.

Cette migration n’est **pas réexécutable** : elle contrôle les définitions attendues et refuse une numérotation déjà installée. Sur une nouvelle installation, respecter l’ordre des migrations et les préconditions ; sur la base locale, conserver ce fichier comme historique. Aucun retour arrière destructeur automatique n’est fourni.
