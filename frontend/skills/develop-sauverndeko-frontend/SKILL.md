---
name: develop-sauverndeko-frontend
description: Faire évoluer les interfaces React de SauverNdeko vers des parcours ERP modernes, avec tableaux cohérents, indicateurs consultables et fiches 360 accessibles. Utiliser pour navigation, formulaires, filtres, consultations produit/commande et présentation des données API.
---

# Frontend SauverNdeko

Pour **Structures** (`/pharmacies`), suivre [le contrat des structures et territoires](../../../SQL/documentation/Annuaire_Sanitaire_Territorial_20261104.md) : une seule population N3/N4/N5 depuis `/api/structures/annuaire-sanitaire`, avec tous les types territoriaux communs actifs, dont districts, secteurs et groupements. Les choix de nouveaux types suivent les visibilités du niveau renvoyées par l’API ; conserver les anciennes valeurs hors choix en option désactivée, sans élargir une liste vide. Ces visibilités ne masquent pas les affectations historiques de l’annuaire. Réutiliser recherche serveur, filtres, pagination, Cartes/Tableau et fiche latérale. Préserver l’identité composite `n5:7` dans les lignes, l’URL et le détail ; un ID numérique seul ne désigne pas une entreprise. Garder la barre de recherche visible hors d’un `SimpleTable showControls={false}`. Afficher les coordonnées et horaires seulement selon leur publication ; Gestion territoriale rejoint les registres N3/N4/N5 sous capacité serveur, avec les pharmacies au niveau 5. La lecture dépend de Structures, sans portée d’entreprise ni licence Territoires. Ne pas y réintroduire profil ERP, logo, discussion ou listes commerciales par ID territorial.

Les niveaux territoriaux 1 à 5 affichent une rubrique **Coordonnées** dans la fiche commune et les détails des lignes du panier : contacts, accueil, horaires et publication explicite des coordonnées, `false` par défaut. La publication ne conditionne pas le nom, le type et le rattachement territorial. Préserver les champs inconnus comme valeurs absentes, la révision opaque et la saisie après erreur. Ne pas copier les contacts du parent ni confondre une adresse professionnelle avec un point GPS ou l’identité d’une entreprise.

Pour [Professionnels](../../../docs/professionnels.md), conserver une seule liste d’annuaire avec choix Cartes/Tableau, recherche serveur par besoin et consultation latérale du même identifiant. Le registre privé suit les droits d’entreprise ; son formulaire commun d’ajout/modification enregistre ensemble les compétences, prestations et structures. Ces enfants partagent le parent, mais la fiche complexe reste individuelle. Les réglages des références affichent les catégories et valeurs renvoyées par l’API. Publication, activité et prise de contact restent distinctes ; ne pas inventer de badge de qualification ni afficher les notes internes dans l’annuaire.

Pour le [module Caisse](../../../docs/module-caisse.md), afficher les totaux séparément par devise, les brouillons et les écritures validées sans ambiguïté. Le frontend utilise les soldes et autorisations du serveur, conserve la même demande après réponse incertaine et ne propose pas de suppression d’écriture validée. Réutiliser les registres, préférences, formulaires et thèmes communs ; documenter le parcours dans le Guide utilisateur.

Le module Guide utilisateur réutilise la navigation, les thèmes et le contexte d’entreprise communs. Ses parcours et exemples proviennent de l’API autorisée, sans manuel complet embarqué côté navigateur. Une recherche ne porte que sur les articles autorisés. Lors d’un changement d’entreprise ou de droits, retirer immédiatement l’ancien contenu et ignorer les réponses périmées. Utiliser des URL stables par module/article et des liens vers les écrans existants ; ne pas inventer de bouton métier ou de démonstration qui écrit des données.

Lire les [consignes du projet](../../../skills/AGENTS.md) avant une intervention.

## Références

**Libellés catégoriels communs :** pour les choix provenant de `referentiel.T_Generique`, afficher `AbrGenerique` et transmettre `ID_Generique`. Appliquer cette règle aux listes SearchSelect, filtres, formulaires, paniers et anciennes valeurs conservées, y compris Support. Ne pas remplacer cette abréviation par `NomGenerique` ni afficher un identifiant de catégorie à la place de la valeur choisie. Si l’abréviation manque, conserver l’identifiant et un libellé neutre explicite ; ne pas modifier les données pour corriger un simple affichage. Les listes d’entreprises, utilisateurs et catégories gardent leurs propres libellés.

