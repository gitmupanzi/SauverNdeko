-- Annuaire professionnel transversal : dictionnaire central, publication explicite et propriété durable.
-- Aucun professionnel ni qualification n'est inventé. La source auditée ne contient aucun profil.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $guard$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 IF EXISTS(SELECT FROM professionnel."T_Professionnel") THEN RAISE EXCEPTION 'Des profils existent : une reprise explicite de leur propriété et publication est requise avant cette migration.';END IF;
END $guard$;

ALTER TABLE professionnel."T_Professionnel" ALTER COLUMN "IdSpecialiteFk" DROP NOT NULL,
 ADD COLUMN "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 ADD COLUMN "IdSecteurFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 ADD COLUMN "TitrePublic" text, ADD COLUMN "PresentationPublique" text, ADD COLUMN "LocalitePublique" text,
 ADD COLUMN "ContactAutorise" boolean NOT NULL DEFAULT true, ADD COLUMN "Publie" boolean NOT NULL DEFAULT false,
 ADD COLUMN "Revision" bigint NOT NULL DEFAULT 1,
 ADD COLUMN "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 ADD COLUMN "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 ADD COLUMN "CreeParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 ADD COLUMN "ModifieParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 ADD COLUMN "CreationRequestId" uuid UNIQUE, ADD COLUMN "CreationPayloadHash" text,
 ADD CONSTRAINT ck_prof_titre CHECK("TitrePublic" IS NULL OR length(btrim("TitrePublic")) BETWEEN 1 AND 180),
 ADD CONSTRAINT ck_prof_presentation CHECK("PresentationPublique" IS NULL OR length(btrim("PresentationPublique")) BETWEEN 1 AND 10000),
 ADD CONSTRAINT ck_prof_localite CHECK("LocalitePublique" IS NULL OR length(btrim("LocalitePublique")) BETWEEN 1 AND 255),
 ADD CONSTRAINT ck_prof_note CHECK("ObsProfessionnel" IS NULL OR length("ObsProfessionnel")<=5000),
 ADD CONSTRAINT ck_prof_revision CHECK("Revision">0),
 ADD CONSTRAINT ck_prof_experience_max CHECK("ExperienceAns" IS NULL OR "ExperienceAns"<=100),
 ADD CONSTRAINT ck_prof_publication CHECK(NOT "Publie" OR ("IdSecteurFk" IS NOT NULL AND nullif(btrim("TitrePublic"),'') IS NOT NULL AND nullif(btrim("PresentationPublique"),'') IS NOT NULL)),
 ADD CONSTRAINT ck_prof_rejeu CHECK(("CreationRequestId" IS NULL)=("CreationPayloadHash" IS NULL) AND ("CreationPayloadHash" IS NULL OR "CreationPayloadHash"~'^[a-f0-9]{64}$'));
COMMENT ON TABLE professionnel."T_Professionnel" IS 'Fiche professionnelle unique par compte et propriétaire entreprise durable. Les compétences sont déclarées, la publication est explicite et distincte de l’activité ; aucune validation de diplôme n’est déduite de ces états.';
COMMENT ON COLUMN professionnel."T_Professionnel"."IdSpecialiteFk" IS 'Spécialité facultative du référentiel central ; son absence permet les professions transversales sans spécialité sanitaire artificielle.';
COMMENT ON COLUMN professionnel."T_Professionnel"."IdEntiteFk" IS 'Entreprise propriétaire immuable de la fiche ; distincte des structures auxquelles le professionnel est affilié.';
COMMENT ON COLUMN professionnel."T_Professionnel"."IdSecteurFk" IS 'Secteur déclaré, valeur T_Generique filtrée par le référencement central de ce champ ; requis pour publier.';
COMMENT ON COLUMN professionnel."T_Professionnel"."TitrePublic" IS 'Titre professionnel public volontaire, sans vérification automatique de qualification ; requis pour publier.';
COMMENT ON COLUMN professionnel."T_Professionnel"."PresentationPublique" IS 'Présentation destinée aux lecteurs de l’annuaire ; séparée de la note interne ObsProfessionnel.';
COMMENT ON COLUMN professionnel."T_Professionnel"."LocalitePublique" IS 'Localité ou zone de service déclarée, y compris prestations à distance ; aucune adresse personnelle n’est déduite du compte.';
COMMENT ON COLUMN professionnel."T_Professionnel"."ContactAutorise" IS 'Autorise la demande de contact dans la messagerie pour un profil public actif ; ne publie ni email ni téléphone personnel.';
COMMENT ON COLUMN professionnel."T_Professionnel"."Publie" IS 'Consentement de publication explicite, faux par défaut ; l’activité du profil ou du compte ne vaut jamais publication.';
COMMENT ON COLUMN professionnel."T_Professionnel"."Revision" IS 'Version concurrente de la fiche, incrémentée par PostgreSQL ; le service la compare sous verrou avant modification.';
COMMENT ON COLUMN professionnel."T_Professionnel"."CreeLe" IS 'Instant technique de création, conservé après enregistrement.';
COMMENT ON COLUMN professionnel."T_Professionnel"."ModifieLe" IS 'Instant technique de la dernière modification de la fiche.';
COMMENT ON COLUMN professionnel."T_Professionnel"."CreeParUserFk" IS 'Compte auteur de la création, distinct du compte professionnel représenté.';
COMMENT ON COLUMN professionnel."T_Professionnel"."ModifieParUserFk" IS 'Compte auteur de la dernière modification autorisée.';
COMMENT ON COLUMN professionnel."T_Professionnel"."CreationRequestId" IS 'Identifiant UUID de demande pour le rejeu de création, unique et immuable.';
COMMENT ON COLUMN professionnel."T_Professionnel"."CreationPayloadHash" IS 'Empreinte SHA256 du contenu normalisé de création ; ne contient aucun secret de compte.';
COMMENT ON COLUMN professionnel."T_Professionnel"."ValideProfessionnel" IS 'Activité de la fiche, distincte de sa publication et de toute vérification de qualification ; faux désigne une fiche archivée.';

