-- Extrait canonique du catalogue vérifié le 03/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_Entite_Localisation_Detail; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Entite_Localisation_Detail" AS
 SELECT el."IdEntiteLocalisation",
    e."IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    e."AdresseEntite",
    e."IdTypeEntiteFk",
    te."NomGenerique" AS "TypeEntite",
    el."Latitude",
    el."Longitude",
    el."AdresseDetaillee",
    el."DateCreation",
    el."IdNiveau_3_Fk",
    n3."NomNiveau_3",
    el."IdNiveau_4_Fk",
    n4."NomNiveau_4",
    el."IdNiveau_5_Fk",
    n5."NomNiveau_5"
   FROM (((((systeme."T_Entite" e
     LEFT JOIN systeme."T_Entite_Localisation" el ON ((el."IdEntiteFk" = e."IdEntite")))
     LEFT JOIN referentiel."T_Generique" te ON ((te."ID_Generique" = e."IdTypeEntiteFk")))
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n3."ID_Niveau_3" = el."IdNiveau_3_Fk")))
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n4."ID_Niveau_4" = el."IdNiveau_4_Fk")))
     LEFT JOIN geolocalisation."T_Niveau_5" n5 ON ((n5."ID_Niveau_5" = el."IdNiveau_5_Fk")));

--
-- Name: VIEW "V_Entite_Localisation_Detail"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Entite_Localisation_Detail" IS 'Entités enrichies de leurs localisations, type et niveaux géographiques. Grain entité/localisation ; une entité sans localisation reste présente et une entité peut apparaître sur plusieurs lignes.';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdEntiteLocalisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdEntiteLocalisation" IS 'Identifiant de la localisation d’entité. Expression projetée : el."IdEntiteLocalisation".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdEntite" IS 'Identifiant de l’entité. Expression projetée : e."IdEntite".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."PhoneEntite" IS 'Téléphone de contact de l’entité. Expression projetée : e."PhoneEntite".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."EmailEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."EmailEntite" IS 'Adresse électronique de contact de l’entité. Expression projetée : e."EmailEntite".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."AdresseEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité. Expression projetée : e."AdresseEntite".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdTypeEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdTypeEntiteFk" IS 'Type de structure ou d’organisation dans le référentiel. Expression projetée : e."IdTypeEntiteFk".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."TypeEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."TypeEntite" IS 'Libellé du type d’entité dans le référentiel. Expression projetée : te."NomGenerique" AS "TypeEntite".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."Latitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."Latitude" IS 'Latitude de la localisation ; coordonnée décimale. Expression projetée : el."Latitude".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."Longitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."Longitude" IS 'Longitude de la localisation ; coordonnée décimale. Expression projetée : el."Longitude".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."AdresseDetaillee"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."AdresseDetaillee" IS 'Adresse détaillée de cette localisation. Expression projetée : el."AdresseDetaillee".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."DateCreation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."DateCreation" IS 'Date et heure de création de l’enregistrement. Expression projetée : el."DateCreation".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdNiveau_3_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdNiveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Expression projetée : el."IdNiveau_3_Fk".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomNiveau_3"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomNiveau_3" IS 'Nom de l’unité géographique de niveau 3. Expression projetée : n3."NomNiveau_3".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdNiveau_4_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdNiveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Expression projetée : el."IdNiveau_4_Fk".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomNiveau_4"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomNiveau_4" IS 'Nom de l’unité géographique de niveau 4. Expression projetée : n4."NomNiveau_4".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."IdNiveau_5_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."IdNiveau_5_Fk" IS 'Unité géographique de rattachement de niveau 5. Expression projetée : el."IdNiveau_5_Fk".';

--
-- Name: COLUMN "V_Entite_Localisation_Detail"."NomNiveau_5"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Localisation_Detail"."NomNiveau_5" IS 'Nom de l’unité géographique de niveau 5. Expression projetée : n5."NomNiveau_5".';

--
-- Name: V_Admin_UI_Setting; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Admin_UI_Setting" AS
 SELECT s."IdAdminUISetting",
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
    COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text),
        CASE
            WHEN (s."UpdatedByUserFk" IS NOT NULL) THEN ('Utilisateur #'::text || s."UpdatedByUserFk")
            ELSE NULL::text
        END) AS "UpdatedByName",
    s."ObsSetting"
   FROM (systeme."T_Admin_UI_Setting" s
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = s."UpdatedByUserFk")))
  WHERE (s."ValideSetting" = true)
  ORDER BY s."SettingGroup", s."DisplayOrder", s."SettingLabel";

--
-- Name: VIEW "V_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Admin_UI_Setting" IS 'Paramètres déclarés valides, enrichis du nom du dernier modificateur ; grain paramètre. La portée est exposée sans imposer d’autorisation utilisateur.';

