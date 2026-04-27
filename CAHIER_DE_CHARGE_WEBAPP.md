# Cahier de charge - SauverNdeko Web App

## 1. Contexte

Une application web complete avec authentification, espace utilisateur et modules metier connectes au backend Node.js + Prisma + PostgreSQL.

Le projet est structure en deux parties :

- `frontend/` : Reactjs
- `backend/` : Node.js + Express + Prisma + PostgreSQL

Ce document sert de support de suivi fonctionnel et technique.

---

## 2. Vision du produit

Construire une application web de sante et d'orientation medicale permettant :

- la consultation publique des produits, pharmacies, experts et maladies ;
- l'authentification des utilisateurs ;
- l'ouverture de discussions avec des experts ou des structures ;
- a terme, la gestion d'un espace utilisateur et de fonctions metier plus avancees.

---

## 3. Objectif principal

Transformer SauverNdeko en application web avec login, roles, discussions persistantes et experience utilisateur claire entre espace public et espace connecte.

---

## 4. Objectifs specifiques

- Mettre en place un systeme de connexion fonctionnel.
- Distinguer les pages publiques et les pages privees.
- Permettre a un utilisateur connecte d'ouvrir et suivre ses discussions.
- Relier le frontend aux vraies routes backend.
- Proteger les donnees sensibles et limiter les informations exposees publiquement.
- Poser une base evolutive pour les commandes, recherches, paiements et historique utilisateur.

---

## 5. Perimetre fonctionnel cible

### 5.1 Partie publique

- Page d'accueil
- Liste des produits/articles
- Liste des pharmacies/structures
- Liste des experts/professionnels
- Liste des maladies
- Page discussions/contact avec transition vers espace connecte si necessaire

### 5.2 Partie authentifiee

- Login
- Logout
- Verification de session
- Profil utilisateur
- Liste de mes discussions
- Lecture d'une discussion
- Envoi de messages

### 5.3 Evolutions futures

- Inscription utilisateur
- Recuperation de mot de passe
- Tableau de bord utilisateur
- Historique de recherches
- Historique de commandes
- Paiements
- Notifications
- Administration

---

## 6. Acteurs

### 6.1 Visiteur public

- Consulte les informations publiques.
- Recherche un produit, un expert ou une structure.
- Peut initier une prise de contact.

### 6.2 Utilisateur connecte

- Se connecte a l'application.
- Consulte et gere ses discussions.
- Accede a ses informations personnelles selon son role.

### 6.3 Expert / Professionnel

- Recoit des discussions.
- Consulte les messages qui le concernent.
- Repond aux utilisateurs.

### 6.4 Structure / Pharmacie

- Peut etre cible d'une discussion.
- Peut exposer ses informations publiques.

### 6.5 Administrateur

- Gere les utilisateurs, contenus, structures et parametres.

---

## 7. Modules applicatifs

### 7.1 Authentification

Fonctions attendues :

- login
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

### 7.3 Discussions / Chat

Fonctions attendues :

- demarrer ou reutiliser une discussion
- lister les discussions d'un utilisateur
- afficher les messages par discussion
- envoyer un message
- conserver les messages dans PostgreSQL

### 7.4 Profil utilisateur

Fonctions attendues :

- afficher les informations minimales de l'utilisateur connecte
- modifier certaines informations publiques ou de contact

### 7.5 Administration

Fonctions attendues a preciser :

- gestion des comptes
- validation de contenus
- supervision des discussions si besoin

---

## 8. Exigences fonctionnelles prioritaires

### Priorite 1 - Fondations

- [ ] Le frontend doit distinguer les pages publiques et privees.
- [ ] Le backend doit exposer les routes d'authentification.
- [ ] Le login doit fonctionner avec JWT.
- [ ] Le frontend doit stocker et reutiliser le token de maniere securisee.
- [ ] Le frontend doit verifier si une session est active au chargement.

### Priorite 2 - Discussions reelles

- [ ] Un utilisateur connecte doit pouvoir ouvrir une discussion avec un expert.
- [ ] Un utilisateur connecte doit pouvoir ouvrir une discussion avec une structure.
- [ ] Les messages doivent etre enregistres dans `communication.T_Chat`.
- [ ] Les discussions doivent etre enregistrees dans `communication.T_Discussion`.
- [ ] Les discussions doivent etre listees par utilisateur.

### Priorite 3 - Experience applicative

- [ ] Ajouter un etat "connecte / non connecte" dans le frontend.
- [ ] Ajouter une navigation adaptee apres login.
- [ ] Ajouter une page profil ou espace utilisateur.
- [ ] Afficher des messages d'erreur et de succes propres.

---

## 9. Exigences techniques

### 9.1 Frontend

- React + Vite
- React Router
- Separation claire :
  - `components/`
  - `pages/`
  - `services/`
  - `hooks/`
  - `data/`

