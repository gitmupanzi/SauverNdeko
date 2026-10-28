# Livraison et exploitation — Logistique

État vérifié le 26 octobre 2026. Les commandes ci-dessous utilisent le Python du backend et les outils PostgreSQL 18. Les sauvegardes, paquets et restaurations sont privés ; `.runtime`, les médias et les fichiers `.env` restent exclus de Git.

## COUSP et les licences

COUSP a été créée comme Entité **11**, avec la licence **3**, active du **26/10/2026 à 09:25:19.021762** au **26/10/2031 à 09:25:19.021762**, selon les horodatages contractuels PostgreSQL. Les neuf applications du catalogue sont disponibles : Catalogue, Produits, Structures, Professionnels, Informations santé, Discussions, Logistique, Organisation territoriale et Administration. Les permissions de chaque rôle continuent de s’appliquer. Aucun compte de test n’a été créé dans la base applicative et les données de l’École Pilote Test n’ont pas été déplacées.

Le nom seul a été fourni : l’adresse, le téléphone, l’e-mail et le type de structure de COUSP restent à compléter avec des informations réelles avant l’émission de documents clients. Aucun taux fiscal ou numéro légal n’a été inventé.

Le provisionnement est reproductible :

```powershell
.\backend\.venv\Scripts\python.exe backend/manage.py provisionner_entite --nom COUSP --actor 15 --ans 5 --backup-dir .runtime/backups/avant-provisionnement --pg-bin 'C:\Program Files\PostgreSQL\18\bin' --apply
```

Sans `--apply`, la commande présente son plan. Une création requiert un compte de plateforme et une sauvegarde neuve vérifiée. Le rejeu de COUSP retourne la même Entité, la même licence et les mêmes dates : il ne prolonge pas sa durée. L’activation utilise le catalogue et le statut actif du référentiel ; aucun identifiant de statut n’est figé dans le code.

## Sauvegarder et restaurer

```powershell
.\backend\.venv\Scripts\python.exe backend/manage.py sauvegarder_instance --destination .runtime/backups/instance-AAAAMMJJ-HHMM --pg-bin 'C:\Program Files\PostgreSQL\18\bin'
```

La commande partage un instantané SQL cohérent entre le contrôle et le dump, protège la structure pendant la copie et exporte PostgreSQL en format personnalisé, contrôle son catalogue et son décodage intégral, archive le répertoire privé configuré par `SAUVERNDEKO_MEDIA_ROOT`, puis écrit les empreintes des tables et fichiers. Les écritures courantes peuvent continuer ; une fenêtre sans changement de structure ni purge des médias reste nécessaire. Les fichiers historiques des photos sont conservés et leurs empreintes sont vérifiées pendant la copie. Le compte de sauvegarde doit pouvoir lire toutes les données et les outils PostgreSQL doivent être compatibles. Les justificatifs stockés dans `T_PieceJustificative.Contenu` sont compris dans le dump ; les photos privées sur disque suivent l’archive média. Une politique de stockage chiffré hors du serveur et de rétention doit être organisée par l’exploitant.

Pour une restauration de contrôle, définir **uniquement dans le processus** `SAUVERNDEKO_RESTORE_TEST_DATABASE_URL` vers une base locale **neuve** nommée `sauverndeko_test_*` :

```powershell
$env:SAUVERNDEKO_RESTORE_TEST_DATABASE_URL='postgresql://COMPTE@127.0.0.1:PORT/sauverndeko_test_restauration'
.\backend\.venv\Scripts\python.exe backend/manage.py restaurer_recette --source .runtime/backups/instance-AAAAMMJJ-HHMM --media-destination .runtime/restorations/photos-restaurees --pg-bin 'C:\Program Files\PostgreSQL\18\bin'
```

