# Mises à jour de la base de données

## Principe

Une nouvelle livraison peut ajouter une colonne, une table, une vue ou un trigger en conservant les données existantes. Le code et les migrations sont versionnés ensemble dans Git. Chaque base possède son propre journal `systeme.T_MigrationSchema` : les entreprises partageant une même base reçoivent une seule mise à jour du schéma ; des installations distinctes doivent chacune recevoir la livraison.

Depuis la racine du dépôt, les scripts PostgreSQL métier se trouvent dans [`backend/database/migrations/`](../backend/database/migrations), avec le [manifeste de livraison](../backend/database/releases/manifest.json) et le socle dans `backend/database/releases/`. Le journal identifie chaque migration par sa version et son empreinte. Le déplacement des fichiers conserve donc les versions déjà appliquées.

L'ORM Django et les migrations natives de `public` restent séparés des schémas métier. Les modèles métier conservent `managed=False`. Les commandes de démarrage, le build frontend et le simple chargement d'un `.env` n'exécutent aucune migration.

## Socle existant et première attestation

`backend/database/releases/manifest.json` désigne le socle `baseline-20261104.json`. Il décrit 4 863 objets du catalogue métier et inventorie les 65 anciens fichiers de migration. Cette photographie a été comparée à une restauration privée de la base ; elle ne prétend pas que chacun des anciens scripts a été exécuté individuellement.

L'attestation vérifie le catalogue réel avant de créer une entrée de journal. Elle n'exécute aucun ancien script et ne permet pas de faire correspondre arbitrairement une ancienne base à la version courante. Un catalogue différent est refusé : les différences doivent être comprises et traitées par un parcours adapté.

Depuis la racine du projet, avec une connexion de maintenance explicitement choisie et une sauvegarde vérifiée :

```powershell
# Présenter le plan ; aucune écriture.
backend/.venv/Scripts/python.exe backend/manage.py migrer_metier

# Vérifier un premier socle ; aucune écriture sans --apply.
backend/.venv/Scripts/python.exe backend/manage.py migrer_metier --baseline backend/database/releases/baseline-20261104.json

# Attester le socle correspondant exactement au catalogue installé.
backend/.venv/Scripts/python.exe backend/manage.py migrer_metier --baseline backend/database/releases/baseline-20261104.json --apply
```

La connexion doit autoriser l'écriture pour la dernière commande. Sur un serveur distant, utiliser l'environnement `config.maintenance`, `DATABASE_URL` explicite et les paramètres TLS adaptés. Ne pas donner ce compte propriétaire au serveur HTTP.

Une installation vierge suit d'abord `preparer_installation` / `installer_instance`, avec le paquet contrôlé et les tables natives Django. Elle passe ensuite par l'attestation. La présence d'une table de journal vide issue de la structure n'est pas une attestation. Un transfert d'instance conserve le journal déjà présent et exige le contrôle du catalogue après restauration.

## Ajouter une nouvelle migration

1. Créer un **nouveau** fichier dans `backend/database/migrations/`, par exemple `20261105_01_contact_secondaire.sql`. Ne pas modifier les fichiers historiques ou le socle attesté.
2. Écrire le SQL progressif, ses préconditions et les `COMMENT ON` utiles. La transaction est gérée par le moteur : aucun `BEGIN`, `COMMIT`, `ROLLBACK`, commande psql ou index `CONCURRENTLY` dans ce parcours.
3. Ajouter l'entrée à la fin de `backend/database/releases/manifest.json`, avec un identifiant unique, le fichier, ses dépendances, sa description, sa version et son empreinte.
4. Tester l'évolution sur une copie restaurée avec données représentatives : conservation, droits, anciennes références, vues et triggers, échec et rejeu.
5. Actualiser les définitions canoniques concernées et les contrats backend/frontend. Un instantané complet de structure sert à une base vide ; il ne doit pas remplacer les tables d'une base cliente.

Exemple d'entrée à adapter à la vraie évolution ; elle n'est pas une migration actuellement en attente :

```json
{
  "id": "20261105_01_contact_secondaire",
  "file": "../migrations/20261105_01_contact_secondaire.sql",
  "sha256": "EMPREINTE_CALCULEE_DU_FICHIER",
  "dependsOn": ["20261104_socle"],
  "description": "Ajouter les coordonnées secondaires nécessaires au parcours validé.",
  "release": "VERSION_DE_LA_LIVRAISON"
}
```

Les empreintes utilisent `sha256-utf8-lf-v1` : texte UTF-8, sans BOM, retours de ligne LF. Le SQL exécuté est exactement ce texte normalisé. Cela évite qu'un checkout Windows change une empreinte sur Linux. Calculer l'empreinte avec `apps.core.schema_migrations.sha256_file`, sans la recopier depuis un autre fichier.

Les dépendances forment une chaîne explicite depuis le socle. Un nouveau fichier SQL ne devient pas exécutable simplement parce qu'il est présent dans le dossier : il doit être inscrit dans le manifeste. Les fichiers historiques inventoriés sont vérifiés et restent exclus de cette chaîne future.

## Mettre à jour une instance

