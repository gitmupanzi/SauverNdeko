# Coordonnées professionnelles des territoires

La migration `20261103_04_coordonnees_territoires.sql` ajoute une source commune de coordonnées déclarées pour les territoires de niveau 1 à 5. Elle ne relie pas arbitrairement un territoire à une entreprise et n’importe aucun contact présumé.

## Données et rattachement

`geolocalisation.T_CoordonneesTerritoire` est initialement vide. Chaque fiche possède un identifiant généré et exactement une FK réelle parmi `ID_Niveau_1Fk` à `ID_Niveau_5Fk`, vers la table territoriale correspondante. Un index unique partiel par FK garantit une seule fiche par territoire. Le rattachement et l’identifiant restent immuables après création.

| Champ | Limite |
|---|---|
| AdresseTerritoire | 2 000 caractères, multiligne |
| TelephoneTerritoire | 50 caractères |
| TelephoneSecondaireTerritoire | 50 caractères |
| EmailTerritoire | 255 caractères |
| SiteWebTerritoire | 255 caractères |
| InformationsAccueilTerritoire | 3 000 caractères, multiligne |

Ces six champs sont facultatifs ; `NULL` représente une absence. PostgreSQL refuse les chaînes vides, les espaces extérieurs et les contrôles interdits ; seules les deux zones multiligne admettent les retours à la ligne. E-mail et URL interdisent les espaces et contrôles ; le service effectue aussi la validation syntaxique de l’e-mail et des schémas web autorisés. Le texte d’accueil n’est jamais interprété comme du HTML ou présenté comme un horaire vérifié.

Il n’existe aucune colonne de propriétaire entreprise, GPS ou contact personnel dans cette table. L’acteur technique est une FK vers le compte existant, pas un professionnel affecté au territoire.

## Projections et compatibilité

`V_Niveau_1` à `V_Niveau_5` conservent toutes leurs anciennes colonnes, types, ordres et calculs. Une jointure externe unique ajoute, à la fin, les six champs de contact et `CoordonneesModifieLe`. Les territoires sans coordonnées restent visibles avec ces champs à `NULL`. Les compteurs et les autres analyses ne sont pas multipliés par la jointure.

Le rejeu vérifie la présence et l’ordre de ces sept colonnes ; il ne réemboîte pas les vues à chaque exécution. Les vues statistiques et les hiérarchies existantes ne sont pas recréées pour leur inventer de nouvelles relations.

Les cinq entrées correspondantes de `T_InterfaceTableau` reçoivent ces sept colonnes dans leur catalogue commun. Elles sont disponibles mais masquées par défaut, aussi bien dans le tableau que dans l’export. Les anciennes définitions JSON conservent exactement leur contenu et leur ordre. La révision augmente une seule fois ; le rejeu n’ajoute aucun doublon. Aucune préférence personnelle n’est réécrite. L’export d’installation existant emporte déjà ce catalogue commun.

## Concurrence et traçabilité

Le trigger `coordonnees_territoire_integrite` s’applique aux insertions, modifications et suppressions. Il verrouille le territoire parent, comme les services territoriaux dédiés. Une écriture SQL directe ne peut pas se glisser entre le contrôle de révision du service et l’enregistrement de ses coordonnées. Un ordre externe inverse de verrouillage peut provoquer un deadlock : PostgreSQL annule alors une transaction, sans écrasement silencieux.

`ModifieLe` est imposé par `clock_timestamp()`. `ModifieParUserFk` provient exclusivement de `systeme.fn_admin_actor_user_id()` et du contexte transactionnel `systeme.actor_user_id` ; un acteur absent ou invalide produit `NULL`. Les valeurs techniques fournies dans une écriture ne peuvent pas falsifier ces deux champs. Ce contexte d’audit n’accorde aucune permission.

Les FK empêchent les orphelins et ne suppriment pas implicitement une fiche. Un service autorisé à supprimer le territoire doit retirer explicitement ses coordonnées dans la même transaction, après ses contrôles et verrous habituels. Les API conservent également leur journal d’audit et leur révision combinant parent et coordonnées.

## Vérifications exécutées

