# Scénario métier du module Logistique — SauverNdeko

## 1. Contexte général

Le module **Logistique** de SauverNdeko assure la gestion des articles, des commandes, des détails de commande et des mouvements de stock.

Il repose principalement sur les tables suivantes :

```text
logistique.T_Article
logistique.T_Commande
logistique.T_CommandeDetail
logistique.T_Mouvement
referentiel.T_Generique
```

La table `referentiel.T_Generique` sert de référentiel pour identifier les types de commandes et les types de mouvements.

Les deux types principaux utilisés dans la logique de stock sont :

```text
AbrGenerique = 'Entrée'
AbrGenerique = 'Sortie'
```

La clé primaire `ID_Generique` de `referentiel.T_Generique` est utilisée comme référence dans :

```text
T_Commande.ID_TypeCmdFk
T_Mouvement.ID_TypeMvtFk
```

Le principe général est le suivant :

```text
T_Article contient le stock courant.
T_Mouvement contient l’historique des mouvements.
T_Commande représente l’opération logistique.
T_CommandeDetail représente les articles concernés par la commande.
```

Toute variation de stock doit donc être répercutée dans `T_Article.QteArticle` et tracée dans `T_Mouvement`.

---

## 2. Principe métier central

Le stock courant d’un article est porté par :

```text
logistique.T_Article.QteArticle
```

L’historique des mouvements est porté par :

```text
logistique.T_Mouvement
```

Chaque mouvement doit permettre d’identifier :

- le type de mouvement ;
- l’article concerné ;
- la commande concernée, si le mouvement provient d’une commande ;
- la quantité mouvementée ;
- le prix unitaire du mouvement ;
- la date du mouvement.

Les mouvements sont principalement de deux types :

```text
Entrée : augmentation de stock
Sortie : diminution de stock
```

---

## 3. Règle générale officielle

La logique métier du module Logistique repose sur la règle suivante :

```text
INSERT applique l’effet.
DELETE annule l’effet.
UPDATE annule l’ancien effet puis applique le nouveau.
```

Cela signifie :

```text
Une entrée augmente le stock.
Une suppression d’entrée diminue le stock.

Une sortie diminue le stock.
Une suppression de sortie augmente le stock.

Une modification annule l’ancienne opération puis applique la nouvelle.
```

---

## 4. Gestion des articles — T_Article

### 4.1 Création d’un article avec quantité nulle

Lorsqu’un article est créé avec :

```text
QteArticle = 0
```

l’article est créé dans `T_Article`, mais aucun mouvement ne doit être créé dans `T_Mouvement`.

Résultat attendu :

```text
Article créé.
QteArticle = 0.
Aucun mouvement créé.
```

---

### 4.2 Création d’un article avec quantité supérieure à zéro

Lorsqu’un article est créé avec :

```text
QteArticle > 0
```

un mouvement de rapport initial doit être créé dans `T_Mouvement`.

Ce mouvement représente une entrée initiale de stock.

Le mouvement doit respecter les règles suivantes :

```text
ID_TypeMvtFk = ID_Generique correspondant à AbrGenerique = 'Entrée'
ID_ArticleFk = article créé
QteMvt = quantité initiale de l’article
```

Exemple :

```text
Création article : Gants médicaux
QteArticle = 100
```

Résultat attendu :

```text
T_Article.QteArticle = 100
T_Mouvement.QteMvt = 100
T_Mouvement.ID_TypeMvtFk = type Entrée
```

---

### 4.3 Modification directe de la quantité d’un article

Lorsqu’on modifie directement `QteArticle`, le système doit comparer l’ancienne quantité et la nouvelle quantité.

La différence est calculée ainsi :

```text
delta = nouvelle quantité - ancienne quantité
```

#### Cas 1 : augmentation du stock

Si :

```text
delta > 0
```

il s’agit d’une entrée de stock.

Le système doit créer un mouvement dans `T_Mouvement` avec :

```text
ID_TypeMvtFk = ID_Generique correspondant à AbrGenerique = 'Entrée'
QteMvt = delta
```

Exemple :

```text
Ancienne quantité : 100
Nouvelle quantité : 130
Delta : +30
```

Résultat attendu :

```text
Créer un mouvement Entrée de 30.
```

---

#### Cas 2 : diminution du stock

Si :

```text
delta < 0
```

il s’agit d’une sortie de stock.