--
-- Name: COLUMN "V_Admin_UI_Setting"."IdAdminUISetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."IdAdminUISetting" IS 'Identifiant du paramètre d’interface. Expression projetée : s."IdAdminUISetting".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : s."SettingScope".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : s."ScopeValue".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingKey" IS 'Clé technique stable du paramètre. Expression projetée : s."SettingKey".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingLabel" IS 'Libellé du paramètre présenté dans l’administration. Expression projetée : s."SettingLabel".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingGroup" IS 'Groupe fonctionnel du paramètre d’interface. Expression projetée : s."SettingGroup".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingValue" IS 'Valeur du paramètre sous forme textuelle. Expression projetée : s."SettingValue".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingValueJson"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingValueJson" IS 'Valeur structurée JSON du paramètre ; distincte de la représentation textuelle. Expression projetée : s."SettingValueJson".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."SettingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."SettingType" IS 'Type de représentation du paramètre contrôlé par la contrainte installée. Expression projetée : s."SettingType".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance. Expression projetée : s."DisplayOrder".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."IsEditable"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."IsEditable" IS 'Indique si le paramètre est déclaré modifiable dans l’interface. Expression projetée : s."IsEditable".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."IsSystem"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."IsSystem" IS 'Identifie un paramètre système. Expression projetée : s."IsSystem".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."ValideSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."ValideSetting" IS 'Indique si le paramètre est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : s."ValideSetting".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."CreatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."CreatedAt" IS 'Horodatage de création du paramètre. Expression projetée : s."CreatedAt".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré. Expression projetée : s."UpdatedAt".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Expression projetée : s."UpdatedByUserFk".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."UpdatedByName" IS 'Nom du dernier modificateur ; repli Utilisateur #identifiant lorsque le compte n’est pas résolu. Expression projetée : COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''''::character varying), '' '', COALESCE(u."NomUser", ''''::character varying))), ''''::text), CASE WHEN s."UpdatedByUserFk" IS NOT NULL THEN ''Utilisateur #''::text || s."UpdatedByUserFk" ELSE NULL::text END) AS "UpdatedByName".';

--
-- Name: COLUMN "V_Admin_UI_Setting"."ObsSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting"."ObsSetting" IS 'Observations enregistrées sur le paramètre. Expression projetée : s."ObsSetting".';

--
-- Name: V_Admin_UI_Setting_Audit; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Admin_UI_Setting_Audit" AS
 SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    COALESCE((cleaned.n ->> 'SettingScope'::text), (cleaned.n ->> 'settingScope'::text), (cleaned.o ->> 'SettingScope'::text), (cleaned.o ->> 'settingScope'::text), 'global'::text) AS "SettingScope",
    COALESCE((cleaned.n ->> 'ScopeValue'::text), (cleaned.n ->> 'scopeValue'::text), (cleaned.o ->> 'ScopeValue'::text), (cleaned.o ->> 'scopeValue'::text)) AS "ScopeValue",
    COALESCE((cleaned.n ->> 'SettingKey'::text), (cleaned.n ->> 'settingKey'::text), (cleaned.o ->> 'SettingKey'::text), (cleaned.o ->> 'settingKey'::text)) AS "SettingKey",
    COALESCE((cleaned.n ->> 'SettingLabel'::text), (cleaned.n ->> 'settingLabel'::text), (cleaned.o ->> 'SettingLabel'::text), (cleaned.o ->> 'settingLabel'::text)) AS "SettingLabel",
    COALESCE((cleaned.n ->> 'SettingGroup'::text), (cleaned.n ->> 'settingGroup'::text), (cleaned.o ->> 'SettingGroup'::text), (cleaned.o ->> 'settingGroup'::text)) AS "SettingGroup",
        CASE
            WHEN (cleaned.n IS NOT NULL) THEN COALESCE((cleaned.n ->> 'SettingValue'::text), (cleaned.n ->> 'settingValue'::text))
            ELSE COALESCE((cleaned.o ->> 'SettingValue'::text), (cleaned.o ->> 'settingValue'::text))
        END AS "SettingValue",
        CASE
            WHEN (COALESCE(cleaned.n, cleaned.o) ? '_actor'::text) THEN (COALESCE(cleaned.n, cleaned.o) #>> '{_actor,NomComplet}'::text[])
            ELSE COALESCE((cleaned.n ->> 'updatedByName'::text), (cleaned.o ->> 'updatedByName'::text))
        END AS "UpdatedByName",
        CASE
            WHEN (COALESCE(cleaned.n, cleaned.o) ? '_actor'::text) THEN (COALESCE(cleaned.n, cleaned.o) #>> '{_actor,IdUser}'::text[])
            ELSE COALESCE((cleaned.n ->> 'UpdatedByUserFk'::text), (cleaned.n ->> 'updatedByUserId'::text), (cleaned.o ->> 'UpdatedByUserFk'::text), (cleaned.o ->> 'updatedByUserId'::text))
        END AS "UpdatedByUserId",
    COALESCE((cleaned.n ->> 'UpdatedAt'::text), (cleaned.n ->> 'updatedAt'::text), (cleaned.o ->> 'UpdatedAt'::text), (cleaned.o ->> 'updatedAt'::text)) AS "UpdatedSettingAt",
    cleaned.o AS "OldData",
    cleaned.n AS "NewData"
   FROM (systeme."T_Audit_Log" a
     CROSS JOIN LATERAL ( SELECT systeme.fn_audit_sans_secrets(a."NewData") AS n,
            systeme.fn_audit_sans_secrets(a."OldData") AS o) cleaned)
  WHERE (a."TableName" = 'T_Admin_UI_Setting'::text)
  ORDER BY a."ChangedAt" DESC;

--
-- Name: VIEW "V_Admin_UI_Setting_Audit"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Admin_UI_Setting_Audit" IS 'Audit nettoyé des paramètres ; une ligne par événement, contexte PascalCase SQL ou camelCase historique et auteur de l’opération.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."IdLog" IS 'Identifiant stable de l’événement de T_Audit_Log.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."TableName" IS 'Table de paramètres concernée par l’événement.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."Operation" IS 'Opération SQL INSERT, UPDATE ou DELETE enregistrée.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."ChangedAt" IS 'Date et heure civiles de l’événement ; les nouveaux triggers utilisent Africa/Kinshasa.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingScope" IS 'Portée du paramètre, extraite de la ligne SQL ou de l’image applicative historique.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."ScopeValue" IS 'Contexte de la portée ; NULL pour un paramètre global.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingKey" IS 'Clé du paramètre extraite des images avant ou après l’écriture.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingLabel" IS 'Libellé du paramètre au moment de l’événement.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingGroup" IS 'Groupe du paramètre au moment de l’événement.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."SettingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingValue" IS 'Valeur après l’écriture, avant pour DELETE ; NULL explicite conservé et valeur sensible masquée.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedByName" IS 'Nom de l’auteur de l’opération SQL, sinon auteur déclaré par l’ancien format applicatif ; absence conservée.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."UpdatedByUserId"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedByUserId" IS 'Identifiant textuel de l’auteur de l’opération, distinct du dernier modificateur de la ligne supprimée.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."UpdatedSettingAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedSettingAt" IS 'Horodatage de la ligne de paramètre extrait de l’image SQL ou du format historique ; texte conservé.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."OldData" IS 'Image avant l’écriture, nettoyée récursivement à la lecture ; NULL pour INSERT.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Audit"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."NewData" IS 'Image après l’écriture, nettoyée récursivement à la lecture ; NULL pour DELETE.';

--
-- Name: V_Admin_UI_Setting_Group; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Admin_UI_Setting_Group" AS
 SELECT "SettingGroup",
    count(*) AS "NbParametres",
    count(*) FILTER (WHERE ("IsEditable" = true)) AS "NbEditables",
    count(*) FILTER (WHERE ("IsSystem" = true)) AS "NbSysteme",
    max("UpdatedAt") AS "DerniereModification"
   FROM systeme."T_Admin_UI_Setting"
  WHERE ("ValideSetting" = true)
  GROUP BY "SettingGroup"
  ORDER BY "SettingGroup";

--
-- Name: VIEW "V_Admin_UI_Setting_Group"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Admin_UI_Setting_Group" IS 'Agrégats des paramètres valides au grain SettingGroup : nombre total, éditables, système et dernière modification. Les portées ne sont pas séparées dans le regroupement.';

--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."SettingGroup" IS 'Groupe fonctionnel du paramètre d’interface. Expression projetée : "SettingGroup".';

--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."NbParametres"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."NbParametres" IS 'Nombre de paramètres valides du groupe, toutes portées confondues. Expression projetée : count(*) AS "NbParametres".';

--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."NbEditables"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."NbEditables" IS 'Nombre de paramètres valides du groupe dont IsEditable vaut true. Expression projetée : count(*) FILTER (WHERE "IsEditable" = true) AS "NbEditables".';

--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."NbSysteme"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."NbSysteme" IS 'Nombre de paramètres valides du groupe dont IsSystem vaut true. Expression projetée : count(*) FILTER (WHERE "IsSystem" = true) AS "NbSysteme".';

--
-- Name: COLUMN "V_Admin_UI_Setting_Group"."DerniereModification"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Group"."DerniereModification" IS 'Dernier UpdatedAt des paramètres valides du groupe. Expression projetée : max("UpdatedAt") AS "DerniereModification".';

--
-- Name: V_Audit_log; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Audit_log" AS
 SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    e."NomEntite",
    systeme.fn_audit_sans_secrets(a."OldData") AS "OldData",
    systeme.fn_audit_sans_secrets(a."NewData") AS "NewData"
   FROM (systeme."T_Audit_Log" a
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = a."IdEntiteFk")));

--
-- Name: VIEW "V_Audit_log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Audit_log" IS 'Journal au grain événement. Les images avant/après masquent les champs de mot de passe et jetons, y compris pour les événements historiques. Les droits restent imposés par le service.';

--
-- Name: COLUMN "V_Audit_log"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."IdLog" IS 'Identifiant de l’événement d’audit. Expression projetée : a."IdLog".';

--
-- Name: COLUMN "V_Audit_log"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."TableName" IS 'Nom de la table à l’origine de l’événement d’audit. Expression projetée : a."TableName".';

--
-- Name: COLUMN "V_Audit_log"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."Operation" IS 'Nom de l’opération auditée ; le trigger produit INSERT, UPDATE ou DELETE. Expression projetée : a."Operation".';

--
-- Name: COLUMN "V_Audit_log"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."ChangedAt" IS 'Horodatage de l’événement d’audit. Expression projetée : a."ChangedAt".';

--
-- Name: COLUMN "V_Audit_log"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';

--
-- Name: COLUMN "V_Audit_log"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."OldData" IS 'Image avant opération sans champs de mot de passe ni jetons ; NULL pour une insertion.';

--
-- Name: COLUMN "V_Audit_log"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Audit_log"."NewData" IS 'Image après opération sans champs de mot de passe ni jetons ; NULL pour une suppression.';

--
-- Name: V_LicenceModule; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_LicenceModule" AS
 SELECT lm."IdLicenceModule",
    lm."IdLicenceFk",
    lm."CodeModule",
    lm."Actif",
    lm."Origine",
    lm."Version",
    lm."ModifieParUserFk",
    lm."CreeLe",
    lm."ModifieLe",
    l."IdEntiteFk",
    e."NomEntite",
    m."Nom" AS "NomModule",
    m."EstSocle",
    m."CodeIncluant",
    l."DateDebut",
    l."DateFin",
    ((e."ValideEntite" IS TRUE) AND m."Actif" AND lm."Actif" AND (l."ValideLicence" IS TRUE) AND ((l."DateDebut" IS NULL) OR (l."DateDebut" <= CURRENT_TIMESTAMP)) AND (l."DateFin" > CURRENT_TIMESTAMP)) AS "EstAccesActif",
        CASE
            WHEN (e."ValideEntite" IS NOT TRUE) THEN 'Entité inactive'::text
            WHEN (NOT m."Actif") THEN 'Module indisponible'::text
            WHEN (NOT lm."Actif") THEN 'Désactivé'::text
            WHEN (l."ValideLicence" IS NOT TRUE) THEN 'Licence inactive'::text
            WHEN (l."DateDebut" > CURRENT_TIMESTAMP) THEN 'À venir'::text
            WHEN (l."DateFin" IS NULL) THEN 'Échéance manquante'::text
            WHEN (l."DateFin" <= CURRENT_TIMESTAMP) THEN 'Licence expirée'::text
            ELSE 'Actif'::text
        END AS "EtatAcces"
   FROM (((systeme."T_LicenceModule" lm
     JOIN systeme."T_Licence" l ON ((l."IdLicence" = lm."IdLicenceFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = l."IdEntiteFk")))
     JOIN systeme."T_ModuleApplication" m ON (((m."CodeModule")::text = (lm."CodeModule")::text)));

--
-- Name: VIEW "V_LicenceModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_LicenceModule" IS 'Activation effective par licence et entité ; les dates sont évaluées à la lecture sans modifier le contrat.';

--
-- Name: COLUMN "V_LicenceModule"."IdLicenceModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."IdLicenceModule" IS 'Identifiant permanent de la ligne d’activation.';

--
-- Name: COLUMN "V_LicenceModule"."IdLicenceFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."IdLicenceFk" IS 'Licence de l’entité ; cette relation est immuable.';

--
-- Name: COLUMN "V_LicenceModule"."CodeModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."CodeModule" IS 'Application activée dans cette licence ; code immuable.';

--
-- Name: COLUMN "V_LicenceModule"."Actif"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."Actif" IS 'Activation explicite du module dans la licence.';

--
-- Name: COLUMN "V_LicenceModule"."Origine"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."Origine" IS 'Reprise identifie les accès conservés lors de la migration ; ce champ ne constitue pas une facturation.';

--
-- Name: COLUMN "V_LicenceModule"."Version"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."Version" IS 'Version utilisée pour refuser les modifications concurrentes.';

--
-- Name: COLUMN "V_LicenceModule"."ModifieParUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification ; NULL pour la migration initiale.';

--
-- Name: COLUMN "V_LicenceModule"."CreeLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."CreeLe" IS 'Instant de création du rattachement.';

--
-- Name: COLUMN "V_LicenceModule"."ModifieLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';

--
-- Name: COLUMN "V_LicenceModule"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."IdEntiteFk" IS 'Entité propriétaire de la licence, obtenue par la clé étrangère T_Licence.';

--
-- Name: COLUMN "V_LicenceModule"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."NomEntite" IS 'Nom de l’entité propriétaire.';

--
-- Name: COLUMN "V_LicenceModule"."NomModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."NomModule" IS 'Libellé de l’application.';

--
-- Name: COLUMN "V_LicenceModule"."EstSocle"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."EstSocle" IS 'Application comprise dans le socle.';

--
-- Name: COLUMN "V_LicenceModule"."CodeIncluant"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."CodeIncluant" IS 'Application parente qui inclut ce module.';

--
-- Name: COLUMN "V_LicenceModule"."DateDebut"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."DateDebut" IS 'Début contractuel conservé depuis T_Licence.';

--
-- Name: COLUMN "V_LicenceModule"."DateFin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."DateFin" IS 'Échéance contractuelle conservée depuis T_Licence.';

--
-- Name: COLUMN "V_LicenceModule"."EstAccesActif"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."EstAccesActif" IS 'Licence, entité, module et activation valides à l’instant de lecture.';

--
-- Name: COLUMN "V_LicenceModule"."EtatAcces"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_LicenceModule"."EtatAcces" IS 'Motif de disponibilité ou de suspension.';

--
-- Name: V_EntiteModuleActif; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_EntiteModuleActif" AS
 SELECT e."IdEntite" AS "IdEntiteFk",
    m."CodeModule"
   FROM (systeme."T_Entite" e
     CROSS JOIN systeme."T_ModuleApplication" m)
  WHERE ((e."ValideEntite" IS TRUE) AND m."Actif" AND m."EstSocle")
UNION
 SELECT l."IdEntiteFk",
    m."CodeModule"
   FROM (systeme."V_LicenceModule" l
     JOIN systeme."T_ModuleApplication" m ON ((((m."CodeModule")::text = (l."CodeModule")::text) OR ((m."CodeIncluant")::text = (l."CodeModule")::text))))
  WHERE (l."EstAccesActif" AND m."Actif");

--
-- Name: VIEW "V_EntiteModuleActif"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_EntiteModuleActif" IS 'Modules effectivement disponibles à une entité active : socle, licence valide et inclusions du Catalogue. Les droits du rôle sont vérifiés ensuite.';

--
-- Name: COLUMN "V_EntiteModuleActif"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_EntiteModuleActif"."IdEntiteFk" IS 'Entité autorisée.';

--
-- Name: COLUMN "V_EntiteModuleActif"."CodeModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_EntiteModuleActif"."CodeModule" IS 'Application comprise dans son socle ou sa licence active.';

--
-- Name: V_Entite_Public; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Entite_Public" AS
 SELECT e."IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."AdresseEntite",
    e."ValideEntite",
    jsonb_build_object('ID_Generique', g."ID_Generique", 'NomGenerique', g."NomGenerique", 'AbrGenerique', g."AbrGenerique") AS "T_Generique"
   FROM (systeme."T_Entite" e
     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = e."IdTypeEntiteFk")))
  WHERE (e."ValideEntite" = true);

--
-- Name: VIEW "V_Entite_Public"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Entite_Public" IS 'Annuaire public des structures actives au grain entité : nom, adresse et téléphone de structure, type ; aucune donnée de connexion utilisateur.';

--
-- Name: COLUMN "V_Entite_Public"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."IdEntite" IS 'Identifiant de l’entité.';

--
-- Name: COLUMN "V_Entite_Public"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."NomEntite" IS 'Nom de la structure ou organisation.';

--
-- Name: COLUMN "V_Entite_Public"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."PhoneEntite" IS 'Téléphone de contact de l’entité.';

--
-- Name: COLUMN "V_Entite_Public"."AdresseEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité.';

--
-- Name: COLUMN "V_Entite_Public"."ValideEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."ValideEntite" IS 'Indique si l’entité est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "V_Entite_Public"."T_Generique"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Entite_Public"."T_Generique" IS 'Type de structure sous forme JSON : identifiant, nom et abréviation du référentiel.';

--
-- Name: V_Fk_Correspondance; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Fk_Correspondance" AS
 SELECT fc."ModuleName",
    fc."SchemaName",
    fc."ViewName",
    fc."SourceKey",
    fc."FieldName",
    max((fc."FieldLabel")::text) AS "FieldLabel",
    fc."MappingType",
    max((fc."ReferenceSchemaName")::text) AS "ReferenceSchemaName",
    max((fc."ReferenceObjectName")::text) AS "ReferenceObjectName",
    max((fc."ReferenceFieldName")::text) AS "ReferenceFieldName",
    string_agg(DISTINCT (fc."MappingValue")::text, ', '::text ORDER BY (fc."MappingValue")::text) AS "MappingValues",
    string_agg(DISTINCT (c."NomCategorieGenerique")::text, ', '::text ORDER BY (c."NomCategorieGenerique")::text) AS "CategoryLabels",
    bool_or(fc."IsDefaultMapping") AS "HasDefaultMapping",
    bool_or(fc."ValideFkCorrespondance") AS "HasActiveMapping",
    fc."SettingScope",
    fc."ScopeValue",
    count(*) AS "NbCorrespondances",
    max(fc."UpdatedAt") AS "UpdatedAt"
   FROM (systeme."T_Fk_Correspondance" fc
     LEFT JOIN referentiel."T_CategorieGenerique" c ON ((c."ID_CategorieGenerique" = fc."TargetCategoryIdFk")))
  GROUP BY fc."ModuleName", fc."SchemaName", fc."ViewName", fc."SourceKey", fc."FieldName", fc."MappingType", fc."SettingScope", fc."ScopeValue";

--
-- Name: VIEW "V_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Fk_Correspondance" IS 'Synthèse des correspondances par module, schéma, vue, source, champ, type et portée : valeurs/catégories distinctes, indicateurs et compte. Les correspondances inactives restent incluses dans le regroupement.';

--
-- Name: COLUMN "V_Fk_Correspondance"."ModuleName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ModuleName" IS 'Module applicatif auquel s’applique la correspondance. Expression projetée : fc."ModuleName".';

--
-- Name: COLUMN "V_Fk_Correspondance"."SchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."SchemaName" IS 'Schéma PostgreSQL de la vue dont le champ est configuré. Expression projetée : fc."SchemaName".';

--
-- Name: COLUMN "V_Fk_Correspondance"."ViewName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ViewName" IS 'Nom de la vue dont les correspondances de champ sont configurées. Expression projetée : fc."ViewName".';

--
-- Name: COLUMN "V_Fk_Correspondance"."SourceKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."SourceKey" IS 'Clé applicative de la source de liste configurée. Expression projetée : fc."SourceKey".';

--
-- Name: COLUMN "V_Fk_Correspondance"."FieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."FieldName" IS 'Nom technique du champ dont la source de liste est configurée. Expression projetée : fc."FieldName".';

--
-- Name: COLUMN "V_Fk_Correspondance"."FieldLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."FieldLabel" IS 'Libellé du champ présenté dans le paramétrage des correspondances. Expression projetée : max(fc."FieldLabel"::text) AS "FieldLabel".';

--
-- Name: COLUMN "V_Fk_Correspondance"."MappingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."MappingType" IS 'Mode de correspondance : generic_category, direct_source ou hierarchy_mode, selon la contrainte installée. Expression projetée : fc."MappingType".';

--
-- Name: COLUMN "V_Fk_Correspondance"."ReferenceSchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ReferenceSchemaName" IS 'Schéma PostgreSQL de l’objet de référence configuré. Expression projetée : max(fc."ReferenceSchemaName"::text) AS "ReferenceSchemaName".';

--
-- Name: COLUMN "V_Fk_Correspondance"."ReferenceObjectName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ReferenceObjectName" IS 'Nom technique de l’objet de référence configuré pour la liste. Expression projetée : max(fc."ReferenceObjectName"::text) AS "ReferenceObjectName".';

--
-- Name: COLUMN "V_Fk_Correspondance"."ReferenceFieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ReferenceFieldName" IS 'Champ identifiant ou libellé utilisé dans l’objet de référence configuré. Expression projetée : max(fc."ReferenceFieldName"::text) AS "ReferenceFieldName".';

--
-- Name: COLUMN "V_Fk_Correspondance"."MappingValues"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."MappingValues" IS 'Valeurs de correspondance distinctes agrégées et triées, séparées par une virgule. Expression projetée : string_agg(DISTINCT fc."MappingValue"::text, '', ''::text ORDER BY (fc."MappingValue"::text)) AS "MappingValues".';

--
-- Name: COLUMN "V_Fk_Correspondance"."CategoryLabels"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."CategoryLabels" IS 'Libellés distincts des catégories cibles agrégés et triés. Expression projetée : string_agg(DISTINCT c."NomCategorieGenerique"::text, '', ''::text ORDER BY (c."NomCategorieGenerique"::text)) AS "CategoryLabels".';

--
-- Name: COLUMN "V_Fk_Correspondance"."HasDefaultMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."HasDefaultMapping" IS 'Vrai si au moins une correspondance du groupe est marquée par défaut. Expression projetée : bool_or(fc."IsDefaultMapping") AS "HasDefaultMapping".';

--
-- Name: COLUMN "V_Fk_Correspondance"."HasActiveMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."HasActiveMapping" IS 'Vrai si au moins une correspondance du groupe est déclarée valide. Expression projetée : bool_or(fc."ValideFkCorrespondance") AS "HasActiveMapping".';

--
-- Name: COLUMN "V_Fk_Correspondance"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : fc."SettingScope".';

--
-- Name: COLUMN "V_Fk_Correspondance"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : fc."ScopeValue".';

--
-- Name: COLUMN "V_Fk_Correspondance"."NbCorrespondances"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."NbCorrespondances" IS 'Nombre de lignes de correspondance dans ce groupe, y compris les inactives. Expression projetée : count(*) AS "NbCorrespondances".';

--
-- Name: COLUMN "V_Fk_Correspondance"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré. Expression projetée : max(fc."UpdatedAt") AS "UpdatedAt".';

--
-- Name: V_Fk_Correspondance_Audit; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Fk_Correspondance_Audit" AS
 SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    COALESCE((cleaned.n ->> 'SettingScope'::text), (cleaned.n ->> 'settingScope'::text), (cleaned.o ->> 'SettingScope'::text), (cleaned.o ->> 'settingScope'::text), 'global'::text) AS "SettingScope",
    COALESCE((cleaned.n ->> 'ScopeValue'::text), (cleaned.n ->> 'scopeValue'::text), (cleaned.o ->> 'ScopeValue'::text), (cleaned.o ->> 'scopeValue'::text)) AS "ScopeValue",
        CASE
            WHEN (COALESCE(cleaned.n, cleaned.o) ? '_actor'::text) THEN (COALESCE(cleaned.n, cleaned.o) #>> '{_actor,NomComplet}'::text[])
            ELSE COALESCE((cleaned.n ->> 'updatedByName'::text), (cleaned.o ->> 'updatedByName'::text))
        END AS "UpdatedByName",
        CASE
            WHEN (COALESCE(cleaned.n, cleaned.o) ? '_actor'::text) THEN (COALESCE(cleaned.n, cleaned.o) #>> '{_actor,IdUser}'::text[])
            ELSE COALESCE((cleaned.n ->> 'UpdatedByUserFk'::text), (cleaned.n ->> 'updatedByUserId'::text), (cleaned.o ->> 'UpdatedByUserFk'::text), (cleaned.o ->> 'updatedByUserId'::text))
        END AS "UpdatedByUserId",
    COALESCE((cleaned.n ->> 'UpdatedAt'::text), (cleaned.n ->> 'updatedAt'::text), (cleaned.o ->> 'UpdatedAt'::text), (cleaned.o ->> 'updatedAt'::text)) AS "UpdatedSettingAt",
    cleaned.o AS "OldData",
    cleaned.n AS "NewData"
   FROM (systeme."T_Audit_Log" a
     CROSS JOIN LATERAL ( SELECT systeme.fn_audit_sans_secrets(a."NewData") AS n,
            systeme.fn_audit_sans_secrets(a."OldData") AS o) cleaned)
  WHERE (a."TableName" = 'T_Fk_Correspondance'::text)
  ORDER BY a."ChangedAt" DESC;

--
-- Name: VIEW "V_Fk_Correspondance_Audit"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Fk_Correspondance_Audit" IS 'Audit nettoyé des correspondances ; une ligne par événement, contexte PascalCase SQL ou camelCase historique et auteur de l’opération.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."IdLog" IS 'Identifiant stable de l’événement de T_Audit_Log.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."TableName" IS 'Table de correspondances concernée par l’événement.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."Operation" IS 'Opération SQL INSERT, UPDATE ou DELETE enregistrée.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."ChangedAt" IS 'Date et heure civiles de l’événement ; les nouveaux triggers utilisent Africa/Kinshasa.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."SettingScope" IS 'Portée FK global, country ou entity, compatible avec l’ancien format applicatif.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."ScopeValue" IS 'Contexte de la portée FK ; NULL pour une correspondance globale.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedByName" IS 'Nom de l’auteur de l’opération SQL, sinon auteur déclaré par l’ancien format applicatif ; absence conservée.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."UpdatedByUserId"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedByUserId" IS 'Identifiant textuel de l’auteur de l’opération, distinct du dernier modificateur de la ligne supprimée.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."UpdatedSettingAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedSettingAt" IS 'Horodatage de la correspondance extrait de l’image SQL ou du format historique ; texte conservé.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."OldData" IS 'Image avant l’écriture, nettoyée récursivement à la lecture ; NULL pour INSERT.';

--
-- Name: COLUMN "V_Fk_Correspondance_Audit"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."NewData" IS 'Image après l’écriture, nettoyée récursivement à la lecture ; NULL pour DELETE.';

--
-- Name: V_Fk_Correspondance_Detail; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Fk_Correspondance_Detail" AS
 SELECT fc."IdFkCorrespondance",
    fc."ModuleName",
    fc."SchemaName",
    fc."ViewName",
    fc."SourceKey",
    fc."FieldName",
    fc."FieldLabel",
    fc."MappingType",
    fc."ReferenceSchemaName",
    fc."ReferenceObjectName",
    fc."ReferenceFieldName",
    fc."TargetCategoryIdFk",
    c."NomCategorieGenerique",
    fc."MappingValue",
    fc."IsDefaultMapping",
    fc."ValideFkCorrespondance",
    fc."SettingScope",
    fc."ScopeValue",
    fc."DisplayOrder",
    fc."UpdatedAt",
    fc."UpdatedByUserFk",
    COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text),
        CASE
            WHEN (fc."UpdatedByUserFk" IS NOT NULL) THEN ('Utilisateur #'::text || fc."UpdatedByUserFk")
            ELSE NULL::text
        END) AS "UpdatedByName",
    fc."ObsFkCorrespondance"
   FROM ((systeme."T_Fk_Correspondance" fc
     LEFT JOIN referentiel."T_CategorieGenerique" c ON ((c."ID_CategorieGenerique" = fc."TargetCategoryIdFk")))
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = fc."UpdatedByUserFk")));

--
-- Name: VIEW "V_Fk_Correspondance_Detail"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Fk_Correspondance_Detail" IS 'Correspondances de champs enrichies de la catégorie et du nom du dernier modificateur, au grain correspondance ; expose les portées et états sans filtrage de validité.';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."IdFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."IdFkCorrespondance" IS 'Identifiant de la correspondance de champ. Expression projetée : fc."IdFkCorrespondance".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ModuleName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ModuleName" IS 'Module applicatif auquel s’applique la correspondance. Expression projetée : fc."ModuleName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."SchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."SchemaName" IS 'Schéma PostgreSQL de la vue dont le champ est configuré. Expression projetée : fc."SchemaName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ViewName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ViewName" IS 'Nom de la vue dont les correspondances de champ sont configurées. Expression projetée : fc."ViewName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."SourceKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."SourceKey" IS 'Clé applicative de la source de liste configurée. Expression projetée : fc."SourceKey".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."FieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."FieldName" IS 'Nom technique du champ dont la source de liste est configurée. Expression projetée : fc."FieldName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."FieldLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."FieldLabel" IS 'Libellé du champ présenté dans le paramétrage des correspondances. Expression projetée : fc."FieldLabel".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."MappingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."MappingType" IS 'Mode de correspondance : generic_category, direct_source ou hierarchy_mode, selon la contrainte installée. Expression projetée : fc."MappingType".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ReferenceSchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ReferenceSchemaName" IS 'Schéma PostgreSQL de l’objet de référence configuré. Expression projetée : fc."ReferenceSchemaName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ReferenceObjectName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ReferenceObjectName" IS 'Nom technique de l’objet de référence configuré pour la liste. Expression projetée : fc."ReferenceObjectName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ReferenceFieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ReferenceFieldName" IS 'Champ identifiant ou libellé utilisé dans l’objet de référence configuré. Expression projetée : fc."ReferenceFieldName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."TargetCategoryIdFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."TargetCategoryIdFk" IS 'Catégorie de nomenclature ciblée par une correspondance de type generic_category. Expression projetée : fc."TargetCategoryIdFk".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."NomCategorieGenerique"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature. Expression projetée : c."NomCategorieGenerique".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."MappingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."MappingValue" IS 'Valeur de configuration associée à la correspondance. Expression projetée : fc."MappingValue".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."IsDefaultMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."IsDefaultMapping" IS 'Indique une correspondance proposée par défaut. Expression projetée : fc."IsDefaultMapping".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ValideFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ValideFkCorrespondance" IS 'Indique si la correspondance est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : fc."ValideFkCorrespondance".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."SettingScope" IS 'Niveau de portée du paramètre ou de la correspondance ; consulter la contrainte de la table pour les valeurs admises. Expression projetée : fc."SettingScope".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès. Expression projetée : fc."ScopeValue".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance. Expression projetée : fc."DisplayOrder".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré. Expression projetée : fc."UpdatedAt".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Expression projetée : fc."UpdatedByUserFk".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."UpdatedByName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."UpdatedByName" IS 'Nom du dernier modificateur ; repli Utilisateur #identifiant lorsque le compte n’est pas résolu. Expression projetée : COALESCE(NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''''::character varying), '' '', COALESCE(u."NomUser", ''''::character varying))), ''''::text), CASE WHEN fc."UpdatedByUserFk" IS NOT NULL THEN ''Utilisateur #''::text || fc."UpdatedByUserFk" ELSE NULL::text END) AS "UpdatedByName".';

