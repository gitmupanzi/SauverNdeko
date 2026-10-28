# Structure et migrations PostgreSQL SauverNdeko

Les sources canoniques de structure sont alignées sur la base locale au 28 octobre 2026, jusqu’à la migration `20261028_07`. Les sections datées ci-dessous conservent l’historique des évolutions, des sauvegardes et des recettes. Les contrôles métier restent dans les vues, fonctions, contraintes et triggers commentés de PostgreSQL.

## Choisir le fichier adapté

| Fichier | Usage |
|---|---|
| SauverNdeko_Metier_Structure.sql | Structure des huit schémas métier, sans données. Pour une base vide ; les tables natives public sont créées séparément par les migrations Django. |
| SauverNdeko_Structure.sql | Référence complète de structure, y compris les tables natives Django. Sans données ni historique django_migrations ; ce fichier n’est pas un installateur applicatif complet. |
| Dossiers 0 à 7, fichiers Tables et View/views | Extraits canoniques par domaine : tables, séquences, contraintes, index, fonctions, triggers et vues commentées. Le domaine operations ne possède actuellement aucune vue et conserve uniquement son fichier Tables. Les dépendances entre domaines exigent le fichier global pour une installation complète. |
| migrations/20261024_04_coherence_schemas_metier.sql | Évolution contrôlée d’une base existante au socle précédent ; déjà appliquée à la base locale. Aucun DML sur les données métier existantes. |
| migrations/rollback/20261024_04_coherence_schemas_metier.sql | Retour arrière logique testé. Refuse de supprimer analytics si des événements existent et conserve les validations de clés étrangères. Revenir aussi au backend compatible avant de l’utiliser. |
| controles/Verifier_Commentaires_PostgreSQL.sql | Contrôle des commentaires en lecture seule. |
| tests/test_metier_postgresql.py et tests/test_api_postgresql.py | Recettes actuelles vérifiées, exclusivement sur une base dédiée contenant la structure et des données fictives. |

Les exports canoniques ne remplacent pas une sauvegarde de données. Les premières restaurations vérifiées du 24 octobre portaient sur 31 tables métier, 41 tables au total et 48 vues ; ces nombres historiques précèdent les évolutions documentées ci-dessous.

## Base existante

Appliquer uniquement l’évolution nécessaire, avec contrôle des préconditions, sauvegarde adaptée au périmètre, limites de verrouillage et vérification avant/après. Ne pas rejouer les extraits canoniques sur la base courante. Les migrations historiques 01, 02 et 03 gardent leur contenu ; leur réapplication après la version 04 peut rétablir des définitions anciennes.

La migration 04 est transactionnelle et réexécutable. Son retour arrière ne constitue pas une restauration de données. Une sauvegarde de la seule structure précède cette intervention ; aucune nouvelle copie des données privées n’a été créée.

## Nouvelle installation

Utiliser une base vide et les outils PostgreSQL 18 compatibles. Créer d’abord l’extension `pg_trgm` dans `public`. Le fichier métier s’exécute avec psql -X -v ON_ERROR_STOP=1 --dbname NOM_BASE --file SQL/SauverNdeko_Metier_Structure.sql. Il ne charge aucun compte, dictionnaire, organisation, article ni événement. Pour préparer l’installation complète, utiliser un nouveau paquet `preparer_installation` produit depuis ce socle : structure, dictionnaire fermé et manifeste de contrôle, sans données clientes ni préférences personnelles.

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

## Référentiel, destinations et annulation d’inventaire — 26 octobre 2026

Après les migrations du 25 octobre jusqu’à 20261025_13, appliquer dans l’ordre :

1. [20261026_01_precision_referentiel.sql](migrations/20261026_01_precision_referentiel.sql) : transfère la précision et sa date de modification dans T_Generique, adapte les contrôles et la vue de comptage, puis supprime T_UniteStockPrecision avec RESTRICT.
2. [20261026_02_destinations_typees.sql](migrations/20261026_02_destinations_typees.sql) : enrichit V_DestinationLogistique avec les types réels du référentiel à chaque niveau de la hiérarchie.
3. [20261026_03_annulation_inventaire.sql](migrations/20261026_03_annulation_inventaire.sql) : conserve validation et comptages, ajoute l’annulation motivée et ses liens de compensation, protège les documents et lots historiques.

