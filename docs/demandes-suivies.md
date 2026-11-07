# Demandes suivies

Une demande permet d’exprimer un besoin à partir d’une offre de produit, d’un profil professionnel ou d’une structure de l’annuaire, puis de connaître son état. Elle reste distincte d’une commande, d’une réservation, d’une facture et d’une discussion. Son enregistrement ne réserve aucun article et ne crée aucun mouvement de stock ou de caisse.

## Parcours

1. Ouvrir une offre, un profil professionnel ou une structure, puis choisir **Faire une demande** lorsque cette action est disponible.
2. Vérifier la source et le destinataire affichés. Renseigner l’objet et une description courte. Pour un produit, préciser si utile la quantité et la destination.
3. Envoyer explicitement la demande. Son numéro permet de la retrouver dans **Discussions → Demandes**.
4. Consulter les rubriques **Envoyées** et **Reçues**. Ouvrir une demande pour consulter son état, les actions autorisées et son historique.
5. Utiliser **Démarrer une discussion** si un échange est nécessaire, puis **Ouvrir la discussion** pour y revenir. La discussion est créée sur cette action seulement ; l’envoi de la demande n’envoie pas automatiquement un message privé.

Une quantité demandée n’est pas une quantité réservée ou livrée. L’unité correspond à celle de l’offre au moment de la demande ; l’application ne convertit pas implicitement des unités différentes.

## Destinataires

| Source | Destinataire |
|---|---|
| Offre de produit | Entreprise qui publie l’offre |
| Profil professionnel | Compte du professionnel ciblé |
| Structure ou territoire de niveau 3, 4 ou 5 | Entreprise explicitement rattachée par l’administration de la plateforme |

Les identifiants des niveaux territoriaux ne sont pas des identifiants d’entreprise. Une structure sans rattachement conserve sa fiche d’annuaire et ses coordonnées publiées, mais ne peut pas recevoir de demande interne. L’interface indique cette indisponibilité ; aucune réception ni prise en charge n’est inventée.

L’administration de la plateforme peut configurer le destinataire d’une structure avec un motif. Ce changement est versionné et tracé. Il s’applique aux nouvelles demandes et ne transfère pas les demandes déjà adressées à un autre destinataire.

Le retrait du rattachement désactive la réception des nouvelles demandes sans supprimer les demandes ni les échanges antérieurs. Une entreprise inactive ne peut pas devenir destinataire d’une nouvelle demande.

Une affiliation professionnelle ne rend pas les administrateurs des entreprises affiliées participants aux demandes et conversations privées du professionnel.

## États et historique

Le circuit comporte **En attente**, **En cours**, **Satisfaite**, **Non satisfaite** et **Annulée**. Le serveur fournit les transitions autorisées pour le compte connecté.

| Participant | Action possible |
|---|---|
| Destinataire autorisé | Prendre en charge une demande en attente, ou la déclarer non satisfaite tant qu’elle est active |
| Demandeur | Annuler ou déclarer non satisfaite une demande active ; confirmer sa satisfaction après prise en charge |

Pour une entreprise destinataire, ces actions reviennent à ses gestionnaires réellement rattachés, avec les droits Discussions. Un agent ordinaire ou le seul choix de cette entreprise dans le sélecteur global ne donne pas ces droits. Pour un professionnel, elles reviennent à son compte destinataire figé.

La prise en charge peut être immédiate, avec un commentaire facultatif. Les clôtures **Satisfaite**, **Non satisfaite** et **Annulée** exigent un motif. Chaque changement conserve son auteur et sa date. Les états de fin ne sont pas effacés pour recommencer le circuit. Si quelqu’un a modifié la demande entre-temps, l’application demande de recharger sa version plutôt que d’écraser la modification.

Les écritures portent un identifiant de requête : rejouer la même opération après une interruption ne doit pas créer de doublon. Réutiliser cet identifiant avec un contenu différent produit un conflit.

## Confidentialité et limites

Les demandes sont accessibles au demandeur et au destinataire autorisé, selon les droits applicatifs. Le contexte global d’un administrateur ne crée aucune participation privée. La licence et les droits de Discussions restent nécessaires.

La disponibilité d’une source et les droits sont revérifiés lors de l’envoi. Si une offre ou un profil est retiré, les nouvelles demandes sont refusées. Les participants gardent le suivi de leurs demandes existantes, sans ouverture vers la fiche privée ni vers une ancienne photo devenue non publiée.

La demande conserve seulement les informations nécessaires au suivi. Éviter les diagnostics, dossiers médicaux, pièces d’identité et informations de tiers dans le texte. Ni la lecture des annuaires, ni une demande, ni une discussion ne constituent un diagnostic ou une donnée de recherche automatiquement collectée. Aucun traitement analytique des messages n’est activé par ce parcours.

Le statut **Satisfaite** décrit le résultat déclaré de la demande ; il ne prouve pas un achat, une vente ou une prestation clinique. L’application ne réalise ni paiement, ni réservation de rendez-vous, ni certification de qualification par cette fonctionnalité.

## Contrat technique