CREATE TABLE professionnel."T_Professionnel_Competence"(
 "IdProfessionnelFk" integer NOT NULL REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT,
 "IdCompetenceFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 PRIMARY KEY("IdProfessionnelFk","IdCompetenceFk")
);
CREATE TABLE professionnel."T_Professionnel_Prestation"(
 "IdProfessionnelFk" integer NOT NULL REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT,
 "IdPrestationFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 PRIMARY KEY("IdProfessionnelFk","IdPrestationFk")
);
CREATE TABLE professionnel."T_SynonymeRecherche"(
 "ID_SynonymeRecherche" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdGeneriqueFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "Terme" text NOT NULL CHECK(length(btrim("Terme")) BETWEEN 1 AND 200),
 "Actif" boolean NOT NULL DEFAULT true,
 "IdEntiteFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT
);
CREATE UNIQUE INDEX uq_synonyme_reference_terme ON professionnel."T_SynonymeRecherche"("IdGeneriqueFk",referentiel.fn_normaliser_libelle("Terme"));
CREATE INDEX ix_prof_owner ON professionnel."T_Professionnel"("IdEntiteFk","IdProfessionnel");
CREATE INDEX ix_prof_secteur ON professionnel."T_Professionnel"("IdSecteurFk") WHERE "Publie" AND "ValideProfessionnel";
CREATE INDEX ix_competence_reference ON professionnel."T_Professionnel_Competence"("IdCompetenceFk","IdProfessionnelFk");
CREATE INDEX ix_prestation_reference ON professionnel."T_Professionnel_Prestation"("IdPrestationFk","IdProfessionnelFk");
COMMENT ON TABLE professionnel."T_Professionnel_Competence" IS 'Liaison entre fiche et compétence déclarée du référentiel central ; cette sélection n’est pas une certification.';
COMMENT ON COLUMN professionnel."T_Professionnel_Competence"."IdProfessionnelFk" IS 'Fiche professionnelle propriétaire ; son entreprise détermine le contexte des références.';
COMMENT ON COLUMN professionnel."T_Professionnel_Competence"."IdCompetenceFk" IS 'Valeur ID_Generique d’une famille de compétences configurée pour ce champ.';
COMMENT ON TABLE professionnel."T_Professionnel_Prestation" IS 'Liaison entre fiche et prestation proposée du référentiel central ; aucune table de dictionnaire locale.';
COMMENT ON COLUMN professionnel."T_Professionnel_Prestation"."IdProfessionnelFk" IS 'Fiche professionnelle propriétaire ; le service contrôle ses droits avant toute modification.';
COMMENT ON COLUMN professionnel."T_Professionnel_Prestation"."IdPrestationFk" IS 'Valeur ID_Generique de la famille de prestations configurée pour ce champ.';
COMMENT ON TABLE professionnel."T_SynonymeRecherche" IS 'Détails lexicaux rattachés à une valeur existante de T_Generique, pour retrouver un besoin par un mot courant. Ne relie jamais arbitrairement une personne à une compétence.';
COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."ID_SynonymeRecherche" IS 'Identifiant technique du terme de recherche.';
COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."IdGeneriqueFk" IS 'Valeur centrale visée par le synonyme ; le terme ne crée pas une nouvelle compétence.';
COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."Terme" IS 'Expression de recherche explicite, sans interprétation médicale ni promesse de service.';
COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."Actif" IS 'Terme utilisé dans la projection de recherche s’il est actif et sa référence reste valide.';
COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."IdEntiteFk" IS 'Portée identique à la référence centrale : NULL commune, sinon entreprise propriétaire de la valeur.';
COMMENT ON INDEX professionnel.uq_synonyme_reference_terme IS 'Interdit un même terme normalisé plusieurs fois pour la même référence.';
COMMENT ON INDEX professionnel.ix_prof_owner IS 'Registre autorisé et pagination par entreprise propriétaire.';
COMMENT ON INDEX professionnel.ix_prof_secteur IS 'Filtre des fiches publiées et actives par secteur.';
COMMENT ON INDEX professionnel.ix_competence_reference IS 'Recherche des fiches par compétence centrale sans dupliquer les profils.';
COMMENT ON INDEX professionnel.ix_prestation_reference IS 'Recherche des fiches par prestation centrale sans double comptage.';

-- La portée des listes de détail vient de la vraie fiche, jamais du compte du lecteur.
CREATE OR REPLACE FUNCTION referentiel.fn_entite_reference_champ(p_schema text,p_table text,p_ligne jsonb) RETURNS integer
 LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE owner_id integer;
