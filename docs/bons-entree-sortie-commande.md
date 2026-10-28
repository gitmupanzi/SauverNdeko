# Bons d’entrée, de sortie et de commande

Le type est une valeur du référentiel partagé, dans la catégorie **Type de commande**, utilisée par le champ **Type de bon**. Les identifiants de valeurs ne sont pas recopiés dans les formulaires.

| Document | Code des nouvelles créations | Effet sur le stock |
|---|---|---|
| Bon d’entrée | `BE-<identifiant>` | Entrée effective, mouvement positif |
| Bon de sortie | `BS-<identifiant>` | Sortie effective, mouvement négatif |
| Bon de commande | `CMD-<identifiant>` | Aucun mouvement ; quantités et prix commandés |

Le numéro est attribué par PostgreSQL et demeure non modifiable dans l’application. À la demande explicite du propriétaire, la migration06 harmonise aussi les anciens bons selon ces préfixes ; chaque ancienne référence reste conservée dans un journal immuable. Voir [la reprise de nomenclature](../SQL/documentation/Nomenclature_Bons_Historiques_20261028.md).

## Bon de commande

La valeur **Bon de commande**, de code `CMD`, décrit une commande préparée avec des articles actifs, une quantité respectant la précision de l’unité et un prix convenu dans la devise du document. Le stock disponible ne limite pas la quantité commandée. Cette première distinction n’impose pas de sens achat ou vente ; le prix est saisi et aucun prix d’achat ou de vente n’est recopié par supposition.

L’enregistrement, la modification ou la suppression d’une ligne de commande n’écrit aucun mouvement, ne réserve aucun stock, n’affecte aucun lot et ne produit aucun coût CUMP. Le montant constitue la valeur commandée, sans dette ou facture émise. Une commande n’est pas signalée comme une facture impayée ou un bon à facturer.

Le formulaire commun d’ajout/modification et la consultation présentent les mêmes informations enregistrées. Les actions réservées à une opération physique (lots, restitution, bon d’entrée/sortie/livraison) et l’émission d’une facture sont exclues pour ce type. Le bon de commande dispose de son propre PDF, en conservant les justificatifs et les exports autorisés.

Une réception ou une sortie réelle s’enregistre dans son propre BE ou BS. La commande conserve son type et son numéro. Les rapprochements automatiques commande/réceptions/livraisons partielles, reliquats et réservations relèvent d’une évolution distincte ; ils ne sont pas simulés par un changement de type.

## Socle et vérification

La migration `20261028_05_bons_commande.sql` porte la valeur référentielle, la classification, la numérotation et les protections SQL. Les tables de documents existantes sont réutilisées ; aucune table de type parallèle n’est créée.

La recette d’écriture utilise uniquement des bases privées `sauverndeko_test_*`. Avant installation réelle : vérifier sauvegarde, conservation des données historiques, absence d’effet de stock du CMD et maintien des mouvements uniques BE/BS. Les règles sont contrôlées au niveau SQL, puis dans les services et l’interface.

## Installation vérifiée le 28 octobre 2026

La migration05 est installée dans **SauverNdeko** après sauvegarde de la base et des médias vérifiée par empreintes. Une seule valeur référentielle est ajoutée : **Bon de commande / CMD**, active dans **Type de commande**. Les anciennes références sont identiques et les 65 autres tables conservent leurs données, notamment les articles, quantités, lots, mouvements, coûts et documents historiques. Aucun enregistrement de recette n’a été ajouté dans la base applicative.

- **51 contrôles PostgreSQL privés** : CRUD CMD, absence d’effet sur stock/lots/CUMP, totaux exacts, quantités selon l’unité, autres entreprises refusées, interdiction des mouvements/factures/retours directs et numérotation concurrente.
- **10 scénarios API réels privés** : formulaire commun, idempotence, prix convenu, droits, exports, PDF et maintien des réceptions BE/sorties BS.
- **188 contrôles de régression physiques** : chaîne logistique 112, annulation d’inventaire 31 et CUMP 45 ; **35 contrôles stock initial** complémentaires sur le socle05. La préparation d’un ancien test d’inventaire utilise désormais un vrai BE au lieu de modifier directement le stock.
- **94 contrôles frontend simulés** sur les fonctions, soumissions et rendus ; compilation Vite réussie. Le PDF fictif a été rendu et inspecté. Ces contrôles ne constituent pas un parcours visuel dans le navigateur de l’application.
- Après redémarrage du backend : **219 contrôles GET réussis** sur SauverNdeko avec une connexion PostgreSQL réellement en lecture seule. Le référentiel contient bien les trois types actifs ; les nouvelles numérotations BE, BS et CMD et les métadonnées des trois vues sont vérifiées.
- Les sources canoniques SQL sont synchronisées. Deux restaurations privées de structure, sans données, conservent exactement les définitions et commentaires : 66/56 tables, 80 vues et 125 triggers. Le fichier historique de migration01 garde son contrat d’origine ; seule la migration05 ajoute CMD.
- Le paquet d’installation neuf est restauré avec ses 56 tables : les trois types actifs sont présents, dont un seul CMD, tandis que préférences personnelles, comptes, entreprises, articles, bons et mouvements restent vides. Seules les cinq tables communes autorisées sont alimentées.
