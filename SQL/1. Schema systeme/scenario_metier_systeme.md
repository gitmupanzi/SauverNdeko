# Scénario métier système — SauverNdeko

## 1. Objet du module

Le module **Système / Administration** de SauverNdeko permet de piloter les données administratives et techniques de l'application.

Il couvre principalement:

- les utilisateurs ;
- les profils utilisateurs ;
- les rôles ;
- les licences ;
- les entités ;
- les localisations d'entités ;
- les journaux d'audit ;
- l'historique de connexion ;
- les correspondances FK ;
- les paramètres UI ;
- les sources référentielles nécessaires à l'affichage et aux formulaires.

Son objectif est de garantir:

- la traçabilité des actions ;
- la lisibilité des données système ;
- la cohérence des listes et correspondances ;
- la possibilité de gérer les objets administratifs sans casser les routes existantes ;
- une interface Administration moderne, cohérente et réutilisable.

## 2. Principe général du module

Le module suit la logique suivante:

```text
Tables système = données source modifiables.
Vues système = lectures propres pour le frontend.
Référentiel = valeurs génériques et rôles exploités dans les formulaires.
Audit = historique officiel des changements.
Correspondances FK = paramétrage des liens entre champs techniques et listes frontend.
Paramètres UI = personnalisation partagée par scope.
```

Le frontend Administration:

- consomme en priorité les vues SQL ;
- garde les formulaires branchés sur les tables métier ou endpoints existants ;
- distingue clairement les vues en lecture seule et les vues avec CRUD ;
- regroupe les écrans par schéma avec une navigation lisible.

## 3. Tables système de référence

### 3.1. `systeme.T_Utilisateurs`

Cette table représente les comptes utilisateurs du système.

Champs clés:

- `IdUser`
- `NomUser`
- `PrenomUser`
- `EmailUser`
- `PhoneUser`
- `MotdepasseUser`
- `IdRoleFk`
- `IdEntiteFk`
- `SexeUser`
- `ValideUser`
- `Is_staff`
- `Is_Admin`
- `DatecreationUser`
- `DateModificationUser`

Règles métier:

- un utilisateur peut être actif ou inactif ;
- un utilisateur staff est identifié par `Is_staff = true` ;
- un administrateur est identifié par `Is_Admin = true` ;
- l'écran utilisateur doit permettre création, modification, désactivation et consultation.

### 3.2. `systeme.T_Entite`

Cette table représente les entités ou organisations.

Champs clés:

- `IdEntite`
- `NomEntite`
- `PhoneEntite`
- `EmailEntite`
- `AdresseEntite`
- `IdTypeEntiteFk`
- `ValideEntite`
- `DateCreationEntite`

Règles métier:

- une entité structure le rattachement des utilisateurs, licences et localisations ;
- une entité peut être active ou désactivée ;
- une entité peut avoir une ou plusieurs informations de localisation.

### 3.3. `systeme.T_Entite_Localisation`

Cette table représente les coordonnées et niveaux géographiques d'une entité.

Champs clés:

- `IdEntiteLocalisation`
- `IdEntiteFk`
- `Latitude`
- `Longitude`
- `AdresseDetaillee`
- `DateCreation`
- `IdNiveau_3_Fk`
- `IdNiveau_4_Fk`
- `IdNiveau_5_Fk`

Règles métier:

- la localisation est liée à une entité existante ;
- les coordonnées doivent rester exploitables pour un aperçu cartographique ;
- les niveaux géographiques servent aux filtres et au classement territorial.

### 3.4. `systeme.T_Licence`

Cette table représente les licences associées aux entités.

Champs clés:

- `IdLicence`
- `IdEntiteFk`
- `DateDebut`
- `DateFin`
- `IdStatutLicenceFk`
- `ValideLicence`
- `ExpireeLicence`

Règles métier:

- une licence peut être active, expirée ou bientôt expirée ;
- la validité dépend des dates et des indicateurs de la table ;
- l'écran licences doit permettre création, modification, renouvellement et suivi du statut.

### 3.5. `systeme.T_Login`

Cette table représente l'historique de connexion.

Champs clés:

- `IdLogin`
- `DateLogin`
- `IdUserFk`
- `IdTypeLoginFk`
- `IdEntiteFk`

Règles métier:

- l'historique de connexion est en lecture seule ;
- il sert à tracer connexions, déconnexions et autres types de login si disponibles ;
- le type de login vient du référentiel.

### 3.6. `systeme.T_Audit_Log`

Cette table représente l'historique officiel des changements.

Champs clés:

