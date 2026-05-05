# Scénario métier logistique — SauverNdeko

## 1. Objet du module

Le module logistique de SauverNdeko couvre la gestion opérationnelle du stock et de ses flux:

- articles et stock courant ;
- commandes d'entrée et de sortie ;
- lignes de commande ;
- mouvements historiques de stock ;
- règlements liés aux factures ;
- vues de contrôle, d'audit et de pilotage.

Le module repose sur une séparation claire entre:

- les tables métier sources ;
- les vues SQL de lecture ;
- l'interface frontend qui consomme les vues ;
- les règles de cohérence entre stock, commandes, mouvements et paiements.

## 2. Tables métier de référence

### 2.1. `logistique.T_Article`

Cette table représente l'article et son stock courant.

Champs clés:

- `ID_Article`
- `CodeArticleInterne`
- `NomArticle`
- `ID_TypeArticleFk`
- `ID_CategorieArticleFk`
- `ID_UniteFk`
- `QteArticle`
- `QteMinArticle`
- `PUArticle`
- `PVArticle`
- `ValideArticle`
- `DatePeremptionArticle`
- `DateHeureAuto`

Règle métier:

> `QteArticle` est le stock courant officiel affiché par l'application.

### 2.2. `logistique.T_Commande`

Cette table représente l'en-tête de commande.

Champs clés:

- `ID_Commande`
- `ID_TypeCmdFk`
- `ID_StatutCmdFk`
- `ID_ClientFk`
- `ID_UserFk`
- `DateHeureAutoCmd`
- `DateCmd`
- `CodeCmd`
- `RefCmd`
- `MontantHT`
- `MontantTTC`
- `DateHeureAutoFacture`
- `DateFacture`
- `CodeFacture`
- `MontantRegleFacture`
- `MontantResteFacture`
- `StatusFacture`
- `ID_ConditionPaiementFk`
- `DateEcheancePaiement`
- `ID_ModePaiementFk`
- `NomClientSaisi`

Règle métier:

> `T_Commande` ne modifie pas le stock à elle seule. Le stock est impacté par les lignes dans `T_CommandeDetail`.

### 2.3. `logistique.T_CommandeDetail`

Cette table représente les lignes de commande.

Champs clés:

- `ID_CmdFk`
- `ID_ArticleFk`
- `QteCmdDetail`
- `PUCmdDetail`
- `RemiseCmdDetail`
- `LieuCmdDetail`

Règle métier:

> `T_CommandeDetail` déclenche réellement l'effet stock.

Clé primaire:

```sql
("ID_ArticleFk", "ID_CmdFk")
```

Conséquence:

> un même article ne peut apparaître qu'une seule fois dans une même commande.

### 2.4. `logistique.T_Mouvement`

Cette table contient l'historique officiel des mouvements de stock.

Champs clés:

- `ID_Mvt`
- `ID_TypeMvtFk`
- `ID_ArticleFk`
- `ID_cmdFk`
- `DateHeureAutoMvt`
- `DateMvt`
- `QteMvt`
- `PUMvt`

Règles métier:

- `T_Mouvement` est la vérité historique des entrées et sorties ;
- les écritures directes doivent être évitées ;
- le type historique est porté par `ID_TypeMvtFk` ;
- `PUMvt` doit reprendre le prix réel de la ligne source.

### 2.5. `logistique.T_Reglements`

Cette table représente les paiements liés aux factures.

Champs clés:

- `ID_Reglement`
- `CodeFactureFk`
- `ID_ModeReglementFk`
- `ID_ClientFk`
- `DateReglement`
- `MontantRegle`

Règle métier:

> un règlement se rattache à la facture par `CodeFactureFk`.

## 3. Principe central de gestion du stock

Le module applique les règles suivantes:

- `T_Article.QteArticle` stocke l'état courant ;
- `T_Mouvement` conserve la trace historique ;
- `T_CommandeDetail` est l'événement métier qui produit l'effet stock ;
- le sens du stock dépend du type de commande ou du type de mouvement ;
- l'historique ne doit pas être modifié manuellement depuis l'interface.

Règle générale d'impact:

```text
INSERT  = applique l'effet
UPDATE  = annule l'ancien effet puis applique le nouveau
DELETE  = annule l'effet précédent
```

## 4. Sens des commandes et mouvements

Les types de commande et de mouvement sont liés à `referentiel.T_Generique`.

Convention métier:

- `Entrée` = effet positif sur le stock ;
- `Sortie` = effet négatif sur le stock.

Dans les vues SQL, cette logique est notamment portée par:

