-- Métadonnées durables et contrôles financiers indépendants de la technologie applicative.
-- Aucune attribution inventée pour les écritures historiques.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';

ALTER TABLE logistique."T_Reglements"
 ADD COLUMN "CreeParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser"),
 ADD COLUMN "ModifieParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser"),
 ADD COLUMN "CreeLe" timestamptz,
 ADD COLUMN "ModifieLe" timestamptz;
COMMENT ON COLUMN logistique."T_Reglements"."CreeParUserFk" IS 'Auteur actif identifié par le contexte SQL transactionnel lors de la création ; NULL pour les écritures historiques sans preuve. Immuable après création.';
COMMENT ON COLUMN logistique."T_Reglements"."ModifieParUserFk" IS 'Auteur actif de la dernière écriture identifié par le contexte SQL ; NULL si aucun acteur applicatif prouvé.';
COMMENT ON COLUMN logistique."T_Reglements"."CreeLe" IS 'Horodatage technique SQL de création, distinct de DateReglement ; NULL pour les écritures historiques non horodatées.';
COMMENT ON COLUMN logistique."T_Reglements"."ModifieLe" IS 'Horodatage technique SQL de la dernière écriture ; ne modifie pas la date métier du règlement.';
COMMENT ON TABLE logistique."T_Reglements" IS 'Règlements d’une facture par CodeFactureFk : montants exacts et origine technique durable. Auteur/date de création immuables, dernière modification attribuée au contexte SQL prouvé et images avant/après auditées dans la même transaction.';
COMMENT ON CONSTRAINT "T_Reglements_CreeParUserFk_fkey" ON logistique."T_Reglements" IS 'Auteur de création existant, sans déduction depuis le propriétaire de la facture.';
COMMENT ON CONSTRAINT "T_Reglements_ModifieParUserFk_fkey" ON logistique."T_Reglements" IS 'Dernier auteur existant ; le changement de rattachement de cet utilisateur ne change pas l’entreprise du document.';

CREATE FUNCTION logistique.tr_reglement_tracabilite() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE actor_id integer:=systeme.fn_admin_actor_user_id();
BEGIN
 IF TG_OP='INSERT' THEN
  NEW."CreeParUserFk":=actor_id; NEW."CreeLe":=clock_timestamp();
 ELSE
  IF NEW."CreeParUserFk" IS DISTINCT FROM OLD."CreeParUserFk"
   OR NEW."CreeLe" IS DISTINCT FROM OLD."CreeLe" THEN
   RAISE EXCEPTION 'Les informations de creation du reglement sont immuables.' USING ERRCODE='23514';
  END IF;
 END IF;
 NEW."ModifieParUserFk":=actor_id; NEW."ModifieLe":=clock_timestamp();
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_reglement_tracabilite() IS 'Fixe les dates techniques et auteurs prouvés du règlement ; conserve les origines historiques inconnues et protège la création contre les modifications.';
CREATE TRIGGER aa_reglement_tracabilite BEFORE INSERT OR UPDATE ON logistique."T_Reglements"
FOR EACH ROW EXECUTE FUNCTION logistique.tr_reglement_tracabilite();
COMMENT ON TRIGGER aa_reglement_tracabilite ON logistique."T_Reglements" IS 'Traçabilité technique SQL de chaque création ou modification de règlement, avant les gardes financières.';