- `IdLog`
- `TableName`
- `Operation`
- `ChangedAt`
- `IdEntiteFk`
- `OldData`
- `NewData`

Règles métier:

- `INSERT`, `UPDATE` et `DELETE` doivent être traçables ;
- les journaux d'audit sont strictement en lecture seule côté interface ;
- `OldData` et `NewData` doivent rester consultables de façon lisible.

### 3.7. `systeme.T_Fk_Correspondance`

Cette table représente les correspondances FK utilisées par l'application.

Champs clés:

- `IdFkCorrespondance`
- `ModuleName`
- `SchemaName`
- `ViewName`
- `SourceKey`
- `FieldName`
- `FieldLabel`
- `MappingType`
- `ReferenceSchemaName`
- `ReferenceObjectName`
- `ReferenceFieldName`
- `TargetCategoryIdFk`
- `MappingValue`
- `IsDefaultMapping`
- `ValideFkCorrespondance`
- `SettingScope`
- `ScopeValue`
- `DisplayOrder`
- `UpdatedAt`
- `UpdatedByUserFk`
- `ObsFkCorrespondance`

Règles métier:

- les mappings actifs ont `ValideFkCorrespondance = true` ;
- les mappings par défaut sont distingués des personnalisations ;
- les types de mapping attendus sont au minimum:
  - `generic_category`
  - `hierarchy_mode`
- les portées attendues sont au minimum:
  - `global`
  - `entity`
  - `user`
  - `module`
- l'historique des modifications doit rester auditable.

### 3.8. `systeme.T_Admin_UI_Setting`

Cette table représente les paramètres UI partagés.

Champs clés:

- `IdAdminUISetting`
- `SettingScope`
- `ScopeValue`
- `SettingKey`
- `SettingLabel`
- `SettingGroup`
- `SettingValue`
- `SettingValueJson`
- `SettingType`
- `DisplayOrder`
- `IsEditable`
- `IsSystem`
- `ValideSetting`
- `CreatedAt`
- `UpdatedAt`
- `UpdatedByUserFk`
- `ObsSetting`

Règles métier:

- les paramètres peuvent être globaux ou spécifiques à une portée ;
- les paramètres modifiables et système doivent être clairement distingués ;
- les paramètres UI doivent être auditables ;
- le frontend ne doit pas coder en dur les paramètres si une source SQL existe déjà.

## 4. Vues SQL système réellement utilisées

Le frontend Administration lit principalement les vues suivantes du schéma `systeme`.

### 4.1. Vues principales

- `systeme.V_User_profil`
- `systeme.V_Audit_log`
- `systeme.V_Fk_Correspondance`
- `systeme.V_Fk_Correspondance_Detail`
- `systeme.V_Fk_Correspondance_Audit`
- `systeme.V_Entite_Localisation_Detail`
- `systeme.V_Licence_active`
- `systeme.V_Login_history`
- `systeme.V_Admin_UI_Setting`
- `systeme.V_Admin_UI_Setting_Group`
- `systeme.V_Admin_UI_Setting_Audit`

### 4.2. Rôle du référentiel dans l'Administration

Le module Administration dépend aussi de sources référentielles:

- `referentiel.V_Generique`
- `referentiel.V_CategorieGenerique`

Le référentiel sert notamment à:

- les rôles utilisateurs ;
- les types d'entité ;
- les statuts de licence ;
- les catégories de correspondance FK ;
- les listes utilisées par les formulaires système.

## 5. Répartition actuelle des écrans Administration

L'interface Administration repose aujourd'hui sur des écrans métier ou virtuels, tous visibles dans la navigation principale.

### 5.1. Écrans réellement branchés

1. `Tableau de bord`
2. `Utilisateurs`
3. `Rôles`
4. `Permissions`
5. `Journaux d'audit`
6. `Correspondances FK`
7. `Localisations entités`
8. `Licences`
9. `Historique de connexion`
10. `Profils utilisateurs`
11. `Paramètres UI`

### 5.2. Source de données par écran

- `Tableau de bord`
  - agrège plusieurs vues système:
    - `V_User_profil`
    - `V_Licence_active`
    - `V_Login_history`
    - `V_Audit_log`
    - `V_Fk_Correspondance`
    - `V_Admin_UI_Setting`
- `Utilisateurs`
  - lit `systeme.V_User_profil`
- `Rôles`
  - lit `referentiel.V_Generique` filtrée sur la catégorie des rôles
- `Permissions`
  - écran préparé mais sans vraie vue SQL système dédiée à ce jour
- `Journaux d'audit`
  - lit `systeme.V_Audit_log`
- `Correspondances FK`
  - lit `systeme.V_Fk_Correspondance_Detail`
