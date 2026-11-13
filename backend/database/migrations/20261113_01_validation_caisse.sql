-- Modes de validation par entreprise et règle immuable à la création des écritures.
CREATE TABLE operations."T_ParametreValidationCaisse" (
    "IdEntiteFk" integer PRIMARY KEY REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
    "ModeValidation" text NOT NULL DEFAULT 'MANUAL',
    "IdsValidateurs" integer[] NOT NULL DEFAULT '{}',
    "AutoriseValidationImmediateHistorique" boolean NOT NULL DEFAULT false,
    "IdModifieParFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser"),
    "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
    "MotifModification" text,
    "Revision" bigint NOT NULL DEFAULT 1,
    CONSTRAINT ck_parametre_validation_caisse_mode CHECK ("ModeValidation" IN ('MANUAL', 'OTHER_AGENT', 'AUTO')),
    CONSTRAINT ck_parametre_validation_caisse_agents CHECK (
        cardinality("IdsValidateurs") <= 100
        AND ("ModeValidation" <> 'OTHER_AGENT' OR cardinality("IdsValidateurs") > 0)
    ),
    CONSTRAINT ck_parametre_validation_caisse_revision CHECK ("Revision" > 0)
);

-- Le choix explicite brouillon/validation immédiate de l’ancienne saisie reste accessible.
INSERT INTO operations."T_ParametreValidationCaisse" ("IdEntiteFk", "AutoriseValidationImmediateHistorique")
SELECT "IdEntite", true FROM systeme."T_Entite";

ALTER TABLE operations."T_Paiement"
    ADD COLUMN "ModeValidation" text NOT NULL DEFAULT 'MANUAL',
    ADD COLUMN "MecanismeValidation" text,
    ADD COLUMN "ValidationDesigneeRequise" boolean NOT NULL DEFAULT false,
    DROP CONSTRAINT ck_paiement_validation,
    ADD CONSTRAINT ck_paiement_validation_mode CHECK ("ModeValidation" IN ('MANUAL', 'OTHER_AGENT', 'AUTO')),
    ADD CONSTRAINT ck_paiement_validation CHECK (
        ("EtatEcriture" = 'POSTED' AND "ValidePaiement"
         AND "ValideLe" IS NOT NULL AND "DeviseCodeSnapshot" IS NOT NULL
         AND (("MecanismeValidation" IS NOT DISTINCT FROM 'AUTO' AND "IdValidateurFk" IS NULL AND "ModeValidation" = 'AUTO')
              OR ("MecanismeValidation" IS DISTINCT FROM 'AUTO' AND "IdValidateurFk" IS NOT NULL
                  AND ("MecanismeValidation" IS NULL OR "MecanismeValidation" IN ('MANUAL', 'COUNTERPOST', 'SETTLEMENT')))))
        OR ("EtatEcriture" = 'DRAFT' AND "ValideLe" IS NULL AND "IdValidateurFk" IS NULL
            AND "DeviseCodeSnapshot" IS NULL AND "MecanismeValidation" IS NULL)
    );

CREATE FUNCTION operations.fn_caisse_mode_validation(p_entite integer)
RETURNS text LANGUAGE sql STABLE SET search_path = pg_catalog AS $$
    SELECT coalesce(
        (SELECT p."ModeValidation" FROM operations."T_ParametreValidationCaisse" p WHERE p."IdEntiteFk" = p_entite),
        'MANUAL'
    )
$$;

CREATE FUNCTION operations.fn_caisse_validateur_designe(p_entite integer, p_actor integer)
RETURNS boolean LANGUAGE sql STABLE SET search_path = pg_catalog AS $$
    SELECT EXISTS (
        SELECT FROM operations."T_ParametreValidationCaisse" p
        JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p_actor AND u."IdEntiteFk" = p_entite AND u."ValideUser"
        WHERE p."IdEntiteFk" = p_entite AND u."IdUser" = ANY(p."IdsValidateurs")
    )
$$;

