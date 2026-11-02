-- Caisse par entreprise et devise : journal validé immuable et compensations.
-- Aucun abonnement, fonds ou règlement historique n'est créé implicitement.
BEGIN;

DO $$ BEGIN
 IF EXISTS(SELECT FROM operations."T_Paiement") OR EXISTS(SELECT FROM operations."T_Paiement_Archive")
    OR EXISTS(SELECT FROM operations."T_Caisse" WHERE "IdEntiteFk" IS NULL OR coalesce("MontantCaisse",0)<>0) THEN
  RAISE EXCEPTION 'La reprise des anciennes caisses exige un rapprochement explicite avant cette migration.';
 END IF;
END $$;

ALTER TABLE operations."T_Caisse" DROP CONSTRAINT "UQ_Entite_Devise";
ALTER TABLE operations."T_Caisse" ALTER COLUMN "MontantCaisse" TYPE numeric,
 ALTER COLUMN "MontantCaisse" SET NOT NULL, ALTER COLUMN "IdEntiteFk" SET NOT NULL,
 ADD COLUMN "CodeCaisse" text, ADD COLUMN "NomCaisse" text,
 ADD COLUMN "IdTypeCaisseFk" integer REFERENCES referentiel."T_Generique"("ID_Generique"),
 ADD COLUMN "IdResponsableFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser"),
 ADD COLUMN "Actif" boolean NOT NULL DEFAULT true,
 ADD COLUMN "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 ADD COLUMN "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 ADD COLUMN "Revision" bigint NOT NULL DEFAULT 1,
 ADD COLUMN "CreationRequestId" uuid UNIQUE, ADD COLUMN "CreationPayloadHash" text;
UPDATE operations."T_Caisse" SET "CodeCaisse"='CAI-'||"IdCaisse", "NomCaisse"='Caisse '||"IdCaisse";
ALTER TABLE operations."T_Caisse" ALTER COLUMN "CodeCaisse" SET NOT NULL,
 ALTER COLUMN "NomCaisse" SET NOT NULL,
 ADD CONSTRAINT uq_caisse_code UNIQUE("CodeCaisse"),
 ADD CONSTRAINT ck_caisse_nom CHECK(length(btrim("NomCaisse")) BETWEEN 1 AND 200),
 ADD CONSTRAINT ck_caisse_solde CHECK("MontantCaisse">=0 AND "MontantCaisse"<=9999999999999999.99 AND "MontantCaisse"=round("MontantCaisse",2)),
 ADD CONSTRAINT ck_caisse_revision CHECK("Revision">0),
 ADD CONSTRAINT ck_caisse_creation CHECK(("CreationRequestId" IS NULL)=("CreationPayloadHash" IS NULL) AND ("CreationPayloadHash" IS NULL OR "CreationPayloadHash"~'^[a-f0-9]{64}$'));
ALTER TABLE operations."T_Caisse" DROP CONSTRAINT "Fk_IdEntite";
ALTER TABLE operations."T_Caisse" ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

ALTER TABLE operations."T_Paiement" ALTER COLUMN "MontantPaiement" TYPE numeric,
 ALTER COLUMN "IdTypePaiementFk" DROP NOT NULL,
 ADD COLUMN "IdCaisseFk" integer NOT NULL REFERENCES operations."T_Caisse"("IdCaisse"),
 ADD COLUMN "SensMouvement" smallint NOT NULL,
 ADD COLUMN "EtatEcriture" text NOT NULL DEFAULT 'DRAFT',
 ADD COLUMN "LibellePaiement" text NOT NULL,
 ADD COLUMN "ReferenceExterne" text,
 ADD COLUMN "IdTiersFk" bigint REFERENCES logistique."T_Client"("ID_Client"),
 ADD COLUMN "IdReglementFk" integer UNIQUE REFERENCES logistique."T_Reglements"("ID_Reglement") ON DELETE RESTRICT,
 ADD COLUMN "IdPaiementOrigineFk" integer UNIQUE REFERENCES operations."T_Paiement"("IdPaiement") ON DELETE RESTRICT,
 ADD COLUMN "CreationRequestId" uuid UNIQUE, ADD COLUMN "CreationPayloadHash" text,
 ADD COLUMN "ValidationRequestId" uuid UNIQUE, ADD COLUMN "ValidationPayloadHash" text,
 ADD COLUMN "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 ADD COLUMN "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 ADD COLUMN "ValideLe" timestamptz, ADD COLUMN "IdValidateurFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser"),
 ADD COLUMN "Revision" bigint NOT NULL DEFAULT 1,
 ADD COLUMN "DeviseCodeSnapshot" text,
 ADD CONSTRAINT uq_paiement_code UNIQUE("CodePaiement"),
 ADD CONSTRAINT ck_paiement_centimes CHECK("MontantPaiement"=round("MontantPaiement",2) AND "MontantPaiement"<=9999999999999999.99),
 ADD CONSTRAINT ck_paiement_sens CHECK("SensMouvement" IN(-1,1)),
 ADD CONSTRAINT ck_paiement_etat CHECK("EtatEcriture" IN('DRAFT','POSTED')),
 ADD CONSTRAINT ck_paiement_libelle CHECK(length(btrim("LibellePaiement")) BETWEEN 1 AND 500),
 ADD CONSTRAINT ck_paiement_revision CHECK("Revision">0),
 ADD CONSTRAINT ck_paiement_validation CHECK(("EtatEcriture"='POSTED')=("ValideLe" IS NOT NULL AND "IdValidateurFk" IS NOT NULL AND "DeviseCodeSnapshot" IS NOT NULL) AND ("EtatEcriture"<>'POSTED' OR "ValidePaiement")),
 ADD CONSTRAINT ck_paiement_creation CHECK(("CreationRequestId" IS NULL)=("CreationPayloadHash" IS NULL) AND ("CreationPayloadHash" IS NULL OR "CreationPayloadHash"~'^[a-f0-9]{64}$')),
 ADD CONSTRAINT ck_paiement_rejeu_validation CHECK(("ValidationRequestId" IS NULL)=("ValidationPayloadHash" IS NULL) AND ("ValidationPayloadHash" IS NULL OR "ValidationPayloadHash"~'^[a-f0-9]{64}$'));
ALTER TABLE operations."T_Paiement" DROP CONSTRAINT "Fk_IdEntite";
ALTER TABLE operations."T_Paiement" ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;
ALTER TABLE operations."T_Paiement" ADD CONSTRAINT fk_paiement_statut FOREIGN KEY("IdStatutPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique"),
 ADD CONSTRAINT fk_paiement_type_mouvement FOREIGN KEY("IdTypeMouvementFk") REFERENCES referentiel."T_Generique"("ID_Generique");

CREATE TABLE operations."T_ClotureCaisse"(
 "ID_ClotureCaisse" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdCaisseFk" integer NOT NULL REFERENCES operations."T_Caisse"("IdCaisse") ON DELETE RESTRICT,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "IdDeviseFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique"),
 "ClotureLe" timestamptz NOT NULL, "SoldeTheorique" numeric NOT NULL,
 "MontantCompte" numeric NOT NULL, "Ecart" numeric GENERATED ALWAYS AS ("MontantCompte"-"SoldeTheorique") STORED,
 "Motif" text, "IdUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser"),
 "CreationRequestId" uuid UNIQUE NOT NULL, "CreationPayloadHash" text NOT NULL,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT ck_cloture_centimes CHECK("MontantCompte">=0 AND "MontantCompte"<=9999999999999999.99 AND "MontantCompte"=round("MontantCompte",2)),
 CONSTRAINT ck_cloture_motif CHECK("MontantCompte"="SoldeTheorique" OR coalesce(length(btrim("Motif")),0)>0),
 CONSTRAINT ck_cloture_hash CHECK("CreationPayloadHash"~'^[a-f0-9]{64}$')
);

