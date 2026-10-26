# Valorisation CUMP — 26 octobre 2026

La migration 20261026_04 fournit le coût moyen unitaire pondéré permanent dans PostgreSQL. React affiche les résultats ; Django contrôle les droits, la révision et les paramètres. Le calcul n’est pas recopié dans le frontend et ne remplace pas les prix commerciaux ou les instantanés de facture.

## Règles de coût

- Un article nouvellement créé utilise le prix d’achat de son stock initial. Chaque réception suivante utilise le prix d’achat réellement saisi sur son bon. Une sortie utilise le coût moyen avant sortie, quel que soit le prix de vente.
- Un retour physique ou une annulation d’inventaire utilise le coût prouvé du mouvement d’origine. Les coûts internes ne sont pas tronqués aux six décimales d’affichage avant leur conservation ; un retour important conserve donc sa valeur après une réévaluation intermédiaire.
- Un surplus d’inventaire utilise le coût moyen existant. Si le stock est nul et qu’aucun coût n’est prouvé, son prix indicatif ne devient pas un coût comptable : l’état reste **Coût à vérifier** jusqu’à confirmation.
- Le calcul reste séparé par article, propriétaire et devise. Une sortie qui dépasse le solde dans sa devise rend le coût indéterminable ; aucune conversion de change n’est inventée. Les quantités de devises distinctes ne produisent pas de moyenne monétaire commune.
- L’ordre de traitement est l’ordre stable d’enregistrement ID_Mvt. Une date métier antérieure ne réordonne pas silencieusement l’historique. Une correction d’un prix d’achat après le dernier arrêté recalcule les coûts ultérieurs ; les modifications de source sont journalisées. Les mouvements déjà inclus dans un arrêté confirmé se corrigent par des bons compensateurs.
- Les valeurs monétaires sont présentées à deux décimales ; les coûts unitaires à six. Les calculs et coûts d’origine conservent leur précision numérique interne. Un coût absent reste distinct d’un coût gratuit explicitement égal à zéro.

Le principe d’un retour de livraison au coût de sa sortie est cohérent avec la [documentation des opérations de valorisation Odoo](https://www.odoo.com/documentation/19.0/applications/inventory_and_mrp/inventory/inventory_valuation/operations_valuation.html). SauverNdeko conserve son modèle PostgreSQL et son journal physique propres.

## Ouverture et réévaluation

Certains anciens mouvements ont été enregistrés avec un ancien prix de vente. La migration laisse donc le coût d’ouverture des articles existants non confirmé, au lieu de convertir ces nombres en coût d’achat. Aucun stock n’est ajouté ou retiré.

Dans Articles → menu ⋯ → **Valorisation CUMP**, ou depuis Produit 360, le gestionnaire habilité sélectionne une entreprise active et confirme le coût du stock courant, avec son justificatif dans le motif. Le formulaire présente la quantité, la devise, la valeur et l’historique. Une réévaluation conserve l’arrêté précédent et les coûts d’origine déjà prouvés. Un retour portant sur une sortie historique dont le coût était inconnu reste à vérifier : le prix de vente n’est jamais utilisé comme remplacement.

La confirmation exige un motif, une révision opaque et un UUID de demande. La lecture du stock, des coûts et de leur révision utilise un seul instantané SQL ; un arrivage entre lecture et confirmation provoque un conflit. Les écritures se sérialisent sur l’article, avec une seule preuve pour deux demandes simultanées identiques. Le journal financier est conservé et ne crée aucun mouvement physique supplémentaire.

## Objets et API

- T_ValorisationOuverture : dernier arrêté confirmé, coût facultatif lors de la reprise, propriétaire, devise, révision et coûts antérieurs prouvés.
- T_ValorisationEvenement : preuves d’ouverture, de réévaluation et de changement de source, conservées en ajout seulement.
- fn_cout_mouvements : calcul exact des coûts ; ses sources de restitution et correction sont préparées une fois, sans recopier un grand objet JSON pour chaque mouvement.
- V_CoutMouvement et V_ValorisationStock : lectures communes. Les clés sont exposées directement depuis leurs sources afin de pousser le filtre article avant le calcul, y compris pour un administrateur global.
- enregistrer_cout_ouverture : contrôle SQL des droits, du propriétaire, de la devise, de la version, de la révision de source et de la demande avant écriture, y compris lors d’un appel SQL direct.
- GET/PUT /api/logistique/articles/{id}/valorisation et GET /valorisation/export.xlsx : même article autorisé, filtre de devise explicite, pagination de l’historique et export complet. Les coûts restent numériques avec six décimales dans Excel, et la devise est conservée.

## Recette

SQL/tests/test_valorisation_cump.py exige une URL explicite sauverndeko_test_* et refuse la base applicative. **45 contrôles** couvrent coût d’achat contre prix de vente, réceptions successives, sorties, retours partiels après réévaluation, précision sur 100 000 unités, corrections de prix, coûts inconnus, surplus à stock nul, quantités fractionnaires, séparation des devises, droits interentreprises, lecture seule, export, révisions périmées et demandes concurrentes. Les deux défauts trouvés en revue (surplus indicatif et révision associée à un autre instantané) ont leurs régressions dédiées.

Les mesures volumétriques et les limites des imports en une seule transaction figurent dans docs/performance-frontend-20261026.md. La validation des coûts d’ouverture et du choix comptable final appartient au responsable de l’entreprise. La valorisation de stock n’émet pas d’écritures de comptabilité générale.
