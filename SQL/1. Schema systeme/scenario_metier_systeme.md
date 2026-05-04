# Scénario métier système — SauverNdeko

## 1. Objectif du module

Le module **Système / Administration** de SauverNdeko permet de gérer les éléments techniques et administratifs de l’application.

Il couvre principalement :

- les utilisateurs ;
- les profils utilisateurs ;
- les entités ou organisations ;
- les localisations des entités ;
- les licences ;
- l’historique des connexions ;
- les journaux d’audit ;
- les paramètres d’interface ;
- les correspondances FK utilisées par le frontend ;
- les valeurs de référence utilisées dans les listes déroulantes.

L’objectif principal est de garantir :

- la traçabilité des actions ;
- la sécurité des accès ;
- la cohérence des données système ;
- la bonne correspondance entre les champs techniques de la base et les libellés lisibles côté frontend ;
- la disponibilité des vues nécessaires pour l’interface Administration.

---

## 2. Principe général

Le module système doit suivre la logique suivante :

```text
Tables système = données opérationnelles et administratives.
Vues système = lecture propre pour le frontend.
Audit log = historique officiel des changements.
Référentiel = valeurs utilisées pour les catégories, rôles, types, statuts et listes déroulantes.
Correspondances FK = mapping entre champs techniques et valeurs compréhensibles par l’interface.
```

Le frontend doit lire principalement les vues, tandis que les opérations de création, modification, désactivation ou suppression doivent passer par les tables métier ou les endpoints backend prévus.

---

## 3. Tables principales concernées

### 3.1. `systeme.T_Utilisateurs`

Cette table représente les utilisateurs du système.

Rôle principal :

- stocker les informations d’identité ;
- stocker les contacts ;
- rattacher un utilisateur à une entité ;
- déterminer si l’utilisateur est staff ou administrateur ;
- gérer l’état actif/inactif de l’utilisateur.

Colonnes importantes :

- `IdUser`
- `NomUser`
- `PrenomUser`
- `EmailUser`
- `PhoneUser`
- `MotdepasseUser`
- `IdRoleFk`
- `SexeUser`
- `IdEntiteFk`
- `ValideUser`
- `Is_staff`
- `Is_Admin`
- `DatecreationUser`

Règles métier :

```text
Un utilisateur doit être rattaché à une entité lorsque le contexte métier l’exige.
Un utilisateur inactif ne doit pas pouvoir accéder au système.
Un administrateur doit être identifiable par Is_Admin = true.
Un utilisateur staff doit être identifiable par Is_staff = true.
```

---

### 3.2. `systeme.T_Entite`

Cette table représente les structures, organisations ou entités utilisant le système.

Rôle principal :

- stocker le nom de l’entité ;
- stocker les contacts de l’entité ;
- stocker le type d’entité ;
- servir de point de rattachement aux utilisateurs, licences et localisations.

Colonnes importantes :

- `IdEntite`
- `NomEntite`
- `PhoneEntite`
- `EmailEntite`
- `AdresseEntite`
- `IdTypeEntiteFk`

Règles métier :

```text
Une entité représente le contexte organisationnel d’un utilisateur ou d’une licence.
Une entité peut avoir une localisation détaillée.
Une entité peut être associée à une licence.
```

---

### 3.3. `systeme.T_Entite_Localisation`

Cette table représente la localisation géographique d’une entité.

Rôle principal :

- stocker la latitude et la longitude ;
- stocker l’adresse détaillée ;
- rattacher l’entité aux niveaux géographiques ;
- permettre l’affichage cartographique côté frontend.

Colonnes importantes :

- `IdEntiteLocalisation`
- `IdEntiteFk`
- `Latitude`
- `Longitude`
- `AdresseDetaillee`
- `DateCreation`
- `IdNiveau_3_Fk`
- `IdNiveau_4_Fk`
- `IdNiveau_5_Fk`

Règles métier :

```text
Une localisation doit être liée à une entité existante.
Les coordonnées Latitude / Longitude doivent être cohérentes pour permettre l’affichage sur carte.
Les niveaux géographiques permettent de filtrer les entités par province, zone, aire ou niveau équivalent.
```

---

### 3.4. `systeme.T_Licence`

Cette table représente les licences attribuées aux entités.

Rôle principal :

- gérer la période de validité ;
- savoir si une licence est active ou expirée ;
- rattacher la licence à une entité ;
- contrôler l’accès selon la validité de la licence.

Colonnes importantes :

- `IdLicence`
- `IdEntiteFk`
- `DateDebut`
- `DateFin`
- `IdStatutLicenceFk`
- `ValideLicence`
- `ExpireeLicence`

Règles métier :

```text
Une licence est active si elle est valide et non expirée.
Une licence est expirée si DateFin < CURRENT_DATE ou si ExpireeLicence = true.
Une entité avec licence expirée peut être bloquée ou signalée selon la politique applicative.
```

---

### 3.5. `systeme.T_Login`

Cette table représente l’historique des connexions et déconnexions.

Rôle principal :

- journaliser les connexions ;
- journaliser les déconnexions ;
- identifier l’utilisateur connecté ;
- rattacher l’événement à une entité ;
- connaître le type de login.

Colonnes importantes :

- `IdLogin`
- `DateLogin`
- `IdUserFk`
- `IdTypeLoginFk`
- `IdEntiteFk`

Règles métier :

```text
Chaque connexion ou déconnexion doit être historisée.
Le type de login vient du référentiel.
L’historique de connexion est en lecture seule côté interface Administration.
```

---

### 3.6. `systeme.T_Audit_Log`

Cette table représente l’historique officiel des modifications système.

Rôle principal :

- tracer les insertions ;
- tracer les modifications ;
- tracer les suppressions ;
- conserver les anciennes données ;
- conserver les nouvelles données ;
- identifier la table modifiée ;
- identifier l’entité concernée lorsque disponible.

Colonnes importantes :

- `IdLog`
- `TableName`
- `Operation`
- `ChangedAt`
- `IdEntiteFk`
- `OldData`
- `NewData`

Règles métier :

```text
T_Audit_Log est l’historique officiel des changements.
Les journaux d’audit doivent être consultables mais non modifiables depuis l’interface.
OldData contient l’état avant modification.
NewData contient l’état après modification.
```

---

### 3.7. `systeme.T_Fk_Correspondance`

Cette table représente les correspondances utilisées pour relier les champs techniques, les vues, les catégories et les valeurs affichables côté frontend.

Rôle principal :

- documenter les FK utilisées dans les vues ;
- indiquer le module concerné ;
- indiquer le schéma et la vue ;
- indiquer le champ source ;
- indiquer le type de mapping ;
- lier une FK à une catégorie générique ou à une référence ;
- gérer les mappings par portée globale, entité, tenant ou scope spécifique.

Colonnes importantes :

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

Règles métier :

```text
Une correspondance FK active doit avoir ValideFkCorrespondance = true.
Une correspondance peut être globale ou spécifique à une portée.
Les correspondances FK doivent faciliter l’affichage des libellés et des listes de choix dans le frontend.
Les modifications des correspondances FK doivent être auditées.
```

---

### 3.8. `systeme.T_Admin_UI_Setting`

Cette table représente les paramètres d’interface d’administration.

Rôle principal :

- stocker les paramètres globaux de l’application ;
- gérer les paramètres par entité, utilisateur ou module ;
- gérer le thème, la langue, le fuseau horaire, le format de date et le logo ;
- gérer les informations visibles dans l’interface Administration ;
- permettre l’audit des modifications des paramètres d’interface.

Colonnes importantes recommandées :

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

Règles métier :

```text
Les paramètres UI doivent être modifiables uniquement par un administrateur ou un utilisateur autorisé.
Un paramètre système ne doit pas être supprimé depuis l’interface.
Un paramètre non éditable doit être affiché en lecture seule.
Les changements doivent être tracés dans T_Audit_Log.
UpdatedAt doit être mis à jour automatiquement lors d’une modification.
La combinaison SettingScope + ScopeValue + SettingKey doit être unique.
```

Portées recommandées :

