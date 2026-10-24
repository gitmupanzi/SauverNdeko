# Architecture backend — Django, 24/10/2026

Le backend actif est Python/Django 5.2 LTS + Django REST Framework. La conversion initiale a conservé PostgreSQL. Le propriétaire a ensuite autorisé les migrations natives Django dans public ; les schémas métier sont conservés. L’audit métier ultérieur a fiabilisé les routines et ajouté le socle analytics dans la migration 04.

| Emplacement | Responsabilité |
|---|---|
| manage.py, start.ps1 | Commandes Django et démarrage local sur 127.0.0.1:5000 |
| config/settings.py | .env existant, connexion unique, lecture seule par défaut, CORS autorisé |
| config/urls.py | Routes React, modules REST et alias historiques |
| apps/accounts | JWT HS256 existants, bcrypt/Django, profil et inscription sans attribution de privilège client |
| apps/core/models.py | 31 modèles managed=False, noms PostgreSQL qualifiés et clés composées |
| apps/core/registry.json | Métadonnées de 31 tables/48 vues ; aucun Prisma à l’exécution |
| apps/core/repository.py | Validation typée, pagination/comptages, écritures, audit transactionnel |
| apps/core/permissions.py | Droits globaux/locaux et refus des objets sans périmètre démontré |
| apps/core/ui_settings.py | Paramétrage T_Fk_Correspondance sans création de stockage au premier appel |
| apps/logistique | Lectures de vues, mutation de lignes, stock PostgreSQL et dashboard |
| apps/catalogue | Projections publiques explicites sans informations de connexion |
| apps/communication | Discussions limitées aux participants et gestionnaires de structure |
| requirements.txt | Dépendances Python verrouillées ; aucun paquet npm backend ni client Prisma conservé |

Les espaces public, connecté, administration et logistique gardent leurs préfixes. Le CRUD générique ne peut pas contourner les routes de stock, journaux ou règlements. L’API privée impose l’authentification puis les droits à chaque requête. L’administration reste celle de React ; les tables natives auth/admin/contenttypes/sessions sont installées dans public et l’administration technique est accessible sur /django-admin/ du backend. Les comptes API métier restent dans systeme en attente d’un rapprochement explicite des identités.

La source analytics.T_Recherche est installée ; son registre GET est réservé à l’administration globale. Les identifiants client des commandes n’ont pas de FK assurant un référentiel tiers universel. L’organisation des objets logistiques est dérivée de l’auteur actuel ; les lignes vérifient commande et article. Le modèle multidevise et la propriété immuable demandent un chantier PostgreSQL distinct, non réalisé ici.

Voir [le bilan métier et technique](../../../SQL/documentation/Audit_Metier_20261024.md) et [le guide de démarrage](../../README.md).

Le socle natif est documenté dans [le bilan PostgreSQL](../../../SQL/documentation/Django_Public_20261024.md). Les migrations du socle sont distinctes des scripts SQL métier.
