Je cherche à améliorer le frontend de la partie Administration du projet SauverNdeko.

Contexte du projet :
SauverNdeko est une application fullstack avec :

- backend Node.js / Express ;
- Prisma ;
- PostgreSQL ;
- frontend React.

Objectif :
Améliorer l’interface utilisateur du module Administration en tenant compte :

1. du scénario métier système déjà validé ;
2. des vues SQL existantes du schéma systeme ;
3. des vues référentielles utiles ;
4. des images de référence de l’interface graphique ;
5. de la logique métier liée aux utilisateurs, rôles, permissions, entités, licences, audit, historique de connexion, correspondances FK et paramètres UI.

Chemins importants :

- Backend :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\backend

- Frontend :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\frontend

- Scénario métier système :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\SQL\1. Schema systeme\scenario_metier_systeme.md

- Fichier des vues système :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\SQL\1. Schema systeme\Systeme_View.sql

- Fichier des tests système :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\SQL\1. Schema systeme\Systeme_Test.sql

- Vues référentielles :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\SQL\0. Schema referentiel\Referentiel_views.sql

- Images de référence de l’interface Administration :
  C:\Users\Benjamin MUPANZI\Dropbox\Documents\PROFANE\SauverNdeko\SQL\1. Schema systeme\Images

Travail demandé :
Améliorer le frontend du module Administration pour obtenir une interface moderne, propre, lisible et cohérente avec les maquettes fournies.

Le module Administration doit contenir les écrans suivants :

1. Tableau de bord
2. Utilisateurs
3. Rôles
4. Permissions
5. Journaux d’audit
6. Correspondances FK
7. Localisations entités
8. Licences
9. Historique de connexion
10. Profils utilisateurs
11. Paramètres UI

Règles générales d’interface :

- Les écrans doivent être cohérents visuellement entre eux.
- Utiliser une barre latérale Administration avec les menus :
  - Tableau de bord
  - Utilisateurs
  - Rôles
  - Permissions
  - Journaux d’audit
  - Correspondances FK
  - Localisations entités
  - Licences
  - Historique de connexion
  - Profils utilisateurs
  - Paramètres UI
- Le menu actif doit être clairement mis en évidence.
- Utiliser une interface de type dashboard SaaS/admin moderne.
- Utiliser des cartes blanches, coins arrondis, ombres légères, boutons propres et badges de statut.
- L’interface doit rester lisible à 100% de zoom.
- Éviter les blocs trop grands ou inutiles.
- Les boutons doivent être alignés proprement sur une même ligne quand c’est possible.
- Le tableau doit être la zone principale de lecture des données.
- Ajouter une barre de recherche, des filtres, des actions, un tableau et une pagination sur les écrans de liste.
- Factoriser les composants répétitifs pour éviter la duplication.

Composants frontend à privilégier ou créer si nécessaire :

- AdminSidebar
- AdminPageHeader
- AdminActionToolbar
- AdminFilterBar
- AdminDataTable
- AdminPagination
- AdminStatusBadge
- AdminDashboardCard
- AdminAuditDrawer
- AdminJsonDiffViewer
- AdminSettingsPanel
- AdminMapPreview

Sources de données attendues côté frontend :

- Utilisateurs / profils :
  - systeme.V_User_profil

- Historique de connexion :
  - systeme.V_Login_history

- Journaux d’audit :
  - systeme.V_Audit_log

- Audit des paramètres UI :
  - systeme.V_Admin_UI_Setting_Audit

- Correspondances FK :
  - systeme.V_Fk_Correspondance
  - systeme.V_Fk_Correspondance_Detail
  - systeme.V_Fk_Correspondance_Audit

- Localisations entités :
  - systeme.V_Entite_Localisation_Detail

- Licences :
  - systeme.V_Licence_active

- Paramètres UI :
  - systeme.V_Admin_UI_Setting
  - systeme.V_Admin_UI_Setting_Group
  - systeme.V_Admin_UI_Setting_Audit

Règles métier importantes :