CREATE FUNCTION operations.tr_parametre_validation_caisse()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $$
DECLARE
    acteur integer := systeme.fn_admin_actor_user_id();
    motif text := nullif(btrim(current_setting('operations.motif', true)), '');
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Modifiez les paramètres de validation pour conserver leur historique.' USING ERRCODE = '23514';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended('caisse-validation-policy:' || NEW."IdEntiteFk", 0));
    IF NOT operations.fn_caisse_actor(acteur, NEW."IdEntiteFk") OR motif IS NULL OR length(motif) > 1000 THEN
        RAISE EXCEPTION 'Auteur de l’entreprise et motif de modification requis.' USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT FROM systeme."T_Entite" WHERE "IdEntite" = NEW."IdEntiteFk" AND "ValideEntite") THEN
        RAISE EXCEPTION 'Choisissez une entreprise active.' USING ERRCODE = '23514';
    END IF;
    IF (SELECT count(DISTINCT id) FROM unnest(NEW."IdsValidateurs") id) <> cardinality(NEW."IdsValidateurs")
       OR EXISTS (
           SELECT FROM unnest(NEW."IdsValidateurs") id
           WHERE NOT EXISTS (
               SELECT FROM systeme."T_Utilisateurs" u
               WHERE u."IdUser" = id AND u."ValideUser" AND u."IdEntiteFk" = NEW."IdEntiteFk"
           )
       ) THEN
        RAISE EXCEPTION 'Choisissez des agents actifs et distincts de cette entreprise.' USING ERRCODE = '23514';
    END IF;
    IF cardinality(NEW."IdsValidateurs") = 0 AND EXISTS (
        SELECT FROM operations."T_Paiement" p
        WHERE p."IdEntiteFk" = NEW."IdEntiteFk" AND p."EtatEcriture" = 'DRAFT'
          AND p."ValidePaiement" AND p."ValidationDesigneeRequise"
    ) THEN
        RAISE EXCEPTION 'Des brouillons en cours nécessitent un agent désigné.' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" THEN
            RAISE EXCEPTION 'L’entreprise des paramètres est immuable.' USING ERRCODE = '23514';
        END IF;
        NEW."Revision" := OLD."Revision" + 1;
    ELSE
        NEW."Revision" := 1;
    END IF;
    NEW."AutoriseValidationImmediateHistorique" := false;
    NEW."IdModifieParFk" := acteur;
    NEW."MotifModification" := motif;
    NEW."ModifieLe" := clock_timestamp();
    RETURN NEW;
END
$$;

CREATE TRIGGER aa_parametre_validation_caisse BEFORE INSERT OR UPDATE OR DELETE
ON operations."T_ParametreValidationCaisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_parametre_validation_caisse();

CREATE TRIGGER trigger_audit_parametre_validation_caisse AFTER INSERT OR UPDATE
ON operations."T_ParametreValidationCaisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_audit();



