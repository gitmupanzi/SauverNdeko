-- Patrimoine de l'entreprise, affectations professionnelles minimales et
-- références partagées. Aucun lien implicite avec les stocks commerciaux.
BEGIN;
SET LOCAL lock_timeout='15s';
SET LOCAL statement_timeout='120s';
DO $preconditions$
BEGIN
 IF current_database()<>'SauverNdeko' AND left(current_database(),17)<>'sauverndeko_test_' THEN RAISE EXCEPTION 'Base cible non autorisée.';END IF;
 IF to_regprocedure('systeme.fn_admin_actor_user_id()') IS NULL OR NOT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='systeme' AND table_name='T_Entite' AND column_name='PhoneSecondaireEntite') THEN RAISE EXCEPTION 'Socle07 requis.';END IF;
 IF to_regclass('logistique."T_Immobilisation"') IS NOT NULL OR EXISTS(SELECT FROM information_schema.columns WHERE table_schema='systeme' AND table_name='T_Utilisateurs' AND column_name='MatriculeUser') THEN RAISE EXCEPTION 'Migration08 déjà installée ou schéma partiel : rejeu interdit.';END IF;
END $preconditions$;

-- Une famille de valeurs, pas une table supplémentaire de nomenclature.
LOCK TABLE referentiel."T_CategorieGenerique",referentiel."T_Generique" IN SHARE ROW EXCLUSIVE MODE;
DO $references$
DECLARE category_id integer;state_id integer;family_count integer;item record;
BEGIN
 SELECT count(*),min("ID_CategorieGenerique") INTO family_count,category_id FROM referentiel."T_CategorieGenerique" WHERE lower(btrim("NomCategorieGenerique"))=lower('Type de matériel');
 IF family_count>1 THEN RAISE EXCEPTION 'Famille Type de matériel ambiguë.';END IF;
 IF category_id IS NULL THEN INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ModuleCategorieGenerique","ValideCategorieGenerique") VALUES('Type de matériel','M_IMMO',true) RETURNING "ID_CategorieGenerique" INTO category_id;END IF;
 IF NOT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=category_id AND "ValideCategorieGenerique") THEN RAISE EXCEPTION 'Famille Type de matériel désactivée.';END IF;
 FOR item IN SELECT * FROM (VALUES('Informatique','INFORMATIQUE'),('Mobilier','MOBILIER'),('Équipement','EQUIPEMENT'),('Véhicule','VEHICULE'),('Autre','AUTRE')) AS seed(label,code) LOOP
  IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=category_id AND lower(btrim("NomGenerique"))=lower(item.label)) THEN
   INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(category_id,item.label,item.code,true);
  END IF;
 END LOOP;
 SELECT count(*),min("ID_CategorieGenerique") INTO family_count,state_id FROM referentiel."T_CategorieGenerique" WHERE lower(btrim("NomCategorieGenerique"))=lower('Etat');
 IF family_count<>1 THEN RAISE EXCEPTION 'Famille Etat absente ou ambiguë.';END IF;
 IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=state_id AND lower(btrim("NomGenerique")) IN ('hors usage','hors d''usage')) THEN
  INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(state_id,'Hors usage','HORS_USAGE',true);
 END IF;
 FOR item IN SELECT * FROM (VALUES('categories','ID_CategorieFk','Type de matériel','Type de matériel'),('etats','ID_EtatFk','État du matériel','Etat'),('services','ID_ServiceFk','Service','Service')) AS seed(source,field,label,family) LOOP
  SELECT count(*),min("ID_CategorieGenerique") INTO family_count,category_id FROM referentiel."T_CategorieGenerique" WHERE lower(btrim("NomCategorieGenerique"))=lower(item.family);
  IF family_count<>1 THEN RAISE EXCEPTION 'Famille % absente ou ambiguë.',item.family;END IF;
  INSERT INTO systeme."T_Fk_Correspondance"("ModuleName","SchemaName","ViewName","SourceKey","FieldName","FieldLabel","MappingType","ReferenceSchemaName","ReferenceObjectName","ReferenceFieldName","TargetCategoryIdFk","MappingValue","IsDefaultMapping","ValideFkCorrespondance","SettingScope","ScopeValue","DisplayOrder","ObsFkCorrespondance")
  SELECT 'logistique','logistique','V_Immobilisation','logistique.immobilisations.'||item.source,item.field,item.label,'generic_category','referentiel','T_Generique','ID_Generique',category_id,category_id::text,true,true,'global',NULL,0,'Socle immobilisations08 ; catégorie résolue par son libellé.'
  WHERE NOT EXISTS(SELECT FROM systeme."T_Fk_Correspondance" WHERE "SourceKey"='logistique.immobilisations.'||item.source AND "FieldName"=item.field AND "MappingType"='generic_category' AND "SettingScope"='global' AND "ScopeValue" IS NULL);
 END LOOP;
END $references$;

