# Référentiels transversaux — 30 octobre 2026

## Périmètre réel et navigation

Le schéma contient cinq tables, conservées sans renommer leurs identifiants :

| Table | Usage | Écran |
|---|---|---|
| `T_CategorieGenerique` | Familles du dictionnaire | Catégories |
| `T_Generique` | Valeurs identifiées par `ID_Generique` | Valeurs de référence |
| `T_ChampReferentiel` | Catalogue fermé des 60 colonnes réellement liées à `T_Generique` | Référencement des champs |
| `T_InterfaceTableau` | Colonnes et réglages autorisés par interface | Tableaux et exports |
| `T_PreferenceTableau` | Préférences du compte, de l’entreprise et de l’usage tableau/export | Tableaux et exports, composants existants |

La dernière page réunit le catalogue et les préférences personnelles. Elle ne crée pas un second éditeur libre du JSON technique. La nouvelle vue `V_InterfaceTableau` projette les six colonnes existantes, un libellé dérivé de la clé et le nombre réel de colonnes. Les indicateurs de personnalisation sont calculés par l’API pour le compte connecté et son contexte autorisé.

## Référentiel commun et entreprise

`20261030_01_referentiels_transversaux.sql` ajoute `IdEntiteFk` aux catégories et aux valeurs. `NULL` désigne le commun ; un identifiant désigne le propriétaire durable. Toutes les lignes antérieures restent communes. Aucun rattachement arbitraire à École Pilote Test ou COUSP n’est effectué.

Une catégorie commune accepte des valeurs communes et des compléments privés. Une catégorie privée exige que ses valeurs appartiennent à la même entreprise. Le propriétaire d’une catégorie ou valeur enregistrée est immuable. Les FK continuent à stocker `ID_Generique` ; le changement de famille de choix ne réécrit aucune référence métier existante.

`fn_categorie_visible` et `fn_reference_visible` limitent les choix aux références communes et à l’entreprise explicitement indiquée. Un contexte sans entreprise ne donne que le commun pour une sélection métier. La consultation administrative globale de plusieurs entreprises reste une permission distincte : ces fonctions SQL de portée n’accordent aucun accès applicatif supplémentaire.

Les catégories privées sont interdites dans une correspondance globale ou destinée à une autre entreprise. Les familles des champs non configurables de sécurité restent communes. La précision d’une unité privée est rattachée par l’identifiant immuable de son unité ; le catalogue évolue uniquement pour `logistique.T_PrecisionStock.ID_UniteFk`, avec un événement d’audit factuel. La permission existante de modification de la précision reste réservée à l’administration globale.

## Doublons et saisie multiple

La comparaison normalise la casse et les espaces, y compris l’espace insécable. Les accents restent distincts. Un nouveau nom de catégorie, libellé de valeur ou code facultatif ne peut produire d’ambiguïté dans un même ensemble visible : commun et entreprise concernée. Deux entreprises distinctes peuvent utiliser le même nom privé. Une nouvelle référence commune ne peut masquer une référence privée préexistante.

Les doublons historiques restent distincts et conservent leurs identifiants. La migration ne les fusionne pas. Une modification descriptive qui ne change pas l’identité normalisée reste possible. Les gardes utilisent des verrous transactionnels pour empêcher une double création concurrente.

La saisie multiple utilise une transaction pour le lot entier et les mêmes gardes que la saisie individuelle. Une erreur d’une ligne annule toutes les insertions du lot. L’interface conserve le panier et les corrections à effectuer. Les catégories sont des lignes similaires ; les valeurs partagent une catégorie choisie dans l’en-tête. Le collage Excel reste une préparation de panier, sans écriture avant l’enregistrement explicite.

## Migration et préservation

Appliquer cette migration uniquement après le socle `20261028_09`. Elle refuse une réapplication. Avant intervention : sauvegarde complète privée avec empreintes et contrôle du catalogue, puis comparaison sous verrous des tables existantes. L’évolution attendue des données est limitée à une politique de portée dans le catalogue fermé, un événement d’audit, deux catalogues enrichis de colonnes facultatives et un nouveau catalogue de tableau.

Les colonnes historiques des vues sont conservées dans leur ordre ; les informations de portée sont ajoutées à leur fin. Aucun stock, prix, facture, mouvement, compte, préférence personnelle ou correspondance actuelle n’est modifié. Les 60 FK vers les valeurs génériques sont conservées. Les nouveaux objets et leurs colonnes, contraintes, index, fonctions et triggers sont commentés.