--
-- Name: COLUMN "V_Fk_Correspondance_Detail"."ObsFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Detail"."ObsFkCorrespondance" IS 'Observations enregistrées sur la correspondance. Expression projetée : fc."ObsFkCorrespondance".';

--
-- Name: V_IdentiteDocumentaire; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_IdentiteDocumentaire" AS
 SELECT v."IdEntite",
    v."NomEntite",
    v."AdresseEntite",
    v."EmailEntite",
    v."PhoneEntite",
    v."IdentifiantsLegauxEntite",
    v."MentionDocumentaireEntite",
    v._version,
    v."SiteWebEntite",
    v."AfficherEnteteDocument",
    v."AfficherPiedDocument",
    v."HasLogo",
    v."LogoMimeEntite",
    v."LogoSha256Entite",
    v."LogoModifieLe",
    v."PhoneSecondaireEntite",
    e."TauxTVAEntite"
   FROM (( SELECT "T_Entite"."IdEntite",
            "T_Entite"."NomEntite",
            "T_Entite"."AdresseEntite",
            "T_Entite"."EmailEntite",
            "T_Entite"."PhoneEntite",
            "T_Entite"."IdentifiantsLegauxEntite",
            "T_Entite"."MentionDocumentaireEntite",
            ("T_Entite".xmin)::text AS _version,
            "T_Entite"."SiteWebEntite",
            "T_Entite"."AfficherEnteteDocument",
            "T_Entite"."AfficherPiedDocument",
            ("T_Entite"."LogoEntite" IS NOT NULL) AS "HasLogo",
            "T_Entite"."LogoMimeEntite",
            "T_Entite"."LogoSha256Entite",
            "T_Entite"."LogoModifieLe",
            "T_Entite"."PhoneSecondaireEntite"
           FROM systeme."T_Entite") v
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = v."IdEntite")));

