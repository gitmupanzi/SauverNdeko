# Architecture frontend

Relevé statique du 24/10/2026. Racine de travail : frontend/.

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

Le propriétaire a demandé le login comme écran d’entrée, selon le principe d’imf_BB. Sans session valide, les pages applicatives redirigent vers /login ; l’inscription libre est fermée et la création des comptes appartient à l’administration. Une session déjà valide est restaurée. Le catalogue ne se charge qu’après entrée dans le shell. Après connexion, la destination interne demandée est conservée, paramètres et fragment inclus ; par défaut, l’accueil est ouvert. La déconnexion ramène au login.

Django impose aussi l’authentification sur les projections du catalogue, malgré leur préfixe historique /api/public/. /api/workspace/modules filtre les applications selon les droits actuels ; les routes privées contrôlent leurs propres permissions. Les réponses API/auth portent Cache-Control: no-store. La session rejetée par le serveur ramène au login. L’accueil par modules est distinct du shell des registres. Sa présentation a été approuvée par le propriétaire ; conserver ce repère visuel, en retirant les mentions ERP/espace de travail et le nom d’espace de l’en-tête à sa demande.

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

## Direction validée pour la suite

Interface moderne inspirée d’Odoo : tableaux et recherches cohérents, indicateurs réellement cliquables et consultations Produit 360/Commande 360 suivant les contrats du projet et les comportements d’imf_BB. Ces fiches restent à construire. Le propriétaire demande des textes courts, humains et professionnels, sans phrases de consigne ni détails techniques dans le parcours ordinaire.