Les deux migrations sont appliquées dans **SauverNdeko**. La première a été précédée d’une sauvegarde complète vérifiée par empreinte, lecture de catalogue et décodage intégral : `avant-referentiels30-20261030-074016`, SHA-256 du dump `546bf56357576827ec55ed7e1032937fe39c9dd9d191e5a4f536b53b02d287e5`. Les 69 tables ont été comparées sous verrous, avec les seules évolutions de métadonnées prévues. Les 64 catégories et 808 valeurs antérieures restent communes. Les comptes, stocks, documents, préférences et correspondances existants n’ont pas changé.

La recette étendue a révélé des filtres de catégorie numériques subsistant dans huit vues de Logistique et dans la garde d’émission de facture. La correction distincte `20261030_02_lectures_logistiques_dynamiques.sql` retire ces filtres des lectures par FK exactes, calcule les signes via `fn_effet_type_bon` et reconnaît les sorties facturables via `fn_nature_bon`. Elle conserve les règles BE/BS/CMD et la protection des factures émises. Les types utilisés puis retirés du choix courant gardent leur sens historique.

La sauvegarde préalable02 `avant-referentiels30-02-20261030-082058` a été vérifiée de la même manière, SHA-256 `d88e0e122fd19dc97a5cfe5054d9f88f932179c75207643f95a424fa99f7b67f`. Après application02, les empreintes des 69 tables, les colonnes, FK, triggers, séquences et toutes les lignes calculées historiques des huit vues sont identiques. Seules les définitions prévues des vues et de la garde de facture changent. Ces contrôles de sauvegarde ne constituent pas une restauration complète du dump de données privées.

## Installation neuve

La commande `preparer_installation` exclut les catégories et valeurs privées ainsi que la précision de leurs unités. Elle garde les identifiants du dictionnaire commun, y compris les doublons hérités. Le catalogue physique est réinitialisé avec des dates, révisions et auteurs propres à l’installation. La date d’activité des précisions n’est pas copiée.

Le chargement initial du dictionnaire exige des tables vides et s’exécute dans une transaction. Seules les deux gardes des nouvelles identités sont suspendues pour charger les identifiants historiques, puis réactivées avant validation. Les contraintes et autres triggers restent actifs. Aucun compte, entreprise, licence cliente, document, préférence personnelle ou correspondance cliente n’est exporté. Les correspondances initiales viennent du seed fermé du code.

## Vérifications exécutées

La recette `SQL/tests/test_referentiels_transversaux_postgresql.py` a exécuté **129 contrôles** dans une base privée locale issue du socle09 : préservation des anciennes tables et FK, propriétaires communs inchangés, ambiguïtés, doublons hérités, concurrence, portée commune/A/B, correspondances privées, précision fractionnaire privée, stock initial avec le type d’entrée de la bonne entreprise et un seul mouvement, annulation complète d’un lot en erreur, commentaires et catalogue de tableau.

`SQL/tests/test_lectures_logistiques_dynamiques.py` a exécuté **21 contrôles** supplémentaires après la recette01 : préservation intégrale des données et métadonnées physiques, changement limité aux huit vues et à la garde autorisée, libellé de catégorie privée, signe/quantité/montant d’un BE privé dont le type a été retiré du choix courant. Les tests API ont aussi exécuté une facture réelle depuis un BS privé et une validation puis annulation d’inventaire avec des types configurés d’entreprise.

Le script `SQL/tests/test_referentiels_installation.py` prépare un vrai paquet depuis une base privée contenant des références privées, puis exécute les vraies commandes d’installation, plan et application, dans une autre base vide. Il compare les identifiants et valeurs communes, vérifie l’exclusion des références privées, les gardes réactivées, les comptes et documents vides, les correspondances fermées et les migrations natives Django réellement appliquées.

Résultats : deux catégories privées et six valeurs privées fictives ont été exclues, avec égalité exacte du dictionnaire commun et de ses précisions hors date locale. Le paquet final a aussi été produit depuis la source en lecture seule, puis réellement installé dans une base vide avec **18 migrations Django**. Les neuf tables clientes contrôlées sont vides.

Les **17 fichiers canoniques existants** ont été régénérés, y compris la vue du schéma analytics. Les deux fichiers globaux ont été restaurés dans deux bases privées neuves, sans données : structure complète **69 tables, 84 vues, 163 triggers, 170 routines** ; structure métier **59 tables, 84 vues, 163 triggers, 139 routines**. Définitions, colonnes, contraintes, index, séquences et commentaires correspondent à la source. Le comparateur tient compte de deux réécritures équivalentes de PostgreSQL : casts varchar/text des tableaux fermés de constantes et représentation des casts dans les contraintes ; les types des colonnes restent vérifiés séparément. Aucun dump de données clientes n’est inclus dans les sources canoniques.

Les tests API et les vérifications de l’interface complètent ces preuves. Un résultat SQL isolé ne constitue pas, à lui seul, une recette de tous les parcours navigateur ou de tous les modules ERP.
