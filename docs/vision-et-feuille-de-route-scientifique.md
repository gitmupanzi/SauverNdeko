# Vision de SauverNdeko et feuille de route scientifique

Référence produit du 3 novembre 2026. Elle reprend le résumé de thèse communiqué par le propriétaire et un examen du code, des migrations et de la base SauverNdeko. Le manuscrit complet, le protocole de recherche et les résultats scientifiques n’ont pas été fournis. Les cartographies du 24 octobre restent des relevés historiques ; ce document actualise le positionnement et les priorités, sans effacer leurs preuves datées.

## Finalité du projet

SauverNdeko poursuit une finalité scientifique et commerciale : rapprocher les usagers des produits, professionnels et structures, tout en offrant aux entreprises des outils de gestion fiables. La santé constitue le premier domaine visé ; le modèle reste transversal pour l’immobilier, la construction et d’autres secteurs.

La contribution à la réduction de la mortalité en RDC est un objectif à évaluer. Aucun effet sur la mortalité, diagnostic, couverture nationale ou gain prédictif n’est démontré par la présence du logiciel. Une fonction annoncée comme disponible doit correspondre à un parcours effectivement raccordé et vérifié.

PostgreSQL conserve les identités, relations, règles métier, paramètres, vues et événements durables. React présente les données autorisées et Django contrôle les accès et transactions. Les valeurs catégorielles restent dans `referentiel`, avec le référencement physique des champs. L’ajout d’une table ou d’une colonne doit répondre à un besoin que l’existant ne couvre pas.

## Résumé de la thèse

**Titre communiqué :** « Conception d’un modèle prédictif pour l’anticipation des besoins logistiques en produits de santé et la détection indirecte des tendances sanitaires : cas de la plateforme SauverNdeko ».

**Problématique :** comment exploiter les demandes, achats, localisations et catégories de produits pour anticiper les besoins logistiques et orienter les décisions sanitaires ?

**Hypothèse à tester :** ces données pourraient aider à anticiper la demande, réduire le risque de rupture et repérer des évolutions sanitaires indirectes par zone, période et famille de produits.

**Objectif général :** concevoir, implémenter et évaluer un modèle intégré de prévision de la demande et des indicateurs d’aide à la décision logistique et sanitaire.

**Objectifs spécifiques :** structurer les données ; relier les produits à des familles sanitaires pertinentes et validées ; prévoir des quantités par produit, zone et période ; repérer des hausses inhabituelles ; présenter des indicateurs ; évaluer les modèles et les performances techniques.

Les métriques correspondent aux tâches : **MAE et RMSE** pour les quantités prédites ; **précision, rappel et F1-score** pour une classification ou des alertes disposant d’une vérité de référence ; latences mesurées pour l’API. Une bonne latence ou un bon score de prévision ne démontre pas un bénéfice sanitaire.

À compléter avec le directeur de thèse : population et terrains étudiés, questions et critères d’évaluation, définition exacte des cibles, unité temporelle, horizons, sources et autorisations, vérité de référence, taille et durée d’observation, protocole de validation et règles de diffusion des résultats.

## État observé avant cette évolution

Le socle actif est Django/DRF, React/Vite et PostgreSQL par schémas. L’audit en transaction **READ ONLY** du 3 novembre a constaté trois articles actifs, deux entreprises, aucune localisation d’entreprise, un profil professionnel publié, une discussion, vingt-deux bons, vingt-six lignes et aucun événement de recherche. Ce relevé local ne représente ni l’adoption du service ni l’offre nationale. Les entreprises observées ne démontrent pas la présence de pharmacies identifiées comme telles.