La commande refuse toute base existante, toute destination distante et tout nom applicatif. Elle ne supprime rien. Elle restaure en transaction, compare les empreintes de toutes les tables dans le même fuseau UTC, extrait seulement les fichiers sûrs de l’archive et vérifie leurs empreintes. Le rapport est écrit à côté des médias restaurés. La recette de remise en service d’une base de production doit utiliser une procédure d’exploitation contrôlée, avec arrêt des écritures et sélection explicite de la sauvegarde ; la commande de recette ne constitue pas un bouton de restauration de production.

Preuve obtenue : restauration de `avant-cousp-20261026-2` vers `sauverndeko_test_restore_delivery_20261026_2`, **61 tables identiques**. Aucun fichier média n’était présent dans ce stockage au moment de la sauvegarde ; les pièces binaires présentes en base sont vérifiées avec leur table. Aucun fichier photo réel n’a donc été restauré pendant cette recette. La sauvegarde complète après création de COUSP (`avant-cump-peremption-20261026`) a aussi été restaurée dans `sauverndeko_test_restore_pre_release_20261026` : **61 tables identiques**, médias privés absents et vérifiés. Un second aller-retour sur une base privée contenant uniquement des données de recette a vérifié **61 tables et un fichier média fictif** : la sauvegarde par instantané fonctionne aussi avec la connexion applicative en lecture seule, puis la restauration retrouve exactement le fichier et son empreinte.

## Clôture documentaire 09 — version courante

La migration 20261026_09 est installée dans SauverNdeko. Elle ajoute le profil documentaire facultatif de l’entreprise et le fige sur les nouveaux documents ; les instantanés déjà présents sont conservés. La sauvegarde avant cette évolution est `.runtime/backups/avant-identite-documentaire-20261026`, réellement restaurée en recette avec **63 tables identiques**.

Le paquet courant `.runtime/releases/socle-logistique-20261026-final09` a été exporté après ce déploiement et installé dans la base entièrement vide `sauverndeko_test_install_final09_20261026`. Avant le premier compte fictif : cinq tables racines vides et neuf modules présents. Après le bootstrap privé, **109 contrôles de chaîne commerciale**, **37 contrôles d’identité documentaire** et **20 contrôles du rôle runtime** ont réussi. Le diagnostic applicatif a ensuite confirmé **187 routes GET sur 187**, avec `transaction_read_only=on` et aucune écriture. Les données fictives restent uniquement dans cette base privée.

La nouvelle sauvegarde complète `.runtime/backups/logistique-final09-20261026` a été restaurée dans `sauverndeko_test_restore_final09_20261026` : **63 tables identiques**, archive média contrôlée et vide. Rapport : `.runtime/restorations/logistique-final09-20261026-restoration.json`. Les paquets et sauvegardes précédents ont été conservés.

| Fichier de la clôture 09 | SHA-256 |
|---|---|
| Sauvegarde `database.dump` | `55bb8e1ba7fe834cc24abd9087aa7c3d405cfd30f7ad333e1c02c34da19aaa13` |
| Archive `media.tar.gz` | `49c112651e29163a6fef169715a38d71271c6d38bab31163a7a0dcb31f888947` |
| Paquet `structure.sql` | `8c74a046efc70b78087e69080eec57831ca8f95ec086fd446298d81409fb2290` |
| Paquet `references.sql` | `37e77df5e1650974a001d8856156019979cbb4b45c37362b02259b038a566401` |

## Socle 01 à 08 — preuve conservée

Après installation réelle des migrations 20261026_04 à 08 dans SauverNdeko, la sauvegarde `.runtime/backups/logistique-final-20261026` a été restaurée vers la base privée neuve `sauverndeko_test_restore_final_20261026` : **63 tables identiques**, archive média contrôlée et vide. Les deux tables supplémentaires appartiennent au nouveau socle ; les documents présents en base sont compris dans leurs empreintes. Le rapport est conservé dans `.runtime/restorations/logistique-final-20261026-restoration.json`.

Empreintes SHA-256 de cette livraison privée :

