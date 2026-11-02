-- Extrait canonique du catalogue installé le 02/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "operations";
--
-- Name: SCHEMA operations; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA operations IS 'Paiements, archives et caisses par entité et devise, avec routines de mouvement, notification et contrôle.';

--
-- Name: archive_paiements(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.archive_paiements() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO operations."T_Paiement_Archive" (
        "IdPaiement",
        "CodePaiement",
        "IdUserFk",
        "IdTypePaiementFk",
        "MontantPaiement",
        "IdStatutPaiementFk",
        "DatePaiement",
        "ObsPaiement",
        "ValidePaiement",
        "IdDeviseFk",
        "IdPayeurFk",
        "IdTypeMouvementFk",
        "DateArchivage",
        "IdEntiteFk"
    )
    SELECT
        p."IdPaiement",
        p."CodePaiement",
        p."IdUserFk",
        p."IdTypePaiementFk",
        p."MontantPaiement",
        p."IdStatutPaiementFk",
        p."DatePaiement",
        p."ObsPaiement",
        p."ValidePaiement",
        p."IdDeviseFk",
        p."IdPayeurFk",
        p."IdTypeMouvementFk",
        NOW() AS "DateArchivage",
        p."IdEntiteFk"
    FROM operations."T_Paiement" p
    WHERE p."DatePaiement" < NOW() - INTERVAL '2 years';

    DELETE FROM operations."T_Paiement"
    WHERE "DatePaiement" < NOW() - INTERVAL '2 years';

    RETURN NULL;
END;
$$;

--
-- Name: FUNCTION archive_paiements(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.archive_paiements() IS 'Après INSERT/UPDATE sur T_Paiement, copie les paiements âgés de plus de deux ans dans T_Paiement_Archive, puis les supprime de la table active. Déclenchement par instruction, sans planification périodique ; les triggers de suppression de la table active restent applicables.';

--
-- Name: fn_audit_caisse(integer, integer, timestamp without time zone); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_audit_caisse(p_id_entite integer DEFAULT NULL::integer, p_id_devise integer DEFAULT NULL::integer, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("IdEntite" integer, "NomEntite" character varying, "IdDevise" integer, "NomDevise" character varying, "SoldeCaisse" numeric, "SoldeTheorique" numeric, "Ecart" numeric, "NbPaiements" integer, "MontantEntree" numeric, "MontantSortie" numeric)
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT c."IdEntiteFk",c."NomEntite"::varchar,c."IdDeviseFk",c."DeviseLibelle"::varchar,sum(c."MontantCaisse"),coalesce(sum(x.balance),0),CASE WHEN p_date_max IS NULL THEN sum(c."MontantCaisse")-coalesce(sum(x.balance),0) ELSE NULL END,coalesce(sum(x.n),0)::integer,coalesce(sum(x.entree),0),coalesce(sum(x.sortie),0)
 FROM operations."V_Caisse" c
 LEFT JOIN LATERAL(SELECT coalesce(sum("SensMouvement"*"MontantPaiement"),0) balance,sum("MontantPaiement") FILTER(WHERE "SensMouvement"=1) entree,sum("MontantPaiement") FILTER(WHERE "SensMouvement"=-1) sortie,count(*) n FROM operations."T_Paiement" WHERE "IdCaisseFk"=c."IdCaisse" AND "EtatEcriture"='POSTED' AND (p_date_max IS NULL OR "DatePaiement"<=p_date_max AT TIME ZONE 'Africa/Kinshasa')) x ON true
 WHERE (p_id_entite IS NULL OR c."IdEntiteFk"=p_id_entite) AND (p_id_devise IS NULL OR c."IdDeviseFk"=p_id_devise)
 GROUP BY c."IdEntiteFk",c."NomEntite",c."IdDeviseFk",c."DeviseLibelle"
$$;

--
-- Name: FUNCTION fn_audit_caisse(p_id_entite integer, p_id_devise integer, p_date_max timestamp without time zone); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_audit_caisse(p_id_entite integer, p_id_devise integer, p_date_max timestamp without time zone) IS 'Rapprochement du journal moderne par caisse/entreprise/devise ; Ecart reste inconnu pour une borne historique puisque SoldeCaisse est courant.';

--
-- Name: fn_audit_flux_caisse(integer, integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_audit_flux_caisse(p_id_entite integer DEFAULT NULL::integer, p_id_devise integer DEFAULT NULL::integer, p_date_min timestamp without time zone DEFAULT NULL::timestamp without time zone, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("DateJour" timestamp without time zone, "IdEntite" integer, "NomEntite" character varying, "IdDevise" integer, "NomDevise" character varying, "MontantEntree" numeric, "MontantSortie" numeric, "NetJour" numeric)
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT date_trunc('day',p."DatePaiement" AT TIME ZONE 'Africa/Kinshasa'),p."IdEntiteFk",e."NomEntite",p."IdDeviseFk",g."NomGenerique",coalesce(sum(p."MontantPaiement") FILTER(WHERE p."SensMouvement"=1),0),coalesce(sum(p."MontantPaiement") FILTER(WHERE p."SensMouvement"=-1),0),sum(p."SensMouvement"*p."MontantPaiement") FROM operations."T_Paiement" p JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk" JOIN referentiel."T_Generique" g ON g."ID_Generique"=p."IdDeviseFk" WHERE p."EtatEcriture"='POSTED' AND (p_id_entite IS NULL OR p."IdEntiteFk"=p_id_entite) AND (p_id_devise IS NULL OR p."IdDeviseFk"=p_id_devise) AND (p_date_min IS NULL OR p."DatePaiement">=p_date_min AT TIME ZONE 'Africa/Kinshasa') AND (p_date_max IS NULL OR p."DatePaiement"<=p_date_max AT TIME ZONE 'Africa/Kinshasa') GROUP BY 1,2,3,4,5
$$;

--
-- Name: FUNCTION fn_audit_flux_caisse(p_id_entite integer, p_id_devise integer, p_date_min timestamp without time zone, p_date_max timestamp without time zone); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_audit_flux_caisse(p_id_entite integer, p_id_devise integer, p_date_min timestamp without time zone, p_date_max timestamp without time zone) IS 'Flux du journal validé, bornes cohérentes et mêmes règles que le solde ; aucune dépendance aux anciens identifiants fixes.';

--
-- Name: fn_caisse_actor(integer, integer); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_caisse_actor(p_actor integer, p_entite integer) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT EXISTS(SELECT FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=p_actor AND u."ValideUser" AND (u."Is_Admin" OR u."IdEntiteFk"=p_entite))
$$;

--
-- Name: FUNCTION fn_caisse_actor(p_actor integer, p_entite integer); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_caisse_actor(p_actor integer, p_entite integer) IS 'Vérification du rattachement et de l’activité d’un auteur ; ce contrôle de cohérence ne remplace pas les permissions du service.';

--
-- Name: fn_caisse_cloturer(integer, integer, timestamp with time zone, numeric, text, uuid, text, bigint); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_caisse_cloturer(p_caisse integer, p_actor integer, p_date timestamp with time zone, p_compte numeric, p_motif text, p_request uuid, p_hash text, p_revision bigint) RETURNS bigint
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
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
END $_$;

--
-- Name: FUNCTION fn_caisse_cloturer(p_caisse integer, p_actor integer, p_date timestamp with time zone, p_compte numeric, p_motif text, p_request uuid, p_hash text, p_revision bigint); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_caisse_cloturer(p_caisse integer, p_actor integer, p_date timestamp with time zone, p_compte numeric, p_motif text, p_request uuid, p_hash text, p_revision bigint) IS 'Constate un comptage immuable avec révision de caisse et rejeu sûr ; un écart exige un motif et ne génère aucune correction automatique.';

--
-- Name: fn_caisse_contrepasser(integer, integer, text, uuid, text, bigint); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_caisse_contrepasser(p_id integer, p_actor integer, p_motif text, p_request uuid, p_hash text, p_revision bigint) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
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
END $_$;

--
-- Name: FUNCTION fn_caisse_contrepasser(p_id integer, p_actor integer, p_motif text, p_request uuid, p_hash text, p_revision bigint); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_caisse_contrepasser(p_id integer, p_actor integer, p_motif text, p_request uuid, p_hash text, p_revision bigint) IS 'Crée une seule écriture opposée au montant original avec motif ; une compensation ou un règlement lié ne se contre-passe pas par ce circuit.';

--
-- Name: fn_caisse_sens_type(integer); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_caisse_sens_type(p_type integer) RETURNS smallint
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT CASE translate(lower(btrim(g."AbrGenerique")),'éèêàâîïôùûç','eeeaaiiouuc') WHEN 'entree' THEN 1 WHEN 'sortie' THEN -1 ELSE NULL END::smallint FROM referentiel."T_Generique" g WHERE g."ID_Generique"=p_type
$$;

--
-- Name: FUNCTION fn_caisse_sens_type(p_type integer); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_caisse_sens_type(p_type integer) IS 'Résout le sens explicite Entrée/Sortie d’une valeur du référentiel ; le journal conserve son propre signe et ne recalcule pas les validations historiques.';

--
-- Name: fn_caisse_valider(integer, integer, text, uuid, text, bigint); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_caisse_valider(p_id integer, p_actor integer, p_motif text, p_request uuid, p_hash text, p_revision bigint) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
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
END $_$;

--
-- Name: FUNCTION fn_caisse_valider(p_id integer, p_actor integer, p_motif text, p_request uuid, p_hash text, p_revision bigint); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_caisse_valider(p_id integer, p_actor integer, p_motif text, p_request uuid, p_hash text, p_revision bigint) IS 'Valide une seule fois un brouillon avec contrôle de révision et preuve de rejeu UUID/empreinte/acteur ; la garde SQL produit l’effet de caisse.';

--
-- Name: gestion_caisse_on_paiement(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.gestion_caisse_on_paiement() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF NEW."EtatEcriture"='POSTED' AND (TG_OP='INSERT' OR OLD."EtatEcriture"='DRAFT') THEN
  UPDATE operations."T_Caisse" SET "MontantCaisse"="MontantCaisse"+NEW."SensMouvement"*NEW."MontantPaiement" WHERE "IdCaisse"=NEW."IdCaisseFk";
 END IF;RETURN NEW;
END $$;

--
-- Name: FUNCTION gestion_caisse_on_paiement(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.gestion_caisse_on_paiement() IS 'Seul effet de caisse : ajout du montant signé à la première validation d’une écriture ; aucune réévaluation par identifiant de statut ou de devise.';

--
-- Name: notification_payment_success(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.notification_payment_success() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE 
    utilisateur_id INT;
    montant        NUMERIC(10,2);
    devise_nom     VARCHAR;
    statut_nom     VARCHAR;
    mouvement_nom  VARCHAR;
    type_notif     INT;
BEGIN
    -- Récupérer les libellés associés aux IDs (statut, devise, type de mouvement)
    SELECT "NomGenerique"
    INTO statut_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdStatutPaiementFk";

    SELECT "NomGenerique"
    INTO devise_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdDeviseFk";

    SELECT "NomGenerique"
    INTO mouvement_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdTypeMouvementFk";

    -- Récupérer le type de communication "Notification"
    SELECT "ID_Generique"
    INTO type_notif
    FROM referentiel."T_Generique"
    WHERE "NomGenerique" = 'Notification';

    utilisateur_id := NEW."IdUserFk";
    montant        := NEW."MontantPaiement";
    
    -- Vérifier que le statut n'est pas "En attente"
    IF statut_nom NOT IN ('En attente') THEN
        INSERT INTO communication."T_Communication" (
            "IdUserFk",
            "IdTypeCommunication",
            "ContenuCommunication",
            "DateCommunication",
            "ValideCommunication",
            "LectureCommunication",
            "IdEntiteFk"
        )
        VALUES (
            utilisateur_id, 
            type_notif, 
            'Votre paiement de ' || montant || ' ' || devise_nom ||
            ' a été reçu avec succès. Statut: ' || statut_nom ||
            ', Mouvement: ' || mouvement_nom || '.',
            NOW(),
            TRUE,
            FALSE,
            NEW."IdEntiteFk"
        );
    END IF;

    RETURN NEW;
END;
$$;

--
-- Name: FUNCTION notification_payment_success(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.notification_payment_success() IS 'Après INSERT/UPDATE du paiement, ajoute une communication à son utilisateur si le libellé de statut n’est pas En attente. Ne vérifie pas une transition vers payé ni l’absence d’une notification précédente ; le nom de la fonction ne certifie pas un paiement réussi.';

--
-- Name: prevent_delete_caisse_if_dependent(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.prevent_delete_caisse_if_dependent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    ----------------------------------------------------------------------
    -- 1. Vérifier les dépendances dans operations."T_Paiement"
    --    On bloque si au moins un paiement existe pour cette entité/devise
    ----------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM operations."T_Paiement" p
        WHERE p."IdDeviseFk" = OLD."IdDeviseFk"
          AND p."IdEntiteFk" = OLD."IdEntiteFk"
    ) THEN
        RAISE EXCEPTION
            'Suppression impossible : des paiements existent pour cette caisse (Entité=% / Devise=%).',
            OLD."IdEntiteFk", OLD."IdDeviseFk";
    END IF;

    ----------------------------------------------------------------------
    -- 2. Vérifier les dépendances dans operations."T_Paiement_Archive"
    --    On bloque aussi si des paiements ARCHIVÉS existent
    ----------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM operations."T_Paiement_Archive" pa
        WHERE pa."IdDeviseFk" = OLD."IdDeviseFk"
          AND pa."IdEntiteFk" = OLD."IdEntiteFk"
    ) THEN
        RAISE EXCEPTION
            'Suppression impossible : des paiements archivés existent pour cette caisse (Entité=% / Devise=%).',
            OLD."IdEntiteFk", OLD."IdDeviseFk";
    END IF;

    ----------------------------------------------------------------------
    -- Si aucune dépendance → on autorise la suppression
    ----------------------------------------------------------------------
    RETURN OLD;
END;
$$;

--
-- Name: FUNCTION prevent_delete_caisse_if_dependent(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.prevent_delete_caisse_if_dependent() IS 'Avant DELETE de caisse, bloque la suppression s’il existe un paiement actif ou archivé pour le même couple entité/devise.';

--
-- Name: tr_caisse_audit(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.tr_caisse_audit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
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
END $_$;

--
-- Name: FUNCTION tr_caisse_audit(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.tr_caisse_audit() IS 'Un seul événement SQL par changement de caisse/journal/clôture ; images nettoyées, auteur et preuve transactionnelle de demande pour rejouer les mises à jour sans duplication. Les GUC sont des métadonnées et ne donnent aucun droit.';

--
-- Name: tr_caisse_integrite(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.tr_caisse_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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

--
-- Name: FUNCTION tr_caisse_integrite(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.tr_caisse_integrite() IS 'Conserve le code automatique, l’entreprise, la devise et l’identité de création ; contrôle le responsable et l’archivage sans brouillon actif.';

--
-- Name: tr_caisse_solde_rapproche(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.tr_caisse_solde_rapproche() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE theoretical numeric;currentbalance numeric;BEGIN
 SELECT coalesce(sum("SensMouvement"*"MontantPaiement") FILTER(WHERE "EtatEcriture"='POSTED'),0) INTO theoretical FROM operations."T_Paiement" WHERE "IdCaisseFk"=NEW."IdCaisse";
 SELECT "MontantCaisse" INTO currentbalance FROM operations."T_Caisse" WHERE "IdCaisse"=NEW."IdCaisse";
 IF currentbalance IS DISTINCT FROM theoretical THEN RAISE EXCEPTION 'Le solde doit correspondre au journal validé de la caisse.' USING ERRCODE='23514';END IF;RETURN NULL;
END $$;

--
-- Name: FUNCTION tr_caisse_solde_rapproche(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.tr_caisse_solde_rapproche() IS 'Contrainte différée : le solde physique stocké doit égaler la somme du journal validé à la fin de la transaction, y compris après SQL direct.';

--
-- Name: tr_cloture_integrite(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.tr_cloture_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE cash operations."T_Caisse";latest timestamptz;BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'La clôture est immuable.' USING ERRCODE='23514';END IF;
 SELECT * INTO STRICT cash FROM operations."T_Caisse" WHERE "IdCaisse"=NEW."IdCaisseFk" FOR UPDATE;
 IF NOT cash."Actif" OR NOT operations.fn_caisse_actor(NEW."IdUserFk",cash."IdEntiteFk") OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=cash."IdEntiteFk" AND "ValideEntite") THEN RAISE EXCEPTION 'Caisse, entreprise actives et auteur de l’entreprise requis.' USING ERRCODE='23514';END IF;
 SELECT greatest((SELECT max("ClotureLe") FROM operations."T_ClotureCaisse" WHERE "IdCaisseFk"=NEW."IdCaisseFk"),(SELECT max("DatePaiement") FROM operations."T_Paiement" WHERE "IdCaisseFk"=NEW."IdCaisseFk" AND "EtatEcriture"='POSTED')) INTO latest;
 IF NEW."ClotureLe" IS NULL OR NOT isfinite(NEW."ClotureLe") OR NEW."ClotureLe">clock_timestamp()+interval '5 seconds' OR (latest IS NOT NULL AND NEW."ClotureLe"<=latest) THEN RAISE EXCEPTION 'La clôture doit suivre les écritures et clôtures précédentes, sans date future.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT FROM operations."T_Paiement" WHERE "IdCaisseFk"=NEW."IdCaisseFk" AND "EtatEcriture"='DRAFT' AND "ValidePaiement" AND "DatePaiement"<=NEW."ClotureLe") THEN RAISE EXCEPTION 'Traitez ou archivez les brouillons avant de clôturer.' USING ERRCODE='23514';END IF;
 NEW."IdEntiteFk":=cash."IdEntiteFk";NEW."IdDeviseFk":=cash."IdDeviseFk";NEW."SoldeTheorique":=cash."MontantCaisse";NEW."CreeLe":=clock_timestamp();RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_cloture_integrite(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.tr_cloture_integrite() IS 'Capture le solde courant et le contexte au verrouillage, refuse un comptage antidaté/futur, des brouillons antérieurs et toute modification ultérieure.';

--
-- Name: tr_paiement_integrite(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.tr_paiement_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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

--
-- Name: FUNCTION tr_paiement_integrite(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.tr_paiement_integrite() IS 'Verrouille la caisse, dérive propriétaire/devise, contrôle acteurs/tiers/règlement, clôtures, disponibilité et compensation ; une validation ne peut plus être modifiée.';

--
-- Name: tr_reglement_caisse_protege(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.tr_reglement_caisse_protege() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF EXISTS(SELECT FROM operations."T_Paiement" WHERE "IdReglementFk"=OLD."ID_Reglement") THEN RAISE EXCEPTION 'Ce règlement est lié au journal de caisse ; une correction financière dédiée est nécessaire.' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_reglement_caisse_protege(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.tr_reglement_caisse_protege() IS 'Empêche la modification ou suppression d’un règlement déjà relié au journal de caisse ; une correction requiert un circuit financier explicite.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Caisse; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Caisse" (
    "IdCaisse" integer CONSTRAINT "T_Caisse_IdCaisse_not_null" NOT NULL,
    "IdDeviseFk" integer CONSTRAINT "T_Caisse_IdDeviseFk_not_null" NOT NULL,
    "MontantCaisse" numeric DEFAULT 0 CONSTRAINT "T_Caisse_MontantCaisse_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Caisse_IdEntiteFk_not_null" NOT NULL,
    "CodeCaisse" text CONSTRAINT "T_Caisse_CodeCaisse_not_null" NOT NULL,
    "NomCaisse" text CONSTRAINT "T_Caisse_NomCaisse_not_null" NOT NULL,
    "IdTypeCaisseFk" integer,
    "IdResponsableFk" integer,
    "Actif" boolean DEFAULT true CONSTRAINT "T_Caisse_Actif_not_null" NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_Caisse_CreeLe_not_null" NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_Caisse_ModifieLe_not_null" NOT NULL,
    "Revision" bigint DEFAULT 1 CONSTRAINT "T_Caisse_Revision_not_null" NOT NULL,
    "CreationRequestId" uuid,
    "CreationPayloadHash" text,
    CONSTRAINT ck_caisse_creation CHECK (((("CreationRequestId" IS NULL) = ("CreationPayloadHash" IS NULL)) AND (("CreationPayloadHash" IS NULL) OR ("CreationPayloadHash" ~ '^[a-f0-9]{64}$'::text)))),
    CONSTRAINT ck_caisse_nom CHECK (((length(btrim("NomCaisse")) >= 1) AND (length(btrim("NomCaisse")) <= 200))),
    CONSTRAINT ck_caisse_revision CHECK (("Revision" > 0)),
    CONSTRAINT ck_caisse_solde CHECK ((("MontantCaisse" >= (0)::numeric) AND ("MontantCaisse" <= 9999999999999999.99) AND ("MontantCaisse" = round("MontantCaisse", 2))))
);

--
-- Name: TABLE "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Caisse" IS 'Caisse mono-devise appartenant durablement à une entreprise ; le solde est exclusivement rapproché du journal validé. Plusieurs caisses distinctes peuvent utiliser la même devise.';

--
-- Name: COLUMN "T_Caisse"."IdCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdCaisse" IS 'Identifiant de la caisse.';

--
-- Name: COLUMN "T_Caisse"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts. Relation imposée : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Caisse"."MontantCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."MontantCaisse" IS 'Solde exact au centime issu exclusivement des écritures POSTED ; contrôlé contre leur somme en fin de transaction. Ouverture initiale à zéro.';

--
-- Name: COLUMN "T_Caisse"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdEntiteFk" IS 'Entreprise propriétaire durable, obligatoire et immuable ; sa suppression ne peut effacer cette caisse.';

--
-- Name: COLUMN "T_Caisse"."CodeCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."CodeCaisse" IS 'Code d’inventaire de caisse automatique CAI-ID, immuable et distinct du libellé.';

--
-- Name: COLUMN "T_Caisse"."NomCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."NomCaisse" IS 'Nom lisible de la caisse dans son entreprise.';

--
-- Name: COLUMN "T_Caisse"."IdTypeCaisseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdTypeCaisseFk" IS 'Type de caisse choisi dans la catégorie configurable du référentiel.';

--
-- Name: COLUMN "T_Caisse"."IdResponsableFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdResponsableFk" IS 'Compte responsable de la caisse ; aucune permission ne découle de cette affectation.';

--
-- Name: COLUMN "T_Caisse"."Actif"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."Actif" IS 'Caisse utilisable pour les nouvelles écritures ; les caisses archivées restent consultables.';

--
-- Name: COLUMN "T_Caisse"."CreeLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."CreeLe" IS 'Instant technique de création ; conservé pour la traçabilité.';

--
-- Name: COLUMN "T_Caisse"."ModifieLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."ModifieLe" IS 'Instant technique de dernière modification autorisée.';

--
-- Name: COLUMN "T_Caisse"."Revision"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."Revision" IS 'Version SQL monotone pour le contrôle des modifications simultanées.';

--
-- Name: COLUMN "T_Caisse"."CreationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."CreationRequestId" IS 'Identifiant de demande initiale pour rejouer sans duplication.';

--
-- Name: COLUMN "T_Caisse"."CreationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."CreationPayloadHash" IS 'Empreinte SHA-256 du contenu initial ; vérifiée lors du rejeu.';

--
-- Name: CONSTRAINT "T_Caisse_IdCaisse_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdCaisse_not_null" ON operations."T_Caisse" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Caisse". Définition : NOT NULL "IdCaisse".';

--
-- Name: CONSTRAINT "T_Caisse_IdDeviseFk_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdDeviseFk_not_null" ON operations."T_Caisse" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Caisse". Définition : NOT NULL "IdDeviseFk".';

--
-- Name: CONSTRAINT "T_Caisse_MontantCaisse_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_MontantCaisse_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_MontantCaisse_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Caisse_IdEntiteFk_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdEntiteFk_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_IdEntiteFk_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Caisse_CodeCaisse_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_CodeCaisse_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_CodeCaisse_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Caisse_NomCaisse_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_NomCaisse_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_NomCaisse_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Caisse_Actif_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_Actif_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_Actif_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Caisse_CreeLe_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_CreeLe_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_CreeLe_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Caisse_ModifieLe_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_ModifieLe_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_ModifieLe_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Caisse_Revision_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_Revision_not_null" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_Revision_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_caisse_creation ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_caisse_creation ON operations."T_Caisse" IS 'Intégrité de caisse : ck_caisse_creation ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_caisse_nom ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_caisse_nom ON operations."T_Caisse" IS 'Intégrité de caisse : ck_caisse_nom ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_caisse_revision ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_caisse_revision ON operations."T_Caisse" IS 'Intégrité de caisse : ck_caisse_revision ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_caisse_solde ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_caisse_solde ON operations."T_Caisse" IS 'Intégrité de caisse : ck_caisse_solde ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Caisse_IdCaisse_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Caisse" ALTER COLUMN "IdCaisse" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Caisse_IdCaisse_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Caisse_IdCaisse_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Caisse_IdCaisse_seq" IS 'Séquence de génération de "operations"."T_Caisse"."IdCaisse". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_ClotureCaisse; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_ClotureCaisse" (
    "ID_ClotureCaisse" bigint CONSTRAINT "T_ClotureCaisse_ID_ClotureCaisse_not_null" NOT NULL,
    "IdCaisseFk" integer CONSTRAINT "T_ClotureCaisse_IdCaisseFk_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_ClotureCaisse_IdEntiteFk_not_null" NOT NULL,
    "IdDeviseFk" integer CONSTRAINT "T_ClotureCaisse_IdDeviseFk_not_null" NOT NULL,
    "ClotureLe" timestamp with time zone CONSTRAINT "T_ClotureCaisse_ClotureLe_not_null" NOT NULL,
    "SoldeTheorique" numeric CONSTRAINT "T_ClotureCaisse_SoldeTheorique_not_null" NOT NULL,
    "MontantCompte" numeric CONSTRAINT "T_ClotureCaisse_MontantCompte_not_null" NOT NULL,
    "Ecart" numeric GENERATED ALWAYS AS (("MontantCompte" - "SoldeTheorique")) STORED,
    "Motif" text,
    "IdUserFk" integer CONSTRAINT "T_ClotureCaisse_IdUserFk_not_null" NOT NULL,
    "CreationRequestId" uuid CONSTRAINT "T_ClotureCaisse_CreationRequestId_not_null" NOT NULL,
    "CreationPayloadHash" text CONSTRAINT "T_ClotureCaisse_CreationPayloadHash_not_null" NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_ClotureCaisse_CreeLe_not_null" NOT NULL,
    CONSTRAINT ck_cloture_centimes CHECK ((("MontantCompte" >= (0)::numeric) AND ("MontantCompte" <= 9999999999999999.99) AND ("MontantCompte" = round("MontantCompte", 2)))),
    CONSTRAINT ck_cloture_hash CHECK (("CreationPayloadHash" ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT ck_cloture_motif CHECK ((("MontantCompte" = "SoldeTheorique") OR (COALESCE(length(btrim("Motif")), 0) > 0)))
);

--
-- Name: TABLE "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_ClotureCaisse" IS 'Constat physique immuable du montant compté face au solde théorique au verrouillage ; ne génère ni correction automatique ni mouvement de caisse.';

--
-- Name: COLUMN "T_ClotureCaisse"."ID_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."ID_ClotureCaisse" IS 'Identifiant de constat de clôture, non réutilisable.';

--
-- Name: COLUMN "T_ClotureCaisse"."IdCaisseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."IdCaisseFk" IS 'Caisse comptée et verrouillée lors de la clôture.';

--
-- Name: COLUMN "T_ClotureCaisse"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."IdEntiteFk" IS 'Entreprise copiée de la caisse, jamais déduite du compte courant.';

--
-- Name: COLUMN "T_ClotureCaisse"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."IdDeviseFk" IS 'Devise copiée de la caisse ; aucune conversion implicite.';

--
-- Name: COLUMN "T_ClotureCaisse"."ClotureLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."ClotureLe" IS 'Date et heure limite du constat ; bloque la validation d’écritures antérieures ou égales.';

--
-- Name: COLUMN "T_ClotureCaisse"."SoldeTheorique"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."SoldeTheorique" IS 'Solde du journal capturé au verrouillage de la caisse.';

--
-- Name: COLUMN "T_ClotureCaisse"."MontantCompte"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."MontantCompte" IS 'Montant réellement compté, positif ou nul et exact au centime.';

--
-- Name: COLUMN "T_ClotureCaisse"."Ecart"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."Ecart" IS 'Différence générée : montant compté moins solde théorique.';

--
-- Name: COLUMN "T_ClotureCaisse"."Motif"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."Motif" IS 'Justification obligatoire lorsque le comptage diffère du théorique.';

--
-- Name: COLUMN "T_ClotureCaisse"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."IdUserFk" IS 'Auteur du constat physique de caisse.';

--
-- Name: COLUMN "T_ClotureCaisse"."CreationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."CreationRequestId" IS 'Identifiant de demande initiale pour rejouer sans duplication.';

--
-- Name: COLUMN "T_ClotureCaisse"."CreationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."CreationPayloadHash" IS 'Empreinte SHA-256 du contenu initial ; vérifiée lors du rejeu.';

--
-- Name: COLUMN "T_ClotureCaisse"."CreeLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_ClotureCaisse"."CreeLe" IS 'Instant technique de création ; conservé pour la traçabilité.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_ID_ClotureCaisse_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_ID_ClotureCaisse_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_ID_ClotureCaisse_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdCaisseFk_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdCaisseFk_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdCaisseFk_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdEntiteFk_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdEntiteFk_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdEntiteFk_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdDeviseFk_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdDeviseFk_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdDeviseFk_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_ClotureLe_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_ClotureLe_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_ClotureLe_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_SoldeTheorique_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_SoldeTheorique_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_SoldeTheorique_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_MontantCompte_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_MontantCompte_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_MontantCompte_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdUserFk_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdUserFk_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdUserFk_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_CreationRequestId_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_CreationRequestId_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_CreationRequestId_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_CreationPayloadHash_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_CreationPayloadHash_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_CreationPayloadHash_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_ClotureCaisse_CreeLe_not_null" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_CreeLe_not_null" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_CreeLe_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_cloture_centimes ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_cloture_centimes ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : ck_cloture_centimes ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_cloture_hash ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_cloture_hash ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : ck_cloture_hash ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_cloture_motif ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_cloture_motif ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : ck_cloture_motif ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_ClotureCaisse_ID_ClotureCaisse_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_ClotureCaisse" ALTER COLUMN "ID_ClotureCaisse" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_ClotureCaisse_ID_ClotureCaisse_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Paiement; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Paiement" (
    "IdPaiement" integer CONSTRAINT "T_Paiement_IdPaiement_not_null" NOT NULL,
    "CodePaiement" character varying(25),
    "IdUserFk" integer CONSTRAINT "T_Paiement_IdUserFk_not_null" NOT NULL,
    "IdTypePaiementFk" integer,
    "MontantPaiement" numeric CONSTRAINT "T_Paiement_MontantPaiement_not_null" NOT NULL,
    "IdStatutPaiementFk" integer,
    "DatePaiement" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "ObsPaiement" text,
    "ValidePaiement" boolean DEFAULT true CONSTRAINT "T_Paiement_ValidePaiement_not_null" NOT NULL,
    "IdDeviseFk" integer CONSTRAINT "T_Paiement_IdDeviseFk_not_null" NOT NULL,
    "IdPayeurFk" integer,
    "IdTypeMouvementFk" integer,
    "IdEntiteFk" integer CONSTRAINT "T_Paiement_IdEntiteFk_not_null" NOT NULL,
    "IdCaisseFk" integer CONSTRAINT "T_Paiement_IdCaisseFk_not_null" NOT NULL,
    "SensMouvement" smallint CONSTRAINT "T_Paiement_SensMouvement_not_null" NOT NULL,
    "EtatEcriture" text DEFAULT 'DRAFT'::text CONSTRAINT "T_Paiement_EtatEcriture_not_null" NOT NULL,
    "LibellePaiement" text CONSTRAINT "T_Paiement_LibellePaiement_not_null" NOT NULL,
    "ReferenceExterne" text,
    "IdTiersFk" bigint,
    "IdReglementFk" integer,
    "IdPaiementOrigineFk" integer,
    "CreationRequestId" uuid,
    "CreationPayloadHash" text,
    "ValidationRequestId" uuid,
    "ValidationPayloadHash" text,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_Paiement_CreeLe_not_null" NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_Paiement_ModifieLe_not_null" NOT NULL,
    "ValideLe" timestamp with time zone,
    "IdValidateurFk" integer,
    "Revision" bigint DEFAULT 1 CONSTRAINT "T_Paiement_Revision_not_null" NOT NULL,
    "DeviseCodeSnapshot" text,
    CONSTRAINT chk_montant_paiement CHECK (("MontantPaiement" > (0)::numeric)),
    CONSTRAINT ck_paiement_centimes CHECK ((("MontantPaiement" = round("MontantPaiement", 2)) AND ("MontantPaiement" <= 9999999999999999.99))),
    CONSTRAINT ck_paiement_creation CHECK (((("CreationRequestId" IS NULL) = ("CreationPayloadHash" IS NULL)) AND (("CreationPayloadHash" IS NULL) OR ("CreationPayloadHash" ~ '^[a-f0-9]{64}$'::text)))),
    CONSTRAINT ck_paiement_etat CHECK (("EtatEcriture" = ANY (ARRAY['DRAFT'::text, 'POSTED'::text]))),
    CONSTRAINT ck_paiement_libelle CHECK (((length(btrim("LibellePaiement")) >= 1) AND (length(btrim("LibellePaiement")) <= 500))),
    CONSTRAINT ck_paiement_rejeu_validation CHECK (((("ValidationRequestId" IS NULL) = ("ValidationPayloadHash" IS NULL)) AND (("ValidationPayloadHash" IS NULL) OR ("ValidationPayloadHash" ~ '^[a-f0-9]{64}$'::text)))),
    CONSTRAINT ck_paiement_revision CHECK (("Revision" > 0)),
    CONSTRAINT ck_paiement_sens CHECK (("SensMouvement" = ANY (ARRAY['-1'::integer, 1]))),
    CONSTRAINT ck_paiement_validation CHECK (((("EtatEcriture" = 'POSTED'::text) = (("ValideLe" IS NOT NULL) AND ("IdValidateurFk" IS NOT NULL) AND ("DeviseCodeSnapshot" IS NOT NULL))) AND (("EtatEcriture" <> 'POSTED'::text) OR "ValidePaiement")))
);

--
-- Name: TABLE "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Paiement" IS 'Journal de caisse : brouillons archivables, validations immuables et contrepassations uniques. Les règlements de facture liés sont prouvés sans seconde création financière.';

--
-- Name: COLUMN "T_Paiement"."IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdPaiement" IS 'Identifiant du paiement ; conservé depuis le paiement source dans la table d’archives.';

--
-- Name: COLUMN "T_Paiement"."CodePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."CodePaiement" IS 'Référence métier du paiement.';

--
-- Name: COLUMN "T_Paiement"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Paiement"."IdTypePaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdTypePaiementFk" IS 'Motif catégoriel facultatif, configuré dans T_ChampReferentiel ; ne détermine ni signe ni état de validation.';

--
-- Name: COLUMN "T_Paiement"."MontantPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."MontantPaiement" IS 'Montant positif exact au centime, sans arrondi implicite PostgreSQL ; le sens financier est stocké séparément.';

--
-- Name: COLUMN "T_Paiement"."IdStatutPaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdStatutPaiementFk" IS 'Ancienne classification conservée et référencée ; EtatEcriture reste la seule autorité du journal moderne.';

--
-- Name: COLUMN "T_Paiement"."DatePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."DatePaiement" IS 'Date métier complète de l’opération, finie et non future ; une clôture bloque les validations antérieures ou égales.';

--
-- Name: COLUMN "T_Paiement"."ObsPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ObsPaiement" IS 'Observations enregistrées sur le paiement.';

--
-- Name: COLUMN "T_Paiement"."ValidePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ValidePaiement" IS 'Brouillon actif ou archivé ; une écriture POSTED reste toujours active et immuable.';

--
-- Name: COLUMN "T_Paiement"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts. Relation imposée : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Paiement"."IdPayeurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdPayeurFk" IS 'Payeur enregistré pour le paiement. Relation imposée : FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "T_Paiement"."IdTypeMouvementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdTypeMouvementFk" IS 'Référence historique facultative Entrée/Sortie ; si renseignée elle doit correspondre au signe explicite de l’écriture.';

--
-- Name: COLUMN "T_Paiement"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdEntiteFk" IS 'Entreprise copiée de la caisse ; indépendante d’un éventuel changement ultérieur du compte créateur.';

--
-- Name: COLUMN "T_Paiement"."IdCaisseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdCaisseFk" IS 'Caisse propriétaire du flux ; détermine immuablement entreprise et devise.';

--
-- Name: COLUMN "T_Paiement"."SensMouvement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."SensMouvement" IS 'Signe financier capturé : +1 entrée, -1 sortie ; indépendant du libellé courant du référentiel.';

--
-- Name: COLUMN "T_Paiement"."EtatEcriture"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."EtatEcriture" IS 'DRAFT sans effet de solde ou POSTED irréversible ; une correction crée une contrepassation.';

--
-- Name: COLUMN "T_Paiement"."LibellePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."LibellePaiement" IS 'Objet lisible de l’encaissement ou du décaissement.';

--
-- Name: COLUMN "T_Paiement"."ReferenceExterne"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ReferenceExterne" IS 'Référence facultative du justificatif ou de l’opération externe ; ne constitue pas une clé financière.';

--
-- Name: COLUMN "T_Paiement"."IdTiersFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdTiersFk" IS 'Tiers facultatif de la même entreprise, sans déduction depuis un texte saisi.';

--
-- Name: COLUMN "T_Paiement"."IdReglementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdReglementFk" IS 'Règlement logistique d’origine unique, de même montant/devise/entreprise ; aucune deuxième dette ou recette créée.';

--
-- Name: COLUMN "T_Paiement"."IdPaiementOrigineFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdPaiementOrigineFk" IS 'Écriture validée compensée, au plus une fois et pour le même montant opposé.';

--
-- Name: COLUMN "T_Paiement"."CreationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."CreationRequestId" IS 'Identifiant de demande initiale pour rejouer sans duplication.';

--
-- Name: COLUMN "T_Paiement"."CreationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."CreationPayloadHash" IS 'Empreinte SHA-256 du contenu initial ; vérifiée lors du rejeu.';

--
-- Name: COLUMN "T_Paiement"."ValidationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ValidationRequestId" IS 'Identifiant de demande de validation, distinct de l’identité métier.';

--
-- Name: COLUMN "T_Paiement"."ValidationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ValidationPayloadHash" IS 'Empreinte SHA-256 de la demande de validation pour un rejeu exact.';

--
-- Name: COLUMN "T_Paiement"."CreeLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."CreeLe" IS 'Instant technique de création ; conservé pour la traçabilité.';

--
-- Name: COLUMN "T_Paiement"."ModifieLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ModifieLe" IS 'Instant technique de dernière modification autorisée.';

--
-- Name: COLUMN "T_Paiement"."ValideLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ValideLe" IS 'Instant technique de première validation, distinct de la date métier.';

--
-- Name: COLUMN "T_Paiement"."IdValidateurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdValidateurFk" IS 'Compte ayant validé le flux ; contrôle de rattachement conservé.';

--
-- Name: COLUMN "T_Paiement"."Revision"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."Revision" IS 'Version SQL monotone pour le contrôle des modifications simultanées.';

--
-- Name: COLUMN "T_Paiement"."DeviseCodeSnapshot"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."DeviseCodeSnapshot" IS 'Code de devise capturé à la validation pour les réimpressions historiques.';

--
-- Name: CONSTRAINT "T_Paiement_IdPaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdPaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdPaiement".';

--
-- Name: CONSTRAINT "T_Paiement_IdUserFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdUserFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdUserFk".';

--
-- Name: CONSTRAINT "T_Paiement_MontantPaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_MontantPaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "MontantPaiement".';

--
-- Name: CONSTRAINT "T_Paiement_ValidePaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_ValidePaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "ValidePaiement".';

--
-- Name: CONSTRAINT "T_Paiement_IdDeviseFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdDeviseFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdDeviseFk".';

--
-- Name: CONSTRAINT "T_Paiement_IdEntiteFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdEntiteFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdEntiteFk".';

--
-- Name: CONSTRAINT "T_Paiement_IdCaisseFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdCaisseFk_not_null" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdCaisseFk_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Paiement_SensMouvement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_SensMouvement_not_null" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_SensMouvement_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Paiement_EtatEcriture_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_EtatEcriture_not_null" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_EtatEcriture_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Paiement_LibellePaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_LibellePaiement_not_null" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_LibellePaiement_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Paiement_CreeLe_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_CreeLe_not_null" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_CreeLe_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Paiement_ModifieLe_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_ModifieLe_not_null" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_ModifieLe_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT "T_Paiement_Revision_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_Revision_not_null" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_Revision_not_null ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT chk_montant_paiement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT chk_montant_paiement ON operations."T_Paiement" IS 'Contrôle de cohérence des valeurs autorisées dans "operations"."T_Paiement". Définition : CHECK ("MontantPaiement" > 0::numeric).';

--
-- Name: CONSTRAINT ck_paiement_centimes ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_centimes ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_centimes ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_paiement_creation ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_creation ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_creation ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_paiement_etat ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_etat ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_etat ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_paiement_libelle ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_libelle ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_libelle ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_paiement_rejeu_validation ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_rejeu_validation ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_rejeu_validation ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_paiement_revision ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_revision ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_revision ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_paiement_sens ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_sens ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_sens ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: CONSTRAINT ck_paiement_validation ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT ck_paiement_validation ON operations."T_Paiement" IS 'Intégrité de caisse : ck_paiement_validation ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement_Archive; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Paiement_Archive" (
    "IdPaiement" integer,
    "CodePaiement" character varying(25),
    "IdUserFk" integer,
    "IdTypePaiementFk" integer,
    "MontantPaiement" numeric(10,2),
    "IdStatutPaiementFk" integer,
    "DatePaiement" timestamp with time zone,
    "ObsPaiement" text,
    "ValidePaiement" boolean,
    "IdDeviseFk" integer,
    "IdPayeurFk" integer,
    "IdTypeMouvementFk" integer,
    "DateArchivage" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "IdEntiteFk" integer,
    "IdPaiementArchive" integer CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" NOT NULL
);

--
-- Name: TABLE "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Paiement_Archive" IS 'Archive des paiements déplacés depuis T_Paiement, avec identifiant du paiement source, identifiant propre d’archive et date d’archivage. Utilisée avec les paiements actifs par le contrôle de caisse.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPaiement" IS 'Identifiant du paiement ; conservé depuis le paiement source dans la table d’archives.';

--
-- Name: COLUMN "T_Paiement_Archive"."CodePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."CodePaiement" IS 'Référence métier du paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdTypePaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdTypePaiementFk" IS 'Type métier du paiement dans le référentiel.';

--
-- Name: COLUMN "T_Paiement_Archive"."MontantPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."MontantPaiement" IS 'Montant du paiement dans IdDeviseFk ; strictement positif sur T_Paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdStatutPaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdStatutPaiementFk" IS 'Statut de paiement dans le référentiel ; les règles de caisse et d’audit déterminent les statuts retenus.';

--
-- Name: COLUMN "T_Paiement_Archive"."DatePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."DatePaiement" IS 'Date et heure du paiement ; sert aux regroupements de flux et à l’archivage.';

--
-- Name: COLUMN "T_Paiement_Archive"."ObsPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."ObsPaiement" IS 'Observations enregistrées sur le paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."ValidePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."ValidePaiement" IS 'Indique si le paiement est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdPayeurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPayeurFk" IS 'Payeur enregistré pour le paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdTypeMouvementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdTypeMouvementFk" IS 'Sens/type du mouvement de paiement dans le référentiel ; distinct du type de mouvement de stock.';

--
-- Name: COLUMN "T_Paiement_Archive"."DateArchivage"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."DateArchivage" IS 'Horodatage du déplacement du paiement vers les archives.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdPaiementArchive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPaiementArchive" IS 'Identifiant propre de la ligne d’archive du paiement.';

--
-- Name: CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" ON operations."T_Paiement_Archive" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement_Archive". Définition : NOT NULL "IdPaiementArchive".';

--
-- Name: T_Paiement_Archive_IdPaiementArchive_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Paiement_Archive" ALTER COLUMN "IdPaiementArchive" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Paiement_Archive_IdPaiementArchive_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Paiement_Archive_IdPaiementArchive_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Paiement_Archive_IdPaiementArchive_seq" IS 'Séquence de génération de "operations"."T_Paiement_Archive"."IdPaiementArchive". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Paiement_IdPaiement_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Paiement" ALTER COLUMN "IdPaiement" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Paiement_IdPaiement_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Paiement_IdPaiement_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Paiement_IdPaiement_seq" IS 'Séquence de génération de "operations"."T_Paiement"."IdPaiement". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Paiement Pk_IdPaiement; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Pk_IdPaiement" PRIMARY KEY ("IdPaiement");

--
-- Name: CONSTRAINT "Pk_IdPaiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdPaiement" ON operations."T_Paiement" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Paiement". Définition : PRIMARY KEY ("IdPaiement").';

--
-- Name: T_Caisse T_Caisse_CreationRequestId_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "T_Caisse_CreationRequestId_key" UNIQUE ("CreationRequestId");

--
-- Name: CONSTRAINT "T_Caisse_CreationRequestId_key" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_CreationRequestId_key" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_CreationRequestId_key ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Caisse T_Caisse_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "T_Caisse_pkey" PRIMARY KEY ("IdCaisse");

--
-- Name: CONSTRAINT "T_Caisse_pkey" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_pkey" ON operations."T_Caisse" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Caisse". Définition : PRIMARY KEY ("IdCaisse").';

--
-- Name: T_ClotureCaisse T_ClotureCaisse_CreationRequestId_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_ClotureCaisse"
    ADD CONSTRAINT "T_ClotureCaisse_CreationRequestId_key" UNIQUE ("CreationRequestId");

--
-- Name: CONSTRAINT "T_ClotureCaisse_CreationRequestId_key" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_CreationRequestId_key" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_CreationRequestId_key ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_ClotureCaisse T_ClotureCaisse_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_ClotureCaisse"
    ADD CONSTRAINT "T_ClotureCaisse_pkey" PRIMARY KEY ("ID_ClotureCaisse");

--
-- Name: CONSTRAINT "T_ClotureCaisse_pkey" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_pkey" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_pkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement_Archive T_Paiement_Archive_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement_Archive"
    ADD CONSTRAINT "T_Paiement_Archive_pkey" PRIMARY KEY ("IdPaiementArchive");

--
-- Name: CONSTRAINT "T_Paiement_Archive_pkey" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_Archive_pkey" ON operations."T_Paiement_Archive" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Paiement_Archive". Définition : PRIMARY KEY ("IdPaiementArchive").';

--
-- Name: T_Paiement T_Paiement_CreationRequestId_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_CreationRequestId_key" UNIQUE ("CreationRequestId");

--
-- Name: CONSTRAINT "T_Paiement_CreationRequestId_key" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_CreationRequestId_key" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_CreationRequestId_key ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_IdPaiementOrigineFk_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_IdPaiementOrigineFk_key" UNIQUE ("IdPaiementOrigineFk");

--
-- Name: CONSTRAINT "T_Paiement_IdPaiementOrigineFk_key" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdPaiementOrigineFk_key" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdPaiementOrigineFk_key ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_IdReglementFk_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_IdReglementFk_key" UNIQUE ("IdReglementFk");

--
-- Name: CONSTRAINT "T_Paiement_IdReglementFk_key" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdReglementFk_key" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdReglementFk_key ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_ValidationRequestId_key; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_ValidationRequestId_key" UNIQUE ("ValidationRequestId");

--
-- Name: CONSTRAINT "T_Paiement_ValidationRequestId_key" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_ValidationRequestId_key" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_ValidationRequestId_key ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Caisse uq_caisse_code; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT uq_caisse_code UNIQUE ("CodeCaisse");

--
-- Name: CONSTRAINT uq_caisse_code ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT uq_caisse_code ON operations."T_Caisse" IS 'Intégrité de caisse : uq_caisse_code ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement uq_paiement_code; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT uq_paiement_code UNIQUE ("CodePaiement");

--
-- Name: CONSTRAINT uq_paiement_code ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT uq_paiement_code ON operations."T_Paiement" IS 'Intégrité de caisse : uq_paiement_code ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: INDEX "Pk_IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."Pk_IdPaiement" IS 'Index support de la clé primaire sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdPaiement" ON operations."T_Paiement" USING btree ("IdPaiement").';

--
-- Name: INDEX "T_Caisse_pkey"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."T_Caisse_pkey" IS 'Index support de la clé primaire sur "operations"."T_Caisse". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Caisse_pkey" ON operations."T_Caisse" USING btree ("IdCaisse").';

--
-- Name: INDEX "T_Paiement_Archive_pkey"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."T_Paiement_Archive_pkey" IS 'Index support de la clé primaire sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Paiement_Archive_pkey" ON operations."T_Paiement_Archive" USING btree ("IdPaiementArchive").';

--
-- Name: idx_fk_paiement_user; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_fk_paiement_user ON operations."T_Paiement" USING btree ("IdUserFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_fk_paiement_user; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_fk_paiement_user IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fk_paiement_user ON operations."T_Paiement" USING btree ("IdUserFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: idx_paiement_archive_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_date ON operations."T_Paiement_Archive" USING btree ("DatePaiement");

--
-- Name: INDEX idx_paiement_archive_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_date IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_date ON operations."T_Paiement_Archive" USING btree ("DatePaiement").';

--
-- Name: idx_paiement_archive_entite; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_entite ON operations."T_Paiement_Archive" USING btree ("IdEntiteFk");

--
-- Name: INDEX idx_paiement_archive_entite; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_entite IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_entite ON operations."T_Paiement_Archive" USING btree ("IdEntiteFk").';

--
-- Name: idx_paiement_archive_idpaiement; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_idpaiement ON operations."T_Paiement_Archive" USING btree ("IdPaiement");

--
-- Name: INDEX idx_paiement_archive_idpaiement; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_idpaiement IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_idpaiement ON operations."T_Paiement_Archive" USING btree ("IdPaiement").';

--
-- Name: idx_paiement_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_date ON operations."T_Paiement" USING btree ("DatePaiement") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_paiement_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_date IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_date ON operations."T_Paiement" USING btree ("DatePaiement") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: idx_paiement_devise; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_devise ON operations."T_Paiement" USING btree ("IdDeviseFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_paiement_devise; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_devise IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_devise ON operations."T_Paiement" USING btree ("IdDeviseFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: idx_paiement_entite_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_entite_date ON operations."T_Paiement" USING btree ("IdEntiteFk", "DatePaiement");

--
-- Name: INDEX idx_paiement_entite_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_entite_date IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_entite_date ON operations."T_Paiement" USING btree ("IdEntiteFk", "DatePaiement").';

--
-- Name: idx_paiement_statut; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_statut ON operations."T_Paiement" USING btree ("IdStatutPaiementFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_paiement_statut; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_statut IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_statut ON operations."T_Paiement" USING btree ("IdStatutPaiementFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: ix_cloture_caisse_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX ix_cloture_caisse_date ON operations."T_ClotureCaisse" USING btree ("IdCaisseFk", "ClotureLe" DESC);

--
-- Name: INDEX ix_cloture_caisse_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.ix_cloture_caisse_date IS 'Recherche de la dernière clôture et garde contre les écritures antidatées.';

--
-- Name: ix_paiement_caisse_etat_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX ix_paiement_caisse_etat_date ON operations."T_Paiement" USING btree ("IdCaisseFk", "EtatEcriture", "DatePaiement", "IdPaiement");

--
-- Name: INDEX ix_paiement_caisse_etat_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.ix_paiement_caisse_etat_date IS 'Parcours et rapprochement du journal de chaque caisse par état et date métier.';

--
-- Name: ix_paiement_entite_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX ix_paiement_entite_date ON operations."T_Paiement" USING btree ("IdEntiteFk", "DatePaiement" DESC);

--
-- Name: INDEX ix_paiement_entite_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.ix_paiement_entite_date IS 'Filtrage du journal par entreprise et période sans mélange de propriétaires.';

--
-- Name: T_ClotureCaisse aa_cloture_integrite; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER aa_cloture_integrite BEFORE INSERT OR DELETE OR UPDATE ON operations."T_ClotureCaisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_cloture_integrite();

--
-- Name: TRIGGER aa_cloture_integrite ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER aa_cloture_integrite ON operations."T_ClotureCaisse" IS 'Garde du journal de caisse : aa_cloture_integrite ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_Paiement aa_owners_paiement; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER aa_owners_paiement BEFORE INSERT OR DELETE OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.tr_paiement_integrite();

--
-- Name: TRIGGER aa_owners_paiement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER aa_owners_paiement ON operations."T_Paiement" IS 'Garde du journal de caisse : aa_owners_paiement ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_Caisse aa_reference_champ; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON operations."T_Caisse" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Paiement aa_reference_champ; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON operations."T_Paiement" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Caisse ab_caisse_integrite; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER ab_caisse_integrite BEFORE INSERT OR DELETE OR UPDATE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_integrite();

--
-- Name: TRIGGER ab_caisse_integrite ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER ab_caisse_integrite ON operations."T_Caisse" IS 'Garde du journal de caisse : ab_caisse_integrite ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_Caisse ck_caisse_journal; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE CONSTRAINT TRIGGER ck_caisse_journal AFTER INSERT OR UPDATE ON operations."T_Caisse" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_solde_rapproche();

--
-- Name: TRIGGER ck_caisse_journal ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER ck_caisse_journal ON operations."T_Caisse" IS 'Garde du journal de caisse : ck_caisse_journal ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_Paiement trigger_archive_paiements; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_archive_paiements AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH STATEMENT EXECUTE FUNCTION operations.archive_paiements();

ALTER TABLE operations."T_Paiement" DISABLE TRIGGER trigger_archive_paiements;

--
-- Name: TRIGGER trigger_archive_paiements ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_archive_paiements ON operations."T_Paiement" IS 'AFTER INSERT OR UPDATE sur "operations"."T_Paiement", par instruction. Appelle "operations"."archive_paiements" : Après INSERT/UPDATE sur T_Paiement, copie les paiements âgés de plus de deux ans dans T_Paiement_Archive, puis les supprime de la table active. Déclenchement par instruction, sans planification périodique ; les triggers de suppression de la table active restent applicables.';

--
-- Name: T_Caisse trigger_audit_T_Caisse; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Caisse" AFTER INSERT OR UPDATE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_audit();

--
-- Name: TRIGGER "trigger_audit_T_Caisse" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Caisse" ON operations."T_Caisse" IS 'Garde du journal de caisse : trigger_audit_T_Caisse ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_ClotureCaisse trigger_audit_T_ClotureCaisse; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER "trigger_audit_T_ClotureCaisse" AFTER INSERT ON operations."T_ClotureCaisse" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_audit();

--
-- Name: TRIGGER "trigger_audit_T_ClotureCaisse" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_ClotureCaisse" ON operations."T_ClotureCaisse" IS 'Garde du journal de caisse : trigger_audit_T_ClotureCaisse ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_Paiement trigger_audit_T_Paiement; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Paiement" AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.tr_caisse_audit();

--
-- Name: TRIGGER "trigger_audit_T_Paiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Paiement" ON operations."T_Paiement" IS 'Garde du journal de caisse : trigger_audit_T_Paiement ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_Paiement trigger_gestion_caisse_on_paiement; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_gestion_caisse_on_paiement AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.gestion_caisse_on_paiement();

--
-- Name: TRIGGER trigger_gestion_caisse_on_paiement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_gestion_caisse_on_paiement ON operations."T_Paiement" IS 'Garde du journal de caisse : trigger_gestion_caisse_on_paiement ; validation SQL, historique et rapprochement du solde.';

--
-- Name: T_Caisse trigger_prevention_delete_caisse; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_prevention_delete_caisse BEFORE DELETE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION operations.prevent_delete_caisse_if_dependent();

--
-- Name: TRIGGER trigger_prevention_delete_caisse ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_prevention_delete_caisse ON operations."T_Caisse" IS 'BEFORE DELETE sur "operations"."T_Caisse", pour chaque ligne. Appelle "operations"."prevent_delete_caisse_if_dependent" : Avant DELETE de caisse, bloque la suppression s’il existe un paiement actif ou archivé pour le même couple entité/devise.';

--
-- Name: T_Caisse Fk_IdDevise; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "Fk_IdDevise" FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdDevise" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdDevise" ON operations."T_Caisse" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Caisse". Définition : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Paiement Fk_IdDevise; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdDevise" FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdDevise" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdDevise" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Caisse Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Caisse" IS 'Intégrité de caisse : Fk_IdEntite ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Paiement" IS 'Intégrité de caisse : Fk_IdEntite ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement_Archive Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement_Archive"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Paiement_Archive" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement_Archive". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: T_Paiement Fk_IdPayeurFk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdPayeurFk" FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "Fk_IdPayeurFk" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdPayeurFk" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: T_Paiement Fk_IdTypePaiement; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdTypePaiement" FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdTypePaiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypePaiement" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Paiement Fk_IdUserFk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdUserFk" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdUserFk" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUserFk" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';

--
-- Name: T_Caisse T_Caisse_IdResponsableFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "T_Caisse_IdResponsableFk_fkey" FOREIGN KEY ("IdResponsableFk") REFERENCES systeme."T_Utilisateurs"("IdUser");

--
-- Name: CONSTRAINT "T_Caisse_IdResponsableFk_fkey" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdResponsableFk_fkey" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_IdResponsableFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Caisse T_Caisse_IdTypeCaisseFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "T_Caisse_IdTypeCaisseFk_fkey" FOREIGN KEY ("IdTypeCaisseFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "T_Caisse_IdTypeCaisseFk_fkey" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdTypeCaisseFk_fkey" ON operations."T_Caisse" IS 'Intégrité de caisse : T_Caisse_IdTypeCaisseFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_ClotureCaisse T_ClotureCaisse_IdCaisseFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_ClotureCaisse"
    ADD CONSTRAINT "T_ClotureCaisse_IdCaisseFk_fkey" FOREIGN KEY ("IdCaisseFk") REFERENCES operations."T_Caisse"("IdCaisse") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdCaisseFk_fkey" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdCaisseFk_fkey" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdCaisseFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_ClotureCaisse T_ClotureCaisse_IdDeviseFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_ClotureCaisse"
    ADD CONSTRAINT "T_ClotureCaisse_IdDeviseFk_fkey" FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdDeviseFk_fkey" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdDeviseFk_fkey" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdDeviseFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_ClotureCaisse T_ClotureCaisse_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_ClotureCaisse"
    ADD CONSTRAINT "T_ClotureCaisse_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdEntiteFk_fkey" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdEntiteFk_fkey" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdEntiteFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_ClotureCaisse T_ClotureCaisse_IdUserFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_ClotureCaisse"
    ADD CONSTRAINT "T_ClotureCaisse_IdUserFk_fkey" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser");

--
-- Name: CONSTRAINT "T_ClotureCaisse_IdUserFk_fkey" ON "T_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_ClotureCaisse_IdUserFk_fkey" ON operations."T_ClotureCaisse" IS 'Intégrité de caisse : T_ClotureCaisse_IdUserFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_IdCaisseFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_IdCaisseFk_fkey" FOREIGN KEY ("IdCaisseFk") REFERENCES operations."T_Caisse"("IdCaisse");

--
-- Name: CONSTRAINT "T_Paiement_IdCaisseFk_fkey" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdCaisseFk_fkey" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdCaisseFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_IdPaiementOrigineFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_IdPaiementOrigineFk_fkey" FOREIGN KEY ("IdPaiementOrigineFk") REFERENCES operations."T_Paiement"("IdPaiement") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Paiement_IdPaiementOrigineFk_fkey" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdPaiementOrigineFk_fkey" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdPaiementOrigineFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_IdReglementFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_IdReglementFk_fkey" FOREIGN KEY ("IdReglementFk") REFERENCES logistique."T_Reglements"("ID_Reglement") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Paiement_IdReglementFk_fkey" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdReglementFk_fkey" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdReglementFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_IdTiersFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_IdTiersFk_fkey" FOREIGN KEY ("IdTiersFk") REFERENCES logistique."T_Client"("ID_Client");

--
-- Name: CONSTRAINT "T_Paiement_IdTiersFk_fkey" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdTiersFk_fkey" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdTiersFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement T_Paiement_IdValidateurFk_fkey; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "T_Paiement_IdValidateurFk_fkey" FOREIGN KEY ("IdValidateurFk") REFERENCES systeme."T_Utilisateurs"("IdUser");

--
-- Name: CONSTRAINT "T_Paiement_IdValidateurFk_fkey" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdValidateurFk_fkey" ON operations."T_Paiement" IS 'Intégrité de caisse : T_Paiement_IdValidateurFk_fkey ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement fk_paiement_statut; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT fk_paiement_statut FOREIGN KEY ("IdStatutPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT fk_paiement_statut ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT fk_paiement_statut ON operations."T_Paiement" IS 'Intégrité de caisse : fk_paiement_statut ; montants exacts, historique conservé et rattachements prouvés.';

--
-- Name: T_Paiement fk_paiement_type_mouvement; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT fk_paiement_type_mouvement FOREIGN KEY ("IdTypeMouvementFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT fk_paiement_type_mouvement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT fk_paiement_type_mouvement ON operations."T_Paiement" IS 'Intégrité de caisse : fk_paiement_type_mouvement ; montants exacts, historique conservé et rattachements prouvés.';

COMMENT ON CONSTRAINT "ck_caisse_journal" ON "operations"."T_Caisse" IS 'Intégrité de caisse : ck_caisse_journal ; montants exacts, historique conservé et rattachements prouvés.';
