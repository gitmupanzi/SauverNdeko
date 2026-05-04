Je cherche à améliorer le frontend de la partie logistique du projet SauverNdeko.

Contexte du projet :
SauverNdeko est une application fullstack avec :

- backend Node.js / Express ;
- Prisma ;
- PostgreSQL ;
- frontend React.

Objectif :
Améliorer l’interface utilisateur du module logistique en tenant compte :

1. du scénario métier logistique déjà validé ;
2. des vues SQL existantes ;
3. des images de référence de l’interface graphique ;
4. de la logique métier stock / commande / mouvement / règlement.

Chemins importants :

- Backend :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\backend

- Frontend :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\frontend

- Page principale logistique :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\frontend\src\pages\Logistique.jsx

- Dossier des pages/composants logistique :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\frontend\src\pages\logistique

- Scénario métier à respecter :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\SQL\3. Schema logistique\scenario_metier_logistique.md

- Images de référence de l’interface logistique :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\SQL\3. Schema logistique\Images

Travail demandé :
Améliorer le frontend du module logistique pour obtenir une interface moderne, propre, lisible et cohérente avec les maquettes fournies.

Le module doit contenir les écrans suivants :

1. Tableau de bord
2. Articles
3. Commandes
4. Commande détail
5. Historique des mouvements
6. Règlements

Règles importantes à respecter :

- Les écrans doivent être cohérents visuellement entre eux.
- Utiliser une barre latérale logistique avec les menus :
  - Tableau de bord
  - Articles
  - Commandes
  - Commande détail
  - Historique des mouvements
  - Règlements
- Le menu actif doit être clairement mis en évidence.
- Utiliser une interface de type dashboard SaaS/admin moderne.
- Utiliser des cartes blanches, coins arrondis, ombres légères, boutons propres et badges de statut.
- L’interface doit rester lisible à 100% de zoom.
- Éviter les blocs trop grands ou inutiles.
- Les boutons doivent être alignés proprement sur une même ligne quand c’est possible.
- Le tableau doit être la zone principale de lecture des données.
- Ajouter une barre de recherche, des filtres, des actions, un tableau et une pagination.

Sources de données attendues côté frontend :

- Articles : lecture depuis la vue logistique.V_Article
- Commandes : lecture depuis la vue logistique.V_Commande ou V_CommandeOverview
- Commande détail : lecture depuis la vue logistique.V_CommandeDetail
- Historique des mouvements : lecture depuis logistique.V_MouvementStock ou V_Mouvement
- Règlements : lecture depuis logistique.V_SuiviReglements
- Tableau de bord :
  - logistique.V_AuditStock
  - logistique.V_AlertStock
  - logistique.V_ConsoMensuelle
  - logistique.V_CouvertureStock
  - logistique.V_CommandeOverview
  - logistique.V_CommandesSansDetails
  - logistique.V_SuiviReglements

Règles métier à respecter dans l’interface :

- T_Article représente le stock courant.
- T_Mouvement représente l’historique officiel du stock.
- T_Commande représente l’en-tête de commande.
- T_CommandeDetail déclenche réellement l’impact sur le stock.
- T_Reglements représente les paiements liés aux factures.
- Ne jamais proposer d’action directe Ajouter / Modifier / Supprimer sur l’historique des mouvements.
- L’écran Historique des mouvements doit être en lecture seule.
- La suppression d’un article doit être bloquée ou désactivée si l’article est déjà lié à une commande ou à un mouvement.
- Une commande clôturée ou facturée ne doit plus être modifiée ni supprimée.
- Les badges doivent aider à comprendre rapidement les états :
  - Disponible : vert
  - Stock faible : orange
  - Rupture : rouge
  - Réglée : vert
  - Partiellement réglée : orange
  - Non réglée : rouge
  - Non facturée : gris
  - Cohérente : vert
  - Sans détails : orange
  - Montant incohérent : rouge
  - Valide : vert
  - Quantité invalide : rouge
  - Prix non renseigné : orange
  - Entrée : vert
  - Sortie : rouge ou orange

Écran Tableau de bord :
Créer un dashboard synthétique avec :

- cartes statistiques :
  - Articles
  - Commandes
  - Stock faible
  - Ruptures
  - Commandes sans détails
  - Règlements en retard
- bloc Audit de stock
- bloc Alertes de stock
- bloc Consommation mensuelle
- bloc Couverture stock
- tableau Dernières commandes
- tableau Derniers mouvements

