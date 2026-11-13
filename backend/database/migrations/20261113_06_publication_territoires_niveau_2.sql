ALTER TABLE geolocalisation."T_ParametrePublicationAnnuaire"
    DROP CONSTRAINT "T_ParametrePublicationAnnuaire_Niveau_check",
    ADD CONSTRAINT ck_publication_annuaire_niveau CHECK ("Niveau" BETWEEN 2 AND 5);

COMMENT ON CONSTRAINT ck_publication_annuaire_niveau ON geolocalisation."T_ParametrePublicationAnnuaire" IS 'Limite le réglage de publication aux niveaux territoriaux 2 à 5.';
COMMENT ON COLUMN geolocalisation."T_ParametrePublicationAnnuaire"."Niveau" IS 'Niveau territorial concerné, de 2 à 5.';

INSERT INTO geolocalisation."T_ParametrePublicationAnnuaire" ("Niveau") VALUES (2);

ALTER TABLE geolocalisation."T_Niveau_2" ADD COLUMN "PublierDansAnnuaire" boolean NOT NULL DEFAULT TRUE;
ALTER TABLE geolocalisation."T_Niveau_2" ALTER COLUMN "PublierDansAnnuaire"
    SET DEFAULT geolocalisation.fn_publication_annuaire_defaut(2);
COMMENT ON COLUMN geolocalisation."T_Niveau_2"."PublierDansAnnuaire" IS 'Indique si la fiche est publiable dans l’annuaire. La validité du type et la publication des contacts restent indépendantes.';

