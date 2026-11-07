# Livraison Render exécutée — 7 novembre 2026

Le service public [SauverNdeko](https://sauverndeko.onrender.com/catalogue) a été mis à jour avec le commit applicatif **`10014c41ad7c08689cc117ec1c22f5c33fd48a13`**. Render a confirmé « Deploy succeeded / Live » à **11:03 UTC**. Le déploiement final est `dep-dbnga8h5efls73b8v0t0` sur le service `srv-dbm85ik9v7es7395g7p0`.

## Sauvegarde et répétition sur copie

Avant toute écriture distante, une sauvegarde cohérente du PostgreSQL de production et du disque média a été créée puis restaurée dans une base locale isolée. Les contrôles ont établi :

- 82 tables et 6 médias restaurés exactement ; 3 commentaires de contraintes-triggers réappliqués et comparés ;
- catalogue identique de 4 863 objets, empreinte `3adeabb830925569bcc3c6e4c689baf35385e1edb7ca94a62ab05b23f9e77100` ;
- source consultée en lecture seule avec TLS `verify-full`, catalogue et médias stables pendant la sauvegarde ;
- quatre migrations répétées avec succès sur cette copie, puis contrôles métier et Django réussis ;
- cinq tests réels de l’API des annonces réussis sur la copie, empreintes des 84 tables après migration identiques avant/après rollback des tests.

L’export distant a dépassé le délai de 180 secondes au premier essai. Le second essai privé a utilisé 900 secondes pour `pg_dump`, sans changer le code publié. Une première exécution des tests API héritait d’une redirection HTTPS locale inadaptée ; elle a été corrigée seulement dans l’environnement du test avant la recette réussie.

Sauvegardes, médias, clone et preuves sont conservés hors Git dans `.runtime/livraison-render-20261107/attempt2/`. Le clone est `sauverndeko_test_prod_render_20261107`. Le dump vérifié porte l’empreinte SHA-256 `ad50c43188157f000a84b19fe3e6a7af1dac873fbe6f6dba6632d9e3c6bb50e2`.

## Installation réelle

GitHub Actions ne pouvait pas démarrer à cause du verrouillage du compte pour facturation. La livraison a donc utilisé la construction Docker réelle dans Render, puis les commandes de maintenance explicites depuis le poste. Le runner local `apply`, qui exige Docker local, n’a pas été contourné : Docker est absent du poste ; sa construction a été effectuée et observée dans Render.

La première construction du commit exact a réussi ; son pré-déploiement a correctement refusé les quatre migrations encore absentes. Après activation de la maintenance native Render et vérification d’une réponse publique HTTP 503, le propriétaire PostgreSQL a appliqué :

1. `20261106_01_annonces_communication` ;
2. `20261106_02_discussions_directes` ;
3. `20261106_03_lecture_messages` ;
4. `20261106_04_offre_modules_entreprise`.

Chaque entrée du journal porte le SHA applicatif ci-dessus. Les migrations natives Django ne nécessitaient aucun changement. Le script transactionnel des droits runtime a été rejoué, puis les deux contrôles de migrations ont réussi. L’empreinte finale du catalogue est `82b26ab95fd461a5d342778ba4f9399900ad60c8067118637780092d3d57a0a2`, identique à celle de la copie testée.

Render a ensuite redéployé le même commit, avec le pré-déploiement inchangé et réussi. Auto-Deploy reste désactivé. La maintenance native a été retirée après les contrôles internes. La variable `MAINTENANCE_MODE` du fichier d’environnement n’active pas cette maintenance native ; utiliser le réglage Render du service.

## Vérifications après mise en ligne

- SHA du processus distant vérifié par SSH : `10014c41ad7c08689cc117ec1c22f5c33fd48a13`.
- Pré-déploiement rejoué dans l’image active : rôle limité, contrôle Django, schéma et migrations natives réussis.
- Compte web `sauverndeko_runtime` sans propriété d’objets ni droits de maintenance ; propriétaire conservé dans un fichier privé distinct.
- Six médias initiaux présents avec les mêmes empreintes ; disque accessible en écriture à UID 10001.
- HTTP 200 sur `/health`, `/catalogue` et `/login` ; `/health` indique `databaseReadOnly: false`.
- HTTP 401 sans authentification sur `/api/discussions`, `/api/discussions/annonces/contexte` et `/api/notifications`.

Le 502 isolé du journal précède l’écoute de Waitress de moins d’une seconde. Il appartient au démarrage de cette tentative ; Render a ensuite validé la santé du service. Les avertissements Caddy de mise en forme et d’en-tête superflu n’ont pas empêché la construction ou la mise en service.

Les preuves finales privées sont dans `.runtime/render-release-20261107/` : `maintenance-report.json`, `render-build-proof.json`, `online-verification.json` et `anonymous-api-proof.json`. Aucun secret ni dump n’est ajouté au dépôt. `backend/.env` a été rétabli pour la base locale ; sa version de production reçue est conservée dans une copie privée.

## Limites restantes

La facturation GitHub Actions et les secrets de son environnement de livraison restent à configurer pour rétablir l’automatisation. Cette mise en ligne ne constitue pas une recette navigateur exhaustive de tous les parcours ni une délivrance Gmail testée. Aucun document métier fictif n’a été créé en production pour cette vérification.

La voie d’installation vierge depuis la structure actuelle conserve le décalage de socle décrit dans [l’audit initial](audit-livraison-render-20261107.md) ; elle n’a pas été utilisée pour cette mise à niveau. Une restauration de production resterait une opération distincte, à cadrer en fonction des écritures postérieures à la sauvegarde.
