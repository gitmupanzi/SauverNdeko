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

---

## 14. Prompts UI pour générer les maquettes du module logistique

### 14.1. Règles communes à toutes les maquettes

Ces prompts doivent produire des maquettes cohérentes avec le scénario métier validé et les vues SQL du module logistique.

Règles communes :

- format d’image : `4:3` ;
- interface desktop ;
- langue : français ;
- style : dashboard SaaS/admin moderne ;
- barre latérale identique sur tous les écrans ;
- affichage principal basé sur les vues SQL ;
- lecture des données via les vues ;
- actions métier via les tables et procédures ;
- ne jamais représenter d’écriture directe dans `T_Mouvement` ;
- toujours afficher les statuts sous forme de badges ;
- garder une interface lisible, compacte et utilisable à 100 % de zoom.

Barre latérale commune :

```text
Créer une barre latérale verticale à gauche, en bleu foncé, avec le logo SauverNdeko en haut.
Sous le logo, afficher le texte “Logistique”.
Afficher les menus avec icônes :
- Tableau de bord
- Articles
- Commandes
- Commande détail
- Historique des mouvements
- Règlements
Le menu actif doit être mis en évidence avec un fond bleu lumineux.
En bas de la barre latérale, afficher un bloc utilisateur avec avatar, nom “Admin” et rôle “Administrateur”.
```

Structure commune de la zone principale :

```text
La zone principale doit avoir un fond clair blanc légèrement bleuté.
En haut à droite, afficher une icône de notification et un avatar rond avec les initiales “AD”.
Afficher un titre principal, un sous-titre, une barre de recherche, des boutons d’action, une zone de filtres et un tableau ou des cartes analytiques selon le module.
Utiliser des cartes blanches avec coins arrondis, ombres légères, typographie nette et espacement régulier.
```

Pagination commune pour les écrans en tableau :

```text
En bas du tableau, ajouter une pagination.
À gauche, afficher “Lignes” avec une liste déroulante contenant “10”.
À droite, afficher les boutons : <<, Préc, 1, 2, 3, 4, 5, Suiv >, Dern >>.
Le bouton de page “1” doit être actif en bleu.
```

---

## 15. Prompt — Tableau de bord logistique