Le système doit créer un mouvement dans `T_Mouvement` avec :

```text
ID_TypeMvtFk = ID_Generique correspondant à AbrGenerique = 'Sortie'
QteMvt = valeur absolue du delta
```

Exemple :

```text
Ancienne quantité : 130
Nouvelle quantité : 90
Delta : -40
```

Résultat attendu :

```text
Créer un mouvement Sortie de 40.
```

---

#### Cas 3 : quantité inchangée

Si :

```text
delta = 0
```

aucun mouvement ne doit être créé.

---

### 4.4 Validation des quantités dans T_Article

Il est interdit d’enregistrer dans `T_Article` :

- une quantité vide ;
- une quantité inférieure à zéro.

Donc :

```text
QteArticle ne doit pas être NULL.
QteArticle ne doit pas être négative.
```

Toute tentative d’enregistrement d’une quantité invalide doit être bloquée.

---

### 4.5 Suppression d’un article

Il est interdit de supprimer un article s’il est déjà utilisé dans :

```text
T_CommandeDetail
T_Mouvement
```

Cela signifie :

```text
Si l’article est lié à une ligne de commande, la suppression est interdite.
Si l’article est lié à un mouvement de stock, la suppression est interdite.
```

Cette règle protège l’historique logistique et évite la perte de traçabilité.

---

## 5. Gestion des commandes — T_Commande

### 5.1 Création d’une commande

Une commande est créée dans `T_Commande`.

Son type est défini par :

```text
ID_TypeCmdFk
```

Ce champ doit correspondre à :

```text
referentiel.T_Generique.ID_Generique
```

Les deux types principaux utilisés pour le stock sont :

```text
Entrée
Sortie
```

Si `ID_TypeCmdFk` correspond à `AbrGenerique = 'Entrée'`, la commande est une commande d’entrée.

Si `ID_TypeCmdFk` correspond à `AbrGenerique = 'Sortie'`, la commande est une commande de sortie.

---

### 5.2 Commande de type Entrée

Une commande est considérée comme une commande d’entrée lorsque :

```text
T_Commande.ID_TypeCmdFk correspond à AbrGenerique = 'Entrée'
```

Les lignes de cette commande doivent augmenter le stock.

---

### 5.3 Commande de type Sortie

Une commande est considérée comme une commande de sortie lorsque :

```text
T_Commande.ID_TypeCmdFk correspond à AbrGenerique = 'Sortie'
```

Les lignes de cette commande doivent diminuer le stock.

---

### 5.4 Suppression d’une commande

Lorsqu’une commande est supprimée dans `T_Commande`, toutes les lignes liées à cette commande doivent être supprimées dans `T_CommandeDetail`.

Chaque suppression de ligne doit annuler l’effet initialement produit par cette ligne sur le stock.

La suppression d’une commande doit donc se comporter ainsi :

```text
Commande Entrée supprimée :
- les lignes de détail sont supprimées ;
- le stock est diminué des quantités qui avaient été ajoutées ;
- les mouvements liés sont supprimés ou neutralisés.

Commande Sortie supprimée :
- les lignes de détail sont supprimées ;
- le stock est augmenté des quantités qui avaient été sorties ;
- les mouvements liés sont supprimés ou neutralisés.
```

Résumé :

```text
DELETE commande Entrée → annuler l’entrée → stock -
DELETE commande Sortie → annuler la sortie → stock +
```

---

## 6. Gestion des détails de commande — T_CommandeDetail

### 6.1 Création d’une ligne de commande

Lorsqu’une ligne est créée dans `T_CommandeDetail`, le système doit :

1. identifier la commande liée ;
2. récupérer `ID_TypeCmdFk` depuis `T_Commande` ;
3. retrouver `AbrGenerique` dans `referentiel.T_Generique` ;
4. appliquer l’effet sur `T_Article.QteArticle` ;
5. créer le mouvement correspondant dans `T_Mouvement`.

---

### 6.2 Ligne de commande de type Entrée

Si la commande est de type **Entrée**, alors :

```text
T_Article.QteArticle = T_Article.QteArticle + T_CommandeDetail.QteCmdDetail
```

Un mouvement doit être créé dans `T_Mouvement` avec :

```text
ID_TypeMvtFk = ID_TypeCmdFk de la commande
ID_ArticleFk = article concerné
ID_CmdFk = commande concernée
QteMvt = quantité de la ligne
```

