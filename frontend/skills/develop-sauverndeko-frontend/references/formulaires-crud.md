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
- Une sortie reprend des lots déjà reçus. Sa ventilation peut être partielle si le reliquat est couvert par le stock disponible sans lot ; afficher séparément les quantités ventilées et sans lot. Pour une entrée, une ventilation saisie reste complète. Les historiques non identifiés restent sans lot ; ne pas inventer de numéro.
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

## Bons de stock et lignes

Commandes.jsx et CommandeDetails.jsx reprennent la surface Articles : barre de recherche unique, filtres appliqués côté serveur, sélection par clé stable, menus de ligne, colonnes/densité et export XLSX complet. Les lignes utilisent /api/logistique/registre/lignes ; ne pas rétablir le chargement plafonné suivi d’un filtre dans le navigateur. Un bon cible apparaît comme une puce effaçable, sans perdre les autres critères. La colonne Devise reste optionnelle quand le code accompagne les montants.

BonComposer (ajout et modification du bon), OrderDeleteDialog et BonLineEditor réutilisent les fenêtres communes ; les formulaires utilisent RecordEditorFrame. Charger la fiche fraîche, ses valeurs brutes et meta.revision avant modification ou suppression ; transmettre _version et proposer de recharger en cas de ORDER_CONFLICT/LINE_CONFLICT. Conserver les champs métier absents à NULL et les métadonnées protégées en lecture seule. Une modification conserve auteur, dates automatiques et identité composée bon/article ; les limites annoncées par meta (type, devise, référence de facture, clôture, suppression) ne remplacent pas les contrôles serveur.

Le prix d’une ligne est explicite dans la devise du bon. Le prix proposé vient du catalogue uniquement dans la même devise et selon le sens du bon ; aucune conversion de change. Un prix absent reste vide, sans devenir zéro ; l’utilisateur doit le renseigner avant une écriture. Les quantités restent entières selon le journal de stock. Les lots utilisent LotFields et les triggers existants restent seuls responsables des mouvements. Rechoisir le même bon/article ne doit pas vider le brouillon.

Commande 360 (libellé Bon de stock 360) utilise OrderOverview, ConsultationTabs et les tableaux communs : Synthèse, Lignes, Mouvements, Lots, Facturation et Contrôle. Facturation regroupe les lectures facture et règlements existantes ; Contrôle présente les champs de contrôle de la vue, sans calcul inventé. Toutes les rubriques sont liées au bon sélectionné. Une ligne peut ouvrir Produit 360 puis revenir au bon, à la rubrique et aux critères précédents.

## Création d’un bon avec ses articles

Depuis Bons de stock, Nouveau bon ouvre BonComposer : informations du bon puis catalogue et panier dans la même fenêtre. Rechercher, paginer et sélectionner plusieurs articles côté serveur, sans perdre le panier. Le catalogue de composition utilise contexte=composition pour respecter l’organisation du compte ; une sortie ne propose que les articles actifs de stock strictement positif, y compris le stock faible. Une entrée permet les articles actifs à stock nul.

Quantité, prix unitaire, lots et informations facultatives de chaque ligne restent modifiables avant enregistrement. Proposer le prix d’achat pour une entrée et le prix de vente pour une sortie, seulement dans la devise du bon. Verrouiller type et devise tant que le panier contient des articles. Les totaux utilisent les outils décimaux exacts ; ne pas additionner les quantités d’unités différentes comme un indicateur métier. Les champs du panier conservent leurs valeurs en changeant de page.

Envoyer une seule demande /api/logistique/commandes/composees avec requestId stable, bon et lignes. Ne pas enchaîner des créations d’en-tête et de lignes dans le navigateur. Après une réponse perdue ou une erreur serveur ambiguë, figer le panier et proposer Réessayer avec la demande identique ; avertir à la fermeture que le bon peut déjà exister. Une erreur de validation connue reste corrigeable et localisée au champ ou à la ligne. La modification d’un bon existant garde le formulaire complet et le contrôle de révision.

