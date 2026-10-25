# Décision d’accès à PostgreSQL — actualisation du 24/10/2026

Le propriétaire a choisi Django après comparaison avec Express, puis a demandé de transformer le dossier backend en précisant de ne pas modifier la base. Cette décision remplace la recommandation initiale de conserver Express/Prisma pendant la seule cartographie.

Architecture active : React → Django REST Framework → connexion Django/psycopg → PostgreSQL existant. Les vues et routines restent les sources métier. Le code Python n’a aucune dépendance à Prisma ; l’ancien backend, son client généré et ses dépendances Node ont été supprimés à la demande du propriétaire.

Les 30 modèles unmanaged reflètent les tables installées. Les lectures métier utilisent des vues SQL paramétrées. Les écritures passent par les services et tables existantes, avec verrous/transactions et triggers PostgreSQL. Aucun ORM n’impose de recréer ces objets : managed=False empêche Django d’en gérer le schéma.

La connexion PostgreSQL est en lecture seule par défaut. Le propriétaire a ensuite autorisé les dix tables natives Django dans public, leurs migrations et commentaires. La création d’une base de recette, d’un schéma métier nouveau ou de données fictives reste hors de ce lot. Les tests sans base et les GET de diagnostic ne prouvent pas les écritures réelles.

Références primaires : [base existante et modèles unmanaged](https://docs.djangoproject.com/en/5.2/howto/legacy-databases/), [SQL paramétré](https://docs.djangoproject.com/en/5.2/topics/db/sql/), [transactions](https://docs.djangoproject.com/en/5.2/topics/db/transactions/).