| SettingScope | Usage                                 | Exemple ScopeValue |
| ------------ | ------------------------------------- | ------------------ |
| `global`     | paramètre général de l’application    | `NULL`             |
| `entite`     | paramètre spécifique à une entité     | `12`               |
| `user`       | paramètre spécifique à un utilisateur | `5`                |
| `module`     | paramètre spécifique à un module      | `logistique`       |

Types de paramètres recommandés :

| SettingType | Usage                 | Exemple              |
| ----------- | --------------------- | -------------------- |
| `text`      | texte simple          | nom de l’application |
| `textarea`  | texte long            | adresse              |
| `number`    | valeur numérique      | lignes par page      |
| `boolean`   | vrai/faux             | sidebar réduite      |
| `select`    | liste de choix        | thème, langue        |
| `color`     | couleur               | couleur principale   |
| `file`      | fichier               | logo                 |
| `email`     | adresse email         | email administrateur |
| `phone`     | téléphone             | contact admin        |
| `url`       | lien                  | URL support          |
| `json`      | configuration avancée | options complexes    |

Groupes recommandés pour l’interface :

```text
general        = nom application, langue, fuseau horaire, format de date
theme          = thème, couleur principale, logo
contact        = email, téléphone, adresse
display        = affichage, pagination, menu latéral
security       = sécurité UI et restrictions
notifications  = préférences de notification
integrations   = options d’intégration
```

Scénario de gestion :

```text
1. L’administrateur ouvre l’écran Paramètres UI.
2. Le frontend lit les paramètres depuis systeme.V_Admin_UI_Setting.
3. Les paramètres sont regroupés par SettingGroup.
4. L’utilisateur modifie une valeur autorisée.
5. Le backend met à jour systeme.T_Admin_UI_Setting.
6. Le trigger met automatiquement UpdatedAt à jour.
7. Le mécanisme d’audit écrit l’ancienne et la nouvelle valeur dans T_Audit_Log.
8. L’historique est consulté depuis systeme.V_Admin_UI_Setting_Audit.
```

Structure SQL recommandée :

```sql
CREATE TABLE IF NOT EXISTS systeme."T_Admin_UI_Setting"
(
    "IdAdminUISetting" integer NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    "SettingScope" character varying(50) NOT NULL DEFAULT 'global',
    "ScopeValue" character varying(100),
    "SettingKey" character varying(100) NOT NULL,
    "SettingLabel" character varying(150),
    "SettingGroup" character varying(100) DEFAULT 'general',
    "SettingValue" text,
    "SettingValueJson" jsonb,
    "SettingType" character varying(50) DEFAULT 'text',
    "DisplayOrder" integer DEFAULT 0,
    "IsEditable" boolean DEFAULT true,
    "IsSystem" boolean DEFAULT false,
    "ValideSetting" boolean DEFAULT true,
    "CreatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "UpdatedByUserFk" integer,
    "ObsSetting" text,

    CONSTRAINT "Pk_Admin_UI_Setting" PRIMARY KEY ("IdAdminUISetting"),

    CONSTRAINT "Fk_Admin_UI_Setting_User" FOREIGN KEY ("UpdatedByUserFk")
        REFERENCES systeme."T_Utilisateurs" ("IdUser")
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" UNIQUE
        ("SettingScope", "ScopeValue", "SettingKey"),

    CONSTRAINT "Ck_Admin_UI_Setting_Scope" CHECK
        ("SettingScope" IN ('global', 'entite', 'user', 'module')),

    CONSTRAINT "Ck_Admin_UI_Setting_Type" CHECK
        ("SettingType" IN (
            'text', 'number', 'boolean', 'select', 'json', 'color',
            'file', 'email', 'phone', 'url', 'textarea'
        ))
);
```

Données initiales recommandées :

```sql
INSERT INTO systeme."T_Admin_UI_Setting"
(
    "SettingScope", "ScopeValue", "SettingKey", "SettingLabel",
    "SettingGroup", "SettingValue", "SettingType",
    "DisplayOrder", "IsEditable", "IsSystem", "ValideSetting"
)
VALUES
('global', NULL, 'app_name', 'Nom de l’application', 'general', 'SauverNdeko', 'text', 1, true, true, true),
('global', NULL, 'default_language', 'Langue par défaut', 'general', 'fr', 'select', 2, true, true, true),
('global', NULL, 'timezone', 'Fuseau horaire', 'general', 'Africa/Kinshasa', 'select', 3, true, true, true),
('global', NULL, 'date_format', 'Format de date', 'general', 'DD/MM/YYYY', 'select', 4, true, true, true),
('global', NULL, 'theme', 'Thème', 'theme', 'light', 'select', 5, true, false, true),
('global', NULL, 'accent_color', 'Couleur principale', 'theme', '#0d6efd', 'color', 6, true, false, true),
('global', NULL, 'logo_path', 'Logo de l’application', 'theme', '/assets/logo.png', 'file', 7, true, false, true),
('global', NULL, 'admin_email', 'Email administrateur', 'contact', 'admin@sauverndeko.cd', 'email', 8, true, false, true),
('global', NULL, 'admin_phone', 'Téléphone administrateur', 'contact', '+243 000 000 000', 'phone', 9, true, false, true),
('global', NULL, 'admin_address', 'Adresse', 'contact', 'Kinshasa, RDC', 'textarea', 10, true, false, true),
('global', NULL, 'items_per_page', 'Nombre de lignes par page', 'display', '10', 'number', 11, true, false, true),
('global', NULL, 'sidebar_collapsed', 'Menu latéral réduit par défaut', 'display', 'false', 'boolean', 12, true, false, true)
ON CONFLICT ("SettingScope", "ScopeValue", "SettingKey") DO NOTHING;
```

Trigger `UpdatedAt` recommandé :

```sql
CREATE OR REPLACE FUNCTION systeme.fn_admin_ui_setting_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW."UpdatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_admin_ui_setting_set_updated_at
ON systeme."T_Admin_UI_Setting";

CREATE TRIGGER tr_admin_ui_setting_set_updated_at
BEFORE UPDATE ON systeme."T_Admin_UI_Setting"
FOR EACH ROW
EXECUTE FUNCTION systeme.fn_admin_ui_setting_set_updated_at();
```

Vue frontend recommandée :

```sql
CREATE OR REPLACE VIEW systeme."V_Admin_UI_Setting" AS
SELECT
    s."IdAdminUISetting",
    s."SettingScope",
    s."ScopeValue",
    s."SettingKey",
    s."SettingLabel",
    s."SettingGroup",
    s."SettingValue",
    s."SettingValueJson",
    s."SettingType",
    s."DisplayOrder",
    s."IsEditable",
    s."IsSystem",
    s."ValideSetting",
    s."CreatedAt",
    s."UpdatedAt",
    s."UpdatedByUserFk",
    COALESCE(
        NULLIF(TRIM(concat(COALESCE(u."PrenomUser", ''), ' ', COALESCE(u."NomUser", ''))), ''),
        CASE
            WHEN s."UpdatedByUserFk" IS NOT NULL THEN 'Utilisateur #' || s."UpdatedByUserFk"
            ELSE NULL
        END
    ) AS "UpdatedByName",
    s."ObsSetting"
FROM systeme."T_Admin_UI_Setting" s
LEFT JOIN systeme."T_Utilisateurs" u
    ON u."IdUser" = s."UpdatedByUserFk"
WHERE s."ValideSetting" = true
ORDER BY s."SettingGroup", s."DisplayOrder", s."SettingLabel";
```

Vue de regroupement recommandée :

```sql
CREATE OR REPLACE VIEW systeme."V_Admin_UI_Setting_Group" AS
SELECT
    "SettingGroup",
    COUNT(*) AS "NbParametres",
    COUNT(*) FILTER (WHERE "IsEditable" = true) AS "NbEditables",
    COUNT(*) FILTER (WHERE "IsSystem" = true) AS "NbSysteme",
    MAX("UpdatedAt") AS "DerniereModification"
FROM systeme."T_Admin_UI_Setting"
WHERE "ValideSetting" = true
GROUP BY "SettingGroup"
ORDER BY "SettingGroup";
```

---

## 4. Tables de référence

### 4.1. `referentiel.T_CategorieGenerique`

Cette table représente les catégories de valeurs génériques.