CREATE OR REPLACE FUNCTION operations.tr_paiement_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cash operations."T_Caisse";origin operations."T_Paiement";reg record;direction smallint;lastclose timestamptz;policy operations."T_ParametreValidationCaisse";BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une écriture de caisse ne se supprime pas ; archivez le brouillon ou contre-passez la validation.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND OLD."EtatEcriture"='POSTED' THEN RAISE EXCEPTION 'Une écriture validée est immuable ; utilisez une contrepassation.' USING ERRCODE='23514';END IF;
 -- L’entreprise de la caisse est immuable. Le verrou du paramètre précède celui du solde.
 IF NEW."IdPaiementOrigineFk" IS NULL
    AND (TG_OP='INSERT' OR NEW."EtatEcriture"='POSTED') THEN
  SELECT "IdEntiteFk" INTO STRICT NEW."IdEntiteFk" FROM operations."T_Caisse" WHERE "IdCaisse"=NEW."IdCaisseFk";
  PERFORM pg_advisory_xact_lock_shared(hashtextextended('caisse-validation-policy:' || NEW."IdEntiteFk", 0));
 END IF;
 SELECT * INTO STRICT cash FROM operations."T_Caisse" WHERE "IdCaisse"=NEW."IdCaisseFk" FOR UPDATE;
 IF NOT cash."Actif" OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=cash."IdEntiteFk" AND "ValideEntite") THEN RAISE EXCEPTION 'Cette caisse ou entreprise est inactive.' USING ERRCODE='23514';END IF;
 NEW."IdEntiteFk":=cash."IdEntiteFk";NEW."IdDeviseFk":=cash."IdDeviseFk";
 IF NOT operations.fn_caisse_actor(NEW."IdUserFk",NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Auteur hors entreprise ou inactif.' USING ERRCODE='23514';END IF;
 IF NEW."IdPayeurFk" IS NOT NULL AND NOT operations.fn_caisse_actor(NEW."IdPayeurFk",NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Payeur hors entreprise ou inactif.' USING ERRCODE='23514';END IF;
 IF NEW."IdTiersFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Client" WHERE "ID_Client"=NEW."IdTiersFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Tiers hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."DatePaiement" IS NULL OR NOT isfinite(NEW."DatePaiement") OR NEW."DatePaiement">clock_timestamp()+interval '5 seconds' THEN RAISE EXCEPTION 'La date de caisse doit être renseignée, finie et non future.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  IF NEW."IdPaiementOrigineFk" IS NOT NULL OR NEW."IdReglementFk" IS NOT NULL THEN
   NEW."ModeValidation":='MANUAL';
   NEW."ValidationDesigneeRequise":=false;
  ELSE
   SELECT * INTO policy FROM operations."T_ParametreValidationCaisse" WHERE "IdEntiteFk"=NEW."IdEntiteFk";
   NEW."ModeValidation":=coalesce(policy."ModeValidation",'MANUAL');
   NEW."ValidationDesigneeRequise":=NEW."ModeValidation"='OTHER_AGENT'
       OR (NEW."ModeValidation"='MANUAL' AND coalesce(cardinality(policy."IdsValidateurs"),0)>0);
   IF NEW."EtatEcriture"='POSTED' THEN
    RAISE EXCEPTION 'Validez l’écriture par le circuit de caisse.' USING ERRCODE='23514';
   END IF;
  END IF;
  NEW."CodePaiement":='MVT-'||NEW."IdPaiement";NEW."CreeLe":=clock_timestamp();NEW."Revision":=1;
 ELSE
  IF (NEW."IdPaiement",NEW."IdCaisseFk",NEW."IdUserFk",NEW."CreationRequestId",NEW."CreationPayloadHash",NEW."IdPaiementOrigineFk",NEW."IdReglementFk") IS DISTINCT FROM (OLD."IdPaiement",OLD."IdCaisseFk",OLD."IdUserFk",OLD."CreationRequestId",OLD."CreationPayloadHash",OLD."IdPaiementOrigineFk",OLD."IdReglementFk") THEN RAISE EXCEPTION 'Identité et rattachements de l’écriture sont conservés.' USING ERRCODE='23514';END IF;
  IF (NEW."ModeValidation",NEW."ValidationDesigneeRequise") IS DISTINCT FROM (OLD."ModeValidation",OLD."ValidationDesigneeRequise") THEN
   RAISE EXCEPTION 'La règle de validation du brouillon est conservée.' USING ERRCODE='23514';
  END IF;
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
  IF NOT NEW."ValidePaiement" THEN
   RAISE EXCEPTION 'Un brouillon archivé ne peut pas être validé.' USING ERRCODE='23514';
  END IF;
  IF NEW."IdPaiementOrigineFk" IS NOT NULL THEN
   NEW."MecanismeValidation":='COUNTERPOST';
  ELSIF NEW."IdReglementFk" IS NOT NULL THEN
   SELECT * INTO policy FROM operations."T_ParametreValidationCaisse" WHERE "IdEntiteFk"=NEW."IdEntiteFk";
   IF policy."ModeValidation"='OTHER_AGENT' THEN
    RAISE EXCEPTION 'Un règlement lié à la caisse ne peut pas être validé par un autre agent dans le même enregistrement.' USING ERRCODE='23514';
   END IF;
   IF policy."ModeValidation"='MANUAL' AND cardinality(policy."IdsValidateurs")>0
      AND NOT operations.fn_caisse_validateur_designe(NEW."IdEntiteFk",NEW."IdValidateurFk") THEN
    RAISE EXCEPTION 'Le règlement lié doit être enregistré par un agent désigné actif de l’entreprise.' USING ERRCODE='23514';
   END IF;
   NEW."MecanismeValidation":='SETTLEMENT';
  ELSIF NEW."ModeValidation"='AUTO' THEN
   IF current_setting('operations.validation_automatique',true) IS DISTINCT FROM '1'
      OR NEW."ValidationRequestId" IS NULL
      OR NEW."ValidationRequestId" IS DISTINCT FROM NEW."CreationRequestId"
      OR NEW."ValidationPayloadHash" IS DISTINCT FROM NEW."CreationPayloadHash"
      OR OLD."Revision"<>1 OR NEW."IdValidateurFk" IS NOT NULL THEN
    RAISE EXCEPTION 'La validation automatique doit accompagner l’enregistrement initial.' USING ERRCODE='23514';
   END IF;
   NEW."MecanismeValidation":='AUTO';
  ELSE
   IF NEW."ModeValidation"='OTHER_AGENT' AND NEW."IdUserFk"=NEW."IdValidateurFk" THEN
    RAISE EXCEPTION 'La validation doit être effectuée par un autre agent.' USING ERRCODE='23514';
   END IF;
   IF NEW."ValidationDesigneeRequise"
      AND NOT operations.fn_caisse_validateur_designe(NEW."IdEntiteFk",NEW."IdValidateurFk") THEN
    RAISE EXCEPTION 'La validation est réservée à un agent désigné actif de l’entreprise.' USING ERRCODE='23514';
   END IF;
   NEW."MecanismeValidation":='MANUAL';
  END IF;
  IF NEW."MecanismeValidation"<>'AUTO' AND NOT operations.fn_caisse_actor(NEW."IdValidateurFk",NEW."IdEntiteFk") THEN
   RAISE EXCEPTION 'Validateur autorisé dans l’entreprise requis.' USING ERRCODE='23514';
  END IF;
  SELECT max("ClotureLe") INTO lastclose FROM operations."T_ClotureCaisse" WHERE "IdCaisseFk"=NEW."IdCaisseFk";
  IF lastclose IS NOT NULL AND NEW."DatePaiement"<=lastclose THEN RAISE EXCEPTION 'Une clôture interdit cette écriture antidatée.' USING ERRCODE='23514';END IF;
  IF cash."MontantCaisse"+NEW."SensMouvement"*NEW."MontantPaiement"<0 THEN RAISE EXCEPTION 'Solde de caisse insuffisant.' USING ERRCODE='23514';END IF;
  NEW."ValideLe":=clock_timestamp();
  SELECT coalesce(nullif(btrim("AbrGenerique"),''),"NomGenerique") INTO STRICT NEW."DeviseCodeSnapshot" FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."IdDeviseFk";
 ELSE
  NEW."MecanismeValidation":=NULL;NEW."ValideLe":=NULL;NEW."IdValidateurFk":=NULL;NEW."DeviseCodeSnapshot":=NULL;NEW."ValidationRequestId":=NULL;NEW."ValidationPayloadHash":=NULL;
 END IF;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION operations.fn_caisse_valider(
    p_id integer, p_actor integer, p_motif text, p_request uuid, p_hash text, p_revision bigint
)
RETURNS integer LANGUAGE plpgsql SET search_path = pg_catalog AS $$
DECLARE
    r operations."T_Paiement";
    entite integer;
    automatique boolean := current_setting('operations.validation_automatique',true) IS NOT DISTINCT FROM '1';
BEGIN
    SELECT "IdEntiteFk" INTO STRICT entite FROM operations."T_Paiement" WHERE "IdPaiement"=p_id;
    PERFORM pg_advisory_xact_lock_shared(hashtextextended('caisse-validation-policy:' || entite, 0));
    SELECT * INTO STRICT r FROM operations."T_Paiement" WHERE "IdPaiement"=p_id FOR UPDATE;
    IF p_request IS NULL OR p_hash IS NULL OR p_hash !~ '^[a-f0-9]{64}$'
       OR NOT operations.fn_caisse_actor(p_actor,r."IdEntiteFk") OR length(btrim(coalesce(p_motif,'')))=0 THEN
        RAISE EXCEPTION 'Acteur, motif et demande valide requis.' USING ERRCODE='23514';
    END IF;
    IF r."EtatEcriture"='POSTED' THEN
        IF r."ValidationRequestId"=p_request AND r."ValidationPayloadHash"=p_hash
           AND (r."IdValidateurFk"=p_actor OR (automatique AND r."MecanismeValidation"='AUTO' AND r."IdUserFk"=p_actor)) THEN
            RETURN p_id;
        END IF;
        RAISE EXCEPTION 'Écriture déjà validée.' USING ERRCODE='23514';
    END IF;
    IF r."Revision" IS DISTINCT FROM p_revision THEN
        RAISE EXCEPTION 'La révision de l’écriture a changé.' USING ERRCODE='40001';
    END IF;
    IF automatique IS DISTINCT FROM (r."ModeValidation"='AUTO') OR (automatique AND r."IdUserFk"<>p_actor) THEN
        RAISE EXCEPTION 'Le mode de validation enregistré doit être respecté.' USING ERRCODE='23514';
    END IF;
    UPDATE operations."T_Paiement" SET
        "EtatEcriture"='POSTED',
        "IdValidateurFk"=CASE WHEN automatique THEN NULL ELSE p_actor END,
        "ValidationRequestId"=p_request,
        "ValidationPayloadHash"=p_hash,
        "ObsPaiement"=CASE WHEN automatique THEN "ObsPaiement"
                          ELSE concat_ws(E'\n',nullif("ObsPaiement",''),'Validation : '||p_motif) END
    WHERE "IdPaiement"=p_id;
    RETURN p_id;
END
$$;

CREATE OR REPLACE VIEW operations."V_Caisse" AS
 SELECT c.*,e."NomEntite",coalesce(nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",g."NomGenerique"::text "DeviseLibelle",t."NomGenerique"::text "TypeCaisse",concat_ws(' ',u."PrenomUser",u."NomUser")::text "Responsable",
 coalesce(p.balance,0)::numeric "SoldeTheorique",(c."MontantCaisse"-coalesce(p.balance,0))::numeric "EcartsRapprochement",coalesce(p.n,0)::bigint "NombreEcritures",coalesce(p.d,0)::bigint "NbBrouillons",cl.lastdate "DerniereClotureLe",
 coalesce(p.entrees,0)::numeric "EntreesBrouillon",coalesce(p.sorties,0)::numeric "SortiesBrouillon",
 (coalesce(p.balance,0)+coalesce(p.entrees,0)-coalesce(p.sorties,0))::numeric "SoldePrevisionnel"
 FROM operations."T_Caisse" c JOIN systeme."T_Entite" e ON e."IdEntite"=c."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."IdDeviseFk" LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=c."IdTypeCaisseFk" LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."IdResponsableFk"
 LEFT JOIN LATERAL(SELECT sum("SensMouvement"*"MontantPaiement") FILTER(WHERE "EtatEcriture"='POSTED') balance,count(*) FILTER(WHERE "EtatEcriture"='POSTED') n,count(*) FILTER(WHERE "EtatEcriture"='DRAFT' AND "ValidePaiement") d,
     sum("MontantPaiement") FILTER(WHERE "EtatEcriture"='DRAFT' AND "ValidePaiement" AND "SensMouvement"=1) entrees,
     sum("MontantPaiement") FILTER(WHERE "EtatEcriture"='DRAFT' AND "ValidePaiement" AND "SensMouvement"=-1) sorties
     FROM operations."T_Paiement" WHERE "IdCaisseFk"=c."IdCaisse") p ON true
 LEFT JOIN LATERAL(SELECT max("ClotureLe") lastdate FROM operations."T_ClotureCaisse" WHERE "IdCaisseFk"=c."IdCaisse") cl ON true;

CREATE OR REPLACE VIEW operations."V_JournalCaisse" AS
 SELECT p."IdPaiement", p."CodePaiement", p."IdUserFk", p."IdTypePaiementFk", p."MontantPaiement", p."IdStatutPaiementFk", p."DatePaiement", p."ObsPaiement", p."ValidePaiement", p."IdDeviseFk", p."IdPayeurFk", p."IdTypeMouvementFk", p."IdEntiteFk", p."IdCaisseFk", p."SensMouvement", p."EtatEcriture", p."LibellePaiement", p."ReferenceExterne", p."IdTiersFk", p."IdReglementFk", p."IdPaiementOrigineFk", p."CreationRequestId", p."CreationPayloadHash", p."ValidationRequestId", p."ValidationPayloadHash", p."CreeLe", p."ModifieLe", p."ValideLe", p."IdValidateurFk", p."Revision", p."DeviseCodeSnapshot",
 c."CodeCaisse",c."NomCaisse",e."NomEntite",coalesce(p."DeviseCodeSnapshot",nullif(g."AbrGenerique",''),g."NomGenerique")::text "DeviseCode",g."NomGenerique"::text "DeviseLibelle",t."NomGenerique"::text "TypePaiement",tiers."Nom"::text "NomTiers",concat_ws(' ',u."PrenomUser",u."NomUser")::text "Auteur",concat_ws(' ',v."PrenomUser",v."NomUser")::text "Validateur",r."CodeFactureFk",o."CodePaiement" "CodePaiementOrigine",cp."IdPaiement" "IdCompensateurFk",cp."CodePaiement" "CodeCompensateur",
 (CASE WHEN p."EtatEcriture"='POSTED' THEN p."SensMouvement"*p."MontantPaiement" ELSE 0 END)::numeric "MontantSigne",
 (CASE WHEN p."EtatEcriture"='POSTED' THEN sum(CASE WHEN p."EtatEcriture"='POSTED' THEN p."SensMouvement"*p."MontantPaiement" ELSE 0 END) OVER(PARTITION BY p."IdCaisseFk" ORDER BY p."ValideLe",p."IdPaiement" ROWS UNBOUNDED PRECEDING) END)::numeric "SoldeApres",
 p."ModeValidation",
 CASE WHEN p."EtatEcriture"='POSTED' THEN coalesce(
     p."MecanismeValidation",
     CASE WHEN p."IdPaiementOrigineFk" IS NOT NULL THEN 'COUNTERPOST'
          WHEN p."IdReglementFk" IS NOT NULL THEN 'SETTLEMENT' ELSE 'MANUAL' END
 ) END "MecanismeValidation",
 p."ValidationDesigneeRequise"
 FROM operations."T_Paiement" p JOIN operations."T_Caisse" c ON c."IdCaisse"=p."IdCaisseFk" JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=p."IdDeviseFk" LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=p."IdTypePaiementFk" LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUserFk" LEFT JOIN systeme."T_Utilisateurs" v ON v."IdUser"=p."IdValidateurFk" LEFT JOIN logistique."T_Client" tiers ON tiers."ID_Client"=p."IdTiersFk" LEFT JOIN logistique."T_Reglements" r ON r."ID_Reglement"=p."IdReglementFk" LEFT JOIN operations."T_Paiement" o ON o."IdPaiement"=p."IdPaiementOrigineFk" LEFT JOIN operations."T_Paiement" cp ON cp."IdPaiementOrigineFk"=p."IdPaiement";

CREATE FUNCTION operations.tr_caisse_validation_automatique_complete()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM operations."T_Paiement" p
        WHERE p."IdPaiement" = NEW."IdPaiement" AND p."EtatEcriture" = 'POSTED'
          AND p."MecanismeValidation" = 'AUTO'
    ) THEN
        RAISE EXCEPTION 'L’écriture doit être validée lors de son enregistrement.' USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END
$$;

CREATE CONSTRAINT TRIGGER tr_caisse_validation_automatique_complete
AFTER INSERT ON operations."T_Paiement" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
WHEN (NEW."ModeValidation" = 'AUTO' AND NEW."EtatEcriture" = 'DRAFT')
EXECUTE FUNCTION operations.tr_caisse_validation_automatique_complete();

CREATE FUNCTION operations.fn_caisse_controle_comptage(p_caisse integer, p_date timestamptz)
RETURNS TABLE (
    "SoldeValide" numeric,
    "EntreesBrouillon" numeric,
    "SortiesBrouillon" numeric,
    "NombreBrouillons" bigint,
    "SoldePrevisionnel" numeric
)
LANGUAGE sql STABLE SET search_path = pg_catalog AS $$
    WITH flux AS (
        SELECT coalesce(sum(p."MontantPaiement" * p."SensMouvement") FILTER (WHERE p."EtatEcriture" = 'POSTED'), 0) AS valide,
               coalesce(sum(p."MontantPaiement") FILTER (WHERE p."EtatEcriture" = 'DRAFT' AND p."SensMouvement" = 1), 0) AS entrees,
               coalesce(sum(p."MontantPaiement") FILTER (WHERE p."EtatEcriture" = 'DRAFT' AND p."SensMouvement" = -1), 0) AS sorties,
               count(*) FILTER (WHERE p."EtatEcriture" = 'DRAFT') AS brouillons
        FROM operations."T_Paiement" p
        WHERE p."IdCaisseFk" = p_caisse AND p."DatePaiement" <= p_date AND p."ValidePaiement"
    )
    SELECT valide, entrees, sorties, brouillons, valide + entrees - sorties FROM flux
$$;

-- Les actions du journal peuvent être restreintes indépendamment de son accès.
ALTER TABLE systeme."T_UtilisateurModule"
    DROP CONSTRAINT utilisateur_module_onglet_check,
    ADD CONSTRAINT utilisateur_module_onglet_check CHECK (
        "CodeOnglet" = ''
        OR ("CodeModule" = 'logistique' AND "CodeOnglet" IN ('dashboard', 'dossiers', 'tiers', 'depots', 'articles', 'lots', 'stocks-depots', 'commandes', 'details', 'transferts', 'mouvements', 'inventaires', 'factures', 'reglements', 'immobilisations'))
        OR ("CodeModule" = 'caisse' AND "CodeOnglet" IN (
            'tableau-de-bord', 'caisses', 'ecritures', 'clotures', 'saisie-ecritures',
            'modification-brouillons', 'validation-ecritures', 'parametres-validation'
        ))
        OR ("CodeModule" = 'support' AND "CodeOnglet" IN ('tableau-de-bord', 'tickets', 'processus'))
        OR ("CodeModule" = 'administration' AND "CodeOnglet" IN ('tableau-de-bord', 'utilisateurs', 'roles', 'permissions', 'entites', 'licences', 'correspondances', 'parametres', 'messagerie', 'audit', 'connexions', 'audit-parametres'))
        OR ("CodeModule" = 'discussions' AND "CodeOnglet" IN ('messages', 'demandes', 'annonces'))
        OR ("CodeModule" = 'professionnels' AND "CodeOnglet" IN ('annuaire', 'profils'))
    );

COMMENT ON CONSTRAINT utilisateur_module_onglet_check ON systeme."T_UtilisateurModule"
    IS 'Liste les sections et actions dont les restrictions individuelles sont contrôlées par le serveur.';

COMMENT ON TABLE operations."T_ParametreValidationCaisse" IS 'Règles de validation des écritures propres à chaque entreprise. Une entreprise sans ligne utilise la validation manuelle.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."IdEntiteFk" IS 'Entreprise propriétaire du paramétrage, indépendante de l’entreprise du compte administrateur.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."ModeValidation" IS 'Mode des nouvelles écritures ordinaires : MANUAL, OTHER_AGENT ou AUTO.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."IdsValidateurs" IS 'Agents habilités par la configuration ; chaque agent admissible peut agir seul, sous réserve de ses droits actuels.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."AutoriseValidationImmediateHistorique" IS 'Compatibilité de la validation immédiate explicite pour les entreprises présentes avant la migration, jusqu’à leur premier changement de réglage.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."IdModifieParFk" IS 'Compte auteur de la dernière modification. La reprise initiale est sans auteur utilisateur.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."ModifieLe" IS 'Instant de la dernière modification du paramétrage.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."MotifModification" IS 'Motif du dernier changement, historisé avec les valeurs précédentes dans le journal d’audit.';
COMMENT ON COLUMN operations."T_ParametreValidationCaisse"."Revision" IS 'Révision monotone pour le contrôle des modifications simultanées.';
COMMENT ON COLUMN operations."T_Paiement"."ModeValidation" IS 'Règle capturée lors de la saisie et conservée pendant toute la vie de l’écriture.';
COMMENT ON COLUMN operations."T_Paiement"."MecanismeValidation" IS 'MANUAL pour une action humaine, AUTO pour un enregistrement automatique, COUNTERPOST pour une contrepassation et SETTLEMENT pour un règlement lié. Les écritures historiques sont interprétées par la vue.';
COMMENT ON COLUMN operations."T_Paiement"."ValidationDesigneeRequise" IS 'Indique si la règle capturée à la saisie exige un agent désigné. La liste des agents admissibles est vérifiée au moment de la validation.';
COMMENT ON COLUMN operations."T_Paiement"."IdValidateurFk" IS 'Compte ayant validé le flux manuellement. Reste vide pour la validation automatique.';
COMMENT ON CONSTRAINT ck_paiement_validation ON operations."T_Paiement" IS 'Une écriture validée conserve sa date, sa devise et le compte du validateur, sauf quand le mécanisme automatique tient lieu de validateur.';
COMMENT ON FUNCTION operations.fn_caisse_mode_validation(integer) IS 'Lit le mode actuel de l’entreprise ; le défaut pour une nouvelle entreprise est la validation manuelle.';
COMMENT ON FUNCTION operations.fn_caisse_validateur_designe(integer, integer) IS 'Vérifie la désignation actuelle et le rattachement actif d’un agent de validation de caisse.';
COMMENT ON FUNCTION operations.tr_parametre_validation_caisse() IS 'Sérialise les réglages par entreprise et exige un auteur actif et un motif traçable.';
COMMENT ON FUNCTION operations.tr_paiement_integrite() IS 'Fixe le mode lors de la saisie et contrôle la validation des écritures, le solde, les clôtures et les liens avec la logistique.';
COMMENT ON FUNCTION operations.fn_caisse_valider(integer, integer, text, uuid, text, bigint) IS 'Valide un brouillon à sa révision attendue et accepte le rejeu exact de la demande.';
COMMENT ON FUNCTION operations.tr_caisse_validation_automatique_complete() IS 'Exige l’achèvement de la validation automatique dans la transaction de création.';
COMMENT ON FUNCTION operations.fn_caisse_controle_comptage(integer, timestamptz) IS 'Calcule à une date métier le solde validé, les flux en brouillon et le solde prévisionnel de la caisse, dans sa propre devise.';
COMMENT ON TRIGGER aa_parametre_validation_caisse ON operations."T_ParametreValidationCaisse" IS 'Contrôle et trace les changements des règles de validation d’une entreprise.';
COMMENT ON TRIGGER trigger_audit_parametre_validation_caisse ON operations."T_ParametreValidationCaisse" IS 'Conserve avant et après chaque changement les réglages et le motif dans le journal d’audit.';
COMMENT ON TRIGGER tr_caisse_validation_automatique_complete ON operations."T_Paiement" IS 'Une saisie automatique se valide dans la transaction de création ou l’ensemble est annulé.';
COMMENT ON VIEW operations."V_Caisse" IS 'Registre des caisses avec solde validé, entrées et sorties en brouillon et solde prévisionnel, par caisse et devise.';
COMMENT ON COLUMN operations."V_Caisse"."EntreesBrouillon" IS 'Somme des encaissements en brouillon actifs, dans la devise de la caisse.';
COMMENT ON COLUMN operations."V_Caisse"."SortiesBrouillon" IS 'Somme positive des décaissements en brouillon actifs, dans la devise de la caisse.';
COMMENT ON COLUMN operations."V_Caisse"."SoldePrevisionnel" IS 'Solde du journal validé augmenté des entrées en brouillon et diminué des sorties en brouillon.';
COMMENT ON COLUMN operations."V_JournalCaisse"."ModeValidation" IS 'Règle capturée au moment de la saisie.';
COMMENT ON COLUMN operations."V_JournalCaisse"."MecanismeValidation" IS 'Mécanisme réel de validation, reconstitué à partir des liens pour les écritures antérieures.';
COMMENT ON COLUMN operations."V_JournalCaisse"."ValidationDesigneeRequise" IS 'La règle de saisie exige un agent désigné.';
