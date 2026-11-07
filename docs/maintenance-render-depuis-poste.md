# Maintenance Render depuis le poste

Procédure préparée le 7 novembre 2026. Aucune des opérations distantes ci-dessous n'a été exécutée pendant cet audit. Le parcours GitHub reste disponible après résolution de son blocage de facturation. Ce parcours local permet d'effectuer la même préparation avec un poste équipé, sans donner de droits de maintenance au serveur web.

La [livraison exécutée ensuite le 7 novembre](livraison-render-20261107.md) documente la construction dans Render, la restauration testée et les commandes de maintenance effectivement appliquées. Elle distingue ce parcours de l’exécution du runner `apply` sur un poste équipé de Docker.

## Conditions avant application

- Intégrer et publier les corrections locales, puis utiliser une copie propre de `main` exactement au commit à livrer. Le programme refuse une branche différente, un arbre modifié ou un SHA différent de `origin/main`. Faire `git fetch origin main` avant de relever le SHA. Une référence distante locale peut être ancienne ; ce contrôle ne remplace pas l'examen du commit dans Render.
- Vérifier les tests et la restauration sur une copie isolée. Préparer une fenêtre sans écritures clientes pour la maintenance et la bascule ; le script ne suspend pas lui-même le service.
- Télécharger l'export PostgreSQL, relever son nom exact et sa somme SHA-256, restaurer une copie de recette, comparer les données et le catalogue. Sauvegarder et restaurer aussi les médias du disque. Un export Render marqué terminé ou une phrase dans `backup_reference` ne constitue pas cette preuve.
- Disposer de Python 3.12 et des dépendances exactes de `backend/requirements.txt`, de Node 22/npm, de Docker opérationnel et des outils PostgreSQL 18. Le mode `apply` construit réellement l'image avant toute migration. Le poste de cet audit n'a pas Docker et ne peut donc pas exécuter cette étape.
- Vérifier dans Render que **Auto-Deploy est désactivé**, et qu'aucune livraison concurrente n'est en cours. La sérialisation GitHub ne couvre pas un lancement depuis le poste. Ne pas lancer les deux parcours simultanément.
- Disposer de l'URL **externe** du propriétaire PostgreSQL, des droits de maintenance et d'une autorisation réseau pour l'adresse de sortie du poste. L'URL du compte `sauverndeko_runtime` reste exclusivement destinée au web. Ne pas élargir les privilèges du web pour passer les migrations.

## Configuration privée dédiée

Toutes les commandes de cette page sont à exécuter depuis `C:\Users\Benjamin-mupanzi\Documents\SauverNdeko`, en PowerShell. Ne pas remplacer `backend/.env` de développement par les identifiants de production.

Créer manuellement `.runtime/render-maintenance.env`, ignoré par Git. Le programme accepte uniquement ces trois clés. Remplacer les paramètres indicatifs dans le fichier privé, sans les coller dans le terminal ou le chat.

```dotenv
MAINTENANCE_DATABASE_URL=postgresql://PROPRIETAIRE:MOT_DE_PASSE_ENCODE@HOTE_EXTERNE:5432/sauver_ndeko_pro
SAUVERNDEKO_DB_SSLMODE=verify-full
SAUVERNDEKO_DB_SSLROOTCERT=C:/CHEMIN_PRIVE/autorites-de-confiance.pem
```

Le certificat doit être un fichier CA de confiance vérifié, pas un certificat récupéré et accepté aveuglément depuis un serveur. Le runner refuse de réduire la vérification TLS pour une connexion distante. Il n'utilise ni le `DATABASE_URL` courant ni un repli implicite vers le `.env` local comme destination. Les options SSL explicites sont celles utilisées par Django et `psql`.

Mettre PostgreSQL dans le PATH du seul terminal et relever le SHA choisi.

```powershell
$env:PATH = 'C:\Program Files\PostgreSQL\18\bin;' + $env:PATH
git fetch origin main
$ReleaseCommit = (git rev-parse origin/main).Trim()
git status --short --branch
git rev-parse HEAD
```

