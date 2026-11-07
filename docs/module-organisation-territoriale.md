# Organisation territoriale

Le module `/territoires` réunit le découpage territorial et la pyramide sanitaire. Il utilise les données partagées du schéma `geolocalisation` : changer d’entreprise ne crée pas un autre découpage et ne réattribue pas les territoires existants.

## Utilisation

Le tableau de bord présente dix indicateurs cliquables : six niveaux territoriaux, les aires sans site, les zones sans aire, les sites sans aire et les sites sans zone directe. Les deux graphiques répartissent les sites par province et par type. Cliquer sur un indicateur ou une barre ouvre le registre correspondant, avec son filtre. Ces chiffres décrivent les rattachements enregistrés ; ils ne certifient pas l’exhaustivité du terrain. Un site « sans zone directe » peut encore hériter d’une zone par son aire : les deux situations restent distinctes.

La barre latérale organise les treize registres suivants :

| Rubrique | Registres |
|---|---|
| Organisation | Pays et territoires ; Provinces et DPS ; Antennes et subdivisions ; Zones de santé ; Aires de santé ; Structures et sites |
| Analyses | Répartition territoriale ; Structures par zone ; Population des sites ; Réseau des aires |
| Contrôles | Aires sans site ; Zones sans aire |
| Historique | Ancien découpage provincial |

Dans chaque registre, utiliser **Rechercher**, **Filtrer**, **Réinitialiser**, le nombre de lignes et la pagination. Les filtres catégoriels et hiérarchiques proposent une recherche dans les choix. **Réglages** rassemble les colonnes, les préférences d’export et, pour les fiches territoriales, les références utilisées. Le choix des colonnes et leur ordre restent distincts de ceux de l’export.

Les colonnes de comptage permettent de descendre directement dans le découpage : provinces d’un pays, subdivisions d’une province, zones d’une subdivision, aires ou sites d’une zone, puis sites d’une aire. Un clic ouvre la liste filtrée dont le nombre correspond au compteur, y compris lorsqu’il vaut zéro. Les noms de parents ouvrent leur véritable fiche. Dans les analyses, les compteurs conservent les filtres du groupe, notamment les types d’aire et de site. Cliquer sur une population ouvre ses lignes sources ; cela ne transforme pas ce montant en nombre de lignes ni en taux de couverture.

**Excel** et **CSV** exportent les résultats filtrés complets. Une sélection de lignes permet aussi un export de la sélection. Le XLSX commence directement par les titres de colonnes et conserve les références textuelles. Les actions et autres colonnes non exportables restent exclues. Les droits d’export sont contrôlés au serveur.

Le nom d’une fiche et l’action **Consulter** ouvrent une fenêtre latérale. Les rubriques **Identification**, **Suivi** et **Géographie** apparaissent selon les champs du niveau. Les boutons d’élargissement, de réduction, de rechargement et de fermeture suivent les conventions communes du projet. La consultation et la modification réutilisent cette même fiche ; les erreurs conservent la saisie. La suppression demande une confirmation et reste refusée si des rattachements la rendent impossible.

Pour les six niveaux actuels, le bouton de création ouvre un **panier d’une ou plusieurs fiches**. Choisir le rattachement commun dans l’en-tête, puis saisir ou coller depuis Excel jusqu’à 100 lignes. Les colonnes principales restent compactes ; le menu **⋯ → Détails de la ligne** ouvre tous les champs de la fiche, puis applique les modifications au panier sans sauvegarde individuelle. Il est possible d’ajouter ou retirer une ligne, de vider le panier après confirmation ou d’annuler la saisie. **Enregistrer l’ensemble** traite tout le lot dans une seule transaction. En cas d’erreur, aucune ligne de cette demande n’est enregistrée ; corriger les lignes signalées, qui restent dans le panier. Le collage accepte les cellules Excel entre guillemets, les tabulations et les retours à la ligne internes. L’ancien découpage provincial conserve son ajout individuel.

**Télécharger le modèle Excel** fournit un vrai fichier `.xlsx` propre au niveau ouvert, avec tous les champs de sa fiche, les choix autorisés et une feuille d’instructions. Compléter la feuille **Territoires**, puis utiliser **Importer un fichier Excel** dans le même panier. Le rattachement reste choisi dans l’en-tête de l’application et s’applique aussi aux lignes importées ; il ne se répète pas dans le fichier. L’import ajoute les lignes au brouillon existant et signale les champs à corriger, y compris dans **Détails de la ligne**. Vérifier le panier, puis cliquer sur **Enregistrer l’ensemble** : importer seul n’enregistre aucune fiche. Les coordonnées, informations d’accueil, horaires et choix explicite de publication des niveaux 1 à 5 sont conservés. Les codes et téléphones doivent rester des cellules texte. Le fichier est limité à 4 Mo et le panier à 100 lignes ; les formules et liens externes de classeur sont refusés.

Les analyses restent en consultation. Les contrôles « Aires sans site » et « Zones sans aire » proposent aussi d’ouvrir la fiche territoriale concernée. Une ligne d’analyse conserve l’identité de son regroupement réel ; elle n’est jamais traitée comme une fiche à modifier.

## Permissions et références

L’ouverture et l’export nécessitent les droits du module Organisation territoriale. La modification du découpage commun est réservée à l’administrateur de la plateforme, avec le droit de gestion et les écritures activées. Choisir une entreprise ne donne aucun droit supplémentaire sur cette géographie partagée.

