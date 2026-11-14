# Contrats d’interface ERP

Ces contrats reprennent les comportements demandés dans imf_BB et les adaptent aux objets de SauverNdeko. L’état réellement livré et ses limites figurent dans architecture.md.

## 1. Tableaux et filtres

Réutiliser les fonctions communes déjà présentes, puis les faire évoluer sans perdre sélection, recherche, tri, visibilité, gel et largeur des colonnes. Les données métier viennent des vues SQL autorisées. La recherche du registre s’exécute côté serveur avant pagination, pas uniquement sur les lignes chargées.

Ordre des filtres quand applicable : identité/code, période/date, organisation/site autorisé, catégorie/type/produit, statut. Garder les paires début/fin ensemble, labels visibles, actions Appliquer/Rechercher et Réinitialiser proches ; les exports forment un groupe cohérent. Adapter le retour à la ligne au mobile sans changer l’ordre clavier.

Pour les filtres métier catégoriels à choix simple, appliquer le [standard SearchSelect](formulaires-crud.md#sélecteurs-des-filtres-métier-et-références), identique à Licence et Article. La recherche d’une option reste distincte de la recherche serveur du registre. Taille de page, densité et thème relèvent des commandes d’affichage ; une multisélection conserve son contrôle adapté.

Les options génériques proviennent de la source commune referentiel.T_Generique et des API autorisées ; éviter les listes ou tables propres à chaque écran. Après un CRUD de référence réussi, utiliser le hook commun useReferencesRefresh pour actualiser les consommateurs et propager le changement entre onglets de même origine. Revalider au retour du focus, de la visibilité ou à pageshow. À périmètre inchangé, conserver les options affichées pendant la relecture, les choix, filtres et brouillons ; ignorer les réponses périmées et signaler une erreur sans vider la saisie. Ce mécanisme utilise un bus local et BroadcastChannel, avec repli storage ; il ne repose ni sur un polling permanent ni sur des WebSockets et ne promet pas une propagation instantanée entre postes.

Séparer filtres métier et commandes d’affichage : taille de page, tri et colonnes sont dans la barre du tableau. Sous la barre ou le tableau, préciser page et nombre affiché / total filtré. Ignorer les réponses anciennes après changement de contexte.

Garder la grille montée pendant une lecture et conserver les lignes à l’actualisation, avec leurs interactions bloquées jusqu’à la réponse. Prévoir les colonnes dès le premier rendu ; le statut de chargement reste hors du flux pour ne pas déplacer le tableau. Notifier la sélection seulement si ses identifiants changent : un tableau vide recréé ne doit pas entretenir une boucle de rendu.

Un filtre issu d’un KPI apparaît comme une puce ou un champ actif effaçable. Ne pas afficher un sélecteur dont la valeur n’est envoyée à aucune requête. Préserver les valeurs au retour d’une consultation.

Les séparateurs de colonnes sont focusables et exposent leur largeur et leurs bornes. Flèches gauche/droite : −10/+10 px ; Maj : −40/+40 px ; Début (Home) rétablit la largeur automatique. Conserver aussi le redimensionnement au pointeur.

Quand les prix et montants affichent déjà leur code monétaire, la colonne Devise reste optionnelle et décochée initialement, y compris dans les listes des fiches 360. Conserver ensuite les choix de colonnes, sans les réinitialiser lors du rechargement ou du changement de filtre. Ce réglage visuel ne retire jamais le code de devise des exports monétaires CSV/XLSX, où les montants restent séparés de leur devise.

### Dates et heures

- Un événement horodaté s’affiche en français `JJ/MM/AAAA HH:mm`, avec `HH:mm:ss` si les secondes fournies sont utiles à la traçabilité. Ne pas tronquer une heure existante ni déduire le type du seul nom de colonne.
- Une valeur SQL DATE ou une date seule de l’API reste `JJ/MM/AAAA`, sans heure inventée. Une valeur absente reste — ; la règle de présentation ne crée ni colonne ni timestamp manquant.
- Un timestamp SQL sans fuseau conserve son heure métier, indépendamment du fuseau du navigateur. Pour un instant avec `Z` ou un décalage explicite, utiliser `Africa/Kinshasa` et indiquer ce fuseau dans le contexte ; aucune conversion silencieuse.
- Tri et filtres utilisent la valeur brute typée de l’API/SQL, jamais la chaîne française formatée.

Conserver le même grain et le même fuseau dans les exports. Excel garde ses dates natives et les formats `dd/mm/yyyy` ou `dd/mm/yyyy hh:mm` de la [charte Excel existante](../../../../skills/document-mise-en-forme/references/excel.md), avec le fuseau déclaré dans les informations de l’extraction.

## 2. Indicateurs réellement consultables

Pour chaque indicateur, définir avec le backend : clé stable, mesure, unité/devise, période/date, population, exclusions, source, filtre de détail et permission. La même définition produit valeur, total, lignes de détail et export.

| Indicateur cible | Population à exposer | Navigation attendue |
|---|---|---|
| Articles | Articles autorisés selon statut et filtres appliqués | Registre Articles filtré |
| Stock faible / ruptures | Prédicat serveur explicite pour chaque notion | Registre Alertes avec critère visible |
| Commandes sans lignes | V_CommandesSansDetails dans le même périmètre | Registre Commandes avec filtre dédié |
| Factures en retard | Échéance dépassée et reste pertinent selon règle validée | Registre Règlements filtré, puis Facture/Commande 360 |
| Écart de stock | Population ou montant de V_AuditStock selon mesure | Détail des écarts avec unité et source |
| Consommation / couverture | Article et période, sans addition d’unités incompatibles | Détail filtré puis Produit 360 |

Les critères actuels criticalOnly et resteOnly ne prouvent pas respectivement « rupture » et « retard ». Ajouter le contrat exact côté API avant de rendre ces cartes actionnables.

Dans le tableau de bord, la valeur, la carte actionnable et Voir le détail ouvrent le même panneau de liste sous la synthèse, avec Revenir à l’indicateur et fermeture qui restituent le focus et le défilement. Les fiches 360 consultent ensuite un enregistrement précis. Utiliser un bouton/lien sémantique activable au clavier ; Sources et calcul est retiré du tableau de bord et de ses listes à la demande du propriétaire. Si aucun détail fiable n’existe, conserver une mesure informative sans fausse affordance.

Le défilement vers le détail d’un KPI se fait une seule fois par ouverture, après réception initiale ou erreur et mesure de la liste. La pagination, le tri et les filtres ne relancent pas ce défilement.

Les ensembles analytiques de KPI des registres commencent repliés avec Afficher les indicateurs et aria-expanded=false. L’utilisateur peut les ouvrir ; un filtrage ne les ouvre pas implicitement. Les tableaux, graphiques et exports restent utilisables lorsque les KPI sont masqués. Les cartes essentielles de la page de pilotage sont gérées selon son organisation propre.

## 3. Conteneur commun de consultation

Créer un composant réutilisable pour les fiches métier, inspiré de ConsultationDialog et Client360Drawer d’imf_BB.

- En-tête fixe : type d’objet, référence/nom, statut et Fermer.
- Boutons Réduire, Élargir et Rétablir la largeur normale ; largeur initiale de référence 680 px, pas de 160 px et borne haute d’environ 94 % de la fenêtre. Borner aussi la largeur minimale selon l’espace disponible.
- Poignée sur le bord gauche avec capture du pointeur et rôle separator. Flèches gauche/droite : 32 px, Maj : 128 px ; Début/Fin pour les bornes ; double-clic pour rétablir.
- Préférence de largeur distincte des données métier, nommée pour SauverNdeko. Modifier la largeur conserve les rubriques ouvertes et ne relance pas les requêtes.
- À 640 px et moins, pleine largeur, poignée et commandes de largeur masquées, fermeture toujours accessible.
- Modale native dialog ou équivalent accessible, titre relié, focus contenu dans la fenêtre, Échap pour fermer, retour au déclencheur après fermeture. Le fond ne reçoit pas d’interaction active.
- Contenu avec défilement interne ; l’en-tête, les commandes et la fermeture restent accessibles. Garder les largeurs flexibles au zoom.

Le bouton Rétablir modifie uniquement la largeur. Il ne recharge pas les données. Distinguer Recharger lorsqu’une erreur permet une reprise.

Dans un éditeur, conserver le brouillon pendant la confirmation d’abandon et placer le focus sur Continuer ; cette action revient au premier champ du formulaire. Une erreur cible le premier champ invalide de ce formulaire, y compris un sélecteur à recherche. Voir [formulaires-crud.md](formulaires-crud.md).

## 4. Fiches 360 par objet

| Fiche cible | Rubriques utiles | Sources à privilégier |
|---|---|---|
| Produit 360 | Identité, catégorie/type/unité, stock et seuil, prix, péremption, mouvements, commandes liées, consommation/couverture, contrôles | V_Article puis vues logistiques filtrées par ID_Article |
| Commande 360 | Identité/type/statut, dates, tiers, synthèse, lignes, mouvements, facture, règlements et contrôles | V_Commande, V_CommandeDetail, V_Mouvement, V_SuiviReglements |
| Facture / règlement | Référence facture/commande, échéance, total, écritures, reste et état | Vue de suivi et écritures autorisées ; ne pas confondre leur grain |
| Client / fournisseur 360 | Identité de tiers, contacts, commandes, factures, règlements et historique | À définir après le référentiel de tiers ; ID_ClientFk et nom libre ne suffisent pas |

Les rubriques proposées ne permettent pas d’inventer une donnée absente. Afficher Non disponible avec contexte utile si la source manque. Les mutations restent des actions distinctes de Consulter, avec permissions et validation serveur.

Les codes métier et Consulter déclenchent le même contrat d’ouverture. Ne pas rendre un ID technique de remplacement cliquable comme s’il était une référence métier. Les objets liés ouvrent la fiche correspondante et permettent le retour à l’objet précédent sans empiler indéfiniment des modales.

Une ouverture = lecture de l’objet sélectionné. Charger les rubriques lourdes à la demande, avec pagination serveur. Pas d’appel 360 par ligne pour compléter un tableau ; le backend enrichit la page en lot.

## 5. État de navigation et droits

Conserver le contexte d’origine : module, onglet, filtres appliqués, page, sélection, scroll et déclencheur. Fermer restitue ce contexte. Une nouvelle sélection remplace ou ferme proprement l’ancienne ; ignorer les réponses obsolètes.

Changer d’organisation, se déconnecter ou perdre une permission vide les données privées et ferme la fiche devenue hors contexte. L’accès au détail et aux objets liés est vérifié côté API, y compris si l’utilisateur modifie l’URL ou l’identifiant. Aucun menu masqué ne constitue une barrière d’accès.

Dans Dossiers de suivi, une écriture exige à la fois la disponibilité annoncée par le serveur, la permission du compte et le droit d’écriture du module. Appliquer cette condition aux boutons et aux callbacks ; la disponibilité du stockage seule ne donne aucun droit.

Dans Licences et applications, Recharger conserve l’organisation et les choix Licence/Rôle encore valides. Une organisation vide ou une réponse périmée ne doit laisser aucune configuration précédente à l’écran. Avant un changement qui abandonne une saisie, y compris un lien interne ou la déconnexion, proposer une confirmation dans DrawerDialog ; Continuer conserve le brouillon et son contexte. Un simple changement d’onglet conserve les deux brouillons. Pendant l’enregistrement, bloquer les doubles envois et la sortie ; une erreur conserve les valeurs saisies. Les activations restent liées à l’entité, avec les permissions vérifiées par le serveur.

Sélection de ligne, cases, menu, aide et boutons d’écriture ne doivent pas ouvrir la fiche par propagation. Éviter les boutons imbriqués et les interactions accessibles seulement au double-clic.

### Administration et sécurité du compte

Le lien Administration du menu logistique suit canAccessAdmin ; les droits effectifs restent contrôlés par le serveur. Le profil conserve une rubrique Sécurité dont l’action de changement de mot de passe ouvre RecordEditorFrame avec mot de passe actuel, nouveau et confirmation. Conserver les saisies masquées par défaut, les boutons de visibilité accessibles au clavier, les autocomplétions adaptées, la validation de confirmation et la politique serveur de 12 à 128 caractères pour le nouveau secret, sans trim.

Protéger le brouillon et bloquer double envoi et fermeture pendant la sauvegarde. Une erreur de validation reste associée au champ et conserve la saisie ; un mot de passe actuel erroné ne doit pas être traité comme une session expirée. Après succès confirmé, terminer la session locale et revenir à la connexion avec une notice de reconnexion ; le serveur révoque les anciens jetons. Aucun mot de passe dans les journaux, URL, stockage local ou messages d’erreur.

## 6. Sources et calcul, sobriété visuelle

Garder titre court, valeur, devise/unité, date/période et réserve indispensable visibles. À la demande du propriétaire, Sources et calcul est retiré du tableau de bord et de ses listes ; conserver les définitions vérifiées côté serveur et la traçabilité des exports. Une explication absente reste absente ; ne pas inventer un contrôle.

Les tableaux reprennent les surfaces et en-têtes gris lisibles de [DataTable.css](../../../src/components/DataTable.css), les séparateurs fins et le texte contrasté. Employer les tokens de [theme.css](../../../src/theme.css) pour tous les états et thèmes, sans couleur locale ni nouveau style par onglet. Les cartes gardent des bords, espacements et focus cohérents.

Les textes techniques et longues consignes ne prennent pas la place du travail métier. Placer les explications secondaires dans une aide accessible au survol/focus et au clic sur mobile. Une aide ouverte n’actionne pas l’indicateur parent.

## 7. Exports

### Préférences de colonnes et d’export

Pour un registre configuré, réutiliser `useTablePreferences(interfaceKey)` et passer son résultat à `SimpleTable` dans `tablePreferences`. Les identifiants stables du catalogue serveur sont les clés des colonnes ; un libellé ou la position physique d’une colonne SQL ne constitue jamais un identifiant. `tableAvailable=false` réserve un champ à l’export sans le proposer dans le tableau. Les colonnes interactives, dont Actions, ne sont pas exportables.

Placer un seul bouton Réglages dans les actions d’en-tête de `RegisterSurface`, près de Nouveau. `DataTableToolbar` reçoit `showSettings={false}`. `RegisterSettingsButton` ouvre directement le tiroir `TableSettings`, selon le format de Logistique → Dépôts, avec Colonnes du tableau et Options d’export. Le tiroir présente les autres réglages liés au registre, comme Références ou les paramètres de validation, lorsque l’appelant les autorise. La fenêtre du registre financier s’ouvre pour la rubrique active même si les deux registres restent montés. La sélection et l’ordre se règlent par glisser-déposer, boutons Monter/Descendre ou Alt + flèche sur la poignée. Enregistrer et Rétablir la référence s’appliquent à la rubrique active. Conserver l’autre brouillon au changement de rubrique. Pour les tableaux inscrits au catalogue, les préférences personnelles sont enregistrées sur le serveur avec révision, utilisateur authentifié et contexte d’Entité. Pour les tableaux sans catalogue, `SimpleTable` fournit le même tiroir avec des préférences limitées à l’affichage courant. L’option de présentation n’accorde aucun droit d’export.

Les choix d’affichage et d’export ne sont jamais déduits l’un de l’autre. Une nouvelle colonne du catalogue ne doit ni effacer l’ordre choisi ni réactiver une colonne déjà masquée ; le serveur rapproche préférences et catalogue courant. Une réponse d’un autre utilisateur ou d’une Entité précédente est ignorée. En cas d’indisponibilité, conserver une erreur explicite et désactiver l’export configuré ; ne pas restaurer silencieusement une préférence métier depuis localStorage. Les largeurs, densité et thème restent des préférences de présentation distinctes.

Quand une même liste propose Excel et CSV, regrouper les deux formats dans le menu commun `ExportMenu`. Le bouton « Exporter » dans `DataTableToolbar` porte sur les résultats filtrés. Le bouton « Exporter la sélection » dans la barre de sélection porte sur les lignes cochées. Quand seul un format est raccordé, proposer l’accès direct à ce format.

Exporter les résultats filtrés utilise les critères appliqués, le tri et `preferences.exportKeys` sur le serveur, sans take/skip. Exporter la sélection transmet les identifiants des lignes au même exporteur serveur. Le serveur impose les mêmes droits et le même périmètre, contrôle chaque colonne et les identifiants sélectionnés. Ne pas exporter un tableau partiel ou ajouter automatiquement une colonne non sélectionnée. Unité et devise restent disponibles dans le catalogue d’export et pertinentes dans sa référence, mais le fichier suit exactement le choix enregistré.

Excel conserve nombres et dates natives, ainsi que codes/références textuels avec zéros initiaux. Le CSV utilise UTF-8 avec BOM et le séparateur point-virgule, échappe les guillemets et retours à la ligne, et neutralise les formules dans les champs texte. Excel peut interpréter spontanément une référence numérique à l’ouverture directe du CSV : proposer le XLSX pour garantir les zéros initiaux, ou l’importation CSV en colonne Texte. Aucun export ne contient Actions ou des composants JSX.

Distinguer CSV · page / Exporter les lignes affichées et export métier complet. Le périmètre, les critères, colonnes pertinentes et dates sont explicites. Un export complet est produit depuis la source serveur filtrée, pas depuis un tableau limité à 200 lignes.

Les formats annoncés correspondent aux fichiers réellement produits. Le helper HTML/.xls existant n’est pas un fichier XLSX ; l’impression navigateur n’est pas un moteur PDF serveur. Ajouter le format demandé avec un mécanisme partagé avant d’en promettre la disponibilité.

Préparation… désactive les doubles déclenchements, puis télécharge ou expose l’erreur. Un traitement asynchrone n’est utile que si le coût le justifie ; il exige une autorisation au téléchargement, une durée de conservation et un état de reprise. Les données exportées restent dans le même périmètre que le détail autorisé.

## 8. Recette observable des futures implémentations

| Scénario | Résultat attendu |
|---|---|
| Tableau de plus de 200 objets | Valeur KPI et total de détail exhaustifs, sans somme sur la page |
| Clic KPI puis effacement du filtre | Population exacte, filtre visible, retour au registre cohérent |
| Code article / Consulter / recherche | Même Produit 360 et même identifiant autorisé |
| Commande → produit lié → retour | Navigation compréhensible, contexte et focus conservés |
| Modifier largeur, glisser, clavier et rétablir | Bornes respectées, aucune requête ou perte de rubrique |
| Fermer par bouton et Échap | Retour au focus, filtres, page et sélection d’origine |
| Lecture refusée ou source absente | Erreur explicite / indisponibilité, aucune valeur zéro inventée |
| Changement d’organisation ou session | Pas de donnée du contexte précédent ni réponse obsolète |
| Export page et export complet | Nombre de lignes, filtres et format conformes aux libellés |
| 1920, environ 1000 et 390 px ; zoom réel | Pas de débordement global, tableau avec scroll interne, fermeture et actions accessibles |

Le build Vite ne couvre pas ces interactions. Lors de la recette, préciser ce qui est exécuté dans le navigateur, simulé ou seulement relu dans le code. Les critères non couverts dans une recette donnée restent à vérifier ; ne pas confondre recette fictive et écriture métier réelle.
