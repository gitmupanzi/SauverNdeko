# Contrats d’interface ERP

Ces contrats reprennent les comportements demandés dans imf_BB et les adaptent aux objets de SauverNdeko. L’état réellement livré et ses limites figurent dans architecture.md.

## 1. Tableaux et filtres

Réutiliser les fonctions communes déjà présentes, puis les faire évoluer sans perdre sélection, recherche, tri, visibilité, gel et largeur des colonnes. Les données métier viennent des vues SQL autorisées. La recherche du registre s’exécute côté serveur avant pagination, pas uniquement sur les lignes chargées.

Ordre des filtres quand applicable : identité/code, période/date, organisation/site autorisé, catégorie/type/produit, statut. Garder les paires début/fin ensemble, labels visibles, actions Appliquer/Rechercher et Réinitialiser proches ; les exports forment un groupe cohérent. Adapter le retour à la ligne au mobile sans changer l’ordre clavier.

Séparer filtres métier et commandes d’affichage : taille de page, tri et colonnes sont dans la barre du tableau. Sous la barre ou le tableau, préciser page et nombre affiché / total filtré. Conserver les lignes pendant un changement de page si possible avec état d’actualisation ; ignorer les réponses anciennes après changement de contexte.

Un filtre issu d’un KPI apparaît comme une puce ou un champ actif effaçable. Ne pas afficher un sélecteur dont la valeur n’est envoyée à aucune requête. Préserver les valeurs au retour d’une consultation.

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

Sélection de ligne, cases, menu, aide et boutons d’écriture ne doivent pas ouvrir la fiche par propagation. Éviter les boutons imbriqués et les interactions accessibles seulement au double-clic.

## 6. Sources et calcul, sobriété visuelle

Garder titre court, valeur, devise/unité, date/période et réserve indispensable visibles. À la demande du propriétaire, Sources et calcul est retiré du tableau de bord et de ses listes ; conserver les définitions vérifiées côté serveur et la traçabilité des exports. Une explication absente reste absente ; ne pas inventer un contrôle.

Repères visuels repris d’imf_BB : bandeaux principaux foncés à texte blanc ; sous-blocs repliables vert très clair #f2f7f5, texte #184f49, survol #e8f2ee, avec adaptation à la charte SauverNdeko. Centraliser ces tokens/styles. Les cartes gardent des bords, espacements et focus cohérents.

Les textes techniques et longues consignes ne prennent pas la place du travail métier. Placer les explications secondaires dans une aide accessible au survol/focus et au clic sur mobile. Une aide ouverte n’actionne pas l’indicateur parent.

## 7. Exports

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