Ces commandes ne modifient aucune base. Vérifier que `HEAD` correspond à `$ReleaseCommit` et que le dépôt est propre. Arrêter le frontend local par son lanceur officiel avant un `npm ci` s'il verrouille esbuild ; le relancer après les vérifications. Le programme ne tue aucun processus.

## Plan sans modification

```powershell
.\backend\.venv\Scripts\python.exe deploy/render/maintenance_local.py plan `
  --commit $ReleaseCommit `
  --env-file .runtime/render-maintenance.env `
  --database-host dpg-dbm5tjgae00c738euuog-a.oregon-postgres.render.com `
  --database-name sauver_ndeko_pro
```

Cette commande utilise `config.maintenance` avec le **propriétaire**, mais force `SAUVERNDEKO_DB_READ_ONLY=1` et donc `default_transaction_read_only=on`. Elle présente `migrer_metier` puis `migrate --plan`. Aucun `--apply`, `migrate --noinput`, octroi de droits ou hook Render n'est exécuté. Les quatre évolutions du 6 novembre doivent apparaître si elles sont toujours absentes. Si le contrôle signale une dérive ou un socle inconnu, interrompre la livraison et comprendre l'écart ; ne pas attester à nouveau le socle pour contourner le refus.

## Application explicitement autorisée

Seulement après sauvegarde/restauration vérifiée, autorisation d'exploitation et préparation de la fenêtre de maintenance, renseigner une référence correspondant à une preuve réelle.

```powershell
.\backend\.venv\Scripts\python.exe deploy/render/maintenance_local.py apply `
  --commit $ReleaseCommit `
  --env-file .runtime/render-maintenance.env `
  --database-host dpg-dbm5tjgae00c738euuog-a.oregon-postgres.render.com `
  --database-name sauver_ndeko_pro `
  --backup-reference 'REFERENCE_REELLE_DU_RAPPORT_DB_ET_MEDIAS_RESTAURES' `
  --confirm-maintenance
```

Le tableau décrit les sous-commandes réellement orchestrées, toutes depuis la racine du dépôt sauf npm dans `frontend`. La configuration de maintenance est transmise uniquement aux étapes PostgreSQL. Les tests/builds ne reçoivent ni URL de base ni secret de maintenance. Les fichiers privés internes sont limités à `.runtime`, exclu du contexte Docker ; un simple fichier ignoré par Git dans `backend` n'est pas accepté.

| Étape | Configuration et rôle | Effet et prérequis | Résultat attendu |
|---|---|---|---|
| `unittest ... test_render*.py` et `test_backup_constraint_comments.py` | Python local, aucun rôle PostgreSQL | Tests simulés, sans connexion DB | Tous réussis |
| `npm ci`, `npm run test:ux`, `npm run build` | Node/npm, dans `frontend` | Écrit uniquement dépendances et fichiers de compilation locaux | Tests réussis et `dist` construit |
| `docker build --file deploy/render/Dockerfile --tag sauverndeko-render-check:SHA .` | Docker local, sans secrets DB | Construction de contrôle avant toute écriture PostgreSQL | Image construite et Caddy validé |
| `migrer_metier` puis `migrate --plan` | `config.maintenance`, propriétaire, READ ONLY | Lecture du catalogue et du journal existants | Plan cohérent, sans dérive |
| `migrer_metier --apply --release SHA` | `config.maintenance`, propriétaire, écritures autorisées | Sauvegarde attestée, source propre recontrôlée | Migrations absentes appliquées dans l'ordre et journalisées avec ce SHA |
| `migrate --noinput` | Même propriétaire et configuration | Modifie uniquement les tables natives Django autorisées dans `public` | Aucun changement natif encore en attente |
| Script `deploy/production/role-runtime.sql` via `psql -X --set=ON_ERROR_STOP=1 --file ...` | Propriétaire de maintenance | Modifie les droits, dans sa transaction ; rôle et schémas déjà préparés | Accès aux nouveaux objets, protection du journal conservée |
| `migrer_metier --check` puis `migrate --check` | Propriétaire, READ ONLY à nouveau | Lecture finale | Les deux commandes réussissent |

