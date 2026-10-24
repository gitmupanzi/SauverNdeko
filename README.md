# SauverNdeko

## Évolution ERP — état du 24 octobre 2026

La cible produit est désormais un ERP modulaire commercialisable. La logistique en constitue un domaine, aux côtés du catalogue santé/services, des discussions et de l’administration. Multi-organisation et multi-pays sont des objectifs à valider dans les droits, les données et la recette.

Le code comprend déjà /logistique et ses écrans articles, commandes, lignes, mouvements, règlements, audit, alertes, consommation, couverture et dashboard. Cette présence ne certifie pas encore une chaîne achats/ventes complète ni une version prête à vendre.

Le backend actif est désormais Django + Django REST Framework, connecté au PostgreSQL existant. Les schémas métier sont conservés. Sur autorisation ultérieure du propriétaire, les dix tables natives Django sont installées dans public. L’ancien backend Express/Prisma, ses dépendances et ses lanceurs npm ont été supprimés à la demande du propriétaire ; Node.js reste nécessaire au frontend Vite. Voir le [guide Django](backend/README.md), le [bilan technique actuel](SQL/documentation/Audit_Metier_20261024.md) et la [décision d’accès PostgreSQL](backend/skill/references/decision-acces-postgresql.md).

Documentation de travail :

- [Cartographie et écarts constatés](skills/sauverndeko-erp/references/cartographie.md).
- [Inventaire des modèles, routes et objets SQL](skills/sauverndeko-erp/references/inventaire-technique.md).
- [Trajectoire ERP et critères des prochains lots](skills/sauverndeko-erp/references/trajectoire-erp.md).
- [Principes repris d’imf_BB](skills/sauverndeko-erp/references/transposition-imf-bb.md).
- [Skill transverse ERP](skills/sauverndeko-erp/SKILL.md), [backend](backend/skill/SKILL.md), [frontend](frontend/skill/SKILL.md).

Les priorités avant livraison client sont la protection des routes modulaires, l’isolation par organisation, les agrégats exhaustifs, les commentaires PostgreSQL et les consultations 360 avec indicateurs cliquables. Elles sont documentées et restent à implémenter ou vérifier.


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
- `backend/` : API Python + Django REST Framework
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

Python 3.12, Django 5.2 LTS, Django REST Framework, psycopg, JWT et bcrypt. Points d’entrée : backend/manage.py, backend/config/urls.py et backend/start.ps1.

## Base de donnees

Le projet repose sur PostgreSQL avec Django/psycopg.

Les 31 tables métier installées sont décrites par des modèles Django unmanaged dans backend/apps/core/models.py. Le registre backend/apps/core/registry.json décrit les tables et les 48 vues autorisées. Les modèles Django et ce registre constituent la référence applicative ; l’ancien schéma Prisma et son client généré ont été supprimés.

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
- `/logistique`

## Installation

### Backend Django

~~~powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\start.ps1
~~~

Conserver backend/.env existant. La connexion est en lecture seule par défaut ; les migrations métier automatiques et la création d’une base de recette ne doivent pas être exécutées. Le socle natif public utilise la commande migrate contrôlée. Voir backend/README.md pour les vérifications et l’activation ultérieure des écritures métier.

### Frontend

~~~powershell
cd ../frontend
npm install
npm run dev
~~~

## Variables d'environnement

Le backend charge ses variables depuis `backend/.env`.

Exemple minimal :

```env
DATABASE_URL=postgresql://user:password@localhost:5432/sauverndeko
DJANGO_DEBUG=0
SAUVERNDEKO_DB_READ_ONLY=1
JWT_SECRET=<secret_existant_long_et_aleatoire>
JWT_REFRESH_SECRET=<autre_secret_existant_long_et_aleatoire>
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


## Commentaires appliqués en base — 24 octobre 2026

Les huit schémas applicatifs de la base locale SauverNdeko possèdent désormais 1553 commentaires couvrant tables, vues, colonnes, fonctions/procédures, triggers, séquences, contraintes et index. Application, réexécution et retour arrière vérifiés sur une copie isolée sans données ; les textes sont vérifiés après commit dans la base locale et les définitions restent inchangées.

Voir le [bilan PostgreSQL et les scripts](SQL/documentation/Commentaires_PostgreSQL_20261024.md). Les écarts de sécurité, d’isolation et de calcul restent des chantiers distincts.


## Logistique fiabilisée — évolution 20261024_02

Les vues et triggers logistiques ont été améliorés et appliqués en local : totaux cohérents sous concurrence, recalcul une fois par commande et instruction, clôtures protégées, alertes et couverture corrigées, audit filtré plus efficace. Données existantes inchangées. La recette PostgreSQL historique en Node a été retirée avec l’ancien backend ; ses résultats antérieurs restent documentés dans SQL/documentation. Le backend se contrôle avec manage.py check et verifier_backend en lecture seule ; les recettes métier et leurs résultats sont documentés dans SQL/documentation/Audit_Metier_20261024.md.

Voir le [bilan, les mesures et les migrations](SQL/documentation/Logistique_Fiabilisation_20261024.md).


## Documents et exports — charte SauverNdeko

Le [skill de mise en forme](skills/document-mise-en-forme/SKILL.md), version 3.0 du 24 octobre 2026, définit la charte Excel/Word/PDF, le logo du projet, les modèles ERP et les contrôles de parité. Il respecte l’identité de chaque organisation utilisatrice et les données issues du backend.

Les règles et contrôles du skill sont disponibles ; les helpers d’export applicatifs actuels restent à raccorder aux vrais formats natifs pour déclarer leurs fichiers conformes.


## Démarrage Windows et réseau local

Les fichiers demarrer.bat, arreter.bat, redemarrer.bat et adresse-reseau.bat sont disponibles à la racine. Ils pilotent Django et Vite, ajustent les ports et conservent les processus des autres projets. Pour accéder depuis un autre PC : demarrer.bat -Reseau. Voir [les instructions de lancement](docs/lancement-local.md). PostgreSQL reste en lecture seule par défaut.


## Tables natives Django

Les tables auth/admin/contenttypes/sessions sont installées et commentées dans public ; les données des 30 tables métier sont inchangées. Voir [le bilan PostgreSQL](SQL/documentation/Django_Public_20261024.md) et [la recommandation de séparation public/systeme](SQL/documentation/Decision_Systeme_Public_20261024.md).