| Fichier | SHA-256 |
|---|---|
| Sauvegarde `database.dump` | `77b470440faa6bea694877072ffdb296d9f3bfb873f9f56c3eb549471e5785c3` |
| Archive `media.tar.gz` | `481d5afa5c9fdb21aab1afc311e572ada823160bf85a5c198fdc61663844b39d` |
| Paquet `structure.sql` | `521ef7f4d4f32d8d2837bc8772415794d687edb29df5d75929419a628fcff862` |
| Paquet `references.sql` | `8641dcd54aab660cc58959a43b8281980b3a3ae70fed3739af5427570c7de522` |

Le paquet vierge et la sauvegarde complète ont des usages différents : le premier fournit un socle sans identité ni données client ; la seconde conserve l’instance existante. Les preuves restent locales et privées, exclues du dépôt.

## Installation vierge

Le dossier SQL historique décrit le socle du 24 octobre ; ses extraits ne doivent pas être rejoués sur une version courante. Pour fournir une installation neuve à la version effectivement installée, préparer un paquet depuis l’instance source validée :

```powershell
.\backend\.venv\Scripts\python.exe backend/manage.py preparer_installation --destination .runtime/releases/socle-AAAAMMJJ --pg-bin 'C:\Program Files\PostgreSQL\18\bin'
```

Le paquet contient uniquement la structure des huit schémas métier, les deux tables du dictionnaire générique, le catalogue des applications et un manifeste d’empreintes. Il ne contient ni utilisateurs, ni entreprises, ni coordonnées clients, ni articles, ni documents, ni événements. La liste `migrationsInCode` inventorie les fichiers du code ; elle ne prétend pas attester à elle seule leur installation dans la base source. Préparer le paquet après la validation du déploiement SQL et fournir avec lui le rapport de version installé.

Sur une **base PostgreSQL entièrement vide**, configurer le fichier privé du backend pour viser cette base puis, dans la fenêtre d’installation, définir `SAUVERNDEKO_DB_READ_ONLY=0` :

```powershell
.\backend\.venv\Scripts\python.exe backend/manage.py installer_instance --source CHEMIN_DU_PAQUET --pg-bin 'C:\Program Files\PostgreSQL\18\bin'
.\backend\.venv\Scripts\python.exe backend/manage.py installer_instance --source CHEMIN_DU_PAQUET --pg-bin 'C:\Program Files\PostgreSQL\18\bin' --apply
```

Le premier appel présente le plan ; le second vérifie les empreintes, installe `pg_trgm`, la structure métier et le dictionnaire, puis exécute les migrations Django natives exclusivement dans `public`. Une base non vide est refusée. Un échec conserve la base pour examen ; aucune purge ou réapplication partielle automatique n’est effectuée.

Créer ensuite le premier administrateur, dont le mot de passe est saisi deux fois dans une invite masquée :

```powershell
.\backend\.venv\Scripts\python.exe backend/manage.py initialiser_admin --email ADRESSE_REELLE --nom NOM --prenom PRENOM --sexe M
```

Cette commande refuse une installation qui possède déjà des utilisateurs. Elle demande au moins 14 caractères et n’affiche jamais le secret. Pour un processus automatisé isolé, `SAUVERNDEKO_BOOTSTRAP_PASSWORD` remplace l’invite ; le retirer immédiatement du processus après usage. Ne pas transmettre le mot de passe dans les arguments de commande ni le documenter.

Première recette complète du socle 01 à 08 obtenue sur `sauverndeko_test_install_final_20261026` depuis `.runtime/releases/socle-logistique-20261026-final`, exporté après installation des migrations du 26 octobre **01 à 08** : installation et migrations natives réussies ; cinq tables racines utilisateurs/entreprises/articles/bons/mouvements vides, neuf modules présents ; premier compte fictif créé uniquement dans cette base privée. **299 contrôles** ont ensuite réussi sur cette installation neuve : CUMP 45, péremption 49, registre des lots 65, annulation d’inventaire 31, corrections non commerciales 40, numérotation 22, récupération d’accès 27 et rôle runtime 20. Régénérer le paquet après une nouvelle migration métier.

