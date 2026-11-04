# Déploiement de SauverNdeko sur Render

Préparation du 4 novembre 2026. Les fichiers de déploiement sont livrés dans le dépôt ; aucun service, abonnement payant ou base Render n'a été créé pendant cette préparation.

## Architecture retenue

Un service web Docker sert React compilé et l'API Django sur la même adresse HTTPS. Caddy sert les fichiers frontend ; Waitress écoute uniquement sur `127.0.0.1:5000`. Le port public suit `PORT`, fourni par Render. Les routes API et leurs permissions restent celles de l'application.

Pour conserver les limites de connexion par adresse, Caddy reconnaît les pairs du réseau privé Render et lit uniquement `CF-Connecting-IP`, remplacé par le frontal Cloudflare. Il transmet à Waitress une seule adresse nettoyée dans `X-Forwarded-For`, jamais la chaîne fournie par le navigateur. Un pair extérieur à ces plages n'est pas cru. Vérifier sur le service réel deux adresses clientes différentes et le refus d'une usurpation d'en-tête ; tout accès privé d'un autre service de l'espace doit rester maîtrisé. Ce contrat est propre au frontal Render et doit être réexaminé pour un autre hébergeur. [Adresse cliente sur Render](https://render.com/articles/host-pocketbase-on-render), [confiance aux proxies dans Caddy](https://caddyserver.com/docs/caddyfile/options#client-ip-headers).

PostgreSQL reste une base distincte. Le service web utilise uniquement le compte `sauverndeko_runtime`, sans propriété d'objet ni droit de modification du schéma. Un processus de maintenance distinct utilise le compte propriétaire pour les migrations. Ne jamais renseigner l'URL propriétaire dans le service web.

Les photos et justificatifs résident dans `/var/data/media`, sur le disque persistant. Caddy ne publie pas ce dossier : les téléchargements passent par les routes Django qui contrôlent les accès. Les fichiers déjà présents sur l'ordinateur doivent être transférés et contrôlés au premier déploiement.

Le Blueprint `render.yaml` décrit un service payant `starter`, une instance, région `frankfurt`, disque de 10 Go. Vérifier le besoin réel de stockage, les offres et le coût dans Render avant sa création. La base PostgreSQL n'est volontairement pas créée par ce Blueprint : choisir sa version, sa région, son offre et le parcours d'installation ou de transfert explicitement.

## Première mise en ligne

1. Créer une base Render PostgreSQL **18**, dans la même région que le service web. Le code métier, les migrations et les outils locaux ont été préparés pour ce socle.
2. Choisir la destination : transférer une sauvegarde vérifiée de l'instance existante, ou utiliser le paquet d'installation sur une base entièrement vide. L'installateur vierge ne doit jamais être lancé sur une base cliente remplie. Voir [la livraison Logistique](livraison-logistique.md#installation-vierge).
3. Vérifier les tables, vues, fonctions, triggers, références, identités et données après le transfert. La connexion propriétaire reste réservée à la maintenance. Le nom réel de la base distante peut différer de `SauverNdeko` ; le socle de migrations doit correspondre à son catalogue installé, pas à son seul nom.
4. Présenter puis attester le **socle de migrations livré** avec `migrer_metier --baseline CHEMIN_DU_SOCLE`, puis la même commande avec `--apply` après vérification et sauvegarde. Utiliser le fichier exact référencé par `SQL/releases/manifest.json`. Cette opération vérifie le catalogue ; elle ne rejoue pas les anciennes migrations et ne constitue pas un `--fake`. Un refus impose de comprendre les différences de schéma, sans modifier le socle pour masquer une anomalie.
5. Initialiser le rôle applicatif avec `deploy/production/role-runtime.sql`, attribuer son mot de passe par une procédure privée et vérifier ses droits. Le compte de maintenance doit posséder les droits nécessaires sur les schémas et le rôle runtime. Ces droits doivent être contrôlés sur le compte Render réel ; leur disponibilité n'a pas été vérifiée sur un compte cloud pendant cette préparation.
6. Importer les médias dans `/var/data/media` et comparer leur inventaire et leurs empreintes à la sauvegarde. Contrôler les droits du **volume réellement monté** pour l'UID/GID `10001`, et vérifier la création puis la suppression d'un fichier temporaire sous cette identité. Le `chown` pendant la construction ne prouve pas les droits du volume fourni par Render. Si une initialisation des permissions est nécessaire, la réaliser dans le parcours privé de préparation du disque avant l'ouverture client ; ne pas rendre le dossier publiquement modifiable ni lancer un `chown` récursif aveugle sur des médias inconnus. Le pré-déploiement n'a pas accès à ce disque ; cette copie se fait séparément, avec les écritures applicatives arrêtées.
7. Dans Render, créer un Blueprint depuis le dépôt et le fichier `render.yaml`, puis renseigner les variables décrites ci-dessous. Aucun fichier `.env` local n'est envoyé par l'image Docker.
8. Vérifier le premier démarrage, `/health`, la connexion, les entreprises, les licences, les photos, les justificatifs et les parcours métier. L'URL web initiale et les hôtes autorisés sont dérivés de `RENDER_EXTERNAL_HOSTNAME`. Pour un domaine propre, renseigner les deux variables d'origine explicitement.