-- Les suppressions en cascade d'un responsable ne doivent pas effacer l'histoire.
CREATE INDEX ix_paiement_caisse_etat_date ON operations."T_Paiement"("IdCaisseFk","EtatEcriture","DatePaiement","IdPaiement");
CREATE INDEX ix_paiement_entite_date ON operations."T_Paiement"("IdEntiteFk","DatePaiement" DESC);
CREATE INDEX ix_cloture_caisse_date ON operations."T_ClotureCaisse"("IdCaisseFk","ClotureLe" DESC);

-- Les effets historiques à identifiants fixes sont remplacés par le journal.
DROP TRIGGER trigger_gestion_caisse_on_paiement ON operations."T_Paiement";
DROP TRIGGER trigger_notification_payment_success ON operations."T_Paiement";
-- L'archive ancienne est préservée mais ne reçoit plus de déplacement automatique.
ALTER TABLE operations."T_Paiement" DISABLE TRIGGER trigger_archive_paiements;

-- Compléter uniquement le défaut auparavant inconnu ; les surcharges restent intactes.
ALTER TABLE referentiel."T_ChampReferentiel" DISABLE TRIGGER tr_catalogue_champ_integrite;
DO $$ DECLARE family integer; r record; BEGIN
 UPDATE referentiel."T_ChampReferentiel" SET "ModuleName"='caisse'
  WHERE "SchemaName"='operations' AND "TableName" IN('T_Caisse','T_Paiement');
 SELECT "ID_CategorieGenerique" INTO STRICT family FROM referentiel."T_CategorieGenerique" WHERE "NomCategorieGenerique"='Type paiement' AND "IdEntiteFk" IS NULL;
 UPDATE referentiel."T_ChampReferentiel" SET "ID_CategorieDefautFk"=family WHERE "SchemaName"='operations' AND "TableName"='T_Paiement' AND "ColumnName"='IdTypePaiementFk' AND "ID_CategorieDefautFk" IS NULL;
 FOR r IN SELECT * FROM (VALUES('T_Caisse','IdTypeCaisseFk','Type de caisse','Type de caisse'),('T_Paiement','IdTypeMouvementFk','Sens du mouvement','Type mouvement paiement'),('T_Paiement','IdStatutPaiementFk','Statut historique','Statut paiement')) t(tab,col,label,familyname) LOOP
  SELECT "ID_CategorieGenerique" INTO STRICT family FROM referentiel."T_CategorieGenerique" WHERE "NomCategorieGenerique"=r.familyname AND "IdEntiteFk" IS NULL;
  INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName","ID_CategorieDefautFk","CanConfigure","SupportsEntityScope") VALUES('operations',r.tab,r.col,r.label,'caisse',family,true,true) ON CONFLICT("SchemaName","TableName","ColumnName") DO NOTHING;
 END LOOP;
 SELECT "ID_CategorieGenerique" INTO STRICT family FROM referentiel."T_CategorieGenerique" WHERE "NomCategorieGenerique"='Type paiement' AND "IdEntiteFk" IS NULL;
 FOR r IN SELECT * FROM (VALUES('Recette diverse','CAISSE_RECETTE'),('Dépense diverse','CAISSE_DEPENSE'),('Règlement de facture','CAISSE_REGLEMENT')) v(label,code) LOOP
  IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=family AND "AbrGenerique"=r.code AND "IdEntiteFk" IS NULL) THEN
   INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(family,r.label,r.code,true);
  END IF;
 END LOOP;
END $$;
ALTER TABLE referentiel."T_ChampReferentiel" ENABLE TRIGGER tr_catalogue_champ_integrite;

CREATE FUNCTION operations.fn_caisse_actor(p_actor integer,p_entite integer) RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=p_actor AND u."ValideUser" AND (u."Is_Admin" OR u."IdEntiteFk"=p_entite))
$$;
CREATE FUNCTION operations.fn_caisse_sens_type(p_type integer) RETURNS smallint LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT CASE translate(lower(btrim(g."AbrGenerique")),'éèêàâîïôùûç','eeeaaiiouuc') WHEN 'entree' THEN 1 WHEN 'sortie' THEN -1 ELSE NULL END::smallint FROM referentiel."T_Generique" g WHERE g."ID_Generique"=p_type
$$;