--
-- Name: VIEW "V_IdentiteDocumentaire"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_IdentiteDocumentaire" IS 'Identité documentaire courante et taux de TVA paramétrable de l’entreprise ; sans contenu binaire du logo ni information de compte.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."IdEntite" IS 'Entreprise propriétaire dont le profil est consulté.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."NomEntite" IS 'Valeur actuelle NomEntite de l’entreprise émettrice.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."AdresseEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."AdresseEntite" IS 'Valeur actuelle AdresseEntite de l’entreprise émettrice.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."EmailEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."EmailEntite" IS 'Valeur actuelle EmailEntite de l’entreprise émettrice.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."PhoneEntite" IS 'Valeur actuelle PhoneEntite de l’entreprise émettrice.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."IdentifiantsLegauxEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."IdentifiantsLegauxEntite" IS 'Couples libelle/valeur facultatifs déclarés par l’entreprise.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."MentionDocumentaireEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."MentionDocumentaireEntite" IS 'Mention courante affichée selon le réglage du pied ; les instantanés documentaires historiques restent séparés.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"._version; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"._version IS 'Révision opaque du profil, obligatoire avant modification concurrente.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."SiteWebEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."SiteWebEntite" IS 'Site web actuel de l’entreprise, facultatif et validé en SQL.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."AfficherEnteteDocument"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."AfficherEnteteDocument" IS 'Option persistante du haut de page PDF, activée par défaut.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."AfficherPiedDocument"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."AfficherPiedDocument" IS 'Option persistante du pied de page PDF, activée par défaut.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."HasLogo"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."HasLogo" IS 'Présence d’un logo PNG courant ; les octets restent exclusivement dans T_Entite et les routes binaires autorisées.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."LogoMimeEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."LogoMimeEntite" IS 'MIME du logo courant, sans contenu binaire.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."LogoSha256Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."LogoSha256Entite" IS 'Version d’intégrité du logo courant, utilisable après autorisation du parent.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."LogoModifieLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."LogoModifieLe" IS 'Date de dernière installation du logo courant, sans modifier les dates d’émission des documents.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."PhoneSecondaireEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."PhoneSecondaireEntite" IS 'Téléphone secondaire courant facultatif de l’entreprise ; seconde coordonnée distincte du téléphone principal.';

