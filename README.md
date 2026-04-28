# SauverNdeko

SauverNdeko est une application web de sante et d'orientation medicale.  
Le projet evolue d'un site public vitrine vers une plateforme web complete avec authentification, espace utilisateur, discussions, administration et modules metier relies a une base PostgreSQL.

## Presentation

L'application permet de :

- consulter des informations publiques sur les produits, pharmacies, experts et maladies
- creer un compte utilisateur et se connecter
- gerer un profil utilisateur
- ouvrir et suivre des discussions
- administrer certaines donnees et vues du systeme depuis une interface web dediee

SauverNdeko est structure en deux parties principales :

- `frontend/` : application web React
- `backend/` : API Node.js + Express + Prisma + PostgreSQL

## Objectif du projet

L'objectif est de construire une application web metier claire, securisee et evolutive, capable de distinguer :

- l'espace public
- l'espace utilisateur connecte
- l'espace administration

Cette base doit ensuite permettre d'etendre l'application vers d'autres modules comme les commandes, paiements, historiques et tableaux de bord.

## Fonctionnalites principales

### Partie publique

- page d'accueil web
- catalogue public des produits
- affichage des pharmacies
- affichage des experts
- affichage des maladies
- recherche depuis l'interface frontend

### Partie authentifiee

- inscription
- connexion
- verification de session
- deconnexion
- affichage du profil utilisateur
- modification du profil
- acces aux discussions

### Partie administration

- acces reserve aux comptes administrateurs
- lecture de vues PostgreSQL
- CRUD sur certaines donnees du schema `systeme`
- tri, filtres, recherche globale, pagination et export
- actions d'administration hors du tableau pour garder une grille lisible

## Architecture

### Frontend

Le frontend est une application web React basee sur Vite.

Technologies principales :

- React 19
- React Router
- Bootstrap
- Bootstrap Icons

Point d'entree principal :

- `frontend/src/main.jsx`
- `frontend/src/App.jsx`

### Backend

Le backend est une API REST Node.js.

Technologies principales :

- Node.js
- Express
- Prisma Client
- PostgreSQL
- JWT
- bcryptjs

Points d'entree principaux :

- `backend/app.js`
- `backend/server.js`

## Base de donnees

Le projet utilise PostgreSQL avec Prisma.

Schema Prisma principal :

- `backend/prisma/schema.prisma`

Schemas PostgreSQL actuellement declares :

- `analytics`
- `communication`
- `geolocalisation`
- `logistique`
- `operations`
- `professionnel`
- `referentiel`
- `systeme`

Scripts SQL du projet :

- `SQL/`

## Administration actuelle

L'administration web est principalement orientee vers les vues du schema `systeme`, avec une prise en charge complementaire du schema `referentiel`.

Vues actuellement exploitees :

### Schema `systeme`

- `systeme.V_Audit_log`
- `systeme.V_Entite_Localisation_Detail`
- `systeme.V_Licence_active`
- `systeme.V_Login_history`
- `systeme.V_User_profil`

### Schema `referentiel`

- `referentiel.V_Generique`

Fonctionnalites disponibles dans les tableaux admin :

- recherche globale toujours visible
- panneau de filtres repliable
- filtres par colonnes
- tri par colonnes
- pagination
- export CSV, Excel et PDF
- affichage et masquage de colonnes
- gel de colonnes
- redimensionnement des colonnes
- selection de ligne
- actions de la ligne selectionnee en dehors du tableau

## Routes importantes

### Backend public

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

### Discussions

Prefixe : `/api/discussions`

- `POST /api/discussions/start`
- `GET /api/discussions`
- `GET /api/discussions/:id/messages`
- `POST /api/discussions/:id/messages`

### Administration

Routes protegees admin :

- `/api/views`
- `/api/models`
- `/api/utilisateurs`
- `/api/entites`
- `/api/licences`

## Pages frontend

Pages principales de l'application web :

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

Regles d'acces :

- `/profil` et `/discussions` demandent une session active
- `/admin` demande un compte administrateur

## Installation

### 1. Ouvrir le projet

```powershell
cd C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko
```

### 2. Installer le backend

```powershell
cd backend
npm install
```

### 3. Installer le frontend

```powershell
cd ..\frontend
npm install
```

### 4. Generer Prisma si necessaire

```powershell
cd ..\backend
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

## Lancement en developpement

### Backend

```powershell
cd backend
npm run dev
```

Backend par defaut :

- `http://localhost:5000`

### Frontend

```powershell
cd frontend
npm run dev
```

Frontend par defaut :

- `http://localhost:5173`

Le proxy Vite redirige :

- `/api` vers `http://localhost:5000`
- `/SauverNdeko` vers `http://localhost:5000`
- `/health` vers `http://localhost:5000`

## Scripts utiles

### Backend

```powershell
npm run dev
npm start
npm run prisma:generate
npm run prisma:pull
```

### Frontend

```powershell
npm run dev
npm run build
npm run preview
```

## Build du frontend

```powershell
cd frontend
npm run build
```

Les fichiers de build sont generes dans :

- `frontend/dist`

## Fichiers importants

- `backend/app.js` : configuration Express
- `backend/server.js` : demarrage du serveur
- `backend/prisma/schema.prisma` : modele de donnees
- `frontend/src/App.jsx` : shell et routes frontend
- `frontend/src/contexts/AuthContext.jsx` : gestion de session
- `frontend/src/pages/Admin.jsx` : administration web
- `cahier_charge.md` : cadrage fonctionnel du projet

## Etat du projet

SauverNdeko est aujourd'hui une vraie base d'application web, avec :

- un frontend React exploitable
- un backend Express connecte a PostgreSQL via Prisma
- une authentification fonctionnelle
- un profil utilisateur
- une administration deja avancee

Les prochaines evolutions logiques concernent :

- l'enrichissement des modules metier
- l'extension des traitements admin du schema `systeme`
- l'amelioration de la documentation fonctionnelle et technique