```text
Créer une maquette d’interface web professionnelle pour le module logistique de l’application SauverNdeko.

L’image doit représenter le Tableau de bord logistique, sous forme de dashboard moderne, propre, structuré et prêt pour un projet web professionnel.

L’interface est en français, en disposition desktop, au format 4:3.

Structure générale :
- Barre latérale verticale à gauche, bleu foncé.
- Logo SauverNdeko en haut.
- Sous le logo, afficher “Logistique”.
- Menus avec icônes : Tableau de bord, Articles, Commandes, Commande détail, Historique des mouvements, Règlements.
- Le menu “Tableau de bord” doit être actif avec un fond bleu lumineux.
- En bas de la barre latérale, afficher le profil “Admin”, rôle “Administrateur”.

Zone principale :
- Fond clair blanc légèrement bleuté.
- En haut à droite, icône notification et avatar rond “AD”.
- Titre principal : “Tableau de bord”.
- Sous-titre : “Vue synthétique du stock, des commandes, des mouvements et des règlements”.

Résumé rapide :
Créer une rangée de cartes statistiques modernes avec icônes, valeurs et petites indications visuelles.
Afficher les indicateurs suivants :
- Articles
- Stock faible
- Ruptures
- Commandes sans détails
- Commandes incohérentes
- Règlements en retard

Les indicateurs doivent être inspirés des vues :
- logistique.V_Article
- logistique.V_AlertStock
- logistique.V_CommandeOverview
- logistique.V_CommandesSansDetails
- logistique.V_SuiviReglements

Exemples de valeurs :
- Articles : 248
- Stock faible : 18
- Ruptures : 7
- Commandes sans détails : 5
- Commandes incohérentes : 3
- Règlements en retard : 12

Zone d’actions rapides :
Afficher des boutons modernes, arrondis et bien alignés :
- Nouvel article
- Nouvelle commande
- Voir alertes stock
- Voir commandes sans détails
- Audit stock
- Exporter rapport
- Imprimer
- Autres filtres

Zone des filtres :
Créer une carte blanche avec six filtres horizontaux :
- Période
- Catégorie article
- Type article
- Type commande
- Statut commande
- État paiement
Chaque filtre doit ressembler à une liste déroulante avec la valeur “Toutes”.

Bloc analytique principal :
Créer une grille de quatre grandes cartes analytiques.

Carte 1 : Audit de stock
- Source logique : logistique.V_AuditStock ou logistique.V_AuditStock_Theorique.
- Titre : “Audit de stock”.
- Sous-titre : “Comparaison entre stock article et stock mouvements”.
- Afficher : Articles audités, stocks cohérents, écarts détectés, total entrées, total sorties.
- Ajouter un mini tableau avec : Code article, Article, Stock article, Stock mouvements, Écart, État audit.
- Badges : “Cohérent” en vert, “Stock article supérieur aux mouvements” en orange, “Stock article inférieur aux mouvements” en rouge.

Carte 2 : Alertes de stock
- Source logique : logistique.V_AlertStock.
- Titre : “Alertes de stock”.
- Sous-titre : “Articles en rupture ou en stock faible”.
- Afficher : Stock faible, Ruptures, Quantité à commander, Alertes péremption.
- Ajouter une petite liste : Code, Article, Stock, Stock min, À commander, État stock, État péremption.
- Badges : “Stock faible” orange, “Rupture” rouge, “Alerte péremption” orange, “Périmé” rouge.

Carte 3 : Consommation mensuelle
- Source logique : logistique.V_ConsoMensuelle.
- Titre : “Consommation mensuelle”.
- Sous-titre : “Sorties de stock par mois”.
- Afficher un graphique en barres ou une courbe simple avec les champs Mois, ConsoMensuelle, ValeurConsoMensuelle.
- Ajouter une valeur résumée : “Valeur consommée”.

Carte 4 : Couverture stock
- Source logique : logistique.V_CouvertureStock.
- Titre : “Couverture stock”.
- Sous-titre : “Durée estimée de stock selon la consommation des 6 derniers mois”.
- Afficher : Stock actuel, Consommation 6 mois, Consommation moyenne mensuelle, Couverture en mois, État couverture.
- Badges : “Correcte” vert, “Faible” orange, “Critique” rouge, “Aucune consommation récente” gris.
- Ajouter une barre de progression ou une jauge simple.

Zone tableaux rapides :
Ajouter deux tableaux courts en bas.

Tableau 1 : Dernières commandes
- Source logique : logistique.V_CommandeOverview.
- Colonnes : Code commande, Date, Type, Statut, Client, Montant TTC, État paiement, Contrôle commande.

Tableau 2 : Derniers mouvements
- Source logique : logistique.V_MouvementStock.
- Colonnes : Date mouvement, Article, Type mouvement, Quantité, Montant mouvement, Origine mouvement.

Style visuel :
- Dashboard SaaS/admin moderne.
- Cartes blanches, coins arrondis, ombres légères.
- Couleurs sobres : bleu foncé, blanc, gris clair, bleu primaire.
- Graphiques simples, lisibles et professionnels.
- Rendu propre, élégant, crédible, pas une photo ni un dessin à main levée.
```

---

## 16. Prompt — Articles