- Les journaux d’audit sont en lecture seule.
- L’historique de connexion est en lecture seule.
- Les audits des paramètres UI et des correspondances FK sont en lecture seule.
- Les écrans en lecture seule ne doivent pas afficher les boutons Ajouter, Modifier ou Supprimer.
- Les actions autorisées sur les écrans de lecture seule sont :
  - Voir
  - Filtrer
  - Exporter
  - Imprimer
  - Voir détail
- Les correspondances FK servent à gérer les liaisons entre les champs frontend/backend et les références génériques.
- Les correspondances FK doivent permettre la gestion des mappings :
  - generic_category
  - hierarchy_mode
- Les correspondances FK doivent gérer les portées :
  - global
  - entite
  - user
  - module
- Les paramètres UI doivent gérer les paramètres globaux, par entité, par utilisateur ou par module.
- Les paramètres UI doivent être auditables.
- Les licences doivent afficher clairement les statuts :
  - Active
  - Expirée
  - Expire bientôt
- Les utilisateurs doivent afficher clairement les statuts :
  - Actif
  - Inactif
  - Staff
  - Admin
- Les opérations audit doivent être affichées sous forme de badges :
  - INSERT en vert
  - UPDATE en bleu ou orange
  - DELETE en rouge

Écran Tableau de bord Administration :
Créer un dashboard synthétique avec des cartes statistiques :

- Utilisateurs
- Utilisateurs actifs
- Administrateurs
- Entités
- Licences actives
- Licences expirées
- Connexions du jour
- Journaux d’audit
- Correspondances FK actives
- Paramètres UI modifiés

Ajouter les blocs suivants :

1. Activités récentes
2. Derniers journaux d’audit
3. Historique de connexion récent
4. État des licences
5. Correspondances FK récentes
6. Paramètres UI récemment modifiés

Graphiques ou mini-visualisations recommandés :

- Répartition utilisateurs actifs / inactifs
- Répartition staff / admin
- Licences actives / expirées
- Connexions par jour
- Opérations d’audit par type : INSERT, UPDATE, DELETE

Écran Utilisateurs :
Afficher un tableau basé sur systeme.V_User_profil.

Colonnes recommandées :

- ID utilisateur
- Nom
- Prénom
- Email
- Téléphone
- Sexe
- Entité
- Staff
- Admin
- Statut
- Date création
- Actions

Filtres recommandés :

- Statut utilisateur
- Staff
- Admin
- Entité
- Sexe
- Période de création

Actions recommandées :

- Ajouter
- Modifier
- Désactiver
- Réinitialiser mot de passe
- Voir profil
- Exporter
- Imprimer
- Autres filtres

Badges :

- Actif : vert
- Inactif : gris ou rouge
- Staff : bleu
- Admin : violet

Écran Rôles :
Afficher un tableau de gestion des rôles à partir des données référentielles ou de la table prévue dans le système si elle existe.

Colonnes recommandées :

- ID rôle
- Code rôle
- Libellé rôle
- Description
- Nombre utilisateurs
- Actif
- Mis à jour le
- Actions

Filtres recommandés :

- Statut
- Type rôle
- Période
- Utilisateur de mise à jour

Actions recommandées :

- Ajouter
- Modifier
- Désactiver
- Voir permissions
- Exporter
- Imprimer
- Autres filtres

Badges :

- Actif : vert
- Inactif : gris
- Admin : violet
- Standard : bleu

Écran Permissions :
Afficher un tableau de gestion des permissions.

Colonnes recommandées :

- ID permission
- Module
- Écran
- Action
- Libellé permission
- Rôle associé
- Autorisé
- Actif
- Mis à jour le
- Actions

Filtres recommandés :

- Module
- Écran
- Action
- Rôle
- Autorisé
- Statut

Actions recommandées :

- Ajouter
- Modifier
- Désactiver
- Copier depuis rôle
- Exporter
- Imprimer
- Autres filtres

Badges :

- Autorisé : vert
- Refusé : rouge
- Lecture seule : orange
- Actif : bleu

