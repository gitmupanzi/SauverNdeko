# Module Support

`/support` utilise le shell ERP commun avec `ModuleSidebar`, `ModuleHeader`, le contexte d’entreprise, les thèmes et les contrôles du compte. **Pilotage** contient **Tableau de bord** puis **Modèles de suivi** selon les droits. **Traitement** contient **Tickets** puis **Suivi des étapes** selon les droits. Tickets regroupe les dossiers de tout type dans les vues **Liste** et **Kanban**. L’ancien lien `?onglet=tickets&vue=suivi` redirige vers `?onglet=processus`, soumis au droit de lecture de l’onglet.

## Pilotage et registre

La synthèse `/api/support/tableau-de-bord` fournit les indicateurs Tickets, les répartitions par statut et priorité et, selon les droits, les indicateurs Parcours. Un clic ouvre la liste paginée sous la synthèse et le bouton **Revenir à l’indicateur** rend le focus au déclencheur. Réutiliser le registre Tickets et le suivi des étapes, avec leur filtre d’origine conservé pendant les recherches, la réinitialisation et les exports disponibles. Les résultats du suivi ouvrent la fiche sur **Parcours**. Les délais de parcours et les échéances des tickets ont des compteurs distincts. Tous les effectifs proviennent du serveur.

Tickets reprend `RegisterSurface`, `SimpleTable`, `DataTableToolbar`, `SearchSelect`, `RegisterSettingsButton` et les préférences `support.tickets`. Le registre propose recherche appliquée, tri, pagination serveur, filtres par responsable, type, catégorie, priorité, statut et période, archives et exports XLSX/CSV. Les exports portent sur les résultats filtrés complets ou la sélection. Les formats et colonnes proviennent du contrat commun ; aucun export de démonstration ni filtrage limité à une page.

Le bouton Réglages reste dans l’en-tête de Tickets. Il donne accès à **Tableau et exports** et **Références**. Références présente l’identité du champ, les catégories effectives, leurs identifiants, le défaut et leurs valeurs. La configuration se modifie dans le référencement central.

L’onglet **Modèles de suivi** (`?onglet=modeles`) est accessible avec les droits de lecture Tickets et Suivi des étapes et la capacité serveur `canReadProcessModels`. Le registre réutilise la barre de recherche, les filtres, les réglages de colonnes (`support.modeles`), la pagination et le menu d’export Excel/CSV. En consultation consolidée, identifier l’entreprise sous le nom du modèle. La création, la modification et l’activation nécessitent `canManage` et une entreprise sélectionnée. Proposer de désactiver un modèle publié pour conserver les parcours historiques.

Le modèle Excel comporte une ligne par étape. Regrouper les étapes d’un même modèle par son nom, puis réutiliser les champs de l’éditeur individuel pour les vérifier dans le panier. Les erreurs associées à un modèle restent signalées jusqu’à confirmation de leur correction. Les erreurs de structure exigent un classeur corrigé. Enregistrer le panier dans une transaction unique et rejouer la même requête après une réponse incertaine.

La vue Kanban appelle `/api/support/kanban`. Chaque colonne porte un effectif serveur, un ensemble limité de cartes et un bouton vers la liste complète filtrée. Un nombre de cartes affichées ne représente jamais le nombre total de dossiers. Les cartes ouvrent la fiche par `ID_Support` ; ne pas déplacer arbitrairement une carte entre statuts sans action serveur autorisée.

Pour la priorité et le statut, réutiliser les badges Support dans la liste, le Kanban et la fiche. La priorité critique ressort en rouge, la priorité haute en ambre ; les états Nouveau, En cours, En attente et Résolu se distinguent respectivement en bleu, violet, ambre et vert. Le suivi des étapes distingue aussi le retard (ambre) du blocage (rouge). Utiliser le code du circuit quand il est fourni, ou une valeur de référence reconnue ; une valeur inconnue reste neutre. Garder les libellés visibles et le mode contraste élevé lisible sans couleur.

## Dossier et traitement

Le numéro et Consulter ouvrent la même fiche. `RecordEditorFrame` fournit les commandes de largeur, la fermeture, les protections du brouillon et le retour au focus. La fiche présente Synthèse, Parcours selon les droits, Échanges, Résolutions, Documents et Historique.

`SupportEditor` réutilise les champs entre la création et les deux modes de modification. **Modifier le ticket** couvre la demande, le demandeur et les objets liés. **Modifier le suivi** couvre l’affectation, la priorité et l’échéance. Depuis la fiche, changer le mode du même `RecordEditorFrame` et revenir à l’onglet courant après enregistrement ou annulation. Depuis le registre, afficher directement le mode demandé pendant le chargement. Pour une modification, envoyer uniquement les champs modifiés de la rubrique avec la révision et l’identifiant de requête. Un dossier complet avec son traitement et sa description utilise une saisie individuelle ; il ne s’agit pas d’un panier de références similaires. Les rubriques sont Demande, Affectation et Objets liés. Les valeurs existantes et la révision doivent être rechargées, y compris celles devenues incompatibles avec une nouvelle catégorie. La création propose les défauts reçus du serveur et respecte `requiredFields`. Le champ facultatif **Modèle de suivi** apparaît à la création selon la capacité serveur. Il propose les modèles actifs de l’entreprise correspondant au type du dossier. Le choix part dans la même requête que le dossier. Après confirmation, ouvrir directement **Parcours** si l’onglet est accessible. Sur un dossier ouvert existant, proposer l’association depuis **Parcours** selon les capacités renvoyées par le serveur.

