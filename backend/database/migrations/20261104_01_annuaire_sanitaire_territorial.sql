-- Annuaire sanitaire issu des territoires N3/N4/N5, distinct des entreprises ERP.
-- Aucune identité territoriale, coordonnée, visibilité historique ou FK n'est réécrite.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 IF to_regclass('geolocalisation."T_CoordonneesTerritoire"') IS NULL
    OR to_regprocedure('referentiel.fn_categories_champ(text,text,text,integer)') IS NULL THEN
  RAISE EXCEPTION 'Coordonnées territoriales et référencement physique commun requis.';
 END IF;
END $$;

-- Types pharmaceutiques du vrai référentiel territorial N5 uniquement.
-- Les 55 types et leurs visibilités existants ne sont jamais reclassés.
DO $$ DECLARE families integer[]; family_id integer; label text; matches integer; BEGIN
 families:=referentiel.fn_categories_champ('geolocalisation','T_Niveau_5','ID_TypeNiveau_5_Fk',NULL);
 IF coalesce(cardinality(families),0)<>1 THEN
  RAISE EXCEPTION 'Une seule famille territoriale N5 requise.';
 END IF;
 family_id:=families[1];
 PERFORM FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=family_id
  AND "IdEntiteFk" IS NULL AND "ValideCategorieGenerique" IS TRUE FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Famille territoriale N5 commune et active requise.';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('referentiel:valeurs:'||family_id::text,0));
 FOREACH label IN ARRAY ARRAY['Pharmacie','Dépôt pharmaceutique'] LOOP
  SELECT count(*) INTO matches FROM referentiel."T_Generique" g WHERE g."ID_CategorieGeneriqueFk"=family_id
   AND g."IdEntiteFk" IS NULL AND referentiel.fn_normaliser_libelle(g."NomGenerique")=referentiel.fn_normaliser_libelle(label);
  IF matches>1 THEN RAISE EXCEPTION 'Type pharmaceutique territorial commun ambigu : %',label;
  ELSIF matches=0 THEN
   INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique",
    "ValideGenerique","IdEntiteFk","VisibleNiveau_5") VALUES(family_id,label,label,true,NULL,true);
  END IF;
 END LOOP;
END $$;

ALTER TABLE geolocalisation."T_CoordonneesTerritoire"
 ADD COLUMN IF NOT EXISTS "PublierCoordonneesAnnuaire" boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS "HorairesOuvertureTerritoire" text;
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_constraint WHERE conrelid='geolocalisation."T_CoordonneesTerritoire"'::regclass
   AND conname='ck_coordonnees_territoire_horaires') THEN
  ALTER TABLE geolocalisation."T_CoordonneesTerritoire" ADD CONSTRAINT ck_coordonnees_territoire_horaires
   CHECK ("HorairesOuvertureTerritoire" IS NULL OR (char_length("HorairesOuvertureTerritoire") BETWEEN 1 AND 1000
    AND "HorairesOuvertureTerritoire"=btrim("HorairesOuvertureTerritoire")
    AND replace(replace("HorairesOuvertureTerritoire",E'\r',''),E'\n','') !~ '[[:cntrl:]]'));
 END IF;
END $$;
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."PublierCoordonneesAnnuaire" IS 'Autorisation explicite de divulguer les coordonnées institutionnelles et horaires dans l’annuaire sanitaire authentifié. False par défaut, y compris pour les fiches antérieures ; le retrait masque immédiatement les contacts sans supprimer le territoire ou sa fiche privée. Ne publie aucune entreprise ERP.';
COMMENT ON COLUMN geolocalisation."T_CoordonneesTerritoire"."HorairesOuvertureTerritoire" IS 'Horaires d’ouverture déclarés en texte simple facultatif, de 1 à 1 000 caractères après retrait des espaces extérieurs ; retours à la ligne admis. NULL signifie inconnus. Ne constitue pas un calcul « ouvert maintenant », une garde ou une vérification de permanence.';
COMMENT ON TABLE geolocalisation."T_CoordonneesTerritoire" IS 'Fiche institutionnelle partagée facultative d’un territoire N1 à N5, une seule FK explicite et immuable par fiche, sans entreprise propriétaire. Adresse, contacts, accueil et horaires déclarés sont conservés dans l’administration territoriale. Le consentement explicite PublierCoordonneesAnnuaire contrôle leur divulgation dans la projection sanitaire N3/N4/N5 ; aucune coordonnée de parent ou de personne n’est déduite. Auteur et date techniques ne constituent pas une vérification métier.';
COMMENT ON CONSTRAINT ck_coordonnees_territoire_horaires ON geolocalisation."T_CoordonneesTerritoire" IS 'Horaires déclarés facultatifs bornés à 1 000 caractères, sans contrôles autres que les retours à la ligne et sans espaces extérieurs.';
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT c.conname,n.nspname,t.relname FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
  JOIN pg_namespace n ON n.oid=t.relnamespace WHERE c.contype='n' AND
   (c.conrelid='geolocalisation."T_CoordonneesTerritoire"'::regclass AND c.conkey=ARRAY[
     (SELECT attnum FROM pg_attribute WHERE attrelid=c.conrelid AND attname='PublierCoordonneesAnnuaire')]::smallint[])
 LOOP EXECUTE format('COMMENT ON CONSTRAINT %I ON %I.%I IS %L',r.conname,r.nspname,r.relname,
  'Choix explicite obligatoire, false par défaut : NULL ne vaut jamais autorisation.');END LOOP;