- `V_Commande` avec `SigneCommande`, `EstCommandeEntree`, `EstCommandeSortie` ;
- `V_MouvementStock` avec le signe stock et la quantité signée.

## 5. Règles métier par table

### 5.1. Articles

- un article peut exister avec ou sans stock initial ;
- la suppression d'un article doit être bloquée s'il est déjà lié à une ligne de commande ou à un mouvement ;
- un article peut être désactivé sans être supprimé ;
- les états affichés côté interface doivent aider à distinguer article actif, stock faible, rupture et état de péremption.

### 5.2. Commandes

- une commande représente une opération logistique globale ;
- une commande d'entrée augmente le stock via ses lignes ;
- une commande de sortie diminue le stock via ses lignes ;
- une commande clôturée ou facturée ne doit plus être modifiée ni supprimée ;
- `DateCmd` est la date métier de commande ;
- `DateFacture` est la date métier de facturation ;
- `DateEcheancePaiement` est la date de référence pour le suivi du retard.

### 5.3. Lignes de commande

- l'ajout d'une ligne applique un impact stock ;
- la modification d'une ligne annule l'ancien effet puis applique le nouveau ;
- la suppression d'une ligne annule son effet stock ;
- si seul le prix change, le stock ne change pas mais le prix historique du mouvement doit rester cohérent ;
- `StockAvantLigneTheorique` et les contrôles de ligne sont exposés par `V_CommandeDetail`.

### 5.4. Mouvements

- les mouvements sont en lecture seule côté interface ;
- aucune action `Ajouter`, `Modifier` ou `Supprimer` ne doit être proposée sur l'écran historique ;
- les champs de date à considérer sont `DateMvt` et `DateHeureAutoMvt` ;
- les mouvements servent à l'audit et au rapprochement avec le stock courant.

### 5.5. Règlements

- les règlements s'appliquent à une facture ;
- `V_SuiviReglements` et `V_Commande` permettent de comparer montant facturé, total réglé et reste ;
- les états attendus côté interface sont au minimum:
  - `Réglée`
  - `Partiellement réglée`
  - `Non réglée`
  - `Non facturée`

## 6. Vues SQL de référence

Le module frontend lit les données d'affichage à partir des vues de `Logistique_View.sql`.

### 6.1. Vues principales

- `logistique.V_Article`
- `logistique.V_Commande`
- `logistique.V_CommandeDetail`
- `logistique.V_Mouvement`
- `logistique.V_MouvementStock`
- `logistique.V_SuiviReglements`

### 6.2. Vues analytiques et dashboard

- `logistique.V_AuditStock`
- `logistique.V_AlertStock`
- `logistique.V_ConsoMensuelle`
- `logistique.V_CouvertureStock`
- `logistique.V_CommandeOverview`
- `logistique.V_CommandesSansDetails`

### 6.3. Répartition par écran

- Tableau de bord:
  - `V_AuditStock`
  - `V_AlertStock`
  - `V_ConsoMensuelle`
  - `V_CouvertureStock`
  - `V_CommandeOverview`
  - `V_CommandesSansDetails`
  - `V_SuiviReglements`
- Articles:
  - `V_Article`
- Commandes:
  - `V_Commande`
- Commande détail:
  - `V_CommandeDetail`
- Historique des mouvements:
  - `V_Mouvement`
- Règlements:
  - `V_SuiviReglements`

Note:

> `V_MouvementStock` reste utile pour les calculs de signe et d'analyse, mais l'écran principal d'historique lit aujourd'hui `V_Mouvement`.

## 7. Points métier importants dans `V_Commande`

`V_Commande` n'est pas une simple projection de table. Elle centralise:

- les informations de commande ;
- les dates automatiques et métier ;
- les informations de facture ;
- les statistiques de lignes ;
- les statistiques de règlements ;
- les contrôles de cohérence des montants.

Champs métier particulièrement importants:

- `DateHeureAutoCmd`
- `DateCmd`
- `DateHeureAutoFacture`
- `DateFacture`
- `DateEcheancePaiement`
- `DernierReglement`
- `NbLignes`
- `NbArticlesDistincts`
- `QteTotale`
- `TotalRegleReel`
- `ResteReel`
- `EtatPaiement`
- `EstPaiementEnRetard`
- `JoursAvantEcheance`
- `EstCommandeSansDetails`
- `EstMontantIncoherent`
- `EtatControleCommande`

Conséquence côté interface:

> le filtre période sur l'écran Commandes doit porter sur la date de commande, et les badges doivent refléter les états calculés par la vue.

## 8. Règles d'interface à respecter

Le frontend logistique doit rester cohérent avec les maquettes validées.

Écrans principaux:

1. Tableau de bord
2. Articles
3. Commandes
4. Commande détail
5. Historique des mouvements
6. Règlements

Règles d'affichage:

- sidebar logistique rétractable ;
- menu actif clairement mis en évidence ;
- cartes blanches, coins arrondis, ombres légères ;
- boutons d'action alignés sur une même ligne autant que possible ;
- tableau comme zone principale de lecture ;
- filtres visibles au-dessus du tableau ;
- pagination simple et lisible ;
- sélection multiple disponible dans les tableaux ;
- historique des mouvements strictement en lecture seule.

## 9. Colonnes attendues par écran

Les colonnes visibles doivent suivre les maquettes, même si les vues SQL exposent plus de champs.

### 9.1. Articles

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

### 9.2. Commandes

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

### 9.3. Commande détail

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

### 9.4. Historique des mouvements

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

### 9.5. Règlements

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

## 10. Filtres métier attendus

Les filtres doivent être adaptés à chaque écran.

Filtres essentiels:

- catégories, types et unités pour les articles ;
- type, statut, paiement et client pour les commandes ;
- commande, article, type et statut pour les lignes ;
- type mouvement, origine, article et commande pour les mouvements ;
- état règlement, retard, client, facture et échéance pour les règlements.

Règle spécifique sur la période:

- sur Commandes, la période filtre `DateCmd` avec une date de début et une date de fin ;
- sur Commande détail, la période filtre `DateCmd` ;
- sur Mouvements, la période filtre `DateMvt` ;
- le filtre période ne doit pas être un simple libellé statique, mais un vrai intervalle de dates.

## 11. Correspondances FK

Le bouton `Correspondances FK` sert à piloter les liens entre certains champs secondaires des tables logistiques et `referentiel.T_Generique`.

Cette logique s'appuie sur `systeme.T_Fk_Correspondance`.

Champs principaux de paramétrage:

- `ModuleName`
- `SchemaName`
- `ViewName`
- `SourceKey`
- `FieldName`
- `MappingType`
- `TargetCategoryIdFk`
- `MappingValue`
- `SettingScope`

La fonctionnalité doit être disponible partout où les champs secondaires se réfèrent à `T_Generique`, notamment pour:

- `T_Article`
  - `ID_TypeArticleFk`
  - `ID_CategorieArticleFk`
  - `ID_UniteFk`
- `T_Commande`
  - `ID_TypeCmdFk`
  - `ID_StatutCmdFk`
  - `ID_ConditionPaiementFk`
  - `ID_ModePaiementFk`
- `T_Mouvement`
  - `ID_TypeMvtFk`
- `T_Reglements`
  - `ID_ModeReglementFk`

## 12. Règles techniques frontend

La logique de lecture des vues dans le frontend doit suivre le principe:

```js
fetchViewData("logistique", "V_Commande", { take: 500 });
```

Règles associées:

- toutes les vues logistiques sont chargées via `fetchViewData` ;
- la limite standard attendue est `take: 500` ;
- les filtres UI doivent être traduits en filtres de vues ;
- les valeurs `BigInt` et les dates doivent être sérialisées correctement côté backend avant affichage.

## 13. Dates automatiques et valeurs générées

Certaines colonnes sont automatiques ou gérées par la base, par exemple:

- `T_Article.DateHeureAuto`
- `T_Commande.DateHeureAutoCmd`
- `T_Commande.DateHeureAutoFacture`
- `T_Mouvement.DateHeureAutoMvt`

Règle de conception:

> lors des opérations d'ajout depuis le frontend, ces valeurs ne doivent pas être forcées artificiellement si la base ou la logique métier les alimente déjà.

Le frontend doit donc:

- envoyer les champs métier utiles ;
- laisser la base enregistrer les dates et valeurs automatiques prévues ;
- réafficher ensuite les valeurs calculées depuis les vues SQL.

## 14. Contrôles métier à maintenir

- ne jamais proposer d'action directe de modification sur l'historique des mouvements ;
- bloquer la suppression d'un article déjà utilisé ;
- bloquer la modification ou suppression d'une commande clôturée ou facturée ;
- afficher des badges cohérents avec les états calculés par les vues ;
- garder le tableau comme source principale de lecture ;
- privilégier les vues SQL comme source d'affichage plutôt qu'une reconstruction frontend.

## 15. Résultat attendu

Le module logistique doit fournir:

- une lecture claire du stock courant ;
- une traçabilité fiable des mouvements ;
- un suivi lisible des commandes ;
- un contrôle des incohérences de montants et de détails ;
- un suivi des paiements et des retards ;
- une interface frontend cohérente avec les maquettes et fidèle aux vues SQL existantes.