L’import Excel complète ce parcours individuel : modèle Tickets vide en ligne 1, puis `SupportBatchEditor` pour lire un `.xlsx` de 4 Mo/100 dossiers maximum, sélectionner une ligne et corriger les mêmes rubriques avant confirmation globale. Les références non reconnues restent visibles avec leur texte d’origine et un avertissement ; ne pas les remplacer silencieusement par un choix par défaut. Aucun dossier, message ni document n’est créé à l’import. Le lot final utilise les contrôles du service individuel dans une transaction englobante ; une erreur conserve le panier et annule toutes les créations et audits de la demande. Garder le corps et l’identifiant exacts après une réponse incertaine. Le changement de droits ou d’entreprise invalide les réponses d’import en attente.

Le demandeur est un tiers existant et ne doit jamais être interprété comme un identifiant utilisateur. Les responsables et objets liés sont des références de l’entreprise autorisée. Les champs liés enregistrent leurs vraies FK. La fiche peut recevoir son propre contexte de référence pour ne pas mélanger les choix d’autres entreprises.

Les actions de traitement sont exactement celles renvoyées par `detail.transitions`. Le serveur décide de la prise en charge, mise en attente, reprise, résolution, vérification, clôture, réouverture et archivage. Ne pas reconstruire les transitions depuis les libellés, une couleur ou l’ordre des colonnes Kanban. Le motif, la cause/solution et le résultat/commentaire de vérification sont demandés selon les drapeaux de l’action reçue.

Les résultats de vérification viennent de l’instantané du dossier, via `verificationResults` ou `references.resultats` de la fiche. Une modification de la configuration courante ne doit pas remplacer les résultats autorisés pour un dossier en cours.

## Échanges et justificatifs

Un échange est public ou interne selon le choix explicite. Le backend filtre la visibilité effective. Les messages utilisent du texte React, sans rendu HTML non contrôlé. Le texte, les notes et fichiers ne sont pas stockés dans le navigateur.

Les justificatifs sont téléversés dans le stockage privé réutilisé. Le formulaire accepte les types effectivement servis par le moteur commun (PDF, PNG, JPEG, WebP), avec contrôle de taille puis validation serveur. Un document peut appartenir au dossier ou à un commentaire du même dossier. Le téléchargement utilise son identifiant privé et contrôle le type MIME ; aucune URL média publique ni adresse distante en guise de fichier.

Les brouillons de message et de justificatif restent montés lors d’un changement de sous-onglet. Ils signalent les modifications non enregistrées à la fiche et bloquent la fermeture pendant l’envoi. Une nouvelle action du dossier ne s’ouvre pas pendant cette saisie pour éviter une révision concurrente créée par la même fenêtre.

## Contexte, droits et réponses incertaines

Les capacités viennent de l’API et des permissions du compte. Le contexte Toutes les entreprises est une consultation ; une entreprise explicite est nécessaire pour les écritures. Le changement d’utilisateur/entreprise invalide les requêtes précédentes et retire les anciennes données immédiatement. Une fiche reçue avec un autre `ID_Support` est refusée explicitement.

Chaque mutation conserve `requestId`, `_version` et le corps exact envoyé. Une réponse réseau incertaine ou un échec serveur conserve ce même corps pour le bouton Vérifier l’enregistrement ; les champs restent figés pour éviter un nouvel enregistrement implicite. Un rejet de validation conserve la saisie et permet sa correction. Le serveur reste responsable des révisions, transactions, permissions, transitions et relations interentreprises.

## Vérifications

Dans **Parcours**, afficher séparément l’état du dossier et l’étape actuelle, ses échéances, son responsable et l’historique des passages. Utiliser les actions, validations et preuves renvoyées par l’API avec la révision du parcours. Réutiliser les fenêtres latérales, les listes recherchables et les états de chargement du module. Les modèles désactivés restent consultables et les dossiers en cours gardent leur version de départ.

`frontend/scripts/tests/support.cjs` exécute les helpers et handlers réels avec API/DOM simulés : création, révisions, brouillons, refus, rejeu, critères, pagination, exports, Kanban, indicateurs, messages, téléversement et téléchargements. La compilation Vite vérifie l’intégration à l’application. Ces tests ne remplacent pas une recette visuelle réelle dans le navigateur ni les tests PostgreSQL/API du parcours métier.
