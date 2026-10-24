---
name: sauverndeko-backend
description: Maintenir le backend Django et Django REST Framework de SauverNdeko sur PostgreSQL existant, avec vues SQL, droits serveur et transactions métier. Utiliser pour API, comptes, permissions, stock, calculs et performances backend.
---

# Backend SauverNdeko

## Architecture active

Le propriétaire a autorisé la conversion du dossier backend vers Django le 24/10/2026, puis a limité initialement le travail aux fichiers. Il a ensuite explicitement autorisé les tables natives Django dans le schéma public et demandé une intervention d’administrateur de base de données. Django/DRF est le seul backend. Le propriétaire a ensuite demandé la suppression d’Express/Prisma, de son client généré, de ses dépendances et des lanceurs npm du backend. React et les contrats d’URL restent en place.

- Lire [l’architecture](references/architecture.md) pour les points d’entrée et les responsabilités.
- Lire [la décision d’accès PostgreSQL](references/decision-acces-postgresql.md) pour la décision mise à jour.
- Lire [le bilan métier et technique](../../SQL/documentation/Audit_Metier_20261024.md) pour les vérifications et limites.
- Lire [vues et commentaires](references/vues-et-commentaires.md) pour les sources SQL ; ses évolutions déjà appliquées sont historiques et ne doivent pas être rejouées pendant une conversion de code.
- Pour Excel/Word/PDF, appliquer le [skill documentaire](../../skills/document-mise-en-forme/SKILL.md).

## Préserver PostgreSQL existant

Les modèles métier sont managed=False. Les migrations natives admin/auth/contenttypes/sessions sont autorisées uniquement dans public, avec search_path=public, sauvegarde et contrôle préalable du plan. makemigrations, flush, syncdb, fake et retours arrière de migration restent désactivés. Ne modifier aucun schéma métier ni créer de base de recette ou de donnée fictive pour une intervention limitée au backend. SAUVERNDEKO_DB_READ_ONLY=1 est le défaut ; ne pas le désactiver pour faire passer une vérification. Le propriétaire a ensuite explicitement demandé l’audit et l’amélioration de referentiel, systeme, geolocalisation, professionnel, analytics, communication et logistique : la migration 20261024_04 est appliquée. Voir le bilan SQL/documentation/Audit_Metier_20261024.md. Une autre évolution demande son propre périmètre ; cette autorisation ne couvre pas une suppression de données clients.

Le serveur local utilise CONN_MAX_AGE=0 et application_name=SauverNdeko-Django pour fermer les connexions en fin de requête et rendre leur suivi possible. Ne pas résoudre une fuite de connexions par une hausse arbitraire de max_connections.

Utiliser la connexion Django unique ; pas de Prisma ni de deuxième pool dans le code Python. Les valeurs SQL sont paramétrées ; schémas, objets, colonnes et tris proviennent du registre autorisé. Les modèles et registry.json décrivent un catalogue existant : une évolution de ce catalogue nécessite une nouvelle inspection en lecture seule et une adaptation vérifiée.

## Invariants des services

- Priorité aux vues PostgreSQL communes ; droits, filtres, comptages et agrégats côté serveur avant pagination.
- Contrôler utilisateur actif, rôle, organisation, objet et FK sur chaque chemin. Is_staff ne donne pas un périmètre global. Les objets sans règle locale démontrée sont refusés aux gestionnaires locaux.
- L’organisation actuelle provient du créateur, faute de FK immuable dans les tables. Ne présenter cette solution comme une isolation historique définitive. La propriété d’un objet ne doit pas être modifiée par un gestionnaire local.
- Les lignes commande verrouillent le parent puis les articles dans un ordre stable. Les triggers réalisent stock/mouvements/totaux ; ne pas appliquer un deuxième effet en Python. Quantités entières selon T_Mouvement.QteMvt.
- T_Mouvement, les journaux et archives sont en lecture seule. Préserver désactivation et suppression définitive distinctes.
- Les montants sont des Decimal et des chaînes JSON exactes ; les absences restent distinctes de zéro. Ne pas inventer de devise ou additionner des unités incompatibles. Les JSON/JSONB des curseurs bruts sont décodés par db.query avant nettoyage récursif ; les UUID sont pris en charge par ExactEncoder. Ne pas retourner une image JSON comme simple texte qui contournerait le masquage des secrets.
- Écriture métier et audit partagent la transaction. Masquer mots de passe et secrets dans réponses/journaux.
- Ne pas remplacer une erreur de permission ou de source par une collection vide ou un total nul.

## Vérification

Dans backend : python manage.py check puis python manage.py verifier_backend pour les contrôles en lecture seule. Le propriétaire a explicitement demandé de retirer le dossier de tests unitaires et les fichiers de dépendances séparés ; conserver un seul requirements.txt. python manage.py verifier_backend est un contrôle réel en lecture seule, avec identité synthétique réservée au diagnostic interne. Son succès ne valide ni les mots de passe clients ni une écriture/concurrence réelle.

Les recettes SQL/tests/test_metier_postgresql.py et test_api_postgresql.py sont vérifiées sur une copie de structure sans données clients et refusent une base hors sauverndeko_test_*. Les mutations de recette ne doivent jamais viser la base applicative.

## Séparation des schémas et comptes

public contient le socle natif Django ; systeme conserve entités, utilisateurs/profils métier, licences, réglages et journaux. Une fusion des schémas n’a pas été retenue : voir [l’examen DBA](../../SQL/documentation/Decision_Systeme_Public_20261024.md). auth_user n’a pas été alimentée par copie des comptes métier. Le rapprochement futur des identités demande un lien explicite et une migration vérifiée ; ne pas confondre déplacement de tables et fusion de comptes.