BEGIN
 IF p_ligne IS NULL OR NOT EXISTS(SELECT FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "SupportsEntityScope") THEN RETURN NULL;END IF;
 IF p_schema='professionnel' AND p_table IN('T_Professionnel_Competence','T_Professionnel_Prestation','T_Professionnel_Entite') THEN
  SELECT "IdEntiteFk" INTO owner_id FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=nullif(p_ligne->>'IdProfessionnelFk','')::integer;RETURN owner_id;END IF;
 IF (p_schema,p_table)=('logistique','T_PrecisionStock') THEN
  SELECT "IdEntiteFk" INTO owner_id FROM referentiel."T_Generique" WHERE "ID_Generique"=nullif(p_ligne->>'ID_UniteFk','')::integer;RETURN owner_id;END IF;
 IF (p_schema,p_table)=('systeme','T_Entite') THEN RETURN nullif(p_ligne->>'IdEntite','')::integer;END IF;
 owner_id:=coalesce(nullif(p_ligne->>'IdEntiteFk','')::integer,nullif(p_ligne->>'ID_EntiteFk','')::integer);
 IF owner_id IS NOT NULL THEN RETURN owner_id;END IF;
 IF p_schema='support' AND p_table='T_ResolutionSupport' THEN
  SELECT "IdEntiteFk" INTO owner_id FROM support."T_Support" WHERE "ID_Support"=nullif(p_ligne->>'ID_SupportFk','')::bigint;RETURN owner_id;END IF;
 IF p_schema='logistique' THEN CASE p_table
  WHEN 'T_Mouvement' THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "ID_Commande"=nullif(p_ligne->>'ID_cmdFk','')::integer;
   IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Article" WHERE "ID_Article"=nullif(p_ligne->>'ID_ArticleFk','')::integer;END IF;
  WHEN 'T_Reglements' THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Facture" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';
   IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';END IF;
  WHEN 'T_Remboursement' THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Avoir" WHERE "ID_Avoir"=nullif(p_ligne->>'ID_AvoirFk','')::bigint;
  ELSE NULL;END CASE;END IF;
 RETURN owner_id;
END $$;
COMMENT ON FUNCTION referentiel.fn_entite_reference_champ(text,text,jsonb) IS 'Contexte durable des références : propriétaire explicite, ou parent métier prouvé ; compétences, prestations et affiliations prennent l’entreprise de leur fiche. La structure affiliée n’est pas le propriétaire. Ne prend jamais l’entreprise courante du compte représenté.';

LOCK TABLE referentiel."T_CategorieGenerique",referentiel."T_Generique" IN SHARE ROW EXCLUSIVE MODE;
-- Évolution fermée de la politique du catalogue : seules ces trois FK acquièrent un propriétaire durable.
ALTER TABLE referentiel."T_ChampReferentiel" DISABLE TRIGGER tr_catalogue_champ_integrite;
DO $seed$
DECLARE r record;v record;fam integer;n integer;families jsonb:='{}';special integer;types integer;liens integer;gid integer;
BEGIN
 FOR r IN SELECT * FROM (VALUES('Secteur professionnel','IdSecteurFk','T_Professionnel','Secteur','secteurs'),
  ('Compétence professionnelle','IdCompetenceFk','T_Professionnel_Competence','Compétences','competences'),
  ('Prestation professionnelle','IdPrestationFk','T_Professionnel_Prestation','Prestations','prestations'),
  ('Type de lien professionnel','IdTypeLienFk','T_Professionnel_Entite','Type de lien','typesLien')) AS t(fam,col,tbl,label,alias)
 LOOP
  SELECT count(*),min("ID_CategorieGenerique") INTO n,fam FROM referentiel."T_CategorieGenerique" WHERE "IdEntiteFk" IS NULL AND referentiel.fn_normaliser_libelle("NomCategorieGenerique")=referentiel.fn_normaliser_libelle(r.fam);
  IF n>1 THEN RAISE EXCEPTION 'Famille % ambiguë.',r.fam;END IF;
  IF fam IS NULL THEN INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ModuleCategorieGenerique","ValideCategorieGenerique") VALUES(r.fam,'M_PROFESSIONNEL',true) RETURNING "ID_CategorieGenerique" INTO fam;END IF;
  IF NOT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=fam AND "ValideCategorieGenerique") THEN RAISE EXCEPTION 'Famille % inactive.',r.fam;END IF;
  families:=families||jsonb_build_object(r.alias,fam);
  IF NOT EXISTS(SELECT FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='professionnel' AND "TableName"=r.tbl AND "ColumnName"=r.col) THEN
   INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName","ID_CategorieDefautFk","AliasSourceKeys","CanConfigure","SupportsEntityScope") VALUES('professionnel',r.tbl,r.col,r.label,'professionnel',fam,ARRAY['professionnel.'||r.alias],true,true);
  ELSE
   -- Les défauts historiques et les surcharges actives ne sont jamais écrasés.
   UPDATE referentiel."T_ChampReferentiel" SET "SupportsEntityScope"=true,"ChampLabel"=r.label WHERE "SchemaName"='professionnel' AND "TableName"=r.tbl AND "ColumnName"=r.col;
  END IF;
 END LOOP;
 UPDATE referentiel."T_ChampReferentiel" SET "SupportsEntityScope"=true,"ChampLabel"=CASE "ColumnName" WHEN 'IdTypeProfessionnelFk' THEN 'Profession' ELSE 'Spécialité' END WHERE "SchemaName"='professionnel' AND "TableName"='T_Professionnel' AND "ColumnName" IN('IdTypeProfessionnelFk','IdSpecialiteFk');
 SELECT min("ID_CategorieGenerique") INTO types FROM referentiel."T_CategorieGenerique" WHERE "IdEntiteFk" IS NULL AND referentiel.fn_normaliser_libelle("NomCategorieGenerique")=referentiel.fn_normaliser_libelle('Type de profession');
 SELECT min("ID_CategorieGenerique") INTO special FROM referentiel."T_CategorieGenerique" WHERE "IdEntiteFk" IS NULL AND referentiel.fn_normaliser_libelle("NomCategorieGenerique")=referentiel.fn_normaliser_libelle('Spécialité');
 IF types IS NULL OR special IS NULL THEN RAISE EXCEPTION 'Familles historiques profession/spécialité absentes.';END IF;
 -- Défauts auparavant inconnus désormais documentés : les surcharges courantes restent intactes.
 UPDATE referentiel."T_ChampReferentiel" SET "ID_CategorieDefautFk"=types WHERE "SchemaName"='professionnel' AND "TableName"='T_Professionnel' AND "ColumnName"='IdTypeProfessionnelFk' AND "ID_CategorieDefautFk" IS NULL;
 UPDATE referentiel."T_ChampReferentiel" SET "ID_CategorieDefautFk"=(families->>'typesLien')::integer WHERE "SchemaName"='professionnel' AND "TableName"='T_Professionnel_Entite' AND "ColumnName"='IdTypeLienFk' AND "ID_CategorieDefautFk" IS NULL;
 families:=families||jsonb_build_object('professions',types,'specialites',special);
 FOR v IN SELECT * FROM (VALUES
  ('secteurs','Santé','SANTE'),('secteurs','Immobilier','IMMOBILIER'),('secteurs','Construction','CONSTRUCTION'),
  ('professions','Médecin','Médecin'),('professions','Architecte','Architecte'),('professions','Ingénieur en construction','Ingénieur en construction'),('professions','Expert immobilier','Expert immobilier'),
  ('competences','Oncologie','Oncologie'),('competences','Architecture','Architecture'),('competences','Expertise immobilière','Expertise immobilière'),('competences','Génie civil','Génie civil'),
  ('prestations','Consultation médicale','Consultation médicale'),('prestations','Évaluation immobilière','Évaluation immobilière'),('prestations','Étude architecturale','Étude architecturale'),('prestations','Suivi de chantier','Suivi de chantier'),
  ('typesLien','Exerce au sein de','Exerce au sein de'),('typesLien','Intervient pour','Intervient pour')) AS t(family,label,code)
 LOOP
  fam:=(families->>v.family)::integer;
  IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=fam AND "IdEntiteFk" IS NULL AND referentiel.fn_normaliser_libelle("NomGenerique")=referentiel.fn_normaliser_libelle(v.label)) THEN
   INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(fam,v.label,v.code,true);
  END IF;
 END LOOP;
 SELECT "ID_Generique" INTO gid FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=(families->>'competences')::integer AND "NomGenerique"='Oncologie' AND "IdEntiteFk" IS NULL;
 IF gid IS NOT NULL THEN INSERT INTO professionnel."T_SynonymeRecherche"("IdGeneriqueFk","Terme") VALUES(gid,'cancer'),(gid,'cancérologie'),(gid,'oncologie');END IF;
