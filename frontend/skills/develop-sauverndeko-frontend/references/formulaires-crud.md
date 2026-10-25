# Formulaires métier et CRUD Articles

## Composants à reprendre

Pour un nouveau formulaire ou une refonte, utiliser les composants partagés de frontend/src/components/ avant de créer une variante :

- RecordEditorFrame et DrawerDialog : création, modification et confirmations dans une fenêtre latérale. Conserver Réduire, Élargir, Rétablir la largeur et Fermer, avec les mêmes icônes que les fiches 360.
- SearchSelect : composant commun des filtres métier et références à choix simple, selon le contrat ci-dessous.
- [CategoricalSelect](../../../src/components/CategoricalSelect.jsx) : adaptateur de SearchSelect pour migrer les select contrôlés en conservant `name`, `required`, options/optgroup et les gestionnaires `event.target.name/value`. Le select natif conserve FormData et la validation HTML5 ; relayer `onInvalid` et placer le focus sur le contrôle visible. Le blocage d’un fieldset doit aussi neutraliser et fermer son panneau en portail. Utiliser SearchSelect directement lorsque le gestionnaire reçoit déjà la valeur.
- ProductPhotoPicker et ArticlePhoto : choix de fichier, prise de photo demandée par l’utilisateur, aperçu et affichage autorisé. Pas de champ URL dans le parcours courant.
- LotFields : plusieurs numéros de lot pour un stock initial ou une ligne de réception/sortie.
- ActionButton et AppIcon : boutons et icônes communs. Ne pas ajouter une bibliothèque d’icônes pour un écran.

Les champs utilisent les variables de thème, des bordures discrètes, un focus visible et une hauteur cohérente. Grouper par sujet dans des sections compactes : deux colonnes sur ordinateur, une sur mobile. Les erreurs restent près du champ ; Annuler et Enregistrer restent accessibles au bas de la fenêtre.

