-- Coordonnées professionnelles des territoires : source partagée, sans entreprise déduite.
-- La table est initialement vide ; aucune coordonnée ou qualification n'est inventée.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 IF to_regprocedure('systeme.fn_admin_actor_user_id()') IS NULL THEN
  RAISE EXCEPTION 'Le contexte transactionnel d’acteur Administration est requis.';
 END IF;
END $$;

CREATE TABLE IF NOT EXISTS geolocalisation."T_CoordonneesTerritoire" (
 "ID_CoordonneesTerritoire" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_Niveau_1Fk" integer REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1"),
 "ID_Niveau_2Fk" integer REFERENCES geolocalisation."T_Niveau_2"("ID_Niveau_2"),
 "ID_Niveau_3Fk" integer REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3"),
 "ID_Niveau_4Fk" integer REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4"),
 "ID_Niveau_5Fk" integer REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5"),
 "AdresseTerritoire" text,
 "TelephoneTerritoire" varchar(50),
 "TelephoneSecondaireTerritoire" varchar(50),
 "EmailTerritoire" varchar(255),
 "SiteWebTerritoire" varchar(255),
 "InformationsAccueilTerritoire" text,
 "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "ModifieParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser"),
 CONSTRAINT ck_coordonnees_territoire_parent_unique CHECK
  (num_nonnulls("ID_Niveau_1Fk","ID_Niveau_2Fk","ID_Niveau_3Fk","ID_Niveau_4Fk","ID_Niveau_5Fk")=1),
 CONSTRAINT ck_coordonnees_territoire_adresse CHECK
  ("AdresseTerritoire" IS NULL OR (char_length("AdresseTerritoire") BETWEEN 1 AND 2000
   AND "AdresseTerritoire"=btrim("AdresseTerritoire")
   AND replace(replace("AdresseTerritoire",E'\r',''),E'\n','') !~ '[[:cntrl:]]')),
 CONSTRAINT ck_coordonnees_territoire_accueil CHECK
  ("InformationsAccueilTerritoire" IS NULL OR (char_length("InformationsAccueilTerritoire") BETWEEN 1 AND 3000
   AND "InformationsAccueilTerritoire"=btrim("InformationsAccueilTerritoire")
   AND replace(replace("InformationsAccueilTerritoire",E'\r',''),E'\n','') !~ '[[:cntrl:]]')),
 CONSTRAINT ck_coordonnees_territoire_telephone CHECK
  ("TelephoneTerritoire" IS NULL OR (char_length("TelephoneTerritoire") BETWEEN 1 AND 50
   AND "TelephoneTerritoire"=btrim("TelephoneTerritoire") AND "TelephoneTerritoire" !~ '[[:cntrl:]]')),
 CONSTRAINT ck_coordonnees_territoire_telephone_secondaire CHECK
  ("TelephoneSecondaireTerritoire" IS NULL OR (char_length("TelephoneSecondaireTerritoire") BETWEEN 1 AND 50
   AND "TelephoneSecondaireTerritoire"=btrim("TelephoneSecondaireTerritoire") AND "TelephoneSecondaireTerritoire" !~ '[[:cntrl:]]')),
 CONSTRAINT ck_coordonnees_territoire_email CHECK
  ("EmailTerritoire" IS NULL OR (char_length("EmailTerritoire") BETWEEN 1 AND 255
   AND "EmailTerritoire"=btrim("EmailTerritoire") AND "EmailTerritoire" !~ '[[:space:][:cntrl:]]')),
 CONSTRAINT ck_coordonnees_territoire_site_web CHECK
  ("SiteWebTerritoire" IS NULL OR (char_length("SiteWebTerritoire") BETWEEN 1 AND 255
   AND "SiteWebTerritoire"=btrim("SiteWebTerritoire") AND "SiteWebTerritoire" !~ '[[:space:][:cntrl:]]'))
);
COMMENT ON TABLE geolocalisation."T_CoordonneesTerritoire" IS 'Coordonnées professionnelles facultatives d’un territoire partagé de niveau 1 à 5, une seule fiche par territoire. Rattachement explicite et immuable, sans entreprise propriétaire ou affiliation inventée. Les coordonnées de personnes, GPS, horaires déduits et contacts importés sans provenance n’y sont pas ajoutés. L’accès reste contrôlé par les services territoriaux.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ID_CoordonneesTerritoire" IS 'Identifiant technique unique de la fiche de coordonnées territoriales, généré en base.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."AdresseTerritoire" IS 'Adresse professionnelle déclarée, facultative, 2 000 caractères au maximum ; les retours à la ligne sont admis. Aucune localisation n’est calculée.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."TelephoneTerritoire" IS 'Téléphone professionnel principal déclaré pour ce territoire, facultatif, 50 caractères au maximum ; aucune qualification automatique.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."TelephoneSecondaireTerritoire" IS 'Téléphone professionnel secondaire facultatif déclaré, 50 caractères au maximum, distinct des comptes utilisateurs.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."EmailTerritoire" IS 'Adresse e-mail professionnelle déclarée, facultative, 255 caractères au maximum sans espaces ni contrôles. Le format est validé par le service avant enregistrement.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."SiteWebTerritoire" IS 'URL professionnelle déclarée, facultative, 255 caractères au maximum sans espaces ni contrôles. Le service limite les liens aux schémas web autorisés.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."InformationsAccueilTerritoire" IS 'Informations d’accueil déclarées en texte simple, facultatives, 3 000 caractères au maximum. Ne constitue pas une vérification d’horaires, d’agrément ou de permanence.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ModifieLe" IS 'Instant technique réel de la dernière écriture, imposé par le trigger ; ne prouve pas une vérification métier des coordonnées.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."ModifieParUserFk" IS 'Acteur actif du contexte systeme.actor_user_id, imposé par le trigger ; NULL lorsqu’aucun acteur valide n’est disponible. Ne constitue pas une autorisation.';