END $seed$;
ALTER TABLE referentiel."T_ChampReferentiel" ENABLE TRIGGER tr_catalogue_champ_integrite;

CREATE FUNCTION professionnel.fn_expert_reference_valide(p_table text,p_champ text,p_valeur integer,p_entite integer) RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_Generique"=p_valeur AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND referentiel.fn_reference_visible(g."ID_Generique",p_entite)
 AND g."ID_CategorieGeneriqueFk"=ANY(coalesce(referentiel.fn_categories_champ('professionnel',p_table,p_champ,p_entite),ARRAY[]::integer[]))) $$;
COMMENT ON FUNCTION professionnel.fn_expert_reference_valide(text,text,integer,integer) IS 'Contrôle d’une nouvelle sélection : famille configurée du vrai champ, validité de valeur/famille et portée de l’entreprise propriétaire.';

CREATE FUNCTION professionnel.tr_professionnel_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE account_entity integer;account_global boolean;actor integer:=nullif(current_setting('professionnel.actor_id',true),'')::integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Archivez la fiche pour conserver son historique.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND (NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" OR NEW."IdUserFk" IS DISTINCT FROM OLD."IdUserFk" OR NEW."CreeLe" IS DISTINCT FROM OLD."CreeLe" OR NEW."CreeParUserFk" IS DISTINCT FROM OLD."CreeParUserFk" OR NEW."CreationRequestId" IS DISTINCT FROM OLD."CreationRequestId" OR NEW."CreationPayloadHash" IS DISTINCT FROM OLD."CreationPayloadHash") THEN RAISE EXCEPTION 'Propriétaire, compte et identité de création sont conservés.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  SELECT "IdEntiteFk",coalesce("Is_Admin",false) INTO account_entity,account_global FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."IdUserFk" FOR SHARE;
  IF NOT FOUND OR (account_entity IS DISTINCT FROM NEW."IdEntiteFk" AND NOT(account_entity IS NULL AND account_global AND coalesce(actor=NEW."IdUserFk",false))) THEN RAISE EXCEPTION 'Le compte professionnel appartient à une autre entreprise.' USING ERRCODE='23514';END IF;
  NEW."Revision":=1;NEW."CreeLe":=clock_timestamp();NEW."ModifieLe":=NEW."CreeLe";
 ELSE NEW."Revision":=OLD."Revision"+1;NEW."ModifieLe":=clock_timestamp();END IF;
 IF NEW."Publie" AND (TG_OP='INSERT' OR NOT OLD."Publie") THEN
  IF NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."IdUserFk" AND "ValideUser") OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" AND "ValideEntite") OR NOT NEW."ValideProfessionnel" THEN RAISE EXCEPTION 'Seule une fiche active d’un compte et d’une entreprise actifs peut être publiée.' USING ERRCODE='23514';END IF;
  IF NOT professionnel.fn_expert_reference_valide('T_Professionnel','IdTypeProfessionnelFk',NEW."IdTypeProfessionnelFk",NEW."IdEntiteFk") OR NOT professionnel.fn_expert_reference_valide('T_Professionnel','IdSecteurFk',NEW."IdSecteurFk",NEW."IdEntiteFk") OR (NEW."IdSpecialiteFk" IS NOT NULL AND NOT professionnel.fn_expert_reference_valide('T_Professionnel','IdSpecialiteFk',NEW."IdSpecialiteFk",NEW."IdEntiteFk")) THEN RAISE EXCEPTION 'Corrigez les références devenues incompatibles avant de publier.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER ab_professionnel_integrite BEFORE INSERT OR UPDATE OR DELETE ON professionnel."T_Professionnel" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_integrite();
