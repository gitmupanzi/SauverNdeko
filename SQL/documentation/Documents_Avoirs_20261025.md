# Documents et avoirs logistiques — 25 octobre 2026

Migrations 20261025_11 et 20261025_12.

- PDF de bons d’entrée/sortie/livraison, factures, reçus et avoirs, avec entreprise émettrice autorisée.
- Justificatifs privés limités à 8 Mo : PDF, JPEG, PNG et WebP ; images normalisées, archivage conservant le contenu.
- Retour avant facturation : seules les quantités nettes sont facturées. Retour après émission : avoir au prix facturé, sans nouveau mouvement de stock.
- Imputation automatique au solde de la facture originale ; disponible restant imputable à une facture ouverte du même tiers, de la même entreprise et devise, ou remboursable.
- Remboursement : enregistrement d’un paiement réellement effectué, sans opération bancaire automatique.
- Identifiants idempotents, révisions, verrous et contraintes empêchent les doubles écritures et le dépassement du disponible.
- V_Facture est la source du solde net. Les vues aval, le tableau de bord, les API et le PDF conservent le même résultat.

## Validation

102 contrôles sur données fictives dans une base privée, dont droits interentreprises, identité figée, rejeu, refus de dépassement, remboursements concurrents, archivage et téléchargements binaires. Sept cas PDF rendus et inspectés, dont un tableau de cinq pages. Compilation frontend et contrôles isolés des formulaires réussis. La migration réelle exige une sauvegarde vérifiée et une transaction, sans variation du journal de stock. Les données fictives ne sont pas installées dans SauverNdeko.

## Limites conservées

Aucun taux de taxe, taux de change ni identité légale n’est inventé. Les justificatifs ne sont pas un service de signature. La valorisation CUMP historique et les alertes exhaustives par lot restent des travaux distincts ; le prix catalogue ne constitue pas un coût moyen comptable.