Écran Journaux d’audit :
Afficher un tableau basé sur systeme.V_Audit_log.

Colonnes recommandées :

- ID log
- Date changement
- Table
- Entité
- Opération
- Anciennes données
- Nouvelles données
- Actions

Filtres recommandés :

- Table
- Entité
- Opération
- Période
- Utilisateur si disponible
- Module si disponible

Actions autorisées uniquement :

- Voir détail
- Exporter
- Imprimer
- Autres filtres

Important :

- Ne pas afficher Ajouter, Modifier ou Supprimer.
- Prévoir un panneau latéral ou modal pour comparer OldData et NewData.
- Afficher les données JSON de manière lisible.
- Prévoir un composant JSON diff si possible.

Badges :

- INSERT : vert
- UPDATE : bleu ou orange
- DELETE : rouge

Écran Correspondances FK :
Afficher un écran basé sur :

- systeme.V_Fk_Correspondance
- systeme.V_Fk_Correspondance_Detail

Colonnes recommandées pour la liste principale :

- Module
- Schéma
- Vue
- Clé source
- Champ
- Libellé champ
- Type mapping
- Référence
- Catégories
- Valeurs mapping
- Scope
- Nombre correspondances
- Mapping actif
- Dernière mise à jour
- Actions

Filtres recommandés :

- Module
- Schéma
- Vue
- Type mapping
- Scope
- Actif

Actions recommandées :

- Ajouter
- Modifier
- Désactiver
- Réinitialiser défaut
- Voir détail
- Voir audit
- Exporter
- Imprimer
- Autres filtres

Règles :

- Le bouton Réinitialiser défaut doit être visible.
- Le bouton Voir audit doit ouvrir l’audit basé sur systeme.V_Fk_Correspondance_Audit.
- Les mappings par défaut doivent être distingués des mappings personnalisés.
- Les mappings actifs doivent être affichés avec badge vert.
- Les mappings inactifs doivent être affichés avec badge gris.

Badges :

- generic_category : bleu
- hierarchy_mode : violet
- Actif : vert
- Inactif : gris
- Par défaut : turquoise

Écran Localisations entités :
Afficher un tableau basé sur systeme.V_Entite_Localisation_Detail.

Colonnes recommandées :

- ID localisation
- ID entité
- Entité
- Type entité
- Téléphone
- Email
- Latitude
- Longitude
- Niveau 3
- Niveau 4
- Niveau 5
- Adresse détaillée
- Date création
- Actions

Filtres recommandés :

- Type entité
- Niveau 3
- Niveau 4
- Niveau 5
- Entité
- Période

Actions recommandées :

- Ajouter
- Modifier
- Voir sur carte
- Exporter
- Imprimer
- Autres filtres

Interface :

- Prévoir une zone tableau.
- Prévoir une carte ou un aperçu cartographique à droite ou en bas.
- Les coordonnées latitude / longitude doivent être clairement visibles.
- Un bouton Voir sur carte doit être présent sur chaque ligne.

Écran Licences :
Afficher un tableau basé sur systeme.V_Licence_active.

Colonnes recommandées :

- ID licence
- Entité
- Date début
- Date fin
- Valide
- Expirée
- Statut licence
- Actions

Filtres recommandés :

- Statut licence
- Entité
- Date début
- Date fin
- Expiration proche
- Validité

Actions recommandées :

- Ajouter
- Modifier
- Renouveler
- Voir
- Exporter
- Imprimer
- Autres filtres

Badges :

- Active : vert
- Expirée : rouge
- Expire bientôt : orange
- Valide : vert
- Non valide : gris

Écran Historique de connexion :
Afficher un tableau basé sur systeme.V_Login_history.

Colonnes recommandées :

- ID login
- Date login
- Type login
- ID utilisateur
- Nom
- Prénom
- Email
- Entité
- Actions

Filtres recommandés :

- Type login
- Utilisateur
- Entité
- Date
- Période
- Email

Actions autorisées uniquement :

