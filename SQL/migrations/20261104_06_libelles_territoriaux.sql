-- Libellés territoriaux communs. Aucun UPDATE/INSERT/DELETE métier.
-- Installer avant le backend qui consomme V_ChoixTerritorial.
BEGIN;
SET LOCAL lock_timeout = '10s';
SELECT pg_advisory_xact_lock(hashtextextended('geolocalisation:hierarchy-writes', 0));
CREATE OR REPLACE VIEW geolocalisation."V_ChoixTerritorial" AS
WITH p0 AS (
    SELECT n."ID_Niveau_0" AS id,
           COALESCE(NULLIF(btrim(n.iso::text), ''), 'Pays #' || n."ID_Niveau_0"::text || ' (ISO absent)') AS label,
           NULL::integer AS "parentId", NULL::integer AS "parentNiveau",
           NULL::text AS "TypeTerritoire", n."CodeNiveau_0"::text AS "CodeTerritoire"
    FROM geolocalisation."T_Niveau_0" n
),
p1 AS (
    SELECT n."ID_Niveau_1" AS id,
           concat_ws(' / ', p.label, COALESCE(NULLIF(btrim(n."NomNiveau_1"::text), ''), 'Sans nom #' || n."ID_Niveau_1"::text)) AS label,
           n."ID_Niveau_0_Fk" AS "parentId", 0 AS "parentNiveau",
           NULL::text AS "TypeTerritoire", n."CodeNiveau_1"::text AS "CodeTerritoire"
    FROM geolocalisation."T_Niveau_1" n LEFT JOIN p0 p ON p.id = n."ID_Niveau_0_Fk"
),
p2 AS (
    SELECT n."ID_Niveau_2" AS id,
           concat_ws(' / ', p.label, concat(COALESCE(NULLIF(btrim(t."AbrGenerique"::text), ''),
                CASE WHEN n."ID_TypeNiveau_2_Fk" IS NOT NULL
                     THEN 'Type #' || n."ID_TypeNiveau_2_Fk"::text
                     ELSE 'Niveau 2' END), ' - ',
                COALESCE(NULLIF(btrim(n."NomNiveau_2"::text), ''), 'Sans nom #' || n."ID_Niveau_2"::text))) AS label,
           n."ID_Niveau_1_FK" AS "parentId", 1 AS "parentNiveau",
           t."AbrGenerique"::text AS "TypeTerritoire", n."CodeNiveau_2"::text AS "CodeTerritoire"
    FROM geolocalisation."T_Niveau_2" n LEFT JOIN p1 p ON p.id = n."ID_Niveau_1_FK"
    LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique" = n."ID_TypeNiveau_2_Fk"
),
p3 AS (
    SELECT n."ID_Niveau_3" AS id,
           concat_ws(' / ', p.label, concat(COALESCE(NULLIF(btrim(t."AbrGenerique"::text), ''),
                CASE WHEN n."ID_TypeNiveau_2_Fk" IS NOT NULL
                     THEN 'Type #' || n."ID_TypeNiveau_2_Fk"::text
                     ELSE 'Niveau 3' END), ' - ',
                COALESCE(NULLIF(btrim(n."NomNiveau_3"::text), ''), 'Sans nom #' || n."ID_Niveau_3"::text))) AS label,
           n."ID_Niveau_2_FK" AS "parentId", 2 AS "parentNiveau",
           t."AbrGenerique"::text AS "TypeTerritoire", n."CodeNiveau_3"::text AS "CodeTerritoire"
    FROM geolocalisation."T_Niveau_3" n LEFT JOIN p2 p ON p.id = n."ID_Niveau_2_FK"
    LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique" = n."ID_TypeNiveau_2_Fk"
),
p4 AS (
    SELECT n."ID_Niveau_4" AS id,
           concat_ws(' / ', p.label, concat(COALESCE(NULLIF(btrim(t."AbrGenerique"::text), ''),
                CASE WHEN n."ID_TypeNiveau_4_Fk" IS NOT NULL
                     THEN 'Type #' || n."ID_TypeNiveau_4_Fk"::text
                     ELSE 'Niveau 4' END), ' - ',
                COALESCE(NULLIF(btrim(n."NomNiveau_4"::text), ''), 'Sans nom #' || n."ID_Niveau_4"::text))) AS label,
           n."ID_Niveau_3_Fk" AS "parentId", 3 AS "parentNiveau",
           t."AbrGenerique"::text AS "TypeTerritoire", n."CodeNiveau_4"::text AS "CodeTerritoire"
    FROM geolocalisation."T_Niveau_4" n LEFT JOIN p3 p ON p.id = n."ID_Niveau_3_Fk"
    LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique" = n."ID_TypeNiveau_4_Fk"
),
p5 AS (
    SELECT n."ID_Niveau_5" AS id,
           concat_ws(' / ', p.label,
               CASE WHEN a."ID_Niveau_4" IS NOT NULL AND (n."ID_Niveau_3_Fk" IS NULL OR n."ID_Niveau_3_Fk" IS NOT DISTINCT FROM a."ID_Niveau_3_Fk") THEN
                   concat(COALESCE(NULLIF(btrim(t4."AbrGenerique"::text), ''),
                       CASE WHEN a."ID_TypeNiveau_4_Fk" IS NOT NULL THEN 'Type #' || a."ID_TypeNiveau_4_Fk"::text ELSE 'Niveau 4' END),
                       ' - ', COALESCE(NULLIF(btrim(a."NomNiveau_4"::text), ''), 'Sans nom #' || a."ID_Niveau_4"::text)) END,
               concat(COALESCE(NULLIF(btrim(t."AbrGenerique"::text), ''),
                CASE WHEN n."ID_TypeNiveau_5_Fk" IS NOT NULL
                     THEN 'Type #' || n."ID_TypeNiveau_5_Fk"::text
                     ELSE 'Niveau 5' END), ' - ',
                COALESCE(NULLIF(btrim(n."NomNiveau_5"::text), ''), 'Sans nom #' || n."ID_Niveau_5"::text)),
               CASE WHEN n."ID_Niveau_3_Fk" IS NOT NULL AND a."ID_Niveau_4" IS NOT NULL
                    AND n."ID_Niveau_3_Fk" IS DISTINCT FROM a."ID_Niveau_3_Fk"
                    THEN '(aire hors zone)' END) AS label,
           COALESCE(n."ID_Niveau_4_Fk", n."ID_Niveau_3_Fk") AS "parentId",
           CASE WHEN n."ID_Niveau_4_Fk" IS NOT NULL THEN 4 ELSE 3 END AS "parentNiveau",
           t."AbrGenerique"::text AS "TypeTerritoire", n."CodeNiveau_5"::text AS "CodeTerritoire"
    FROM geolocalisation."T_Niveau_5" n
    LEFT JOIN geolocalisation."T_Niveau_4" a ON a."ID_Niveau_4" = n."ID_Niveau_4_Fk"
    LEFT JOIN p3 p ON p.id = COALESCE(n."ID_Niveau_3_Fk", a."ID_Niveau_3_Fk")
    LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique" = n."ID_TypeNiveau_5_Fk"
    LEFT JOIN referentiel."T_Generique" t4 ON t4."ID_Generique" = a."ID_TypeNiveau_4_Fk"
)
SELECT 0 AS niveau, id, label, "parentId", "parentNiveau", "TypeTerritoire", "CodeTerritoire" FROM p0
UNION ALL
SELECT 1 AS niveau, id, label, "parentId", "parentNiveau", "TypeTerritoire", "CodeTerritoire" FROM p1
UNION ALL
SELECT 2 AS niveau, id, label, "parentId", "parentNiveau", "TypeTerritoire", "CodeTerritoire" FROM p2
UNION ALL
SELECT 3 AS niveau, id, label, "parentId", "parentNiveau", "TypeTerritoire", "CodeTerritoire" FROM p3
UNION ALL
SELECT 4 AS niveau, id, label, "parentId", "parentNiveau", "TypeTerritoire", "CodeTerritoire" FROM p4
UNION ALL
SELECT 5 AS niveau, id, label, "parentId", "parentNiveau", "TypeTerritoire", "CodeTerritoire" FROM p5;
COMMENT ON VIEW geolocalisation."V_ChoixTerritorial" IS 'Choix territoriaux partagés N0 à N5 : un identifiant par niveau et un chemin ISO / province / type - nom selon les parents physiques existants. Aucun rattachement sanitaire ou administratif n’est inventé.';
COMMENT ON COLUMN geolocalisation."V_ChoixTerritorial".niveau IS 'Niveau physique 0 à 5 ; associé à id pour désigner un territoire sans ambiguïté entre tables.';
COMMENT ON COLUMN geolocalisation."V_ChoixTerritorial".id IS 'Clé primaire inchangée de T_Niveau_n ; jamais remplacée par un libellé.';
COMMENT ON COLUMN geolocalisation."V_ChoixTerritorial".label IS 'Chemin lisible : iso du pays, nom de province puis AbrGenerique - NomNiveau_n pour chaque niveau typé. Un champ manquant conserve un repère neutre identifié, sans repli vers NomGenerique.';
COMMENT ON COLUMN geolocalisation."V_ChoixTerritorial"."parentId" IS 'Clé du parent physique direct ; pour N5, aire si renseignée, sinon zone directe. Ne remplace aucune FK de la fiche.';
COMMENT ON COLUMN geolocalisation."V_ChoixTerritorial"."parentNiveau" IS 'Niveau de la clé parentId, NULL pour N0. N5 conserve son lien direct à N3 en absence d’aire.';
COMMENT ON COLUMN geolocalisation."V_ChoixTerritorial"."TypeTerritoire" IS 'AbrGenerique du type réellement référencé, sans priorité au nom de dictionnaire et sans filtre de visibilité sur les affectations historiques.';
COMMENT ON COLUMN geolocalisation."V_ChoixTerritorial"."CodeTerritoire" IS 'Code local existant, distinct de iso du pays et des UID SNIS ; aucune conversion ni création de code.';
REVOKE ALL ON geolocalisation."V_ChoixTerritorial" FROM PUBLIC;
CREATE OR REPLACE VIEW geolocalisation."V_DestinationLogistique" AS
 SELECT n5."ID_Niveau_5" AS id,
    n5."NomNiveau_5",
    n5."CodeNiveau_5",
    chemin.label,
    n3."ID_Niveau_3" AS "ID_Niveau_3_Fk",
    n4."ID_Niveau_4" AS "ID_Niveau_4_Fk",
    ((NULLIF(btrim((n5."NomNiveau_5")::text), ''::text) IS NOT NULL) AND (n3."ID_Niveau_3" IS NOT NULL) AND (n2."ID_Niveau_2" IS NOT NULL) AND (n1."ID_Niveau_1" IS NOT NULL) AND (n0."ID_Niveau_0" IS NOT NULL) AND ((n5."ID_Niveau_4_Fk" IS NULL) OR (n4."ID_Niveau_4" IS NOT NULL)) AND ((n5."ID_Niveau_3_Fk" IS NULL) OR (n5."ID_Niveau_4_Fk" IS NULL) OR (n5."ID_Niveau_3_Fk" = n4."ID_Niveau_3_Fk"))) AS "EstCoherente"
   FROM (((((((((geolocalisation."T_Niveau_5" n5
     LEFT JOIN geolocalisation."T_Niveau_4" n4 ON ((n4."ID_Niveau_4" = n5."ID_Niveau_4_Fk")))
     LEFT JOIN geolocalisation."T_Niveau_3" n3 ON ((n3."ID_Niveau_3" = COALESCE(n5."ID_Niveau_3_Fk", n4."ID_Niveau_3_Fk"))))
     LEFT JOIN geolocalisation."T_Niveau_2" n2 ON ((n2."ID_Niveau_2" = n3."ID_Niveau_2_FK")))
     LEFT JOIN geolocalisation."T_Niveau_1" n1 ON ((n1."ID_Niveau_1" = n2."ID_Niveau_1_FK")))
     LEFT JOIN geolocalisation."T_Niveau_0" n0 ON ((n0."ID_Niveau_0" = n1."ID_Niveau_0_Fk")))
     LEFT JOIN referentiel."T_Generique" t2 ON ((t2."ID_Generique" = n2."ID_TypeNiveau_2_Fk")))
     LEFT JOIN referentiel."T_Generique" t3 ON ((t3."ID_Generique" = n3."ID_TypeNiveau_2_Fk")))
     LEFT JOIN referentiel."T_Generique" t4 ON ((t4."ID_Generique" = n4."ID_TypeNiveau_4_Fk")))
     LEFT JOIN referentiel."T_Generique" t5 ON ((t5."ID_Generique" = n5."ID_TypeNiveau_5_Fk")))
   LEFT JOIN geolocalisation."V_ChoixTerritorial" chemin ON chemin.niveau = 5 AND chemin.id = n5."ID_Niveau_5";
COMMENT ON VIEW geolocalisation."V_DestinationLogistique" IS 'Destinations logistiques avec le chemin partagé ISO / province / type - nom ; identifiants, parents et critères de cohérence historiques conservés.';
COMMENT ON COLUMN geolocalisation."V_DestinationLogistique".label IS 'Libellé de V_ChoixTerritorial au niveau 5 : iso du pays et abréviations réelles des types, sans classification déduite du nom.';
COMMIT;
