# Scénario métier logistique — SauverNdeko

## 1. Objectif du module

Le module logistique de SauverNdeko permet de gérer :

- les articles ou produits disponibles ;
- les commandes d’entrée et de sortie ;
- les lignes de commande ;
- les mouvements de stock ;
- les règlements liés aux factures ;
- les vues de contrôle et d’audit.

La logique métier doit garantir que le stock courant affiché dans `logistique.T_Article` reste cohérent avec l’historique des mouvements enregistré dans `logistique.T_Mouvement`.

---

## 2. Tables principales

### 2.1. `logistique.T_Article`

Cette table représente le stock courant.

Rôle principal :

- stocker l’article ;
- stocker la quantité courante disponible ;
- stocker les prix de référence ;
- stocker les informations de classification et d’unité.

Colonnes importantes :

- `ID_Article`
- `NomArticle`
- `CodeArticleInterne`
- `ID_TypeArticleFk`
- `ID_CategorieArticleFk`
- `ID_UniteFk`
- `QteArticle`
- `QteMinArticle`
- `PUArticle`
- `PVArticle`

Règle métier :

> `QteArticle` est le stock courant officiel.

---

### 2.2. `logistique.T_Commande`

Cette table représente l’en-tête d’une opération logistique.

Une commande peut être :

- une entrée de stock ;
- une sortie de stock.

Colonnes importantes :

- `ID_Commande`
- `ID_TypeCmdFk`
- `ID_StatutCmdFk`
- `ID_ClientFk`
- `ID_UserFk`
- `DateCmd`
- `CodeCmd`
- `CodeFacture`
- `MontantHT`
- `MontantTTC`
- `StatusFacture`
- `ID_ConditionPaiementFk`
- `ID_ModePaiementFk`
- `NomClientSaisi`

Règle métier :

> Le type de commande détermine le sens du stock : entrée ou sortie.

---

### 2.3. `logistique.T_CommandeDetail`

Cette table contient les lignes de commande.

Elle relie une commande à un article.

Colonnes importantes :

- `ID_CmdFk`
- `ID_ArticleFk`
- `QteCmdDetail`
- `PUCmdDetail`
- `ObsCmdDetail`
- `RemiseCmdDetail`
- `LieuCmdDetail`

Règle métier :

> `T_CommandeDetail` pilote réellement l’impact sur le stock.

La clé primaire est composée de :

```sql
("ID_ArticleFk", "ID_CmdFk")
```

Conséquence :

> Un même article ne peut pas apparaître deux fois dans une même commande.

---

### 2.4. `logistique.T_Mouvement`

Cette table représente l’historique officiel des mouvements de stock.

Colonnes importantes :

- `ID_Mvt`
- `ID_TypeMvtFk`
- `ID_ArticleFk`
- `ID_cmdFk`
- `DateMvt`
- `QteMvt`
- `PUMvt`

Règles métier :

- `T_Mouvement` est alimentée automatiquement par la logique métier.
- Les écritures directes sont interdites.
- `QteMvt` reste de type `integer`.
- `ID_TypeMvtFk` est la vérité historique du mouvement.
- `PUMvt` doit reprendre le prix réel saisi dans `T_CommandeDetail.PUCmdDetail`.

---

### 2.5. `logistique.T_Reglements`

Cette table représente les paiements liés aux factures.

Colonnes importantes :

- `ID_Reglement`
- `CodeFactureFk`
- `ID_ModeReglementFk`
- `ID_ClientFk`
- `DateReglement`
- `MontantRegle`

Règle métier :

> Le règlement est rattaché à une facture par `CodeFactureFk`.

---

## 3. Principe central du stock

Le stock courant est stocké dans :

```sql
logistique."T_Article"."QteArticle"
```

L’historique du stock est stocké dans :

```sql
logistique."T_Mouvement"
```

La règle générale est :

```text
INSERT applique l’effet.
DELETE annule l’effet.
UPDATE annule l’ancien effet puis applique le nouveau.
```

---

## 4. Sens des mouvements

Les types de mouvement et de commande sont stockés dans :

```sql
referentiel."T_Generique"
```

La catégorie utilisée pour les entrées et sorties est :

```text
ID_CategorieGeneriqueFk = 64
```

Règle de signe :

| Type   |  Effet stock |
| ------ | -----------: |
| Entrée | `+ quantité` |
| Sortie | `- quantité` |