CREATE OR REPLACE FUNCTION geolocalisation.tr_coordonnees_territoire_integrite()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE parent_data jsonb; level integer; parent_id integer;
BEGIN
 IF TG_OP='UPDATE' AND ROW(NEW."ID_CoordonneesTerritoire",NEW."ID_Niveau_1Fk",NEW."ID_Niveau_2Fk",
   NEW."ID_Niveau_3Fk",NEW."ID_Niveau_4Fk",NEW."ID_Niveau_5Fk") IS DISTINCT FROM
   ROW(OLD."ID_CoordonneesTerritoire",OLD."ID_Niveau_1Fk",OLD."ID_Niveau_2Fk",OLD."ID_Niveau_3Fk",
   OLD."ID_Niveau_4Fk",OLD."ID_Niveau_5Fk") THEN
  RAISE EXCEPTION 'Le territoire d’une fiche de coordonnées enregistrée est conservé.'
   USING ERRCODE='23514',CONSTRAINT='ck_coordonnees_territoire_parent_immuable';
 END IF;
 -- Même verrou commun que l’édition territoriale dédiée. Une écriture SQL
 -- directe ne peut se glisser entre sa vérification de révision et l’upsert.
 -- Un ordre inverse externe peut produire un deadlock : PostgreSQL annule alors
 -- une transaction, sans écrasement silencieux de la dernière modification.
 parent_data:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 FOR level IN 1..5 LOOP
  parent_id:=(parent_data->>('ID_Niveau_'||level||'Fk'))::integer;
  IF parent_id IS NOT NULL THEN
   EXECUTE format('SELECT 1 FROM geolocalisation.%I WHERE %I=$1 FOR UPDATE',
    'T_Niveau_'||level,'ID_Niveau_'||level) USING parent_id;
  END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 NEW."ModifieLe":=clock_timestamp();
 NEW."ModifieParUserFk":=systeme.fn_admin_actor_user_id();
 RETURN NEW;
END $$;
COMMENT ON FUNCTION geolocalisation.tr_coordonnees_territoire_integrite() IS 'Verrouille le territoire parent pour chaque insertion, modification ou suppression, comme le service versionné. Préserve l’identité et le rattachement de la fiche ; impose horodatage et acteur transactionnel actif. Un ordre externe inverse peut provoquer un deadlock annulé par PostgreSQL, jamais une perte silencieuse. Le contexte d’audit ne constitue pas une permission.';
DROP TRIGGER IF EXISTS coordonnees_territoire_integrite ON geolocalisation."T_CoordonneesTerritoire";
CREATE TRIGGER coordonnees_territoire_integrite BEFORE INSERT OR UPDATE OR DELETE
 ON geolocalisation."T_CoordonneesTerritoire" FOR EACH ROW
 EXECUTE FUNCTION geolocalisation.tr_coordonnees_territoire_integrite();
