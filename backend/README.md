# Backend SauverNdeko — Django

L’API active utilise Python 3.12, Django 5.2 LTS, Django REST Framework et la connexion PostgreSQL Django/psycopg. Les URL consommées par React restent sous /api et /SauverNdeko/auth. Le port Django par défaut est 5000 ; les lanceurs Windows choisissent un port libre et transmettent cette cible au proxy Vite.

## Démarrer

Depuis le dossier backend, dans PowerShell :

~~~powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\start.ps1
~~~

L’environnement local est déjà installé. Ne pas écraser le .env existant : DATABASE_URL, JWT_SECRET et JWT_REFRESH_SECRET sont réutilisés. Les options Django sont lues depuis ce fichier par [config/settings.py](config/settings.py).

SAUVERNDEKO_DB_READ_ONLY vaut 1 par défaut. La connexion et les GET autorisés sont utilisables ; modification de profil et écritures métier renvoient READ_ONLY/503. L’inscription libre est fermée avec REGISTRATION_DISABLED/403. L’activation explicite de SAUVERNDEKO_DB_READ_ONLY=0 nécessite un redémarrage et permettra les écritures normales de l’application. Le réglage local a été activé en écriture le 25 octobre 2026 sur autorisation du propriétaire ; les nouvelles installations restent en lecture seule par défaut. Aucun lancement ne crée de table ni de base.

Le serveur runserver est destiné au développement local. Pour une installation client, prévoir un serveur WSGI/ASGI, HTTPS, les hôtes/origines autorisés, les secrets, sauvegardes, surveillance et une recette des écritures métier autorisée séparément.

## Vérifier sans écrire dans PostgreSQL

~~~powershell
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py verifier_backend
~~~

verifier_backend exécute uniquement des GET avec PostgreSQL en lecture seule, vérifie les routes globales et le refus d’une organisation fictive sans offre. Il injecte une identité interne synthétique et ne prouve pas une connexion réelle avec le mot de passe d’un client. Le dossier de tests unitaires a été retiré à la demande du propriétaire.

migrate est limité aux applications natives Django dans public. makemigrations, flush, syncdb, fake et migrations vers une version antérieure sont désactivés. Les 31 modèles Django sont unmanaged ; les 48 vues existantes sont répertoriées et interrogées par SQL paramétré. Le socle auth/admin/contenttypes/sessions est installé dans public avec 18 migrations. Les trois comptes métier existants sont conservés dans systeme ; aucun compte natif Django n’a été créé ou dupliqué.

## Organisation du code

- config/ : paramètres, routes, WSGI/ASGI.
- apps/accounts/ : JWT compatible React, mots de passe existants et profils.
- apps/core/ : modèles unmanaged, registre de sources, permissions, SQL commun, paramétrage et réponses JSON.
- apps/logistique/ : commandes/lignes, références, stock et dashboard.
- apps/catalogue/ : projections publiques autorisées.
- apps/communication/ : discussions et messages avec contrôle des participants.
- requirements.txt : fichier unique des dépendances Python verrouillées. Le démarrage passe par start.ps1 ou les BAT de la racine.

Les effets de stock et les totaux restent portés par les triggers PostgreSQL. Le backend Python n’écrit jamais directement dans T_Mouvement. Les écritures métier et leur audit sont regroupés dans la même transaction.

## Contrats et limites

- L’accès privé exige un JWT valide et un utilisateur actif relu en base. Is_Admin représente l’administration globale ; Is_staff/les rôles administratifs existants donnent accès au périmètre local autorisé.
- Les organisations sont déduites du créateur actuel des articles/commandes, conformément aux colonnes existantes. Cette limite ne garantit pas une propriété immuable si un créateur change d’organisation. Les lignes contrôlent les deux parents. Les objets sans règle de périmètre démontrée restent réservés à l’administration globale.
- Les mots de passe bcrypt existants sont lus sans modification. Les nouveaux mots de passe utilisent le hachage Django. Les anciens mots de passe en clair sont refusés par défaut. Les JWT restent sans révocation persistante, comme auparavant ; la déconnexion efface la session côté client.
- La création des comptes est réservée à l’administration. Une association à une entité n’accorde aucun droit administratif ; les discussions d’une structure sont réservées à ses gestionnaires autorisés et aux participants concernés.
- Les nombres décimaux sont reçus et renvoyés sans conversion en flottants. Les quantités de mouvement restent entières selon le schéma actuel. La base ne fournit pas une devise par commande : aucune certification multidevise n’est ajoutée.
- L’administration utilise les écrans React existants. L’administration native Django est accessible uniquement sur le backend local, à /django-admin/. Elle utilise ses propres comptes natifs ; elle ne remplace pas l’administration ERP React.
- analytics.T_Recherche et V_Recherche sont installées. GET /api/recherches est réservé à l’administration globale ; ce registre est consultable sans activer de suivi automatique.
- Les écritures et les scénarios de concurrence ont été vérifiés sur une copie isolée avec données fictives. Ces résultats concernent le socle historique ; le CRUD local a été autorisé le 25 octobre 2026 et les vérifications frontend sont décrites dans les sections suivantes.
- Les véritables générateurs Excel, Word et PDF restent un chantier distinct, soumis au skill documentaire.

Voir [le bilan métier et technique](../SQL/documentation/Audit_Metier_20261024.md) pour les contrôles et les différences de comportement.


Les quatre lanceurs BAT de la racine démarrent/arrêtent les deux services et affichent leurs adresses. Voir [le lancement local et réseau](../docs/lancement-local.md). Le script backend/start.ps1 reste disponible pour lancer uniquement Django.


## Socle natif dans public

