> Relevé historique antérieur à la conversion Django. Pour l’architecture et les commandes actuelles, suivre le [skill canonique](../../../skill/SKILL.md). Les descriptions Express/Prisma ci-dessous ne décrivent plus le backend actif.

# Validation frontend

## Build

```powershell
cd frontend
npm install
npm run build
```

Le package ne définit actuellement ni lint ni tests automatisés. Ne pas présenter le build seul comme preuve complète du comportement.

## Vérifications ciblées

- rendu sans erreur avec réponse nominale ;
- état de chargement et liste vide ;
- erreur réseau et erreur HTTP structurée ;
- token expiré, restauration de session et logout ;
- accès refusé aux routes admin ;
- formulaire valide, invalide et mutation en cours ;
- mobile étroit, écran moyen et bureau ;
- clavier, focus, libellés et boutons désactivés ;
- valeurs nulles, dates, nombres, `BigInt` sérialisés et libellés longs.

## Contrat backend

Pour tout service modifié, comparer méthode, URL, query, payload et enveloppe avec la route Express. Tester au moins un succès et les statuts 400, 401/403 et 404 pertinents.

## Logistique et administration

- Vérifier les colonnes réellement renvoyées par la vue.
- Vérifier filtres, tri, pagination, sélection et rafraîchissement après mutation.
- Vérifier qu'aucune action d'écriture n'apparaît sur un module en lecture seule.
- Vérifier qu'un calcul dérivé n'est pas dupliqué avec une logique différente de la vue SQL.

