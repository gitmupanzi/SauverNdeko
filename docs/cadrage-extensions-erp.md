# Cadrage des extensions ERP

Décisions de cadrage du 26 octobre 2026. Ces extensions prolongent la Logistique ; leurs contrats doivent être définis avant d’ajouter des écrans. Le socle reste PostgreSQL, avec contraintes, vues, fonctions, triggers, commentaires et migrations versionnées. Les références de type, statut, unité ou catégorie restent dans `referentiel.T_Generique`. Un événement métier autonome peut justifier une table dédiée ; un libellé de choix n’en justifie pas une.

## Dépôts, emplacements et transferts

**Parcours** : entreprise active → dépôt source → dépôt destinataire → articles/lots → quantités → expédition → réception et écarts justifiés. Un transfert appartient à une seule entreprise ; un échange entre deux entreprises utilise des documents de vente et d’achat distincts.

**Socle proposé** : une identité de dépôt propriétaire de l’Entité, des emplacements facultatifs et un registre de transfert versionné. Les types de dépôts et statuts viennent du référentiel. Chaque affectation article/lot garde la quantité physique et l’historique. Les vues présentent stock disponible par dépôt, stock en transit, lots et rapprochement avec le stock global. `QteArticle` reste un total contrôlé ; une ventilation par dépôt ne doit pas multiplier le stock existant.

**Règles** : aucune sortie supérieure au disponible du dépôt/lot ; verrouillage stable des articles et emplacements ; une expédition et une réception portent chacune leur identifiant idempotent. Un transfert interne conserve la valeur globale de l’entreprise et la devise ; le stock en transit explique l’écart entre départ et arrivée. Une annulation produit une compensation documentée. Les transferts partiellement reçus gardent leur reliquat.

**Interface** : registre compact, filtres de dépôts recherchables, même fenêtre ajout/modification, sous-onglets Bon / Articles / Suivi / Traçabilité, fiche Transfert 360 et liens Produit 360. Le catalogue est au-dessus des lignes sélectionnées ; quantités et prix restent sur une ligne par article.

**Critères de clôture** : migration initiale des stocks non ventilés approuvée, égalité du total par dépôts avec le stock global, réception partielle, perte en transit justifiée, lots périmés, deux opérateurs concurrents, double envoi, isolation entre Entités et documents PDF cohérents. Aucun dépôt par défaut ne doit être inventé pour une entreprise cliente.

## Cycle achats et ventes

**Achats** : demande d’achat → validation → commande fournisseur → réception partielle → facture fournisseur → règlement. **Ventes** : devis → acceptation → commande client → préparation → livraison partielle → facture → encaissement → retour/avoir. Chaque étape doit être distinguée des mouvements physiques : un devis ou une commande en attente ne modifie pas le stock.

**Socle proposé** : documents commerciaux liés aux tiers et à leur Entité, lignes immuables une fois émises, engagements et rapprochements entre quantités commandées/reçues/facturées. Réutiliser les bons de stock pour les entrées/sorties physiques et leurs triggers. Les types du référentiel portent une sémantique explicite et vérifiée ; ajouter un libellé ne doit pas produire silencieusement une entrée ou une sortie. Les devis, annulations et états intermédiaires ont un effet physique nul.

**Règles** : aucune facture ne doit dépasser les quantités ou montants autorisés sans dérogation formelle ; un reliquat est traçable, les tarifs sont exprimés dans la devise du document, et aucune conversion de change n’est implicite. Les retours avant facturation diminuent les quantités facturables ; après émission ils passent par un avoir. Les autorisations de valider, réceptionner, facturer et régler restent distinctes.

**Interface** : registres séparés lorsque le métier diffère, même style partagé, actions contextuelles accessibles dans ⋯, compteurs vers leurs listes exactes et fiches 360 liées par identifiants. Une création rapide de tiers conserve le panier ; les brouillons restent dans l’Entité qui les a ouverts.

**Critères de clôture** : circuits de validation définis par le client, réceptions et livraisons partielles, dépassements refusés, annulations et retours, montants par devise, numérotation documentaire, factures multiples d’une même commande, règlement partiel et doubles requêtes. Le module actuel ne doit pas être présenté comme un cycle achats/ventes complet avant cette recette.

## Comptabilité générale et rapprochements

Le suivi des factures, avoirs, règlements et coûts de stock fournit les sources d’une comptabilité, mais ne définit ni le plan comptable ni le traitement fiscal de chaque client.

**Socle proposé** : plan de comptes et périodes par Entité, journaux, pièces et lignes d’écritures équilibrées. Une vue d’interface reçoit les événements immuables de la Logistique : émission de facture/avoir, encaissement/remboursement et valorisation du stock. Chaque pièce conserve l’identifiant d’origine, sa devise, sa date comptable et l’auteur de validation. Les règles de correspondance sont configurées ; aucun compte ou taux légal n’est inventé.

**Règles** : équilibre débit/crédit à la précision comptable choisie, unicité de comptabilisation d’un événement, périodes closes protégées, correction par extourne et nouvelle pièce. Un mouvement de stock compensateur reste distinct d’une extourne financière ; ils sont rapprochés par des liens vérifiés. Les paiements enregistrés ne déclenchent aucun transfert bancaire. Les écritures rétroactives respectent la clôture et la politique de recalcul retenue.

**Interface** : journal filtrable et exportable, pièce 360, liens facture/bon/règlement, rapprochements et anomalies cliquables. Afficher les informations utiles au comptable sans exposer les noms des tables dans le parcours quotidien.

**Critères de clôture** : validation par le responsable comptable du plan, de la méthode de coût et des règles fiscales applicables ; balance équilibrée, livre et grand livre cohérents, périodes closes, annulation traçable, rapprochement des soldes clients/fournisseurs et valorisation du stock, exports contrôlés et séparation stricte des Entités.

## Autres modules de la plateforme

Administration, Référentiels, Organisation territoriale, catalogue santé et discussions doivent reprendre les composants communs : filtres catégoriels recherchables, tableaux professionnels, menus de ligne, fenêtres latérales et sous-onglets. Leur modernisation se fait module par module, en conservant les permissions et contrats SQL existants. Les opérations globales du référentiel sont réservées à la plateforme ; une licence d’entreprise n’accorde pas l’administration de toutes les Entités.

Avant une refonte de chacun : relever les vues et relations, établir le parcours et les droits, reprendre un formulaire commun ajout/modification, définir indicateurs/détails/exports sur un même périmètre, puis vérifier ordinateur/mobile, thèmes, clavier, états d’erreur et conservation du contexte. Le style de référence reste [TailAdmin](https://tailadmin.com/) et l’organisation par applications s’appuie sur [Odoo](https://www.odoo.com/fr_FR).