COMMENT ON FUNCTION professionnel.tr_professionnel_integrite() IS 'Propriété et compte immuables, révision SQL, cohérence initiale compte/entreprise et publication explicite. Exception limitée au compte global qui se représente lui-même dans une entreprise choisie ; la GUC n’accorde aucun droit API.';
COMMENT ON TRIGGER ab_professionnel_integrite ON professionnel."T_Professionnel" IS 'Garde commune du registre et des écritures SQL ; la suppression physique est remplacée par l’archivage.';

CREATE FUNCTION professionnel.tr_compte_professionnel_entreprise() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND EXISTS(SELECT FROM professionnel."T_Professionnel" p WHERE p."IdUserFk"=NEW."IdUser" AND p."IdEntiteFk" IS DISTINCT FROM NEW."IdEntiteFk") THEN
  RAISE EXCEPTION 'Ce compte possède une fiche professionnelle rattachée durablement à son entreprise.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER ac_compte_professionnel_entreprise BEFORE UPDATE OF "IdEntiteFk" ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_compte_professionnel_entreprise();
COMMENT ON FUNCTION professionnel.tr_compte_professionnel_entreprise() IS 'Empêche un déplacement de compte qui contredirait la propriété durable d’une fiche professionnelle existante ; ne change ni authentification ni rôles.';
COMMENT ON TRIGGER ac_compte_professionnel_entreprise ON systeme."T_Utilisateurs" IS 'Conserve la cohérence compte/entreprise du profil sans déplacement implicite des données.';

CREATE FUNCTION professionnel.tr_detail_professionnel_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE profile_id integer;owner_id integer;f text;val integer;
BEGIN
 profile_id:=CASE WHEN TG_OP='DELETE' THEN OLD."IdProfessionnelFk" ELSE NEW."IdProfessionnelFk" END;
 SELECT "IdEntiteFk" INTO owner_id FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=profile_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Fiche professionnelle introuvable.' USING ERRCODE='23503';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 IF TG_OP='UPDATE' AND NEW."IdProfessionnelFk" IS DISTINCT FROM OLD."IdProfessionnelFk" THEN RAISE EXCEPTION 'Le parent du détail est conservé.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_Professionnel_Entite' THEN
  IF NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" AND "ValideEntite") AND (TG_OP='INSERT' OR NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk") THEN RAISE EXCEPTION 'Structure inactive ou introuvable.' USING ERRCODE='23514';END IF;
  IF (NEW."DateDebut" IS NOT NULL AND NOT isfinite(NEW."DateDebut")) OR (NEW."DateFin" IS NOT NULL AND NOT isfinite(NEW."DateFin")) THEN RAISE EXCEPTION 'Période d’affiliation invalide.' USING ERRCODE='23514';END IF;
  IF NEW."EstPrincipal" THEN
   IF EXISTS(SELECT FROM professionnel."T_Professionnel_Entite" x WHERE x."IdProfessionnelFk"=profile_id AND x."IdEntiteFk"<>NEW."IdEntiteFk" AND x."EstPrincipal" AND tsrange(x."DateDebut",x."DateFin",'[)') && tsrange(NEW."DateDebut",NEW."DateFin",'[)')) THEN RAISE EXCEPTION 'Une seule affiliation principale est possible sur la même période.' USING ERRCODE='23514';END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER ab_detail_professionnel_integrite BEFORE INSERT OR UPDATE OR DELETE ON professionnel."T_Professionnel_Competence" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_integrite();
CREATE TRIGGER ab_detail_professionnel_integrite BEFORE INSERT OR UPDATE OR DELETE ON professionnel."T_Professionnel_Prestation" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_integrite();
CREATE TRIGGER ab_detail_professionnel_integrite BEFORE INSERT OR UPDATE OR DELETE ON professionnel."T_Professionnel_Entite" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_integrite();
CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel_Competence" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();
CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel_Prestation" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();
COMMENT ON FUNCTION professionnel.tr_detail_professionnel_integrite() IS 'Sérialise les détails sous le verrou du profil, conserve le parent et contrôle les affiliations principales et dates finies ; ne réattribue aucune entreprise.';

CREATE FUNCTION professionnel.tr_synonyme_portee() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE owner_id integer;
BEGIN
 SELECT "IdEntiteFk" INTO owner_id FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."IdGeneriqueFk" FOR SHARE;
 IF NOT FOUND OR NEW."IdEntiteFk" IS DISTINCT FROM owner_id THEN RAISE EXCEPTION 'La portée du synonyme doit être celle de sa référence.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER ab_synonyme_portee BEFORE INSERT OR UPDATE ON professionnel."T_SynonymeRecherche" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_synonyme_portee();
COMMENT ON FUNCTION professionnel.tr_synonyme_portee() IS 'Un terme de recherche hérite exactement de la portée de sa valeur centrale, sans exposer les dictionnaires d’une autre entreprise.';
COMMENT ON TRIGGER ab_synonyme_portee ON professionnel."T_SynonymeRecherche" IS 'Garde la cohérence de portée du dictionnaire lexical.';

