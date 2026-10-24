> Relevé historique antérieur à la conversion Django. Pour l’architecture et les commandes actuelles, suivre le [skill canonique](../../sauverndeko-erp/SKILL.md). Les descriptions Express/Prisma ci-dessous ne décrivent plus le backend actif.

# Validation transversale

## Base

- Analyser la syntaxe du script SQL avant exécution.
- Exécuter la migration et les scripts `*_Test.sql` dans une base jetable ou dédiée.
- Vérifier tables, colonnes, FK, vues, procédures et triggers concernés.
- Tester le cas nominal, une violation de FK, une valeur de référentiel de mauvaise catégorie et un rollback.
- Pour la logistique, rapprocher stock courant et somme des mouvements, puis tester insert/update/delete d'une ligne de commande.

## Backend

```powershell
cd backend
npm install
npm run prisma:generate
node --check app.js
node --check server.js
```

Le dépôt ne définit actuellement aucun script `test`. Ajouter ou exécuter des tests ciblés avant de présenter une modification sensible comme validée. Ne pas lancer `prisma:pull` pour une simple vérification.

## Frontend

```powershell
cd frontend
npm install
npm run build
```

Vérifier ensuite les états chargement/vide/erreur, le mobile, les routes protégées, les rôles administrateur et les formulaires concernés.

## Contrat intégré

- Comparer l'URL, la méthode, les paramètres, le corps, le rôle et l'enveloppe de réponse entre frontend et backend.
- Vérifier la sérialisation de `BigInt`, `Decimal`, dates et valeurs nulles.
- Vérifier que la vue expose toutes les colonnes attendues par le mapper ou le tableau.
- Tester un succès, une validation 400, une absence 404, un refus 401/403 et une erreur métier de base.