Références demandées : [éléments TailAdmin](https://demo.tailadmin.com/form-elements), [disposition des formulaires](https://demo.tailadmin.com/form-layout), [liste de produits](https://react-demo.tailadmin.com/products-list). Reprendre lisibilité et interactions dans React/Bootstrap existant, sans migration de framework.

## Sélecteurs des filtres métier et références

Tout filtre métier catégoriel et toute référence à choix simple utilisent [SearchSelect](../../../src/components/SearchSelect.jsx), déjà commun aux choix Licence et Article. Cela couvre les formulaires et les filtres des registres, tableaux de bord, dossiers et fiches 360 : organisation, licence, rôle, catégorie, type, unité, statut ou période prédéfinie. Réutiliser ce composant ; faire évoluer son comportement commun si nécessaire.

- Options `{value, label}` et valeur sélectionnée stables ; `onChange` reçoit directement la valeur sous forme de chaîne, pas un événement DOM. Préserver les valeurs attendues par l’API, y compris `"false"`, `"0"`, `"all"` ou `""` lorsqu’elles sont prévues. Une référence ancienne reste lisible même si elle n’est plus proposée.
- Ajouter explicitement Tous/Toutes pour un filtre sans restriction et Non renseigné pour une référence facultative, avec la valeur prévue par le contrat API. Choisir… est une indication de saisie, pas une option de remise à zéro.
- Recherche des options insensible à la casse et aux accents, choix actuel marqué d’une coche, nombre d’options et état Aucun résultat. Rechercher dans les options ne modifie pas à lui seul les critères appliqués au tableau ni sa population serveur.
- Associer un `id` et un libellé accessible. Conserver ouverture et navigation au clavier, Home/End, validation, Échap, Tab et retour au déclencheur ; désactiver le choix pendant chargement ou enregistrement et afficher l’erreur au champ.
- Le panneau utilise le portail commun dans le dialog actif ou le document. Il reste visible au-dessus des tableaux et fenêtres, dans les limites de la zone visible, sans être coupé par un conteneur défilant. Contrôler focus, coche, états et lisibilité en Clair, Sombre, Contraste élevé, au zoom et sur mobile.

Les réglages techniques courts, tels que taille de page, densité et thème, gardent leur contrôle existant adapté. Dates, nombres, texte et cases de formulaire gardent aussi leur saisie propre. Une sélection multiple conserve un composant conçu pour plusieurs valeurs ; ne pas la réduire à ce sélecteur simple. Ces exceptions ne justifient pas un nouveau select natif pour un filtre métier catégoriel.

## Contrat du formulaire Article

ArticleEditor.jsx est la base livrée pour les futurs CRUD. Charger la fiche fraîche et sa révision à l’ouverture d’une modification. Envoyer les champs modifiés avec _version. En cas de conflit, proposer de recharger ; ne pas écraser silencieusement une modification concurrente.

En modification, présenter tous les champs métier et préremplir leurs valeurs reçues, y compris code externe, état actif, photo, poids, devise et informations complémentaires. Garder visibles en lecture seule les informations protégées : identifiant, responsable, création horodatée, stock et début d’alerte calculé. Une valeur nulle ne devient ni zéro ni une valeur déduite ; respecter les verrouillages de l’historique et conserver la saisie en cas d’erreur.

Le stock actuel est consultable dans l’éditeur, sans modification directe : les bons portent entrées et sorties. Le stock initial se saisit à la création. Le responsable vient du compte connecté et reste conservé en modification. Après le premier mouvement, l’unité de stock reste verrouillée.

Annuler, fermer ou Échap avec une saisie demande de l’abandonner dans la fenêtre. Pendant l’enregistrement, bloquer la double soumission et la fermeture. Après succès, actualiser liste et références sans effacer les filtres ; restaurer le focus au déclencheur. Une erreur conserve la saisie.

## Réception depuis un article

L’action Réceptionner stock du menu ⋯ Articles ouvre une fenêtre latérale préparant un bon d’entrée pour l’article sélectionné : quantité reçue, prix d’achat unitaire, devise et lots éventuels. Suggérer le prix catalogue uniquement dans la même devise ; sinon demander un prix explicite dans la devise du bon, sans conversion automatique. Le stock actuel reste en lecture seule ; la réception ajoute une entrée par le parcours métier du bon et de sa ligne, sans écriture directe de QteArticle ni second mouvement côté interface. Conserver les droits, la confirmation d’abandon et le blocage pendant l’enregistrement du formulaire commun ; annuler avant envoi ne crée aucun document.

Le champ Type de bon utilise SearchSelect et la référence T_Commande.ID_TypeCmdFk. Pour une réception, proposer uniquement les types de sens entrée actifs autorisés par le serveur ; identifiants, libellés et choix initial viennent de l’API. Réutiliser le référentiel commun, sans valeur ni libellé de type imposés dans l’écran et sans table de types propre à ce formulaire.

## Poids, lots et informations

- Poids unitaire et unité de masse sont facultatifs ensemble. Ils ne changent ni unité ni quantité de stock. Conserver les décimales comme chaînes dans les échanges.
- Un article peut avoir plusieurs lots reçus avec les produits. Le numéro appartient à l’article et à ses mouvements, pas à une unique colonne N° lot sur la fiche. Une ligne peut ventiler sa quantité entre plusieurs lots.
- Une sortie reprend des lots déjà reçus. Si une ventilation est saisie, sa somme égale la quantité de la ligne. Les historiques non identifiés restent sans lot ; ne pas inventer de numéro.
- Les lots des fiches Produit 360 et Bon de stock 360 concernent uniquement l’objet consulté. Le registre Articles peut afficher leur nombre.
- InformationArticle décrit le produit et ses caractéristiques. Le présenter avant Observation (ObsArticle), réservé aux remarques. Ce texte ne remplace pas une donnée structurée indispensable aux calculs.

## Photos

L’utilisateur choisit un fichier ou démarre lui-même la caméra. Arrêter le flux en quittant la capture ou la fenêtre ; ne pas ouvrir le microphone. Garder l’aperçu local jusqu’à l’enregistrement. Une erreur laisse la saisie disponible.

Le serveur contrôle et convertit l’image. Les fichiers privés sont dans backend/media/Article/ par défaut, avec un nom dérivé de l’article et un suffixe unique. La base contient le chemin généré. Renommer l’article ne renomme pas automatiquement l’ancien fichier. Ne pas publier ce dossier comme répertoire statique ouvert. Sauvegarder les fichiers en plus de PostgreSQL.

## Recette

Vérifier création, modification, conflit, désactivation/réactivation, suppression admissible ; conservation des filtres ; annulation ; erreurs serveur et double clic ; recherche/sélection au clavier ; commandes et focus de la fenêtre ; photo et arrêt du flux ; poids et lots ; clair/sombre et mobile. Réaliser les écritures de recette sur un environnement fictif indépendant, jamais sur les données du client.

Cette base est livrée pour Articles. Étendre progressivement ces composants aux autres formulaires ; leur présence ne signifie pas que tous les anciens onglets sont déjà refondus.

## Devises des prix et documents

Article et bon de stock choisissent leur devise avec SearchSelect depuis les références serveur. USD est le défaut des créations via defaultCurrencyId ; conserver la valeur existante en édition. Respecter canChangeCurrency et le verrouillage des bons après lignes/facturation. Un prix catalogue d’une autre devise ne remplit jamais automatiquement le prix de ligne : demander le prix dans la devise du bon. Les règlements héritent de la facture ; les mouvements conservent leur devise historique. Synthèse, liste et export partagent deviseId (ou sans-devise). Ne pas additionner plusieurs devises et ne pas convertir les Decimal en Number ; les exports séparent montant numérique et code de devise.