CREATE FUNCTION professionnel.tr_professionnel_audit() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE before_row jsonb;after_row jsonb;entity_id integer;profile_id integer;extra jsonb;
BEGIN
 extra:=jsonb_strip_nulls(jsonb_build_object('_requestId',nullif(current_setting('professionnel.request_id',true),''),'_payloadHash',nullif(current_setting('professionnel.payload_hash',true),''),'_actorId',nullif(current_setting('professionnel.actor_id',true),''),'_operation',nullif(current_setting('professionnel.operation',true),''),'_motif',nullif(current_setting('professionnel.motif',true),'')));
 IF TG_OP IN('UPDATE','DELETE') THEN before_row:=systeme.fn_audit_sans_secrets(to_jsonb(OLD))||extra;END IF;
 IF TG_OP IN('INSERT','UPDATE') THEN after_row:=systeme.fn_audit_sans_secrets(to_jsonb(NEW))||extra;END IF;
 IF TG_TABLE_NAME='T_Professionnel' THEN entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 ELSIF TG_TABLE_NAME='T_SynonymeRecherche' THEN entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 ELSE profile_id:=coalesce((after_row->>'IdProfessionnelFk')::integer,(before_row->>'IdProfessionnelFk')::integer);SELECT "IdEntiteFk" INTO entity_id FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=profile_id;END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk") VALUES(TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME,TG_OP,before_row,after_row,clock_timestamp(),entity_id);
 RETURN NULL;
END $$;
COMMENT ON FUNCTION professionnel.tr_professionnel_audit() IS 'Événement SQL unique et transactionnel des fiches, sélections et affiliations ; images sans secrets et métadonnées de rejeu/acteur/motif. Ces métadonnées ne remplacent jamais les permissions serveur.';
DO $$ DECLARE t text;BEGIN
 FOREACH t IN ARRAY ARRAY['T_Professionnel','T_Professionnel_Competence','T_Professionnel_Prestation','T_Professionnel_Entite','T_SynonymeRecherche'] LOOP
  EXECUTE format('CREATE TRIGGER zz_professionnel_audit AFTER INSERT OR UPDATE OR DELETE ON professionnel.%I FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_audit()',t);
  EXECUTE format('COMMENT ON TRIGGER zz_professionnel_audit ON professionnel.%I IS %L',t,'Trace SQL transactionnelle sans secret ; parent et entreprise restent identifiables après modification.');
 END LOOP;
 FOREACH t IN ARRAY ARRAY['T_Professionnel_Competence','T_Professionnel_Prestation','T_Professionnel_Entite'] LOOP
  EXECUTE format('COMMENT ON TRIGGER ab_detail_professionnel_integrite ON professionnel.%I IS %L',t,'Verrou parent, intégrité des liens et des affiliations principales sans double comptage.');
 END LOOP;
 FOREACH t IN ARRAY ARRAY['T_Professionnel_Competence','T_Professionnel_Prestation'] LOOP
  EXECUTE format('COMMENT ON TRIGGER aa_reference_champ ON professionnel.%I IS %L',t,'Valide les nouvelles références depuis le catalogue central dans le contexte propriétaire du profil.');
 END LOOP;
END $$;

-- Une seule ligne par professionnel, même avec plusieurs affiliations ou prestations.
CREATE VIEW professionnel."V_Professionnel_Registre" AS
SELECT p.*,u."NomUser",u."PrenomUser",u."EmailUser",u."UrlPhoto",u."ValideUser",
 btrim(concat_ws(' ',u."PrenomUser",u."NomUser")) AS "NomComplet",e."NomEntite",
 coalesce(nullif(s."AbrGenerique",''),s."NomGenerique") AS "Secteur",
 coalesce(nullif(t."AbrGenerique",''),t."NomGenerique") AS "TypeProfessionnel",
 coalesce(nullif(sp."AbrGenerique",''),sp."NomGenerique") AS "Specialite",
 coalesce(c."Competences",'[]'::jsonb) AS "Competences",coalesce(pr."Prestations",'[]'::jsonb) AS "Prestations",
 coalesce(a."Affiliations",'[]'::jsonb) AS "Affiliations",
 coalesce(c."NbCompetences",0) AS "NbCompetences",coalesce(pr."NbPrestations",0) AS "NbPrestations",
 CASE WHEN NOT coalesce(p."ValideProfessionnel",false) THEN 'archive' WHEN p."Publie" THEN 'publie' ELSE 'brouillon' END AS "EtatProfil",
 jsonb_build_object('ID_Generique',s."ID_Generique",'NomGenerique',s."NomGenerique",'AbrGenerique',s."AbrGenerique") AS "T_GeneriqueSecteur",
 jsonb_build_object('ID_Generique',sp."ID_Generique",'NomGenerique',sp."NomGenerique",'AbrGenerique',sp."AbrGenerique") AS "T_GeneriqueSpecialite",
 jsonb_build_object('ID_Generique',t."ID_Generique",'NomGenerique',t."NomGenerique",'AbrGenerique',t."AbrGenerique") AS "T_GeneriqueType",
 jsonb_build_object('IdUser',u."IdUser",'NomUser',u."NomUser",'PrenomUser',u."PrenomUser",'UrlPhoto',u."UrlPhoto") AS "T_Utilisateurs",
 search."TexteRecherche",to_tsvector('simple'::regconfig,search."TexteRecherche") AS "RechercheVecteur"