END $$;

-- Les lectures privées existantes conservent leur grain et toutes leurs colonnes.
DO $$ DECLARE level integer; view_name text; definition text; suffix text[]; existing integer; BEGIN
 FOR level IN 1..5 LOOP
  view_name:='V_Niveau_'||level;
  SELECT count(*) INTO existing FROM pg_attribute WHERE attrelid=to_regclass(format('geolocalisation.%I',view_name))
   AND attnum>0 AND NOT attisdropped AND attname=ANY(ARRAY['PublierCoordonneesAnnuaire','HorairesOuvertureTerritoire']);
  IF existing=0 THEN
   SELECT rtrim(pg_get_viewdef(to_regclass(format('geolocalisation.%I',view_name)),true),E';\n ') INTO definition;
   IF definition IS NULL THEN RAISE EXCEPTION 'Vue territoriale requise : %',view_name;END IF;
   EXECUTE format('CREATE OR REPLACE VIEW geolocalisation.%I AS SELECT q.*,coalesce(c."PublierCoordonneesAnnuaire",false) AS "PublierCoordonneesAnnuaire",c."HorairesOuvertureTerritoire" FROM (%s) q LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON c.%I=q.%I',
    view_name,definition,'ID_Niveau_'||level||'Fk','ID_Niveau_'||level);
  ELSIF existing=2 THEN
   SELECT array_agg(attname ORDER BY attnum) INTO suffix FROM (SELECT attname,attnum FROM pg_attribute
    WHERE attrelid=to_regclass(format('geolocalisation.%I',view_name)) AND attnum>0 AND NOT attisdropped
    ORDER BY attnum DESC LIMIT 2) a;
   IF suffix IS DISTINCT FROM ARRAY['PublierCoordonneesAnnuaire','HorairesOuvertureTerritoire'] THEN
    RAISE EXCEPTION 'Suffixe sanitaire territorial incompatible : %',view_name;END IF;
  ELSE RAISE EXCEPTION 'Extension sanitaire territoriale partiellement installée : %',view_name;END IF;
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."PublierCoordonneesAnnuaire" IS %L',view_name,
   'Choix explicite de publication des coordonnées dans l’annuaire sanitaire ; false en l’absence de fiche. Lecture territoriale privée : ce champ ne masque pas les contacts dans ce registre administrateur.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."HorairesOuvertureTerritoire" IS %L',view_name,
   'Horaires d’ouverture déclarés, facultatifs, conservés dans la fiche territoriale associée. Aucun héritage depuis les parents, aucun calcul d’ouverture actuelle.');
 END LOOP;
END $$;

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
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."ID_TypeNiveau_5_Fk"
  AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_5','ID_TypeNiveau_5_Fk',NULL))
 JOIN referentiel."T_CategorieGenerique" cat ON cat."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  AND cat."ValideCategorieGenerique" IS TRUE AND cat."IdEntiteFk" IS NULL
 LEFT JOIN geolocalisation."T_CoordonneesTerritoire" c ON c."ID_Niveau_5Fk"=v."ID_Niveau_5" AND c."PublierCoordonneesAnnuaire" IS TRUE;
