# Module Support

`/support` utilise le shell ERP commun : `ModuleSidebar`, `ModuleHeader`, contexte d’entreprise, thèmes et contrôles du compte. Les onglets sont Tableau de bord et Tickets. Tickets désigne le registre de traitement ; la table principale reste `support.T_Support`.

## Pilotage et registre

Les six indicateurs du tableau de bord et les répartitions par statut/priorité viennent de `/api/support/tableau-de-bord`. Un clic ouvre Tickets avec le même critère serveur visible et effaçable. Ne jamais calculer un effectif exhaustif depuis les lignes de la page.

Tickets reprend `RegisterSurface`, `SimpleTable`, `DataTableToolbar`, `SearchSelect`, `RegisterSettingsButton` et les préférences `support.tickets`. Le registre propose recherche appliquée, tri, pagination serveur, filtres par responsable, type, catégorie, priorité, statut et période, archives et exports XLSX/CSV. Les exports portent sur les résultats filtrés complets ou la sélection. Les formats et colonnes proviennent du contrat commun ; aucun export de démonstration ni filtrage limité à une page.

Le bouton Réglages reste dans l’en-tête. Il ouvre Tableau et exports ou Références. Références présente l’identité du champ, les catégories effectives, leurs identifiants, le défaut et leurs valeurs. La configuration se modifie dans le référencement central, pas dans une copie locale.

La vue Kanban appelle `/api/support/kanban`. Chaque colonne porte un effectif serveur, un ensemble limité de cartes et un bouton vers la liste complète filtrée. Un nombre de cartes affichées ne représente jamais le nombre total de dossiers. Les cartes ouvrent la fiche par `ID_Support` ; ne pas déplacer arbitrairement une carte entre statuts sans action serveur autorisée.

## Dossier et traitement

Le numéro et Consulter ouvrent la même fiche. `RecordEditorFrame` fournit les commandes de largeur, la fermeture, les protections du brouillon et le retour au focus. La fiche présente Synthèse, Échanges, Résolutions, Documents et Historique.

`SupportEditor` est commun à l’ajout et à la modification. Un dossier complet avec son traitement et sa description utilise une saisie individuelle ; il ne s’agit pas d’un panier de références similaires. Les rubriques sont Demande, Affectation et Objets liés. Les valeurs existantes et la révision doivent être rechargées, y compris celles devenues incompatibles avec une nouvelle catégorie. La création propose les défauts reçus du serveur et respecte `requiredFields`.

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

`frontend/scripts/tests/support.cjs` exécute les helpers et handlers réels avec API/DOM simulés : création, révisions, brouillons, refus, rejeu, critères, pagination, exports, Kanban, indicateurs, messages, téléversement et téléchargements. La compilation Vite vérifie l’intégration à l’application. Ces tests ne remplacent pas une recette visuelle réelle dans le navigateur ni les tests PostgreSQL/API du parcours métier.