FROM professionnel."T_Professionnel" p JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUserFk"
 JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk"
 LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique"=p."IdSecteurFk"
 LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=p."IdTypeProfessionnelFk"
 LEFT JOIN referentiel."T_Generique" sp ON sp."ID_Generique"=p."IdSpecialiteFk"
 LEFT JOIN LATERAL(SELECT jsonb_agg(jsonb_build_object('ID_Generique',g."ID_Generique",'NomGenerique',g."NomGenerique",'AbrGenerique',g."AbrGenerique") ORDER BY g."NomGenerique",g."ID_Generique") AS "Competences",count(*) AS "NbCompetences" FROM professionnel."T_Professionnel_Competence" l JOIN referentiel."T_Generique" g ON g."ID_Generique"=l."IdCompetenceFk" WHERE l."IdProfessionnelFk"=p."IdProfessionnel") c ON true
 LEFT JOIN LATERAL(SELECT jsonb_agg(jsonb_build_object('ID_Generique',g."ID_Generique",'NomGenerique',g."NomGenerique",'AbrGenerique',g."AbrGenerique") ORDER BY g."NomGenerique",g."ID_Generique") AS "Prestations",count(*) AS "NbPrestations" FROM professionnel."T_Professionnel_Prestation" l JOIN referentiel."T_Generique" g ON g."ID_Generique"=l."IdPrestationFk" WHERE l."IdProfessionnelFk"=p."IdProfessionnel") pr ON true
 LEFT JOIN LATERAL(SELECT jsonb_agg(jsonb_build_object('IdEntiteFk',l."IdEntiteFk",'NomEntite',x."NomEntite",'IdTypeLienFk',l."IdTypeLienFk",'EstPrincipal',l."EstPrincipal",'DateDebut',l."DateDebut",'DateFin',l."DateFin",'ObsLien',l."ObsLien") ORDER BY l."EstPrincipal" DESC,l."IdEntiteFk") AS "Affiliations" FROM professionnel."T_Professionnel_Entite" l JOIN systeme."T_Entite" x ON x."IdEntite"=l."IdEntiteFk" WHERE l."IdProfessionnelFk"=p."IdProfessionnel") a ON true
 CROSS JOIN LATERAL(SELECT referentiel.fn_normaliser_libelle(concat_ws(' ',u."NomUser",u."PrenomUser",p."TitrePublic",p."PresentationPublique",p."LocalitePublique",s."NomGenerique",t."NomGenerique",sp."NomGenerique",c."Competences"::text,pr."Prestations"::text,a."Affiliations"::text)) AS "TexteRecherche") search;
COMMENT ON VIEW professionnel."V_Professionnel_Registre" IS 'Registre privé, une ligne par fiche propriétaire ; informations compte minimales, références et détails agrégés. Réservé aux services autorisés, jamais SELECT * dans une réponse publique.';

CREATE FUNCTION professionnel.fn_expert_recherche(p_texte text) RETURNS tsquery LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $$ SELECT plainto_tsquery('simple'::regconfig,referentiel.fn_normaliser_libelle(p_texte)) $$;
COMMENT ON FUNCTION professionnel.fn_expert_recherche(text) IS 'Requête plein texte paramétrée en configuration simple, casse et espaces normalisés ; les mots courants sont reliés par les synonymes explicites de la référence sélectionnée.';

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Public" AS
SELECT p."IdProfessionnel",p."ExperienceAns",p."ValideProfessionnel",
 jsonb_build_object('ID_Generique',sp."ID_Generique",'NomGenerique',sp."NomGenerique",'AbrGenerique',sp."AbrGenerique") AS "T_GeneriqueSpecialite",
 jsonb_build_object('ID_Generique',t."ID_Generique",'NomGenerique',t."NomGenerique",'AbrGenerique',t."AbrGenerique") AS "T_GeneriqueType",
 jsonb_build_object('IdUser',u."IdUser",'NomUser',u."NomUser",'PrenomUser',u."PrenomUser",'UrlPhoto',u."UrlPhoto") AS "T_Utilisateurs",
 coalesce(aff."Affiliations",'[]'::jsonb) AS "T_Professionnel_Entite",
 p."IdEntiteFk",e."NomEntite",p."IdSecteurFk",coalesce(nullif(s."AbrGenerique",''),s."NomGenerique") AS "Secteur",
 p."TitrePublic",p."PresentationPublique",p."LocalitePublique",p."ContactAutorise",
 coalesce(sk."Competences",'[]'::jsonb) AS "Competences",coalesce(sv."Prestations",'[]'::jsonb) AS "Prestations",
 search."TexteRecherche",to_tsvector('simple'::regconfig,search."TexteRecherche") AS "RechercheVecteur",
 p."IdUserFk",p."IdSpecialiteFk",p."IdTypeProfessionnelFk",btrim(concat_ws(' ',u."PrenomUser",u."NomUser")) AS "NomComplet",
 jsonb_build_object('ID_Generique',s."ID_Generique",'NomGenerique',s."NomGenerique",'AbrGenerique',s."AbrGenerique") AS "T_GeneriqueSecteur"
