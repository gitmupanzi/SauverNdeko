# Trajectoire ERP et préparation client

Cible définie le 24/10/2026. Les lots ci-dessous sont proposés ; ils ne constituent pas des fonctionnalités déjà livrées ni un engagement sur un calendrier. Le secteur du client, ses volumes, rôles, implantations et modules contractuels restent à préciser avant le paramétrage final.

## Positionnement

SauverNdeko devient un ERP modulaire : un socle partagé pour les organisations, utilisateurs, tiers, référentiels, droits, documents et audit, puis des domaines activables. Le catalogue santé/services demeure un canal du produit. La logistique constitue le premier domaine métier avancé.

| Domaine ERP | Base trouvée | Cible à construire ou consolider |
|---|---|---|
| Socle organisationnel | Entités, utilisateurs, licences, géographie, paramètres | Isolation réelle, rôles par fonction, droits par module/action, organisations et sites |
| Tiers / relation client | Utilisateurs, entités, ID_ClientFk, nom libre | Référentiel explicite clients/fournisseurs, contacts, liens et fiche 360 |
| Produits et services | Articles, catégories, unités, prix, péremption | Produit 360, règles d’unité/devise, lots et emplacements si le besoin est confirmé |
| Achats / approvisionnement | Commandes d’entrée et lignes | Demande, validation, commande fournisseur, réception et suivi des écarts |
| Ventes / facturation | Commandes de sortie, facture attachée, règlements | Devis, commande client, livraison, facture, avoir et suivi du reste, selon règles validées |
| Stocks / logistique | Stock courant, mouvements et vues de contrôle | Réconciliation fiable, inventaires, transferts et multi-dépôts si nécessaire |
| Caisse / trésorerie | Modèles Caisse/Paiement et vues | Écrans métier, contrôle des encaissements/décaissements, rapprochements |
| Finance / comptabilité | Aucun grand livre complet identifié | Interface ou module dédié à cadrer ; un suivi de règlements n’est pas une comptabilité générale |
| Pilotage | Dashboard logistique et vues | Indicateurs exhaustifs, détails filtrés, historique et exports fiables |
| Administration / exploitation | Admin, audit et licences | Configuration livrable, sauvegarde/restauration éprouvée, journal et diagnostic |
| RH / immobilisations / projets | Pas de modules complets trouvés | Extensions possibles selon le contrat ; ne pas les annoncer disponibles |

## Lot A — sécuriser le socle métier existant

Traiter SEC-01 et SEC-02 de la cartographie : protection des routeurs modulaires, matrice de droits et périmètre d’organisation côté serveur, y compris objets liés et métadonnées. Conserver l’accès public limité aux champs publics explicitement prévus.

Critères : 401 pour accès sans session, refus pour droits insuffisants, impossibilité d’accéder aux objets d’une autre organisation, opérations permises réussies, secrets et mots de passe exclus des sorties. Exercices sur données fictives, sans exposition du serveur sur le réseau pour le test.

## Lot B — fiabiliser SQL et les calculs

Inventorier la base de recette, comparer ses objets aux scripts, choisir les définitions canoniques, versionner les évolutions et commentaires. Déporter les agrégats du dashboard vers les vues/services communs. Vérifier triggers, atomicité, verrouillage, quantités fractionnaires, stock initial et commandes clôturées.

Critères : aucune double mise à jour stock ; parité quantité/valeur entre scénario, vues, API et historique ; calculs justes au-delà de 200 lignes ; filtre période réellement appliqué ; absence distinguée de zéro. Comparer les plans et temps sur un volume représentatif avant de prétendre accélérer l’application.

## Lot C — consultations 360 et navigation métier

Construire le conteneur commun de consultation, Produit 360 et Commande 360. Ajouter Facture/Règlement puis Client/Fournisseur 360 après stabilisation du modèle de tiers. Raccorder les indicateurs au détail SQL exact, les codes aux fiches et les objets liés à la même navigation.

Critères : ouverture depuis tableau, KPI et recherche ; mêmes filtres et droits ; retour au focus et à la ligne ; largeur réglable jusqu’à environ 94 % de l’écran, mobile pleine largeur ; aucun chargement 360 par ligne ; états erreur/vide/chargement accessibles.

## Lot D — première chaîne ERP vendable

Choisir avec le client une chaîne complète, par exemple approvisionnement → entrée stock → vente → sortie stock → facture → règlement. Définir transitions, validations, pièces, références, rôles et corrections autorisées avant d’étendre les écrans. Les entrées/sorties actuelles ne suffisent pas à prouver un cycle achats/ventes complet.

Critères : parcours bout en bout reproductible, documents utilisables, historique conservé, annulations explicables et indicateurs concordants. Définir explicitement quelles fonctions sont incluses dans la version proposée au client.

## Lot E — industrialisation et extensions

Préparer configuration d’installation, journalisation utile, vérification des dépendances, sauvegarde/restauration testée dans une base isolée, documentation utilisateur et démonstration fictive. Puis ajouter les modules retenus : dépôts/lots, trésorerie, comptabilité, projets ou RH.

Critères : nouvelle installation reproductible, restauration prouvée, rôles de démonstration, recette responsive/clavier et dossier de livraison décrivant les limitations réelles. Le multilingue, les devises, taxes, numérotations et règles locales demandent un cadrage propre au client.

## Ordre conseillé

A précède la livraison d’un accès privé. B rend les mesures fiables et prépare C. C peut progresser sur données fictives pendant B, avec un contrat API explicite. D constitue la première tranche métier complète ; E accompagne sa livraison. Le nombre de modules visibles n’est pas un critère suffisant de maturité ERP.

## État livré le 25 octobre 2026 — accès aux applications

La licence appartient à l’Entité : T_Utilisateurs.IdEntiteFk et T_Licence.IdEntiteFk sont les relations existantes utilisées. Les activations sont dans T_LicenceModule, le catalogue dans T_ModuleApplication et les restrictions dans T_RoleModule. Aucun abonnement individuel ni nouveau contrat commercial n’est créé. La migration 20261025_02_modules_entites et les services dédiés assurent le contrôle serveur.

L’accueil est limité aux applications effectives. Le catalogue est séparé. L’administration de plateforme configure les modules et restrictions ; l’administrateur d’entreprise voit sa propre offre. Les droits antérieurs forment une limite supérieure : aucune règle de module ne donne le statut d’administrateur. Les référentiels partagés restent au socle.

Le socle actuel comprend Discussions, Organisation territoriale et Administration ; Catalogue inclut Produits, Structures, Professionnels et Informations santé. Logistique est activable séparément. Ces choix sont versionnés dans la migration, sans prix ni facturation automatique. Pour une nouvelle licence, activer explicitement les modules contractuels ; la reprise des accès n’est exécutée qu’à la migration initiale.

La recette comprend les refus serveur, les périodes simulées par le SQL réel des vues, les restrictions de rôle et l’interface. Les tests d’écriture des réglages sont simulés ; aucun cycle de modification réel de licence n’a été réalisé pendant la recette. La garantie d’isolation métier reste limitée par la propriété déduite du créateur actuel, décrite dans le guide backend.
