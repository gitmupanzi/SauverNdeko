# Référence visuelle SauverNdeko

Le propriétaire retient [TailAdmin React](https://react-demo.tailadmin.com/) comme référence de modernité, le 25 octobre 2026. S’en inspirer pour la cohérence, la lisibilité et les interactions ; conserver les contenus métier et la marque SauverNdeko dans la pile React JSX/Vite/Bootstrap existante.

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

Le lien Référentiels du menu logistique ouvre /referentiels, protégé par AdminRoute. Admin y est limité au schéma referentiel et charge seulement les catégories utiles aux formulaires. Ce lien ne rend pas tout le module d’administration public.

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
