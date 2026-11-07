# Audit local de livraison Render — 7 novembre 2026

## Périmètre et état de départ

Audit effectué dans `C:\Users\Benjamin-mupanzi\Documents\SauverNdeko`. Au départ, branche `main`, arbre propre, `HEAD` et `origin/main` à `bb6d5040bded9ad16d7a496d62a3534809c73480`, exactement le commit des journaux fournis. Les corrections de cet audit restent locales, non commitées et non poussées. Aucun déploiement, migration distante, reset ou suppression de production n'a été exécuté. Les seules bases créées pour les essais sont locales, isolées et ont été retirées après contrôle.

Sources du diagnostic distant : journal Render joint du 6 novembre 2026, captures GitHub Actions et facturation, demande d'audit jointe. L'état actuel des comptes, secrets GitHub et réglages du tableau de bord Render n'a pas été consulté pendant cet audit local.

## Diagnostic confirmé

| Élément | Constat et implication |
|---|---|
| Docker | Les journaux fournis montrent compilation Vite, collecte statique, validation Caddy, construction et export de l'image réussis. Le Dockerfile et le démarrage locaux correspondent à cette architecture. Les deux avertissements Caddy n'expliquent pas le refus de pré-déploiement. |
| Pré-déploiement | Le contrôle du rôle runtime et `check` Django réussissent dans ce journal. Le contrôle métier s'arrête sur quatre évolutions manquantes. `migrate --check`, placé après, n'a pas encore été exécuté dans cette tentative distante. |
| GitHub Actions | L'exécution 42298012832 refuse de démarrer `build` pour facturation. `maintenance` et `deploy` sont sautés. Cette exécution n'a donc pas appliqué les migrations. Un changement de YAML ne régularise pas le paiement. |
| Migrations | Le manifeste et les sommes SQL sont cohérents. La chaîne est `20261104_socle` → `20261106_01_annonces_communication` → `20261106_02_discussions_directes` → `20261106_03_lecture_messages` → `20261106_04_offre_modules_entreprise`. Aucun fichier publié ni socle n'a été modifié. |
| Reprise après échec | Le moteur tient un verrou consultatif ; chaque migration et son journal partagent une transaction. Une erreur annule cette migration, les précédentes restent attestées. Les tests PostgreSQL couvrent échecs, relances, refus des dérives et journal. Le plan utilise une transaction de lecture seule. |
| Droits | Le web reste sous `sauverndeko_runtime`. Le compte propriétaire exécute la maintenance et le script transactionnel de droits après les nouveaux objets. Le pré-déploiement conserve son contrôle des droits réels du runtime. Aucune élévation du compte web n'a été ajoutée. |
| Sauvegarde Render | L'export affiché terminé à 22:18 est une preuve de génération. Le fichier téléchargé, sa restauration, les médias et leur sauvegarde restent à confirmer. Aucun champ saisi dans GitHub ne crée ces preuves. |

Le workflow vérifie, migre puis demande le **même SHA source**, avec checkout explicite à chaque job et `ref=SHA` sur le hook. Il ne promeut pas une image par digest : Render reconstruit avec des tags Docker de base mutables. Les validations Docker et l'identité de source restent utiles, sans prétendre garantir des octets d'image identiques.

## Corrections locales