La reconnaissance du type se fait par `AbrGenerique` :

```text
Entrée : AbrGenerique commence par entr
Sortie : AbrGenerique commence par sort
```

---

## 5. Règles sur les articles

### 5.1. Création d’un article

Si un article est créé avec `QteArticle > 0`, alors un mouvement d’entrée de rapport est créé automatiquement.

Exemple :

```text
Création article A avec QteArticle = 10
=> Stock article = 10
=> Mouvement entrée = 10
```

### 5.2. Modification directe du stock d’un article

Si `QteArticle` est modifié directement :

- une augmentation crée un mouvement d’entrée ;
- une diminution crée un mouvement de sortie.

Exemple :

```text
Ancien stock = 10
Nouveau stock = 15
Delta = +5
=> Mouvement entrée = 5
```

Exemple :

```text
Ancien stock = 15
Nouveau stock = 8
Delta = -7
=> Mouvement sortie = 7
```

### 5.3. Suppression d’un article

La suppression d’un article est interdite si l’article est lié à :

- `T_CommandeDetail` ;
- `T_Mouvement`.

---

## 6. Règles sur les commandes

### 6.1. Création d’une commande

La création d’une commande ne modifie pas directement le stock.

Le stock est modifié uniquement quand une ligne est ajoutée dans :

```sql
logistique."T_CommandeDetail"
```

### 6.2. Modification du type de commande

Si `ID_TypeCmdFk` change, il faut réaligner :

- le stock courant dans `T_Article` ;
- le type historique dans `T_Mouvement`.

Règle :

```text
Ancien type Entrée : annulation = stock -
Ancien type Sortie : annulation = stock +
Nouveau type Entrée : application = stock +
Nouveau type Sortie : application = stock -
```

Exemple :

```text
Stock initial = 100
Commande initiale = Entrée de 10
Stock après commande = 110

La commande passe de Entrée à Sortie.

Annuler l’ancienne entrée : -10
Appliquer la nouvelle sortie : -10

Stock final = 90
```

### 6.3. Commande clôturée

Une commande clôturée ou facturée ne doit plus être modifiée ni supprimée.

Règle :

```text
Si StatusFacture = Clôturée
=> modification interdite
=> suppression interdite
```

---

## 7. Règles sur les lignes de commande

### 7.1. Insertion d’une ligne de commande

Lorsqu’une ligne est insérée dans `T_CommandeDetail` :

1. la quantité est validée ;
2. le type de commande est identifié ;
3. le stock de l’article est modifié ;
4. un mouvement est créé dans `T_Mouvement`.

Exemple entrée :

```text
Commande Entrée
Article A
Quantité = 5

=> Stock Article A +5
=> Mouvement Entrée 5
```

Exemple sortie :

```text
Commande Sortie
Article A
Quantité = 3

=> Stock Article A -3
=> Mouvement Sortie 3
```

---

### 7.2. Modification d’une ligne de commande

Lorsqu’une ligne de commande est modifiée :

1. l’ancien effet est annulé ;
2. l’ancien mouvement est supprimé ;
3. le nouvel effet est appliqué ;
4. un nouveau mouvement est créé.

Exemple :

```text
Commande Sortie
Ancienne quantité = 3
Nouvelle quantité = 5

Annuler ancienne sortie : stock +3
Appliquer nouvelle sortie : stock -5
Effet net : stock -2
```

Si seul `PUCmdDetail` change :

- le stock ne change pas ;
- `T_Mouvement.PUMvt` est mis à jour.

---

### 7.3. Suppression d’une ligne de commande

Lorsqu’une ligne de commande est supprimée :

1. l’effet stock de cette ligne est annulé ;
2. le mouvement correspondant est supprimé.

Exemple sortie :

```text
Commande Sortie
Article A
Quantité = 4

Suppression de la ligne
=> Annulation sortie : stock +4
=> Suppression du mouvement
```

---

## 8. Prix des mouvements

Le prix stocké dans `T_Mouvement.PUMvt` doit provenir de :

```sql
logistique."T_CommandeDetail"."PUCmdDetail"
```

Il ne doit pas être recalculé à partir de `T_Article.PVArticle`.

Justification :

- le prix peut changer selon la commande ;
- le prix peut être négocié ;
- une remise peut être appliquée ;
- l’historique doit garder le prix réellement utilisé.