--
-- Name: COLUMN "V_IdentiteDocumentaire"."TauxTVAEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."TauxTVAEntite" IS 'Taux de TVA courant des nouvelles factures de cette entreprise, en pourcentage.';

--
-- Name: V_Licence_active; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Licence_active" AS
 SELECT l."IdLicence",
    l."IdEntiteFk",
    e."NomEntite",
    l."DateDebut",
    l."DateFin",
    l."ValideLicence",
    (l."DateFin" <= CURRENT_TIMESTAMP) AS "ExpireeLicence",
        CASE
            WHEN (l."ValideLicence" IS NOT TRUE) THEN 'Inactive'::text
            WHEN (l."DateFin" <= CURRENT_TIMESTAMP) THEN 'Expirée'::text
            WHEN (l."DateDebut" > CURRENT_TIMESTAMP) THEN 'À venir'::text
            ELSE 'Active'::text
        END AS statut_licence
   FROM (systeme."T_Licence" l
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = l."IdEntiteFk")));

--
-- Name: VIEW "V_Licence_active"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Licence_active" IS 'Suivi de toutes les licences au grain licence ; état temporel calculé à chaque lecture : Inactive, Expirée, À venir ou Active. Le nom historique est conservé ; aucune licence historique n’est masquée.';

--
-- Name: COLUMN "V_Licence_active"."IdLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."IdLicence" IS 'Identifiant de la licence. Expression projetée : l."IdLicence".';

