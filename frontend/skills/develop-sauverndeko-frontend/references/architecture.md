# Architecture frontend

Relevé historique du 24/10/2026. Racine de travail : frontend/.

Ce document conserve l’architecture observée à cette date ; ses anciennes routes et pages ne décrivent pas la version actuelle. Pour les parcours en service, lire le [skill frontend](../SKILL.md) et `src/App.jsx`. Le nettoyage de la version 1.0.0 a retiré les anciennes pages d’accueil et d’inscription devenues inutilisées.

## Structure et routes

main.jsx charge l’application. App.jsx présente le login aux visiteurs sans session, puis monte le shell applicatif et la recherche globale, le tiroir de navigation et les appels d’ouverture de discussions. AuthContext expose session, utilisateur et permissions ; ProtectedRoute protège profil/discussions, AdminRoute protège administration/logistique dans l’interface.

| Route | Page | Accès dans React |
|---|---|---|
| / | WorkspaceHome | Connecté ; modules fournis par Django |
| /catalogue | Home | Connecté |
| /produits | Products | Connecté |
| /pharmacies | Pharmacies | Connecté |
| /experts | Experts | Connecté |
| /maladies | Diseases | Connecté |
| /login | Login | Sans session ; redirection si session valide |
| /register | Redirection vers /login | Inscription libre fermée |
| /profil | Profile | Connecté |
| /discussions | Discussions | Connecté |
| /admin | Admin | canAccessAdmin |
| /logistique | Logistique | canAccessAdmin |
| /territoires | OrganisationTerritoriale | canAccessAdmin |

Le propriétaire a demandé le login comme écran d’entrée, selon le principe d’imf_BB. Sans session valide, les pages applicatives redirigent vers /login ; l’inscription libre est fermée et la création des comptes appartient à l’administration. Une session déjà valide est restaurée. Le catalogue ne se charge qu’après entrée dans le shell. Après connexion, la destination interne demandée est conservée, paramètres et fragment inclus ; par défaut, l’accueil est ouvert. La déconnexion ramène au login.

Django impose aussi l’authentification sur les projections du catalogue, malgré leur préfixe historique /api/public/. /api/workspace/modules filtre les applications selon les droits actuels ; les routes privées contrôlent leurs propres permissions. Les réponses API/auth portent Cache-Control: no-store. La session rejetée par le serveur ramène au login. L’accueil par modules est distinct du shell des registres. Sa présentation a été approuvée par le propriétaire ; conserver ce repère visuel, en retirant les mentions ERP/espace de travail et le nom d’espace de l’en-tête à sa demande.

## Services et données

- services/api.js : requestJson avec Bearer issu de authStorage pour requiresAuth, normalisation d’erreur, appels publics/discussions/admin/vues.
- services/auth.js et authStorage.js : authentification et stockage des jetons ; relire leurs comportements avant de toucher la session.
- services/logistique.js : API dédiée /api/logistique avec les mêmes helpers.
- services/mappers.js et hooks/usePublicCatalogue.js : adaptation des données publiques et catalogue.

## Administration

Admin.jsx concentre beaucoup de code (~4 816 lignes). Les configurations pages/admin/systeme.js, referentiel.js et geolocalisation.js décrivent les vues. Les appels /api/views et les nouveaux endpoints modulaires coexistent avec les routes génériques /api/models. Les réglages FK et leurs portées se synchronisent avec le backend.

Une extraction de composants doit préserver les comportements effectivement utilisés : filtres, sélection, colonnes, scroll, formulaires, audit et réglages. Ne pas réécrire toute l’administration pour ajouter une seule consultation.

## Logistique — état du 25/10/2026

Logistique.jsx possède un en-tête de module et une colonne de navigation permanente à gauche, avec icônes Bootstrap, repli sur ordinateur et rail compact sur mobile. Le shell du catalogue n’enveloppe plus ce module. Les libellés métier sont définis dans la [terminologie du stock](terminologie-stock.md).

DashboardLogistique charge /api/logistique/synthese avec les critères appliqués. Les mesures viennent du serveur, jamais d’une somme sur la page. Quatre blocs repliables regroupent Articles (dont catégories), Bons de stock (attente, en cours, entrées, sorties, lignes et facturation), Factures (comptages et montants) et Alertes (stock faible, ruptures, péremption, écarts, couverture courte). Le bloc Derniers bons de stock est supprimé ; les listes sont chargées sur clic d’un indicateur. Une facture possède une référence non vide ; les bons non facturés sont exclus du bloc Factures. Les périodes utilisent la date du bon, la date de facture ou la date du mouvement selon la source. Le clic sur une carte ou son lien de détail charge /api/logistique/indicateurs/<clé> dans une liste sous les indicateurs. Revenir à l’indicateur et Fermer la liste restituent défilement et focus. Les recherches de détail sont validées explicitement ; populationQ conserve la recherche du dashboard lorsque q affine la liste.

Articles et Commandes (libellé Bons de stock) utilisent /api/logistique/registre/articles et /registre/commandes. SimpleTable accepte serverMeta/serverState/onServerChange ; ses tris, recherches et pages sont alors exécutés par Django. Les colonnes visibles, gelées et redimensionnées restent locales. Les autres registres utilisent encore leurs lectures historiques : leur présentation commune ne prouve pas l’exhaustivité de leurs listes plafonnées.

