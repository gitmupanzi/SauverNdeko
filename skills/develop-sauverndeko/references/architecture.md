# Architecture SauverNdeko

## Couches

- `SQL/` : DDL, vues, fonctions, procédures, triggers, scénarios et scripts de contrôle PostgreSQL.
- `backend/prisma/schema.prisma` : modèles applicatifs introspectés et mapping multi-schémas.
- `backend/src/modules/` : API modulaire par domaine.
- `backend/controllers/`, `routes/`, `services/` : API historique ou transverse encore active.
- `frontend/src/services/` : contrat réseau centralisé.
- `frontend/src/pages/` et `components/` : écrans publics, connectés, admin et logistique.

## Domaines

| Schéma | Responsabilité | Objets principaux |
|---|---|---|
| `referentiel` | catégories et valeurs configurables | `T_CategorieGenerique`, `T_Generique`, vues associées |
| `systeme` | utilisateurs, entités, licences, audit, réglages et correspondances FK | tables `T_*`, vues d'administration |
| `geolocalisation` | hiérarchie générique de niveaux 0 à 5 | `T_Niveau_*`, `V_Niveau_*`, vues de couverture |
| `logistique` | articles, commandes, lignes, mouvements, règlements et stock | tables, vues métier, procédures et triggers |
| `operations` | caisse et paiements | modèles Prisma et vues de paiement |
| `professionnel` | professionnels et rattachements | modèles Prisma et vues de détail |
| `communication` | chat, communications et discussions | modèles Prisma et vues de communication |
| `analytics` | recherche et lectures analytiques | `T_Recherche`, `V_Recherche` |

## Parcours de modification

1. Identifier la table d'écriture ou la vue de lecture.
2. Vérifier les règles SQL et les relations Prisma.
3. Vérifier le montage de route dans `backend/app.js` et `backend/src/modules/register-module-routes.js`.
4. Vérifier la chaîne backend `route → controller → service → repository/viewRepository → Prisma/SQL`.
5. Vérifier `frontend/src/services/api.js`, `auth.js` ou `logistique.js`.
6. Vérifier le mapper, la page et les permissions de route.

## Architecture hybride à préserver

Le backend contient des routes modulaires et des routes historiques. `app.js` monte notamment les modules avant certaines routes génériques et legacy. Avant d'ajouter une route, rechercher un endpoint équivalent pour éviter un doublon ou une interception par une route `/:id`.

Les modules standards utilisent `src/modules/shared/module-kit.js`. Plusieurs modules logistiques concentrent leur implémentation dans `index.js`; les fichiers `*.controller.js`, `*.service.js` et similaires peuvent seulement réexporter cet index.