---

### 6.3 Ligne de commande de type Sortie

Si la commande est de type **Sortie**, alors :

```text
T_Article.QteArticle = T_Article.QteArticle - T_CommandeDetail.QteCmdDetail
```

Un mouvement doit être créé dans `T_Mouvement` avec :

```text
ID_TypeMvtFk = ID_TypeCmdFk de la commande
ID_ArticleFk = article concerné
ID_CmdFk = commande concernée
QteMvt = quantité de la ligne
```

Une sortie ne doit pas faire passer le stock en dessous de zéro.

---

### 6.4 Modification d’une ligne de commande

Lorsqu’une ligne de commande est modifiée, le système ne doit pas appliquer directement la nouvelle quantité sans tenir compte de l’ancienne.

Il faut appliquer la règle suivante :

```text
1. Annuler l’effet de l’ancienne ligne.
2. Supprimer ou neutraliser l’ancien mouvement.
3. Appliquer l’effet de la nouvelle ligne.
4. Créer ou mettre à jour le nouveau mouvement.
```

Exemple : modification d’une ligne Sortie.

Ancienne ligne :

```text
Sortie de 10
```

Nouvelle ligne :

```text
Sortie de 15
```

Traitement attendu :

```text
Annuler ancienne sortie de 10 → stock +10
Appliquer nouvelle sortie de 15 → stock -15
Effet net → stock -5
```

Le mouvement final doit représenter la nouvelle quantité :

```text
QteMvt = 15
```

---

### 6.5 Suppression d’une ligne de commande

Lorsqu’une ligne est supprimée dans `T_CommandeDetail`, le système doit annuler l’effet initial de cette ligne.

#### Suppression d’une ligne Entrée

Une ligne d’entrée avait ajouté du stock.

Sa suppression doit donc diminuer le stock :

```text
stock - QteCmdDetail
```

Le mouvement lié doit être supprimé ou neutralisé.

#### Suppression d’une ligne Sortie

Une ligne de sortie avait retiré du stock.

Sa suppression doit donc restituer le stock :

```text
stock + QteCmdDetail
```

Le mouvement lié doit être supprimé ou neutralisé.

---

## 7. Critère de correspondance dans T_Mouvement

Pour retrouver correctement le mouvement lié à une commande et à un article, le système doit utiliser la combinaison suivante :

```text
ID_TypeMvtFk
ID_ArticleFk
ID_CmdFk
```

Ce critère est obligatoire pour éviter de modifier ou supprimer un mouvement qui ne correspond pas à la ligne concernée.

Exemple de filtre attendu :

```sql
WHERE "ID_TypeMvtFk" = v_id_type_mvt
  AND "ID_ArticleFk" = v_id_article
  AND "ID_cmdFk" = v_id_commande
```

Il ne faut pas retrouver un mouvement uniquement par :

```text
ID_ArticleFk
```

ou uniquement par :

```text
ID_CmdFk
```

---

## 8. Règle anti-doublon

Le système doit éviter les mouvements doublons.

Lorsqu’une ligne de `T_CommandeDetail` modifie le stock dans `T_Article`, cette modification ne doit pas créer un mouvement de rapport supplémentaire venant du CRUD direct de `T_Article`.

Donc :

```text
Modification directe de T_Article
→ créer un mouvement de rapport.

Modification de T_Article provoquée par T_CommandeDetail
→ ne pas créer de mouvement de rapport supplémentaire.
→ seul le mouvement de commande doit être créé.
```

Cette règle est essentielle pour garder `T_Mouvement` cohérente.

---

## 9. Synthèse des effets attendus

### 9.1 Effets de T_Article

| Opération | Condition          |           Effet stock | Effet mouvement  |
| --------- | ------------------ | --------------------: | ---------------- |
| INSERT    | `QteArticle = 0`   |    stock initial zéro | aucun mouvement  |
| INSERT    | `QteArticle > 0`   | stock initial positif | mouvement Entrée |
| UPDATE    | quantité augmente  |        stock augmenté | mouvement Entrée |
| UPDATE    | quantité diminue   |         stock diminué | mouvement Sortie |
| UPDATE    | quantité inchangée |           aucun effet | aucun mouvement  |
| DELETE    | article lié        |              interdit | aucun            |

---

### 9.2 Effets de T_CommandeDetail