COMMENT ON TRIGGER coordonnees_territoire_integrite ON geolocalisation."T_CoordonneesTerritoire" IS 'Verrouille le territoire parent pour toutes les écritures, contrôle les métadonnées et interdit de réaffecter une fiche existante à un autre territoire.';

DO $$ DECLARE level integer; field text; idx text; r record; BEGIN
 FOR level IN 1..5 LOOP
  field:='ID_Niveau_'||level||'Fk';idx:='uq_coordonnees_territoire_niveau_'||level;
  EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS %I ON geolocalisation."T_CoordonneesTerritoire" (%I) WHERE %I IS NOT NULL',idx,field,field);
  EXECUTE format('COMMENT ON INDEX geolocalisation.%I IS %L',idx,'Une seule fiche de coordonnées par territoire de niveau '||level||' ; aucune multiplication de lignes dans sa vue.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire".%I IS %L',field,'Rattachement explicite au territoire existant de niveau '||level||'. Une seule des cinq FK est renseignée ; ce rattachement est immuable.');
 END LOOP;
 FOR r IN SELECT conname,contype FROM pg_constraint WHERE conrelid='geolocalisation."T_CoordonneesTerritoire"'::regclass LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON geolocalisation."T_CoordonneesTerritoire" IS %L',r.conname,
   CASE r.contype WHEN 'f' THEN 'Relation réelle imposée : aucun territoire ou acteur orphelin ; suppression du parent refusée tant que cette fiche le référence.'
    WHEN 'p' THEN 'Identifiant unique de la fiche de coordonnées territoriales.'
    WHEN 'n' THEN 'Valeur technique obligatoire, produite et contrôlée en PostgreSQL.'
    ELSE 'Contrôle du rattachement exclusif ou de la longueur et du contenu déclaré ; absence représentée par NULL. Définition : '||(SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid='geolocalisation."T_CoordonneesTerritoire"'::regclass AND conname=r.conname)
   END);
 END LOOP;
 EXECUTE format('COMMENT ON SEQUENCE %s IS %L',pg_get_serial_sequence('geolocalisation."T_CoordonneesTerritoire"','ID_CoordonneesTerritoire'),'Génération de l’identifiant des coordonnées territoriales ; les écarts de numérotation ne prouvent pas une suppression.');
END $$;