Ces trois migrations sont installées dans SauverNdeko. Ne pas les rejouer. La sauvegarde complète locale .runtime/backups/SauverNdeko-avant-referentiel-annulation-20261026-094221.dump a été vérifiée par empreinte, catalogue et décodage intégral ; cela ne remplace pas un essai de restauration. Les empreintes des 22 tables métier contrôlées sont identiques avant/après, hors nouvelles colonnes de métadonnées NULL. Aucun inventaire réel n’a été annulé pour les essais.

La migration 01 plaçait la précision dans les lignes Unités de referentiel.T_Generique. Cette étape historique reste à conserver dans l’ordre de migration. La cible courante décrite ci-dessous par la migration 10 restitue une politique logistique dédiée, liée aux mêmes unités ; le réglage partagé reste réservé à l’administrateur global et une réduction incompatible avec les quantités historiques est refusée.

Annuler la validation exige les droits de gestion, une entreprise active, la révision du document, un UUID de demande et un motif. L’opération crée les bons inverses par les triggers de stock existants, conserve quantités, lots, prix historiques et devise, et interdit toute suppression des écritures d’origine. Un stock ou lot insuffisant refuse toute la transaction ; rejouer la même demande ne produit aucun mouvement supplémentaire. L’inventaire annulé reste consultable et ne peut pas être revalidé.

Recette reproductible : définir SAUVERNDEKO_TEST_DATABASE_URL vers une base indépendante sauverndeko_test_* déjà migrée, puis exécuter SQL/tests/test_annulation_inventaire.py avec le Python du backend. Le script refuse la base applicative et crée exclusivement des données fictives dans la base dédiée. Résultat : 31 contrôles réussis. Sur SauverNdeko, le diagnostic de 176 routes GET et les lectures ciblées sont passés en lecture seule ; Django et la compilation frontend sont également validés.

## Valorisation, péremption et registre des lots — 26 octobre 2026

Les migrations suivantes sont installées dans SauverNdeko après les trois migrations 20261026_01 à 03. Respecter cet ordre sur une reprise compatible ; ne pas les rejouer sur la base locale déjà mise à jour. Une installation neuve utilise le paquet fermé décrit dans [le guide de livraison](../docs/livraison-logistique.md).

1. [20261026_04_valorisation_cump.sql](migrations/20261026_04_valorisation_cump.sql) : coût moyen permanent PostgreSQL, arrêté motivé/révision de source, coûts d’origine des retours et journal append-only. Les coûts historiques incertains restent inconnus.
2. [20261026_05_peremption_lots.sql](migrations/20261026_05_peremption_lots.sql) : conservation effective par lot, seuils et politique d’entreprise, stock sans lot, dérogations tracées. Le jour métier est Africa/Kinshasa.
3. [20261026_06_performance_numerotation.sql](migrations/20261026_06_performance_numerotation.sql) : normalisation et index GIN ciblés de l’audit pour préserver la non-réutilisation des identités sans scanner tout l’historique à chaque bon.
4. [20261026_07_registre_lots.sql](migrations/20261026_07_registre_lots.sql) : V_RegistreLots et V_RegistreMouvementLot, sources partagées des écrans et exports, propriétaires durables et unités.
5. [20261026_08_corrections_inventaire_non_commerciales.sql](migrations/20261026_08_corrections_inventaire_non_commerciales.sql) : identification des bons correcteurs/compensateurs par FK, protections contre facturation et retours commerciaux dans les deux sens.

La sauvegarde pré-déploiement .runtime/backups/avant-cump-peremption-20261026 a réellement été restaurée et comparée (61 tables, médias privés). Son dump SHA-256 est 7037a1c10e571ff7c592776f5f671e494fa9efbfd7562f3c3d7df5927c4ba91e. Les cinq migrations ont été appliquées dans une seule transaction ; les empreintes des 24 tables source contrôlées sont identiques avant/après, en excluant uniquement les nouvelles colonnes de métadonnées. Aucun coût d’ouverture réel n’a été arbitrairement confirmé : deux restent à compléter.