- `Localisations entités`
  - lit `systeme.V_Entite_Localisation_Detail`
- `Licences`
  - lit `systeme.V_Licence_active`
- `Historique de connexion`
  - lit `systeme.V_Login_history`
- `Profils utilisateurs`
  - lit `systeme.V_User_profil`
- `Paramètres UI`
  - lit `systeme.V_Admin_UI_Setting`

### 5.3. Vues secondaires non exposées directement dans la navigation

- `systeme.V_Fk_Correspondance`
- `systeme.V_Fk_Correspondance_Audit`
- `systeme.V_Admin_UI_Setting_Group`
- `systeme.V_Admin_UI_Setting_Audit`

Ces vues servent à l'analyse, à l'audit ou à la synthèse sans être forcément des pages principales.

## 6. Écrans virtuels et écrans en attente

Le frontend Administration introduit aussi des vues virtuelles pour mieux coller au métier:

- `dashboard`
  - écran virtuel de synthèse
- `V_User_profil_users`
  - variante métier de `V_User_profil` pour l'écran `Utilisateurs`
- `V_User_profil_profiles`
  - variante métier de `V_User_profil` pour l'écran `Profils utilisateurs`
- `V_Roles`
  - variante métier de `referentiel.V_Generique`
- `V_Permissions`
  - écran métier préparé, mais sans source SQL système valide actuellement

Règle importante:

> un écran préparé sans vraie vue ne doit pas inventer de données. Il doit afficher clairement qu'aucune source système dédiée n'est encore disponible.

## 7. Navigation et structure d'interface

L'interface Administration doit rester cohérente avec les maquettes validées.

Règles actuelles:

- une sidebar Administration dédiée est affichée ;
- les vues sont regroupées par schéma ;
- une liste déroulante `Vue active` permet aussi de sélectionner rapidement une vue ;
- le menu actif est mis en évidence ;
- la navigation distingue les vues avec CRUD et les vues en lecture seule ;
- l'apparence reste homogène avec les autres modules, notamment la Logistique.

## 8. Règles d'affichage par écran

### 8.1. Tableau de bord

Le dashboard Administration doit présenter:

- des KPI de synthèse ;
- les derniers journaux d'audit ;
- l'historique de connexion récent ;
- l'état des licences ;
- les correspondances FK récentes ;
- les paramètres UI récemment modifiés.

Le dashboard ne dépend pas d'une seule vue, mais d'un agrégat de plusieurs vues système.

### 8.2. Utilisateurs

Colonnes prioritaires:

- `IdUser`
- `NomUser`
- `PrenomUser`
- `EmailUser`
- `PhoneUser`
- `SexeUser`
- `NomEntite`
- `ValideUser`
- `DatecreationUser`

Actions attendues:

- ajouter ;
- modifier ;
- désactiver ;
- exporter ;
- imprimer ;
- voir le profil.

### 8.3. Rôles

Source:

- `referentiel.V_Generique` filtrée sur la catégorie des rôles.

Colonnes prioritaires:

- `ID_Generique`
- `AbrGenerique`
- `NomGenerique`
- `ObsGenerique`
- `ValideGenerique`

### 8.4. Permissions

État actuel:

- l'écran existe dans la navigation ;
- aucune vue système dédiée n'est encore disponible ;
- il doit donc rester un écran préparé, sans données fictives.

### 8.5. Journaux d'audit

Source:

- `systeme.V_Audit_log`

Colonnes prioritaires:

- `IdLog`
- `ChangedAt`
- `TableName`
- `NomEntite`
- `Operation`
- `OldData`
- `NewData`

Règles:

- lecture seule ;
- pas de boutons `Ajouter`, `Modifier`, `Supprimer` ;
- possibilité de voir les anciennes et nouvelles données.

### 8.6. Correspondances FK

Source:

- `systeme.V_Fk_Correspondance_Detail`

Colonnes prioritaires:

- `ModuleName`
- `SchemaName`
- `ViewName`
- `SourceKey`
- `FieldName`
- `FieldLabel`
- `MappingType`
- `NomCategorieGenerique`
- `MappingValue`
- `SettingScope`
- `ValideFkCorrespondance`
- `UpdatedAt`

Actions attendues:

- ajouter ;
- modifier ;
- désactiver ;
- exporter ;
- imprimer.

### 8.7. Localisations entités

Source:

- `systeme.V_Entite_Localisation_Detail`

Colonnes prioritaires:

