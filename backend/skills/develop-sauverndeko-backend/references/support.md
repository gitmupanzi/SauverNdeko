# Contrat Support

La table principale est `support.T_Support` ; Tickets est le nom de l’onglet de traitement. Lire [le socle PostgreSQL](../../../../SQL/documentation/Support_20261030.md) avant une évolution de ses invariants. Le service dédié est `backend/apps/support/portal.py` et ses routes commencent par `/api/support/`.

## Propriété et accès

`IdEntiteFk` est le propriétaire durable du dossier. Les demandes, commentaires, solutions, justificatifs, compteurs, listes et exports partagent le même périmètre serveur. Un compte local ne lit que son entreprise ; un compte global peut consulter toutes les entreprises mais doit choisir une entreprise pour écrire. Support exige son accès de module ; les droits de gestion existants et le statut administrateur de l’acteur conditionnent les mutations. Ne pas ouvrir les écritures par le registre générique.

Le demandeur référence exactement `logistique.T_Client.ID_Client`, sans obligation de connexion. Créateur, responsable et vérificateur référencent `systeme.T_Utilisateurs`. Réutiliser les services du référentiel ; aucune équipe fictive ou table RH parallèle. Les liens Article, Bon de stock et Immobilisation possèdent leurs vraies FK et des gardes d’entreprise dans les deux sens.

## Configuration et circuit

Les familles passent par le référencement physique `schéma + table + colonne` et les valeurs sont des `ID_Generique`. Aucun numéro de catégorie ne doit être codé en Python ou JavaScript. Les codes techniques stables `support.status.*` et `support.verify.*` restent distincts des libellés humains affichés dans ce module.

Le circuit réside dans `systeme.T_Admin_UI_Setting`, clé `support.workflow`, avec les mécanismes existants de portée et de révision. Sa définition est validée en SQL. `CircuitSnapshot` capture le circuit à la création et reste immuable : ce n’est pas un deuxième réglage. Un changement ultérieur n’altère pas les dossiers existants. Les capacités et transitions de la fiche viennent de cet instantané.

Les règles minimales sont imposées en SQL : responsable avant prise en charge, motif de mise en attente/réouverture, cause et solution pour résoudre, vérification de la dernière tentative par une personne distincte du proposant, vérification conforme avant clôture. Une solution refusée nécessite reprise et nouvelle tentative. L’archivage motivé concerne les dossiers clôturés ; restaurer ne rouvre pas.

## Écritures et confidentialité

Une mutation verrouille le dossier, compare `_version` et vérifie le contenu canonique lié à `requestId`. Le même UUID ne peut être réutilisé avec un autre corps. La transaction englobe données, révision et audit dans `systeme.T_Audit_Log`. Conserver les anciennes tentatives et les commentaires ; ne pas les éditer ou supprimer pour corriger l’historique.

Les notes et pièces internes sont réservées aux gestionnaires. Public signifie visible des lecteurs autorisés du dossier, jamais Internet. Ne pas exposer leurs compteurs internes, métadonnées brutes, BLOB ou instantané dans les registres/exports. Le journal d’audit générique reste réservé à la plateforme ; la fiche Support filtre et présente son historique autorisé.

Réutiliser `logistique.T_PieceJustificative` et sa validation de fichier, puis `support.T_PieceSupport` pour les FK. Le dossier, l’auteur, la visibilité et l’éventuel commentaire doivent être compatibles dans une seule transaction. Télécharger après contrôle d’entreprise, de visibilité, de taille et de SHA-256 ; aucune URL publique de fichier. Le changement de contexte ne doit jamais réutiliser les données d’une entreprise précédente.

## Installation et preuves

Les modèles de processus sont propres à une entreprise. Une version publiée est immuable et référencée par les dossiers déjà engagés. Les étapes, réceptions, retours, blocages et validations métier sont distincts du circuit général et de sa vérification de clôture. Muter sous verrou du dossier avec révision et UUID de requête, conserver l’historique append-only et contrôler le périmètre des responsables, justificatifs, services et motifs. Une validation Support laisse les écritures de paiement et décisions métier dans leurs modules. Les relances utilisent la commande `traiter_alertes_support` et la clé dossier, passage, type et occurrence.

Le registre des modèles utilise les droits Support / Suivi des étapes et les préférences `support.modeles`. Les exports appliquent les mêmes critères que la liste et respectent le droit d’export. La lecture d’un fichier Excel prépare le panier sans modifier la base. La création multiple réutilise la validation individuelle dans une transaction unique. Une désactivation conserve les versions et ne concerne que les nouveaux parcours.

La migration `20261030_06_support.sql` est une installation unique. Le paquet vierge format 3 charge structure, références communes, correspondances fermées puis `backend/database/seeds/support_defaults.sql`. Le script initialise le circuit standard à partir des codes techniques historiques ou des libellés français standards non ambigus dans les familles communes. Les comptes, les dossiers et les configurations privées restent propres à leur installation. Une activation commerciale relève de la licence de l’entreprise.

Les recettes `SQL/tests/test_support_postgresql.py` et `SQL/tests/test_support_api.py` exigent des bases privées au préfixe `sauverndeko_test_`. Le diagnostic `verifier_backend` utilise des GET en lecture seule et ne prouve pas une connexion interactive, un téléchargement utilisateur ou la qualité visuelle du navigateur. Rapporter ces niveaux séparément.
