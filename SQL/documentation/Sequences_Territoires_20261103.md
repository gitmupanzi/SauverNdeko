# Reprise des séquences territoriales

La migration `20261103_05_sequences_territoires.sql` corrige un état de reprise historique : les séquences d’identité des niveaux 0 à 5, ainsi que celle du niveau 1 historique, étaient encore à `last_value = 1, is_called = false` alors que leurs tables contenaient déjà des identifiants explicites.

L’inspection en lecture seule de la copie fraîche vérifiée constate :

| Table | Maximum enregistré | Prochain identifiant après correction |
|---|---:|---:|
| T_Niveau_0 | 251 | 252 |
| T_Niveau_1 | 26 | 27 |
| T_Niveau_1_Old | 12 | 13 |
| T_Niveau_2 | 631 | 632 |
| T_Niveau_3 | 2 716 | 2 717 |
| T_Niveau_4 | 24 229 | 24 230 |
| T_Niveau_5 | 24 240 | 24 241 |

Ces nombres sont des constats de recette, pas des valeurs fixées dans la migration. Celle-ci résout la séquence réelle de chaque colonne et calcule son maximum au moment de l’exécution. Elle ne réécrit aucun identifiant, aucune table et aucune relation.

Les tables sont verrouillées dans un ordre constant pendant la transaction. Le prochain identifiant tient compte de `is_called`. Une séquence déjà en avance reste inchangée ; une table vide ne nécessite aucun alignement. Avant de corriger une séquence en retard, la migration conserve sa taille de cache pour obtenir son verrou et relit son état, puis utilise exclusivement `ALTER SEQUENCE ... RESTART WITH maximum + 1`. Aucun `setval` non transactionnel n’est utilisé. Une annulation restaure donc l’état précédent. Les séquences cycliques ou dont l’incrément diffère de 1 sont refusées pour examen, sans tentative de réinterprétation.

Les structures canoniques n’ont pas à enregistrer ce correctif d’état : leurs tables sont vides et leurs définitions d’identité restent identiques. Une sauvegarde/restauration complète doit toutefois conserver les états des séquences ; le correctif versionné est destiné aux bases historiques concernées.

## Vérifications exécutées

Huit tests PostgreSQL ont réussi sur `sauverndeko_test_sequences_c342a38e`, copie privée intégrant les migrations 03 et 04 :

- prochain identifiant supérieur au maximum des sept tables ;
- véritables insertions avec génération d’identité sur les sept tables, sans collision, puis annulation des lignes fictives ;
- rejeu sans changement d’une séquence déjà alignée ;
- séquence volontairement placée plus loin jamais abaissée ;
- correction des états appelés et non appelés ;
- annulation transactionnelle de l’alignement vérifiée ;
- absence de `setval` et d’écriture métier ;
- toutes les données des 78 tables, les triggers et les définitions de séquences conservés lors du rejeu.

Preuves locales : `.runtime/territorial-sequences-sql/clone.json` et `tests.log`. SHA-256 contrôlé : `5839ab81229dac46e788f03871301a35f1332906aff28dc9d4567ca4f4632807`. Ces contrôles privés ne constituent pas une preuve d’installation sur la base source.