## Identification des articles et parcours de préparation

Le catalogue d’un bon présente une identité permettant de distinguer les articles proches : nom, code interne, référence, type, catégorie et stock avec son unité. Afficher les informations disponibles sous forme compacte, avec des libellés et séparations lisibles ; ne pas masquer la référence lorsqu’un code interne existe. Les libellés viennent de V_Article et du référentiel commun, sans recherches individuelles par ligne. La recherche, le comptage et la pagination restent côté serveur.

La référence fonctionnelle Access F_AjoutCommande décrit la préparation des informations du bon, la recherche/sélection des produits, leur quantité et prix, les compléments de ligne, le panier modifiable puis l’enregistrement. Conserver le brouillon lorsqu’une référence est créée par un raccourci autorisé. Les créations de référence et les sélecteurs doivent reposer sur des objets réellement raccordés ; ne pas demander de deviner un identifiant de lieu.

État vérifié le 25 octobre 2026 : marque, modèle, numéro de série et provenance ne sont pas des colonnes structurées de T_Article/V_Article. InformationArticle est du texte libre ; ne pas en extraire des valeurs supposées. LieuCmdDetail et ID_ClientFk ne possèdent pas de FK métier démontrée et aucun Projet n’est présent dans le modèle actuel. Leurs anciens identifiants Access ne prouvent aucune correspondance. Une cascade Pays/Province/Destination, des créations rapides de tiers/lieu et une modification atomique de tout le panier restent des évolutions à raccorder ; la création composée et les modifications versionnées des lignes existent déjà.

## Code du bon automatique et immuable

Le code du bon est attribué par le serveur à l’enregistrement, au format court cmd- suivi de l’identifiant du bon, sans zéros ajoutés (exemple cmd-112). En création, afficher Attribué à l’enregistrement en lecture seule. En modification et en consultation, afficher le code reçu sans contrôle permettant de le changer. CodeCmd ne fait pas partie des valeurs éditables ni des payloads de création/modification, y compris dans les anciennes configurations de formulaire. Réception et création avec panier utilisent la même numérotation serveur.

La migration de nomenclature du 25 octobre 2026, explicitement demandée par le propriétaire, remplace aussi les anciens codes et complète les codes manquants ; la correspondance est conservée dans l’audit. Hors migration, l’ouverture d’une fiche n’attribue ni ne change aucun numéro. Les factures utilisent fac- suivi de l’identifiant du bon (exemple fac-112), émis uniquement par le service de facturation. Le refus de modifier le code appartient aussi à l’API, même pour un administrateur. Une nouvelle tentative de la même demande rejoue le bon et son numéro existants.


## Formulaire unique, panier compact et suivi du bon

Le formulaire d’ajout est aussi celui de modification : BonComposer recharge les valeurs brutes du bon et toutes ses lignes via GET /commandes/{id}/composition, puis utilise PUT sur ce même contrat avec sa révision. Ne pas ouvrir un second formulaire réduit pour Modifier. Conserver les valeurs absentes à NULL, l’identité automatique, les lots et les observations existantes. Le panier d’édition peut contenir des articles historiques absents du catalogue courant ; leur disparition du catalogue ne les retire pas du bon.

Les sous-onglets sont, dans cet ordre exact : **Bon · Articles · Suivi bon · Facturation · Traçabilité**. Bon contient l’identité et le tiers ; Articles contient le catalogue puis les lignes choisies ; Suivi bon regroupe statut, bon de livraison et suivi ; Facturation regroupe les conditions de paiement et le parcours de facture ; Traçabilité présente les informations historiques et automatiques en lecture seule. Le même ordre s’applique à l’ajout et à la modification. Un document pas encore enregistré ne reçoit aucun faux numéro ni horodatage d’enregistrement.