Voir [le bilan de migration](../SQL/documentation/Django_Public_20261024.md). Les tables techniques sont dans public ; les tables métier restent qualifiées dans leurs schémas. Une sauvegarde complète a précédé la migration. Pour préparer une évolution native : python manage.py migrate --plan. Pour appliquer un plan validé ou créer un compte technique avec createsuperuser, lancer ponctuellement le processus avec SAUVERNDEKO_DB_READ_ONLY=0 ; aucun changement du .env n’a été réalisé pendant cette intervention. L’administration native écrit sessions/journal et exige aussi ce mode lors de son utilisation. Les identités métier et natives restent à rapprocher explicitement.

## Audit des schémas métier

Le [bilan de la migration 04](../SQL/documentation/Audit_Metier_20261024.md) décrit les contrôles de stock, licences, JSON/UUID, géographie et discussions. Les résultats historiques des 66 tests unitaires, des 36 scénarios PostgreSQL et des 19 échanges Django sur recette sont conservés dans ce bilan. Le dossier de tests unitaires a été retiré depuis ; les commandes de contrôle disponibles sont celles indiquées plus haut. Les fichiers SQL canoniques et leur usage sont décrits dans [SQL/README.md](../SQL/README.md).

Le serveur local ferme les connexions PostgreSQL après chaque requête (CONN_MAX_AGE=0) et les identifie comme SauverNdeko-Django. Les anciens serveurs lancés sous une autre session Windows doivent être fermés depuis cette session ; utiliser les adresses de .runtime/services.json pour l’instance courante.

## Accès ERP et applications

/api/workspace/modules expose uniquement les applications effectivement autorisées : socle de l’Entité active, modules de ses licences en cours et restrictions du rôle. Le même contrôle protège les routes métier, les vues génériques, les exports officiels et les consultations 360. Les endpoints /api/public/* sont conservés pour leur contrat de projection, mais exigent maintenant un compte actif. Les réponses /api/* et /SauverNdeko/auth/* portent Cache-Control: no-store, private. Une réponse 401 sur une requête privée ramène le frontend au login. /health vérifie la connexion PostgreSQL par SELECT 1 ; aucune donnée métier anonyme n’est nécessaire au lancement.

## Licences par Entité — 25 octobre 2026

La migration SQL 20261025_02_modules_entites ajoute trois tables, trois vues et deux triggers commentés dans systeme. T_LicenceModule rattache un module à une licence existante ; l’Entité et les dates restent celles de T_Licence. T_RoleModule définit des restrictions par Entité/rôle/module. Les nouvelles lectures et écritures utilisent les services dédiés apps/core/module_access.py et application_licences.py ; ces tables ne sont pas exposées au CRUD générique.

- Socle : Discussions, Organisation territoriale, Administration, sous réserve des habilitations existantes.
- Modules optionnels : Catalogue, Produits, Structures, Professionnels, Informations santé et Logistique. Catalogue inclut ses quatre rubriques.
- Les six activations reprises sur la licence existante portent Origine=reprise. Aucun contrat, prix, compte ou nouveau privilège administratif n’a été créé.
- Un utilisateur d’entreprise hérite de son Entité relue en base ; une valeur d’Entité envoyée par le client ne peut pas changer son périmètre.
- Seul Is_Admin configure les activations et restrictions. Un administrateur d’entreprise consulte son offre et ne peut pas prolonger sa licence par les anciennes routes CRUD.
- Les règles de rôle ne dépassent jamais les habilitations antérieures. Is_staff n’accorde aucun accès global.
- L’expiration, la désactivation et les droits sont relus à chaque requête ; aucun cache global des habilitations. Le profil frontend se synchronise au retour sur la fenêtre et toutes les minutes pendant son utilisation.
- Les API de configuration sont /api/workspace/organisations, /licences, /licences/{id}/modules et /roles (préfixe commun /api/workspace). Les écritures sont versionnées, transactionnelles et auditées.

Contrôles effectués : Django check, 144 routes GET aux statuts attendus, 107 assertions en lecture seule sur SauverNdeko, simulation isolée des enregistrements et recette navigateur sur données fictives. La sauvegarde complète avant migration est vérifiée dans .runtime/backups. Aucun article, bon, règlement, compte ni date de licence n’a été modifié par cette évolution.

Le test transactionnel d’écriture sur la base réelle a été refusé par la validation automatique et n’a pas été exécuté. Les écritures ont donc été contrôlées en simulation, avec validation SQL/PLpgSQL et contrôles des objets installés ; un cycle d’enregistrement réel de configuration n’est pas attesté par cette recette.

## Articles, photos et lots — 25/10/2026

La migration SQL 20261025_03 est installée sur SauverNdeko. Le CRUD Articles utilise une révision optimiste et contrôle les suppressions ; le stock ne se corrige pas directement par PUT Article. Le poids unitaire, son unité de masse et InformationArticle sont disponibles. La ventilation par numéro de lot suit les mouvements existants, sans deuxième effet sur le stock. Les photos sont contrôlées par Pillow et stockées en fichiers privés ; sauvegarder backend/media avec la base.

Contrats de maintenance : [Articles, photos et lots](skills/develop-sauverndeko-backend/references/articles-lots-photos.md). Recette dédiée : SQL/tests/test_articles_postgresql.py sur une base sauverndeko_test_* indépendante. La livraison passe 70 assertions de CRUD/lots/photos/concurrence, les 36 scénarios PostgreSQL et les 19 échanges API existants. Le diagnostic réel verifier_backend passe 146 routes GET en lecture seule. Ces contrôles ne remplacent pas une recette complète de tous les modules.