```text
Créer une maquette d’interface web professionnelle pour le module logistique de l’application SauverNdeko.

L’image doit représenter l’écran Articles, basé sur la vue logistique.V_Article.

Disposition desktop au format 4:3.

Structure générale :
- Barre latérale gauche bleu foncé.
- Logo SauverNdeko en haut.
- Texte “Logistique”.
- Menus : Tableau de bord, Articles, Commandes, Commande détail, Historique des mouvements, Règlements.
- Le menu “Articles” est actif.
- En bas : profil Admin / Administrateur.

Zone principale :
- Titre : “Articles”.
- Sous-titre : “Catalogue, stock, valorisation et péremption des articles”.
- En haut à droite : notification et avatar “AD”.

Recherche :
- Barre de recherche : “Rechercher un article, code, référence ou catégorie...”.

Boutons d’action :
- Ajouter
- Modifier
- Supprimer
- Désactiver
- Voir
- Exporter
- Imprimer
- Correspondance FK
- Autres filtres

Filtres :
Afficher six filtres :
- Catégorie article
- Type article
- Unité
- État stock
- État péremption
- État article

Tableau principal :
Créer une grande table basée sur logistique.V_Article.

Colonnes visibles :
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

Exemples de lignes :
1. ART001 | Gants d’examen latex | Consommables | Médical | Boîte | 250 | 50 | 0 | 6 500 FC | 8 500 FC | 1 625 000 FC | 2 000 FC | Disponible | Valide | Actif
2. ART002 | Sérum physiologique 500ml | Médicaments | Solution | Poche | 120 | 30 | 0 | 1 200 FC | 1 800 FC | 144 000 FC | 600 FC | Disponible | Valide | Actif
3. ART003 | Masque chirurgical | Consommables | Protection | Boîte | 80 | 20 | 0 | 2 500 FC | 3 500 FC | 200 000 FC | 1 000 FC | Disponible | Alerte péremption | Actif
4. ART004 | Savon antiseptique | Hygiène | Antiseptique | Flacon | 40 | 50 | 10 | 2 000 FC | 3 000 FC | 80 000 FC | 1 000 FC | Stock faible | Valide | Actif
5. ART005 | Perfuseur de précision | Dispositifs médicaux | Perfusion | Pièce | 0 | 20 | 20 | 1 500 FC | 2 200 FC | 0 FC | 700 FC | Rupture | Non renseignée | Actif

Badges :
- État stock : Disponible vert, Stock faible orange, Rupture rouge.
- État péremption : Valide vert, Alerte péremption orange, Périmé rouge, Non renseignée gris.
- État article : Actif vert, Inactif gris.

Dans la colonne Actions, afficher une icône verticale à trois points.
Pagination standard en bas.

Style :
- UI admin moderne.
- Cartes blanches, coins arrondis, ombres légères.
- Table lisible, colonnes bien alignées.
```

---

## 17. Prompt — Commandes

```text
Créer une maquette d’interface web professionnelle pour le module logistique de l’application SauverNdeko.

L’image doit représenter l’écran Commandes, basé sur la vue logistique.V_Commande ou logistique.V_CommandeOverview.

Disposition desktop au format 4:3.

Structure générale :
- Barre latérale gauche bleu foncé.
- Logo SauverNdeko.
- Texte “Logistique”.
- Menus : Tableau de bord, Articles, Commandes, Commande détail, Historique des mouvements, Règlements.
- Le menu “Commandes” est actif.
- Bloc utilisateur Admin / Administrateur en bas.

Zone principale :
- Titre : “Commandes”.
- Sous-titre : “Liste des commandes, facturation, règlement et contrôle des montants”.
- Notification et avatar AD en haut à droite.

Recherche :
- “Rechercher une commande, facture, client ou référence...”

Boutons :
- Ajouter
- Modifier
- Supprimer
- Voir
- Ajouter produits
- Exporter
- Imprimer
- Correspondance FK
- Autres filtres

Filtres :
- Type commande
- Statut commande
- État paiement
- Contrôle commande
- Client
- Période

Tableau principal :
Créer une grande table basée sur logistique.V_Commande.

Colonnes visibles :
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

Exemples de lignes :
1. CMD001 | REF-001 | 04/05/2026 | Entrée | Validée | Hôpital Général | 5 | 5 | 320 | 850 000 FC | 1 003 000 FC | 1 003 000 FC | 0 FC | Réglée | Cohérente
2. CMD002 | REF-002 | 04/05/2026 | Sortie | En cours | Centre Médical Nzambe | 3 | 3 | 75 | 210 000 FC | 247 800 FC | 100 000 FC | 147 800 FC | Partiellement réglée | Cohérente
3. CMD003 | REF-003 | 03/05/2026 | Entrée | Brouillon | COUSP Kinshasa | 0 | 0 | 0 | 0 FC | 0 FC | 0 FC | 0 FC | Non facturée | Sans détails
4. CMD004 | REF-004 | 03/05/2026 | Sortie | Validée | Zone de Santé Kintambo | 4 | 4 | 90 | 315 000 FC | 371 700 FC | 0 FC | 371 700 FC | Non réglée | Cohérente
5. CMD005 | REF-005 | 02/05/2026 | Entrée | Validée | Clinique Espoir | 2 | 2 | 25 | 78 000 FC | 92 040 FC | 20 000 FC | 72 040 FC | Partiellement réglée | Montant incohérent

Badges :
- Type : Entrée vert, Sortie rouge/orange.
- État paiement : Réglée vert, Partiellement réglée orange, Non réglée rouge, Non facturée gris.
- Contrôle commande : Cohérente vert, Sans détails orange, Montant incohérent rouge.

Dans la colonne Actions, afficher une icône verticale à trois points.
Pagination standard en bas.
Style moderne, propre, SaaS/admin dashboard.
```

