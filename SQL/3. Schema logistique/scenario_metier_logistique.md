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

### 4.6 Utilisateur auteur automatique

Lors de la creation d'un article depuis l'application, le champ :

```text
T_Article.ID_UserFK
```

doit etre renseigne automatiquement avec l'identifiant de l'utilisateur actuellement authentifie dans le systeme.

Regles attendues :

```text
Le frontend affiche le nom de l'utilisateur connecte.
Le frontend ne doit pas laisser modifier manuellement ce champ lors de la creation.
Le backend doit forcer la valeur finale avec l'identifiant issu de la session authentifiee.
```

En consequence :

```text
La valeur envoyee par le client n'est pas une source de verite suffisante.
La source de verite est l'utilisateur authentifie sur la requete.
```

Critere d'acceptation :

```text
Un article cree depuis l'interface est toujours rattache a l'utilisateur connecte, meme si le client tente d'envoyer un autre ID utilisateur.
```

---

### 4.7 Gestion de la peremption et de l'alerte

Le module logistique doit gerer les champs suivants de `T_Article` :

```text
DatePeremptionArticle
DatePeremptionAlerteArticle
NbreJoursAlerteArticle
```

Le comportement metier attendu est le suivant :

```text
L'utilisateur saisit la date de peremption.
L'utilisateur saisit le nombre de jours d'alerte.
La date d'alerte de peremption est calculee automatiquement.
```

Formule officielle :

```text
DatePeremptionAlerteArticle = DatePeremptionArticle - NbreJoursAlerteArticle
```

Le calcul inverse doit aussi rester coherent :

```text
NbreJoursAlerteArticle = DatePeremptionArticle - DatePeremptionAlerteArticle
```

Contraintes metier :

```text
NbreJoursAlerteArticle doit etre un entier positif ou nul.
DatePeremptionAlerteArticle doit etre anterieure ou egale a DatePeremptionArticle.
Si la date de peremption est absente, l'alerte ne peut pas etre calculee.
```

Exemple :

```text
DatePeremptionArticle = 2026-07-31
NbreJoursAlerteArticle = 93
DatePeremptionAlerteArticle = 2026-04-29
```

Regles d'implementation attendues :

```text
Le frontend peut afficher le calcul en direct.
Le backend doit recalculer ou verifier la valeur finale avant enregistrement.
La coherence metier ne doit jamais dependre uniquement du navigateur.
```

---

## 5. Gestion des commandes — T_Commande

### 5.1 Création d’une commande

Une commande est créée dans `T_Commande`.

Pour l'identification du client, le module doit accepter un modele hybride :

```text
ID_ClientFk    = reference structuree quand le client existe deja
NomClientSaisi = nom libre saisi au moment de la commande si aucun client n'est reference
```

Regles attendues :

- `ID_ClientFk` reste prioritaire quand une reference fiable existe ;
- `NomClientSaisi` permet de creer la commande meme si aucun identifiant client n'est disponible ;
- le frontend doit afficher `NomClientSaisi` comme solution de secours quand `ID_ClientFk` est vide ;
- la vue `V_Commande` doit exposer `NomClientSaisi` pour permettre la relecture applicative.

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

```

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

## 13. Alignement referentiel obligatoire

Le module logistique ne doit pas valider une FK generique uniquement par :

```text
referentiel.T_Generique.ID_Generique
```

La validation correcte est :

```text
la valeur existe dans T_Generique
ET
la valeur appartient a la bonne categorie dans T_CategorieGenerique
```

Correspondances metier attendues :

```text
T_Article.ID_TypeArticleFk        -> categorie 46 = Type produit
T_Article.ID_CategorieArticleFk   -> categorie 40 = Categorie produit
T_Article.ID_UniteFk              -> categorie 34 = Unites

T_Commande.ID_TypeCmdFk           -> categorie 64 = Type de commande
T_Commande.ID_StatutCmdFk         -> categorie 28 = Statut
T_Commande.ID_ConditionPaiementFk -> categorie 37 = Condition de paiement
T_Commande.ID_ModePaiementFk      -> categorie 36 = Mode paiement

T_Mouvement.ID_TypeMvtFk          -> categorie 64 = Type de commande
T_Reglements.ID_ModeReglementFk   -> categorie 36 = Mode paiement
```

Les valeurs metier de stock `Entree` et `Sortie` doivent etre recherchees dans la categorie 64.

### 13.1 Regle obligatoire pour les listes deroulantes

Pour les formulaires de creation et de modification, une liste deroulante logistique ne doit jamais etre alimentee directement par :

```text
referentiel.T_CategorieGenerique
```

`T_CategorieGenerique` sert uniquement a identifier la categorie metier attendue.

Les options visibles par l'utilisateur doivent toujours provenir de :

```text
referentiel.T_Generique
filtre par T_Generique.ID_CategorieGeneriqueFk
```

En consequence :

```text
T_CategorieGenerique = table de definition des categories
T_Generique          = table des valeurs a afficher dans les listes
```

Exemple :

```text
Pour "Type article", le frontend ne doit pas afficher la categorie 46 elle-meme.
Le frontend doit afficher les lignes de T_Generique dont ID_CategorieGeneriqueFk = 46.
```

### 13.2 Contrat technique attendu pour le backend

Pour chaque FK generique du module logistique :

1. le backend identifie la categorie attendue ;
2. le backend charge les options depuis `referentiel.T_Generique` ;
3. le backend filtre ces options par `ID_CategorieGeneriqueFk` ;
4. le backend renvoie au frontend la liste des valeurs deja exploitables ;
5. le backend refuse tout enregistrement si la valeur choisie existe dans `T_Generique` mais appartient a une autre categorie.

Requete type attendue :

```sql
SELECT
  g."ID_Generique" AS id,
  g."NomGenerique" AS label,
  g."AbrGenerique" AS abbr,
  g."ID_CategorieGeneriqueFk" AS "categoryId"