Écran Articles :
Afficher un tableau basé sur V_Article avec les colonnes principales :

- Code interne
- Article
- Catégorie
- Type
- Unité
- Stock
- Stock min
- À commander
- PU
- PV
- Valeur stock achat
- Marge
- État stock
- État péremption
- État article
- Actions

Filtres recommandés :

- Catégorie article
- Type article
- Unité
- État stock
- État péremption
- État article

Actions recommandées :

- Ajouter
- Modifier
- Supprimer
- Désactiver
- Voir
- Exporter
- Imprimer
- Correspondance FK
- Autres filtres

Écran Commandes :
Afficher un tableau basé sur V_Commande ou V_CommandeOverview avec les colonnes :

- Code commande
- Référence
- Date commande
- Type
- Statut
- Client
- Nb lignes
- Articles distincts
- Quantité totale
- Montant HT
- Montant TTC
- Total réglé
- Reste réel
- État paiement
- Contrôle commande
- Actions

Filtres recommandés :

- Type commande
- Statut commande
- État paiement
- Contrôle commande
- Client
- Période

Actions recommandées :

- Ajouter
- Modifier
- Supprimer
- Voir
- Ajouter produits
- Exporter
- Imprimer
- Correspondance FK
- Autres filtres

Écran Commande détail :
Afficher un tableau basé sur V_CommandeDetail avec les colonnes :

- Code commande
- Facture
- Date commande
- Type commande
- Statut commande
- Code article
- Article
- Unité
- Stock avant théorique
- Stock actuel
- Quantité
- PU
- Montant ligne
- Lieu
- État ligne
- Actions

Filtres recommandés :

- Commande
- Type commande
- Statut commande
- Article
- État ligne
- Période

Actions recommandées :

- Ajouter ligne
- Modifier ligne
- Supprimer ligne
- Voir
- Exporter
- Imprimer
- Autres filtres

Écran Historique des mouvements :
Afficher un tableau basé sur V_MouvementStock ou V_Mouvement.

Colonnes recommandées :

- ID mouvement
- Date mouvement
- Code article
- Article
- Code commande
- Type mouvement
- Quantité
- Quantité signée
- PU mouvement
- Montant mouvement
- Montant signé
- Origine mouvement
- Actions

Filtres recommandés :

- Type mouvement
- Origine mouvement
- Article
- Commande
- Période
- Sens stock

Actions autorisées uniquement :

- Voir
- Exporter
- Imprimer
- Autres filtres

Important :
Ne pas afficher les boutons Ajouter, Modifier ou Supprimer sur cet écran.

Écran Règlements :
Afficher un tableau basé sur V_SuiviReglements.

Colonnes recommandées :

- Code commande
- Code facture
- Date facture
- Échéance
- Client
- Montant TTC
- Total réglé
- Reste
- Nombre règlements
- Dernier règlement
- Jours avant échéance
- État règlement
- Retard
- Actions

Filtres recommandés :

- État règlement
- Retard paiement
- Client
- Date facture
- Échéance
- Période

Actions recommandées :

- Ajouter règlement
- Modifier règlement
- Voir commande
- Exporter
- Imprimer
- Correspondance FK
- Autres filtres

Contraintes techniques :

- Conserver les fonctionnalités existantes.
- Ne pas casser les routes existantes.
- Ne pas modifier la logique backend sans nécessité.
- Privilégier une amélioration frontend propre et progressive.
- Vérifier les composants existants avant d’en créer de nouveaux.
- Factoriser les éléments répétitifs :
  - Sidebar logistique
  - Header de page
  - Barre d’actions
  - Barre de filtres
  - Tableau réutilisable
  - Pagination
  - Badge de statut
- Garder le code lisible, maintenable et compatible avec la structure actuelle du projet.

Résultat attendu :

- Une interface logistique améliorée, cohérente avec les images de référence.
- Des écrans propres et lisibles pour Tableau de bord, Articles, Commandes, Commande détail, Historique des mouvements et Règlements.
- Une page utilisable à 100% de zoom.
- Des tableaux bien structurés.
- Des actions et filtres adaptés à chaque écran.
- Une logique UI fidèle au scénario métier logistique.

Avant de modifier, analyser d’abord :

1. Logistique.jsx
2. le dossier frontend/src/pages/logistique
3. les composants déjà existants
4. les appels API existants
5. les noms exacts des champs retournés par le backend
