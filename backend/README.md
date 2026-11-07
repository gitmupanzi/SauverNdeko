# Backend SauverNdeko

L'API utilise Django 5.2 LTS, Django REST Framework et PostgreSQL via psycopg. React/Vite consomme les routes `/api/*` et `/SauverNdeko/auth/*`. Les dépendances Python verrouillées sont réunies dans [requirements.txt](requirements.txt).

## Démarrage local

Les lanceurs de la racine démarrent ensemble Django et Vite sur le port frontend fixe 5174. Ils ouvrent `/catalogue` ; après connexion, les applications autorisées sont dans `/espace`. Voir le [guide de lancement](../docs/lancement-local.md).

Pour préparer uniquement le backend depuis ce dossier :

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\start.ps1
```

`start.ps1` lance Django sur `127.0.0.1:5000` par défaut. Le lanceur complet peut choisir un port backend libre puis configurer le proxy Vite. `runserver` est réservé au développement.

Le fichier `backend/.env` est privé. Il contient notamment la connexion PostgreSQL et les secrets de session ; il n'est jamais transmis par un push. La base locale s'appelle `sauver_ndeko_pro`. Une connexion manquante ou invalide ne crée aucune base de secours. `SAUVERNDEKO_DB_READ_ONLY=1` est le défaut de protection ; les écritures des comptes habilités exigent `0` et le redémarrage du service. Ce réglage ne donne aucune permission supplémentaire.

## Architecture

| Dossier | Responsabilité |
|---|---|
| `config/` | Paramètres local/production/maintenance, routes et WSGI/ASGI. |
| `apps/accounts/` | Authentification, profils, photos et récupération d'accès. |
| `apps/core/` | Accès par entreprise, licences, référentiels, territoires, administration et maintenance. |
| `apps/logistique/` | Articles, lots, bons, inventaires, documents, factures, règlements et immobilisations. |
| `apps/caisse/` | Caisses, écritures et clôtures. |
| `apps/catalogue/` | Offres de produits et annuaires de structures autorisés. |
| `apps/professionnels/` | Profils professionnels et annuaire publié. |
| `apps/communication/` | Discussions privées, annonces et notifications. |
| `apps/support/` | Incidents et demandes d'assistance. |

Les modèles métier sont `managed=False` ; les lectures réutilisent les vues PostgreSQL et le registre des sources autorisées. Les écritures métier contrôlent les droits, la portée, les révisions et les demandes rejouées. Leurs audits partagent la transaction. Les triggers et fonctions PostgreSQL portent les effets de stock : aucun deuxième mouvement n'est ajouté en Python.

Les données métier appartiennent durablement à l'entreprise lorsqu'un propriétaire est défini dans le schéma. Le contexte sélectionné par le navigateur est vérifié par le serveur. Un compte d'entreprise reste dans son périmètre ; `Is_staff` ne confère pas les droits de l'administrateur global `Is_Admin`.

Les valeurs catégorielles enregistrent `ID_Generique` et affichent `AbrGenerique`. Les associations schéma/table/colonne vers les catégories sont centralisées. Les quantités exactes respectent la précision de l'unité ; les montants et devises restent explicites, sans addition de devises différentes ni conversion implicite. Les JWT vérifient l'état actuel du compte et la version du mot de passe ; un changement de mot de passe invalide les anciennes sessions. L'inscription libre est fermée.

## Contrôles sans écriture

Depuis le dossier backend :

```powershell
.\.venv\Scripts\python.exe manage.py check
```

Pour les diagnostics qui interrogent réellement PostgreSQL, utiliser un processus en lecture seule, sans modifier le fichier `.env` :

```powershell
$PreviousReadOnly = [Environment]::GetEnvironmentVariable('SAUVERNDEKO_DB_READ_ONLY', 'Process')
try {
    $env:SAUVERNDEKO_DB_READ_ONLY = '1'
    .\.venv\Scripts\python.exe manage.py verifier_backend
    .\.venv\Scripts\python.exe manage.py verifier_livraison
    .\.venv\Scripts\python.exe manage.py migrer_metier --check
    .\.venv\Scripts\python.exe manage.py migrate --check
}
finally {
    [Environment]::SetEnvironmentVariable('SAUVERNDEKO_DB_READ_ONLY', $PreviousReadOnly, 'Process')
}
```

`verifier_backend` effectue des GET avec une identité interne de diagnostic. Il ne prouve ni connexion avec un mot de passe client, ni écriture réelle, ni délivrance Gmail. Les recettes d'écriture dans `SQL/tests/` sont réservées aux bases isolées explicitement configurées `sauverndeko_test_*` ; elles ne doivent jamais viser une base cliente.

## Migrations et livraison

Les migrations natives Django concernent uniquement `admin`, `auth`, `contenttypes` et `sessions` dans `public`. Les évolutions métier suivent [SQL/releases/manifest.json](../SQL/releases/manifest.json) et leur journal par base ; les SQL publiés restent immuables. `makemigrations`, `flush`, `syncdb`, les fausses migrations et les retours arrière sont bloqués. Ni le build, ni le démarrage, ni un push ne modifient automatiquement le schéma.

Avant une mise à jour : sauvegarder la base et les médias, vérifier leur restauration sur copie, tester les migrations, puis appliquer avec le seul compte propriétaire de maintenance. Le compte du service web reste limité. Voir [les mises à jour sans recréation](../docs/mises-a-jour-base.md), [le parcours Render](../docs/deploiement-render.md) et [la maintenance depuis un poste](../docs/maintenance-render-depuis-poste.md).

En production Render, Caddy sert React et transmet l'API à Waitress. Les médias privés résident sur le disque persistant et sont sauvegardés avec PostgreSQL. Le [bilan du 7 novembre 2026](../docs/livraison-render-20261107.md) documente la mise à niveau réellement exécutée et ses limites. La préparation d'une installation vierge conserve un décalage de socle à traiter ; cette voie ne doit pas être présentée comme validée.

Les [skills backend](skills/develop-sauverndeko-backend/SKILL.md) et les guides par domaine décrivent les contrats détaillés. Les anciens bilans datés restent des archives de recette, pas une preuve de l'état actuel de toute installation.
