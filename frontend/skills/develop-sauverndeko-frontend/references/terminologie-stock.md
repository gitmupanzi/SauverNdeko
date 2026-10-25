# Terminologie du stock

Le module rapproche les usages logistiques et comptables en distinguant le justificatif, ses lignes, le mouvement physique et le règlement. Les types réellement configurés sont Entrée et Sortie.

| Menu ou terme | Sens dans SauverNdeko | Source interne |
|---|---|---|
| Articles | Catalogue des biens suivis et de leurs unités | T_Article / V_Article |
| Bons de stock | Documents d’entrée ou de sortie ; le type précise le sens | T_Commande / V_Commande |
| Lignes des bons | Articles, quantités et prix d’un bon | T_CommandeDetail / V_CommandeDetail |
| Mouvements de stock | Historique des variations physiques et lien vers le bon | T_Mouvement / V_Mouvement |
| Factures et règlements | Facturation des bons et paiements rattachés | V_SuiviReglements / T_Reglements |
| Tiers | Partie liée au document, selon le référentiel disponible | ID_ClientFk / NomClientSaisi |
| Produit 360 / Bon de stock 360 | Consultation d’un seul article ou bon et de ses liens | ConsultationProvider |

Conserver les noms techniques des tables, colonnes, clés et routes. Ne pas renommer une clé commande en bon dans un contrat API uniquement pour modifier son libellé à l’écran. Réserver « commande fournisseur/client » à un futur engagement commercial distinct de la réception ou de la sortie effective. Ne pas appeler le catalogue « inventaire physique », ni le journal des mouvements « journal comptable ».

Le [guide du Logistics Cluster](https://log.logcluster.org/fr/enregistrement-systematique-et-documentation-dappui) distingue les documents de réception/sortie et l’enregistrement des mouvements. Cette distinction motive les libellés choisis ; elle ne prescrit pas un menu logiciel particulier. [Odoo distingue aussi commande, réception et livraison](https://www.odoo.com/documentation/18.0/fr/applications/inventory_and_mrp/inventory/shipping_receiving.html).

La valeur quantité × prix d’achat de la vue existante ne suffit pas à annoncer un moteur de valorisation comptable. IAS 2 traite le coût des stocks et leur évaluation ; les méthodes et écritures comptables doivent être spécifiées avant d’être promises. [Référence IAS 2](https://www.ifrs.org/issued-standards/list-of-standards/ias-2-inventories/).
