---
name: sauverndeko-erp
description: Cartographier et faire évoluer SauverNdeko vers un ERP modulaire, en coordonnant domaines métier, vues PostgreSQL, API et parcours React. Utiliser pour les évolutions transversales, la reprise de principes d’imf_BB et la préparation d’une livraison client.
---

# Faire évoluer SauverNdeko

## Vision scientifique et commerciale

Lire la [vision et la feuille de route scientifique](../../docs/vision-et-feuille-de-route-scientifique.md) pour le catalogue, les relations entre produits/structures/professionnels/territoires et toute préparation d’analytics. Le résumé de thèse fourni par le propriétaire y fait référence ; le manuscrit complet reste à compléter. La réduction de mortalité est une contribution visée à évaluer. Recherches, demandes, commandes, sorties, ventes et dispensation constituent des signaux distincts ; aucun ne devient automatiquement un diagnostic ou une mesure des maladies.

Conserver le socle PostgreSQL et les référentiels partagés. Distinguer code présent, installation contrôlée et résultats scientifiques démontrés. Avant collecte de texte, localisation individuelle ou données de santé, définir finalité, minimisation, conservation et accès. Ne pas réaffecter les territoires pour les faire correspondre à une prétendue hiérarchie universelle ONU ; utiliser des rapprochements versionnés et validés. Préparer les prévisions après la qualité des données et les connexions entre modules, avec évaluation chronologique et métriques adaptées à chaque cible.

## Références à choisir selon la tâche

Pour les [demandes suivies](../../docs/demandes-suivies.md), conserver une identité de source et un destinataire explicite, les étapes de traitement et leur historique. Une demande ne réserve pas de stock et n’émet aucun document financier. Le résultat déclaré par les participants reste distinct d’une preuve de livraison, d’un diagnostic et d’une mesure scientifique. Les structures territoriales partagées ne deviennent pas entreprises : leur destinataire nécessite une association explicite et contrôlée.

Le partage d’articles utilise un défaut d’entreprise pour les nouvelles créations et un choix propre à chaque article. Les réglages de publication par défaut s’appliquent aux nouvelles fiches. Les registres proposent la publication ou le retrait de la sélection explicite et conservent les décisions existantes. La publication d’un article ne modifie jamais le stock. La projection d’offre et sa photo excluent les informations de gestion privées. Ce contrat reste distinct d’une ouverture des annuaires aux visiteurs anonymes.

- Pour repérer un domaine et son état réel : [cartographie](references/cartographie.md), puis [inventaire technique](references/inventaire-technique.md).
- Pour prioriser une version client ou un module ERP : [trajectoire ERP](references/trajectoire-erp.md).
- Pour les droits par entreprise, le compte global, les clients/fournisseurs et le suivi facultatif par lot : [décisions Entités, tiers et stock](references/entites-tiers-et-stock.md). Cette cible reste distincte du comportement installé.
- Pour les équipements de l’entreprise et les informations professionnelles minimales : [Patrimoine et affectations](references/patrimoine-affectations.md).
- Pour les paramètres propres à l’entreprise et la TVA : [guide Paramètres](../../docs/parametres-entreprise-tva.md) et [contrat PostgreSQL](../../SQL/documentation/Parametres_TVA_20261102.md). Le taux courant appartient à l’entreprise ; chaque facture conserve son taux et ses montants à l’émission.
- Pour la trésorerie : [module Caisse](../../docs/module-caisse.md). Une caisse appartient à une entreprise et une devise ; ses soldes proviennent du journal PostgreSQL. Les écritures validées se corrigent par compensation, les clôtures restent tracées et un règlement Logistique ne crée une entrée de caisse que par son parcours transactionnel explicite.
- Pour l’accueil, le catalogue et les licences : [modules et fonctionnalités](../../docs/modules-et-fonctionnalites.md). Lire la classification commerciale dans `systeme.T_ModuleApplication`, afficher deux groupes et deux compteurs, sans confondre commercialisation et habilitation. Conserver les licences et inclusions existantes.

