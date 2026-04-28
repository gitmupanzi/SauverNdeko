# Cahier de charge - SauverNdeko

## 1. Contexte

SauverNdeko est un projet d'application web modulaire destine a la sante, a l'orientation, aux services et a l'administration de donnees.

Le projet ne doit pas etre pense comme un site local ou comme une solution reservee a un seul pays.  
Il doit pouvoir etre reutilise par :

- plusieurs entreprises
- plusieurs ONG
- plusieurs institutions publiques
- plusieurs programmes nationaux
- plusieurs pays ou groupes de pays

L'architecture actuelle repose sur :

- `frontend/` : React + Vite
- `backend/` : Node.js + Express + Prisma
- `PostgreSQL` : base de donnees structuree par schemas

## 2. Vision produit

SauverNdeko doit devenir une plateforme web configurable capable de separer clairement :

- l'experience publique
- l'experience connectee
- l'experience d'administration
- les referentiels communs
- les adaptations locales par entite ou par pays

Le produit doit offrir un socle standard international, tout en laissant chaque contexte activer ou adapter :

- ses nomenclatures
- ses structures
- ses niveaux geographiques
- ses listes deroulantes
- ses regles d'administration

## 3. Objectif principal

Construire une application web metier claire, securisee, evolutive et internationalisable, basee sur :

- un frontend moderne
- un backend securise
- une base PostgreSQL exploitable par API, vues et administration
- un systeme de parametrage par portee

## 4. Objectifs specifiques

- proposer une base web reusable entre organisations
- separer les referentiels globaux et les adaptations locales
- permettre des reglages par portee `global`, `country`, `entity`
- exposer une administration professionnelle exploitable par des equipes non techniques
- preparer l'application a des extensions multi-pays et multi-organisations

## 5. Perimetre fonctionnel

### 5.1 Espace public

- page d'accueil
- catalogue public
- consultation de structures
- consultation d'experts ou professionnels
- consultation de contenus de reference
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
- consultation de vues d'administration
- CRUD cible sur des donnees metier
- parametrage des listes deroulantes
- parametrage partage selon la portee
- historique des changements de parametrage

### 5.4 Evolutions futures

- commandes
- paiements
- reporting
- notifications
- tableaux de bord
- supervision multi-entites
- multi-langue

## 6. Acteurs

### 6.1 Visiteur public

- consulte les informations publiques
- recherche un produit, une structure ou un expert
- identifie un service ou une orientation utile

### 6.2 Utilisateur connecte

- accede a son espace
- consulte et modifie son profil
- suit ses discussions

### 6.3 Professionnel ou expert

- recoit ou consulte des echanges
- repond aux demandes
- exploite les donnees qui lui sont accessibles

### 6.4 Structure ou organisation

- est visible dans les modules publics ou prives
- porte une partie du contexte fonctionnel
- peut avoir ses reglages propres selon la portee

### 6.5 Administrateur

- administre les vues, tables et reglages
- supervise la qualite des donnees
- gere les correspondances et les listes de support

## 7. Principes directeurs

### 7.1 Standard international

Le produit doit pouvoir fonctionner dans plusieurs pays sans redev lourd de code.

Implications :

- vocabulaire adaptable
- referentiels parametrables
- niveaux geographiques non figes a un seul modele national
- logique de portee applicable a differents contextes

### 7.2 Portee des reglages

Les reglages d'administration doivent supporter au minimum :

- `global`
- `country`
- `entity`

Ordre logique de lecture :

1. portee la plus specifique disponible
2. fallback vers une portee plus large
3. fallback final vers `global`

### 7.3 Gouvernance des donnees

Les donnees de reference et les correspondances doivent etre :

- auditables
- historisees
- administrables sans changer le code
- partageables entre utilisateurs autorises

## 8. Modules de l'application

### 8.1 Authentification

Fonctions attendues :

- login
- register
- logout
- verification de session
- protection des routes
- stockage et renouvellement des tokens

### 8.2 Catalogue et consultation

Fonctions attendues :

- affichage des produits ou services
- affichage des structures
- affichage des professionnels
- affichage de contenus de reference
- recherche publique

### 8.3 Profil utilisateur

