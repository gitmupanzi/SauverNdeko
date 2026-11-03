# Présentation de l’espace des applications

## Modèle et portée

La migration `20261103_07_presentation_espace_applications.sql` ajoute `systeme."T_ModuleApplication"."AfficherDansEspace"`, booléen obligatoire à `true` par défaut. Cette information pilote uniquement la présence d’une tuile dans le lanceur. La colonne et sa contrainte `NOT NULL` PostgreSQL 18 sont commentées.

Produits et Discussions deviennent des `MODULE` de présentation, commercialisables, sans parent de présentation. Leurs `EstSocle`, `CodeIncluant`, `Actif`, ordre, codes, licences et restrictions de rôle sont conservés. Discussions reste donc comprise dans le socle actuel ; ce changement de présentation n’ajoute ni achat ni facturation automatique. L’inclusion de Produits par la licence Catalogue demeure inchangée.

Informations santé possède `AfficherDansEspace=false`. Seule sa tuile `/maladies` disparaît du lanceur : aucune donnée, route ou habilitation antérieure n’est supprimée ou étendue.

Référentiels est une fonctionnalité du manifeste du lanceur. Sa tuile exige un administrateur ERP (`actor.admin`, comme les API existantes `IsERPAdmin`) et le contrôle `require_module(actor, 'referentiels')`. Cette fonctionnalité dérivée ne crée aucune ligne dans `T_ModuleApplication`, aucune licence et aucun droit supplémentaire : l’accès nécessite toujours au moins une application consultable ; export et gestion continuent leurs propres contrôles. Un lecteur ordinaire ne voit pas cette tuile et ne reçoit aucun accès nouveau aux API du référentiel.

## Contrat API

- `GET /api/workspace/modules` : tableau des tuiles réellement consultables, filtrées par `AfficherDansEspace`. Référentiels est ajouté seulement lorsque les deux règles d’accès existantes autorisent la consultation.
- `GET /api/workspace/catalogue` : catalogue historique des treize codes, y compris Santé. Référentiels n’y devient pas un code de licence. La métadonnée `showInWorkspace` permet de distinguer visibilité du lanceur et droit d’accès.
- La nature reste `type='MODULE'|'FONCTIONNALITE'`, avec `commercialisable` et `parentModule`. Pour l’administrateur global, le lanceur contient neuf modules et quatre fonctionnalités après filtrage et ajout de Référentiels. Les comptes d’entreprise reçoivent uniquement les entrées autorisées et les compteurs doivent être calculés depuis cette réponse.

Aucune route de mutation de `T_ModuleApplication` n’est ajoutée. Les messages de verrou PostgreSQL `55P03` et `40P01` deviennent transversaux : « Une autre opération est en cours. Réessayez dans un instant. » Le statut `409` et le code `BUSINESS_CONFLICT` sont inchangés.

## Vérifications exécutées

La migration a été exécutée puis rejouée sur une copie privée PostgreSQL locale `sauverndeko_test_workspace07_6b7c4df8`. Les empreintes des 78 tables restent identiques après exclusion des seules métadonnées de présentation visées. Les treize codes, leurs anciens drapeaux de droits, les licences, les rôles et les définitions des triggers sont conservés. Le second passage ne change plus les lignes.

Neuf tests API et cinq tests SQL ont réussi. Ils vérifient notamment : classification, distinction catalogue/lanceur, visibilité lue en base, authentification, Référentiels sans droit inventé, accès Produits toujours refusé sans licence, inclusion par Catalogue conservée, socle Discussions inchangé, absence de changement de licence, hiérarchie valide et commentaire de la nouvelle contrainte.

Preuves locales : `.runtime/workspace-presentation07/clone.json`, `api.txt` et `sql.txt`. SHA-256 de la migration : `9f28fd23ed6573de71cd43bf82d765d9a711e69726733655315cfe4a8e0a3e74`.

Les quatre fichiers canoniques (tables système, vues Support et deux structures globales) intègrent les modifications ciblées des migrations 06 et 07. Deux restaurations vides contiennent respectivement 78 et 68 tables ; définitions, types, contraintes, commentaires, vues, routines et triggers sont identiques à la copie privée migrée. Preuve : `.runtime/workspace-presentation07-canonicals/verification.json`. L’installation de la source est consignée séparément par le responsable de livraison. Ces tests privés ne constituent pas une preuve d’installation sur une autre base.