FROM referentiel."T_Generique" g
WHERE g."ID_CategorieGeneriqueFk" = :categorie_attendue
ORDER BY COALESCE(NULLIF(trim(g."AbrGenerique"), ''), g."NomGenerique"), g."ID_Generique";
```

Le backend ne doit pas construire une liste deroulante a partir de `T_CategorieGenerique` seule.

### 13.3 Contrat technique attendu pour le frontend

Le frontend logistique doit respecter les regles suivantes :

1. consommer en priorite les options renvoyees par l'API logistique ;
2. considerer que ces options correspondent deja aux bonnes categories metier ;
3. afficher les lignes de `T_Generique` comme choix utilisateur ;
4. ne jamais remplacer une liste backend non vide par une reconstruction locale vide ;
5. n'utiliser `T_CategorieGenerique` que pour afficher une information de contexte, jamais comme source directe des choix.

Autrement dit :

```text
Categorie = contexte
Generique = option selectionnable
```

### 13.4 Regle d'acceptation fonctionnelle des listes

Le comportement est considere correct si :

1. la creation d'un article affiche des options reelles pour `Type article`, `Categorie article` et `Unite` ;
2. la creation d'une commande affiche des options reelles pour `Type commande`, `Statut`, `Condition de paiement` et `Mode de paiement` ;
3. la creation d'un reglement affiche des options reelles pour `Mode de reglement` ;
4. chaque option affichee correspond a une ligne de `referentiel.T_Generique` ;
5. chaque option affichee appartient a la categorie attendue ;
6. aucune liste n'est peuplee a partir de `referentiel.T_CategorieGenerique` seule ;
7. si une categorie existe mais ne contient aucune ligne dans `T_Generique`, la liste est vide et l'etat est signale explicitement.

### 13.5 Ergonomie attendue des listes deroulantes

Les listes deroulantes volumineuses du module logistique doivent permettre une recherche de valeur sans obliger l'utilisateur a parcourir toute la liste manuellement.

Le comportement attendu est :

```text
Le composant de selection ouvre un panneau de choix.
La recherche de valeur se fait dans ce panneau de choix.
La selection peut se faire a la souris ou au clavier.
```

Exigences minimales :

1. recherche integree dans l'ouverture de la liste ;
2. filtrage dynamique des options visibles ;
3. conservation de la valeur deja selectionnee ;
4. validation au clavier avec `Enter` ;
5. navigation avec `Fleche haut` et `Fleche bas` ;
6. fermeture avec `Escape`.

Important :

```text
La recherche est une aide d'ergonomie.
Elle ne remplace jamais la regle de filtrage metier par categorie.
```

## 14. Alignement des vues

Les vues de lecture doivent exposer le champ technique `ID_StatutCmdFk` et peuvent conserver l'alias `ID_StatutCmd` pour la compatibilite applicative.

### 14.1 Regle de compatibilite pour les vues de lecture

Pour `T_Commande`, les vues de lecture doivent suivre cet ordre de priorite :

1. exposer `ID_StatutCmdFk` comme champ technique officiel ;
2. conserver eventuellement `ID_StatutCmd` comme alias de compatibilite ;
3. utiliser les deux uniquement pour la lecture ;
4. utiliser `ID_StatutCmdFk` uniquement pour l'ecriture applicative.

Exemple de projection attendue dans une vue :

```sql
SELECT
  c."ID_StatutCmdFk",
  c."ID_StatutCmdFk" AS "ID_StatutCmd"
FROM logistique."T_Commande" c;
```

### 14.2 Champs attendus dans V_Article

La vue `logistique.V_Article` doit exposer au minimum les champs necessaires a la lecture metier des articles et a l'affichage du formulaire apres enregistrement.

Champs attendus :

```text
DateHeureAuto
ID_Article
ID_TypeArticleFk
ID_CategorieArticleFk
ID_UserFK
CodeArticleInterne
NomArticle
ID_UniteFk
RefArticle
QteArticle
QteMinArticle
PUArticle
PVArticle
ObsArticle
ValideArticle
DatePeremptionArticle
DatePeremptionAlerteArticle
NbreJoursAlerteArticle
IdUser
NomComplet
```

Regle importante :

```text
Si T_Article contient un champ utile au formulaire ou a la fiche article, la vue V_Article doit aussi l'exposer lorsque ce champ fait partie du contrat de lecture du module.
```

Exemple critique :

```text
DatePeremptionAlerteArticle ne doit pas exister seulement dans T_Article.
Ce champ doit aussi etre projete dans V_Article pour rester visible apres rechargement.
```
