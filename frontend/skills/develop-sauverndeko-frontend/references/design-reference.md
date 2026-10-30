# Référence visuelle SauverNdeko

Le propriétaire retient [TailAdmin React](https://react-demo.tailadmin.com/) comme référence de modernité, le 25 octobre 2026. S’en inspirer pour la cohérence, la lisibilité et les interactions ; conserver les contenus métier et la marque SauverNdeko dans la pile React JSX/Vite/Bootstrap existante.

## Navigation commune — 30 octobre 2026

`ModuleSidebar` mutualise les menus d’Administration, Logistique, Référentiels, Organisation territoriale et du catalogue. La référence [TailAdmin Form Elements](https://demo.tailadmin.com/form-elements) guide les groupes repliables, les chevrons, les icônes fines et la rubrique active ; conserver la marque et les couleurs bleu ardoise des thèmes SauverNdeko, sans recopier les données ou badges de démonstration.

Les groupes vides disparaissent et les entrées sont filtrées par les droits réellement reçus. La navigation transmet la clé stable de rubrique ou la route, jamais un index. Le repli d’un groupe ne navigue pas, ne filtre pas et ne touche aucune donnée métier. Lors d’une navigation vers une rubrique repliée, son groupe s’ouvre. Le groupe de la rubrique courante garde un repère même s’il est ensuite replié manuellement. Les états locaux de repli sont des préférences visuelles uniquement.

Sur ordinateur, conserver le panneau permanent, le rail compact et le pied de raccourcis selon les permissions. Sur mobile, le rail conserve les icônes et le bouton de menu ouvre la navigation complète, avec masque extérieur, fermeture par Échap, confinement du focus, retour au déclencheur et fermeture au passage vers une largeur d’ordinateur. Ne pas désactiver les libellés accessibles quand les textes sont masqués. Les transitions respectent la préférence de réduction des animations. Une modification visuelle ne peut pas élargir les autorisations serveur ni perdre le brouillon d’un formulaire protégé par son module.

Les anciens tableaux territoriaux gardent leurs contrats de vues et d’identifiants ; seul leur menu emploie le composant commun. Une compilation, des tests de handlers et des contrôles de cascade CSS ne constituent pas une recette visuelle du navigateur.

## Références ciblées

- [Tableaux de données](https://react-demo.tailadmin.com/data-tables) : en-têtes sobres, séparateurs fins, recherche, pagination et actions alignées.
- [Tableau de bord](https://nextjs-demo.tailadmin.com/) : hiérarchie des cartes et densité maîtrisée.
- [Onglets](https://nextjs-demo.tailadmin.com/tabs) : rubrique active et groupes cohérents.
- [Profil](https://nextjs-demo.tailadmin.com/profile) : identité et informations structurées.
- [Formulaires](https://react-demo.tailadmin.com/form-layout) : libellés courts, champs lisibles, validation près du champ.
- [Fichiers](https://react-demo.tailadmin.com/file-manager) : présentation des pièces jointes lorsqu’un parcours réel de documents sera raccordé. Cette référence n’atteste pas un gestionnaire de fichiers livré.

## Application au projet

Le login utilise un formulaire compact et un panneau d’identité bleu ardoise sur ordinateur ; le formulaire reste seul sur mobile. Garder les contrôles d’authentification, le retour vers la destination autorisée, les états d’erreur et le support des gestionnaires de mots de passe. Ne pas ajouter de connexion sociale ou d’inscription sans parcours autorisé.

Vos applications garde la grille validée : icônes colorées, carte de module cliquable, recherche immédiate et modules reçus du serveur selon les autorisations. Le dashboard conserve quatre blocs repliables Articles, Bons de stock, Factures et Alertes, avec mini-indicateurs compacts. Le clic ouvre la liste en dessous et le retour restitue défilement et focus. Une fiche 360 concerne un enregistrement, pas la population du KPI.

Les tables privilégient des en-têtes clairs, texte contrasté, lignes séparées, valeurs numériques alignées à droite et statuts en pastilles avec leur libellé. Regrouper recherche, lignes, filtres, réinitialisation, densité, colonnes et export raccordé dans une barre. Sur petite largeur, les outils reviennent à la ligne et seul le tableau défile horizontalement.

Centraliser les couleurs dans les variables erp de theme.css. Vérifier Clair, Sombre, Contraste élevé, mobile et largeur intermédiaire. Une variation de thème ou de densité n’altère ni la requête, ni la sélection métier. Ne pas copier les données de démonstration, les logos, les textes commerciaux ou les contrôles sans effet de la référence.

## Correction demandée par le propriétaire

Le tableau de bord n’affiche pas Sources et calcul, y compris dans la liste sous un indicateur. La traçabilité reste disponible dans le contrat serveur et les métadonnées de l’export. Les quatre blocs sont disposés sur deux colonnes sur ordinateur puis une colonne sur petite largeur ; les mini-indicateurs ouvrent leur liste par un bouton unique qui occupe toute la carte.

La référence fournie pour les actions utilise Rechercher en vert, Réinitialiser et les formats en contour fin, avec une icône de réinitialisation et une même icône de téléchargement pour Excel, Word et PDF. AppIcon et ActionButton portent ce vocabulaire partagé pour éviter des variantes par écran. Conserver les formats réellement disponibles ; cette règle visuelle n’autorise pas à afficher des exports fictifs.

## Registre Articles et Produit 360 — 25 octobre 2026

RegisterSurface porte l’en-tête et la carte de registre. Articles utilise une seule DataTableToolbar : recherche validée, taille de page, filtres métier repliables, réinitialisation, densité, colonnes et Excel complet. Les critères appliqués apparaissent en puces effaçables. Les boutons de stock sont des filtres serveur, sans compteur calculé sur une page.

La grille affiche par défaut Article (nom et code), Catégorie, Stock actuel et unité, État du stock, Prix d’achat, Péremption et Actions. Les autres champs restent dans ColumnPicker. Les colonnes ne sont pas gelées par défaut ; leur en-tête et leurs cellules défilent ensemble. Le gel est une préférence explicite. Sur mobile, éviter qu’une colonne gelée masque toute la grille. Conserver la sélection multiple, la sélection de page, le tri, les largeurs et TablePagination.

RowActionsMenu fournit le bouton ⋯ par ligne, avec Consulter, Modifier, Désactiver et Supprimer. Les écritures restent désactivées si canWriteData est faux et les confirmations existantes sont conservées. Ne pas remplacer ce menu par une simple sélection de ligne. Le CSV de sélection décrit uniquement les lignes sélectionnées de la page ; Excel exporte tous les résultats filtrés du registre, avec les colonnes choisies.

ProductHeading et ProductOverview structurent Produit 360 : identité, situation du stock, informations générales, prix et valorisation, conservation et observation. Les rubriques liées sont chargées à la demande et restent limitées à l’identifiant du produit. Changer de rubrique ne présente pas les données de la rubrique précédente. Conserver le conteneur commun, ses largeurs, son clavier et le retour au déclencheur.

Le lien Référentiels du menu logistique ouvre /referentiels, protégé par AdminRoute. Referentiels.jsx présente désormais un registre dédié aux catégories et valeurs partagées ; ne pas y réintroduire le shell historique Admin. Ce lien ne rend pas tout le module d’administration public.

## Réglages et fenêtres latérales — 25 octobre 2026

ReferenceSettings présente les listes associées à l’onglet dans un panneau latéral : libellés métier, nombre de valeurs, consultation avec recherche locale, informations associées et historique récent disponible. Ne pas afficher les noms SQL ni les identifiants de correspondance dans le parcours courant. Les configurations standard verrouillées ne présentent pas de fausses actions Enregistrer/Rétablir ; les réglages modifiables restent soumis aux droits globaux et au mode d’écriture reçu. Les actions groupées conservent les réglages des autres onglets.

Tous les panneaux latéraux métier de ce type utilisent DrawerDialog : Réduire, Élargir, Rétablir la largeur et Fermer, avec les mêmes AppIcon. Conserver la poignée, les pas de 32 px au clavier (128 px avec Maj), les bornes, le double-clic, le focus et la rubrique ouverte. Les préférences de largeur restent locales et indépendantes des requêtes métier. À 640 px et moins, la fenêtre occupe toute la largeur, avec fermeture toujours visible.


## Dossiers de suivi et en-tête 360 (25/10/2026)

Dossiers de suivi est un onglet du groupe Pilotage. Il classe les Articles, Bons de stock et Factures, avec filtre de type, catégories communes, couleurs, recherche et archives. Un dossier garde un type unique et immuable ; une catégorie peut regrouper des dossiers de plusieurs types. Les dossiers automatiques restent dynamiques selon les vues, sans copie de stock ni tâche de synchronisation. Les personnalisés sont privés au compte et à son contexte d’organisation, manuels ou automatiques.

FollowupFoldersProvider centralise le classement et son rafraîchissement. Chaque requête de rattachement contient objectType et recordIds ; un dossier d’un autre type ne doit jamais être proposé. Les fiches Produit/Bon montrent leurs dossiers colorés cliquables ; un bon facturé permet de classer le bon ou la facture distinctement. Tous les éditeurs utilisent DrawerDialog et ses quatre commandes.

Dans Produit 360, regrouper identité, codes et statuts à gauche, dossiers sous forme d’étiquettes compactes à droite. En dessous de 850 px, empiler ces zones. Utiliser la largeur effective du contenu de la fenêtre pour placer Informations générales et Prix et valorisation côte à côte au-delà de 1000 px ; ne pas se baser uniquement sur la largeur de l’écran. Aucun redimensionnement ne recharge les données métier.

Le 25/10, la migration SQL/migrations/20261025_01_dossiers_suivi.sql est installée après sauvegarde et accord explicite du propriétaire. L’application locale autorise les écritures des comptes déjà habilités. Les standards restent dynamiques et les personnalisés sont disponibles ; leur modification reste soumise au propriétaire et au périmètre du dossier. Annoncer une éventuelle indisponibilité de stockage ou de permission sans remplacer cet état par des données locales présentées comme persistées.


Le choix d’affichage de Dossiers de suivi propose Tableau, Liste, Compact et Cartes ; Tableau est le défaut demandé par le propriétaire. La préférence sauverndeko.followupFolders.view ne stocke que le mode, jamais les dossiers. Un changement de mode conserve recherche et filtres et ne recharge pas les données métier. Le tableau doit porter le conteneur erp-results et employer DataTable.css : en-têtes sobres en casse normale, bordures fines, badges colorés, pas de dégradés sur les poignées ni de colonne Actions figée arbitrairement. Utiliser SimpleTable et RowActionsMenu, dont le menu radio rend le mode sélectionné accessible au clavier.


## Menu du compte et notifications

Réutiliser [AccountControls](../../../src/components/AccountControls.jsx) pour le menu, le profil, le thème et la déconnexion existante, et [Notifications](../../../src/components/Notifications.jsx) pour la cloche. Le badge vient uniquement de meta.unreadCount de /api/notifications, jamais du nombre d’éléments de la page ni d’une valeur fictive. Une erreur reste une indisponibilité, pas zéro. Les communications sont personnelles et limitées à l’entité autorisée, même pour un administrateur ; vider immédiatement la liste et le badge lors d’un changement de compte ou d’entité. Respecter canMarkRead et conserver l’état non lu si l’écriture échoue.

Conserver les tokens de thème, les mêmes AppIcon, le contraste et les dispositions mobiles. Le menu et les panneaux restent utilisables au clavier, avec focus visible, fermeture par Échap et retour au déclencheur ; le profil et la déconnexion gardent leurs parcours réels et leurs protections de brouillon.


## Sous-onglets de consultation

Références de modernité : [onglets TailAdmin](https://react-demo.tailadmin.com/tabs), [profil](https://react-demo.tailadmin.com/profile) et [marketing](https://react-demo.tailadmin.com/marketing) pour la lisibilité et la hiérarchie. Reprendre ces principes dans les composants existants, sans copier de données de démonstration ni créer de fonction marketing sans besoin métier.

[ConsultationTabs](../../../src/components/ConsultationTabs.jsx) reçoit tabs ({key,label,icon}), value, onChange, label et idPrefix. Garder une barre neutre compacte à largeur du contenu, des icônes AppIcon et une pilule active contrastée ; les onglets ne s’étirent pas sur toute la fenêtre. Sur petite largeur, seul leur défilement horizontal révèle l’actif, sans déplacer la page. Flèches gauche/droite et Début/Fin assurent le parcours clavier ; seul l’onglet actif appartient à l’ordre de tabulation. Chaque panneau porte role=tabpanel, id={idPrefix}-panel-{key} et aria-labelledby={idPrefix}-tab-{key}, correspondant aux aria-controls des onglets.

Le contenu reste celui du profil ou de l’objet 360 sélectionné, chargé à la demande avec ses droits et ses états réels. Les changements de style, thème ou largeur ne relancent pas les lectures ; cliquer l’onglet déjà actif ne réinitialise ni filtres ni pagination. Vérifier clavier, focus visible, mobile et thèmes : une apparence moderne seule ne valide pas l’expérience.

## Profil utilisateur et photo

[Profile](../../../src/pages/Profile.jsx) conserve l’identité au-dessus des sous-onglets Informations personnelles, Organisation et Sécurité. Modifier ouvre RecordEditorFrame ; organisation et droits restent en consultation. Le paramètre modifier=1 ouvre une seule fois l’éditeur à l’arrivée.

[UserAvatar](../../../src/components/UserAvatar.jsx) est partagé avec l’en-tête, avec initiales par défaut. Choisir une photo JPEG, PNG ou WebP de 8 Mo maximum, avec aperçu local et retrait ; aucun champ d’adresse d’image dans le parcours. Révoquer les URL d’aperçu au remplacement, à l’annulation et à la fermeture. Aucun téléversement avant Enregistrer : réutiliser updateProfile pour la sauvegarde atomique des informations et de la photo ; le retrait reste une modification en attente. Une erreur conserve le fichier et le brouillon ; Annuler ne persiste rien.

Les contrôles de mot de passe ou de double authentification n’apparaissent que lorsqu’un parcours serveur réel est raccordé.


## Chargement des pages et valorisation — 26 octobre 2026

Réutiliser `lazyView` pour une nouvelle page ou une consultation volumineuse. Garder les contextes et le shell montés, conserver un espace réservé stable et une reprise explicite si un module n’a pas pu être téléchargé. Ne pas remplacer la grille ou son conteneur par un écran blanc pendant une actualisation de données ; préserver les filtres et les données déjà reçues dans leur périmètre. Mesurer le JavaScript initial par la fermeture des imports statiques du manifeste, puis vérifier la navigation sur le build de production.

`StockValuation` fournit la consultation CUMP et le formulaire de coût motivé avec le même DrawerDialog/RecordEditorFrame. Le coût moyen est une valeur exacte pouvant avoir six décimales ; il reste distinct du prix catalogue. Ne pas convertir la révision opaque en nombre et conserver l’UUID lors d’un rejeu incertain. Les boutons d’initialisation/réévaluation suivent `canConfigure` fourni par le serveur et le contexte d’entreprise. L’historique est paginé et filtré par devise côté serveur ; son Excel utilise le même filtre et l’ensemble des lignes. Le mode `readOnly` de RecordEditorFrame propose uniquement Fermer dans le pied de consultation.


## Identité documentaire et diagnostic d’envoi — 26 octobre 2026

Le pied du menu Logistique ouvre `EntityDocumentIdentity` pour l’entreprise active. Réutiliser le même `RecordEditorFrame` en consultation et modification ; les identifiants légaux sont des libellés/valeurs génériques (dix au maximum), sans imposer un régime fiscal ou un secteur. Les valeurs manquantes restent explicitement non renseignées. Le motif, la révision opaque et l’UUID de demande accompagnent la sauvegarde. Une réponse incertaine fige le contenu et réutilise la même demande ; recharger un brouillon exige un abandon explicite. Après réussite, rafraîchir la liste d’entreprises sans recharger la page ni perdre l’entreprise active. Les documents émis conservent leurs instantanés historiques.

`AdminMailSettings` prend les valeurs par défaut dans `data.defaults`, sans adresse codée en dur. « Tester la connexion » vérifie uniquement le transport courant et n’envoie aucun e-mail. Le bouton suit `canTest`, ses états attente/échec/reprise/succès sont distincts de la sauvegarde de l’expéditeur. Rappeler sobrement que les modifications du formulaire ne sont pas enregistrées. Les tests UI de ce bouton utilisent une réponse simulée et ne contactent jamais un service SMTP réel.

Tous les exports de lignes, listes, dossiers et consultations respectent à la fois le droit global et `moduleRights(user,"logistique").canExport`. Un accès de consultation ne donne pas le droit de créer une ligne : réutiliser `useEntityScope().canWrite`, qui tient compte du rôle et de l’entreprise active. Le serveur reste l’autorité sur chaque opération.


## Référentiels — 26 octobre 2026

Réutiliser le shell bleu ardoise, ModuleHeader, RegisterSurface, SimpleTable, DataTableToolbar et les menus communs. Deux entrées : Valeurs de référence et Catégories. Les identifiants et règles de visibilité restent des colonnes facultatives, sans cartes techniques de résumé.

Ordre initial des valeurs : Catégorie, Libellé, Abréviation ou code, Modules associés, État, Actions. Modules associés affiche exactement ModuleCategorieGenerique reçu du serveur, sans traduction codée dans React. Un libellé supplémentaire doit venir d’une source de référence centrale.

V_Generique et V_CategorieGenerique fournissent recherche, filtres, tri et pagination serveur. L’Excel natif /api/referentiel/exports/(valeurs|categories).xlsx reprend les mêmes critères, toutes les lignes filtrées et les colonnes choisies. Le CSV de sélection reste limité à celle-ci et neutralise les cellules pouvant être interprétées comme des formules.

Un clic, Consulter et Modifier emploient ID_Generique ou ID_CategorieGenerique de l’objet réel, jamais l’index de page. ReferenceEditor relit la fiche brute par cet identifiant, propose le formulaire commun Identification/Visibilité et protège le brouillon. En édition, envoyer uniquement les champs modifiés ; préserver les booléens NULL non touchés. Une perte de droits vide les données et la sélection devenues interdites.

Le DELETE standard du référentiel désactive : le menu et la confirmation disent Désactiver, sans annoncer une suppression définitive. La réactivation passe par le même formulaire. useReferencesRefresh garde les consommateurs à jour après une mutation réussie.

## Administration — 26 octobre 2026

Les images de SQL/1. Schema systeme/Images définissent les rubriques attendues, jamais les données, chiffres ni couleurs à recopier. /admin utilise AdminPortal : menu bleu ardoise par groupes, ModuleHeader et mêmes composants de registre que Logistique et Référentiels. Conserver Tableau de bord, Utilisateurs, Rôles, Permissions, Journaux d’audit, Correspondances FK, Localisations, Licences, Connexions, Profils utilisateurs et Paramètres UI ; Entreprises et Messagerie complètent les parcours déjà raccordés. LegacyAdmin reste chargé à la demande pour le module territorial, sans son ancien shell dans /admin.

AdminPortal utilise /api/systeme/administration/synthese et /registres/{kind} pour les lectures autorisées. Recherche, filtres appliqués, dates, tri et XLSX complet partagent leurs critères serveur. Les indicateurs actifs ouvrent exactement leur population ; connexions du jour conserve aussi le type Connexion. Les graphiques sans population consultable ne simulent pas un clic. Les listes restent montées pendant une actualisation et les identifiants réels servent au clic, à la sélection et à la modification. Une localisation possède IdEntiteLocalisation, distinct de IdEntite ; une entreprise sans localisation reste dans Entreprises.

AdminRecordEditor est commun à création, modification et consultation, avec RecordEditorFrame, SearchSelect et ConsultationTabs. Recharger la fiche brute fraîche et contrôler sa PK ; envoyer seulement les champs modifiés, préserver NULL et associations existantes, exclure les identifiants automatiques, dates automatiques et secrets masqués. Le mot de passe initial est saisi seulement à la création. Les paramètres secrets ou non modifiables restent en lecture ; un paramètre système modifiable verrouille son identité mais garde ses valeurs autorisées éditables. La désactivation conserve la fiche : FK et paramètres utilisent leur champ de validité par PUT, jamais un DELETE physique présenté comme une désactivation.

Permissions utilise les contrats existants /api/workspace/roles avec entreprise, rôle, socle autorisé et versions ; protéger les brouillons au changement de contexte et le retour après erreur. Les journaux et l’historique de connexion restent en consultation, avec secrets masqués côté serveur jusque dans les exports. Cet historique présente les événements déjà enregistrés ; la modernisation du portail ne constitue pas une nouvelle collecte de connexions.
