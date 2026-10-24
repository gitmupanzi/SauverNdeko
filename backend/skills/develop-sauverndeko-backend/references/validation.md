> Relevé historique antérieur à la conversion Django. Pour l’architecture et les commandes actuelles, suivre le [skill canonique](../../../skill/SKILL.md). Les descriptions Express/Prisma ci-dessous ne décrivent plus le backend actif.

# Validation backend

## Statique

```powershell
cd backend
npm install
node --check app.js
node --check server.js
Get-ChildItem src,routes,controllers,services,middlewares -Recurse -Filter *.js |
  ForEach-Object { node --check $_.FullName }
```

Si `prisma/schema.prisma` change :

```powershell
npm run prisma:generate
```

Inspecter ensuite le diff de `generated/prisma`; ne pas accepter des fichiers temporaires de moteur.

## Tests ciblés

Le package ne définit actuellement aucun script `test`. Pour une évolution métier, ajouter ou exécuter des tests ciblés avec dépendances simulées, puis tester contre une base isolée.

Vérifier au minimum :

- succès nominal ;
- payload invalide 400 ;
- token absent ou invalide 401 ;
- rôle insuffisant 403 ;
- ressource absente 404 ;
- conflit ou contrainte SQL ;
- sérialisation `BigInt`/`Decimal` ;
- pagination et limite 500 ;
- absence d'écriture sur les modules en lecture seule.

## Intégration

Démarrer le backend seulement avec un `.env` local valide et une base de développement :

```powershell
npm start
```

Tester `/health`, l'endpoint modifié et son consommateur frontend. Ne jamais afficher le contenu du `.env` dans les logs ou le compte rendu.