Recette intégrée sur base privée fraîche : 299 contrôles (45 CUMP, 49 péremption, 65 lots, 31 annulation, 40 protections inventaire, 22 numérotation, 27 accès, 20 rôle runtime). Sur SauverNdeko : 185 routes GET réussies sous connexion effectivement en lecture seule. Les commandes de recette refusent les bases hors sauverndeko_test_*. Les définitions et commentaires sont versionnés ; aucune désactivation des triggers de stock n’est nécessaire.

## Profil documentaire et clôture — 26 octobre 2026

La migration [20261026_09_identite_documentaire.sql](migrations/20261026_09_identite_documentaire.sql) est installée après 01–08. Elle ajoute deux champs facultatifs sur T_Entite (identifiants déclaratifs génériques et mention), la fonction canonique fn_identite_documentaire et la vue V_IdentiteDocumentaire ; le trigger de création des identités les reprend dans les nouveaux documents uniquement. Les instantanés existants et leur protection immuable sont conservés. Aucun identifiant légal ni taux fiscal n’est inventé.

Sauvegarde préalable restaurée : .runtime/backups/avant-identite-documentaire-20261026, dump SHA-256 f24ea851aa6d6252a30c52fddea54fe61ea24d2761ffcfd91807ebe1c3091ef2. La migration atomique a conservé les empreintes des 26 tables source, hors les deux nouvelles colonnes de profil. Ne pas la rejouer sur l’instance locale.

Recettes privées : identité documentaire37 (révisions, rejeux, concurrence, SQL direct et instantanés), chaîne complète112 et diagnostic livraison47. Les nouveaux PDF ont été rendus et inspectés. Les paramètres réels de l’entreprise et la confirmation comptable des coûts restent sous la responsabilité du propriétaire. Voir [le suivi de clôture](../docs/reste-a-faire-logistique.md).


## Politique dédiée de précision du stock — installée le 26 octobre 2026

La migration [20261026_10_precision_stock_table.sql](migrations/20261026_10_precision_stock_table.sql), installée dans SauverNdeko après 01–09, crée `logistique.T_PrecisionStock` avec exactement quatre colonnes : identité technique, `ID_UniteFk`, `DecimalesStock` et `ModifieLe`. La FK pointe vers la même catégorie Unités de T_Generique que les articles. Les lecteurs SQL et backend utilisent la vue commune `V_PrecisionStock`. Les nouvelles unités sans politique conservent zéro décimale implicite.

La reprise conserve les réglages et dates explicites et initialise les huit unités actives à zéro avec une date réelle lorsque le réglage est absent, avant de retirer les deux anciennes colonnes de T_Generique avec RESTRICT. Aucun stock, prix ou document n’est modifié. Les migrations historiques ne sont pas réécrites. La reprise réelle et les quatre colonnes/huit politiques sont vérifiées ; les empreintes des 63 tables source sont identiques hors les deux anciennes colonnes retirées de T_Generique. Sauvegarde vérifiée : `.runtime/backups/avant-precision-stock-20261026-171642`. Les 314 contrôles privés et quatre GET réels en lecture seule sont réussis ; le backend a été relancé sur 5000 et le frontend conservé sur 5174. Voir [la stratégie de reprise et les preuves de recette](documentation/Precision_Stock_20261026.md). Ne pas rejouer cette migration sur la base locale.

## Administration et réglages partagés — installés le 26 octobre 2026

La migration [20261026_11_controles_administration.sql](migrations/20261026_11_controles_administration.sql) est installée dans SauverNdeko. Elle renforce les deux tables existantes de paramètres et correspondances FK : unicité même lorsque le contexte global est NULL, cohérence des portées, protection des paramètres, auteur/date imposés et audit SQL unique par écriture. Un paramètre système éditable conserve la modification de sa valeur. Aucune colonne supplémentaire ni copie des licences, modules ou droits n’est nécessaire : ces informations majeures sont déjà persistées dans `systeme`.

