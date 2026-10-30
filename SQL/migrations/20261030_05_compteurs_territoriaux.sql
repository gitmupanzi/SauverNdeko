-- Compteurs liés et contexte territorial au niveau des vues partagées.
-- CREATE OR REPLACE conserve strictement les anciennes colonnes et leurs types.
-- Aucun territoire, référence métier ou préférence personnelle n’est modifié.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
SELECT pg_advisory_xact_lock(hashtextextended('geolocalisation:hierarchy-writes',0));

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_0" AS
 SELECT "ID_Niveau_0",
    "NomNiveau_0",
    iso,
    "CodeNiveau_0",
    "geometryNiveau_0",
    n0."uidSNIS" AS "uidSNIS",
    (SELECT count(*) FROM geolocalisation."T_Niveau_1" child WHERE child."ID_Niveau_0_Fk"=n0."ID_Niveau_0") AS "Nb_Niveau_1"
   FROM geolocalisation."T_Niveau_0" n0;
COMMENT ON COLUMN geolocalisation."V_Niveau_0"."uidSNIS" IS 'Identifiant SNIS du pays ou territoire, conservé depuis la table source sans transformation.';
COMMENT ON COLUMN geolocalisation."V_Niveau_0"."Nb_Niveau_1" IS 'Nombre exact de niveaux 1 rattachés à ce pays, sans exclusion implicite de fusion ou visibilité. Correspond au registre des provinces filtré sur ID_Niveau_0_Fk.';
COMMENT ON VIEW geolocalisation."V_Niveau_0" IS 'Référentiel territorial partagé du niveau 0. Conserve les colonnes historiques et les rattachements absents ; expose les identifiants et libellés actuels ainsi que les compteurs exacts des enfants consultables, sans multiplication par les jointures ni exclusion implicite de visibilité.';

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_1" AS
 SELECT n1a."ID_Niveau_0_Fk",
    n0."NomNiveau_0",
    n1a."ID_Niveau_1_Old_Fk",
    n1b."NomNiveau_1_Old",
    n1a."ID_Niveau_1",
    n1a."NomNiveau_1",
    n1a."Alt1_Niveau_1",
    n1a."Alt2_Niveau_1",
    n1a."AbreNiveau_1",
    n1a."CodeSNIS",
    n1a."CodeNiveau_1",
    n1a."PopulationNiveau_1",
    n1a."LatitudeNiveau_1",
    n1a."LongitudeNiveau_1",
    n1a."surfaceNiveau_1",
    n1a."geometryNiveau_1",
    n1a."EtenduNiveau_1",
    n1a."timezoneNiveau_1",
    n1a."wikidataNiveau_1",
    n1a."FusionNiveau_1",
    n1a."VisibleNiveau_1",
    n1a."VisibleNiveau_5",
    n1a."ObsNiveau_1",
    n1a."prov_uid" AS "prov_uid",
    n1a."uidSNIS" AS "uidSNIS",
    (SELECT count(*) FROM geolocalisation."T_Niveau_2" child WHERE child."ID_Niveau_1_FK"=n1a."ID_Niveau_1") AS "Nb_Niveau_2"
   FROM ((geolocalisation."T_Niveau_1" n1a
     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")));
COMMENT ON COLUMN geolocalisation."V_Niveau_1"."prov_uid" IS 'Identifiant provincial complémentaire, conservé depuis la table source.';
COMMENT ON COLUMN geolocalisation."V_Niveau_1"."uidSNIS" IS 'Identifiant SNIS provincial, conservé depuis la table source.';
COMMENT ON COLUMN geolocalisation."V_Niveau_1"."Nb_Niveau_2" IS 'Nombre exact de niveaux 2 rattachés à la province. Correspond au registre des antennes filtré sur ID_Niveau_1_FK.';
COMMENT ON VIEW geolocalisation."V_Niveau_1" IS 'Référentiel territorial partagé du niveau 1. Conserve les colonnes historiques et les rattachements absents ; expose les identifiants et libellés actuels ainsi que les compteurs exacts des enfants consultables, sans multiplication par les jointures ni exclusion implicite de visibilité.';

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_2" AS
 SELECT n0."NomNiveau_0",
    n1b."NomNiveau_1_Old",
    n2."ID_Niveau_1_FK",
    n1a."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique", ' '::character varying) AS "Type_Niveau_2",
    n2."NomNiveau_2",
    n2."Alt1_NomNiveau_2",
    n2."AbreNiveau_2",
    n2."CodeNiveau_2",
    n2."PopulationNiveau_2",
    n2."LatitudeNiveau_2",
    n2."LongitudeNiveau_2",
    n2."AltitudeNiveau_2",
    n2."geometryNiveau_2",
    n2."surfaceNiveau_2",
    n2."EtenduNiveau_2",
    n2."ObsNiveau_2",
    n2."ID_StatutNiveau_2",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "Statut_Niveau_2",
    n2."ID_StatusDeploiFk",
    COALESCE(g_deploi."AbrGenerique", ' '::character varying) AS "Statut_Deploiement",
    n2."KmDPSANT",
    n2."ID_VoieAccesDPSANTFk",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "Voie_Acces_DPS",
    n2."SelectNiveau_2",
    n1a."ID_Niveau_0_Fk" AS "ID_Niveau_0",
    n1a."ID_Niveau_1" AS "ID_Niveau_1",
    n1a."FusionNiveau_1" AS "FusionNiveau_1",
    n1a."VisibleNiveau_1" AS "VisibleNiveau_1",
    n1a."VisibleNiveau_5" AS "VisibleNiveau_5",
    n2.iso AS "iso",
    n2."uidSNIS" AS "uidSNIS",
    (SELECT count(*) FROM geolocalisation."T_Niveau_3" child WHERE child."ID_Niveau_2_FK"=n2."ID_Niveau_2") AS "Nb_Niveau_3"
   FROM (((((((geolocalisation."T_Niveau_2" n2
     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN geolocalisation."T_Niveau_1_Old" n1b ON ((n1a."ID_Niveau_1_Old_Fk" = n1b."ID_Niveau_1_Old")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n2."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n2."ID_StatutNiveau_2" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploi ON ((n2."ID_StatusDeploiFk" = g_deploi."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n2."ID_VoieAccesDPSANTFk" = g_voie."ID_Generique")));
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_0" IS 'Identifiant du pays parent obtenu par la province, utilisable pour filtrer le découpage partagé.';
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."ID_Niveau_1" IS 'Identifiant de province parent ; alias de lecture compatible avec les analyses territoriales.';
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente ; NULL reste inconnu, aucune exclusion automatique.';
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."VisibleNiveau_1" IS 'Visibilité déclarée du niveau provincial parent, sans restriction implicite des compteurs.';
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."VisibleNiveau_5" IS 'Visibilité des sites déclarée par la province parente, conservée sans modifier ses sites.';
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."iso" IS 'Code ISO ou identifiant géographique enregistré pour cette subdivision.';
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette subdivision.';
COMMENT ON COLUMN geolocalisation."V_Niveau_2"."Nb_Niveau_3" IS 'Nombre exact de zones de santé rattachées à cette subdivision. Correspond au registre des zones filtré sur ID_Niveau_2_FK.';
COMMENT ON VIEW geolocalisation."V_Niveau_2" IS 'Référentiel territorial partagé du niveau 2. Conserve les colonnes historiques et les rattachements absents ; expose les identifiants et libellés actuels ainsi que les compteurs exacts des enfants consultables, sans multiplication par les jointures ni exclusion implicite de visibilité.';

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_3" AS
 SELECT n3."ID_TypeNiveau_2_Fk",
    COALESCE(g_type."AbrGenerique", ' '::character varying) AS "Type_Niveau_3",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n3."Alt_Niveau_3",
    n3."AbreNiveau_3",
    n3."CodeNiveau_3",
    n3."LatitudeNiveau_3",
    n3."PopulationNiveau_3",
    n3."LongitudeNiveau_3",
    n3."AltitudeNiveau_3",
    n3."EtenduNiveau_3",
    n3."surfaceNiveau_3",
    n3."geometryNiveau_3",
    n3."ObsNiveau_3",
    n3."ID_StatutNiveau_3_Fk",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "Statut_Niveau_3",
    n3."ID_StatutDeploieFk",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "Statut_Deploiement",
    n3."KmAntenneBCZS",
    n3."ID_VoieAccesANTBCZFk",
    COALESCE(g_voie1."AbrGenerique", ' '::character varying) AS "Voie_ANTBCZ",
    n3."KmDPSBCZS",
    n3."ID_VoieAccesDPSBCZFk",
    COALESCE(g_voie2."AbrGenerique", ' '::character varying) AS "Voie_DPSBCZS",
    n3."SelectNiveau_3",
    n3."ID_Niveau_2_FK",
    n0."ID_Niveau_0" AS "ID_Niveau_0",
    n0."NomNiveau_0" AS "NomNiveau_0",
    n1a."ID_Niveau_1" AS "ID_Niveau_1",
    n1a."NomNiveau_1" AS "NomNiveau_1",
    n2."ID_Niveau_2" AS "ID_Niveau_2",
    n2."NomNiveau_2" AS "NomNiveau_2",
    n1a."FusionNiveau_1" AS "FusionNiveau_1",
    n1a."VisibleNiveau_1" AS "VisibleNiveau_1",
    n1a."VisibleNiveau_5" AS "VisibleNiveau_5",
    n3.iso AS "iso",
    n3."uidSNIS" AS "uidSNIS",
    (SELECT count(*) FROM geolocalisation."T_Niveau_4" child WHERE child."ID_Niveau_3_Fk"=n3."ID_Niveau_3") AS "Nb_Niveau_4",
    ((SELECT count(*) FROM geolocalisation."T_Niveau_5" child WHERE child."ID_Niveau_3_Fk"=n3."ID_Niveau_3") + (SELECT count(*) FROM geolocalisation."T_Niveau_4" area JOIN geolocalisation."T_Niveau_5" child ON child."ID_Niveau_4_Fk"=area."ID_Niveau_4" WHERE child."ID_Niveau_3_Fk" IS NULL AND area."ID_Niveau_3_Fk"=n3."ID_Niveau_3")) AS "Nb_Niveau_5"
   FROM ((((((((geolocalisation."T_Niveau_3" n3
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1a ON ((n2."ID_Niveau_1_FK" = n1a."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1a."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n3."ID_TypeNiveau_2_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n3."ID_StatutNiveau_3_Fk" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n3."ID_StatutDeploieFk" = g_deploiement."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie1 ON ((n3."ID_VoieAccesANTBCZFk" = g_voie1."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie2 ON ((n3."ID_VoieAccesDPSBCZFk" = g_voie2."ID_Generique")));
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_0" IS 'Identifiant du pays parent obtenu par les jointures de rattachement.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_0" IS 'Nom courant du pays parent, issu de la source unique géographique.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_1" IS 'Identifiant de la province parente de la zone.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_1" IS 'Nom courant de la province parente de la zone.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."ID_Niveau_2" IS 'Identifiant de la subdivision parente de la zone.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."NomNiveau_2" IS 'Nom courant de la subdivision parente de la zone.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."FusionNiveau_1" IS 'Indicateur de fusion provincial, exposé pour les filtres sans exclusion implicite.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente ; aucun territoire n’est masqué par cette vue.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."VisibleNiveau_5" IS 'Visibilité déclarée des sites de la province parente, sans réécriture de données.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."iso" IS 'Code ISO ou identifiant géographique enregistré pour cette zone.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette zone.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Nb_Niveau_4" IS 'Nombre exact d’aires rattachées à cette zone. Correspond au registre des aires filtré sur ID_Niveau_3_Fk.';
COMMENT ON COLUMN geolocalisation."V_Niveau_3"."Nb_Niveau_5" IS 'Nombre exact de sites de cette zone : rattachement direct prioritaire, sinon zone de l’aire. Chaque site compte une fois. Correspond au registre des sites filtré sur ID_Niveau_3 effectif.';
COMMENT ON VIEW geolocalisation."V_Niveau_3" IS 'Référentiel territorial partagé du niveau 3. Conserve les colonnes historiques et les rattachements absents ; expose les identifiants et libellés actuels ainsi que les compteurs exacts des enfants consultables, sans multiplication par les jointures ni exclusion implicite de visibilité.';

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_4" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n4."ID_TypeNiveau_4_Fk",
    COALESCE(g_type."AbrGenerique", ''::character varying) AS "Type_Niveau_4",
    n4."AbreNiveau_4",
    (((COALESCE(g_type."AbrGenerique", ''::character varying))::text || ' '::text) || (COALESCE(n4."NomNiveau_4", ''::character varying))::text) AS "SITE",
    n4."CodeNiveau_4",
    n4."PopulationNiveau_4",
    n4."LatitudeNiveau_4",
    n4."LongitudeNiveau_4",
    n4."AltitudeNiveau_4",
    n4."geometryNiveau_4",
    COALESCE(g_reseau."AbrGenerique", ' '::character varying) AS "RESEAU",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "VOIE_AS_ZS",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "STATUT_AS",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS",
    n4."ObsNiveau_4",
    n4."SelectNiveau_4",
    n4."ID_Niveau_4",
    n4."ID_Niveau_3_Fk",
    n4."NomNiveau_4",
    n4."KmZoneSanteAS",
    n4."surfaceNiveau_4",
    n4."ID_DispoReseauNiveau_4",
    n4."ID_VoieAccesZsASFk",
    n4."ID_StatutNiveau_4",
    n4."ID_StatutDeploiementFk",
    n1."FusionNiveau_1" AS "FusionNiveau_1",
    n1."VisibleNiveau_1" AS "VisibleNiveau_1",
    n1."VisibleNiveau_5" AS "VisibleNiveau_5",
    n4.iso AS "iso",
    n4."uidSNIS" AS "uidSNIS",
    (SELECT count(*) FROM geolocalisation."T_Niveau_5" child WHERE child."ID_Niveau_4_Fk"=n4."ID_Niveau_4") AS "Nb_Niveau_5",
    (g_reseau."AbrGenerique" IS NOT NULL AND g_reseau."AbrGenerique"::text <> 'Sans reseau'::text) AS "AvecReseau"
   FROM (((((((((geolocalisation."T_Niveau_4" n4
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n4."ID_Niveau_3_Fk" = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n4."ID_TypeNiveau_4_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n4."ID_DispoReseauNiveau_4" = g_reseau."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n4."ID_VoieAccesZsASFk" = g_voie."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n4."ID_StatutNiveau_4" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n4."ID_StatutDeploiementFk" = g_deploiement."ID_Generique")))
  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n4."NomNiveau_4";
COMMENT ON COLUMN geolocalisation."V_Niveau_4"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente, sans filtre implicite.';
COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente, exposée sans altération.';
COMMENT ON COLUMN geolocalisation."V_Niveau_4"."VisibleNiveau_5" IS 'Visibilité déclarée des sites au niveau provincial parent.';
COMMENT ON COLUMN geolocalisation."V_Niveau_4"."iso" IS 'Code ISO ou identifiant géographique enregistré pour cette aire.';
COMMENT ON COLUMN geolocalisation."V_Niveau_4"."uidSNIS" IS 'Identifiant SNIS enregistré pour cette aire.';
COMMENT ON COLUMN geolocalisation."V_Niveau_4"."Nb_Niveau_5" IS 'Nombre exact de sites directement rattachés à cette aire. Les sites rattachés seulement à une zone ne sont pas attribués arbitrairement à une aire.';
COMMENT ON COLUMN geolocalisation."V_Niveau_4"."AvecReseau" IS 'Indicateur exact du rapport Réseau des aires : abréviation réseau renseignée et différente de « Sans reseau ». Ne constitue pas une certification de connectivité.';
COMMENT ON VIEW geolocalisation."V_Niveau_4" IS 'Référentiel territorial partagé du niveau 4. Conserve les colonnes historiques et les rattachements absents ; expose les identifiants et libellés actuels ainsi que les compteurs exacts des enfants consultables, sans multiplication par les jointures ni exclusion implicite de visibilité.';

CREATE OR REPLACE VIEW geolocalisation."V_Niveau_5" AS
 SELECT n0."ID_Niveau_0",
    n0."NomNiveau_0",
    n1."ID_Niveau_1",
    n1."NomNiveau_1",
    n2."ID_Niveau_2",
    n2."NomNiveau_2",
    n3."ID_Niveau_3",
    n3."NomNiveau_3",
    n5."ID_TypeNiveau_5_Fk",
    COALESCE(g_type."AbrGenerique", ''::character varying) AS "Type_Niveau_5",
    (((COALESCE(g_type."AbrGenerique", ''::character varying))::text || ' '::text) || (COALESCE(n5."NomNiveau_5", ''::character varying))::text) AS "SITE",
    n5."AbreNiveau_5",
    n5."CodeNiveau_5",
    n5."PopulationNiveau_5",
    n5."LongitudeNiveau_5",
    n5."LatitudeNiveau_5",
    n5."AltitudeNiveau_5",
    n5."geometryNiveau_5",
    COALESCE(g_reseau."AbrGenerique", ' '::character varying) AS "RESEAU",
    COALESCE(g_voie."AbrGenerique", ' '::character varying) AS "VOIE_AS_Site",
    COALESCE(g_statut."AbrGenerique", ' '::character varying) AS "STATUT_Site",
    COALESCE(g_deploiement."AbrGenerique", ' '::character varying) AS "STATUT_DEPLOI",
    n3."KmAntenneBCZS",
    n3."KmDPSBCZS",
    n4."ID_Niveau_4",
    n5."ID_Niveau_5",
    n5."ID_Niveau_4_Fk",
    n5."ID_Niveau_3_Fk",
    n5."NomNiveau_5",
    n5."KmZoneSanteNiveau_5",
    n5."surfaceNiveau_5",
    n5."ID_DispoReseauNiveau_5",
    n5."ID_VoieAccesZsSiteFk",
    n5."ID_StatutNiveau_5",
    n5."ID_StatutDeploiementFk",
    n5."ID_TypeToitFk",
    n5."ObsNiveau_5",
    n5."SelectNiveau_5",
    n4."NomNiveau_4" AS "NomNiveau_4",
    (SELECT roof."AbrGenerique" FROM referentiel."T_Generique" roof WHERE roof."ID_Generique"=n5."ID_TypeToitFk") AS "Type_Toit",
    n1."FusionNiveau_1" AS "FusionNiveau_1",
    n1."VisibleNiveau_1" AS "VisibleNiveau_1",
    n1."VisibleNiveau_5" AS "VisibleNiveau_5",
    n5.iso AS "iso",
    n5."uidSNIS" AS "uidSNIS",
    n4."ID_TypeNiveau_4_Fk" AS "ID_TypeNiveau_4_Fk"
   FROM ((((((((((geolocalisation."T_Niveau_5" n5
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n5."ID_Niveau_4_Fk" = n4."ID_Niveau_4")))
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk") = n3."ID_Niveau_3")))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n3."ID_Niveau_2_FK" = n2."ID_Niveau_2")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n2."ID_Niveau_1_FK" = n1."ID_Niveau_1")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n1."ID_Niveau_0_Fk" = n0."ID_Niveau_0")))
     LEFT JOIN referentiel."T_Generique" g_type ON ((n5."ID_TypeNiveau_5_Fk" = g_type."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_reseau ON ((n5."ID_DispoReseauNiveau_5" = g_reseau."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_voie ON ((n5."ID_VoieAccesZsSiteFk" = g_voie."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_statut ON ((n5."ID_StatutNiveau_5" = g_statut."ID_Generique")))
     LEFT JOIN referentiel."T_Generique" g_deploiement ON ((n5."ID_StatutDeploiementFk" = g_deploiement."ID_Generique")))
  ORDER BY n0."NomNiveau_0", n1."NomNiveau_1", n2."NomNiveau_2", n3."NomNiveau_3", n5."NomNiveau_5";
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."NomNiveau_4" IS 'Nom courant de l’aire lorsque le site lui est réellement rattaché ; NULL si aucun rattachement à une aire.';
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."Type_Toit" IS 'Abréviation du type de toit selon la valeur générique enregistrée ; ne remplace pas sa clé étrangère.';
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."FusionNiveau_1" IS 'Indicateur de fusion de la province parente, sans exclusion implicite des sites.';
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VisibleNiveau_1" IS 'Visibilité déclarée de la province parente du site.';
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."VisibleNiveau_5" IS 'Visibilité déclarée des sites au niveau provincial parent.';
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."iso" IS 'Code ISO ou identifiant géographique enregistré pour ce site.';
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."uidSNIS" IS 'Identifiant SNIS enregistré pour ce site.';
COMMENT ON COLUMN geolocalisation."V_Niveau_5"."ID_TypeNiveau_4_Fk" IS 'Type de l’aire réellement liée au site ; NULL lorsque le site n’a pas d’aire ou que son type est absent. Permet le détail exact des analyses par type d’aire.';
COMMENT ON VIEW geolocalisation."V_Niveau_5" IS 'Référentiel territorial partagé du niveau 5. Conserve les colonnes historiques et les rattachements absents ; expose les identifiants et libellés actuels. Aucun compteur métier non disponible, budget ou intervention historique n’est inventé.';

-- Ajouter uniquement les colonnes absentes, sans remplacer les choix communs existants.
-- Les ordres intercalaires placent les ajouts avant Actions sans déplacer une colonne personnalisée.
-- Le trigger existant augmente Version une seule fois par catalogue réellement complété.
-- T_PreferenceTableau reste intact : un choix personnel n’est jamais élargi implicitement.
DO $catalogues$
DECLARE target record; current_columns jsonb; result_columns jsonb; additions jsonb; item jsonb; addition jsonb;
        missing_count integer; inserted_count integer; before_actions boolean; table_order numeric; export_order numeric;
BEGIN
 FOR target IN SELECT key AS interface_key,value AS definitions FROM jsonb_each('{"territoires.niveaux-zero":[{"id":"uidSNIS","label":"Identifiant SNIS","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"Nb_Niveau_1","label":"Provinces / DPS","type":"bigint","exportable":true,"tableAvailable":true,"defaultVisible":true,"defaultExport":true}],"territoires.niveaux-un":[{"id":"prov_uid","label":"Identifiant provincial","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"uidSNIS","label":"Identifiant SNIS","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"Nb_Niveau_2","label":"Antennes / subdivisions","type":"bigint","exportable":true,"tableAvailable":true,"defaultVisible":true,"defaultExport":true}],"territoires.niveaux-deux":[{"id":"ID_Niveau_0","label":"Réf. pays","type":"integer","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"ID_Niveau_1","label":"Réf. province","type":"integer","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"FusionNiveau_1","label":"Province fusionnée","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_1","label":"Province visible","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_5","label":"Sites visibles","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"iso","label":"Code ISO","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"uidSNIS","label":"Identifiant SNIS","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"Nb_Niveau_3","label":"Zones de santé","type":"bigint","exportable":true,"tableAvailable":true,"defaultVisible":true,"defaultExport":true}],"territoires.niveaux-trois":[{"id":"ID_Niveau_0","label":"Réf. pays","type":"integer","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"NomNiveau_0","label":"Pays / territoire","type":"character varying","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"ID_Niveau_1","label":"Réf. province","type":"integer","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"NomNiveau_1","label":"Province / DPS","type":"character varying","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"ID_Niveau_2","label":"Réf. subdivision","type":"integer","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"NomNiveau_2","label":"Antenne / subdivision","type":"character varying","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"FusionNiveau_1","label":"Province fusionnée","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_1","label":"Province visible","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_5","label":"Sites visibles","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"iso","label":"Code ISO","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"uidSNIS","label":"Identifiant SNIS","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"Nb_Niveau_4","label":"Aires de santé","type":"bigint","exportable":true,"tableAvailable":true,"defaultVisible":true,"defaultExport":true},{"id":"Nb_Niveau_5","label":"Sites et structures","type":"bigint","exportable":true,"tableAvailable":true,"defaultVisible":true,"defaultExport":true}],"territoires.niveaux-quatre":[{"id":"FusionNiveau_1","label":"Province fusionnée","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_1","label":"Province visible","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_5","label":"Sites visibles","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"iso","label":"Code ISO","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"uidSNIS","label":"Identifiant SNIS","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"Nb_Niveau_5","label":"Sites et structures","type":"bigint","exportable":true,"tableAvailable":true,"defaultVisible":true,"defaultExport":true},{"id":"AvecReseau","label":"Aire avec réseau","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false}],"territoires.niveaux-cinq":[{"id":"NomNiveau_4","label":"Aire de santé","type":"character varying","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"Type_Toit","label":"Type de toit","type":"character varying","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"FusionNiveau_1","label":"Province fusionnée","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_1","label":"Province visible","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"VisibleNiveau_5","label":"Sites visibles","type":"boolean","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"iso","label":"Code ISO","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"uidSNIS","label":"Identifiant SNIS","type":"text","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false},{"id":"ID_TypeNiveau_4_Fk","label":"Réf. type d’aire","type":"integer","exportable":true,"tableAvailable":true,"defaultVisible":false,"defaultExport":false}]}'::jsonb)
 LOOP
  SELECT "Colonnes" INTO current_columns FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=target.interface_key AND "Module"='territoires' FOR UPDATE;
  IF current_columns IS NULL THEN RAISE EXCEPTION 'Catalogue territorial manquant : %. Installer 03 avant 05.',target.interface_key; END IF;
  SELECT COALESCE(jsonb_agg(d.value ORDER BY d.ordinality),'[]'::jsonb) INTO additions
  FROM jsonb_array_elements(target.definitions) WITH ORDINALITY d(value,ordinality)
  WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(current_columns) c WHERE c->>'id'=d.value->>'id');
  missing_count:=jsonb_array_length(additions);
  IF missing_count=0 THEN CONTINUE; END IF;
  SELECT (c->>'defaultOrder')::numeric,COALESCE((c->>'defaultExportOrder')::numeric,(c->>'defaultOrder')::numeric)
  INTO table_order,export_order FROM jsonb_array_elements(current_columns) c WHERE c->>'id'='actions';
  IF table_order IS NULL THEN
   SELECT COALESCE(max((c->>'defaultOrder')::numeric),0)+1,COALESCE(max(COALESCE((c->>'defaultExportOrder')::numeric,(c->>'defaultOrder')::numeric)),0)+1 INTO table_order,export_order FROM jsonb_array_elements(current_columns) c;
  END IF;
  result_columns:='[]'::jsonb; inserted_count:=0; before_actions:=false;
  FOR item IN SELECT value FROM jsonb_array_elements(current_columns) LOOP
   IF item->>'id'='actions' THEN
    FOR addition IN SELECT value FROM jsonb_array_elements(additions) LOOP
     inserted_count:=inserted_count+1;
     result_columns:=result_columns||jsonb_build_array(addition||jsonb_build_object('defaultOrder',table_order-1+inserted_count::numeric/(missing_count+1),'defaultExportOrder',export_order-1+inserted_count::numeric/(missing_count+1)));
    END LOOP;
    before_actions:=true;
    result_columns:=result_columns||jsonb_build_array((SELECT value FROM jsonb_array_elements(current_columns) WHERE value->>'id'='actions'));
   ELSE result_columns:=result_columns||jsonb_build_array(item); END IF;
  END LOOP;
  IF NOT before_actions THEN
   FOR addition IN SELECT value FROM jsonb_array_elements(additions) LOOP
    result_columns:=result_columns||jsonb_build_array(addition||jsonb_build_object('defaultOrder',table_order,'defaultExportOrder',export_order)); table_order:=table_order+1; export_order:=export_order+1;
   END LOOP;
  END IF;
  UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=result_columns WHERE "CleInterface"=target.interface_key;
 END LOOP;
END
$catalogues$;
COMMIT;