Exemples :

- Type entité ;
- Role ;
- Type login ;
- Statut licence ;
- autres catégories utilisées par l’application.

---

### 4.2. `referentiel.T_Generique`

Cette table représente les valeurs de référence.

Exemples :

- Admin ;
- Manager ;
- Connexion ;
- Déconnexion ;
- Active ;
- Expirée ;
- Ecole ;
- Hôpital ;
- Centre de santé.

Règle métier :

```text
Les listes déroulantes du frontend doivent utiliser les valeurs actives du référentiel.
Les champs visibles doivent respecter les colonnes VisibleUsers, VisibleAll et les autres indicateurs de visibilité selon le contexte.
```

---

## 5. Vues système utilisées par le frontend

### 5.1. `systeme.V_Audit_log`

Rôle : afficher les journaux d’audit généraux.

Champs principaux :

- `IdLog`
- `TableName`
- `Operation`
- `ChangedAt`
- `NomEntite`
- `OldData`
- `NewData`

Usage frontend :

```text
Écran Journaux d’audit.
Lecture seule.
Filtres par table, opération, entité et période.
```

---

### 5.2. `systeme.V_Admin_UI_Setting_Audit`

Rôle : afficher les modifications des paramètres d’interface.

Champs principaux :

- `IdLog`
- `TableName`
- `Operation`
- `ChangedAt`
- `SettingScope`
- `UpdatedByName`
- `UpdatedByUserId`
- `UpdatedSettingAt`
- `OldData`
- `NewData`

Usage frontend :

```text
Écran Paramètres UI / Audit paramètres.
Lecture seule pour l’historique.
Permet de savoir qui a modifié quel paramètre et à quelle portée.
```

---

### 5.3. `systeme.V_Fk_Correspondance`

Rôle : afficher une vue consolidée des correspondances FK.

Champs principaux :

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
- `MappingValues`
- `CategoryLabels`
- `HasDefaultMapping`
- `HasActiveMapping`
- `SettingScope`
- `ScopeValue`
- `NbCorrespondances`
- `UpdatedAt`

Usage frontend :

```text
Écran Correspondances FK.
Vue synthétique.
Permet de voir les mappings actifs, les catégories et le nombre de correspondances.
```

---

### 5.4. `systeme.V_Fk_Correspondance_Detail`

Rôle : afficher le détail des correspondances FK.

Champs principaux :

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
- `NomCategorieGenerique`
- `MappingValue`
- `IsDefaultMapping`
- `ValideFkCorrespondance`
- `SettingScope`
- `ScopeValue`
- `DisplayOrder`
- `UpdatedAt`
- `UpdatedByUserFk`
- `UpdatedByName`
- `ObsFkCorrespondance`

Usage frontend :

```text
Écran détail ou édition des correspondances FK.
Permet de gérer les mappings par champ, module, vue et catégorie.
```

---

### 5.5. `systeme.V_Fk_Correspondance_Audit`

Rôle : afficher l’audit spécifique des correspondances FK.

Champs principaux :

- `IdLog`
- `TableName`
- `Operation`
- `ChangedAt`
- `SettingScope`
- `ScopeValue`
- `UpdatedByName`
- `UpdatedByUserId`
- `UpdatedSettingAt`
- `OldData`
- `NewData`

Usage frontend :

```text
Onglet Audit dans l’écran Correspondances FK.
Lecture seule.
```

---

### 5.6. `systeme.V_Entite_Localisation_Detail`

Rôle : afficher les entités avec leurs informations de localisation.

Champs principaux :

- `IdEntiteLocalisation`
- `IdEntite`
- `NomEntite`
- `PhoneEntite`
- `EmailEntite`
- `AdresseEntite`
- `IdTypeEntiteFk`
- `TypeEntite`
- `Latitude`
- `Longitude`
- `AdresseDetaillee`
- `DateCreation`
- `IdNiveau_3_Fk`
- `NomNiveau_3`
- `IdNiveau_4_Fk`
- `NomNiveau_4`
- `IdNiveau_5_Fk`
- `NomNiveau_5`

Usage frontend :

```text
Écran Localisations entités.
Tableau + carte.
Filtres par type entité, niveau 3, niveau 4 et niveau 5.
```

---

### 5.7. `systeme.V_Licence_active`

Rôle : afficher les licences et leur statut calculé.

Champs principaux :

- `IdLicence`
- `IdEntiteFk`
- `NomEntite`
- `DateDebut`
- `DateFin`
- `ValideLicence`
- `ExpireeLicence`
- `statut_licence`

Règle de calcul :

```sql
CASE
    WHEN DateFin < CURRENT_DATE THEN 'Expirée'
    WHEN ExpireeLicence = true THEN 'Expirée'
    ELSE 'Active'
END
```

Usage frontend :

```text
Écran Licences.
Badge Active / Expirée.
Alerte pour les licences proches de l’expiration.
```

---

### 5.8. `systeme.V_Login_history`

Rôle : afficher l’historique de connexion des utilisateurs.

Champs principaux :

- `IdLogin`
- `DateLogin`
- `IdTypeLoginFk`
- `TypeLogin`
- `IdUser`
- `NomUser`
- `PrenomUser`
- `EmailUser`
- `IdEntite`
- `NomEntite`

Usage frontend :

```text
Écran Historique de connexion.
Lecture seule.
Filtres par type login, utilisateur, entité et période.
```

---

### 5.9. `systeme.V_User_profil`

Rôle : afficher les profils utilisateurs et leur rattachement aux entités.

Champs principaux :

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
- `IdEntite`
- `NomEntite`
- `EmailEntite`
- `PhoneEntite`

Usage frontend :

```text
Écran Profils utilisateurs.
Permet de visualiser les profils, leur statut, leurs privilèges et leur entité.
```

---

## 6. Vues référentielles utilisées par l’administration

### 6.1. `referentiel.V_CategorieGenerique`

Rôle : afficher les catégories génériques.

Champs principaux :

- `ID_CategorieGenerique`
- `NomCategorieGenerique`
- `ModuleCategorieGenerique`
- `ValideCategorieGenerique`

Usage frontend :

```text
Alimenter les filtres de catégories et les écrans de paramétrage.
```

---

### 6.2. `referentiel.V_Generique`

Rôle : afficher les valeurs génériques avec leurs paramètres de visibilité.

Champs principaux :

- `ID_CategorieGeneriqueFk`
- `NomCategorieGenerique`
- `ModuleCategorieGenerique`
- `ID_Generique`
- `NomGenerique`
- `AbrGenerique`
- `VisibleNiveau_2`
- `VisibleNiveau_3`
- `VisibleNiveau_4`
- `VisibleNiveau_5`
- `VisibleArticle`
- `VisibleCmd`
- `VisibleFacture`
- `VisibleUsers`
- `VisibleVoie`
- `VisibleAll`
- `ObsGenerique`
- `ValideGenerique`

Usage frontend :

```text
Alimenter les listes déroulantes : rôle, type entité, type login, statut licence et autres valeurs génériques.
```

---

## 7. Écrans attendus dans l’interface Administration

### 7.1. Tableau de bord

Objectif : afficher une vue d’ensemble du module Administration.

Indicateurs recommandés :

- nombre d’utilisateurs ;
- nombre d’entités ;
- licences actives ;
- licences expirées ;
- connexions du jour ;
- événements d’audit récents ;
- correspondances FK actives ;
- paramètres modifiés récemment.

Sources recommandées :

- `systeme.V_User_profil`
- `systeme.V_Licence_active`
- `systeme.V_Login_history`
- `systeme.V_Audit_log`
- `systeme.V_Fk_Correspondance`
- `systeme.V_Admin_UI_Setting_Audit`

---

### 7.2. Utilisateurs

Objectif : gérer les comptes utilisateurs.

Source principale :

- table `systeme.T_Utilisateurs` pour CRUD ;
- vue `systeme.V_User_profil` pour lecture enrichie.

Colonnes recommandées :

- ID utilisateur ;
- nom ;
- prénom ;
- email ;
- téléphone ;
- sexe ;
- entité ;
- staff ;
- admin ;
- statut ;
- date création ;
- actions.