Dans Articles, Catalogue des articles occupe toute la largeur, puis Articles du bon vient dessous, également en pleine largeur. Le panier est un tableau compact : une ligne par article sur ordinateur, identité et stock, quantité, prix unitaire avec devise, montant et actions. Les informations facultatives et lots s’ouvrent à la demande ; ne pas réserver deux bandes fermées sous chaque produit. Conserver les brouillons, erreurs par ligne, navigation clavier et adaptation mobile. Vérifier la lisibilité avec dix articles.

La restitution physique utilise BonReturnEditor et le service /commandes/{id}/retours. Afficher quantités sorties, déjà restituées et encore restituables ; le cumul et chaque lot ne dépassent jamais la sortie source. Proposer Tout restituer sans imposer le retour complet. Les prix historiques et la devise sont conservés. Les anciens booléens de remise restent historiques en lecture seule et ne remplacent pas cet événement métier. La fiche du bon donne accès à l’historique et au contre-document ; celui-ci revient vers sa sortie d’origine.

InvoiceEditor constitue le formulaire unique de création et de modification de facture. Le numéro et les lignes émises ne sont pas saisis par le client. Avant émission, facturer les quantités nettes des restitutions déjà enregistrées ; après émission, conserver l’instantané et signaler Avoir à établir pour les retours ultérieurs. L’émission d’un avoir et le remboursement sont des parcours distincts encore à raccorder. Une condition de paiement contient un délai explicite fourni par le serveur ; ne jamais traiter son ID comme un nombre de jours. Un bon d’entrée de restitution ne devient pas une nouvelle vente.


## Sous-onglets du formulaire Article

ArticleEditor reste le formulaire unique d’ajout et de modification, avec les sous-onglets **Article · Stock et prix · Lots · Conservation · Informations · Traçabilité**. Article réunit photo, identification et état actif ; Stock et prix réunit unité, quantités, poids, devise et tarifs ; Lots contient les lots du stock initial en création et le raccourci réel Produit 360 en édition ; Conservation regroupe péremption et alerte ; Informations conserve InformationArticle et ObsArticle ; Traçabilité présente les auteurs et dates automatiques sans inventer de valeur.

Conserver le brouillon, la photo choisie, son retrait et les lots en changeant d’onglet. Le composant de capture est démonté hors Article pour arrêter caméra et autorisation tardive sans perdre le fichier conservé par l’éditeur. Les contrôles de révision et champs protégés restent identiques. Le bouton global Enregistrer valide aussi les champs masqués par JavaScript et active la rubrique de la première erreur avant d’y restituer le focus ; aucune contrainte native ne doit bloquer sur un champ invisible. Sur mobile, la barre commune défile horizontalement et reste utilisable au clavier.


## Mouvements, factures et règlements

Les registres Mouvements de stock et Factures et règlements reprennent RegisterSurface, DataTableToolbar et SimpleTable. Conserver une barre unique, les filtres métier SearchSelect repliables, les critères appliqués visibles et effaçables, les colonnes/densités, la pagination serveur et l’export Excel complet. Les colonnes monétaires affichent leur devise ; Devise reste décochée par défaut à l’écran, mais accompagne les nombres dans l’export.

Mouvements de stock reste un journal en consultation. Les menus de ligne ouvrent le produit ou le bon concerné ; aucune modification ni suppression directe du journal. Pour un compte habilité, Réceptionner du stock ouvre StockReceiptEditor sur l’article sélectionné : un bon d’entrée et ses lots éventuels créent le mouvement par les triggers existants. Ne pas créer un autre formulaire de quantité ni ajouter un second mouvement. Les filtres catégorie et type d’article restent distincts du type de mouvement. Le champ Stock actuel est une situation courante du catalogue ; ne pas le présenter comme un solde historique après chaque mouvement. Les quantités gardent leur unité, la variation signée reste distincte de la quantité et aucun total ne mélange des unités incompatibles. Les choix Article et Bon sont recherchés et paginés côté serveur, sans catalogue arbitrairement tronqué.