ConsultationProvider, monté sous AuthProvider, expose openProduct/openOrder. Les identités et Consulter convergent vers une même fiche ; lignes, mouvements et factures peuvent ouvrir leur article ou bon associé. L’API /api/logistique/consultations/<produit|commande>/<id> vérifie le parent autorisé puis fixe les clés étrangères des rubriques. Les paramètres du navigateur ne peuvent pas déplacer le parent. Les rubriques lourdes sont chargées à la demande et paginées.

Le dialog natif fournit largeur initiale 680 px, boutons ±160, poignée/clavier, rétablissement, Échap et restitution du focus. La largeur seule est mémorisée. Une modification de largeur ne relance pas les lectures. Sur mobile, la fiche occupe toute la largeur. Changer de session, organisation ou permission ferme les fiches.

Les montants conservent les décimales reçues et une absence reste —. La devise n’étant pas fournie par le modèle actuel, aucune devise n’est inventée. Les détails d’indicateurs disposent d’un export XLSX serveur complet, portant sur les critères appliqués, le tri et les colonnes métier visibles. La route /api/logistique/indicateurs/<clé>/export.xlsx partage read_scope et resolve_indicator avec la liste. Le serveur refuse explicitement les exports de plus de 100 000 lignes ; aucune troncature silencieuse. Les autres exports historiques restent des exports de page (CSV, tableau HTML compatible tableur, impression navigateur). Aucun PDF serveur exhaustif n’est annoncé.

## Organisation territoriale

L’accueil présente ce module aux utilisateurs autorisés, via /api/workspace/modules. /territoires réutilise Admin restreint au schéma geolocalisation : découpages administratifs et pyramide sanitaire. Ce nom n’affirme pas une conformité réglementaire ou ONU.

## Vérifications

Le bundling Vite, le diagnostic Django GET en lecture seule et la recette navigateur sur données fictives sont complémentaires. La recette couvre recherche au-delà de la première page, pagination, KPI vers liste intégrée, fiches liées, retour/focus, redimensionnement sans requête, refus d’accès et mobile. Les contrôles API utilisent la base SauverNdeko en lecture seule ; aucune écriture métier ni migration n’est requise par cette évolution.

## Thèmes et préférences

main.jsx monte ThemeProvider autour de l’application. ThemePicker propose les quatre modes dans les en-têtes et à la connexion. theme.css porte les palettes et les adaptations des composants partagés ; ThemeContext applique data-theme et color-scheme sans recharger les listes. La clé sauverndeko.theme contient uniquement le choix de présentation. La couleur par défaut du menu logistique est bleu ardoise.

## Barre de données et présentation

DataTableToolbar et DataTable.css servent les détails d’indicateurs et les rubriques paginées des fiches 360 : recherche validée, taille de page, filtres par colonne, réinitialisation, densité, colonnes et pagination. Excel est proposé uniquement lorsque son endpoint complet est raccordé. columnFilters est un objet JSON de valeurs validées côté Django à partir des métadonnées de la vue. Les filtres numériques acceptent =, >, >=, < et <= ; les dates suivent le fuseau validé timeZone. populationQ maintient la population du dashboard quand la recherche de détail affine les résultats. Le KPI conserve sa mesure de population, et le pied du tableau indique le nombre de résultats affinés.

La préférence sauverndeko.table.density change uniquement l’espacement. Elle ne déclenche pas de lecture métier. Les colonnes visibles/gelées/redimensionnées restent pilotées par SimpleTable. Le login, Vos applications et DashboardLogistique suivent la référence TailAdmin adaptée à React/Bootstrap ; aucune migration Next.js/Tailwind n’est nécessaire. Les périodes prédéfinies remplissent les dates du formulaire ; Appliquer déclenche la lecture.

## Colonnes, pagination et résumé du projet

ColumnPicker remplace la grille des réglages par un menu ancré : recherche locale, visibilité, colonne figée et largeur automatique. Le menu utilise la couche native popover lorsqu’elle est disponible, fonctionne dans une fiche 360, se ferme par Échap ou clic extérieur et restitue le focus au déclencheur. Ces réglages ne déclenchent pas de lecture métier.

TablePagination affiche la plage réellement présentée et les pages disponibles. Quand tous les résultats tiennent sur une page, le pied indique Tous les résultats sont affichés ; les boutons précédent/suivant ne sont pas proposés. La barre de recherche reste visible même après un résultat vide, afin de pouvoir réinitialiser.

Le panneau droit du login contient un résumé court de Projet Startup SauverNdeko.pdf fourni par le propriétaire : produits, professionnels et établissements de proximité en RDC, avec la santé, l’immobilier et la construction comme premiers domaines. Ce texte présente la mission sans promettre une couverture territoriale, un résultat médical ou des fonctions non raccordées. Le dashboard ne propose plus Actualiser ni Nouveau bon de stock dans son en-tête, à sa demande ; la création appartient au registre.