- 15 recettes PostgreSQL réussies sur une copie privée locale, incluant le catalogue de colonnes. Les tests refusent toute base hors `sauverndeko_test_*`.
- La concurrence utilise deux connexions : les `UPDATE` et `DELETE` directs attendent le verrou du parent et échouent proprement au délai prévu ; l’écriture réussit après libération. La fixture temporairement validée est ensuite supprimée.
- Le rejeu répété conserve les 77 tables antérieures et tous leurs triggers, avec pour seule évolution de données l’ajout contrôlé aux cinq catalogues ci-dessus. Les anciens objets JSON et les préférences personnelles restent identiques. Les données, types et ordres antérieurs des cinq vues territoriales sont comparés exactement ; la nouvelle table reste vide.
- Deux restaurations des structures canoniques vérifient les définitions et commentaires : 78 tables pour la structure complète, 68 pour la structure métier, zéro donnée dans les deux fichiers.

Journaux locaux : `.runtime/territorial-contacts-sql/tests.log`, `tests-fresh.log`, `fresh-preservation.json` et `.runtime/territorial-contacts-canonicals/verification.json`.

SHA-256 de la migration contrôlée : `a76a8a27caf046f5d5c240e63648c917a68007f3bb4a2efd156590b5dd3fef59`. Les preuves privées et les fichiers SQL ne constituent pas, seuls, une preuve d’installation sur la base source ou chez un client.

## Services et recette de bout en bout

Les routes territoriales existantes conservent leur contrat d’écriture plat : champs de la fiche, `requestId` et `_version` pour une modification. Les six coordonnées sont séparées des colonnes de `T_Niveau_*` par le service dédié, puis sauvegardées dans la même transaction que le parent. Le panier conserve `header` pour les rattachements et `rows` pour les lignes identifiées par `rowId` ; une erreur de coordonnées reste attachée à sa ligne et annule le lot entier. Les niveaux 0 et l’ancien découpage restent exclus des nouvelles coordonnées.

La révision opaque `_version` combine `xmin` du parent, `xmin` et le contenu de sa fiche de coordonnées. Elle détecte une modification des contacts même si le territoire n’a pas changé, y compris plusieurs écritures au sein d’une même transaction. Un champ omis préserve sa valeur ; l’effacement explicite de tous les contacts retire la fiche facultative. Une suppression de territoire retire ses coordonnées dans la même transaction ; si un autre rattachement empêche la suppression du territoire, les coordonnées sont restaurées par le rollback.

Les coordonnées restent communes comme le découpage. Leur édition conserve les droits actuels de gestion territoriale de la plateforme et ne découle pas d’une licence d’une entreprise. Les écritures génériques directes de la nouvelle table sont refusées par l’API, pour préserver la révision et la transaction du formulaire. Les e-mails sont validés et les liens limités à http/https sans identifiants intégrés. Aucun GPS personnel, contact, horaire ou rattachement d’entreprise n’est inféré.

**49 recettes API réussies** sur la copie privée `sauverndeko_test_contacts_final_99b4a942` : 10 dédiées aux coordonnées et 39 régressions territoriales (saisie individuelle, panier, erreurs, permissions, collisions, rejeu et concurrence). `manage.py check` réussit ; `verifier_backend` vérifie **360/360 lectures** avec connexion réellement en lecture seule et aucune écriture. Preuve : `.runtime/territorial-contacts-api-tests/verification.json`, journaux `final.txt`, `territoires-final.txt`, `check.txt` et `verifier.txt`.

Les séquences historiques importées ont été examinées séparément : leur réparation conditionnelle relève de la migration `20261103_05_sequences_territoires.sql`, sans changement des données géographiques. La préparation des séquences dans les fixtures privées ne constitue pas une intervention sur la source.


Installation locale effectuée par le responsable de livraison après une nouvelle sauvegarde et sa restauration vérifiée : `.runtime/coordonnees-source-applied-20261103.json`. Les anciennes données et les préférences sont conservées ; la table des coordonnées est créée vide. La réparation séparée des sept séquences territoriales est tracée dans `.runtime/territorial-sequences-source-applied-20261103.json`. Aucun identifiant existant n’est renuméroté.