Actions recommandées :

- Ajouter ;
- Modifier ;
- Désactiver ;
- Réinitialiser mot de passe ;
- Voir profil ;
- Exporter ;
- Imprimer.

Règles métier :

```text
Ne pas supprimer physiquement un utilisateur si des données métier lui sont liées.
Préférer la désactivation via ValideUser.
Le mot de passe doit être stocké sous forme sécurisée/hachée.
Les changements sensibles doivent être audités.
```

---

### 7.3. Profils utilisateurs

Objectif : consulter les profils enrichis des utilisateurs.

Source principale :

- `systeme.V_User_profil`

Colonnes recommandées :

- ID utilisateur ;
- nom ;
- prénom ;
- email ;
- téléphone ;
- sexe ;
- actif ;
- staff ;
- admin ;
- date création ;
- entité ;
- email entité ;
- téléphone entité ;
- actions.

Actions recommandées :

- Voir profil ;
- Modifier ;
- Exporter ;
- Imprimer.

---

### 7.4. Rôles

Objectif : gérer ou consulter les rôles utilisateurs.

Source recommandée :

- `referentiel.V_Generique` filtrée sur la catégorie `Role`.

Colonnes recommandées :

- ID rôle ;
- code / abréviation ;
- nom rôle ;
- module ;
- visibilité utilisateurs ;
- actif ;
- observations ;
- actions.

Actions recommandées :

- Ajouter ;
- Modifier ;
- Désactiver ;
- Voir ;
- Exporter ;
- Imprimer.

Règle métier :

```text
Les rôles utilisés par des utilisateurs ne doivent pas être supprimés brutalement.
Préférer la désactivation si nécessaire.
```

---

### 7.5. Permissions

Objectif : gérer les permissions fonctionnelles.

Source recommandée :

- selon la table de permissions si elle existe dans le backend ;
- sinon `referentiel.V_Generique` peut être utilisé provisoirement pour les droits paramétrables.

Colonnes recommandées :

- code permission ;
- nom permission ;
- module ;
- description ;
- niveau d’accès ;
- statut ;
- date mise à jour ;
- actions.

Actions recommandées :

- Ajouter ;
- Modifier ;
- Désactiver ;
- Voir ;
- Exporter ;
- Imprimer.

Règle métier :

```text
Les permissions critiques doivent être modifiables uniquement par un administrateur.
Toute modification de permission doit être auditée.
```

---

### 7.6. Journaux d’audit

Objectif : consulter les changements système.

Source principale :

- `systeme.V_Audit_log`

Colonnes recommandées :

- ID log ;
- date/heure ;
- table ;
- entité ;
- opération ;
- anciennes données ;
- nouvelles données ;
- actions.

Actions recommandées :

- Voir détail ;
- Filtrer ;
- Exporter ;
- Imprimer.

Règles métier :

```text
Les journaux d’audit sont en lecture seule.
Ils ne doivent pas être modifiés ni supprimés depuis le frontend.
OldData et NewData doivent être affichés de façon lisible, idéalement dans un panneau de détail JSON.
```

---

### 7.7. Correspondances FK

Objectif : gérer les mappings entre les FK techniques et les valeurs lisibles côté frontend.

Sources principales :

- `systeme.V_Fk_Correspondance`
- `systeme.V_Fk_Correspondance_Detail`
- `systeme.V_Fk_Correspondance_Audit`

Colonnes recommandées pour la liste :

- module ;
- schéma ;
- vue ;
- clé source ;
- champ ;
- libellé ;
- type mapping ;
- valeurs mapping ;
- catégories ;
- scope ;
- nombre correspondances ;
- actif ;
- mis à jour le ;
- actions.

Actions recommandées :

- Filtres ;
- Correspondances FK ;
- Exporter ;
- Navigation ;
- Audit ;
- Réinitialiser ;
- Voir détail ;
- Modifier ;
- Désactiver.

Règles métier :

```text
Une correspondance inactive ne doit pas être utilisée pour alimenter les libellés frontend.
Les correspondances par scope doivent surcharger les correspondances globales si la logique applicative le prévoit.
Toute modification doit être visible dans V_Fk_Correspondance_Audit.
```

---

### 7.8. Localisations entités

Objectif : afficher les entités et leurs coordonnées.

Source principale :

- `systeme.V_Entite_Localisation_Detail`

Colonnes recommandées :

- ID localisation ;
- entité ;
- type entité ;
- téléphone ;
- email ;
- latitude ;
- longitude ;
- niveau 3 ;
- niveau 4 ;
- niveau 5 ;
- adresse détaillée ;
- actions.

Actions recommandées :

- Ajouter ;
- Modifier ;
- Voir sur carte ;
- Exporter ;
- Imprimer.

Règles métier :

```text
Une entité sans coordonnées peut être listée mais doit être signalée.
La carte doit utiliser Latitude et Longitude.
Les filtres géographiques doivent utiliser les niveaux 3, 4 et 5.
```

---

### 7.9. Licences

Objectif : suivre les licences des entités.

Source principale :

- `systeme.V_Licence_active`

Colonnes recommandées :

- ID licence ;
- entité ;
- date début ;
- date fin ;
- valide ;
- expirée ;
- statut licence ;
- actions.

Actions recommandées :

- Ajouter ;
- Modifier ;
- Renouveler ;
- Voir ;
- Exporter ;
- Imprimer.

Règles métier :

```text
Une licence expirée doit être affichée en rouge.
Une licence active doit être affichée en vert.
Une licence proche de l’expiration doit être signalée en orange.
Le renouvellement doit prolonger DateFin ou créer une nouvelle période selon la stratégie retenue.
```

---

### 7.10. Historique de connexion

Objectif : consulter les connexions et déconnexions.

Source principale :

- `systeme.V_Login_history`

Colonnes recommandées :

- ID login ;
- date login ;
- type login ;
- ID utilisateur ;
- nom ;
- prénom ;
- email ;
- entité ;
- actions.

Actions recommandées :

- Filtrer ;
- Exporter ;
- Imprimer ;
- Audit.

Règles métier :

```text
L’historique de connexion est en lecture seule.
Les connexions réussies peuvent être affichées en vert.
Les déconnexions en orange ou gris.
Les échecs de connexion, si disponibles, en rouge.
```

---

### 7.11. Paramètres UI

Objectif : gérer les paramètres d’interface.

Sources recommandées :

- table `systeme.T_Admin_UI_Setting` pour les paramètres ;
- vue `systeme.V_Admin_UI_Setting_Audit` pour l’historique.

Actions recommandées :

- Modifier ;
- Enregistrer ;
- Annuler ;
- Voir audit ;
- Exporter audit.

Règles métier :

```text
Les paramètres UI peuvent être globaux ou spécifiques à un scope.
Tout changement doit être audité.
L’audit doit indiquer UpdatedByName, UpdatedByUserId, SettingScope et UpdatedSettingAt.
```

---

## 8. Règles de sécurité et de contrôle

### 8.1. Utilisateurs

```text
Un utilisateur inactif ne doit pas accéder au système.
La désactivation est préférable à la suppression physique.
Les mots de passe doivent être hachés.
La réinitialisation de mot de passe doit être auditée.
Les utilisateurs administrateurs doivent être clairement identifiables.
```

### 8.2. Audit

```text
Les logs d’audit sont en lecture seule.
Ils doivent tracer les changements sur les tables sensibles.
Les opérations INSERT, UPDATE et DELETE doivent être distinguées.
OldData et NewData doivent rester disponibles pour contrôle.
```

### 8.3. Correspondances FK

```text
Les correspondances FK actives alimentent les libellés et listes côté frontend.
Les mappings par scope doivent être contrôlés.
Les modifications doivent être auditées.
```

### 8.4. Licences

```text
Une licence expirée doit être signalée.
Une licence proche de l’expiration doit générer une alerte visuelle.
Les licences doivent être rattachées à une entité.
```

### 8.5. Connexions

```text
Les connexions doivent être historisées.
Les historiques de connexion doivent être filtrables par utilisateur, entité, type et période.
```

---

## 9. Cas de test attendus

### Test 1 — Création d’une entité

