# Modules métier et fonctionnalités associées

« Vos applications », à /espace, affiche les modules accessibles au compte. Le catalogue /applications présente aussi les modules disponibles sur licence et indique l’accès effectif du compte. Chaque groupe a son propre compteur, y compris pendant une recherche.

| Modules inclus | Modules sur licence | Fonctionnalités associées | Administration de la plateforme |
|---|---|---|---|
| Produits | Discussions | Administration | Organisation territoriale |
| Structures | Logistique | Paramètres | |
| Professionnels | Caisse | Guide utilisateur | |
| | Support | Référentiels | |

Les trois annuaires inclus sont disponibles aux comptes authentifiés même sans entreprise. La messagerie exige l’accès à Discussions. La cloche de notifications reste accessible aux utilisateurs connectés. Organisation territoriale est réservée à l’administrateur de la plateforme, y compris si une licence historique d’entreprise comporte ce module. L’annuaire Structures conserve sa propre projection de lecture.

Dans /abonnements, l’administrateur de plateforme choisit une entreprise et une licence, puis active ou désactive les quatre modules de l’offre. L’accès effectif peut provenir d’une autre licence active. Les administrateurs d’entreprise consultent les licences de leur entreprise. Les activations historiques restent conservées et les restrictions du rôle continuent à s’appliquer.

La configuration est centralisée dans `systeme.T_ModuleApplication`. `TypeApplication` distingue modules et fonctionnalités. `EstSocle` inclut une application pour les entreprises actives. `AccessibleSansEntite` identifie les annuaires inclus pour les comptes sans entreprise. `Commercialisable` définit l’offre sous licence et `ReservePlateforme` réserve l’accès à la plateforme. `AfficherDansEspace` pilote l’affichage de la tuile. Les vues `systeme.V_LicenceModule` et `systeme.V_EntiteModuleActif` calculent les activations et leur disponibilité effective.

L’accueil public /catalogue reste la destination par défaut de la racine et du lanceur local. Après connexion, /espace reste la destination par défaut, sauf si une page protégée a été explicitement demandée.

Référentiels reste une fonctionnalité transversale réservée aux administrateurs ERP habilités disposant d’une application lisible, comme ses API existantes. Sa tuile est ajoutée par le manifeste serveur ; elle n’introduit aucune licence autonome. La licence Administration n’est pas exigée pour ce seul accès.

À la demande du propriétaire du 4 novembre 2026, **Informations santé** et sa page **Maladies** sont retirées : elles ne figurent plus dans Vos applications, le catalogue de découverte, la navigation ni le Guide utilisateur. L’ancienne URL `/maladies` redirige vers l’accueil `/catalogue` et l’API dédiée `/api/public/maladies` répond 404. Les valeurs de maladie du référentiel et les anciennes activations de licence sont conservées ; cette conservation historique ne réactive aucun parcours du module retiré.