---

## 18. Prompt — Commande détail

```text
Créer une maquette d’interface web professionnelle pour le module logistique de l’application SauverNdeko.

L’image doit représenter l’écran Commande détail, basé sur la vue logistique.V_CommandeDetail.

Disposition desktop au format 4:3.

Structure générale :
- Barre latérale gauche bleu foncé.
- Logo SauverNdeko.
- Texte “Logistique”.
- Menus : Tableau de bord, Articles, Commandes, Commande détail, Historique des mouvements, Règlements.
- Le menu “Commande détail” est actif.
- Bloc Admin en bas.

Zone principale :
- Titre : “Commande détail”.
- Sous-titre : “Lignes de commande, quantités, prix et contrôle du stock”.
- En haut à droite : notification et avatar AD.

Recherche :
- “Rechercher une ligne, commande, article ou facture...”

Boutons :
- Ajouter ligne
- Modifier ligne
- Supprimer ligne
- Voir
- Exporter
- Imprimer
- Autres filtres

Filtres :
- Commande
- Type commande
- Statut commande
- Article
- État ligne
- Période

Tableau principal :
Créer une grande table basée sur logistique.V_CommandeDetail.

Colonnes visibles :
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

Exemples de lignes :
1. CMD001 | FAC001 | 04/05/2026 | Entrée | Validée | ART001 | Gants d’examen latex | Boîte | 150 | 250 | 100 | 6 500 FC | 650 000 FC | Dépôt principal | Valide
2. CMD001 | FAC001 | 04/05/2026 | Entrée | Validée | ART002 | Sérum physiologique | Poche | 70 | 120 | 50 | 1 200 FC | 60 000 FC | Dépôt principal | Valide
3. CMD002 | FAC002 | 04/05/2026 | Sortie | En cours | ART003 | Masque chirurgical | Boîte | 110 | 80 | 30 | 2 500 FC | 75 000 FC | Magasin A | Valide
4. CMD002 | FAC002 | 04/05/2026 | Sortie | En cours | ART008 | Alcool 70° | Bouteille | 80 | 60 | 20 | 2 200 FC | 44 000 FC | Magasin A | Valide
5. CMD003 | FAC003 | 03/05/2026 | Sortie | Brouillon | ART005 | Perfuseur de précision | Pièce | 10 | 10 | 0 | 1 500 FC | 0 FC | Dépôt principal | Quantité invalide
6. CMD004 | FAC004 | 03/05/2026 | Entrée | Validée | ART006 | Paracétamol 500mg | Boîte | 100 | 150 | 50 | 800 FC | 40 000 FC | Pharmacie | Valide

Badges :
- Type commande : Entrée vert, Sortie rouge/orange.
- État ligne : Valide vert, Quantité invalide rouge, Prix non renseigné orange.

Dans la colonne Actions, afficher une icône verticale à trois points.
Pagination standard en bas.
Style moderne, propre, lisible et professionnel.
```

