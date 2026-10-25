# Dossiers de suivi — état du 25 octobre 2026

## Périmètre

Le classement couvre articles, bons de stock et factures. Chaque dossier a un type unique ; les catégories de dossiers sont transversales. Les couleurs sont des repères visuels, sans effet sur les opérations métier. Les dossiers standards sont des sélections dynamiques : rupture, stock faible, péremption proche, articles périmés, bons en attente, en cours, non facturés, sans lignes, factures à régler, en retard et partiellement réglées.

## Installation appliquée

La migration ../migrations/20261025_01_dossiers_suivi.sql contient T_CategorieDossierSuivi, T_DossierSuivi, T_DossierSuiviMembre, trois vues, une fonction et trois triggers commentés. Les membres référencent réellement T_Article ou T_Commande. La facture utilise son bon de rattachement et sa référence actuelle : aucun journal comptable supplémentaire n’est créé. Les objets sont hors du registre CRUD générique et passent uniquement par les services spécialisés.

Le propriétaire a explicitement approuvé l’installation et l’activation des écritures pour l’ensemble de l’application le 25/10/2026. La migration est appliquée à SauverNdeko ; les six objets, tous leurs commentaires de colonnes, la fonction et les trois triggers actifs ont été contrôlés. Les trois tables de classement étaient vides après installation. Aucune ligne de stock, bon ou règlement n’a été modifiée par cette migration.

backend/.env définit localement SAUVERNDEKO_DB_READ_ONLY=0. Ce réglage agit sur toutes les opérations métier autorisées, pas uniquement sur les dossiers ; les rôles et contrôles d’organisation restent inchangés. Les nouvelles installations gardent le défaut 1. Les diagnostics doivent utiliser un processus isolé avec SAUVERNDEKO_DB_READ_ONLY=1, sans changer la configuration du service.

Sauvegarde native vérifiée avant installation : .runtime/backups/SauverNdeko_avant_dossiers_20261025_024255.dump (11 348 631 octets), SHA-256 48fe55507b18e36a0a40c510dbe1dc4df2e14bd53f8ffe4245e7142dd040ba9b. L’archive a été relue par pg_restore --list. Le relevé d’installation est conservé dans .runtime/backups/deploiement_dossiers_20261025.json ; ces fichiers privés restent exclus de Git.

## Garanties et limites

Les services imposent le propriétaire et l’organisation ; les clés de contexte, type et mode sont immuables. Les archives conservent les membres. Les noms actifs sont uniques dans le contexte. La version empêche l’écrasement d’une modification concurrente. Catégories et membres sont contrôlés par les triggers en plus de l’API ; les écritures métier et leur audit partagent la transaction. Aucune instruction de cette migration ne modifie stock, mouvement, bon ou règlement.

La lecture réutilise les vues et les prédicats de l’ERP. Les factures sans référence sont exclues, les dates de facture ne deviennent pas des dates de bon. Les critères additionnels d’une liste affinent le dossier ; ils ne retirent pas son critère initial. Les XLSX exportent toute la liste filtrée, les colonnes autorisées et les critères du dossier.

## Vérifications

- Django check : succès.
- Diagnostic réel : 142 routes GET réussies, connexion en lecture seule.
- Recette ciblée externe : 125 assertions, base SauverNdeko, aucune écriture exécutée.
- Parseur PostgreSQL : 92 instructions SQL ; corps PL/pgSQL analysé avec substitution du type composite en record pour le parseur autonome. Les objets et dépendances ont ensuite été créés avec succès sur PostgreSQL 18.6.
- Interface : recette fictive séparée, sans données clients ni requête vers la base. Après installation, la session administrateur réelle ouvre les formulaires Nouveau dossier et Nouvel article ; l’aperçu Bons non facturés retrouve quatre bons. Aucun cycle CRUD fictif n’a été exécuté dans la base applicative.

Le script ../migrations/rollback/20261025_01_dossiers_suivi.sql refuse le retrait si une table contient des données. Une restauration après utilisation relève d’une sauvegarde et d’une décision de déploiement.


Le classement manuel exige un responsable renseigné sur l’article ou le bon, conformément au trigger installé. L’API retourne OWNER_REQUIRED avant toute écriture si ce responsable manque ; le 360 l’annonce explicitement. Les dossiers automatiques restent des sélections du registre autorisé. Cette règle ne change ni les droits de consultation ni les rôles des comptes.
