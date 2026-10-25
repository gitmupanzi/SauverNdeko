# Formulaires métier et CRUD Articles

## Composants à reprendre

Pour un nouveau formulaire ou une refonte, utiliser les composants partagés de frontend/src/components/ avant de créer une variante :

- RecordEditorFrame et DrawerDialog : création, modification et confirmations dans une fenêtre latérale. Conserver Réduire, Élargir, Rétablir la largeur et Fermer, avec les mêmes icônes que les fiches 360.
- SearchSelect : références avec recherche, choix sélectionné visible, navigation au clavier, état vide et état désactivé. Prévoir une option vide pour une valeur facultative. Une valeur ancienne doit rester lisible même si elle n’est plus proposée.
- ProductPhotoPicker et ArticlePhoto : choix de fichier, prise de photo demandée par l’utilisateur, aperçu et affichage autorisé. Pas de champ URL dans le parcours courant.
- LotFields : plusieurs numéros de lot pour un stock initial ou une ligne de réception/sortie.
- ActionButton et AppIcon : boutons et icônes communs. Ne pas ajouter une bibliothèque d’icônes pour un écran.

Les champs utilisent les variables de thème, des bordures discrètes, un focus visible et une hauteur cohérente. Grouper par sujet dans des sections compactes : deux colonnes sur ordinateur, une sur mobile. Les erreurs restent près du champ ; Annuler et Enregistrer restent accessibles au bas de la fenêtre.

Références demandées : [éléments TailAdmin](https://demo.tailadmin.com/form-elements), [disposition des formulaires](https://demo.tailadmin.com/form-layout), [liste de produits](https://react-demo.tailadmin.com/products-list). Reprendre lisibilité et interactions dans React/Bootstrap existant, sans migration de framework.

## Contrat du formulaire Article

ArticleEditor.jsx est la base livrée pour les futurs CRUD. Charger la fiche fraîche et sa révision à l’ouverture d’une modification. Envoyer les champs modifiés avec _version. En cas de conflit, proposer de recharger ; ne pas écraser silencieusement une modification concurrente.

Le stock actuel est consultable dans l’éditeur, sans modification directe : les bons portent entrées et sorties. Le stock initial se saisit à la création. Le responsable vient du compte connecté et reste conservé en modification. Après le premier mouvement, l’unité de stock reste verrouillée.

Annuler, fermer ou Échap avec une saisie demande de l’abandonner dans la fenêtre. Pendant l’enregistrement, bloquer la double soumission et la fermeture. Après succès, actualiser liste et références sans effacer les filtres ; restaurer le focus au déclencheur. Une erreur conserve la saisie.

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
