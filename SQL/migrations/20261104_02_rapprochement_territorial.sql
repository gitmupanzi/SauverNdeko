-- Socle additif de rapprochement des territoires, validé par le propriétaire.
-- Ne charge aucune source, correspondance ou donnée ; ne modifie aucun uidSNIS,
-- nom, parent, identifiant, type, coordonnée ou vue des territoires existants.
-- Les sources SNIS/DHIS2, GRID3 et les copies locales restent distinctes.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 IF to_regclass('geolocalisation."T_Niveau_5"') IS NULL THEN
  RAISE EXCEPTION 'Les territoires existants sont requis';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('geolocalisation:rapprochement-installation',0));
END $$;

CREATE TABLE IF NOT EXISTS geolocalisation."T_SourceRapprochementTerritorial" (
 "ID_SourceRapprochementTerritorial" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "CodeSource" text NOT NULL CHECK (length(btrim("CodeSource")) BETWEEN 1 AND 80),
 "VersionSource" text NOT NULL CHECK (length(btrim("VersionSource")) BETWEEN 1 AND 160),
 "Sha256Source" text NOT NULL UNIQUE CHECK ("Sha256Source" ~ '^[0-9a-f]{64}$'),
 "NomFichierSource" text NOT NULL CHECK (length(btrim("NomFichierSource")) BETWEEN 1 AND 255),
 "DateSource" date,
 "MetadonneesSource" jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof("MetadonneesSource")='object'),
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS geolocalisation."T_CorrespondanceTerritoriale" (
 "ID_CorrespondanceTerritoriale" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_SourceRapprochementFk" bigint NOT NULL REFERENCES geolocalisation."T_SourceRapprochementTerritorial"("ID_SourceRapprochementTerritorial") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "CleLigneSource" text NOT NULL CHECK (length(btrim("CleLigneSource")) BETWEEN 1 AND 500),
 "UidSource" text,
 "UidSNISSource" text,
 "UidProvinceSource" text,
 "UidZoneSource" text,
 "UidAireSource" text,
 "Grid3Id" text,
 "NomSource" text,
 "ID_Niveau_1Fk" integer REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_Niveau_3Fk" integer REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_Niveau_4Fk" integer REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_Niveau_5Fk" integer REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "Decision" text NOT NULL DEFAULT 'proposee' CHECK ("Decision" IN ('proposee','confirmee','refusee')),
 "ConflitSource" boolean NOT NULL DEFAULT false,
 "Preuves" jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof("Preuves")='object'),
 "MotifDecision" text,
 "DecideParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "DecideLe" timestamptz,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT uq_correspondance_source_ligne UNIQUE("ID_SourceRapprochementFk","CleLigneSource"),
 CONSTRAINT ck_correspondance_une_cible CHECK (num_nonnulls("ID_Niveau_1Fk","ID_Niveau_3Fk","ID_Niveau_4Fk","ID_Niveau_5Fk")=1),
 CONSTRAINT ck_correspondance_decision_tracee CHECK ("Decision"='proposee' OR (length(btrim("MotifDecision"))>0 AND "MotifDecision" IS NOT NULL AND "DecideParUserFk" IS NOT NULL AND "DecideLe" IS NOT NULL AND "Preuves"<>'{}'::jsonb)),
 CONSTRAINT ck_correspondance_conflit_non_confirme CHECK ("Decision"<>'confirmee' OR NOT "ConflitSource")
);
CREATE INDEX IF NOT EXISTS ix_correspondance_territoire_n1 ON geolocalisation."T_CorrespondanceTerritoriale"("ID_Niveau_1Fk") WHERE "ID_Niveau_1Fk" IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_correspondance_territoire_n3 ON geolocalisation."T_CorrespondanceTerritoriale"("ID_Niveau_3Fk") WHERE "ID_Niveau_3Fk" IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_correspondance_territoire_n4 ON geolocalisation."T_CorrespondanceTerritoriale"("ID_Niveau_4Fk") WHERE "ID_Niveau_4Fk" IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_correspondance_territoire_n5 ON geolocalisation."T_CorrespondanceTerritoriale"("ID_Niveau_5Fk") WHERE "ID_Niveau_5Fk" IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_correspondance_uid_confirme ON geolocalisation."T_CorrespondanceTerritoriale"("UidSNISSource") WHERE "Decision"='confirmee' AND "UidSNISSource" IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_correspondance_source_grid3id ON geolocalisation."T_CorrespondanceTerritoriale"("ID_SourceRapprochementFk","Grid3Id") WHERE "Grid3Id" IS NOT NULL;