- Voir détail
- Exporter
- Imprimer
- Autres filtres

Important :

- Ne pas afficher Ajouter, Modifier ou Supprimer.
- Cet écran est strictement en lecture seule.

Badges :

- Connexion : vert
- Déconnexion : gris
- Échec : rouge si cette donnée existe
- Autre type : bleu

Écran Profils utilisateurs :
Afficher un tableau basé sur systeme.V_User_profil.

Colonnes recommandées :

- ID utilisateur
- Nom
- Prénom
- Email
- Téléphone
- Sexe
- Actif
- Staff
- Admin
- Date création
- Entité
- Email entité
- Téléphone entité
- Actions

Filtres recommandés :

- Actif
- Staff
- Admin
- Entité
- Sexe
- Période

Actions recommandées :

- Voir profil
- Modifier
- Exporter
- Imprimer
- Autres filtres

Écran Paramètres UI :
Afficher un écran basé sur :

- systeme.V_Admin_UI_Setting
- systeme.V_Admin_UI_Setting_Group
- systeme.V_Admin_UI_Setting_Audit

Interface recommandée :

- Afficher des onglets ou sections :
  - Général
  - Thème
  - Contact
  - Affichage
  - Sécurité
  - Notifications
  - Intégrations
  - Audit
- Afficher les paramètres sous forme de formulaire groupé.
- Afficher une table de paramètres si nécessaire.
- Afficher un bloc historique des modifications.
- Prévoir un bouton Voir audit.

Colonnes recommandées si affichage tableau :

- Groupe
- Clé
- Libellé
- Type
- Valeur
- Scope
- Modifiable
- Système
- Mis à jour le
- Mis à jour par
- Actions

Actions recommandées :

- Modifier
- Enregistrer
- Annuler
- Réinitialiser défaut
- Voir audit
- Exporter
- Imprimer

Badges :

- Modifiable : vert
- Non modifiable : gris
- Système : violet
- Global : bleu
- Entité : turquoise
- Utilisateur : orange
- Module : gris

Contraintes techniques :

- Conserver les fonctionnalités existantes.
- Ne pas casser les routes existantes.
- Ne pas modifier la logique backend sans nécessité.
- Vérifier les routes API existantes avant d’en créer.
- Vérifier les composants déjà disponibles avant d’en créer.
- Garder une amélioration progressive et propre.
- Si des routes API manquent, proposer leur création dans une structure propre :
  - routes
  - controllers
  - services
- Ne jamais coder en dur les listes référentielles si les données existent via les vues ou via systeme.T_Fk_Correspondance.
- Utiliser les noms exacts des champs retournés par les vues SQL.
- Gérer les états loading, error, empty state.
- Prévoir pagination, recherche et filtres côté API ou côté frontend selon l’existant.
- Garder un code lisible, maintenable et compatible avec la structure actuelle du projet.

Résultat attendu :

- Une interface Administration améliorée, cohérente avec les images de référence.
- Des écrans propres et lisibles pour Tableau de bord, Utilisateurs, Rôles, Permissions, Journaux d’audit, Correspondances FK, Localisations entités, Licences, Historique de connexion, Profils utilisateurs et Paramètres UI.
- Une page utilisable à 100% de zoom.
- Des tableaux bien structurés.
- Des actions et filtres adaptés à chaque écran.
- Une logique UI fidèle au scénario métier système.
- Les écrans d’audit et d’historique doivent rester en lecture seule.
- Le module doit être prêt pour évoluer sans casser les autres parties de SauverNdeko.

Avant de modifier le code, analyser d’abord :

1. la structure actuelle du dossier frontend ;
2. les pages Administration existantes ;
3. les composants réutilisables existants ;
4. les routes frontend ;
5. les appels API existants ;
6. les routes backend disponibles ;
7. les noms exacts des champs retournés par les vues SQL ;
8. le fichier scenario_metier_systeme.md ;
9. les images de référence de l’interface Administration.

Ensuite, appliquer les changements progressivement, sans casser l’existant.
