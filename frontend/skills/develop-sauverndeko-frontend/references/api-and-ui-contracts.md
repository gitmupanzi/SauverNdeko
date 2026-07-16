# Contrats API et interface

## Réseau

`API_BASE_URL` provient de `VITE_API_BASE_URL` et reste vide lorsque le proxy Vite est utilisé.

`requestJson` :

- ajoute `Accept: application/json` ;
- ajoute `Content-Type` lorsqu'un corps est envoyé ;
- ajoute le bearer token si `requiresAuth` ;
- normalise les erreurs HTTP et réseau.

Les helpers publics peuvent retourner `null` lors d'une indisponibilité. Les composants doivent distinguer fallback public et erreur d'une action authentifiée.

## Authentification

- Utiliser `/SauverNdeko/auth/*` via `services/auth.js`.
- Persister ensemble utilisateur, access token et refresh token avec les helpers existants.
- Restaurer la session par verify/refresh/me selon le flux existant.
- Après logout, nettoyer le stockage et rediriger hors des routes protégées.

## Administration

- Les modèles connus ont des routes modulaires dans `ADMIN_MODEL_ROUTE_MAP`; les autres passent par `/api/models/:model`.
- Les vues sont lues par `/api/views/:schema/:view`.
- Les réglages UI et correspondances doivent respecter la portée et rester partagés côté backend.
- Ne pas supposer qu'un nom de colonne visible est la clé Prisma : vérifier la configuration et le mapper.

## Logistique

- Les services utilisent `/api/logistique/*`.
- Limite courante des lectures de vues : `take: 500`.
- Les dates de filtre dépendent de l'écran : `DateCmd`, `DateMvt`, échéance ou date de facture.
- Mouvements : lecture seule.
- Les champs calculés de commande, stock et règlement viennent des vues; afficher leurs états sans les réinterpréter différemment.
- Les dates et valeurs automatiques de base ne doivent pas être forcées dans les payloads de création.

## États UI obligatoires

Pour chaque lecture ou mutation, traiter : chargement, vide, erreur, succès, confirmation destructive et action en cours. Après mutation, rafraîchir la projection de vue plutôt que modifier localement un calcul dérivé fragile.