ALTER TABLE systeme."T_Utilisateurs"
 ADD COLUMN "MatriculeUser" character varying(50),
 ADD COLUMN "ID_ServiceFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 ADD COLUMN "ID_FonctionFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 ADD COLUMN "DateEmbauche" date,
 ADD COLUMN "DateFinEmploi" date,
 ADD COLUMN "ObservationProfessionnelle" text,
 ADD CONSTRAINT ck_user_matricule CHECK("MatriculeUser" IS NULL OR (char_length("MatriculeUser") BETWEEN 1 AND 50 AND "MatriculeUser"=btrim("MatriculeUser") AND "MatriculeUser" !~ '[[:cntrl:]]')),
 ADD CONSTRAINT ck_user_dates_emploi CHECK(("DateEmbauche" IS NULL OR isfinite("DateEmbauche")) AND ("DateFinEmploi" IS NULL OR isfinite("DateFinEmploi")) AND ("DateEmbauche" IS NULL OR "DateFinEmploi" IS NULL OR "DateFinEmploi">="DateEmbauche")),
 ADD CONSTRAINT ck_user_observation_professionnelle CHECK("ObservationProfessionnelle" IS NULL OR (char_length("ObservationProfessionnelle")<=1000 AND replace(replace("ObservationProfessionnelle",E'\r\n',E'\n'),E'\n','') !~ '[[:cntrl:]]'));
CREATE UNIQUE INDEX uq_user_matricule_entite ON systeme."T_Utilisateurs"("IdEntiteFk",lower("MatriculeUser")) NULLS NOT DISTINCT WHERE "MatriculeUser" IS NOT NULL;
COMMENT ON INDEX systeme.uq_user_matricule_entite IS 'Matricule facultatif unique sans distinction de casse dans chaque entreprise ; les valeurs NULL ne représentent pas un matricule.';
COMMENT ON COLUMN systeme."T_Utilisateurs"."MatriculeUser" IS 'Matricule professionnel facultatif, maximum50 caractères, sans espaces extérieurs ; unique sans distinction de casse dans son entreprise.';
COMMENT ON COLUMN systeme."T_Utilisateurs"."ID_ServiceFk" IS 'Service professionnel actuel dans la famille générique Service ; ne déplace pas automatiquement les immobilisations affectées.';
COMMENT ON COLUMN systeme."T_Utilisateurs"."ID_FonctionFk" IS 'Fonction professionnelle actuelle dans la famille générique Fonction, distincte du rôle de sécurité.';
COMMENT ON COLUMN systeme."T_Utilisateurs"."DateEmbauche" IS 'Début professionnel facultatif ; aucune date supposée pour les comptes existants.';
COMMENT ON COLUMN systeme."T_Utilisateurs"."DateFinEmploi" IS 'Fin professionnelle facultative, jamais antérieure au début renseigné ; condition de nouvelle affectation des biens.';
COMMENT ON COLUMN systeme."T_Utilisateurs"."ObservationProfessionnelle" IS 'Note professionnelle facultative, maximum1000 caractères ; séparée des projections publiques et du profil courant.';

