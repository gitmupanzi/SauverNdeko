# Architecture frontend

## Entrées

- `src/main.jsx` initialise React, Router, Bootstrap et le contexte d'authentification.
- `src/App.jsx` définit le shell, la recherche, la navigation et toutes les routes principales.
- `src/styles.css` porte le thème et les mises en page globales.

## Routes

Publiques : `/`, `/produits`, `/pharmacies`, `/experts`, `/maladies`, `/login`, `/register`.

Connectées : `/profil`, `/discussions` via `ProtectedRoute`.

Administrateur : `/admin`, `/logistique` via `AdminRoute`.

## Données

- `services/api.js` : public, discussions, vues, modèles admin et réglages UI.
- `services/auth.js` et `authStorage.js` : login, register, refresh, verify, profil, logout et persistance.
- `services/logistique.js` : endpoints spécialisés de logistique.
- `services/mappers.js` : adaptation entre réponses backend et modèles d'affichage publics.
- `hooks/usePublicCatalogue.js` : chargement du catalogue et de la santé de l'API.
- `contexts/AuthContext.jsx` : état et restauration de session.

## Écrans complexes

- `pages/Admin.jsx` s'appuie sur les configurations de `pages/admin/systeme.js`, `referentiel.js` et `geolocalisation.js`.
- `pages/Logistique.jsx` orchestre les sous-écrans de `pages/logistique/`.
- Les colonnes logistiques et calculs affichés proviennent principalement des vues SQL décrites dans `../SQL/3. Schema logistique/`.

## Principe de placement

- Contrat HTTP : `services/`.
- Normalisation métier d'affichage : mapper ou helper partagé.
- État transversal : contexte ou hook.
- Présentation réutilisable : composant.
- Configuration d'un domaine admin : fichier de configuration du domaine.
- Mise en page propre à un écran : page et styles associés.

