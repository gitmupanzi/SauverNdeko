# SauverNdeko

SauverNdeko est une plateforme web modulaire orientee sante, services, orientation et administration de donnees.  
Le projet est pense comme une base reutilisable pour plusieurs organisations, plusieurs territoires et plusieurs pays.

## Vision

Le produit ne doit pas etre limite a une structure unique ni a un seul contexte national.  
Il doit pouvoir etre adapte a :

- une entreprise privee
- une ONG
- un ministere
- un reseau de structures de sante
- un programme pays
- un groupe multi-pays

SauverNdeko est donc concu comme une application :

- multi-organisation
- multi-pays
- configurable par referentiels
- extensible par schemas metier
- exploitable via une administration web avancee

## Objectif produit

Fournir une base web robuste pour :

- publier des informations et services publics
- gerer des comptes et profils utilisateurs
- ouvrir des discussions et interactions metier
- administrer des donnees de reference et de geolocalisation
- parametrer des comportements differents selon le contexte connecte

## Structure du projet

- `frontend/` : application React + Vite
- `backend/` : API Node.js + Express + Prisma
- `SQL/` : scripts SQL par schema

## Capacites fonctionnelles

### Espace public

- page d'accueil
- consultation de contenus publics
- catalogue de produits ou services
- consultation de structures
- consultation d'experts ou professionnels
- recherche publique

### Espace connecte

- inscription
- connexion
- verification de session
- deconnexion
- profil utilisateur
- discussions

### Administration

- lecture de vues PostgreSQL
- CRUD sur certains objets metier
- tri, filtres, export, colonnes visibles et gelees
- parametrage des listes deroulantes
- gestion de la portee des parametres

## Portee et standardisation

Le projet adopte un principe de portee pour ses reglages d'administration.  
Les parametrages peuvent etre definis a differents niveaux :

- `global`
- `country`
- `entity`

Ce mecanisme permet :

- d'avoir une base commune internationale
- d'appliquer des adaptations locales par pays
- de specialiser certains comportements par organisation ou entite

Le panneau `Correspondances FK` de l'administration s'inscrit dans cette logique :

- configuration partagee via le backend
- historique des changements
- portee cible determinee automatiquement selon le contexte connecte

## Architecture technique

### Frontend

Technologies principales :

- React 19
- React Router
- Vite
- Bootstrap
- Bootstrap Icons

Points d'entree :

- `frontend/src/main.jsx`
- `frontend/src/App.jsx`

### Backend

Technologies principales :

- Node.js
- Express
- Prisma Client
- PostgreSQL
- JWT
- bcryptjs

Points d'entree :

- `backend/app.js`
- `backend/server.js`

## Base de donnees

Le projet repose sur PostgreSQL avec Prisma.

Schema Prisma principal :

- `backend/prisma/schema.prisma`

Schemas PostgreSQL declares :

- `analytics`
- `communication`
- `geolocalisation`
- `logistique`
- `operations`
- `professionnel`
- `referentiel`
- `systeme`

Le decoupage par schemas permet :

- d'isoler les domaines metier
- de faire evoluer un module sans casser les autres
- de mieux adapter la plateforme a des contextes pays differents

## Administration actuelle

L'administration couvre deja plusieurs familles de besoins :

- vues systeme
- vues referentiel
- vues geolocalisation
- CRUD cible sur les tables principales
- parametrage partage des listes et correspondances

Exemples de vues exploitees :

- `systeme.V_Audit_log`
- `systeme.V_Admin_UI_Setting_Audit`
- `systeme.V_Entite_Localisation_Detail`
- `systeme.V_Licence_active`
- `systeme.V_Login_history`
- `systeme.V_User_profil`
- `referentiel.V_Generique`
- `referentiel.V_CategorieGenerique`
- vues `geolocalisation.V_*`

## API importante

### Public

- `GET /health`
- `GET /api/public/stats`
- `GET /api/public/articles`
- `GET /api/public/pharmacies`
- `GET /api/public/experts`
- `GET /api/public/maladies`

### Authentification

Prefixe : `/SauverNdeko/auth`

- `POST /SauverNdeko/auth/login`
- `POST /SauverNdeko/auth/register`
- `POST /SauverNdeko/auth/refresh`
- `POST /SauverNdeko/auth/logout`
- `GET /SauverNdeko/auth/me`
- `PUT /SauverNdeko/auth/me`
- `GET /SauverNdeko/auth/verify`

### Administration

- `GET /api/views`
- `GET /api/views/:schema/:view`
- `GET /api/models`
- `GET /api/models/:model`
- `GET /api/models/:model/:id`
- `POST /api/models/:model`
- `PUT /api/models/:model/:id`
- `DELETE /api/models/:model/:id`
- `GET /api/admin-ui-settings`
- `PUT /api/admin-ui-settings`

## Pages frontend

- `/`
- `/produits`
- `/pharmacies`
- `/experts`
- `/maladies`
- `/login`
- `/register`
- `/profil`
- `/discussions`
- `/admin`

## Installation

### Backend

```powershell
cd backend
npm install
```

### Frontend

```powershell
cd ../frontend
npm install
```

### Prisma

```powershell
cd ../backend
npm run prisma:generate
```

## Variables d'environnement

Le backend charge ses variables depuis `backend/.env`.

Exemple minimal :

```env
DATABASE_URL=postgresql://user:password@localhost:5432/sauverndeko
PORT=5000
NODE_ENV=development
JWT_SECRET=change_me
JWT_REFRESH_SECRET=change_me_too
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7
```

## Orientation long terme

SauverNdeko doit rester un socle adaptable.  
Les evolutions ciblees incluent notamment :

- multi-tenant plus explicite
- tableaux de bord et reporting
- operations logistiques
- paiements et facturation
- parametrage metier par pays
- localisation multilingue
- gouvernance des referentiels

## Documentation complementaire

- `cahier_charge.md`
- `SQL/`
- `backend/docs/`