CREATE OR REPLACE VIEW geolocalisation."V_StructureSanitairePublique" AS
 SELECT 'n3:'||v."ID_Niveau_3"::text AS "StructureKey",3::integer AS "NiveauStructure",
  v."ID_Niveau_3" AS "ID_Structure",v."NomNiveau_3" AS "NomStructure",v."CodeNiveau_3" AS "CodeStructure",
  g."ID_Generique" AS "ID_TypeStructureFk",
  coalesce(nullif(btrim(g."AbrGenerique"),''),'Valeur sans abréviation #'||g."ID_Generique"::text)::text AS "TypeStructure",
  v."ID_Niveau_1",v."NomNiveau_1",v."ID_Niveau_2",v."NomNiveau_2",v."ID_Niveau_3",v."NomNiveau_3",
  NULL::integer AS "ID_Niveau_4",NULL::varchar AS "NomNiveau_4",
  c."AdresseTerritoire",c."TelephoneTerritoire",c."TelephoneSecondaireTerritoire",c."EmailTerritoire",
  c."SiteWebTerritoire",c."InformationsAccueilTerritoire",c."HorairesOuvertureTerritoire",
  (c."ID_CoordonneesTerritoire" IS NOT NULL) AS "CoordonneesPubliees"
 FROM geolocalisation."V_Niveau_3" v
 JOIN geolocalisation."T_Niveau_3" publication ON publication."ID_Niveau_3" = v."ID_Niveau_3" AND publication."PublierDansAnnuaire"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."ID_TypeNiveau_2_Fk"
  AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_3','ID_TypeNiveau_2_Fk',NULL))
 JOIN referentiel."T_CategorieGenerique" cat ON cat."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  AND cat."ValideCategorieGenerique" IS TRUE AND cat."IdEntiteFk" IS NULL
 LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON c."ID_Niveau_3Fk"=v."ID_Niveau_3" AND c."PublierCoordonneesAnnuaire" IS TRUE
 UNION ALL
 SELECT 'n4:'||v."ID_Niveau_4"::text,4::integer,v."ID_Niveau_4",v."NomNiveau_4",v."CodeNiveau_4",g."ID_Generique",
  coalesce(nullif(btrim(g."AbrGenerique"),''),'Valeur sans abréviation #'||g."ID_Generique"::text)::text,
  v."ID_Niveau_1",v."NomNiveau_1",v."ID_Niveau_2",v."NomNiveau_2",v."ID_Niveau_3",v."NomNiveau_3",v."ID_Niveau_4",v."NomNiveau_4",
  c."AdresseTerritoire",c."TelephoneTerritoire",c."TelephoneSecondaireTerritoire",c."EmailTerritoire",
  c."SiteWebTerritoire",c."InformationsAccueilTerritoire",c."HorairesOuvertureTerritoire",(c."ID_CoordonneesTerritoire" IS NOT NULL)
 FROM geolocalisation."V_Niveau_4" v
 JOIN geolocalisation."T_Niveau_4" publication ON publication."ID_Niveau_4" = v."ID_Niveau_4" AND publication."PublierDansAnnuaire"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."ID_TypeNiveau_4_Fk"
  AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_4','ID_TypeNiveau_4_Fk',NULL))
 JOIN referentiel."T_CategorieGenerique" cat ON cat."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  AND cat."ValideCategorieGenerique" IS TRUE AND cat."IdEntiteFk" IS NULL
 LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON c."ID_Niveau_4Fk"=v."ID_Niveau_4" AND c."PublierCoordonneesAnnuaire" IS TRUE
 UNION ALL
 SELECT 'n5:'||v."ID_Niveau_5"::text,5::integer,v."ID_Niveau_5",v."NomNiveau_5",v."CodeNiveau_5",g."ID_Generique",
  coalesce(nullif(btrim(g."AbrGenerique"),''),'Valeur sans abréviation #'||g."ID_Generique"::text)::text,
  v."ID_Niveau_1",v."NomNiveau_1",v."ID_Niveau_2",v."NomNiveau_2",v."ID_Niveau_3",v."NomNiveau_3",v."ID_Niveau_4",v."NomNiveau_4",
  c."AdresseTerritoire",c."TelephoneTerritoire",c."TelephoneSecondaireTerritoire",c."EmailTerritoire",
  c."SiteWebTerritoire",c."InformationsAccueilTerritoire",c."HorairesOuvertureTerritoire",(c."ID_CoordonneesTerritoire" IS NOT NULL)
 FROM geolocalisation."V_Niveau_5" v
 JOIN geolocalisation."T_Niveau_5" publication ON publication."ID_Niveau_5" = v."ID_Niveau_5" AND publication."PublierDansAnnuaire"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."ID_TypeNiveau_5_Fk"
  AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_5','ID_TypeNiveau_5_Fk',NULL))
 JOIN referentiel."T_CategorieGenerique" cat ON cat."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  AND cat."ValideCategorieGenerique" IS TRUE AND cat."IdEntiteFk" IS NULL
 LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON c."ID_Niveau_5Fk"=v."ID_Niveau_5" AND c."PublierCoordonneesAnnuaire" IS TRUE
 UNION ALL
 SELECT 'n2:'||v."ID_Niveau_2"::text,2::integer,v."ID_Niveau_2",v."NomNiveau_2",v."CodeNiveau_2",g."ID_Generique",
  coalesce(nullif(btrim(g."AbrGenerique"),''),'Valeur sans abréviation #'||g."ID_Generique"::text)::text,
  v."ID_Niveau_1_FK",v."NomNiveau_1",v."ID_Niveau_2",v."NomNiveau_2",
  NULL::integer,NULL::varchar(255),NULL::integer,NULL::varchar,
  c."AdresseTerritoire",c."TelephoneTerritoire",c."TelephoneSecondaireTerritoire",c."EmailTerritoire",
  c."SiteWebTerritoire",c."InformationsAccueilTerritoire",c."HorairesOuvertureTerritoire",(c."ID_CoordonneesTerritoire" IS NOT NULL)
 FROM geolocalisation."V_Niveau_2" v
 JOIN geolocalisation."T_Niveau_2" publication ON publication."ID_Niveau_2" = v."ID_Niveau_2" AND publication."PublierDansAnnuaire"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."ID_TypeNiveau_2_Fk"
  AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_2','ID_TypeNiveau_2_Fk',NULL))
 JOIN referentiel."T_CategorieGenerique" cat ON cat."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  AND cat."ValideCategorieGenerique" IS TRUE AND cat."IdEntiteFk" IS NULL
 LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON c."ID_Niveau_2Fk"=v."ID_Niveau_2" AND c."PublierCoordonneesAnnuaire" IS TRUE;

COMMENT ON VIEW geolocalisation."V_StructureSanitairePublique" IS 'Annuaire partagé des niveaux 2 à 5, limité aux fiches publiées dont le type appartient au référentiel actif. Les contacts et horaires ont un réglage de publication indépendant.';