- `IdEntiteLocalisation`
- `IdEntite`
- `NomEntite`
- `TypeEntite`
- `PhoneEntite`
- `EmailEntite`
- `Latitude`
- `Longitude`
- `NomNiveau_3`
- `NomNiveau_4`
- `NomNiveau_5`
- `AdresseDetaillee`
- `DateCreation`

### 8.8. Licences

Source:

- `systeme.V_Licence_active`

Colonnes prioritaires:

- `IdLicence`
- `NomEntite`
- `DateDebut`
- `DateFin`
- `ValideLicence`
- `ExpireeLicence`
- `statut_licence`

Règles:

- le statut doit aider à distinguer licence active et expirée ;
- les formulaires de licence doivent rester liés aux statuts référentiels réels.

### 8.9. Historique de connexion

Source:

- `systeme.V_Login_history`

Colonnes prioritaires:

- `IdLogin`
- `DateLogin`
- `TypeLogin`
- `IdUser`
- `NomUser`
- `PrenomUser`
- `EmailUser`
- `NomEntite`

Règles:

- lecture seule ;
- pas de boutons `Ajouter`, `Modifier`, `Supprimer`.

### 8.10. Profils utilisateurs

Source:

- `systeme.V_User_profil`

Colonnes prioritaires:

- `IdUser`
- `NomUser`
- `PrenomUser`
- `EmailUser`
- `PhoneUser`
- `SexeUser`
- `ValideUser`
- `Is_staff`
- `Is_Admin`
- `DatecreationUser`
- `NomEntite`
- `EmailEntite`
- `PhoneEntite`

### 8.11. Paramètres UI

Source:

- `systeme.V_Admin_UI_Setting`

Colonnes prioritaires:

- `SettingGroup`
- `SettingKey`
- `SettingLabel`
- `SettingType`
- `SettingValue`
- `SettingScope`
- `ScopeValue`
- `IsEditable`
- `IsSystem`
- `UpdatedAt`
- `UpdatedByName`

Actions attendues:

- ajouter ;
- modifier ;
- exporter ;
- imprimer ;
- consulter l'audit si nécessaire.

## 9. Règles de lecture seule et de CRUD

Écrans en lecture seule:

- `Journaux d'audit`
- `Historique de connexion`
- `Audit paramètres UI`
- `Audit correspondances FK`

Règles:

- pas de création ;
- pas de modification ;
- pas de suppression ;
- actions autorisées:
  - voir ;
  - filtrer ;
  - exporter ;
  - imprimer ;
  - consulter le détail.

Écrans avec CRUD ou édition:

- `Utilisateurs`
- `Rôles`
- `Correspondances FK`
- `Localisations entités`
- `Licences`
- `Profils utilisateurs`
- `Paramètres UI`

## 10. Correspondances FK et paramètres partagés

Le frontend Administration exploite la logique de `T_Fk_Correspondance` et `T_Admin_UI_Setting` pour piloter:

- les catégories génériques utilisées par les listes ;
- les modes hiérarchiques ;
- les valeurs de portée ;
- la persistance des réglages partagés.

Principes de fonctionnement:

- les réglages peuvent être rechargés et synchronisés ;
- l'historique compact des réglages peut être consulté ;
- les correspondances génériques ne doivent pas être codées en dur si elles existent dans la base ;
- les groupes et catégories affichés doivent rester cohérents avec le référentiel réel.

## 11. Logique technique frontend validée

Le frontend Administration suit désormais les conventions suivantes:

- regroupement des écrans par schéma ;
- sélection possible de la vue active via une liste déroulante ;
- distinction entre vues SQL directes et écrans virtuels métier ;
- conservation des routes existantes ;
- lecture des vues via `fetchViewData(...)` ;
- usage des configs CRUD existantes pour les formulaires ;
- réutilisation du référentiel pour les rôles, types d'entité, statuts de licence et catégories.

## 12. Limitations actuelles connues

- il n'existe pas encore de vue SQL système dédiée aux permissions ;
- l'écran `Permissions` est donc volontairement un écran préparé, non simulé ;
- le rôle est aujourd'hui traité à partir du référentiel générique, pas d'une table système autonome ;
- les vues d'audit et de synthèse non principales existent mais ne sont pas toutes exposées comme pages de navigation.

## 13. Résultat attendu

Le module Administration doit fournir:

- une navigation claire par schéma ;
- une vue d'ensemble synthétique du système ;
- un pilotage propre des utilisateurs, licences, entités et correspondances FK ;
- une consultation fiable des journaux et historiques ;
- une gestion cohérente des paramètres UI ;
- une interface alignée sur les maquettes et sur les sources SQL réellement disponibles ;
- une base prête à évoluer quand une vraie source `Permissions` sera ajoutée.
