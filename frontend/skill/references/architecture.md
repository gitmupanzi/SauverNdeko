# Architecture frontend

Relevé statique du 24/10/2026. Racine de travail : frontend/.

## Structure et routes

main.jsx charge l’application. App.jsx contient le routage, le shell public, la recherche globale, le tiroir de navigation et les appels d’ouverture de discussions. AuthContext expose session, utilisateur et permissions ; ProtectedRoute protège profil/discussions, AdminRoute protège administration/logistique dans l’interface.

| Route | Page | Accès dans React |
|---|---|---|
| / | Home | Public |
| /produits | Products | Public |
| /pharmacies | Pharmacies | Public |
| /experts | Experts | Public |
| /maladies | Diseases | Public |
| /login, /register | Login, Register | Public |
| /profil | Profile | Connecté |
| /discussions | Discussions | Connecté |
| /admin | Admin | canAccessAdmin |
| /logistique | Logistique | canAccessAdmin |

La protection React ne certifie pas la protection API. La navigation actuelle reste fortement structurée autour d’un shell mobile ; le workspace ERP desktop doit être conçu sans casser le catalogue public.

## Services et données

- services/api.js : requestJson avec Bearer issu de authStorage pour requiresAuth, normalisation d’erreur, appels publics/discussions/admin/vues.
- services/auth.js et authStorage.js : authentification et stockage des jetons ; relire leurs comportements avant de toucher la session.
- services/logistique.js : API dédiée /api/logistique avec les mêmes helpers.
- services/mappers.js et hooks/usePublicCatalogue.js : adaptation des données publiques et catalogue.
- data/mockData.js : données présentes dans le dépôt ; vérifier les imports effectifs avant d’affirmer leur usage dans un écran ou de les supprimer.

## Administration

Admin.jsx concentre beaucoup de code (~4 816 lignes). Les configurations pages/admin/systeme.js, referentiel.js et geolocalisation.js décrivent les vues. Les appels /api/views et les nouveaux endpoints modulaires coexistent avec les routes génériques /api/models. Les réglages FK et leurs portées se synchronisent avec le backend.

Une extraction de composants doit préserver les comportements effectivement utilisés : filtres, sélection, colonnes, scroll, formulaires, audit et réglages. Ne pas réécrire toute l’administration pour ajouter une seule consultation.

## Logistique

Logistique.jsx gère sidebar, onglet actif, références et correspondances. pages/logistique/views.js regroupe le catalogue des dix vues, règles CRUD, sources de référentiels et fetchers. Les clés dashboard/articles/commandes/details/mouvements/reglements/audit/alertes/consommation/couverture sont internes à cette page.

Composants dédiés : DashboardLogistique, Articles, Commandes, CommandeDetails, Mouvements, Reglements, StockAudit, AlertesStock, ConsommationMensuelle et CouvertureStock.

logistiqueShared.jsx contient SectionCard, SummaryCard, LoadingErrorEmpty, SimpleTable, SelectionStrip, formulaires et helpers de format/export. Vérifier les props existantes avant d’ajouter un second tableau générique. SimpleTable gère des fonctions d’affichage locales ; cela ne rend pas exhaustive une recherche sur un résultat limité par l’API.

## Limites à ne pas propager

- DashboardKpiCard est une carte statique ; les valeurs n’ouvrent pas encore leur détail.
- Plusieurs boutons onNavigate changent seulement l’onglet ; un libellé mentionnant un critère ne prouve pas que le critère est appliqué.
- Les filtres du dashboard ne sont pas transmis à son chargement ; des synthèses React utilisent des listes plafonnées, parfois demandées au-delà du maximum serveur.
- formatNumber/formatCurrency convertissent aujourd’hui certaines absences en zéro ; formatCurrency utilise USD en dur. Ne pas recopier ce traitement dans les nouveaux contrats.
- exportRowsToExcel produit du HTML avec extension .xls ; exportRowsToPdf utilise une fenêtre d’impression. Les helpers consomment les lignes fournies, sans garantir un registre complet.
- Aucun conteneur partagé Produit 360/Commande 360 conforme au contrat cible n’a été trouvé.

## Points d’extension proposés

Créer une infrastructure JSX commune de consultation et un état d’ouverture par objet ; noms indicatifs, pas fichiers déjà présents : ConsultationDialog, Product360, Order360 et openObject({type,id,context}). Utiliser les API métier actuelles lorsqu’elles suffisent ; définir les rubriques manquantes avec le backend.

Créer un contrat unique de critères appliqués pour dashboard, liste, détail et export, avec restitution des filtres visibles. Le contexte comprend organisation, identifiant stable, critères appliqués et point de retour. Ne pas stocker de données métier privées dans une préférence de largeur.

La validation et le détail des interactions figurent dans [les contrats d’interface](contrats-interface.md).