CREATE TABLE logistique."T_Immobilisation"(
 "ID_Immobilisation" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "CodeImmobilisation" character varying(32) NOT NULL UNIQUE,
 "NomImmobilisation" character varying(200) NOT NULL,
 "Reference" character varying(255),
 "Caracteristiques" text,
 "SuiviIndividuel" boolean NOT NULL DEFAULT true,
 "Quantite" numeric NOT NULL DEFAULT 1,
 "PrixUnitaire" numeric(18,2),
 "ID_DeviseFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_CategorieFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_EtatFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_ResponsableFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ID_ServiceFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_LocalisationFk" integer REFERENCES systeme."T_Entite_Localisation"("IdEntiteLocalisation") ON DELETE RESTRICT,
 "LocalisationComplement" character varying(255),
 "DateEntree" timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
 "DateAcquisition" date,
 "NumeroSerie" character varying(255),
 "Observations" text,
 "Actif" boolean NOT NULL DEFAULT true,
 "CreeLe" timestamp with time zone NOT NULL,
 "ModifieLe" timestamp with time zone NOT NULL,
 "CreeParUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ModifieParUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 CONSTRAINT ck_immobilisation_nom CHECK(char_length("NomImmobilisation") BETWEEN 1 AND 200 AND "NomImmobilisation"=btrim("NomImmobilisation") AND "NomImmobilisation" !~ '[[:cntrl:]]'),
 CONSTRAINT ck_immobilisation_reference CHECK("Reference" IS NULL OR (char_length("Reference") BETWEEN 1 AND 255 AND "Reference"=btrim("Reference") AND "Reference" !~ '[[:cntrl:]]')),
 CONSTRAINT ck_immobilisation_serie CHECK("NumeroSerie" IS NULL OR (char_length("NumeroSerie") BETWEEN 1 AND 255 AND "NumeroSerie"=btrim("NumeroSerie") AND "NumeroSerie" !~ '[[:cntrl:]]')),
 CONSTRAINT ck_immobilisation_localisation_complement CHECK("LocalisationComplement" IS NULL OR (char_length("LocalisationComplement") BETWEEN 1 AND 255 AND "LocalisationComplement"=btrim("LocalisationComplement") AND "LocalisationComplement" !~ '[[:cntrl:]]')),
 CONSTRAINT ck_immobilisation_caracteristiques CHECK("Caracteristiques" IS NULL OR (char_length("Caracteristiques")<=4000 AND replace(replace("Caracteristiques",E'\r\n',E'\n'),E'\n','') !~ '[[:cntrl:]]')),
 CONSTRAINT ck_immobilisation_observations CHECK("Observations" IS NULL OR (char_length("Observations")<=4000 AND replace(replace("Observations",E'\r\n',E'\n'),E'\n','') !~ '[[:cntrl:]]')),
 CONSTRAINT ck_immobilisation_quantite CHECK("Quantite">0 AND "Quantite"=trunc("Quantite") AND "Quantite"<=999999999999999999),
 CONSTRAINT ck_immobilisation_individuelle CHECK((NOT "SuiviIndividuel" AND "NumeroSerie" IS NULL) OR "Quantite"=1),
 CONSTRAINT ck_immobilisation_prix CHECK("PrixUnitaire" IS NULL OR ("PrixUnitaire">=0 AND "PrixUnitaire"<>'NaN'::numeric AND "ID_DeviseFk" IS NOT NULL)),
 CONSTRAINT ck_immobilisation_dates CHECK(isfinite("DateEntree") AND ("DateAcquisition" IS NULL OR isfinite("DateAcquisition")))
);
COMMENT ON TABLE logistique."T_Immobilisation" IS 'Biens et équipements appartenant durablement à une entreprise, suivis individuellement ou par groupe homogène explicite. Affectations et coût indicatif d’acquisition exacts, sans stock commercial, mouvement, CUMP, amortissement ou écriture comptable implicite. Archivage conservant le registre et son audit.';
COMMENT ON SEQUENCE logistique."T_Immobilisation_ID_Immobilisation_seq" IS 'Identifiant technique des biens ; les trous de séquence sont normaux après annulation transactionnelle, aucun identifiant n’est réutilisé.';
CREATE INDEX ix_immobilisation_entite_actif ON logistique."T_Immobilisation"("IdEntiteFk","Actif","ID_Immobilisation");
CREATE INDEX ix_immobilisation_responsable ON logistique."T_Immobilisation"("ID_ResponsableFk") WHERE "ID_ResponsableFk" IS NOT NULL;
CREATE INDEX ix_immobilisation_localisation ON logistique."T_Immobilisation"("ID_LocalisationFk") WHERE "ID_LocalisationFk" IS NOT NULL;
COMMENT ON INDEX logistique.ix_immobilisation_entite_actif IS 'Registre et pagination stable par entreprise, état d’archivage et identifiant.';
COMMENT ON INDEX logistique.ix_immobilisation_responsable IS 'Affectations conservées par responsable ; contrôle des transferts d’entreprise et consultation de ses biens.';
COMMENT ON INDEX logistique.ix_immobilisation_localisation IS 'Biens liés à une localisation d’entreprise ; protège son propriétaire et facilite la consultation.';

CREATE FUNCTION logistique.fn_reference_immobilisation_valide(p_id integer,p_famille text,p_entite integer) RETURNS boolean
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 WITH matching AS (
  SELECT f."TargetCategoryIdFk" cat,f."SettingScope" FROM systeme."T_Fk_Correspondance" f
  WHERE f."SourceKey"='logistique.immobilisations.'||p_famille AND f."MappingType"='generic_category' AND f."ValideFkCorrespondance"
   AND ((f."SettingScope"='entity' AND f."ScopeValue"=p_entite::text) OR (f."SettingScope"='global' AND f."ScopeValue" IS NULL))
 ), allowed AS (
  SELECT cat FROM matching WHERE "SettingScope"=CASE WHEN EXISTS(SELECT FROM matching WHERE "SettingScope"='entity') THEN 'entity' ELSE 'global' END
  UNION ALL SELECT "ID_CategorieGenerique" FROM referentiel."T_CategorieGenerique"
   WHERE (p_famille='devise' AND lower(btrim("NomCategorieGenerique"))=lower('Devise'))
      OR (p_famille='service-rh' AND lower(btrim("NomCategorieGenerique"))=lower('Service'))
      OR (p_famille='fonction-rh' AND lower(btrim("NomCategorieGenerique"))=lower('Fonction'))
 ) SELECT p_id IS NULL OR EXISTS(SELECT FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  WHERE g."ID_Generique"=p_id AND g."ID_CategorieGeneriqueFk" IN (SELECT cat FROM allowed) AND g."ValideGenerique" AND c."ValideCategorieGenerique")
$$;
COMMENT ON FUNCTION logistique.fn_reference_immobilisation_valide(integer,text,integer) IS 'Valide une nouvelle référence active depuis les correspondances FK d’entreprise prioritaires puis globales, ou les familles RH/Devise existantes résolues par libellé ; aucun identifiant de catégorie figé.';

CREATE VIEW systeme."V_User_Affectation" AS
 SELECT u."IdUser",u."IdEntiteFk",u."NomUser",u."PrenomUser",concat_ws(' ',u."PrenomUser",u."NomUser") AS "NomCompletUser",
  u."MatriculeUser",u."ID_ServiceFk",s."NomGenerique" AS "Service",u."ID_FonctionFk",f."NomGenerique" AS "Fonction",
  u."DateEmbauche",u."DateFinEmploi",u."ObservationProfessionnelle",u."ValideUser",
  u."ValideUser" AND (u."DateEmbauche" IS NULL OR u."DateEmbauche"<=(current_timestamp AT TIME ZONE 'Africa/Kinshasa')::date)
   AND (u."DateFinEmploi" IS NULL OR u."DateFinEmploi">=(current_timestamp AT TIME ZONE 'Africa/Kinshasa')::date) AS "EstAffectable",
  u.xmin::text AS "_version"
 FROM systeme."T_Utilisateurs" u LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique"=u."ID_ServiceFk" LEFT JOIN referentiel."T_Generique" f ON f."ID_Generique"=u."ID_FonctionFk";