### 9.2 Backend

- Node.js + Express
- Prisma Client genere depuis `backend/generated/prisma`
- PostgreSQL
- Reponses JSON standardisees :

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

### 9.3 Securite

- Utiliser `select` dans Prisma pour limiter les champs retournes.
- Ne jamais exposer :
  - `MotdepasseUser`
  - `Is_Admin`
  - `Is_staff`
  - donnees privees inutiles
- Proteger les routes sensibles.

---

## 10. Exigences UX/UI

- Conserver le design actuel de SauverNdeko.
- Clarifier la difference entre mode public et mode connecte.
- Afficher les etats :
  - chargement
  - erreur
  - vide
  - succes
- Eviter les blocages si l'API est indisponible.
- Garder des donnees mock uniquement comme fallback temporaire.

---

## 11. Routes backend cibles

### Authentification

- [ ] `POST /SauverNdeko/auth/login`
- [ ] `POST /SauverNdeko/auth/register`
- [ ] `POST /SauverNdeko/auth/logout`
- [ ] `GET /SauverNdeko/auth/me`
- [ ] `GET /SauverNdeko/auth/verify`

### Public

- [x] `GET /api/public/articles`
- [x] `GET /api/public/pharmacies`
- [x] `GET /api/public/experts`
- [x] `GET /api/public/maladies`
- [x] `GET /api/public/stats`

### Discussions

- [x] `POST /api/discussions/start`
- [x] `GET /api/discussions`
- [x] `GET /api/discussions/:id/messages`
- [x] `POST /api/discussions/:id/messages`

---

## 12. Routes frontend cibles

- [x] `/`
- [x] `/produits`
- [x] `/pharmacies`
- [x] `/experts`
- [x] `/maladies`
- [x] `/discussions`
- [ ] `/login`
- [ ] `/profil`
- [ ] routes protegees

---

## 14. Backlog recommande

### Phase 1 - Application web avec login

- [ ] Creer la page `Login`
- [ ] Ajouter un service frontend `auth`
- [ ] Gerer stockage token
- [ ] Ajouter `AuthContext` ou hook equivalent
- [ ] Ajouter protection des routes privees
- [ ] Afficher le nom de l'utilisateur connecte
- [ ] Ajouter bouton `Se connecter / Se deconnecter`

### Phase 2 - Consolidation du chat

- [ ] Brancher les discussions sur le vrai login
- [ ] Associer automatiquement les discussions a l'utilisateur authentifie
- [ ] Afficher l'etat lu/non lu
- [ ] Ajouter rafraichissement des messages
- [ ] Prevoir futur temps reel si necessaire

### Phase 3 - Espace utilisateur

- [ ] Page profil
- [ ] Historique discussions
- [ ] Historique recherches
- [ ] Historique commandes

### Phase 4 - Administration

- [ ] Definir les roles
- [ ] Ecran d'administration
- [ ] Gestion des contenus publics
- [ ] Supervision des utilisateurs

---

## 15. Risques et points d'attention

- Le backend utilise Prisma genere dans un dossier synchronise par Dropbox.
- `prisma generate` peut echouer sous Windows si le moteur est verrouille.
- Les donnees de base peuvent etre vides, ce qui bloque certains tests fonctionnels.
- L'authentification frontend n'est pas encore totalement branchee au chat.
- Il faut eviter toute fuite de donnees sensibles dans les endpoints publics.

---

## 16. Pre requis de mise en oeuvre

- [ ] Base PostgreSQL accessible
- [ ] `.env` configure
- [ ] Prisma valide et genere
- [ ] Au moins un utilisateur de test
- [ ] Au moins une structure
- [ ] Au moins un professionnel

---

## 17. Indicateurs de progression

### Etat global

- Frontend public : En cours
- Backend public : En cours
- Authentification : A finaliser
- Discussions persistantes : En cours
- Espace utilisateur : A demarrer
- Administration : A cadrer

---

## 18. Journal de suivi

### Decisions

- [ ] Decision 1 :
- [ ] Decision 2 :
- [ ] Decision 3 :

### Blocages

- [ ] Blocage 1 :
- [ ] Blocage 2 :

### Prochaines actions

- [ ] Creer la page login
- [ ] Brancher le token frontend
- [ ] Ajouter route protegee pour les discussions
- [ ] Ajouter un seed minimal pour les tests

---

## 19. Definition de succes

Le projet pourra etre considere comme une vraie application web lorsque :

- un utilisateur peut se connecter ;
- son identite est connue du frontend ;
- les pages privees sont protegees ;
- les discussions et messages sont rattachés a cet utilisateur ;
- les donnees publiques et privees sont bien separees ;
- aucune donnee sensible n'est exposee publiquement.
