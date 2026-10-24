# Excel SauverNdeko

## Format et structure

Produire un véritable .xlsx. Un CSV reste un export de données sans charte ; un tableau HTML renommé .xls n’est pas le format natif attendu. Préserver les classeurs existants et leurs formules lorsque la demande porte seulement sur leur mise en forme.

Choisir des feuilles utiles au livrable : Synthèse, Articles, Commandes, Lignes, Mouvements, Règlements, Contrôles ou Paramètres selon le besoin. Ne pas créer de feuilles vides ou une longue notice de sources sur chaque export. Le contexte essentiel peut tenir dans un bloc compact avant le tableau ; une annexe technique n’est ajoutée que si elle est utile et autorisée.

Pour une feuille de données : une ligne par objet au grain annoncé, une colonne par information, en-têtes non vides et uniques, aucune fusion au milieu des données. Utiliser un tableau structuré et ses filtres lorsque le volume et le moteur le permettent.

## Types et précision

| Donnée | Stockage | Présentation |
|---|---|---|
| Code article/commande/facture, identifiant, téléphone | Texte natif | Conserver zéros, signes et valeur exacte |
| Quantité | Nombre | Format #,##0.### ; unité dans sa colonne |
| Prix/montant | Nombre | Format #,##0.00 ; devise de la source séparée |
| Ratio fourni | Nombre | 0.30 stocké pour 30 %, format 0.00% |
| Date/heure | Date native | dd/mm/yyyy ou dd/mm/yyyy hh:mm |
| Information numérique absente | Cellule vide | État ou motif à proximité |
| Zéro connu | Nombre 0 | Ne pas le confondre avec une absence |

Les formats sont des codes de cellule ; l’affichage dépend de la langue du tableur. Ne pas écrire des nombres français déjà formatés dans les cellules numériques. Les identifiants longs restent textuels pour éviter perte de précision et notation scientifique.

La devise n’a aucun défaut implicite. Les modèles logistiques actuels ne portent pas une devise par ligne : un format USD existant dans React n’autorise pas à marquer ces montants USD dans le classeur. Conserver le montant source avec une devise vide/qualifiée lorsque nécessaire. Ne pas convertir ou sommer plusieurs devises ou unités.

## Présentation et usage

Appliquer la [charte commune](charte_documentaire.md). Figer les en-têtes et les colonnes d’identification utiles, activer les filtres, aligner texte à gauche et nombres à droite. Largeurs adaptées, retours à la ligne pour désignations longues et horodatages complets visibles ; aucun #### ou texte masqué par une hauteur trop faible.

Les couleurs de statut complètent un libellé explicite. Les totaux sont distincts des données et ne mélangent pas lignes et sous-totaux déjà comptés. Un total source partiel ou non calculable est signalé, pas reconstitué par une formule locale.

Les graphiques reprennent les agrégats du backend. Un classeur de simulation peut contenir ses formules autorisées, mais il est identifié comme simulation ; il ne remplace pas un export d’état figé.

## Impression

Définir zone d’impression, orientation et répétition des en-têtes. Adapter à la largeur de la page si le texte reste lisible ; ne pas réduire des centaines de lignes sur une page en hauteur. Préférer paysage ou découpage logique à une police minuscule. Une facture ou un bon court tient normalement sur A4 ; un registre très large peut nécessiter une autre organisation explicitement choisie.

L’en-tête/pied reprend organisation, titre court, période ou référence et pagination lorsque pertinent. Une couverture n’est pas imposée à un simple registre.

## Formules et sécurité des cellules

Un texte importé commençant par =, +, - ou @ reste une cellule texte, sans devenir une formule ou un lien externe. Les formules contrôlées d’un modèle sont distinctes des valeurs source. Pour CSV, choisir et documenter une protection contre la réinterprétation à l’ouverture, sans altérer le fichier source original.

Préserver TCD, validations, connexions et macros seulement si l’outil utilisé le permet et si la demande les couvre ; ne pas en ajouter par défaut. Une feuille masquée ou protégée n’assure pas la confidentialité.

## Contrôle

Ouvrir le fichier avec un lecteur de classeur : vérifier types, valeurs, filtres, volets, formules et erreurs. Si des formules sont générées, contrôler leur recalcul et leurs valeurs en cache avec un moteur compatible ; une option de recalcul à l’ouverture ne constitue pas une preuve. Vérifier le rendu/impression dans un tableur disponible et annoncer la cible réellement testée ; aucune version d’Office n’est présumée validée pour SauverNdeko.
