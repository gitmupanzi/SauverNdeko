---
name: develop-sauverndeko-backend
description: Développer, corriger et valider le backend SauverNdeko en Node.js CommonJS, Express 4, Prisma 6 et PostgreSQL. Utiliser pour les routes et contrôleurs publics, authentification JWT, discussions, administration, modules `referentiel`, `systeme`, `geolocalisation` et `logistique`, repositories de tables ou vues, validation et mapping des payloads, sérialisation Prisma, middleware de sécurité, contrats d'erreur et intégration avec les schémas SQL SauverNdeko.
---

# Développer le backend SauverNdeko

Travailler depuis `backend/` et relier toute modification de données au schéma PostgreSQL réel situé dans `../SQL/`.

## Procédure

1. Lire [references/backend-architecture.md](references/backend-architecture.md).
2. Vérifier les montages et routes avec `scripts/inspect_backend.py --routes`, puis rechercher le concept avec `--query`.
3. Lire le modèle dans `prisma/schema.prisma` et le DDL ou la vue SQL correspondante dans `../SQL/`.
4. Identifier si l'endpoint appartient à l'architecture modulaire, à l'API historique ou aux routes génériques.
5. Définir le contrat avec [references/api-contracts.md](references/api-contracts.md) : méthode, chemin, authentification, rôle, query, payload, réponse et erreurs.
6. Modifier dans l'ordre repository/viewRepository, mapper, validation, service, controller et route. Réutiliser `src/modules/shared/module-kit.js` pour un CRUD standard.
7. Préserver les règles de base : ne pas mettre à jour le stock en double si un trigger le fait et ne pas rendre modifiable une vue ou un historique en lecture seule.
8. Valider avec [references/validation.md](references/validation.md).

## Règles

- Conserver CommonJS (`require`, `module.exports`) dans le backend actuel.
- Monter les routes statiques comme `/search` avant `/:id`.
- Utiliser `catchAsync` ou le mécanisme d'erreur existant; laisser `errorHandler` produire une réponse cohérente.
- Valider et normaliser les entrées avant le repository. Ne pas transmettre `req.body` directement à Prisma.
- Respecter `DEFAULT_TAKE = 100` et `MAX_TAKE = 500` du module kit, sauf contrat spécialisé justifié.
- Utiliser le delegate Prisma exact de `schema.prisma`; ne pas modifier `generated/prisma` à la main.
- Préférer Prisma ou les requêtes paramétrées. Pour une vue dynamique, limiter schéma, vue, colonnes et tri à des métadonnées autorisées.
- Sérialiser proprement `BigInt`, `Decimal`, dates et JSON avant `res.json`.
- Vérifier `verifyToken` et `requireAdmin` pour chaque route sensible; une protection frontend ne suffit pas.
- Préserver les modules `writeEnabled: false`, notamment les mouvements et dashboards de lecture.
- Ne pas journaliser mots de passe, JWT, refresh tokens ou données personnelles sensibles.
- Ne pas lancer `prisma db pull` sans demande explicite : cette commande peut réécrire le schéma source.

## Utilitaire

```powershell
$python = "C:\Users\Benjamin-mupanzi\AppData\Local\anaconda3\python.exe"
& $python backend/skills/develop-sauverndeko-backend/scripts/inspect_backend.py --routes
& $python backend/skills/develop-sauverndeko-backend/scripts/inspect_backend.py --module logistique/commande
& $python backend/skills/develop-sauverndeko-backend/scripts/inspect_backend.py --query "V_Commande"
```