--
-- Name: COLUMN "V_Licence_active"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Expression projetée : l."IdEntiteFk".';

--
-- Name: COLUMN "V_Licence_active"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';

--
-- Name: COLUMN "V_Licence_active"."DateDebut"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."DateDebut" IS 'Début de la période enregistrée. Expression projetée : l."DateDebut".';

--
-- Name: COLUMN "V_Licence_active"."DateFin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."DateFin" IS 'Fin de la période enregistrée. Expression projetée : l."DateFin".';

--
-- Name: COLUMN "V_Licence_active"."ValideLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."ValideLicence" IS 'Indique si la licence est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : l."ValideLicence".';

--
-- Name: COLUMN "V_Licence_active"."ExpireeLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active"."ExpireeLicence" IS 'Vrai dès que DateFin est atteinte à l’instant de lecture, indépendamment du drapeau stocké.';

--
-- Name: COLUMN "V_Licence_active".statut_licence; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Licence_active".statut_licence IS 'Inactive si désactivée ; sinon Expirée à DateFin, À venir avant DateDebut, Active durant la période de validité.';

--
-- Name: V_Login_history; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_Login_history" AS
 SELECT lg."IdLogin",
    lg."DateLogin",
    lg."IdTypeLoginFk",
    type_log."AbrGenerique" AS "TypeLogin",
    u."IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    e."IdEntite",
    e."NomEntite"
   FROM (((systeme."T_Login" lg
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = lg."IdUserFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = lg."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" type_log ON ((lg."IdTypeLoginFk" = type_log."ID_Generique")));

--
-- Name: VIEW "V_Login_history"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_Login_history" IS 'Historique au grain événement de connexion, enrichi de l’utilisateur, du type et de l’entité de l’événement.';

--
-- Name: COLUMN "V_Login_history"."IdLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdLogin" IS 'Identifiant de l’événement de connexion. Expression projetée : lg."IdLogin".';

--
-- Name: COLUMN "V_Login_history"."DateLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."DateLogin" IS 'Date et heure de l’événement de connexion. Expression projetée : lg."DateLogin".';

--
-- Name: COLUMN "V_Login_history"."IdTypeLoginFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdTypeLoginFk" IS 'Type de l’événement de connexion dans le référentiel. Expression projetée : lg."IdTypeLoginFk".';

--
-- Name: COLUMN "V_Login_history"."TypeLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."TypeLogin" IS 'Abréviation du type d’événement de connexion. Expression projetée : type_log."AbrGenerique" AS "TypeLogin".';

--
-- Name: COLUMN "V_Login_history"."IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdUser" IS 'Identifiant du compte utilisateur. Expression projetée : u."IdUser".';

--
-- Name: COLUMN "V_Login_history"."NomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."NomUser" IS 'Nom de l’utilisateur. Expression projetée : u."NomUser".';

--
-- Name: COLUMN "V_Login_history"."PrenomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."PrenomUser" IS 'Prénom de l’utilisateur. Expression projetée : u."PrenomUser".';

--
-- Name: COLUMN "V_Login_history"."EmailUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion. Expression projetée : u."EmailUser".';

--
-- Name: COLUMN "V_Login_history"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."IdEntite" IS 'Identifiant de l’entité. Expression projetée : e."IdEntite".';

--
-- Name: COLUMN "V_Login_history"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_Login_history"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';

--
-- Name: V_RoleModule; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_RoleModule" AS
 SELECT r."IdRoleModule",
    r."IdEntiteFk",
    r."IdRoleFk",
    r."CodeModule",
    r."PeutConsulter",
    r."PeutGerer",
    r."PeutExporter",
    r."Actif",
    r."Version",
    r."ModifieParUserFk",
    r."CreeLe",
    r."ModifieLe",
    g."NomGenerique" AS "NomRole",
    m."Nom" AS "NomModule"
   FROM ((systeme."T_RoleModule" r
     JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = r."IdRoleFk")))
     JOIN systeme."T_ModuleApplication" m ON (((m."CodeModule")::text = (r."CodeModule")::text)));

--
-- Name: VIEW "V_RoleModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_RoleModule" IS 'Restrictions par rôle d’une entité ; aucune souscription n’est attribuée individuellement aux utilisateurs.';

--
-- Name: COLUMN "V_RoleModule"."IdRoleModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."IdRoleModule" IS 'Identifiant permanent du paramétrage.';

--
-- Name: COLUMN "V_RoleModule"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."IdEntiteFk" IS 'Entité à laquelle s’applique cette règle ; immuable.';

--
-- Name: COLUMN "V_RoleModule"."IdRoleFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."IdRoleFk" IS 'Rôle du référentiel, catégorie Rôles (39) ; immuable.';

--
-- Name: COLUMN "V_RoleModule"."CodeModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."CodeModule" IS 'Application concernée par les restrictions ; code immuable.';

--
-- Name: COLUMN "V_RoleModule"."PeutConsulter"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."PeutConsulter" IS 'Autorise la consultation si la licence et les droits préexistants l’autorisent aussi.';

--
-- Name: COLUMN "V_RoleModule"."PeutGerer"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."PeutGerer" IS 'Autorise les créations, modifications et suppressions permises par les services métier existants.';

--
-- Name: COLUMN "V_RoleModule"."PeutExporter"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."PeutExporter" IS 'Autorise les exports officiels du module.';

--
-- Name: COLUMN "V_RoleModule"."Actif"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."Actif" IS 'Une règle inactive refuse ces accès ; son absence conserve les droits antérieurs.';

--
-- Name: COLUMN "V_RoleModule"."Version"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."Version" IS 'Version du paramétrage pour la concurrence optimiste.';

--
-- Name: COLUMN "V_RoleModule"."ModifieParUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification.';

--
-- Name: COLUMN "V_RoleModule"."CreeLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."CreeLe" IS 'Instant de création du paramétrage.';

--
-- Name: COLUMN "V_RoleModule"."ModifieLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';

--
-- Name: COLUMN "V_RoleModule"."NomRole"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."NomRole" IS 'Libellé du rôle du référentiel.';

--
-- Name: COLUMN "V_RoleModule"."NomModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_RoleModule"."NomModule" IS 'Libellé de l’application.';

--
-- Name: V_User_Affectation; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_User_Affectation" AS
 SELECT u."IdUser",
    u."IdEntiteFk",
    u."NomUser",
    u."PrenomUser",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "NomCompletUser",
    u."MatriculeUser",
    u."ID_ServiceFk",
    s."NomGenerique" AS "Service",
    u."ID_FonctionFk",
    f."NomGenerique" AS "Fonction",
    u."DateEmbauche",
    u."DateFinEmploi",
    u."ObservationProfessionnelle",
    u."ValideUser",
    (u."ValideUser" AND ((u."DateEmbauche" IS NULL) OR (u."DateEmbauche" <= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date)) AND ((u."DateFinEmploi" IS NULL) OR (u."DateFinEmploi" >= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date))) AS "EstAffectable",
    (u.xmin)::text AS _version
   FROM ((systeme."T_Utilisateurs" u
     LEFT JOIN referentiel."T_Generique" s ON ((s."ID_Generique" = u."ID_ServiceFk")))
     LEFT JOIN referentiel."T_Generique" f ON ((f."ID_Generique" = u."ID_FonctionFk")));

--
-- Name: VIEW "V_User_Affectation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_User_Affectation" IS 'Métadonnées professionnelles privées pour la gestion RH minimale et les affectations ; sans mot de passe, photo, e-mail ni téléphone. Le service doit imposer entreprise et droits. N’élargit pas V_User_profil ni les projections publiques.';

--
-- Name: COLUMN "V_User_Affectation"."IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."IdUser" IS 'Métadonnée professionnelle privée IdUser ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."IdEntiteFk" IS 'Métadonnée professionnelle privée IdEntiteFk ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."NomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."NomUser" IS 'Métadonnée professionnelle privée NomUser ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."PrenomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."PrenomUser" IS 'Métadonnée professionnelle privée PrenomUser ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."NomCompletUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."NomCompletUser" IS 'Métadonnée professionnelle privée NomCompletUser ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."MatriculeUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."MatriculeUser" IS 'Métadonnée professionnelle privée MatriculeUser ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."ID_ServiceFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."ID_ServiceFk" IS 'Métadonnée professionnelle privée ID_ServiceFk ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."Service"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."Service" IS 'Métadonnée professionnelle privée Service ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."ID_FonctionFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."ID_FonctionFk" IS 'Métadonnée professionnelle privée ID_FonctionFk ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."Fonction"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."Fonction" IS 'Métadonnée professionnelle privée Fonction ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."DateEmbauche"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."DateEmbauche" IS 'Métadonnée professionnelle privée DateEmbauche ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."DateFinEmploi"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."DateFinEmploi" IS 'Métadonnée professionnelle privée DateFinEmploi ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."ObservationProfessionnelle"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."ObservationProfessionnelle" IS 'Note professionnelle privée limitée à1000 caractères, jamais étendue au profil public.';

--
-- Name: COLUMN "V_User_Affectation"."ValideUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."ValideUser" IS 'Métadonnée professionnelle privée ValideUser ; filtrage par entreprise et droits requis.';

--
-- Name: COLUMN "V_User_Affectation"."EstAffectable"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"."EstAffectable" IS 'Compte actif, sans début professionnel futur ni fin passée à la date de Kinshasa ; les nouvelles responsabilités exigent aussi la même entreprise.';

--
-- Name: COLUMN "V_User_Affectation"._version; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_Affectation"._version IS 'Révision opaque xmin de la fiche utilisateur, sans secret.';

--
-- Name: V_User_profil; Type: VIEW; Schema: systeme; Owner: -
--

CREATE VIEW systeme."V_User_profil" AS
 SELECT u."IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    u."PhoneUser",
    u."SexeUser",
    u."ValideUser",
    u."Is_staff",
    u."Is_Admin",
    u."DatecreationUser",
    e."IdEntite",
    e."NomEntite",
    e."EmailEntite",
    e."PhoneEntite"
   FROM (systeme."T_Utilisateurs" u
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = u."IdEntiteFk")));