Le menu Finances présente deux entrées distinctes, Factures et Règlements, chacune ouvrant directement son registre. Conserver leurs filtres, pages et tris en changeant d’entrée ; ne pas ajouter un second choix Factures/Règlements dans ces pages. Factures contient exclusivement des documents émis, jamais les bons sans facture. Le montant facturé vient du serveur et peut différer de la valeur du bon après restitution. Les indicateurs sont repliés par défaut et les montants groupés par devise. Le code de facture ouvre openOrderInvoice ; le journal du document peut être ouvert avec openOrderPayments. Ces deux méthodes visent la rubrique exacte de Bon de stock 360, avec les droits et le retour au contexte communs.

ReglementEditor sert à l’ajout et à la modification. Charger la préparation de facture à la création et la fiche fraîche avec révision en modification. La devise, le tiers et la facture liée sont hérités et protégés ; date/heure, mode actif du référentiel et montant sont saisis dans le même formulaire. Conserver les chaînes décimales, les erreurs aux champs, la confirmation d’abandon et le blocage des doubles envois. Un conflit laisse la saisie disponible et propose le rechargement explicite. Après une réponse ambiguë, conserver l’UUID et le corps exacts pour Réessayer sans double paiement. Ne pas inventer un champ Observation absent du modèle.

Les actions suivent les droits du module, les permissions du compte et les capacités renvoyées par l’API. Un refus 401/403 ou un changement d’utilisateur, d’Entité ou de périmètre efface données et sélections privées. Une recherche, une pagination ou une ouverture de fiche ne provoque pas de rechargement de page ; conserver le tableau pendant un chargement dans le même contexte et ignorer les réponses obsolètes.


### Préparer plusieurs règlements

ReglementBatchEditor reprend le parcours de préparation en panier : rechercher les factures d’un tiers dont le solde est positif, y compris celles partiellement réglées, préparer date/heure, mode et montant, puis ajouter les lignes à un tableau compact. Les filtres et la navigation du catalogue ne vident pas le panier. Conserver l’accès au formulaire individuel et le même ReglementEditor pour sa modification.

Une facture peut recevoir plusieurs modes dans ce panier, sans doublon facture/mode ; les règlements historiques d’un même mode restent autorisés. Le solde proposé déduit les lignes déjà préparées pour cette facture. Les montants restent des chaînes décimales exactes et les totaux sont distincts par devise. Un changement de sélection, une erreur serveur ou un conflit ne supprime pas la saisie.

Enregistrer le panier par un seul POST /api/logistique/reglements/groupes, avec requestId stable et révision de chaque facture préparée. Un échec refuse tout le panier ; après une réponse incertaine, Réessayer conserve le même corps et le même UUID. Ne pas envoyer une boucle de créations indépendantes ni annoncer un règlement validé avant la réponse serveur.


Dans le panier d’un bon de sortie, rendre visible le besoin de lots et ouvrir leur saisie depuis la ligne. Réutiliser SearchSelect pour choisir les lots reçus, avec leur disponibilité. Charger les budgets par lot sans perdre les quantités, prix ou lots déjà saisis. Une erreur serveur lignes.<indice>.Lots désigne l’article concerné, ouvre sa rubrique Lots et conserve le panier ; ne pas afficher les noms SQL ni le message technique PostgreSQL. L’indication de disponibilité ne remplace pas la validation serveur sous verrou.

## Filtres catégoriels des registres

Les choix de population des listes logistiques utilisent RegisterCategoryFilter et SearchSelect : liste compacte recherchable, choix actif visible et options dynamiques du référentiel. Éviter une rangée de boutons pour chaque catégorie. Conserver les handlers de filtrage serveur, la remise à la première page et les autres critères. Les véritables sous-onglets des formulaires et consultations restent ConsultationTabs.

## Comptage physique

Le formulaire d’inventaire conserve deux rubriques : Comptage et Validation. Dans Comptage, présenter les informations, le catalogue recherchable avec sélection multiple, puis les articles comptés sur toute la largeur, comme dans la composition d’un bon. L’ajout conserve les valeurs saisies et évite les doublons ; un inventaire validé reste consultable sans catalogue d’ajout. Afficher les détails métier des erreurs API au lieu du seul libellé générique.