---

## 19. Prompt — Historique des mouvements

```text
Créer une maquette d’interface web professionnelle pour le module logistique de l’application SauverNdeko.

L’image doit représenter l’écran Historique des mouvements, basé sur la vue logistique.V_MouvementStock.

Disposition desktop au format 4:3.

Structure générale :
- Barre latérale gauche bleu foncé.
- Logo SauverNdeko.
- Texte “Logistique”.
- Menus : Tableau de bord, Articles, Commandes, Commande détail, Historique des mouvements, Règlements.
- Le menu “Historique des mouvements” est actif.
- Bloc Admin en bas.

Zone principale :
- Titre : “Historique des mouvements”.
- Sous-titre : “Traçabilité des entrées, sorties et ajustements de stock”.
- En haut à droite : notification et avatar AD.

Recherche :
- “Rechercher un mouvement, article ou commande...”

Boutons :
- Voir
- Exporter
- Imprimer
- Autres filtres

Important :
- Ne pas afficher Ajouter, Modifier ou Supprimer, car les mouvements sont issus de l’historique stock et doivent rester en lecture seule.
- La vue utilise T_Mouvement.ID_TypeMvtFk comme vérité historique du mouvement.
- La commande liée sert de contexte, mais ne doit pas déterminer le signe du mouvement.

Filtres :
- Type mouvement
- Origine mouvement
- Article
- Commande
- Période
- Sens stock

Tableau principal :
Créer une grande table basée sur logistique.V_MouvementStock.

Colonnes visibles :
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

Exemples de lignes :
1. MVT001 | 04/05/2026 | ART001 | Gants d’examen latex | CMD001 | Entrée | 100 | +100 | 6 500 FC | 650 000 FC | +650 000 FC | Commande
2. MVT002 | 04/05/2026 | ART002 | Sérum physiologique | CMD002 | Sortie | 30 | -30 | 1 200 FC | 36 000 FC | -36 000 FC | Commande
3. MVT003 | 04/05/2026 | ART003 | Masque chirurgical | CMD001 | Entrée | 50 | +50 | 2 500 FC | 125 000 FC | +125 000 FC | Commande
4. MVT004 | 03/05/2026 | ART008 | Alcool 70° | CMD002 | Sortie | 20 | -20 | 2 200 FC | 44 000 FC | -44 000 FC | Commande
5. MVT005 | 03/05/2026 | ART005 | Perfuseur de précision | - | Sortie | 5 | -5 | 1 500 FC | 7 500 FC | -7 500 FC | Ajustement direct article
6. MVT006 | 02/05/2026 | ART006 | Paracétamol 500mg | CMD004 | Entrée | 50 | +50 | 800 FC | 40 000 FC | +40 000 FC | Commande

Badges :
- Entrée vert
- Sortie rouge/orange
- Ajustement direct article gris ou bleu
- Commande bleu

Dans la colonne Actions, afficher une icône verticale à trois points.
Pagination standard en bas.
Style : interface lecture seule, orientée audit et traçabilité, moderne SaaS/admin dashboard.
```

---

## 20. Prompt — Suivi des règlements

