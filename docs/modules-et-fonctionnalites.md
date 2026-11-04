# Modules métier et fonctionnalités associées

L’espace privé « Vos applications », à `/espace`, distingue les **modules métier commercialisables** des **fonctionnalités associées**, avec deux groupes et deux compteurs séparés. Une recherche indique le nombre de résultats dans chaque groupe, rapporté aux éléments accessibles au compte.

`/catalogue` est l’accueil public de SauverNdeko, ouvert par défaut par le lanceur local et par la racine `/`. Il ne constitue pas un module métier. Après connexion, la destination par défaut est `/espace` ; une destination protégée explicitement demandée reste prioritaire. Les annuaires et les données métier conservent leurs protections.

| Modules métier | Fonctionnalités associées |
|---|---|
| Produits | Administration |
| Structures | Paramètres |
| Professionnels | Guide utilisateur |
| Logistique | Référentiels |
| Caisse | |
| Organisation territoriale | |
| Support | |
| Discussions | |

Le catalogue de découverte identifie les modules commercialisables. Une fonctionnalité associée n’est pas présentée comme un module à acheter séparément. La page de gestion des licences garde la distinction et conserve les activations historiques.

La classification est centralisée dans `systeme.T_ModuleApplication` :

- `TypeApplication` : `MODULE` ou `FONCTIONNALITE` ;
- `Commercialisable` : indication commerciale ;
- `ModuleParentCode` : rattachement facultatif à un module existant.
- `AfficherDansEspace` : présence de la tuile dans Vos applications ; désactiver cette présentation ne supprime ni données ni droits.

Ces informations ne remplacent pas les droits ni les licences. Elles ne créent pas d’héritage d’autorisation, ne modifient pas `EstSocle` et ne retirent pas un accès ancien. Les inclusions du Catalogue et les restrictions de rôle existantes sont conservées. Un administrateur peut toujours gérer l’activation technique d’une fonctionnalité dans la licence ; cette configuration d’accès ne constitue pas une vente séparée.

Le serveur renvoie ces métadonnées à l’accueil, au catalogue et aux licences. Les interfaces ne déterminent pas la commercialisation à partir d’une liste de libellés codée en dur.

Référentiels reste une fonctionnalité transversale réservée aux administrateurs ERP habilités disposant d’une application lisible, comme ses API existantes. Sa tuile est ajoutée par le manifeste serveur ; elle n’introduit aucune licence autonome. La licence Administration n’est pas exigée pour ce seul accès.

À la demande du propriétaire du 4 novembre 2026, **Informations santé** et sa page **Maladies** sont retirées : elles ne figurent plus dans Vos applications, le catalogue de découverte, la navigation ni le Guide utilisateur. L’ancienne URL `/maladies` redirige vers l’accueil `/catalogue` et l’API dédiée `/api/public/maladies` répond 404. Les valeurs de maladie du référentiel et les anciennes activations de licence sont conservées ; cette conservation historique ne réactive aucun parcours du module retiré. Les autres applications incluses par le code historique Catalogue gardent leurs droits.