## Mise à jour d’une instance existante

1. Identifier la version installée, le commit et le manifeste du paquet cible. Sauvegarder DB et médias, contrôler les empreintes et essayer leur restauration isolée.
2. Réserver une fenêtre de maintenance et arrêter les écritures applicatives. Appliquer uniquement les migrations manquantes dans l’ordre de `SQL/README.md`, avec leurs préconditions et commentaires. Aucun lanceur n’applique une migration automatiquement.
3. Déployer ensemble le backend, le frontend compilé et les contrats SQL correspondants. Exécuter `manage.py check`, le diagnostic GET en lecture seule et les recettes privées adaptées aux changements.
4. Contrôler les licences, identités documentaires, photos et justificatifs, puis rouvrir les écritures. Un retour à une ancienne version de code exige une compatibilité SQL démontrée ; une restauration complète doit tenir compte des écritures postérieures, sans les effacer silencieusement.

## Serveur de production

`config.production` et `serve_production.py` fournissent un service WSGI Waitress derrière un frontal HTTPS. Les fichiers de `deploy/production` préparent les images backend et frontend, Caddy, les volumes privés et la rotation des journaux. Le frontend est compilé ; Vite et `runserver` ne servent pas les requêtes clientes de production. Le port du backend n’est pas publié sur l’hôte Docker. Les médias ne sont jamais servis directement par Caddy.

Paramètres à fournir dans un fichier privé **distinct de la configuration locale** :

| Paramètre | Usage |
|---|---|
| `DATABASE_URL` | Rôle dédié `sauverndeko_runtime` vers une base SauverNdeko réservée à l’application, joignable depuis le conteneur ; aucun superutilisateur ni propriétaire de base. |
| `SAUVERNDEKO_DB_SSLMODE`, `SAUVERNDEKO_DB_SSLROOTCERT` | TLS PostgreSQL, défaut `verify-full`, certificat de l’autorité de confiance. La désactivation est refusée hors boucle locale. |
| `DJANGO_SECRET_KEY` | Secret aléatoire d’au moins 50 caractères. |
| `JWT_SECRET`, `JWT_REFRESH_SECRET` | Secrets distincts d’au moins 32 caractères. |
| `DJANGO_ALLOWED_HOSTS` | Noms exacts, sans joker. |
| `SAUVERNDEKO_FRONTEND_URL` | Origine HTTPS exacte utilisée par le client et les liens de récupération. |
| `SAUVERNDEKO_DB_READ_ONLY` | `1` jusqu’à validation de l’exploitation ; `0` pour les écritures déjà autorisées. |
| Variables `SAUVERNDEKO_EMAIL_*` | Transport Google autorisé ; conserver le secret hors Git. |

Après l’installation des schémas, appliquer `deploy/production/role-runtime.sql` avec le compte d’administration habilité à créer le rôle du cluster ; les migrations ordinaires utilisent ensuite un propriétaire de schémas distinct du service applicatif. Le rôle créé est sans connexion jusqu’à l’attribution interactive du mot de passe avec `psql` (`\password sauverndeko_runtime`), puis `ALTER ROLE sauverndeko_runtime LOGIN`. Le script refuse un rôle existant non identifié ou propriétaire d’objets. Il accorde les lectures et DML nécessaires aux triggers, les séquences sans remise à zéro et les journaux en ajout seulement ; il refuse CREATE, TEMP, TRUNCATE, création de rôle/base et privilèges administratifs. Réappliquer et contrôler les droits après une migration créant de nouveaux objets. Les comptes d’administration ne servent jamais au processus API.