- [Architecture existante](references/architecture.md) pour les composants, routes, helpers et limites du code actuel.
- [Références de design et d’usage](references/design-reference.md) pour comparer TailAdmin et shadcn/ui à l’existant : accueil, navigation, formulaires, tableaux et retours d’opération.
- [Champs, filtres métier et CRUD Articles](references/formulaires-crud.md) pour le standard SearchSelect, les fenêtres latérales, photos, poids et lots : base des futurs onglets.
- [Contrats d’interface](references/contrats-interface.md) pour tableaux, indicateurs, fenêtres 360, filtres, exports et recette.
- [Module Support](references/support.md) pour le registre Tickets, le Kanban, les actions de traitement, les échanges internes et les réponses réseau incertaines.
- [Entités, tiers et stock](../../../skills/sauverndeko-erp/references/entites-tiers-et-stock.md) pour le partage par entreprise/rôle, le futur contexte global, Clients et fournisseurs et la simplicité des lots facultatifs. Distinguer cette cible des écrans installés.
- [Skill transverse ERP](../../../skills/sauverndeko-erp/SKILL.md) pour un changement entre plusieurs domaines.
- [Skill backend](../../../backend/skills/develop-sauverndeko-backend/SKILL.md) dès qu’un nouveau filtre, calcul ou détail API est requis.

- Pour les exports Excel, Word et PDF : [skill documentaire SauverNdeko](../../../skills/document-mise-en-forme/SKILL.md). Réutiliser la charte et le contrat de parité sans recalcul métier propre au format.

## Présentation de la plateforme et recherche

La [vision scientifique et commerciale](../../../docs/vision-et-feuille-de-route-scientifique.md) distingue les fonctions disponibles, les développements en cours et les objectifs à évaluer. La vitrine `/catalogue` utilise les composants et thèmes existants, sans exemples présentés comme réels, compteurs fabriqués, témoignages inventés ou promesse de prédiction/qualification vérifiée. Une réponse API réussie ne prouve pas que les stocks sont récents ou représentatifs de tout le pays. Présenter la disponibilité comme déclarée et la devise reçue par le serveur, sans inférence à partir du seul état actif.

L’annuaire `/produits` utilise sa lecture serveur paginée et une seule population commutable cartes/tableau. Réutiliser les filtres SearchSelect, ModuleSidebar, ModuleHeader et DrawerDialog. La fiche Offre produit ne doit jamais ouvrir le Produit 360 privé de Logistique : elle ne reçoit ni stock exact, ni prix d’achat, ni notes internes. Un lien direct doit charger l’offre par son identifiant publié, même hors de la page courante, et respecter son retrait ultérieur. Conserver critères appliqués, page et focus lors de la consultation ; annuler les lectures obsolètes lors d’un changement de compte ou de contexte.

Le changement cartes/tableau conserve une barre commune de recherche, filtres, taille de page, réinitialisation et densité, y compris pendant un chargement ou avec une liste vide. Avec `SimpleTable showControls={false}`, rendre cette barre hors du tableau : sa prop `toolbar` est masquée avec les contrôles. Vérifier la composition avec les vrais composants, car une doublure de tableau peut masquer cette régression.

Le prix porte unité et devise de l’offre. Deux articles locaux de même nom ne prouvent pas une équivalence ; ne pas les fusionner ni classer leurs prix entre unités ou devises différentes. Les adresses sont déclarées, sans proximité calculée. Contacter l’entreprise ouvre Discussions seulement si autorisé et ne crée aucun message, commande ou réservation à la consultation. Aucun suivi de recherche ne découle de ce parcours sans décision dédiée.

## Entrée de l’application

Depuis le 4 novembre 2026, le module « Informations santé » et sa page « Maladies » sont retirés. Ne plus afficher cette tuile dans `/applications`, `/espace`, les licences ou les menus ; les compteurs excluent également un ancien manifeste `sante`. L’ancienne URL `/maladies` redirige vers `/catalogue`. Ne pas recréer de lecture de cet annuaire ni supprimer les valeurs du référentiel médical encore utiles aux autres domaines.