Lorsqu’une action de ligne ouvre un détail sous le tableau, faire défiler uniquement le conteneur de la fenêtre jusqu’à ce détail après son rendu et lui transférer le focus sans second saut. Respecter la préférence de mouvement réduit. Un nouveau clic sur le même article révèle de nouveau le détail ; sa fermeture rend le focus et la visibilité au bouton de la ligne d’origine, sans modifier les saisies.

## Documents depuis les actions d’une ligne

Les menus ⋯ proposent les fichiers disponibles pour l’objet sélectionné, via RowDocumentActions : PDF de bon selon son sens, facture uniquement si émise, reçu de règlement et Excel ciblé sur les clés exactes. La facture du bon est aussi accessible depuis Bons de stock. Réutiliser les mêmes routes autorisées que les fiches 360 et la charte documentaire ; ne pas exporter toute une liste à la place de la ligne, ni afficher un format non raccordé. Conserver les droits d’export, le blocage des doubles clics, les erreurs avec Réessayer et l’annulation après changement d’entreprise.

Dans Bons de stock, afficher Code facture par défaut à côté du numéro de bon ; conserver la colonne sélectionnable, le tri et son inclusion dans les exports. Une facture absente reste représentée par —.

## Colonnes par défaut — accord du 26 octobre 2026

Bons de stock : Bon de stock · Code facture · Date et heure · Type de bon · Statut du bon · Tiers · Quantité totale · Montant TTC · Paiement · Référence · Actions. Une seule définition de CodeFacture, libellée Code facture ; ne pas ajouter une deuxième colonne Facture. Les colonnes facultatives restent sélectionnables sans dupliquer leur clé.

Articles : Article · Catégorie · Type · Stock actuel · Lots · État de l’article, puis Actions pour l’accès aux opérations. Lots ouvre la consultation liée ; État de l’article indique Actif/Inactif, distinct de la disponibilité du stock. Les prix, la péremption et les autres informations restent disponibles dans le choix des colonnes.

Le menu ⋯ des inventaires validés propose Annuler la validation selon les droits. Employer une fenêtre commune avec motif obligatoire, état d’envoi, conservation de la demande en cas de réponse incertaine et erreurs explicites. Après succès, montrer Annulé et conserver la fiche, l’auteur, la date, le motif et les bons compensateurs. Aucun bouton de suppression de l’historique.


## Conservation du stock

Articles → Conservation utilise RecordEditorFrame et SearchSelect, avec entreprise active, délai d’alerte et règle des lots périmés. La date générale de l’article vise le stock sans lot ; les lots conservent chacun leur date. Les consultations reprennent les quantités périmées/proches et la prochaine date réellement en stock. Le formulaire de lot sortant présente au compte global un motif de dérogation quand un lot périmé est sélectionné ; préserver ce motif dans la composition, la modification et le comptage. Une suggestion FEFO reste un choix à confirmer et exclut les lots périmés par défaut.

## Registre Lots de stock et fiche Lot 360

Le registre commun des lots suit Articles et présente tous les lots, y compris épuisés/archivés par défaut. Réutiliser les composants de registre, filtres catégoriels recherchables, pagination/tri serveur et menu ⋯. Le sélecteur d’article distant doit paginer ses options, jamais charger un catalogue exhaustif pour un simple choix. Lot 360 reprend DrawerDialog et ConsultationTabs avec Synthèse/Mouvements ; les mouvements sont demandés au serveur uniquement pour le lot choisi. Chaque quantité conserve son abréviation d’unité. Les changements de contexte d’Entité effacent les lignes et la fiche ; une ancienne réponse ou un téléchargement annulé ne doit pas réafficher les données précédentes. Proposer la fiche Excel dans les actions, sans PDF fictif ni édition directe du stock.
