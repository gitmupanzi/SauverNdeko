---
name: develop-sauverndeko
description: Analyser, concevoir, corriger et valider SauverNdeko de bout en bout entre PostgreSQL, Prisma, Express et React. Utiliser pour les évolutions transversales de la plateforme, les contrats frontend/backend, les schémas SQL `analytics`, `communication`, `geolocalisation`, `logistique`, `operations`, `professionnel`, `referentiel` et `systeme`, l'authentification, l'administration, les référentiels, la portée global/country/entity, les discussions, la logistique, les vues, triggers, procédures, modèles Prisma ou routes API.
---

# Développer SauverNdeko

Raisonner par contrat vertical : base PostgreSQL, modèle Prisma, API Express, service frontend, puis écran React. Ne modifier que les couches réellement concernées.

## Procédure

1. Lire [references/architecture.md](references/architecture.md) et sélectionner le domaine métier.
2. Vérifier `git status --short` et préserver les changements hors périmètre, les sauvegardes et les fichiers générés.
3. Inspecter le concept avec `scripts/inspect_sauverndeko.py --query "terme"`.
4. Pour une donnée, lire [references/database.md](references/database.md), le modèle de `backend/prisma/schema.prisma`, le DDL ou la vue SQL, l'API qui l'expose et le service frontend qui la consomme.
5. Définir avant modification : source d'écriture, source de lecture, clés, cardinalité, rôle requis, portée, enveloppe JSON et comportement d'erreur.
6. Appliquer la modification dans la couche propriétaire. Ne pas reconstruire dans React un calcul déjà exposé par une vue, ni reproduire dans Express un effet garanti par un trigger.
7. Valider chaque couche avec [references/validation.md](references/validation.md), puis le parcours intégré.
8. Signaler les migrations à appliquer, la régénération Prisma nécessaire et toute validation impossible sans Node, PostgreSQL ou variables d'environnement.

## Routage vers les skills spécifiques

- Pour Express, Prisma, contrôleurs, services, repositories, validations et routes, utiliser aussi `$develop-sauverndeko-backend` dans `backend/skills/develop-sauverndeko-backend`.
- Pour React, Vite, pages, composants, authentification côté client et services API, utiliser aussi `$develop-sauverndeko-frontend` dans `frontend/skills/develop-sauverndeko-frontend`.
- Pour une évolution SQL seule ou transversale, rester dans ce skill et vérifier ensuite les deux consommateurs.

## Invariants

- Préserver l'objectif multi-organisation, multi-pays et configurable du produit. Ne pas figer les niveaux géographiques ou libellés sur un seul pays.
- Respecter la résolution de portée `entity`, puis `country`, puis `global` lorsqu'une fonctionnalité utilise les réglages partagés.
- Utiliser les tables pour les écritures et les vues pour les lectures métier enrichies, sauf contrat existant différent.
- Considérer les mouvements logistiques comme auditables et non modifiables directement. Laisser les procédures et triggers appliquer les effets de stock.
- Ne pas modifier `backend/generated/prisma/` manuellement. Modifier le schéma source, puis régénérer explicitement.
- Ne pas exécuter `prisma db pull`, un script SQL destructif ou une restauration de backup sans autorisation claire et sauvegarde vérifiée.
- Ne jamais exposer `.env`, `DATABASE_URL`, secrets JWT, tokens ou données personnelles.
- Préférer les requêtes paramétrées. Justifier et borner tout usage de SQL brut dynamique.

## Utilitaire

```powershell
$python = "C:\Users\Benjamin-mupanzi\AppData\Local\anaconda3\python.exe"
& $python skills/develop-sauverndeko/scripts/inspect_sauverndeko.py --summary
& $python skills/develop-sauverndeko/scripts/inspect_sauverndeko.py --query "V_Commande"
& $python skills/develop-sauverndeko/scripts/inspect_sauverndeko.py --sql-object logistique.V_Commande
& $python skills/develop-sauverndeko/scripts/inspect_sauverndeko.py --prisma-model T_Commande
```