Les routes dédiées commencent par `/api/discussions/demandes` : contexte de source, listes envoyées/reçues, fiche et historique, transitions, ouverture explicite de discussion et configuration du routage territorial. Les objets du schéma `communication` restent exclus des routes génériques de modèles et de vues.

Les vérifications indépendantes sont réunies dans `SQL/tests/test_demandes_suivies_api.py`. Elles exigent une base PostgreSQL locale dont le nom commence par `sauverndeko_test_` et refusent une URL Render ou la base de l’application. Le bilan d’exécution doit être consulté avec les preuves privées de la recette ; la présence du fichier ne signifie pas qu’un test a été exécuté en production.

## Vérification du 7 novembre 2026

La recette API et SQL a exécuté **21 scénarios réussis** sur une copie PostgreSQL locale dédiée :

- Authentification, droits Discussions, lecture seule et licences réellement actives, y compris lorsque les capacités applicatives sont déjà chargées.
- Destinataires prouvés, cloisonnement entre entreprises, séparation du compte professionnel et de son entreprise, absence de privilège privé lié au seul contexte global.
- Création, validation, quantité exacte facultative, recherche, pagination, historique, retrait de publication et inactivité du destinataire.
- Rejeu d’une opération, refus d’une clé réutilisée avec un autre contenu, contrôle de révision, motifs de clôture et fermeture définitive des états terminaux.
- Ouverture explicite du fil, envoi et lecture de vrais messages par l’API existante, rejeu de message et refus des non-participants.
- Routage territorial explicite, changement ou retrait tracé, conservation du destinataire des demandes anciennes, refus d’accès par les routes génériques.
- Absence d’écriture de stock, de commande, de caisse ou d’analytics à la création ; retrait effectif de la photo d’une offre masquée ; commentaires SQL des tables, colonnes et vue.

Trois vérifications supplémentaires, conservées dans `SQL/tests/test_demandes_suivies_concurrency.py`, ont utilisé **deux connexions PostgreSQL simultanées** : une création rejouée ne produit qu’une demande ; deux clôtures concurrentes de la même révision donnent un seul succès et un conflit de version ; les deux participants ouvrant la discussion obtiennent le même fil. L’historique conserve une seule clôture acceptée. Le test exige une copie locale de recette inactive et les droits de création d’une base temporaire. Il crée son propre clone, puis le supprime après fermeture des connexions ; il ne termine aucune session et ne modifie pas sa copie source.

Les **105 assertions frontend ciblées** ont également réussi pendant cette recette. Elles vérifient les composants et parcours automatisés ; elles ne constituent pas une validation visuelle complète dans un navigateur.

Les preuves techniques restent privées dans `.runtime/demandes-suivies/`. Un jeu de comptes, d’offres et de routage fictifs est conservé uniquement sur la copie de recette pour permettre la vérification navigateur. Aucun de ces contrôles n’a écrit dans la base de l’application ou dans Render.

Les tests de non-régression existants des discussions et annonces ont aussi réussi : **9 scénarios de messagerie et 5 scénarios d’annonces**. La compilation Vite réussit. La migration a été installée par le moteur de livraison sur une copie restaurée : contrôle à jour, seconde application sans écriture et empreinte de schéma inchangée.

## Installation locale

Le 7 novembre 2026, la migration `20261107_01_demandes_suivies` a été installée dans **localhost / sauver_ndeko_pro**, après sauvegarde restaurée et vérifiée de 84 tables et 6 médias. La comparaison avant/après conserve les anciennes données de 83 tables, hors journal de migration ; les valeurs de référence nouvellement ajoutées et la nouvelle colonne de liaison sont distinguées des anciennes lignes. Aucun compte, demande ni routage fictif n’a été ajouté à la base de l’application.

Les services Django et Vite ont été redémarrés avec le lanceur sécurisé du projet. Les contrôles HTTP directs et via le port 5174 répondent ; les routes privées exigent une authentification. La page est accessible dans **Discussions → Demandes** (`/discussions?onglet=demandes`). Render et son environnement sont restés inchangés. La preuve d’installation se trouve dans `.runtime/demandes-suivies/local-install-proof.json`.

**Configuration des destinataires :** les contrôles en lecture de la base locale ont trouvé trois offres publiées, mais aucun gestionnaire d’entreprise disposant actuellement de l’accès Discussions et aucun routage territorial vérifié. L’envoi vers une entreprise reste donc indisponible jusqu’à la configuration d’un destinataire réellement habilité. Pour une structure territoriale, son entreprise destinataire doit aussi être choisie explicitement. Aucun compte, rattachement ou droit n’a été créé automatiquement pour contourner ce prérequis.

**Limite restante :** la recette visuelle complète sur ordinateur et téléphone n’a pas été exécutée. Le contrôle du navigateur a été interrompu parce que l’outil ne pouvait pas identifier son URL avec suffisamment de confiance. Les tailles d’écran, le défilement et l’utilisation réelle au clavier doivent encore être vérifiés dans le navigateur avant de déclarer le parcours entièrement réceptionné. L’installation et la recette en production restent distinctes de ces tests locaux.