Le complément [20261026_12_commentaires_administration.sql](migrations/20261026_12_commentaires_administration.sql) documente les index implicites recréés et actualise les commentaires des vues d’audit. Il est installé après 11 et ne modifie aucune donnée ni règle.

La sauvegarde `.runtime/backups/avant-controles-admin-20261026-195858` a été vérifiée par empreinte, catalogue et décodage intégral (dump SHA-256 `358305f36d4cfd07643a8e3666cdf384424e28860066bffb66e5f0862b275f28`). Les empreintes des 64 tables sont identiques avant et après la migration ; aucun compte, droit, réglage, stock ou document client n’a été modifié pour les essais. Ne pas rejouer cette migration sur l’instance locale.

Les sources canoniques ont été régénérées depuis cette structure. Elles ont réellement été restaurées dans deux bases isolées : 64 tables/79 vues pour la structure globale ; 54 tables/79 vues pour la structure métier. Cette dernière nécessite l’extension `pg_trgm` dans `public` avant restauration. Ces restaurations de structure ne constituent pas un essai de restauration de la sauvegarde complète avec données et médias.

Recette : 14 contrôles SQL privés, parcours réel API → auteur transactionnel → audit unique, tests de contrat API et onze registres/exports Excel contrôlés en lecture seule sur SauverNdeko. Les recettes ne visent que des bases explicitement nommées `sauverndeko_test_*`. Le diagnostic `verifier_backend` inclut aussi la synthèse et les registres d’administration. Le frontend `/admin` réutilise les tableaux, filtres, fenêtres et thèmes de Logistique ; la compatibilité du module territorial reste conservée.


## Socle logistique et préférences — 28 octobre 2026

Les quatre migrations du 28 octobre sont installées dans SauverNdeko après sauvegarde et recette privée :

- `20261028_01_stock_initial_documents.sql` : stock initial documenté par un bon d’entrée et sa ligne, origine durable, création idempotente, nouveaux préfixes BE/BS et reprise documentaire des mouvements initiaux orphelins. Les quatre mouvements historiques concernés conservent identifiants, quantités, prix, dates et lots ; aucun code historique n’est renuméroté.
- `20261028_02_preferences_tableaux.sql` : catalogues de colonnes communs et préférences personnelles indépendantes pour le tableau et l’export dans `referentiel`, plus quantités des bons ventilées par unité. Les choix sont isolés par utilisateur, entreprise et interface.
- `20261028_03_tracabilite_logistique.sql` : auteurs et dates techniques des règlements, contrôles financiers lors d’une modification, unicité des codes Article par entreprise et intégrité SHA-256 des justificatifs binaires.
- `20261028_04_commentaires_socle.sql` : commentaires des treize contraintes NOT NULL implicites des nouvelles tables, sans modification de données.

Les deux instantanés globaux et les extraits Référentiel/Logistique ont été régénérés à partir du catalogue installé. Leur restauration sur deux bases privées vides a vérifié **66 tables** pour la structure complète, **56 tables** pour le métier, **80 vues** et **123 triggers**, sans aucune donnée. Les définitions, relations, contraintes, index, routines, séquences et commentaires ont été comparés au catalogue source ; les commentaires des contraintes associées aux triggers sont conservés explicitement dans les sources, en complément de pg_dump.

Une nouvelle installation doit aussi charger le dictionnaire fermé du paquet produit par `preparer_installation`. Il inclut maintenant `referentiel.T_InterfaceTableau` avec les vingt catalogues de référence. Les préférences personnelles `T_PreferenceTableau`, comptes, entreprises, articles et documents clients ne sont jamais repris dans ce paquet. La restauration du paquet vierge a confirmé cette séparation.

Voir [stock initial et numérotation](documentation/Stock_Initial_Documents_20261028.md), [préférences de tableaux et exports](documentation/Preferences_Tableaux_Exports_20261028.md) et les recettes `tests/test_stock_initial_documents.py`, `tests/test_preferences_tableaux.py` et `tests/test_tracabilite_logistique.py`. Les recettes d’écriture refusent une base ne commençant pas par `sauverndeko_test_`.