Fonctions attendues :

- lecture du profil
- modification d'informations autorisees
- prise en compte du contexte utilisateur connecte

### 8.4 Discussions

Fonctions attendues :

- creation ou reutilisation d'une discussion
- liste des discussions
- lecture des messages
- envoi de messages
- persistance PostgreSQL

### 8.5 Administration

Fonctions attendues :

- lecture de vues backend
- CRUD cible
- tri, filtres, export, pagination
- gel et visibilite des colonnes
- parametres partages des listes
- comportement hierarchique des listes
- historique des parametres

## 9. Etat actuel

### 9.1 Deja en place

- frontend React + Vite
- backend Express + Prisma
- connexion PostgreSQL
- authentification
- session restauree
- profil utilisateur
- discussions protegees
- administration web
- parametrage partage des listes via backend

### 9.2 En consolidation

- standardisation des vues admin
- couverture des schemas `referentiel`, `systeme` et `geolocalisation`
- stabilisation de la logique de portee
- documentation internationale

### 9.3 A venir

- exploitation plus fine du scope `country`
- parametrage multi-entites
- multi-langue
- tableaux de bord
- autres schemas metier

## 10. Administration cible

L'administration web est un composant central.

Elle doit permettre a un administrateur de :

- consulter les vues utiles
- modifier les donnees cibles
- comprendre les relations FK
- corriger les listes deroulantes
- adapter les reglages sans ouvrir le code

### 10.1 Vues prioritaires

#### Schema `systeme`

- `systeme.V_Audit_log`
- `systeme.V_Admin_UI_Setting_Audit`
- `systeme.V_Entite_Localisation_Detail`
- `systeme.V_Licence_active`
- `systeme.V_Login_history`
- `systeme.V_User_profil`

#### Schema `referentiel`

- `referentiel.V_Generique`
- `referentiel.V_CategorieGenerique`

#### Schema `geolocalisation`

- `geolocalisation.V_Niveau_0`
- `geolocalisation.V_Niveau_1_Old`
- `geolocalisation.V_Niveau_1`
- `geolocalisation.V_Niveau_2`
- `geolocalisation.V_Niveau_3`
- `geolocalisation.V_Niveau_4`
- `geolocalisation.V_Niveau_5`

### 10.2 Capacites attendues

- recherche globale
- filtres par colonnes
- tri
- pagination
- export
- gestion des colonnes
- selection de lignes
- actions hors tableau
- panneau `Correspondances FK`

## 11. Exigences fonctionnelles prioritaires

### Priorite 1 - Fondations

- distinguer les pages publiques et privees
- securiser l'acces par JWT
- restaurer la session au chargement
- connecter le frontend au backend reel

### Priorite 2 - Standard international

- ne pas figer le produit a un seul pays
- permettre l'adaptation des niveaux geographiques
- permettre la configuration de listes par referentiels
- supporter des portees de parametrage

### Priorite 3 - Experience d'administration

- rendre les reglages comprenables et actionnables
- eviter les changements manuels dans le code pour des besoins fonctionnels
- historiser les parametres et les operations

## 12. Exigences techniques

### 12.1 Frontend

- application React moderne
- routes publiques et privees
- etat de session restaure
- administration ergonomique
- composants reutilisables

### 12.2 Backend

- API REST Express
- acces protege aux routes sensibles
- Prisma pour les CRUD standards
- vues SQL pour les lectures metier
- logique de parametrage partage

### 12.3 Base de donnees

- PostgreSQL
- schemas separes par domaine
- tables de reference
- vues de lecture
- journalisation des changements

## 13. Criteres de reussite

Le projet sera considere en bonne voie si :

- l'application fonctionne en public, connecte et admin
- les vues et CRUD sont exploitables depuis le web
- les listes deroulantes se parametrent sans modifier le code
- les reglages peuvent etre differencies par portee
- la documentation reste claire pour une reutilisation dans d'autres contextes

## 14. Orientation long terme

SauverNdeko doit rester un socle.

La cible n'est pas seulement de finaliser une application locale, mais de disposer d'une plateforme :

- reutilisable
- configurable
- administrable
- extensible
- compatible avec des besoins multi-pays et multi-organisations