CREATE OR REPLACE FUNCTION logistique.tr_reglement_apres_avoir() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE code text; parent logistique."T_Commande"%ROWTYPE; invoice numeric; credit numeric; paid numeric; old_total numeric;
BEGIN
 IF TG_OP='UPDATE' AND (NEW."CodeFactureFk" IS DISTINCT FROM OLD."CodeFactureFk"
   OR NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk"
   OR NEW."ID_TiersFk" IS DISTINCT FROM OLD."ID_TiersFk"
   OR NEW."ID_ClientFk" IS DISTINCT FROM OLD."ID_ClientFk") THEN
  RAISE EXCEPTION 'La facture, sa devise et le tiers du reglement sont immuables.' USING ERRCODE='23514';
 END IF;
 code:=CASE WHEN TG_OP='DELETE' THEN OLD."CodeFactureFk" ELSE NEW."CodeFactureFk" END;
 SELECT * INTO parent FROM logistique."T_Commande" WHERE "CodeFacture"=code FOR UPDATE;
 IF NOT FOUND OR nullif(btrim(code),'') IS NULL THEN
  RAISE EXCEPTION 'Le reglement doit etre rattache a une facture existante.' USING ERRCODE='23514';
 END IF;
 IF logistique.fn_commande_cloturee(parent."StatusFacture") THEN
  RAISE EXCEPTION 'Cette facture est cloturee ; ses reglements sont conserves.' USING ERRCODE='23514';
 END IF;
 IF TG_OP IN ('UPDATE','DELETE') AND (EXISTS(SELECT 1 FROM logistique."T_Avoir" WHERE "ID_CommandeFk"=parent."ID_Commande")
  OR EXISTS(SELECT 1 FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=parent."ID_Commande")) THEN
  RAISE EXCEPTION 'Un avoir existe : le reglement doit etre conserve.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF NEW."MontantRegle" IS NULL OR NEW."MontantRegle"<=0 OR NEW."DateReglement" IS NULL THEN
  RAISE EXCEPTION 'Renseignez une date et un montant de reglement strictement positif.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='INSERT' THEN
  IF NEW."ID_TiersFk" IS DISTINCT FROM parent."ID_TiersFk" OR NEW."ID_ClientFk" IS DISTINCT FROM parent."ID_ClientFk" THEN
   RAISE EXCEPTION 'Le tiers du reglement doit correspondre a celui de la facture.' USING ERRCODE='23514';
  END IF;
 END IF;
 IF TG_OP='INSERT' OR NEW."ID_ModeReglementFk" IS DISTINCT FROM OLD."ID_ModeReglementFk" THEN
  PERFORM 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
   ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
   WHERE g."ID_Generique"=NEW."ID_ModeReglementFk" AND g."ID_CategorieGeneriqueFk"=36
     AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE FOR SHARE OF g,c;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mode de reglement indisponible.' USING ERRCODE='23514'; END IF;
 END IF;
 SELECT coalesce(f."MontantTTC",parent."MontantTTC") INTO invoice
  FROM (SELECT 1) source LEFT JOIN logistique."T_Facture" f ON f."ID_CommandeFk"=parent."ID_Commande";
 IF invoice IS NULL THEN RAISE EXCEPTION 'Le montant de cette facture doit etre verifie.' USING ERRCODE='23514'; END IF;
 SELECT coalesce(sum("Montant"),0) INTO credit FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=parent."ID_Commande";
 SELECT coalesce(sum("MontantRegle"),0) INTO paid FROM logistique."T_Reglements"
  WHERE "CodeFactureFk"=code AND (TG_OP='INSERT' OR "ID_Reglement"<>NEW."ID_Reglement");
 old_total:=paid+CASE WHEN TG_OP='UPDATE' THEN coalesce(OLD."MontantRegle",0) ELSE 0 END;
 IF paid+NEW."MontantRegle">invoice-credit AND NOT (TG_OP='UPDATE' AND old_total>invoice-credit AND paid+NEW."MontantRegle"<old_total) THEN
  RAISE EXCEPTION 'Le reglement depasse le solde net. Un excedent historique peut seulement etre reduit.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_reglement_apres_avoir() IS 'Verrouille la facture et contrôle créations ET modifications : montant positif, parent/devise/tiers immuables, mode actif, clôture et avoirs conservés, solde net non dépassé. Un excédent historique peut seulement diminuer.';
-- PostgreSQL exécute les BEFORE de même type par nom. Le verrou exclusif
-- précède aa_propriete_reglement (FOR SHARE) pour éviter deux conversions
-- concurrentes SHARE -> UPDATE sur la même facture.
ALTER TRIGGER reglement_apres_avoir ON logistique."T_Reglements" RENAME TO a0_reglement_apres_avoir;
COMMENT ON TRIGGER a0_reglement_apres_avoir ON logistique."T_Reglements" IS 'Garde financière SQL exécutée avant le contrôle de propriété : verrou du parent acquis avant les verrous partagés, sans conversion concurrente de verrou ni dépassement du solde.';