CREATE TABLE IF NOT EXISTS geolocalisation."T_LienTerritorial" (
 "ID_LienTerritorial" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_SourceRapprochementFk" bigint NOT NULL REFERENCES geolocalisation."T_SourceRapprochementTerritorial"("ID_SourceRapprochementTerritorial") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "CleLienSource" text NOT NULL CHECK (length(btrim("CleLienSource")) BETWEEN 1 AND 500),
 "NatureLien" text NOT NULL CHECK ("NatureLien" IN ('copie_n5_n4','bureau_de_zone','rattachement_sanitaire','aire_de_zone')),
 "DomaineLien" text NOT NULL CHECK ("DomaineLien" IN ('sanitaire','administratif','compatibilite')),
 "ID_OrigineNiveau_3Fk" integer REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_OrigineNiveau_4Fk" integer REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_OrigineNiveau_5Fk" integer REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_CibleNiveau_2Fk" integer REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_CibleNiveau_3Fk" integer REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "ID_CibleNiveau_4Fk" integer REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "Decision" text NOT NULL DEFAULT 'proposee' CHECK ("Decision" IN ('proposee','confirmee','refusee')),
 "ConflitSource" boolean NOT NULL DEFAULT false,
 "Preuves" jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof("Preuves")='object'),
 "MotifDecision" text,
 "DecideParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE RESTRICT ON DELETE RESTRICT,
 "DecideLe" timestamptz,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT uq_lien_territorial_source_ligne UNIQUE("ID_SourceRapprochementFk","CleLienSource"),
 CONSTRAINT ck_lien_territorial_forme CHECK (
  num_nonnulls("ID_OrigineNiveau_3Fk","ID_OrigineNiveau_4Fk","ID_OrigineNiveau_5Fk")=1 AND num_nonnulls("ID_CibleNiveau_2Fk","ID_CibleNiveau_3Fk","ID_CibleNiveau_4Fk")=1 AND
  (("NatureLien"='copie_n5_n4' AND "ID_OrigineNiveau_5Fk" IS NOT NULL AND "ID_CibleNiveau_4Fk" IS NOT NULL)
   OR ("NatureLien"='bureau_de_zone' AND "DomaineLien"='sanitaire' AND "ID_OrigineNiveau_3Fk" IS NOT NULL AND "ID_CibleNiveau_3Fk" IS NOT NULL AND "ID_OrigineNiveau_3Fk"<>"ID_CibleNiveau_3Fk")
   OR ("NatureLien"='rattachement_sanitaire' AND "DomaineLien"='sanitaire' AND "ID_OrigineNiveau_3Fk" IS NOT NULL AND "ID_CibleNiveau_2Fk" IS NOT NULL)
   OR ("NatureLien"='aire_de_zone' AND "DomaineLien"='sanitaire' AND "ID_OrigineNiveau_4Fk" IS NOT NULL AND "ID_CibleNiveau_3Fk" IS NOT NULL))),
 CONSTRAINT ck_lien_territorial_decision_tracee CHECK ("Decision"='proposee' OR (length(btrim("MotifDecision"))>0 AND "MotifDecision" IS NOT NULL AND "DecideParUserFk" IS NOT NULL AND "DecideLe" IS NOT NULL AND "Preuves"<>'{}'::jsonb)),
 CONSTRAINT ck_lien_territorial_conflit_non_confirme CHECK ("Decision"<>'confirmee' OR NOT "ConflitSource")
);