- `.github/workflows/livraison-render.yml` fixe les trois runners à `ubuntu-24.04`, installe les dépendances Python avant les tests qui en ont besoin et inclut les nouveaux tests de maintenance/sauvegarde. La séquence build → maintenance → deploy, le déclenchement manuel et les confirmations restent conservés.
- Les sauvegardes produites par `apps/core/maintenance.py` passent au **format 2**, avec `constraint-comments.sql`, son SHA-256 et son nombre de commentaires. PostgreSQL 18 omettait trois commentaires portés par des contraintes-triggers dans le dump restauré. Ces métadonnées participent à l'empreinte du schéma. `restaurer_recette` valide le complément avant création, le rejoue dans la destination privée et compare le résultat. `verifier_livraison` accepte formats 1/2 ; un ancien format ne bénéficie pas d'une preuve absente. Le préparateur d'installation réutilise le même générateur SQL. Aucun contrôle d'empreinte n'a été affaibli.
- `deploy/render/maintenance_local.py` fournit un plan réellement READ ONLY et une application séparée exigeant confirmations, destination hôte/port/base, TLS vérifié, source propre égale à `origin/main`, tests et build Docker réussis avant mutation. Le fichier privé réside dans `.runtime` ou hors dépôt. Les mots de passe restent dans l'environnement des processus concernés ; les sorties capturées sont traitées en UTF-8 et masquées, y compris sous Windows. Le programme ne déclenche aucun déploiement.
- `release.py` partage la seule étape d'actualisation SQL des droits avec ce runner. Les gardes de livraison GitHub restent en place. Les variables PostgreSQL héritées sont éliminées avant de composer la connexion `psql` explicite.
- `.dockerignore` exclut aussi les fichiers `*.env` et `.env_*`, en complément de `.runtime` et `.env.*`. Un fichier simplement ignoré par Git n'est pas nécessairement exclu d'une image Docker ; le runner interdit donc les fichiers privés ailleurs dans le dépôt.
- `frontend/package-lock.json` actualise neuf paquets signalés et 21 éléments existants de leur graphe, sans nouvelle dépendance ni changement majeur. Les plages de `package.json` sont inchangées. React Router passe de 7.14.2 à 7.18.5, Vite de 6.4.2 à 6.4.5. L'audit npm final retourne zéro vulnérabilité déclarée. Aucun exploit applicatif n'a été reproduit ; plusieurs avis concernent des modes SSR/RSC absents du `BrowserRouter` actuel ou des outils de développement exclus de l'image finale.

## Tests réellement exécutés

| Vérification | Résultat |
|---|---|
| Tests Render et runner local, `test_render*.py` | **34 réussis**, sans connexion distante ; destination incorrecte, rôle runtime, refus TLS affaibli, absence Docker, confirmations, identité du commit, ordre build/migrations/droits, arrêt sur erreur et masquage UTF-8 couverts |
| Complément des sauvegardes | **11 réussis**, notamment altération/refus avant création, format historique et exactitude des commentaires |
| Moteur de migration, unitaires | **21 réussis** |
| Moteur de migration, PostgreSQL réel | **26 réussis** sur clone local isolé, environ 224 secondes |
| Sauvegarde puis restauration réelle format 2 | **84 tables, 6 médias, 3 commentaires de contraintes-triggers**, empreintes exactes ; catalogue de **4 980 objets** identique ; `migrer_metier --check` réussi sans réinjection manuelle |
| Runner `plan` sur une seconde restauration | Réussi, aucune évolution métier ou Django en attente, connexion READ ONLY, aucun `apply` |
| Préservation de la source | Lignes des 84 tables, séquences et catalogue identiques avant/après ; les clones exacts ont été supprimés |
| Frontend après correction du lockfile | `npm ci` réussi, **384 contrôles UX** réussis, `npm run build` réussi avec **350 modules** et **136 fichiers**, `npm audit --json` retourne **0** |
| Python/statique | Compilation Python réussie ; collecte effective de **154 fichiers statiques**, avec URL DB factice sur port fermé |
| YAML/diff | YAML analysé et séquence des jobs vérifiée ; contrôle `git diff --check` réussi |

Le premier `npm ci` a rencontré un verrou esbuild du serveur local. Les services ont été arrêtés puis relancés avec le lanceur officiel, après contrôle de leur identité. Les résultats indiqués sont ceux des exécutions complètes suivantes, après correction des dépendances. Le postinstall esbuild a réellement terminé avec code 0 malgré l'avertissement npm `allowScripts`.

