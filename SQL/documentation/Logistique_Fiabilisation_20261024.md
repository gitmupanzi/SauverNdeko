# Logistique — fiabilisation du 24 octobre 2026

> Bilan historique de la version 02. Les recettes Node ont depuis été retirées avec l’ancien backend ; leurs chemins mentionnés ci-dessous sont historiques. Utiliser les recettes Python de SQL/tests et le [bilan de la version 04](Audit_Metier_20261024.md) pour l’état actuel.

Migration 20261024_02 appliquée à la base locale SauverNdeko (PostgreSQL 18.6), puis vérifiée après commit. Les définitions appliquées correspondent à celles testées sur une copie de structure avec données fictives. Les empreintes des cinq tables logistiques confirment que leurs données sont inchangées pendant la migration.

## Problèmes reproduits et corrections

| Cas sur données fictives | Avant | Après |
|---|---|---|
| Deux insertions simultanées sur une commande | Total enregistré 45, somme des lignes 65 | Total et somme à 65 |
| Lot de 50 lignes dans une instruction INSERT | 50 mises à jour du total de commande | Une seule mise à jour |
| Modification/suppression des 50 lignes | Recalcul par événement de ligne | Une mise à jour pour chaque instruction ; aucune pour une annotation sans changement de montant |
| Statut avec espaces/casse/accents usuels | CLOTUREE avec espaces permet encore de modifier l’en-tête | En-tête et lignes protégés par le prédicat commun |
| Rupture sans seuil minimum | Article absent de V_AlertStock | Article présent dans les alertes |
| Mouvement daté d’un jour futur | Inclus dans la consommation servant à la couverture | Exclu de la fenêtre de couverture courante |
| Audit de stock filtré sur un article | Fonction PL/pgSQL évaluée comme Function Scan | Fonction SQL STABLE permettant la poussée du filtre |

## Organisation SQL retenue

- fn_commande_cloturee(text) centralise la lecture du statut fermé, avec normalisation des espaces, de la casse et des accents français usuels.
- tr_00_guard_commandedetail verrouille les parents avant les effets de ligne et refuse leurs modifications après clôture. Son nom impose son passage avant le trigger BEFORE DELETE qui annule l’effet de stock. Un déplacement de ligne verrouille ses deux commandes dans l’ordre des identifiants.
- tr_totaux_commande_insert/update/delete sont trois triggers AFTER STATEMENT avec tables de transition. Ils recalculent chaque commande distincte une seule fois, après les effets stock des lignes.
- ps_update_totaux_commande verrouille le parent et évite un UPDATE si HT et TTC sont déjà corrects. La règle actuelle HT = TTC = somme quantité × prix est conservée ; aucun moteur de taxe n’est ajouté.
- fn_audit_stock conserve ses paramètres, ses résultats et la distinction stock courant/mouvements bornés ; son écriture SQL rend le filtre exploitable par le planificateur.
- V_AlertStock inclut une rupture même sans seuil. V_CouvertureStock borne les mouvements de CURRENT_DATE moins six mois inclus au lendemain du jour courant exclu ; la moyenne reste divisée par six.

Les noms, ordre et types des colonnes existantes sont préservés. Les contrôles de quantité entière, de stock non négatif et d’écriture des mouvements sont conservés. Les nouveaux objets et les objets modifiés sont commentés ; le contrôle global relève désormais 1558 objets/colonnes documentés dans les huit schémas applicatifs.

## Mesures de lecture

Mesure PostgreSQL seule sur une requête V_AuditStock filtrée par ID_Article, après ajout de 5000 articles fictifs et de leurs mouvements initiaux. Quatre exécutions par état ; la première sert d’échauffement, les trois suivantes sont conservées.

| État | Temps SQL mesurés (ms) | Médiane (ms) |
|---|---|---:|
| Avant | 38.794 ; 43.762 ; 48.21 | 43.762 |
| Après | 0.147 ; 0.283 ; 0.155 | 0.155 |

La recette exécutée depuis les fichiers installés du backend confirme également un ordre de grandeur de 0,15 ms pour cette lecture. Ces temps portent sur la requête SQL filtrée et un jeu synthétique local ; ils ne mesurent pas le chargement complet d’une page ou une charge de production. Aucun index ou cache supplémentaire n’a été nécessaire pour ce gain.

## Recette exécutée

La recette PostgreSQL installée dans backend/tests couvre : deux saisies simultanées, sorties concurrentes sans survente, clôture concurrente, lots INSERT/UPDATE/DELETE, annotation sans modification de total, changement de prix seul, changement de quantité, suppression de ligne, déplacement entre commandes, cascade de suppression, changement de type de commande, rupture, refus des fractions, refus d’écriture directe des mouvements, rollback transactionnel et audit cohérent.

Le cycle de migration a aussi vérifié : retour exact aux définitions/commentaires initiaux, parité des valeurs d’audit avant/après, réexécution identique, conservation des colonnes/types et absence de commentaire manquant. Les essais de mutation utilisent exclusivement la base temporaire ; la base locale n’a reçu que les changements de définition et de commentaires.

## Fichiers et réutilisation

- [Migration appliquée](../../backend/database/migrations/20261024_02_fiabilisation_logistique.sql).
- [Retour arrière](../../backend/database/migrations/rollback/20261024_02_fiabilisation_logistique.sql).
- [Vues canoniques](<../3. Schema logistique/Logistique_View.sql>), alignées pour les deux vues modifiées.
- [Recette](../../backend/tests/logistique.postgres.test.cjs) et [helpers de données fictives](../../backend/tests/helpers/logistique-postgres.cjs).
- [Contrôle de couverture des commentaires](../controles/Verifier_Commentaires_PostgreSQL.sql).

Depuis backend/, npm run test:logistique exécute la recette. Définir SAUVERNDEKO_TEST_DATABASE_URL vers une copie de structure contenant la migration, sur une base locale nommée sauverndeko_logistique_* ou sauverndeko_test_*, distincte de DATABASE_URL. La recette réinitialise les tables logistiques de cette base isolée et y crée ses fixtures et instruments de mesure ; ne pas la diriger vers une base métier. Les identifiants de connexion ne sont pas écrits dans le dépôt.

Pour reconstruire cette version depuis l’ancien socle, appliquer les évolutions de structure, puis 20261024_01 et enfin 20261024_02. Ne pas rejouer l’ancienne migration d’alignement après la version 02, ce qui rétablirait les anciennes routines. Le rollback restaure les mécanismes précédents ; son usage doit donc correspondre à une annulation de cette livraison.

## Périmètre restant

Cette livraison ne traite pas les droits des routes modulaires, l’isolation par organisation, les agrégats locaux du dashboard React ou la définition des devises. Elle ne réécrit pas les montants déjà enregistrés et ne qualifie pas le backend entier comme prêt à livrer. La fonction historique tr_delete_commande, non raccordée, reste à reprendre séparément si un futur parcours doit l’utiliser.

Références techniques : [triggers et tables de transition](https://www.postgresql.org/docs/18/trigger-definition.html), [verrous de lignes](https://www.postgresql.org/docs/18/explicit-locking.html). Les mesures et résultats métier ci-dessus proviennent de la recette locale.