--
-- Name: VIEW "V_User_profil"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON VIEW systeme."V_User_profil" IS 'Profil au grain utilisateur enrichi de l’entité : identité, contacts, validité et indicateurs staff/admin ; ne projette pas MotdepasseUser et ne filtre pas les utilisateurs inactifs.';

--
-- Name: COLUMN "V_User_profil"."IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."IdUser" IS 'Identifiant du compte utilisateur. Expression projetée : u."IdUser".';

--
-- Name: COLUMN "V_User_profil"."NomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."NomUser" IS 'Nom de l’utilisateur. Expression projetée : u."NomUser".';

--
-- Name: COLUMN "V_User_profil"."PrenomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."PrenomUser" IS 'Prénom de l’utilisateur. Expression projetée : u."PrenomUser".';

--
-- Name: COLUMN "V_User_profil"."EmailUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion. Expression projetée : u."EmailUser".';

--
-- Name: COLUMN "V_User_profil"."PhoneUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays. Expression projetée : u."PhoneUser".';

--
-- Name: COLUMN "V_User_profil"."SexeUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."SexeUser" IS 'Code de sexe enregistré pour le compte ; la contrainte actuelle admet M ou F. Expression projetée : u."SexeUser".';

--
-- Name: COLUMN "V_User_profil"."ValideUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."ValideUser" IS 'Indique si le compte est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : u."ValideUser".';