COMMENT ON VIEW systeme."V_User_Affectation" IS 'Métadonnées professionnelles privées pour la gestion RH minimale et les affectations ; sans mot de passe, photo, e-mail ni téléphone. Le service doit imposer entreprise et droits. N’élargit pas V_User_profil ni les projections publiques.';

CREATE FUNCTION logistique.tr_immobilisation_verifier() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE actor_id integer:=systeme.fn_admin_actor_user_id();actor_entity integer;actor_global boolean;target_entity integer;assignable boolean;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Archivez le bien pour conserver son historique.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' THEN
  IF ROW(NEW."ID_Immobilisation",NEW."IdEntiteFk",NEW."CodeImmobilisation",NEW."CreeLe",NEW."CreeParUserFk") IS DISTINCT FROM ROW(OLD."ID_Immobilisation",OLD."IdEntiteFk",OLD."CodeImmobilisation",OLD."CreeLe",OLD."CreeParUserFk") THEN RAISE EXCEPTION 'Identité, entreprise, code et origine du bien sont immuables.' USING ERRCODE='23514';END IF;
 ELSE
  IF NEW."CodeImmobilisation" IS NOT NULL THEN RAISE EXCEPTION 'Le code du bien est attribué automatiquement.' USING ERRCODE='23514';END IF;
  NEW."CodeImmobilisation":='IMMO-'||NEW."ID_Immobilisation"::text;
 END IF;
 IF actor_id IS NULL THEN RAISE EXCEPTION 'Auteur actif requis pour enregistrer un bien.' USING ERRCODE='42501';END IF;
 SELECT "IdEntiteFk","Is_Admin" INTO actor_entity,actor_global FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor_id FOR SHARE;
 IF NOT actor_global AND actor_entity IS DISTINCT FROM NEW."IdEntiteFk" THEN RAISE EXCEPTION 'Entreprise du bien hors périmètre de son auteur.' USING ERRCODE='42501';END IF;
 IF TG_OP='INSERT' OR NEW."ID_CategorieFk" IS DISTINCT FROM OLD."ID_CategorieFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_CategorieFk",'categories',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Type de matériel indisponible.' USING ERRCODE='23514';END IF;END IF;
 IF TG_OP='INSERT' OR NEW."ID_EtatFk" IS DISTINCT FROM OLD."ID_EtatFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_EtatFk",'etats',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'État du matériel indisponible.' USING ERRCODE='23514';END IF;END IF;
 IF TG_OP='INSERT' OR NEW."ID_ServiceFk" IS DISTINCT FROM OLD."ID_ServiceFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_ServiceFk",'services',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Service indisponible.' USING ERRCODE='23514';END IF;END IF;
 IF TG_OP='INSERT' OR NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_DeviseFk",'devise',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Devise indisponible.' USING ERRCODE='23514';END IF;END IF;
 IF NEW."ID_ResponsableFk" IS NOT NULL AND (TG_OP='INSERT' OR NEW."ID_ResponsableFk" IS DISTINCT FROM OLD."ID_ResponsableFk") THEN
  SELECT u."IdEntiteFk",u."ValideUser" AND (u."DateEmbauche" IS NULL OR u."DateEmbauche"<=(current_timestamp AT TIME ZONE 'Africa/Kinshasa')::date) AND (u."DateFinEmploi" IS NULL OR u."DateFinEmploi">=(current_timestamp AT TIME ZONE 'Africa/Kinshasa')::date)
   INTO target_entity,assignable FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=NEW."ID_ResponsableFk" FOR SHARE;
  IF NOT FOUND OR target_entity IS DISTINCT FROM NEW."IdEntiteFk" OR assignable IS NOT TRUE THEN RAISE EXCEPTION 'Choisissez un responsable actif de cette entreprise.' USING ERRCODE='23514';END IF;
 END IF;
 IF NEW."ID_LocalisationFk" IS NOT NULL AND (TG_OP='INSERT' OR NEW."ID_LocalisationFk" IS DISTINCT FROM OLD."ID_LocalisationFk") THEN
  PERFORM FROM systeme."T_Entite_Localisation" WHERE "IdEntiteLocalisation"=NEW."ID_LocalisationFk" AND "IdEntiteFk"=NEW."IdEntiteFk" FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Choisissez une localisation de cette entreprise.' USING ERRCODE='23514';END IF;
 END IF;
 IF TG_OP='INSERT' THEN NEW."CreeLe":=clock_timestamp();NEW."CreeParUserFk":=actor_id;END IF;
 NEW."ModifieLe":=clock_timestamp();NEW."ModifieParUserFk":=actor_id;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_immobilisation_verifier() IS 'Impose identité/code/propriétaire immuables, références nouvelles actives, responsable affectable et localisation de la même entreprise, auteur prouvé et horodatages SQL. Conservation par archivage ; aucun effet de stock.';