COMMENT ON VIEW geolocalisation."V_StructureSanitairePublique" IS 'Annuaire des structures et territoires fermé au grain niveau 3/4/5 + identifiant territorial, distinct des entreprises ERP. Tous les types territoriaux communs actifs de la famille physique actuellement résolue sont admis, y compris districts, secteurs et groupements ; aucune sélection médicale implicite ni filtre sur VisibleNiveau pour masquer les affectations historiques. Les contacts et horaires déclarés sont NULL sans publication explicite de la fiche associée. Exclut GPS, comptes, observations, populations, géométries, déploiement, auteurs, logos, offres et affiliations. Les API imposent session et module Structures ; aucune permission anonyme ou messagerie n’est accordée. Ne prouve ni agrément, disponibilité ou permanence.';
DO $$ DECLARE item record; BEGIN
 FOR item IN SELECT * FROM (VALUES
  ('StructureKey','Clé stable composite n3:<id>, n4:<id> ou n5:<id>. Ne désigne jamais une entreprise ERP ou un destinataire de discussion.'),
  ('NiveauStructure','Niveau territorial source : 3, 4 ou 5 ; composant obligatoire de l’identité.'),
  ('ID_Structure','Identifiant physique du territoire dans son niveau source ; seul, il n’est pas unique entre niveaux.'),
  ('NomStructure','Nom territorial enregistré, éventuellement absent ; aucune dénomination d’entreprise n’est déduite.'),
  ('CodeStructure','Code territorial facultatif déclaré, sans unicité mondiale supposée.'),
  ('ID_TypeStructureFk','Identifiant T_Generique du vrai champ de type du territoire, actif, commun et appartenant à la famille physique actuellement résolue. Aucun classement médical supplémentaire.'),
  ('TypeStructure','AbrGenerique du type central ; si absente, libellé neutre identifié. NomGenerique ne remplace jamais l’abréviation.'),
  ('ID_Niveau_1','Identifiant de province issu de la hiérarchie territoriale commune, éventuellement absent.'),
  ('NomNiveau_1','Nom de province issu de la vue territoriale commune, sans déduction de visibilité ou publication.'),
  ('ID_Niveau_2','Identifiant de subdivision ou antenne réellement rattachée, éventuellement absent.'),
  ('NomNiveau_2','Nom de subdivision ou antenne issu de la hiérarchie commune.'),
  ('ID_Niveau_3','Identifiant du niveau 3 : propre territoire N3 ou zone effective de la vue N4/N5 ; N5 conserve COALESCE(zone directe, zone de l’aire).'),
  ('NomNiveau_3','Nom du niveau 3 issu de la même hiérarchie que son identifiant.'),
  ('ID_Niveau_4','Identifiant propre du territoire N4 ou de l’aire réellement liée au N5 ; NULL pour une entrée N3.'),
  ('NomNiveau_4','Nom du niveau 4 réellement lié, NULL pour une entrée N3 ou sans aire.'),
  ('AdresseTerritoire','Adresse institutionnelle déclarée pour cette seule entrée ; NULL sans consentement explicite, sans héritage de parent.'),
  ('TelephoneTerritoire','Téléphone institutionnel principal déclaré et explicitement publié ; NULL sinon.'),
  ('TelephoneSecondaireTerritoire','Téléphone institutionnel secondaire déclaré et explicitement publié ; NULL sinon.'),
  ('EmailTerritoire','Adresse e-mail institutionnelle déclarée et explicitement publiée ; NULL sinon.'),
  ('SiteWebTerritoire','Site web institutionnel déclaré et explicitement publié ; NULL sinon, sans agrément implicite.'),
  ('InformationsAccueilTerritoire','Informations d’accueil en texte simple explicitement publiées ; NULL sinon, sans permanence déduite.'),
  ('HorairesOuvertureTerritoire','Horaires déclarés en texte simple explicitement publiés ; NULL si absents ou non publiés, aucun calcul d’ouverture actuelle.'),
  ('CoordonneesPubliees','True seulement lorsqu’une fiche de coordonnées du territoire porte le consentement explicite. Ne garantit ni complétude ni vérification métier.')) AS comments(name,description)
 LOOP EXECUTE format('COMMENT ON COLUMN geolocalisation."V_StructureSanitairePublique".%I IS %L',item.name,item.description);END LOOP;
END $$;

-- Catalogue privé : champs disponibles mais facultatifs, sans réécrire de préférence.
DO $$ DECLARE key text; current_columns jsonb; additions jsonb; item record; ordinal integer; BEGIN
 FOREACH key IN ARRAY ARRAY['territoires.niveaux-un','territoires.niveaux-deux','territoires.niveaux-trois',
  'territoires.niveaux-quatre','territoires.niveaux-cinq'] LOOP
  SELECT "Colonnes" INTO current_columns FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Catalogue territorial requis : %',key;END IF;
  SELECT ceil(coalesce(max((value->>'defaultOrder')::numeric),-1))::integer+1 INTO ordinal FROM jsonb_array_elements(current_columns);
  additions:='[]'::jsonb;
  FOR item IN SELECT * FROM (VALUES ('PublierCoordonneesAnnuaire','Coordonnées publiées dans l’annuaire','boolean'),
   ('HorairesOuvertureTerritoire','Horaires d’ouverture déclarés','text')) AS fields(id,label,kind) LOOP
   IF NOT EXISTS(SELECT FROM jsonb_array_elements(current_columns) c WHERE c->>'id'=item.id) THEN
    additions:=additions||jsonb_build_array(jsonb_build_object('id',item.id,'label',item.label,'type',item.kind,
     'exportable',true,'tableAvailable',true,'defaultVisible',false,'defaultExport',false,
     'defaultOrder',ordinal,'defaultExportOrder',ordinal+100));ordinal:=ordinal+1;
   END IF;
  END LOOP;
  IF jsonb_array_length(additions)>0 THEN
   UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=current_columns||additions WHERE "CleInterface"=key;
  END IF;
 END LOOP;
END $$;
COMMIT;