FROM professionnel."T_Professionnel" p JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUserFk"
 JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk"
 LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique"=p."IdSecteurFk" AND s."ValideGenerique" AND referentiel.fn_reference_visible(s."ID_Generique",p."IdEntiteFk") AND EXISTS(SELECT FROM referentiel."T_CategorieGenerique" c WHERE c."ID_CategorieGenerique"=s."ID_CategorieGeneriqueFk" AND c."ValideCategorieGenerique")
 LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=p."IdTypeProfessionnelFk" AND t."ValideGenerique" AND referentiel.fn_reference_visible(t."ID_Generique",p."IdEntiteFk") AND EXISTS(SELECT FROM referentiel."T_CategorieGenerique" c WHERE c."ID_CategorieGenerique"=t."ID_CategorieGeneriqueFk" AND c."ValideCategorieGenerique")
 LEFT JOIN referentiel."T_Generique" sp ON sp."ID_Generique"=p."IdSpecialiteFk" AND sp."ValideGenerique" AND referentiel.fn_reference_visible(sp."ID_Generique",p."IdEntiteFk") AND EXISTS(SELECT FROM referentiel."T_CategorieGenerique" c WHERE c."ID_CategorieGenerique"=sp."ID_CategorieGeneriqueFk" AND c."ValideCategorieGenerique")
 LEFT JOIN LATERAL(SELECT jsonb_agg(jsonb_build_object('EstPrincipal',l."EstPrincipal",'T_Entite',jsonb_build_object('IdEntite',x."IdEntite",'NomEntite',x."NomEntite",'PhoneEntite',x."PhoneEntite",'AdresseEntite',x."AdresseEntite")) ORDER BY l."EstPrincipal" DESC,l."IdEntiteFk") AS "Affiliations",string_agg(x."NomEntite",' ') AS words FROM professionnel."T_Professionnel_Entite" l JOIN systeme."T_Entite" x ON x."IdEntite"=l."IdEntiteFk" WHERE l."IdProfessionnelFk"=p."IdProfessionnel" AND x."ValideEntite" AND (l."DateDebut" IS NULL OR l."DateDebut"<=localtimestamp) AND (l."DateFin" IS NULL OR l."DateFin">localtimestamp)) aff ON true
 LEFT JOIN LATERAL(SELECT jsonb_agg(jsonb_build_object('ID_Generique',g."ID_Generique",'NomGenerique',g."NomGenerique",'AbrGenerique',g."AbrGenerique") ORDER BY g."NomGenerique",g."ID_Generique") AS "Competences",string_agg(concat_ws(' ',g."NomGenerique",g."AbrGenerique",syn.words),' ') AS words FROM professionnel."T_Professionnel_Competence" l JOIN referentiel."T_Generique" g ON g."ID_Generique"=l."IdCompetenceFk" JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" LEFT JOIN LATERAL(SELECT string_agg(z."Terme",' ') AS words FROM professionnel."T_SynonymeRecherche" z WHERE z."IdGeneriqueFk"=g."ID_Generique" AND z."Actif" AND (z."IdEntiteFk" IS NULL OR z."IdEntiteFk"=p."IdEntiteFk")) syn ON true WHERE l."IdProfessionnelFk"=p."IdProfessionnel" AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND referentiel.fn_reference_visible(g."ID_Generique",p."IdEntiteFk")) sk ON true
 LEFT JOIN LATERAL(SELECT jsonb_agg(jsonb_build_object('ID_Generique',g."ID_Generique",'NomGenerique',g."NomGenerique",'AbrGenerique',g."AbrGenerique") ORDER BY g."NomGenerique",g."ID_Generique") AS "Prestations",string_agg(concat_ws(' ',g."NomGenerique",g."AbrGenerique",syn.words),' ') AS words FROM professionnel."T_Professionnel_Prestation" l JOIN referentiel."T_Generique" g ON g."ID_Generique"=l."IdPrestationFk" JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" LEFT JOIN LATERAL(SELECT string_agg(z."Terme",' ') AS words FROM professionnel."T_SynonymeRecherche" z WHERE z."IdGeneriqueFk"=g."ID_Generique" AND z."Actif" AND (z."IdEntiteFk" IS NULL OR z."IdEntiteFk"=p."IdEntiteFk")) syn ON true WHERE l."IdProfessionnelFk"=p."IdProfessionnel" AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND referentiel.fn_reference_visible(g."ID_Generique",p."IdEntiteFk")) sv ON true
 CROSS JOIN LATERAL(SELECT referentiel.fn_normaliser_libelle(concat_ws(' ',u."NomUser",u."PrenomUser",p."TitrePublic",p."PresentationPublique",p."LocalitePublique",s."NomGenerique",s."AbrGenerique",t."NomGenerique",t."AbrGenerique",sp."NomGenerique",sp."AbrGenerique",sk.words,sv.words,aff.words)) AS "TexteRecherche") search
WHERE p."Publie" AND p."ValideProfessionnel" AND u."ValideUser" AND e."ValideEntite";
COMMENT ON VIEW professionnel."V_Professionnel_Public" IS 'Annuaire transversal publié, actif et lié à un compte/entreprise actifs, une ligne par fiche. Compétences et prestations déclarées, affiliations valables ; sans email/téléphone personnel, numéro professionnel privé, note interne ni donnée RH. Les synonymes appartiennent à la valeur sélectionnée, jamais à un expert supposé.';

-- Compléter toutes les colonnes de vues nouvellement projetées sans laisser un commentaire vide.
DO $$ DECLARE r record;BEGIN
 FOR r IN SELECT c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped WHERE n.nspname='professionnel' AND c.relname IN('V_Professionnel_Registre','V_Professionnel_Public') LOOP
  IF col_description(format('professionnel.%I',r.relname)::regclass,(SELECT attnum FROM pg_attribute WHERE attrelid=format('professionnel.%I',r.relname)::regclass AND attname=r.attname)) IS NULL THEN EXECUTE format('COMMENT ON COLUMN professionnel.%I.%I IS %L',r.relname,r.attname,CASE WHEN r.relname='V_Professionnel_Public' THEN 'Projection publique limitée : ' ELSE 'Projection privée du registre autorisé : ' END||r.attname||'. Issue de la fiche et de ses références centrales, sans effet sur les droits.');END IF;
 END LOOP;
END $$;
COMMIT;
