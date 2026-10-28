# Référencement des champs

La migration `20261028_09_referencement_champs.sql` centralise les familles proposées par les colonnes possédant réellement une clé étrangère vers `referentiel.T_Generique`. Elle n’ajoute pas de champ métier aux articles ou documents et ne transforme aucune référence historique. Son application réelle reste une étape contrôlée après sauvegarde et recette ; elle ne se lance pas au démarrage du backend.

## Catalogue physique et choix courants

`referentiel.T_ChampReferentiel` contient une seule définition par schéma, table et colonne. Les 60 clés étrangères de l’instance sont représentées sur 26 tables, dans sept schémas. Chaque clé est vérifiée dans le catalogue PostgreSQL ; un alias d’interface ou une colonne texte ne suffit pas à créer une définition.

La catégorie de référence `ID_CategorieDefautFk` est immuable après installation. Elle ne représente pas le choix courant. Trois colonnes restent sans catégorie de référence faute de preuve dans leurs consommateurs : `operations.T_Paiement.IdTypePaiementFk`, `professionnel.T_Professionnel.IdTypeProfessionnelFk` et `professionnel.T_Professionnel_Entite.IdTypeLienFk`. Un administrateur peut les configurer explicitement ; rétablir leur défaut revient à « non configuré » sans inventer une famille.

Les catégories courantes et surcharges restent exclusivement dans `systeme.T_Fk_Correspondance`. Sa nouvelle FK nullable `IdChampReferentielFk` relie un jeu canonique au catalogue. Les lignes antérieures conservent leurs valeurs et cette relation reste NULL. Il n’existe aucune seconde colonne de catégorie courante dans le catalogue.

`AliasSourceKeys` relie explicitement les anciennes sources à leurs vraies colonnes. Par exemple, `roles` est un alias de plusieurs consommateurs ; ce n’est pas une colonne SQL. Les deux références de rôle de sécurité restent configurables en lecture seulement et conservent leur famille de référence.

## Résolution commune

`fn_resolution_champ` est l’autorité de résolution, exposée par `fn_categories_champ` :

1. Jeu canonique de l’entreprise choisie, sinon son alias historique.
2. Jeu canonique global, sinon son alias historique.
3. Catégorie de référence immuable, ou liste vide si elle n’est pas prouvée.

Un jeu remplace entièrement celui d’une portée inférieure ; les listes ne sont pas fusionnées implicitement. Les anciennes correspondances multiples restent représentables et lisibles. Le nouvel écran choisit une catégorie à la fois. Le périmètre pays n’est pas activé par cette évolution.

`SupportsEntityScope` est une politique immuable, indépendante du droit de modifier le champ. **37 champs** possèdent un propriétaire durable : une FK d’entreprise, la propre PK de `T_Entite` ou un parent logistique déjà protégé. Les **23 autres restent globaux** : 19 champs géographiques, l’unité de précision partagée, la spécialité d’une recherche et les deux références du professionnel partagé. L’entreprise actuelle d’un utilisateur ou d’un résultat de recherche ne devient jamais leur propriétaire. `T_Professionnel_Entite`, qui possède une vraie FK d’entreprise, accepte en revanche une portée entreprise.

`fn_entite_reference_champ` détermine ce contexte depuis la vraie ligne et ses parents prouvés. Le même contexte guide les listes et leur validation SQL. Une nouvelle surcharge d’entreprise sur un champ partagé est refusée ; les anciens réglages d’entreprise sont conservés physiquement et ignorés pour ces champs, dont les valeurs restent communes. Les rôles restent protégés dans les deux portées.

**Rétablir** écrit un marqueur canonique `@default` dans la portée sélectionnée. Cette intention persiste : elle ne retombe pas accidentellement sur une ancienne surcharge globale ou d’entreprise. Le marqueur n’est jamais mélangé à des catégories dans un même jeu. Les autres portées et les lignes historiques restent conservées.

Chaque modification canonique ou d’un alias incrémente `Revision` du champ, avec date et auteur factuels. Le service verrouille le catalogue avant de comparer la révision puis de remplacer le jeu. Les audits SQL des correspondances et la preuve de requête du service conservent la traçabilité ; les anciennes écritures d’audit ne sont pas réécrites.

## Valeurs, codes et données historiques