À la demande du propriétaire du 3 novembre 2026, `/` redirige vers `/catalogue`, accueil public de SauverNdeko. Cette vitrine n’est pas une tuile de module métier et n’appelle aucune API métier. L’espace privé « Vos applications » se trouve à `/espace` ; la connexion y conduit par défaut, tout en conservant une destination protégée explicitement demandée. App.jsx attend la restauration de session pour les parcours métier. Les liens « Applications » des modules ouvrent `/espace` et les liens de présentation ouvrent `/catalogue`. Ne pas ouvrir les stocks, annuaires, discussions ou l’inscription libre par cette exception. Les API historiques `/api/public/*` restent authentifiées ; `/api/workspace/modules` conserve les licences et droits. Les liens de la vitrine vers un parcours protégé passent par la connexion et les gardes habituels.

La vitrine utilise la largeur disponible avec des gouttières réduites et adaptatives, sans large plafond de conteneur centré. Les paragraphes gardent une longueur lisible ; les grilles passent sur une colonne et les actions s’adaptent aux petits écrans. Vérifier notamment 320, 375, 768, 1440 et 1920 pixels, sans masquer un débordement horizontal pour simuler son absence.

Conserver les illustrations locales des cartes Produits, Professionnels et Structures. La barre de navigation reste visible pendant le défilement, avec une surface opaque du thème ; les ancres et le lien d’accès au contenu tiennent compte de sa hauteur réelle, y compris lorsqu’elle revient à la ligne sur mobile. Les images gardent leurs proportions et un espace réservé pour éviter les décalages au chargement.

## Profil et récupération d’accès

Conserver /reset-password hors de ModuleGate et accessible sans session : cette exception ouvre uniquement la récupération, aucun module métier. Le parcours retenu est adresse e-mail, lien à usage unique, puis nouveau mot de passe confirmé. Réutiliser le style du login, ThemePicker et les champs masqués avec commande d’affichage. Une indisponibilité du service ne doit jamais annoncer un envoi réussi.

Le lien de récupération arrive dans le fragment ; conserver uid/token seulement en mémoire, nettoyer immédiatement l’URL et transmettre les vérifications par POST. Prendre en compte un nouveau lien reçu sur la page déjà ouverte sans mélanger les brouillons ni appliquer une ancienne réponse. Les mots de passe ne sont ni normalisés ni conservés dans le stockage du navigateur.

Dans Mon profil, la rubrique Sécurité utilise PasswordEditor et les protections communes de RecordEditorFrame. Le changement personnel exige le mot de passe actuel et reste indépendant des licences métier. Après réussite, fermer la session locale puis demander une reconnexion ; une réponse de restauration tardive ne doit pas rétablir l’ancienne session.

Administration → Messagerie utilise AdminMailSettings, réservé aux administrateurs de plateforme. Il modifie le nom et l’adresse expéditrice, jamais le secret Google. Le défaut demandé est SauverNdeko <benjaminmupanzi@gmail.com>. Pour le transport et les contrats serveur, lire [la référence backend de messagerie](../../../backend/skills/develop-sauverndeko-backend/references/messagerie-reinitialisation.md).

## Pile et responsabilités

Conserver React 19 en JSX, React Router, Vite, Bootstrap et Bootstrap Icons présents dans le projet. Les principes d’imf_BB sont à reproduire dans cette pile ; ne pas imposer sa migration TypeScript. Le backend est Django/DRF avec les JWT existants ; ne pas remplacer la session React par des cookies Django sans décision dédiée. Ajouter une dépendance seulement pour un besoin réel.

React présente les données autorisées et pilote les interactions. Les mesures métier, droits, recherches exhaustives, totaux et exports complets viennent du serveur. Le nouveau dashboard et les registres Articles/Bons de stock utilisent les lectures paginées et agrégats de apps/logistique/reads.py. Les autres registres historiques restent à contrôler avant de promettre une recherche exhaustive.

## Parcours attendus

