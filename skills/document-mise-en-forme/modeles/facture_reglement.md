# Gabarit — facture ou relevé de règlements

Choisir le type exact avant génération : facture attachée à une commande ou relevé des écritures de règlement. Ne pas utiliser les deux titres comme s’ils désignaient le même objet.

## Identité et références

[Organisation émettrice et tiers autorisés] · Facture : [CodeFacture existant] · Commande : [CodeCmd] · Date de facture : [DateFacture] · Échéance : [DateEcheancePaiement si renseignée].

## Facture

[Tableau des lignes autorisées : référence, désignation, quantité/unité, prix et montant fournis.] Montants HT/TTC repris de la source ; ne pas inventer de taxe, taux, remise, mention ou numéro légal. La devise provient des données disponibles et reste signalée si absente.

## Règlements — si le document les inclut

| Référence d’écriture | Date | Mode | Montant de l’écriture | Devise |
|---|---|---|---:|---|
| [ID_Reglement] | [DateReglement] | [Source] | [MontantRegle] | [Source] |

Le total des écritures et le reste recalculé sont distincts des montants réglé/restant enregistrés sur l’en-tête. Employer leurs libellés exacts et conserver les éventuels écarts ; ne pas les ajuster pour faire concorder le document.

Validation/signature : [source réelle, ou champ de brouillon vide si nécessaire]. Les informations d’identité ou de document manquantes ne sont pas remplacées par des données d’exemple.
