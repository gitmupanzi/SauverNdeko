---
name: develop-sauverndeko-frontend
description: Développer, corriger et valider le frontend SauverNdeko avec React 19, React Router 7, Vite 6, Bootstrap et les services API réels. Utiliser pour les pages publiques, authentification et restauration de session, routes protégées et administrateur, profil, discussions, administration générique, logistique, tableaux et filtres, mappers, gestion des états réseau, responsive mobile, styles, composants et contrats avec le backend Express.
---

# Développer le frontend SauverNdeko

Travailler depuis `frontend/`. Garder les appels réseau dans `src/services/`, les adaptations de données dans les mappers et la présentation dans les pages ou composants.

## Procédure

1. Lire [references/frontend-architecture.md](references/frontend-architecture.md).
2. Inspecter les routes et services avec `scripts/inspect_frontend.py --routes` et `--services`.
3. Lire le service API appelé, le mapper, le composant consommateur et l'endpoint backend correspondant.
4. Définir les états chargement, succès, vide, erreur, non authentifié et non autorisé.
5. Modifier le plus petit composant réutilisable ou la configuration admin/logistique propriétaire.
6. Préserver les contrats décrits dans [references/api-and-ui-contracts.md](references/api-and-ui-contracts.md).
7. Valider avec [references/validation.md](references/validation.md), puis vérifier le parcours avec le backend réel ou simulé.

## Règles

- Conserver les modules ES et les composants fonctionnels.
- Utiliser `requestJson` pour les API métier et l'authentification; utiliser les helpers publics existants pour les lectures tolérant l'indisponibilité.
- Ne pas appeler `fetch` directement depuis une page si un service peut porter le contrat.
- Respecter `VITE_API_BASE_URL`; en développement, Vite proxifie `/api`, `/SauverNdeko` et `/health` vers le backend.
- Traiter l'enveloppe `success`, `message`, `data`, `error` sans supposer qu'une réponse HTTP contient toujours du JSON.
- Préserver `ProtectedRoute` pour les sessions et `AdminRoute` pour les écrans d'administration/logistique. Ne pas remplacer une autorisation serveur par un simple masquage UI.
- Conserver les tokens via `authStorage` et la restauration via `AuthContext`; ne jamais les afficher dans les logs ou le DOM.
- Réutiliser les services `api.js`, `auth.js`, `logistique.js` et les mappers avant de créer une nouvelle couche parallèle.
- Pour l'administration, modifier les configurations de `src/pages/admin/` et les métadonnées partagées plutôt que dupliquer des tableaux.
- Pour la logistique, lire les vues SQL comme source des colonnes calculées. Ne pas recalculer stock, reste, état de paiement ou audit si la vue les fournit.
- Préserver l'historique des mouvements en lecture seule.
- Maintenir accessibilité clavier, libellés, focus, contraste, états désactivés et comportement responsive.
- Ne pas introduire de données mock dans un parcours connecté sans fallback explicitement identifié.

## Utilitaire

```powershell
$python = "C:\Users\Benjamin-mupanzi\AppData\Local\anaconda3\python.exe"
& $python frontend/skills/develop-sauverndeko-frontend/scripts/inspect_frontend.py --routes
& $python frontend/skills/develop-sauverndeko-frontend/scripts/inspect_frontend.py --services
& $python frontend/skills/develop-sauverndeko-frontend/scripts/inspect_frontend.py --query "fetchLogistiqueCommandes"
```