```text
Créer une entité avec nom, téléphone, email, adresse et type entité.
Attendu :
- l’entité est créée dans systeme.T_Entite ;
- elle peut être rattachée à un utilisateur ;
- elle peut être rattachée à une licence ;
- elle apparaît dans les vues liées.
```

---

### Test 2 — Création d’un utilisateur

```text
Créer un utilisateur avec nom, prénom, email, téléphone, rôle, sexe et entité.
Attendu :
- l’utilisateur est créé dans systeme.T_Utilisateurs ;
- il apparaît dans systeme.V_User_profil ;
- son entité est visible ;
- son statut est actif par défaut si prévu.
```

---

### Test 3 — Désactivation d’un utilisateur

```text
Désactiver un utilisateur.
Attendu :
- ValideUser devient false ;
- l’utilisateur apparaît comme inactif ;
- la modification est tracée dans systeme.T_Audit_Log si l’audit est configuré.
```

---

### Test 4 — Connexion utilisateur

```text
Insérer un événement de connexion dans systeme.T_Login.
Attendu :
- l’événement apparaît dans systeme.V_Login_history ;
- le type login est affiché ;
- l’utilisateur et l’entité sont visibles.
```

---

### Test 5 — Création d’une licence

```text
Créer une licence pour une entité avec DateDebut et DateFin.
Attendu :
- la licence est visible dans systeme.V_Licence_active ;
- statut_licence = Active si DateFin >= CURRENT_DATE et ExpireeLicence = false ;
- statut_licence = Expirée si DateFin < CURRENT_DATE ou ExpireeLicence = true.
```

---

### Test 6 — Audit général

```sql
SELECT *
FROM systeme."V_Audit_log"
ORDER BY "ChangedAt" DESC;
```

Attendu :

```text
Les opérations récentes sont visibles avec TableName, Operation, ChangedAt, OldData et NewData.
```

---

### Test 7 — Correspondances FK

```sql
SELECT *
FROM systeme."V_Fk_Correspondance";
```

Attendu :

```text
Les correspondances sont regroupées par module, schéma, vue, champ, type mapping et scope.
Le nombre de correspondances est calculé.
Les mappings actifs sont visibles.
```

---

### Test 8 — Audit des correspondances FK

```sql
SELECT *
FROM systeme."V_Fk_Correspondance_Audit"
ORDER BY "ChangedAt" DESC;
```

Attendu :

```text
Les modifications des correspondances FK sont visibles avec l’utilisateur, le scope, les anciennes données et les nouvelles données.
```

---

### Test 9 — Localisation des entités

```sql
SELECT *
FROM systeme."V_Entite_Localisation_Detail";
```

Attendu :

```text
Les entités sont affichées avec leur type, coordonnées, adresse détaillée et niveaux géographiques.
```

---

### Test 10 — Référentiel

```sql
SELECT *
FROM referentiel."V_CategorieGenerique";

SELECT *
FROM referentiel."V_Generique";
```

Attendu :

```text
Les catégories et valeurs génériques sont disponibles pour alimenter les filtres et listes déroulantes.
```

---

### Test 8 — Modification d’un paramètre UI

```text
Modifier le paramètre global theme de light vers dark.

Attendu :
- SettingValue = dark dans systeme.T_Admin_UI_Setting.
- UpdatedAt est mis à jour automatiquement.
- UpdatedByUserFk contient l’utilisateur ayant modifié.
- Une trace est visible dans systeme.V_Admin_UI_Setting_Audit.
```

### Test 9 — Unicité des paramètres UI

```text
Créer deux paramètres avec le même SettingScope, ScopeValue et SettingKey.

Attendu :
- La deuxième insertion est rejetée par Uq_Admin_UI_Setting_Key_Scope.
```

### Test 10 — Paramètre non éditable

```text
Afficher un paramètre avec IsEditable = false.

Attendu :
- Le frontend l’affiche en lecture seule.
- Le bouton Modifier est désactivé pour ce paramètre.
```

---

## 10. Prompts UI Administration

### 10.1. Prompt standard — Administration

```text
Créer une maquette d’interface web professionnelle pour le module Administration de l’application SauverNdeko.

L’interface doit être en français, au format desktop 4:3, avec un style moderne SaaS/admin dashboard.

Structure générale :
- Barre latérale verticale à gauche, bleu foncé.
- Logo SauverNdeko en haut.
- Sous le logo, afficher “Administration”.
- Menus avec icônes :
  - Tableau de bord
  - Utilisateurs
  - Rôles
  - Permissions
  - Journaux d’audit
  - Correspondances FK
  - Localisations entités
  - Licences
  - Historique de connexion
  - Profils utilisateurs
  - Paramètres UI
- Le menu actif doit être mis en évidence avec un fond bleu lumineux.
- En bas de la barre latérale, afficher un bloc utilisateur avec avatar, nom “Admin” et rôle “Administrateur”.

Zone principale :
- Fond clair blanc légèrement bleuté.
- En haut à droite, afficher une icône de notification et un avatar rond avec les initiales “AD”.
- Afficher un titre principal selon l’écran.
- Afficher un sous-titre descriptif.
- Utiliser des cartes blanches, coins arrondis, ombres légères, boutons propres et badges de statut.
```

---

### 10.2. Prompt — Tableau de bord Administration

```text
Créer une maquette d’interface web professionnelle pour le Tableau de bord du module Administration de SauverNdeko.

Le menu “Tableau de bord” doit être actif.

Titre : “Tableau de bord”.
Sous-titre : “Vue d’ensemble du module Administration”.

Afficher une rangée de cartes statistiques :
- Utilisateurs
- Entités
- Licences actives
- Licences expirées
- Connexions du jour
- Journaux d’audit
- Correspondances FK actives

Ajouter une barre d’actions avec :
- Filtres
- Exporter
- Navigation
- Audit

Créer des blocs analytiques :
- Activités récentes
- Répartition des utilisateurs par rôle
- Derniers journaux d’audit
- Activités par module
- Correspondances FK récentes
- État système

Utiliser des badges :
- Succès en vert
- Alerte en orange
- Erreur en rouge
- Information en bleu ou gris.
```

---

### 10.3. Prompt — Utilisateurs

```text
Créer une maquette d’interface web professionnelle pour l’écran Utilisateurs du module Administration de SauverNdeko.

Le menu “Utilisateurs” doit être actif.

Titre : “Utilisateurs”.
Sous-titre : “Gestion des utilisateurs du système”.

Boutons d’action :
- Ajouter
- Modifier
- Désactiver
- Réinitialiser mot de passe
- Exporter
- Imprimer

Ajouter une recherche : “Rechercher un utilisateur...”.

Filtres :
- Entité
- Rôle
- Statut
- Sexe
- Date création
- Autre filtre

Tableau :
- ID
- Nom d’utilisateur
- Nom complet
- Email
- Téléphone
- Sexe
- Entité
- Rôle
- Statut
- Date création
- Actions

Badges :
- Actif en vert
- Inactif en rouge ou gris
- Admin en violet
- Staff en bleu.
```

---

### 10.4. Prompt — Journaux d’audit

```text
Créer une maquette d’interface web professionnelle pour l’écran Journaux d’audit du module Administration de SauverNdeko.

Le menu “Journaux d’audit” doit être actif.

Titre : “Journaux d’audit”.
Sous-titre : “Historique des activités système”.

Actions :
- Filtres
- Exporter
- Imprimer
- Audit

Filtres :
- Table
- Opération
- Entité
- Utilisateur
- Date début
- Date fin

Recherche : “Rechercher dans les journaux...”.

Tableau :
- ID log
- Date/Heure
- Table
- Entité
- Opération
- Anciennes données
- Nouvelles données
- Actions

Badges :
- INSERT en vert
- UPDATE en bleu ou orange
- DELETE en rouge

L’écran doit être en lecture seule.
```

---

### 10.5. Prompt — Correspondances FK