-- Les FK ci-dessus restent les autorités d'identité. Cette fonction ne transforme
-- jamais les identifiants locaux en UID externes et ne recopie aucun parent.
CREATE OR REPLACE FUNCTION geolocalisation.tr_rapprochement_territorial_integrite()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,geolocalisation AS $$
DECLARE current_uid text; province_uid text; zone_uid text; area_uid text;
 local_n3 integer; local_n4 integer; local_n1 integer;
 source_parent integer; target_parent integer; source_type integer; target_type integer;
 source_province integer; target_province integer; source_type_label text; target_type_label text; parent_type_label text;
 source_name text; target_name text; source_uid text; target_uid text; matching_areas integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une preuve de rapprochement ne se supprime pas ; conserver sa version et sa décision.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_SourceRapprochementTerritorial' THEN
  IF TG_OP='UPDATE' THEN RAISE EXCEPTION 'La provenance est immuable ; enregistrer une nouvelle version de source.' USING ERRCODE='23514';END IF;
  NEW."CreeLe":=clock_timestamp();RETURN NEW;
 END IF;
 IF TG_OP='UPDATE' THEN
  IF OLD."Decision"<>'proposee' THEN RAISE EXCEPTION 'La décision finale est immuable ; réexaminer dans une nouvelle version de source.' USING ERRCODE='23514';END IF;
  IF (to_jsonb(NEW)-ARRAY['Decision','MotifDecision','DecideParUserFk','DecideLe']) IS DISTINCT FROM
     (to_jsonb(OLD)-ARRAY['Decision','MotifDecision','DecideParUserFk','DecideLe']) THEN
   RAISE EXCEPTION 'La cible et les preuves importées sont immuables ; créer une nouvelle version.' USING ERRCODE='23514';
  END IF;
 ELSE NEW."CreeLe":=clock_timestamp();END IF;
 IF NEW."Decision"='proposee' THEN
  NEW."DecideLe":=NULL;NEW."DecideParUserFk":=NULL;
 ELSE NEW."DecideLe":=clock_timestamp();END IF;
 IF NEW."Decision"<>'confirmee' THEN RETURN NEW;END IF;
 IF NEW."ConflitSource" THEN RAISE EXCEPTION 'Une correspondance en conflit ne peut pas être confirmée.' USING ERRCODE='23514';END IF;

 IF TG_TABLE_NAME='T_CorrespondanceTerritoriale' THEN
  IF NEW."ID_Niveau_1Fk" IS NOT NULL THEN
   local_n1:=NEW."ID_Niveau_1Fk";
   SELECT "uidSNIS" INTO current_uid FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=local_n1 FOR SHARE;
  ELSIF NEW."ID_Niveau_3Fk" IS NOT NULL THEN
   local_n3:=NEW."ID_Niveau_3Fk";
   SELECT "uidSNIS" INTO current_uid FROM geolocalisation."T_Niveau_3" WHERE "ID_Niveau_3"=local_n3 FOR SHARE;
  ELSIF NEW."ID_Niveau_4Fk" IS NOT NULL THEN
   local_n4:=NEW."ID_Niveau_4Fk";
   SELECT "uidSNIS","ID_Niveau_3_Fk" INTO current_uid,local_n3 FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=local_n4 FOR SHARE;
  ELSE
   SELECT "uidSNIS","ID_Niveau_3_Fk","ID_Niveau_4_Fk" INTO current_uid,local_n3,local_n4 FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=NEW."ID_Niveau_5Fk" FOR SHARE;
   IF local_n4 IS NOT NULL THEN
    SELECT "ID_Niveau_3_Fk" INTO target_parent FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=local_n4 FOR SHARE;
    IF local_n3 IS NOT NULL AND target_parent IS NOT NULL AND local_n3<>target_parent THEN
     RAISE EXCEPTION 'Le site et son aire indiquent des zones contradictoires.' USING ERRCODE='23514';
    END IF;
    local_n3:=coalesce(local_n3,target_parent);
   END IF;
  END IF;
  IF local_n3 IS NOT NULL THEN
   SELECT n3."uidSNIS",n2."ID_Niveau_1_FK" INTO zone_uid,local_n1
    FROM geolocalisation."T_Niveau_3" n3 LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK" WHERE n3."ID_Niveau_3"=local_n3;
  END IF;
  IF local_n4 IS NOT NULL THEN SELECT "uidSNIS" INTO area_uid FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=local_n4;END IF;
  IF local_n1 IS NOT NULL THEN SELECT "uidSNIS" INTO province_uid FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=local_n1;END IF;
  IF (nullif(btrim(current_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidSNISSource"),'') IS NOT NULL AND current_uid<>NEW."UidSNISSource")
   OR (nullif(btrim(province_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidProvinceSource"),'') IS NOT NULL AND province_uid<>NEW."UidProvinceSource")
   OR (nullif(btrim(zone_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidZoneSource"),'') IS NOT NULL AND zone_uid<>NEW."UidZoneSource")
   OR (nullif(btrim(area_uid),'') IS NOT NULL AND nullif(btrim(NEW."UidAireSource"),'') IS NOT NULL AND area_uid<>NEW."UidAireSource") THEN
   RAISE EXCEPTION 'Identifiant SNIS ou parent existant contradictoire ; conserver la proposition pour validation.' USING ERRCODE='23514';
  END IF;
  IF nullif(btrim(NEW."UidSNISSource"),'') IS NOT NULL THEN
   PERFORM pg_advisory_xact_lock(hashtextextended('geolocalisation:uid-snis:'||NEW."UidSNISSource",0));
   IF EXISTS(SELECT FROM geolocalisation."T_CorrespondanceTerritoriale" c WHERE c."Decision"='confirmee'
    AND c."ID_CorrespondanceTerritoriale"<>NEW."ID_CorrespondanceTerritoriale"
    AND c."UidSNISSource"=NEW."UidSNISSource"
    AND ROW(c."ID_Niveau_1Fk",c."ID_Niveau_3Fk",c."ID_Niveau_4Fk",c."ID_Niveau_5Fk") IS DISTINCT FROM ROW(NEW."ID_Niveau_1Fk",NEW."ID_Niveau_3Fk",NEW."ID_Niveau_4Fk",NEW."ID_Niveau_5Fk")) THEN
    RAISE EXCEPTION 'Le même UID SNIS confirmé désigne déjà une autre identité locale ; conserver le conflit proposé.' USING ERRCODE='23514';
   END IF;
  END IF;
 ELSE
  IF NEW."NatureLien"='copie_n5_n4' THEN
   SELECT "ID_Niveau_3_Fk","ID_TypeNiveau_5_Fk","NomNiveau_5","uidSNIS" INTO source_parent,source_type,source_name,source_uid FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=NEW."ID_OrigineNiveau_5Fk" FOR SHARE;
   SELECT "ID_Niveau_3_Fk","ID_TypeNiveau_4_Fk","NomNiveau_4","uidSNIS" INTO target_parent,target_type,target_name,target_uid FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=NEW."ID_CibleNiveau_4Fk" FOR SHARE;
   SELECT count(*) INTO matching_areas FROM geolocalisation."T_Niveau_4" n WHERE n."ID_Niveau_3_Fk"=source_parent AND n."ID_TypeNiveau_4_Fk"=source_type
    AND referentiel.fn_normaliser_libelle(n."NomNiveau_4")=referentiel.fn_normaliser_libelle(source_name);
   IF source_parent IS NULL OR target_parent IS NULL OR source_parent<>target_parent OR source_type IS NULL OR target_type IS NULL OR source_type<>target_type
    OR nullif(btrim(source_name),'') IS NULL OR referentiel.fn_normaliser_libelle(source_name) IS DISTINCT FROM referentiel.fn_normaliser_libelle(target_name)
    OR matching_areas<>1 OR (nullif(btrim(source_uid),'') IS NOT NULL AND nullif(btrim(target_uid),'') IS NOT NULL AND source_uid<>target_uid) THEN
    RAISE EXCEPTION 'Une copie N5/N4 confirmée exige un nom, un type et un parent concordants, une cible unique et aucun UID contradictoire ; aucune fusion par homonymie.' USING ERRCODE='23514';
   END IF;
  ELSIF NEW."NatureLien"='aire_de_zone' THEN
   SELECT n."ID_Niveau_3_Fk",g."AbrGenerique" INTO source_parent,source_type_label
    FROM geolocalisation."T_Niveau_4" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_4_Fk"
    WHERE n."ID_Niveau_4"=NEW."ID_OrigineNiveau_4Fk" FOR SHARE OF n;
   SELECT g."AbrGenerique",n2."ID_Niveau_1_FK" INTO target_type_label,target_province
    FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk"
    JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n."ID_Niveau_2_FK"
    WHERE n."ID_Niveau_3"=NEW."ID_CibleNiveau_3Fk";
   SELECT n2."ID_Niveau_1_FK",g."AbrGenerique" INTO source_province,parent_type_label
    FROM geolocalisation."T_Niveau_3" n JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n."ID_Niveau_2_FK"
    JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=source_parent;
   IF NOT coalesce(source_type_label='AS' AND target_type_label='ZS' AND parent_type_label IN ('BCZS','ZS'),false)
    OR source_province IS NULL OR target_province IS NULL OR source_province<>target_province
    OR (parent_type_label='ZS' AND source_parent<>NEW."ID_CibleNiveau_3Fk")
    OR EXISTS(SELECT FROM geolocalisation."T_LienTerritorial" l WHERE l."NatureLien"='bureau_de_zone' AND l."Decision"='confirmee'
      AND l."ID_OrigineNiveau_3Fk"=source_parent AND l."ID_CibleNiveau_3Fk"<>NEW."ID_CibleNiveau_3Fk") THEN
    RAISE EXCEPTION 'Le lien aire-zone exige une AS, une ZS et une province concordantes, sans contredire le parent sanitaire prouvé.' USING ERRCODE='23514';
   END IF;
  ELSE
   SELECT n2."ID_Niveau_1_FK" INTO source_province FROM geolocalisation."T_Niveau_3" n3 JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK" WHERE n3."ID_Niveau_3"=NEW."ID_OrigineNiveau_3Fk";
   IF NEW."NatureLien"='bureau_de_zone' THEN
    SELECT n2."ID_Niveau_1_FK" INTO target_province FROM geolocalisation."T_Niveau_3" n3 JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK" WHERE n3."ID_Niveau_3"=NEW."ID_CibleNiveau_3Fk";
    SELECT g."AbrGenerique" INTO source_type_label FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=NEW."ID_OrigineNiveau_3Fk";
    SELECT g."AbrGenerique" INTO target_type_label FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=NEW."ID_CibleNiveau_3Fk";
    IF NOT coalesce(source_type_label='BCZS' AND target_type_label='ZS',false) THEN
     RAISE EXCEPTION 'Le bureau de zone exige un BCZS d’origine et une ZS cible distincte ; un bureau ne devient pas la zone desservie.' USING ERRCODE='23514';
    END IF;
   ELSE
    SELECT "ID_Niveau_1_FK" INTO target_province FROM geolocalisation."T_Niveau_2" WHERE "ID_Niveau_2"=NEW."ID_CibleNiveau_2Fk";
    SELECT g."AbrGenerique" INTO source_type_label FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_3"=NEW."ID_OrigineNiveau_3Fk";
    SELECT g."AbrGenerique" INTO target_type_label FROM geolocalisation."T_Niveau_2" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk" WHERE n."ID_Niveau_2"=NEW."ID_CibleNiveau_2Fk";
    IF NOT coalesce(source_type_label='ZS' AND target_type_label='Ant PEV',false) THEN
     RAISE EXCEPTION 'Un rattachement sanitaire exige une ZS et une antenne PEV identifiées par le référentiel.' USING ERRCODE='23514';
    END IF;
   END IF;
   IF source_province IS NULL OR target_province IS NULL OR source_province<>target_province THEN
    RAISE EXCEPTION 'Un lien bureau-zone ou un rattachement sanitaire confirmé exige une province commune prouvée.' USING ERRCODE='23514';
   END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;

DO $$ DECLARE tab text; BEGIN
 FOREACH tab IN ARRAY ARRAY['T_SourceRapprochementTerritorial','T_CorrespondanceTerritoriale','T_LienTerritorial'] LOOP
  IF NOT EXISTS(SELECT FROM pg_trigger WHERE tgrelid=to_regclass(format('geolocalisation.%I',tab)) AND tgname='rapprochement_territorial_integrite' AND NOT tgisinternal) THEN
   EXECUTE format('CREATE TRIGGER rapprochement_territorial_integrite BEFORE INSERT OR UPDATE OR DELETE ON geolocalisation.%I FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_rapprochement_territorial_integrite()',tab);
  END IF;
  EXECUTE format('REVOKE ALL ON geolocalisation.%I FROM PUBLIC',tab);
  EXECUTE format('COMMENT ON TRIGGER rapprochement_territorial_integrite ON geolocalisation.%I IS %L',tab,'Provenance et décisions finales immuables ; contrôles des parents et conflits avant confirmation, sans réécriture des territoires.');
 END LOOP;
END $$;

COMMENT ON TABLE geolocalisation."T_SourceRapprochementTerritorial" IS 'Version immuable et empreinte vérifiable d’une source de rapprochement géographique. Socle installé sans import implicite ; toute application d’une décision utilise une migration de données contrôlée. Ne contient aucune géométrie fabriquée à partir de surfaces ou de longueurs.';
COMMENT ON TABLE geolocalisation."T_CorrespondanceTerritoriale" IS 'Correspondance documentée d’une ligne source vers une seule vraie FK territoriale N1, N3, N4 ou N5. Un objet GRID3 est unique dans sa version de source, mais plusieurs objets GRID3 peuvent pointer vers une même aire ; aucune unicité artificielle par aire n’est déduite. Une confirmation ne modifie ni uidSNIS ni la hiérarchie : une migration de données contrôlée et validée est nécessaire.';
COMMENT ON TABLE geolocalisation."T_LienTerritorial" IS 'Liens explicites versionnés entre identités locales conservées : copie N5/N4, bureau BCZS vers zone ZS distincte, rattachement sanitaire ZS vers antenne PEV ou aire AS vers zone ZS canonique. Un bureau et sa zone ne sont pas une même identité et ne partagent pas leur UID par déduction. Ne fusionne pas les organisations administrative et sanitaire, ne déplace pas les parents physiques historiques et ne supprime aucune copie utilisée comme destination.';
COMMENT ON FUNCTION geolocalisation.tr_rapprochement_territorial_integrite() IS 'Garde transactionnelle additive du rapprochement : sources, preuves, cibles et décisions finales immuables, acteur/motif pour les décisions, refus des UID ou parents contradictoires. Ne peuple aucun UID, parent ou GPS ; n’accorde aucun droit applicatif.';

-- Toutes les colonnes, contraintes et index de ce nouveau socle sont documentés.
DO $$ DECLARE r record; label text; BEGIN
 FOR r IN SELECT c.relname,a.attname FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='geolocalisation' AND c.relname IN ('T_SourceRapprochementTerritorial','T_CorrespondanceTerritoriale','T_LienTerritorial') AND a.attnum>0 AND NOT a.attisdropped LOOP
  label:=CASE r.attname
   WHEN 'ID_SourceRapprochementTerritorial' THEN 'Identifiant technique stable de cette version de source.'
   WHEN 'ID_CorrespondanceTerritoriale' THEN 'Clé primaire technique de la preuve de correspondance, distincte des identifiants externes et des clés territoriales.'
   WHEN 'ID_LienTerritorial' THEN 'Clé primaire technique du lien local versionné ; ne remplace aucune identité N2, N3, N4 ou N5.'
   WHEN 'CodeSource' THEN 'Nom technique de la source, par exemple SNIS/DHIS2, GRID3 ou un état local ; ne constitue pas une catégorie métier.'
   WHEN 'VersionSource' THEN 'Version ou date déclarée de la source ; ne pas remplacer une version antérieure.'
   WHEN 'Sha256Source' THEN 'Empreinte SHA-256 des octets du fichier ou de l’état source, 64 caractères hexadécimaux minuscules uniques.'
   WHEN 'NomFichierSource' THEN 'Nom du fichier justificatif ; privilégier le nom simple plutôt qu’un chemin personnel ou un secret.'
   WHEN 'DateSource' THEN 'Date déclarée dans la source ; NULL si inconnue, distincte de la date d’import.'
   WHEN 'MetadonneesSource' THEN 'Provenance et périmètre de la source en objet JSON, sans géométrie ou coordonnées déduites de mesures de surface/longueur.'
   WHEN 'ID_SourceRapprochementFk' THEN 'Vraie FK vers la version immuable de provenance ; plusieurs lignes peuvent partager cette source.'
   WHEN 'CleLigneSource' THEN 'Clé textuelle stable de ligne dans cette version de source, éventuellement feuille et numéro de ligne ; unique avec la source.'
   WHEN 'CleLienSource' THEN 'Clé stable de la proposition de lien dans sa version de source ; unique avec cette version.'
   WHEN 'UidSource' THEN 'Identifiant externe tel que fourni, sans le confondre par égalité textuelle avec un UID SNIS.'
   WHEN 'UidSNISSource' THEN 'UID SNIS/DHIS2 explicitement proposé par la source, distinct du champ uidSNIS territorial ; un conflit existant interdit la confirmation.'
   WHEN 'UidProvinceSource' THEN 'Identifiant externe de la province parente cité dans la preuve ; comparaison SNIS seulement si cette identité est prouvée.'
   WHEN 'UidZoneSource' THEN 'Identifiant externe de zone de santé cité dans la preuve, sans écrasement du rattachement existant.'
   WHEN 'UidAireSource' THEN 'Identifiant externe de l’aire de santé ; plusieurs objets GRID3 peuvent partager cette valeur.'
   WHEN 'Grid3Id' THEN 'Identifiant de l’objet GRID3 source, conservé textuellement sans supposer une relation un-à-un avec l’aire métier.'
   WHEN 'NomSource' THEN 'Libellé original de la ligne externe, conservé pour vérifier et expliquer la correspondance.'
   WHEN 'Decision' THEN 'État technique de revue : proposee, confirmee ou refusee. La proposition ne vaut pas modification métier ; la décision finale est immuable.'
   WHEN 'ConflitSource' THEN 'Conflit détecté entre identifiants, parents ou sources ; une ligne en conflit ne peut pas être confirmée.'
   WHEN 'Preuves' THEN 'Éléments immuables justifiant la proposition : méthode, noms, parents et références de ligne ; objet non vide requis pour conclure.'
   WHEN 'MotifDecision' THEN 'Justification obligatoire d’une confirmation ou d’un refus, sans effacer les données source.'
   WHEN 'DecideParUserFk' THEN 'Compte métier existant ayant pris la décision ; une GUC de session ne vaut pas autorisation.'
   WHEN 'DecideLe' THEN 'Instant technique de décision renseigné par le trigger ; NULL pour une proposition non décidée.'
   WHEN 'CreeLe' THEN 'Instant technique de conservation de la preuve, indépendant de la date des données source.'
   WHEN 'NatureLien' THEN 'Forme technique fermée : copie_n5_n4, bureau_de_zone (BCZS vers ZS distincte), rattachement_sanitaire (ZS vers antenne PEV) ou aire_de_zone (AS vers ZS canonique). Ne remplace pas le type catégoriel et ne fusionne pas le bureau et sa zone.'
   WHEN 'DomaineLien' THEN 'Organisation concernée par la proposition : sanitaire, administratif ou compatibilite ; ne déduit aucune équivalence de périmètre.'
   ELSE 'Identité locale protégée par une vraie clé étrangère ; niveau indiqué dans le nom du champ, sans conversion par simple égalité numérique.'
  END;
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I.%I IS %L',r.relname,r.attname,label);
 END LOOP;
 FOR r IN SELECT c.relname,co.conname FROM pg_constraint co JOIN pg_class c ON c.oid=co.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='geolocalisation' AND c.relname IN ('T_SourceRapprochementTerritorial','T_CorrespondanceTerritoriale','T_LienTerritorial') LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON geolocalisation.%I IS %L',r.conname,r.relname,'Intégrité du rapprochement versionné : identité, unicité de ligne source, FK réelles ou décision explicite ; aucun changement implicite des territoires.');
 END LOOP;
 FOR r IN SELECT i.relname FROM pg_index x JOIN pg_class i ON i.oid=x.indexrelid JOIN pg_class c ON c.oid=x.indrelid JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='geolocalisation' AND c.relname IN ('T_SourceRapprochementTerritorial','T_CorrespondanceTerritoriale','T_LienTerritorial') LOOP
  EXECUTE format('COMMENT ON INDEX geolocalisation.%I IS %L',r.relname,'Index de conservation et de recherche des preuves versionnées, sans unicité artificielle entre les objets GRID3 et les aires de santé.');
 END LOOP;
 FOR r IN SELECT s.relname FROM pg_class s JOIN pg_namespace n ON n.oid=s.relnamespace JOIN pg_depend d ON d.objid=s.oid
  JOIN pg_class c ON c.oid=d.refobjid WHERE s.relkind='S' AND n.nspname='geolocalisation'
  AND c.relname IN ('T_SourceRapprochementTerritorial','T_CorrespondanceTerritoriale','T_LienTerritorial') LOOP
  EXECUTE format('COMMENT ON SEQUENCE geolocalisation.%I IS %L',r.relname,'Séquence technique d’identité du rapprochement ; aucun UID externe ou code métier n’est généré par cette séquence.');
 END LOOP;
END $$;

-- Lecture privée canonique : une ligne par AS, plus les ZS sans AS rapprochée.
-- Un bureau n'est pas une zone ; les copies historiques N5 ne sont pas des AS
-- supplémentaires. Les candidats distincts sont agrégés AVANT les jointures.
CREATE OR REPLACE VIEW geolocalisation."V_PyramideSanitaireRapprochee" AS
WITH zones AS (
 SELECT n."ID_Niveau_3" id,n."NomNiveau_3" nom,n."uidSNIS" uid,n."ID_Niveau_2_FK" parent,n2."ID_Niveau_1_FK" province
 FROM geolocalisation."T_Niveau_3" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_2_Fk"
 LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n."ID_Niveau_2_FK"
 WHERE g."AbrGenerique"='ZS' AND g."IdEntiteFk" IS NULL
  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_3','ID_TypeNiveau_2_Fk',NULL))
), aires AS (
 SELECT n."ID_Niveau_4" id,n."NomNiveau_4" nom,n."uidSNIS" uid,n."ID_Niveau_3_Fk" parent,n2."ID_Niveau_1_FK" province
 FROM geolocalisation."T_Niveau_4" n JOIN referentiel."T_Generique" g ON g."ID_Generique"=n."ID_TypeNiveau_4_Fk"
 LEFT JOIN geolocalisation."T_Niveau_3" n3 ON n3."ID_Niveau_3"=n."ID_Niveau_3_Fk"
 LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK"
 WHERE g."AbrGenerique"='AS' AND g."IdEntiteFk" IS NULL
  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_4','ID_TypeNiveau_4_Fk',NULL))
), liens_confirmes AS (
 SELECT * FROM geolocalisation."T_LienTerritorial" WHERE "Decision"='confirmee' AND NOT "ConflitSource"
), candidats_zones AS (
 SELECT a.id aire,z.id zone FROM aires a JOIN zones z ON z.id=a.parent
 UNION
 SELECT a.id,z.id FROM liens_confirmes l JOIN aires a ON a.id=l."ID_OrigineNiveau_4Fk"
 JOIN zones z ON z.id=l."ID_CibleNiveau_3Fk" WHERE l."NatureLien"='aire_de_zone'
), affectations_aires AS (
 SELECT aire,count(DISTINCT zone)::integer nombre,
 CASE WHEN count(DISTINCT zone)=1 THEN min(zone) ELSE NULL END zone
 FROM candidats_zones GROUP BY aire
), candidats_antennes AS (
 SELECT z.id zone,n2."ID_Niveau_2" antenne FROM zones z
 JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=z.parent
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=n2."ID_TypeNiveau_2_Fk" AND g."AbrGenerique"='Ant PEV'
 UNION
 SELECT z.id,n2."ID_Niveau_2" FROM liens_confirmes l JOIN zones z ON z.id=l."ID_OrigineNiveau_3Fk"
 JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=l."ID_CibleNiveau_2Fk"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=n2."ID_TypeNiveau_2_Fk" AND g."AbrGenerique"='Ant PEV'
 WHERE l."NatureLien"='rattachement_sanitaire'
), affectations_antennes AS (
 SELECT zone,count(DISTINCT antenne)::integer nombre,
 CASE WHEN count(DISTINCT antenne)=1 THEN min(antenne) ELSE NULL END antenne
 FROM candidats_antennes GROUP BY zone
), bureaux AS (
 SELECT z.id zone,count(DISTINCT n3."ID_Niveau_3")::integer nombre FROM liens_confirmes l
 JOIN zones z ON z.id=l."ID_CibleNiveau_3Fk"
 JOIN geolocalisation."T_Niveau_3" n3 ON n3."ID_Niveau_3"=l."ID_OrigineNiveau_3Fk"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=n3."ID_TypeNiveau_2_Fk" AND g."AbrGenerique"='BCZS'
 WHERE l."NatureLien"='bureau_de_zone' GROUP BY z.id
), lignes AS (
 SELECT 'as:'||a.id::text cle,a.id aire,a.nom nom_aire,a.uid uid_aire,a.parent parent_aire,
 coalesce(z.province,a.province) province,z.id zone,z.nom nom_zone,z.uid uid_zone,
 coalesce(az.nombre,0) nombre_zones,false sans_aire
 FROM aires a LEFT JOIN affectations_aires az ON az.aire=a.id LEFT JOIN zones z ON z.id=az.zone
 UNION ALL
 SELECT 'zs:'||z.id::text,NULL::integer,NULL::text,NULL::text,NULL::integer,z.province,z.id,z.nom,z.uid,1,true
 FROM zones z WHERE NOT EXISTS(SELECT FROM affectations_aires az WHERE az.zone=z.id AND az.nombre=1)
)
SELECT l.cle AS "ClePyramide",p."ID_Niveau_1",p."NomNiveau_1" AS "NomProvince",p."uidSNIS" AS "UidProvinceSNIS",
 n2."ID_Niveau_2" AS "ID_AntennePEV",n2."NomNiveau_2" AS "NomAntennePEV",
 coalesce(an.nombre,0) AS "NbAntennesCandidates",CASE WHEN an.nombre>1 THEN an.nombre ELSE 0 END AS "NbConflitsAntenne",
 l.zone AS "ID_ZoneSante",l.nom_zone AS "NomZoneSante",l.uid_zone AS "UidZoneSNIS",
 l.aire AS "ID_AireSante",l.nom_aire AS "NomAireSante",l.uid_aire AS "UidAireSNIS",
 l.parent_aire AS "ID_ParentPhysiqueAire",l.nombre_zones AS "NbZonesCandidates",
 CASE WHEN l.nombre_zones>1 THEN l.nombre_zones ELSE 0 END AS "NbConflitsZone",
 coalesce(b.nombre,0) AS "NbBureauxZone",l.sans_aire AS "ZoneSansAireRapprochee",l.zone IS NULL AS "AireSansZoneRapprochee"
FROM lignes l LEFT JOIN geolocalisation."T_Niveau_1" p ON p."ID_Niveau_1"=l.province
 LEFT JOIN affectations_antennes an ON an.zone=l.zone LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=an.antenne
 LEFT JOIN bureaux b ON b.zone=l.zone;
REVOKE ALL ON geolocalisation."V_PyramideSanitaireRapprochee" FROM PUBLIC;
COMMENT ON VIEW geolocalisation."V_PyramideSanitaireRapprochee" IS 'Lecture privée de la pyramide sanitaire rapprochée, une ligne par AS N4 plus une ligne par ZS sans AS rapprochée. ZS canonique distincte de son BCZS ; antenne via lien confirmé ou parent PEV réel, AS via lien confirmé ou parent ZS réel. Les parents historiques restent inchangés et les copies N5 ne gonflent pas les effectifs. Les cibles multiples restent NULL et sont signalées ; les UID viennent des champs territoriaux, sans copie d’UID de bureau vers zone. Pas de géométrie, contact ou droit public ajouté.';
DO $$ DECLARE r record; label text; BEGIN
 FOR r IN SELECT a.attname FROM pg_attribute a WHERE a.attrelid='geolocalisation."V_PyramideSanitaireRapprochee"'::regclass AND a.attnum>0 AND NOT a.attisdropped LOOP
  label:=CASE r.attname
   WHEN 'ClePyramide' THEN 'Identité stable de ligne as:ID ou zs:ID ; niveaux distincts, aucune clé partagée par égalité numérique.'
   WHEN 'ID_Niveau_1' THEN 'Province réelle de la zone rapprochée ou, si la zone manque, province du parent physique de l’aire.'
   WHEN 'NomProvince' THEN 'Nom courant de la province, sans correction silencieuse des homonymies.'
   WHEN 'UidProvinceSNIS' THEN 'UID SNIS effectivement enregistré sur la province ; NULL si non validé.'
   WHEN 'ID_AntennePEV' THEN 'Unique antenne candidate prouvée ; NULL si aucune ou plusieurs cibles distinctes.'
   WHEN 'NomAntennePEV' THEN 'Nom de l’unique antenne PEV prouvée ; aucun choix arbitraire parmi plusieurs antennes.'
   WHEN 'NbAntennesCandidates' THEN 'Nombre de cibles antennes distinctes, versions de sources identiques dédupliquées.'
   WHEN 'NbConflitsAntenne' THEN 'Zéro pour zéro ou une antenne, sinon nombre de cibles distinctes concurrentes ; l’antenne reste NULL.'
   WHEN 'ID_ZoneSante' THEN 'Identifiant N3 de la ZS canonique, jamais celui de son bureau BCZS par déduction.'
   WHEN 'NomZoneSante' THEN 'Nom courant de la zone de santé canonique prouvée.'
   WHEN 'UidZoneSNIS' THEN 'UID SNIS de la ZS réellement enregistré ; ne reprend pas l’identité d’un BCZS distinct.'
   WHEN 'ID_AireSante' THEN 'Identifiant N4 de l’aire de santé, sans duplication par ses objets GRID3 ou sa copie historique N5.'
   WHEN 'NomAireSante' THEN 'Nom courant de l’aire N4 ; NULL sur la ligne d’une zone sans aire rapprochée.'
   WHEN 'UidAireSNIS' THEN 'UID SNIS de l’aire effectivement enregistré ; NULL lorsque la correspondance reste non validée.'
   WHEN 'ID_ParentPhysiqueAire' THEN 'Parent N3 conservé sur l’aire ; peut être un BCZS historique distinct de la ZS canonique.'
   WHEN 'NbZonesCandidates' THEN 'Nombre de zones sanitaires candidates distinctes pour une aire ; vaut un sur la ligne ZS sans aire.'
   WHEN 'NbConflitsZone' THEN 'Zéro pour zéro ou une zone, sinon nombre de cibles distinctes concurrentes ; la zone canonique reste NULL.'
   WHEN 'NbBureauxZone' THEN 'Nombre de bureaux BCZS distincts explicitement liés à la ZS ; ne multiplie pas les lignes des aires.'
   WHEN 'ZoneSansAireRapprochee' THEN 'Ligne de ZS sans aire reliée de manière univoque ; ne prouve pas une absence réelle d’aires.'
   WHEN 'AireSansZoneRapprochee' THEN 'Aire dont la zone canonique est absente ou ambiguë ; son parent physique et son identité restent conservés.'
  END;
  EXECUTE format('COMMENT ON COLUMN geolocalisation."V_PyramideSanitaireRapprochee".%I IS %L',r.attname,label);
 END LOOP;
END $$;
COMMIT;
