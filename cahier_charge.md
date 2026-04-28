# Cahier de charge - SauverNdeko Application Web

## 1. Contexte

SauverNdeko est un projet d'application web de sante et d'orientation medicale.

Le produit evolue d'un site public vitrine vers une application web complete, avec :

- authentification
- espace utilisateur
- discussions
- administration
- modules metier relies a PostgreSQL

L'application est structuree en deux parties :

- `frontend/` : interface web React
- `backend/` : API Node.js + Express + Prisma + PostgreSQL

Ce document sert de reference fonctionnelle, technique et organisationnelle pour le projet.

## 2. Vision du produit

SauverNdeko doit devenir une application web capable de proposer une experience claire entre :

- consultation publique
- espace connecte
- espace administration

L'application doit permettre a un utilisateur de :

- rechercher des informations utiles en sante
- consulter des produits, structures et experts
- creer un compte et se connecter
- gerer son profil
- echanger via des discussions
- acceder a des services et modules metier plus avances dans la suite du projet

## 3. Objectif principal

Transformer SauverNdeko en application web metier, avec une architecture claire, un frontend moderne, un backend securise et une base de donnees PostgreSQL exploitable a travers Prisma et des vues admin.

## 4. Objectifs specifiques

- mettre en place un systeme d'authentification fonctionnel
- distinguer clairement les pages publiques et les pages privees
- relier toutes les donnees frontend au backend
- securiser l'exposition des donnees
- creer une administration web exploitable
- preparer la plateforme pour les futurs modules metier

## 5. Perimetre fonctionnel

### 5.1 Espace public

- page d'accueil
- consultation des produits
- consultation des pharmacies et structures
- consultation des experts
- consultation des maladies
- recherche publique

### 5.2 Espace utilisateur connecte

- inscription
- connexion
- verification de session
- deconnexion
- consultation du profil
- mise a jour du profil
- acces aux discussions

### 5.3 Espace administration

- acces reserve aux administrateurs
- consultation des vues d'administration
- CRUD metier sur certaines donnees
- recherche globale, filtres, tri et export

### 5.4 Evolutions futures

- historique utilisateur
- commandes
- paiements
- notifications
- tableaux de bord
- reporting

## 6. Acteurs

### 6.1 Visiteur public

- consulte les informations publiques
- recherche un produit, une structure ou un expert
- peut etre oriente vers une prise de contact

### 6.2 Utilisateur connecte

- se connecte a l'application
- consulte et modifie son profil
- gere ses discussions

### 6.3 Expert / Professionnel

- recoit des discussions
- consulte les messages qui le concernent
- repond aux utilisateurs

### 6.4 Structure / Pharmacie

- est visible dans l'espace public
- peut etre cible de discussions ou d'autres interactions metier

### 6.5 Administrateur

- accede a l'interface d'administration
- consulte les vues systeme
- effectue des operations de supervision et de gestion

## 7. Modules de l'application web

### 7.1 Authentification

Fonctions attendues :

- login
- register
- logout
- verification de session
- gestion du token
- protection des routes privees

### 7.2 Catalogue public

Fonctions attendues :

- affichage des articles
- affichage des structures
- affichage des experts
- affichage des maladies
- recherche publique

### 7.3 Profil utilisateur

Fonctions attendues :

- affichage des informations de l'utilisateur connecte
- modification de certaines informations personnelles

### 7.4 Discussions

Fonctions attendues :

- creation ou reutilisation d'une discussion
- liste des discussions d'un utilisateur
- lecture des messages
- envoi de messages
- persistance en base PostgreSQL

### 7.5 Administration

Fonctions attendues :

- lecture de vues backend
- exploitation des vues du schema `systeme`
- CRUD sur les donnees reliees
- filtres, tri, recherche et export

## 8. Etat actuel du projet

### 8.1 Deja en place

- frontend React + Vite
- backend Express + Prisma
- connexion a PostgreSQL
- inscription et connexion
- verification de session
- deconnexion
- profil utilisateur
- discussions protegees
- interface administration

### 8.2 En consolidation

- enrichissement des modules metier
- stabilisation des parcours utilisateurs
- documentation et cadrage fonctionnel

### 8.3 A venir

- commandes
- paiements
- historiques
- notifications
- autres schemas metier au-dela du schema `systeme`

## 9. Administration cible

L'administration web est un composant central du projet.

Pour le travail actuel, l'accent est mis en priorite sur le schema `systeme`.

### Vues d'administration prioritaires

#### Schema `systeme`

