# Diagnostic de préparation à la livraison

`verifier_livraison` contrôle l’instance configurée avec une transaction PostgreSQL explicitement `REPEATABLE READ, READ ONLY`, un délai de requête de 15 secondes et une garde SQL. Il ne crée ni compte, ni licence, ni coût, ni mouvement. Il ne se connecte pas à SMTP, n’envoie aucun message, ne contacte pas de domaine externe et n’écrit aucun fichier. Le service peut conserver sa configuration habituelle d’écriture : la protection appartient à la transaction du diagnostic.

## Utilisation

Depuis la racine du projet :

```powershell
.\backend\.venv\Scripts\python.exe backend/manage.py verifier_livraison
.\backend\.venv\Scripts\python.exe backend/manage.py verifier_livraison --entity 11
.\backend\.venv\Scripts\python.exe backend/manage.py verifier_livraison --entity 11 --backup-dir .runtime/backups/logistique-final-20261026 --json
.\backend\.venv\Scripts\python.exe backend/manage.py verifier_livraison --production --strict
```

`--entity` limite les contrôles de licence, identité, stock et valorisation à cette entreprise. Les contrôles de socle, comptes globaux et documents sans propriétaire restent globaux et ne retournent que des effectifs. Aucun nom de client, utilisateur, contact, hôte SMTP, secret ou chaîne de connexion n’est affiché. Le JSON contient uniquement l’identifiant d’entreprise demandé, les comptes agrégés et les observations techniques nécessaires.

`--production` durcit les exigences du compte SQL et des paramètres de production. Il ne bascule pas le profil ni ne déploie les services. Sur le serveur cible, exécuter la commande avec le même profil et les mêmes variables privées que le service (`config.production`). Le profil local peut être inspecté avec ce drapeau pour voir les écarts ; ses hôtes locaux ne sont pas une configuration de production.

`--json` fournit une seule sortie JSON, sans création automatique d’un rapport sur disque. Un rapport peut être redirigé explicitement vers un fichier privé sous `.runtime`, jamais vers le dépôt public. `--strict` retourne une erreur si au moins un contrôle est **Bloquant** ou **À configurer**. Un code de sortie nul avec des contrôles **Non vérifiés** ne constitue pas une approbation de production : ces contrôles externes restent à réaliser.

## Lecture des résultats

Chaque contrôle possède un code stable, un état, un constat, des mesures et une action :

- **Prêt** : la condition locale indiquée est observée. Par exemple, le solde de stock concorde avec les mouvements, ou les deux empreintes de fichiers correspondent.
- **À configurer** : une information ou une décision réelle reste à compléter : identité d’entreprise, accès de licence, coût historique inconnu, politique sur un stock périmé ou paramètres du serveur cible.
- **Bloquant** : absence de socle, entreprise explicite introuvable/inactive, désactivation de contrôles SQL, incohérence stock/lots, privilèges administratifs dans le profil production ou sauvegarde altérée.
- **Non vérifié** : l’opération n’a pas été exécutée. La commande conserve notamment cet état pour le certificat HTTPS externe, la délivrance d’e-mail, les droits effectifs du volume média, la planification et rétention des sauvegardes et une restauration.

Depuis le profil documentaire installé par SQL09, une identité incomplète se corrige dans **Logistique → Identité de l’entreprise**, après sélection de l’entreprise concernée. Compléter les coordonnées réelles. Les identifiants légaux et la mention documentaire restent facultatifs selon le pays et le secteur ; aucun RCCM/NIF universel n’est exigé ni inventé par le diagnostic.

Le constat CUMP vient de `V_ValorisationStock`, clé `ID_Article`. Les coûts inconnus restent `NULL` et les quantités non nulles à coût inconnu sont signalées. Le diagnostic ne remplace jamais ce coût par un prix catalogue ou par zéro et ne valide aucune ouverture. Les stocks sans date ne sont pas considérés automatiquement comme périssables ; les alertes de péremption ne concernent que les quantités restantes, selon les vues communes.

Les licences viennent de `V_EntiteModuleActif` et `V_LicenceModule`. Le diagnostic vérifie l’accès Logistique et ne requiert pas que chaque entreprise souscrive tous les modules. Les permissions des rôles restent à vérifier par les recettes dédiées ; le contrôle du compte SQL ne les remplace pas.

## Vérification d’une sauvegarde précise

`--backup-dir` désigne un dossier produit par `sauvegarder_instance`. La commande lit `manifest.json`, `database.dump` et `media.tar.gz` dans ce dossier explicite. Le format 2 ajoute le seul fichier fixe `constraint-comments.sql`, avec son empreinte et son nombre de commentaires de contraintes-triggers. Elle ne parcourt pas les sous-dossiers, ne recherche pas une sauvegarde récente et n’ouvre aucun chemin issu de la liste de médias du manifeste. Les fichiers liés et les manifestes d’une autre instance sont refusés.

Les SHA-256 des deux archives et du complément en format 2 doivent correspondre au manifeste. L’ancienneté observée du manifeste est comparée à 72 heures par défaut, modifiable avec `--max-backup-age-hours` entre 1 et 8760. Cette date de modification n’est ni un horodatage certifié de création, ni une preuve de restauration ou de planification externe. La correspondance d’empreintes ne décode pas le dump et n’extrait pas les médias. Exécuter séparément `restaurer_recette` sur une base privée neuve et conserver son rapport ; le champ `restored` d’un manifeste n’est jamais accepté comme preuve. Les sauvegardes historiques de format 1 restent acceptées, sans preuve des commentaires complémentaires. Le rapport format 2 indique séparément `constraintTriggerCommentsVerified` et `constraintTriggerCommentsExact`.

## Recette

`SQL/tests/test_diagnostic_livraison.py` exige explicitement une URL `SAUVERNDEKO_TEST_DATABASE_URL` vers une base `sauverndeko_test_*`. Ses fixtures n’existent que dans cette base privée ; il ne se replie jamais sur SauverNdeko. La recette du 26/10/2026 a réussi **47 contrôles**, dont les cas prêt/à configurer, la licence expirée, le CUMP inconnu conservé, le refus d’UPDATE et d’un CTE modificateur, les sorties JSON, les prérequis de production, les sauvegardes fraîches/anciennes/altérées et l’interdiction de toute construction de connexion SMTP.

Le guide général `docs/livraison-logistique.md` décrit les commandes distinctes de sauvegarde, restauration, installation et provisionnement. Le diagnostic propose ces actions mais ne les exécute jamais.