L’accueil public est `/catalogue`, également destination de `/` et du lanceur local. Catalogue n’est pas un module à acheter ni une tuile de l’espace privé `/espace`. Cet espace « Vos applications » classe Produits et Discussions parmi les modules métier. Référentiels est une fonctionnalité transversale du manifeste serveur, réservée aux administrateurs ERP habilités avec une application lisible ; ne pas inventer une licence autonome pour sa tuile ni élargir la permission API `IsERPAdmin`. La garde frontend vérifie le rôle ERP, sans exiger la licence Administration. `AfficherDansEspace` retire une tuile sans supprimer les données, routes ou habilitations, comme pour l’accueil Catalogue. Le module « Informations santé » a été retiré le 4 novembre 2026 : ne plus exposer son annuaire, sa tuile, son guide ni ses liens ; l’ancienne URL `/maladies` renvoie vers `/catalogue`. Les données catégorielles médicales et les inclusions de licence historiques du code `catalogue` sont conservées. Une destination proposée doit être utilisable avec les mêmes droits que son API.

L’accueil présente désormais trois totaux non identifiants de publication via `/api/public/catalogue/synthese` : offres partagées, profils publiés, structures territoriales référencées. Cette synthèse globale sans filtre ne rend pas les fiches, contacts ou stocks accessibles sans compte. Ne pas la confondre avec les anciens agrégats authentifiés, la couverture sanitaire du pays ou une preuve de disponibilité. Utiliser les vues de publication existantes et garder la date réelle du calcul ; aucune projection privée ni nouvelle migration de données n’est nécessaire pour ces compteurs.
- Pour l’aide intégrée par application : [Guide utilisateur](../../docs/guide-utilisateur.md). Chaque évolution d’un parcours doit mettre à jour ses étapes et son exemple concret. Le serveur limite le catalogue et chaque article aux applications autorisées par la licence et le rôle ; l’administrateur global conserve son périmètre transversal.
- Pour le traitement transversal des incidents, demandes et réclamations : [contrat backend Support](../../backend/skills/develop-sauverndeko-backend/references/support.md), [contrat d’interface](../../frontend/skills/develop-sauverndeko-frontend/references/support.md) et [guide utilisateur](../../docs/module-support.md). Les nomenclatures restent dans referentiel, la configuration dans systeme et les dossiers dans support.
- Pour reprendre un comportement d’imf_BB : [matrice de transposition](references/transposition-imf-bb.md).
- Pour PostgreSQL/API : [skill backend](../../backend/skills/develop-sauverndeko-backend/SKILL.md).
- Pour l’interface : [skill frontend](../../frontend/skills/develop-sauverndeko-frontend/SKILL.md).

TailAdmin et shadcn/ui servent de références complémentaires de design et d’usage. Une amélioration préserve les particularités métier, les permissions et les API et commence par les composants communs. Réduire les étapes inutiles et rendre les erreurs compréhensibles ; ne pas modifier la base ou changer de bibliothèque pour une seule question de présentation. Lire [les références frontend](../../frontend/skills/develop-sauverndeko-frontend/references/design-reference.md) pour les exemples, licences et contrôles.

- Pour les fichiers Excel, Word et PDF : [mise en forme SauverNdeko](../document-mise-en-forme/SKILL.md), charte, modèles et contrôle des exports.

## Intentions du propriétaire

L’application doit devenir un ERP dont la logistique fait partie. Préserver les fonctions santé/services et la réutilisation entre organisations et pays. Les priorités exprimées le 24/10/2026 sont les vues SQL, les commentaires des tables et vues, des interfaces modernes, les indicateurs cliquables et les consultations 360 pour les objets métier.

La première intervention porte sur la cartographie et les skills. Elle ne valide pas une mise en production ni la conformité commerciale de l’application. Une demande ultérieure d’implémentation doit produire une tranche utilisable du parcours concerné.

## Manière de conduire une évolution

1. Identifier l’objet métier, ses sources, ses droits, ses effets de bord et ses consommateurs. Distinguer explicitement code présent, comportement vérifié et cible proposée.
2. Suivre le chemin écran → service HTTP → route montée → service métier → vue de lecture → tables/routines. S’appuyer sur config/urls.py, les vues Django et les services réellement appelés.
3. Réutiliser le contrat commun avant de dupliquer une jointure, un calcul, une modale ou une table. Vérifier le grain, les dates, les unités et le périmètre de la source.
4. Préparer ensemble la lecture, son détail consultable et l’export lorsque le besoin les inclut. Une somme sur une page ne représente pas le total du registre.
5. Pour une modification SQL, versionner la définition, les commentaires et les dépendances. Vérifier les triggers installés avant de programmer un deuxième effet sur le stock.
6. Faire respecter les droits par le serveur sur chaque route et chaque objet lié. Une portée de réglage global/country/entity n’assure pas l’isolation des données métier.
7. Mettre à jour les références du domaine et indiquer ce qui a été effectivement exécuté. Ne pas déclarer un module livré sur la seule présence de son modèle Django ou d’un écran.