Le programme s'arrête au premier échec et ne demande **aucun déploiement**. Chaque migration métier conserve sa transaction et sa ligne de journal. Une migration échouée est annulée avec son journal ; les migrations précédentes réussies restent appliquées. Une relance présente le nouvel état et saute les migrations déjà attestées. Les étapes métier, Django et droits ne forment pas une transaction globale. Ne pas poursuivre vers Render lorsqu'une étape échoue. Le moteur tient un verrou consultatif durant son application pour éviter deux exécutions concurrentes du moteur.

L'attestation saisie par l'opérateur ne peut pas être vérifiée automatiquement par ce runner. Conserver le rapport réel de restauration, les empreintes et l'autorisation d'exploitation dans le dossier de livraison privé.

## Demande de déploiement après maintenance

Dans Render, utiliser **Manual Deploy → Deploy a specific commit**, avec exactement `$ReleaseCommit`. Ne pas sélectionner par habitude le dernier commit d'une branche ayant avancé. Le pré-déploiement doit conserver `python deploy/render/predeploy.py` et le seul compte runtime. Il contrôle ses droits, Django, le schéma métier et les migrations natives avant le remplacement du service.

Le workflow GitHub utilise quant à lui `release.py deploy`, qui ajoute le même SHA au hook privé. Une réponse HTTP 200/202 indique une demande acceptée, pas une livraison terminée. Attendre le statut final dans Render, puis vérifier `/health`, la connexion/déconnexion, les droits par entreprise, les écritures autorisées et les photos/justificatifs. Vérifier le disque **réellement monté** et ses droits pour UID/GID 10001. Le `chown` du build ne prouve pas ceux du disque.

Le code source reste identique entre les étapes, mais Render reconstruit une image à partir des tags de base Docker. Ce parcours ne promeut pas un digest immuable construit par GitHub ou par le poste. Conserver les identifiants des builds et les journaux ; une promotion d'image par digest serait une évolution distincte.

## Installation vierge ou retour arrière

Une base existante avec migrations en attente n'a pas besoin d'être supprimée. Pour une installation parallèle réellement nécessaire, suivre [la livraison et l'installation vierge](livraison-logistique.md#installation-vierge) : paquet de structure complet, seed fermé des références communes, complément des commentaires de contraintes-triggers, séquences, catalogue, socle attesté, migrations futures, tables natives `public`, rôle runtime, puis compte administrateur et médias propres à cette instance. `initialiser_admin` refuse un système contenant déjà des utilisateurs. Un simple `manage.py migrate` ne crée pas les schémas métier `unmanaged`.

**Limite identifiée pendant cet audit :** le paquet exporté depuis la structure actuelle inclut déjà les migrations du 6 novembre, tandis que le socle publié décrit le 4 novembre. Restaurer ce paquet puis tenter de lui attester le socle ancien doit échouer. Cette voie d'installation courante reste à compléter et à tester avant utilisation ; elle ne constitue pas un raccourci pour réparer la base Render. La mise à niveau progressive de la base existante ne présente pas ce décalage.

Tester cette nouvelle instance avant toute bascule de connexion. Un retour au code précédent ne remet pas le schéma à l'état précédent. Privilégier une migration corrective compatible ; une restauration de production demande une procédure séparée pour éviter de perdre les opérations enregistrées depuis la sauvegarde.

Sources : [hooks Render et SHA](https://render.com/docs/deploy-hooks#deploying-a-specific-git-commit), [pré-déploiement Render](https://render.com/docs/deploys#pre-deploy-command), [sauvegardes et restauration parallèle](https://render.com/docs/postgresql-backups).