| Domaine | Existant constaté | Écart vers la vision |
|---|---|---|
| Logistique | Propriétaire durable par entreprise ; BE/BS/CMD, stock, lots, inventaires, facturation, règlements, patrimoine ; vues et gardes SQL | Séparer explicitement le stock interne de l’offre consultable ; consolider les preuves de fraîcheur et le raccordement produit/structure |
| Professionnels | Annuaire publié, brouillons privés, secteurs et compétences du référentiel, affiliations, photo, contact par discussion | Mettre en place un circuit de vérification documentaire des qualifications ; ne pas afficher de certification actuellement |
| Structures et pharmacies | Entités, identité documentaire, contacts et table de localisations liée aux territoires ; ancien écran `/pharmacies` | Identifier le type métier réel ; l’ancienne API liste des entités actives de plusieurs types, sans prouver qu’il s’agit de pharmacies |
| Produits | Articles de stock local, prix, devise, unités, photos ; ancien écran de recherche | Produit normalisé commun, familles sanitaires validées, offres par entreprise, recherche/pagination exhaustives, parcours de demande et d’achat à construire |
| Territoires | Hiérarchie partagée et vues pays/provinces/subdivisions/zones/aires/sites ; analyses et contrôles | Rapprochement documenté avec les sources administratives et sanitaires officielles ; coordonnées et rattachements réels à compléter |
| Discussions | Conversations privées avec un professionnel ou une structure, sous contrôle des participants | Aucun parcours structuré demande patient → article → satisfaction/achat ; un message n’est pas une commande ni une observation clinique |
| Analytics | `T_Recherche` et `V_Recherche`, consultation administrative restreinte | Aucun enregistrement automatique trouvé, aucune série produit-zone-période, aucun pipeline prédictif ni modèle évalué |
| Catalogue | Ancienne page connectée consommant des listes et statistiques | Première vitrine de présentation séparée des données métier ; absence de compteurs ou témoignages inventés |