## Bons de commande sans mouvement — 28 octobre 2026

La migration [20261028_05_bons_commande.sql](migrations/20261028_05_bons_commande.sql), installée après les migrations précédentes, ajoute **Bon de commande**, code `CMD`, à la catégorie partagée **Type de commande**. Les nouveaux documents reçoivent `BE-ID` pour une entrée effective, `BS-ID` pour une sortie effective et `CMD-ID` pour une commande préparatoire. Cette migration05 avait conservé les codes antérieurs ; leur harmonisation ultérieure relève de06 ci-dessous.

`fn_nature_bon` et `fn_effet_type_bon` classent le type depuis le référentiel : un CMD explicite a un effet zéro ; un type inconnu retourne NULL et reste refusé. Les lignes CMD conservent quantités et prix convenus, sans mouvement, réservation, lot ou valorisation CUMP. La facturation, la restitution et la livraison physique sont interdites pour CMD, y compris par écriture SQL directe. Le type CMD ne peut pas être converti en BE/BS ; les opérations réelles ont leurs propres documents. Les trois vues de bons/lignes exposent `NatureBon` et le suivi indique « Sans facturation » sans créer de dette.

L’application réelle a conservé les 65 autres tables et les références historiques ; seule la nouvelle valeur CMD a été ajoutée au dictionnaire. La migration refuse son rejeu. Une nouvelle installation utilise les sources canoniques et le dictionnaire fermé produit par `preparer_installation`, sans rejouer les migrations sur ce socle déjà installé.

Les six sources Référentiel/Logistique et globales ont été régénérées. Deux restaurations privées ont comparé les définitions et commentaires au catalogue installé : **66 tables, 80 vues, 125 triggers** pour le global ; **56 tables, 80 vues, 125 triggers** pour le métier, avec zéro ligne de données. `NatureBon`, les trois fonctions de classification et les gardes supplémentaires sont commentés.

Recettes privées : 51 contrôles SQL CMD, 10 tests API, puis 112 contrôles de chaîne logistique, 31 d’annulation d’inventaire et 45 de CUMP. La recette stock initial passe aussi sur le socle05 avec 35 contrôles ; elle conserve conditionnellement l’attente historique01 lorsque seule cette migration est installée. La fixture de précision de l’inventaire utilise désormais un BE de 0,125 plutôt qu’une modification directe du stock courant. Voir [le contrat des bons](../docs/bons-entree-sortie-commande.md), `tests/test_bons_commande_postgresql.py` et `tests/test_bons_commande_api.py`.

## Harmonisation des codes historiques — 28 octobre 2026

Sur demande explicite du propriétaire, la migration [20261028_06_nomenclature_bons_historiques.sql](migrations/20261028_06_nomenclature_bons_historiques.sql) a aussi harmonisé les anciens bons : **17 codes modifiés**, quatre déjà conformes conservés. Chaque code est calculé depuis le même identifiant et le type réel du bon. Les bons n’ont pas changé d’identité, de type, de quantité, de montant ou d’entreprise.

`T_BonCodeHistorique` conserve le code antérieur exact, le nouveau code, l’entreprise, la date réelle, le motif, la migration et l’utilisateur PostgreSQL. Ce journal fermé refuse les écritures applicatives et ne possède aucune FK de suppression vers le bon, afin de conserver la correspondance après une suppression autorisée. Aucune colonne n’est ajoutée à `T_Commande` : les révisions et contenus idempotents existants conservent leur structure. Les vues `V_Commande`, `V_CommandeDetail` et `V_CommandeOverview` exposent `AncienCodeCmd` et `RenumeroteLe` par jointure sur l’identifiant.

Les sept fonctions de garde concernées ont été adaptées uniquement dans la transaction de reprise, pour autoriser exactement la modification de `CodeCmd` prévue par le mapping temporaire. Elles ont ensuite été intégralement restaurées ; aucun trigger n’a été désactivé et aucun contournement permanent n’est laissé. Les **64 autres tables antérieures** sont inchangées. Les deux catalogues Bons de stock/Lignes gagnent seulement deux possibilités facultatives, sans déplacer les définitions existantes ni modifier les préférences personnelles. Ces champs sont masqués dans le tableau et exclus de l’export par défaut.