```text
Créer une maquette d’interface web professionnelle pour l’écran Correspondances FK du module Administration de SauverNdeko.

Le menu “Correspondances FK” doit être actif.

Titre : “Correspondances FK”.
Sous-titre : “Gestion des correspondances de clés étrangères et mappings du frontend”.

Boutons obligatoires :
- Filtres
- Correspondances FK
- Exporter
- Navigation
- Audit

Recherche : “Rechercher un module, une vue, un champ ou une valeur de mapping...”.

Filtres :
- Module
- Schéma
- Vue
- Type mapping
- Scope
- Statut

Tableau principal :
- Module
- Schéma
- Vue
- Clé source
- Champ
- Libellé
- Type mapping
- Valeurs de mapping
- Catégories
- Scope
- Nombre correspondances
- Actif
- Mis à jour le
- Actions

Ajouter un bloc “Aperçu audit des dernières modifications”.

Badges :
- Actif en vert
- Inactif en gris
- Liste en vert
- Valeur fixe en bleu
- Global en bleu ou gris
- Tenant ou entité en violet.
```

---

### 10.6. Prompt — Paramètres UI

```text
Créer une maquette d’interface web professionnelle pour l’écran Paramètres UI du module Administration de SauverNdeko.

Le menu “Paramètres UI” doit être actif.

Titre : “Paramètres UI”.
Sous-titre : “Configuration des paramètres de l’application”.

Structure attendue :
- Barre latérale Administration complète.
- Zone principale claire.
- Onglets horizontaux :
  - Général
  - Sécurité
  - Notifications
  - Thème
  - Intégrations
  - Audit

Source de données principale :
- systeme.V_Admin_UI_Setting pour les paramètres actifs.
- systeme.V_Admin_UI_Setting_Group pour le résumé par groupe.
- systeme.V_Admin_UI_Setting_Audit pour l’historique des modifications.

Champs à afficher dans l’onglet Général :
- Nom de l’application
- Langue par défaut
- Fuseau horaire
- Format de date
- Email administrateur
- Téléphone
- Adresse
- Scope paramètre

Champs à afficher dans l’onglet Thème :
- Thème clair/sombre
- Couleur principale
- Logo de l’application
- Menu latéral réduit par défaut
- Nombre de lignes par page

Actions principales :
- Modifier
- Enregistrer
- Annuler
- Voir audit
- Exporter audit
- Imprimer

Règles UI :
- Un paramètre avec IsEditable = false doit être affiché en lecture seule.
- Un paramètre avec IsSystem = true doit être marqué comme paramètre système.
- Les paramètres désactivés ne doivent pas être proposés dans les listes de configuration.
- Les changements doivent apparaître dans le bloc Audit des paramètres UI.

Bloc Audit des paramètres UI :
Afficher un tableau avec les colonnes :
- ID log
- Date / Heure
- Paramètre modifié
- Ancienne valeur
- Nouvelle valeur
- Scope
- Modifié par
- Actions

Badges :
- Paramètre actif en vert
- Paramètre système en bleu
- Non éditable en gris
- Modification réussie en vert
- Suppression ou désactivation en rouge

Style visuel :
- Interface SaaS/admin moderne.
- Cartes blanches avec coins arrondis.
- Boutons alignés proprement.
- Table audit lisible.
- Design cohérent avec les autres écrans Administration.
```

---

---

## 10.2. Scénario d’initialisation des correspondances FK par défaut

### 10.2.1. Objectif

Le script d’initialisation des correspondances FK permet de préparer automatiquement les correspondances utilisées par le frontend pour afficher les listes déroulantes, les libellés métier et les catégories référentielles.

Il concerne principalement la table :

```sql
systeme."T_Fk_Correspondance"
```

L’objectif est de garantir que les modules Administration, Géolocalisation et Logistique disposent déjà des mappings nécessaires après migration ou installation initiale.

Ce scénario complète la logique de l’écran **Correspondances FK** et permet au frontend de savoir comment relier certains champs techniques aux valeurs de référence.

---

### 10.2.2. Portée fonctionnelle

Le script initialise uniquement les correspondances de portée globale :

```text
SettingScope = global
ScopeValue = NULL
```

Il gère deux types de correspondances :

```text
generic_category = correspondance vers une catégorie de T_Generique
hierarchy_mode = mode de lecture des niveaux géographiques
```

Le script est prévu pour être rejouable.

Avant de réinsérer les valeurs, il supprime les correspondances globales déjà gérées pour les types :

```sql
MappingType IN ('generic_category', 'hierarchy_mode')
```

Règle métier :

```text
Les correspondances globales par défaut peuvent être réinitialisées sans supprimer les correspondances spécifiques à une entité, à un utilisateur ou à un autre scope.
```

---

### 10.2.3. Contrôle préalable

Avant l’initialisation, le script vérifie que la table existe :

```sql
to_regclass('systeme."T_Fk_Correspondance"')
```

Si la table est absente, le script bloque l’exécution avec une exception.

Règle métier :

```text
L’initialisation ne doit jamais créer silencieusement des correspondances si la table système attendue est absente.
```

---

### 10.2.4. Modules couverts

Les correspondances par défaut concernent trois grands ensembles.

#### A. Administration

Correspondances principales :

```text
roles              -> catégorie 39
entityTypes        -> catégorie 48
licenseStatuses   -> catégorie 55
```

Usage frontend :

```text
- listes déroulantes des rôles ;
- types d’entités ;
- statuts de licences ;
- écrans Utilisateurs, Rôles, Licences et Entités.
```

#### B. Géolocalisation

Correspondances principales :

```text
niveau2Types          -> catégorie 32
niveau3Types          -> catégorie 32
niveau4Types          -> catégorie 32
niveau5Types          -> catégorie 32
niveau2Statuses       -> catégorie 4
niveau3Statuses       -> catégorie 4
niveau4Statuses       -> catégorie 4
niveau5Statuses       -> catégorie 4
deploymentStatuses    -> catégorie 27
dpsAccessRoutes       -> catégorie 29
antBczAccessRoutes    -> catégorie 29
dpsBczAccessRoutes    -> catégorie 29
zsAsAccessRoutes      -> catégorie 29
zsSiteAccessRoutes    -> catégorie 29
networkAvailabilities -> catégorie 19
roofTypes             -> catégorie 18
```

Usage frontend :

```text
- formulaires géographiques ;
- listes des niveaux ;
- modes de filtrage hiérarchique ;
- informations de disponibilité réseau ;
- caractéristiques de sites ou structures.
```

#### C. Logistique

Correspondances principales :

```text
logistique.articleTypes                 -> catégorie 46
logistique.articleCategories            -> catégorie 40
logistique.articleUnits                 -> catégorie 34
logistique.commandeTypes                -> catégorie 64
logistique.commandeStatuses             -> catégorie 28
logistique.commandeConditionPaiements   -> catégorie 37
logistique.commandeModesPaiement        -> catégorie 36
logistique.reglementModes               -> catégorie 36
```

Usage frontend :

```text
- écran Articles ;
- écran Commandes ;
- écran Commande détail ;
- écran Suivi règlements ;
- bouton Correspondance FK ;
- listes déroulantes et filtres dynamiques.
```

---

### 10.2.5. Modes hiérarchiques géographiques

Le script initialise aussi les modes de lecture des niveaux géographiques.

Correspondances :

```text
niveaux0      -> all
niveaux1Old   -> all
niveaux1      -> filtered
niveaux2      -> filtered
niveaux3      -> filtered
niveaux4      -> filtered
niveaux5      -> filtered
```

Règle métier :

```text
Les premiers niveaux peuvent être chargés globalement.
Les niveaux dépendants doivent être filtrés selon le parent sélectionné.
```

Cela permet au frontend de savoir si une liste doit être chargée entièrement ou filtrée selon le contexte géographique.

---

### 10.2.6. Colonnes fonctionnelles de `T_Fk_Correspondance`

Les colonnes les plus importantes pour ce scénario sont :

```text
ModuleName
SchemaName
ViewName
SourceKey
FieldName
FieldLabel
MappingType
ReferenceSchemaName
ReferenceObjectName
ReferenceFieldName
TargetCategoryIdFk
MappingValue
IsDefaultMapping
ValideFkCorrespondance
SettingScope
ScopeValue
DisplayOrder
UpdatedAt
UpdatedByUserFk
ObsFkCorrespondance
```

Rôle des champs :