---

## 9. Quantités

### 9.1. Stock courant

Le stock courant dans `T_Article.QteArticle` est de type :

```sql
numeric(14,3)
```

### 9.2. Mouvement historique

La quantité de mouvement dans `T_Mouvement.QteMvt` est de type :

```sql
integer
```

Conséquence :

> Les mouvements historisés doivent avoir des quantités entières.

Les quantités fractionnaires sont bloquées au moment de créer ou modifier les mouvements.

---

## 10. Protection de `T_Mouvement`

Les écritures directes dans `T_Mouvement` sont interdites.

Cela concerne :

- `INSERT`
- `UPDATE`
- `DELETE`

La table ne peut être modifiée que par la logique métier interne.

Objectif :

> éviter les écarts entre le stock courant et l’historique.

---

## 11. Vues métier et analytiques

### 11.1. Principe

Les vues analytiques doivent considérer que :

```sql
logistique."T_Mouvement"."ID_TypeMvtFk"
```

est la vérité historique du type de mouvement.

Elles ne doivent pas recalculer le sens d’un mouvement à partir de :

```sql
logistique."T_Commande"."ID_TypeCmdFk"
```

### 11.2. Vue `V_MouvementStock`

Cette vue calcule :

- le type de mouvement ;
- le signe du stock ;
- la quantité signée.

Règle :

```text
Entrée => signe +1
Sortie => signe -1
Autre => signe 0
```

### 11.3. Vue `V_AuditStock`

Cette vue compare :

```text
Stock enregistré dans T_Article
versus
Stock calculé depuis T_Mouvement
```

Objectif :

> détecter rapidement les écarts de stock.

---

## 12. Cas de test attendus

### Test 1 — Création article avec stock initial

```text
Créer article A avec QteArticle = 10
Attendu :
- T_Article.QteArticle = 10
- T_Mouvement contient une entrée de 10
```

### Test 2 — Entrée de stock par commande

```text
Stock initial = 10
Commande Entrée de 5
Attendu :
- stock final = 15
- mouvement entrée = 5
```

### Test 3 — Sortie de stock par commande

```text
Stock initial = 15
Commande Sortie de 4
Attendu :
- stock final = 11
- mouvement sortie = 4
```

### Test 4 — Modification quantité détail

```text
Stock initial après sortie de 4 = 11
Modifier quantité sortie de 4 à 6

Attendu :
- annulation ancienne sortie : +4
- application nouvelle sortie : -6
- stock final = 9
```

### Test 5 — Changement type commande Entrée vers Sortie

```text
Stock initial = 100
Commande Entrée de 10
Stock = 110

Changer le type en Sortie

Attendu :
- annulation entrée : -10
- application sortie : -10
- stock final = 90
- mouvement devient Sortie
```

### Test 6 — Changement type commande Sortie vers Entrée

```text
Stock initial = 100
Commande Sortie de 10
Stock = 90

Changer le type en Entrée

Attendu :
- annulation sortie : +10
- application entrée : +10
- stock final = 110
- mouvement devient Entrée
```

### Test 7 — Modification du prix uniquement

```text
Commande Sortie
Article A
Quantité = 5
Ancien PU = 10
Nouveau PU = 12

Attendu :
- stock inchangé
- T_Mouvement.PUMvt = 12
- totaux commande recalculés
```

### Test 8 — Audit stock

```text
SELECT *
FROM logistique."V_AuditStock"
WHERE "Ecart" <> 0;
```

Attendu :

```text
Aucune ligne si le stock est cohérent.
```

---

## 13. Résumé de la logique validée

```text
T_Article = stock courant.
T_Mouvement = historique officiel.
T_Commande = en-tête métier.
T_CommandeDetail = déclencheur réel du stock.
T_Reglements = paiements.
```

Règle centrale :

```text
INSERT applique.
DELETE annule.
UPDATE annule l’ancien effet puis applique le nouveau.
```

Règle analytique :

```text
Les vues lisent l’historique dans T_Mouvement.
Elles ne réinterprètent pas les mouvements à partir de T_Commande.
```

Règle de sécurité :

```text
Pas d’écriture directe sur T_Mouvement.
Pas de stock négatif.
Pas de mouvement fractionnaire.
Pas de modification d’une commande clôturée.
```