- `systeme.V_Audit_log`
- `systeme.V_Entite_Localisation_Detail`
- `systeme.V_Licence_active`
- `systeme.V_Login_history`
- `systeme.V_User_profil`

#### Schema `referentiel`

- `referentiel.V_Generique`

### Capacites attendues dans les tableaux admin

- recherche globale
- filtres par colonnes
- tri
- pagination
- export
- colonnes visibles
- gel et degel de colonnes
- redimensionnement des colonnes
- selection de lignes
- actions hors du tableau pour garder une bonne lisibilite

## 10. Exigences fonctionnelles prioritaires

### Priorite 1 - Fondations application web

- distinguer les pages publiques et les pages privees
- utiliser un systeme d'authentification JWT
- verifier la session au chargement du frontend
- relier les donnees frontend au backend reel

### Priorite 2 - Espace utilisateur

- afficher l'etat connecte / non connecte
- permettre la modification du profil
- proteger les routes privees

### Priorite 3 - Discussions

- ouvrir une discussion a partir d'un utilisateur authentifie
- lister les discussions de l'utilisateur
- persister les messages en base

### Priorite 4 - Administration

- permettre aux administrateurs d'exploiter les vues systeme
- proposer une experience de tableau professionnelle
- offrir les actions metier utiles sans nuire a la lisibilite

## 11. Exigences techniques

### 11.1 Frontend

- React
- Vite
- React Router
- organisation claire en :
  - `components/`
  - `pages/`
  - `services/`
  - `hooks/`
  - `contexts/`
  - `data/`

### 11.2 Backend

- Node.js
- Express
- Prisma Client
- PostgreSQL
- reponses JSON coherentes

Format attendu :

```json
{
  "success": true,
  "data": {}
}
```

ou

```json
{
  "success": false,
  "message": "Message d'erreur"
}
```

### 11.3 Base de donnees

- PostgreSQL multi-schemas
- schema Prisma principal dans `backend/prisma/schema.prisma`
- scripts SQL de support dans `SQL/`

## 12. Exigences de securite

- ne jamais exposer les mots de passe
- limiter les champs sensibles retournes par les endpoints
- proteger les routes privees et admin
- verifier les droits avant les operations critiques
- journaliser les operations importantes si necessaire

## 13. Exigences UX/UI

L'application web doit :

- conserver une identite claire et professionnelle
- distinguer le mode public, connecte et administrateur
- afficher des etats de chargement, erreur, vide et succes
- proposer une administration lisible et efficace
- privilegier une navigation simple et une lecture confortable des tableaux

## 14. Routes cibles

### Backend Auth

- `POST /SauverNdeko/auth/login`
- `POST /SauverNdeko/auth/register`
- `POST /SauverNdeko/auth/logout`
- `POST /SauverNdeko/auth/refresh`
- `GET /SauverNdeko/auth/me`
- `PUT /SauverNdeko/auth/me`
- `GET /SauverNdeko/auth/verify`

### Backend Public

- `GET /api/public/articles`
- `GET /api/public/pharmacies`
- `GET /api/public/experts`
- `GET /api/public/maladies`
- `GET /api/public/stats`

### Backend Discussions

- `POST /api/discussions/start`
- `GET /api/discussions`
- `GET /api/discussions/:id/messages`
- `POST /api/discussions/:id/messages`

### Frontend

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

## 15. Roadmap recommande

### Phase 1 - Fondations web

- consolider l'authentification
- fiabiliser les routes protegees
- maintenir la coherence frontend / backend

### Phase 2 - Experience utilisateur

- enrichir l'espace profil
- consolider les discussions
- fluidifier les parcours connectes

### Phase 3 - Administration metier

- completer le schema `systeme`
- etendre le CRUD metier
- optimiser l'experience des vues admin

### Phase 4 - Extensions

- commandes
- paiements
- historiques
- reporting

## 16. Risques et points d'attention

- Prisma genere dans un environnement Windows / Dropbox peut parfois poser des contraintes de verrouillage
- certaines donnees de test peuvent manquer selon les schemas ou les vues
- les modules metier ne sont pas tous encore finalises
- l'administration doit rester ciblee et lisible meme si le volume de donnees augmente

## 17. Definition de succes

SauverNdeko pourra etre considere comme une vraie application web aboutie lorsque :

- un utilisateur peut creer un compte et se connecter
- les pages privees sont correctement protegees
- le frontend travaille avec les vraies donnees backend
- les discussions sont persistantes
- l'administration est exploitable pour les donnees systeme
- les espaces public, utilisateur et administration sont clairement separes
