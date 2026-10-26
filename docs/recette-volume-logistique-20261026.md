# Recette de volume logistique — 26 octobre 2026

## Périmètre et méthode

Mesures locales sur PostgreSQL privé, base `sauverndeko_test_cump_20261026` sur 127.0.0.1:53542. La base applicative SauverNdeko n’a reçu aucune donnée de volume. Deux entreprises fictives distinctes ont chacune un article : 1 000, puis 5 000 bons d’entrée et mouvements par article. Les lignes passent par les triggers existants ; aucune désactivation de trigger ou de contrainte. Toute la transaction de fixtures a été annulée à la fin.

Les requêtes passent par les vues API Django en mémoire (`APIRequestFactory`, identité et entreprise validées), avec rendu JSON ou production/lecture complète du XLSX. Version finale : révision CUMP incluant propriété/unité/retours et garde inventaire SQL08. Trois appels successifs par mesure ; chiffres ci-dessous = médiane, en millisecondes. Les mesures ne couvrent ni latence Internet, ni HTTPS, ni un serveur de production. Les caches PostgreSQL et les plans préparés se réchauffent au fil de la recette ; il ne faut pas interpréter chaque différence entre 1 000 et 5 000 comme une pente de complexité.

## Résultats après optimisation

| Lecture | 1 000 mouvements par entreprise | 5 000 mouvements par entreprise |
|---|---:|---:|
| CUMP : synthèse et 25 mouvements | 331 ms | 242 ms |
| Registre Articles : 25 lignes | 107 ms | 124 ms |
| Registre Bons : 25 lignes | 447 ms | 818 ms |
| Indicateur Articles et son détail | 89 ms | 162 ms |
| Excel CUMP complet de l’article | 361 ms | 1 837 ms |

À 5 000, la plage des trois appels CUMP est de 229 à 250 ms ; l’export complet de 1 725 à 2 204 ms. Le registre des bons varie de 596 à 954 ms : c’est la lecture la plus proche du budget local de 1 seconde et elle reste à surveiller sur les machines de livraison. Les budgets de recette locale retenus pour ces parcours sont une médiane sous 1 seconde pour les listes/consultations et sous 5 secondes pour l’export complet de 5 000 mouvements. Ils sont atteints ici ; ces budgets sont des objectifs de recette, pas des garanties de temps de réponse sur tout matériel ou volume.

## Optimisations justifiées

Les identifiants de la vue `V_CoutMouvement` proviennent maintenant de ses clés SQL visibles et de l’article, au lieu des sorties opaques de la fonction PL/pgSQL. Le filtre d’article/devise se pousse avant l’appel du calcul. À 1 000 mouvements, le plan passe de 46 appels de fonction (autres paires article/devise incluses) à un seul ; le plan complet ciblé passe de 544 à 127 ms dans cette comparaison intermédiaire.

La fonction prépare une seule fois les correspondances des restitutions/annulations et les commandes de correction. Elle ne reconstruit plus un grand JSONB à chaque mouvement ordinaire : seuls les coûts réellement requis comme origines de retours/annulations actuels sont mémorisés pendant le parcours. Les coûts internes restent exacts et la procédure d’arrêté conserve tous les coûts prouvés pour des restitutions futures. Cette optimisation conserve les règles de coût et n’ajoute aucun mouvement physique.

À 5 000 mouvements, le calcul PL/pgSQL ciblé passe de 2 331 à 33 ms. La consultation API complète passe de 5 051 à 242 ms ; l’export de 3 845 à 1 837 ms dans le dernier rejeu, incluant la révision finale et les gardes SQL08. Les 44 contrôles de régression CUMP passent après l’optimisation, notamment restitutions, réévaluation, précision et conflits.

L’index existant `mouvement_article_devise_ordre` porte le parcours de lecture. La migration 06 accélère aussi la vérification d’identité des bons dans l’audit historique : les insertions par lots de 4 000 bons ne dépassent plus le délai de 90 secondes observé avant les index. La constitution des 2 × 1 000 fixtures a pris 10,9 secondes puis l’ajout de 2 × 4 000 a pris 54,7 secondes dans le dernier essai ; ces temps ne sont pas annoncés comme un débit d’import validé.

## Intégrité et limites de ce banc

Avant rollback, pour chaque entreprise : 5 000 mouvements, stock article de 5 000, somme signée des mouvements de 5 000 et aucune allocation par lot (les fixtures sont intégralement sans lot). Le GET d’un article de l’autre entreprise est refusé avec 404. Ces contrôles arithmétiques vérifient la cohérence de ce jeu précis ; les scénarios avec lots et annulations sont couverts par leurs recettes fonctionnelles séparées.

Le forçage de la validation différée de 8 000 événements dans une seule transaction a dépassé 90 secondes dans `controler_stock_lots`. Cette limite de gros import est conservée au relevé. Pour mesurer les lectures, le banc final n’a pas forcé ce checkpoint : les triggers sont restés actifs, les événements différés n’ont jamais été validés par un commit, et toutes les fixtures ont été annulées. Cette mesure ne valide donc pas l’import ou le commit de milliers d’événements dans une transaction unique. Les parcours actuels bornent leurs lots de lignes ; une future fonction d’import massif doit définir son découpage, sa reprise, ses budgets et une recette de validation des contraintes.

Les résultats JSON, plans SQL et scripts de ce banc sont conservés dans le dossier local de preuves de la session, hors du dépôt applicatif et sans secret ni données clients.
