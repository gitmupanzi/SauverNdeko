> Relevé historique antérieur à la conversion Django. Pour l’architecture et les commandes actuelles, suivre le [skill canonique](../../../skill/SKILL.md). Les descriptions Express/Prisma ci-dessous ne décrivent plus le backend actif.

# Contrats API

## Enveloppe

Conserver une forme cohérente avec les consommateurs existants :

```json
{
  "success": true,
  "message": "...",
  "data": {}
}
```

En erreur, fournir un statut HTTP juste et, selon le gestionnaire existant, `message` et `error` avec un code et des détails exploitables. Ne pas renvoyer de stack en production.

## Familles de routes

- Santé : `GET /health`.
- Public : `/api/public/*`.
- Discussions protégées : `/api/discussions/*`.
- Authentification : `/SauverNdeko/auth/*`.
- Modules : `/api/{domaine}/{ressource}`.
- Vues : `/api/views/:schema/:view`.
- Modèles génériques : `/api/models/:model`.

Le frontend dépend notamment de `/api/referentiel`, `/api/systeme`, `/api/geolocalisation` et `/api/logistique`. Vérifier `frontend/src/services/api.js`, `auth.js` et `logistique.js` avant de renommer un chemin ou un champ.

## Liste standard

- `GET /search` avant `GET /:id` ;
- `GET /` pour la liste ;
- `POST /`, `PUT /:id`, `DELETE /:id` uniquement si l'écriture est autorisée ;
- query standard : `take`, `skip`, `q`, `includeInactive` ;
- limite maximale habituelle : 500.

## Authentification

- Token d'accès dans `Authorization: Bearer ...`.
- Refresh token traité uniquement par les endpoints prévus.
- `verifyToken` établit l'identité serveur; `requireAdmin` contrôle l'autorisation administrative.
- Ne pas déduire un rôle depuis une valeur envoyée par le client.

## Changements incompatibles

En cas de modification d'URL, payload, nom de colonne ou enveloppe : mettre à jour le service frontend, les mappers, les écrans et la documentation dans la même évolution, ou fournir une compatibilité transitoire explicite.

