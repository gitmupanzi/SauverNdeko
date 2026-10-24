# Documentation PostgreSQL — livraison du 24 octobre 2026

Les commentaires sont appliqués et vérifiés après commit dans la base locale SauverNdeko (PostgreSQL 18.6). Le relevé porte sur les huit schémas applicatifs ; aucun contenu de table métier n’a été exporté ou utilisé pour rédiger les commentaires.

La couverture ci-dessous est celle de la première livraison 20261024_01. La [fiabilisation logistique 20261024_02](Logistique_Fiabilisation_20261024.md) ajoute des fonctions et remplace des triggers : la base compte ensuite 1558 objets/colonnes documentés, sans commentaire manquant.

## Couverture constatée

| Type | Objets documentés | Sans commentaire après application |
|---|---:|---:|
| SCHEMA | 8 | 0 |
| TABLE | 30 | 0 |
| SEQUENCE | 27 | 0 |
| VIEW | 39 | 0 |
| COLUMN | 1020 | 0 |
| FUNCTION | 25 | 0 |
| PROCEDURE | 6 | 0 |
| TRIGGER | 24 | 0 |
| CONSTRAINT | 232 | 0 |
| INDEX | 142 | 0 |
| **Total** | **1553** | **0** |

Avant l’intervention, 38 objets possédaient un commentaire et 1515 n’en avaient pas. Les 13 commentaires de vues géographiques existants ont été conservés ; les autres textes existants ont été précisés après lecture des définitions. Les 1020 colonnes comprennent 363 colonnes de tables et 657 colonnes de vues.

## Fichiers livrés

- [Migration des commentaires](../migrations/20261024_01_commentaires_objets_postgresql.sql) : instructions COMMENT ON explicites, encadrées par une transaction, avec délais de verrouillage et d’exécution bornés.
- [Retour arrière des commentaires](../migrations/rollback/20261024_01_commentaires_objets_postgresql.sql) : restitution exacte des commentaires du catalogue initial ; les commentaires auparavant absents sont remis à NULL.
- [Contrôle de couverture en lecture seule](../controles/Verifier_Commentaires_PostgreSQL.sql) : compte les objets documentés et liste les éventuels manquants, sans lire les données métier.

La migration concerne l’état installé relevé. Un objet ou une signature absent fait échouer la transaction ; elle ne crée pas de table ou routine et ne masque pas une structure manquante. Appliquer les migrations de structure correspondantes avant de rejouer la documentation sur une autre installation.

## Contenu des commentaires

Les tables précisent leur rôle et leur grain. Les colonnes décrivent la donnée, les unités ou limites connues et les références installées. Les colonnes de vues incluent leur expression projetée, vérifiée dans la définition installée. Les fonctions/procédures décrivent paramètres utiles, règles, effets et limites. Les triggers précisent événement, moment, granularité et fonction appelée. Séquences, contraintes et index décrivent leur rattachement et leur définition exacte.

Les commentaires ne constituent ni une nouvelle règle métier ni une permission. Ils documentent le comportement installé ; aucune définition, donnée ou autorisation n’est modifiée. Les objets internes PostgreSQL, fonctions d’extensions et objets hors des huit schémas applicatifs ne sont pas couverts.

## Contrôles exécutés

1. Copie de la structure seule vers une base temporaire ; les 30 tables de cette base ont été vérifiées vides.
2. Application des 1553 commentaires, puis contrôle exact des textes.
3. Deuxième application identique : résultat inchangé.
4. Retour arrière sur la base isolée : tous les commentaires initiaux restaurés exactement.
5. Application transactionnelle sur la base locale avec contrôle préalable des définitions et des commentaires initiaux.
6. Contrôle exact des 1553 textes après commit et comparaison de l’empreinte des définitions avant/après : identique.

Empreinte SHA-256 des métadonnées de structure comparées, hors OID et commentaires : 12b7c1aedfdd288d8fe6b61986d03f82c2f30a407b4a08211538d220f995cf81. Elle couvre schémas, relations, colonnes/types/défauts, définitions de vues/routines/triggers, contraintes, index et rattachements des séquences. Elle ne représente pas une empreinte des données.

## Précisions révélées par la lecture

- La base installée possède 30 tables et 39 vues ; le relevé des fichiers trouve 31 modèles Prisma et 52 vues SQL déclarées. analytics.T_Recherche et certaines vues déclarées dans les sources ne sont pas installées. Cette intervention n’installe pas ces objets manquants.
- Les portées de T_Admin_UI_Setting admises en base sont global/entite/user/module ; celles de T_Fk_Correspondance sont global/country/entity. Cette divergence est documentée, sans modification des contraintes.
- QteArticle et QteCmdDetail sont décimaux, mais les routines actuelles refusent les effets fractionnaires car QteMvt est entier.
- ps_update_totaux_commande écrit la somme des lignes dans HT et TTC au même montant ; aucun moteur de taxe distinct n’est établi par cette routine.
- V_Licence_active contient aussi les licences expirées : son nom ne constitue pas un filtre. Les notifications de licence sont déclenchées par INSERT/UPDATE, sans tâche quotidienne implicite.
- tr_delete_commande est une fonction historique sans trigger raccordé et utilise une ancienne signature de procédure. Elle n’est ni corrigée ni activée ici.
- Les fonctions d’audit de caisse utilisent des identifiants fixes et des critères différents de la gestion de caisse par libellés. Leur présence et leur documentation ne constituent pas une validation fonctionnelle de leurs résultats.

Ces points servent aux prochaines évolutions ; aucun correctif fonctionnel n’est inclus dans la livraison de commentaires.

## Consulter ou réappliquer

Dans pgAdmin, actualiser l’objet puis consulter son commentaire dans ses propriétés ; les commentaires de colonnes sont attachés aux colonnes correspondantes. Le fichier de contrôle peut être exécuté dans l’éditeur SQL.

La migration est réexécutable après les évolutions de structure compatibles : ouvrir le fichier SQL complet dans pgAdmin ou utiliser psql avec ON_ERROR_STOP. Les identifiants d’accès restent dans la configuration locale, jamais dans les scripts versionnés. Le retour arrière doit être réservé à l’annulation de cette livraison avant une nouvelle campagne de documentation.

La syntaxe et les signatures utilisées suivent la [documentation PostgreSQL de COMMENT](https://www.postgresql.org/docs/18/sql-comment.html). Un nouveau COMMENT ON remplace le commentaire existant du même objet ; il ne modifie pas sa définition.
