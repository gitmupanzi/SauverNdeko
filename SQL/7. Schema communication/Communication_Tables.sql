-- Extrait canonique PostgreSQL 18 après migration demandes suivies du 07/11/2026.
-- Sans données ni propriétaires. Installation : baseline puis migrations du manifeste.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- PostgreSQL database dump
--


-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


--
-- Name: communication; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA communication;



--
-- Name: SCHEMA communication; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA communication IS 'Discussions, messages de conversation et communications adressées aux utilisateurs et entités.';



--
-- Name: fn_dater_lecture_annonce(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_dater_lecture_annonce() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
    IF OLD."IdAnnonceFk" IS NOT NULL THEN
        IF OLD."LectureCommunication" AND NOT NEW."LectureCommunication" THEN
            RAISE EXCEPTION 'La lecture d’une annonce ne peut pas être annulée.' USING ERRCODE = '23514';
        END IF;
        NEW."LuLe" := CASE WHEN NEW."LectureCommunication"
                           THEN COALESCE(OLD."LuLe", CURRENT_TIMESTAMP) END;
    END IF;
    RETURN NEW;
END
$$;



--
-- Name: FUNCTION fn_dater_lecture_annonce(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_dater_lecture_annonce() IS 'Date la première lecture d’une annonce individuelle sans changer les anciennes notifications.';



--
-- Name: fn_demande_compte_autorise(integer, boolean); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_compte_autorise(p_user integer, p_gestion boolean DEFAULT false) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT EXISTS (
  SELECT FROM systeme."T_Utilisateurs" u
  LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk"
  JOIN systeme."T_ModuleApplication" m ON m."CodeModule"='discussions' AND m."Actif"
  LEFT JOIN systeme."T_RoleModule" r ON r."CodeModule"=m."CodeModule" AND r."IdEntiteFk"=u."IdEntiteFk" AND r."IdRoleFk"=u."IdRoleFk"
  WHERE u."IdUser"=p_user AND u."ValideUser" IS TRUE AND
   (u."Is_Admin" IS TRUE OR ((e."ValideEntite" IS TRUE OR u."IdEntiteFk" IS NULL)
    AND ((u."IdEntiteFk" IS NULL AND m."AccessibleSansEntite") OR EXISTS (
     SELECT FROM systeme."V_EntiteModuleActif" x WHERE x."IdEntiteFk"=u."IdEntiteFk" AND x."CodeModule"='discussions'))
    AND (r."IdRoleModule" IS NULL OR (r."Actif" AND r."PeutConsulter" AND (NOT p_gestion OR r."PeutGerer")))))
 )
$$;



--
-- Name: FUNCTION fn_demande_compte_autorise(p_user integer, p_gestion boolean); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_compte_autorise(p_user integer, p_gestion boolean) IS 'Vérifie le compte actif, l’entreprise réelle et la licence/règle Discussions ; le contexte choisi dans l’interface ne change jamais l’identité.';



--
-- Name: fn_demande_creer(integer, text, integer, text, text, numeric, text, uuid); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_creer(p_user integer, p_type text, p_id integer, p_sujet text, p_description text, p_quantite numeric, p_destination text, p_cle uuid) RETURNS bigint
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE s jsonb; n bigint; org integer; h communication."T_DemandeHistorique"%ROWTYPE;
 payload jsonb:=jsonb_build_object('action','creation','sourceType',p_type,'sourceId',p_id,'subject',btrim(p_sujet),
 'description',btrim(p_description),'quantity',p_quantite,'destination',nullif(btrim(p_destination),''));
BEGIN
 IF NOT communication.fn_demande_compte_autorise(p_user,true) THEN RAISE EXCEPTION 'Accès Discussions requis.' USING ERRCODE='PDE02'; END IF;
 IF p_cle IS NULL OR char_length(btrim(p_sujet)) NOT BETWEEN 1 AND 160 OR char_length(btrim(p_description)) NOT BETWEEN 1 AND 5000
 OR p_sujet IS NULL OR p_description IS NULL OR p_sujet ~ '[\r\n]' OR char_length(p_destination)>300 THEN
  RAISE EXCEPTION 'Vérifiez l’objet et la description.' USING ERRCODE='PDE04'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('demande:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_DemandeHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND THEN
  IF h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
  RETURN h."IdDemandeFk";
 END IF;
 -- Le verrou de la fiche source empêche de publier une demande pendant son retrait.
 IF p_type='product' THEN
  PERFORM FROM logistique."T_Article" WHERE "ID_Article"=p_id FOR SHARE;
 ELSIF p_type='expert' THEN
  PERFORM FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=p_id FOR SHARE;
 ELSIF p_type IN ('structure_n3','structure_n4','structure_n5') THEN
  PERFORM pg_advisory_xact_lock(hashtextextended('routage:'||p_type||':'||p_id,0));
  IF p_type='structure_n3' THEN PERFORM FROM geolocalisation."T_Niveau_3" WHERE "ID_Niveau_3"=p_id FOR SHARE;
  ELSIF p_type='structure_n4' THEN PERFORM FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=p_id FOR SHARE;
  ELSE PERFORM FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=p_id FOR SHARE; END IF;
 END IF;
 s:=communication.fn_demande_source(p_type,p_id);
 IF s IS NULL THEN RAISE EXCEPTION 'Cette fiche n’est plus publiée.' USING ERRCODE='PDE01'; END IF;
 IF (s->>'userId')::integer=p_user THEN RAISE EXCEPTION 'Vous ne pouvez pas vous adresser cette demande.' USING ERRCODE='PDE04'; END IF;
 IF s->>'userId' IS NOT NULL THEN
  PERFORM FROM systeme."T_Utilisateurs" WHERE "IdUser"=(s->>'userId')::integer FOR SHARE;
  PERFORM FROM systeme."T_Entite" e JOIN systeme."T_Utilisateurs" u ON u."IdEntiteFk"=e."IdEntite"
   WHERE u."IdUser"=(s->>'userId')::integer FOR SHARE OF e;
  IF NOT communication.fn_demande_compte_autorise((s->>'userId')::integer,false) THEN RAISE EXCEPTION 'Destinataire indisponible.' USING ERRCODE='PDE03'; END IF;
 ELSIF s->>'entityId' IS NOT NULL THEN
  PERFORM FROM systeme."T_Entite" WHERE "IdEntite"=(s->>'entityId')::integer AND "ValideEntite" IS TRUE FOR SHARE;
  IF NOT FOUND OR NOT EXISTS (SELECT FROM systeme."T_Utilisateurs" u WHERE communication.fn_demande_gestionnaire(u."IdUser",(s->>'entityId')::integer)) THEN
   RAISE EXCEPTION 'Aucun gestionnaire autorisé pour cette entreprise.' USING ERRCODE='PDE03'; END IF;
 ELSE RAISE EXCEPTION 'Aucun destinataire vérifié pour cette structure.' USING ERRCODE='PDE03'; END IF;
 IF communication.fn_demande_source(p_type,p_id) IS DISTINCT FROM s THEN
  RAISE EXCEPTION 'La fiche publiée a changé pendant l’opération.' USING ERRCODE='PDE03'; END IF;
 IF p_quantite IS NOT NULL AND (p_type<>'product' OR p_quantite<=0 OR p_quantite>=1000000000000000
  OR p_quantite<>round(p_quantite,coalesce((s->>'quantityDecimals')::integer,0))) THEN
  RAISE EXCEPTION 'Quantité incompatible avec l’unité du produit.' USING ERRCODE='PDE04'; END IF;
 SELECT "IdEntiteFk" INTO org FROM systeme."T_Utilisateurs" WHERE "IdUser"=p_user FOR SHARE;
 INSERT INTO communication."T_Demande" ("IdDemandeurFk","IdEntiteDemandeurFk","TypeSource","IdArticleFk","IdProfessionnelFk","IdNiveau3Fk","IdNiveau4Fk","IdNiveau5Fk",
  "LibelleSource","IdDestinataireUserFk","IdEntiteDestinataireFk","SujetDemande","DescriptionDemande","QuantiteSouhaitee","UniteSouhaitee","DestinationDemande")
 VALUES(p_user,org,p_type,CASE WHEN p_type='product' THEN p_id END,CASE WHEN p_type='expert' THEN p_id END,
 CASE WHEN p_type='structure_n3' THEN p_id END,CASE WHEN p_type='structure_n4' THEN p_id END,CASE WHEN p_type='structure_n5' THEN p_id END,
 s->>'label',(s->>'userId')::integer,(s->>'entityId')::integer,btrim(p_sujet),btrim(p_description),p_quantite,s->>'unit',nullif(btrim(p_destination),'')) RETURNING "IdDemande" INTO n;
 INSERT INTO communication."T_DemandeHistorique" ("IdDemandeFk","IdAuteurFk","ActionDemande","EtatApres","CleRequete","ContenuRequete")
 VALUES(n,p_user,'creation','en_attente',p_cle,payload);
 RETURN n;
END $$;



--
-- Name: FUNCTION fn_demande_creer(p_user integer, p_type text, p_id integer, p_sujet text, p_description text, p_quantite numeric, p_destination text, p_cle uuid); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_creer(p_user integer, p_type text, p_id integer, p_sujet text, p_description text, p_quantite numeric, p_destination text, p_cle uuid) IS 'Crée atomiquement une demande et son historique après validation de la publication, du destinataire et de la quantité exacte facultative ; rejeu sans doublon.';



--
-- Name: fn_demande_discussion(integer, bigint, integer, uuid); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_discussion(p_user integer, p_id bigint, p_version integer, p_cle uuid) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE d communication."T_Demande"%ROWTYPE; h communication."T_DemandeHistorique"%ROWTYPE; n integer;
 payload jsonb:=jsonb_build_object('action','discussion','id',p_id,'version',p_version);
BEGIN
 IF p_cle IS NULL OR NOT communication.fn_demande_compte_autorise(p_user,true) OR NOT communication.fn_demande_participant(p_user,p_id) THEN
  RAISE EXCEPTION 'Demande inaccessible.' USING ERRCODE='PDE02'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('demande:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_DemandeHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND AND h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
 SELECT * INTO d FROM communication."T_Demande" WHERE "IdDemande"=p_id FOR UPDATE;
 IF h."IdHistorique" IS NULL AND d."VersionDemande" IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Fiche modifiée par un autre utilisateur.' USING ERRCODE='PDE05'; END IF;
 SELECT "IdDiscussion" INTO n FROM communication."T_Discussion" WHERE "IdDemandeFk"=p_id;
 IF n IS NULL THEN
  INSERT INTO communication."T_Discussion" ("IdUserClientFk","TypeDiscussion","SujetDiscussion","IdDemandeFk")
  VALUES(d."IdDemandeurFk",'demande',d."CodeDemande"||' · '||d."SujetDemande",p_id) RETURNING "IdDiscussion" INTO n;
 END IF;
 IF h."IdHistorique" IS NULL THEN
  INSERT INTO communication."T_DemandeHistorique" ("IdDemandeFk","IdAuteurFk","ActionDemande","EtatAvant","EtatApres","CleRequete","ContenuRequete")
  VALUES(p_id,p_user,'discussion',d."EtatDemande",d."EtatDemande",p_cle,payload);
 END IF;
 RETURN n;
END $$;



--
-- Name: FUNCTION fn_demande_discussion(p_user integer, p_id bigint, p_version integer, p_cle uuid); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_discussion(p_user integer, p_id bigint, p_version integer, p_cle uuid) IS 'Ouvre sur action explicite une unique conversation liée à la demande pour ses participants, sans message, stock, facture ni notification automatique.';



--
-- Name: fn_demande_garder_historique(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_garder_historique() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 RAISE EXCEPTION 'L’historique des demandes ne peut pas être modifié ou supprimé.' USING ERRCODE='PDE03';
END $$;



--
-- Name: FUNCTION fn_demande_garder_historique(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_garder_historique() IS 'Interdit modification et suppression des historiques de demande et de routage.';



--
-- Name: fn_demande_gestionnaire(integer, integer); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_gestionnaire(p_user integer, p_entite integer) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT EXISTS (SELECT FROM systeme."T_Utilisateurs" u
 LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique"=u."IdRoleFk"
 JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk" AND e."ValideEntite" IS TRUE
 WHERE u."IdUser"=p_user AND u."ValideUser" IS TRUE AND u."IdEntiteFk"=p_entite
 AND (u."Is_Admin" IS TRUE OR u."Is_staff" IS TRUE OR lower(coalesce(r."NomGenerique",'')) IN ('admin','administrateur'))
 AND communication.fn_demande_compte_autorise(p_user,false))
$$;



--
-- Name: FUNCTION fn_demande_gestionnaire(p_user integer, p_entite integer); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_gestionnaire(p_user integer, p_entite integer) IS 'Gestionnaire actif de l’entreprise destinataire réelle, avec accès Discussions ; un administrateur global sans rattachement réel ne devient pas participant.';



--
-- Name: fn_demande_participant(integer, bigint); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_participant(p_user integer, p_demande bigint) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT communication.fn_demande_compte_autorise(p_user,false) AND EXISTS (
 SELECT FROM communication."T_Demande" d WHERE d."IdDemande"=p_demande AND (
 d."IdDemandeurFk"=p_user OR d."IdDestinataireUserFk"=p_user
 OR communication.fn_demande_gestionnaire(p_user,d."IdEntiteDestinataireFk")))
$$;



--
-- Name: FUNCTION fn_demande_participant(p_user integer, p_demande bigint); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_participant(p_user integer, p_demande bigint) IS 'Accès privé : demandeur, destinataire professionnel figé ou gestionnaire de l’entreprise destinataire ; aucun privilège global implicite.';



--
-- Name: fn_demande_proteger_identite(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_proteger_identite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une demande suivie reste dans l’historique.' USING ERRCODE='PDE03'; END IF;
 -- Une colonne générée est recalculée après BEFORE UPDATE : ne pas comparer sa valeur NEW.
 IF (to_jsonb(NEW)-ARRAY['CodeDemande','EtatDemande','VersionDemande','ModifieLe']) IS DISTINCT FROM
    (to_jsonb(OLD)-ARRAY['CodeDemande','EtatDemande','VersionDemande','ModifieLe']) THEN
  RAISE EXCEPTION 'L’identité, la source et le destinataire de la demande sont figés.' USING ERRCODE='PDE03';
 END IF;
 IF NEW."VersionDemande"<>OLD."VersionDemande"+1 OR OLD."EtatDemande" IN ('satisfaite','non_satisfaite','annulee')
 OR NOT ((OLD."EtatDemande"='en_attente' AND NEW."EtatDemande" IN ('en_cours','non_satisfaite','annulee'))
 OR (OLD."EtatDemande"='en_cours' AND NEW."EtatDemande" IN ('satisfaite','non_satisfaite','annulee'))) THEN
  RAISE EXCEPTION 'Transition incompatible avec l’état de la demande.' USING ERRCODE='PDE03';
 END IF;
 NEW."ModifieLe":=CURRENT_TIMESTAMP;
 RETURN NEW;
END $$;



--
-- Name: FUNCTION fn_demande_proteger_identite(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_proteger_identite() IS 'Fige l’identité et la source, impose les cinq états, leur sens de transition et la révision monotone ; aucun effacement des demandes.';



--
-- Name: fn_demande_routage(integer, text, integer, integer, integer, text, uuid); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_routage(p_user integer, p_type text, p_id integer, p_entite integer, p_version integer, p_motif text, p_cle uuid) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE r communication."T_RoutageStructure"%ROWTYPE; h communication."T_RoutageStructureHistorique"%ROWTYPE; v integer;
 payload jsonb:=jsonb_build_object('action','routage','sourceType',p_type,'sourceId',p_id,'entityId',p_entite,'version',p_version,'reason',btrim(p_motif));
BEGIN
 IF NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=p_user AND "Is_Admin" IS TRUE AND "ValideUser" IS TRUE)
 OR NOT communication.fn_demande_compte_autorise(p_user,true) THEN RAISE EXCEPTION 'Administration globale requise.' USING ERRCODE='PDE02'; END IF;
 IF p_cle IS NULL OR p_type NOT IN ('structure_n3','structure_n4','structure_n5') OR p_motif IS NULL OR char_length(btrim(p_motif)) NOT BETWEEN 1 AND 1000
 THEN RAISE EXCEPTION 'Structure et motif obligatoires.' USING ERRCODE='PDE04'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('routage-requete:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_RoutageStructureHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND THEN
  IF h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
  RETURN h."VersionRoutage";
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('routage:'||p_type||':'||p_id,0));
 IF communication.fn_demande_source(p_type,p_id) IS NULL THEN RAISE EXCEPTION 'Structure non publiée.' USING ERRCODE='PDE01'; END IF;
 SELECT * INTO r FROM communication."T_RoutageStructure" WHERE "TypeSource"=p_type AND "IdSource"=p_id FOR UPDATE;
 IF coalesce(r."VersionRoutage",0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Routage modifié par un autre administrateur.' USING ERRCODE='PDE05'; END IF;
 IF p_entite IS NULL THEN
  IF r."IdEntiteFk" IS NULL THEN RAISE EXCEPTION 'Aucun routage à désactiver.' USING ERRCODE='PDE04'; END IF;
 ELSE
  PERFORM FROM systeme."T_Entite" WHERE "IdEntite"=p_entite AND "ValideEntite" IS TRUE FOR SHARE;
  IF NOT FOUND OR NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" u WHERE communication.fn_demande_gestionnaire(u."IdUser",p_entite)) THEN
   RAISE EXCEPTION 'Entreprise sans gestionnaire Discussions autorisé.' USING ERRCODE='PDE04'; END IF;
 END IF;
 v:=p_version+1;
 INSERT INTO communication."T_RoutageStructure" ("TypeSource","IdSource","IdNiveau3Fk","IdNiveau4Fk","IdNiveau5Fk","IdEntiteFk","VersionRoutage","IdVerificateurFk","Actif")
 VALUES(p_type,p_id,CASE WHEN p_type='structure_n3' THEN p_id END,CASE WHEN p_type='structure_n4' THEN p_id END,CASE WHEN p_type='structure_n5' THEN p_id END,coalesce(p_entite,r."IdEntiteFk"),v,p_user,p_entite IS NOT NULL)
 ON CONFLICT("TypeSource","IdSource") DO UPDATE SET "IdEntiteFk"=excluded."IdEntiteFk","VersionRoutage"=excluded."VersionRoutage","IdVerificateurFk"=p_user,"ModifieLe"=CURRENT_TIMESTAMP,"Actif"=excluded."Actif";
 INSERT INTO communication."T_RoutageStructureHistorique" ("TypeSource","IdSource","IdEntiteAvantFk","IdEntiteApresFk","VersionRoutage","IdAuteurFk","MotifRoutage","CleRequete","ContenuRequete")
 VALUES(p_type,p_id,r."IdEntiteFk",p_entite,v,p_user,btrim(p_motif),p_cle,payload);
 RETURN v;
END $$;



--
-- Name: FUNCTION fn_demande_routage(p_user integer, p_type text, p_id integer, p_entite integer, p_version integer, p_motif text, p_cle uuid); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_routage(p_user integer, p_type text, p_id integer, p_entite integer, p_version integer, p_motif text, p_cle uuid) IS 'Validation globale explicite du représentant d’une structure territoriale, avec motif, concurrence et historique ; ne change pas les anciens dossiers.';



--
-- Name: fn_demande_source(text, integer); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_source(p_type text, p_id integer) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE v jsonb;
BEGIN
 IF p_type='product' THEN
  SELECT jsonb_build_object('type',p_type,'id',p_id,'label',o."NomArticle",'entityId',o."IdEntite",'recipientName',o."NomEntite",
   'unit',o."Unite",'quantityDecimals',coalesce(pr."DecimalesStock",0)) INTO v
  FROM logistique."V_OffreArticle" o JOIN logistique."T_Article" a ON a."ID_Article"=o."ID_Article"
  LEFT JOIN logistique."T_PrecisionStock" pr ON pr."ID_UniteFk"=a."ID_UniteFk" WHERE o."ID_Article"=p_id;
 ELSIF p_type='expert' THEN
  SELECT jsonb_build_object('type',p_type,'id',p_id,'label',p."NomComplet",'userId',p."IdUserFk",'recipientName',p."NomComplet") INTO v
  FROM professionnel."V_Professionnel_Public" p WHERE p."IdProfessionnel"=p_id AND p."ContactAutorise" IS TRUE;
 ELSIF p_type IN ('structure_n3','structure_n4','structure_n5') THEN
  SELECT jsonb_build_object('type',p_type,'id',p_id,'label',s."NomStructure",'entityId',CASE WHEN r."Actif" AND e."IdEntite" IS NOT NULL THEN r."IdEntiteFk" END,'recipientName',CASE WHEN r."Actif" THEN e."NomEntite" END) INTO v
  FROM geolocalisation."V_StructureSanitairePublique" s
  LEFT JOIN communication."T_RoutageStructure" r ON r."TypeSource"=p_type AND r."IdSource"=p_id
  LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=r."IdEntiteFk" AND e."ValideEntite" IS TRUE
  WHERE s."NiveauStructure"=right(p_type,1)::integer AND s."ID_Structure"=p_id;
 END IF;
 RETURN v;
END $$;



--
-- Name: FUNCTION fn_demande_source(p_type text, p_id integer); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_source(p_type text, p_id integer) IS 'Projection publique minimale publiée et destinataire vérifié ; ne retourne ni quantité de stock exacte, coût d’achat ni coordonnées privées.';



--
-- Name: fn_demande_transition(integer, bigint, text, integer, text, uuid); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_demande_transition(p_user integer, p_id bigint, p_etat text, p_version integer, p_motif text, p_cle uuid) RETURNS bigint
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE d communication."T_Demande"%ROWTYPE; h communication."T_DemandeHistorique"%ROWTYPE; requester boolean; receiver boolean;
 payload jsonb:=jsonb_build_object('action','transition','id',p_id,'state',p_etat,'version',p_version,'reason',btrim(p_motif));
BEGIN
 IF p_cle IS NULL OR NOT communication.fn_demande_compte_autorise(p_user,true) OR NOT communication.fn_demande_participant(p_user,p_id) THEN
  RAISE EXCEPTION 'Demande inaccessible.' USING ERRCODE='PDE02'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('demande:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_DemandeHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND THEN
  IF h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
  RETURN h."IdDemandeFk";
 END IF;
 SELECT * INTO d FROM communication."T_Demande" WHERE "IdDemande"=p_id FOR UPDATE;
 IF d."VersionDemande" IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Fiche modifiée par un autre utilisateur.' USING ERRCODE='PDE05'; END IF;
 requester:=d."IdDemandeurFk"=p_user;
 receiver:=coalesce(d."IdDestinataireUserFk"=p_user,false) OR communication.fn_demande_gestionnaire(p_user,d."IdEntiteDestinataireFk");
 IF p_motif IS NULL OR char_length(btrim(p_motif))>1000 OR (p_etat<>'en_cours' AND char_length(btrim(p_motif))<1) THEN RAISE EXCEPTION 'Un motif est obligatoire pour cette transition.' USING ERRCODE='PDE04'; END IF;
 IF NOT ((requester AND p_etat IN ('annulee','non_satisfaite')) OR (requester AND p_etat='satisfaite' AND d."EtatDemande"='en_cours')
 OR (receiver AND p_etat IN ('en_cours','non_satisfaite'))) THEN RAISE EXCEPTION 'Action réservée au participant autorisé.' USING ERRCODE='PDE02'; END IF;
 UPDATE communication."T_Demande" SET "EtatDemande"=p_etat,"VersionDemande"="VersionDemande"+1 WHERE "IdDemande"=p_id;
 INSERT INTO communication."T_DemandeHistorique" ("IdDemandeFk","IdAuteurFk","ActionDemande","EtatAvant","EtatApres","MotifDemande","CleRequete","ContenuRequete")
 VALUES(p_id,p_user,'transition',d."EtatDemande",p_etat,btrim(p_motif),p_cle,payload);
 RETURN p_id;
END $$;



--
-- Name: FUNCTION fn_demande_transition(p_user integer, p_id bigint, p_etat text, p_version integer, p_motif text, p_cle uuid); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_demande_transition(p_user integer, p_id bigint, p_etat text, p_version integer, p_motif text, p_cle uuid) IS 'Transition métier avec droits du participant réel, motif, verrou, révision et rejeu exact ; historique conservé.';



--
-- Name: fn_diffuser_annonce(integer, integer[], text, text, uuid); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_diffuser_annonce(p_auteur integer, p_entites integer[], p_sujet text, p_contenu text, p_cle uuid) RETURNS TABLE("IdAnnonce" bigint, "Rejouee" boolean)
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
    v_global boolean;
    v_admin boolean;
    v_entite integer;
    v_portee text := CASE WHEN p_entites IS NULL THEN 'toutes' ELSE 'entreprises' END;
    v_sujet text := btrim(p_sujet);
    v_contenu text := btrim(p_contenu);
    v_cibles integer[];
    v_rejeu communication."T_Annonce"%ROWTYPE;
    v_id bigint;
    v_publication timestamptz := CURRENT_TIMESTAMP;
    v_cibles_actives bigint;
    v_entreprises bigint;
    v_livraisons bigint;
BEGIN
    SELECT u."Is_Admin" IS TRUE,
           u."Is_staff" IS TRUE OR lower(coalesce(r."NomGenerique", '')) IN ('admin', 'administrateur'),
           u."IdEntiteFk"
    INTO v_global, v_admin, v_entite
    FROM systeme."T_Utilisateurs" u
    LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique" = u."IdRoleFk"
    WHERE u."IdUser" = p_auteur AND u."ValideUser" IS TRUE
    FOR SHARE OF u;

    IF NOT FOUND OR (NOT v_global AND (NOT v_admin OR v_entite IS NULL)) THEN
        RAISE EXCEPTION 'Diffusion réservée aux administrateurs autorisés.' USING ERRCODE = 'PCO01';
    END IF;

    IF p_entites IS NOT NULL THEN
        IF array_ndims(p_entites) IS DISTINCT FROM 1 OR cardinality(p_entites) > 100
            OR EXISTS (SELECT FROM unnest(p_entites) AS ids(id) WHERE id IS NULL OR id <= 0) THEN
            RAISE EXCEPTION 'Sélectionnez des entreprises valides.' USING ERRCODE = 'PCO02';
        END IF;
        v_cibles := ARRAY(SELECT DISTINCT id FROM unnest(p_entites) AS ids(id) ORDER BY id);
    END IF;

    IF NOT v_global AND v_cibles IS DISTINCT FROM ARRAY[v_entite] THEN
        RAISE EXCEPTION 'Vous pouvez uniquement diffuser à votre entreprise.' USING ERRCODE = 'PCO01';
    END IF;

    IF p_cle IS NULL OR v_sujet IS NULL OR char_length(v_sujet) NOT BETWEEN 1 AND 160
        OR v_sujet ~ '[\r\n]' OR v_sujet !~ '\S'
        OR v_contenu IS NULL OR char_length(v_contenu) NOT BETWEEN 1 AND 5000 OR v_contenu !~ '\S' THEN
        RAISE EXCEPTION 'Renseignez un sujet et un message valides.' USING ERRCODE = 'PCO05';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended('communication.annonce:' || p_auteur || ':' || p_cle, 0));
    SELECT a.* INTO v_rejeu
    FROM communication."T_Annonce" a
    WHERE a."IdAuteurFk" = p_auteur AND a."CleRequete" = p_cle;
    IF FOUND THEN
        IF v_rejeu."EmisParPlateforme" IS DISTINCT FROM v_global
            OR v_rejeu."IdEntiteFk" IS DISTINCT FROM (CASE WHEN NOT v_global THEN v_entite END)
            OR v_rejeu."PorteeAnnonce" <> v_portee OR v_rejeu."SujetAnnonce" <> v_sujet
            OR v_rejeu."ContenuAnnonce" <> v_contenu
            OR (v_cibles IS NOT NULL AND v_cibles <> ARRAY(
                SELECT (cible ->> 'id')::integer FROM jsonb_array_elements(v_rejeu."Entreprises") AS cible
                ORDER BY 1
            )) THEN
            RAISE EXCEPTION 'Cette demande de diffusion a déjà un autre contenu ou périmètre.' USING ERRCODE = 'PCO04';
        END IF;
        RETURN QUERY SELECT v_rejeu."IdAnnonce", true;
        RETURN;
    END IF;

    WITH cibles AS MATERIALIZED (
        SELECT e."IdEntite", e."NomEntite"
        FROM systeme."T_Entite" e
        WHERE e."ValideEntite" IS TRUE AND (v_cibles IS NULL OR e."IdEntite" = ANY(v_cibles))
    ),
    audience AS MATERIALIZED (
        SELECT e."IdEntite", e."NomEntite", u."IdUser"
        FROM cibles e
        JOIN systeme."T_Utilisateurs" u ON u."IdEntiteFk" = e."IdEntite" AND u."ValideUser" IS TRUE
    ),
    entreprises AS (
        SELECT DISTINCT "IdEntite", "NomEntite" FROM audience
    ),
    statistiques AS (
        SELECT (SELECT count(*) FROM cibles) AS cibles_actives,
               count(*) AS entreprises,
               (SELECT count(*) FROM audience) AS destinataires,
               jsonb_agg(jsonb_build_object('id', "IdEntite", 'name', "NomEntite") ORDER BY "IdEntite") AS instantane
        FROM entreprises
    ),
    annonce AS (
        INSERT INTO communication."T_Annonce" AS a (
            "IdAuteurFk", "IdEntiteFk", "EmisParPlateforme", "PorteeAnnonce", "SujetAnnonce", "ContenuAnnonce",
            "PublieLe", "CleRequete", "Entreprises", "NombreDestinataires"
        )
        SELECT p_auteur, CASE WHEN NOT v_global THEN v_entite END, v_global, v_portee, v_sujet, v_contenu,
               v_publication, p_cle, s.instantane, s.destinataires
        FROM statistiques s
        WHERE s.destinataires > 0 AND (v_cibles IS NULL OR s.entreprises = cardinality(v_cibles))
        RETURNING a."IdAnnonce"
    ),
    livraisons AS (
        INSERT INTO communication."T_Communication" ("IdAnnonceFk", "IdUserFk", "IdEntiteFk", "DateCommunication")
        SELECT a."IdAnnonce", u."IdUser", u."IdEntite", v_publication AT TIME ZONE 'Africa/Kinshasa'
        FROM annonce a CROSS JOIN audience u
        ORDER BY u."IdUser"
        RETURNING 1
    )
    SELECT a."IdAnnonce", s.cibles_actives, s.entreprises, (SELECT count(*) FROM livraisons)
    INTO v_id, v_cibles_actives, v_entreprises, v_livraisons
    FROM statistiques s LEFT JOIN annonce a ON true;

    IF v_cibles IS NOT NULL AND v_cibles_actives <> cardinality(v_cibles) THEN
        RAISE EXCEPTION 'Une entreprise sélectionnée est inactive ou introuvable.' USING ERRCODE = 'PCO02';
    END IF;
    IF v_id IS NULL OR v_entreprises = 0 OR v_livraisons = 0 THEN
        RAISE EXCEPTION 'Aucun compte actif pour une entreprise destinataire.' USING ERRCODE = 'PCO03';
    END IF;
    INSERT INTO systeme."T_Audit_Log" ("TableName", "Operation", "NewData", "IdEntiteFk")
    VALUES (
        'communication.T_Annonce', 'DIFFUSION',
        jsonb_build_object('IdAnnonce', v_id, 'PorteeAnnonce', v_portee,
                           'NombreDestinataires', v_livraisons, 'NombreEntreprises', v_entreprises,
                           '_actor', jsonb_build_object('IdUser', p_auteur)),
        CASE WHEN NOT v_global THEN v_entite END
    );
    RETURN QUERY SELECT v_id, false;
END
$$;



--
-- Name: FUNCTION fn_diffuser_annonce(p_auteur integer, p_entites integer[], p_sujet text, p_contenu text, p_cle uuid); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_diffuser_annonce(p_auteur integer, p_entites integer[], p_sujet text, p_contenu text, p_cle uuid) IS 'Publie une annonce et toutes ses notifications dans une seule opération. Contrôle le droit réel de l’auteur, les entreprises actives, les destinataires actifs et le rejeu de la demande. L’audit de diffusion ne contient ni sujet ni texte.';



--
-- Name: fn_lock_discussion_message(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_lock_discussion_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 PERFORM 1 FROM communication."T_Discussion" WHERE "IdDiscussion"=ANY(ids) ORDER BY "IdDiscussion" FOR NO KEY UPDATE;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END;$$;



--
-- Name: FUNCTION fn_lock_discussion_message(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_lock_discussion_message() IS 'Verrouille les discussions parentes dans l’ordre des identifiants avant une mutation de message, afin de sérialiser le calcul de la dernière activité.';



--
-- Name: fn_sync_dernier_message(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_sync_dernier_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 UPDATE communication."T_Discussion" d SET "DernierMessageAt"=(SELECT max(c."DateChat") FROM communication."T_Chat" c WHERE c."IdDiscussionFk"=d."IdDiscussion")
 WHERE d."IdDiscussion"=ANY(ids);
 RETURN NULL;
END;$$;



--
-- Name: FUNCTION fn_sync_dernier_message(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_sync_dernier_message() IS 'Maintient DernierMessageAt égal au maximum des DateChat après insertion, modification, déplacement ou suppression ; NULL quand la discussion n’a plus de message. Le parent est verrouillé par le trigger BEFORE associé.';



--
-- Name: fn_verifier_chat_lecture(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_verifier_chat_lecture() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW."LuLe" IS DISTINCT FROM OLD."LuLe" THEN
            RAISE EXCEPTION 'La date de première lecture est conservée.'
                USING ERRCODE = '23514', CONSTRAINT = 'ck_chat_lecture_date_immuable';
        END IF;
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM communication."T_Chat" c
        JOIN communication."T_Discussion" d ON d."IdDiscussion" = c."IdDiscussionFk"
        JOIN systeme."T_Utilisateurs" u ON u."IdUser" = NEW."IdUserFk"
        LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk"
        LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique" = u."IdRoleFk"
        WHERE c."IdChat" = NEW."IdChatFk" AND c."SuiviLectureChat" IS TRUE
          AND c."AuthorIdFk" IS DISTINCT FROM u."IdUser"
          AND d."ValideDiscussion" IS TRUE AND u."ValideUser" IS TRUE
          AND (e."ValideEntite" IS DISTINCT FROM false OR u."Is_Admin" IS TRUE)
          AND (
              (d."TypeDiscussion" = 'user' AND d."IdEntiteFk" = u."IdEntiteFk"
                  AND u."IdUser" IN (d."IdUserClientFk", d."IdUserDestinataireFk"))
              OR (d."TypeDiscussion" IN ('expert', 'structure') AND d."IdUserClientFk" = u."IdUser")
              OR (d."TypeDiscussion" = 'expert' AND EXISTS (
                  SELECT 1 FROM professionnel."T_Professionnel" p
                  WHERE p."IdProfessionnel" = d."IdProfessionnelFk" AND p."IdUserFk" = u."IdUser"))
              OR (d."TypeDiscussion" = 'structure' AND d."IdEntiteFk" = u."IdEntiteFk"
                  AND (u."Is_Admin" IS TRUE OR u."Is_staff" IS TRUE
                       OR lower(r."NomGenerique") IN ('admin', 'administrateur')))
          )
    ) THEN
        RAISE EXCEPTION 'Ce message ne peut pas être marqué comme lu pour ce compte.'
            USING ERRCODE = '23514', CONSTRAINT = 'ck_chat_lecture_participant';
    END IF;

    NEW."LuLe" := clock_timestamp();
    RETURN NEW;
END
$$;



--
-- Name: FUNCTION fn_verifier_chat_lecture(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_verifier_chat_lecture() IS 'Contrôle la participation du lecteur et conserve la date de première lecture. Exclut les propres messages et les messages historiques.';



--
-- Name: fn_verifier_creation_discussion_directe(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_verifier_creation_discussion_directe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    membres integer;
BEGIN
    SELECT count(*) INTO membres FROM (
        SELECT u."IdUser"
        FROM systeme."T_Utilisateurs" u
        JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk"
        WHERE u."IdUser" IN (NEW."IdUserClientFk", NEW."IdUserDestinataireFk")
            AND u."IdEntiteFk" = NEW."IdEntiteFk"
            AND u."ValideUser" IS TRUE AND e."ValideEntite" IS TRUE
        ORDER BY u."IdUser" FOR SHARE OF u, e
    ) actifs;
    IF membres <> 2 THEN
        RAISE EXCEPTION 'Les deux participants doivent appartenir à la même entreprise active.'
            USING ERRCODE = '23514', CONSTRAINT = 'ck_discussion_directe_membres';
    END IF;
    RETURN NEW;
END;
$$;



--
-- Name: FUNCTION fn_verifier_creation_discussion_directe(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_verifier_creation_discussion_directe() IS 'Vérifie les deux comptes et leur entreprise à la création du fil direct, même pour un autre producteur SQL.';


SET default_tablespace = '';

SET default_table_access_method = heap;


--
-- Name: T_Annonce; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Annonce" (
    "IdAnnonce" bigint NOT NULL,
    "IdAuteurFk" integer,
    "IdEntiteFk" integer,
    "EmisParPlateforme" boolean NOT NULL,
    "PorteeAnnonce" text NOT NULL,
    "SujetAnnonce" text NOT NULL,
    "ContenuAnnonce" text NOT NULL,
    "PublieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "CleRequete" uuid NOT NULL,
    "Entreprises" jsonb NOT NULL,
    "NombreDestinataires" bigint NOT NULL,
    CONSTRAINT "T_Annonce_ContenuAnnonce_check" CHECK (((char_length(btrim("ContenuAnnonce")) >= 1) AND (char_length(btrim("ContenuAnnonce")) <= 5000))),
    CONSTRAINT "T_Annonce_Entreprises_check" CHECK (((jsonb_typeof("Entreprises") = 'array'::text) AND (jsonb_array_length("Entreprises") > 0))),
    CONSTRAINT "T_Annonce_NombreDestinataires_check" CHECK (("NombreDestinataires" > 0)),
    CONSTRAINT "T_Annonce_PorteeAnnonce_check" CHECK (("PorteeAnnonce" = ANY (ARRAY['entreprises'::text, 'toutes'::text]))),
    CONSTRAINT "T_Annonce_SujetAnnonce_check" CHECK (((char_length(btrim("SujetAnnonce")) >= 1) AND (char_length(btrim("SujetAnnonce")) <= 160))),
    CONSTRAINT ck_annonce_portee_globale CHECK (((("PorteeAnnonce" <> 'toutes'::text) OR "EmisParPlateforme") AND ((NOT "EmisParPlateforme") OR ("IdEntiteFk" IS NULL))))
);



--
-- Name: TABLE "T_Annonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Annonce" IS 'Publications administratives. Une annonce est enregistrée une fois et distribuée aux comptes actifs lors de sa publication.';



--
-- Name: COLUMN "T_Annonce"."IdAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."IdAnnonce" IS 'Identifiant de la publication administrative.';



--
-- Name: COLUMN "T_Annonce"."IdAuteurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."IdAuteurFk" IS 'Compte ayant publié l’annonce. La publication est conservée après suppression du compte.';



--
-- Name: COLUMN "T_Annonce"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."IdEntiteFk" IS 'Entreprise émettrice lors d’une publication locale. NULL pour une publication de la plateforme ou après retrait de l’entreprise émettrice.';



--
-- Name: COLUMN "T_Annonce"."EmisParPlateforme"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."EmisParPlateforme" IS 'Identifie une publication de la plateforme, même si une entreprise ou le compte émetteur sont retirés.';



--
-- Name: COLUMN "T_Annonce"."PorteeAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."PorteeAnnonce" IS 'Entreprises sélectionnées ou toutes les entreprises actives à la date de publication.';



--
-- Name: COLUMN "T_Annonce"."SujetAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."SujetAnnonce" IS 'Titre de l’annonce, limité à 160 caractères.';



--
-- Name: COLUMN "T_Annonce"."ContenuAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."ContenuAnnonce" IS 'Texte de l’annonce, limité à 5 000 caractères et partagé entre ses notifications personnelles.';



--
-- Name: COLUMN "T_Annonce"."PublieLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."PublieLe" IS 'Instant de publication utilisé pour dater toutes les notifications de l’annonce.';



--
-- Name: COLUMN "T_Annonce"."CleRequete"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."CleRequete" IS 'Identifiant de demande unique par auteur pour rejouer une diffusion sans dupliquer les notifications.';



--
-- Name: COLUMN "T_Annonce"."Entreprises"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."Entreprises" IS 'Instantané des identifiants et noms des entreprises ayant au moins un destinataire à la publication.';



--
-- Name: COLUMN "T_Annonce"."NombreDestinataires"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."NombreDestinataires" IS 'Effectif initial des comptes destinataires, conservé indépendamment des lectures ou changements ultérieurs de rattachement.';



--
-- Name: CONSTRAINT ck_annonce_portee_globale ON "T_Annonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_annonce_portee_globale ON communication."T_Annonce" IS 'Une publication générale est émise par la plateforme, sans entreprise émettrice.';



--
-- Name: T_Annonce_IdAnnonce_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Annonce" ALTER COLUMN "IdAnnonce" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Annonce_IdAnnonce_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



--
-- Name: T_Chat; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Chat" (
    "IdChat" integer CONSTRAINT "T_Chat_IdChat_not_null" NOT NULL,
    "TextChat" text,
    "ChatFile" text,
    "ChatLink" text,
    "AuthorIdFk" integer,
    "IdDiscussionFk" integer,
    "DateChat" timestamp with time zone DEFAULT now() CONSTRAINT "T_Chat_DateChat_not_null" NOT NULL,
    "LuChat" boolean DEFAULT false CONSTRAINT "T_Chat_LuChat_not_null" NOT NULL,
    "CleRequeteChat" uuid,
    "SuiviLectureChat" boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_chat_contenu_non_vide CHECK (((NULLIF(btrim("TextChat"), ''::text) IS NOT NULL) OR (NULLIF(btrim("ChatFile"), ''::text) IS NOT NULL) OR (NULLIF(btrim("ChatLink"), ''::text) IS NOT NULL)))
);



--
-- Name: TABLE "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Chat" IS 'Messages des discussions : texte, pièce ou lien, auteur, discussion, date et indicateur de lecture. Grain : un message identifié par IdChat.';



--
-- Name: COLUMN "T_Chat"."IdChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."IdChat" IS 'Identifiant du message.';



--
-- Name: COLUMN "T_Chat"."TextChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."TextChat" IS 'Texte du message de discussion.';



--
-- Name: COLUMN "T_Chat"."ChatFile"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."ChatFile" IS 'Référence de la pièce jointe au message.';



--
-- Name: COLUMN "T_Chat"."ChatLink"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."ChatLink" IS 'Lien associé au message.';



--
-- Name: COLUMN "T_Chat"."AuthorIdFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."AuthorIdFk" IS 'Utilisateur auteur du message. Relation imposée : FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL.';



--
-- Name: COLUMN "T_Chat"."IdDiscussionFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."IdDiscussionFk" IS 'Discussion contenant le message. Relation imposée : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';



--
-- Name: COLUMN "T_Chat"."DateChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."DateChat" IS 'Date et heure du message avec fuseau horaire.';



--
-- Name: COLUMN "T_Chat"."LuChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."LuChat" IS 'Indicateur historique conservé pour compatibilité. Les lectures individuelles sont enregistrées dans T_ChatLecture.';



--
-- Name: COLUMN "T_Chat"."CleRequeteChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."CleRequeteChat" IS 'Clé de rejeu facultative d’un envoi, propre au fil et à son auteur. Les anciens messages n’en ont pas.';



--
-- Name: COLUMN "T_Chat"."SuiviLectureChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."SuiviLectureChat" IS 'Active le suivi individuel des nouveaux messages. Les messages antérieurs à son installation sont exclus des non-lus.';



--
-- Name: CONSTRAINT "T_Chat_IdChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_IdChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "IdChat".';



--
-- Name: CONSTRAINT "T_Chat_DateChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_DateChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "DateChat".';



--
-- Name: CONSTRAINT "T_Chat_LuChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_LuChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "LuChat".';



--
-- Name: CONSTRAINT ck_chat_contenu_non_vide ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_chat_contenu_non_vide ON communication."T_Chat" IS 'Intégrité imposée par PostgreSQL : CHECK (NULLIF(btrim("TextChat"), ''''::text) IS NOT NULL OR NULLIF(btrim("ChatFile"), ''''::text) IS NOT NULL OR NULLIF(btrim("ChatLink"), ''''::text) IS NOT NULL)';



--
-- Name: T_ChatLecture; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_ChatLecture" (
    "IdChatFk" integer NOT NULL,
    "IdUserFk" integer NOT NULL,
    "LuLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);



--
-- Name: TABLE "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_ChatLecture" IS 'Première lecture d’un message par un compte participant. Chaque lecteur est suivi séparément, y compris lorsque plusieurs personnes reçoivent les messages d’une structure.';



--
-- Name: COLUMN "T_ChatLecture"."IdChatFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_ChatLecture"."IdChatFk" IS 'Identifiant du message suivi.';



--
-- Name: COLUMN "T_ChatLecture"."IdUserFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_ChatLecture"."IdUserFk" IS 'Identifiant du compte qui a lu le message.';



--
-- Name: COLUMN "T_ChatLecture"."LuLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_ChatLecture"."LuLe" IS 'Date et heure de la première lecture enregistrée par PostgreSQL.';



--
-- Name: T_Chat_IdChat_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Chat" ALTER COLUMN "IdChat" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Chat_IdChat_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



--
-- Name: SEQUENCE "T_Chat_IdChat_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Chat_IdChat_seq" IS 'Séquence de génération de "communication"."T_Chat"."IdChat". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';



--
-- Name: T_Communication; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Communication" (
    "IdCommunication" integer CONSTRAINT "T_Communication_IdCommunication_not_null" NOT NULL,
    "IdUserFk" integer,
    "IdTypeCommunication" integer,
    "ContenuCommunication" text,
    "DateCommunication" timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Communication_DateCommunication_not_null" NOT NULL,
    "ObsCommunication" text,
    "ValideCommunication" boolean DEFAULT true CONSTRAINT "T_Communication_ValideCommunication_not_null" NOT NULL,
    "LectureCommunication" boolean DEFAULT false CONSTRAINT "T_Communication_LectureCommunication_not_null" NOT NULL,
    "IdEntiteFk" integer,
    "IdAnnonceFk" bigint,
    "LuLe" timestamp with time zone,
    CONSTRAINT ck_comm_annonce_contenu CHECK ((("IdAnnonceFk" IS NULL) OR ("ContenuCommunication" IS NULL))),
    CONSTRAINT ck_comm_annonce_lecture CHECK ((("IdAnnonceFk" IS NULL) OR ("LectureCommunication" = ("LuLe" IS NOT NULL))))
);



--
-- Name: TABLE "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Communication" IS 'Notifications individuelles, autonomes ou issues d’une annonce administrative. Distinctes des messages de discussion.';



--
-- Name: COLUMN "T_Communication"."IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdCommunication" IS 'Identifiant de la communication ou notification.';



--
-- Name: COLUMN "T_Communication"."IdUserFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: COLUMN "T_Communication"."IdTypeCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdTypeCommunication" IS 'Type de communication dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: COLUMN "T_Communication"."ContenuCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ContenuCommunication" IS 'Texte d’une notification autonome. Le texte partagé d’une annonce appartient à T_Annonce.';



--
-- Name: COLUMN "T_Communication"."DateCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."DateCommunication" IS 'Date et heure d’enregistrement de la communication.';



--
-- Name: COLUMN "T_Communication"."ObsCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ObsCommunication" IS 'Observations enregistrées sur la communication.';



--
-- Name: COLUMN "T_Communication"."ValideCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ValideCommunication" IS 'Indique si la communication est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';



--
-- Name: COLUMN "T_Communication"."LectureCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."LectureCommunication" IS 'Indique si la communication est marquée comme lue.';



--
-- Name: COLUMN "T_Communication"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: COLUMN "T_Communication"."IdAnnonceFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdAnnonceFk" IS 'Source du titre et du corps pour une annonce distribuée. NULL pour les notifications historiques ou autonomes.';



--
-- Name: COLUMN "T_Communication"."LuLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."LuLe" IS 'Date de la première lecture d’une notification issue d’une annonce. NULL si non lue ou pour une notification autonome.';



--
-- Name: CONSTRAINT "T_Communication_IdCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_IdCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "IdCommunication".';



--
-- Name: CONSTRAINT "T_Communication_DateCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_DateCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "DateCommunication".';



--
-- Name: CONSTRAINT "T_Communication_ValideCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_ValideCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "ValideCommunication".';



--
-- Name: CONSTRAINT "T_Communication_LectureCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_LectureCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "LectureCommunication".';



--
-- Name: CONSTRAINT ck_comm_annonce_contenu ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_comm_annonce_contenu ON communication."T_Communication" IS 'Le corps d’une annonce est enregistré seulement dans sa publication source.';



--
-- Name: CONSTRAINT ck_comm_annonce_lecture ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_comm_annonce_lecture ON communication."T_Communication" IS 'La date de lecture et l’état de lecture doivent concorder pour une annonce.';



--
-- Name: T_Communication_IdCommunication_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Communication" ALTER COLUMN "IdCommunication" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Communication_IdCommunication_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



--
-- Name: SEQUENCE "T_Communication_IdCommunication_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Communication_IdCommunication_seq" IS 'Séquence de génération de "communication"."T_Communication"."IdCommunication". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';



--
-- Name: T_Demande; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Demande" (
    "IdDemande" bigint NOT NULL,
    "CodeDemande" text GENERATED ALWAYS AS (('DEM-'::text || ("IdDemande")::text)) STORED,
    "IdDemandeurFk" integer NOT NULL,
    "IdEntiteDemandeurFk" integer,
    "TypeSource" text NOT NULL,
    "IdArticleFk" integer,
    "IdProfessionnelFk" integer,
    "IdNiveau3Fk" integer,
    "IdNiveau4Fk" integer,
    "IdNiveau5Fk" integer,
    "LibelleSource" text NOT NULL,
    "IdDestinataireUserFk" integer,
    "IdEntiteDestinataireFk" integer,
    "SujetDemande" text NOT NULL,
    "DescriptionDemande" text NOT NULL,
    "QuantiteSouhaitee" numeric(18,3),
    "UniteSouhaitee" text,
    "DestinationDemande" text,
    "EtatDemande" text DEFAULT 'en_attente'::text NOT NULL,
    "VersionDemande" integer DEFAULT 1 NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_Demande_DescriptionDemande_check" CHECK (((char_length(btrim("DescriptionDemande")) >= 1) AND (char_length(btrim("DescriptionDemande")) <= 5000))),
    CONSTRAINT "T_Demande_DestinationDemande_check" CHECK ((char_length("DestinationDemande") <= 300)),
    CONSTRAINT "T_Demande_EtatDemande_check" CHECK (("EtatDemande" = ANY (ARRAY['en_attente'::text, 'en_cours'::text, 'satisfaite'::text, 'non_satisfaite'::text, 'annulee'::text]))),
    CONSTRAINT "T_Demande_QuantiteSouhaitee_check" CHECK (("QuantiteSouhaitee" > (0)::numeric)),
    CONSTRAINT "T_Demande_SujetDemande_check" CHECK (((char_length(btrim("SujetDemande")) >= 1) AND (char_length(btrim("SujetDemande")) <= 160))),
    CONSTRAINT "T_Demande_TypeSource_check" CHECK (("TypeSource" = ANY (ARRAY['product'::text, 'expert'::text, 'structure_n3'::text, 'structure_n4'::text, 'structure_n5'::text]))),
    CONSTRAINT "T_Demande_VersionDemande_check" CHECK (("VersionDemande" > 0)),
    CONSTRAINT demande_destinataire_exact CHECK (((num_nonnulls("IdDestinataireUserFk", "IdEntiteDestinataireFk") = 1) AND (("TypeSource" = 'expert'::text) = ("IdDestinataireUserFk" IS NOT NULL)) AND ("IdDemandeurFk" IS DISTINCT FROM "IdDestinataireUserFk"))),
    CONSTRAINT demande_quantite_produit CHECK ((("QuantiteSouhaitee" IS NULL) OR (("TypeSource" = 'product'::text) AND ("UniteSouhaitee" IS NOT NULL)))),
    CONSTRAINT demande_source_exacte CHECK (((num_nonnulls("IdArticleFk", "IdProfessionnelFk", "IdNiveau3Fk", "IdNiveau4Fk", "IdNiveau5Fk") = 1) AND (("TypeSource" = 'product'::text) = ("IdArticleFk" IS NOT NULL)) AND (("TypeSource" = 'expert'::text) = ("IdProfessionnelFk" IS NOT NULL)) AND (("TypeSource" = 'structure_n3'::text) = ("IdNiveau3Fk" IS NOT NULL)) AND (("TypeSource" = 'structure_n4'::text) = ("IdNiveau4Fk" IS NOT NULL)) AND (("TypeSource" = 'structure_n5'::text) = ("IdNiveau5Fk" IS NOT NULL))))
);



--
-- Name: TABLE "T_Demande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Demande" IS 'Intention suivie, privée, issue d’une offre ou fiche publiée. Source, demandeur réel, destinataire vérifié et unité sont figés. Ne réserve aucun stock et ne crée aucune facture ni conversation.';



--
-- Name: COLUMN "T_Demande"."IdDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdDemande" IS 'Champ persistant du suivi : IdDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."CodeDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."CodeDemande" IS 'Champ persistant du suivi : CodeDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdDemandeurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdDemandeurFk" IS 'Champ persistant du suivi : IdDemandeurFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdEntiteDemandeurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdEntiteDemandeurFk" IS 'Entreprise réelle du demandeur à la création, indépendante de son contexte administrateur.';



--
-- Name: COLUMN "T_Demande"."TypeSource"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."TypeSource" IS 'Champ persistant du suivi : TypeSource. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdArticleFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdArticleFk" IS 'Champ persistant du suivi : IdArticleFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdProfessionnelFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdProfessionnelFk" IS 'Champ persistant du suivi : IdProfessionnelFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdNiveau3Fk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdNiveau3Fk" IS 'Champ persistant du suivi : IdNiveau3Fk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdNiveau4Fk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdNiveau4Fk" IS 'Champ persistant du suivi : IdNiveau4Fk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdNiveau5Fk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdNiveau5Fk" IS 'Champ persistant du suivi : IdNiveau5Fk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."LibelleSource"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."LibelleSource" IS 'Champ persistant du suivi : LibelleSource. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdDestinataireUserFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdDestinataireUserFk" IS 'Champ persistant du suivi : IdDestinataireUserFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."IdEntiteDestinataireFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."IdEntiteDestinataireFk" IS 'Champ persistant du suivi : IdEntiteDestinataireFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."SujetDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."SujetDemande" IS 'Champ persistant du suivi : SujetDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."DescriptionDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."DescriptionDemande" IS 'Champ persistant du suivi : DescriptionDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."QuantiteSouhaitee"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."QuantiteSouhaitee" IS 'Quantité souhaitée facultative, exacte à la précision de l’unité ; aucune réservation de stock.';



--
-- Name: COLUMN "T_Demande"."UniteSouhaitee"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."UniteSouhaitee" IS 'Libellé d’unité figé à la création depuis l’offre publiée ; jamais saisi par le demandeur.';



--
-- Name: COLUMN "T_Demande"."DestinationDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."DestinationDemande" IS 'Champ persistant du suivi : DestinationDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."EtatDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."EtatDemande" IS 'Code métier stable ; le libellé affiché provient de AbrGenerique, catégorie État demande suivie.';



--
-- Name: COLUMN "T_Demande"."VersionDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."VersionDemande" IS 'Champ persistant du suivi : VersionDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."CreeLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."CreeLe" IS 'Champ persistant du suivi : CreeLe. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_Demande"."ModifieLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Demande"."ModifieLe" IS 'Champ persistant du suivi : ModifieLe. Source et historique préservés par les fonctions métier.';



--
-- Name: T_DemandeHistorique; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_DemandeHistorique" (
    "IdHistorique" bigint NOT NULL,
    "IdDemandeFk" bigint NOT NULL,
    "IdAuteurFk" integer NOT NULL,
    "ActionDemande" text NOT NULL,
    "EtatAvant" text,
    "EtatApres" text NOT NULL,
    "MotifDemande" text DEFAULT ''::text NOT NULL,
    "CleRequete" uuid NOT NULL,
    "ContenuRequete" jsonb NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_DemandeHistorique_ActionDemande_check" CHECK (("ActionDemande" = ANY (ARRAY['creation'::text, 'transition'::text, 'discussion'::text]))),
    CONSTRAINT "T_DemandeHistorique_MotifDemande_check" CHECK ((char_length("MotifDemande") <= 1000))
);



--
-- Name: TABLE "T_DemandeHistorique"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_DemandeHistorique" IS 'Journal immuable des créations, transitions et ouvertures explicites de conversation ; protège également le rejeu exact par auteur et UUID.';



--
-- Name: COLUMN "T_DemandeHistorique"."IdHistorique"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."IdHistorique" IS 'Champ persistant du suivi : IdHistorique. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."IdDemandeFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."IdDemandeFk" IS 'Champ persistant du suivi : IdDemandeFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."IdAuteurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."IdAuteurFk" IS 'Champ persistant du suivi : IdAuteurFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."ActionDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."ActionDemande" IS 'Champ persistant du suivi : ActionDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."EtatAvant"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."EtatAvant" IS 'Champ persistant du suivi : EtatAvant. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."EtatApres"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."EtatApres" IS 'Champ persistant du suivi : EtatApres. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."MotifDemande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."MotifDemande" IS 'Champ persistant du suivi : MotifDemande. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."CleRequete"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."CleRequete" IS 'Champ persistant du suivi : CleRequete. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_DemandeHistorique"."ContenuRequete"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."ContenuRequete" IS 'Contenu canonique privé utilisé uniquement pour reconnaître un rejeu exact ; non exposé dans les API.';



--
-- Name: COLUMN "T_DemandeHistorique"."CreeLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_DemandeHistorique"."CreeLe" IS 'Champ persistant du suivi : CreeLe. Source et historique préservés par les fonctions métier.';



--
-- Name: T_DemandeHistorique_IdHistorique_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_DemandeHistorique" ALTER COLUMN "IdHistorique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_DemandeHistorique_IdHistorique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



--
-- Name: T_Demande_IdDemande_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Demande" ALTER COLUMN "IdDemande" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Demande_IdDemande_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



--
-- Name: T_Discussion; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Discussion" (
    "IdDiscussion" integer CONSTRAINT "T_Discussion_IdDiscussion_not_null" NOT NULL,
    "IdUserClientFk" integer,
    "IdProfessionnelFk" integer,
    "IdEntiteFk" integer,
    "TypeDiscussion" character varying(30) CONSTRAINT "T_Discussion_TypeDiscussion_not_null" NOT NULL,
    "SujetDiscussion" character varying(255),
    "DateCreation" timestamp with time zone DEFAULT now() CONSTRAINT "T_Discussion_DateCreation_not_null" NOT NULL,
    "DernierMessageAt" timestamp with time zone,
    "ValideDiscussion" boolean DEFAULT true CONSTRAINT "T_Discussion_ValideDiscussion_not_null" NOT NULL,
    "IdUserDestinataireFk" integer,
    "IdDemandeFk" bigint,
    CONSTRAINT "Ck_Discussion_Target" CHECK ((((("TypeDiscussion")::text = 'demande'::text) AND ("IdDemandeFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NULL) AND ("IdEntiteFk" IS NULL) AND ("IdUserDestinataireFk" IS NULL)) OR (("IdDemandeFk" IS NULL) AND (((("TypeDiscussion")::text = 'expert'::text) AND ("IdProfessionnelFk" IS NOT NULL) AND ("IdEntiteFk" IS NULL) AND ("IdUserDestinataireFk" IS NULL)) OR ((("TypeDiscussion")::text = 'structure'::text) AND ("IdEntiteFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NULL) AND ("IdUserDestinataireFk" IS NULL)) OR ((("TypeDiscussion")::text = 'user'::text) AND ("IdProfessionnelFk" IS NULL) AND (("IdUserClientFk" IS NULL) OR ("IdUserDestinataireFk" IS NULL) OR ("IdUserClientFk" <> "IdUserDestinataireFk"))))))),
    CONSTRAINT "Ck_Discussion_Type" CHECK ((("TypeDiscussion")::text = ANY ((ARRAY['expert'::character varying, 'structure'::character varying, 'user'::character varying, 'demande'::character varying])::text[])))
);



--
-- Name: TABLE "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Discussion" IS 'Fils privés entre comptes, auprès d’un professionnel ou d’une entreprise, et fils explicitement rattachés à une demande suivie. Seuls les participants autorisés accèdent aux échanges.';



--
-- Name: COLUMN "T_Discussion"."IdDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdDiscussion" IS 'Identifiant du fil de discussion.';



--
-- Name: COLUMN "T_Discussion"."IdUserClientFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdUserClientFk" IS 'Utilisateur client à l’origine du fil de discussion. Relation imposée : FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: COLUMN "T_Discussion"."IdProfessionnelFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: COLUMN "T_Discussion"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdEntiteFk" IS 'Structure destinataire pour un fil structure. Entreprise commune à la création pour un fil direct.';



--
-- Name: COLUMN "T_Discussion"."TypeDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."TypeDiscussion" IS 'Canal privé : expert, structure entreprise, user interne ou demande suivie ; chaque canal impose ses clés et ses participants.';



--
-- Name: COLUMN "T_Discussion"."SujetDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."SujetDiscussion" IS 'Sujet ou titre du fil de discussion.';



--
-- Name: COLUMN "T_Discussion"."DateCreation"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."DateCreation" IS 'Horodatage de création de la discussion avec fuseau horaire.';



--
-- Name: COLUMN "T_Discussion"."DernierMessageAt"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."DernierMessageAt" IS 'Horodatage du dernier message associé à la discussion.';



--
-- Name: COLUMN "T_Discussion"."ValideDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."ValideDiscussion" IS 'Indique si la discussion est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';



--
-- Name: COLUMN "T_Discussion"."IdUserDestinataireFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdUserDestinataireFk" IS 'Second compte participant à un fil direct. Absent pour les fils professionnels et structures ou si le compte a été supprimé.';



--
-- Name: COLUMN "T_Discussion"."IdDemandeFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdDemandeFk" IS 'Demande suivie d’origine ; une seule conversation créée sur action explicite, sans message automatique.';



--
-- Name: CONSTRAINT "T_Discussion_IdDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_IdDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "IdDiscussion".';



--
-- Name: CONSTRAINT "T_Discussion_TypeDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_TypeDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "TypeDiscussion".';



--
-- Name: CONSTRAINT "T_Discussion_DateCreation_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_DateCreation_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "DateCreation".';



--
-- Name: CONSTRAINT "T_Discussion_ValideDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_ValideDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "ValideDiscussion".';



--
-- Name: CONSTRAINT "Ck_Discussion_Target" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Discussion_Target" ON communication."T_Discussion" IS 'Contrôle les clés propres aux quatre canaux ; un fil de demande ne porte pas un destinataire déduit ou modifiable.';



--
-- Name: CONSTRAINT "Ck_Discussion_Type" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Discussion_Type" ON communication."T_Discussion" IS 'Canaux privés expert, structure entreprise, user interne et demande suivie.';



--
-- Name: T_Discussion_IdDiscussion_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Discussion" ALTER COLUMN "IdDiscussion" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Discussion_IdDiscussion_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



--
-- Name: SEQUENCE "T_Discussion_IdDiscussion_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Discussion_IdDiscussion_seq" IS 'Séquence de génération de "communication"."T_Discussion"."IdDiscussion". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';



--
-- Name: T_RoutageStructure; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_RoutageStructure" (
    "TypeSource" text NOT NULL,
    "IdSource" integer NOT NULL,
    "IdNiveau3Fk" integer,
    "IdNiveau4Fk" integer,
    "IdNiveau5Fk" integer,
    "IdEntiteFk" integer NOT NULL,
    "VersionRoutage" integer DEFAULT 1 NOT NULL,
    "Actif" boolean DEFAULT true NOT NULL,
    "IdVerificateurFk" integer NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_RoutageStructure_TypeSource_check" CHECK (("TypeSource" = ANY (ARRAY['structure_n3'::text, 'structure_n4'::text, 'structure_n5'::text]))),
    CONSTRAINT routage_source_exacte CHECK (((num_nonnulls("IdNiveau3Fk", "IdNiveau4Fk", "IdNiveau5Fk") = 1) AND ("IdSource" = COALESCE("IdNiveau3Fk", "IdNiveau4Fk", "IdNiveau5Fk")) AND (("TypeSource" = 'structure_n3'::text) = ("IdNiveau3Fk" IS NOT NULL)) AND (("TypeSource" = 'structure_n4'::text) = ("IdNiveau4Fk" IS NOT NULL)) AND (("TypeSource" = 'structure_n5'::text) = ("IdNiveau5Fk" IS NOT NULL))))
);



--
-- Name: TABLE "T_RoutageStructure"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_RoutageStructure" IS 'Représentation explicitement vérifiée d’un territoire par une entreprise. Aucune inférence depuis la localisation d’une entreprise.';



--
-- Name: COLUMN "T_RoutageStructure"."TypeSource"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."TypeSource" IS 'Champ persistant du suivi : TypeSource. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."IdSource"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."IdSource" IS 'Champ persistant du suivi : IdSource. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."IdNiveau3Fk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."IdNiveau3Fk" IS 'Champ persistant du suivi : IdNiveau3Fk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."IdNiveau4Fk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."IdNiveau4Fk" IS 'Champ persistant du suivi : IdNiveau4Fk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."IdNiveau5Fk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."IdNiveau5Fk" IS 'Champ persistant du suivi : IdNiveau5Fk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."IdEntiteFk" IS 'Champ persistant du suivi : IdEntiteFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."VersionRoutage"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."VersionRoutage" IS 'Champ persistant du suivi : VersionRoutage. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."Actif"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."Actif" IS 'Champ persistant du suivi : Actif. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."IdVerificateurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."IdVerificateurFk" IS 'Champ persistant du suivi : IdVerificateurFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructure"."ModifieLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructure"."ModifieLe" IS 'Champ persistant du suivi : ModifieLe. Source et historique préservés par les fonctions métier.';



--
-- Name: T_RoutageStructureHistorique; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_RoutageStructureHistorique" (
    "IdHistorique" bigint NOT NULL,
    "TypeSource" text NOT NULL,
    "IdSource" integer NOT NULL,
    "IdEntiteAvantFk" integer,
    "IdEntiteApresFk" integer,
    "VersionRoutage" integer NOT NULL,
    "IdAuteurFk" integer NOT NULL,
    "MotifRoutage" text NOT NULL,
    "CleRequete" uuid NOT NULL,
    "ContenuRequete" jsonb NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_RoutageStructureHistorique_MotifRoutage_check" CHECK (((char_length(btrim("MotifRoutage")) >= 1) AND (char_length(btrim("MotifRoutage")) <= 1000)))
);



--
-- Name: TABLE "T_RoutageStructureHistorique"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_RoutageStructureHistorique" IS 'Versions successives et motif obligatoire de chaque routage, immuables ; un nouveau routage ne déplace jamais les anciennes demandes.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."IdHistorique"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."IdHistorique" IS 'Champ persistant du suivi : IdHistorique. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."TypeSource"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."TypeSource" IS 'Champ persistant du suivi : TypeSource. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."IdSource"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."IdSource" IS 'Champ persistant du suivi : IdSource. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."IdEntiteAvantFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."IdEntiteAvantFk" IS 'Champ persistant du suivi : IdEntiteAvantFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."IdEntiteApresFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."IdEntiteApresFk" IS 'Champ persistant du suivi : IdEntiteApresFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."VersionRoutage"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."VersionRoutage" IS 'Champ persistant du suivi : VersionRoutage. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."IdAuteurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."IdAuteurFk" IS 'Champ persistant du suivi : IdAuteurFk. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."MotifRoutage"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."MotifRoutage" IS 'Champ persistant du suivi : MotifRoutage. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."CleRequete"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."CleRequete" IS 'Champ persistant du suivi : CleRequete. Source et historique préservés par les fonctions métier.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."ContenuRequete"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."ContenuRequete" IS 'Contenu canonique privé utilisé uniquement pour reconnaître un rejeu exact ; non exposé dans les API.';



--
-- Name: COLUMN "T_RoutageStructureHistorique"."CreeLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_RoutageStructureHistorique"."CreeLe" IS 'Champ persistant du suivi : CreeLe. Source et historique préservés par les fonctions métier.';



--
-- Name: T_RoutageStructureHistorique_IdHistorique_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_RoutageStructureHistorique" ALTER COLUMN "IdHistorique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_RoutageStructureHistorique_IdHistorique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



--
-- Name: T_ChatLecture Pk_ChatLecture; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_ChatLecture"
    ADD CONSTRAINT "Pk_ChatLecture" PRIMARY KEY ("IdChatFk", "IdUserFk");



--
-- Name: CONSTRAINT "Pk_ChatLecture" ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Pk_ChatLecture" ON communication."T_ChatLecture" IS 'Une seule lecture par message et par compte, y compris en cas de rejeu.';



--
-- Name: T_Communication Pk_IdCommunication; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Pk_IdCommunication" PRIMARY KEY ("IdCommunication");



--
-- Name: CONSTRAINT "Pk_IdCommunication" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdCommunication" ON communication."T_Communication" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Communication". Définition : PRIMARY KEY ("IdCommunication").';



--
-- Name: T_Annonce T_Annonce_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT "T_Annonce_pkey" PRIMARY KEY ("IdAnnonce");



--
-- Name: T_Chat T_Chat_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "T_Chat_pkey" PRIMARY KEY ("IdChat");



--
-- Name: CONSTRAINT "T_Chat_pkey" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_pkey" ON communication."T_Chat" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Chat". Définition : PRIMARY KEY ("IdChat").';



--
-- Name: T_DemandeHistorique T_DemandeHistorique_IdAuteurFk_CleRequete_key; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_DemandeHistorique"
    ADD CONSTRAINT "T_DemandeHistorique_IdAuteurFk_CleRequete_key" UNIQUE ("IdAuteurFk", "CleRequete");



--
-- Name: T_DemandeHistorique T_DemandeHistorique_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_DemandeHistorique"
    ADD CONSTRAINT "T_DemandeHistorique_pkey" PRIMARY KEY ("IdHistorique");



--
-- Name: T_Demande T_Demande_CodeDemande_key; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_CodeDemande_key" UNIQUE ("CodeDemande");



--
-- Name: T_Demande T_Demande_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_pkey" PRIMARY KEY ("IdDemande");



--
-- Name: T_Discussion T_Discussion_IdDemandeFk_key; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "T_Discussion_IdDemandeFk_key" UNIQUE ("IdDemandeFk");



--
-- Name: T_Discussion T_Discussion_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "T_Discussion_pkey" PRIMARY KEY ("IdDiscussion");



--
-- Name: CONSTRAINT "T_Discussion_pkey" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_pkey" ON communication."T_Discussion" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Discussion". Définition : PRIMARY KEY ("IdDiscussion").';



--
-- Name: T_RoutageStructureHistorique T_RoutageStructureHistorique_IdAuteurFk_CleRequete_key; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructureHistorique"
    ADD CONSTRAINT "T_RoutageStructureHistorique_IdAuteurFk_CleRequete_key" UNIQUE ("IdAuteurFk", "CleRequete");



--
-- Name: T_RoutageStructureHistorique T_RoutageStructureHistorique_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructureHistorique"
    ADD CONSTRAINT "T_RoutageStructureHistorique_pkey" PRIMARY KEY ("IdHistorique");



--
-- Name: T_RoutageStructure T_RoutageStructure_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructure"
    ADD CONSTRAINT "T_RoutageStructure_pkey" PRIMARY KEY ("TypeSource", "IdSource");



--
-- Name: T_Annonce uq_annonce_auteur_requete; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT uq_annonce_auteur_requete UNIQUE ("IdAuteurFk", "CleRequete");



--
-- Name: CONSTRAINT uq_annonce_auteur_requete ON "T_Annonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT uq_annonce_auteur_requete ON communication."T_Annonce" IS 'Identifie le rejeu d’une demande par son auteur et sa clé.';



--
-- Name: INDEX "Pk_IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."Pk_IdCommunication" IS 'Index support de la clé primaire sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdCommunication" ON communication."T_Communication" USING btree ("IdCommunication").';



--
-- Name: INDEX "T_Chat_pkey"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."T_Chat_pkey" IS 'Index support de la clé primaire sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Chat_pkey" ON communication."T_Chat" USING btree ("IdChat").';



--
-- Name: INDEX "T_Discussion_pkey"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."T_Discussion_pkey" IS 'Index support de la clé primaire sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Discussion_pkey" ON communication."T_Discussion" USING btree ("IdDiscussion").';



--
-- Name: demande_demandeur_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX demande_demandeur_date ON communication."T_Demande" USING btree ("IdDemandeurFk", "CreeLe" DESC, "IdDemande");



--
-- Name: INDEX demande_demandeur_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.demande_demandeur_date IS 'Pagination des demandes envoyées par le compte réel.';



--
-- Name: demande_destinataire_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX demande_destinataire_date ON communication."T_Demande" USING btree ("IdEntiteDestinataireFk", "EtatDemande", "CreeLe" DESC);



--
-- Name: INDEX demande_destinataire_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.demande_destinataire_date IS 'Suivi des demandes reçues par entreprise et état.';



--
-- Name: demande_historique_dossier; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX demande_historique_dossier ON communication."T_DemandeHistorique" USING btree ("IdDemandeFk", "IdHistorique");



--
-- Name: INDEX demande_historique_dossier; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.demande_historique_dossier IS 'Lecture chronologique de l’historique d’un dossier privé.';



--
-- Name: demande_professionnel_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX demande_professionnel_date ON communication."T_Demande" USING btree ("IdDestinataireUserFk", "EtatDemande", "CreeLe" DESC);



--
-- Name: INDEX demande_professionnel_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.demande_professionnel_date IS 'Suivi des demandes reçues par compte professionnel figé.';



--
-- Name: idx_annonce_entite_publication; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_annonce_entite_publication ON communication."T_Annonce" USING btree ("IdEntiteFk", "PublieLe" DESC, "IdAnnonce" DESC);



--
-- Name: INDEX idx_annonce_entite_publication; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_annonce_entite_publication IS 'Accès à l’historique des publications locales par date et entreprise émettrice.';



--
-- Name: idx_chat_author; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_author ON communication."T_Chat" USING btree ("AuthorIdFk");



--
-- Name: INDEX idx_chat_author; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_author IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_author ON communication."T_Chat" USING btree ("AuthorIdFk").';



--
-- Name: idx_chat_author_idchat_desc; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_author_idchat_desc ON communication."T_Chat" USING btree ("AuthorIdFk", "IdChat" DESC);



--
-- Name: INDEX idx_chat_author_idchat_desc; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_author_idchat_desc IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_author_idchat_desc ON communication."T_Chat" USING btree ("AuthorIdFk", "IdChat" DESC).';



--
-- Name: idx_chat_discussion_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_discussion_date ON communication."T_Chat" USING btree ("IdDiscussionFk", "DateChat");



--
-- Name: INDEX idx_chat_discussion_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_discussion_date IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_discussion_date ON communication."T_Chat" USING btree ("IdDiscussionFk", "DateChat").';



--
-- Name: idx_chat_discussion_idchat; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_discussion_idchat ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat");



--
-- Name: INDEX idx_chat_discussion_idchat; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_discussion_idchat IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_discussion_idchat ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat").';



--
-- Name: idx_chat_lecture_utilisateur; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_lecture_utilisateur ON communication."T_ChatLecture" USING btree ("IdUserFk", "IdChatFk");



--
-- Name: INDEX idx_chat_lecture_utilisateur; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_lecture_utilisateur IS 'Accès aux messages lus par un compte et aux lectures concernées par une suppression du compte.';



--
-- Name: idx_chat_suivi_discussion_message; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_suivi_discussion_message ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat") INCLUDE ("AuthorIdFk") WHERE ("SuiviLectureChat" IS TRUE);



--
-- Name: INDEX idx_chat_suivi_discussion_message; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_suivi_discussion_message IS 'Recherche des nouveaux messages d’une discussion pour le calcul des non-lus.';



--
-- Name: idx_comm_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_date ON communication."T_Communication" USING btree ("DateCommunication");



--
-- Name: INDEX idx_comm_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_date IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_date ON communication."T_Communication" USING btree ("DateCommunication").';



--
-- Name: idx_comm_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_entite ON communication."T_Communication" USING btree ("IdEntiteFk");



--
-- Name: INDEX idx_comm_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_entite IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_entite ON communication."T_Communication" USING btree ("IdEntiteFk").';



--
-- Name: idx_comm_type; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_type ON communication."T_Communication" USING btree ("IdTypeCommunication");



--
-- Name: INDEX idx_comm_type; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_type IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_type ON communication."T_Communication" USING btree ("IdTypeCommunication").';



--
-- Name: idx_comm_user; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_user ON communication."T_Communication" USING btree ("IdUserFk");



--
-- Name: INDEX idx_comm_user; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_user IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_user ON communication."T_Communication" USING btree ("IdUserFk").';



--
-- Name: idx_comm_user_unread; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_user_unread ON communication."T_Communication" USING btree ("IdUserFk", "DateCommunication" DESC) WHERE ("LectureCommunication" = false);



--
-- Name: INDEX idx_comm_user_unread; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_user_unread IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_user_unread ON communication."T_Communication" USING btree ("IdUserFk", "DateCommunication" DESC) WHERE ("LectureCommunication" = false).';



--
-- Name: idx_discussion_dernier_message; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_dernier_message ON communication."T_Discussion" USING btree ("DernierMessageAt" DESC);



--
-- Name: INDEX idx_discussion_dernier_message; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_dernier_message IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_dernier_message ON communication."T_Discussion" USING btree ("DernierMessageAt" DESC).';



--
-- Name: idx_discussion_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_entite ON communication."T_Discussion" USING btree ("IdEntiteFk");



--
-- Name: INDEX idx_discussion_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_entite IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_entite ON communication."T_Discussion" USING btree ("IdEntiteFk").';



--
-- Name: idx_discussion_professionnel; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_professionnel ON communication."T_Discussion" USING btree ("IdProfessionnelFk");



--
-- Name: INDEX idx_discussion_professionnel; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_professionnel IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_professionnel ON communication."T_Discussion" USING btree ("IdProfessionnelFk").';



--
-- Name: idx_discussion_user_client; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_user_client ON communication."T_Discussion" USING btree ("IdUserClientFk");



--
-- Name: INDEX idx_discussion_user_client; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_user_client IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_user_client ON communication."T_Discussion" USING btree ("IdUserClientFk").';



--
-- Name: idx_discussion_user_destinataire; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_user_destinataire ON communication."T_Discussion" USING btree ("IdUserDestinataireFk") WHERE ("IdUserDestinataireFk" IS NOT NULL);



--
-- Name: INDEX idx_discussion_user_destinataire; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_user_destinataire IS 'Accès aux fils directs du second participant.';



--
-- Name: uq_chat_requete_auteur_discussion; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_chat_requete_auteur_discussion ON communication."T_Chat" USING btree ("IdDiscussionFk", "AuthorIdFk", "CleRequeteChat") WHERE ("CleRequeteChat" IS NOT NULL);



--
-- Name: INDEX uq_chat_requete_auteur_discussion; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_chat_requete_auteur_discussion IS 'Empêche de dupliquer un envoi après une réponse réseau incertaine.';



--
-- Name: uq_comm_annonce_destinataire; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_comm_annonce_destinataire ON communication."T_Communication" USING btree ("IdAnnonceFk", "IdUserFk") WHERE ("IdAnnonceFk" IS NOT NULL);



--
-- Name: INDEX uq_comm_annonce_destinataire; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_comm_annonce_destinataire IS 'Empêche une même annonce d’être distribuée deux fois à un compte.';



--
-- Name: uq_discussion_client_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_client_entite ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdEntiteFk") WHERE ((("TypeDiscussion")::text = 'structure'::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdEntiteFk" IS NOT NULL));



--
-- Name: INDEX uq_discussion_client_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_client_entite IS 'Index d’unicité sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_discussion_client_entite ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdEntiteFk") WHERE ((("TypeDiscussion")::text = ''structure''::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdEntiteFk" IS NOT NULL)).';



--
-- Name: uq_discussion_client_expert; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_client_expert ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdProfessionnelFk") WHERE ((("TypeDiscussion")::text = 'expert'::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NOT NULL));



--
-- Name: INDEX uq_discussion_client_expert; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_client_expert IS 'Index d’unicité sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_discussion_client_expert ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdProfessionnelFk") WHERE ((("TypeDiscussion")::text = ''expert''::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NOT NULL)).';



--
-- Name: uq_discussion_directe_entreprise; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_directe_entreprise ON communication."T_Discussion" USING btree ("IdEntiteFk", LEAST("IdUserClientFk", "IdUserDestinataireFk"), GREATEST("IdUserClientFk", "IdUserDestinataireFk")) WHERE ((("TypeDiscussion")::text = 'user'::text) AND "ValideDiscussion" AND ("IdUserClientFk" IS NOT NULL) AND ("IdUserDestinataireFk" IS NOT NULL));



--
-- Name: INDEX uq_discussion_directe_entreprise; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_directe_entreprise IS 'Un seul fil direct actif par paire de comptes et entreprise, dans les deux sens.';



--
-- Name: T_Communication aa_reference_champ; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON communication."T_Communication" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();



--
-- Name: TRIGGER aa_reference_champ ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON communication."T_Communication" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';



--
-- Name: T_DemandeHistorique demande_historique_immuable; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER demande_historique_immuable BEFORE DELETE OR UPDATE ON communication."T_DemandeHistorique" FOR EACH ROW EXECUTE FUNCTION communication.fn_demande_garder_historique();



--
-- Name: TRIGGER demande_historique_immuable ON "T_DemandeHistorique"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER demande_historique_immuable ON communication."T_DemandeHistorique" IS 'Conserve les preuves de suivi et de rejeu.';



--
-- Name: T_Demande demande_identite_immuable; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER demande_identite_immuable BEFORE DELETE OR UPDATE ON communication."T_Demande" FOR EACH ROW EXECUTE FUNCTION communication.fn_demande_proteger_identite();



--
-- Name: TRIGGER demande_identite_immuable ON "T_Demande"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER demande_identite_immuable ON communication."T_Demande" IS 'Préserve source et destinataire historiques et les transitions valides.';



--
-- Name: T_RoutageStructureHistorique routage_historique_immuable; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER routage_historique_immuable BEFORE DELETE OR UPDATE ON communication."T_RoutageStructureHistorique" FOR EACH ROW EXECUTE FUNCTION communication.fn_demande_garder_historique();



--
-- Name: TRIGGER routage_historique_immuable ON "T_RoutageStructureHistorique"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER routage_historique_immuable ON communication."T_RoutageStructureHistorique" IS 'Conserve les preuves de validation du destinataire territorial.';



--
-- Name: T_Chat tr_00_lock_discussion_message; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_00_lock_discussion_message BEFORE INSERT OR DELETE OR UPDATE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_lock_discussion_message();



--
-- Name: TRIGGER tr_00_lock_discussion_message ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_00_lock_discussion_message ON communication."T_Chat" IS 'Verrou des discussions avant modification de leurs messages.';



--
-- Name: T_Communication tr_dater_lecture_annonce; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_dater_lecture_annonce BEFORE UPDATE OF "LectureCommunication", "LuLe" ON communication."T_Communication" FOR EACH ROW EXECUTE FUNCTION communication.fn_dater_lecture_annonce();



--
-- Name: TRIGGER tr_dater_lecture_annonce ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_dater_lecture_annonce ON communication."T_Communication" IS 'Conserve l’instant de la première lecture de chaque annonce reçue.';



--
-- Name: T_Chat tr_sync_dernier_message; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_sync_dernier_message AFTER INSERT OR DELETE OR UPDATE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_sync_dernier_message();



--
-- Name: TRIGGER tr_sync_dernier_message ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_sync_dernier_message ON communication."T_Chat" IS 'Synchronise la dernière activité avec les messages effectivement présents.';



--
-- Name: T_ChatLecture tr_verifier_chat_lecture; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_verifier_chat_lecture BEFORE INSERT OR UPDATE OF "LuLe" ON communication."T_ChatLecture" FOR EACH ROW EXECUTE FUNCTION communication.fn_verifier_chat_lecture();



--
-- Name: TRIGGER tr_verifier_chat_lecture ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_verifier_chat_lecture ON communication."T_ChatLecture" IS 'Vérifie toute nouvelle lecture et empêche de modifier sa date.';



--
-- Name: T_Discussion tr_verifier_creation_discussion_directe; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_verifier_creation_discussion_directe BEFORE INSERT ON communication."T_Discussion" FOR EACH ROW WHEN (((new."TypeDiscussion")::text = 'user'::text)) EXECUTE FUNCTION communication.fn_verifier_creation_discussion_directe();



--
-- Name: TRIGGER tr_verifier_creation_discussion_directe ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_verifier_creation_discussion_directe ON communication."T_Discussion" IS 'Refuse la création d’un fil direct hors de l’entreprise des deux comptes actifs.';



--
-- Name: T_Chat AuthorIdFk; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "AuthorIdFk" FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL;



--
-- Name: CONSTRAINT "AuthorIdFk" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "AuthorIdFk" ON communication."T_Chat" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Chat". Définition : FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL.';



--
-- Name: T_ChatLecture Fk_ChatLecture_Chat; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_ChatLecture"
    ADD CONSTRAINT "Fk_ChatLecture_Chat" FOREIGN KEY ("IdChatFk") REFERENCES communication."T_Chat"("IdChat") ON UPDATE CASCADE ON DELETE CASCADE;



--
-- Name: CONSTRAINT "Fk_ChatLecture_Chat" ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ChatLecture_Chat" ON communication."T_ChatLecture" IS 'La lecture appartient à son message et disparaît si le message est supprimé physiquement.';



--
-- Name: T_ChatLecture Fk_ChatLecture_Utilisateur; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_ChatLecture"
    ADD CONSTRAINT "Fk_ChatLecture_Utilisateur" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE CASCADE;



--
-- Name: CONSTRAINT "Fk_ChatLecture_Utilisateur" ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ChatLecture_Utilisateur" ON communication."T_ChatLecture" IS 'La lecture appartient à son compte et disparaît si le compte est supprimé physiquement.';



--
-- Name: T_Chat Fk_Chat_Discussion; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "Fk_Chat_Discussion" FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE;



--
-- Name: CONSTRAINT "Fk_Chat_Discussion" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Chat_Discussion" ON communication."T_Chat" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Chat". Définition : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';



--
-- Name: T_Discussion Fk_Discussion_Entite; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: CONSTRAINT "Fk_Discussion_Entite" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_Entite" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: T_Discussion Fk_Discussion_Professionnel; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_Professionnel" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: CONSTRAINT "Fk_Discussion_Professionnel" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_Professionnel" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: T_Discussion Fk_Discussion_UserClient; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_UserClient" FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: CONSTRAINT "Fk_Discussion_UserClient" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_UserClient" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: T_Communication Fk_IdEntite; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: T_Communication Fk_IdTypeCommunication; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdTypeCommunication" FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: CONSTRAINT "Fk_IdTypeCommunication" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypeCommunication" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: T_Communication Fk_IdUser; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdUser" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: CONSTRAINT "Fk_IdUser" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUser" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';



--
-- Name: T_Annonce T_Annonce_IdAuteurFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT "T_Annonce_IdAuteurFk_fkey" FOREIGN KEY ("IdAuteurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: T_Annonce T_Annonce_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT "T_Annonce_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: T_Communication T_Communication_IdAnnonceFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "T_Communication_IdAnnonceFk_fkey" FOREIGN KEY ("IdAnnonceFk") REFERENCES communication."T_Annonce"("IdAnnonce") ON DELETE RESTRICT;



--
-- Name: T_DemandeHistorique T_DemandeHistorique_IdAuteurFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_DemandeHistorique"
    ADD CONSTRAINT "T_DemandeHistorique_IdAuteurFk_fkey" FOREIGN KEY ("IdAuteurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;



--
-- Name: T_DemandeHistorique T_DemandeHistorique_IdDemandeFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_DemandeHistorique"
    ADD CONSTRAINT "T_DemandeHistorique_IdDemandeFk_fkey" FOREIGN KEY ("IdDemandeFk") REFERENCES communication."T_Demande"("IdDemande") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdArticleFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdArticleFk_fkey" FOREIGN KEY ("IdArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdDemandeurFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdDemandeurFk_fkey" FOREIGN KEY ("IdDemandeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdDestinataireUserFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdDestinataireUserFk_fkey" FOREIGN KEY ("IdDestinataireUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdEntiteDemandeurFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdEntiteDemandeurFk_fkey" FOREIGN KEY ("IdEntiteDemandeurFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdEntiteDestinataireFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdEntiteDestinataireFk_fkey" FOREIGN KEY ("IdEntiteDestinataireFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdNiveau3Fk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdNiveau3Fk_fkey" FOREIGN KEY ("IdNiveau3Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdNiveau4Fk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdNiveau4Fk_fkey" FOREIGN KEY ("IdNiveau4Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdNiveau5Fk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdNiveau5Fk_fkey" FOREIGN KEY ("IdNiveau5Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON DELETE RESTRICT;



--
-- Name: T_Demande T_Demande_IdProfessionnelFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Demande"
    ADD CONSTRAINT "T_Demande_IdProfessionnelFk_fkey" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT;



--
-- Name: T_Discussion T_Discussion_IdDemandeFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "T_Discussion_IdDemandeFk_fkey" FOREIGN KEY ("IdDemandeFk") REFERENCES communication."T_Demande"("IdDemande") ON DELETE RESTRICT;



--
-- Name: T_Discussion T_Discussion_IdUserDestinataireFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "T_Discussion_IdUserDestinataireFk_fkey" FOREIGN KEY ("IdUserDestinataireFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;



--
-- Name: T_RoutageStructureHistorique T_RoutageStructureHistorique_IdAuteurFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructureHistorique"
    ADD CONSTRAINT "T_RoutageStructureHistorique_IdAuteurFk_fkey" FOREIGN KEY ("IdAuteurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructureHistorique T_RoutageStructureHistorique_IdEntiteApresFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructureHistorique"
    ADD CONSTRAINT "T_RoutageStructureHistorique_IdEntiteApresFk_fkey" FOREIGN KEY ("IdEntiteApresFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructureHistorique T_RoutageStructureHistorique_IdEntiteAvantFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructureHistorique"
    ADD CONSTRAINT "T_RoutageStructureHistorique_IdEntiteAvantFk_fkey" FOREIGN KEY ("IdEntiteAvantFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructureHistorique T_RoutageStructureHistorique_TypeSource_IdSource_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructureHistorique"
    ADD CONSTRAINT "T_RoutageStructureHistorique_TypeSource_IdSource_fkey" FOREIGN KEY ("TypeSource", "IdSource") REFERENCES communication."T_RoutageStructure"("TypeSource", "IdSource") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructure T_RoutageStructure_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructure"
    ADD CONSTRAINT "T_RoutageStructure_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructure T_RoutageStructure_IdNiveau3Fk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructure"
    ADD CONSTRAINT "T_RoutageStructure_IdNiveau3Fk_fkey" FOREIGN KEY ("IdNiveau3Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructure T_RoutageStructure_IdNiveau4Fk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructure"
    ADD CONSTRAINT "T_RoutageStructure_IdNiveau4Fk_fkey" FOREIGN KEY ("IdNiveau4Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructure T_RoutageStructure_IdNiveau5Fk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructure"
    ADD CONSTRAINT "T_RoutageStructure_IdNiveau5Fk_fkey" FOREIGN KEY ("IdNiveau5Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON DELETE RESTRICT;



--
-- Name: T_RoutageStructure T_RoutageStructure_IdVerificateurFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_RoutageStructure"
    ADD CONSTRAINT "T_RoutageStructure_IdVerificateurFk_fkey" FOREIGN KEY ("IdVerificateurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--