```text
ModuleName               = module applicatif concerné.
SchemaName               = schéma PostgreSQL concerné.
ViewName                 = vue concernée si applicable.
SourceKey                = clé utilisée côté frontend.
FieldName                = champ technique concerné.
FieldLabel               = libellé lisible pour l’interface.
MappingType              = type de mapping.
ReferenceSchemaName      = schéma de l’objet de référence.
ReferenceObjectName      = table ou vue de référence.
ReferenceFieldName       = champ de référence.
TargetCategoryIdFk       = catégorie générique ciblée.
MappingValue             = valeur de mapping.
IsDefaultMapping         = indique une correspondance par défaut.
ValideFkCorrespondance   = active ou désactive la correspondance.
SettingScope             = portée du mapping.
ScopeValue               = valeur de portée.
DisplayOrder             = ordre d’affichage.
UpdatedAt                = date de mise à jour.
UpdatedByUserFk          = utilisateur ayant modifié.
ObsFkCorrespondance      = observation.
```

---

### 10.2.7. Règle d’unicité et rejouabilité

Le script utilise une logique :

```sql
ON CONFLICT (...) DO UPDATE
```

La clé fonctionnelle de conflit repose sur :

```text
ModuleName
SchemaName
ViewName
SourceKey
FieldName
MappingType
MappingValue
SettingScope
ScopeValue
```

Règle métier :

```text
Si la correspondance existe déjà, elle est mise à jour.
Si elle n’existe pas, elle est créée.
```

Cela rend le script compatible avec les migrations répétées, les réinitialisations et les corrections de mappings.

---

### 10.2.8. Effet attendu après exécution

Après exécution, le script affiche un message de confirmation indiquant le nombre total de correspondances gérées présentes dans la table.

Exemple attendu :

```text
Initialisation FK terminée. X correspondance(s) gérée(s) présente(s) dans systeme.T_Fk_Correspondance.
```

Contrôle recommandé :

```sql
SELECT *
FROM systeme."V_Fk_Correspondance"
ORDER BY "ModuleName", "SchemaName", "SourceKey";
```

Contrôle détaillé :

```sql
SELECT *
FROM systeme."V_Fk_Correspondance_Detail"
ORDER BY "ModuleName", "SchemaName", "DisplayOrder", "FieldLabel";
```

Contrôle logistique :

```sql
SELECT *
FROM systeme."V_Fk_Correspondance_Detail"
WHERE "ModuleName" = 'logistique'
ORDER BY "SourceKey";
```

---

### 10.2.9. Impact sur l’écran Correspondances FK

L’écran **Correspondances FK** doit permettre de consulter et gérer ces mappings.

Colonnes recommandées :

```text
Module
Schéma
Vue
Clé source
Champ
Libellé
Type mapping
Objet de référence
Catégorie cible
Valeur mapping
Mapping par défaut
Actif
Scope
Ordre
Mis à jour le
Mis à jour par
Actions
```

Filtres recommandés :

```text
Module
Schéma
Vue
Type mapping
Catégorie cible
Scope
Actif / Inactif
```

Actions recommandées :

```text
Ajouter
Modifier
Désactiver
Réinitialiser global
Voir détail
Voir audit
Exporter
Imprimer
Autres filtres
```

Règles UI :

```text
Les correspondances par défaut doivent être distinguées visuellement.
Les correspondances inactives doivent être grisées.
Le bouton Réinitialiser global doit être utilisé avec prudence.
L’audit doit rester consultable pour tracer les changements.
```

Badges recommandés :

```text
generic_category = bleu
hierarchy_mode = violet
Mapping actif = vert
Mapping inactif = gris
Mapping par défaut = badge bleu clair
Scope global = badge gris ou bleu
```

---

### 10.2.10. Prompt UI — écran Correspondances FK amélioré

```text
Créer une maquette d’interface web professionnelle pour l’écran Correspondances FK du module Administration de SauverNdeko.

L’interface doit être en français, au format desktop 4:3, avec un style moderne SaaS/admin dashboard.

La barre latérale gauche doit afficher les menus Administration :
- Tableau de bord
- Utilisateurs
- Rôles
- Permissions
- Journaux d’audit
- Correspondances FK
- Localisations entités
- Licences
- Historique de connexion
- Profils utilisateurs
- Paramètres UI

Le menu “Correspondances FK” doit être actif.

Zone principale :
- Titre : “Correspondances FK”
- Sous-titre : “Gestion des mappings entre champs techniques, référentiels et listes frontend”
- Ajouter une barre de recherche : “Rechercher un module, une clé source, un champ ou une catégorie...”

Boutons d’action :
- Ajouter
- Modifier
- Désactiver
- Réinitialiser global
- Voir détail
- Voir audit
- Exporter
- Imprimer
- Autres filtres

Filtres :
- Module
- Schéma
- Vue
- Type mapping
- Catégorie cible
- Scope

Tableau principal :
Colonnes :
- Module
- Schéma
- Vue
- Clé source
- Champ
- Libellé
- Type mapping
- Objet référence
- Catégorie cible
- Valeur mapping
- Défaut
- Actif
- Scope
- Mis à jour le
- Mis à jour par
- Actions

Exemples de lignes :
1. logistique | logistique | V_Article | logistique.articleTypes | ID_TypeArticleFk | Type d’article | generic_category | referentiel.T_Generique | 46 | 46 | Oui | Actif | global | Admin
2. logistique | logistique | V_Commande | logistique.commandeStatuses | ID_StatutCmdFk | Statut commande | generic_category | referentiel.T_Generique | 28 | 28 | Oui | Actif | global | Admin
3. admin | referentiel | - | roles | roles | Role | generic_category | referentiel.T_Generique | 39 | 39 | Oui | Actif | global | Admin
4. admin | geolocalisation | - | niveaux3 | niveaux3 | Niveau 3 | hierarchy_mode | - | - | filtered | Oui | Actif | global | Admin
5. admin | geolocalisation | - | niveaux0 | niveaux0 | Niveau 0 | hierarchy_mode | - | - | all | Oui | Actif | global | Admin

Badges :
- generic_category en bleu
- hierarchy_mode en violet
- Actif en vert
- Inactif en gris
- Défaut en bleu clair
- global en gris ou bleu

Ajouter une petite carte de résumé en haut :
- Correspondances actives
- Correspondances par défaut
- Modules couverts
- Dernière mise à jour

Le rendu doit être propre, lisible et cohérent avec les autres écrans Administration.
```

---

### 10.2.11. Cas de test recommandés

#### Test 1 — Table absente

```text
Si systeme.T_Fk_Correspondance n’existe pas, le script doit bloquer avec une exception explicite.
```

#### Test 2 — Exécution sur base vide

```text
Le script doit insérer toutes les correspondances globales prévues.
```

#### Test 3 — Rejouabilité

```text
Exécuter le script deux fois ne doit pas créer de doublons.
Les lignes existantes doivent être mises à jour.
```

#### Test 4 — Protection des scopes spécifiques

```text
Les correspondances dont SettingScope est différent de global ne doivent pas être supprimées par la réinitialisation globale.
```

#### Test 5 — Contrôle des mappings logistiques

```sql
SELECT "SourceKey", "FieldName", "FieldLabel", "TargetCategoryIdFk", "MappingValue"
FROM systeme."V_Fk_Correspondance_Detail"
WHERE "ModuleName" = 'logistique'
ORDER BY "SourceKey";
```

Résultat attendu :

```text
Les mappings articles, commandes, paiements et règlements doivent être présents.
```

#### Test 6 — Contrôle des modes hiérarchiques

```sql
SELECT "SourceKey", "MappingType", "MappingValue"
FROM systeme."V_Fk_Correspondance_Detail"
WHERE "MappingType" = 'hierarchy_mode'
ORDER BY "SourceKey";
```

Résultat attendu :

```text
Les niveaux 0 et 1 historique peuvent avoir all.
Les niveaux dépendants doivent avoir filtered.
```

---

### 10.2.12. Script SQL complet — initialisation par défaut FK

Ce script SQL complet permet d’initialiser les correspondances FK par défaut en portée globale. Il est rejouable et utilise `ON CONFLICT DO UPDATE` pour éviter les doublons tout en mettant à jour les correspondances existantes.