Les factures, leurs numéros et lignes, les règlements, les identités documentaires, les justificatifs, les retours, les mouvements, la valorisation et les audits antérieurs sont conservés. `fn_code_bon_a_date` restitue l’ancienne référence pour un document émis avant ou au moment de la reprise, ainsi que pour une date historique absente ; un document émis ensuite utilise le code actuel. Le service vérifie d’abord l’autorisation sur le parent et son entreprise.

La recette privée de reprise vérifie **52 contrôles spécifiques**, avec préparation par 112 contrôles de chaîne complète et 31 d’inventaires. Elle couvre notamment bons facturés/clôturés, restitutions, stocks initiaux et inventaires protégés ; aucune écriture fictive ne vise SauverNdeko. Voir `tests/test_nomenclature_bons.py` et la recette API/PDF associée.

Les six sources canoniques ont été régénérées après cette application. Leurs deux restaurations privées conservent les définitions et commentaires du catalogue installé : **67 tables, 80 vues, 126 triggers** pour la structure globale ; **57 tables, 80 vues, 126 triggers** pour le métier. Les restaurations restent sans données. Une nouvelle installation produit un nouveau paquet avec le dictionnaire fermé actuel ; les journaux historiques, comptes, entreprises et documents ne sont jamais repris depuis l’instance source.

## Identité courante et présentation des PDF — 28 octobre 2026

La migration [20261028_07_identite_documents_entreprise.sql](migrations/20261028_07_identite_documents_entreprise.sql) est installée après sauvegarde et recette privée. Elle ajoute huit champs dans `systeme.T_Entite` : site web, téléphone secondaire facultatif, deux options de présentation activées par défaut et quatre champs cohérents de logo PNG privé (octets, MIME, SHA-256 et date). Sept contraintes nouvelles, y compris les deux NOT NULL, sont commentées. Les anciennes colonnes des entreprises et les **66 autres tables** restent inchangées ; aucun instantané, montant, audit, stock ou document historique n’est réécrit.

`V_IdentiteDocumentaire` et `fn_identite_documentaire` exposent le profil courant avec `HasLogo` et les seules métadonnées de l’image. Les octets restent dans `T_Entite` et les routes binaires autorisées ; le nettoyage d’audit les retire récursivement. Chaque PDF généré ou régénéré utilise l’identité actuelle de son entreprise. Les tiers, montants, références et instantanés historiques restent conservés, comme les octets des PDF archivés. Les deux réglages persistés sont appliqués directement au téléchargement : le nom reste visible sans en-tête ; un pied désactivé est entièrement retiré, pagination comprise.

Les **huit sources canoniques** ont été régénérées : deux structures globales et les extraits Tables/Views de Référentiel, Logistique et Système. Deux restaurations privées vides ont confirmé les définitions et commentaires : **67 tables, 80 vues, 126 triggers et 149 routines** pour le global ; **57 tables, 80 vues, 126 triggers et 118 routines** pour le métier. Les contrôles ciblés vérifient les seize commentaires des nouvelles colonnes de table/vue, les sept contraintes, les options true et l’absence de binaire en vue/JSON. Les valeurs CRLF/LF des contraintes sont écrites avec la notation SQL échappée explicite, afin que la conversion des fins de ligne de Git sur Windows n’en change pas le sens.

Recette finale sur des fixtures privées : **57 contrôles SQL**, **13 tests API de profil**, **312 contrôles API/PDF** sur sept documents et les quatre combinaisons de réglages, puis **189 contrôles de mise en page** et **48 pages rendues inspectées**. Voir [le contrat et les preuves](documentation/Identite_Documents_Entreprise_20261028.md), [le guide utilisateur](../docs/identite-entreprise-pdf.md) et `tests/test_identite_documents_entreprise_postgresql.py`. Une installation neuve utilise le socle canonique actuel et son dictionnaire fermé ; ne pas rejouer07 sur une base qui le possède déjà.