CREATE TRIGGER a_immobilisation_verifier BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Immobilisation" FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_verifier();
COMMENT ON TRIGGER a_immobilisation_verifier ON logistique."T_Immobilisation" IS 'Contrôle métier du patrimoine avant chaque écriture, y compris par un autre backend ; refus des suppressions physiques.';

CREATE FUNCTION systeme.tr_utilisateur_affectation_verifier() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND EXISTS(SELECT FROM logistique."T_Immobilisation" WHERE "ID_ResponsableFk"=OLD."IdUser") THEN RAISE EXCEPTION 'Un bien reste lié à cet utilisateur ; son entreprise doit être conservée.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' OR NEW."ID_ServiceFk" IS DISTINCT FROM OLD."ID_ServiceFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_ServiceFk",'service-rh',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Service professionnel indisponible.' USING ERRCODE='23514';END IF;END IF;
 IF TG_OP='INSERT' OR NEW."ID_FonctionFk" IS DISTINCT FROM OLD."ID_FonctionFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_FonctionFk",'fonction-rh',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Fonction professionnelle indisponible.' USING ERRCODE='23514';END IF;END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION systeme.tr_utilisateur_affectation_verifier() IS 'Références RH actives à leur affectation ; le changement d’entreprise est refusé lorsqu’un bien, même archivé, reste lié comme responsabilité. Aucune extension du profil public.';
CREATE TRIGGER aa_utilisateur_affectation_verifier BEFORE INSERT OR UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.tr_utilisateur_affectation_verifier();
COMMENT ON TRIGGER aa_utilisateur_affectation_verifier ON systeme."T_Utilisateurs" IS 'Intégrité des nouvelles affectations professionnelles et conservation de l’entreprise des responsables de biens.';

CREATE FUNCTION systeme.tr_localisation_patrimoine_proprietaire() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND EXISTS(SELECT FROM logistique."T_Immobilisation" WHERE "ID_LocalisationFk"=OLD."IdEntiteLocalisation") THEN RAISE EXCEPTION 'Une immobilisation est liée à cette localisation ; son entreprise est conservée.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION systeme.tr_localisation_patrimoine_proprietaire() IS 'Empêche de déplacer une localisation vers une autre entreprise lorsqu’un bien actif ou archivé y reste lié. Ne crée aucun état d’archivage fictif pour les localisations.';
CREATE TRIGGER aa_localisation_patrimoine_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON systeme."T_Entite_Localisation" FOR EACH ROW EXECUTE FUNCTION systeme.tr_localisation_patrimoine_proprietaire();
COMMENT ON TRIGGER aa_localisation_patrimoine_proprietaire ON systeme."T_Entite_Localisation" IS 'Conserve le propriétaire des lieux d’affectation liés au patrimoine.';