### Saisie de plusieurs enregistrements similaires

Dans tous les modules où des créations similaires s’y prêtent, privilégier un panier de lignes. Un seul bouton de création (« Nouveau… » / « Nouvelle… », par exemple « Nouvelle valeur ») ouvre ce formulaire, utilisable aussi avec une seule ligne ; ne pas dédoubler cette action avec un bouton « Saisie multiple ». Le compositeur des Bons de stock sert de référence d’interaction : ajouter, corriger, retirer une ligne, annuler l’ensemble puis enregistrer une seule fois. Lorsque les lignes partagent un parent, employer un en-tête/détails : par exemple une catégorie puis ses valeurs. Le collage Excel alimente ce même brouillon ; les validations et doublons sont indiqués par ligne, sans perdre la saisie. Le serveur enregistre tout le lot et son audit dans une transaction unique ; aucune réussite partielle. Un rejeu après une réponse incertaine conserve la même demande et son contenu. Conserver un formulaire individuel pour les opérations qui ne se prêtent pas à un panier.

Choix explicite du 30 octobre 2026 pour Logistique : Tiers et Immobilisations utilisent un seul bouton de création avec panier. Articles conserve « Nouvel article » et son formulaire complet, avec un bouton distinct « Ajouter plusieurs articles ». Préserver cette exception demandée par le propriétaire.

Dans chaque panier pertinent, proposer ensemble **Télécharger le modèle Excel**, **Importer un fichier Excel** et **Coller depuis Excel**. L’import prépare les lignes, il ne les enregistre pas : vérifier et corriger dans le même panier, puis confirmer l’enregistrement transactionnel de l’ensemble. Ce standard couvre les catégories/valeurs, territoires N0 à N5, tickets, profils professionnels, tiers, immobilisations, utilisateurs, rôles, correspondances, paramètres et paniers de caisse. Réutiliser le lecteur XLSX commun et les services de sauvegarde existants, avec les droits et le contexte courant. Ne pas transformer un journal, une validation financière ou un paramétrage structurel en import libre. Les profils complexes conservent aussi leur fiche individuelle pour la photo et la publication.

Dans Administration, Utilisateurs, Rôles, Correspondances FK et Paramètres utilisent chacun un seul bouton de création ouvrant un panier de 1 à 100 lignes. La fiche complète sert aussi à corriger une ligne du brouillon, sans écriture individuelle avant la validation du panier. Les mots de passe initiaux restent uniquement dans le fichier privé choisi et le panier en mémoire ; ils ne figurent jamais dans les préférences navigateur, URL, lectures de comptes ou audits. L’aperçu d’import retourne uniquement les cellules fournies au compte habilité, sans cache ni mot de passe existant.

### Administration par entreprise et navigation commune

Le contexte Administration se charge indépendamment de la licence Logistique. Un gestionnaire d’entreprise ne peut gérer que les comptes ordinaires de son entreprise ; les rôles de sécurité, licences et réglages structurants se gèrent par la plateforme. Les rôles restent partagés, sans copie par entreprise. Les compteurs, graphiques, listes et exports conservent le même périmètre serveur. Lire le [contrat d’administration](../../backend/skills/develop-sauverndeko-backend/references/administration-portail.md) et le [bilan du 30 octobre](../../docs/administration-entreprises-20261030.md).

Les localisations appartiennent à la fiche Entreprise, dans son sous-onglet Localisation. Ne pas recréer un onglet de navigation parallèle ni les transmettre via le profil documentaire de Logistique. Sauvegarder ensemble la fiche, son logo et ses points en contrôlant les révisions et les affectations existantes.

Réutiliser `ModuleSidebar` pour les barres latérales : groupes repliables, état actif, rail compact, menu mobile, navigation au clavier et couleurs de thème. Les préférences de repli restent visuelles ; elles n’accordent aucun droit. Les [preuves de navigation](../../docs/verification-navigation-20261030.md) distinguent les tests techniques d’une recette réelle au navigateur.

## Invariants SauverNdeko