Versions du poste : Python 3.12.10 dans `backend/.venv`, **18/18 dépendances backend** conformes au fichier `requirements.txt`, Node 24.21.0/npm 11.19.0. La CI et Docker ciblent Node 22 ; cette version Linux n'a pas été exécutée ici. Les contrôles UX sont simulés en DOM et ne valent pas recette visuelle dans un navigateur.

Docker, Caddy, bash et actionlint sont absents du poste. Aucun build Docker Linux ni `caddy validate` local n'a été exécuté. Le succès Docker mentionné plus haut provient des journaux Render fournis pour le commit précédent aux corrections. Une nouvelle construction reste nécessaire pour le futur commit.

Preuves privées dans `.runtime/audit-render-20261107` : `backup-engine-proof.json`, `schema-postgresql-tests.log`, `maintenance-runner-plan-proof.json` et rapports de restauration voisins. Les sauvegardes et médias ne sont pas publiés dans Git.

## Installation vierge : point ouvert

`preparer_installation.py` exporte la structure courante, déjà enrichie par les quatre migrations du 6 novembre. Ses seeds fermés excluent le journal `T_MigrationSchema`. `installer_instance.py` applique les fichiers et les migrations natives Django, mais n'atteste pas cette chaîne métier. Avec un journal vide, le moteur exige le socle publié du 4 novembre, qui contient **4 863 objets**, contre **4 980** pour le schéma courant. Leurs empreintes diffèrent, comme attendu.

Le parcours d'installation vierge courant reste donc à compléter et à recetter avant usage client. Aucune suppression de la base Render n'est justifiée par les journaux de migrations en attente. La maintenance progressive de la base existante reste le chemin recommandé. Ne pas éditer le socle ou faire une nouvelle attestation arbitraire pour forcer une installation.

## Suite recommandée

1. Intégrer les corrections locales dans un commit de livraison validé. Vérifier sa construction Docker sur un environnement équipé avant toute écriture distante.
2. Télécharger et restaurer la sauvegarde Render, sauvegarder/restaurer les médias et conserver les preuves. L'export `.dir.tar.gz` Render ne comporte pas automatiquement le complément de métadonnées de l'outil local ; comparer le catalogue restauré et préparer ce complément depuis une source autorisée si nécessaire, sans contourner la comparaison.
3. Dans GitHub, régulariser le blocage de facturation puis vérifier l'environnement `render-production`, ses protections et les deux secrets `MAINTENANCE_DATABASE_URL`/`RENDER_DEPLOY_HOOK_URL`. Leur présence actuelle n'est pas attestée par cet audit.
4. Dans Render, vérifier Auto-Deploy désactivé, les identifiants **runtime** du service web, les accès réseau de maintenance, le disque média et ses droits. Ne pas placer le propriétaire dans `DATABASE_URL` du service web.
5. Lancer la livraison contrôlée depuis `main` avec une référence de sauvegarde réelle et la confirmation de maintenance. Si GitHub reste indisponible, utiliser le [parcours depuis le poste](maintenance-render-depuis-poste.md) sur un poste équipé. Les commandes, répertoires, rôles, effets et résultats attendus y sont détaillés.
6. Attendre la fin du déploiement Render du SHA exact, puis vérifier connexion/déconnexion, permissions par entreprise, opérations métier et médias. Une demande de hook acceptée n'est pas une preuve de service opérationnel.

Références officielles consultées : [compte GitHub verrouillé](https://docs.github.com/en/billing/how-tos/troubleshooting/locked-account), [transition ubuntu-latest](https://github.com/actions/runner-images/issues/14748), [pré-déploiement Render](https://render.com/docs/deploys#pre-deploy-command), [hook et commit exact](https://render.com/docs/deploy-hooks#deploying-a-specific-git-commit), [sauvegardes Render](https://render.com/docs/postgresql-backups), [avis React Router](https://github.com/advisories/GHSA-wrjc-x8rr-h8h6), [avis Vite/launch-editor](https://github.com/advisories/GHSA-r825-w8mm-5pxw).