-- Conserver toutes les colonnes et tous les calculs antérieurs, dans leur ordre.
-- Le LEFT JOIN unique ajoute la fiche facultative sans masquer les territoires.
DO $$ DECLARE level integer; view_name text; old_definition text; existing integer;
 fields text[]:=ARRAY['AdresseTerritoire','TelephoneTerritoire','TelephoneSecondaireTerritoire',
  'EmailTerritoire','SiteWebTerritoire','InformationsAccueilTerritoire','CoordonneesModifieLe'];
 actual_suffix text[]; BEGIN
 FOR level IN 1..5 LOOP
  view_name:='V_Niveau_'||level;
  IF to_regclass(format('geolocalisation.%I',view_name)) IS NULL THEN RAISE EXCEPTION 'Vue territoriale requise : %',view_name;END IF;
  SELECT count(*) INTO existing FROM pg_attribute
   WHERE attrelid=to_regclass(format('geolocalisation.%I',view_name)) AND attnum>0 AND NOT attisdropped AND attname=ANY(fields);
  IF existing=0 THEN
   SELECT rtrim(pg_get_viewdef(to_regclass(format('geolocalisation.%I',view_name)),true),E';\n ') INTO old_definition;
   EXECUTE format('CREATE OR REPLACE VIEW geolocalisation.%I AS SELECT q.*,c."AdresseTerritoire",c."TelephoneTerritoire",c."TelephoneSecondaireTerritoire",c."EmailTerritoire",c."SiteWebTerritoire",c."InformationsAccueilTerritoire",c."ModifieLe" AS "CoordonneesModifieLe" FROM (%s) q LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON c.%I=q.%I',view_name,old_definition,'ID_Niveau_'||level||'Fk','ID_Niveau_'||level);
  ELSIF existing=7 THEN
   -- Les évolutions suivantes peuvent ajouter leurs propres colonnes après
   -- celles-ci ; vérifier leur ordre sans exiger qu'elles terminent la vue.
   SELECT array_agg(attname ORDER BY attnum) INTO actual_suffix FROM
    (SELECT attname,attnum FROM pg_attribute WHERE attrelid=to_regclass(format('geolocalisation.%I',view_name))
      AND attnum>0 AND NOT attisdropped AND attname=ANY(fields)) a;
   IF actual_suffix IS DISTINCT FROM fields THEN RAISE EXCEPTION 'Contrat des colonnes de coordonnées différent : %',view_name;END IF;
  ELSE RAISE EXCEPTION 'Coordonnées territoriales partiellement installées : %',view_name;
  END IF;
  EXECUTE format('COMMENT ON VIEW geolocalisation.%I IS %L',view_name,'Référentiel territorial partagé du niveau '||level||'. Colonnes, calculs, compteurs et rattachements historiques conservés ; coordonnées professionnelles facultatives ajoutées par une jointure unique. Aucun territoire exclu en l’absence de coordonnées, aucune entreprise ou affiliation déduite. Les liens et informations d’accueil sont déclaratifs.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."AdresseTerritoire" IS %L',view_name,'Adresse professionnelle facultative explicitement déclarée pour ce territoire ; aucune localisation calculée.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."TelephoneTerritoire" IS %L',view_name,'Téléphone professionnel principal déclaré du territoire, distinct des comptes utilisateurs.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."TelephoneSecondaireTerritoire" IS %L',view_name,'Téléphone professionnel secondaire facultatif déclaré pour le territoire.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."EmailTerritoire" IS %L',view_name,'Adresse e-mail professionnelle facultative déclarée du territoire.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."SiteWebTerritoire" IS %L',view_name,'Site web professionnel facultatif déclaré du territoire, sans agrément implicite.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."InformationsAccueilTerritoire" IS %L',view_name,'Informations d’accueil déclarées, affichées en texte simple sans garantie de permanence ou de certification.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."CoordonneesModifieLe" IS %L',view_name,'Dernière écriture technique de la fiche de coordonnées ; NULL en son absence. Ne constitue pas une date de vérification métier.');
 END LOOP;
END $$;

-- Les colonnes restent facultatives dans les tableaux et dans les exports.
-- Enrichir le catalogue commun ne réécrit jamais les préférences personnelles.
DO $$ DECLARE key text; columns_json jsonb; additions jsonb; item record; ordinal integer; BEGIN
 FOREACH key IN ARRAY ARRAY['territoires.niveaux-un','territoires.niveaux-deux','territoires.niveaux-trois',
  'territoires.niveaux-quatre','territoires.niveaux-cinq'] LOOP
  SELECT "Colonnes" INTO columns_json FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Catalogue de tableau territorial requis : %',key;END IF;
  SELECT ceil(coalesce(max((value->>'defaultOrder')::numeric),-1))::integer+1 INTO ordinal FROM jsonb_array_elements(columns_json);
  additions:='[]'::jsonb;
  FOR item IN SELECT * FROM (VALUES
   ('AdresseTerritoire','Adresse professionnelle','text'),
   ('TelephoneTerritoire','Téléphone professionnel','character varying'),
   ('TelephoneSecondaireTerritoire','Téléphone secondaire','character varying'),
   ('EmailTerritoire','Adresse e-mail professionnelle','character varying'),
   ('SiteWebTerritoire','Site web professionnel','character varying'),
   ('InformationsAccueilTerritoire','Informations d’accueil','text'),
   ('CoordonneesModifieLe','Coordonnées modifiées le','timestamp with time zone')) AS fields(id,label,kind) LOOP
   IF NOT EXISTS(SELECT FROM jsonb_array_elements(columns_json) c WHERE c->>'id'=item.id) THEN
    additions:=additions||jsonb_build_array(jsonb_build_object('id',item.id,'label',item.label,'type',item.kind,
     'exportable',true,'tableAvailable',true,'defaultVisible',false,'defaultExport',false,
     'defaultOrder',ordinal,'defaultExportOrder',ordinal+100));
    ordinal:=ordinal+1;
   END IF;
  END LOOP;
  IF jsonb_array_length(additions)>0 THEN
   UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=columns_json||additions WHERE "CleInterface"=key;
  END IF;
 END LOOP;
END $$;
COMMIT;
