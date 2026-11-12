# Socle natif Django dans public — 24/10/2026

Le propriétaire a explicitement autorisé les tables par défaut Django dans public après une première phase limitée au code, puis demandé de procéder comme administrateur de base de données. L’intervention est limitée aux objets natifs public et à leur documentation.

## Sauvegarde préalable

Une sauvegarde complète PostgreSQL au format custom a été créée avant toute migration :

C:/Users/Benjamin-mupanzi/Documents/SauverNdeko/.runtime/backups/avant-django-public-20261024-205626.dump

Taille : 11183230 octets. Archive lisible vérifiée avec pg_restore --list. Une restauration complète de cette archive n’a pas été exécutée pendant ce lot. Aucun mot de passe de connexion n’est enregistré dans les commandes ou comptes rendus.

## Migration exécutée

Django 5.2.18 LTS : 18 migrations standard des applications auth, admin, contenttypes et sessions, dans une transaction PostgreSQL globale et sous verrou de migration. search_path=public est imposé ; modèles métier unmanaged et noms qualifiés conservés. Le plan a été examiné avant application ; aucune migration native ne reste en attente.

Tables créées :

- auth_user, auth_group, auth_permission ;
- auth_user_groups, auth_user_user_permissions, auth_group_permissions ;
- django_content_type, django_admin_log, django_session, django_migrations.

Le socle contient 36 contenttypes et 144 permissions générées par Django, ainsi que 18 lignes d’historique de migrations. Aucun compte auth_user, groupe, session ou entrée de journal d’administration n’a été créé. Les trois comptes métier de systeme.T_Utilisateurs sont inchangés.

Aucune table métier n’est enregistrée dans l’administration native afin de ne pas contourner les services de stock et leurs validations. Les permissions natives ne sont pas présentées comme une migration déjà accomplie des droits ERP.

## Commentaires et intégrité

La migration SQL [20261024_03](../../backend/database/migrations/20261024_03_commentaires_django_public.sql) ajoute 162 commentaires : schéma (1), tables (10), colonnes (44), contraintes (68), index (30), séquences (9). Le [retour arrière](../../backend/database/migrations/rollback/20261024_03_commentaires_django_public.sql) ne restaure que les commentaires ; il ne supprime aucun objet ni donnée.

Le contrôle étendu à public trouve 1 720 objets/colonnes documentés et zéro commentaire manquant dans le périmètre applicatif : 40 tables, 39 vues, 1 064 colonnes, 300 contraintes, 172 index, 36 séquences, 27 fonctions, six procédures, 27 triggers et neuf schémas. Les objets d’extensions sont exclus selon le contrôle versionné. Tous les index natifs sont valides et toutes les contraintes natives validées.

Le droit CREATE sur public n’est pas accordé au rôle PUBLIC dans l’état constaté. Les droits existants n’ont pas été modifiés.

## Conservation du métier

La comparaison avant/après confirme :

| Élément | Résultat |
|---|---|
| Comptages/empreintes des lignes des 30 tables métier | Identiques |
| Catalogue des colonnes métier | Identique |
| Définitions des 39 vues | Identiques |
| Définitions des fonctions/procédures métier inspectées | Identiques |

Le nombre total de tables passe de 30 à 40 uniquement par l’ajout du socle public. Aucune table n’a été déplacée entre schémas. La question d’une fusion est traitée dans [la recommandation systeme/public](Decision_Systeme_Public_20261024.md).

## Commandes et exploitation

migrate est limité aux migrations natives vers leur version courante ; syncdb, fake, prune et retours vers une version ciblée sont refusés. makemigrations et flush restent désactivés. Le lancement BAT ne lance jamais migrate automatiquement.

Le backend reste en lecture seule par défaut. Pour appliquer une future migration native examinée, ou créer un administrateur technique avec createsuperuser, utiliser ponctuellement SAUVERNDEKO_DB_READ_ONLY=0 dans le processus concerné. L’administration /django-admin/ du backend a besoin d’écrire ses sessions et son journal lors d’une connexion réelle. Les données d’identité ne sont pas dupliquées sans rapprochement explicite.

L’administration native est disponible sur le backend local ; les écrans ERP restent React. Le serveur de développement sert les ressources statiques natives, sans activer DEBUG. L’installation client de production exige un serveur et une distribution statique adaptés.