CREATE FUNCTION logistique.tr_reglement_audit() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE actor_id integer:=systeme.fn_admin_actor_user_id(); entity_id integer; code text; before_data jsonb; after_data jsonb;
BEGIN
 code:=CASE WHEN TG_OP='DELETE' THEN OLD."CodeFactureFk" ELSE NEW."CodeFactureFk" END;
 SELECT "IdEntiteFk" INTO entity_id FROM logistique."T_Commande" WHERE "CodeFacture"=code;
 IF TG_OP IN ('UPDATE','DELETE') THEN before_data:=systeme.fn_audit_sans_secrets(to_jsonb(OLD))||jsonb_build_object('_actor',jsonb_build_object('IdUser',actor_id)); END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN after_data:=systeme.fn_audit_sans_secrets(to_jsonb(NEW))||jsonb_build_object('_actor',jsonb_build_object('IdUser',actor_id)); END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk")
 VALUES('logistique.T_Reglements',CASE WHEN TG_OP='INSERT' THEN 'CREATE' ELSE TG_OP END,before_data,after_data,
        CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa',entity_id);
 RETURN NULL;
END $$;
COMMENT ON FUNCTION logistique.tr_reglement_audit() IS 'Une image avant/après nettoyée par écriture de règlement, avec auteur identifié et entreprise durable de la facture. Les événements PAYMENT_* applicatifs ne portent que les preuves idempotentes.';
CREATE TRIGGER zz_reglement_audit AFTER INSERT OR UPDATE OR DELETE ON logistique."T_Reglements"
FOR EACH ROW EXECUTE FUNCTION logistique.tr_reglement_audit();
COMMENT ON TRIGGER zz_reglement_audit ON logistique."T_Reglements" IS 'Historique transactionnel SQL du règlement, y compris pour un futur backend ; ne crée aucun mouvement de stock.';

CREATE OR REPLACE FUNCTION logistique.tr_audit_numero_document() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE payload jsonb; entity_id integer;
BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN
  payload:=jsonb_build_object('ID_Commande',NEW."ID_Commande",'CodeCmd',NEW."CodeCmd");
 ELSE
  payload:=jsonb_build_object('ID_Facture',NEW."ID_Facture",'ID_CommandeFk',NEW."ID_CommandeFk",'CodeFacture',NEW."CodeFacture");
 END IF;
 entity_id:=NEW."IdEntiteFk";
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk")
 VALUES('logistique.'||TG_TABLE_NAME,'DOCUMENT_NUMBER',payload||jsonb_build_object('version','20261028_03','sqlUser',current_user),entity_id);
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_audit_numero_document() IS 'Conserve identité et numéro émis avec l’entreprise propriétaire durable du document, indépendamment de l’entreprise de son créateur. Les journaux antérieurs restent inchangés.';

ALTER TABLE logistique."T_Article" DROP CONSTRAINT uq_article_codeinterne;
ALTER TABLE logistique."T_Article" ADD CONSTRAINT uq_article_codeinterne UNIQUE ("IdEntiteFk","CodeArticleInterne");
COMMENT ON CONSTRAINT uq_article_codeinterne ON logistique."T_Article" IS 'Code interne unique dans une entreprise ; deux entreprises peuvent employer le même code catalogue sans partager leurs données.';
COMMENT ON INDEX logistique.uq_article_codeinterne IS 'Unicité du code article par propriétaire durable, conservant la comparaison textuelle existante et les codes NULL.';
COMMENT ON COLUMN logistique."T_Article"."CodeArticleInterne" IS 'Code catalogue textuel unique dans l’entreprise propriétaire ; deux entreprises distinctes peuvent utiliser le même code. Les références existantes et les valeurs NULL sont conservées.';
ALTER TABLE logistique."T_PieceJustificative" ADD CONSTRAINT ck_piece_sha256_contenu
 CHECK ("Sha256"=encode(sha256("Contenu"),'hex'));
COMMENT ON CONSTRAINT ck_piece_sha256_contenu ON logistique."T_PieceJustificative" IS 'L’empreinte SHA-256 doit correspondre exactement au contenu binaire conservé en base, quelle que soit la technologie d’enregistrement.';
COMMIT;
