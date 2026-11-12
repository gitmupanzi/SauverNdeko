# Audit et corrections des schémas métier du 24 octobre 2026

La migration 20261024_04 est appliquée à la base locale. Les sept schémas demandés ont été inspectés dans PostgreSQL et confrontés aux sources SQL et au backend Django. Les empreintes des 27 tables existantes contrôlées sont identiques avant/après. La nouvelle table analytics est vide ; aucune collecte de données ni donnée fictive n’a été ajoutée à la base applicative.

## Corrections appliquées

| Domaine | Résultat |
|---|---|
| referentiel | Le sens Entrée/Sortie d’un type déjà utilisé ne peut plus être inversé ou effacé par modification du référentiel. Les vues et les relations installées sont conservées. |
| systeme | Les nouvelles images d’audit ne stockent plus mots de passe ou jetons. V_Audit_log masque aussi ces champs dans les événements anciens. Les licences disposent d’un identifiant automatique ; leur chevauchement est contrôlé à la création et à la modification, avec verrou de l’entité pour les écritures concurrentes. Leur état temporel est calculé à la lecture. |
| geolocalisation | Quinze clés étrangères en attente, réparties entre géographie et logistique, ont été validées sans orphelin. Deux agrégats incluent désormais les sites directement rattachés au niveau 3 : les 21 949 sites sources sont comptés. Le rattachement indirect via le niveau 4 reste pris en charge. |
| professionnel | Les trois vues administratives présentes dans les fichiers sont installées et commentées. Une projection publique commune limite les données personnelles et agrège les affiliations actives à la date de lecture, sans multiplier les professionnels. |
| analytics | Le socle T_Recherche/V_Recherche attendu par les sources est installé avec FK, contrôles et index. GET /api/recherches est raccordé et réservé à l’administration globale. Aucun suivi automatique des utilisateurs n’est activé. |
| communication | Les vues privées sont installées. PostgreSQL maintient la dernière activité d’une discussion après insertion, modification ou suppression de message, y compris sous concurrence. Un message doit comporter texte, fichier ou lien non vide. |
| logistique | Une modification de ligne applique le delta net de stock par article, dans un ordre de verrouillage stable. L’augmentation d’une entrée partiellement consommée est donc autorisée si le stock final reste non négatif. Une ligne conserve un mouvement source unique ; prix, quantités, changement d’article, changement de sens, déplacement et suppression restent cohérents. |

Les montants de ligne et de commande gardent la convention existante quantité × prix, HT = TTC. Aucune taxe, remise calculée ou devise nouvelle n’a été inventée.

## Backend Django

Le registre et les modèles unmanaged reflètent 31 tables métier et 48 vues. Les annuaires publics et leurs compteurs utilisent les mêmes vues. Le calcul de dernière activité n’est plus dupliqué en Python.

La recette d’écriture a révélé deux défauts de conversion corrigés : les UUID de licence deviennent des chaînes JSON, et les colonnes JSON/JSONB des curseurs SQL bruts sont décodées en objets, avec Decimal pour les nombres décimaux. Les autres champs texte restent du texte. Le nettoyage récursif des réponses d’audit peut ainsi retirer effectivement les champs sensibles des images JSON.

## Vérifications