La recette privée `SQL/tests/test_role_runtime.py` a passé 20 contrôles : identité SQL restreinte, refus DDL/TRUNCATE/modification d’audit, effacement des archives et remise à zéro des séquences et CRUD Article avec réception/sortie produisant un seul mouvement par bon. Le cluster de recette utilise une authentification locale de confiance ; l’authentification SCRAM et le certificat du serveur PostgreSQL cible restent à configurer et vérifier par l’exploitant. Le fichier `.env` local n’a pas été modifié.

Sur un hôte Docker équipé, fournir `SAUVERNDEKO_DOMAIN` (domaine réel résolu vers le serveur), `SAUVERNDEKO_DEPLOY_ENV` (chemin absolu du fichier privé) et `SAUVERNDEKO_DB_CA_FILE` (certificat CA local monté en lecture seule), puis vérifier la configuration et lancer :

```powershell
docker compose -f deploy/production/compose.yaml config --quiet
docker compose -f deploy/production/compose.yaml build
docker compose -f deploy/production/compose.yaml up -d
```

Prévoir DNS, accès 80/443, PostgreSQL privé, sauvegardes externes et supervision. Le sous-réseau privé déclaré doit être libre. Le fichier séparé `compose.maintenance.yaml` prépare les opérations de maintenance avec les outils PostgreSQL 18 et le volume média en lecture seule. Définir `SAUVERNDEKO_MAINTENANCE_ENV` vers un fichier privé de maintenance et `SAUVERNDEKO_BACKUP_DIR` vers un dossier privé existant accessible à l’UID 10001. Le compte de migration est réservé à ce processus éphémère ; il ne remplace pas le compte runtime du backend. Pour une sauvegarde, le compte runtime disposant des lectures suffit. Exécuter, par exemple, `docker compose -f deploy/production/compose.maintenance.yaml run --rm --build maintenance sauvegarder_instance --destination /backups/instance-AAAAMMJJ-HHMM`. Ne jamais monter le répertoire média dans le frontal public. Les variables TLS de la connexion de maintenance doivent correspondre à son environnement ; sur le serveur distant utiliser un profil TLS vérifié.

Les images utilisent des branches de version maintenues ; après validation de la construction sur le serveur cible, enregistrer les digests exacts des images dans le rapport de livraison. Seul le frontal déclaré est un proxy de confiance ; ne pas remplacer son adresse par un joker.

`check --deploy` et un appel `/health` via Waitress éphémère ont réussi en lecture seule. HSTS est actif ; `includeSubDomains` et le préchargement restent désactivés jusqu’à maîtrise de tous les sous-domaines. Docker n’est pas installé sur le poste de développement : les images, Caddy, l’obtention d’un certificat réel et l’accès depuis un second poste restent à exécuter sur le serveur cible. Aucun domaine fictif n’a été déployé.