Les listes génériques utilisent le référencement physique `schéma + table + colonne → catégorie`. Dans **Réglages → Références**, la famille active est indiquée par son ID et son libellé, avec le défaut et les valeurs disponibles. Le lien **Référencement des champs** ouvre le réglage central si le compte y est autorisé. Une ancienne valeur devenue incompatible reste visible et conservée tant que le champ n’est pas changé ; aucune conversion des données historiques n’est implicite.

Un site peut être rattaché directement à sa zone de santé sans aire renseignée. Le formulaire ne crée pas une aire fictive et ne déduit pas un rattachement absent. Lorsqu’une aire est renseignée, la cohérence avec sa zone est contrôlée. Les valeurs booléennes facultatives conservent la distinction Oui / Non / non renseigné ; les deux visibilités obligatoires du niveau provincial imposent Oui ou Non.

Les sauvegardes et suppressions utilisent une révision de fiche et un identifiant de demande. Une modification concurrente est signalée. Après une réponse incertaine, la fiche propose de vérifier la même demande au lieu de créer une seconde écriture.

## État des données et vérifications du 30 octobre 2026

La lecture de `SauverNdeko` a trouvé 251 pays/territoires, 26 provinces/DPS, 315 antennes/subdivisions, 2 469 zones, 1 011 aires, 21 949 sites et 12 anciennes provinces. Les 21 949 sites sont actuellement rattachés directement à une zone, sans aire renseignée. Les listes de contrôle retournent donc 1 011 aires sans site et 2 227 zones sans aire. Ce sont des données existantes à examiner, conservées sans réaffectation automatique.

Les analyses ont des grains distincts. « Population des sites » regroupe par zone et type de site ; les populations peuvent se recouper. « Structures par zone » regroupe aussi par types d’aire et de site : ne pas additionner les nombres d’aires répétés entre types. Une proportion réseau absente lorsqu’aucune aire n’existe reste absente.

Trois migrations sont installées après sauvegardes vérifiées :

- `20261030_03_portail_territorial.sql` ajoute treize catalogues de tableaux/exports. Les 23 catalogues antérieurs sont conservés exactement ; aucune donnée géographique n’est modifiée.
- `20261030_04_type_site_referentiel.sql` complète la référence physique du type de site vers `T_Generique`, son index et ses commentaires. La catégorie par défaut est déduite d’une référence prouvée. Les 60 correspondances antérieures et toutes les données géographiques restent inchangées ; la clé étrangère est validée.
- `20261030_05_compteurs_territoriaux.sql` enrichit six vues existantes avec 41 colonnes de lecture : compteurs enfants, identifiants et noms de parents, contexte provincial, identifiants géographiques, type d’aire et réseau déclaré. Chaque colonne ajoutée est commentée. Les anciennes colonnes et leurs valeurs restent identiques ; les six catalogues de tableaux sont complétés sans modifier les préférences personnelles ni les données géographiques. Le clic sur les six compteurs enfants utilise exactement leur périmètre, sans filtre de fusion ajouté implicitement.

La recette générale sur la base applicative a exécuté **553 assertions réussies en lecture seule** : treize registres et leurs identifiants, pagination, filtres, recherches vides, treize exports XLSX et treize CSV de sélection, export complet, préférences, sept fiches et leurs références, dix indicateurs, graphiques, droits et réponses aux requêtes invalides. Elle vérifie aussi les six compteurs enfants pour tous leurs parents, les cibles des quatre analyses, les types non renseignés, les sommes de populations sources et le dénominateur réseau. Ce nombre désigne des assertions de recette, pas 553 requêtes HTTP.

Une contre-vérification ciblée distincte a exécuté **444 assertions réussies**, avec **94 GET API et 336 instructions SQL de lecture**. Elle contrôle notamment les métadonnées et réglages des 41 colonnes, les six comptages exhaustifs — **6 541 comparaisons parent/compteur, aucun écart** —, vingt détails issus des quatre analyses, les exports correspondants et les cellules Excel laissées vides pour les valeurs NULL. Cette recette impose une transaction PostgreSQL `READ ONLY` et une garde limitant les instructions à la lecture ; elle ne crée ni compte, ni jeton, ni donnée métier.

Les écritures sont vérifiées séparément : **39 tests API sur PostgreSQL privé** couvrent les fiches, les paniers des six niveaux, les erreurs et corrections, les doublons composites, les refus tardifs avec annulation complète, les droits, les références dynamiques, l’idempotence et la concurrence. Les composants frontend disposent de **219 assertions automatisées** ; le diagnostic backend comporte **311 contrôles de lecture**. Ces vérifications ne remplacent pas une connexion utilisateur et une recette visuelle réelles.

Les deux structures globales et les extraits géographiques tables/vues ont été actualisés. Leur restauration dans deux bases privées vides a réussi : **69 tables, 84 vues et 163 triggers** pour le global ; **59 tables, 84 vues et 163 triggers** pour le métier. Les restaurations ne chargent aucune donnée cliente source.

Les preuves privées principales sont `.runtime/territoires-readonly.json`, `.runtime/territoires-final-readonly.json`, `.runtime/territoires-api-tests.json`, `.runtime/territoires-applied.json`, `.runtime/territoires-site-type-applied.json` et `.runtime/territoires-counters-applied.json`. Elles ne sont pas destinées au dépôt. Aucun essai de création, modification ou suppression de recette ne vise les territoires réels.

**Limite de recette :** la permission enregistrée du navigateur intégré a empêché la vérification visuelle de localhost pendant ce travail. Les contrôles API, les tests de composants et la compilation ne remplacent pas une recette visuelle : contraste des thèmes, ouverture des fenêtres, navigation au clavier et affichage mobile restent à vérifier dans un navigateur autorisé avant livraison.