L'attestation du socle et le transfert initial sont des opérations de maintenance, pas des tâches automatiques à chaque démarrage. Une nouvelle installation ne doit recevoir aucun compte, stock, document ou configuration d'une autre entreprise par copie involontaire.

## Variables privées à renseigner

### Dans le service web Render

| Variable | Valeur attendue |
|---|---|
| `DATABASE_URL` | URL PostgreSQL du seul rôle runtime. Ne pas recopier l'URL propriétaire affichée par défaut dans Render. |
| `DJANGO_SECRET_KEY` | Secret aléatoire propre au serveur, au moins 50 caractères. |
| `JWT_SECRET`, `JWT_REFRESH_SECRET` | Deux secrets distincts, générés séparément par le Blueprint. Leur changement invalide les jetons correspondants. |
| `SAUVERNDEKO_DB_READ_ONLY` | `0` pour les opérations métier des comptes habilités ; cela ne donne aucun droit DDL au rôle runtime. |
| `SAUVERNDEKO_DB_SSLMODE` | `require` pour le réseau privé Render décrit par le Blueprint. |
| `SAUVERNDEKO_MEDIA_ROOT` | `/var/data/media`, sous le disque persistant. |
| `DJANGO_ALLOWED_HOSTS` | Facultatif avec l'hôte Render ; liste exacte des noms autorisés pour un domaine propre. Aucun `*`. |
| `SAUVERNDEKO_FRONTEND_URL` | Facultatif avec l'hôte Render ; origine HTTPS exacte pour un domaine propre. |

Le serveur refuse de démarrer si une URL de maintenance est fournie dans son environnement. Ne pas copier tout le `.env` de développement dans Render. Les clés SMTP et autres services se configurent séparément avec les noms déjà utilisés par le backend ; elles ne sont pas embarquées dans Git ni dans le frontend.

Le fichier privé `backend/.env` contient une section commentée « EN LIGNE » préparée pour le service web. Remplacer les paramètres indicatifs de l'hôte, de la base et de la messagerie, puis copier uniquement cette section dans les variables Render en retirant les préfixes de commentaire. La laisser commentée sur le poste local. Les secrets SauverNdeko y sont distincts de ceux du développement et des autres projets. La section de maintenance suivante est destinée aux secrets GitHub, pas au service web.

`config.production` reste la configuration HTTP. `config.maintenance` initialise les commandes CLI avec une clé éphémère, une URL PostgreSQL explicite et les paramètres TLS ; cette configuration n'est pas destinée à servir l'application web. `SAUVERNDEKO_DB_READ_ONLY=0` n'est utilisé pour les changements de schéma que dans ce processus de maintenance isolé.

