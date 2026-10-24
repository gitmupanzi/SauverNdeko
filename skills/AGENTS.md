# SauverNdeko — consignes de travail

## Orientation et périmètre

SauverNdeko évolue vers un ERP modulaire commercialisable, multi-organisation et multi-pays, en conservant son catalogue santé/services, ses discussions et son administration. La logistique est un domaine de cet ERP. Cette cible ne signifie pas que tous les modules ERP sont déjà livrés.

## Skills du dépôt

- Lire [le skill transverse](sauverndeko-erp/SKILL.md) pour une évolution produit, une cartographie, une livraison ou un changement entre plusieurs couches.
- Lire [le skill backend](../backend/skill/SKILL.md) pour Django, Django REST Framework, PostgreSQL, les permissions et les calculs métier.
- Lire [le skill frontend](../frontend/skill/SKILL.md) pour React, les tableaux, les indicateurs et les consultations 360.
- Lire [le skill de mise en forme](document-mise-en-forme/SKILL.md) pour les fichiers Excel, Word et PDF, les exports et leurs gabarits.
- Consulter les références utiles à la tâche seulement. Ces emplacements sont ceux demandés par le propriétaire ; leur présence ne constitue pas une installation globale dans Codex.

## Conventions structurantes

1. Réutiliser les vues PostgreSQL communes avant de créer une lecture parallèle. Les écritures passent par les tables et les services métier, avec les triggers et procédures existants vérifiés.
2. Chaque table, vue et colonne métier créée ou modifiée doit recevoir un commentaire PostgreSQL utile et versionné. Les commentaires de code ne remplacent pas COMMENT ON.
3. Les calculs métier, agrégats exhaustifs et permissions appartiennent au serveur. Un indicateur, sa liste de détail et son export partagent le même périmètre autorisé.
4. Les identifiants métier et indicateurs ayant un détail ouvrent une consultation commune, accessible au clavier, avec retour au contexte. Produit 360 et Commande 360 sont des cibles à construire, pas des composants déjà disponibles.
5. Le backend unique est Django + Django REST Framework ; l’ancien backend Express/Prisma et ses dépendances ont été supprimés à la demande du propriétaire. Conserver React JSX/Vite/Bootstrap. Les modèles métier restent unmanaged et les schémas métier sont conservés. La migration SQL 20261024_04 fiabilise les schémas demandés et ajoute le socle analytics ; voir [le bilan SQL](../SQL/documentation/Audit_Metier_20261024.md). Sur autorisation ultérieure du propriétaire, les migrations natives Django (auth/admin/contenttypes/sessions) sont installées dans public ; la connexion applicative reste en lecture seule par défaut. Les règles financières et TypeScript d’imf_BB ne sont pas des exigences de SauverNdeko.

L’état de référence et les écarts documentés figurent dans [la cartographie](sauverndeko-erp/references/cartographie.md). Relire le code avant toute modification : ce relevé date du 24 octobre 2026 et n’atteste pas l’état d’une base déployée.

Les documents et exports Office/PDF suivent la charte SauverNdeko du skill documentaire, avec identité de l’organisation autorisée et valeurs issues des mêmes vues/services que l’écran. La conformité d’un exporteur se vérifie sur ses fichiers réels ; le skill seul ne la prouve pas.
