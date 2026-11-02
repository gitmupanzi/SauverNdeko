# Modules métier et fonctionnalités associées

Le catalogue distingue les **modules métier commercialisables** des **fonctionnalités associées**. L’accueil présente ces deux groupes et leurs compteurs séparés. Une recherche indique le nombre de résultats dans chaque groupe, rapporté aux éléments accessibles au compte.

| Modules métier | Fonctionnalités associées |
|---|---|
| Catalogue | Produits et Informations santé, rattachés au Catalogue |
| Structures | Administration |
| Professionnels | Paramètres |
| Logistique | Guide utilisateur |
| Caisse | Discussions |
| Organisation territoriale | |
| Support | |

Le catalogue de découverte identifie les modules commercialisables. Une fonctionnalité associée n’est pas présentée comme un module à acheter séparément. La page de gestion des licences garde la distinction et conserve les activations historiques.

La classification est centralisée dans `systeme.T_ModuleApplication` :

- `TypeApplication` : `MODULE` ou `FONCTIONNALITE` ;
- `Commercialisable` : indication commerciale ;
- `ModuleParentCode` : rattachement facultatif à un module existant.

Ces informations ne remplacent pas les droits ni les licences. Elles ne créent pas d’héritage d’autorisation, ne modifient pas `EstSocle` et ne retirent pas un accès ancien. Les inclusions du Catalogue et les restrictions de rôle existantes sont conservées. Un administrateur peut toujours gérer l’activation technique d’une fonctionnalité dans la licence ; cette configuration d’accès ne constitue pas une vente séparée.

Le serveur renvoie ces métadonnées à l’accueil, au catalogue et aux licences. Les interfaces ne déterminent pas la commercialisation à partir d’une liste de libellés codée en dur.