| Opération | Type commande    |                                 Effet stock | Effet mouvement                     |
| --------- | ---------------- | ------------------------------------------: | ----------------------------------- |
| INSERT    | Entrée           |                            stock + quantité | créer mouvement Entrée              |
| INSERT    | Sortie           |                            stock - quantité | créer mouvement Sortie              |
| UPDATE    | Entrée ou Sortie | annuler ancien effet puis appliquer nouveau | remplacer / mettre à jour mouvement |
| DELETE    | Entrée           |                            stock - quantité | supprimer / neutraliser mouvement   |
| DELETE    | Sortie           |                            stock + quantité | supprimer / neutraliser mouvement   |

---

### 9.3 Effets de T_Commande

| Opération | Effet attendu                                                                                  |
| --------- | ---------------------------------------------------------------------------------------------- |
| INSERT    | création de l’entête de commande                                                               |
| UPDATE    | modification de l’entête sans casser la cohérence stock/mouvement                              |
| DELETE    | suppression des détails, annulation du stock, suppression / neutralisation des mouvements liés |

---

## 10. Critères d’acceptation

Le scénario est correctement respecté si :

1. la création d’un article avec `QteArticle > 0` crée un mouvement Entrée ;
2. l’augmentation directe de `QteArticle` crée un mouvement Entrée du delta ;
3. la diminution directe de `QteArticle` crée un mouvement Sortie du delta absolu ;
4. une quantité vide ou négative est refusée ;
5. un article lié à `T_CommandeDetail` ou `T_Mouvement` ne peut pas être supprimé ;
6. une ligne de commande Entrée augmente le stock ;
7. une ligne de commande Sortie diminue le stock ;
8. la modification d’une ligne annule l’ancien effet et applique le nouveau ;
9. la suppression d’une ligne Entrée diminue le stock ;
10. la suppression d’une ligne Sortie augmente le stock ;
11. la suppression d’une commande supprime ses détails et annule leurs effets sur le stock ;
12. les mouvements liés sont retrouvés avec `ID_TypeMvtFk + ID_ArticleFk + ID_CmdFk` ;
13. aucun mouvement doublon n’est créé ;
14. le stock courant dans `T_Article` reste cohérent avec l’historique dans `T_Mouvement`.

---

## 11. Version courte officielle

```text
T_Article gère le stock courant et les ajustements directs.

T_Commande représente l’opération logistique.

T_CommandeDetail applique l’effet de la commande sur les articles.

T_Mouvement conserve l’historique des mouvements.

Une entrée augmente le stock.
Une sortie diminue le stock.

INSERT applique l’effet.
DELETE annule l’effet.
UPDATE annule l’ancien effet puis applique le nouveau.

Un mouvement lié à une commande est identifié par :
ID_TypeMvtFk + ID_ArticleFk + ID_CmdFk.

## 12. Ordre d'execution recommande du schema logistique

1. Schemas + tables + cles etrangeres
2. T_Article_PS_TR_CRUD_vf.sql
   Contient `ps_update_qte_article`, `ps_crud_article` et `tr_crud_article`
3. T_Commande_PS_TR_CRUD_vf.sql
   Contient `ps_crud_commande`, `tr_crud_commande` et `tr_delete_commande`
4. T_CommandeDetail_PS_TR_CRUD_vf.sql
   Contient `ps_crud_commandeDetail` et `tr_crud_commandeDetail`
5. PS_TR_Audit_Stock.sql
   Contient les outils annexes: verrou intelligent de `T_Mouvement`, recalcul des totaux, audits et vues analytiques
6. Logistique_View.sql
   Contient les vues de lecture du module
7. Logistique_Test.sql
   Verifie le scenario metier officiel
8. Logistique_Test_view.sql
   Verifie les vues et tableaux de bord

Rappels metier importants

- `T_Article` porte le stock courant.
- `T_Mouvement` porte l'historique.
- `INSERT applique l'effet`.
- `DELETE annule l'effet`.
- `UPDATE annule l'ancien effet puis applique le nouveau`.
- `T_Mouvement` ne doit jamais etre modifie directement hors logique metier.
- Les mouvements de commande sont identifies par `ID_TypeMvtFk + ID_ArticleFk + ID_cmdFk`.
- Les modifications de `T_Article` provoquees par `T_CommandeDetail` ne doivent pas creer de mouvement de rapport supplementaire.
```
