# Base PostgreSQL SauverNdeko

## Sources et autorité

1. Vérifier d'abord le comportement attendu dans les scénarios métier et scripts SQL modulaires.
2. Vérifier les tables et relations consommées par l'application dans `backend/prisma/schema.prisma`.
3. Vérifier les vues dans les fichiers `*_View.sql` ou `*_views.sql`.
4. Pour la logistique, lire aussi `Migration_Alignement_Logistique_Scenario.sql`, qui contient procédures, triggers et versions alignées de plusieurs vues.
5. Traiter `SauverNdeko_test.sql` comme un scénario de données, pas comme le schéma complet.
6. Traiter `sauverndeko.backup`, les fichiers `.pgerd` et `Schema_SauverNdeko.png` comme artefacts de restauration ou de visualisation, non comme sources éditables.

En cas de divergence, ne pas choisir silencieusement : documenter la différence entre intention SQL, modèle Prisma et base effectivement ciblée.

## Règles structurelles

- Conserver les identifiants PostgreSQL cités et leur casse exacte, par exemple `logistique."T_Commande"`.
- Qualifier chaque objet par son schéma.
- Vérifier les FK vers `referentiel."T_Generique"` et la catégorie attendue, pas seulement l'existence de l'identifiant.
- Préserver les contraintes d'unicité, le soft delete et les champs automatiques.
- Livrer une migration rejouable et ordonnée. Ne pas supposer qu'un `CREATE TABLE IF NOT EXISTS` aligne une table déjà existante.

## Logistique

- `T_Article` porte le stock courant.
- `T_CommandeDetail` applique ou annule son effet via la logique SQL lors des insertions, mises à jour et suppressions.
- `T_Mouvement` est une trace d'audit; les écritures directes sont bloquées sauf contexte interne prévu par la base.
- Une commande clôturée ou facturée ne doit plus être modifiée ou supprimée.
- `V_Commande`, `V_CommandeDetail`, `V_Mouvement`, `V_SuiviReglements` et les vues de stock sont les projections métier privilégiées.
- Les dates métier et dates automatiques ont des significations différentes; ne pas les interchanger dans les filtres.

## Système et portée

- `T_Admin_UI_Setting` et `T_Fk_Correspondance` rendent l'administration configurable.
- Les réglages doivent rester auditables et résolus selon la portée la plus spécifique disponible.
- Les vues `V_Admin_UI_Setting*`, `V_Fk_Correspondance*`, `V_User_profil` et autres vues système servent à l'administration enrichie.

## Sécurité SQL

- Éviter `$queryRawUnsafe` et `$executeRawUnsafe` pour les nouvelles requêtes lorsque Prisma ou une requête paramétrée suffit.
- Si un nom de vue ou de colonne est dynamique, l'autoriser depuis une liste issue des métadonnées, puis citer correctement l'identifiant.
- Ne jamais concaténer une valeur utilisateur brute dans un filtre SQL.
- Tester les migrations dans une base isolée et dans une transaction lorsque le script le permet.