| Contrôle | Résultat |
|---|---|
| Tests Django sans base | Résultat historique : 66 réussis avant le retrait du dossier de tests unitaires demandé par le propriétaire. |
| Recette PostgreSQL sur structure et données fictives | 36 réussis : stock initial, entrées/sorties, prix, quantité, suppression/cascade, clôture, rollback, changements de clé et de sens, lots, géographie, annuaire et quatre courses concurrentes. |
| Recette Django sur cette base fictive | Connexion réelle par mot de passe et 19 échanges réussis, dont créations d’article, commande, ligne, entité, licence et message ; conflits et accès refusés vérifiés. |
| Diagnostic de la base applicative | 96 parcours GET réussis en lecture seule, dont un périmètre d’organisation fictive sans fuite de lignes ou de compteurs. |
| Intégrité sur les sept schémas | 77 clés étrangères validées, aucun orphelin, 48 vues exécutables. |
| Stock existant | Aucun écart entre stock courant et mouvements dans V_AuditStock. |
| Commentaires sur les neuf schémas, public inclus | 1 893 objets/colonnes documentés, aucun commentaire manquant. |
| Retour arrière en recette | Refus si analytics contient des événements ; restauration logique des anciennes définitions, puis réapplication et idempotence vérifiées. |
| Fichiers SQL canoniques | Restaurations réussies sur bases vides : 31 tables métier ou 41 tables avec socle natif, et 48 vues ; aucune donnée copiée. |

Les données de recette ne proviennent d’aucun client. La sauvegarde préparatoire contient uniquement les définitions. Les états de contrôle détaillés figurent dans Audit_Metier_20261024.json et les scripts reproductibles dans SQL/tests.

## Connexions du serveur local

Une saturation des 100 connexions PostgreSQL a été observée pendant le contrôle final. Une ancienne instance Django conservait des connexions inactives. Les 33 sessions encore associées à cette instance, inactives depuis plus d’une minute et sans transaction, ont été fermées ; les sessions des autres applications et de pgAdmin ont été conservées.

Le backend courant utilise CONN_MAX_AGE=0 et l’identifiant PostgreSQL SauverNdeko-Django. Après vingt requêtes HTTP successives, le nombre de connexions de la nouvelle instance reste à zéro. Les connexions se ferment à la fin de la requête HTTP ; aucun relèvement de max_connections n’a été effectué. L’ancienne instance Django du port 5001 ne peut pas être arrêtée avec le jeton Windows disponible : accès refusé. Utiliser l’instance mise à jour sur http://localhost:5176 ; les anciennes fenêtres pourront être fermées depuis leur session administrateur.

## Limites d’exploitation

La connexion de l’application reste en lecture seule. Les écritures ont été vérifiées sur la copie isolée ; leur activation en exploitation exige une fenêtre choisie et les règles de déploiement habituelles.

Le modèle ne garantit pas encore une propriété d’organisation immuable pour les articles et commandes : elle dépend du créateur actuel. Le référentiel universel des clients/fournisseurs et la devise par document ne sont pas définis. La clôture continue de suivre StatusFacture et son prédicat commun ; la création d’un CodeFacture ne remplace pas un parcours formel de validation de facture.

Les notifications de licence par trigger réagissent à une écriture ; aucune tâche quotidienne de rappel n’est installée. Les dix anciennes images d’audit contenant des champs de mot de passe restent conservées en stockage historique, mais la vue et les réponses Django les masquent. Les nouveaux événements en sont dépourvus.

Les données géographiques gardent leurs rattachements disponibles : aucune aire de santé n’a été inventée pour les sites directement liés au niveau 3. La somme des populations déclarées reste la convention historique et ne prouve pas l’absence de chevauchement démographique.

L’état testé ne constitue pas une certification de tous les parcours ERP ni une mesure de charge de production. Les règles de validation métier restent nécessaires pour les étapes ultérieures de facturation, de fiscalité, de devises et d’isolation historique.

## Sources et fichiers

- [Migration appliquée](../../backend/database/migrations/20261024_04_coherence_schemas_metier.sql) et [retour arrière logique](../../backend/database/migrations/rollback/20261024_04_coherence_schemas_metier.sql).
- [Guide des fichiers SQL](../README.md), recettes et règles de nouvelle installation.
- [Comportement des triggers PostgreSQL 18](https://www.postgresql.org/docs/18/trigger-definition.html), [verrous](https://www.postgresql.org/docs/18/explicit-locking.html) et [validation des contraintes](https://www.postgresql.org/docs/18/sql-altertable.html).