CREATE FUNCTION logistique.tr_immobilisation_audit() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE context_text text:=nullif(current_setting('logistique.immobilisation_request',true),'');context_data jsonb;event_operation text;image_before jsonb;image_after jsonb;
BEGIN
 event_operation:=CASE WHEN TG_OP='INSERT' THEN 'CREATE' WHEN OLD."Actif" AND NOT NEW."Actif" THEN 'ARCHIVE' WHEN NOT OLD."Actif" AND NEW."Actif" THEN 'RESTORE' ELSE 'UPDATE' END;
 IF context_text IS NOT NULL THEN
  IF char_length(context_text)>4000 THEN RAISE EXCEPTION 'Contexte de traçabilité invalide.' USING ERRCODE='23514';END IF;
  BEGIN context_data:=context_text::jsonb;EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Contexte de traçabilité invalide.' USING ERRCODE='23514';END;
  IF jsonb_typeof(context_data)<>'object' OR coalesce(context_data->>'requestId','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   OR coalesce(context_data->>'payloadHash','') !~ '^[0-9a-f]{64}$' OR context_data->>'operation' IS DISTINCT FROM event_operation
   OR (context_data ? 'motif' AND (jsonb_typeof(context_data->'motif') IS DISTINCT FROM 'string' OR char_length(context_data->>'motif') NOT BETWEEN 1 AND 1000)) THEN RAISE EXCEPTION 'Preuve de requête invalide.' USING ERRCODE='23514';END IF;
 END IF;
 IF TG_OP='UPDATE' THEN image_before:=systeme.fn_audit_sans_secrets(to_jsonb(OLD));END IF;
 image_after:=systeme.fn_audit_sans_secrets(to_jsonb(NEW))||jsonb_build_object('_actor',jsonb_build_object('IdUser',NEW."ModifieParUserFk"));
 IF context_data IS NOT NULL THEN image_after:=image_after||jsonb_build_object('requestId',context_data->>'requestId','payloadHash',context_data->>'payloadHash','operation',event_operation,'_motif',context_data->>'motif');END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk") VALUES('logistique.T_Immobilisation',event_operation,image_before,image_after,CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa',NEW."IdEntiteFk");
 RETURN NULL;
END $$;
COMMENT ON FUNCTION logistique.tr_immobilisation_audit() IS 'Une image avant/après par écriture de patrimoine avec auteur réel et entreprise. Requête UUID/hash/opération facultative prouvée, sans GUC d’autorisation ni mouvement ; les anciennes affectations restent dans l’historique.';
CREATE TRIGGER zz_immobilisation_audit AFTER INSERT OR UPDATE ON logistique."T_Immobilisation" FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_audit();
COMMENT ON TRIGGER zz_immobilisation_audit ON logistique."T_Immobilisation" IS 'Historique transactionnel unique du bien, comprenant les changements de responsable, service, état et localisation.';
CREATE UNIQUE INDEX uq_audit_immobilisation_request ON systeme."T_Audit_Log"("IdEntiteFk",(("NewData"#>>'{_actor,IdUser}')),(("NewData"->>'requestId'))) WHERE "TableName"='logistique.T_Immobilisation' AND "NewData" ? 'requestId';
COMMENT ON INDEX systeme.uq_audit_immobilisation_request IS 'Une seule preuve UUID d’immobilisation par entreprise et auteur, quelle que soit l’opération ou le contenu ; le service compare hash/opération et sérialise les rejeux avant réponse.';

CREATE VIEW logistique."V_Immobilisation" AS
 SELECT i.*,e."NomEntite",c."NomGenerique" AS "CategorieMateriel",s."NomGenerique" AS "EtatMateriel",service."NomGenerique" AS "Service",
  nullif(concat_ws(' ',u."PrenomUser",u."NomUser"),'') AS "Responsable",d."AbrGenerique" AS "DeviseCode",d."NomGenerique" AS "DeviseLibelle",
  CASE WHEN i."PrixUnitaire" IS NULL THEN NULL ELSE round(i."Quantite"*i."PrixUnitaire",2) END AS "ValeurAcquisition",
  nullif(concat_ws(' · ',nullif(l."AdresseDetaillee",''),nullif(l."NomNiveau_5",''),nullif(l."NomNiveau_4",''),nullif(l."NomNiveau_3",'')),'') AS "Localisation",
  i.xmin::text AS "_version"
 FROM logistique."T_Immobilisation" i LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=i."IdEntiteFk"
 LEFT JOIN referentiel."T_Generique" c ON c."ID_Generique"=i."ID_CategorieFk" LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique"=i."ID_EtatFk"
 LEFT JOIN referentiel."T_Generique" service ON service."ID_Generique"=i."ID_ServiceFk" LEFT JOIN referentiel."T_Generique" d ON d."ID_Generique"=i."ID_DeviseFk"
 LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=i."ID_ResponsableFk" AND u."IdEntiteFk"=i."IdEntiteFk"
 LEFT JOIN systeme."V_Entite_Localisation_Detail" l ON l."IdEntiteLocalisation"=i."ID_LocalisationFk" AND l."IdEntite"=i."IdEntiteFk";
COMMENT ON VIEW logistique."V_Immobilisation" IS 'Registre de patrimoine au grain un bien/groupe homogène, avec LEFT JOIN conservant les références optionnelles et contrôle du propriétaire des lieux/responsables. Valeur d’acquisition indicative exacte, NULL si coût inconnu ; aucun montant comptable amorti ou stock réservé. Filtrage par entreprise imposé au serveur.';

DO $commentaires$
DECLARE item record;description text;
BEGIN
 FOR item IN SELECT * FROM (VALUES
 ('ID_Immobilisation','Identifiant technique stable du bien ; attribué par PostgreSQL et jamais réutilisé.'),('IdEntiteFk','Entreprise propriétaire durable, obligatoire et immuable.'),('CodeImmobilisation','Code IMMO-identifiant attribué par trigger ; unique et immuable.'),
 ('NomImmobilisation','Désignation du bien, maximum200 caractères, sans contrôle ni espace extérieur.'),('Reference','Référence libre facultative du modèle ou du catalogue, maximum255 caractères.'),('Caracteristiques','Caractéristiques communes du bien ou du groupe homogène, maximum4000 caractères, retours de ligne autorisés.'),
 ('SuiviIndividuel','true par défaut pour une fiche par équipement ; false explicite pour un groupe homogène partageant caractéristiques, état et affectation.'),('Quantite','Nombre entier exact de biens, de1 à18 chiffres ; aucun arrondi silencieux des fractions. Un suivi individuel ou numéro de série impose1.'),
 ('PrixUnitaire','Prix d’acquisition unitaire indicatif à2 décimales, non négatif ; NULL signifie inconnu et ne vaut jamais zéro.'),('ID_DeviseFk','Devise du référentiel ; obligatoire dès que le prix est renseigné, sans conversion automatique.'),('ID_CategorieFk','Type de matériel depuis le référentiel et les correspondances configurées pour cette entreprise.'),('ID_EtatFk','État facultatif issu de la famille configurée ; aucune présomption de bon état.'),
 ('ID_ResponsableFk','Compte responsable de la même entreprise ; nouvelle affectation réservée aux comptes actifs dont les dates d’emploi permettent l’affectation.'),('ID_ServiceFk','Service explicite du bien, issu du référentiel ; indépendant de l’évolution du service professionnel de son responsable.'),('ID_LocalisationFk','Lieu d’affectation appartenant à la même entreprise, sans lien texte ou égalité d’identifiants d’une autre table.'),('LocalisationComplement','Salle, bureau ou précision facultative de l’affectation, maximum255 caractères.'),
 ('DateEntree','Date et heure d’entrée du bien dans le registre ; distincte de la date d’achat et des dates techniques.'),('DateAcquisition','Date d’acquisition facultative ; aucune date inventée si inconnue.'),('NumeroSerie','Numéro de série facultatif, maximum255 caractères ; sa présence impose une fiche pour un seul bien.'),('Observations','Note complémentaire facultative, maximum4000 caractères, retours de ligne autorisés.'),('Actif','true si le bien figure dans le registre actif ; false archive sa fiche sans effacer les affectations ni l’historique.'),
 ('CreeLe','Horodatage technique PostgreSQL de création, immuable.'),('ModifieLe','Horodatage technique PostgreSQL de la dernière écriture.'),('CreeParUserFk','Auteur actif prouvé par le contexte transactionnel à la création, immuable.'),('ModifieParUserFk','Auteur actif prouvé de la dernière écriture.')) AS descriptions(name,description) LOOP
  EXECUTE format('COMMENT ON COLUMN logistique."T_Immobilisation".%I IS %L',item.name,item.description);
 END LOOP;
 FOR item IN SELECT conname,pg_get_constraintdef(oid,true) definition FROM pg_constraint WHERE conrelid='logistique."T_Immobilisation"'::regclass LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON logistique."T_Immobilisation" IS %L',item.conname,'Intégrité durable du patrimoine : '||item.definition||'. Aucun effet de stock ou comptabilisation automatique.');
 END LOOP;
 FOR item IN SELECT c.relname FROM pg_index k JOIN pg_class c ON c.oid=k.indexrelid WHERE k.indrelid='logistique."T_Immobilisation"'::regclass AND (k.indisprimary OR k.indisunique) LOOP
  EXECUTE format('COMMENT ON INDEX logistique.%I IS %L',item.relname,'Unicité de l’identité technique ou du code immuable de patrimoine.');
 END LOOP;
 FOR item IN SELECT conname,pg_get_constraintdef(oid,true) definition FROM pg_constraint WHERE conrelid='systeme."T_Utilisateurs"'::regclass AND (conname IN ('ck_user_matricule','ck_user_dates_emploi','ck_user_observation_professionnelle') OR conname IN ('T_Utilisateurs_ID_ServiceFk_fkey','T_Utilisateurs_ID_FonctionFk_fkey')) LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON systeme."T_Utilisateurs" IS %L',item.conname,'Métadonnée professionnelle facultative contrôlée : '||item.definition||'. Ne donne aucun droit de sécurité.');
 END LOOP;
 FOR item IN SELECT a.attname FROM pg_attribute a WHERE a.attrelid='logistique."V_Immobilisation"'::regclass AND a.attnum>0 AND NOT a.attisdropped LOOP
  SELECT col_description(attrelid,attnum) INTO description FROM pg_attribute WHERE attrelid='logistique."T_Immobilisation"'::regclass AND attname=item.attname;
  description:=coalesce(description,CASE item.attname WHEN 'ValeurAcquisition' THEN 'Quantité entière multipliée par prix unitaire, arrondi monétaire à2 décimales ; NULL si prix inconnu, sans calcul d’amortissement.' WHEN '_version' THEN 'Révision technique opaque xmin pour refuser les modifications concurrentes périmées.' WHEN 'Localisation' THEN 'Adresse et niveaux géographiques du lieu lié, avec propriétaire vérifié ; aucune ligne supprimée par un champ optionnel absent.' ELSE 'Libellé courant '||item.attname||' joint depuis son référentiel ou son propriétaire, sans calcul en frontend.' END);
  EXECUTE format('COMMENT ON COLUMN logistique."V_Immobilisation".%I IS %L',item.attname,description);
 END LOOP;
 FOR item IN SELECT attname FROM pg_attribute WHERE attrelid='systeme."V_User_Affectation"'::regclass AND attnum>0 AND NOT attisdropped LOOP
  description:=CASE item.attname WHEN 'EstAffectable' THEN 'Compte actif, sans début professionnel futur ni fin passée à la date de Kinshasa ; les nouvelles responsabilités exigent aussi la même entreprise.' WHEN '_version' THEN 'Révision opaque xmin de la fiche utilisateur, sans secret.' WHEN 'ObservationProfessionnelle' THEN 'Note professionnelle privée limitée à1000 caractères, jamais étendue au profil public.' ELSE 'Métadonnée professionnelle privée '||item.attname||' ; filtrage par entreprise et droits requis.' END;
  EXECUTE format('COMMENT ON COLUMN systeme."V_User_Affectation".%I IS %L',item.attname,description);
 END LOOP;
END $commentaires$;

-- Un nouveau catalogue ne réinitialise aucun choix personnel déjà enregistré.
INSERT INTO referentiel."T_InterfaceTableau"("CleInterface","Module","Colonnes")
SELECT 'logistique.immobilisations','logistique',jsonb_agg(jsonb_build_object('id',a.attname,'label',CASE a.attname WHEN 'CodeImmobilisation' THEN 'Code du bien' WHEN 'NomImmobilisation' THEN 'Bien' WHEN 'CategorieMateriel' THEN 'Type de matériel' WHEN 'EtatMateriel' THEN 'État du matériel' WHEN 'ValeurAcquisition' THEN 'Valeur d’acquisition' WHEN 'DateEntree' THEN 'Date et heure d’entrée'
 WHEN 'Reference' THEN 'Référence' WHEN 'Quantite' THEN 'Quantité' WHEN 'PrixUnitaire' THEN 'Prix unitaire' WHEN 'SuiviIndividuel' THEN 'Mode de suivi' WHEN 'DateAcquisition' THEN 'Date d’acquisition' WHEN 'NumeroSerie' THEN 'N° de série' WHEN 'LocalisationComplement' THEN 'Bureau ou salle' WHEN 'NomEntite' THEN 'Entreprise' WHEN 'CreeLe' THEN 'Créé le' WHEN 'ModifieLe' THEN 'Modifié le' WHEN 'Actif' THEN 'État de la fiche' WHEN 'Caracteristiques' THEN 'Caractéristiques' WHEN 'DeviseCode' THEN 'Code devise' WHEN 'DeviseLibelle' THEN 'Devise' ELSE a.attname END,
 'type',CASE WHEN a.atttypid IN ('numeric'::regtype,'integer'::regtype) THEN 'number' WHEN a.atttypid='boolean'::regtype THEN 'boolean' WHEN a.atttypid='date'::regtype THEN 'date' WHEN a.atttypid='timestamptz'::regtype THEN 'datetime' ELSE 'text' END,
 'defaultVisible',a.attname=ANY(ARRAY['CodeImmobilisation','NomImmobilisation','CategorieMateriel','Quantite','ValeurAcquisition','Responsable','Service','EtatMateriel','DateEntree']),
 'defaultExport',a.attname=ANY(ARRAY['CodeImmobilisation','NomImmobilisation','CategorieMateriel','Quantite','ValeurAcquisition','Responsable','Service','EtatMateriel','DateEntree']),
 'exportable',a.attname NOT IN ('_version','IdEntiteFk','CreeParUserFk','ModifieParUserFk'),
 'tableAvailable',a.attname NOT IN ('_version','IdEntiteFk','CreeParUserFk','ModifieParUserFk','ID_Immobilisation','ID_CategorieFk','ID_EtatFk','ID_ResponsableFk','ID_ServiceFk','ID_LocalisationFk','ID_DeviseFk'),
 'defaultOrder',coalesce(array_position(ARRAY['CodeImmobilisation','NomImmobilisation','CategorieMateriel','Quantite','ValeurAcquisition','Responsable','Service','EtatMateriel','DateEntree'],a.attname),20+a.attnum)) ORDER BY a.attnum)
 ||jsonb_build_array(jsonb_build_object('id','actions','label','Actions','type','actions','defaultVisible',true,'defaultExport',false,'exportable',false,'tableAvailable',true,'defaultOrder',100))
FROM pg_attribute a WHERE a.attrelid='logistique."V_Immobilisation"'::regclass AND a.attnum>0 AND NOT a.attisdropped AND a.attname<>'_version';

-- Les profils privés gagnent les informations professionnelles sans élargir
-- la vue publique ni modifier les préférences personnelles ou d'export.
DO $catalogue_profils$
DECLARE columns_data jsonb;item record;catalog_key text;defaults text[];position integer;
BEGIN
 FOREACH catalog_key IN ARRAY ARRAY['admin.profils','admin.utilisateurs'] LOOP
 defaults:=CASE WHEN catalog_key='admin.utilisateurs' THEN ARRAY['NomUser','MatriculeUser','NomEntite','Service','Fonction','Role','ValideUser','Is_Admin','actions'] ELSE ARRAY['NomUser','MatriculeUser','NomEntite','Service','Fonction','ValideUser','actions'] END;
 position:=0;
 SELECT "Colonnes" INTO columns_data FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=catalog_key;
 IF columns_data IS NULL THEN RAISE EXCEPTION 'Catalogue privé % requis.',catalog_key;END IF;
 SELECT jsonb_agg(value||jsonb_build_object('defaultVisible',(value->>'id')=ANY(defaults),'defaultOrder',coalesce(array_position(defaults,value->>'id')-1,100+ordinality::integer)) ORDER BY ordinality)
 INTO columns_data FROM jsonb_array_elements(columns_data) WITH ORDINALITY;
 FOR item IN SELECT * FROM (VALUES
  ('MatriculeUser','Matricule','character varying',true),('ID_ServiceFk','Identifiant service','integer',false),('ID_FonctionFk','Identifiant fonction','integer',false),
  ('DateEmbauche','Date d’embauche','date',true),('DateFinEmploi','Fin d’emploi','date',true),('ObservationProfessionnelle','Observation professionnelle','text',true),
  ('Service','Service','text',true),('Fonction','Fonction','text',true),('EstAffectable','Affectable','boolean',true)) AS seed(id,label,type,available) LOOP
  position:=position+1;
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(columns_data) c WHERE c->>'id'=item.id) THEN
   columns_data:=columns_data||jsonb_build_array(jsonb_build_object('id',item.id,'label',item.label,'type',item.type,'tableAvailable',item.available,'exportable',true,
    'defaultVisible',item.id=ANY(defaults),'defaultOrder',coalesce(array_position(defaults,item.id)-1,200+position),'defaultExport',false,'defaultExportOrder',200+position));
  END IF;
 END LOOP;
 UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=columns_data WHERE "CleInterface"=catalog_key;
 END LOOP;
END $catalogue_profils$;
COMMIT;