Une sortie BS peut être interne ou corriger un inventaire : elle ne devient pas automatiquement une vente à un usager. Un CMD ne modifie pas le stock et ne prouve pas une demande sanitaire. L’OMS distingue elle-même les données de ventes, dispensation et rencontres patients dans ses [sources de données d’utilisation des médicaments](https://www.who.int/tools/atc-ddd-toolkit/data). Cette distinction doit rester dans les jeux de recherche.

### Relations à conserver

| Relation | Règle actuelle ou besoin à traiter |
|---|---|
| `T_Article.IdEntiteFk → T_Entite` | Propriété durable de l’article et contexte des droits ; ne pas déduire le propriétaire du compte créateur actuel |
| Article → catégories, type, unités et devise | Identifiants de `T_Generique`, familles résolues par le référencement des champs ; pas de dictionnaires locaux dans les écrans |
| Bon → lignes → article → mouvements | Quantités et effets contrôlés par PostgreSQL ; ne pas appliquer un deuxième mouvement lors d’une publication ou d’une analyse |
| `T_Entite_Localisation` → niveaux territoriaux | Relation déjà disponible ; renseigner de vrais lieux avant de proposer un classement par proximité |
| Professionnel → utilisateur, entreprise et affiliations | Identité et gestion séparées de la projection publiée et des droits de discussion |
| Recherche → article/structure/spécialité | Socle d’événement existant, sans suivi automatique ; le résultat d’une recherche ne désigne pas le domicile du demandeur ni un achat |
| Article local → produit commun | Relation à concevoir : aucune deuxième table `T_Produit` n’est actuellement nécessaire au fonctionnement du stock, mais le rapprochement entre entreprises n’est pas normalisé |

## Publication et première vitrine

Le propriétaire a retenu un défaut de partage **paramétrable par entreprise**, avec un choix individuel pour chaque article. Le paramètre d’entreprise préremplit les nouvelles créations ; il ne réécrit pas les articles existants. Les articles antérieurs à cette évolution sont conservés sans publication automatique, afin de laisser examiner leurs informations. Un gestionnaire peut ensuite choisir leur visibilité dans le formulaire commun d’ajout/modification.

Une offre publiée doit provenir de son article actif et de son entreprise active, au moyen d’une projection limitée. Prix de vente et devise restent associés ; prix d’achat, auteur, notes internes, informations de gestion, justificatifs et données RH restent privés. La photo doit appliquer la même règle de visibilité que l’offre. La publication n’est ni une certification pharmaceutique ni une garantie de disponibilité lors du déplacement de l’usager.

Les règles de partage et les effets de stock sont indépendants. Changer le défaut de l’entreprise ne retire ni ne publie ses anciennes offres. Changer la visibilité d’un article ne crée aucun bon, mouvement ou règlement.

La première version de `/catalogue` était une **vitrine sans lecture de données métier** : présentation de SauverNdeko, accès aux parcours existants et distinction des développements encore en cours. Depuis le 7 novembre 2026, la synthèse décrite ci-dessous ajoute trois totaux de publication. Elle ne reprend pas les anciennes statistiques dérivées telles que « Réponse rapide » ou un nombre d’annonces déduit du nombre d’articles.

La racine `/` conserve l’entrée ERP par connexion. Les recherches métier, profils, discussions et API historiques `/api/public/*` restent soumis à la session et aux licences. Le terme « public » désigne ici la projection partageable de l’annuaire ; cette évolution n’ouvre pas l’ensemble de ces API aux visiteurs anonymes. L’accès anonyme à de vraies offres nécessitera une décision et un contrat dédiés.

### Annuaire Produits du 3 novembre 2026

Le parcours `/produits` présente une seule population d’offres publiées, en cartes ou en tableau. La recherche serveur porte sur les désignations, références, entreprises, adresses, catégories et types ; filtres, compteur et page partagent la même population. Les catégories, types et devises sont les valeurs centrales déjà enregistrées, sans réaffectation des articles lors d’un changement de configuration. Les filtres ne proposent pas de valeurs privées sans offre publiée.

La fiche Offre de produit affiche uniquement les informations partageables : photo autorisée, désignation, référence, catégorie, type, prix de vente, devise, unité, disponibilité déclarée et coordonnées professionnelles. Les lieux proviennent des localisations d’entreprise existantes, en libellés et adresses ; une absence reste explicite. Aucun GPS d’utilisateur, classement par distance ou stock sur un site particulier n’est déduit. Le Produit 360 privé de Logistique reste séparé.

Le contact rejoint le parcours Discussions existant avec l’entreprise destinataire, lorsque les droits le permettent. La lecture d’une offre ne crée ni message, ni commande, ni réservation, ni événement scientifique. Un clic explicite sur Contacter ouvre la conversation ; l’envoi du texte reste une action du demandeur. Deux articles locaux de même nom ne sont pas automatiquement regroupés comme un produit commun. Les tris portent sur le nom ou l’entreprise, sans comparaison monétaire implicite entre devises ou unités.

Ce parcours améliore la mise en relation prévue par la thèse. Il ne remplace pas les étapes de normalisation produit, demande structurée, qualification des établissements, collecte autorisée et évaluation prédictive ci-dessous.

## Données fiables avant prévision

La série scientifique devra distinguer **recherche, demande explicite, commande, sortie, vente, retour et dispensation**. Une recherche de produit peut concerner un proche, une disponibilité ou une information : son texte ne constitue pas un diagnostic. Une discussion peut contenir des informations sensibles et ne doit pas alimenter automatiquement l’analytics.

Avant d’activer une collecte nouvelle, préciser la finalité, les personnes concernées, les autorisations, l’information des usagers, les accès, la durée de conservation, les règles de suppression et la minimisation. Préférer une zone utile à l’étude à des coordonnées individuelles précises. Séparer les identités opérationnelles des données de recherche ; pseudonymisation et agrégation ne suffisent pas à garantir à elles seules l’anonymat. Les recommandations de l’[OMS sur l’éthique et la gouvernance de l’IA en santé, 28 juin 2021](https://www.who.int/publications/i/item/9789240029200), fournissent un cadre de conception, pas une attestation juridique de conformité.

Pour chaque mesure, conserver nature et provenance du signal, produit identifié, unité standard, entreprise/site contributeur, territoire applicable, période, dates d’événement et de réception, corrections/retours, couverture de collecte et qualité connue. Un stock nul, une demande nulle et une donnée absente restent trois situations distinctes. Les ventes observées pendant une rupture sous-estiment potentiellement la demande ; cette censure doit être documentée.

Les agrégats scientifiques seront servis par des vues ou fonctions contrôlées avec un grain explicite, sans addition de quantités d’unités différentes. Les sources opérationnelles et leurs corrections restent conservées ; une extraction de recherche doit être versionnée et reproductible. Aucun événement, diagnostic ou historique synthétique ne doit être introduit dans la base cliente pour simuler la maturité scientifique.

## Territoires : correspondances à vérifier

Le standard [ONU M49](https://unstats.un.org/unsd/methodology/m49/) porte sur les pays ou aires et leurs regroupements statistiques. Il ne définit pas une hiérarchie nationale universelle à six niveaux. Les [COD-AB d’OCHA, page mise à jour le 23 octobre 2024](https://knowledge.base.unocha.org/wiki/spaces/imtoolbox/pages/2557378679/), suivent la hiérarchie administrative propre au pays et ses P-codes.

**Choix de conception proposé à partir de ces sources :** conserver les identifiants territoriaux existants et préparer une correspondance versionnée entre découpage administratif et pyramide sanitaire, avec source, code, dates de validité et statut de validation. Ne pas transformer automatiquement une province/DPS, une antenne ou une zone en niveau ADM universel. Une [couche OCHA de zones de santé RDC](https://gis.unocha.org/server/rest/services/Hosted/ROWCA_DRC_Health_zone/FeatureServer/0) existe ; sa date de référence et sa correspondance avec la base locale restent à vérifier avant import.

Le contenu du jeu HDX COD-AB RDC n’a pas été validé lors de cette intervention, son accès ayant présenté un contrôle JavaScript. Aucun jeu de limites ou géométrie n’est importé. La recherche « proche de moi » doit attendre des coordonnées fiables, un consentement adapté au parcours et une définition explicite de la distance ; un nom de zone seul ne permet pas ce calcul.

## Feuille de route progressive

| Étape | Livrable | Critère pour poursuivre |
|---|---|---|
| 1 — Fiabilité et partage | Défaut d’entreprise et visibilité article ; projection d’offre limitée ; prix/devise cohérents ; vitrine séparée | Tests de permissions, héritage et dérogation, absence d’effet sur stock, photo protégée, données antérieures préservées |
| 2 — Relier les parcours engagés | Types réels des structures, localisations, offres rattachées au bon établissement, recherche et pagination serveur ; produit normalisé à cadrer | L’usager voit l’offre, son entreprise et sa devise exactes ; aucun faux classement pharmacie/proximité ; une recherche couvre les données autorisées |
| 3 — Demandes et qualité des annuaires | Demande structurée vers une offre/structure, état satisfaite/non satisfaite ; vérification des qualifications selon un circuit défini | Droits et historique de chaque transition, preuve de traitement, qualifications déclarées distinguées des vérifiées ; demande distincte d’une facture |
| 4 — Gouvernance et collecte de recherche | Protocole validé, données minimales, dictionnaire des événements et familles sanitaires validées ; processus d’extraction restreint | Base légale et autorisations examinées, conservation/accessibilité décidées, mesures de complétude et de fraîcheur, aucune collecte cachée |
| 5 — Jeu d’évaluation | Séries produit-zone-période, provenance et version ; gestion des retours, unités, ruptures et absences | Durée/volume suffisants selon le protocole, qualité documentée, périodes de test distinctes, résultats reproductibles |
| 6 — Prévisions et signaux | Référence simple puis modèles candidats ; prévisions et hausses inhabituelles accompagnées de leurs limites | Comparaison sur périodes futures tenues à l’écart, métriques par groupe, incertitude et erreurs examinées ; aucune alerte sanitaire automatique sans validation |
| 7 — Tableau de bord et étude d’impact | Synthèses agrégées, détail autorisé, historique de modèles et décisions | Évaluation prospective de l’utilité logistique, de la charge d’alertes et de l’équité territoriale ; étude spécifique avant toute conclusion sur la mortalité |

L’étape 1 ne suffit pas à déclarer l’ensemble du catalogue pharmaceutique ou le volet prédictif terminé. Les étapes suivantes constituent une progression, pas un engagement de calendrier ni une fonctionnalité livrée.

### Évaluation scientifique envisagée

Commencer par des références simples : dernière valeur, moyenne adaptée ou naïf saisonnier lorsque les données le permettent. Comparer les candidats au moyen de découpages chronologiques et de fenêtres glissantes, en empêchant toute information future dans l’apprentissage. Réserver une période finale et examiner les performances par produit, entreprise et territoire, en documentant les volumes faibles et les séries nouvelles.

Rapporter MAE/RMSE dans l’unité de la cible, par horizon et groupe utile. Ne pas additionner des kilogrammes, comprimés et litres pour fabriquer un score métier unique. Pour les alertes, établir d’abord des labels ou une validation de référence ; rapporter précision/rappel/F1, volume d’alertes et délai de détection. Sans vérité de référence, parler de signaux exploratoires à examiner. Le cadre de [renseignement de santé publique de l’OMS, 27 novembre 2025](https://www.who.int/publications/i/item/9789240115408), distingue détection, vérification, analyse et évaluation.

Évaluer séparément les performances techniques : jeux et volumes fixés, latences médianes et percentiles, erreurs, filtres, pagination et concurrence. Les recommandations de qualité du [Toolkit RHIS de l’OMS](https://www.who.int/data/data-collection-tools/health-service-data/toolkit-for-routine-health-information-system-data/modules) rappellent de vérifier complétude, cohérence, fraîcheur et représentativité. Une série issue des seuls contributeurs de SauverNdeko ne mesure pas automatiquement les besoins de toute la RDC.

## Décisions encore nécessaires

- Définir l’identité du produit commun et les familles sanitaires avec les experts compétents, leurs sources, unités et règles de version ; ne pas déduire une maladie du seul nom commercial.
- Fixer les conditions de référencement et de vérification des pharmacies et professionnels, avec preuves, responsables et renouvellement.
- Décider l’éventuel accès anonyme aux offres, les informations de stock publiables et les engagements de fraîcheur ; la première vitrine ne l’active pas.
- Valider le rapprochement des découpages territoriaux à partir de sources datées avant toute migration des rattachements.
- Compléter le manuscrit/protocole de thèse, la gouvernance de la collecte et l’accès aux données de référence nécessaires à l’évaluation.

Les choix structurants de cette liste doivent être validés avant modification des identités, ouverture de données sensibles ou instrumentation. Les développements indépendants peuvent progresser sans les anticiper.

## Livraison et vérifications du 3 novembre 2026

La première disposition de la vitrine `/catalogue` utilisait toute la largeur disponible. À la demande du propriétaire du 7 novembre 2026, le contenu est désormais centré et limité à 1440 pixels afin d’éviter l’étirement sur grand écran, avec des gouttières de 16 pixels sur mobile et de 24 à 32 pixels sur ordinateur. L’en-tête reste fixe, les illustrations sont conservées dans des cartes compactes et les sections Vision et questions pratiques partagent une ligne sur grand écran. Le bloc de connexion répété en bas est retiré. Sur les petits écrans, les blocs s’empilent et les cartes adaptent leur illustration, sans réduction artificielle de la page. Les thèmes, icônes, accès et totaux réels sont conservés.

Le défaut de partage est disponible dans la fiche Entreprise commune à Administration et Paramètres. Le formulaire Article et le panier proposent un choix individuel, conservé lors d’une modification et lors du chargement tardif des références. La projection SQL et les règles sont détaillées dans [Publication volontaire des articles](../SQL/documentation/Publication_Articles_20261103.md). La migration est appliquée à SauverNdeko avec sauvegarde/restauration vérifiées : toutes les colonnes antérieures des 77 tables sont préservées, les trois articles historiques restent masqués et les effets de stock sont inchangés.

Vérifications effectivement exécutées :

- 12 tests PostgreSQL de publication et de rejeu ; 10 tests API de publication, licences, permissions, confidentialité, photos et panier ; 13 tests de non-régression de fiche entreprise/logo, sur des bases privées.
- 20 tests API du guide utilisateur, dont cohérence des nouvelles instructions et contrôle des accès ; les essais n’écrivent aucune donnée fictive dans SauverNdeko.
- Tests frontend de parcours, partage, formulaires et paniers ; contrôles de cascade et contraste des thèmes ; 149 contrôles des règles adaptatives aux largeurs 320, 375, 768, 1440 et 1920 pixels ; build Vite réussi.
- Trois skills validés ; contrôle Django et compilation Python sans problème ; deux fichiers SQL globaux restaurés avec définitions et commentaires concordants, sans données clientes.

Après redémarrage autonome du serveur, 14 contrôles HTTP réels ont confirmé la santé du service, le refus des lectures métier anonymes, l’absence de publication historique, le défaut des deux entreprises, les fiches Paramètres, la protection de photo et la livraison de la feuille CSS pleine largeur par Vite. Ces lectures n’ont changé aucune empreinte de table source. Elles ne sont pas une simulation d’écran ni une validation interactive des boutons.

Les contrôles de règles CSS et les tests de rendu serveur ne remplacent pas une recette interactive sur de vrais navigateurs et téléphones. Cette recette n’a pas été exécutée : l’accès navigateur était précédemment refusé. Les fonctionnalités prédictives, la normalisation commune des produits, la qualification des pharmacies et la collecte scientifique restent les développements de la feuille de route, pas des fonctions livrées par cette intervention.

## Synthèse de l’accueil — 7 novembre 2026

À la demande du propriétaire, trois cartes cliquables présentent les totaux globaux des **offres de produits partagées**, des **profils professionnels publiés** et des **structures et territoires référencés**. Leurs sources sont respectivement `logistique.V_OffreArticle`, `professionnel.V_Professionnel_Public` et `geolocalisation.V_StructureSanitairePublique`. Une offre correspond à une publication par entreprise ; les profils ne sont pas dédupliqués en personnes uniques. Les structures comprennent les niveaux territoriaux 3 à 5 et tous leurs types actifs, sans prétendre représenter uniquement les hôpitaux et pharmacies ni l’ensemble du pays.

Une seule lecture PostgreSQL produit les trois effectifs sur le même instantané. `/api/public/catalogue/synthese` ne retourne que ces entiers et leur date de calcul, avec un cache interne maximal de 60 secondes et sans filtre. Aucune fiche, coordonnée, identité de compte, quantité de stock, coût ou indicateur privé n’est ouvert aux visiteurs. Les annuaires et leurs API historiques restent authentifiés et contrôlés selon les droits existants ; les liens de l’accueil passent par la connexion au besoin. Les informations d’une fiche restent à confirmer auprès de l’organisation, sans garantie de disponibilité ni de qualification.

La page conserve ses illustrations, ses thèmes et l’en-tête fixe. Les cartes s’empilent sur téléphone et précèdent le parcours explicatif. Le chargement conserve la place des totaux ; zéro reste distinct de l’absence, et une erreur propose Réessayer sans bloquer les annuaires. Aucun suivi de visite ni collecte scientifique n’est ajouté. Aucune table, migration ou donnée existante n’a été modifiée pour cette synthèse.

La rubrique « Notre vision » présente l’ambition d’accès aux produits, compétences et services en RDC, à partir de la santé et avec une ouverture à d’autres secteurs. Elle ne décrit pas une prédiction déjà opérationnelle ni un effet sanitaire prouvé.

Vérifications exécutées sur la disposition compacte : 11 tests backend isolés de la synthèse, 47 contrôles du cycle React (chargement, zéro, erreur/reprise, délai, abandon et liens), 122 contrôles de rendu de l’accueil et de ses gardes, 748 contrôles de contraste dans trois thèmes et 326 contrôles CSS adaptatifs de 320 à 1920 pixels. Le build Vite et le contrôle Django réussissent. Après redémarrage local, la page et la synthèse répondent en HTTP 200, y compris via le proxy du frontend ; les filtres de la synthèse sont refusés en 400 et quatre anciennes API d’annuaire restent refusées en 401 sans connexion. Ces requêtes sont des lectures. Aucune recette visuelle au navigateur n’est revendiquée : une nouvelle tentative le 7 novembre reste refusée par une permission enregistrée pour localhost ; les tests CSS et React ne la remplacent pas.

La page `/login` est également resserrée dans une carte commune de 1080 pixels au maximum, avec son formulaire et le panneau de présentation. À 900 pixels et en dessous, le formulaire occupe seul l’espace disponible, dans 480 pixels au plus. Le retour à l’accueil et le thème restent accessibles ; les champs de 50 pixels et le bouton de visibilité du mot de passe de 44 pixels sont conservés. Les validations, messages d’erreur, redirections et règles d’authentification ne changent pas. Les contrôles de navigation, rendu serveur et contraste couvrent aussi la récupération du mot de passe, qui partage la feuille CSS sans prendre ce nouveau cadre.