Les connexions privées Render utilisent des certificats auto-signés et ne supportent pas `verify-ca`/`verify-full` ; `require` impose le chiffrement sur ce réseau privé. Pour la maintenance externe, le workflow utilise `verify-full` et le magasin CA du runner. Vérifier la chaîne de certificats et le nom d'hôte externe réel. Les paramètres SSL explicites de configuration font autorité ; ne pas supposer qu'une option ajoutée à la query string de `DATABASE_URL` est automatiquement reprise par les réglages Django existants. [Connexion PostgreSQL Render](https://render.com/docs/postgresql-creating-connecting#ssl-modes-for-internal-connections).

### Dans GitHub, environnement `render-production`

| Secret | Destination |
|---|---|
| `MAINTENANCE_DATABASE_URL` | URL externe TLS du propriétaire des schémas, réservée au job de maintenance. |
| `RENDER_DEPLOY_HOOK_URL` | URL secrète du hook du service web. Le workflow y ajoute le SHA exact à déployer. |

Créer l'environnement GitHub `render-production`, limiter les branches autorisées à `main` et configurer sa protection selon l'organisation. Les secrets de cet environnement ne se configurent pas dans le service web Render. L'accès réseau PostgreSQL externe du runner doit être autorisé : employer une sortie réseau maîtrisée et une liste d'IP adaptée. Ne pas ouvrir la base à toutes les IP pour contourner un refus. Le choix d'un runner hébergé, à sortie stable ou privé doit être vérifié avant activation sur le compte cible.

## Livrer une mise à jour

Le workflow **Livraison Render contrôlée**, dans `.github/workflows/livraison-render.yml`, s'exécute uniquement manuellement (`workflow_dispatch`) depuis `main`. Les déploiements Render automatiques sur chaque push sont désactivés par `autoDeployTrigger: off`.

Avant son lancement, disposer d'une sauvegarde DB **et médias** vérifiée, d'un retour compatible et d'une fenêtre de maintenance lorsque le changement l'exige. Le champ `backup_reference` conserve la référence de cette preuve ; **le workflow ne crée ni ne restaure cette sauvegarde et ne prouve pas sa validité**. Il exige l'attestation de l'opérateur. Aucun export de données clientes n'est téléversé vers les artefacts GitHub par ce workflow.

Parcours livré :

1. Tester les contrats Render et les composants frontend, compiler React, puis construire l'image Docker sans secrets PostgreSQL de production. Cette construction valide aussi le Caddyfile et embarque la charte utilisée par les exports Excel.
2. Avec le seul environnement de maintenance, présenter le plan `migrer_metier`, appliquer les évolutions manquantes avec `--apply --release "$GITHUB_SHA"`, puis les seules migrations natives Django autorisées dans `public`. Le journal conserve le commit associé aux nouvelles évolutions.
3. Actualiser les droits runtime avec le script SQL contrôlé : les nouveaux objets doivent être accessibles selon les droits métier, tandis que le journal de migrations reste en lecture seule pour le service web.
4. Vérifier `migrer_metier --check` et `migrate --check`.
5. Demander au hook Render le déploiement du **même commit** que celui construit et migré, avec le paramètre `ref`. Un échec de migration ou de droit arrête le workflow avant cet appel. [Hooks et commit exact](https://render.com/docs/deploy-hooks#deploying-a-specific-git-commit).

Sur Render, le pré-déploiement contrôle le rôle runtime et les versions dans une connexion en lecture seule. Il refuse les privilèges DDL/propriétaire ainsi que l'écriture ou la troncature du journal de migrations, y compris par droits de colonne. Il refuse aussi un schéma non attesté, des migrations manquantes ou une dérive. Il ne crée ni base, ni table métier, ni utilisateur. Le build et le démarrage n'exécutent aucune migration. La commande de pré-déploiement est disponible sur les services payants et s'exécute sans accès au disque persistant. [Étapes de déploiement Render](https://render.com/docs/deploys#pre-deploy-command).

La réussite du job `deploy` signifie que Render a accepté la demande, pas que le nouveau service est déjà opérationnel. Vérifier son résultat final dans Render et effectuer la recette. Une demande en attente peut être remplacée par une autre selon la politique Render ; conserver **Wait** et ne pas lancer un déploiement manuel concurrent pendant une livraison.

Les migrations restent progressives et compatibles avec l'ancien service tant que celui-ci peut encore recevoir des requêtes. Un changement incompatible exige une maintenance bloquant les écritures avant l'application. Le retour à un ancien commit n'annule pas la base ; prévoir une migration corrective compatible plutôt qu'une restauration qui supprimerait les opérations clients postérieures.

## Médias, sauvegardes et limites de la première architecture

Le disque persistant conserve les fichiers entre redémarrages. Il limite le service à une instance et empêche les déploiements sans interruption ; Render peut arrêter brièvement l'instance pendant son remplacement. Les commandes de build, pré-déploiement et jobs ponctuels ne voient pas le disque. [Disques persistants Render](https://render.com/docs/disks#disk-limitations-and-considerations).

Les sauvegardes PostgreSQL et médias restent distinctes et doivent être conservées hors du seul disque actif, avec une restauration de recette. Les fonctions de sauvegarde de l'offre Render choisie doivent être vérifiées avant l'ouverture client. Cette préparation ne configure ni sauvegarde externe planifiée, ni coût commercial, ni domaine, ni serveur SMTP sur un compte réel. Une évolution vers du stockage objet privé pourra permettre plusieurs instances, avec adaptation des chemins et contrôles d'accès ; elle n'est pas nécessaire à cette première architecture et n'est pas livrée ici.

## Contrôles effectués dans le poste de développement

- 16 tests autonomes réussis : hôtes/origines, refus des secrets de maintenance dans le web, ports privés, contrôle de versions sans écriture, arrêt des processus, confirmations de livraison, garde du hook, commit exact, couverture des préfixes de routes backend et arguments de mise à jour des droits sans mot de passe dans la commande.
- Compilation Python des fichiers Render et de `config.maintenance` réussie.
- Initialisation CLI vérifiée sans connexion DB : une `DATABASE_URL` absente est refusée avant tout repli sur le `.env` local ; une URL factice explicite en boucle locale permet l'initialisation de la configuration.
- Initialisation de `config.production` vérifiée avec un environnement Render factice : hôte autorisé, origine HTTPS de réinitialisation, chemin média privé et TLS `require`, sans connexion DB. Un export Excel à une ligne a aussi été généré en mémoire avec la charte et son archive XLSX a été vérifiée ; cela ne remplace pas une recette visuelle du fichier client.
- Collecte réelle de **154 fichiers statiques** dans un dossier temporaire, avec connexion DB factice sur un port fermé ; les fichiers natifs Django et DRF sont présents.
- Contrats textuels vérifiés pour le disque, le proxy local, les médias privés et l'absence de migration dans le build/démarrage.

Docker et Caddy ne sont pas installés sur ce poste : la construction Linux et la validation effective du Caddyfile restent à exécuter. Le workflow construit l'image **avant** toute migration distante. Aucun test de connexion, permission, coût, certificat, hook, disque ou restauration Render n'a été exécuté contre un compte cloud. Les résultats détaillés du journal et du socle de migrations relèvent de sa recette SQL, distincte de ces tests de préparation Render.
