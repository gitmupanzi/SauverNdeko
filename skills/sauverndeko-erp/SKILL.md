---
name: sauverndeko-erp
description: Cartographier et faire évoluer SauverNdeko vers un ERP modulaire, en coordonnant domaines métier, vues PostgreSQL, API et parcours React. Utiliser pour les évolutions transversales, la reprise de principes d’imf_BB et la préparation d’une livraison client.
---

# Faire évoluer SauverNdeko

## Références à choisir selon la tâche

- Pour repérer un domaine et son état réel : [cartographie](references/cartographie.md), puis [inventaire technique](references/inventaire-technique.md).
- Pour prioriser une version client ou un module ERP : [trajectoire ERP](references/trajectoire-erp.md).
- Pour les droits par entreprise, le compte global, les clients/fournisseurs et le suivi facultatif par lot : [décisions Entités, tiers et stock](references/entites-tiers-et-stock.md). Cette cible reste distincte du comportement installé.
- Pour reprendre un comportement d’imf_BB : [matrice de transposition](references/transposition-imf-bb.md).
- Pour PostgreSQL/API : [skill backend](../../backend/skills/develop-sauverndeko-backend/SKILL.md).
- Pour l’interface : [skill frontend](../../frontend/skills/develop-sauverndeko-frontend/SKILL.md).

- Pour les fichiers Excel, Word et PDF : [mise en forme SauverNdeko](../document-mise-en-forme/SKILL.md), charte, modèles et contrôle des exports.

## Intentions du propriétaire

L’application doit devenir un ERP dont la logistique fait partie. Préserver les fonctions santé/services et la réutilisation entre organisations et pays. Les priorités exprimées le 24/10/2026 sont les vues SQL, les commentaires des tables et vues, des interfaces modernes, les indicateurs cliquables et les consultations 360 pour les objets métier.

La première intervention porte sur la cartographie et les skills. Elle ne valide pas une mise en production ni la conformité commerciale de l’application. Une demande ultérieure d’implémentation doit produire une tranche utilisable du parcours concerné.

## Manière de conduire une évolution

1. Identifier l’objet métier, ses sources, ses droits, ses effets de bord et ses consommateurs. Distinguer explicitement code présent, comportement vérifié et cible proposée.
2. Suivre le chemin écran → service HTTP → route montée → service métier → vue de lecture → tables/routines. S’appuyer sur config/urls.py, les vues Django et les services réellement appelés.
3. Réutiliser le contrat commun avant de dupliquer une jointure, un calcul, une modale ou une table. Vérifier le grain, les dates, les unités et le périmètre de la source.
4. Préparer ensemble la lecture, son détail consultable et l’export lorsque le besoin les inclut. Une somme sur une page ne représente pas le total du registre.
5. Pour une modification SQL, versionner la définition, les commentaires et les dépendances. Vérifier les triggers installés avant de programmer un deuxième effet sur le stock.
6. Faire respecter les droits par le serveur sur chaque route et chaque objet lié. Une portée de réglage global/country/entity n’assure pas l’isolation des données métier.
7. Mettre à jour les références du domaine et indiquer ce qui a été effectivement exécuté. Ne pas déclarer un module livré sur la seule présence de son modèle Django ou d’un écran.

## Invariants SauverNdeko

- PostgreSQL reste organisé par schémas métier ; les noms qualifiés existants et leur casse sont des contrats.
- QteArticle est le stock courant officiel ; T_Mouvement conserve l’historique ; T_CommandeDetail porte l’événement qui affecte le stock.
- Les mouvements restent en lecture seule ; les commandes clôturées sont protégées selon le scénario et les règles serveur existants.
- T_CommandeDetail possède une clé composée article/commande. Un article n’apparaît qu’une fois dans une commande avec le modèle actuel.
- Les règlements se rattachent à la facture par CodeFactureFk ; ne pas reconstruire une relation depuis un nom libre.
- Les données absentes restent distinctes de zéro. Ne pas additionner des devises ou unités différentes ; la devise du catalogue et celle du document sont explicites, les flux conservent leur instantané et les totaux sont ventilés par devise. Aucun taux ni conversion implicite n’est fourni.
- Reprendre les principes d’imf_BB, sans transférer ses clients, secrets, données financières, règles M-PESA/CBS ni obligations financières propres à ce projet. Le backend Django de SauverNdeko conserve les schémas métier ; les migrations natives Django sont autorisées dans public.

## Préparation d’une version client

Utiliser les jalons de la trajectoire ERP comme critères de travail, puis rapporter les résultats observés et les écarts restants. La livraison doit préciser les modules activés, les rôles, les données de démonstration fictives, l’installation, la sauvegarde/restauration et les limites connues. L’existence d’un client intéressé ne permet pas de présenter une fonction cible comme disponible.

## Architecture actualisée

Le backend unique est Django/DRF ; l’ancien backend Express/Prisma et ses dépendances ont été supprimés à la demande du propriétaire. Lire [le bilan technique actuel](../../SQL/documentation/Audit_Metier_20261024.md). Les inventaires initiaux décrivent l’état antérieur. Respecter le périmètre actualisé : schémas métier conservés, migrations natives Django autorisées dans public uniquement.

## Devises logistiques

La migration 20261025_04 est appliquée à SauverNdeko après sauvegarde. Le propriétaire a confirmé le rattachement des montants existants à USD. Pour les nouvelles créations, résoudre USD dans la catégorie Devise active du référentiel ; ne pas figer son identifiant ni inventer une devise dans le formatage frontend. Les champs `ID_DeviseFk`, `DeviseCode` et `DeviseLibelle` accompagnent les prix et montants ; les affichages peuvent suffixer le montant sans imposer une colonne redondante. Les exports numériques conservent une colonne de devise. Les agrégats, leurs détails et exports partagent le même filtre. Les montants de devises différentes ne sont jamais additionnés ; un prix catalogue d’une autre devise ne peut pas être recopié automatiquement dans un bon.

## Coûts, lots et livraison logistique

La valorisation CUMP est calculée par les fonctions et vues PostgreSQL de 20261026_04, par article, propriétaire et devise. Ne pas la remplacer par prix catalogue × quantité. Un coût inconnu reste distinct de zéro ; une ouverture doit être confirmée avec motif et révision atomique. Les retours utilisent les coûts historiques prouvés. Les tables d’arrêtés et de journal portent des événements métier, elles ne sont pas des catégories à déplacer dans T_Generique. Lire [la règle CUMP](../../SQL/documentation/Valorisation_CUMP_20261026.md).

Lots de stock est un registre transversal après Articles ; V_RegistreLots et V_RegistreMouvementLot servent les tableaux, la fiche Lot 360 et les exports. Chaque fiche limite son journal au lot sélectionné et à son entreprise. Les lots épuisés/archivés restent consultables, tandis que les alertes courantes ne comptent que les stocks restants. Les seuils et dérogations suivent la [règle de péremption](../../SQL/documentation/Peremption_Lots_20261026.md).

Les bons correcteurs et compensateurs d’inventaire sont identifiés par FK, jamais par leur référence libre ; ils ne peuvent être facturés ou restitués commercialement. Une livraison nécessite les preuves de sauvegarde/restauration, installation et recette du [guide de livraison](../../docs/livraison-logistique.md), ainsi que les validations externes encore ouvertes dans [les travaux restants](../../docs/reste-a-faire-logistique.md).
