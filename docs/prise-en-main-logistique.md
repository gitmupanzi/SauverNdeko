# Prise en main — Logistique

## Avant de commencer

Connectez-vous et ouvrez Logistique. Le compte de plateforme choisit une entreprise dans l’en-tête ; « Toutes les entreprises » permet la consultation globale. Les utilisateurs locaux travaillent dans leur propre entreprise selon leurs droits.

Dans **Identité de l’entreprise**, vérifiez nom, adresse, téléphone et e-mail. Les identifiants légaux et la mention sont facultatifs et doivent correspondre aux informations réelles. Une modification s’applique aux nouveaux documents ; les documents déjà émis conservent leur identité historique.

Dans **Articles → ⋯ → Valorisation CUMP**, confirmez les coûts d’ouverture uniquement sur justificatif. « À initialiser » indique un coût encore inconnu, pas une valeur nulle. Le prix catalogue reste distinct du coût moyen.

## Parcours quotidiens

| Besoin | Parcours | Résultat à contrôler |
|---|---|---|
| Préparer le catalogue | Articles → Nouvel article | Unité, précision, prix/devise et photo corrects. Un stock initial positif produit une seule entrée. |
| Préparer une commande | Bons de stock → Nouveau bon → Bon de commande → Articles | Articles, quantités et prix convenus ; code CMD automatique, sans mouvement ni réservation de stock. |
| Réceptionner | Article → ⋯ → Réceptionner du stock, ou Bons de stock → Nouveau bon → Entrée | Fournisseur, prix d’achat, quantités et lots correspondent à la livraison. |
| Sortir des articles | Bons de stock → Nouveau bon → Sortie → Articles | Le catalogue alimente le bon ; quantités, prix et lots sont vérifiés avant enregistrement. |
| Consulter un lot | Lots de stock → lot ou Consulter | Article, stock restant, péremption et mouvements sont ceux du lot choisi. |
| Restituer | Bon de stock 360 → Restituer des articles | La quantité retournée reste limitée à la quantité sortie non encore restituée. Une entrée traçable rétablit le stock. |
| Facturer | Bon de stock commercial → Créer la facture | Le document conserve son numéro et ses lignes. Les retours antérieurs sont pris en compte ; un retour après émission conduit à un avoir. |
| Régler | Factures ou Règlements → Ajouter un règlement | Montant, devise, facture et mode corrects ; le solde est recalculé au serveur. |
| Traiter un avoir | Facture/avoir → Imputer ou Enregistrer le remboursement | L’imputation diminue une dette éligible ; le remboursement enregistré correspond à une opération réellement effectuée. |
| Compter le stock | Inventaires → Nouvel inventaire → Comptage | Sélectionnez les articles, saisissez les quantités comptées, justifiez les écarts et ventilez les lots concernés. |
| Corriger un inventaire validé | Inventaire → ⋯ → Annuler la validation | Motif obligatoire et mouvements compensateurs ; le comptage et les écritures d’origine restent consultables. |

Les bons d’écart d’inventaire sont internes : ils se corrigent dans Inventaires et ne servent pas à facturer un client ou à effectuer une restitution commerciale.

**BE** constate une entrée effective et **BS** une sortie effective. **CMD** prépare une commande : les quantités peuvent dépasser le stock disponible, et aucun lot n’est affecté. La réception ou la sortie réelle s’enregistre ensuite dans un BE ou un BS séparé. Le CMD garde son numéro ; le rapprochement automatique des réceptions partielles reste une évolution distincte. Voir [les trois types de bons](bons-entree-sortie-commande.md).

## Documents et recherches

Les menus ⋯ proposent les documents disponibles pour l’enregistrement sélectionné. Les justificatifs restent privés. Un export Excel suit les filtres et porte sur tous les résultats autorisés, même si l’écran ne montre qu’une page. Les prix restent numériques avec leur devise ; les dates de mouvement conservent l’heure.

Les anciens bons ont été harmonisés en BE, BS ou CMD. Leur fiche conserve l’**Ancien code**, également recherchable dans les bons et leurs lignes. Les factures, reçus et avoirs déjà émis gardent leur référence d’origine lors d’une réimpression ; leur numéro et leurs montants restent conservés.

Un clic sur un indicateur du tableau de bord affiche sa liste en dessous. Le lien de retour ramène à l’indicateur. Les fenêtres Produit 360, Bon de stock 360, Lot 360 et Tiers 360 conservent le contexte de consultation.

## En cas de message d’erreur

- Une réponse réseau incertaine peut survenir après enregistrement : utilisez la vérification/reprise proposée, sans changer le contenu ni créer une seconde demande.
- Un conflit de modification demande de recharger la fiche et de vérifier les valeurs récentes.
- Un stock insuffisant ou une ventilation de lot incomplète exige de corriger la ligne avant confirmation.
- Un lot périmé suit la politique de l’entreprise ; une dérogation autorisée exige un motif.
- Pour la récupération d’accès, Administration → Messagerie → Tester la connexion contrôle le transport sans envoyer d’e-mail. La réception effective d’un message se vérifie séparément.

## Avant une remise au client

Faire accepter le parcours complet, les données de reprise, les droits et les documents avec l’identité réelle de l’entreprise. Le responsable client valide les coûts, le traitement fiscal applicable et les mentions ; aucun taux ou identifiant légal n’est déduit du seul nom de l’entreprise. Le [guide de livraison](livraison-logistique.md) couvre installation, sauvegardes, restauration et exploitation. Le [diagnostic de livraison](diagnostic-livraison.md) produit un état technique vérifiable en lecture seule.