Dans tous les modules où des créations similaires s’y prêtent, privilégier une saisie avec panier en reprenant le parcours de Bons de stock. Un seul bouton de création (« Nouveau… » / « Nouvelle… », par exemple « Nouvelle valeur ») ouvre ce panier pour une ou plusieurs lignes ; ne pas ajouter un second bouton « Saisie multiple ». Une seule ligne permet l’ajout individuel. Quand les lignes partagent un parent, utiliser un en-tête et ses détails : par exemple une catégorie et plusieurs valeurs génériques. Modification/suppression des lignes, annulation globale, collage Excel, erreurs par ligne et enregistrement atomique suivent le [contrat de saisie multiple](references/formulaires-crud.md#saisie-multiple-et-en-têtedétails). Conserver la saisie individuelle pour les opérations qui ne se prêtent pas à ce parcours. Exception demandée pour Articles (30 octobre 2026) : conserver « Nouvel article » et son formulaire complet, et proposer « Ajouter plusieurs articles » dans un panier séparé. Ce panier réutilise le même éditeur pour les détails de chaque brouillon, avec photo, lots et stock initial conservés. Tiers et Immobilisations gardent un seul bouton de création pour une ou plusieurs lignes.

- Le code/nom d’un objet et son bouton Consulter ouvrent la même fiche 360 depuis liste, recherche ou détail lié.
- Une valeur d’indicateur ayant un détail ouvre cette population exacte, ou son registre avec un filtre visible et effaçable. La carte et le lien de détail partagent le même contrat.
- ConsultationProvider fournit Produit 360 et Bon de stock 360, avec rubriques liées à la demande. Une facture ouvre directement la rubrique Facturation de Bon de stock 360 ; ReglementEditor fournit la consultation et le formulaire commun des paiements. La fiche Tiers 360 utilise le même principe de parent autorisé et de rubriques liées.
- Toute fenêtre latérale métier de ce type utilise DrawerDialog et propose les commandes communes Réduire, Élargir, Rétablir la largeur et Fermer, avec les mêmes icônes. Conserver poignée, clavier, adaptation mobile et retour au contexte, conformément à la référence. Cette règle couvre aussi les réglages, pas seulement les consultations 360.
- La consultation charge uniquement l’objet sélectionné, puis ses rubriques à la demande si volumineuses. Ne pas lancer une requête 360 pour chaque ligne du tableau.

## Invariants d’interface

1. Conserver filtres appliqués, page, sélection et position lors de l’ouverture/fermeture d’une fiche. Restituer le focus au déclencheur.
2. Distinguer saisie et filtres appliqués. Le compteur et l’export décrivent les critères effectivement envoyés au serveur.
3. Préserver recherche, tri, pagination, colonnes visibles/gelées/redimensionnables et sélection déjà disponibles ; mutualiser leur comportement avant d’ajouter des variantes.
4. Placer la taille de page et les commandes d’affichage au-dessus du tableau. Les totaux viennent dessous. Les actions principales et exports restent alignés aux filtres quand la largeur le permet.
5. Garder les groupes d’indicateurs analytiques repliés par défaut dans les registres ; un affichage ou repli ne change aucun filtre ni montant. Les cartes du tableau de bord principal restent selon le parcours de pilotage retenu. L’en-tête du tableau de bord ne présente ni Actualiser ni Nouveau bon de stock ; les créations se font dans les registres.
6. Valeur inconnue = — ou Non déterminable ; zéro seulement s’il vient de la source. Devise, unité, période et réserves indispensables restent visibles.
7. Les prix et montants logistiques portent la devise du référentiel reçue par l’API (ID_DeviseFk, DeviseCode). Le défaut USD des créations est résolu par defaultCurrencyId, sans identifiant numérique encodé. Utiliser formatCurrency avec le code de la ligne et conserver les chaînes décimales exactes ; aucune conversion de change implicite. Les totaux et détails monétaires se regroupent par devise ; une devise absente reste distincte de zéro. La reprise des anciens montants en USD résulte d’une migration explicitement autorisée, jamais d’un fallback d’affichage.
8. Menus et boutons suivent les permissions reçues ; le backend reste responsable du refus effectif. Traiter 401, 403, indisponibilité et conflit avec un état explicite.
9. Aucun bouton fictif ou sélecteur sans effet réel : raccorder l’action ou rendre son indisponibilité compréhensible. Les chiffres de démonstration restent identifiés et fictifs.
10. Les aides, cases de sélection et actions d’une ligne arrêtent la propagation quand elle ouvrirait une autre consultation. Utiliser de vrais liens/boutons avec focus visible.
11. Tout filtre métier catégoriel et toute référence à choix simple réutilisent SearchSelect, comme Licence et Article. Appliquer le [contrat des sélecteurs](references/formulaires-crud.md#sélecteurs-des-filtres-métier-et-références) ; conserver les contrôles adaptés aux réglages techniques et à la multisélection.
12. Afficher la date et l’heure des événements horodatés, sans ajouter d’heure aux dates seules ; appliquer le [contrat des dates et heures](references/contrats-interface.md#dates-et-heures).

## Navigation logistique livrée

Conserver la colonne de gauche sur toute la hauteur : logo, menus à icônes regroupés en Pilotage/Stocks/Finances, rubrique active visible, deux entrées Finances distinctes Factures et Règlements, retour aux applications, repli sur ordinateur et rail compact sur mobile. Le propriétaire demande le parcours Numérique–M-PESA : blocs Articles/Bons de stock/Factures/Alertes avec mini-indicateurs compacts (éviter les grandes tuiles), clic sur un KPI, détail dans une liste sous la synthèse, recherche validée, pagination serveur, puis Revenir à l’indicateur ou fermeture avec défilement/focus au déclencheur. Une fiche 360 consulte uniquement un enregistrement précis depuis ce détail ou un autre onglet.

Lire [la terminologie du stock](references/terminologie-stock.md) pour les noms de menus, documents, tiers et mouvements. Les noms techniques T_Commande et /commandes restent internes.

### Patrimoine et immobilisations

La rubrique Patrimoine vient après Finances et contient Immobilisations. Son registre reprend RegisterSurface, SimpleTable, le bouton unique Réglages en en-tête, les préférences de colonnes/export en base (`logistique.immobilisations`), les filtres SearchSelect et les exports serveur filtrés ou limités à la sélection. Un clic sur le code, le nom ou Consulter ouvre la même fiche Immobilisation 360 par identifiant stable. La fiche PDF utilise le moteur documentaire commun et l’identité actuelle de l’entreprise.

L’historique de la fiche montre les changements d’affectation en libellés précédents → nouveaux : responsable, service, localisation (bureau/salle compris) et état. Comparer les clés des images d’audit pour détecter le changement, puis utiliser exclusivement AffectationAvant/AffectationApres reçues du serveur pour la présentation. Une désaffectation du responsable devient « Sans affectataire » ; ne pas exposer d’identifiant ou de JSON technique. Ne pas répéter une affectation inchangée lors d’un archivage.

ImmobilisationEditor est partagé par ajout et modification, avec Identification, Affectation, Acquisition et Traçabilité ; recharger toutes les valeurs existantes, références et révision. Les types de matériel, états et services viennent des correspondances du référentiel, sans identifiant numérique encodé. Les responsables et localisations appartiennent à l’entreprise ; une affectation absente reste affichée sans valeur inventée. Ne pas confondre responsable d’un bien et rôle de sécurité.

Le défaut Bien individuel impose une quantité de 1 ; Lot homogène est un choix explicite pour des biens partageant caractéristiques, état et affectation. Un numéro de série impose aussi 1. Conserver les quantités entières de 18 chiffres et les prix en chaînes exactes, jamais en Number. Un prix inconnu reste vide/NULL et s’affiche — ; le défaut USD est fourni par l’API. Regrouper les valeurs par devise sans somme de devises différentes. L’état du matériel est facultatif, sans « Bon état » automatique. Ce registre ne génère aucun mouvement de stock ni amortissement. Archivage/réactivation conservent l’historique ; chaque écriture porte un motif, une révision fraîche et un UUID réutilisé après une réponse incertaine. Le code IMMO est attribué par PostgreSQL et reste non modifiable.

## Présentation

### Administration par entreprise

Administration utilise le contexte d’entreprise partagé, sans dépendre d’une licence Logistique. La sélection d’une entreprise recharge les registres, références et synthèses ; annuler les anciennes requêtes et retirer immédiatement les données du contexte précédent. Les droits de gestion viennent du module Administration et des capacités serveur, jamais de `scope.canWrite` propre à Logistique. Les licences restent consultables dans l’entreprise autorisée ; leur création, modification et désactivation sont réservées à la plateforme. Les rôles de sécurité communs restent gérés par la plateforme et ne sont pas dupliqués par entreprise. Un gestionnaire local ne peut ni créer un compte privilégié ni modifier les privilèges d’un autre compte.

Les boutons Nouvel utilisateur, Nouveau rôle, Nouvelle correspondance et Nouveau paramètre ouvrent un panier pour une ou plusieurs lignes : champs compacts, détails dans le formulaire existant en mode brouillon, collage Excel, suppression/annulation et validation par ligne. Ne jamais écrire une fiche depuis l’éditeur de brouillon ; le serveur enregistre le lot complet atomiquement. Une réponse incertaine conserve UUID et corps exacts pour vérification. Les mots de passe initiaux restent masqués et uniquement en mémoire ; aucune persistance navigateur, URL, journal ou export.

La fiche entreprise contient le sous-onglet Localisation, pour une ou plusieurs adresses et coordonnées. Réutiliser les références territoriales et conserver les identifiants/révisions des lieux existants. Profil, logo et localisations sont enregistrés dans la même demande ; un lieu déjà utilisé ne peut pas être retiré arbitrairement. L’ancienne URL Localisations redirige vers Entreprises, sans écran de gestion parallèle.

Les indicateurs et graphiques d’administration utilisent les agrégats serveur du contexte courant. Les destinations des indicateurs viennent de `metricTargets` ; clics des répartitions et des journées appliquent la population correspondante au registre. Conserver les valeurs nulles comme filtres SQL explicites pour Sans rôle et les états d’indisponibilité ; ne pas fabriquer zéro ou calculer un effectif exhaustif depuis une page de liste.

### Référencement des champs

Dans Référentiels → Référencement des champs, choisir la portée puis le champ physique ; Modifier et Rétablir conservent le même parcours de fiche. L’onglet porte les correspondances au grain schéma/table/colonne physique. Son registre reprend les sept colonnes Schéma, Table, Colonne, ID catégorie, Libellé catégorie, ID catégorie par défaut et Actions, avec les composants ERP communs et les préférences `referentiels.champs`. Il ne crée ni ne supprime librement des champs SQL. Modifier et Rétablir ouvrent le même formulaire, avec motif, révision opaque et UUID rejoué à l’identique si la réponse est incertaine. Un champ marqué `SupportsEntityScope=false` affiche sa portée Plateforme partagée et interdit Modifier/Rétablir dans le contexte Entreprise. La portée Plateforme ou Entreprise sélectionnée est explicite ; seul l’administrateur de plateforme peut modifier ce paramétrage, sous contrôle serveur.

Les formulaires chargent leurs choix par l’identité du champ ou par leur API métier résolue côté serveur. Ne pas figer de numéro de catégorie, réintroduire une surcharge métier locale ou élargir une liste vide à toutes les catégories. Les prédicats territoriaux existants restent stricts. Les devises des articles et celles des bons sont deux champs indépendants : une réception dont la devise d’article est exclue demande une devise autorisée et un prix explicite, sans conversion ni copie implicite. Les cartes Références affichent l’ID et le nom de la famille effective et renvoient au registre central. Afficher l’abréviation/code non vide après trim, puis le nom si elle est absente ; conserver les métadonnées métier des options, notamment `kind`, `stockEffect` et `canInvoice` pour les bons.

Une valeur enregistrée devenue inactive ou hors catégorie reste visible et conservée, avec une option désactivée et un avertissement discret. Aucune actualisation de références ne vide le champ ou le brouillon. Une modification d’autres informations conserve cette FK inchangée ; sa nouvelle sélection doit appartenir à la liste autorisée. Le signal partagé `T_ChampReferentiel` recharge les listes sans remonter les formulaires. Tout changement d’utilisateur ou d’entreprise invalide les anciennes réponses et les données du contexte précédent.

TailAdmin et shadcn/ui sont les deux références demandées par le propriétaire pour le login, Vos applications et les modules. Les utiliser pour améliorer une tâche réelle : repères, nombre d’étapes, recherche, clavier, erreurs et petits écrans, autant que la présentation. Comparer d’abord aux composants existants ; ne pas remplacer une interface pour reproduire une démo. Conserver React JSX/Vite/Bootstrap et vérifier dépendances et licences avant toute reprise de code. Conserver les principes d’interaction d’imf_BB : indicateurs vers liste intégrée, puis fiche 360 d’un enregistrement. Préserver la marque SauverNdeko, les mini-indicateurs compacts, le menu bleu ardoise et les styles partagés. Lire les références de design avant une évolution de présentation.

La charte commune couvre Connexion, Vos applications, Découvrir les applications, Licences et applications, Tableau de bord logistique, Articles, Dossiers de suivi, Bons de stock, Lignes des bons, Mouvements de stock, Factures et règlements et les consultations 360. Les futurs écrans reprennent leurs composants, tokens, états et interactions ; éviter une variante de présentation propre à chaque onglet.

Les sous-onglets de consultation utilisent [ConsultationTabs](../../src/components/ConsultationTabs.jsx), partagé entre profil et fiches métier : barre compacte, icônes communes, onglet actif visible et navigation au clavier. La modernité comprend le contenu lié à l’objet sélectionné, le chargement à la demande et la conservation du contexte, au-delà du seul style. Voir les [références et le contrat des onglets](references/design-reference.md#sous-onglets-de-consultation).

Le propriétaire demande de retirer Sources et calcul du tableau de bord et de ses listes détaillées. Conserver les définitions et la traçabilité côté serveur et dans les exports, sans afficher les noms SQL dans le parcours métier. AppIcon et ActionButton centralisent les icônes et boutons : Réinitialiser utilise reset, tous les téléchargements utilisent download. Un bouton de format apparaît uniquement si son export est réellement raccordé.

## Vérification

Le package frontend déclare build, dev et preview, sans script test. Pour une modification réelle, npm run build vérifie le bundling ; compléter par les interactions utiles à la tâche sur données fictives. Vérifier ordinateur, largeur intermédiaire et mobile, clavier, zoom réel, retour au focus, annulation, erreur et parité des filtres/détails/exports. Une compilation seule ne valide pas les droits, la précision d’un KPI ou l’ergonomie d’une fenêtre.

## Ton des interfaces

Le propriétaire a validé l’accueil par applications, inspiré d’Odoo. Préserver cette présentation et employer des libellés courts, humains et professionnels. Retirer les textes qui ressemblent à des consignes de conception, les mentions de backend/JWT et les explications techniques inutiles. Les descriptions utiles restent brèves ; les explications de calcul sont repliées.

## Thèmes

ThemeContext fournit Clair, Sombre, Contraste élevé et Système. ThemePicker est présent à la connexion, sur l’accueil et dans ModuleHeader. La préférence sauverndeko.theme est locale au navigateur ; aucun appel métier ni écriture PostgreSQL n’est associé à un changement de thème. Le thème Système suit prefers-color-scheme. Conserver le menu bleu ardoise contrasté dans la présentation claire par défaut. Centraliser les couleurs dans theme.css et vérifier tableaux, formulaires et fiches 360 dans les modes proposés.

ThemePicker affiche uniquement l’icône du choix : soleil pour Clair, lune pour Sombre, demi-cercle pour Contraste élevé et écran pour Système. Le bouton rond (40 px, 34 px sur mobile) ouvre un menu personnalisé compact utilisant les tokens de thème. Chaque choix porte son icône et un libellé ; le choix actif est coché et exposé comme sélection radio. Conserver le titre actualisé, le focus visible, les flèches haut/bas, Début/Fin et Échap. Un choix ou Échap restitue le focus au bouton ; le clic extérieur ferme le menu. Adapter son positionnement au mobile ; aucun texte ni flèche ne reste affiché sur le bouton.

## Outils et relevés historiques

Pour `/territoires`, suivre [le contrat Organisation territoriale](references/organisation-territoriale.md) : portail dédié, indicateurs liés aux mêmes registres, références physiques centralisées, fiches complètes et conservation des valeurs historiques. Le découpage reste partagé ; ne pas lui appliquer le blocage d’écriture propre à l’entreprise logistique. Les créations des niveaux 0 à 5 utilisent un seul bouton ouvrant une saisie multiple, avec rattachement commun en en-tête, lignes modifiables, collage Excel et transaction de lot. La consultation et la modification conservent la même fiche individuelle et sa vraie clé.

Les anciennes références [frontend-architecture.md](references/frontend-architecture.md), [api-and-ui-contracts.md](references/api-and-ui-contracts.md) et [validation.md](references/validation.md) conservent le relevé antérieur à la conversion Django. Les références précédentes décrivent les conventions actuelles. L’[inspecteur statique](scripts/inspect_frontend.py) peut aider à repérer composants et services ; son inventaire partiel des routes ne valide ni les ModuleGate conditionnels ni les permissions.

## Documents métier et avoirs

Réutiliser BusinessDocuments pour PDF et justificatifs privés ; conserver les états de chargement, reprise du téléchargement échoué et protection des réponses obsolètes après changement d’entreprise. Utiliser le formulaire CreditNotes partagé pour émission, imputation et remboursement ; la consultation reste en lecture avec un bouton Fermer. Une réponse incertaine conserve le même identifiant et le même contenu pour vérification. Afficher les montants exacts fournis par le serveur et distinguer encaissements, avoirs imputés, remboursements et solde disponible. Aucun transfert bancaire n’est exécuté par l’enregistrement d’un remboursement.

## Paramétrage documentaire et livraison

Le module socle `/parametres` présente les paramètres de l’entreprise autorisée, indépendamment de la licence Logistique. Réutiliser le profil et `EntityProfileEditor` communs, avec la rubrique Fiscalité. Le champ `TauxTVAEntite` reste une chaîne décimale exacte de 0 à 100, avec quatre décimales au maximum et une virgule de saisie acceptée. Son défaut 0 vient du serveur. Les droits et l’entreprise proviennent de l’API ; Toutes les entreprises demande une sélection avant modification. La création, le type et l’état d’entreprise restent dans Administration.

Les factures présentent les prix HT et les composantes HT, TVA et TTC reçues de PostgreSQL. `InvoiceTaxSummary` partage cette présentation entre préparation, consultation et avoir. Une facture émise utilise son instantané et sa devise ; ne pas lui appliquer le taux courant, même si le contexte de préparation contient d’autres valeurs. Le changement du taux pendant une préparation exige un rechargement, avec saisie conservée. Lire [le guide Paramètres](../../../docs/parametres-entreprise-tva.md).

Administration → Entreprises et EntityDocumentIdentity réutilisent EntityProfileEditor : mêmes rubriques Coordonnées, Identifiants légaux et Documents, mêmes validations et protection des modifications non enregistrées. Les types d’entreprise viennent des références de l’API, sans catégorie numérique figée. Seule l’administration de plateforme peut créer une entreprise ou modifier son type et son état ; l’identité documentaire respecte les droits de l’entreprise choisie. Réutiliser la révision figée et le même UUID/contenu lors d’une réponse incertaine ; rafraîchir le sélecteur d’entreprise après sauvegarde, sans recharger la page.

Dans ce formulaire, une modification autorisée active Enregistrer. Un champ obligatoire manquant, dont le motif conservé dans l’historique, produit un message explicite et reçoit le focus à la soumission ; ne pas laisser le bouton silencieusement désactivé pour cette raison. Le motif ne change pas le sous-onglet courant. Conserver les blocages de permissions, de chargement et de double soumission, ainsi que le rejeu identique d’une demande incertaine.

Les coordonnées proposent un téléphone principal et un téléphone secondaire facultatif (`PhoneSecondaireEntite`, 20 caractères maximum), sans numéro inventé. Ils suivent le même formulaire partagé et sont présentés depuis le profil reçu du serveur.

Le logo est une image privée téléversée (PNG, JPEG ou WebP, 2 Mo maximum), avec aperçu authentifié, remplacement et retrait explicites. Le profil complet et le logo sont sauvegardés atomiquement ; aucun contenu binaire ni secret n’est placé dans le JSON, une URL distante ou le stockage du navigateur. Les identifiants légaux sont des couples libelle/valeur facultatifs, indépendants du pays : proposer RCCM, ID national et N° d’impôt comme libellés assistés, jamais comme valeurs inventées.

Afficher l’en-tête et Afficher le pied de page sont deux options indépendantes, vraies par défaut ; conserver explicitement une valeur false reçue. L’identité actuelle de l’entreprise est reprise lors de chaque impression et réimpression, tandis que les données financières historiques restent protégées côté serveur. Ne pas préremplir de coordonnées, références légales ou mentions fictives.

AdminMailSettings distingue configuration présente et connexion prouvée. Tester la connexion appelle un POST réservé à l’administration de plateforme, sans destinataire ni e-mail envoyé. Les valeurs par défaut viennent du compte d’envoi configuré, pas du compte utilisateur connecté. Une réussite du test ne prouve pas la réception d’un message.