Pour toute liste catégorielle liée à `referentiel.T_Generique`, la valeur enregistrée est `ID_Generique` et le libellé affiché est `AbrGenerique`. Ne pas donner la priorité à `NomGenerique` dans un module, un filtre, un formulaire ou une valeur conservée. Cette convention ne modifie ni les clés étrangères, ni le nom des catégories, ni les codes et critères utilisés par les règles métier. Une abréviation absente doit être signalée par un libellé neutre identifiable, sans inventer une valeur ni réécrire le dictionnaire.

### Structures et coordonnées territoriales

Les listes de rattachement territorial affichent le chemin réel jusqu’au niveau proposé : `COD / province / Type - Nom / Type - Nom`. Le pays provient de `T_Niveau_0.iso`, les types de `T_Generique.AbrGenerique` ; ne pas substituer le nom long du pays ni réduire un choix au seul nom. Le type et les parents distinguent par exemple Ngiri Ngiri secteur, ZS ou BCZS. Ce libellé commun s’applique aux créations individuelles et multiples, modifications, filtres, destinations logistiques et localisations d’entreprise. La valeur reste la clé du territoire ; une donnée manquante n’autorise ni pays inventé ni rattachement déduit. Lire le [contrat des libellés territoriaux](../../backend/skills/develop-sauverndeko-backend/references/territoires-portail.md#libellés-des-listes-territoriales).

Le module `/pharmacies`, présenté comme **Structures**, est l’annuaire des structures et territoires N2 à N5, issu de `geolocalisation.V_StructureSanitairePublique`. Tous les types communs actifs de leurs familles physiques y sont consultables, y compris districts, secteurs et groupements. Les visibilités existantes `VisibleNiveau_3/4/5` gouvernent les choix de types dans les nouvelles saisies ; elles ne masquent pas les affectations historiques valides de l’annuaire. Conserver les anciennes valeurs hors choix et ne pas ajouter de second classement. Le niveau et l’ID forment l’identité ; les pharmacies relèvent du niveau 5. La lecture transverse exige Structures, sans licence Territoires ni entreprise active ; Gestion territoriale rejoint les registres sous leurs droits propres. Un territoire ne devient ni entreprise licenciée ni destinataire de discussion.

Les niveaux territoriaux 1 à 5 utilisent une fiche de coordonnées centralisée dans `geolocalisation.T_CoordonneesTerritoire`, liée à un seul territoire par de vraies clés étrangères. `PublierCoordonneesAnnuaire`, `false` par défaut, autorise les seuls contacts, accueil et horaires déclarés ; son retrait ne masque pas le nom, le type ou le rattachement territorial. Aucun contact de parent n’est copié ou déduit. La fiche Entreprise reste distincte. Les vues, fiches et paniers partagent cette source, leur transaction et leur contrôle de révision.

Lire [le contrat actuel des structures et territoires](../../SQL/documentation/Annuaire_Sanitaire_Territorial_20261104.md) et [le portail territorial](../../backend/skills/develop-sauverndeko-backend/references/territoires-portail.md). Les libellés publics ne doivent promettre ni agrément, ni disponibilité vérifiée, ni ouverture actuelle ou proximité calculée.

Pour une reprise SNIS/DHIS2 ou GRID3, lire [le dossier de fiabilisation géographique](../../docs/fiabilisation-geolocalisation-20261104.md). Préserver les identités et parents physiques ; distinguer zone de santé, bureau BCZS et rattachement PEV. Les liens et correspondances versionnés ne fusionnent ni les bureaux et zones ni les groupements et aires de santé. Une aire peut avoir plusieurs objets GRID3. Un rattachement établissement→aire exige une preuve propre : l'homonymie et l'égalité accidentelle des clés entre niveaux ne suffisent pas.

### Annuaire professionnel transversal

Le module Professionnels utilise un annuaire publié et une gestion privée par entreprise. Réutiliser les familles de `T_Generique` et le référencement physique des champs pour les secteurs, professions, spécialités, compétences, prestations et types de rattachement ; ne pas créer de dictionnaires locaux. Les tables de liaison décrivent les choix d’une fiche et les synonymes référencent une valeur centrale. Une recherche par besoin ne confère aucune qualification à une personne.

Conserver la fiche unique par compte, son propriétaire durable, les affiliations et leurs périodes. Les nouveaux profils reprennent le réglage de publication de leur entreprise. La publication exige un profil publiable. L’activité et l’autorisation de contact restent des décisions distinctes. Ne pas exposer dans l’annuaire les coordonnées personnelles, identifiants internes ou données RH. La gestion relève des administrateurs autorisés ; la lecture publiée est transversale et la messagerie contrôle de nouveau le destinataire et ses autorisations. Lire [le contrat Professionnels](../../docs/professionnels.md).

- PostgreSQL reste organisé par schémas métier ; les noms qualifiés existants et leur casse sont des contrats.
- QteArticle est le stock courant officiel ; T_Mouvement conserve l’historique ; les lignes de BE/BS portent les entrées/sorties effectives. Les lignes de bon de commande CMD décrivent des quantités commandées sans mouvement ni réservation de stock.
- Les mouvements restent en lecture seule ; les commandes clôturées sont protégées selon le scénario et les règles serveur existants.
- T_CommandeDetail possède une clé composée article/commande. Un article n’apparaît qu’une fois dans une commande avec le modèle actuel.
- Les règlements se rattachent à la facture par CodeFactureFk ; ne pas reconstruire une relation depuis un nom libre.
- Les données absentes restent distinctes de zéro. Ne pas additionner des devises ou unités différentes ; la devise du catalogue et celle du document sont explicites, les flux conservent leur instantané et les totaux sont ventilés par devise. Aucun taux ni conversion implicite n’est fourni.
- Reprendre les principes d’imf_BB, sans transférer ses clients, secrets, données financières, règles M-PESA/CBS ni obligations financières propres à ce projet. Le backend Django de SauverNdeko conserve les schémas métier ; les migrations natives Django sont autorisées dans public.

## Préparation d’une version client

Le schéma métier suit un manifeste de migrations et un journal par base ; lire [les mises à jour sans recréation de données](../../docs/mises-a-jour-base.md) avant une livraison. Le socle existant est attesté par comparaison du catalogue, sans rejeu des anciens SQL. Une nouvelle version ajoute une migration immuable, testée sur copie restaurée, et conserve la compatibilité backend/frontend pendant son installation. Les réglages privés de `.env` ne sont jamais publiés ; [le parcours Render](../../docs/deploiement-render.md) sépare maintenance et service web. Ne pas confondre un push, une demande de déploiement et une mise en ligne effectivement vérifiée.

Utiliser les jalons de la trajectoire ERP comme critères de travail, puis rapporter les résultats observés et les écarts restants. La livraison doit préciser les modules activés, les rôles, les données de démonstration fictives, l’installation, la sauvegarde/restauration et les limites connues. L’existence d’un client intéressé ne permet pas de présenter une fonction cible comme disponible.

## Architecture actualisée

Le backend unique est Django/DRF ; l’ancien backend Express/Prisma et ses dépendances ont été supprimés à la demande du propriétaire. Lire [le bilan technique actuel](../../SQL/documentation/Audit_Metier_20261024.md). Les inventaires initiaux décrivent l’état antérieur. Respecter le périmètre actualisé : schémas métier conservés, migrations natives Django autorisées dans public uniquement.

## Devises logistiques

La migration 20261025_04 est appliquée à SauverNdeko après sauvegarde. Le propriétaire a confirmé le rattachement des montants existants à USD. Pour les nouvelles créations, résoudre USD dans la catégorie Devise active du référentiel ; ne pas figer son identifiant ni inventer une devise dans le formatage frontend. Les champs `ID_DeviseFk`, `DeviseCode` et `DeviseLibelle` accompagnent les prix et montants ; les affichages peuvent suffixer le montant sans imposer une colonne redondante. La devise reste disponible dans les exports numériques, qui respectent exactement les colonnes et l’ordre choisis sans ajout implicite. Les agrégats, leurs détails et exports partagent le même filtre. Les montants de devises différentes ne sont jamais additionnés ; un prix catalogue d’une autre devise ne peut pas être recopié automatiquement dans un bon.

## Coûts, lots et livraison logistique

### Dépôts et transferts internes

Le multi-dépôts utilise l’extension versionnée [Logistique MultiDépôts](../../SQL/3.%20Schema%20logistique/Logistique_MultiDepots.md) et le [plan de migration](../../docs/multi-depots-plan-migration.md). Vérifier sa présence dans le journal de chaque instance avant d’annoncer les nouveaux parcours disponibles. Le stock physique reste issu des mouvements, ventilé par dépôt de l’entreprise ; le total article conserve la somme physique. Le disponible exclut les réservations et les lots indisponibles, tandis que le transit demeure distinct. Ne pas additionner les unités hétérogènes dans un indicateur unique.

Les bons, réceptions, stocks initiaux et inventaires portent leur dépôt. Un historique ne se déplace pas par modification de sa fiche. Le dépôt principal simplifie les créations et accueille la migration des historiques sans rejouer leurs mouvements. Un transfert concerne deux dépôts de la même entreprise : demande, validation/réservation, expédition, réception partielle ou complète, retour du transit ou écart motivé. Chaque action garde son identité de demande et sa révision pour empêcher un second effet lors d’un rejeu. La réception reprend le coût de la sortie source. Aucun transfert ne crée une facture, un règlement ou une écriture de caisse.

Les nouveaux onglets Dépôts, Stocks par dépôt et Transferts internes suivent aussi le catalogue de présentation par entreprise : noms personnalisables, masquage et restauration des défauts, sans effacer les préférences déjà enregistrées. Un masquage visuel n’accorde ni ne retire une permission métier. Réutiliser les mêmes vues pour listes, contrôles, alertes, détails et exports. Conserver les mécanismes existants de péremption et de lots ; une quarantaine opérationnelle et les rappels ne sont pas implicitement livrés par ce modèle.

La valorisation CUMP est calculée par les fonctions et vues PostgreSQL de 20261026_04, par article, propriétaire et devise. Ne pas la remplacer par prix catalogue × quantité. Un coût inconnu reste distinct de zéro ; une ouverture doit être confirmée avec motif et révision atomique. Les retours utilisent les coûts historiques prouvés. Les tables d’arrêtés et de journal portent des événements métier, elles ne sont pas des catégories à déplacer dans T_Generique. Lire [la règle CUMP](../../SQL/documentation/Valorisation_CUMP_20261026.md).

Lots de stock est un registre transversal après Articles ; V_RegistreLots et V_RegistreMouvementLot servent les tableaux, la fiche Lot 360 et les exports. Chaque fiche limite son journal au lot sélectionné et à son entreprise. Les lots épuisés/archivés restent consultables, tandis que les alertes courantes ne comptent que les stocks restants. Les seuils et dérogations suivent la [règle de péremption](../../SQL/documentation/Peremption_Lots_20261026.md).

Les bons correcteurs et compensateurs d’inventaire sont identifiés par FK, jamais par leur référence libre ; ils ne peuvent être facturés ou restitués commercialement. Une livraison nécessite les preuves de sauvegarde/restauration, installation et recette du [guide de livraison](../../docs/livraison-logistique.md), ainsi que les validations externes encore ouvertes dans [les travaux restants](../../docs/reste-a-faire-logistique.md).

## Données durables, stock initial et configurations transversales

Les évolutions SQL du 28 octobre 2026 distinguent les données métier, leur historique et les préférences personnelles. Avant d’ajouter une colonne, vérifier ce qui est déjà conservé par les tables, relations, instantanés et journaux : ne pas dupliquer un solde, une identité d’entreprise ou une révision sans besoin démontré. Une présence dans une migration n’atteste pas son installation chez un client ; vérifier les objets réels et les preuves de recette.

- Un stock initial positif crée atomiquement un bon d’entrée interne, une ligne et un seul mouvement sous contrôle PostgreSQL. Zéro ne produit aucune écriture fictive ; une modification descriptive ne recrée pas l’ouverture. L’origine et l’article source sont persistés, indépendamment du type de bon. Une reprise historique documente les mouvements prouvés sans rejouer le stock ni inventer auteur ou coût. Lire [le contrat Article](../../backend/skills/develop-sauverndeko-backend/references/articles-lots-photos.md).
- Les nouveaux numéros courts distinguent `BE-` (entrée effective), `BS-` (sortie effective), `CMD-` (commande sans effet stock) et `fac-`. L’identité est réservée en base et n’est pas réutilisable ; les numéros historiques restent inchangés par défaut. Exception explicitement demandée : la migration06 du 28 octobre harmonise les anciens codes de bons en conservant leur correspondance et leur instant dans T_BonCodeHistorique, sans réécrire les factures émises, audits ou mouvements. Lire [la reprise de nomenclature](../../SQL/documentation/Nomenclature_Bons_Historiques_20261028.md). Les bons d’ouverture technique ne deviennent pas des ventes ou commandes fournisseurs. Le type `CMD` vient de la catégorie partagée Type de commande ; zéro ne suffit pas à reconnaître un type autorisé. Les commandes ne créent ni lot, mouvement, coût, dette ou facture ; elles portent un prix convenu explicite. Une opération physique utilise son propre BE/BS. Lire [la distinction des trois documents](../../docs/bons-entree-sortie-commande.md).
- Les préférences de tableau et d’export ont deux usages indépendants, conservés dans `referentiel.T_InterfaceTableau` et `referentiel.T_PreferenceTableau`. Le contexte utilisateur/entreprise, les droits et les colonnes exportables sont vérifiés par le serveur. Les réglages communs ne sont pas modifiables par une préférence personnelle. Lire [le contrat de tableaux et exports](../../SQL/documentation/Preferences_Tableaux_Exports_20261028.md).
- Les correspondances FK et références métier sont chargées du serveur ; un ancien cache navigateur ne doit pas remplacer un réglage absent ou refusé. Les préférences purement visuelles peuvent rester locales. Ne pas réintroduire une liste métier codée dans chaque écran ou un réglage local portant un droit.
- Les dates et auteurs techniques des règlements et les contrôles financiers demeurent en SQL, y compris pour un futur backend. La GUC d’acteur sert à la traçabilité transactionnelle ; elle ne constitue pas une autorisation. Les permissions réelles restent vérifiées côté serveur, et les audits détaillés ne sont pas dupliqués en Python. Les métadonnées historiques inconnues restent inconnues.

Les tableaux, indicateurs et exports reprennent les mêmes unités, devises et périmètres. Une somme de quantités de plusieurs unités n’est pas présentée comme un total unique. Les exports respectent exactement les colonnes et leur ordre, proposent sélection ou résultats filtrés complets et conservent les références textuelles dans le XLSX. Le CSV UTF-8 avec BOM est adapté à Excel français mais reste sans types ; les zéros initiaux sont garantis par le XLSX.

## Référencement physique commun

Les champs catégoriels reposent sur `T_ChampReferentiel` et leurs vraies clés étrangères. Le défaut immuable est une référence prouvée ; NULL signifie qu’aucune famille n’est connue. La catégorie courante reste une configuration dans `T_Fk_Correspondance`, résolue en SQL par entreprise puis global puis défaut. Ne pas créer une deuxième autorité dans un composant, un JSON de code ou une autre table. Rétablir conserve explicitement le défaut au scope choisi, sans effacer les autres contextes.

La portée entreprise exige `SupportsEntityScope` et un propriétaire durable prouvé. La géographie et les autres tables partagées gardent leurs références globales ; l’utilisateur associé ne leur attribue pas une entreprise par déduction. Le contexte et les validations viennent du même résolveur SQL. Les métadonnées d’une nouvelle installation excluent auteurs, révisions et surcharges de l’instance source.

Les rôles de sécurité ne changent pas de famille. Une configuration n’est pas une migration de données : conserver les anciennes références, les copies exactes de parent et les valeurs financières/physiques historiques. Les nouvelles affectations sont validées au serveur dans les catégories actives ; libellés, abréviations et visibilités restent distincts des identifiants. Lire [le contrat de référencement des champs](../../SQL/documentation/Referencement_Champs_20261028.md) avant d’ajouter un consommateur ou un réglage.

## Biens de l’entreprise et données professionnelles

La tranche Patrimoine sépare les immobilisations des Articles et du stock commercial. Les références, affectations, quantités entières et calculs de valeur appartiennent aux vues et gardes SQL ; aucun retrait de stock, amortissement ou droit d’accès n’en découle automatiquement. Les données RH minimales complètent les comptes existants, restent privées et se gèrent dans l’onglet Utilisateurs fusionné ; la source Profils conserve sa compatibilité. Lire [la règle de patrimoine](references/patrimoine-affectations.md) avant d’étendre ce parcours.

## Organisation territoriale partagée

`/territoires` dispose d’un portail dédié, avec tableau de bord, treize registres, références dynamiques et fiches communes d’ajout/modification/consultation. La géographie conserve sa portée globale ; seul l’administrateur de la plateforme peut la modifier avec les droits requis. Le choix d’une entreprise ne change pas cette propriété. Une structure peut dépendre directement d’une zone sans aire renseignée : ne pas combler les rattachements absents par déduction. Les analyses conservent leur grain réel et leurs clés composites, sans addition de populations ou de nombres d’aires qui se répètent entre types. Lire [le guide du module et les preuves de recette](../../docs/module-organisation-territoriale.md).