CREATE FUNCTION operations.tr_caisse_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une caisse est archivée, jamais supprimée.' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" AND "ValideEntite") THEN RAISE EXCEPTION 'Entreprise de caisse inactive ou absente.' USING ERRCODE='23514';END IF;
 IF (TG_OP='INSERT' OR NEW."IdResponsableFk" IS DISTINCT FROM OLD."IdResponsableFk") AND NEW."IdResponsableFk" IS NOT NULL AND NOT operations.fn_caisse_actor(NEW."IdResponsableFk",NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Responsable hors entreprise ou inactif.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  IF coalesce(NEW."MontantCaisse",0)<>0 THEN RAISE EXCEPTION 'Le solde d’ouverture passe par une entrée validée, jamais par la fiche caisse.' USING ERRCODE='23514';END IF;
  NEW."CodeCaisse":='CAI-'||NEW."IdCaisse";NEW."MontantCaisse":=0;NEW."CreeLe":=clock_timestamp();NEW."Revision":=1;
 ELSE
  IF NEW."IdEntiteFk"<>OLD."IdEntiteFk" OR NEW."IdDeviseFk"<>OLD."IdDeviseFk" OR NEW."CodeCaisse"<>OLD."CodeCaisse" OR NEW."IdCaisse"<>OLD."IdCaisse" OR NEW."CreationRequestId" IS DISTINCT FROM OLD."CreationRequestId" OR NEW."CreationPayloadHash" IS DISTINCT FROM OLD."CreationPayloadHash" THEN RAISE EXCEPTION 'Identité, entreprise et devise de caisse sont conservées.' USING ERRCODE='23514';END IF;
  IF NOT NEW."Actif" AND OLD."Actif" AND EXISTS(SELECT FROM operations."T_Paiement" WHERE "IdCaisseFk"=OLD."IdCaisse" AND "EtatEcriture"='DRAFT' AND "ValidePaiement") THEN RAISE EXCEPTION 'Traitez les brouillons avant d’archiver la caisse.' USING ERRCODE='23514';END IF;
  IF NOT NEW."Actif" AND OLD."Actif" AND OLD."MontantCaisse"<>0 THEN RAISE EXCEPTION 'Le solde de caisse doit être nul avant archivage.' USING ERRCODE='23514';END IF;
  NEW."CreeLe":=OLD."CreeLe";NEW."Revision":=OLD."Revision"+1;
 END IF;
 NEW."ModifieLe":=clock_timestamp();RETURN NEW;
END $$;
CREATE TRIGGER ab_caisse_integrite BEFORE INSERT OR UPDATE OR DELETE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_integrite();

CREATE FUNCTION operations.tr_paiement_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cash operations."T_Caisse";origin operations."T_Paiement";reg record;direction smallint;lastclose timestamptz;BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une écriture de caisse ne se supprime pas ; archivez le brouillon ou contre-passez la validation.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND OLD."EtatEcriture"='POSTED' THEN RAISE EXCEPTION 'Une écriture validée est immuable ; utilisez une contrepassation.' USING ERRCODE='23514';END IF;
 SELECT * INTO STRICT cash FROM operations."T_Caisse" WHERE "IdCaisse"=NEW."IdCaisseFk" FOR UPDATE;
 IF NOT cash."Actif" OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=cash."IdEntiteFk" AND "ValideEntite") THEN RAISE EXCEPTION 'Cette caisse ou entreprise est inactive.' USING ERRCODE='23514';END IF;
 NEW."IdEntiteFk":=cash."IdEntiteFk";NEW."IdDeviseFk":=cash."IdDeviseFk";
 IF NOT operations.fn_caisse_actor(NEW."IdUserFk",NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Auteur hors entreprise ou inactif.' USING ERRCODE='23514';END IF;
 IF NEW."IdPayeurFk" IS NOT NULL AND NOT operations.fn_caisse_actor(NEW."IdPayeurFk",NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Payeur hors entreprise ou inactif.' USING ERRCODE='23514';END IF;
 IF NEW."IdTiersFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Client" WHERE "ID_Client"=NEW."IdTiersFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Tiers hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."DatePaiement" IS NULL OR NOT isfinite(NEW."DatePaiement") OR NEW."DatePaiement">clock_timestamp()+interval '5 seconds' THEN RAISE EXCEPTION 'La date de caisse doit être renseignée, finie et non future.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  NEW."CodePaiement":='MVT-'||NEW."IdPaiement";NEW."CreeLe":=clock_timestamp();NEW."Revision":=1;
 ELSE
  IF (NEW."IdPaiement",NEW."IdCaisseFk",NEW."IdUserFk",NEW."CreationRequestId",NEW."CreationPayloadHash",NEW."IdPaiementOrigineFk",NEW."IdReglementFk") IS DISTINCT FROM (OLD."IdPaiement",OLD."IdCaisseFk",OLD."IdUserFk",OLD."CreationRequestId",OLD."CreationPayloadHash",OLD."IdPaiementOrigineFk",OLD."IdReglementFk") THEN RAISE EXCEPTION 'Identité et rattachements de l’écriture sont conservés.' USING ERRCODE='23514';END IF;
  IF NOT OLD."ValidePaiement" THEN RAISE EXCEPTION 'Le brouillon archivé est conservé.' USING ERRCODE='23514';END IF;
  NEW."CodePaiement":=OLD."CodePaiement";NEW."CreeLe":=OLD."CreeLe";NEW."Revision":=OLD."Revision"+1;
 END IF;
 NEW."ModifieLe":=clock_timestamp();
 IF NEW."IdTypeMouvementFk" IS NOT NULL THEN
  direction:=operations.fn_caisse_sens_type(NEW."IdTypeMouvementFk");
  IF direction IS NULL OR direction<>NEW."SensMouvement" THEN RAISE EXCEPTION 'Le sens du type de mouvement ne correspond pas à l’écriture.' USING ERRCODE='23514';END IF;
 END IF;
 IF NEW."IdPaiementOrigineFk" IS NOT NULL THEN
  SELECT * INTO STRICT origin FROM operations."T_Paiement" WHERE "IdPaiement"=NEW."IdPaiementOrigineFk" FOR UPDATE;
  IF origin."EtatEcriture"<>'POSTED' OR origin."IdReglementFk" IS NOT NULL OR origin."IdPaiementOrigineFk" IS NOT NULL OR origin."IdCaisseFk"<>NEW."IdCaisseFk" OR NEW."SensMouvement"<>-origin."SensMouvement" OR NEW."MontantPaiement"<>origin."MontantPaiement" OR NEW."EtatEcriture"<>'POSTED' OR length(btrim(coalesce(NEW."ObsPaiement",'')))=0 THEN RAISE EXCEPTION 'La compensation exige l’écriture d’origine, le même montant, le sens inverse et un motif ; un règlement lié suit son circuit financier.' USING ERRCODE='23514';END IF;
 END IF;
 IF NEW."IdReglementFk" IS NOT NULL THEN
  SELECT r."MontantRegle",r."ID_DeviseFk",f."IdEntiteFk" INTO STRICT reg FROM logistique."T_Reglements" r JOIN logistique."T_Facture" f ON f."CodeFacture"=r."CodeFactureFk" WHERE r."ID_Reglement"=NEW."IdReglementFk" FOR UPDATE OF r;
  IF NEW."EtatEcriture"<>'POSTED' OR NEW."SensMouvement"<>1 OR NEW."MontantPaiement"<>reg."MontantRegle" OR NEW."IdDeviseFk"<>reg."ID_DeviseFk" OR NEW."IdEntiteFk"<>reg."IdEntiteFk" THEN RAISE EXCEPTION 'Règlement et entrée de caisse doivent avoir la même entreprise, devise et montant.' USING ERRCODE='23514';END IF;
 END IF;
 IF NEW."EtatEcriture"='POSTED' THEN
  IF NOT NEW."ValidePaiement" OR NOT operations.fn_caisse_actor(NEW."IdValidateurFk",NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Validation et validateur autorisé dans l’entreprise requis.' USING ERRCODE='23514';END IF;
  SELECT max("ClotureLe") INTO lastclose FROM operations."T_ClotureCaisse" WHERE "IdCaisseFk"=NEW."IdCaisseFk";
  IF lastclose IS NOT NULL AND NEW."DatePaiement"<=lastclose THEN RAISE EXCEPTION 'Une clôture interdit cette écriture antidatée.' USING ERRCODE='23514';END IF;
  IF cash."MontantCaisse"+NEW."SensMouvement"*NEW."MontantPaiement"<0 THEN RAISE EXCEPTION 'Solde de caisse insuffisant.' USING ERRCODE='23514';END IF;
  NEW."ValideLe":=clock_timestamp();
  SELECT coalesce(nullif(btrim("AbrGenerique"),''),"NomGenerique") INTO STRICT NEW."DeviseCodeSnapshot" FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."IdDeviseFk";
 ELSE
  NEW."ValideLe":=NULL;NEW."IdValidateurFk":=NULL;NEW."DeviseCodeSnapshot":=NULL;NEW."ValidationRequestId":=NULL;NEW."ValidationPayloadHash":=NULL;
 END IF;
 RETURN NEW;
END $$;
-- aa_owners précède le validateur commun des références : propriétaire dérivé du parent.
CREATE TRIGGER aa_owners_paiement BEFORE INSERT OR UPDATE OR DELETE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.tr_paiement_integrite();

CREATE OR REPLACE FUNCTION operations.gestion_caisse_on_paiement() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW."EtatEcriture"='POSTED' AND (TG_OP='INSERT' OR OLD."EtatEcriture"='DRAFT') THEN
  UPDATE operations."T_Caisse" SET "MontantCaisse"="MontantCaisse"+NEW."SensMouvement"*NEW."MontantPaiement" WHERE "IdCaisse"=NEW."IdCaisseFk";
 END IF;RETURN NEW;
END $$;
CREATE TRIGGER trigger_gestion_caisse_on_paiement AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.gestion_caisse_on_paiement();

CREATE FUNCTION operations.tr_caisse_solde_rapproche() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE theoretical numeric;currentbalance numeric;BEGIN
 SELECT coalesce(sum("SensMouvement"*"MontantPaiement") FILTER(WHERE "EtatEcriture"='POSTED'),0) INTO theoretical FROM operations."T_Paiement" WHERE "IdCaisseFk"=NEW."IdCaisse";
 SELECT "MontantCaisse" INTO currentbalance FROM operations."T_Caisse" WHERE "IdCaisse"=NEW."IdCaisse";
 IF currentbalance IS DISTINCT FROM theoretical THEN RAISE EXCEPTION 'Le solde doit correspondre au journal validé de la caisse.' USING ERRCODE='23514';END IF;RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER ck_caisse_journal AFTER INSERT OR UPDATE ON operations."T_Caisse" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_solde_rapproche();

CREATE FUNCTION operations.tr_cloture_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cash operations."T_Caisse";latest timestamptz;BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'La clôture est immuable.' USING ERRCODE='23514';END IF;
 SELECT * INTO STRICT cash FROM operations."T_Caisse" WHERE "IdCaisse"=NEW."IdCaisseFk" FOR UPDATE;
 IF NOT cash."Actif" OR NOT operations.fn_caisse_actor(NEW."IdUserFk",cash."IdEntiteFk") OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=cash."IdEntiteFk" AND "ValideEntite") THEN RAISE EXCEPTION 'Caisse, entreprise actives et auteur de l’entreprise requis.' USING ERRCODE='23514';END IF;
 SELECT greatest((SELECT max("ClotureLe") FROM operations."T_ClotureCaisse" WHERE "IdCaisseFk"=NEW."IdCaisseFk"),(SELECT max("DatePaiement") FROM operations."T_Paiement" WHERE "IdCaisseFk"=NEW."IdCaisseFk" AND "EtatEcriture"='POSTED')) INTO latest;
 IF NEW."ClotureLe" IS NULL OR NOT isfinite(NEW."ClotureLe") OR NEW."ClotureLe">clock_timestamp()+interval '5 seconds' OR (latest IS NOT NULL AND NEW."ClotureLe"<=latest) THEN RAISE EXCEPTION 'La clôture doit suivre les écritures et clôtures précédentes, sans date future.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT FROM operations."T_Paiement" WHERE "IdCaisseFk"=NEW."IdCaisseFk" AND "EtatEcriture"='DRAFT' AND "ValidePaiement" AND "DatePaiement"<=NEW."ClotureLe") THEN RAISE EXCEPTION 'Traitez ou archivez les brouillons avant de clôturer.' USING ERRCODE='23514';END IF;
 NEW."IdEntiteFk":=cash."IdEntiteFk";NEW."IdDeviseFk":=cash."IdDeviseFk";NEW."SoldeTheorique":=cash."MontantCaisse";NEW."CreeLe":=clock_timestamp();RETURN NEW;
END $$;
CREATE TRIGGER aa_cloture_integrite BEFORE INSERT OR UPDATE OR DELETE ON operations."T_ClotureCaisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_cloture_integrite();

CREATE FUNCTION operations.tr_reglement_caisse_protege() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT FROM operations."T_Paiement" WHERE "IdReglementFk"=OLD."ID_Reglement") THEN RAISE EXCEPTION 'Ce règlement est lié au journal de caisse ; une correction financière dédiée est nécessaire.' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;
CREATE TRIGGER aa_reglement_caisse_protege BEFORE UPDATE OR DELETE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION operations.tr_reglement_caisse_protege();

CREATE FUNCTION operations.fn_caisse_valider(p_id integer,p_actor integer,p_motif text,p_request uuid,p_hash text,p_revision bigint) RETURNS integer LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE r operations."T_Paiement";BEGIN
 SELECT * INTO STRICT r FROM operations."T_Paiement" WHERE "IdPaiement"=p_id FOR UPDATE;
 IF p_request IS NULL OR p_hash IS NULL OR p_hash!~'^[a-f0-9]{64}$' OR NOT operations.fn_caisse_actor(p_actor,r."IdEntiteFk") OR length(btrim(coalesce(p_motif,'')))=0 THEN RAISE EXCEPTION 'Acteur, motif et demande valide requis.' USING ERRCODE='23514';END IF;
 IF r."EtatEcriture"='POSTED' THEN
  IF r."ValidationRequestId"=p_request AND r."ValidationPayloadHash"=p_hash AND r."IdValidateurFk"=p_actor THEN RETURN p_id;END IF;
  RAISE EXCEPTION 'Écriture déjà validée.' USING ERRCODE='23514';
 END IF;
 IF r."Revision" IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'La révision de l’écriture a changé.' USING ERRCODE='40001';END IF;
 UPDATE operations."T_Paiement" SET "EtatEcriture"='POSTED',"IdValidateurFk"=p_actor,"ValidationRequestId"=p_request,"ValidationPayloadHash"=p_hash,"ObsPaiement"=concat_ws(E'\n',nullif("ObsPaiement",''),'Validation : '||p_motif) WHERE "IdPaiement"=p_id;
 RETURN p_id;
END $$;
CREATE FUNCTION operations.fn_caisse_contrepasser(p_id integer,p_actor integer,p_motif text,p_request uuid,p_hash text,p_revision bigint) RETURNS integer LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE r operations."T_Paiement";existing operations."T_Paiement";result integer;BEGIN
 SELECT * INTO STRICT r FROM operations."T_Paiement" WHERE "IdPaiement"=p_id FOR UPDATE;
 IF p_request IS NULL OR p_hash IS NULL OR p_hash!~'^[a-f0-9]{64}$' OR NOT operations.fn_caisse_actor(p_actor,r."IdEntiteFk") OR length(btrim(coalesce(p_motif,'')))=0 THEN RAISE EXCEPTION 'Acteur, motif et demande valide requis.' USING ERRCODE='23514';END IF;
 SELECT * INTO existing FROM operations."T_Paiement" WHERE "IdPaiementOrigineFk"=p_id;
 IF FOUND THEN
  IF existing."CreationRequestId"=p_request AND existing."CreationPayloadHash"=p_hash AND existing."IdUserFk"=p_actor THEN RETURN existing."IdPaiement";END IF;
  RAISE EXCEPTION 'Écriture déjà contre-passée.' USING ERRCODE='23514';
 END IF;
 IF r."EtatEcriture"<>'POSTED' OR r."Revision" IS DISTINCT FROM p_revision OR r."IdReglementFk" IS NOT NULL OR r."IdPaiementOrigineFk" IS NOT NULL THEN RAISE EXCEPTION 'Cette écriture ne peut pas être contre-passée directement.' USING ERRCODE='23514';END IF;
 INSERT INTO operations."T_Paiement"("IdUserFk","IdTypePaiementFk","MontantPaiement","DatePaiement","ObsPaiement","IdDeviseFk","IdEntiteFk","IdCaisseFk","SensMouvement","EtatEcriture","LibellePaiement","ReferenceExterne","IdTiersFk","IdPaiementOrigineFk","CreationRequestId","CreationPayloadHash","IdValidateurFk","ValidationRequestId","ValidationPayloadHash")
 VALUES(p_actor,NULL,r."MontantPaiement",clock_timestamp(),p_motif,r."IdDeviseFk",r."IdEntiteFk",r."IdCaisseFk",-r."SensMouvement",'POSTED','Contrepassation de '||r."CodePaiement",r."ReferenceExterne",r."IdTiersFk",p_id,p_request,p_hash,p_actor,p_request,p_hash) RETURNING "IdPaiement" INTO result;
 RETURN result;
END $$;
CREATE FUNCTION operations.fn_caisse_cloturer(p_caisse integer,p_actor integer,p_date timestamptz,p_compte numeric,p_motif text,p_request uuid,p_hash text,p_revision bigint) RETURNS bigint LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cash operations."T_Caisse";r operations."T_ClotureCaisse";result bigint;BEGIN
 SELECT * INTO STRICT cash FROM operations."T_Caisse" WHERE "IdCaisse"=p_caisse FOR UPDATE;
 IF p_request IS NULL OR p_hash IS NULL OR p_hash!~'^[a-f0-9]{64}$' OR NOT operations.fn_caisse_actor(p_actor,cash."IdEntiteFk") THEN RAISE EXCEPTION 'Acteur et demande valide requis.' USING ERRCODE='23514';END IF;
 SELECT * INTO r FROM operations."T_ClotureCaisse" WHERE "CreationRequestId"=p_request;
 IF FOUND THEN
  IF r."CreationPayloadHash"=p_hash AND r."IdUserFk"=p_actor AND r."IdCaisseFk"=p_caisse THEN RETURN r."ID_ClotureCaisse";END IF;
  RAISE EXCEPTION 'La demande de clôture a déjà un autre contenu.' USING ERRCODE='23514';
 END IF;
 IF cash."Revision" IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'Le solde de caisse a changé.' USING ERRCODE='40001';END IF;
 INSERT INTO operations."T_ClotureCaisse"("IdCaisseFk","IdEntiteFk","IdDeviseFk","ClotureLe","SoldeTheorique","MontantCompte","Motif","IdUserFk","CreationRequestId","CreationPayloadHash") VALUES(p_caisse,cash."IdEntiteFk",cash."IdDeviseFk",p_date,cash."MontantCaisse",p_compte,p_motif,p_actor,p_request,p_hash) RETURNING "ID_ClotureCaisse" INTO result;
 UPDATE operations."T_Caisse" SET "ModifieLe"=clock_timestamp() WHERE "IdCaisse"=p_caisse;
 RETURN result;
END $$;

CREATE VIEW operations."V_Caisse" AS
 SELECT c.*,e."NomEntite",coalesce(nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",g."NomGenerique"::text "DeviseLibelle",t."NomGenerique"::text "TypeCaisse",concat_ws(' ',u."PrenomUser",u."NomUser")::text "Responsable",
 coalesce(p.balance,0)::numeric "SoldeTheorique",(c."MontantCaisse"-coalesce(p.balance,0))::numeric "EcartsRapprochement",coalesce(p.n,0)::bigint "NombreEcritures",coalesce(p.d,0)::bigint "NbBrouillons",cl.lastdate "DerniereClotureLe"
 FROM operations."T_Caisse" c JOIN systeme."T_Entite" e ON e."IdEntite"=c."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."IdDeviseFk" LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=c."IdTypeCaisseFk" LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."IdResponsableFk"
 LEFT JOIN LATERAL(SELECT sum("SensMouvement"*"MontantPaiement") FILTER(WHERE "EtatEcriture"='POSTED') balance,count(*) FILTER(WHERE "EtatEcriture"='POSTED') n,count(*) FILTER(WHERE "EtatEcriture"='DRAFT' AND "ValidePaiement") d FROM operations."T_Paiement" WHERE "IdCaisseFk"=c."IdCaisse") p ON true
 LEFT JOIN LATERAL(SELECT max("ClotureLe") lastdate FROM operations."T_ClotureCaisse" WHERE "IdCaisseFk"=c."IdCaisse") cl ON true;
CREATE VIEW operations."V_JournalCaisse" AS
 SELECT p.*,c."CodeCaisse",c."NomCaisse",e."NomEntite",coalesce(p."DeviseCodeSnapshot",nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",g."NomGenerique"::text "DeviseLibelle",t."NomGenerique"::text "TypePaiement",tiers."Nom"::text "NomTiers",concat_ws(' ',u."PrenomUser",u."NomUser")::text "Auteur",concat_ws(' ',v."PrenomUser",v."NomUser")::text "Validateur",r."CodeFactureFk",o."CodePaiement" "CodePaiementOrigine",cp."IdPaiement" "IdCompensateurFk",cp."CodePaiement" "CodeCompensateur",
 (CASE WHEN p."EtatEcriture"='POSTED' THEN p."SensMouvement"*p."MontantPaiement" ELSE 0 END)::numeric "MontantSigne",
 (CASE WHEN p."EtatEcriture"='POSTED' THEN sum(CASE WHEN p."EtatEcriture"='POSTED' THEN p."SensMouvement"*p."MontantPaiement" ELSE 0 END) OVER(PARTITION BY p."IdCaisseFk" ORDER BY p."ValideLe",p."IdPaiement" ROWS UNBOUNDED PRECEDING) END)::numeric "SoldeApres"
 FROM operations."T_Paiement" p JOIN operations."T_Caisse" c ON c."IdCaisse"=p."IdCaisseFk" JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=p."IdDeviseFk" LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=p."IdTypePaiementFk" LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUserFk" LEFT JOIN systeme."T_Utilisateurs" v ON v."IdUser"=p."IdValidateurFk" LEFT JOIN logistique."T_Client" tiers ON tiers."ID_Client"=p."IdTiersFk" LEFT JOIN logistique."T_Reglements" r ON r."ID_Reglement"=p."IdReglementFk" LEFT JOIN operations."T_Paiement" o ON o."IdPaiement"=p."IdPaiementOrigineFk" LEFT JOIN operations."T_Paiement" cp ON cp."IdPaiementOrigineFk"=p."IdPaiement";
CREATE VIEW operations."V_FluxCaisseJournalier" AS SELECT (p."DatePaiement" AT TIME ZONE 'Africa/Kinshasa')::date "DateJour",p."IdEntiteFk",p."IdCaisseFk",p."IdDeviseFk",c."NomCaisse",c."CodeCaisse",e."NomEntite",coalesce(nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",coalesce(sum(p."MontantPaiement") FILTER(WHERE p."SensMouvement"=1),0) "MontantEntree",coalesce(sum(p."MontantPaiement") FILTER(WHERE p."SensMouvement"=-1),0) "MontantSortie",sum(p."SensMouvement"*p."MontantPaiement") "NetJour",count(*) "NbEcritures" FROM operations."T_Paiement" p JOIN operations."T_Caisse" c ON c."IdCaisse"=p."IdCaisseFk" JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=p."IdDeviseFk" WHERE p."EtatEcriture"='POSTED' GROUP BY 1,2,3,4,5,6,7,8;
CREATE VIEW operations."V_ClotureCaisse" AS SELECT cl.*,c."CodeCaisse",c."NomCaisse",e."NomEntite",coalesce(nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",concat_ws(' ',u."PrenomUser",u."NomUser")::text "Auteur" FROM operations."T_ClotureCaisse" cl JOIN operations."T_Caisse" c ON c."IdCaisse"=cl."IdCaisseFk" JOIN systeme."T_Entite" e ON e."IdEntite"=cl."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=cl."IdDeviseFk" LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=cl."IdUserFk";

-- Les fonctions d'audit historiques deviennent des projections du journal unique.
CREATE OR REPLACE FUNCTION operations.fn_audit_caisse(p_id_entite integer DEFAULT NULL,p_id_devise integer DEFAULT NULL,p_date_max timestamp without time zone DEFAULT NULL) RETURNS TABLE("IdEntite" integer,"NomEntite" character varying,"IdDevise" integer,"NomDevise" character varying,"SoldeCaisse" numeric,"SoldeTheorique" numeric,"Ecart" numeric,"NbPaiements" integer,"MontantEntree" numeric,"MontantSortie" numeric) LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT c."IdEntiteFk",c."NomEntite"::varchar,c."IdDeviseFk",c."DeviseLibelle"::varchar,sum(c."MontantCaisse"),coalesce(sum(x.balance),0),CASE WHEN p_date_max IS NULL THEN sum(c."MontantCaisse")-coalesce(sum(x.balance),0) ELSE NULL END,coalesce(sum(x.n),0)::integer,coalesce(sum(x.entree),0),coalesce(sum(x.sortie),0)
 FROM operations."V_Caisse" c
 LEFT JOIN LATERAL(SELECT coalesce(sum("SensMouvement"*"MontantPaiement"),0) balance,sum("MontantPaiement") FILTER(WHERE "SensMouvement"=1) entree,sum("MontantPaiement") FILTER(WHERE "SensMouvement"=-1) sortie,count(*) n FROM operations."T_Paiement" WHERE "IdCaisseFk"=c."IdCaisse" AND "EtatEcriture"='POSTED' AND (p_date_max IS NULL OR "DatePaiement"<=p_date_max AT TIME ZONE 'Africa/Kinshasa')) x ON true
 WHERE (p_id_entite IS NULL OR c."IdEntiteFk"=p_id_entite) AND (p_id_devise IS NULL OR c."IdDeviseFk"=p_id_devise)
 GROUP BY c."IdEntiteFk",c."NomEntite",c."IdDeviseFk",c."DeviseLibelle"
$$;
CREATE OR REPLACE FUNCTION operations.fn_audit_flux_caisse(p_id_entite integer DEFAULT NULL,p_id_devise integer DEFAULT NULL,p_date_min timestamp without time zone DEFAULT NULL,p_date_max timestamp without time zone DEFAULT NULL) RETURNS TABLE("DateJour" timestamp without time zone,"IdEntite" integer,"NomEntite" character varying,"IdDevise" integer,"NomDevise" character varying,"MontantEntree" numeric,"MontantSortie" numeric,"NetJour" numeric) LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT date_trunc('day',p."DatePaiement" AT TIME ZONE 'Africa/Kinshasa'),p."IdEntiteFk",e."NomEntite",p."IdDeviseFk",g."NomGenerique",coalesce(sum(p."MontantPaiement") FILTER(WHERE p."SensMouvement"=1),0),coalesce(sum(p."MontantPaiement") FILTER(WHERE p."SensMouvement"=-1),0),sum(p."SensMouvement"*p."MontantPaiement") FROM operations."T_Paiement" p JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=p."IdDeviseFk" WHERE p."EtatEcriture"='POSTED' AND (p_id_entite IS NULL OR p."IdEntiteFk"=p_id_entite) AND (p_id_devise IS NULL OR p."IdDeviseFk"=p_id_devise) AND (p_date_min IS NULL OR p."DatePaiement">=p_date_min AT TIME ZONE 'Africa/Kinshasa') AND (p_date_max IS NULL OR p."DatePaiement"<=p_date_max AT TIME ZONE 'Africa/Kinshasa') GROUP BY 1,2,3,4,5
$$;

CREATE FUNCTION operations.tr_caisse_audit() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE before_row jsonb;after_row jsonb;entity_id integer;actor integer:=systeme.fn_admin_actor_user_id();
 request_id text:=nullif(current_setting('operations.request_id',true),'');
 payload_hash text:=nullif(current_setting('operations.payload_hash',true),'');extra jsonb;
BEGIN
 extra:=jsonb_build_object('_actor',jsonb_build_object('IdUser',actor));
 IF request_id IS NOT NULL AND payload_hash IS NOT NULL AND payload_hash~'^[a-f0-9]{64}$' THEN
  PERFORM request_id::uuid;extra:=extra||jsonb_build_object('_requestId',request_id,'_payloadHash',payload_hash);
 END IF;
 IF TG_OP IN('DELETE','UPDATE') THEN before_row:=systeme.fn_audit_sans_secrets(to_jsonb(OLD))||extra;END IF;
 IF TG_OP IN('INSERT','UPDATE') THEN after_row:=systeme.fn_audit_sans_secrets(to_jsonb(NEW))||extra;END IF;
 entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk") VALUES(TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME,TG_OP,before_row,after_row,current_timestamp,entity_id);
 RETURN NULL;
END $$;
DROP TRIGGER "trigger_audit_T_Paiement" ON operations."T_Paiement";
CREATE TRIGGER "trigger_audit_T_Paiement" AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_audit();
CREATE TRIGGER "trigger_audit_T_Caisse" AFTER INSERT OR UPDATE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_audit();
CREATE TRIGGER "trigger_audit_T_ClotureCaisse" AFTER INSERT ON operations."T_ClotureCaisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_audit();
COMMENT ON FUNCTION operations.tr_caisse_audit() IS 'Un seul événement SQL par changement de caisse/journal/clôture ; images nettoyées, auteur et preuve transactionnelle de demande pour rejouer les mises à jour sans duplication. Les GUC sont des métadonnées et ne donnent aucun droit.';

INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom","EstSocle","CodeIncluant","Actif","Ordre") VALUES('caisse','Caisse',false,NULL,true,75) ON CONFLICT("CodeModule") DO UPDATE SET "Nom"=EXCLUDED."Nom","Actif"=true;
ALTER TABLE referentiel."T_InterfaceTableau" DROP CONSTRAINT ck_interface_tableau_module;
ALTER TABLE referentiel."T_InterfaceTableau" ADD CONSTRAINT ck_interface_tableau_module CHECK("Module" IN('logistique','referentiels','administration','territoires','support','caisse'));

DO $catalogue$
DECLARE item record;columns_json jsonb;extra_columns jsonb;view_name text;
BEGIN
 FOR item IN SELECT * FROM (VALUES
 ('caisses',ARRAY['CodeCaisse','NomCaisse','DeviseCode','Responsable','MontantCaisse','Actif','actions'],ARRAY['Code caisse','Caisse','Devise','Responsable','Solde','État','Actions']),
 ('ecritures',ARRAY['CodePaiement','DatePaiement','NomCaisse','LibellePaiement','SensMouvement','MontantPaiement','EtatEcriture','NomTiers','CodeFactureFk','actions'],ARRAY['Écriture','Date et heure','Caisse','Libellé','Sens','Montant','État','Tiers','Facture','Actions']),
 ('clotures',ARRAY['ID_ClotureCaisse','ClotureLe','NomCaisse','SoldeTheorique','MontantCompte','Ecart','Motif','Auteur','actions'],ARRAY['Clôture','Date et heure','Caisse','Théorique','Compté','Écart','Motif','Auteur','Actions'])
 ) v(key,ids,labels) LOOP
  SELECT jsonb_agg(jsonb_build_object('id',item.ids[n],'label',item.labels[n],'type',CASE WHEN item.ids[n] IN('DatePaiement','ClotureLe') THEN 'datetime' WHEN item.ids[n] IN('MontantCaisse','MontantPaiement','SoldeTheorique','MontantCompte','Ecart','ID_ClotureCaisse') THEN 'number' ELSE 'text' END,'exportable',item.ids[n]<>'actions','defaultVisible',true,'defaultExport',item.ids[n]<>'actions','defaultOrder',n-1,'defaultExportOrder',n-1,'tableAvailable',true) ORDER BY n) INTO columns_json FROM generate_subscripts(item.ids,1) n;
  view_name:=CASE item.key WHEN 'caisses' THEN 'V_Caisse' WHEN 'ecritures' THEN 'V_JournalCaisse' ELSE 'V_ClotureCaisse' END;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',labels.id,'label',labels.label,
   'type',CASE WHEN t.typcategory='N' THEN 'number' WHEN t.typcategory='D' THEN 'datetime' WHEN t.typcategory='B' THEN 'boolean' ELSE 'text' END,
   'exportable',true,'defaultVisible',false,'defaultExport',false,'defaultOrder',a.attnum+100,'defaultExportOrder',a.attnum+100,
   'tableAvailable',labels.id IN('NomEntite','ReferenceExterne','Auteur','Validateur','CodeCompensateur','ObsPaiement')) ORDER BY a.attnum),'[]'::jsonb)
  INTO extra_columns FROM (VALUES
   ('IdCaisse','Identifiant caisse'),('CodeCaisse','Code caisse'),('NomCaisse','Caisse'),('NomEntite','Entreprise'),
   ('DeviseCode','Devise'),('DeviseLibelle','Libellé devise'),('IdDeviseFk','Identifiant devise'),('TypeCaisse','Type de caisse'),
   ('Responsable','Responsable'),('Actif','Active'),('MontantCaisse','Solde enregistré'),('SoldeTheorique','Solde théorique'),
   ('EcartsRapprochement','Écart de rapprochement'),('NombreEcritures','Écritures validées'),('NbBrouillons','Brouillons'),
   ('DerniereClotureLe','Dernière clôture'),('CreeLe','Créé le'),('ModifieLe','Modifié le'),
   ('IdPaiement','Identifiant écriture'),('CodePaiement','Écriture'),('DatePaiement','Date et heure'),
   ('LibellePaiement','Libellé'),('ReferenceExterne','Référence'),('SensMouvement','Sens (+1 entrée / −1 sortie)'),
   ('EtatEcriture','État'),('MontantPaiement','Montant'),('MontantSigne','Montant signé'),('SoldeApres','Solde après'),
   ('TypePaiement','Type de paiement'),('NomTiers','Tiers'),('Auteur','Auteur'),('Validateur','Validé par'),('ValideLe','Validé le'),
   ('ObsPaiement','Observations'),('ValidePaiement','Active'),('CodeFactureFk','Facture'),
   ('CodePaiementOrigine','Écriture d’origine'),('CodeCompensateur','Contrepassation'),('IdReglementFk','Identifiant règlement'),
   ('ID_ClotureCaisse','Identifiant clôture'),('ClotureLe','Date et heure de clôture'),('MontantCompte','Montant compté'),
   ('Ecart','Écart de clôture'),('Motif','Motif')
  ) labels(id,label)
  JOIN pg_attribute a ON a.attrelid=to_regclass(format('operations.%I',view_name)) AND a.attname=labels.id AND a.attnum>0 AND NOT a.attisdropped
  JOIN pg_type t ON t.oid=a.atttypid WHERE NOT labels.id=ANY(item.ids);
  columns_json:=columns_json||extra_columns;
  INSERT INTO referentiel."T_InterfaceTableau"("CleInterface","Module","Colonnes") VALUES('caisse.'||item.key,'caisse',columns_json) ON CONFLICT("CleInterface") DO NOTHING;
 END LOOP;
END $catalogue$;

COMMENT ON INDEX operations.ix_paiement_caisse_etat_date IS 'Parcours et rapprochement du journal de chaque caisse par état et date métier.';
COMMENT ON INDEX operations.ix_paiement_entite_date IS 'Filtrage du journal par entreprise et période sans mélange de propriétaires.';
COMMENT ON INDEX operations.ix_cloture_caisse_date IS 'Recherche de la dernière clôture et garde contre les écritures antidatées.';

COMMENT ON TABLE operations."T_Caisse" IS 'Caisse mono-devise appartenant durablement à une entreprise ; le solde est exclusivement rapproché du journal validé. Plusieurs caisses distinctes peuvent utiliser la même devise.';
COMMENT ON TABLE operations."T_Paiement" IS 'Journal de caisse : brouillons archivables, validations immuables et contrepassations uniques. Les règlements de facture liés sont prouvés sans seconde création financière.';
COMMENT ON TABLE operations."T_ClotureCaisse" IS 'Constat physique immuable du montant compté face au solde théorique au verrouillage ; ne génère ni correction automatique ni mouvement de caisse.';
COMMENT ON VIEW operations."V_Caisse" IS 'Registre des caisses par entreprise et devise, avec rapprochement du journal, brouillons et dernière clôture. Aucun total multidevise.';
COMMENT ON VIEW operations."V_JournalCaisse" IS 'Journal enrichi et solde après validation dans l’ordre technique ValideLe/IdPaiement ; les brouillons n’affectent aucun solde.';
COMMENT ON VIEW operations."V_FluxCaisseJournalier" IS 'Flux validés journaliers à Kinshasa par caisse, entreprise et devise ; entrées, sorties et compensations restent dans le même journal.';
COMMENT ON VIEW operations."V_ClotureCaisse" IS 'Registre de clôture physique de caisse avec propriétaire, devise et auteur, sans modification du journal.';
COMMENT ON COLUMN operations."T_Caisse"."MontantCaisse" IS 'Solde exact au centime issu exclusivement des écritures POSTED ; contrôlé contre leur somme en fin de transaction. Ouverture initiale à zéro.';
COMMENT ON COLUMN operations."T_Caisse"."IdEntiteFk" IS 'Entreprise propriétaire durable, obligatoire et immuable ; sa suppression ne peut effacer cette caisse.';
COMMENT ON COLUMN operations."T_Paiement"."MontantPaiement" IS 'Montant positif exact au centime, sans arrondi implicite PostgreSQL ; le sens financier est stocké séparément.';
COMMENT ON COLUMN operations."T_Paiement"."IdEntiteFk" IS 'Entreprise copiée de la caisse ; indépendante d’un éventuel changement ultérieur du compte créateur.';
COMMENT ON COLUMN operations."T_Paiement"."IdTypePaiementFk" IS 'Motif catégoriel facultatif, configuré dans T_ChampReferentiel ; ne détermine ni signe ni état de validation.';
COMMENT ON COLUMN operations."T_Paiement"."IdTypeMouvementFk" IS 'Référence historique facultative Entrée/Sortie ; si renseignée elle doit correspondre au signe explicite de l’écriture.';
COMMENT ON COLUMN operations."T_Paiement"."IdStatutPaiementFk" IS 'Ancienne classification conservée et référencée ; EtatEcriture reste la seule autorité du journal moderne.';
COMMENT ON COLUMN operations."T_Paiement"."ValidePaiement" IS 'Brouillon actif ou archivé ; une écriture POSTED reste toujours active et immuable.';
COMMENT ON COLUMN operations."T_Paiement"."DatePaiement" IS 'Date métier complète de l’opération, finie et non future ; une clôture bloque les validations antérieures ou égales.';
COMMENT ON FUNCTION operations.fn_caisse_actor(integer,integer) IS 'Vérification du rattachement et de l’activité d’un auteur ; ce contrôle de cohérence ne remplace pas les permissions du service.';
COMMENT ON FUNCTION operations.fn_caisse_sens_type(integer) IS 'Résout le sens explicite Entrée/Sortie d’une valeur du référentiel ; le journal conserve son propre signe et ne recalcule pas les validations historiques.';
COMMENT ON FUNCTION operations.tr_caisse_integrite() IS 'Conserve le code automatique, l’entreprise, la devise et l’identité de création ; contrôle le responsable et l’archivage sans brouillon actif.';
COMMENT ON FUNCTION operations.tr_paiement_integrite() IS 'Verrouille la caisse, dérive propriétaire/devise, contrôle acteurs/tiers/règlement, clôtures, disponibilité et compensation ; une validation ne peut plus être modifiée.';
COMMENT ON FUNCTION operations.gestion_caisse_on_paiement() IS 'Seul effet de caisse : ajout du montant signé à la première validation d’une écriture ; aucune réévaluation par identifiant de statut ou de devise.';
COMMENT ON FUNCTION operations.tr_caisse_solde_rapproche() IS 'Contrainte différée : le solde physique stocké doit égaler la somme du journal validé à la fin de la transaction, y compris après SQL direct.';
COMMENT ON FUNCTION operations.tr_cloture_integrite() IS 'Capture le solde courant et le contexte au verrouillage, refuse un comptage antidaté/futur, des brouillons antérieurs et toute modification ultérieure.';
COMMENT ON FUNCTION operations.tr_reglement_caisse_protege() IS 'Empêche la modification ou suppression d’un règlement déjà relié au journal de caisse ; une correction requiert un circuit financier explicite.';
COMMENT ON FUNCTION operations.fn_caisse_valider(integer,integer,text,uuid,text,bigint) IS 'Valide une seule fois un brouillon avec contrôle de révision et preuve de rejeu UUID/empreinte/acteur ; la garde SQL produit l’effet de caisse.';
COMMENT ON FUNCTION operations.fn_caisse_contrepasser(integer,integer,text,uuid,text,bigint) IS 'Crée une seule écriture opposée au montant original avec motif ; une compensation ou un règlement lié ne se contre-passe pas par ce circuit.';
COMMENT ON FUNCTION operations.fn_caisse_cloturer(integer,integer,timestamptz,numeric,text,uuid,text,bigint) IS 'Constate un comptage immuable avec révision de caisse et rejeu sûr ; un écart exige un motif et ne génère aucune correction automatique.';
COMMENT ON FUNCTION operations.fn_audit_caisse(integer,integer,timestamp without time zone) IS 'Rapprochement du journal moderne par caisse/entreprise/devise ; Ecart reste inconnu pour une borne historique puisque SoldeCaisse est courant.';
COMMENT ON FUNCTION operations.fn_audit_flux_caisse(integer,integer,timestamp without time zone,timestamp without time zone) IS 'Flux du journal validé, bornes cohérentes et mêmes règles que le solde ; aucune dépendance aux anciens identifiants fixes.';

DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT * FROM (VALUES
 ('T_Caisse','CodeCaisse','Code d’inventaire de caisse automatique CAI-ID, immuable et distinct du libellé.'),('T_Caisse','NomCaisse','Nom lisible de la caisse dans son entreprise.'),('T_Caisse','IdTypeCaisseFk','Type de caisse choisi dans la catégorie configurable du référentiel.'),('T_Caisse','IdResponsableFk','Compte responsable de la caisse ; aucune permission ne découle de cette affectation.'),('T_Caisse','Actif','Caisse utilisable pour les nouvelles écritures ; les caisses archivées restent consultables.'),
 ('T_Paiement','IdCaisseFk','Caisse propriétaire du flux ; détermine immuablement entreprise et devise.'),('T_Paiement','SensMouvement','Signe financier capturé : +1 entrée, -1 sortie ; indépendant du libellé courant du référentiel.'),('T_Paiement','EtatEcriture','DRAFT sans effet de solde ou POSTED irréversible ; une correction crée une contrepassation.'),('T_Paiement','LibellePaiement','Objet lisible de l’encaissement ou du décaissement.'),('T_Paiement','ReferenceExterne','Référence facultative du justificatif ou de l’opération externe ; ne constitue pas une clé financière.'),('T_Paiement','IdTiersFk','Tiers facultatif de la même entreprise, sans déduction depuis un texte saisi.'),('T_Paiement','IdReglementFk','Règlement logistique d’origine unique, de même montant/devise/entreprise ; aucune deuxième dette ou recette créée.'),('T_Paiement','IdPaiementOrigineFk','Écriture validée compensée, au plus une fois et pour le même montant opposé.'),('T_Paiement','IdValidateurFk','Compte ayant validé le flux ; contrôle de rattachement conservé.'),('T_Paiement','ValideLe','Instant technique de première validation, distinct de la date métier.'),('T_Paiement','DeviseCodeSnapshot','Code de devise capturé à la validation pour les réimpressions historiques.'),
 ('T_ClotureCaisse','ID_ClotureCaisse','Identifiant de constat de clôture, non réutilisable.'),('T_ClotureCaisse','IdCaisseFk','Caisse comptée et verrouillée lors de la clôture.'),('T_ClotureCaisse','IdEntiteFk','Entreprise copiée de la caisse, jamais déduite du compte courant.'),('T_ClotureCaisse','IdDeviseFk','Devise copiée de la caisse ; aucune conversion implicite.'),('T_ClotureCaisse','ClotureLe','Date et heure limite du constat ; bloque la validation d’écritures antérieures ou égales.'),('T_ClotureCaisse','SoldeTheorique','Solde du journal capturé au verrouillage de la caisse.'),('T_ClotureCaisse','MontantCompte','Montant réellement compté, positif ou nul et exact au centime.'),('T_ClotureCaisse','Ecart','Différence générée : montant compté moins solde théorique.'),('T_ClotureCaisse','Motif','Justification obligatoire lorsque le comptage diffère du théorique.'),('T_ClotureCaisse','IdUserFk','Auteur du constat physique de caisse.')
 ) v(tab,col,description) LOOP EXECUTE format('COMMENT ON COLUMN operations.%I.%I IS %L',r.tab,r.col,r.description);END LOOP;
 FOR r IN SELECT t.tab,c.col,c.description FROM (VALUES('T_Caisse'),('T_Paiement'),('T_ClotureCaisse')) t(tab) CROSS JOIN (VALUES('CreeLe','Instant technique de création ; conservé pour la traçabilité.'),('ModifieLe','Instant technique de dernière modification autorisée.'),('Revision','Version SQL monotone pour le contrôle des modifications simultanées.'),('CreationRequestId','Identifiant de demande initiale pour rejouer sans duplication.'),('CreationPayloadHash','Empreinte SHA-256 du contenu initial ; vérifiée lors du rejeu.'),('ValidationRequestId','Identifiant de demande de validation, distinct de l’identité métier.'),('ValidationPayloadHash','Empreinte SHA-256 de la demande de validation pour un rejeu exact.')) c(col,description) WHERE EXISTS(SELECT FROM information_schema.columns WHERE table_schema='operations' AND table_name=t.tab AND column_name=c.col) LOOP EXECUTE format('COMMENT ON COLUMN operations.%I.%I IS %L',r.tab,r.col,r.description);END LOOP;
 FOR r IN SELECT n.nspname,c.relname,a.attname FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='operations' AND c.relkind='v' AND a.attnum>0 AND NOT a.attisdropped LOOP EXECUTE format('COMMENT ON COLUMN %I.%I.%I IS %L',r.nspname,r.relname,r.attname,'Projection de lecture : '||r.attname||' ; périmètre entreprise et devise du registre de caisse.');END LOOP;
 FOR r IN SELECT k.conname,c.relname FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='operations' AND c.relname IN('T_Caisse','T_Paiement','T_ClotureCaisse') AND obj_description(k.oid,'pg_constraint') IS NULL LOOP EXECUTE format('COMMENT ON CONSTRAINT %I ON operations.%I IS %L',r.conname,r.relname,'Intégrité de caisse : '||r.conname||' ; montants exacts, historique conservé et rattachements prouvés.');END LOOP;
 FOR r IN SELECT t.tgname,c.relname FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='operations' AND NOT t.tgisinternal AND obj_description(t.oid,'pg_trigger') IS NULL LOOP EXECUTE format('COMMENT ON TRIGGER %I ON operations.%I IS %L',r.tgname,r.relname,'Garde du journal de caisse : '||r.tgname||' ; validation SQL, historique et rapprochement du solde.');END LOOP;
END $$;
COMMIT;