La sélection conserve `ID_Generique`. `NomGenerique` est le libellé métier, `AbrGenerique` son abréviation ou code. Aucun rapprochement d’identité n’utilise le libellé, l’abréviation ou la position d’une ligne. Les listes actives exigent une valeur et une famille actives ; les visibilités historiques restent des options distinctes. Elles ne deviennent pas des filtres globaux : la plupart des valeurs installées ne portent pas les anciens drapeaux de visibilité.

La garde physique valide une nouvelle affectation ou un changement de référence/entreprise. Une valeur ancienne inchangée peut rester affichée et permet encore une modification descriptive. L’audit en lecture seule a détecté des familles étrangères dans quatre champs géographiques historiques ; aucun des 505 rattachements concernés n’est corrigé ou reclassé automatiquement par la migration. Le nouvel écran fournit un diagnostic ; une correction nécessite un choix explicite.

Un document physique ou financier peut copier exactement une référence de son parent historique : type du mouvement, devise, ou mode/condition de facture. Les gardes métier continuent de contrôler parent, propriétaire, sens et montants ; la copie ne devient pas incompatible simplement parce que la liste courante a changé. `ReferenceHeriteeParent` indique ces champs dans la vue de configuration.

La nature des types de bon provient toujours des codes Entrée, Sortie ou CMD. Les familles déclarées et les types déjà utilisés restent interprétables après un changement de choix courant. La nature et la famille d’un type utilisé sont protégées ; aucun mouvement n’est recalculé. Une nouvelle valeur hors famille courante reste refusée, même si elle existe dans un ancien document.

Les devises gardent leurs contrôles ISO et le défaut USD actif unique ; les unités gardent leur politique de décimales et les unités de masse leurs codes autorisés. Changer une liste ne modifie ni un coût, un stock, un lot, une facture ou un règlement.

## Vue, interface et installation

`V_ReferencementChamp` expose le même catalogue et le résolveur global. Pour une entreprise autorisée, le service appelle ce résolveur avec son identifiant ; une fonction de lecture SQL n’accorde aucun droit d’administration.

Le catalogue de tableau `referentiels.champs` affiche par défaut : **Schéma, Table, Colonne, ID catégorie, Libellé catégorie, ID catégorie par défaut, Actions**. Les identifiants techniques sans rendu restent exclus des choix de colonnes à l’écran. Les choix d’export demeurent indépendants.

Une installation neuve doit charger les définitions physiques comme métadonnées fermées après la structure et les familles génériques, avant les réglages par défaut. Le paquet copie uniquement les colonnes immuables du catalogue et réinitialise localement révision, dates et auteur. Il ne copie ni les surcharges de l’instance source, ses préférences personnelles, entreprises ou utilisateurs. Le manifeste décrit cette projection dans `sanitizedDataTables`. L’insertion initiale du catalogue prouve chaque vraie FK ; une définition installée ne peut ensuite être modifiée ou supprimée par le CRUD ordinaire. Les sources canoniques et l’installateur sont synchronisés après l’application réelle validée.

## Recette privée

`SQL/tests/test_referencement_champs_postgresql.py` exige une URL locale explicite vers `sauverndeko_test_*`, avec le socle08 avant application09. La recette couvre conservation des anciennes tables/réglages et des 60 FK, défauts inconnus, portées, restauration, valeurs actives, rôles protégés, métadonnées immuables, références historiques hors famille, concurrence, commentaires et vraie chaîne BE/BS/CMD utilisant une nouvelle famille.

La recette finale passe **133 contrôles SQL**, dont la matrice de portée, la PK d’entreprise et le refus des surcharges sur champs partagés. Les régressions physiques ont également passé **113 contrôles de chaîne**, **45 contrôles CUMP** et **31 contrôles d’annulation d’inventaire**. La recette de chaîne suit désormais la demande documentaire07 : émetteur courant après renommage, tiers/lignes/montants émis conservés et archives restituées à l’octet près. Les tests utilisent exclusivement des entreprises, comptes et documents fictifs dans les bases privées.

Preuve SQL locale : `.runtime/referencement09/verification.json`. Le dictionnaire fermé de régression vient de cinq tables de métadonnées lues dans une transaction source en lecture seule ; aucune donnée cliente n’est copiée. Le contrôle technique ne constitue pas une acceptation du client. La dernière vérification interactive du navigateur à localhost:5174 reste limitée par sa permission d’accès.