```text
Créer une maquette d’interface web professionnelle pour le module logistique de l’application SauverNdeko.

L’image doit représenter l’écran Suivi des règlements, basé sur la vue logistique.V_SuiviReglements.

Disposition desktop au format 4:3.

Structure générale :
- Barre latérale gauche bleu foncé.
- Logo SauverNdeko.
- Texte “Logistique”.
- Menus : Tableau de bord, Articles, Commandes, Commande détail, Historique des mouvements, Règlements.
- Le menu “Règlements” est actif.
- Bloc Admin / Administrateur en bas.

Zone principale :
- Titre : “Règlements”.
- Sous-titre : “Suivi des factures, paiements, restes à payer et retards”.
- Notification et avatar AD en haut à droite.

Recherche :
- “Rechercher une facture, commande ou client...”

Boutons :
- Ajouter règlement
- Modifier règlement
- Voir commande
- Exporter
- Imprimer
- Correspondance FK
- Autres filtres

Filtres :
- État règlement
- Retard paiement
- Client
- Date facture
- Échéance
- Période

Tableau principal :
Créer une grande table basée sur logistique.V_SuiviReglements.

Colonnes visibles :
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

Exemples de lignes :
1. CMD001 | FAC001 | 04/05/2026 | 14/05/2026 | Hôpital Général | 1 003 000 FC | 1 003 000 FC | 0 FC | 1 | 04/05/2026 | 10 | Réglée | Non
2. CMD002 | FAC002 | 04/05/2026 | 10/05/2026 | Centre Médical Nzambe | 247 800 FC | 100 000 FC | 147 800 FC | 1 | 04/05/2026 | 6 | Partiellement réglée | Non
3. CMD003 | FAC003 | 03/05/2026 | 08/05/2026 | COUSP Kinshasa | 1 439 600 FC | 0 FC | 1 439 600 FC | 0 | - | 4 | Non réglée | Non
4. CMD004 | FAC004 | 25/04/2026 | 30/04/2026 | Zone de Santé Kintambo | 371 700 FC | 0 FC | 371 700 FC | 0 | - | -4 | Non réglée | Oui
5. CMD005 | - | - | - | Clinique Espoir | 92 040 FC | 0 FC | 92 040 FC | 0 | - | - | Non facturée | Non
6. CMD006 | FAC006 | 02/05/2026 | 09/05/2026 | HGR Matete | 531 000 FC | 531 000 FC | 0 FC | 2 | 03/05/2026 | 5 | Réglée | Non

Badges :
- Réglée vert
- Partiellement réglée orange
- Non réglée rouge
- Non facturée gris
- Montant nul gris
- Retard “Oui” rouge
- Retard “Non” vert ou gris

Dans la colonne Actions, afficher une icône verticale à trois points.
Pagination standard en bas.
Style : interface moderne orientée finance, suivi facture et contrôle échéance.
```

---

## 21. Correspondance entre vues SQL et écrans frontend

| Écran frontend            | Vue SQL principale                                                                                                                                        | Rôle                                                |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| Tableau de bord           | `V_Article`, `V_AlertStock`, `V_AuditStock`, `V_ConsoMensuelle`, `V_CouvertureStock`, `V_CommandeOverview`, `V_CommandesSansDetails`, `V_SuiviReglements` | Synthèse et indicateurs                             |
| Articles                  | `V_Article`                                                                                                                                               | Catalogue, stock, valorisation, péremption          |
| Commandes                 | `V_Commande` ou `V_CommandeOverview`                                                                                                                      | Liste, facturation, paiement, contrôle montant      |
| Commande détail           | `V_CommandeDetail`                                                                                                                                        | Lignes de commande, quantité, prix, stock théorique |
| Historique des mouvements | `V_MouvementStock` ou `V_Mouvement`                                                                                                                       | Traçabilité officielle du stock                     |
| Règlements                | `V_SuiviReglements`                                                                                                                                       | Factures, paiements, restes à payer, échéances      |

---

## 22. Points de vigilance UI et métier

- L’écran Historique des mouvements doit être en lecture seule.
- Les boutons Ajouter, Modifier et Supprimer ne doivent pas apparaître pour les mouvements.
- Les écrans de lecture doivent utiliser les vues SQL.
- Les opérations CRUD doivent viser les tables métier, jamais directement `T_Mouvement`.
- Les badges doivent aider l’utilisateur à identifier rapidement les anomalies : rupture, stock faible, commande sans détails, montant incohérent, paiement en retard, écart de stock.
- Les colonnes affichées dans les prompts doivent rester proches des champs exposés dans les vues SQL.
- Les maquettes doivent rester lisibles même avec beaucoup de colonnes : utiliser largeur adaptée, scroll horizontal ou colonnes prioritaires.