```sql
-- Initialisation par defaut de systeme.T_Fk_Correspondance
-- Portee : globale
-- Usage :
-- - a executer sur une base vide ou juste apres migration
-- - le script est rejouable
-- - il reinitialise uniquement les correspondances gerees en portee globale

BEGIN;

DO $$
BEGIN
    IF to_regclass('systeme."T_Fk_Correspondance"') IS NULL THEN
        RAISE EXCEPTION
            'Initialisation impossible : systeme.T_Fk_Correspondance est absente.';
    END IF;
END $$;

DELETE FROM systeme."T_Fk_Correspondance"
WHERE "SettingScope" = 'global'
  AND "ScopeValue" IS NULL
  AND "MappingType" IN ('generic_category', 'hierarchy_mode');

WITH seed_rows AS (
    SELECT *
    FROM (
        VALUES
            ('admin','referentiel',NULL,'roles','roles','Role','generic_category','referentiel','T_Generique','ID_Generique',39,'39',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','referentiel',NULL,'entityTypes','entityTypes','Type entite','generic_category','referentiel','T_Generique','ID_Generique',48,'48',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','referentiel',NULL,'licenseStatuses','licenseStatuses','Statut licence','generic_category','referentiel','T_Generique','ID_Generique',55,'55',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau2Types','niveau2Types','Type niveau 2','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau3Types','niveau3Types','Type niveau 3','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau2Statuses','niveau2Statuses','Statut niveau 2','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau3Statuses','niveau3Statuses','Statut niveau 3','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'deploymentStatuses','deploymentStatuses','Statut deploiement','generic_category','referentiel','T_Generique','ID_Generique',27,'27',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'dpsAccessRoutes','dpsAccessRoutes','Voie acces DPS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'antBczAccessRoutes','antBczAccessRoutes','Voie acces antenne BCZS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'dpsBczAccessRoutes','dpsBczAccessRoutes','Voie acces DPS BCZS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau4Types','niveau4Types','Type niveau 4','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau5Types','niveau5Types','Type niveau 5','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau4Statuses','niveau4Statuses','Statut niveau 4','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau5Statuses','niveau5Statuses','Statut niveau 5','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'networkAvailabilities','networkAvailabilities','Disponibilite reseau','generic_category','referentiel','T_Generique','ID_Generique',19,'19',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'zsAsAccessRoutes','zsAsAccessRoutes','Voie acces ZS-AS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'zsSiteAccessRoutes','zsSiteAccessRoutes','Voie acces ZS-Site','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'roofTypes','roofTypes','Type de toit','generic_category','referentiel','T_Generique','ID_Generique',18,'18',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Article','logistique.articleTypes','ID_TypeArticleFk','Type d''article','generic_category','referentiel','T_Generique','ID_Generique',46,'46',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Article','logistique.articleCategories','ID_CategorieArticleFk','Categorie d''article','generic_category','referentiel','T_Generique','ID_Generique',40,'40',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Article','logistique.articleUnits','ID_UniteFk','Unite','generic_category','referentiel','T_Generique','ID_Generique',34,'34',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique',NULL,'logistique.commandeTypes','ID_TypeCmdFk','Type de commande','generic_category','referentiel','T_Generique','ID_Generique',64,'64',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Commande','logistique.commandeStatuses','ID_StatutCmdFk','Statut commande','generic_category','referentiel','T_Generique','ID_Generique',28,'28',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Commande','logistique.commandeConditionPaiements','ID_ConditionPaiementFk','Condition de paiement','generic_category','referentiel','T_Generique','ID_Generique',37,'37',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Commande','logistique.commandeModesPaiement','ID_ModePaiementFk','Mode de paiement','generic_category','referentiel','T_Generique','ID_Generique',36,'36',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_SuiviReglements','logistique.reglementModes','ID_ModeReglementFk','Mode de reglement','generic_category','referentiel','T_Generique','ID_Generique',36,'36',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux0','niveaux0','Niveau 0','hierarchy_mode',NULL,NULL,NULL,NULL,'all',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux1Old','niveaux1Old','Niveau 1 historique','hierarchy_mode',NULL,NULL,NULL,NULL,'all',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux1','niveaux1','Niveau 1','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux2','niveaux2','Niveau 2','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux3','niveaux3','Niveau 3','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux4','niveaux4','Niveau 4','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux5','niveaux5','Niveau 5','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut')
    ) AS t(
        module_name,
        schema_name,
        view_name,
        source_key,
        field_name,
        field_label,
        mapping_type,
        reference_schema_name,
        reference_object_name,
        reference_field_name,
        target_category_id_fk,
        mapping_value,
        is_default_mapping,
        valide_fk_correspondance,
        setting_scope,
        scope_value,
        display_order,
        updated_by_user_fk,
        obs_fk_correspondance
    )
)
INSERT INTO systeme."T_Fk_Correspondance" (
    "ModuleName",
    "SchemaName",
    "ViewName",
    "SourceKey",
    "FieldName",
    "FieldLabel",
    "MappingType",
    "ReferenceSchemaName",
    "ReferenceObjectName",
    "ReferenceFieldName",
    "TargetCategoryIdFk",
    "MappingValue",
    "IsDefaultMapping",
    "ValideFkCorrespondance",
    "SettingScope",
    "ScopeValue",
    "DisplayOrder",
    "UpdatedAt",
    "UpdatedByUserFk",
    "ObsFkCorrespondance"
)
SELECT
    sr.module_name,
    sr.schema_name,
    sr.view_name,
    sr.source_key,
    sr.field_name,
    sr.field_label,
    sr.mapping_type,
    sr.reference_schema_name,
    sr.reference_object_name,
    sr.reference_field_name,
    sr.target_category_id_fk::integer,
    sr.mapping_value,
    sr.is_default_mapping,
    sr.valide_fk_correspondance,
    sr.setting_scope,
    sr.scope_value,
    sr.display_order,
    CURRENT_TIMESTAMP,
    sr.updated_by_user_fk::integer,
    sr.obs_fk_correspondance
FROM seed_rows sr
ON CONFLICT ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue")
DO UPDATE SET
    "FieldLabel" = EXCLUDED."FieldLabel",
    "ReferenceSchemaName" = EXCLUDED."ReferenceSchemaName",
    "ReferenceObjectName" = EXCLUDED."ReferenceObjectName",
    "ReferenceFieldName" = EXCLUDED."ReferenceFieldName",
    "TargetCategoryIdFk" = EXCLUDED."TargetCategoryIdFk",
    "IsDefaultMapping" = EXCLUDED."IsDefaultMapping",
    "ValideFkCorrespondance" = EXCLUDED."ValideFkCorrespondance",
    "DisplayOrder" = EXCLUDED."DisplayOrder",
    "UpdatedAt" = EXCLUDED."UpdatedAt",
    "UpdatedByUserFk" = EXCLUDED."UpdatedByUserFk",
    "ObsFkCorrespondance" = EXCLUDED."ObsFkCorrespondance";

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*)::integer
    INTO v_count
    FROM systeme."T_Fk_Correspondance"
    WHERE "MappingType" IN ('generic_category', 'hierarchy_mode');

    RAISE NOTICE 'Initialisation FK terminee. % correspondance(s) geree(s) presente(s) dans systeme.T_Fk_Correspondance.', COALESCE(v_count, 0);
END $$;

COMMIT;
```

## 11. Résumé de la logique validée

```text
T_Utilisateurs = comptes utilisateurs.
T_Entite = organisations / structures.
T_Entite_Localisation = coordonnées et rattachement géographique.
T_Licence = validité d’accès par entité.
T_Login = historique de connexion.
T_Audit_Log = historique officiel des modifications.
T_Fk_Correspondance = mappings FK pour le frontend.
T_Admin_UI_Setting = paramètres UI.
Référentiel = catégories et valeurs génériques.
```

Règle centrale :

```text
Lecture frontend = vues système et référentielles.
CRUD = tables système via backend.
Audit = lecture seule.
Historique de connexion = lecture seule.
Correspondances FK = gérées avec audit.
Licences = contrôlées par DateFin, ValideLicence et ExpireeLicence.
```
