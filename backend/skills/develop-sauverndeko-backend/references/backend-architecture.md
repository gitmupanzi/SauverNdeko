> Relevé historique antérieur à la conversion Django. Pour l’architecture et les commandes actuelles, suivre le [skill canonique](../SKILL.md). Les descriptions Express/Prisma ci-dessous ne décrivent plus le backend actif.

# Architecture backend

## Entrées et montage

- `server.js` démarre le serveur.
- `app.js` configure Express, CORS, parseurs, `/health`, routes et gestionnaire d'erreur.
- `src/modules/register-module-routes.js` monte les modules modernes.
- `routes/` et `controllers/` contiennent les fonctionnalités historiques ou transversales : public, auth, discussions, vues et CRUD générique.

## Modules modernes

Domaines enregistrés :

- `referentiel` : catégories génériques et génériques ;
- `systeme` : utilisateurs, entités, localisations, licences, logins, audit, correspondances FK et réglages UI ;
- `geolocalisation` : niveaux 0 à 5 et hiérarchie ;
- `logistique` : articles, commandes, détails, règlements, mouvements, stock et dashboard.

Le module kit fournit validation de base, mapper, repository Prisma, repository de vue, service, controller et routes CRUD. Utiliser `buildStandardModule` lorsqu'un module suit ce contrat.

Plusieurs modules logistiques implémentent tout dans `index.js`; les fichiers spécialisés sont des réexports. Modifier l'implémentation propriétaire, pas le fichier alias.

## Lecture et écriture

- Repository de table : CRUD Prisma sur `T_*`.
- Repository de vue : lecture SQL sur `V_*` pour les projections enrichies.
- Service : règles métier et orchestration.
- Mapper/validation : frontière entre JSON HTTP et types Prisma.

Les vues ne sont pas des cibles de mutation. Une création ou modification retourne idéalement la projection métier relue après écriture lorsque l'interface en dépend.

## Architecture hybride

`app.js` monte à la fois les modules, les routes logistiques legacy, les routes de domaine génériques et les routes de vues. Rechercher les collisions avant d'ajouter un endpoint. Préserver l'ordre de montage, car une route générique peut intercepter un chemin plus spécifique.

## Couplage SQL

Consulter le skill général `../skills/develop-sauverndeko` depuis la racine du dépôt et le dossier `../SQL/` depuis `backend/` pour les règles de base. Pour la logistique, les triggers et procédures gèrent les stocks, mouvements, totaux et blocages de commandes clôturées.