Références techniques : [Waitress](https://docs.pylonsproject.org/projects/waitress/en/stable/usage.html), [proxy Caddy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).

## Récupération du mot de passe

`SQL/tests/test_recuperation_acces.py` crée uniquement des comptes fictifs dans une base `sauverndeko_test_*` explicitement configurée. Le transport mémoire remplace SMTP. **27 contrôles** sont passés : rendu texte/HTML, lien dans le fragment, non-énumération, expiration, usage unique, refus des comptes/entreprises inactifs, changements concurrents, révocation des anciennes sessions, conservation des permissions et absence de secrets dans l’audit. Ce test démontre le parcours applicatif ; il ne prouve pas la délivrance par Gmail. La recette `SQL/tests/test_messagerie_diagnostic.py` a passé **21 contrôles avec transport simulé** : permissions, configuration, ouverture/fermeture, erreurs masquées, absence d’envoi et limitation de fréquence de la route. Elle ne confirme ni une authentification SMTP réelle ni une délivrance. Aucun e-mail réel n’est envoyé par ces recettes.

## Corrections d’inventaire et documents commerciaux

Les bons correcteurs et compensateurs d’un comptage sont exclus des factures et restitutions commerciales. La migration 20261026_08 ajoute la vue de classement, la fonction commune, les verrous et contrôles SQL dans les deux sens, avec vérification différée au terme de la transaction. Les menus et fiches reprennent cette règle. Aucun document ancien n’est réécrit ; la migration refuse tout lien commercial historique qui demanderait un examen. Sur SauverNdeko, le contrôle préalable en lecture seule n’a trouvé aucun tel lien. La recette privée `test_corrections_inventaire.py` a passé 40 contrôles, dont l’émission normale d’une facture commerciale et la course d’une facture attendant un rattachement d’inventaire. Le parcours de correction reste un comptage ou une annulation motivée.

## Recette intégrée du cycle commercial

`SQL/tests/test_chaine_logistique.py` complète les recettes ciblées en reliant les services réels et les vues SQL. Elle exige une URL locale explicite `SAUVERNDEKO_TEST_DATABASE_URL` dont le nom commence par `sauverndeko_test_`, vérifie le nom effectif avant toute mutation et n'utilise jamais la connexion applicative par défaut. Privilégier une installation neuve du paquet final ; aucun e-mail ni transfert bancaire n'est déclenché.

```powershell
$env:SAUVERNDEKO_TEST_DATABASE_URL='postgresql://COMPTE@127.0.0.1:PORT/sauverndeko_test_chaine'
.\backend\.venv\Scripts\python.exe SQL/tests/test_chaine_logistique.py --artifacts .runtime/evidence/chaine
```

La recette passée sur `sauverndeko_test_chain09_delivery_20261026`, installation vierge du paquet 01 à 08 suivie de la migration 20261026_09, compte **109 contrôles**. La recette ciblée des identités documentaires a ensuite passé **37 contrôles** sur cette même base privée. Ces **109 + 37 contrôles** ont également été rejoués sur l’installation entièrement neuve issue du paquet courant `final09` :

- Deux entreprises fictives possèdent leur licence et leurs gestionnaires locaux, sans privilège de plateforme. Clients et fournisseurs utilisent les types du dictionnaire commun.
- Réception de 10,500 kg par lot à 4 USD/kg ; sortie de 6,250 kg à 8 USD/kg ; retour de 1,250 kg avant émission, donc facture de 40 USD sur 5 kg nets.
- Règlement partiel de 12 USD puis concurrence sur le solde de 28 USD : une seule demande réussit, le total reste 40 USD. Un nouveau retour de 2 kg laisse la facture émise intacte et produit un avoir de 16 USD.
- Imputation de 6 USD sur une autre facture du même tiers et remboursement enregistré de 10 USD. Deux requêtes simultanées identiques ne créent qu'un remboursement. Un retour sur la seconde facture impute d'abord son solde encore ouvert et conserve le crédit restant.
- Stock et lot finaux égaux à 7 kg ; six mouvements physiques seulement, coût moyen de 4 USD/kg et valeur de 28 USD. Le stock de l'autre entreprise reste à 5,125 kg.
- Rapprochement commercial : factures 48 USD moins avoirs 20 USD = 28 USD ; encaissements 40 USD moins remboursement 10 USD et crédit client encore disponible 2 USD = 28 USD.
- Rejeux, contenu modifié, droits insuffisants, autre entreprise, licence inactive, paiement historique protégé et sélection explicite d'entreprise par le compte global sont contrôlés.
- Les gestionnaires locaux licenciés configurent les profils documentaires de leurs seules entreprises. UUID/rejeux et contenu modifié sont contrôlés ; les identifiants légaux facultatifs et mentions multilignes sont figés dans les nouvelles factures.
- Les six PDF (entrée, sortie, livraison, facture, reçu, avoir) sont téléchargés par des routes privées, refusés à l'autre entreprise et sans cache. Cette recette historique conservait les identités émettrice et du tiers facturé figées ; la règle de présentation de l’émetteur a depuis évolué comme indiqué ci-dessous. Le justificatif PDF est restitué à l'octet près puis archivé, avec conservation en base.

Les six PDF d'une page ont été rendus avec Poppler et inspectés : tableaux, valeurs, identité, marges et pagination restent lisibles. Ce contrôle porte sur les cas fictifs de recette. Il ne remplace ni la validation du modèle documentaire par l'entreprise cliente ni les vérifications de fiscalité, coordonnées légales et signature réelle. Les remboursements sont des écritures de suivi ; aucun ordre bancaire réel n'est exécuté.

## Dernière correction du parcours de facturation

La recette UI de clôture a trouvé un contrat manquant : le registre Bons de stock ne publiait pas ses capacités de facturation, ce qui masquait « Créer la facture ». reads.register fournit désormais les mêmes indicateurs de disponibilité que la consultation 360 ; les droits et l’éligibilité métier restent contrôlés au serveur. Trois régressions couvrent disponibilité facture, restitution et contexte de chaque ligne : la chaîne complète a été rejouée avec **112 contrôles réussis** sur la base privée chain09, après les preuves d’installation à 109 contrôles ci-dessus. Cette correction de lecture ne modifie ni schéma ni donnée.

Le [guide de prise en main](prise-en-main-logistique.md) décrit les parcours utilisateurs et la reprise après une réponse réseau incertaine. Les réglages réels de l’entreprise, les deux coûts historiques encore inconnus et la connexion Google authentifiée restent des validations distinctes du succès des recettes privées.

## Identité courante de présentation des PDF — 28 octobre 2026

La demande du propriétaire remplace la présentation figée de l’émetteur : les PDF d’entrée, sortie, livraison, commande CMD, facture, reçu et avoir prennent le profil courant de leur entreprise à chaque génération, même pour un document antérieur. Le téléphone secondaire facultatif, le site, le logo PNG privé, les identifiants déclaratifs et les options d’en-tête/pied complètent `T_Entite` et sa vue canonique. Les octets ne sont pas exposés dans les JSON, audits ou exports génériques.

Les identités historiques conservées en base, les tiers émis, montants, lignes, numéros et dates restent inchangés. Les pièces ou PDF archivés sont téléchargés tels quels. Les deux options sont activées par défaut et sont exclusivement enregistrées dans le profil : le téléchargement les applique directement. Le nom de l’entreprise reste visible lorsque l’en-tête détaillé est masqué ; le pied désactivé est entièrement retiré, pagination comprise.

Pour la livraison, contrôler les quatre combinaisons d’options, le nom long, l’adresse multiligne, les mentions, le logo transparent, l’absence de logo et plusieurs pages. Vérifier un changement de nom suivi d’une nouvelle génération, la conservation des valeurs financières et la restitution à l’octet près d’une archive. Ces vérifications de présentation sont distinctes de la recette historique ci-dessus. Voir [le guide de profil et PDF](identite-entreprise-pdf.md) et [la charte documentaire](../skills/document-mise-en-forme/references/charte_documentaire.md).

La recette finale du 28 octobre a passé **57 contrôles SQL**, **13 tests API de profil**, **312 contrôles API/PDF** pour les sept documents et les quatre combinaisons, puis **189 contrôles de mise en page**. **48 pages rendues** ont été inspectées, avec contenus longs, logo transparent, absence de logo et documents multipages. Les polices Vera et Vera Bold de ReportLab sont embarquées dans les PDF pour conserver le rendu sur les différents systèmes.

La migration07 est appliquée dans SauverNdeko : les anciennes données des entreprises et les 66 autres tables sont conservées, sans modifier les écritures financières ou les instantanés. Les huit sources canoniques, y compris Système, ont été exportées sans données puis restaurées sur deux bases privées vides. Leurs définitions et commentaires sont identiques au catalogue installé : 67 tables pour la structure complète, 57 pour le métier, 80 vues et 126 triggers dans les deux cas. Voir [le dossier technique de l’identité documentaire](../SQL/documentation/Identite_Documents_Entreprise_20261028.md).