```powershell
# Plan et contrôle des versions/définitions.
backend/.venv/Scripts/python.exe backend/manage.py migrer_metier

# Appliquer uniquement les migrations manquantes, dans l'ordre.
backend/.venv/Scripts/python.exe backend/manage.py migrer_metier --apply --release VERSION_DU_CODE

# Refuser une migration manquante ou un catalogue divergent.
backend/.venv/Scripts/python.exe backend/manage.py migrer_metier --check
```

Le journal enregistre identifiant, empreinte, dépendances, date, durée, version applicative et empreintes du catalogue après réussite. Un verrou empêche deux exécutions simultanées. Chaque migration et son entrée de journal partagent la même transaction : l'échec de cette migration annule ses changements et son inscription. Les migrations précédentes déjà réussies restent appliquées ; il n'est pas annoncé de transaction globale entre tous les fichiers.

Un second appel sans changement ne rejoue rien. Un ancien fichier modifié, un historique inconnu, une dépendance incohérente, un schéma altéré hors du parcours ou une base non attestée font échouer la mise à jour. Le plan et `--check` sont en lecture seule. Une erreur ne déclenche ni réinitialisation, ni suppression de données, ni retour arrière automatique.

## Déploiement et protection des données

Une livraison doit identifier la sauvegarde DB/médias et sa restauration de recette, puis réserver une fenêtre adaptée. Les évolutions compatibles sont privilégiées : ajouter le nouveau champ, adapter progressivement le code et retirer un ancien champ dans une livraison ultérieure si nécessaire. Les corrections de données sont préparées et vérifiées comme des opérations métier distinctes ; elles ne découlent pas d'une comparaison automatique des modèles.

Une ancienne version du backend peut encore fonctionner pendant le début d'un déploiement : une migration incompatible exige l'arrêt des écritures. Revenir à un commit ne remet pas la base à sa version précédente. Une migration corrective est généralement préférable à une restauration qui effacerait les opérations intervenues depuis la sauvegarde.

Le compte web conserve les droits métier nécessaires, mais aucun droit de création de schéma ni d'écriture du journal. Le script `deploy/production/role-runtime.sql` rétablit les droits sur les nouveaux objets et maintient l'exception de lecture seule du journal. Les ACL et propriétaires sont contrôlés séparément du catalogue de structure.

Voir [le parcours Render](deploiement-render.md) pour la première installation, les secrets, le disque média et le workflow de livraison du commit exact. Un push n'envoie pas `backend/.env`, n'atteste pas une sauvegarde et n'initialise pas une nouvelle base distante.

## Portée du contrôle de catalogue

Le socle vérifie les neuf schémas métier : schémas, relations, colonnes dans leur ordre visible, contraintes, index, vues, fonctions/procédures, triggers, types, structure des séquences, politiques RLS, règles et commentaires pris en charge. Les données, numéros courants des séquences, propriétaires et ACL sont exclus. Les tables natives Django dans `public` suivent `migrate` et `migrate --check`.

Le journal est exclu de sa propre photographie pour éviter une dépendance circulaire ; sa forme et son contenu sont contrôlés séparément. Le fingerprint reste un contrat du socle PostgreSQL 18 utilisé par le projet, pas une comparaison sémantique universelle de SQL. Les différences de reconstruction d'un tableau de constantes varchar/text sont normalisées dans une grammaire strictement limitée ; les autres différences de définition sont signalées.

Trois commentaires de contraintes-triggers omis lors de la restauration PostgreSQL ont dû être réinjectés explicitement sur la copie privée pour obtenir l'égalité du catalogue. Le préparateur de paquet métier possède déjà ce complément documentaire ; une restauration distante doit contrôler ces commentaires au lieu de masquer la divergence.

## Recette du 4 novembre 2026

La sauvegarde préalable contient 81 tables et six médias ; les 81 empreintes de tables ont été vérifiées sur une copie restaurée. Le catalogue de la source et de la copie préparée est identique sur 4 863 objets. Le socle a ensuite été attesté sur cette copie, puis dans SauverNdeko : les données des 81 tables anciennes sont restées identiques, une seule entrée de journal a été créée et le second passage n'a exécuté aucune migration.

Résultats réellement exécutés : 21 tests unitaires du moteur, 26 tests PostgreSQL sur copie privée et 16 tests de préparation Render réussis. Ils couvrent notamment l'ajout de colonne/table/vue/fonction/trigger avec conservation des données, les transactions, le rejeu, les dépendances, la concurrence, les droits du journal et les refus d'états incohérents. Le contrôle SQL réel du rôle Render a été testé avec et sans journal. Les commandes Django `check`, `migrer_metier --check` et `migrate --check` réussissent sur l'instance locale. Après démarrage par le lanceur du projet, `/health` et `/catalogue` répondent HTTP 200.

Les deux structures canoniques ont été restaurées dans des bases privées vides : 82 tables pour la structure complète, 72 pour la structure métier, aucune ligne de données. Le journal vide conserve ses contraintes et commentaires. Le catalogue métier restauré correspond exactement au socle ; le prévol d'attestation réussit et `--check` refuse correctement l'absence d'attestation. Ces restaurations ne remplacent pas la recette du paquet d'installation complet avec initialisation des référentiels.

L'activation sur un compte Render, les secrets de production, la construction Linux complète et la recette métier sur le domaine déployé restent des vérifications de la première mise en ligne ; les tests locaux ne les remplacent pas.