--
-- Name: COLUMN "V_User_profil"."Is_staff"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."Is_staff" IS 'Indicateur de compte staff ; pris en compte par les contrôles actuels d’administration. Expression projetée : u."Is_staff".';

--
-- Name: COLUMN "V_User_profil"."Is_Admin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."Is_Admin" IS 'Indicateur de compte administrateur ; pris en compte par les contrôles actuels d’administration. Expression projetée : u."Is_Admin".';

--
-- Name: COLUMN "V_User_profil"."DatecreationUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."DatecreationUser" IS 'Date et heure de création du compte. Expression projetée : u."DatecreationUser".';

--
-- Name: COLUMN "V_User_profil"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."IdEntite" IS 'Identifiant de l’entité. Expression projetée : e."IdEntite".';

--
-- Name: COLUMN "V_User_profil"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."NomEntite" IS 'Nom de la structure ou organisation. Expression projetée : e."NomEntite".';

--
-- Name: COLUMN "V_User_profil"."EmailEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."EmailEntite" IS 'Adresse électronique de contact de l’entité. Expression projetée : e."EmailEntite".';

--
-- Name: COLUMN "V_User_profil"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."V_User_profil"."PhoneEntite" IS 'Téléphone de contact de l’entité. Expression projetée : e."PhoneEntite".';
