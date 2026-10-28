# Terminologie du stock

Le module rapproche les usages logistiques et comptables en distinguant le justificatif, ses lignes, le mouvement physique et le règlement. Les types configurés distinguent Entrée (BE), Sortie (BS) et Bon de commande (CMD). Seules l’entrée et la sortie effectives modifient le stock.

| Menu ou terme | Sens dans SauverNdeko | Source interne |
|---|---|---|
| Articles | Catalogue des biens suivis et de leurs unités | T_Article / V_Article |
| Bons de stock | Entrées, sorties et bons de commande ; le type précise l’effet physique ou l’engagement | T_Commande / V_Commande |
| Lignes des bons | Articles, quantités et prix d’un bon | T_CommandeDetail / V_CommandeDetail |
| Mouvements de stock | Historique des variations physiques et lien vers le bon | T_Mouvement / V_Mouvement |
| Factures et règlements | Facturation des bons et paiements rattachés | V_SuiviReglements / T_Reglements |
| Tiers | Partie liée au document, selon le référentiel disponible | ID_ClientFk / NomClientSaisi |
| Produit 360 / Bon de stock 360 | Consultation d’un seul article ou bon et de ses liens | ConsultationProvider |

Conserver les noms techniques des tables, colonnes, clés et routes. Ne pas renommer une clé commande en bon dans un contrat API uniquement pour modifier son libellé à l’écran. Le Bon de commande est un engagement sans mouvement de stock, distinct de la réception ou de la sortie effective. Son code CMD ne présume ni achat ni vente : conserver Tiers et Prix convenu tant qu’un sens commercial n’est pas configuré. Ne pas appeler le catalogue « inventaire physique », ni le journal des mouvements « journal comptable ».

Le [guide du Logistics Cluster](https://log.logcluster.org/fr/enregistrement-systematique-et-documentation-dappui) distingue les documents de réception/sortie et l’enregistrement des mouvements. Cette distinction motive les libellés choisis ; elle ne prescrit pas un menu logiciel particulier. [Odoo distingue aussi commande, réception et livraison](https://www.odoo.com/documentation/18.0/fr/applications/inventory_and_mrp/inventory/shipping_receiving.html).

La valeur quantité × prix d’achat de la vue existante ne suffit pas à annoncer un moteur de valorisation comptable. IAS 2 traite le coût des stocks et leur évaluation ; les méthodes et écritures comptables doivent être spécifiées avant d’être promises. [Référence IAS 2](https://www.ifrs.org/issued-standards/list-of-standards/ias-2-inventories/).


## Trois types de bon, trois effets distincts

Reconnaître le type depuis `kind`/`NatureBon` de l’API ou le code exact `CMD` du référentiel, jamais depuis un identifiant SQL figé. Un signe nul ou un libellé ressemblant à « commande » ne suffit pas à reconnaître CMD. Réutiliser `stockDocumentKind` dans tous les parcours. Entrée/BE correspond à une réception effective avec prix d’achat proposé ; Sortie/BS correspond à une sortie effective avec prix de vente proposé et contrôle du stock disponible.

Bon de commande/CMD accepte tous les articles actifs, même sans stock disponible, et les quantités selon la précision de leur unité. Son prix convenu est saisi explicitement ; ne préremplir ni prix d’achat ni prix de vente et ne convertir aucune devise. Il ne crée ni mouvement, ni réservation, ni affectation de lots. Les payloads de composition et de ligne transmettent `Lots: []`. Le type CMD reste immuable en modification ; les opérations physiques utilisent des bons BE/BS distincts.

Le 360 CMD conserve Synthèse, Lignes, Contrôle, justificatifs, Excel et Bon de commande · PDF (`/api/logistique/documents/bon/<id>/commande.pdf`). Retirer les rubriques et actions de lots, mouvements, restitution et facturation qui ne le concernent pas ; afficher sobrement Sans mouvement de stock. Une création de facture est réservée à une sortie éligible, avec vérification serveur, et les anciennes factures restent consultables.


## Renumérotation explicitement demandée

Les codes de bons sont normalement attribués et conservés par la base de données. Une renumérotation historique expressément demandée par le propriétaire constitue une opération de maintenance journalisée, jamais un champ modifiable du formulaire. Le code courant suit BE/BS/CMD selon le type ; les factures conservent leur propre numéro. Les vues exposent `AncienCodeCmd` et `RenumeroteLe`, en lecture seule, pour garder la correspondance.

Présenter un ancien code différent du code courant dans Informations du bon du 360 et dans Traçabilité du compositeur ; omettre les champs quand aucun ancien code n’existe. Dans Bons de stock, Ancien code est une colonne facultative, sans modification des colonnes par défaut. Sa consultation utilise le même ID_Commande courant. La recherche des anciens codes est effectuée par le serveur et reste limitée à l’entreprise autorisée. Ne jamais reconstruire une route à partir de l’ancien code, ni réécrire RefCmd, les références libres de retour ou les snapshots financiers pour suivre une nouvelle numérotation.
