-- Extrait canonique du catalogue installé le 28/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "logistique";
--
-- Name: SCHEMA logistique; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA logistique IS 'Articles, commandes, lignes, stock, mouvements et règlements ; vues et routines de cohérence logistique.';

--
-- Name: controler_inventaire_valide(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.controler_inventaire_valide() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE h record;l record;o record;n record; BEGIN
 IF TG_TABLE_NAME='T_Inventaire' THEN
  SELECT * INTO h FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=NEW."ID_Inventaire";
 ELSE
  SELECT * INTO h FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=COALESCE(NEW."ID_InventaireFk",OLD."ID_InventaireFk");
 END IF;
 IF h."Etat" IN ('valide','annule') AND (NOT EXISTS(SELECT FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=h."ID_Inventaire") OR
  EXISTS(SELECT FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=h."ID_Inventaire" AND ("QteComptee"<>"QteTheorique")<>("ID_CommandeCorrectionFk" IS NOT NULL))) THEN
 RAISE EXCEPTION 'Chaque écart doit posséder son bon correcteur unique' USING ERRCODE='23514';END IF;
 IF h."Etat"<>'annule' THEN RETURN NULL;END IF;
 FOR l IN SELECT * FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=h."ID_Inventaire" LOOP
  IF (l."QteComptee"<>l."QteTheorique")<>(l."ID_CommandeAnnulationFk" IS NOT NULL) THEN RAISE EXCEPTION 'Compensation manquante ou superflue' USING ERRCODE='23514';END IF;
  IF l."ID_CommandeAnnulationFk" IS NULL THEN CONTINUE;END IF;
  SELECT m.* INTO o FROM logistique."V_MouvementStock" m WHERE "ID_cmdFk"=l."ID_CommandeCorrectionFk" AND "ID_ArticleFk"=l."ID_ArticleFk";
  SELECT m.* INTO n FROM logistique."V_MouvementStock" m WHERE "ID_cmdFk"=l."ID_CommandeAnnulationFk" AND "ID_ArticleFk"=l."ID_ArticleFk";
  IF o."ID_Mvt" IS NULL OR n."ID_Mvt" IS NULL OR n."SigneStock"<>-o."SigneStock" OR n."QteMvt"<>o."QteMvt" OR NOT EXISTS(
   SELECT FROM logistique."T_Commande" c JOIN logistique."T_Commande" oldc ON oldc."ID_Commande"=l."ID_CommandeCorrectionFk"
   JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=c."ID_Commande"
   JOIN logistique."T_CommandeDetail" od ON od."ID_CmdFk"=oldc."ID_Commande" AND od."ID_ArticleFk"=d."ID_ArticleFk"
   WHERE c."ID_Commande"=l."ID_CommandeAnnulationFk" AND c."IdEntiteFk"=h."IdEntiteFk" AND c."ID_DeviseFk"=oldc."ID_DeviseFk"
    AND d."ID_ArticleFk"=l."ID_ArticleFk" AND d."PUCmdDetail" IS NOT DISTINCT FROM od."PUCmdDetail"
    AND (SELECT count(*) FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=c."ID_Commande")=1)
  THEN RAISE EXCEPTION 'Compensation incompatible avec le bon d’origine' USING ERRCODE='23514';END IF;
  IF EXISTS((SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=o."ID_Mvt" EXCEPT SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=n."ID_Mvt")
   UNION ALL (SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=n."ID_Mvt" EXCEPT SELECT "ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=o."ID_Mvt"))
  THEN RAISE EXCEPTION 'La compensation conserve les lots d’origine' USING ERRCODE='23514';END IF;
 END LOOP;RETURN NULL;
END $$;

--
-- Name: FUNCTION controler_inventaire_valide(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.controler_inventaire_valide() IS 'Contrôle différé de complétude et inversion exacte des mouvements, prix, devise et lots lors de l’annulation.';

--
-- Name: controler_propriete_logistique(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.controler_propriete_logistique() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE parent_entity integer; article_entity integer; client_entity integer; parent_tiers bigint;
BEGIN
 IF TG_TABLE_NAME IN('T_Article','T_Commande','T_Client') THEN
  IF NEW."IdEntiteFk" IS NULL THEN RAISE EXCEPTION 'Entreprise propriétaire requise.' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND NOT (OLD."IdEntiteFk" IS NULL AND NEW."IdEntiteFk" IS NOT NULL AND current_setting('sauverndeko.owner_assignment',true)='on') THEN RAISE EXCEPTION 'Entreprise propriétaire immuable.' USING ERRCODE='23514';END IF;
 END IF;
 IF TG_TABLE_NAME='T_Client' THEN
  IF TG_OP='UPDATE' AND (NEW."CreeParUserFk" IS DISTINCT FROM OLD."CreeParUserFk" OR NEW."DateCreation" IS DISTINCT FROM OLD."DateCreation") THEN RAISE EXCEPTION 'Auteur et date de création immuables.' USING ERRCODE='23514';END IF;
  IF NEW."IdProfessionnelFk" IS NOT NULL AND NEW."IdUserFk" IS NOT NULL AND NOT EXISTS(SELECT 1 FROM professionnel."T_Professionnel" p WHERE p."IdProfessionnel"=NEW."IdProfessionnelFk" AND p."IdUserFk"=NEW."IdUserFk") THEN RAISE EXCEPTION 'Identités du tiers incompatibles.' USING ERRCODE='23514';END IF;
  IF NEW."ID_TypeClientFk" IS NOT NULL AND NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_Generique"=NEW."ID_TypeClientFk" AND referentiel.fn_reference_champ_connue('logistique','T_Client','ID_TypeClientFk',NEW."ID_TypeClientFk")) THEN RAISE EXCEPTION 'Type de client incompatible.' USING ERRCODE='23514';END IF;
 ELSIF TG_TABLE_NAME='T_Commande' THEN
  IF NEW."ID_TiersFk" IS NOT NULL THEN SELECT "IdEntiteFk" INTO client_entity FROM logistique."T_Client" WHERE "ID_Client"=NEW."ID_TiersFk" FOR SHARE;IF client_entity IS DISTINCT FROM NEW."IdEntiteFk" THEN RAISE EXCEPTION 'Tiers d’une autre entreprise.' USING ERRCODE='23514';END IF;END IF;
 ELSIF TG_TABLE_NAME='T_CommandeDetail' OR TG_TABLE_NAME='T_Mouvement' THEN
  SELECT "IdEntiteFk" INTO article_entity FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk" FOR SHARE;
  IF TG_TABLE_NAME='T_CommandeDetail' THEN SELECT "IdEntiteFk" INTO parent_entity FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CmdFk" FOR SHARE;
  ELSIF NEW."ID_cmdFk" IS NOT NULL THEN SELECT "IdEntiteFk" INTO parent_entity FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_cmdFk" FOR SHARE;
  ELSE parent_entity:=article_entity;END IF;
  IF article_entity IS NULL OR article_entity IS DISTINCT FROM parent_entity THEN RAISE EXCEPTION 'Article et bon doivent appartenir à la même entreprise.' USING ERRCODE='23514';END IF;
 ELSIF TG_TABLE_NAME='T_Reglements' THEN
  SELECT "ID_TiersFk" INTO parent_tiers FROM logistique."T_Commande" WHERE "CodeFacture"=NEW."CodeFactureFk" FOR SHARE;
  IF NEW."ID_TiersFk" IS DISTINCT FROM parent_tiers THEN RAISE EXCEPTION 'Le règlement conserve le tiers de sa facture.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION controler_propriete_logistique(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.controler_propriete_logistique() IS 'Propriété durable et cohérence des tiers conservées ; leur famille de référence est déléguée au catalogue commun.';

--
-- Name: controler_retour_bon(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.controler_retour_bon() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE origine record; entree record; source_entite integer; acteur_entite integer; candidat record; disponible record; lot record; lignes integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Un retour validé est conservé dans son historique.' USING ERRCODE='23514';END IF;
 SELECT c.*,t."AbrGenerique" AS sens,t."ID_CategorieGeneriqueFk" AS categorie INTO origine
 FROM logistique."T_Commande" c LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=c."ID_TypeCmdFk"
 WHERE c."ID_Commande"=NEW."ID_CommandeOrigineFk" FOR UPDATE OF c;
 IF NOT FOUND OR logistique.fn_nature_bon(origine."ID_TypeCmdFk") IS DISTINCT FROM 'sortie' OR origine.sens NOT ILIKE 'sort%' OR origine.sens IS NULL THEN
  RAISE EXCEPTION 'Le retour exige un bon de sortie historique.' USING ERRCODE='23514';END IF;
 SELECT c.*,t."AbrGenerique" AS sens,t."ID_CategorieGeneriqueFk" AS categorie INTO entree
 FROM logistique."T_Commande" c LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=c."ID_TypeCmdFk"
 WHERE c."ID_Commande"=NEW."ID_CommandeRetourFk" FOR UPDATE OF c;
 IF NOT FOUND OR logistique.fn_nature_bon(entree."ID_TypeCmdFk") IS DISTINCT FROM 'entree' OR entree.sens NOT ILIKE 'entr%' OR entree.sens IS NULL THEN
  RAISE EXCEPTION 'Le document compensateur doit être un bon d’entrée.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeRetourFk"=origine."ID_Commande" OR "ID_CommandeOrigineFk"=entree."ID_Commande") THEN
  RAISE EXCEPTION 'Un retour ne peut pas devenir une nouvelle origine.' USING ERRCODE='23514';END IF;
 SELECT "IdEntiteFk" INTO source_entite FROM logistique."T_Commande" WHERE "ID_Commande"=origine."ID_Commande" FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Organisation source introuvable.' USING ERRCODE='23514';END IF;
 SELECT "IdEntiteFk" INTO acteur_entite FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_UserFk" FOR SHARE;
 IF NOT FOUND OR source_entite IS DISTINCT FROM NEW."IdEntiteFk" OR (acteur_entite IS DISTINCT FROM NEW."IdEntiteFk" AND NOT EXISTS(SELECT 1 FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=NEW."ID_UserFk" AND u."Is_Admin" IS TRUE)) OR entree."ID_UserFk" IS DISTINCT FROM NEW."ID_UserFk" THEN
  RAISE EXCEPTION 'Retour et sortie doivent appartenir à la même organisation.' USING ERRCODE='23514';END IF;
 IF origine."ID_DeviseFk" IS NULL OR entree."ID_DeviseFk" IS DISTINCT FROM origine."ID_DeviseFk" THEN
  RAISE EXCEPTION 'La contre-écriture conserve la devise de la sortie.' USING ERRCODE='23514';END IF;
 IF NULLIF(btrim(entree."CodeFacture"),'') IS NOT NULL OR logistique.fn_commande_cloturee(entree."StatusFacture") OR entree."DateCmd" IS DISTINCT FROM NEW."DateRetour" THEN
  RAISE EXCEPTION 'Le bon de retour conserve sa date et ne porte pas de facture.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."V_RetourArticle" WHERE "ID_CommandeOrigineFk"=origine."ID_Commande" AND NOT "SourceCoherente") THEN
  RAISE EXCEPTION 'La sortie doit être rapprochée de ses mouvements avant un retour.' USING ERRCODE='23514';END IF;
 lignes=0;
 FOR candidat IN SELECT d.*,m."ID_Mvt",m."QteMvt",m."PUMvt",m."ID_DeviseFk",m."ID_TypeMvtFk",
   COALESCE((SELECT sum(ml."Quantite") FROM logistique."T_MouvementLot" ml WHERE ml."ID_MvtFk"=m."ID_Mvt"),0) AS lots_qte
   FROM logistique."T_CommandeDetail" d LEFT JOIN logistique."T_Mouvement" m ON m."ID_cmdFk"=d."ID_CmdFk" AND m."ID_ArticleFk"=d."ID_ArticleFk"
   WHERE d."ID_CmdFk"=entree."ID_Commande" ORDER BY d."ID_ArticleFk"
 LOOP
  lignes=lignes+1;
  SELECT * INTO disponible FROM logistique."V_RetourArticle" WHERE "ID_CommandeOrigineFk"=origine."ID_Commande" AND "ID_ArticleFk"=candidat."ID_ArticleFk";
  IF NOT FOUND OR NOT disponible."SourceCoherente" OR candidat."QteCmdDetail" IS NULL OR candidat."QteCmdDetail"<=0 OR candidat."QteCmdDetail">disponible."QteRestante" THEN
   RAISE EXCEPTION 'La quantité rendue dépasse la sortie restante.' USING ERRCODE='23514';END IF;
  IF candidat."PUCmdDetail" IS DISTINCT FROM disponible."PUHistorique" OR candidat."PUMvt" IS DISTINCT FROM disponible."PUHistorique" OR candidat."QteMvt" IS DISTINCT FROM candidat."QteCmdDetail" OR candidat."ID_DeviseFk" IS DISTINCT FROM origine."ID_DeviseFk" OR candidat."ID_TypeMvtFk" IS DISTINCT FROM entree."ID_TypeCmdFk" THEN
   RAISE EXCEPTION 'La contre-écriture conserve le prix, la devise et la quantité historiques.' USING ERRCODE='23514';END IF;
  IF candidat.lots_qte>candidat."QteCmdDetail" OR candidat."QteCmdDetail"-candidat.lots_qte>disponible."QteSansLotRestante" THEN
   RAISE EXCEPTION 'La quantité sans lot dépasse la quantité sortie sans lot.' USING ERRCODE='23514';END IF;
  FOR lot IN SELECT ml."ID_LotArticleFk",ml."Quantite" FROM logistique."T_MouvementLot" ml WHERE ml."ID_MvtFk"=candidat."ID_Mvt"
  LOOP
   IF NOT EXISTS(SELECT 1 FROM logistique."V_RetourLot" rl WHERE rl."ID_CommandeOrigineFk"=origine."ID_Commande" AND rl."ID_ArticleFk"=candidat."ID_ArticleFk" AND rl."ID_LotArticle"=lot."ID_LotArticleFk" AND rl."QteRestante">=lot."Quantite") THEN
    RAISE EXCEPTION 'La quantité ou le lot ne provient pas de la sortie restante.' USING ERRCODE='23514';END IF;
  END LOOP;
 END LOOP;
 IF lignes=0 OR EXISTS(SELECT 1 FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=entree."ID_Commande" AND NOT EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk"=m."ID_cmdFk" AND d."ID_ArticleFk"=m."ID_ArticleFk")) THEN
  RAISE EXCEPTION 'Un retour exige ses lignes et leurs seuls mouvements source.' USING ERRCODE='23514';END IF;
 IF entree."MontantHT" IS DISTINCT FROM (SELECT sum(round("QteCmdDetail"*"PUCmdDetail",2)) FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=entree."ID_Commande") OR entree."MontantTTC" IS DISTINCT FROM entree."MontantHT" THEN
  RAISE EXCEPTION 'La valeur du retour doit correspondre à ses quantités et prix historiques.' USING ERRCODE='23514';END IF;
 NEW."CreeLe"=clock_timestamp();
 NEW."Motif"=btrim(NEW."Motif");
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION controler_retour_bon(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.controler_retour_bon() IS 'Restitution conservée par document de sortie et entrée compensatrice, types déclarés ou historiques au lieu d’une constante de famille ; aucun mouvement ou montant antérieur modifié.';

--
-- Name: controler_sortie_lot_perime(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.controler_sortie_lot_perime() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE s integer; expiration date; bloque boolean; BEGIN
 IF TG_OP='UPDATE' AND NEW IS NOT DISTINCT FROM OLD THEN RETURN NEW; END IF;
 SELECT v."SigneStock",l."DatePeremptionLot",e."BloquerLotsPerimes" INTO s,expiration,bloque
 FROM logistique."T_Mouvement" m JOIN logistique."V_MouvementStock" v ON v."ID_Mvt"=m."ID_Mvt"
 JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=NEW."ID_LotArticleFk"
 JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk" JOIN systeme."T_Entite" e ON e."IdEntite"=a."IdEntiteFk"
 WHERE m."ID_Mvt"=NEW."ID_MvtFk";
 IF NEW."MotifDerogationPeremption" IS NOT NULL THEN
  IF s<>-1 OR expiration IS NULL OR expiration>=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date OR NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_DerogationUserFk" AND "ValideUser" IS TRUE AND "Is_Admin" IS TRUE) THEN
   RAISE EXCEPTION 'Dérogation de péremption réservée à un administrateur global actif et à un lot périmé sortant' USING ERRCODE='23514'; END IF;
  NEW."MotifDerogationPeremption"=btrim(NEW."MotifDerogationPeremption");
  NEW."DateDerogationPeremption"=clock_timestamp();
 ELSIF s=-1 AND expiration<(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date AND bloque IS TRUE THEN
  RAISE EXCEPTION 'Lot périmé : sortie bloquée ; dérogation motivée requise' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION controler_sortie_lot_perime(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.controler_sortie_lot_perime() IS 'Défense SQL des prélèvements sur lots périmés selon l’entreprise ; contrôle l’auteur global et conserve le motif sur la ventilation.';

--
-- Name: controler_stock_lots(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.controler_stock_lots() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE article_id integer; mvt_id integer; linked_total numeric; global_stock numeric; lot_stock numeric;
BEGIN
 IF TG_TABLE_NAME='T_Article' THEN article_id=NEW."ID_Article";
 ELSIF TG_TABLE_NAME='T_LotArticle' THEN article_id=NEW."ID_ArticleFk";
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN
  IF TG_OP='DELETE' THEN article_id=OLD."ID_ArticleFk";mvt_id=OLD."ID_Mvt";ELSE article_id=NEW."ID_ArticleFk";mvt_id=NEW."ID_Mvt";END IF;
 ELSE
  IF TG_OP='DELETE' THEN mvt_id=OLD."ID_MvtFk";SELECT "ID_ArticleFk" INTO article_id FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=OLD."ID_LotArticleFk";
  ELSE mvt_id=NEW."ID_MvtFk";SELECT "ID_ArticleFk" INTO article_id FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=NEW."ID_LotArticleFk";END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
 JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk" WHERE m."ID_ArticleFk"=article_id AND l."ID_ArticleFk"<>m."ID_ArticleFk") THEN
 RAISE EXCEPTION 'Lot et mouvement incompatibles.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_Mouvement" m JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
 WHERE m."ID_ArticleFk"=article_id GROUP BY m."ID_Mvt",m."QteMvt" HAVING sum(ml."Quantite")>m."QteMvt") THEN
 RAISE EXCEPTION 'La ventilation par lot dépasse la quantité du mouvement.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."V_LotArticleStock" WHERE "ID_ArticleFk"=article_id AND "StockLot"<0) THEN
 RAISE EXCEPTION 'Stock de lot insuffisant.' USING ERRCODE='23514';END IF;
 SELECT "QteArticle" INTO global_stock FROM logistique."T_Article" WHERE "ID_Article"=article_id;
 SELECT COALESCE(sum("StockLot"),0) INTO lot_stock FROM logistique."V_LotArticleStock" WHERE "ID_ArticleFk"=article_id;
 IF global_stock IS NOT NULL AND lot_stock>global_stock THEN
 RAISE EXCEPTION 'Une sortie doit préciser ses lots : le stock sans lot est insuffisant.' USING ERRCODE='23514';END IF;
 RETURN NULL;
END;
$$;

--
-- Name: FUNCTION controler_stock_lots(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.controler_stock_lots() IS 'Contrôle différé en fin de transaction : ventilation bornée par le mouvement, lots non négatifs et stock total ventilé inférieur ou égal au stock global. Aucun second effet sur le stock.';

--
-- Name: enregistrer_cout_ouverture(integer, integer, numeric, text, integer, bigint, uuid, integer, text); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.enregistrer_cout_ouverture(p_article integer, p_devise integer, p_cout numeric, p_motif text, p_auteur integer, p_version bigint, p_request uuid, p_entite integer, p_revision text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE a record;u record;o record;lastid integer;qty numeric;costs jsonb;last_request record;priorflag text;newrow jsonb;
BEGIN
 IF p_request IS NULL OR p_revision IS NULL OR p_version IS NULL OR p_version<0 OR p_cout IS NULL OR p_cout<0 OR p_cout>9999999999.999999 OR p_cout<>round(p_cout,6) OR p_cout::text IN ('NaN','Infinity','-Infinity') OR p_motif IS NULL OR length(btrim(p_motif)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Coût, motif et demande valides requis' USING ERRCODE='23514';END IF;
 SELECT x.*,g."NomGenerique" AS role INTO u FROM systeme."T_Utilisateurs" x LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=x."IdRoleFk" WHERE x."IdUser"=p_auteur;
 IF u."ValideUser" IS NOT TRUE OR (u."Is_Admin" IS TRUE OR u."IdEntiteFk"=p_entite AND (u."Is_staff" IS TRUE OR lower(u.role) IN ('admin','administrateur'))) IS NOT TRUE THEN RAISE EXCEPTION 'Droits de valorisation requis' USING ERRCODE='42501';END IF;
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=p_article AND "IdEntiteFk"=p_entite FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Article hors entreprise' USING ERRCODE='42501';END IF;
 SELECT * INTO last_request FROM logistique."T_ValorisationEvenement" WHERE "ID_UserFk"=p_auteur AND "RequestId"=p_request;
 IF FOUND THEN
  IF last_request."ID_ArticleFk"=p_article AND (last_request."Apres"->>'ID_DeviseFk')::integer=p_devise AND (last_request."Apres"->>'CoutOuverture')::numeric=p_cout AND last_request."Motif"=btrim(p_motif) AND (last_request."Apres"->>'RevisionDemande') IS NOT DISTINCT FROM p_revision AND (last_request."Avant"->>'Version')::bigint=p_version THEN RETURN;END IF;
  RAISE EXCEPTION 'Cette demande possède un autre contenu' USING ERRCODE='23505';
 END IF;
 SELECT * INTO o FROM logistique."T_ValorisationOuverture" WHERE "ID_ArticleFk"=p_article AND "ID_DeviseFk"=p_devise;
 IF COALESCE(o."Version",0)<>p_version THEN RAISE EXCEPTION 'Valorisation modifiée : rechargez la fiche' USING ERRCODE='40001';END IF;
 IF p_revision<>logistique.fn_revision_valorisation(p_article,p_devise,p_version) THEN RAISE EXCEPTION 'La source du coût a changé : rechargez la fiche' USING ERRCODE='40001';END IF;
 SELECT coalesce(max(m."ID_Mvt"),0),coalesce(sum(m."QteMvt"*CASE WHEN g."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN g."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END),0)
 INTO lastid,qty FROM logistique."T_Mouvement" m JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeMvtFk" WHERE m."ID_ArticleFk"=p_article AND m."ID_DeviseFk"=p_devise;
 IF qty<0 THEN RAISE EXCEPTION 'Stock négatif dans cette devise : rapprochez les documents avant valorisation' USING ERRCODE='23514';END IF;
 SELECT coalesce(jsonb_object_agg(f."ID_Mvt"::text,to_jsonb(f."CoutUnitaire")) FILTER(WHERE f."CoutUnitaire" IS NOT NULL),'{}'::jsonb) INTO costs FROM logistique.fn_cout_mouvements(p_article,p_devise) f;
 priorflag=coalesce(current_setting('logistique.allow_valuation_write',true),'off');PERFORM set_config('logistique.allow_valuation_write','on',true);
 INSERT INTO logistique."T_ValorisationOuverture"("ID_ArticleFk","ID_DeviseFk","IdEntiteFk","ID_MvtArrete","QuantiteOuverture","CoutOuverture","CoutsAnterieurs") VALUES(p_article,p_devise,p_entite,lastid,qty,p_cout,costs)
 ON CONFLICT("ID_ArticleFk","ID_DeviseFk") DO UPDATE SET "ID_MvtArrete"=excluded."ID_MvtArrete","QuantiteOuverture"=excluded."QuantiteOuverture","CoutOuverture"=excluded."CoutOuverture","CoutsAnterieurs"=excluded."CoutsAnterieurs","Version"=logistique."T_ValorisationOuverture"."Version"+1,"ModifieLe"=clock_timestamp();
 PERFORM set_config('logistique.allow_valuation_write',priorflag,true);
 SELECT to_jsonb(x)||jsonb_build_object('RevisionDemande',p_revision) INTO newrow FROM logistique."T_ValorisationOuverture" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise;
 INSERT INTO logistique."T_ValorisationEvenement"("ID_ArticleFk","IdEntiteFk","ID_UserFk","RequestId","Operation","Motif","Avant","Apres") VALUES(p_article,p_entite,p_auteur,p_request,CASE WHEN o."CoutOuverture" IS NULL THEN 'ouverture' ELSE 'reevaluation' END,btrim(p_motif),coalesce(to_jsonb(o),'{}'::jsonb)||jsonb_build_object('Version',coalesce(o."Version",0)),newrow);
END $$;

--
-- Name: FUNCTION enregistrer_cout_ouverture(p_article integer, p_devise integer, p_cout numeric, p_motif text, p_auteur integer, p_version bigint, p_request uuid, p_entite integer, p_revision text); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.enregistrer_cout_ouverture(p_article integer, p_devise integer, p_cout numeric, p_motif text, p_auteur integer, p_version bigint, p_request uuid, p_entite integer, p_revision text) IS 'Confirme ou réévalue le stock courant dans une devise, sous verrou article, avec droit gestionnaire, motif, version et demande idempotente. Conserve les coûts prouvés antérieurs et journalise avant/après. Aucun mouvement de quantité et aucune écriture de comptabilité générale.';

--
-- Name: fn_assert_generique_category(integer, integer, text, text); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_assert_generique_category(p_id_generique integer, p_id_categorie_generique integer, p_contexte text, p_nom_colonne text) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE table_name text;
BEGIN
 IF p_id_generique IS NULL THEN RETURN;END IF;
 table_name:=CASE WHEN p_contexte ILIKE '%article%' THEN 'T_Article' WHEN p_contexte ILIKE '%commande%' THEN 'T_Commande'
 WHEN p_contexte ILIKE '%reglement%' THEN 'T_Reglements' WHEN p_contexte ILIKE '%mouvement%' THEN 'T_Mouvement'
 WHEN p_contexte ILIKE '%remboursement%' THEN 'T_Remboursement' WHEN p_contexte ILIKE '%facture%' THEN 'T_Facture' END;
 IF table_name='T_Mouvement' AND p_nom_colonne='ID_TypeMvtFk' AND referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',p_id_generique) THEN RETURN;END IF;
 IF table_name='T_Facture' AND p_nom_colonne IN('ID_ModePaiementFk','ID_ConditionPaiementFk') AND referentiel.fn_reference_champ_connue('logistique','T_Commande',p_nom_colonne,p_id_generique) THEN RETURN;END IF;
 IF table_name IS NULL OR NOT referentiel.fn_reference_champ_connue('logistique',table_name,p_nom_colonne,p_id_generique) THEN
  RAISE EXCEPTION 'Référence incompatible pour %.%.',coalesce(table_name,p_contexte),p_nom_colonne USING ERRCODE='23514';END IF;
END $$;

--
-- Name: FUNCTION fn_assert_generique_category(p_id_generique integer, p_id_categorie_generique integer, p_contexte text, p_nom_colonne text); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_assert_generique_category(p_id_generique integer, p_id_categorie_generique integer, p_contexte text, p_nom_colonne text) IS 'Compatibilité des procédures historiques avec le catalogue physique. Le paramètre de famille ancien conserve la signature, sans imposer une constante ; la nouvelle affectation est validée au scope par la garde de table.';

--
-- Name: fn_audit_stock(integer, timestamp without time zone); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_audit_stock(p_id_article integer DEFAULT NULL::integer, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("ID_Article" integer, "CodeArticleInterne" character varying, "NomArticle" character varying, "StockArticle" numeric, "StockMouvements" numeric, "Ecart" numeric, "N_Mouvements" integer, "QteEntree" numeric, "QteSortie" numeric)
    LANGUAGE sql STABLE PARALLEL SAFE
    AS $$
SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    COALESCE(a."QteArticle", 0)::numeric AS "StockArticle",
    COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS "StockMouvements",
    COALESCE(a."QteArticle", 0)::numeric - COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS "Ecart",
    COUNT(v."ID_Mvt")::integer AS "N_Mouvements",
    COALESCE(
        SUM(
            CASE
                WHEN v."SigneStock" = 1 THEN COALESCE(v."QteMvt", 0)
                ELSE 0
            END
        ),
        0
    )::numeric AS "QteEntree",
    COALESCE(
        SUM(
            CASE
                WHEN v."SigneStock" = -1 THEN COALESCE(v."QteMvt", 0)
                ELSE 0
            END
        ),
        0
    )::numeric AS "QteSortie"
FROM logistique."T_Article" a
    LEFT JOIN logistique."V_MouvementStock" v ON v."ID_ArticleFk" = a."ID_Article"
    AND (
        p_date_max IS NULL
        OR v."DateMvt" <= p_date_max
    )
WHERE p_id_article IS NULL
    OR a."ID_Article" = p_id_article
GROUP BY a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    a."QteArticle"
ORDER BY a."NomArticle",
    a."ID_Article";
$$;

--
-- Name: FUNCTION fn_audit_stock(p_id_article integer, p_date_max timestamp without time zone); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_audit_stock(p_id_article integer, p_date_max timestamp without time zone) IS 'Lecture SQL STABLE de l’audit au grain article, intégrable par le planificateur pour pousser les filtres d’article. Compare le stock courant aux mouvements signés ; p_date_max borne les mouvements sans reconstituer un stock historique.';

--
-- Name: fn_bon_inventaire(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_bon_inventaire(p_commande integer) RETURNS boolean
    LANGUAGE sql
    SET search_path TO 'pg_catalog'
    AS $$ SELECT EXISTS(SELECT FROM logistique."V_BonInventaire" WHERE "ID_Commande"=p_commande) $$;

--
-- Name: FUNCTION fn_bon_inventaire(p_commande integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_bon_inventaire(p_commande integer) IS 'Classe un bon selon ses liens de comptage, sans heuristique de référence texte. VOLATILE conserve un instantané frais après attente du verrou concurrent.';

--
-- Name: fn_code_bon(integer, integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_code_bon(p_id integer, p_type integer) RETURNS character varying
    LANGUAGE plpgsql STABLE STRICT
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE nature text:=logistique.fn_nature_bon(p_type);
BEGIN
 IF p_id IS NULL OR p_id<=0 OR nature IS NULL THEN RAISE EXCEPTION 'Identité ou type de bon inconnu.' USING ERRCODE='23514';END IF;
 RETURN CASE nature WHEN 'entree' THEN 'BE-' WHEN 'sortie' THEN 'BS-' WHEN 'commande' THEN 'CMD-' END||p_id::text;
END $$;

--
-- Name: FUNCTION fn_code_bon(p_id integer, p_type integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_code_bon(p_id integer, p_type integer) IS 'Numéro court automatique des nouveaux documents : BE-ID, BS-ID et CMD-ID selon le type explicite du référentiel. Les numéros déjà émis restent inchangés.';

--
-- Name: fn_code_bon_a_date(integer, timestamp with time zone); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_code_bon_a_date(p_id integer, p_emis_le timestamp with time zone) RETURNS character varying
    LANGUAGE sql STABLE PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT CASE WHEN h."ID_Commande" IS NOT NULL AND (p_emis_le IS NULL OR p_emis_le<=h."RenumeroteLe") THEN h."AncienCodeCmd"
  ELSE coalesce(c."CodeCmd",h."NouveauCodeCmd") END
 FROM (SELECT 1) source
 LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=p_id
 LEFT JOIN logistique."T_BonCodeHistorique" h ON h."ID_Commande"=p_id
 WHERE c."ID_Commande" IS NOT NULL OR h."ID_Commande" IS NOT NULL
$$;

--
-- Name: FUNCTION fn_code_bon_a_date(p_id integer, p_emis_le timestamp with time zone); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_code_bon_a_date(p_id integer, p_emis_le timestamp with time zone) IS 'Référence du bon à l’émission documentaire : ancien code exact si émission antérieure/égale à la reprise06 ou date historique absente, sinon code courant. Le service appelant doit d’abord autoriser le parent et son entreprise.';

--
-- Name: fn_code_commande(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_code_commande(p_id integer) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF p_id<=0 THEN RAISE EXCEPTION 'Identité de bon positive requise.' USING ERRCODE='23514'; END IF;
 RETURN 'cmd-'||p_id::text;
END $$;

--
-- Name: FUNCTION fn_code_commande(p_id integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_code_commande(p_id integer) IS 'Code déterministe court cmd-ID_Commande, sans padding ni réservation de séquence.';

--
-- Name: fn_code_devise(text); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_code_devise(p_abreviation text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$ SELECT CASE upper(btrim(p_abreviation)) WHEN 'EURO' THEN 'EUR' ELSE upper(btrim(p_abreviation)) END $$;

--
-- Name: FUNCTION fn_code_devise(p_abreviation text); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_code_devise(p_abreviation text) IS 'Code de devise normalisé du référentiel ; EURO est présenté EUR, sans conversion monétaire.';

--
-- Name: fn_code_facture(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_code_facture(p_id_commande integer) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF p_id_commande<=0 THEN RAISE EXCEPTION 'Identité du bon facturé positive requise.' USING ERRCODE='23514'; END IF;
 RETURN 'fac-'||p_id_commande::text;
END $$;

--
-- Name: FUNCTION fn_code_facture(p_id_commande integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_code_facture(p_id_commande integer) IS 'Code déterministe court fac-ID_Commande du bon facturé ; ne consomme aucune identité.';

--
-- Name: fn_commande_cloturee(text); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_commande_cloturee(p_statut text) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
 SELECT translate(lower(btrim(COALESCE(p_statut, ''))),
   'àâäéèêëîïôöùûüç', 'aaaeeeeiioouuuc') = 'cloturee';
$$;

--
-- Name: FUNCTION fn_commande_cloturee(p_statut text); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_commande_cloturee(p_statut text) IS 'Prédicat commun de clôture : normalise espaces, casse et accents français du statut ; vrai pour Clôturée/cloturee. Sans lecture de données ni effet de bord.';

--
-- Name: fn_cout_mouvements(integer, integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_cout_mouvements(p_article integer, p_devise integer) RETURNS TABLE("ID_Mvt" integer, "ID_ArticleFk" integer, "ID_DeviseFk" integer, "IdEntiteFk" integer, "QteSignee" numeric, "CoutUnitaire" numeric, "ValeurMouvement" numeric, "StockApres" numeric, "ValeurApres" numeric, "OrigineCout" text, "EtatValorisation" text)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE o record;m record; q numeric:=0;v numeric:=0;cu numeric;sgn integer;known boolean:=true;arret integer:=0;costs jsonb:='{}';source_id integer;tag text;entity integer;origins jsonb:='{}';needed integer[]:=ARRAY[]::integer[];corrections integer[]:=ARRAY[]::integer[];
BEGIN
 SELECT a."IdEntiteFk" INTO entity FROM logistique."T_Article" a WHERE a."ID_Article"=p_article;
 SELECT * INTO o FROM logistique."T_ValorisationOuverture" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise;
 IF FOUND THEN q=o."QuantiteOuverture";v=q*o."CoutOuverture";known=o."CoutOuverture" IS NOT NULL;arret=o."ID_MvtArrete";costs=o."CoutsAnterieurs";END IF;
 -- Préparer les liens réellement utilisés dans cet historique, une fois par article/devise.
 -- Le calcul est relu après un futur retour : son coût d’origine sera alors mis en cache.
 WITH child_commands AS (SELECT DISTINCT x."ID_cmdFk" AS child FROM logistique."T_Mouvement" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise AND x."ID_cmdFk" IS NOT NULL),
 links AS (SELECT r."ID_CommandeRetourFk" AS child,r."ID_CommandeOrigineFk" AS origin,0 AS priority FROM logistique."T_RetourBon" r JOIN child_commands c ON c.child=r."ID_CommandeRetourFk"
 UNION ALL SELECT i."ID_CommandeAnnulationFk",i."ID_CommandeCorrectionFk",1 FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article AND i."ID_CommandeAnnulationFk" IS NOT NULL),
 chosen AS (SELECT DISTINCT ON (x.child) x.child,x.origin FROM links x ORDER BY x.child,x.priority)
 SELECT coalesce(jsonb_object_agg(x.child::text,to_jsonb((SELECT y."ID_Mvt" FROM logistique."T_Mouvement" y WHERE y."ID_cmdFk"=x.origin AND y."ID_ArticleFk"=p_article AND y."ID_DeviseFk"=p_devise ORDER BY y."ID_Mvt" LIMIT 1))),'{}'::jsonb) INTO origins FROM chosen x;
 SELECT coalesce(array_agg(DISTINCT x.value::integer) FILTER(WHERE x.value IS NOT NULL),ARRAY[]::integer[]) INTO needed FROM jsonb_each_text(origins) x;
 SELECT coalesce(array_agg(DISTINCT i."ID_CommandeCorrectionFk") FILTER(WHERE i."ID_CommandeCorrectionFk" IS NOT NULL),ARRAY[]::integer[]) INTO corrections FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article;
 FOR m IN SELECT x.*,g."AbrGenerique" AS sens FROM logistique."T_Mouvement" x JOIN referentiel."T_Generique" g ON g."ID_Generique"=x."ID_TypeMvtFk"
  WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise ORDER BY x."ID_Mvt" LOOP
  "ID_Mvt"=m."ID_Mvt";"ID_ArticleFk"=p_article;"ID_DeviseFk"=p_devise;"IdEntiteFk"=entity;
  sgn=CASE WHEN m.sens ILIKE 'entr%' THEN 1 WHEN m.sens ILIKE 'sort%' THEN -1 ELSE 0 END;
  "QteSignee"=m."QteMvt"*sgn;cu=NULL;tag=NULL;
  IF m."ID_Mvt"<=arret THEN
   "CoutUnitaire"=(costs->>m."ID_Mvt"::text)::numeric;"ValeurMouvement"="QteSignee"*"CoutUnitaire";"StockApres"=NULL;"ValeurApres"=NULL;
   "OrigineCout"='Avant arrêté';"EtatValorisation"=CASE WHEN "CoutUnitaire" IS NULL THEN 'Historique non valorisé' ELSE 'Coût conservé' END;RETURN NEXT;CONTINUE;
  END IF;
  source_id=(origins->>m."ID_cmdFk"::text)::integer;
  IF origins ? coalesce(m."ID_cmdFk"::text,'') THEN
   -- Un lien sans mouvement source reste sans coût, sans repli sur le prix commercial.
   cu=(costs->>source_id::text)::numeric;tag='Coût du mouvement d’origine';
  ELSIF sgn=1 THEN
   -- Un gain d’inventaire utilise le coût moyen, une réception son prix d’achat réel.
   IF m."ID_cmdFk"=ANY(corrections) THEN cu=CASE WHEN q>0 THEN v/q ELSE NULL END;tag='Correction d’inventaire';
   ELSE cu=m."PUMvt";tag='Prix d’achat de réception';END IF;
  ELSIF sgn=-1 THEN cu=CASE WHEN q>0 THEN v/q ELSE NULL END;tag='CUMP avant sortie';
  ELSE cu=0;tag='Sans effet de stock';END IF;
  IF NOT known OR cu IS NULL OR cu<0 OR cu::text IN ('NaN','Infinity','-Infinity') THEN known=false;END IF;
  IF known THEN v=v+"QteSignee"*cu;END IF;
  q=q+"QteSignee";
  IF q<0 OR (known AND v< -0.000000000001) THEN known=false;END IF;
  IF q=0 THEN v=0;known=true;END IF;
  IF known AND cu IS NOT NULL AND m."ID_Mvt"=ANY(needed) THEN costs=jsonb_set(costs,ARRAY[m."ID_Mvt"::text],to_jsonb(cu));END IF;
  "CoutUnitaire"=CASE WHEN known THEN cu ELSE NULL END;"ValeurMouvement"=CASE WHEN known THEN round("QteSignee"*cu,2) ELSE NULL END;
  "StockApres"=q;"ValeurApres"=CASE WHEN known THEN round(v,12) ELSE NULL END;"OrigineCout"=tag;
  "EtatValorisation"=CASE WHEN known THEN 'Calculé' WHEN o."CoutOuverture" IS NULL AND arret>0 THEN 'À initialiser' ELSE 'Coût à vérifier' END;
  RETURN NEXT;
 END LOOP;
END $$;

--
-- Name: FUNCTION fn_cout_mouvements(p_article integer, p_devise integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_cout_mouvements(p_article integer, p_devise integer) IS 'CUMP par ordre stable d’enregistrement ID_Mvt, indépendant des dates métier rétroactives. Entrées au prix d’achat ; sorties au coût moyen ; retours/annulations au coût prouvé d’origine. Calcul numeric sans conversion ; absence de coût, stock négatif par devise ou coût incohérent restent indéterminables. Aucun stock modifié.';

--
-- Name: fn_devise_usd(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_devise_usd() RETURNS integer
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE identifiant integer; nombre bigint;
BEGIN
 SELECT min(g."ID_Generique"),count(*) INTO identifiant,nombre
 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Article','ID_DeviseFk',NULL))
   AND c."ValideCategorieGenerique" IS TRUE AND g."ValideGenerique" IS TRUE
   AND logistique.fn_code_devise(g."AbrGenerique")='USD';
 IF nombre<>1 THEN
  RAISE EXCEPTION 'Une seule devise USD active est requise dans la catégorie Devise active (trouvées : %).',nombre USING ERRCODE='23514';
 END IF;
 RETURN identifiant;
END;
$$;

--
-- Name: FUNCTION fn_devise_usd(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_devise_usd() IS 'Défaut USD global résolu dans la catégorie courante du champ devise Article ; exige une seule valeur USD active et conserve son code ISO. Les choix d’entreprise sont explicitement transmis par les services.';

--
-- Name: fn_effet_type_bon(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_effet_type_bon(p_type integer) RETURNS smallint
    LANGUAGE sql STABLE PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$ SELECT CASE logistique.fn_nature_bon(p_type) WHEN 'entree' THEN 1 WHEN 'sortie' THEN -1 WHEN 'commande' THEN 0 ELSE NULL END::smallint $$;

--
-- Name: FUNCTION fn_effet_type_bon(p_type integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_effet_type_bon(p_type integer) IS 'Effet stock du type connu : +1 entrée, -1 sortie, 0 pour CMD explicite. Un type absent ou inconnu retourne NULL et doit être refusé en écriture.';

--
-- Name: fn_entite_document(text, bigint); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_entite_document(kind text, object_id bigint) RETURNS integer
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE result integer;
BEGIN
 IF kind='bon' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Commande" WHERE "ID_Commande"=object_id;
 ELSIF kind='facture' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Facture" WHERE "ID_CommandeFk"=object_id;
 ELSIF kind='reglement' THEN SELECT c."IdEntiteFk" INTO result FROM logistique."T_Reglements" p JOIN logistique."T_Commande" c ON c."CodeFacture"=p."CodeFactureFk" WHERE p."ID_Reglement"=object_id;
 ELSIF kind='avoir' AND to_regclass('logistique."T_Avoir"') IS NOT NULL THEN EXECUTE 'SELECT "IdEntiteFk" FROM logistique."T_Avoir" WHERE "ID_Avoir"=$1' INTO result USING object_id;
 END IF;
 RETURN result;
END $_$;

--
-- Name: FUNCTION fn_entite_document(kind text, object_id bigint); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_entite_document(kind text, object_id bigint) IS 'Résout uniquement les types de documents autorisés et leur entreprise propriétaire durable.';

--
-- Name: fn_identite_commande_deja_utilisee(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_identite_commande_deja_utilisee(p_id integer) RETURNS boolean
    LANGUAGE sql STABLE STRICT PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT EXISTS(SELECT 1 FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_id
  OR c."CodeCmd"=logistique.fn_code_commande(p_id) OR c."CodeFacture"=logistique.fn_code_facture(p_id))
 OR EXISTS(SELECT 1 FROM systeme."T_Audit_Log" a WHERE a."TableName" IN ('logistique.T_Commande','T_Commande','logistique.T_Facture') AND logistique.fn_identites_audit(a."OldData") @> ARRAY[p_id::numeric])
 OR EXISTS(SELECT 1 FROM systeme."T_Audit_Log" a WHERE a."TableName" IN ('logistique.T_Commande','T_Commande','logistique.T_Facture') AND logistique.fn_identites_audit(a."NewData") @> ARRAY[p_id::numeric]);
$$;

--
-- Name: FUNCTION fn_identite_commande_deja_utilisee(p_id integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_identite_commande_deja_utilisee(p_id integer) IS 'Détecte les identités/références courantes ou historiques via deux index GIN des audits, anciens formats et zéros initiaux inclus ; aucun parcours intégral par nouveau bon.';

--
-- Name: fn_identites_audit(jsonb); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_identites_audit(p_document jsonb) RETURNS numeric[]
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE result numeric[]:=ARRAY[]::numeric[]; raw text; digits text; key text;
BEGIN
 IF jsonb_typeof(p_document)<>'object' THEN RETURN result;END IF;
 FOREACH key IN ARRAY ARRAY['ID_Commande','ID_CommandeFk','ID_CommandeRetourFk','CodeCmd','CodeFacture'] LOOP
  raw=p_document->>key;
  IF raw IS NULL THEN CONTINUE;END IF;
  IF key='CodeCmd' THEN
   IF raw ~* '^C_[0-9]+$' THEN digits=substr(raw,3);
   ELSIF raw ~* '^cmd-[0-9]+$' THEN digits=substr(raw,5);
   ELSIF raw ~* '^(BE|BS)-[0-9]+$' THEN digits=substr(raw,4);ELSE CONTINUE;END IF;
  ELSIF key='CodeFacture' THEN
   IF raw ~* '^F_[0-9]+$' THEN digits=substr(raw,3);
   ELSIF raw ~* '^fac-[0-9]+$' THEN digits=substr(raw,5);ELSE CONTINUE;END IF;
  ELSE
   IF raw !~ '^[0-9]+$' THEN CONTINUE;END IF;digits=raw;
  END IF;
  digits=ltrim(digits,'0');
  IF digits='' OR length(digits)>1000 THEN CONTINUE;END IF;
  result=array_append(result,digits::numeric);
 END LOOP;
 SELECT coalesce(array_agg(DISTINCT x ORDER BY x),ARRAY[]::numeric[]) INTO result FROM unnest(result) x;
 RETURN result;
END $_$;

--
-- Name: FUNCTION fn_identites_audit(p_document jsonb); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_identites_audit(p_document jsonb) IS 'Identites historiques indexables, y compris C_/cmd-/BE-/BS-/F_/fac- et zeros initiaux; les identites supprimees restent reservees.';

--
-- Name: fn_materialiser_stock_initial(integer, integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_materialiser_stock_initial(p_article integer, p_mouvement integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE a record;m logistique."T_Mouvement"%ROWTYPE;num record;kind integer;command_id integer;qty numeric;price numeric;business_date timestamp;origin text;prior_article text:=coalesce(current_setting('logistique.stock_initial_article',true),'');prior_movement text:=coalesce(current_setting('logistique.stock_initial_mouvement',true),'');
BEGIN
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=p_article FOR NO KEY UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Article absent.' USING ERRCODE='23503';END IF;
 IF p_mouvement IS NULL THEN
  SELECT "ID_Commande" INTO command_id FROM logistique."T_Commande" WHERE "ID_ArticleInitialFk"=p_article AND "OrigineBon"='stock_initial';
  IF FOUND THEN RETURN command_id;END IF;
  qty=a."QteArticle";price=a."PUArticle";business_date=coalesce(a."DateHeureAuto"::timestamp,clock_timestamp()::timestamp);origin='stock_initial';
  IF coalesce(qty,0)=0 THEN RETURN NULL;END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=p_article) THEN RAISE EXCEPTION 'Stock deja historise: rapprochez les mouvements existants.' USING ERRCODE='23514';END IF;
  SELECT g."ID_Generique" INTO kind FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Commande','ID_TypeCmdFk',a."IdEntiteFk")) AND g."AbrGenerique" ILIKE 'entr%' AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE ORDER BY g."ID_Generique" LIMIT 1;
 ELSE
  SELECT * INTO m FROM logistique."T_Mouvement" WHERE "ID_Mvt"=p_mouvement AND "ID_ArticleFk"=p_article FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mouvement absent.' USING ERRCODE='23503';END IF;
  IF m."ID_cmdFk" IS NOT NULL THEN RETURN m."ID_cmdFk";END IF;
  qty=m."QteMvt";price=m."PUMvt";business_date=m."DateMvt";kind=m."ID_TypeMvtFk";origin='reprise_mouvement';
 END IF;
 IF qty IS NULL OR qty<=0 OR price IS NULL OR price<0 OR kind IS NULL THEN RAISE EXCEPTION 'Quantite, prix d achat et type requis pour le stock initial.' USING ERRCODE='23514';END IF;
 PERFORM set_config('logistique.stock_initial_article',p_article::text,true);
 PERFORM set_config('logistique.stock_initial_mouvement',coalesce(p_mouvement::text,''),true);
 SELECT * INTO num FROM logistique.fn_reserver_identite_commande();
 INSERT INTO logistique."T_Commande"("ID_Commande","ID_TypeCmdFk","ID_UserFk","IdEntiteFk","ID_DeviseFk","DateCmd","DateHeureAutoCmd","RefCmd","ObsCmd","OrigineBon","ID_ArticleInitialFk")
 VALUES(num."ID_Commande",kind,CASE WHEN p_mouvement IS NULL THEN a."ID_UserFK" END,a."IdEntiteFk",coalesce(m."ID_DeviseFk",a."ID_DeviseFk"),business_date,clock_timestamp(),CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Reprise mouvement historique / '||p_mouvement::text END,CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Rattachement documentaire sans variation de stock. Auteur historique non prouvé; dates, prix et mouvement conservés.' END,origin,p_article)
 RETURNING "ID_Commande" INTO command_id;
 INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail","ObsCmdDetail") VALUES(command_id,p_article,qty,price,CASE WHEN p_mouvement IS NULL THEN 'Stock initial de la fiche article' ELSE 'Mouvement historique conservé #'||p_mouvement::text END);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk") VALUES('logistique.T_Commande',CASE WHEN p_mouvement IS NULL THEN 'INITIAL_STOCK_DOCUMENT' ELSE 'HISTORICAL_STOCK_DOCUMENT' END,jsonb_build_object('ID_Commande',command_id,'ID_Article',p_article,'ID_Mvt',coalesce(p_mouvement,(SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=command_id AND "ID_ArticleFk"=p_article)),'OrigineBon',origin,'AuteurOrigineProuve',p_mouvement IS NULL),a."IdEntiteFk");
 PERFORM set_config('logistique.stock_initial_article',prior_article,true);
 PERFORM set_config('logistique.stock_initial_mouvement',prior_movement,true);
 RETURN command_id;
END $$;

--
-- Name: FUNCTION fn_materialiser_stock_initial(p_article integer, p_mouvement integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_materialiser_stock_initial(p_article integer, p_mouvement integer) IS 'Stock initial positif matérialisé une seule fois par BE, ligne et mouvement ; type d’entrée actif résolu dans la famille de commande effective de son entreprise. Reprise historique inchangée.';

--
-- Name: fn_montant_avoir_attente(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_montant_avoir_attente(command_id integer) RETURNS numeric
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT COALESCE(sum(round(greatest(COALESCE(r.qty,0)-l."QteRetourAvantFacture"-COALESCE(c.qty,0),0)*l."PUFacture",2)),0)::numeric(12,2)
 FROM logistique."T_Facture" f JOIN logistique."T_FactureLigne" l ON l."ID_FactureFk"=f."ID_Facture"
 LEFT JOIN LATERAL(SELECT sum(d."QteCmdDetail") AS qty FROM logistique."T_RetourBon" b JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=b."ID_CommandeRetourFk" WHERE b."ID_CommandeOrigineFk"=command_id AND d."ID_ArticleFk"=l."ID_ArticleFk") r ON true
 LEFT JOIN LATERAL(SELECT sum(al."Quantite") AS qty FROM logistique."T_Avoir" a JOIN logistique."T_AvoirLigne" al ON al."ID_AvoirFk"=a."ID_Avoir" WHERE a."ID_CommandeFk"=command_id AND al."ID_ArticleFk"=l."ID_ArticleFk") c ON true
 WHERE f."ID_CommandeFk"=command_id
$$;

--
-- Name: FUNCTION fn_montant_avoir_attente(command_id integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_montant_avoir_attente(command_id integer) IS 'Montant exact des retours après facture qui ne sont pas encore couverts par un avoir émis.';

--
-- Name: fn_nature_bon(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_nature_bon(p_type integer) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT logistique.fn_nature_type_bon(g."AbrGenerique") FROM referentiel."T_Generique" g WHERE g."ID_Generique"=p_type
 AND (referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',p_type) OR referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',p_type)) $$;

--
-- Name: FUNCTION fn_nature_bon(p_type integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_nature_bon(p_type integer) IS 'Nature par code Entrée/Sortie/CMD uniquement pour un type déclaré ou déjà utilisé. Retirer une famille du choix courant ne requalifie aucun document historique ; un type inconnu reste refusé.';

--
-- Name: fn_nature_type_bon(text); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_nature_type_bon(p_abbreviation text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$ SELECT CASE WHEN upper(btrim(p_abbreviation))='CMD' THEN 'commande'
 WHEN p_abbreviation ILIKE 'entr%' THEN 'entree'
 WHEN p_abbreviation ILIKE 'sort%' THEN 'sortie' ELSE NULL END $$;

--
-- Name: FUNCTION fn_nature_type_bon(p_abbreviation text); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_nature_type_bon(p_abbreviation text) IS 'Classe une abréviation de type : CMD exact prépare une commande ; entr*/sort* constatent une opération physique. NULL désigne un type inconnu, jamais un bon neutre autorisé.';

--
-- Name: fn_precision_stock_compatible(integer, integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_precision_stock_compatible(p_unite integer, p_decimales integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF p_decimales IS NULL OR p_decimales NOT BETWEEN 0 AND 3 THEN
  RAISE EXCEPTION 'Précision de zéro à trois décimales requise' USING ERRCODE='23514';
 END IF;
 IF EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_UniteFk"=p_unite AND
  (a."QteArticle"<>round(a."QteArticle",p_decimales) OR a."QteMinArticle"<>round(a."QteMinArticle",p_decimales)))
 OR EXISTS(SELECT FROM logistique."T_CommandeDetail" d JOIN logistique."T_Article" a ON a."ID_Article"=d."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND d."QteCmdDetail"<>round(d."QteCmdDetail",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_Mouvement" m JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND m."QteMvt"<>round(m."QteMvt",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
  JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND ml."Quantite"<>round(ml."Quantite",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_InventaireLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND
  (l."QteTheorique"<>round(l."QteTheorique",p_decimales) OR l."QteComptee"<>round(l."QteComptee",p_decimales)))
 OR EXISTS(SELECT FROM logistique."T_FactureLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND
  (l."QteSortie"<>round(l."QteSortie",p_decimales)
   OR l."QteRetourAvantFacture"<>round(l."QteRetourAvantFacture",p_decimales)
   OR l."QteFacturee"<>round(l."QteFacturee",p_decimales)))
 OR EXISTS(SELECT FROM logistique."T_AvoirLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND l."Quantite"<>round(l."Quantite",p_decimales))
 OR EXISTS(SELECT FROM logistique."T_ValorisationOuverture" o JOIN logistique."T_Article" a ON a."ID_Article"=o."ID_ArticleFk"
  WHERE a."ID_UniteFk"=p_unite AND o."QuantiteOuverture"<>round(o."QuantiteOuverture",p_decimales)) THEN
  RAISE EXCEPTION 'La précision est incompatible avec les quantités historiques' USING ERRCODE='23514';
 END IF;
END $$;

--
-- Name: FUNCTION fn_precision_stock_compatible(p_unite integer, p_decimales integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_precision_stock_compatible(p_unite integer, p_decimales integer) IS 'Contrôle sans écriture de la compatibilité d’une précision avec stock, seuils, lignes, mouvements, lots, comptages, instantanés de facture, avoirs et arrêtés de valorisation de l’unité.';

--
-- Name: fn_reference_immobilisation_valide(integer, text, integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_reference_immobilisation_valide(p_id integer, p_famille text, p_entite integer) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT referentiel.fn_valider_reference_champ(CASE WHEN p_famille IN('service-rh','fonction-rh') THEN 'systeme' ELSE 'logistique' END,
 CASE WHEN p_famille IN('service-rh','fonction-rh') THEN 'T_Utilisateurs' ELSE 'T_Immobilisation' END,
 CASE p_famille WHEN 'categories' THEN 'ID_CategorieFk' WHEN 'etats' THEN 'ID_EtatFk' WHEN 'services' THEN 'ID_ServiceFk' WHEN 'service-rh' THEN 'ID_ServiceFk' WHEN 'fonction-rh' THEN 'ID_FonctionFk' WHEN 'devise' THEN 'ID_DeviseFk' END,p_id,p_entite) $$;

--
-- Name: FUNCTION fn_reference_immobilisation_valide(p_id integer, p_famille text, p_entite integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_reference_immobilisation_valide(p_id integer, p_famille text, p_entite integer) IS 'Références du patrimoine et des données professionnelles résolues par le catalogue commun, sans seconde règle de catégorie dans ce domaine.';

--
-- Name: fn_reserver_identite_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_reserver_identite_commande() RETURNS TABLE("ID_Commande" integer, "CodeCmd" character varying)
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE candidate bigint; attempt integer;
BEGIN
 FOR attempt IN 1..1000 LOOP
  SELECT nextval(pg_get_serial_sequence('logistique."T_Commande"','ID_Commande')::regclass) INTO candidate;
  IF candidate IS NULL OR candidate<=0 OR candidate>2147483647 THEN RAISE EXCEPTION 'Séquence de bons hors limites.' USING ERRCODE='22003'; END IF;
  IF NOT logistique.fn_identite_commande_deja_utilisee(candidate::integer) THEN
   RETURN QUERY SELECT candidate::integer,logistique.fn_code_commande(candidate::integer);RETURN;
  END IF;
 END LOOP;
 RAISE EXCEPTION 'La numérotation des bons doit être contrôlée.' USING ERRCODE='23514';
END $$;

--
-- Name: FUNCTION fn_reserver_identite_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_reserver_identite_commande() IS 'Réserve une identité dans la séquence existante puis retourne cmd-ID ; saute les identités déjà utilisées, jamais MAX+1 ni réutilisation après suppression.';

--
-- Name: fn_revision_valorisation(integer, integer, bigint); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_revision_valorisation(p_article integer, p_devise integer, p_version bigint) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT p_version::text||':'||md5(jsonb_build_object(
 'article',(SELECT jsonb_build_object('stock',a."QteArticle",'unite',a."ID_UniteFk",'proprietaire',a."IdEntiteFk") FROM logistique."T_Article" a WHERE a."ID_Article"=p_article),
 'mouvements',(SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m."ID_Mvt"),'[]'::jsonb) FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=p_article AND m."ID_DeviseFk"=p_devise),
 'retours',(SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r."ID_RetourBon"),'[]'::jsonb) FROM logistique."T_RetourBon" r WHERE EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=p_article AND m."ID_DeviseFk"=p_devise AND m."ID_cmdFk" IN (r."ID_CommandeOrigineFk",r."ID_CommandeRetourFk"))),
 'inventaires',(SELECT COALESCE(jsonb_agg(jsonb_build_array(i."ID_InventaireFk",i."ID_CommandeCorrectionFk",i."ID_CommandeAnnulationFk") ORDER BY i."ID_InventaireFk"),'[]'::jsonb) FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article)
 )::text)
$$;

--
-- Name: FUNCTION fn_revision_valorisation(p_article integer, p_devise integer, p_version bigint); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_revision_valorisation(p_article integer, p_devise integer, p_version bigint) IS 'Révision opaque commune à la lecture et à la confirmation : arrêté, stock physique, mouvements et liens de retours/corrections qui déterminent le coût. STABLE conserve le même instantané que les positions affichées ; ne remplace pas les contrôles de droits.';

--
-- Name: fn_verifier_devise(integer); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_verifier_devise(p_id integer) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
BEGIN
 PERFORM 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_Generique"=p_id AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND logistique.fn_code_devise(g."AbrGenerique") ~ '^[A-Z]{3}$'
 AND EXISTS(SELECT FROM referentiel."T_ChampReferentiel" r WHERE r."ColumnName" IN('ID_DeviseFk','IdDeviseFk') AND referentiel.fn_reference_champ_connue(r."SchemaName",r."TableName",r."ColumnName",p_id)) FOR SHARE OF g,c;
 IF NOT FOUND THEN RAISE EXCEPTION 'Une devise active de référence, avec code ISO, est requise.' USING ERRCODE='23514';END IF;
END $_$;

--
-- Name: FUNCTION fn_verifier_devise(p_id integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_verifier_devise(p_id integer) IS 'Contrôle sémantique financier conservé : référence déclarée ou historique, valeur active et code ISO trois lettres. Le scope de la nouvelle affectation relève de la garde physique.';

--
-- Name: fn_verifier_quantite(integer, numeric); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.fn_verifier_quantite(p_unite integer, p_qte numeric) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE d integer;
BEGIN
 IF p_qte IS NULL THEN RETURN;END IF;
 IF p_qte<0 OR p_qte::text IN ('NaN','Infinity','-Infinity') OR p_qte>99999999999.999 OR p_qte<>round(p_qte,3) THEN
  RAISE EXCEPTION 'Quantité hors précision' USING ERRCODE='23514';
 END IF;
 PERFORM 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=p_unite AND (referentiel.fn_reference_champ_connue('logistique','T_Article','ID_UniteFk',p_unite) OR referentiel.fn_reference_champ_connue('logistique','T_PrecisionStock','ID_UniteFk',p_unite)) FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unité de stock requise' USING ERRCODE='23514';END IF;
 SELECT "DecimalesStock" INTO d FROM logistique."V_PrecisionStock" WHERE "ID_UniteFk"=p_unite;
 IF d IS NULL OR p_qte<>round(p_qte,d) THEN
  RAISE EXCEPTION 'Quantité incompatible avec la précision de son unité' USING ERRCODE='23514';
 END IF;
END $$;

--
-- Name: FUNCTION fn_verifier_quantite(p_unite integer, p_qte numeric); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.fn_verifier_quantite(p_unite integer, p_qte numeric) IS 'Contrôle exact des quantités et de la politique de précision ; unités déclarées ou déjà utilisées sans arrondi silencieux, même après changement des choix proposés.';

--
-- Name: proteger_bon_inventaire(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.proteger_bon_inventaire() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE targets integer[]; BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN targets=ARRAY[OLD."ID_Commande"];
 ELSIF TG_TABLE_NAME='T_CommandeDetail' THEN targets=ARRAY[NEW."ID_CmdFk",OLD."ID_CmdFk"];
 ELSIF TG_TABLE_NAME='T_MouvementLot' THEN SELECT array_agg("ID_cmdFk") INTO targets FROM logistique."T_Mouvement" WHERE "ID_Mvt" IN (NEW."ID_MvtFk",OLD."ID_MvtFk");
 ELSE targets=ARRAY[NEW."ID_cmdFk",OLD."ID_cmdFk"];END IF;
 IF EXISTS(SELECT FROM logistique."T_InventaireLigne" l JOIN logistique."T_Inventaire" h ON h."ID_Inventaire"=l."ID_InventaireFk"
  WHERE (l."ID_CommandeCorrectionFk"=ANY(targets) OR l."ID_CommandeAnnulationFk"=ANY(targets)) AND h."Etat" IN ('valide','annule')) THEN
 RAISE EXCEPTION 'Les bons et mouvements de cet inventaire sont conservés' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;

--
-- Name: FUNCTION proteger_bon_inventaire(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.proteger_bon_inventaire() IS 'Préserve les bons originaux et inverses, leurs lignes, mouvements et ventilations de lots.';

--
-- Name: proteger_bon_retour(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.proteger_bon_retour() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE ids integer[]; command_id integer; child boolean; linked boolean; financial text[];
BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN
  SELECT EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeRetourFk"=OLD."ID_Commande"),
         EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeOrigineFk"=OLD."ID_Commande") INTO child,linked;
  IF NOT child AND NOT linked THEN IF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;END IF;
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Un bon lié à un retour ne peut pas être supprimé.' USING ERRCODE='23514';END IF;
  IF to_jsonb(NEW)=to_jsonb(OLD) THEN RETURN NEW;END IF;
  financial=ARRAY['CodeFacture','DateFacture','DateHeureAutoFacture','StatusFacture','ID_ModePaiementFk','ID_ConditionPaiementFk','DateEcheancePaiement','MontantRegleFacture','MontantResteFacture','UrlFacture'];
  IF child OR (to_jsonb(NEW)-financial) IS DISTINCT FROM (to_jsonb(OLD)-financial) THEN
   RAISE EXCEPTION 'Les données de stock d’un bon lié à un retour sont conservées.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 ELSIF TG_TABLE_NAME='T_CommandeDetail' THEN
  ids=ARRAY[CASE WHEN TG_OP<>'INSERT' THEN OLD."ID_CmdFk" END,CASE WHEN TG_OP<>'DELETE' THEN NEW."ID_CmdFk" END];
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN
  ids=ARRAY[CASE WHEN TG_OP<>'INSERT' THEN OLD."ID_cmdFk" END,CASE WHEN TG_OP<>'DELETE' THEN NEW."ID_cmdFk" END];
 ELSE
  SELECT array_agg(DISTINCT "ID_cmdFk") INTO ids FROM logistique."T_Mouvement" WHERE "ID_Mvt"=ANY(ARRAY[CASE WHEN TG_OP<>'INSERT' THEN OLD."ID_MvtFk" END,CASE WHEN TG_OP<>'DELETE' THEN NEW."ID_MvtFk" END]);
 END IF;
 FOR command_id IN SELECT DISTINCT i FROM unnest(ids) AS t(i) WHERE i IS NOT NULL ORDER BY i
 LOOP
  PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=command_id FOR UPDATE;
  IF EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeOrigineFk"=command_id OR "ID_CommandeRetourFk"=command_id) THEN
   RAISE EXCEPTION 'Les lignes, mouvements et lots d’un bon restitué sont conservés.' USING ERRCODE='23514';END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;
END;
$$;

--
-- Name: FUNCTION proteger_bon_retour(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.proteger_bon_retour() IS 'Conserve les données de stock de toute source et contre-document validés. Les seules métadonnées financières de la source restent modifiables pour une facture nette et ses règlements ; le retour reste non facturable.';

--
-- Name: proteger_identite_lot_retour(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.proteger_identite_lot_retour() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF (NEW."NumeroLot",NEW."DatePeremptionLot",NEW."ID_ArticleFk") IS DISTINCT FROM (OLD."NumeroLot",OLD."DatePeremptionLot",OLD."ID_ArticleFk") AND EXISTS(
 SELECT 1 FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
 JOIN logistique."T_RetourBon" r ON r."ID_CommandeOrigineFk"=m."ID_cmdFk" OR r."ID_CommandeRetourFk"=m."ID_cmdFk"
 WHERE ml."ID_LotArticleFk"=OLD."ID_LotArticle") THEN
  RAISE EXCEPTION 'L’identité d’un lot restitué est conservée dans l’historique.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION proteger_identite_lot_retour(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.proteger_identite_lot_retour() IS 'Conserve numéro, péremption et article des lots présents dans un retour historique ; leur archivage reste possible.';

--
-- Name: proteger_valorisation(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.proteger_valorisation() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$ BEGIN
 IF TG_TABLE_NAME='T_ValorisationEvenement' THEN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Journal de valorisation conservé' USING ERRCODE='23514';END IF;RETURN NEW;
 END IF;
 IF current_setting('logistique.allow_valuation_write',true) IS DISTINCT FROM 'on' THEN RAISE EXCEPTION 'Utilisez la procédure de valorisation motivée' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Un arrêté de coût est conservé' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_Article"=NEW."ID_ArticleFk" AND a."IdEntiteFk"=NEW."IdEntiteFk") OR
 NOT EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"=NEW."ID_DeviseFk" AND g."ID_CategorieGeneriqueFk"=42) THEN RAISE EXCEPTION 'Propriété ou devise incohérente' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND (NEW."ID_ArticleFk",NEW."ID_DeviseFk",NEW."IdEntiteFk") IS DISTINCT FROM (OLD."ID_ArticleFk",OLD."ID_DeviseFk",OLD."IdEntiteFk") THEN RAISE EXCEPTION 'Identité de valorisation immuable' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION proteger_valorisation(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.proteger_valorisation() IS 'Protège identité, devise et caractère append-only des preuves ; les arrêtés sont écrits par la procédure motivée.';

--
-- Name: ps_crud_article(integer, integer, integer, integer, numeric, numeric, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_article(IN p_id_article integer, IN p_id_type_article integer, IN p_id_categorie_article integer, IN p_id_unite integer, IN p_old_qte numeric, IN p_new_qte numeric, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_op text;
v_new_qte numeric(14, 3);
BEGIN v_op := upper(trim(p_operation));
v_new_qte := COALESCE(p_new_qte, 0)::numeric(14, 3);
IF v_op IN ('INSERT', 'UPDATE') THEN PERFORM logistique.fn_assert_generique_category(
    p_id_type_article,
    46,
    format('ps_crud_article(%s)', v_op),
    'ID_TypeArticleFk'
);
PERFORM logistique.fn_assert_generique_category(
    p_id_categorie_article,
    40,
    format('ps_crud_article(%s)', v_op),
    'ID_CategorieArticleFk'
);
PERFORM logistique.fn_assert_generique_category(
    p_id_unite,
    34,
    format('ps_crud_article(%s)', v_op),
    'ID_UniteFk'
);
END IF;
IF v_op IN ('INSERT', 'UPDATE')
AND v_new_qte < 0 THEN RAISE EXCEPTION 'ps_crud_article(%) : QteArticle negative interdite pour ID_Article=%.',
v_op,
p_id_article;
END IF;
END;
$$;

--
-- Name: PROCEDURE ps_crud_article(IN p_id_article integer, IN p_id_type_article integer, IN p_id_categorie_article integer, IN p_id_unite integer, IN p_old_qte numeric, IN p_new_qte numeric, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_article(IN p_id_article integer, IN p_id_type_article integer, IN p_id_categorie_article integer, IN p_id_unite integer, IN p_old_qte numeric, IN p_new_qte numeric, IN p_operation character varying) IS 'Contrôle les catégories article 46/type, 40/catégorie et 34/unité et refuse un stock négatif pour INSERT/UPDATE. Ne produit pas elle-même de mouvement ; les triggers article assurent l’historisation.';

--
-- Name: ps_crud_commande(integer, integer, integer, integer, integer, integer, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE op text:=upper(btrim(p_operation)); old_abr text; new_abr text; old_sign integer; new_sign integer; item record;
 prior_skip text:=coalesce(current_setting('logistique.skip_article_report_mvt',true),'off');
 prior_write text:=coalesce(current_setting('logistique.allow_t_mouvement_write',true),'off');
BEGIN
 IF op='DELETE' THEN RETURN; END IF;
 IF op NOT IN ('INSERT','UPDATE') OR op IS NULL THEN RAISE EXCEPTION 'Opération de commande inconnue.' USING ERRCODE='23514'; END IF;
 PERFORM logistique.fn_assert_generique_category(p_new_id_type_cmd,64,'Commande','ID_TypeCmdFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_statut_cmd,28,'Commande','ID_StatutCmdFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_condition_paiement,37,'Commande','ID_ConditionPaiementFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_mode_paiement,36,'Commande','ID_ModePaiementFk');
 SELECT "AbrGenerique" INTO new_abr FROM referentiel."T_Generique" WHERE "ID_Generique"=p_new_id_type_cmd AND referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',"ID_Generique");
 new_sign:=CASE WHEN new_abr ILIKE 'entr%' THEN 1 WHEN new_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
 IF logistique.fn_nature_bon(p_new_id_type_cmd) IS NULL THEN RAISE EXCEPTION 'Type de bon inconnu.' USING ERRCODE='23514'; END IF;
 IF op='INSERT' OR p_old_id_type_cmd IS NOT DISTINCT FROM p_new_id_type_cmd THEN RETURN; END IF;
 IF logistique.fn_nature_bon(p_old_id_type_cmd)='commande' OR logistique.fn_nature_bon(p_new_id_type_cmd)='commande' THEN RAISE EXCEPTION 'Un bon de commande ne se convertit pas en mouvement physique ; créez un BE ou BS distinct.' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande) THEN RETURN; END IF;
 SELECT "AbrGenerique" INTO old_abr FROM referentiel."T_Generique" WHERE "ID_Generique"=p_old_id_type_cmd AND referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',"ID_Generique");
 old_sign:=CASE WHEN old_abr ILIKE 'entr%' THEN 1 WHEN old_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
 IF old_sign=0 THEN RAISE EXCEPTION 'Ancien type inconnu : changement de sens impossible.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article" IN
 (SELECT "ID_ArticleFk" FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande)
 ORDER BY a."ID_Article" FOR NO KEY UPDATE;
 PERFORM set_config('logistique.skip_article_report_mvt','on',true);
 FOR item IN SELECT "ID_ArticleFk" id,"QteCmdDetail"*(new_sign-old_sign) delta FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande ORDER BY "ID_ArticleFk"
 LOOP IF item.delta<>0 THEN CALL logistique.ps_update_qte_article(item.id,abs(item.delta),CASE WHEN item.delta>0 THEN '+' ELSE '-' END); END IF; END LOOP;
 PERFORM set_config('logistique.skip_article_report_mvt',prior_skip,true);
 PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
 UPDATE logistique."T_Mouvement" SET "ID_TypeMvtFk"=p_new_id_type_cmd WHERE "ID_cmdFk"=p_id_commande;
 PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
END;
$$;

--
-- Name: PROCEDURE ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying) IS 'Procédure de sens des bons conservée ; familles déléguées au catalogue sans modifier le sens, les codes, les lignes ou les mouvements historiques.';

--
-- Name: ps_crud_commandedetail(integer, integer, numeric, numeric, integer, integer, numeric, numeric, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
 op text := upper(btrim(p_operation)); old_type integer; new_type integer;
 old_abr text; new_abr text; old_sign integer := 0; new_sign integer := 0;
 item record; touched integer;
 prior_skip text := coalesce(current_setting('logistique.skip_article_report_mvt',true),'off');
 prior_write text := coalesce(current_setting('logistique.allow_t_mouvement_write',true),'off');
BEGIN

 IF op='INSERT' AND EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk AND c."OrigineBon" IN ('stock_initial','reprise_mouvement')) THEN
  IF current_setting('logistique.stock_initial_article',true) IS DISTINCT FROM p_new_article_fk::text THEN RAISE EXCEPTION 'Creation de stock initial hors procedure.' USING ERRCODE='23514';END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO new_type,new_abr FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" WHERE c."ID_Commande"=p_new_cmd_fk AND c."ID_ArticleInitialFk"=p_new_article_fk;
  IF new_type IS NULL OR p_new_qte<=0 OR p_new_pu<0 THEN RAISE EXCEPTION 'Stock initial invalide.' USING ERRCODE='23514';END IF;
  PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
  IF nullif(current_setting('logistique.stock_initial_mouvement',true),'') IS NOT NULL THEN
   UPDATE logistique."T_Mouvement" SET "ID_cmdFk"=p_new_cmd_fk WHERE "ID_Mvt"=current_setting('logistique.stock_initial_mouvement')::integer AND "ID_cmdFk" IS NULL AND "ID_ArticleFk"=p_new_article_fk AND "ID_TypeMvtFk"=new_type AND "QteMvt"=p_new_qte AND "PUMvt" IS NOT DISTINCT FROM p_new_pu;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'Mouvement historique modifie ou deja rattache.' USING ERRCODE='23514';END IF;
  ELSE
   INSERT INTO logistique."T_Mouvement"("ID_TypeMvtFk","ID_ArticleFk","ID_cmdFk","DateHeureAutoMvt","DateMvt","QteMvt","PUMvt") SELECT new_type,p_new_article_fk,p_new_cmd_fk,clock_timestamp(),c."DateCmd",p_new_qte,p_new_pu FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk;
  END IF;
  PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
  RETURN;
 END IF;

 IF op NOT IN ('INSERT','UPDATE','DELETE') OR op IS NULL THEN
  RAISE EXCEPTION 'Opération de ligne inconnue.' USING ERRCODE='23514';
 END IF;
 -- Le cas neutre est explicite ; l'absence de mouvement ne prouve jamais un CMD.
 IF op IN ('INSERT','UPDATE') AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk))='commande' THEN
  IF p_new_qte IS NULL OR p_new_qte<=0 OR p_new_pu IS NULL OR p_new_pu<0 THEN RAISE EXCEPTION 'Quantité positive et prix convenu non négatif requis.' USING ERRCODE='23514';END IF;
  IF op='UPDATE' AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_old_cmd_fk)) IS DISTINCT FROM 'commande' THEN RAISE EXCEPTION 'Déplacement entre commande et opération physique interdit.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=ANY(ARRAY[p_old_cmd_fk,p_new_cmd_fk])) THEN RAISE EXCEPTION 'Un bon de commande ne doit avoir aucun mouvement.' USING ERRCODE='23514';END IF;
  PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article"=ANY(ARRAY[p_old_article_fk,p_new_article_fk]) ORDER BY a."ID_Article" FOR NO KEY UPDATE;
  IF NOT EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_Article"=p_new_article_fk AND a."ValideArticle" IS TRUE) THEN RAISE EXCEPTION 'Article absent ou désactivé.' USING ERRCODE='23514';END IF;
  RETURN;
 END IF;
 IF op IN ('UPDATE','DELETE') AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_old_cmd_fk))='commande' THEN
  IF op='UPDATE' THEN RAISE EXCEPTION 'Déplacement entre commande et opération physique interdit.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=p_old_cmd_fk) THEN RAISE EXCEPTION 'Un bon de commande ne doit avoir aucun mouvement.' USING ERRCODE='23514';END IF;
  PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article"=p_old_article_fk FOR NO KEY UPDATE;
  RETURN;
 END IF;
 IF op IN ('UPDATE','DELETE') THEN
  IF p_old_qte IS NULL OR p_old_qte<=0 THEN
   RAISE EXCEPTION 'Ancienne quantité de ligne invalide.' USING ERRCODE='23514';
  END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO old_type,old_abr
  FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',g."ID_Generique"))
  WHERE c."ID_Commande"=p_old_cmd_fk;
  IF NOT FOUND THEN
   SELECT m."ID_TypeMvtFk",g."AbrGenerique" INTO old_type,old_abr
   FROM logistique."T_Mouvement" m JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeMvtFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',g."ID_Generique"))
   WHERE m."ID_cmdFk"=p_old_cmd_fk AND m."ID_ArticleFk"=p_old_article_fk;
  END IF;
  old_sign := CASE WHEN old_abr ILIKE 'entr%' THEN 1 WHEN old_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF old_sign=0 THEN RAISE EXCEPTION 'Ancien type de mouvement inconnu.' USING ERRCODE='23514'; END IF;
 END IF;
 IF op IN ('INSERT','UPDATE') THEN
  IF p_new_qte IS NULL OR p_new_qte<=0 OR p_new_pu<0 THEN
   RAISE EXCEPTION 'Quantité entière positive et prix non négatif requis.' USING ERRCODE='23514';
  END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO new_type,new_abr
  FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',g."ID_Generique"))
  WHERE c."ID_Commande"=p_new_cmd_fk;
  new_sign := CASE WHEN new_abr ILIKE 'entr%' THEN 1 WHEN new_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF new_sign=0 THEN RAISE EXCEPTION 'Nouveau type de mouvement inconnu.' USING ERRCODE='23514'; END IF;
 END IF;
 -- Une quantité modifiée applique le delta net : aucun stock négatif intermédiaire artificiel.
 PERFORM 1 FROM logistique."T_Article" a
 WHERE a."ID_Article"=ANY(ARRAY[p_old_article_fk,p_new_article_fk])
 ORDER BY a."ID_Article" FOR NO KEY UPDATE;
 PERFORM set_config('logistique.skip_article_report_mvt','on',true);
 FOR item IN
  SELECT id,sum(delta) delta FROM (VALUES
   (p_old_article_fk,CASE WHEN op IN ('UPDATE','DELETE') THEN -old_sign*p_old_qte ELSE 0 END),
   (p_new_article_fk,CASE WHEN op IN ('INSERT','UPDATE') THEN new_sign*p_new_qte ELSE 0 END)
  ) x(id,delta) WHERE id IS NOT NULL GROUP BY id ORDER BY id
 LOOP
  IF item.delta<>0 THEN
   CALL logistique.ps_update_qte_article(item.id,abs(item.delta),CASE WHEN item.delta>0 THEN '+' ELSE '-' END);
  END IF;
 END LOOP;
 PERFORM set_config('logistique.skip_article_report_mvt',prior_skip,true);
 PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
 IF op='UPDATE' AND p_old_cmd_fk=p_new_cmd_fk AND p_old_article_fk=p_new_article_fk THEN
  IF p_old_qte IS DISTINCT FROM p_new_qte OR p_old_pu IS DISTINCT FROM p_new_pu THEN
   UPDATE logistique."T_Mouvement" SET "QteMvt"=p_new_qte,"PUMvt"=coalesce(p_new_pu,0),"ID_TypeMvtFk"=new_type
   WHERE "ID_cmdFk"=p_old_cmd_fk AND "ID_ArticleFk"=p_old_article_fk;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'La ligne doit posséder exactement un mouvement source.' USING ERRCODE='23514'; END IF;
  END IF;
 ELSE
  IF op IN ('UPDATE','DELETE') THEN
   DELETE FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=p_old_cmd_fk AND "ID_ArticleFk"=p_old_article_fk;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'Mouvement source absent ou dupliqué.' USING ERRCODE='23514'; END IF;
  END IF;
  IF op IN ('INSERT','UPDATE') THEN
   INSERT INTO logistique."T_Mouvement"("ID_TypeMvtFk","ID_ArticleFk","ID_cmdFk","DateHeureAutoMvt","DateMvt","QteMvt","PUMvt")
   VALUES(new_type,p_new_article_fk,p_new_cmd_fk,now(),now(),p_new_qte,coalesce(p_new_pu,0));
  END IF;
 END IF;
 PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
END;
$$;

--
-- Name: PROCEDURE ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying) IS 'Lignes CMD : quantité et prix convenu valides, aucun stock, mouvement, lot ni coût ; les totaux restent calculés par les triggers de transition. Préserve les flux physiques et le stock initial sans double mouvement.';

--
-- Name: ps_crud_reglement(integer, integer, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_crud_reglement(IN p_id_reglement integer, IN p_id_mode_reglement integer, IN p_operation character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_op text;
BEGIN v_op := upper(trim(p_operation));
IF v_op IN ('INSERT', 'UPDATE') THEN PERFORM logistique.fn_assert_generique_category(
    p_id_mode_reglement,
    36,
    format('ps_crud_reglement(%s)', v_op),
    'ID_ModeReglementFk'
);
END IF;
END;
$$;

--
-- Name: PROCEDURE ps_crud_reglement(IN p_id_reglement integer, IN p_id_mode_reglement integer, IN p_operation character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_crud_reglement(IN p_id_reglement integer, IN p_id_mode_reglement integer, IN p_operation character varying) IS 'Contrôle l’appartenance du mode de règlement à la catégorie 36 pour INSERT/UPDATE ; ne recalcule pas les règlements ni le reste de facture.';

--
-- Name: ps_update_qte_article(integer, numeric, character varying); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_update_qte_article(IN p_id_article_fk integer, IN p_qte numeric, IN p_operateur character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE v_delta numeric;
v_operateur varchar(1);
v_new_stock numeric;
BEGIN IF p_qte IS NULL
OR p_qte <= 0 THEN RAISE EXCEPTION 'ps_update_qte_article : la quantite doit etre strictement positive (recu=%).',
p_qte;
END IF;
v_operateur := trim(p_operateur);
IF v_operateur NOT IN ('+', '-') THEN RAISE EXCEPTION 'ps_update_qte_article : operateur invalide (recu=%). Utiliser seulement + ou -.',
p_operateur;
END IF;
v_delta := CASE
    WHEN v_operateur = '+' THEN p_qte
    ELSE - p_qte
END;
UPDATE logistique."T_Article"
SET "QteArticle" = COALESCE("QteArticle", 0)::numeric + v_delta
WHERE "ID_Article" = p_id_article_fk
RETURNING "QteArticle" INTO v_new_stock;
IF NOT FOUND THEN RAISE EXCEPTION 'ps_update_qte_article : article % introuvable.',
p_id_article_fk;
END IF;
IF v_new_stock < 0 THEN RAISE EXCEPTION 'ps_update_qte_article : la mise a jour ferait passer le stock de l''article % en negatif (stock final=%).',
p_id_article_fk,
v_new_stock;
END IF;
END;
$$;

--
-- Name: PROCEDURE ps_update_qte_article(IN p_id_article_fk integer, IN p_qte numeric, IN p_operateur character varying); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_update_qte_article(IN p_id_article_fk integer, IN p_qte numeric, IN p_operateur character varying) IS 'Ajoute ou retranche une quantité strictement positive au stock de l’article selon l’opérateur + ou -. Refuse l’article absent, l’opérateur invalide et le stock final négatif ; l’écriture participe à la transaction appelante.';

--
-- Name: ps_update_totaux_commande(integer); Type: PROCEDURE; Schema: logistique; Owner: -
--

CREATE PROCEDURE logistique.ps_update_totaux_commande(IN p_id_commande integer)
    LANGUAGE plpgsql
    AS $$
DECLARE v_montant numeric(12,2);
BEGIN
 PERFORM 1 FROM logistique."T_Commande"
 WHERE "ID_Commande" = p_id_commande FOR NO KEY UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 SELECT COALESCE(sum(round(COALESCE(d."QteCmdDetail",0) * COALESCE(d."PUCmdDetail",0),2)),0)
 INTO v_montant FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk" = p_id_commande;
 UPDATE logistique."T_Commande"
 SET "MontantHT" = v_montant, "MontantTTC" = v_montant
 WHERE "ID_Commande" = p_id_commande
   AND ("MontantHT" IS DISTINCT FROM v_montant OR "MontantTTC" IS DISTINCT FROM v_montant);
END;
$$;

--
-- Name: PROCEDURE ps_update_totaux_commande(IN p_id_commande integer); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON PROCEDURE logistique.ps_update_totaux_commande(IN p_id_commande integer) IS 'Somme des montants quantité exacte fois prix, arrondis par ligne à deux décimales ; pas de taxe ni conversion implicite.';

--
-- Name: tr_audit_numero_document(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_audit_numero_document() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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

--
-- Name: FUNCTION tr_audit_numero_document(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_audit_numero_document() IS 'Conserve identité et numéro émis avec l’entreprise propriétaire durable du document, indépendamment de l’entreprise de son créateur. Les journaux antérieurs restent inchangés.';

--
-- Name: tr_avoir_immuable(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_avoir_immuable() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE f logistique."T_Facture";
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Un avoir émis est conservé.' USING ERRCODE='23514'; END IF;
 SELECT * INTO f FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_FactureFk";
 IF NOT FOUND OR NEW."ID_CommandeFk"<>f."ID_CommandeFk" OR NEW."IdEntiteFk"<>f."IdEntiteFk" OR NEW."ID_DeviseFk"<>f."ID_DeviseFk" OR NEW."DeviseCode"<>f."DeviseCode" THEN RAISE EXCEPTION 'Avoir incompatible avec sa facture.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=f."ID_CommandeFk" FOR UPDATE;
 IF NEW."DateAvoir"<f."DateFacture" THEN RAISE EXCEPTION 'La date d’avoir précède la facture.' USING ERRCODE='23514'; END IF;
 NEW."CodeAvoir"='avr-'||NEW."ID_Avoir"::text;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_avoir_immuable(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_avoir_immuable() IS 'Valide entreprise, devise et facture, attribue avr-ID et conserve l’avoir émis.';

--
-- Name: tr_avoir_ligne_immuable(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_avoir_ligne_immuable() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE a logistique."T_Avoir"; f logistique."T_FactureLigne"; available numeric; credited numeric;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Les lignes d’avoir sont conservées.' USING ERRCODE='23514'; END IF;
 SELECT * INTO a FROM logistique."T_Avoir" WHERE "ID_Avoir"=NEW."ID_AvoirFk";
 IF a."TransactionCreation"<>txid_current() THEN RAISE EXCEPTION 'Un avoir émis ne reçoit pas de nouvelle ligne.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=a."ID_CommandeFk" FOR UPDATE;
 SELECT * INTO f FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=a."ID_FactureFk" AND "ID_ArticleFk"=NEW."ID_ArticleFk";
 IF NOT FOUND OR NEW."PUAvoir"<>f."PUFacture" OR NEW."NomArticle"<>f."NomArticle" OR NEW."Unite" IS DISTINCT FROM f."Unite" THEN RAISE EXCEPTION 'La ligne d’avoir reprend l’instantané facturé.' USING ERRCODE='23514'; END IF;
 SELECT COALESCE(sum(d."QteCmdDetail"),0)-f."QteRetourAvantFacture" INTO available FROM logistique."T_RetourBon" r JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=r."ID_CommandeRetourFk" WHERE r."ID_CommandeOrigineFk"=a."ID_CommandeFk" AND d."ID_ArticleFk"=NEW."ID_ArticleFk";
 SELECT COALESCE(sum(l."Quantite"),0) INTO credited FROM logistique."T_AvoirLigne" l JOIN logistique."T_Avoir" n ON n."ID_Avoir"=l."ID_AvoirFk" WHERE n."ID_FactureFk"=a."ID_FactureFk" AND l."ID_ArticleFk"=NEW."ID_ArticleFk";
 IF NEW."Quantite"+credited>available OR NEW."Quantite"+credited>f."QteFacturee" THEN RAISE EXCEPTION 'Quantité retournée déjà créditée ou insuffisante.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_avoir_ligne_immuable(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_avoir_ligne_immuable() IS 'Empêche la double créditation des retours après facturation et conserve le prix facturé.';

--
-- Name: tr_avoir_total(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_avoir_total() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE key_id bigint; total numeric; expected numeric;
BEGIN
 key_id=COALESCE((to_jsonb(NEW)->>'ID_Avoir')::bigint,(to_jsonb(NEW)->>'ID_AvoirFk')::bigint);
 SELECT "MontantTTC" INTO expected FROM logistique."T_Avoir" WHERE "ID_Avoir"=key_id;
 SELECT sum("MontantLigne") INTO total FROM logistique."T_AvoirLigne" WHERE "ID_AvoirFk"=key_id;
 IF total IS NULL OR total<>expected THEN RAISE EXCEPTION 'Le montant de l’avoir doit correspondre à ses lignes.' USING ERRCODE='23514'; END IF;
 RETURN NULL;
END $$;

--
-- Name: FUNCTION tr_avoir_total(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_avoir_total() IS 'Vérifie au commit que les lignes couvrent exactement le montant émis.';

--
-- Name: tr_bon_code_historique_immuable(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_bon_code_historique_immuable() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN RAISE EXCEPTION 'Journal de nomenclature conservé ; alimentation réservée aux migrations contrôlées.' USING ERRCODE='23514';END $$;

--
-- Name: FUNCTION tr_bon_code_historique_immuable(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_bon_code_historique_immuable() IS 'Ferme le journal après la reprise06 : aucune insertion, modification ni suppression applicative ; une évolution ultérieure exige sa propre migration contrôlée.';

--
-- Name: tr_bon_initial_protection(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_bon_initial_protection() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE parent record; armed text:=current_setting('logistique.stock_initial_article',true);
BEGIN
 IF TG_TABLE_NAME IN ('T_Facture','T_RetourBon') THEN
  IF EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."OrigineBon" IS NOT NULL AND c."ID_Commande"=CASE WHEN TG_TABLE_NAME='T_Facture' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::integer ELSE (to_jsonb(NEW)->>'ID_CommandeOrigineFk')::integer END) THEN RAISE EXCEPTION 'Un stock initial ou une reprise ne constitue pas une vente ou un retour commercial.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 ELSIF TG_TABLE_NAME='T_Article' THEN
  IF TG_OP='UPDATE' AND ((NEW."CreationRequestId",NEW."CreationPayloadHash") IS DISTINCT FROM (OLD."CreationRequestId",OLD."CreationPayloadHash") OR OLD."CreationRequestId" IS NOT NULL AND NEW."ID_UserFK" IS DISTINCT FROM OLD."ID_UserFK") THEN RAISE EXCEPTION 'Identifiant et auteur de creation immuables.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 ELSIF TG_TABLE_NAME='T_Commande' THEN
  IF TG_OP='INSERT' THEN
   IF NEW."OrigineBon" IS NOT NULL AND (armed IS DISTINCT FROM NEW."ID_ArticleInitialFk"::text OR NOT EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_Article"=NEW."ID_ArticleInitialFk" AND a."IdEntiteFk"=NEW."IdEntiteFk")) THEN RAISE EXCEPTION 'Origine du stock reservee a la procedure.' USING ERRCODE='23514';END IF;
   RETURN NEW;
  END IF;
  IF TG_OP='UPDATE' AND (NEW."OrigineBon",NEW."ID_ArticleInitialFk") IS DISTINCT FROM (OLD."OrigineBon",OLD."ID_ArticleInitialFk") THEN RAISE EXCEPTION 'Origine du bon immuable.' USING ERRCODE='23514';END IF;
  IF OLD."OrigineBon" IS NOT NULL AND armed IS DISTINCT FROM OLD."ID_ArticleInitialFk"::text THEN RAISE EXCEPTION 'Le bon de stock initial est conserve; utilisez un bon correcteur.' USING ERRCODE='23514';END IF;
 ELSE
  SELECT * INTO parent FROM logistique."T_Commande" WHERE "ID_Commande"=CASE WHEN TG_OP='DELETE' THEN OLD."ID_CmdFk" ELSE NEW."ID_CmdFk" END;
  IF parent."OrigineBon" IS NOT NULL AND (armed IS DISTINCT FROM parent."ID_ArticleInitialFk"::text OR TG_OP<>'INSERT' OR NEW."ID_ArticleFk"<>parent."ID_ArticleInitialFk") THEN RAISE EXCEPTION 'La ligne de stock initial est conservee; utilisez un bon correcteur.' USING ERRCODE='23514';END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_bon_initial_protection(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_bon_initial_protection() IS 'Conserve demandes de creation et bons techniques initiaux; interdit suppression, facturation, restitution et modification silencieuse de leurs lignes.';

--
-- Name: tr_commande_sans_stock(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_commande_sans_stock() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE nature text;
BEGIN
 IF TG_OP='DELETE' THEN
  IF logistique.fn_nature_bon(OLD."ID_TypeCmdFk")='commande' AND EXISTS(SELECT FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk"=OLD."ID_Commande") THEN
   RAISE EXCEPTION 'Retirez les articles du bon de commande avant sa suppression.' USING ERRCODE='23514';
  END IF;
  RETURN OLD;
 END IF;
 nature:=logistique.fn_nature_bon(NEW."ID_TypeCmdFk");
 IF nature IS NULL THEN RAISE EXCEPTION 'Type de bon inconnu ; choisissez un type du référentiel.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."ID_TypeCmdFk" IS DISTINCT FROM OLD."ID_TypeCmdFk" AND (nature='commande' OR logistique.fn_nature_bon(OLD."ID_TypeCmdFk")='commande') THEN
  RAISE EXCEPTION 'Nature CMD immuable ; créez un BE ou BS distinct.' USING ERRCODE='23514';
 END IF;
 IF nature='commande' AND (NEW."OrigineBon" IS NOT NULL OR NEW."DateFacture" IS NOT NULL OR NEW."DateHeureAutoFacture" IS NOT NULL
  OR nullif(btrim(NEW."CodeFacture"),'') IS NOT NULL OR nullif(btrim(NEW."UrlFacture"),'') IS NOT NULL OR nullif(btrim(NEW."UrlBL"),'') IS NOT NULL
  OR nullif(btrim(NEW."StatusFacture"),'') IS NOT NULL OR NEW."ValideRemiseFacture" IS TRUE
  OR coalesce(NEW."MontantRegleFacture",0)<>0 OR coalesce(NEW."MontantResteFacture",0)<>0) THEN
  RAISE EXCEPTION 'Une commande prépare des articles sans facture, règlement, livraison physique ni mouvement.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_commande_sans_stock(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_commande_sans_stock() IS 'Garde SQL du bon : refuse les types inconnus, la conversion CMD/physique et la facturation/livraison de CMD. Pour supprimer un CMD, retirer ses lignes préalablement afin de conserver une classification explicite.';

--
-- Name: tr_crud_article_after(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_article_after() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF coalesce(current_setting('logistique.skip_article_report_mvt',true),'off')='on' THEN RETURN NEW;END IF;
 IF TG_OP='INSERT' THEN
  IF coalesce(NEW."QteArticle",0)>0 THEN PERFORM logistique.fn_materialiser_stock_initial(NEW."ID_Article");END IF;
 ELSIF NEW."QteArticle" IS DISTINCT FROM OLD."QteArticle" THEN RAISE EXCEPTION 'Utilisez un bon de stock motive pour modifier les quantites.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_crud_article_after(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_article_after() IS 'Apres creation avec quantite positive, materialise le stock initial par un bon entree et sa ligne; zero ne cree rien. Les modifications descriptives ne recreent rien; les ajustements directs sont refuses hors flux de lignes.';

--
-- Name: tr_crud_article_before(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_article_before() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_new_qte numeric(14, 3);
BEGIN IF TG_OP = 'INSERT' THEN v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(14, 3);
NEW."QteArticle" := v_new_qte;
CALL logistique.ps_crud_article(
    NEW."ID_Article",
    NEW."ID_TypeArticleFk",
    NEW."ID_CategorieArticleFk",
    NEW."ID_UniteFk",
    NULL,
    v_new_qte,
    'INSERT'
);
RETURN NEW;
END IF;
IF TG_OP = 'UPDATE' THEN NEW."QteArticle" := COALESCE(NEW."QteArticle", 0)::numeric(14, 3);
CALL logistique.ps_crud_article(
    NEW."ID_Article",
    NEW."ID_TypeArticleFk",
    NEW."ID_CategorieArticleFk",
    NEW."ID_UniteFk",
    COALESCE(OLD."QteArticle", 0)::numeric(14, 3),
    NEW."QteArticle",
    'UPDATE'
);
RETURN NEW;
END IF;
IF TG_OP = 'DELETE' THEN IF EXISTS (
    SELECT 1
    FROM logistique."T_CommandeDetail" cd
    WHERE cd."ID_ArticleFk" = OLD."ID_Article"
) THEN RAISE EXCEPTION 'tr_crud_article(DELETE) : suppression interdite, article % lie a T_CommandeDetail.',
OLD."ID_Article";
END IF;
IF EXISTS (
    SELECT 1
    FROM logistique."T_Mouvement" m
    WHERE m."ID_ArticleFk" = OLD."ID_Article"
) THEN RAISE EXCEPTION 'tr_crud_article(DELETE) : suppression interdite, article % lie a T_Mouvement.',
OLD."ID_Article";
END IF;
RETURN OLD;
END IF;
RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_crud_article_before(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_article_before() IS 'Avant INSERT/UPDATE, normalise la quantité absente à zéro et appelle ps_crud_article. Avant DELETE, bloque la suppression d’un article lié à une ligne ou un mouvement.';

--
-- Name: tr_crud_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_commande() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF TG_OP = 'INSERT' THEN CALL logistique.ps_crud_commande(
        NEW."ID_Commande",
        NULL,
        NEW."ID_TypeCmdFk",
        NEW."ID_StatutCmdFk",
        NEW."ID_ConditionPaiementFk",
        NEW."ID_ModePaiementFk",
        'INSERT'
    );
RETURN NEW;
END IF;
IF TG_OP = 'UPDATE' THEN CALL logistique.ps_crud_commande(
    NEW."ID_Commande",
    OLD."ID_TypeCmdFk",
    NEW."ID_TypeCmdFk",
    NEW."ID_StatutCmdFk",
    NEW."ID_ConditionPaiementFk",
    NEW."ID_ModePaiementFk",
    'UPDATE'
);
RETURN NEW;
END IF;
RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_crud_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_commande() IS 'Fonction de trigger AFTER INSERT/UPDATE transmettant anciens/nouveaux types et références à ps_crud_commande pour validation et réalignement des effets de stock.';

--
-- Name: tr_crud_commandedetail(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_commandedetail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF TG_OP = 'INSERT' THEN CALL logistique.ps_crud_commandeDetail(
        NULL,
        NULL,
        NULL,
        NULL,
        NEW."ID_CmdFk",
        NEW."ID_ArticleFk",
        NEW."QteCmdDetail",
        NEW."PUCmdDetail",
        'INSERT'
    );
RETURN NEW;
END IF;
IF TG_OP = 'UPDATE' THEN CALL logistique.ps_crud_commandeDetail(
    OLD."ID_CmdFk",
    OLD."ID_ArticleFk",
    OLD."QteCmdDetail",
    OLD."PUCmdDetail",
    NEW."ID_CmdFk",
    NEW."ID_ArticleFk",
    NEW."QteCmdDetail",
    NEW."PUCmdDetail",
    'UPDATE'
);
RETURN NEW;
END IF;
IF TG_OP = 'DELETE' THEN CALL logistique.ps_crud_commandeDetail(
    OLD."ID_CmdFk",
    OLD."ID_ArticleFk",
    OLD."QteCmdDetail",
    OLD."PUCmdDetail",
    NULL,
    NULL,
    NULL,
    NULL,
    'DELETE'
);
RETURN OLD;
END IF;
RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_crud_commandedetail(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_commandedetail() IS 'Fonction commune des triggers de ligne : transmet OLD/NEW à ps_crud_commandedetail. Raccordée après INSERT/UPDATE et avant DELETE pour annuler l’ancien effet avant disparition de la ligne.';

--
-- Name: tr_crud_reglement(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_crud_reglement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF TG_OP IN ('INSERT', 'UPDATE') THEN CALL logistique.ps_crud_reglement(
        NEW."ID_Reglement",
        NEW."ID_ModeReglementFk",
        TG_OP
    );
END IF;
IF TG_OP = 'DELETE' THEN RETURN OLD;
END IF;
RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_crud_reglement(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_crud_reglement() IS 'Fonction de trigger BEFORE INSERT/UPDATE validant le mode via ps_crud_reglement ; renvoie la ligne sans mise à jour des montants de facture.';

--
-- Name: tr_delete_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_delete_commande() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 CALL logistique.ps_crud_commande(OLD."ID_Commande",OLD."ID_TypeCmdFk",NULL,NULL,NULL,NULL,'DELETE');
 RETURN OLD;
END;$$;

--
-- Name: FUNCTION tr_delete_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_delete_commande() IS 'Compatibilité de la fonction historique non raccordée : utilise la signature courante à sept paramètres. La cascade des lignes assure les effets stock.';

--
-- Name: tr_destination_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_destination_commande() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF NEW."ID_DestinationFk" IS NULL OR (TG_OP='UPDATE' AND NEW."ID_DestinationFk" IS NOT DISTINCT FROM OLD."ID_DestinationFk") THEN RETURN NEW;END IF;
 PERFORM 1 FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=NEW."ID_DestinationFk" FOR KEY SHARE;
 IF NOT EXISTS(SELECT 1 FROM geolocalisation."V_DestinationLogistique" d WHERE d.id=NEW."ID_DestinationFk" AND d."EstCoherente") THEN RAISE EXCEPTION 'Destination géographique absente ou hiérarchie incohérente.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_destination_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_destination_commande() IS 'Vérifie le lieu choisi et la cohérence de sa hiérarchie ; conserve les anciennes références inchangées.';

--
-- Name: tr_devise_article(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_devise_article() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 IF TG_OP='UPDATE' AND NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" AND (
  EXISTS (SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_ArticleFk"=OLD."ID_Article")
  OR EXISTS (SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=OLD."ID_Article")
 ) THEN RAISE EXCEPTION 'La devise d’un article déjà utilisé ne peut plus être changée.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_devise_article(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_devise_article() IS 'Valide la devise du catalogue et interdit sa réinterprétation après usage, sans écrire de stock.';

--
-- Name: tr_devise_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_devise_commande() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 IF TG_OP='UPDATE' AND NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" AND (
  EXISTS (SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=OLD."ID_Commande")
  OR EXISTS (SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=OLD."ID_Commande")
  OR EXISTS (SELECT 1 FROM logistique."T_Reglements" WHERE "CodeFactureFk"=OLD."CodeFacture")
 ) THEN RAISE EXCEPTION 'La devise d’un bon comportant des lignes ou des flux ne peut plus être changée.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_devise_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_devise_commande() IS 'Verrouille la devise du bon et de sa facture dès usage ; les prix des lignes sont exprimés dans cette devise sans conversion automatique.';

--
-- Name: tr_devise_mouvement(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_devise_mouvement() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE devise_source integer;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" THEN
   RAISE EXCEPTION 'La devise historique d’un mouvement est immuable.' USING ERRCODE='23514';
  END IF;
  -- ON DELETE SET NULL du bon ne doit jamais réinterpréter l’instantané.
  IF NEW."ID_cmdFk" IS NULL AND OLD."ID_cmdFk" IS NOT NULL THEN RETURN NEW; END IF;
 END IF;
 IF NEW."ID_cmdFk" IS NOT NULL THEN
  SELECT "ID_DeviseFk" INTO devise_source FROM logistique."T_Commande"
   WHERE "ID_Commande"=NEW."ID_cmdFk" FOR NO KEY UPDATE;
 ELSE
  SELECT "ID_DeviseFk" INTO devise_source FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";
 END IF;
 IF devise_source IS NULL THEN RAISE EXCEPTION 'Source de devise du mouvement introuvable.' USING ERRCODE='23503'; END IF;
 IF TG_OP='INSERT' AND NEW."ID_DeviseFk" IS NULL THEN NEW."ID_DeviseFk"=devise_source; END IF;
 IF NEW."ID_DeviseFk" IS DISTINCT FROM devise_source THEN
  RAISE EXCEPTION 'La devise du mouvement doit correspondre à son bon ou à son article source.' USING ERRCODE='23514';
 END IF;
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_devise_mouvement(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_devise_mouvement() IS 'Affecte une seule fois la devise du bon, ou de l’article initial/direct ; ne modifie ni quantité, ni prix, ni effet stock.';

--
-- Name: tr_devise_reglement(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_devise_reglement() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE devise_source integer;
BEGIN
 SELECT "ID_DeviseFk" INTO devise_source FROM logistique."T_Commande"
  WHERE "CodeFacture"=NEW."CodeFactureFk" FOR NO KEY UPDATE;
 IF devise_source IS NULL THEN RAISE EXCEPTION 'Une facture existante est requise pour le règlement.' USING ERRCODE='23503'; END IF;
 IF TG_OP='INSERT' AND NEW."ID_DeviseFk" IS NULL THEN NEW."ID_DeviseFk"=devise_source; END IF;
 IF TG_OP='UPDATE' AND NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" THEN
  RAISE EXCEPTION 'La devise historique d’un règlement est immuable.' USING ERRCODE='23514';
 END IF;
 IF NEW."ID_DeviseFk" IS DISTINCT FROM devise_source THEN
  RAISE EXCEPTION 'Le règlement doit être exprimé dans la devise de sa facture.' USING ERRCODE='23514';
 END IF;
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_devise_reglement(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_devise_reglement() IS 'Rattache le règlement à la devise de sa facture unique, verrouille le parent et refuse tout paiement implicite en autre devise.';

--
-- Name: tr_document_identite(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_document_identite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE kind text; key_id bigint; company integer; entity jsonb; third_id bigint; third_party jsonb;
BEGIN
 kind=CASE TG_TABLE_NAME WHEN 'T_Commande' THEN 'bon' WHEN 'T_Facture' THEN 'facture' WHEN 'T_Reglements' THEN 'reglement' ELSE 'avoir' END;
 key_id=CASE kind WHEN 'bon' THEN (to_jsonb(NEW)->>'ID_Commande')::bigint WHEN 'facture' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::bigint WHEN 'reglement' THEN (to_jsonb(NEW)->>'ID_Reglement')::bigint ELSE (to_jsonb(NEW)->>'ID_Avoir')::bigint END;
 company=logistique.fn_entite_document(kind,key_id);
 IF company IS NULL THEN RETURN NEW; END IF;
 entity:=systeme.fn_identite_documentaire(company);
 third_id=NULLIF(to_jsonb(NEW)->>'ID_TiersFk','')::bigint;
 IF third_id IS NULL AND kind IN ('facture','reglement','avoir') THEN
  SELECT c."ID_TiersFk" INTO third_id FROM logistique."T_Commande" c WHERE c."ID_Commande"=CASE WHEN kind='facture' THEN key_id WHEN kind='avoir' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::bigint ELSE (SELECT "ID_Commande" FROM logistique."T_Commande" WHERE "CodeFacture"=to_jsonb(NEW)->>'CodeFactureFk') END;
 END IF;
 IF third_id IS NOT NULL THEN SELECT to_jsonb(t)-ARRAY['ID_UserFk','IdUserFk','IdProfessionnelFk'] INTO third_party FROM logistique."T_Client" t WHERE t."ID_Client"=third_id AND t."IdEntiteFk"=company; END IF;
 INSERT INTO logistique."T_DocumentIdentite"("TypeObjet","ID_Objet","IdEntiteFk","IdentiteEmetteur","IdentiteTiers") VALUES(kind,key_id,company,entity,third_party) ON CONFLICT("TypeObjet","ID_Objet") DO NOTHING;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_document_identite(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_document_identite() IS 'Fige le profil documentaire canonique et le tiers à la création seulement ; les instantanés existants, stocks et montants restent inchangés.';

--
-- Name: tr_facture_apres_avoir(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_facture_apres_avoir() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM logistique."T_Avoir" WHERE "ID_FactureFk"=OLD."ID_Facture") OR EXISTS(SELECT 1 FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=OLD."ID_CommandeFk") THEN RAISE EXCEPTION 'Un avoir existe : la facture d’origine est conservée.' USING ERRCODE='23514'; END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;

--
-- Name: FUNCTION tr_facture_apres_avoir(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_facture_apres_avoir() IS 'Conserve l’identité et les dates de la facture après émission d’un avoir.';

--
-- Name: tr_guard_commandedetail(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_guard_commandedetail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
 v_ids integer[];
 v_commande record;
 v_nouvelle_trouvee boolean := false;
BEGIN
 IF TG_OP = 'INSERT' THEN v_ids := ARRAY[NEW."ID_CmdFk"];
 ELSIF TG_OP = 'UPDATE' THEN v_ids := ARRAY[OLD."ID_CmdFk", NEW."ID_CmdFk"];
 ELSE v_ids := ARRAY[OLD."ID_CmdFk"];
 END IF;
 -- Verrou commun avant l'effet stock et le futur calcul des totaux.
 -- L'ordre stable évite les inversions lors d'un déplacement entre commandes.
 FOR v_commande IN
  SELECT c."ID_Commande", c."StatusFacture"
  FROM logistique."T_Commande" c
  WHERE c."ID_Commande" = ANY(v_ids)
  ORDER BY c."ID_Commande"
  FOR NO KEY UPDATE
 LOOP
  IF logistique.fn_commande_cloturee(v_commande."StatusFacture") THEN
   RAISE EXCEPTION 'Commande % clôturée : modification de ses lignes interdite.', v_commande."ID_Commande"
    USING ERRCODE = '23514';
  END IF;
  IF TG_OP <> 'DELETE' AND v_commande."ID_Commande" = NEW."ID_CmdFk" THEN
   v_nouvelle_trouvee := true;
  END IF;
 END LOOP;
 IF TG_OP <> 'DELETE' AND NOT v_nouvelle_trouvee THEN
  RAISE EXCEPTION 'Commande % introuvable.', NEW."ID_CmdFk" USING ERRCODE = '23503';
 END IF;
 -- Lors du DELETE en cascade, le parent peut déjà avoir disparu ; son
 -- propre verrou de clôture a alors été contrôlé avant la suppression.
 IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_guard_commandedetail(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_guard_commandedetail() IS 'Avant chaque mutation de ligne, verrouille les commandes concernées par identifiant croissant et refuse les commandes clôturées. Sérialise les saisies pour éviter les totaux perdus ; accepte la disparition du parent lors d’un DELETE en cascade déjà autorisé.';

--
-- Name: tr_identite_document_immuable(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_identite_document_immuable() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN RAISE EXCEPTION 'L’identité documentaire est conservée.' USING ERRCODE='23514'; END $$;

--
-- Name: FUNCTION tr_identite_document_immuable(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_identite_document_immuable() IS 'Conserve les identités des documents émis.';

--
-- Name: tr_immobilisation_audit(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_immobilisation_audit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
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
END $_$;

--
-- Name: FUNCTION tr_immobilisation_audit(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_immobilisation_audit() IS 'Une image avant/après par écriture de patrimoine avec auteur réel et entreprise. Requête UUID/hash/opération facultative prouvée, sans GUC d’autorisation ni mouvement ; les anciennes affectations restent dans l’historique.';

--
-- Name: tr_immobilisation_verifier(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_immobilisation_verifier() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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

--
-- Name: FUNCTION tr_immobilisation_verifier(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_immobilisation_verifier() IS 'Impose identité/code/propriétaire immuables, références nouvelles actives, responsable affectable et localisation de la même entreprise, auteur prouvé et horodatages SQL. Conservation par archivage ; aucun effet de stock.';

--
-- Name: tr_lock_commande_cloturee(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_lock_commande_cloturee() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF logistique.fn_commande_cloturee(OLD."StatusFacture") THEN
  RAISE EXCEPTION 'Commande % clôturée : modification ou suppression interdite.', OLD."ID_Commande"
   USING ERRCODE = '23514';
 END IF;
 IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_lock_commande_cloturee(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_lock_commande_cloturee() IS 'Avant UPDATE/DELETE de commande, refuse une commande clôturée selon le prédicat commun normalisé fn_commande_cloturee ; contrôle l’état OLD.';

--
-- Name: tr_lock_mouvement_direct(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_lock_mouvement_direct() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF COALESCE(
        current_setting('logistique.allow_t_mouvement_write', true),
        'off'
    ) = 'on' THEN IF TG_OP = 'DELETE' THEN RETURN OLD;
END IF;
PERFORM logistique.fn_assert_generique_category(
    NEW."ID_TypeMvtFk",
    64,
    format('tr_lock_mouvement_direct(%s)', TG_OP),
    'ID_TypeMvtFk'
);
RETURN NEW;
END IF;
RAISE EXCEPTION 'T_Mouvement est geree par la logique metier. Ecriture directe interdite.';
END;
$$;

--
-- Name: FUNCTION tr_lock_mouvement_direct(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_lock_mouvement_direct() IS 'Bloque les écritures sur T_Mouvement sauf si le drapeau transactionnel logistique.allow_t_mouvement_write vaut on ; valide alors la catégorie 64 du type pour INSERT/UPDATE.';

--
-- Name: tr_mouvement_physique(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_mouvement_physique() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE nature text; parent_nature text;
BEGIN
 nature:=logistique.fn_nature_bon(NEW."ID_TypeMvtFk");
 IF nature IS NULL OR nature='commande' THEN RAISE EXCEPTION 'Un mouvement exige une entrée ou sortie physique.' USING ERRCODE='23514';END IF;
 IF NEW."ID_cmdFk" IS NOT NULL THEN
  SELECT logistique.fn_nature_bon(c."ID_TypeCmdFk") INTO parent_nature FROM logistique."T_Commande" c WHERE c."ID_Commande"=NEW."ID_cmdFk" FOR NO KEY UPDATE;
  IF parent_nature IS DISTINCT FROM nature THEN RAISE EXCEPTION 'Mouvement incompatible avec la nature du bon ; aucun mouvement pour CMD.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_mouvement_physique(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_mouvement_physique() IS 'Refuse tout mouvement CMD, inconnu ou lié à un parent CMD, même avec le drapeau interne d’écriture activé et un type physique falsifié. Vérifie le sens commun du parent verrouillé et du mouvement.';

--
-- Name: tr_numero_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_numero_commande() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE expected_code varchar;
BEGIN
 IF TG_OP='INSERT' THEN
  expected_code=logistique.fn_code_bon(NEW."ID_Commande",NEW."ID_TypeCmdFk");
  IF expected_code IS NULL OR logistique.fn_identite_commande_deja_utilisee(NEW."ID_Commande") THEN RAISE EXCEPTION 'Cette identite de bon a deja ete utilisee.' USING ERRCODE='23514';END IF;
  IF NULLIF(btrim(NEW."CodeCmd"),'') IS NOT NULL AND NEW."CodeCmd"<>expected_code THEN RAISE EXCEPTION 'Le code du bon est attribue automatiquement.' USING ERRCODE='23514';END IF;
  NEW."CodeCmd"=expected_code;
  IF NULLIF(btrim(NEW."CodeFacture"),'') IS NOT NULL THEN RAISE EXCEPTION 'La facture est emise apres le bon.' USING ERRCODE='23514';END IF;
  NEW."CodeFacture"=NULL;
 ELSE
  IF NEW."ID_TypeCmdFk" IS DISTINCT FROM OLD."ID_TypeCmdFk" AND (logistique.fn_nature_bon(OLD."ID_TypeCmdFk")='commande' OR logistique.fn_nature_bon(NEW."ID_TypeCmdFk")='commande') THEN RAISE EXCEPTION 'Nature CMD immuable ; créez un BE ou BS distinct.' USING ERRCODE='23514';END IF;
  IF NEW."ID_Commande" IS DISTINCT FROM OLD."ID_Commande" OR NEW."CodeCmd" IS DISTINCT FROM OLD."CodeCmd" THEN RAISE EXCEPTION 'Identite et code du bon immuables.' USING ERRCODE='23514';END IF;
  IF NEW."ID_TypeCmdFk" IS DISTINCT FROM OLD."ID_TypeCmdFk" AND OLD."CodeCmd" ~ '^(BE|BS)-' AND logistique.fn_code_bon(NEW."ID_Commande",NEW."ID_TypeCmdFk") IS DISTINCT FROM OLD."CodeCmd" THEN RAISE EXCEPTION 'Le sens du bon est conserve avec son numero; creez un nouveau bon.' USING ERRCODE='23514';END IF;
  IF NEW."CodeFacture" IS DISTINCT FROM OLD."CodeFacture" THEN
   IF NULLIF(btrim(OLD."CodeFacture"),'') IS NOT NULL OR NEW."CodeFacture" IS DISTINCT FROM logistique.fn_code_facture(NEW."ID_Commande") OR NOT EXISTS(SELECT FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=NEW."ID_Commande" AND f."CodeFacture"=NEW."CodeFacture") THEN RAISE EXCEPTION 'Numero de facture automatique et immuable.' USING ERRCODE='23514';END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_numero_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_numero_commande() IS 'Attribue BE-/BS-/CMD- aux nouvelles identités, conserve les codes historiques et interdit toute conversion vers ou depuis CMD, même sans ligne. Les factures gardent leur numérotation dédiée.';

--
-- Name: tr_numero_facture(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_numero_facture() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE expected_code varchar;
BEGIN
 expected_code=logistique.fn_code_facture(NEW."ID_CommandeFk");
 IF TG_OP='INSERT' THEN
  IF expected_code IS NULL OR (NULLIF(btrim(NEW."CodeFacture"),'') IS NOT NULL AND NEW."CodeFacture"<>expected_code) THEN
   RAISE EXCEPTION 'Le numéro de facture est attribué depuis le bon.' USING ERRCODE='23514'; END IF;
  NEW."CodeFacture"=expected_code;
 ELSE
  IF NEW."ID_CommandeFk" IS DISTINCT FROM OLD."ID_CommandeFk" OR NEW."CodeFacture" IS DISTINCT FROM OLD."CodeFacture" THEN
   RAISE EXCEPTION 'La référence et le bon d’une facture émise sont immuables.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_numero_facture(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_numero_facture() IS 'Génère fac-IDBon lors de l’émission et conserve la référence et le parent ensuite.';

--
-- Name: tr_piece_coherente(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_piece_coherente() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Les justificatifs sont archivés et conservés.' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND (to_jsonb(NEW)-'Archive') IS DISTINCT FROM (to_jsonb(OLD)-'Archive') THEN RAISE EXCEPTION 'Le justificatif est immuable.' USING ERRCODE='23514'; END IF;
 IF NEW."IdEntiteFk" IS DISTINCT FROM logistique.fn_entite_document(NEW."TypeObjet",NEW."ID_Objet") THEN RAISE EXCEPTION 'Justificatif hors entreprise du document.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_piece_coherente(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_piece_coherente() IS 'Interdit les justificatifs interentreprises et la modification des fichiers déjà enregistrés.';

--
-- Name: tr_precision_stock(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_precision_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION 'Conservez la politique ; choisissez explicitement zéro décimale si nécessaire' USING ERRCODE='23514';
 END IF;
 IF TG_OP='UPDATE' AND
 (NEW."ID_PrecisionStock"<>OLD."ID_PrecisionStock" OR NEW."ID_UniteFk"<>OLD."ID_UniteFk") THEN
  RAISE EXCEPTION 'L’identité et l’unité de la politique sont conservées' USING ERRCODE='23514';
 END IF;
 -- Même clé de verrou que fn_verifier_quantite : la réduction attend les opérations en cours.
 PERFORM 1 FROM referentiel."T_Generique"
  WHERE "ID_Generique"=NEW."ID_UniteFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Article','ID_UniteFk',NEW."ID_UniteFk") OR referentiel.fn_reference_champ_connue('logistique','T_PrecisionStock','ID_UniteFk',NEW."ID_UniteFk")) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Une unité du référentiel Unités est requise' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."DecimalesStock" IS NOT DISTINCT FROM OLD."DecimalesStock" THEN
  NEW."ModifieLe"=OLD."ModifieLe";RETURN NEW;
 END IF;
 PERFORM logistique.fn_precision_stock_compatible(NEW."ID_UniteFk",NEW."DecimalesStock");
 NEW."ModifieLe"=clock_timestamp();
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_precision_stock(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_precision_stock() IS 'Politique de décimales conservée et protégée par l’historique ; sélection d’unité résolue au catalogue, identité toujours immuable.';

--
-- Name: tr_proteger_bon_facture(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_proteger_bon_facture() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE invoice logistique."T_Facture";
BEGIN
 SELECT * INTO invoice FROM logistique."T_Facture" WHERE "ID_CommandeFk"=OLD."ID_Commande";
 IF NOT FOUND THEN RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END; END IF;
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Le bon d’une facture émise est conservé.' USING ERRCODE='23514'; END IF;
 IF (to_jsonb(NEW)-ARRAY['DateFacture','DateEcheancePaiement','CodeFacture','ID_ModePaiementFk','ID_ConditionPaiementFk','DateHeureAutoFacture','StatusFacture','MontantRegleFacture','MontantResteFacture']) IS DISTINCT FROM
    (to_jsonb(OLD)-ARRAY['DateFacture','DateEcheancePaiement','CodeFacture','ID_ModePaiementFk','ID_ConditionPaiementFk','DateHeureAutoFacture','StatusFacture','MontantRegleFacture','MontantResteFacture']) THEN
   RAISE EXCEPTION 'Le panier et les informations de stock d’un bon facturé sont conservés.' USING ERRCODE='23514'; END IF;
 IF NEW."CodeFacture" IS DISTINCT FROM invoice."CodeFacture" OR NEW."DateFacture" IS DISTINCT FROM invoice."DateFacture"
 OR NEW."DateEcheancePaiement" IS DISTINCT FROM invoice."DateEcheancePaiement"
 OR NEW."ID_ModePaiementFk" IS DISTINCT FROM invoice."ID_ModePaiementFk" OR NEW."ID_ConditionPaiementFk" IS DISTINCT FROM invoice."ID_ConditionPaiementFk" THEN
   RAISE EXCEPTION 'Utilisez le service de facturation pour modifier ses métadonnées.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_proteger_bon_facture(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_proteger_bon_facture() IS 'Conserve les valeurs du bon facturé et vérifie le miroir financier sans mise à jour de stock.';

--
-- Name: tr_proteger_facture(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_proteger_facture() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE parent logistique."T_Commande"; source_entity integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une facture émise est conservée.' USING ERRCODE='23514'; END IF;
 SELECT * INTO parent FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CommandeFk" FOR UPDATE;
 IF NOT FOUND OR logistique.fn_commande_cloturee(parent."StatusFacture") THEN RAISE EXCEPTION 'Bon absent ou clôturé.' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (to_jsonb(NEW)-ARRAY['DateFacture','DateEcheancePaiement','ID_ModePaiementFk','ID_ConditionPaiementFk','DelaiJours','ModifieLe']) IS DISTINCT FROM
     (to_jsonb(OLD)-ARRAY['DateFacture','DateEcheancePaiement','ID_ModePaiementFk','ID_ConditionPaiementFk','DelaiJours','ModifieLe']) THEN
     RAISE EXCEPTION 'Identité, devise et montants facturés immuables.' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM logistique."T_Reglements" WHERE "CodeFactureFk"=OLD."CodeFacture") THEN
     RAISE EXCEPTION 'Facture réglée en tout ou partie : métadonnées conservées.' USING ERRCODE='23514'; END IF;
 ELSE
  IF NULLIF(btrim(parent."CodeFacture"),'') IS NOT NULL THEN RAISE EXCEPTION 'Une facture historique existe déjà.' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=parent."ID_TypeCmdFk"
    AND "ID_CategorieGeneriqueFk"=64 AND "AbrGenerique" ILIKE 'sort%')
    OR EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeRetourFk"=parent."ID_Commande") THEN
    RAISE EXCEPTION 'Seul un bon de sortie original peut être facturé.' USING ERRCODE='23514'; END IF;
  source_entity:=parent."IdEntiteFk";
  IF NEW."IdEntiteFk" IS DISTINCT FROM source_entity OR NEW."ID_DeviseFk" IS DISTINCT FROM parent."ID_DeviseFk" THEN
     RAISE EXCEPTION 'Organisation ou devise incompatible avec le bon.' USING ERRCODE='23514'; END IF;
  PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
  IF NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."ID_DeviseFk"
    AND logistique.fn_code_devise("AbrGenerique")=NEW."DeviseCode") THEN
    RAISE EXCEPTION 'Le code de devise doit correspondre au référentiel.' USING ERRCODE='23514'; END IF;
 END IF;
 PERFORM logistique.fn_assert_generique_category(NEW."ID_ModePaiementFk",36,'Facture','ID_ModePaiementFk');
 PERFORM logistique.fn_assert_generique_category(NEW."ID_ConditionPaiementFk",37,'Facture','ID_ConditionPaiementFk');
 IF (TG_OP='INSERT' OR NEW."ID_ModePaiementFk" IS DISTINCT FROM OLD."ID_ModePaiementFk") AND NEW."ID_ModePaiementFk" IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
   WHERE g."ID_Generique"=NEW."ID_ModePaiementFk" AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE) THEN
  RAISE EXCEPTION 'Mode de paiement inactif.' USING ERRCODE='23514'; END IF;
 IF (TG_OP='INSERT' OR NEW."ID_ConditionPaiementFk" IS DISTINCT FROM OLD."ID_ConditionPaiementFk") AND NEW."ID_ConditionPaiementFk" IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
   WHERE g."ID_Generique"=NEW."ID_ConditionPaiementFk" AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE) THEN
  RAISE EXCEPTION 'Condition de paiement inactive.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_proteger_facture(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_proteger_facture() IS 'Interdit suppression et modification du snapshot ; seules les métadonnées restent modifiables avant règlement.';

--
-- Name: tr_proteger_identite_lot_facture(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_proteger_identite_lot_facture() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF (NEW."NumeroLot",NEW."DatePeremptionLot",NEW."ID_ArticleFk") IS DISTINCT FROM
    (OLD."NumeroLot",OLD."DatePeremptionLot",OLD."ID_ArticleFk") THEN
  PERFORM 1 FROM logistique."T_Commande" c WHERE c."ID_Commande" IN
    (SELECT m."ID_cmdFk" FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
     WHERE ml."ID_LotArticleFk"=OLD."ID_LotArticle") ORDER BY c."ID_Commande" FOR UPDATE;
  IF EXISTS(SELECT 1 FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
    JOIN logistique."T_Facture" f ON f."ID_CommandeFk"=m."ID_cmdFk" WHERE ml."ID_LotArticleFk"=OLD."ID_LotArticle") THEN
    RAISE EXCEPTION 'L’identité d’un lot présent sur une facture est conservée.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_proteger_identite_lot_facture(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_proteger_identite_lot_facture() IS 'Conserve numéro, péremption et article des lots ventilés sur un bon facturé ; leur stock futur reste géré par de nouveaux mouvements.';

--
-- Name: tr_proteger_ligne_facture(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_proteger_ligne_facture() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE invoice logistique."T_Facture"; created_xid bigint;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Les lignes d’une facture émise sont immuables.' USING ERRCODE='23514'; END IF;
 SELECT f.* INTO invoice FROM logistique."T_Facture" f WHERE f."ID_Facture"=NEW."ID_FactureFk";
 SELECT f."TransactionCreation" INTO created_xid FROM logistique."T_Facture" f WHERE f."ID_Facture"=NEW."ID_FactureFk";
 IF created_xid IS DISTINCT FROM txid_current() OR NEW."ID_CmdFk" IS DISTINCT FROM invoice."ID_CommandeFk" THEN
    RAISE EXCEPTION 'Les lignes sont figées lors de l’émission.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_proteger_ligne_facture(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_proteger_ligne_facture() IS 'Les lignes sont créées dans la transaction de leur facture puis conservées sans modification.';

--
-- Name: tr_proteger_reference_devise(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_proteger_reference_devise() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE utilisee boolean;
BEGIN
 SELECT EXISTS (SELECT 1 FROM logistique."T_Article" WHERE "ID_DeviseFk"=OLD."ID_Generique")
  OR EXISTS (SELECT 1 FROM logistique."T_Commande" WHERE "ID_DeviseFk"=OLD."ID_Generique")
  OR EXISTS (SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_DeviseFk"=OLD."ID_Generique")
  OR EXISTS (SELECT 1 FROM logistique."T_Reglements" WHERE "ID_DeviseFk"=OLD."ID_Generique") INTO utilisee;
 IF utilisee AND (NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk"
  OR logistique.fn_code_devise(NEW."AbrGenerique") IS DISTINCT FROM logistique.fn_code_devise(OLD."AbrGenerique")) THEN
  RAISE EXCEPTION 'Le code et la catégorie d’une devise utilisée sont immuables.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_proteger_reference_devise(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_proteger_reference_devise() IS 'Empêche de renommer le code ou de reclasser une devise déjà utilisée ; la désactivation ne supprime pas l’historique.';

--
-- Name: tr_proteger_stock_facture(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_proteger_stock_facture() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE old_id integer; new_id integer; command_ids integer[];
BEGIN
 IF TG_TABLE_NAME='T_CommandeDetail' THEN
   IF TG_OP<>'INSERT' THEN old_id:=OLD."ID_CmdFk"; END IF;
   IF TG_OP<>'DELETE' THEN new_id:=NEW."ID_CmdFk"; END IF;
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN
   IF TG_OP<>'INSERT' THEN old_id:=OLD."ID_cmdFk"; END IF;
   IF TG_OP<>'DELETE' THEN new_id:=NEW."ID_cmdFk"; END IF;
 ELSE
   IF TG_OP<>'INSERT' THEN SELECT "ID_cmdFk" INTO old_id FROM logistique."T_Mouvement" WHERE "ID_Mvt"=OLD."ID_MvtFk"; END IF;
   IF TG_OP<>'DELETE' THEN SELECT "ID_cmdFk" INTO new_id FROM logistique."T_Mouvement" WHERE "ID_Mvt"=NEW."ID_MvtFk"; END IF;
 END IF;
 command_ids:=ARRAY[old_id,new_id];
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=ANY(command_ids) ORDER BY "ID_Commande" FOR UPDATE;
 IF EXISTS(SELECT 1 FROM logistique."T_Facture" WHERE "ID_CommandeFk"=ANY(command_ids)) THEN
   RAISE EXCEPTION 'Les lignes et mouvements d’un bon facturé sont immuables.' USING ERRCODE='23514'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;

--
-- Name: FUNCTION tr_proteger_stock_facture(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_proteger_stock_facture() IS 'Refuse les écritures de lignes et mouvements d’un bon déjà facturé.';

--
-- Name: tr_proteger_unite_precision_stock(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_proteger_unite_precision_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW."ID_Generique"=OLD."ID_Generique" AND NEW."ID_CategorieGeneriqueFk"=OLD."ID_CategorieGeneriqueFk" THEN RETURN NEW;END IF;
 IF
 (EXISTS(SELECT FROM logistique."T_PrecisionStock" WHERE "ID_UniteFk"=OLD."ID_Generique")
 OR EXISTS(SELECT FROM logistique."T_Article" WHERE "ID_UniteFk"=OLD."ID_Generique")) THEN
  RAISE EXCEPTION 'La catégorie et l’identité d’une unité utilisée sont conservées' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_proteger_unite_precision_stock(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_proteger_unite_precision_stock() IS 'Conserve la catégorie et l’identité d’une unité référencée par une politique ou un article, sans bloquer la modification de son libellé.';

--
-- Name: tr_quantite_unite(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_quantite_unite() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE u integer; BEGIN
 IF TG_TABLE_NAME='T_Article' THEN u=NEW."ID_UniteFk";PERFORM logistique.fn_verifier_quantite(u,NEW."QteArticle");PERFORM logistique.fn_verifier_quantite(u,NEW."QteMinArticle");
 ELSIF TG_TABLE_NAME='T_CommandeDetail' THEN SELECT "ID_UniteFk" INTO u FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";PERFORM logistique.fn_verifier_quantite(u,NEW."QteCmdDetail");
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN SELECT "ID_UniteFk" INTO u FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";PERFORM logistique.fn_verifier_quantite(u,NEW."QteMvt");
 ELSE SELECT a."ID_UniteFk" INTO u FROM logistique."T_Mouvement" m JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE m."ID_Mvt"=NEW."ID_MvtFk";PERFORM logistique.fn_verifier_quantite(u,NEW."Quantite");END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_quantite_unite(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_quantite_unite() IS 'Défense SQL commune article, ligne, mouvement et ventilation ; aucun effet de stock supplémentaire.';

--
-- Name: tr_reglement_apres_avoir(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_reglement_apres_avoir() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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
   WHERE g."ID_Generique"=NEW."ID_ModeReglementFk" AND referentiel.fn_reference_champ_connue('logistique','T_Reglements','ID_ModeReglementFk',NEW."ID_ModeReglementFk")
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

--
-- Name: FUNCTION tr_reglement_apres_avoir(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_reglement_apres_avoir() IS 'Protections du règlement conservées : valeur active, solde après avoir et dates ; famille du mode déléguée au référencement physique.';

--
-- Name: tr_reglement_audit(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_reglement_audit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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

--
-- Name: FUNCTION tr_reglement_audit(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_reglement_audit() IS 'Une image avant/après nettoyée par écriture de règlement, avec auteur identifié et entreprise durable de la facture. Les événements PAYMENT_* applicatifs ne portent que les preuves idempotentes.';

--
-- Name: tr_reglement_tracabilite(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_reglement_tracabilite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
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

--
-- Name: FUNCTION tr_reglement_tracabilite(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_reglement_tracabilite() IS 'Fixe les dates techniques et auteurs prouvés du règlement ; conserve les origines historiques inconnues et protège la création contre les modifications.';

--
-- Name: tr_totaux_commande(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_totaux_commande() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_id integer;
BEGIN
 IF TG_OP = 'INSERT' THEN
  FOR v_id IN SELECT DISTINCT "ID_CmdFk" FROM lignes_nouvelles ORDER BY "ID_CmdFk"
  LOOP CALL logistique.ps_update_totaux_commande(v_id); END LOOP;
 ELSIF TG_OP = 'DELETE' THEN
  FOR v_id IN SELECT DISTINCT "ID_CmdFk" FROM lignes_anciennes ORDER BY "ID_CmdFk"
  LOOP CALL logistique.ps_update_totaux_commande(v_id); END LOOP;
 ELSIF TG_OP = 'UPDATE' THEN
  FOR v_id IN
   SELECT "ID_CmdFk" FROM lignes_anciennes
   UNION SELECT "ID_CmdFk" FROM lignes_nouvelles ORDER BY "ID_CmdFk"
  LOOP CALL logistique.ps_update_totaux_commande(v_id); END LOOP;
 END IF;
 RETURN NULL;
END;
$$;

--
-- Name: FUNCTION tr_totaux_commande(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_totaux_commande() IS 'Fonction des trois triggers AFTER STATEMENT de lignes : utilise les tables de transition pour recalculer une seule fois chaque commande affectée, y compris ancien/nouveau parent en UPDATE. Aucune boucle de recalcul par ligne.';

--
-- Name: tr_utilisation_avoir(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_utilisation_avoir() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE a logistique."T_Avoir"; target logistique."T_Facture"; source_client bigint; target_client bigint; used numeric; due numeric; target_id integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'L’historique des imputations et remboursements est conservé.' USING ERRCODE='23514'; END IF;
 SELECT * INTO a FROM logistique."T_Avoir" WHERE "ID_Avoir"=NEW."ID_AvoirFk";
 IF TG_TABLE_NAME='T_AvoirAffectation' THEN target_id=NEW."ID_CommandeCibleFk"; END IF;
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande" IN (a."ID_CommandeFk",target_id) ORDER BY "ID_Commande" FOR UPDATE;
 SELECT * INTO a FROM logistique."T_Avoir" WHERE "ID_Avoir"=NEW."ID_AvoirFk" FOR UPDATE;
 SELECT COALESCE((SELECT sum("Montant") FROM logistique."T_AvoirAffectation" WHERE "ID_AvoirFk"=a."ID_Avoir"),0)+COALESCE((SELECT sum("Montant") FROM logistique."T_Remboursement" WHERE "ID_AvoirFk"=a."ID_Avoir"),0) INTO used;
 IF used+NEW."Montant">a."MontantTTC" THEN RAISE EXCEPTION 'Le disponible de l’avoir est insuffisant.' USING ERRCODE='23514'; END IF;
 IF target_id IS NOT NULL THEN
  SELECT * INTO target FROM logistique."T_Facture" WHERE "ID_CommandeFk"=target_id;
  IF NOT FOUND OR target."IdEntiteFk"<>a."IdEntiteFk" OR target."ID_DeviseFk"<>a."ID_DeviseFk" THEN RAISE EXCEPTION 'Facture cible d’entreprise ou devise différente.' USING ERRCODE='23514'; END IF;
  IF target_id<>a."ID_CommandeFk" THEN
   SELECT "ID_TiersFk" INTO source_client FROM logistique."T_Commande" WHERE "ID_Commande"=a."ID_CommandeFk";
   SELECT "ID_TiersFk" INTO target_client FROM logistique."T_Commande" WHERE "ID_Commande"=target_id;
   IF source_client IS NULL OR source_client IS DISTINCT FROM target_client THEN RAISE EXCEPTION 'L’imputation concerne le même tiers référencé.' USING ERRCODE='23514'; END IF;
  END IF;
  SELECT target."MontantTTC"-COALESCE((SELECT sum("MontantRegle") FROM logistique."T_Reglements" WHERE "CodeFactureFk"=target."CodeFacture"),0)-COALESCE((SELECT sum("Montant") FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=target_id),0) INTO due;
  IF NEW."Montant">due THEN RAISE EXCEPTION 'L’imputation dépasse le solde de la facture cible.' USING ERRCODE='23514'; END IF;
 ELSE
  PERFORM logistique.fn_assert_generique_category(NEW."ID_ModePaiementFk",36,'Remboursement','ID_ModePaiementFk');
  IF NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_Generique"=NEW."ID_ModePaiementFk" AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE) THEN RAISE EXCEPTION 'Mode de remboursement inactif.' USING ERRCODE='23514'; END IF;
  IF NEW."DateRemboursement"<a."DateAvoir" THEN RAISE EXCEPTION 'Le remboursement précède l’avoir.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_utilisation_avoir(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_utilisation_avoir() IS 'Sérialise l’utilisation des avoirs, vérifie disponible, solde cible, tiers, devise et mode de remboursement.';

--
-- Name: tr_verifier_snapshot_facture(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tr_verifier_snapshot_facture() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE invoice logistique."T_Facture"; parent logistique."T_Commande"; total numeric;
BEGIN
 IF TG_TABLE_NAME='T_FactureLigne' THEN
  SELECT * INTO invoice FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_FactureFk";
 ELSE SELECT * INTO invoice FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_Facture"; END IF;
 SELECT * INTO parent FROM logistique."T_Commande" WHERE "ID_Commande"=invoice."ID_CommandeFk";
 IF parent."CodeFacture" IS DISTINCT FROM invoice."CodeFacture" OR parent."DateFacture" IS DISTINCT FROM invoice."DateFacture"
 OR parent."DateEcheancePaiement" IS DISTINCT FROM invoice."DateEcheancePaiement"
 OR parent."ID_ModePaiementFk" IS DISTINCT FROM invoice."ID_ModePaiementFk"
 OR parent."ID_ConditionPaiementFk" IS DISTINCT FROM invoice."ID_ConditionPaiementFk" THEN
   RAISE EXCEPTION 'Le miroir de facture du bon doit rester cohérent.' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  SELECT sum("MontantLigne") INTO total FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=invoice."ID_Facture";
  IF total IS DISTINCT FROM invoice."MontantTTC" THEN RAISE EXCEPTION 'Total de facture différent de ses lignes.' USING ERRCODE='23514'; END IF;
  IF EXISTS(
   WITH returned AS (SELECT d."ID_ArticleFk",sum(d."QteCmdDetail") AS n FROM logistique."T_RetourBon" r
     JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=r."ID_CommandeRetourFk"
     WHERE r."ID_CommandeOrigineFk"=invoice."ID_CommandeFk" GROUP BY d."ID_ArticleFk")
   SELECT 1 FROM (SELECT * FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=invoice."ID_CommandeFk") d
   LEFT JOIN returned r ON r."ID_ArticleFk"=d."ID_ArticleFk"
   FULL JOIN (SELECT * FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=invoice."ID_Facture") l ON l."ID_ArticleFk"=d."ID_ArticleFk"
   WHERE (d."ID_CmdFk"=invoice."ID_CommandeFk" OR l."ID_FactureFk"=invoice."ID_Facture")
    AND ((COALESCE(d."QteCmdDetail",0)-COALESCE(r.n,0)>0 AND
          (l."ID_FactureLigne" IS NULL OR l."ID_CmdFk"<>invoice."ID_CommandeFk"
           OR l."QteSortie" IS DISTINCT FROM d."QteCmdDetail" OR l."PUFacture" IS DISTINCT FROM d."PUCmdDetail"
           OR l."QteRetourAvantFacture" IS DISTINCT FROM COALESCE(r.n,0)))
         OR (COALESCE(d."QteCmdDetail",0)-COALESCE(r.n,0)<=0 AND l."ID_FactureLigne" IS NOT NULL))) THEN
   RAISE EXCEPTION 'Les lignes facturées doivent correspondre aux quantités nettes du bon.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NULL;
END $$;

--
-- Name: FUNCTION tr_verifier_snapshot_facture(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tr_verifier_snapshot_facture() IS 'Contrôle différé du miroir, du total et des quantités nettes avant émission ; aucun mouvement de stock.';

--
-- Name: tracer_source_cout(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.tracer_source_cout() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE a record;m record;bound integer;BEGIN
 IF TG_OP='UPDATE' AND OLD."ID_cmdFk" IS NULL AND NEW."ID_cmdFk" IS NOT NULL AND (to_jsonb(NEW)-'ID_cmdFk')=(to_jsonb(OLD)-'ID_cmdFk') AND current_setting('logistique.stock_initial_mouvement',true)=OLD."ID_Mvt"::text AND EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."ID_Commande"=NEW."ID_cmdFk" AND c."OrigineBon"='reprise_mouvement' AND c."ID_ArticleInitialFk"=NEW."ID_ArticleFk") THEN
  INSERT INTO logistique."T_ValorisationEvenement"("ID_ArticleFk","IdEntiteFk","Operation","Motif","Avant","Apres") SELECT source_article."ID_Article",source_article."IdEntiteFk",'mouvement_update','Rattachement documentaire; mouvement, quantite, prix et arrete conserves',to_jsonb(OLD),to_jsonb(NEW) FROM logistique."T_Article" source_article WHERE source_article."ID_Article"=NEW."ID_ArticleFk";
  RETURN NEW;
 END IF;
 
 IF TG_OP='DELETE' THEN m=OLD;ELSE m=NEW;END IF;
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=m."ID_ArticleFk" FOR NO KEY UPDATE;
 IF TG_OP IN ('UPDATE','DELETE') THEN
  SELECT "ID_MvtArrete" INTO bound FROM logistique."T_ValorisationOuverture" WHERE "ID_ArticleFk"=OLD."ID_ArticleFk" AND "ID_DeviseFk"=OLD."ID_DeviseFk" AND "CoutOuverture" IS NOT NULL;
  IF bound IS NOT NULL AND OLD."ID_Mvt"<=bound THEN RAISE EXCEPTION 'Ce mouvement appartient à un arrêté de coût ; corrigez par un bon compensateur' USING ERRCODE='23514';END IF;
 END IF;
 INSERT INTO logistique."T_ValorisationEvenement"("ID_ArticleFk","IdEntiteFk","ID_UserFk","Operation","Avant","Apres")
 VALUES(a."ID_Article",a."IdEntiteFk",NULL,'mouvement_'||lower(TG_OP),CASE WHEN TG_OP<>'INSERT' THEN to_jsonb(OLD) END,CASE WHEN TG_OP<>'DELETE' THEN to_jsonb(NEW) END);
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;

--
-- Name: FUNCTION tracer_source_cout(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.tracer_source_cout() IS 'Trace les sources et protege les arretes confirmes; seule exception: rattachement documentaire strict d un mouvement orphelin sans changer identite, dates, quantite, prix ou devise.';

--
-- Name: verifier_article_poids(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.verifier_article_poids() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW."ID_UnitePoidsFk" IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."ID_UnitePoidsFk" AND referentiel.fn_reference_champ_connue('logistique','T_Article','ID_UnitePoidsFk',NEW."ID_UnitePoidsFk") AND lower(btrim("AbrGenerique")) IN ('mg','g','kg','t')) THEN
 RAISE EXCEPTION 'Unité de masse requise pour le poids unitaire.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION verifier_article_poids(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.verifier_article_poids() IS 'Unité de poids issue de la famille du champ, avec les codes de masse mg/g/kg/t toujours obligatoires ; aucun poids ni unité historique recalculé.';

--
-- Name: verifier_bon_inventaire_non_commercial(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.verifier_bon_inventaire_non_commercial() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE targets integer[];identifier integer;
BEGIN
 IF TG_TABLE_NAME='T_Facture' THEN targets=ARRAY[NEW."ID_CommandeFk"];
 ELSIF TG_TABLE_NAME='T_RetourBon' THEN targets=ARRAY[NEW."ID_CommandeOrigineFk",NEW."ID_CommandeRetourFk"];
 ELSIF TG_TABLE_NAME='T_Commande' THEN
  IF NEW."CodeFacture" IS NOT DISTINCT FROM OLD."CodeFacture" OR NULLIF(btrim(NEW."CodeFacture"),'') IS NULL THEN RETURN NEW;END IF;
  targets=ARRAY[NEW."ID_Commande"];
 ELSE targets=ARRAY[NEW."ID_CommandeCorrectionFk",NEW."ID_CommandeAnnulationFk",OLD."ID_CommandeCorrectionFk",OLD."ID_CommandeAnnulationFk"];
 END IF;
 -- Un verrou commun aux deux sens empêche facture et rattachement concurrents.
 PERFORM 1 FROM logistique."T_Commande" c WHERE c."ID_Commande"=ANY(targets) ORDER BY c."ID_Commande" FOR UPDATE;
 IF TG_TABLE_NAME IN('T_Facture','T_RetourBon','T_Commande') THEN
  FOREACH identifier IN ARRAY targets LOOP
   IF logistique.fn_bon_inventaire(identifier) THEN RAISE EXCEPTION 'Un bon d’inventaire ne peut pas être facturé ou restitué comme une opération commerciale.' USING ERRCODE='23514',CONSTRAINT='inventaire_bon_non_commercial';END IF;
  END LOOP;
 ELSE
  FOREACH identifier IN ARRAY targets LOOP
   IF identifier IS NOT NULL AND (
     EXISTS(SELECT FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=identifier)
     OR EXISTS(SELECT FROM logistique."T_RetourBon" r WHERE identifier IN(r."ID_CommandeOrigineFk",r."ID_CommandeRetourFk"))
     OR EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."ID_Commande"=identifier AND NULLIF(btrim(c."CodeFacture"),'') IS NOT NULL))
   THEN RAISE EXCEPTION 'Un bon commercial ne peut pas servir de correction ou d’annulation d’inventaire.' USING ERRCODE='23514',CONSTRAINT='inventaire_bon_non_commercial';END IF;
  END LOOP;
 END IF;
 IF TG_WHEN='AFTER' THEN RETURN NULL;ELSIF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;
END $$;

--
-- Name: FUNCTION verifier_bon_inventaire_non_commercial(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.verifier_bon_inventaire_non_commercial() IS 'Verrouille les bons dans un ordre stable et refuse les liens commerciaux dans les deux sens, y compris les rattachements différés de la transaction.';

--
-- Name: verifier_dossier_suivi(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.verifier_dossier_suivi() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE parent logistique."T_DossierSuivi"; permitted boolean;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF TG_TABLE_NAME IN ('T_DossierSuivi','T_CategorieDossierSuivi') THEN
   IF OLD."ID_UserFk" IS DISTINCT FROM NEW."ID_UserFk" OR OLD."IdEntiteFk" IS DISTINCT FROM NEW."IdEntiteFk" THEN RAISE EXCEPTION 'Le propriétaire et le périmètre du dossier sont immuables.'; END IF;
  ELSE
   IF OLD."ID_Membre"<>NEW."ID_Membre" OR OLD."ID_DossierSuiviFk"<>NEW."ID_DossierSuiviFk" OR OLD."ID_ArticleFk" IS DISTINCT FROM NEW."ID_ArticleFk" OR OLD."ID_CommandeFk" IS DISTINCT FROM NEW."ID_CommandeFk" THEN RAISE EXCEPTION 'Le rattachement ne peut pas être transféré.'; END IF;
  END IF;
 END IF;
 IF TG_TABLE_NAME='T_DossierSuivi' THEN
  IF TG_OP='UPDATE' AND (OLD."Mode"<>NEW."Mode" OR OLD."TypeObjet"<>NEW."TypeObjet") THEN RAISE EXCEPTION 'Le type et le mode du dossier sont immuables.'; END IF;
  IF NEW."ID_CategorieDossierSuiviFk" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM logistique."T_CategorieDossierSuivi" c WHERE c."ID_CategorieDossierSuivi"=NEW."ID_CategorieDossierSuiviFk" AND c."ID_UserFk"=NEW."ID_UserFk" AND c."IdEntiteFk" IS NOT DISTINCT FROM NEW."IdEntiteFk" AND c."Actif") THEN RAISE EXCEPTION 'La catégorie n’appartient pas au périmètre du dossier.'; END IF;
 ELSIF TG_TABLE_NAME='T_DossierSuiviMembre' THEN
  SELECT * INTO parent FROM logistique."T_DossierSuivi" WHERE "ID_DossierSuivi"=NEW."ID_DossierSuiviFk" FOR UPDATE;
  IF NOT FOUND OR parent."Mode"<>'manuel' OR NOT parent."Actif" THEN RAISE EXCEPTION 'Seul un dossier manuel actif accepte un rattachement.'; END IF;
  IF parent."TypeObjet"='article' THEN
   IF NEW."ID_ArticleFk" IS NULL OR NEW."ID_CommandeFk" IS NOT NULL THEN RAISE EXCEPTION 'Ce dossier accepte uniquement des articles.'; END IF;
   SELECT EXISTS (SELECT 1 FROM logistique."T_Article" a JOIN systeme."T_Utilisateurs" owner_u ON owner_u."IdUser"=parent."ID_UserFk" WHERE a."ID_Article"=NEW."ID_ArticleFk" AND (parent."IdEntiteFk" IS NOT NULL AND a."IdEntiteFk"=parent."IdEntiteFk")) INTO permitted;
  ELSE
   IF NEW."ID_CommandeFk" IS NULL OR NEW."ID_ArticleFk" IS NOT NULL THEN RAISE EXCEPTION 'Ce dossier accepte uniquement des documents de stock ou de facturation.'; END IF;
   SELECT EXISTS (SELECT 1 FROM logistique."T_Commande" c JOIN systeme."T_Utilisateurs" owner_u ON owner_u."IdUser"=parent."ID_UserFk" WHERE c."ID_Commande"=NEW."ID_CommandeFk" AND (parent."TypeObjet"='bon' OR (c."CodeFacture" IS NOT NULL AND btrim(c."CodeFacture")<>'')) AND (parent."IdEntiteFk" IS NOT NULL AND c."IdEntiteFk"=parent."IdEntiteFk")) INTO permitted;
  END IF;
  IF NOT permitted THEN RAISE EXCEPTION 'L’enregistrement ne fait pas partie du périmètre autorisé du dossier.'; END IF;
 END IF;
 NEW."ModifieLe"=CURRENT_TIMESTAMP;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION verifier_dossier_suivi(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.verifier_dossier_suivi() IS 'Contrôle le périmètre propriétaire/catégorie, le mode immuable et les rattachements manuels. Ne modifie jamais le stock ni les mouvements.';

--
-- Name: verifier_inventaire(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.verifier_inventaire() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE h record; a record; BEGIN
 IF TG_TABLE_NAME='T_Inventaire' THEN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Inventaire historique conservé' USING ERRCODE='23514';END IF;
  IF TG_OP='INSERT' AND NEW."Etat"<>'brouillon' THEN RAISE EXCEPTION 'Créez un comptage avant sa validation' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' THEN
   IF OLD."IdEntiteFk"<>NEW."IdEntiteFk" OR OLD."ID_UserFk"<>NEW."ID_UserFk" OR OLD."Etat"='annule' OR
    (OLD."Etat"='valide' AND (NEW."Etat"<>'annule' OR
      (to_jsonb(OLD)-ARRAY['Etat','AnnuleLe','ID_AnnulateurFk','MotifAnnulation','AnnulationRequest','AnnulationHash']) IS DISTINCT FROM
      (to_jsonb(NEW)-ARRAY['Etat','AnnuleLe','ID_AnnulateurFk','MotifAnnulation','AnnulationRequest','AnnulationHash']))) OR
    (OLD."Etat"='brouillon' AND NEW."Etat"='annule')
   THEN RAISE EXCEPTION 'Inventaire historique ou propriétaire immuable' USING ERRCODE='23514';END IF;
   NEW."Version"=OLD."Version"+1;NEW."ModifieLe"=clock_timestamp();
  END IF;RETURN NEW;
 END IF;
 IF TG_OP='UPDATE' AND (OLD."ID_InventaireFk"<>NEW."ID_InventaireFk" OR OLD."ID_ArticleFk"<>NEW."ID_ArticleFk") THEN
  RAISE EXCEPTION 'Identité de ligne conservée' USING ERRCODE='23514';END IF;
 SELECT * INTO h FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=COALESCE(NEW."ID_InventaireFk",OLD."ID_InventaireFk") FOR UPDATE;
 IF h."Etat"='annule' AND TG_OP='UPDATE' AND OLD."ID_CommandeAnnulationFk" IS NULL AND NEW."ID_CommandeAnnulationFk" IS NOT NULL AND
  (to_jsonb(OLD)-'ID_CommandeAnnulationFk')=(to_jsonb(NEW)-'ID_CommandeAnnulationFk') THEN RETURN NEW;END IF;
 IF h."Etat"<>'brouillon' THEN RAISE EXCEPTION 'Un inventaire validé est conservé' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 IF NEW."ID_CommandeAnnulationFk" IS NOT NULL THEN RAISE EXCEPTION 'Annulation réservée à un inventaire validé' USING ERRCODE='23514';END IF;
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";
 IF a."IdEntiteFk"<>h."IdEntiteFk" THEN RAISE EXCEPTION 'Article hors entreprise de l’inventaire' USING ERRCODE='23514';END IF;
 PERFORM logistique.fn_verifier_quantite(a."ID_UniteFk",NEW."QteTheorique");PERFORM logistique.fn_verifier_quantite(a."ID_UniteFk",NEW."QteComptee");
 IF NEW."ID_CommandeCorrectionFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Commande" c JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=c."ID_Commande"
  JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk"
  WHERE c."ID_Commande"=NEW."ID_CommandeCorrectionFk" AND c."IdEntiteFk"=h."IdEntiteFk" AND d."ID_ArticleFk"=NEW."ID_ArticleFk"
  AND d."QteCmdDetail"=abs(NEW."QteComptee"-NEW."QteTheorique") AND
   (NEW."QteComptee">NEW."QteTheorique" AND g."AbrGenerique" ILIKE 'entr%' OR NEW."QteComptee"<NEW."QteTheorique" AND g."AbrGenerique" ILIKE 'sort%')) THEN RAISE EXCEPTION 'Bon d’écart incompatible' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION verifier_inventaire(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.verifier_inventaire() IS 'Autorise une unique annulation motivée, conserve comptage et validation, verrouille le propriétaire et les lignes historiques.';

--
-- Name: verifier_lot_rattachement(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.verifier_lot_rattachement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP='UPDATE' AND (OLD."ID_ArticleFk"<>NEW."ID_ArticleFk" OR OLD."ID_LotArticle"<>NEW."ID_LotArticle") THEN
 RAISE EXCEPTION 'Un lot ne peut pas être déplacé vers un autre article.' USING ERRCODE='23514';
 END IF;
 NEW."NumeroLot"=btrim(NEW."NumeroLot");
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION verifier_lot_rattachement(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.verifier_lot_rattachement() IS 'Normalise le numéro du lot et interdit son transfert vers un autre article.';

--
-- Name: verrouiller_ventilation_lot(); Type: FUNCTION; Schema: logistique; Owner: -
--

CREATE FUNCTION logistique.verrouiller_ventilation_lot() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE lot_id integer; article_id integer; mvt_article integer; mvt_id integer; mvt_sign integer;
BEGIN
 IF TG_OP='UPDATE' AND (OLD."ID_MvtFk"<>NEW."ID_MvtFk" OR OLD."ID_LotArticleFk"<>NEW."ID_LotArticleFk") THEN
 RAISE EXCEPTION 'Un rattachement de lot ne peut pas être transféré.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN lot_id=OLD."ID_LotArticleFk";mvt_id=OLD."ID_MvtFk";ELSE lot_id=NEW."ID_LotArticleFk";mvt_id=NEW."ID_MvtFk";END IF;
 SELECT "ID_ArticleFk" INTO article_id FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=lot_id;
 PERFORM 1 FROM logistique."T_Article" WHERE "ID_Article"=article_id FOR NO KEY UPDATE;
 PERFORM 1 FROM logistique."T_LotArticle" WHERE "ID_LotArticle"=lot_id FOR NO KEY UPDATE;
 IF TG_OP<>'DELETE' THEN
 SELECT "ID_ArticleFk","SigneStock" INTO mvt_article,mvt_sign FROM logistique."V_MouvementStock" WHERE "ID_Mvt"=mvt_id;
 IF mvt_sign IS NULL OR mvt_sign NOT IN (-1,1) THEN RAISE EXCEPTION 'Sens du mouvement de lot inconnu.' USING ERRCODE='23514';END IF;
 IF article_id IS DISTINCT FROM mvt_article THEN RAISE EXCEPTION 'Le lot et le mouvement doivent concerner le même article.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
 END IF;
 RETURN OLD;
END;
$$;

--
-- Name: FUNCTION verrouiller_ventilation_lot(); Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON FUNCTION logistique.verrouiller_ventilation_lot() IS 'Verrouille article puis lot ; vérifie leur cohérence avec le mouvement et conserve le rattachement.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Article; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Article" (
    "ID_Article" integer CONSTRAINT "T_Article_ID_Article_not_null" NOT NULL,
    "ID_TypeArticleFk" integer,
    "ID_CategorieArticleFk" integer,
    "ID_UserFK" integer,
    "ID_UniteFk" integer,
    "DateHeureAuto" timestamp with time zone,
    "CodeArticleExterne" integer,
    "NomArticle" character varying(100) CONSTRAINT "T_Article_NomArticle_not_null" NOT NULL,
    "RefArticle" character varying(255),
    "QteArticle" numeric(14,3) DEFAULT 0 CONSTRAINT "T_Article_QteArticle_not_null" NOT NULL,
    "PUArticle" numeric(12,2) CONSTRAINT "T_Article_PUArticle_not_null" NOT NULL,
    "PVArticle" numeric(12,2) CONSTRAINT "T_Article_PVArticle_not_null" NOT NULL,
    "QteMinArticle" numeric(14,3),
    "PhotoArticle" character varying(255),
    "ObsArticle" text,
    "ValideArticle" boolean DEFAULT true CONSTRAINT "T_Article_ValideArticle_not_null" NOT NULL,
    "DatePeremptionArticle" timestamp with time zone,
    "DatePeremptionAlerteArticle" timestamp with time zone,
    "NbreJoursAlerteArticle" integer,
    "CodeArticleInterne" character varying(243),
    "PoidsUnitaire" numeric(14,6),
    "ID_UnitePoidsFk" integer,
    "InformationArticle" text,
    "ID_DeviseFk" integer DEFAULT logistique.fn_devise_usd() NOT NULL,
    "IdEntiteFk" integer,
    "CreationRequestId" uuid,
    "CreationPayloadHash" character varying(64),
    CONSTRAINT article_creation_demande_coherente CHECK (((("CreationRequestId" IS NULL) AND ("CreationPayloadHash" IS NULL)) OR (("CreationRequestId" IS NOT NULL) AND ("CreationPayloadHash" IS NOT NULL) AND ("ID_UserFK" IS NOT NULL) AND (("CreationPayloadHash")::text ~ '^[a-f0-9]{64}$'::text)))),
    CONSTRAINT article_poids_coherent CHECK (((("PoidsUnitaire" IS NULL) = ("ID_UnitePoidsFk" IS NULL)) AND (("PoidsUnitaire" IS NULL) OR ("PoidsUnitaire" >= (0)::numeric)))),
    CONSTRAINT chk_article_qte_non_negative CHECK ((("QteArticle" IS NULL) OR ("QteArticle" >= (0)::numeric))),
    CONSTRAINT chk_article_qtemin_non_negative CHECK ((("QteMinArticle" IS NULL) OR ("QteMinArticle" >= (0)::numeric))),
    CONSTRAINT ck_article_prix_positifs CHECK (((("PUArticle" IS NULL) OR ("PUArticle" >= (0)::numeric)) AND (("PVArticle" IS NULL) OR ("PVArticle" >= (0)::numeric))))
);

--
-- Name: TABLE "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Article" IS 'Catalogue des articles et stock courant officiel QteArticle, avec prix, unité, seuil et péremption. Les triggers contrôlent les références et historisent les ajustements directs de quantité.';

--
-- Name: COLUMN "T_Article"."ID_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_Article" IS 'Identifiant de l’article.';

--
-- Name: COLUMN "T_Article"."ID_TypeArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_TypeArticleFk" IS 'Type d’article dans la nomenclature de catégorie 46. Relation imposée : FOREIGN KEY ("ID_TypeArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Article"."ID_CategorieArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_CategorieArticleFk" IS 'Catégorie de l’article dans la nomenclature de catégorie 40. Relation imposée : FOREIGN KEY ("ID_CategorieArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Article"."ID_UserFK"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_UserFK" IS 'Utilisateur rattaché à l’article. Relation imposée : FOREIGN KEY ("ID_UserFK") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE NOT VALID.';

--
-- Name: COLUMN "T_Article"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_UniteFk" IS 'Unité de référence de l’article, dans la nomenclature de catégorie 34. Relation imposée : FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Article"."DateHeureAuto"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."DateHeureAuto" IS 'Horodatage automatique enregistré pour l’article.';

--
-- Name: COLUMN "T_Article"."CodeArticleExterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."CodeArticleExterne" IS 'Code de l’article dans un référentiel externe, enregistré sous forme entière.';

--
-- Name: COLUMN "T_Article"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."NomArticle" IS 'Libellé de l’article.';

--
-- Name: COLUMN "T_Article"."RefArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."RefArticle" IS 'Référence descriptive complémentaire de l’article.';

--
-- Name: COLUMN "T_Article"."QteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."QteArticle" IS 'Stock courant officiel de l’article dans son unité de référence ; malgré le type décimal, les routines actuelles refusent les effets fractionnaires historisés en mouvements entiers.';

--
-- Name: COLUMN "T_Article"."PUArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."PUArticle" IS 'Prix unitaire d’achat enregistré sur l’article ; la devise n’est pas portée par cette table.';

--
-- Name: COLUMN "T_Article"."PVArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."PVArticle" IS 'Prix unitaire de vente enregistré sur l’article ; la devise n’est pas portée par cette table.';

--
-- Name: COLUMN "T_Article"."QteMinArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."QteMinArticle" IS 'Seuil minimum exact dans l’unité de stock ; précision identique au stock, NULL signifie absence de seuil.';

--
-- Name: COLUMN "T_Article"."PhotoArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."PhotoArticle" IS 'Référence de la photo de l’article.';

--
-- Name: COLUMN "T_Article"."ObsArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ObsArticle" IS 'Observations enregistrées sur l’article.';

--
-- Name: COLUMN "T_Article"."ValideArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ValideArticle" IS 'Indique si l’article est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "T_Article"."DatePeremptionArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."DatePeremptionArticle" IS 'Date de péremption enregistrée pour l’article ; absence conservée comme date non renseignée dans la qualification.';

--
-- Name: COLUMN "T_Article"."DatePeremptionAlerteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."DatePeremptionAlerteArticle" IS 'Date explicite de début d’alerte avant péremption ; utilisée par les vues avec le délai d’alerte.';

--
-- Name: COLUMN "T_Article"."NbreJoursAlerteArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."NbreJoursAlerteArticle" IS 'Nombre de jours avant péremption déclenchant une alerte dans la vue article.';

--
-- Name: COLUMN "T_Article"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."CodeArticleInterne" IS 'Code catalogue textuel unique dans l’entreprise propriétaire ; deux entreprises distinctes peuvent utiliser le même code. Les références existantes et les valeurs NULL sont conservées.';

--
-- Name: COLUMN "T_Article"."PoidsUnitaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."PoidsUnitaire" IS 'Masse d’une unité de stock ; inconnue si NULL, indépendante de la quantité en stock.';

--
-- Name: COLUMN "T_Article"."ID_UnitePoidsFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_UnitePoidsFk" IS 'Unité de masse du référentiel catégorie 34 (mg, g, kg ou t), distincte de l’unité de stock.';

--
-- Name: COLUMN "T_Article"."InformationArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."InformationArticle" IS 'Description complémentaire et caractéristiques libres du produit, distinctes des remarques ObsArticle. Ne remplace aucune donnée structurée de stock.';

--
-- Name: COLUMN "T_Article"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."ID_DeviseFk" IS 'Devise des prix achat/vente et valorisations du catalogue ; USD historique confirmé. Immuable dès usage par ligne ou mouvement.';

--
-- Name: COLUMN "T_Article"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."IdEntiteFk" IS 'Entreprise propriétaire obligatoire et immuable ; indépendante de l’affectation future de l’auteur.';

--
-- Name: COLUMN "T_Article"."CreationRequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."CreationRequestId" IS 'UUID de creation fourni une seule fois par le formulaire, reserve au serveur pour rejouer une demande sans doubler article, bon ou mouvement; NULL pour les articles historiques.';

--
-- Name: COLUMN "T_Article"."CreationPayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Article"."CreationPayloadHash" IS 'SHA256 du contenu de creation incluant lots et photo normalisee; permet de refuser la reutilisation du meme UUID avec un autre contenu.';

--
-- Name: CONSTRAINT "T_Article_ID_Article_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_ID_Article_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "ID_Article".';

--
-- Name: CONSTRAINT "T_Article_NomArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_NomArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "NomArticle".';

--
-- Name: CONSTRAINT "T_Article_QteArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_QteArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "QteArticle".';

--
-- Name: CONSTRAINT "T_Article_PUArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_PUArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "PUArticle".';

--
-- Name: CONSTRAINT "T_Article_PVArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_PVArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "PVArticle".';

--
-- Name: CONSTRAINT "T_Article_ValideArticle_not_null" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_ValideArticle_not_null" ON logistique."T_Article" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Article". Définition : NOT NULL "ValideArticle".';

--
-- Name: CONSTRAINT article_creation_demande_coherente ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT article_creation_demande_coherente ON logistique."T_Article" IS 'UUID et empreinte SHA256 presents ensemble ou tous deux absents sur les articles historiques.';

--
-- Name: CONSTRAINT chk_article_qte_non_negative ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_article_qte_non_negative ON logistique."T_Article" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Article". Définition : CHECK ("QteArticle" IS NULL OR "QteArticle" >= 0::numeric).';

--
-- Name: CONSTRAINT chk_article_qtemin_non_negative ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_article_qtemin_non_negative ON logistique."T_Article" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Article". Définition : CHECK ("QteMinArticle" IS NULL OR "QteMinArticle" >= 0).';

--
-- Name: CONSTRAINT ck_article_prix_positifs ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_article_prix_positifs ON logistique."T_Article" IS 'Intégrité imposée par PostgreSQL : CHECK (("PUArticle" IS NULL OR "PUArticle" >= 0::numeric) AND ("PVArticle" IS NULL OR "PVArticle" >= 0::numeric))';

--
-- Name: T_Article_ID_Article_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Article" ALTER COLUMN "ID_Article" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Article_ID_Article_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Article_ID_Article_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Article_ID_Article_seq" IS 'Séquence de génération de "logistique"."T_Article"."ID_Article". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Avoir; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Avoir" (
    "ID_Avoir" bigint NOT NULL,
    "ID_FactureFk" bigint NOT NULL,
    "ID_CommandeFk" integer NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "ID_UserFk" integer NOT NULL,
    "CodeAvoir" text NOT NULL,
    "DateAvoir" timestamp with time zone NOT NULL,
    "Motif" text NOT NULL,
    "ID_DeviseFk" integer NOT NULL,
    "DeviseCode" text NOT NULL,
    "MontantTTC" numeric(12,2) NOT NULL,
    "RequestId" uuid NOT NULL,
    "PayloadHash" text NOT NULL,
    "TransactionCreation" bigint DEFAULT txid_current() NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_Avoir_MontantTTC_check" CHECK (("MontantTTC" > (0)::numeric)),
    CONSTRAINT "T_Avoir_Motif_check" CHECK (((length(btrim("Motif")) >= 3) AND (length(btrim("Motif")) <= 2000))),
    CONSTRAINT "T_Avoir_PayloadHash_check" CHECK (("PayloadHash" ~ '^[a-f0-9]{64}$'::text))
);

--
-- Name: TABLE "T_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Avoir" IS 'Avoir immuable correspondant aux retours postérieurs à une facture émise ; sans effet de stock supplémentaire.';

--
-- Name: COLUMN "T_Avoir"."ID_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."ID_Avoir" IS 'Identifiant interne et stable de l’avoir émis.';

--
-- Name: COLUMN "T_Avoir"."ID_FactureFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."ID_FactureFk" IS 'Facture originale et immuable à laquelle se rapporte l’avoir.';

--
-- Name: COLUMN "T_Avoir"."ID_CommandeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."ID_CommandeFk" IS 'Bon original facturé dont les articles ont été retournés.';

--
-- Name: COLUMN "T_Avoir"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."IdEntiteFk" IS 'Entreprise propriétaire durable de l’avoir et de sa facture.';

--
-- Name: COLUMN "T_Avoir"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."ID_UserFk" IS 'Auteur réel de l’émission, imputation ou remboursement.';

--
-- Name: COLUMN "T_Avoir"."CodeAvoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."CodeAvoir" IS 'Référence automatique et immuable avr-identifiant.';

--
-- Name: COLUMN "T_Avoir"."DateAvoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."DateAvoir" IS 'Date et heure effectives de l’émission de l’avoir.';

--
-- Name: COLUMN "T_Avoir"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."Motif" IS 'Justification métier de l’avoir après retour facturé.';

--
-- Name: COLUMN "T_Avoir"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."ID_DeviseFk" IS 'Devise de la facture d’origine, issue du référentiel.';

--
-- Name: COLUMN "T_Avoir"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."DeviseCode" IS 'Code de la devise de la facture, conservé à l’émission.';

--
-- Name: COLUMN "T_Avoir"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."MontantTTC" IS 'Montant émis égal à la somme des lignes.';

--
-- Name: COLUMN "T_Avoir"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."RequestId" IS 'Identifiant unique du traitement empêchant les doubles envois.';

--
-- Name: COLUMN "T_Avoir"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."PayloadHash" IS 'Empreinte canonique à comparer lors du rejeu d’une demande.';

--
-- Name: COLUMN "T_Avoir"."TransactionCreation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."TransactionCreation" IS 'Transaction autorisée à insérer les lignes du nouvel avoir.';

--
-- Name: COLUMN "T_Avoir"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Avoir"."CreeLe" IS 'Horodatage serveur de l’enregistrement.';

--
-- Name: T_AvoirAffectation; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_AvoirAffectation" (
    "ID_Affectation" bigint NOT NULL,
    "ID_AvoirFk" bigint NOT NULL,
    "ID_CommandeCibleFk" integer NOT NULL,
    "Montant" numeric(12,2) NOT NULL,
    "ID_UserFk" integer NOT NULL,
    "RequestId" uuid NOT NULL,
    "PayloadHash" text NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_AvoirAffectation_Montant_check" CHECK (("Montant" > (0)::numeric))
);

--
-- Name: TABLE "T_AvoirAffectation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_AvoirAffectation" IS 'Imputation immuable d’un avoir sur un solde de facture de même entreprise, devise et tiers.';

--
-- Name: COLUMN "T_AvoirAffectation"."ID_Affectation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."ID_Affectation" IS 'Identifiant stable de l’imputation.';

--
-- Name: COLUMN "T_AvoirAffectation"."ID_AvoirFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."ID_AvoirFk" IS 'Avoir émis dont dépend cette ligne, imputation ou remboursement.';

--
-- Name: COLUMN "T_AvoirAffectation"."ID_CommandeCibleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."ID_CommandeCibleFk" IS 'Bon dont la facture reçoit une imputation, sans effet de stock.';

--
-- Name: COLUMN "T_AvoirAffectation"."Montant"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."Montant" IS 'Montant positif dans la devise de l’avoir.';

--
-- Name: COLUMN "T_AvoirAffectation"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."ID_UserFk" IS 'Auteur réel de l’émission, imputation ou remboursement.';

--
-- Name: COLUMN "T_AvoirAffectation"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."RequestId" IS 'Identifiant unique du traitement empêchant les doubles envois.';

--
-- Name: COLUMN "T_AvoirAffectation"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."PayloadHash" IS 'Empreinte canonique à comparer lors du rejeu d’une demande.';

--
-- Name: COLUMN "T_AvoirAffectation"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirAffectation"."CreeLe" IS 'Horodatage serveur de l’enregistrement.';

--
-- Name: T_AvoirAffectation_ID_Affectation_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_AvoirAffectation" ALTER COLUMN "ID_Affectation" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_AvoirAffectation_ID_Affectation_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_AvoirLigne; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_AvoirLigne" (
    "ID_AvoirFk" bigint NOT NULL,
    "ID_ArticleFk" integer NOT NULL,
    "NomArticle" text NOT NULL,
    "Unite" text,
    "Quantite" numeric(14,3) NOT NULL,
    "PUAvoir" numeric(12,2) NOT NULL,
    "MontantLigne" numeric(12,2) NOT NULL,
    CONSTRAINT "T_AvoirLigne_PUAvoir_check" CHECK (("PUAvoir" >= (0)::numeric)),
    CONSTRAINT "T_AvoirLigne_Quantite_check" CHECK (("Quantite" > (0)::numeric)),
    CONSTRAINT "T_AvoirLigne_check" CHECK (("MontantLigne" = round(("Quantite" * "PUAvoir"), 2)))
);

--
-- Name: TABLE "T_AvoirLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_AvoirLigne" IS 'Quantités retournées après facturation, au prix de l’instantané original, créditées une seule fois.';

--
-- Name: COLUMN "T_AvoirLigne"."ID_AvoirFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirLigne"."ID_AvoirFk" IS 'Avoir émis dont dépend cette ligne, imputation ou remboursement.';

--
-- Name: COLUMN "T_AvoirLigne"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirLigne"."ID_ArticleFk" IS 'Article de la ligne facturée à l’origine.';

--
-- Name: COLUMN "T_AvoirLigne"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirLigne"."NomArticle" IS 'Désignation figée sur la facture d’origine.';

--
-- Name: COLUMN "T_AvoirLigne"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirLigne"."Unite" IS 'Unité figée sur la facture d’origine.';

--
-- Name: COLUMN "T_AvoirLigne"."Quantite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirLigne"."Quantite" IS 'Quantité retournée après émission, non encore créditée, dans l’unité facturée.';

--
-- Name: COLUMN "T_AvoirLigne"."PUAvoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirLigne"."PUAvoir" IS 'Prix unitaire figé de la facture d’origine.';

--
-- Name: COLUMN "T_AvoirLigne"."MontantLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_AvoirLigne"."MontantLigne" IS 'Quantité au prix facturé, arrondie à deux décimales.';

--
-- Name: T_Avoir_ID_Avoir_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Avoir" ALTER COLUMN "ID_Avoir" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_Avoir_ID_Avoir_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_BonCodeHistorique; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_BonCodeHistorique" (
    "ID_BonCodeHistorique" bigint CONSTRAINT "T_BonCodeHistorique_ID_BonCodeHistorique_not_null" NOT NULL,
    "ID_Commande" integer CONSTRAINT "T_BonCodeHistorique_ID_Commande_not_null" NOT NULL,
    "IdEntiteFk" integer,
    "AncienCodeCmd" character varying(20),
    "NouveauCodeCmd" character varying(20) CONSTRAINT "T_BonCodeHistorique_NouveauCodeCmd_not_null" NOT NULL,
    "RenumeroteLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_BonCodeHistorique_RenumeroteLe_not_null" NOT NULL,
    "Motif" text CONSTRAINT "T_BonCodeHistorique_Motif_not_null" NOT NULL,
    "VersionMigration" character varying(20) CONSTRAINT "T_BonCodeHistorique_VersionMigration_not_null" NOT NULL,
    "UtilisateurBase" text DEFAULT CURRENT_USER CONSTRAINT "T_BonCodeHistorique_UtilisateurBase_not_null" NOT NULL,
    CONSTRAINT bon_code_historique_identite CHECK (("ID_Commande" > 0)),
    CONSTRAINT bon_code_historique_motif CHECK (((length(btrim("Motif")) >= 10) AND (length(btrim("Motif")) <= 1000))),
    CONSTRAINT bon_code_historique_nouveau CHECK (((("NouveauCodeCmd")::text ~ '^(BE|BS|CMD)-[1-9][0-9]*$'::text) AND (regexp_replace(("NouveauCodeCmd")::text, '^[A-Z]+-'::text, ''::text) = ("ID_Commande")::text))),
    CONSTRAINT bon_code_historique_utilisateur CHECK ((length(btrim("UtilisateurBase")) > 0)),
    CONSTRAINT bon_code_historique_version CHECK ((("VersionMigration")::text = '20261028_06'::text))
);

--
-- Name: TABLE "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_BonCodeHistorique" IS 'Correspondances factuelles de la reprise autorisée06 : anciens codes vers BE-/BS-/CMD-, date, entreprise, motif et utilisateur SQL. Journal fermé et immuable ; conserve la référence même après suppression d’un bon non protégé. Aucun CRUD applicatif.';

--
-- Name: COLUMN "T_BonCodeHistorique"."ID_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."ID_BonCodeHistorique" IS 'Identité technique de la correspondance ; ne réalloue jamais l’identité du bon.';

--
-- Name: COLUMN "T_BonCodeHistorique"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."ID_Commande" IS 'Identité stable du bon renommé, sans FK de suppression pour conserver la preuve historique.';

--
-- Name: COLUMN "T_BonCodeHistorique"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."IdEntiteFk" IS 'Entreprise propriétaire constatée lors du renommage ; la conservation historique ne dépend pas d’une suppression ultérieure de l’entreprise.';

--
-- Name: COLUMN "T_BonCodeHistorique"."AncienCodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."AncienCodeCmd" IS 'Code exact avant06 ; NULL reste l’absence historique réelle de code.';

--
-- Name: COLUMN "T_BonCodeHistorique"."NouveauCodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."NouveauCodeCmd" IS 'Code canonique BE-ID, BS-ID ou CMD-ID attribué au même identifiant de bon.';

--
-- Name: COLUMN "T_BonCodeHistorique"."RenumeroteLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."RenumeroteLe" IS 'Instant PostgreSQL réel du changement de nomenclature ; distingue les références des documents émis avant et après la reprise.';

--
-- Name: COLUMN "T_BonCodeHistorique"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."Motif" IS 'Motif de la reprise documentaire autorisée ; aucun ajustement de stock ou de montant.';

--
-- Name: COLUMN "T_BonCodeHistorique"."VersionMigration"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."VersionMigration" IS 'Migration ayant produit cette correspondance ; valeur contrôlée 20261028_06.';

--
-- Name: COLUMN "T_BonCodeHistorique"."UtilisateurBase"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_BonCodeHistorique"."UtilisateurBase" IS 'Utilisateur PostgreSQL ayant exécuté la reprise ; ne prétend pas identifier une personne applicative absente du contexte de migration.';

--
-- Name: CONSTRAINT "T_BonCodeHistorique_ID_BonCodeHistorique_not_null" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_ID_BonCodeHistorique_not_null" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT "T_BonCodeHistorique_ID_Commande_not_null" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_ID_Commande_not_null" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT "T_BonCodeHistorique_NouveauCodeCmd_not_null" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_NouveauCodeCmd_not_null" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT "T_BonCodeHistorique_RenumeroteLe_not_null" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_RenumeroteLe_not_null" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT "T_BonCodeHistorique_Motif_not_null" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_Motif_not_null" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT "T_BonCodeHistorique_VersionMigration_not_null" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_VersionMigration_not_null" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT "T_BonCodeHistorique_UtilisateurBase_not_null" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_UtilisateurBase_not_null" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT bon_code_historique_identite ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT bon_code_historique_identite ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT bon_code_historique_motif ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT bon_code_historique_motif ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT bon_code_historique_nouveau ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT bon_code_historique_nouveau ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT bon_code_historique_utilisateur ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT bon_code_historique_utilisateur ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: CONSTRAINT bon_code_historique_version ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT bon_code_historique_version ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: T_BonCodeHistorique_ID_BonCodeHistorique_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_BonCodeHistorique" ALTER COLUMN "ID_BonCodeHistorique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_BonCodeHistorique_ID_BonCodeHistorique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_BonCodeHistorique_ID_BonCodeHistorique_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_BonCodeHistorique_ID_BonCodeHistorique_seq" IS 'Séquence technique du journal de correspondance ; indépendante des identités et numéros des bons.';

--
-- Name: T_CategorieDossierSuivi; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_CategorieDossierSuivi" (
    "ID_CategorieDossierSuivi" integer NOT NULL,
    "ID_UserFk" integer NOT NULL,
    "IdEntiteFk" integer,
    "Nom" character varying(80) NOT NULL,
    "Couleur" character varying(10) DEFAULT 'bleu'::character varying NOT NULL,
    "Actif" boolean DEFAULT true NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_CategorieDossierSuivi_Couleur_check" CHECK ((("Couleur")::text = ANY ((ARRAY['vert'::character varying, 'rouge'::character varying, 'orange'::character varying, 'bleu'::character varying, 'violet'::character varying, 'ardoise'::character varying])::text[]))),
    CONSTRAINT "T_CategorieDossierSuivi_Nom_check" CHECK ((btrim(("Nom")::text) <> ''::text))
);

--
-- Name: TABLE "T_CategorieDossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_CategorieDossierSuivi" IS 'Dossiers de suivi privés : articles, bons de stock ou factures ; aucun effet sur les écritures métier.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."ID_CategorieDossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."ID_CategorieDossierSuivi" IS 'Identifiant permanent de la catégorie de dossiers.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."IdEntiteFk" IS 'Organisation du contexte à la création ; nullable et immuable.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."Nom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."Couleur"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."CreeLe" IS 'Instant de création.';

--
-- Name: COLUMN "T_CategorieDossierSuivi"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';

--
-- Name: T_CategorieDossierSuivi_ID_CategorieDossierSuivi_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_CategorieDossierSuivi" ALTER COLUMN "ID_CategorieDossierSuivi" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_CategorieDossierSuivi_ID_CategorieDossierSuivi_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Client; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Client" (
    "ID_Client" bigint CONSTRAINT "T_Client_ID_Client_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Client_IdEntiteFk_not_null" NOT NULL,
    "Nature" text DEFAULT 'personne'::text CONSTRAINT "T_Client_Nature_not_null" NOT NULL,
    "ID_TypeClientFk" integer CONSTRAINT "T_Client_ID_TypeClientFk_not_null" NOT NULL,
    "Nom" text CONSTRAINT "T_Client_Nom_not_null" NOT NULL,
    "Email" text,
    "Telephone" text,
    "Adresse" text,
    "IdUserFk" integer,
    "IdProfessionnelFk" integer,
    "IdEntiteRepresenteeFk" integer,
    "ObsClient" text,
    "Actif" boolean DEFAULT true CONSTRAINT "T_Client_Actif_not_null" NOT NULL,
    "CreeParUserFk" integer CONSTRAINT "T_Client_CreeParUserFk_not_null" NOT NULL,
    "ModifieParUserFk" integer CONSTRAINT "T_Client_ModifieParUserFk_not_null" NOT NULL,
    "DateCreation" timestamp with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Client_DateCreation_not_null" NOT NULL,
    "DateModification" timestamp with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Client_DateModification_not_null" NOT NULL,
    CONSTRAINT "T_Client_Nature_check" CHECK (("Nature" = ANY (ARRAY['personne'::text, 'entreprise'::text]))),
    CONSTRAINT "T_Client_Nom_check" CHECK ((btrim("Nom") <> ''::text))
);

--
-- Name: TABLE "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Client" IS 'Tiers collaboratif appartenant durablement à une entreprise, utilisable comme client et fournisseur, sans compte obligatoire.';

--
-- Name: COLUMN "T_Client"."ID_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."ID_Client" IS 'Attribut du tiers : ID_Client. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."IdEntiteFk" IS 'Attribut du tiers : IdEntiteFk. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."Nature"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."Nature" IS 'Attribut du tiers : Nature. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."ID_TypeClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."ID_TypeClientFk" IS 'Attribut du tiers : ID_TypeClientFk. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."Nom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."Nom" IS 'Attribut du tiers : Nom. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."Email"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."Email" IS 'Attribut du tiers : Email. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."Telephone"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."Telephone" IS 'Attribut du tiers : Telephone. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."Adresse"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."Adresse" IS 'Attribut du tiers : Adresse. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."IdUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."IdUserFk" IS 'Attribut du tiers : IdUserFk. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."IdProfessionnelFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."IdProfessionnelFk" IS 'Attribut du tiers : IdProfessionnelFk. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."IdEntiteRepresenteeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."IdEntiteRepresenteeFk" IS 'Attribut du tiers : IdEntiteRepresenteeFk. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."ObsClient"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."ObsClient" IS 'Attribut du tiers : ObsClient. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."Actif" IS 'Attribut du tiers : Actif. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."CreeParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."CreeParUserFk" IS 'Attribut du tiers : CreeParUserFk. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."ModifieParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."ModifieParUserFk" IS 'Attribut du tiers : ModifieParUserFk. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."DateCreation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."DateCreation" IS 'Attribut du tiers : DateCreation. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: COLUMN "T_Client"."DateModification"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Client"."DateModification" IS 'Attribut du tiers : DateModification. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.';

--
-- Name: CONSTRAINT "T_Client_ID_Client_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_ID_Client_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_IdEntiteFk_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_IdEntiteFk_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_Nature_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_Nature_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_ID_TypeClientFk_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_ID_TypeClientFk_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_Nom_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_Nom_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_Actif_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_Actif_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_CreeParUserFk_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_CreeParUserFk_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_ModifieParUserFk_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_ModifieParUserFk_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_DateCreation_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_DateCreation_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_DateModification_not_null" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_DateModification_not_null" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_Nature_check" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_Nature_check" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: CONSTRAINT "T_Client_Nom_check" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_Nom_check" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Client_ID_Client_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Client" ALTER COLUMN "ID_Client" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_Client_ID_Client_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Commande; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Commande" (
    "ID_Commande" integer CONSTRAINT "T_Commande_ID_Commande_not_null" NOT NULL,
    "ID_TypeCmdFk" integer,
    "ID_StatutCmdFk" integer,
    "ID_ClientFk" integer,
    "ID_UserFk" integer,
    "geolocalisationCmd" character varying(255),
    "DateHeureAutoCmd" timestamp with time zone,
    "DateCmd" timestamp with time zone,
    "CodeCmd" character varying(20),
    "RefCmd" character varying(255),
    "MontantHT" numeric(12,2),
    "MontantTTC" numeric(12,2),
    "UrlBL" character varying(255),
    "ObsCmd" character varying(255),
    "SelectCmd" boolean,
    "DateHeureAutoFacture" timestamp with time zone,
    "DateFacture" timestamp with time zone,
    "CodeFacture" character varying(255),
    "MontantRegleFacture" numeric(12,2),
    "MontantResteFacture" numeric(12,2),
    "StatusFacture" character varying(243),
    "ValideRemiseFacture" boolean,
    "UrlFacture" character varying(255),
    "ID_ConditionPaiementFk" integer,
    "DateEcheancePaiement" timestamp with time zone,
    "ID_ModePaiementFk" integer,
    "NomClientSaisi" character varying(255),
    "ID_DeviseFk" integer DEFAULT logistique.fn_devise_usd() NOT NULL,
    "IdEntiteFk" integer,
    "ID_TiersFk" bigint,
    "ID_DestinationFk" integer,
    "OrigineBon" text,
    "ID_ArticleInitialFk" integer,
    CONSTRAINT bon_origine_initiale_coherente CHECK (((("OrigineBon" IS NULL) AND ("ID_ArticleInitialFk" IS NULL)) OR (("OrigineBon" IS NOT NULL) AND ("OrigineBon" = ANY (ARRAY['stock_initial'::text, 'reprise_mouvement'::text])) AND ("ID_ArticleInitialFk" IS NOT NULL)))),
    CONSTRAINT chk_cmd_montants_non_negatifs CHECK (((("MontantHT" IS NULL) OR ("MontantHT" >= (0)::numeric)) AND (("MontantTTC" IS NULL) OR ("MontantTTC" >= (0)::numeric)) AND (("MontantRegleFacture" IS NULL) OR ("MontantRegleFacture" >= (0)::numeric)) AND (("MontantResteFacture" IS NULL) OR ("MontantResteFacture" >= (0)::numeric))))
);

--
-- Name: TABLE "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Commande" IS 'Documents d’articles typés par le référentiel : BE entrée physique, BS sortie physique, CMD préparation sans stock. Identités et numéros émis immuables ; facturation dédiée aux sorties autorisées.';

--
-- Name: COLUMN "T_Commande"."ID_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_Commande" IS 'Identifiant de la commande.';

--
-- Name: COLUMN "T_Commande"."ID_TypeCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_TypeCmdFk" IS 'Valeur Type de commande dans le référentiel : entr*/sort* pour les mouvements physiques, CMD exact pour le bon de commande sans stock, facture ni restitution. Une nature inconnue est refusée.';

--
-- Name: COLUMN "T_Commande"."ID_StatutCmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_StatutCmdFk" IS 'Statut de commande dans la nomenclature de catégorie 28. Relation imposée : FOREIGN KEY ("ID_StatutCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Commande"."ID_ClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_ClientFk" IS 'Identifiant client enregistré pour l’opération ; distinct du nom client saisi librement.';

--
-- Name: COLUMN "T_Commande"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_UserFk" IS 'Utilisateur rattaché à la commande. Relation imposée : FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE NOT VALID.';

--
-- Name: COLUMN "T_Commande"."geolocalisationCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."geolocalisationCmd" IS 'Localisation enregistrée librement pour la commande, sous forme textuelle.';

--
-- Name: COLUMN "T_Commande"."DateHeureAutoCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateHeureAutoCmd" IS 'Horodatage automatique enregistré pour la commande.';

--
-- Name: COLUMN "T_Commande"."DateCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateCmd" IS 'Date métier de la commande, distincte de son horodatage automatique.';

--
-- Name: COLUMN "T_Commande"."CodeCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."CodeCmd" IS 'Code serveur immuable BE-ID pour une entrée effective, BS-ID pour une sortie, CMD-ID pour une commande préparatoire. Les anciens codes renommés par06 restent dans T_BonCodeHistorique.';

--
-- Name: COLUMN "T_Commande"."RefCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."RefCmd" IS 'Référence complémentaire de la commande.';

--
-- Name: COLUMN "T_Commande"."MontantHT"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantHT" IS 'Montant hors taxes enregistré sur la commande ; la routine actuelle de totaux le calcule depuis les lignes.';

--
-- Name: COLUMN "T_Commande"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantTTC" IS 'Montant toutes taxes comprises enregistré sur la commande ; la routine actuelle de totaux le fixe au même montant que MontantHT, sans calcul de taxe distinct.';

--
-- Name: COLUMN "T_Commande"."UrlBL"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."UrlBL" IS 'Référence du bon de livraison associé à la commande.';

--
-- Name: COLUMN "T_Commande"."ObsCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ObsCmd" IS 'Observations enregistrées sur la commande.';

--
-- Name: COLUMN "T_Commande"."SelectCmd"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."SelectCmd" IS 'Indicateur de sélection enregistré sur la commande.';

--
-- Name: COLUMN "T_Commande"."DateHeureAutoFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateHeureAutoFacture" IS 'Horodatage automatique enregistré lors de la facturation.';

--
-- Name: COLUMN "T_Commande"."DateFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateFacture" IS 'Date métier de facturation.';

--
-- Name: COLUMN "T_Commande"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."CodeFacture" IS 'Miroir du numéro de facture fac-ID_Commande ; NULL avant émission ; immuable ensuite.';

--
-- Name: COLUMN "T_Commande"."MontantRegleFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantRegleFacture" IS 'Montant réglé enregistré sur l’en-tête de facture ; distinct de la somme des écritures de règlement.';

--
-- Name: COLUMN "T_Commande"."MontantResteFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."MontantResteFacture" IS 'Reste enregistré sur l’en-tête de facture ; à distinguer du reste recalculé dans les vues.';

--
-- Name: COLUMN "T_Commande"."StatusFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."StatusFacture" IS 'Statut textuel enregistré de la facture ; le verrou SQL actuel compare exactement la valeur Clôturée.';

--
-- Name: COLUMN "T_Commande"."ValideRemiseFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ValideRemiseFacture" IS 'Indicateur de validation de remise enregistré sur la facture.';

--
-- Name: COLUMN "T_Commande"."UrlFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."UrlFacture" IS 'Référence du document de facture associé à la commande.';

--
-- Name: COLUMN "T_Commande"."ID_ConditionPaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_ConditionPaiementFk" IS 'Condition de paiement de la commande, dans la nomenclature de catégorie 37. Relation imposée : FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Commande"."DateEcheancePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."DateEcheancePaiement" IS 'Échéance de paiement de la facture ; utilisée pour les contrôles de retard.';

--
-- Name: COLUMN "T_Commande"."ID_ModePaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_ModePaiementFk" IS 'Mode de paiement prévu sur la commande, dans la nomenclature de catégorie 36. Relation imposée : FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Commande"."NomClientSaisi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."NomClientSaisi" IS 'Nom du client saisi librement sur la commande, distinct d’un rattachement par identifiant.';

--
-- Name: COLUMN "T_Commande"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_DeviseFk" IS 'Devise unique des prix de ligne, totaux du bon et de sa facture ; aucun taux implicite. Immuable dès ligne, mouvement ou règlement.';

--
-- Name: COLUMN "T_Commande"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."IdEntiteFk" IS 'Entreprise propriétaire obligatoire et immuable ; indépendante de l’affectation future de l’auteur.';

--
-- Name: COLUMN "T_Commande"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_TiersFk" IS 'Nouvelle FK explicite vers T_Client ; ne convertit pas les anciens ID_ClientFk ambigus.';

--
-- Name: COLUMN "T_Commande"."ID_DestinationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_DestinationFk" IS 'Destination facultative référencée au dernier niveau géographique existant ; le texte historique geolocalisationCmd reste conservé sans conversion.';

--
-- Name: COLUMN "T_Commande"."OrigineBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."OrigineBon" IS 'Origine technique distincte du sens Entree/Sortie: stock_initial pour creation depuis Articles, reprise_mouvement pour rattachement historique sans effet stock, NULL pour les autres flux existants.';

--
-- Name: COLUMN "T_Commande"."ID_ArticleInitialFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Commande"."ID_ArticleInitialFk" IS 'Article source du bon technique de stock initial ou de reprise documentaire; FK durable, jamais un fournisseur fictif.';

--
-- Name: CONSTRAINT "T_Commande_ID_Commande_not_null" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Commande_ID_Commande_not_null" ON logistique."T_Commande" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Commande". Définition : NOT NULL "ID_Commande".';

--
-- Name: CONSTRAINT bon_origine_initiale_coherente ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT bon_origine_initiale_coherente ON logistique."T_Commande" IS 'Origine interne et article source obligatoirement associes.';

--
-- Name: CONSTRAINT chk_cmd_montants_non_negatifs ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_cmd_montants_non_negatifs ON logistique."T_Commande" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Commande". Définition : CHECK (("MontantHT" IS NULL OR "MontantHT" >= 0::numeric) AND ("MontantTTC" IS NULL OR "MontantTTC" >= 0::numeric) AND ("MontantRegleFacture" IS NULL OR "MontantRegleFacture" >= 0::numeric) AND ("MontantResteFacture" IS NULL OR "MontantResteFacture" >= 0::numeric)).';

--
-- Name: T_CommandeDetail; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_CommandeDetail" (
    "ID_CmdFk" integer CONSTRAINT "T_CommandeDetail_ID_CmdFk_not_null" NOT NULL,
    "ID_ArticleFk" integer CONSTRAINT "T_CommandeDetail_ID_ArticleFk_not_null" NOT NULL,
    "QteCmdDetail" numeric(14,3),
    "PUCmdDetail" numeric(12,2),
    "ObsCmdDetail" text,
    "RemiseCmdDetail" boolean,
    "LieuCmdDetail" integer,
    "SelectCmdDetail" boolean,
    CONSTRAINT chk_cmddetail_qte_non_negative CHECK ((("QteCmdDetail" IS NULL) OR ("QteCmdDetail" >= (0)::numeric))),
    CONSTRAINT ck_ligne_prix_positif CHECK ((("PUCmdDetail" IS NULL) OR ("PUCmdDetail" >= (0)::numeric)))
);

--
-- Name: TABLE "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_CommandeDetail" IS 'Articles et prix convenus d’un bon ; totaux exacts partagés. BE/BS pilotent un seul mouvement par ligne ; CMD ne produit aucun stock, lot, mouvement ou coût.';

--
-- Name: COLUMN "T_CommandeDetail"."ID_CmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."ID_CmdFk" IS 'Commande à laquelle appartient la ligne. Relation imposée : FOREIGN KEY ("ID_CmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: COLUMN "T_CommandeDetail"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."ID_ArticleFk" IS 'Article rattaché à la ligne ou au mouvement. Relation imposée : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE NOT VALID.';

--
-- Name: COLUMN "T_CommandeDetail"."QteCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."QteCmdDetail" IS 'Quantité strictement positive exacte, précision0..3 autorisée explicitement par unité de stock.';

--
-- Name: COLUMN "T_CommandeDetail"."PUCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."PUCmdDetail" IS 'Prix unitaire propre à la ligne ; source du prix historique du mouvement de commande.';

--
-- Name: COLUMN "T_CommandeDetail"."ObsCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."ObsCmdDetail" IS 'Observations enregistrées sur la ligne de commande.';

--
-- Name: COLUMN "T_CommandeDetail"."RemiseCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."RemiseCmdDetail" IS 'Indicateur de remise enregistré sur la ligne ; ce booléen ne représente pas un taux de remise.';

--
-- Name: COLUMN "T_CommandeDetail"."LieuCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."LieuCmdDetail" IS 'Identifiant de lieu enregistré pour la ligne de commande ; sa signification dépend du paramétrage métier.';

--
-- Name: COLUMN "T_CommandeDetail"."SelectCmdDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_CommandeDetail"."SelectCmdDetail" IS 'Indicateur de sélection enregistré sur la ligne de commande.';

--
-- Name: CONSTRAINT "T_CommandeDetail_ID_CmdFk_not_null" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_CommandeDetail_ID_CmdFk_not_null" ON logistique."T_CommandeDetail" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_CommandeDetail". Définition : NOT NULL "ID_CmdFk".';

--
-- Name: CONSTRAINT "T_CommandeDetail_ID_ArticleFk_not_null" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_CommandeDetail_ID_ArticleFk_not_null" ON logistique."T_CommandeDetail" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_CommandeDetail". Définition : NOT NULL "ID_ArticleFk".';

--
-- Name: CONSTRAINT chk_cmddetail_qte_non_negative ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_cmddetail_qte_non_negative ON logistique."T_CommandeDetail" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_CommandeDetail". Définition : CHECK ("QteCmdDetail" IS NULL OR "QteCmdDetail" >= 0::numeric).';

--
-- Name: CONSTRAINT ck_ligne_prix_positif ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_ligne_prix_positif ON logistique."T_CommandeDetail" IS 'Intégrité imposée par PostgreSQL : CHECK ("PUCmdDetail" IS NULL OR "PUCmdDetail" >= 0::numeric)';

--
-- Name: T_Commande_ID_Commande_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Commande" ALTER COLUMN "ID_Commande" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Commande_ID_Commande_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Commande_ID_Commande_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Commande_ID_Commande_seq" IS 'Séquence de génération de "logistique"."T_Commande"."ID_Commande". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_DocumentIdentite; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_DocumentIdentite" (
    "ID_DocumentIdentite" bigint NOT NULL,
    "TypeObjet" text NOT NULL,
    "ID_Objet" bigint NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "IdentiteEmetteur" jsonb NOT NULL,
    "IdentiteTiers" jsonb,
    "RepriseHistorique" boolean DEFAULT false NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_DocumentIdentite_ID_Objet_check" CHECK (("ID_Objet" > 0)),
    CONSTRAINT "T_DocumentIdentite_IdentiteEmetteur_check" CHECK ((jsonb_typeof("IdentiteEmetteur") = 'object'::text)),
    CONSTRAINT "T_DocumentIdentite_TypeObjet_check" CHECK (("TypeObjet" = ANY (ARRAY['bon'::text, 'facture'::text, 'reglement'::text, 'avoir'::text])))
);

--
-- Name: TABLE "T_DocumentIdentite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_DocumentIdentite" IS 'Instantané privé de l’identité de l’émetteur et du tiers à la création du document ; reprises historiques signalées.';

--
-- Name: COLUMN "T_DocumentIdentite"."ID_DocumentIdentite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."ID_DocumentIdentite" IS 'Champ documentaire ID_DocumentIdentite du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_DocumentIdentite"."TypeObjet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."TypeObjet" IS 'Champ documentaire TypeObjet du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_DocumentIdentite"."ID_Objet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."ID_Objet" IS 'Champ documentaire ID_Objet du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_DocumentIdentite"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."IdEntiteFk" IS 'Entreprise propriétaire du document, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "T_DocumentIdentite"."IdentiteEmetteur"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."IdentiteEmetteur" IS 'Nom et coordonnées de l’entreprise figés pour l’édition du document.';

--
-- Name: COLUMN "T_DocumentIdentite"."IdentiteTiers"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."IdentiteTiers" IS 'Identité facultative du client ou fournisseur à la création du document.';

--
-- Name: COLUMN "T_DocumentIdentite"."RepriseHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."RepriseHistorique" IS 'Identité reprise lors de l’installation, sans prétendre connaître l’identité antérieure.';

--
-- Name: COLUMN "T_DocumentIdentite"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DocumentIdentite"."CreeLe" IS 'Champ documentaire CreeLe du justificatif ou de son identité historique.';

--
-- Name: T_DocumentIdentite_ID_DocumentIdentite_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_DocumentIdentite" ALTER COLUMN "ID_DocumentIdentite" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_DocumentIdentite_ID_DocumentIdentite_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_DossierSuivi; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_DossierSuivi" (
    "ID_DossierSuivi" integer NOT NULL,
    "ID_UserFk" integer NOT NULL,
    "IdEntiteFk" integer,
    "ID_CategorieDossierSuiviFk" integer,
    "Nom" character varying(120) NOT NULL,
    "Description" character varying(1000) DEFAULT ''::character varying NOT NULL,
    "Couleur" character varying(10) DEFAULT 'bleu'::character varying NOT NULL,
    "TypeObjet" character varying(10) NOT NULL,
    "Mode" character varying(12) NOT NULL,
    "Regles" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "Actif" boolean DEFAULT true NOT NULL,
    "Version" integer DEFAULT 1 NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_DossierSuivi_Couleur_check" CHECK ((("Couleur")::text = ANY ((ARRAY['vert'::character varying, 'rouge'::character varying, 'orange'::character varying, 'bleu'::character varying, 'violet'::character varying, 'ardoise'::character varying])::text[]))),
    CONSTRAINT "T_DossierSuivi_Mode_check" CHECK ((("Mode")::text = ANY ((ARRAY['manuel'::character varying, 'automatique'::character varying])::text[]))),
    CONSTRAINT "T_DossierSuivi_Nom_check" CHECK ((btrim(("Nom")::text) <> ''::text)),
    CONSTRAINT "T_DossierSuivi_TypeObjet_check" CHECK ((("TypeObjet")::text = ANY ((ARRAY['article'::character varying, 'bon'::character varying, 'facture'::character varying])::text[]))),
    CONSTRAINT "T_DossierSuivi_Version_check" CHECK (("Version" > 0)),
    CONSTRAINT "T_DossierSuivi_check" CHECK (((jsonb_typeof("Regles") = 'object'::text) AND (("Regles" -
CASE "TypeObjet"
    WHEN 'article'::text THEN ARRAY['q'::text, 'categorieId'::text, 'typeId'::text, 'uniteId'::text, 'statut'::text, 'stockState'::text, 'peremption'::text]
    WHEN 'bon'::text THEN ARRAY['q'::text, 'client'::text, 'typeId'::text, 'statutId'::text, 'etatBon'::text]
    ELSE ARRAY['q'::text, 'client'::text, 'etatFacture'::text]
END) = '{}'::jsonb))),
    CONSTRAINT "T_DossierSuivi_check1" CHECK ((((("Mode")::text = 'manuel'::text) AND ("Regles" = '{}'::jsonb)) OR ((("Mode")::text = 'automatique'::text) AND ("Regles" <> '{}'::jsonb))))
);

--
-- Name: TABLE "T_DossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_DossierSuivi" IS 'Dossiers de suivi privés : articles, bons de stock ou factures ; aucun effet sur les écritures métier.';

--
-- Name: COLUMN "T_DossierSuivi"."ID_DossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."ID_DossierSuivi" IS 'Identifiant permanent du dossier ; indépendant de son libellé.';

--
-- Name: COLUMN "T_DossierSuivi"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';

--
-- Name: COLUMN "T_DossierSuivi"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."IdEntiteFk" IS 'Organisation du contexte à la création ; nullable et immuable.';

--
-- Name: COLUMN "T_DossierSuivi"."ID_CategorieDossierSuiviFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."ID_CategorieDossierSuiviFk" IS 'Catégorie de classement du même propriétaire et du même périmètre.';

--
-- Name: COLUMN "T_DossierSuivi"."Nom"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';

--
-- Name: COLUMN "T_DossierSuivi"."Description"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."Description" IS 'Description facultative du suivi.';

--
-- Name: COLUMN "T_DossierSuivi"."Couleur"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';

--
-- Name: COLUMN "T_DossierSuivi"."TypeObjet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."TypeObjet" IS 'Type immuable du dossier : article, bon ou facture. Une facture correspond au bon portant sa référence de facture dans le modèle actuel.';

--
-- Name: COLUMN "T_DossierSuivi"."Mode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."Mode" IS 'manuel pour les rattachements explicites, automatique pour une sélection dynamique.';

--
-- Name: COLUMN "T_DossierSuivi"."Regles"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."Regles" IS 'Critères JSON autorisés selon TypeObjet, interprétés par le serveur ; aucun fragment SQL utilisateur.';

--
-- Name: COLUMN "T_DossierSuivi"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';

--
-- Name: COLUMN "T_DossierSuivi"."Version"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."Version" IS 'Version de concurrence optimiste des métadonnées du dossier.';

--
-- Name: COLUMN "T_DossierSuivi"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."CreeLe" IS 'Instant de création.';

--
-- Name: COLUMN "T_DossierSuivi"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';

--
-- Name: T_DossierSuiviMembre; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_DossierSuiviMembre" (
    "ID_DossierSuiviFk" integer NOT NULL,
    "ID_ArticleFk" integer,
    "ID_CommandeFk" integer,
    "ID_Membre" integer NOT NULL,
    "Actif" boolean DEFAULT true NOT NULL,
    "AjouteLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_DossierSuiviMembre_check" CHECK ((num_nonnulls("ID_ArticleFk", "ID_CommandeFk") = 1))
);

--
-- Name: TABLE "T_DossierSuiviMembre"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_DossierSuiviMembre" IS 'Dossiers de suivi privés : articles, bons de stock ou factures ; aucun effet sur les écritures métier.';

--
-- Name: COLUMN "T_DossierSuiviMembre"."ID_DossierSuiviFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_DossierSuiviFk" IS 'Dossier manuel actif du rattachement.';

--
-- Name: COLUMN "T_DossierSuiviMembre"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_ArticleFk" IS 'Article classé ; clé de la vue et de la table article existantes.';

--
-- Name: COLUMN "T_DossierSuiviMembre"."ID_CommandeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_CommandeFk" IS 'Bon classé, ou bon portant la facture classée ; exclusif de ID_ArticleFk. La facture reste soumise à son existence actuelle.';

--
-- Name: COLUMN "T_DossierSuiviMembre"."ID_Membre"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_Membre" IS 'Identifiant permanent du rattachement ; unicité par dossier et objet classé.';

--
-- Name: COLUMN "T_DossierSuiviMembre"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."Actif" IS 'État actif ; false conserve le classement archivé.';

--
-- Name: COLUMN "T_DossierSuiviMembre"."AjouteLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."AjouteLe" IS 'Date du premier rattachement manuel ; conservée lors d’une réactivation.';

--
-- Name: COLUMN "T_DossierSuiviMembre"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';

--
-- Name: T_DossierSuiviMembre_ID_Membre_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_DossierSuiviMembre" ALTER COLUMN "ID_Membre" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_DossierSuiviMembre_ID_Membre_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_DossierSuivi_ID_DossierSuivi_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_DossierSuivi" ALTER COLUMN "ID_DossierSuivi" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_DossierSuivi_ID_DossierSuivi_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Facture; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Facture" (
    "ID_Facture" bigint CONSTRAINT "T_Facture_ID_Facture_not_null" NOT NULL,
    "ID_CommandeFk" integer CONSTRAINT "T_Facture_ID_CommandeFk_not_null" NOT NULL,
    "CodeFacture" character varying(255) CONSTRAINT "T_Facture_CodeFacture_not_null" NOT NULL,
    "ID_UserFk" integer CONSTRAINT "T_Facture_ID_UserFk_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Facture_IdEntiteFk_not_null" NOT NULL,
    "RequestId" uuid CONSTRAINT "T_Facture_RequestId_not_null" NOT NULL,
    "PayloadHash" text CONSTRAINT "T_Facture_PayloadHash_not_null" NOT NULL,
    "DateFacture" timestamp with time zone CONSTRAINT "T_Facture_DateFacture_not_null" NOT NULL,
    "DateEcheancePaiement" timestamp with time zone CONSTRAINT "T_Facture_DateEcheancePaiement_not_null" NOT NULL,
    "ID_ModePaiementFk" integer,
    "ID_ConditionPaiementFk" integer,
    "DelaiJours" integer,
    "ID_DeviseFk" integer CONSTRAINT "T_Facture_ID_DeviseFk_not_null" NOT NULL,
    "DeviseCode" text CONSTRAINT "T_Facture_DeviseCode_not_null" NOT NULL,
    "DeviseLibelle" text CONSTRAINT "T_Facture_DeviseLibelle_not_null" NOT NULL,
    "MontantHT" numeric(12,2) CONSTRAINT "T_Facture_MontantHT_not_null" NOT NULL,
    "MontantTTC" numeric(12,2) CONSTRAINT "T_Facture_MontantTTC_not_null" NOT NULL,
    "TransactionCreation" bigint DEFAULT txid_current() CONSTRAINT "T_Facture_TransactionCreation_not_null" NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_Facture_CreeLe_not_null" NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_Facture_ModifieLe_not_null" NOT NULL,
    CONSTRAINT "T_Facture_DelaiJours_check" CHECK (("DelaiJours" >= 0)),
    CONSTRAINT "T_Facture_DeviseCode_check" CHECK (("DeviseCode" ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT "T_Facture_MontantHT_check" CHECK (("MontantHT" > (0)::numeric)),
    CONSTRAINT "T_Facture_PayloadHash_check" CHECK (("PayloadHash" ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT "T_Facture_check" CHECK (("MontantTTC" = "MontantHT")),
    CONSTRAINT ck_facture_echeance CHECK (("DateEcheancePaiement" >= "DateFacture"))
);

--
-- Name: TABLE "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Facture" IS 'Une facture par bon de sortie ; total net figé à l’émission, sans effet de stock ni taxe implicite.';

--
-- Name: COLUMN "T_Facture"."ID_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."ID_Facture" IS 'Identité interne de la facture, indépendante du code lisible.';

--
-- Name: COLUMN "T_Facture"."ID_CommandeFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."ID_CommandeFk" IS 'Bon de sortie d’origine ; une seule facture émise par bon.';

--
-- Name: COLUMN "T_Facture"."CodeFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."CodeFacture" IS 'Numéro serveur immuable fac-ID_Commande du bon facturé ; valeurs historiques renommées et mappées dans l’audit08.';

--
-- Name: COLUMN "T_Facture"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."ID_UserFk" IS 'Auteur de l’émission de la facture.';

--
-- Name: COLUMN "T_Facture"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."IdEntiteFk" IS 'Organisation figée lors de l’émission.';

--
-- Name: COLUMN "T_Facture"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."RequestId" IS 'Identifiant de la demande pour les rejeux idempotents.';

--
-- Name: COLUMN "T_Facture"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."PayloadHash" IS 'Empreinte exacte de la demande d’émission, sans secret.';

--
-- Name: COLUMN "T_Facture"."DateFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."DateFacture" IS 'Date et heure d’émission métier, modifiables seulement avant règlement.';

--
-- Name: COLUMN "T_Facture"."DateEcheancePaiement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."DateEcheancePaiement" IS 'Échéance explicite ; jamais déduite d’un identifiant de référence.';

--
-- Name: COLUMN "T_Facture"."ID_ModePaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."ID_ModePaiementFk" IS 'Mode de paiement du référentiel catégorie36.';

--
-- Name: COLUMN "T_Facture"."ID_ConditionPaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."ID_ConditionPaiementFk" IS 'Condition de paiement du référentiel catégorie37.';

--
-- Name: COLUMN "T_Facture"."DelaiJours"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."DelaiJours" IS 'Nombre de jours uniquement lorsque la condition les écrit explicitement ; NULL sinon.';

--
-- Name: COLUMN "T_Facture"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."ID_DeviseFk" IS 'Devise du bon figée à l’émission.';

--
-- Name: COLUMN "T_Facture"."DeviseCode"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."DeviseCode" IS 'Code de devise copié à l’émission.';

--
-- Name: COLUMN "T_Facture"."DeviseLibelle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."DeviseLibelle" IS 'Libellé de devise copié à l’émission.';

--
-- Name: COLUMN "T_Facture"."MontantHT"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."MontantHT" IS 'Somme des lignes nettes facturées ; aucune taxe créée implicitement.';

--
-- Name: COLUMN "T_Facture"."MontantTTC"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."MontantTTC" IS 'Montant exigible figé, égal au HT en l’absence de taxe explicite.';

--
-- Name: COLUMN "T_Facture"."TransactionCreation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."TransactionCreation" IS 'Transaction d’émission ; borne la création des lignes à la même transaction.';

--
-- Name: COLUMN "T_Facture"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."CreeLe" IS 'Horodatage technique de création immuable.';

--
-- Name: COLUMN "T_Facture"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Facture"."ModifieLe" IS 'Dernière modification autorisée des métadonnées.';

--
-- Name: CONSTRAINT "T_Facture_ID_Facture_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_Facture_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_ID_CommandeFk_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_CommandeFk_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_CodeFacture_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_CodeFacture_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_ID_UserFk_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_UserFk_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_IdEntiteFk_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_IdEntiteFk_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_RequestId_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_RequestId_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_PayloadHash_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_PayloadHash_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_DateFacture_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_DateFacture_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_DateEcheancePaiement_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_DateEcheancePaiement_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_ID_DeviseFk_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_DeviseFk_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_DeviseCode_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_DeviseCode_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_DeviseLibelle_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_DeviseLibelle_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_MontantHT_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_MontantHT_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_MontantTTC_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_MontantTTC_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_TransactionCreation_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_TransactionCreation_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_CreeLe_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_CreeLe_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_ModifieLe_not_null" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ModifieLe_not_null" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_DelaiJours_check" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_DelaiJours_check" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_DeviseCode_check" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_DeviseCode_check" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_MontantHT_check" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_MontantHT_check" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_PayloadHash_check" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_PayloadHash_check" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_Facture_check" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_check" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT ck_facture_echeance ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_facture_echeance ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_FactureLigne; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_FactureLigne" (
    "ID_FactureLigne" bigint CONSTRAINT "T_FactureLigne_ID_FactureLigne_not_null" NOT NULL,
    "ID_FactureFk" bigint CONSTRAINT "T_FactureLigne_ID_FactureFk_not_null" NOT NULL,
    "ID_CmdFk" integer CONSTRAINT "T_FactureLigne_ID_CmdFk_not_null" NOT NULL,
    "ID_ArticleFk" integer CONSTRAINT "T_FactureLigne_ID_ArticleFk_not_null" NOT NULL,
    "NomArticle" text CONSTRAINT "T_FactureLigne_NomArticle_not_null" NOT NULL,
    "CodeArticleInterne" text,
    "Unite" text,
    "QteSortie" numeric(14,3) CONSTRAINT "T_FactureLigne_QteSortie_not_null" NOT NULL,
    "QteRetourAvantFacture" numeric(14,3) CONSTRAINT "T_FactureLigne_QteRetourAvantFacture_not_null" NOT NULL,
    "QteFacturee" numeric(14,3) CONSTRAINT "T_FactureLigne_QteFacturee_not_null" NOT NULL,
    "PUFacture" numeric(12,2) CONSTRAINT "T_FactureLigne_PUFacture_not_null" NOT NULL,
    "MontantLigne" numeric(12,2) CONSTRAINT "T_FactureLigne_MontantLigne_not_null" NOT NULL,
    CONSTRAINT "T_FactureLigne_PUFacture_check" CHECK (("PUFacture" >= (0)::numeric)),
    CONSTRAINT "T_FactureLigne_QteRetourAvantFacture_check" CHECK (("QteRetourAvantFacture" >= (0)::numeric)),
    CONSTRAINT "T_FactureLigne_QteSortie_check" CHECK (("QteSortie" > (0)::numeric)),
    CONSTRAINT "T_FactureLigne_check" CHECK ((("QteFacturee" > (0)::numeric) AND ("QteFacturee" = ("QteSortie" - "QteRetourAvantFacture")))),
    CONSTRAINT facture_ligne_montant_arrondi CHECK (("MontantLigne" = round(("QteFacturee" * "PUFacture"), 2)))
);

--
-- Name: TABLE "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_FactureLigne" IS 'Copie financière des lignes nettes au moment de l’émission ; noms, unité, prix et quantités historiques immuables.';

--
-- Name: COLUMN "T_FactureLigne"."ID_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."ID_FactureLigne" IS 'Identité interne de la ligne financière.';

--
-- Name: COLUMN "T_FactureLigne"."ID_FactureFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."ID_FactureFk" IS 'Facture à laquelle appartient la ligne.';

--
-- Name: COLUMN "T_FactureLigne"."ID_CmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."ID_CmdFk" IS 'Bon de sortie de la ligne d’origine.';

--
-- Name: COLUMN "T_FactureLigne"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."ID_ArticleFk" IS 'Article de la ligne d’origine.';

--
-- Name: COLUMN "T_FactureLigne"."NomArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."NomArticle" IS 'Désignation copiée lors de l’émission.';

--
-- Name: COLUMN "T_FactureLigne"."CodeArticleInterne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."CodeArticleInterne" IS 'Code article copié lors de l’émission.';

--
-- Name: COLUMN "T_FactureLigne"."Unite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."Unite" IS 'Unité copiée lors de l’émission ; aucune somme entre unités incompatibles.';

--
-- Name: COLUMN "T_FactureLigne"."QteSortie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."QteSortie" IS 'Quantité originale exacte de sortie dans l’unité figée sur la facture.';

--
-- Name: COLUMN "T_FactureLigne"."QteRetourAvantFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."QteRetourAvantFacture" IS 'Quantité exacte restituée avant émission de la facture.';

--
-- Name: COLUMN "T_FactureLigne"."QteFacturee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."QteFacturee" IS 'Quantité nette exacte facturée après restitutions antérieures.';

--
-- Name: COLUMN "T_FactureLigne"."PUFacture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."PUFacture" IS 'Prix unitaire explicite du bon, copié sans conversion.';

--
-- Name: COLUMN "T_FactureLigne"."MontantLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_FactureLigne"."MontantLigne" IS 'Quantité nette facturée multipliée par le prix historique.';

--
-- Name: CONSTRAINT "T_FactureLigne_ID_FactureLigne_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_ID_FactureLigne_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_ID_FactureFk_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_ID_FactureFk_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_ID_CmdFk_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_ID_CmdFk_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_ID_ArticleFk_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_ID_ArticleFk_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_NomArticle_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_NomArticle_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_QteSortie_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_QteSortie_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_QteRetourAvantFacture_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_QteRetourAvantFacture_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_QteFacturee_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_QteFacturee_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_PUFacture_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_PUFacture_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_MontantLigne_not_null" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_MontantLigne_not_null" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_PUFacture_check" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_PUFacture_check" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_QteRetourAvantFacture_check" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_QteRetourAvantFacture_check" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_QteSortie_check" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_QteSortie_check" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT "T_FactureLigne_check" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_check" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: CONSTRAINT facture_ligne_montant_arrondi ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT facture_ligne_montant_arrondi ON logistique."T_FactureLigne" IS 'Montant arrondi par ligne à deux décimales selon PostgreSQL numeric, avant sommation.';

--
-- Name: T_FactureLigne_ID_FactureLigne_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_FactureLigne" ALTER COLUMN "ID_FactureLigne" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_FactureLigne_ID_FactureLigne_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Facture_ID_Facture_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Facture" ALTER COLUMN "ID_Facture" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_Facture_ID_Facture_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Immobilisation; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Immobilisation" (
    "ID_Immobilisation" integer CONSTRAINT "T_Immobilisation_ID_Immobilisation_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Immobilisation_IdEntiteFk_not_null" NOT NULL,
    "CodeImmobilisation" character varying(32) CONSTRAINT "T_Immobilisation_CodeImmobilisation_not_null" NOT NULL,
    "NomImmobilisation" character varying(200) CONSTRAINT "T_Immobilisation_NomImmobilisation_not_null" NOT NULL,
    "Reference" character varying(255),
    "Caracteristiques" text,
    "SuiviIndividuel" boolean DEFAULT true CONSTRAINT "T_Immobilisation_SuiviIndividuel_not_null" NOT NULL,
    "Quantite" numeric DEFAULT 1 CONSTRAINT "T_Immobilisation_Quantite_not_null" NOT NULL,
    "PrixUnitaire" numeric(18,2),
    "ID_DeviseFk" integer,
    "ID_CategorieFk" integer CONSTRAINT "T_Immobilisation_ID_CategorieFk_not_null" NOT NULL,
    "ID_EtatFk" integer,
    "ID_ResponsableFk" integer,
    "ID_ServiceFk" integer,
    "ID_LocalisationFk" integer,
    "LocalisationComplement" character varying(255),
    "DateEntree" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_Immobilisation_DateEntree_not_null" NOT NULL,
    "DateAcquisition" date,
    "NumeroSerie" character varying(255),
    "Observations" text,
    "Actif" boolean DEFAULT true CONSTRAINT "T_Immobilisation_Actif_not_null" NOT NULL,
    "CreeLe" timestamp with time zone CONSTRAINT "T_Immobilisation_CreeLe_not_null" NOT NULL,
    "ModifieLe" timestamp with time zone CONSTRAINT "T_Immobilisation_ModifieLe_not_null" NOT NULL,
    "CreeParUserFk" integer CONSTRAINT "T_Immobilisation_CreeParUserFk_not_null" NOT NULL,
    "ModifieParUserFk" integer CONSTRAINT "T_Immobilisation_ModifieParUserFk_not_null" NOT NULL,
    CONSTRAINT ck_immobilisation_caracteristiques CHECK ((("Caracteristiques" IS NULL) OR ((char_length("Caracteristiques") <= 4000) AND (replace(replace("Caracteristiques", E'\r\n'::text, E'\n'::text), E'\n'::text, ''::text) !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_immobilisation_dates CHECK ((isfinite("DateEntree") AND (("DateAcquisition" IS NULL) OR isfinite("DateAcquisition")))),
    CONSTRAINT ck_immobilisation_individuelle CHECK ((((NOT "SuiviIndividuel") AND ("NumeroSerie" IS NULL)) OR ("Quantite" = (1)::numeric))),
    CONSTRAINT ck_immobilisation_localisation_complement CHECK ((("LocalisationComplement" IS NULL) OR (((char_length(("LocalisationComplement")::text) >= 1) AND (char_length(("LocalisationComplement")::text) <= 255)) AND (("LocalisationComplement")::text = btrim(("LocalisationComplement")::text)) AND (("LocalisationComplement")::text !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_immobilisation_nom CHECK ((((char_length(("NomImmobilisation")::text) >= 1) AND (char_length(("NomImmobilisation")::text) <= 200)) AND (("NomImmobilisation")::text = btrim(("NomImmobilisation")::text)) AND (("NomImmobilisation")::text !~ '[[:cntrl:]]'::text))),
    CONSTRAINT ck_immobilisation_observations CHECK ((("Observations" IS NULL) OR ((char_length("Observations") <= 4000) AND (replace(replace("Observations", E'\r\n'::text, E'\n'::text), E'\n'::text, ''::text) !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_immobilisation_prix CHECK ((("PrixUnitaire" IS NULL) OR (("PrixUnitaire" >= (0)::numeric) AND ("PrixUnitaire" <> 'NaN'::numeric) AND ("ID_DeviseFk" IS NOT NULL)))),
    CONSTRAINT ck_immobilisation_quantite CHECK ((("Quantite" > (0)::numeric) AND ("Quantite" = trunc("Quantite")) AND ("Quantite" <= ('999999999999999999'::bigint)::numeric))),
    CONSTRAINT ck_immobilisation_reference CHECK ((("Reference" IS NULL) OR (((char_length(("Reference")::text) >= 1) AND (char_length(("Reference")::text) <= 255)) AND (("Reference")::text = btrim(("Reference")::text)) AND (("Reference")::text !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_immobilisation_serie CHECK ((("NumeroSerie" IS NULL) OR (((char_length(("NumeroSerie")::text) >= 1) AND (char_length(("NumeroSerie")::text) <= 255)) AND (("NumeroSerie")::text = btrim(("NumeroSerie")::text)) AND (("NumeroSerie")::text !~ '[[:cntrl:]]'::text))))
);

--
-- Name: TABLE "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Immobilisation" IS 'Biens et équipements appartenant durablement à une entreprise, suivis individuellement ou par groupe homogène explicite. Affectations et coût indicatif d’acquisition exacts, sans stock commercial, mouvement, CUMP, amortissement ou écriture comptable implicite. Archivage conservant le registre et son audit.';

--
-- Name: COLUMN "T_Immobilisation"."ID_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ID_Immobilisation" IS 'Identifiant technique stable du bien ; attribué par PostgreSQL et jamais réutilisé.';

--
-- Name: COLUMN "T_Immobilisation"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."IdEntiteFk" IS 'Entreprise propriétaire durable, obligatoire et immuable.';

--
-- Name: COLUMN "T_Immobilisation"."CodeImmobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."CodeImmobilisation" IS 'Code IMMO-identifiant attribué par trigger ; unique et immuable.';

--
-- Name: COLUMN "T_Immobilisation"."NomImmobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."NomImmobilisation" IS 'Désignation du bien, maximum200 caractères, sans contrôle ni espace extérieur.';

--
-- Name: COLUMN "T_Immobilisation"."Reference"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."Reference" IS 'Référence libre facultative du modèle ou du catalogue, maximum255 caractères.';

--
-- Name: COLUMN "T_Immobilisation"."Caracteristiques"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."Caracteristiques" IS 'Caractéristiques communes du bien ou du groupe homogène, maximum4000 caractères, retours de ligne autorisés.';

--
-- Name: COLUMN "T_Immobilisation"."SuiviIndividuel"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."SuiviIndividuel" IS 'true par défaut pour une fiche par équipement ; false explicite pour un groupe homogène partageant caractéristiques, état et affectation.';

--
-- Name: COLUMN "T_Immobilisation"."Quantite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."Quantite" IS 'Nombre entier exact de biens, de1 à18 chiffres ; aucun arrondi silencieux des fractions. Un suivi individuel ou numéro de série impose1.';

--
-- Name: COLUMN "T_Immobilisation"."PrixUnitaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."PrixUnitaire" IS 'Prix d’acquisition unitaire indicatif à2 décimales, non négatif ; NULL signifie inconnu et ne vaut jamais zéro.';

--
-- Name: COLUMN "T_Immobilisation"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ID_DeviseFk" IS 'Devise du référentiel ; obligatoire dès que le prix est renseigné, sans conversion automatique.';

--
-- Name: COLUMN "T_Immobilisation"."ID_CategorieFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ID_CategorieFk" IS 'Type de matériel depuis le référentiel et les correspondances configurées pour cette entreprise.';

--
-- Name: COLUMN "T_Immobilisation"."ID_EtatFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ID_EtatFk" IS 'État facultatif issu de la famille configurée ; aucune présomption de bon état.';

--
-- Name: COLUMN "T_Immobilisation"."ID_ResponsableFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ID_ResponsableFk" IS 'Compte responsable de la même entreprise ; nouvelle affectation réservée aux comptes actifs dont les dates d’emploi permettent l’affectation.';

--
-- Name: COLUMN "T_Immobilisation"."ID_ServiceFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ID_ServiceFk" IS 'Service explicite du bien, issu du référentiel ; indépendant de l’évolution du service professionnel de son responsable.';

--
-- Name: COLUMN "T_Immobilisation"."ID_LocalisationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ID_LocalisationFk" IS 'Lieu d’affectation appartenant à la même entreprise, sans lien texte ou égalité d’identifiants d’une autre table.';

--
-- Name: COLUMN "T_Immobilisation"."LocalisationComplement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."LocalisationComplement" IS 'Salle, bureau ou précision facultative de l’affectation, maximum255 caractères.';

--
-- Name: COLUMN "T_Immobilisation"."DateEntree"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."DateEntree" IS 'Date et heure d’entrée du bien dans le registre ; distincte de la date d’achat et des dates techniques.';

--
-- Name: COLUMN "T_Immobilisation"."DateAcquisition"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."DateAcquisition" IS 'Date d’acquisition facultative ; aucune date inventée si inconnue.';

--
-- Name: COLUMN "T_Immobilisation"."NumeroSerie"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."NumeroSerie" IS 'Numéro de série facultatif, maximum255 caractères ; sa présence impose une fiche pour un seul bien.';

--
-- Name: COLUMN "T_Immobilisation"."Observations"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."Observations" IS 'Note complémentaire facultative, maximum4000 caractères, retours de ligne autorisés.';

--
-- Name: COLUMN "T_Immobilisation"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."Actif" IS 'true si le bien figure dans le registre actif ; false archive sa fiche sans effacer les affectations ni l’historique.';

--
-- Name: COLUMN "T_Immobilisation"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."CreeLe" IS 'Horodatage technique PostgreSQL de création, immuable.';

--
-- Name: COLUMN "T_Immobilisation"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ModifieLe" IS 'Horodatage technique PostgreSQL de la dernière écriture.';

--
-- Name: COLUMN "T_Immobilisation"."CreeParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."CreeParUserFk" IS 'Auteur actif prouvé par le contexte transactionnel à la création, immuable.';

--
-- Name: COLUMN "T_Immobilisation"."ModifieParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Immobilisation"."ModifieParUserFk" IS 'Auteur actif prouvé de la dernière écriture.';

--
-- Name: CONSTRAINT "T_Immobilisation_ID_Immobilisation_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_Immobilisation_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "ID_Immobilisation". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_IdEntiteFk_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_IdEntiteFk_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "IdEntiteFk". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_CodeImmobilisation_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_CodeImmobilisation_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "CodeImmobilisation". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_NomImmobilisation_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_NomImmobilisation_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "NomImmobilisation". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_SuiviIndividuel_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_SuiviIndividuel_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "SuiviIndividuel". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_Quantite_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_Quantite_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "Quantite". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_ID_CategorieFk_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_CategorieFk_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "ID_CategorieFk". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_DateEntree_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_DateEntree_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "DateEntree". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_Actif_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_Actif_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "Actif". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_CreeLe_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_CreeLe_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "CreeLe". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_ModifieLe_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ModifieLe_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "ModifieLe". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_CreeParUserFk_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_CreeParUserFk_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "CreeParUserFk". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT "T_Immobilisation_ModifieParUserFk_not_null" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ModifieParUserFk_not_null" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : NOT NULL "ModifieParUserFk". Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_caracteristiques ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_caracteristiques ON logistique."T_Immobilisation" IS E'Intégrité durable du patrimoine : CHECK ("Caracteristiques" IS NULL OR char_length("Caracteristiques") <= 4000 AND replace(replace("Caracteristiques", ''\r\n''::text, ''\n''::text), ''\n''::text, ''''::text) !~ ''[[:cntrl:]]''::text). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_dates ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_dates ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK (isfinite("DateEntree") AND ("DateAcquisition" IS NULL OR isfinite("DateAcquisition"))). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_individuelle ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_individuelle ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK (NOT "SuiviIndividuel" AND "NumeroSerie" IS NULL OR "Quantite" = 1::numeric). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_localisation_complement ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_localisation_complement ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK ("LocalisationComplement" IS NULL OR char_length("LocalisationComplement"::text) >= 1 AND char_length("LocalisationComplement"::text) <= 255 AND "LocalisationComplement"::text = btrim("LocalisationComplement"::text) AND "LocalisationComplement"::text !~ ''[[:cntrl:]]''::text). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_nom ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_nom ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK (char_length("NomImmobilisation"::text) >= 1 AND char_length("NomImmobilisation"::text) <= 200 AND "NomImmobilisation"::text = btrim("NomImmobilisation"::text) AND "NomImmobilisation"::text !~ ''[[:cntrl:]]''::text). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_observations ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_observations ON logistique."T_Immobilisation" IS E'Intégrité durable du patrimoine : CHECK ("Observations" IS NULL OR char_length("Observations") <= 4000 AND replace(replace("Observations", ''\r\n''::text, ''\n''::text), ''\n''::text, ''''::text) !~ ''[[:cntrl:]]''::text). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_prix ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_prix ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK ("PrixUnitaire" IS NULL OR "PrixUnitaire" >= 0::numeric AND "PrixUnitaire" <> ''NaN''::numeric AND "ID_DeviseFk" IS NOT NULL). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_quantite ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_quantite ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK ("Quantite" > 0::numeric AND "Quantite" = trunc("Quantite") AND "Quantite" <= ''999999999999999999''::bigint::numeric). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_reference ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_reference ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK ("Reference" IS NULL OR char_length("Reference"::text) >= 1 AND char_length("Reference"::text) <= 255 AND "Reference"::text = btrim("Reference"::text) AND "Reference"::text !~ ''[[:cntrl:]]''::text). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: CONSTRAINT ck_immobilisation_serie ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_immobilisation_serie ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : CHECK ("NumeroSerie" IS NULL OR char_length("NumeroSerie"::text) >= 1 AND char_length("NumeroSerie"::text) <= 255 AND "NumeroSerie"::text = btrim("NumeroSerie"::text) AND "NumeroSerie"::text !~ ''[[:cntrl:]]''::text). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation_ID_Immobilisation_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Immobilisation" ALTER COLUMN "ID_Immobilisation" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_Immobilisation_ID_Immobilisation_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Immobilisation_ID_Immobilisation_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Immobilisation_ID_Immobilisation_seq" IS 'Identifiant technique des biens ; les trous de séquence sont normaux après annulation transactionnelle, aucun identifiant n’est réutilisé.';

--
-- Name: T_Inventaire; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Inventaire" (
    "ID_Inventaire" bigint NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "ID_UserFk" integer NOT NULL,
    "DateInventaire" timestamp with time zone NOT NULL,
    "Motif" text NOT NULL,
    "Etat" text DEFAULT 'brouillon'::text NOT NULL,
    "Version" bigint DEFAULT 1 NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "ValideLe" timestamp with time zone,
    "ID_ValidateurFk" integer,
    "ValidationRequest" uuid,
    "ValidationHash" text,
    "AnnuleLe" timestamp with time zone,
    "ID_AnnulateurFk" integer,
    "MotifAnnulation" text,
    "AnnulationRequest" uuid,
    "AnnulationHash" text,
    CONSTRAINT "T_Inventaire_Motif_check" CHECK (((length(btrim("Motif")) >= 1) AND (length(btrim("Motif")) <= 1000))),
    CONSTRAINT inventaire_annulation CHECK (((("Etat" = 'annule'::text) AND ("AnnuleLe" IS NOT NULL) AND ("ID_AnnulateurFk" IS NOT NULL) AND ("MotifAnnulation" IS NOT NULL) AND ((length(btrim("MotifAnnulation")) >= 1) AND (length(btrim("MotifAnnulation")) <= 1000)) AND ("AnnulationRequest" IS NOT NULL) AND ("AnnulationHash" IS NOT NULL)) OR (("Etat" <> 'annule'::text) AND ("AnnuleLe" IS NULL) AND ("ID_AnnulateurFk" IS NULL) AND ("MotifAnnulation" IS NULL) AND ("AnnulationRequest" IS NULL) AND ("AnnulationHash" IS NULL)))),
    CONSTRAINT inventaire_etat CHECK (("Etat" = ANY (ARRAY['brouillon'::text, 'valide'::text, 'annule'::text]))),
    CONSTRAINT inventaire_validation CHECK ((("Etat" = ANY (ARRAY['valide'::text, 'annule'::text])) = (("ValideLe" IS NOT NULL) AND ("ID_ValidateurFk" IS NOT NULL) AND ("ValidationRequest" IS NOT NULL) AND ("ValidationHash" IS NOT NULL))))
);

--
-- Name: TABLE "T_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Inventaire" IS 'Comptage physique versionné par entreprise ; validation justifiée et bons compensateurs, sans effacer le journal des mouvements.';

--
-- Name: COLUMN "T_Inventaire"."ID_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ID_Inventaire" IS 'Donnée ID_Inventaire de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."IdEntiteFk" IS 'Entreprise propriétaire stable ; ne découle jamais du rattachement actuel de l’auteur.';

--
-- Name: COLUMN "T_Inventaire"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ID_UserFk" IS 'Donnée ID_UserFk de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."DateInventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."DateInventaire" IS 'Donnée DateInventaire de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."Motif" IS 'Donnée Motif de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."Etat"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."Etat" IS 'Donnée Etat de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."Version"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."Version" IS 'Version optimiste incrémentée à chaque modification, indépendante des variations de stock.';

--
-- Name: COLUMN "T_Inventaire"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."CreeLe" IS 'Donnée CreeLe de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ModifieLe" IS 'Donnée ModifieLe de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."ValideLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ValideLe" IS 'Donnée ValideLe de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."ID_ValidateurFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ID_ValidateurFk" IS 'Donnée ID_ValidateurFk de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."ValidationRequest"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ValidationRequest" IS 'Identifiant de demande idempotente de validation ; un rejeu identique conserve les mêmes bons.';

--
-- Name: COLUMN "T_Inventaire"."ValidationHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ValidationHash" IS 'Donnée ValidationHash de T_Inventaire, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_Inventaire"."AnnuleLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."AnnuleLe" IS 'Date et heure de l’annulation ; la validation originale reste conservée.';

--
-- Name: COLUMN "T_Inventaire"."ID_AnnulateurFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."ID_AnnulateurFk" IS 'Administrateur autorisé ayant demandé l’annulation dans cette entreprise.';

--
-- Name: COLUMN "T_Inventaire"."MotifAnnulation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."MotifAnnulation" IS 'Motif obligatoire, conservé avec les bons compensateurs.';

--
-- Name: COLUMN "T_Inventaire"."AnnulationRequest"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."AnnulationRequest" IS 'Demande idempotente : un rejeu identique ne recrée pas les mouvements.';

--
-- Name: COLUMN "T_Inventaire"."AnnulationHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Inventaire"."AnnulationHash" IS 'Empreinte de la demande, incluant motif et version initiale.';

--
-- Name: CONSTRAINT inventaire_annulation ON "T_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT inventaire_annulation ON logistique."T_Inventaire" IS 'Annulation complète, motivée, datée et identifiée ; aucune métadonnée d’annulation sur les autres états.';

--
-- Name: CONSTRAINT inventaire_etat ON "T_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT inventaire_etat ON logistique."T_Inventaire" IS 'Brouillon, validation conservée ou validation annulée par compensation.';

--
-- Name: CONSTRAINT inventaire_validation ON "T_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT inventaire_validation ON logistique."T_Inventaire" IS 'Conserve les preuves de validation après annulation.';

--
-- Name: T_InventaireLigne; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_InventaireLigne" (
    "ID_InventaireFk" bigint NOT NULL,
    "ID_ArticleFk" integer NOT NULL,
    "QteTheorique" numeric(14,3) NOT NULL,
    "QteComptee" numeric(14,3) NOT NULL,
    "PUCorrection" numeric(12,2),
    "Lots" jsonb DEFAULT '[]'::jsonb NOT NULL,
    "Justification" text NOT NULL,
    "ID_CommandeCorrectionFk" integer,
    "ID_CommandeAnnulationFk" integer,
    CONSTRAINT "T_InventaireLigne_Justification_check" CHECK (((length(btrim("Justification")) >= 1) AND (length(btrim("Justification")) <= 1000))),
    CONSTRAINT "T_InventaireLigne_Lots_check" CHECK ((jsonb_typeof("Lots") = 'array'::text)),
    CONSTRAINT "T_InventaireLigne_PUCorrection_check" CHECK (("PUCorrection" >= (0)::numeric)),
    CONSTRAINT "T_InventaireLigne_QteComptee_check" CHECK (("QteComptee" >= (0)::numeric)),
    CONSTRAINT "T_InventaireLigne_QteTheorique_check" CHECK (("QteTheorique" >= (0)::numeric))
);

--
-- Name: TABLE "T_InventaireLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_InventaireLigne" IS 'Stock théorique au comptage, quantité comptée et lots du seul écart ; chaque écart non nul est relié à une ligne de bon correcteur.';

--
-- Name: COLUMN "T_InventaireLigne"."ID_InventaireFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."ID_InventaireFk" IS 'Donnée ID_InventaireFk de T_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_InventaireLigne"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."ID_ArticleFk" IS 'Donnée ID_ArticleFk de T_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_InventaireLigne"."QteTheorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."QteTheorique" IS 'Stock exact capturé lors de la préparation du comptage, contrôlé de nouveau sous verrou à la validation.';

--
-- Name: COLUMN "T_InventaireLigne"."QteComptee"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."QteComptee" IS 'Quantité physique saisie explicitement ; zéro est un comptage, absence est refusée.';

--
-- Name: COLUMN "T_InventaireLigne"."PUCorrection"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."PUCorrection" IS 'Donnée PUCorrection de T_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_InventaireLigne"."Lots"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."Lots" IS 'Ventilation JSON des seuls écarts : numéro, quantité exacte et péremption facultative ; aucun mouvement autonome.';

--
-- Name: COLUMN "T_InventaireLigne"."Justification"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."Justification" IS 'Donnée Justification de T_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_InventaireLigne"."ID_CommandeCorrectionFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."ID_CommandeCorrectionFk" IS 'Donnée ID_CommandeCorrectionFk de T_InventaireLigne, consultée dans le périmètre entreprise autorisé.';

--
-- Name: COLUMN "T_InventaireLigne"."ID_CommandeAnnulationFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_InventaireLigne"."ID_CommandeAnnulationFk" IS 'Bon inverse unique de cette ligne ; même quantité, prix, devise et lots que la correction originale.';

--
-- Name: T_Inventaire_ID_Inventaire_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Inventaire" ALTER COLUMN "ID_Inventaire" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_Inventaire_ID_Inventaire_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_LotArticle; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_LotArticle" (
    "ID_LotArticle" integer NOT NULL,
    "ID_ArticleFk" integer NOT NULL,
    "NumeroLot" character varying(100) NOT NULL,
    "DatePeremptionLot" date,
    "Actif" boolean DEFAULT true NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_LotArticle_NumeroLot_check" CHECK ((btrim(("NumeroLot")::text) <> ''::text))
);

--
-- Name: TABLE "T_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_LotArticle" IS 'Lots identifiés par article et numéro reçu ; aucun stock copié sur cette table.';

--
-- Name: COLUMN "T_LotArticle"."ID_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_LotArticle"."ID_LotArticle" IS 'Identifiant stable du lot.';

--
-- Name: COLUMN "T_LotArticle"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_LotArticle"."ID_ArticleFk" IS 'Article auquel appartient le lot ; relation immuable.';

--
-- Name: COLUMN "T_LotArticle"."NumeroLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_LotArticle"."NumeroLot" IS 'Numéro communiqué lors de la réception, unique pour cet article sans distinction de casse.';

--
-- Name: COLUMN "T_LotArticle"."DatePeremptionLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_LotArticle"."DatePeremptionLot" IS 'Date propre au lot ; NULL signifie non renseignée.';

--
-- Name: COLUMN "T_LotArticle"."Actif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_LotArticle"."Actif" IS 'Disponibilité du lot pour de nouvelles saisies.';

--
-- Name: COLUMN "T_LotArticle"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_LotArticle"."CreeLe" IS 'Instant de première identification du lot.';

--
-- Name: T_LotArticle_ID_LotArticle_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_LotArticle" ALTER COLUMN "ID_LotArticle" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_LotArticle_ID_LotArticle_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Mouvement; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Mouvement" (
    "ID_Mvt" integer CONSTRAINT "T_Mouvement_ID_Mvt_not_null" NOT NULL,
    "ID_TypeMvtFk" integer,
    "ID_ArticleFk" integer,
    "ID_cmdFk" integer,
    "DateHeureAutoMvt" timestamp without time zone,
    "DateMvt" timestamp without time zone,
    "QteMvt" numeric(14,3),
    "PUMvt" numeric(12,2),
    "ID_DeviseFk" integer NOT NULL,
    CONSTRAINT chk_mvt_qte_non_negative CHECK ((("QteMvt" IS NULL) OR ("QteMvt" >= (0)::numeric)))
);

--
-- Name: TABLE "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Mouvement" IS 'Historique des entrées, sorties et ajustements d’article, avec type, quantité entière et prix du mouvement. Écritures réservées aux routines autorisées ; lecture pour audit et suivi du stock.';

--
-- Name: COLUMN "T_Mouvement"."ID_Mvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_Mvt" IS 'Identifiant du mouvement de stock.';

--
-- Name: COLUMN "T_Mouvement"."ID_TypeMvtFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_TypeMvtFk" IS 'Type historique du mouvement dans la catégorie 64 ; son abréviation détermine son signe de stock. Relation imposée : FOREIGN KEY ("ID_TypeMvtFk") REFERENCES referentiel."T_Generique"("ID_Generique") NOT VALID.';

--
-- Name: COLUMN "T_Mouvement"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_ArticleFk" IS 'Article rattaché à la ligne ou au mouvement. Relation imposée : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Mouvement"."ID_cmdFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_cmdFk" IS 'Commande source du mouvement ; NULL pour un ajustement direct d’article. Relation imposée : FOREIGN KEY ("ID_cmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "T_Mouvement"."DateHeureAutoMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."DateHeureAutoMvt" IS 'Horodatage automatique de création du mouvement, sans fuseau dans le type SQL.';

--
-- Name: COLUMN "T_Mouvement"."DateMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."DateMvt" IS 'Date métier du mouvement, utilisée dans les consommations et audits de stock.';

--
-- Name: COLUMN "T_Mouvement"."QteMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."QteMvt" IS 'Quantité positive exacte à trois décimales au maximum ; sens porté par le type, précision autorisée par l’unité de stock.';

--
-- Name: COLUMN "T_Mouvement"."PUMvt"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."PUMvt" IS 'Prix unitaire historique du mouvement : prix de ligne pour une commande, prix de vente article pour l’ajustement direct produit par le trigger actuel.';

--
-- Name: COLUMN "T_Mouvement"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Mouvement"."ID_DeviseFk" IS 'Instantané de la devise du bon source ou de l’article pour un ajustement initial/direct ; conservé même si le bon disparaît.';

--
-- Name: CONSTRAINT "T_Mouvement_ID_Mvt_not_null" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Mouvement_ID_Mvt_not_null" ON logistique."T_Mouvement" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Mouvement". Définition : NOT NULL "ID_Mvt".';

--
-- Name: CONSTRAINT chk_mvt_qte_non_negative ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_mvt_qte_non_negative ON logistique."T_Mouvement" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Mouvement". Définition : CHECK ("QteMvt" IS NULL OR "QteMvt" >= 0).';

--
-- Name: T_MouvementLot; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_MouvementLot" (
    "ID_MvtFk" integer NOT NULL,
    "ID_LotArticleFk" integer NOT NULL,
    "Quantite" numeric(14,3) NOT NULL,
    "MotifDerogationPeremption" text,
    "ID_DerogationUserFk" integer,
    "DateDerogationPeremption" timestamp with time zone,
    CONSTRAINT "T_MouvementLot_Quantite_check" CHECK (("Quantite" > (0)::numeric)),
    CONSTRAINT mouvement_lot_derogation_complete CHECK (((("MotifDerogationPeremption" IS NULL) AND ("ID_DerogationUserFk" IS NULL) AND ("DateDerogationPeremption" IS NULL)) OR (("MotifDerogationPeremption" IS NOT NULL) AND ((length(btrim("MotifDerogationPeremption")) >= 10) AND (length(btrim("MotifDerogationPeremption")) <= 1000)) AND ("ID_DerogationUserFk" IS NOT NULL) AND ("DateDerogationPeremption" IS NOT NULL))))
);

--
-- Name: TABLE "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_MouvementLot" IS 'Ventilation d’un mouvement existant par lot ; ne modifie jamais une seconde fois le stock global.';

--
-- Name: COLUMN "T_MouvementLot"."ID_MvtFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_MouvementLot"."ID_MvtFk" IS 'Mouvement source, créé par les triggers de stock existants.';

--
-- Name: COLUMN "T_MouvementLot"."ID_LotArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_MouvementLot"."ID_LotArticleFk" IS 'Lot du même article que le mouvement.';

--
-- Name: COLUMN "T_MouvementLot"."Quantite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_MouvementLot"."Quantite" IS 'Quantité positive exacte affectée au lot, même unité et précision que son mouvement, sans second effet sur le stock.';

--
-- Name: COLUMN "T_MouvementLot"."MotifDerogationPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_MouvementLot"."MotifDerogationPeremption" IS 'Justification explicite d’un prélèvement périmé, conservée avec sa ventilation historique ; aucun effet de stock supplémentaire.';

--
-- Name: COLUMN "T_MouvementLot"."ID_DerogationUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_MouvementLot"."ID_DerogationUserFk" IS 'Compte global autorisant le prélèvement périmé ; distinct de l’auteur initial du bon.';

--
-- Name: COLUMN "T_MouvementLot"."DateDerogationPeremption"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_MouvementLot"."DateDerogationPeremption" IS 'Horodatage serveur de la dérogation de péremption.';

--
-- Name: T_Mouvement_ID_Mvt_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Mouvement" ALTER COLUMN "ID_Mvt" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Mouvement_ID_Mvt_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Mouvement_ID_Mvt_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Mouvement_ID_Mvt_seq" IS 'Séquence de génération de "logistique"."T_Mouvement"."ID_Mvt". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_PieceJustificative; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_PieceJustificative" (
    "ID_Piece" bigint NOT NULL,
    "TypeObjet" text NOT NULL,
    "ID_Objet" bigint NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "ID_UserFk" integer NOT NULL,
    "NomFichier" character varying(180) NOT NULL,
    "MimeType" text NOT NULL,
    "TailleOctets" integer NOT NULL,
    "Sha256" text NOT NULL,
    "Contenu" bytea NOT NULL,
    "Archive" boolean DEFAULT false NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_PieceJustificative_ID_Objet_check" CHECK (("ID_Objet" > 0)),
    CONSTRAINT "T_PieceJustificative_MimeType_check" CHECK (("MimeType" = ANY (ARRAY['application/pdf'::text, 'image/jpeg'::text, 'image/png'::text, 'image/webp'::text]))),
    CONSTRAINT "T_PieceJustificative_NomFichier_check" CHECK ((length(btrim(("NomFichier")::text)) > 0)),
    CONSTRAINT "T_PieceJustificative_Sha256_check" CHECK (("Sha256" ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT "T_PieceJustificative_TailleOctets_check" CHECK ((("TailleOctets" > 0) AND ("TailleOctets" <= 8388608))),
    CONSTRAINT "T_PieceJustificative_TypeObjet_check" CHECK (("TypeObjet" = ANY (ARRAY['bon'::text, 'facture'::text, 'reglement'::text, 'avoir'::text]))),
    CONSTRAINT "T_PieceJustificative_check" CHECK ((octet_length("Contenu") = "TailleOctets")),
    CONSTRAINT ck_piece_sha256_contenu CHECK (("Sha256" = encode(sha256("Contenu"), 'hex'::text)))
);

--
-- Name: TABLE "T_PieceJustificative"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_PieceJustificative" IS 'Justificatifs privés de documents logistiques, téléchargés après contrôle du parent et conservés après archivage.';

--
-- Name: COLUMN "T_PieceJustificative"."ID_Piece"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."ID_Piece" IS 'Champ documentaire ID_Piece du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_PieceJustificative"."TypeObjet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."TypeObjet" IS 'Champ documentaire TypeObjet du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_PieceJustificative"."ID_Objet"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."ID_Objet" IS 'Champ documentaire ID_Objet du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_PieceJustificative"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."IdEntiteFk" IS 'Entreprise propriétaire du document, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "T_PieceJustificative"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."ID_UserFk" IS 'Champ documentaire ID_UserFk du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_PieceJustificative"."NomFichier"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."NomFichier" IS 'Champ documentaire NomFichier du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_PieceJustificative"."MimeType"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."MimeType" IS 'Champ documentaire MimeType du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_PieceJustificative"."TailleOctets"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."TailleOctets" IS 'Champ documentaire TailleOctets du justificatif ou de son identité historique.';

--
-- Name: COLUMN "T_PieceJustificative"."Sha256"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."Sha256" IS 'Empreinte du contenu binaire enregistré.';

--
-- Name: COLUMN "T_PieceJustificative"."Contenu"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."Contenu" IS 'Fichier privé limité à 8 Mo, jamais servi par un chemin public.';

--
-- Name: COLUMN "T_PieceJustificative"."Archive"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."Archive" IS 'Pièce retirée du parcours actif, contenu et historique conservés.';

--
-- Name: COLUMN "T_PieceJustificative"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PieceJustificative"."CreeLe" IS 'Champ documentaire CreeLe du justificatif ou de son identité historique.';

--
-- Name: CONSTRAINT ck_piece_sha256_contenu ON "T_PieceJustificative"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_piece_sha256_contenu ON logistique."T_PieceJustificative" IS 'L’empreinte SHA-256 doit correspondre exactement au contenu binaire conservé en base, quelle que soit la technologie d’enregistrement.';

--
-- Name: T_PieceJustificative_ID_Piece_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_PieceJustificative" ALTER COLUMN "ID_Piece" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_PieceJustificative_ID_Piece_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_PrecisionStock; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_PrecisionStock" (
    "ID_PrecisionStock" integer NOT NULL,
    "ID_UniteFk" integer NOT NULL,
    "DecimalesStock" smallint DEFAULT 0 NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT precision_stock_decimales CHECK ((("DecimalesStock" >= 0) AND ("DecimalesStock" <= 3)))
);

--
-- Name: TABLE "T_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_PrecisionStock" IS 'Politique logistique partagée de précision des quantités par unité du référentiel ; une ligne au plus par unité, de zéro à trois décimales, sans variation des stocks.';

--
-- Name: COLUMN "T_PrecisionStock"."ID_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PrecisionStock"."ID_PrecisionStock" IS 'Identité technique de la politique ; distincte de l’identifiant de l’unité, attribuée automatiquement et immuable.';

--
-- Name: COLUMN "T_PrecisionStock"."ID_UniteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PrecisionStock"."ID_UniteFk" IS 'Unité de stock partagée : FK vers referentiel.T_Generique.ID_Generique, limitée à la catégorie Unités (34), comme T_Article.ID_UniteFk.';

--
-- Name: COLUMN "T_PrecisionStock"."DecimalesStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PrecisionStock"."DecimalesStock" IS 'Nombre explicite de décimales autorisées, entre zéro et trois ; une réduction incompatible avec les quantités courantes ou historiques est refusée.';

--
-- Name: COLUMN "T_PrecisionStock"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_PrecisionStock"."ModifieLe" IS 'Horodatage du dernier changement effectif de précision ; date source conservée à la reprise, ou date réelle d’initialisation en l’absence de réglage antérieur.';

--
-- Name: CONSTRAINT precision_stock_decimales ON "T_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT precision_stock_decimales ON logistique."T_PrecisionStock" IS 'Précision physique bornée entre zéro et trois décimales.';

--
-- Name: T_PrecisionStock_ID_PrecisionStock_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_PrecisionStock" ALTER COLUMN "ID_PrecisionStock" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_PrecisionStock_ID_PrecisionStock_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_PrecisionStock_ID_PrecisionStock_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_PrecisionStock_ID_PrecisionStock_seq" IS 'Identités techniques des politiques de précision, indépendantes des identifiants d’unités.';

--
-- Name: T_Reglements; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Reglements" (
    "ID_Reglement" integer CONSTRAINT "T_Reglements_ID_Reglement_not_null" NOT NULL,
    "CodeFactureFk" character varying(255),
    "ID_ModeReglementFk" integer CONSTRAINT "T_Reglements_ID_ModeReglementFk_not_null" NOT NULL,
    "ID_ClientFk" integer,
    "DateReglement" timestamp without time zone,
    "MontantRegle" numeric(12,2),
    "ID_DeviseFk" integer NOT NULL,
    "ID_TiersFk" bigint,
    "CreeParUserFk" integer,
    "ModifieParUserFk" integer,
    "CreeLe" timestamp with time zone,
    "ModifieLe" timestamp with time zone,
    CONSTRAINT chk_reglement_montant_non_negatif CHECK ((("MontantRegle" IS NULL) OR ("MontantRegle" >= (0)::numeric)))
);

--
-- Name: TABLE "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Reglements" IS 'Règlements d’une facture par CodeFactureFk : montants exacts et origine technique durable. Auteur/date de création immuables, dernière modification attribuée au contexte SQL prouvé et images avant/après auditées dans la même transaction.';

--
-- Name: COLUMN "T_Reglements"."ID_Reglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_Reglement" IS 'Identifiant de l’écriture de règlement.';

--
-- Name: COLUMN "T_Reglements"."CodeFactureFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."CodeFactureFk" IS 'Référence de facture fac-IDBon, conservée atomiquement avec le miroir et le snapshot lors de la renumérotation08.';

--
-- Name: COLUMN "T_Reglements"."ID_ModeReglementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_ModeReglementFk" IS 'Mode du règlement, dans la nomenclature de catégorie 36. Relation imposée : FOREIGN KEY ("ID_ModeReglementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Reglements"."ID_ClientFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_ClientFk" IS 'Identifiant client enregistré pour l’opération ; distinct du nom client saisi librement.';

--
-- Name: COLUMN "T_Reglements"."DateReglement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."DateReglement" IS 'Date métier du règlement.';

--
-- Name: COLUMN "T_Reglements"."MontantRegle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."MontantRegle" IS 'Montant de cette écriture de règlement ; distinct du cumul des règlements de facture.';

--
-- Name: COLUMN "T_Reglements"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_DeviseFk" IS 'Instantané de la devise de la facture rattachée par CodeFactureFk ; règlement en autre devise interdit sans traitement explicite.';

--
-- Name: COLUMN "T_Reglements"."ID_TiersFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ID_TiersFk" IS 'Tiers explicite conservé depuis le bon de la facture ; distinct de l’ancien identifiant client.';

--
-- Name: COLUMN "T_Reglements"."CreeParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."CreeParUserFk" IS 'Auteur actif identifié par le contexte SQL transactionnel lors de la création ; NULL pour les écritures historiques sans preuve. Immuable après création.';

--
-- Name: COLUMN "T_Reglements"."ModifieParUserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ModifieParUserFk" IS 'Auteur actif de la dernière écriture identifié par le contexte SQL ; NULL si aucun acteur applicatif prouvé.';

--
-- Name: COLUMN "T_Reglements"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."CreeLe" IS 'Horodatage technique SQL de création, distinct de DateReglement ; NULL pour les écritures historiques non horodatées.';

--
-- Name: COLUMN "T_Reglements"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Reglements"."ModifieLe" IS 'Horodatage technique SQL de la dernière écriture ; ne modifie pas la date métier du règlement.';

--
-- Name: CONSTRAINT "T_Reglements_ID_Reglement_not_null" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_ID_Reglement_not_null" ON logistique."T_Reglements" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Reglements". Définition : NOT NULL "ID_Reglement".';

--
-- Name: CONSTRAINT "T_Reglements_ID_ModeReglementFk_not_null" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_ID_ModeReglementFk_not_null" ON logistique."T_Reglements" IS 'Non-nullité : exige une valeur renseignée dans "logistique"."T_Reglements". Définition : NOT NULL "ID_ModeReglementFk".';

--
-- Name: CONSTRAINT chk_reglement_montant_non_negatif ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT chk_reglement_montant_non_negatif ON logistique."T_Reglements" IS 'Contrôle de cohérence des valeurs autorisées dans "logistique"."T_Reglements". Définition : CHECK ("MontantRegle" IS NULL OR "MontantRegle" >= 0::numeric).';

--
-- Name: T_Reglements_ID_Reglement_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Reglements" ALTER COLUMN "ID_Reglement" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_Reglements_ID_Reglement_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Reglements_ID_Reglement_seq"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON SEQUENCE logistique."T_Reglements_ID_Reglement_seq" IS 'Séquence de génération de "logistique"."T_Reglements"."ID_Reglement". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Remboursement; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_Remboursement" (
    "ID_Remboursement" bigint NOT NULL,
    "ID_AvoirFk" bigint NOT NULL,
    "Montant" numeric(12,2) NOT NULL,
    "DateRemboursement" timestamp with time zone NOT NULL,
    "ID_ModePaiementFk" integer NOT NULL,
    "ReferenceRemboursement" character varying(200),
    "ID_UserFk" integer NOT NULL,
    "RequestId" uuid NOT NULL,
    "PayloadHash" text NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_Remboursement_Montant_check" CHECK (("Montant" > (0)::numeric))
);

--
-- Name: TABLE "T_Remboursement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_Remboursement" IS 'Remboursement effectivement enregistré contre le disponible d’un avoir ; aucun transfert bancaire automatique.';

--
-- Name: COLUMN "T_Remboursement"."ID_Remboursement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."ID_Remboursement" IS 'Identifiant stable de la preuve de remboursement.';

--
-- Name: COLUMN "T_Remboursement"."ID_AvoirFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."ID_AvoirFk" IS 'Avoir émis dont dépend cette ligne, imputation ou remboursement.';

--
-- Name: COLUMN "T_Remboursement"."Montant"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."Montant" IS 'Montant positif dans la devise de l’avoir.';

--
-- Name: COLUMN "T_Remboursement"."DateRemboursement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."DateRemboursement" IS 'Date et heure du montant effectivement restitué au client.';

--
-- Name: COLUMN "T_Remboursement"."ID_ModePaiementFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."ID_ModePaiementFk" IS 'Mode de remboursement actif issu du référentiel partagé.';

--
-- Name: COLUMN "T_Remboursement"."ReferenceRemboursement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."ReferenceRemboursement" IS 'Référence de caisse, banque ou autre preuve du paiement restitué.';

--
-- Name: COLUMN "T_Remboursement"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."ID_UserFk" IS 'Auteur réel de l’émission, imputation ou remboursement.';

--
-- Name: COLUMN "T_Remboursement"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."RequestId" IS 'Identifiant unique du traitement empêchant les doubles envois.';

--
-- Name: COLUMN "T_Remboursement"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."PayloadHash" IS 'Empreinte canonique à comparer lors du rejeu d’une demande.';

--
-- Name: COLUMN "T_Remboursement"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_Remboursement"."CreeLe" IS 'Horodatage serveur de l’enregistrement.';

--
-- Name: T_Remboursement_ID_Remboursement_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_Remboursement" ALTER COLUMN "ID_Remboursement" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_Remboursement_ID_Remboursement_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_RetourBon; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_RetourBon" (
    "ID_RetourBon" bigint NOT NULL,
    "ID_CommandeOrigineFk" integer NOT NULL,
    "ID_CommandeRetourFk" integer NOT NULL,
    "ID_UserFk" integer NOT NULL,
    "IdEntiteFk" integer,
    "RequestId" uuid NOT NULL,
    "PayloadHash" text NOT NULL,
    "Motif" text NOT NULL,
    "DateRetour" timestamp with time zone NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_retour_bon_distinct CHECK (("ID_CommandeOrigineFk" <> "ID_CommandeRetourFk")),
    CONSTRAINT ck_retour_bon_empreinte CHECK (("PayloadHash" ~ '^[a-f0-9]{64}$'::text)),
    CONSTRAINT ck_retour_bon_motif CHECK (((length(btrim("Motif")) >= 1) AND (length(btrim("Motif")) <= 1000)))
);

--
-- Name: TABLE "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_RetourBon" IS 'Événements validés de retour physique, total ou partiel, d’un bon de sortie. Plusieurs retours peuvent compenser une même origine. Les quantités et valeurs restent dans les lignes et mouvements des bons liés ; aucune annulation de facture ni remboursement n’est implicite.';

--
-- Name: COLUMN "T_RetourBon"."ID_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."ID_RetourBon" IS 'Identifiant stable de l’événement de retour physique.';

--
-- Name: COLUMN "T_RetourBon"."ID_CommandeOrigineFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."ID_CommandeOrigineFk" IS 'Bon de sortie historique compensé ; plusieurs événements successifs sont autorisés dans les limites des quantités et lots d’origine.';

--
-- Name: COLUMN "T_RetourBon"."ID_CommandeRetourFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."ID_CommandeRetourFk" IS 'Bon d’entrée inverse propre à cet événement ; un bon ne peut représenter deux événements de retour.';

--
-- Name: COLUMN "T_RetourBon"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."ID_UserFk" IS 'Utilisateur ayant validé le retour ; indépendant de l’auteur conservé sur le bon d’origine.';

--
-- Name: COLUMN "T_RetourBon"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."IdEntiteFk" IS 'Organisation autorisée au moment du retour, conservée comme instantané ; NULL désigne le contexte de plateforme.';

--
-- Name: COLUMN "T_RetourBon"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."RequestId" IS 'Identifiant de demande fourni par le formulaire et unique pour son auteur, permettant un rejeu sans nouveau crédit de stock.';

--
-- Name: COLUMN "T_RetourBon"."PayloadHash"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."PayloadHash" IS 'Empreinte canonique de la demande validée, hors jetons de session et prix catalogue ; un même UUID ne peut être réutilisé pour un autre retour.';

--
-- Name: COLUMN "T_RetourBon"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."Motif" IS 'Motif humain obligatoire du retour, conservé sans modifier les observations historiques de la sortie.';

--
-- Name: COLUMN "T_RetourBon"."DateRetour"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."DateRetour" IS 'Date et heure métier du retour, correspondant à DateCmd du bon d’entrée ; distinctes de l’instant d’enregistrement.';

--
-- Name: COLUMN "T_RetourBon"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_RetourBon"."CreeLe" IS 'Horodatage d’enregistrement de l’événement dans la transaction.';

--
-- Name: CONSTRAINT ck_retour_bon_distinct ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_retour_bon_distinct ON logistique."T_RetourBon" IS 'Une sortie ne peut pas être son propre bon de retour.';

--
-- Name: CONSTRAINT ck_retour_bon_empreinte ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_retour_bon_empreinte ON logistique."T_RetourBon" IS 'L’empreinte de demande est un SHA-256 hexadécimal.';

--
-- Name: CONSTRAINT ck_retour_bon_motif ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT ck_retour_bon_motif ON logistique."T_RetourBon" IS 'Le motif doit contenir de 1 à 1000 caractères après retrait des espaces de bord.';

--
-- Name: T_RetourBon_ID_RetourBon_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_RetourBon" ALTER COLUMN "ID_RetourBon" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME logistique."T_RetourBon_ID_RetourBon_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_ValorisationEvenement; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_ValorisationEvenement" (
    "ID_Evenement" bigint NOT NULL,
    "ID_ArticleFk" integer NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "ID_UserFk" integer,
    "RequestId" uuid,
    "Operation" text NOT NULL,
    "Motif" text,
    "Avant" jsonb,
    "Apres" jsonb,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_ValorisationEvenement_Operation_check" CHECK (("Operation" = ANY (ARRAY['ouverture'::text, 'reevaluation'::text, 'mouvement_insert'::text, 'mouvement_update'::text, 'mouvement_delete'::text])))
);

--
-- Name: TABLE "T_ValorisationEvenement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_ValorisationEvenement" IS 'Journal append-only des ouvertures, réévaluations et modifications de la source de valorisation ; sans mouvement physique supplémentaire. Les coûts antérieurs connus sont conservés pour valoriser les restitutions au coût de sortie.';

--
-- Name: COLUMN "T_ValorisationEvenement"."ID_Evenement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."ID_Evenement" IS 'ID_Evenement de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationEvenement"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."ID_ArticleFk" IS 'ID_Article de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationEvenement"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."IdEntiteFk" IS 'IdEntite de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationEvenement"."ID_UserFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."ID_UserFk" IS 'ID_User de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationEvenement"."RequestId"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."RequestId" IS 'RequestId de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationEvenement"."Operation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."Operation" IS 'Operation de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationEvenement"."Motif"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."Motif" IS 'Motif de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationEvenement"."Avant"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."Avant" IS 'Instantané JSON antérieur au changement ; contient les coûts précédents lors d’une réévaluation.';

--
-- Name: COLUMN "T_ValorisationEvenement"."Apres"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."Apres" IS 'Instantané JSON après changement ; les paramètres comptables et la source restent auditables.';

--
-- Name: COLUMN "T_ValorisationEvenement"."CreeLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationEvenement"."CreeLe" IS 'CreeLe de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: T_ValorisationEvenement_ID_Evenement_seq; Type: SEQUENCE; Schema: logistique; Owner: -
--

ALTER TABLE logistique."T_ValorisationEvenement" ALTER COLUMN "ID_Evenement" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME logistique."T_ValorisationEvenement_ID_Evenement_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_ValorisationOuverture; Type: TABLE; Schema: logistique; Owner: -
--

CREATE TABLE logistique."T_ValorisationOuverture" (
    "ID_ArticleFk" integer NOT NULL,
    "ID_DeviseFk" integer NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "ID_MvtArrete" integer DEFAULT 0 NOT NULL,
    "QuantiteOuverture" numeric(14,3) NOT NULL,
    "CoutOuverture" numeric(22,6),
    "CoutsAnterieurs" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "Version" bigint DEFAULT 1 NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_ValorisationOuverture_CoutOuverture_check" CHECK ((("CoutOuverture" >= (0)::numeric) AND (("CoutOuverture")::text <> ALL (ARRAY['NaN'::text, 'Infinity'::text, '-Infinity'::text])))),
    CONSTRAINT "T_ValorisationOuverture_check" CHECK ((("QuantiteOuverture" >= (0)::numeric) OR ("CoutOuverture" IS NULL)))
);

--
-- Name: TABLE "T_ValorisationOuverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TABLE logistique."T_ValorisationOuverture" IS 'Dernier arrêté de coût confirmé, par article, propriétaire et devise. Les articles présents avant installation restent à initialiser : aucun coût catalogue ou prix de vente historique n’est accepté implicitement.';

--
-- Name: COLUMN "T_ValorisationOuverture"."ID_ArticleFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."ID_ArticleFk" IS 'ID_Article de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationOuverture"."ID_DeviseFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."ID_DeviseFk" IS 'ID_Devise de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationOuverture"."IdEntiteFk"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."IdEntiteFk" IS 'IdEntite de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationOuverture"."ID_MvtArrete"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."ID_MvtArrete" IS 'Dernier ID_Mvt inclus dans la quantité et le coût d’ouverture ; les événements ultérieurs suivent leur ordre d’enregistrement, même si leur date métier est antérieure.';

--
-- Name: COLUMN "T_ValorisationOuverture"."QuantiteOuverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."QuantiteOuverture" IS 'Quantité signée du journal, dans cette devise, au moment de l’arrêté confirmé.';

--
-- Name: COLUMN "T_ValorisationOuverture"."CoutOuverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."CoutOuverture" IS 'Coût unitaire explicitement confirmé à six décimales ; NULL signifie ouverture requise et ne vaut jamais zéro.';

--
-- Name: COLUMN "T_ValorisationOuverture"."CoutsAnterieurs"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."CoutsAnterieurs" IS 'Coûts unitaires prouvés des mouvements antérieurs à l’arrêté, par ID_Mvt ; permet un retour au coût de sortie historique sans prix catalogue.';

--
-- Name: COLUMN "T_ValorisationOuverture"."Version"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."Version" IS 'Version de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: COLUMN "T_ValorisationOuverture"."ModifieLe"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON COLUMN logistique."T_ValorisationOuverture"."ModifieLe" IS 'ModifieLe de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.';

--
-- Name: T_Article T_Article_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "T_Article_pkey" PRIMARY KEY ("ID_Article");

--
-- Name: CONSTRAINT "T_Article_pkey" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Article_pkey" ON logistique."T_Article" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Article". Définition : PRIMARY KEY ("ID_Article").';

--
-- Name: T_AvoirAffectation T_AvoirAffectation_ID_UserFk_RequestId_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirAffectation"
    ADD CONSTRAINT "T_AvoirAffectation_ID_UserFk_RequestId_key" UNIQUE ("ID_UserFk", "RequestId");

--
-- Name: T_AvoirAffectation T_AvoirAffectation_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirAffectation"
    ADD CONSTRAINT "T_AvoirAffectation_pkey" PRIMARY KEY ("ID_Affectation");

--
-- Name: T_AvoirLigne T_AvoirLigne_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirLigne"
    ADD CONSTRAINT "T_AvoirLigne_pkey" PRIMARY KEY ("ID_AvoirFk", "ID_ArticleFk");

--
-- Name: T_Avoir T_Avoir_CodeAvoir_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_CodeAvoir_key" UNIQUE ("CodeAvoir");

--
-- Name: T_Avoir T_Avoir_ID_UserFk_RequestId_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_ID_UserFk_RequestId_key" UNIQUE ("ID_UserFk", "RequestId");

--
-- Name: T_Avoir T_Avoir_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_pkey" PRIMARY KEY ("ID_Avoir");

--
-- Name: T_BonCodeHistorique T_BonCodeHistorique_ID_Commande_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_BonCodeHistorique"
    ADD CONSTRAINT "T_BonCodeHistorique_ID_Commande_key" UNIQUE ("ID_Commande");

--
-- Name: CONSTRAINT "T_BonCodeHistorique_ID_Commande_key" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_ID_Commande_key" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: T_BonCodeHistorique T_BonCodeHistorique_NouveauCodeCmd_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_BonCodeHistorique"
    ADD CONSTRAINT "T_BonCodeHistorique_NouveauCodeCmd_key" UNIQUE ("NouveauCodeCmd");

--
-- Name: CONSTRAINT "T_BonCodeHistorique_NouveauCodeCmd_key" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_NouveauCodeCmd_key" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: T_BonCodeHistorique T_BonCodeHistorique_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_BonCodeHistorique"
    ADD CONSTRAINT "T_BonCodeHistorique_pkey" PRIMARY KEY ("ID_BonCodeHistorique");

--
-- Name: CONSTRAINT "T_BonCodeHistorique_pkey" ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_BonCodeHistorique_pkey" ON logistique."T_BonCodeHistorique" IS 'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.';

--
-- Name: T_CategorieDossierSuivi T_CategorieDossierSuivi_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CategorieDossierSuivi"
    ADD CONSTRAINT "T_CategorieDossierSuivi_pkey" PRIMARY KEY ("ID_CategorieDossierSuivi");

--
-- Name: T_Client T_Client_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_pkey" PRIMARY KEY ("ID_Client");

--
-- Name: CONSTRAINT "T_Client_pkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_pkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_CommandeDetail T_CommandeDetail_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CommandeDetail"
    ADD CONSTRAINT "T_CommandeDetail_pkey" PRIMARY KEY ("ID_ArticleFk", "ID_CmdFk");

--
-- Name: CONSTRAINT "T_CommandeDetail_pkey" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_CommandeDetail_pkey" ON logistique."T_CommandeDetail" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_CommandeDetail". Définition : PRIMARY KEY ("ID_ArticleFk", "ID_CmdFk").';

--
-- Name: T_Commande T_Commande_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "T_Commande_pkey" PRIMARY KEY ("ID_Commande");

--
-- Name: CONSTRAINT "T_Commande_pkey" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Commande_pkey" ON logistique."T_Commande" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Commande". Définition : PRIMARY KEY ("ID_Commande").';

--
-- Name: T_DocumentIdentite T_DocumentIdentite_TypeObjet_ID_Objet_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DocumentIdentite"
    ADD CONSTRAINT "T_DocumentIdentite_TypeObjet_ID_Objet_key" UNIQUE ("TypeObjet", "ID_Objet");

--
-- Name: T_DocumentIdentite T_DocumentIdentite_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DocumentIdentite"
    ADD CONSTRAINT "T_DocumentIdentite_pkey" PRIMARY KEY ("ID_DocumentIdentite");

--
-- Name: T_DossierSuiviMembre T_DossierSuiviMembre_ID_DossierSuiviFk_ID_ArticleFk_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuiviMembre"
    ADD CONSTRAINT "T_DossierSuiviMembre_ID_DossierSuiviFk_ID_ArticleFk_key" UNIQUE ("ID_DossierSuiviFk", "ID_ArticleFk");

--
-- Name: T_DossierSuiviMembre T_DossierSuiviMembre_ID_DossierSuiviFk_ID_CommandeFk_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuiviMembre"
    ADD CONSTRAINT "T_DossierSuiviMembre_ID_DossierSuiviFk_ID_CommandeFk_key" UNIQUE ("ID_DossierSuiviFk", "ID_CommandeFk");

--
-- Name: T_DossierSuiviMembre T_DossierSuiviMembre_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuiviMembre"
    ADD CONSTRAINT "T_DossierSuiviMembre_pkey" PRIMARY KEY ("ID_Membre");

--
-- Name: T_DossierSuivi T_DossierSuivi_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuivi"
    ADD CONSTRAINT "T_DossierSuivi_pkey" PRIMARY KEY ("ID_DossierSuivi");

--
-- Name: T_FactureLigne T_FactureLigne_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_FactureLigne"
    ADD CONSTRAINT "T_FactureLigne_pkey" PRIMARY KEY ("ID_FactureLigne");

--
-- Name: CONSTRAINT "T_FactureLigne_pkey" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_pkey" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_CodeFacture_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_CodeFacture_key" UNIQUE ("CodeFacture");

--
-- Name: CONSTRAINT "T_Facture_CodeFacture_key" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_CodeFacture_key" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_ID_CommandeFk_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_ID_CommandeFk_key" UNIQUE ("ID_CommandeFk");

--
-- Name: CONSTRAINT "T_Facture_ID_CommandeFk_key" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_CommandeFk_key" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_pkey" PRIMARY KEY ("ID_Facture");

--
-- Name: CONSTRAINT "T_Facture_pkey" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_pkey" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Immobilisation T_Immobilisation_CodeImmobilisation_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_CodeImmobilisation_key" UNIQUE ("CodeImmobilisation");

--
-- Name: CONSTRAINT "T_Immobilisation_CodeImmobilisation_key" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_CodeImmobilisation_key" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : UNIQUE ("CodeImmobilisation"). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_pkey" PRIMARY KEY ("ID_Immobilisation");

--
-- Name: CONSTRAINT "T_Immobilisation_pkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_pkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : PRIMARY KEY ("ID_Immobilisation"). Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_InventaireLigne T_InventaireLigne_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_InventaireLigne"
    ADD CONSTRAINT "T_InventaireLigne_pkey" PRIMARY KEY ("ID_InventaireFk", "ID_ArticleFk");

--
-- Name: T_Inventaire T_Inventaire_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Inventaire"
    ADD CONSTRAINT "T_Inventaire_pkey" PRIMARY KEY ("ID_Inventaire");

--
-- Name: T_LotArticle T_LotArticle_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_LotArticle"
    ADD CONSTRAINT "T_LotArticle_pkey" PRIMARY KEY ("ID_LotArticle");

--
-- Name: T_MouvementLot T_MouvementLot_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_MouvementLot"
    ADD CONSTRAINT "T_MouvementLot_pkey" PRIMARY KEY ("ID_MvtFk", "ID_LotArticleFk");

--
-- Name: T_Mouvement T_Mouvement_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "T_Mouvement_pkey" PRIMARY KEY ("ID_Mvt");

--
-- Name: CONSTRAINT "T_Mouvement_pkey" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Mouvement_pkey" ON logistique."T_Mouvement" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Mouvement". Définition : PRIMARY KEY ("ID_Mvt").';

--
-- Name: T_PieceJustificative T_PieceJustificative_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_PieceJustificative"
    ADD CONSTRAINT "T_PieceJustificative_pkey" PRIMARY KEY ("ID_Piece");

--
-- Name: T_Reglements T_Reglements_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "T_Reglements_pkey" PRIMARY KEY ("ID_Reglement");

--
-- Name: CONSTRAINT "T_Reglements_pkey" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_pkey" ON logistique."T_Reglements" IS 'Clé primaire : identifie de manière unique chaque ligne dans "logistique"."T_Reglements". Définition : PRIMARY KEY ("ID_Reglement").';

--
-- Name: T_Remboursement T_Remboursement_ID_UserFk_RequestId_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Remboursement"
    ADD CONSTRAINT "T_Remboursement_ID_UserFk_RequestId_key" UNIQUE ("ID_UserFk", "RequestId");

--
-- Name: T_Remboursement T_Remboursement_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Remboursement"
    ADD CONSTRAINT "T_Remboursement_pkey" PRIMARY KEY ("ID_Remboursement");

--
-- Name: T_RetourBon T_RetourBon_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_RetourBon"
    ADD CONSTRAINT "T_RetourBon_pkey" PRIMARY KEY ("ID_RetourBon");

--
-- Name: T_ValorisationEvenement T_ValorisationEvenement_ID_UserFk_RequestId_key; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationEvenement"
    ADD CONSTRAINT "T_ValorisationEvenement_ID_UserFk_RequestId_key" UNIQUE ("ID_UserFk", "RequestId");

--
-- Name: T_ValorisationEvenement T_ValorisationEvenement_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationEvenement"
    ADD CONSTRAINT "T_ValorisationEvenement_pkey" PRIMARY KEY ("ID_Evenement");

--
-- Name: T_ValorisationOuverture T_ValorisationOuverture_pkey; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationOuverture"
    ADD CONSTRAINT "T_ValorisationOuverture_pkey" PRIMARY KEY ("ID_ArticleFk", "ID_DeviseFk");

--
-- Name: T_PrecisionStock precision_stock_pk; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_PrecisionStock"
    ADD CONSTRAINT precision_stock_pk PRIMARY KEY ("ID_PrecisionStock");

--
-- Name: CONSTRAINT precision_stock_pk ON "T_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT precision_stock_pk ON logistique."T_PrecisionStock" IS 'Clé technique unique de politique de précision.';

--
-- Name: T_PrecisionStock precision_stock_unite_unique; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_PrecisionStock"
    ADD CONSTRAINT precision_stock_unite_unique UNIQUE ("ID_UniteFk");

--
-- Name: CONSTRAINT precision_stock_unite_unique ON "T_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT precision_stock_unite_unique ON logistique."T_PrecisionStock" IS 'Une politique partagée au plus par unité de stock.';

--
-- Name: T_Article uq_article_codeinterne; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT uq_article_codeinterne UNIQUE ("IdEntiteFk", "CodeArticleInterne");

--
-- Name: CONSTRAINT uq_article_codeinterne ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_article_codeinterne ON logistique."T_Article" IS 'Code interne unique dans une entreprise ; deux entreprises peuvent employer le même code catalogue sans partager leurs données.';

--
-- Name: T_Commande uq_commande_codecmd; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT uq_commande_codecmd UNIQUE ("CodeCmd");

--
-- Name: CONSTRAINT uq_commande_codecmd ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_commande_codecmd ON logistique."T_Commande" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "logistique"."T_Commande". Définition : UNIQUE ("CodeCmd").';

--
-- Name: T_Commande uq_commande_codefacture; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT uq_commande_codefacture UNIQUE ("CodeFacture");

--
-- Name: CONSTRAINT uq_commande_codefacture ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_commande_codefacture ON logistique."T_Commande" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "logistique"."T_Commande". Définition : UNIQUE ("CodeFacture").';

--
-- Name: T_FactureLigne uq_facture_article; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_FactureLigne"
    ADD CONSTRAINT uq_facture_article UNIQUE ("ID_FactureFk", "ID_ArticleFk");

--
-- Name: CONSTRAINT uq_facture_article ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_facture_article ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture uq_facture_request; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT uq_facture_request UNIQUE ("ID_UserFk", "RequestId");

--
-- Name: CONSTRAINT uq_facture_request ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_facture_request ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_RetourBon uq_retour_bon_demande; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_RetourBon"
    ADD CONSTRAINT uq_retour_bon_demande UNIQUE ("ID_UserFk", "RequestId");

--
-- Name: CONSTRAINT uq_retour_bon_demande ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_retour_bon_demande ON logistique."T_RetourBon" IS 'Un auteur et un UUID de demande ne peuvent créditer le stock qu’une fois.';

--
-- Name: T_RetourBon uq_retour_bon_entree; Type: CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_RetourBon"
    ADD CONSTRAINT uq_retour_bon_entree UNIQUE ("ID_CommandeRetourFk");

--
-- Name: CONSTRAINT uq_retour_bon_entree ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT uq_retour_bon_entree ON logistique."T_RetourBon" IS 'Un bon d’entrée inverse appartient à un seul événement de retour.';

--
-- Name: INDEX "T_Article_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Article_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Article_pkey" ON logistique."T_Article" USING btree ("ID_Article").';

--
-- Name: INDEX "T_BonCodeHistorique_ID_Commande_key"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_BonCodeHistorique_ID_Commande_key" IS 'Index d’intégrité et de recherche du journal06 : une correspondance par bon et un nouveau code unique.';

--
-- Name: INDEX "T_BonCodeHistorique_NouveauCodeCmd_key"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_BonCodeHistorique_NouveauCodeCmd_key" IS 'Index d’intégrité et de recherche du journal06 : une correspondance par bon et un nouveau code unique.';

--
-- Name: INDEX "T_BonCodeHistorique_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_BonCodeHistorique_pkey" IS 'Index d’intégrité et de recherche du journal06 : une correspondance par bon et un nouveau code unique.';

--
-- Name: INDEX "T_CommandeDetail_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_CommandeDetail_pkey" IS 'Index support de la clé primaire sur "logistique"."T_CommandeDetail". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_CommandeDetail_pkey" ON logistique."T_CommandeDetail" USING btree ("ID_ArticleFk", "ID_CmdFk").';

--
-- Name: INDEX "T_Commande_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Commande_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Commande_pkey" ON logistique."T_Commande" USING btree ("ID_Commande").';

--
-- Name: INDEX "T_FactureLigne_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_FactureLigne_pkey" IS 'Unicité et accès aux instantanés de facturation par identité, bon, article ou demande idempotente.';

--
-- Name: INDEX "T_Facture_CodeFacture_key"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Facture_CodeFacture_key" IS 'Unicité et accès aux instantanés de facturation par identité, bon, article ou demande idempotente.';

--
-- Name: INDEX "T_Facture_ID_CommandeFk_key"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Facture_ID_CommandeFk_key" IS 'Unicité et accès aux instantanés de facturation par identité, bon, article ou demande idempotente.';

--
-- Name: INDEX "T_Facture_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Facture_pkey" IS 'Unicité et accès aux instantanés de facturation par identité, bon, article ou demande idempotente.';

--
-- Name: INDEX "T_Immobilisation_CodeImmobilisation_key"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Immobilisation_CodeImmobilisation_key" IS 'Unicité de l’identité technique ou du code immuable de patrimoine.';

--
-- Name: INDEX "T_Immobilisation_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Immobilisation_pkey" IS 'Unicité de l’identité technique ou du code immuable de patrimoine.';

--
-- Name: INDEX "T_Mouvement_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Mouvement_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Mouvement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Mouvement_pkey" ON logistique."T_Mouvement" USING btree ("ID_Mvt").';

--
-- Name: INDEX "T_Reglements_pkey"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique."T_Reglements_pkey" IS 'Index support de la clé primaire sur "logistique"."T_Reglements". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Reglements_pkey" ON logistique."T_Reglements" USING btree ("ID_Reglement").';

--
-- Name: article_creation_demande_unique; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX article_creation_demande_unique ON logistique."T_Article" USING btree ("IdEntiteFk", "ID_UserFK", "CreationRequestId") WHERE ("CreationRequestId" IS NOT NULL);

--
-- Name: INDEX article_creation_demande_unique; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.article_creation_demande_unique IS 'Un UUID de creation par utilisateur et entreprise ne peut produire deux articles.';

--
-- Name: bon_stock_initial_unique; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX bon_stock_initial_unique ON logistique."T_Commande" USING btree ("ID_ArticleInitialFk") WHERE ("OrigineBon" = 'stock_initial'::text);

--
-- Name: INDEX bon_stock_initial_unique; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.bon_stock_initial_unique IS 'Un seul bon automatique de creation par article; les reprises historiques distinctes restent tracables.';

--
-- Name: categorie_dossier_suivi_nom_actif; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX categorie_dossier_suivi_nom_actif ON logistique."T_CategorieDossierSuivi" USING btree ("ID_UserFk", COALESCE("IdEntiteFk", 0), lower(btrim(("Nom")::text))) WHERE "Actif";

--
-- Name: dossier_suivi_categorie; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX dossier_suivi_categorie ON logistique."T_DossierSuivi" USING btree ("ID_CategorieDossierSuiviFk");

--
-- Name: dossier_suivi_membre_article; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX dossier_suivi_membre_article ON logistique."T_DossierSuiviMembre" USING btree ("ID_ArticleFk", "ID_DossierSuiviFk") WHERE "Actif";

--
-- Name: dossier_suivi_membre_bon; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX dossier_suivi_membre_bon ON logistique."T_DossierSuiviMembre" USING btree ("ID_CommandeFk", "ID_DossierSuiviFk") WHERE "Actif";

--
-- Name: dossier_suivi_nom_actif; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX dossier_suivi_nom_actif ON logistique."T_DossierSuivi" USING btree ("ID_UserFk", COALESCE("IdEntiteFk", 0), lower(btrim(("Nom")::text))) WHERE "Actif";

--
-- Name: idx_article_categorie; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_categorie ON logistique."T_Article" USING btree ("ID_CategorieArticleFk");

--
-- Name: INDEX idx_article_categorie; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_categorie IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_categorie ON logistique."T_Article" USING btree ("ID_CategorieArticleFk").';

--
-- Name: idx_article_nom; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_nom ON logistique."T_Article" USING btree ("NomArticle");

--
-- Name: INDEX idx_article_nom; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_nom IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_nom ON logistique."T_Article" USING btree ("NomArticle").';

--
-- Name: idx_article_nom_trgm; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_nom_trgm ON logistique."T_Article" USING gin ("NomArticle" public.gin_trgm_ops);

--
-- Name: INDEX idx_article_nom_trgm; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_nom_trgm IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_nom_trgm ON logistique."T_Article" USING gin ("NomArticle" gin_trgm_ops).';

--
-- Name: idx_article_type; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_type ON logistique."T_Article" USING btree ("ID_TypeArticleFk");

--
-- Name: INDEX idx_article_type; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_type IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_type ON logistique."T_Article" USING btree ("ID_TypeArticleFk").';

--
-- Name: idx_article_unite; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_article_unite ON logistique."T_Article" USING btree ("ID_UniteFk");

--
-- Name: INDEX idx_article_unite; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_article_unite IS 'Index d’accès sur "logistique"."T_Article". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_article_unite ON logistique."T_Article" USING btree ("ID_UniteFk").';

--
-- Name: idx_cmd_client; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_client ON logistique."T_Commande" USING btree ("ID_ClientFk");

--
-- Name: INDEX idx_cmd_client; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_client IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_client ON logistique."T_Commande" USING btree ("ID_ClientFk").';

--
-- Name: idx_cmd_date; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_date ON logistique."T_Commande" USING btree ("DateCmd");

--
-- Name: INDEX idx_cmd_date; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_date IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_date ON logistique."T_Commande" USING btree ("DateCmd").';

--
-- Name: idx_cmd_type; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_type ON logistique."T_Commande" USING btree ("ID_TypeCmdFk");

--
-- Name: INDEX idx_cmd_type; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_type IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_type ON logistique."T_Commande" USING btree ("ID_TypeCmdFk").';

--
-- Name: idx_cmd_user; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmd_user ON logistique."T_Commande" USING btree ("ID_UserFk");

--
-- Name: INDEX idx_cmd_user; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmd_user IS 'Index d’accès sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmd_user ON logistique."T_Commande" USING btree ("ID_UserFk").';

--
-- Name: idx_cmddetail_article; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmddetail_article ON logistique."T_CommandeDetail" USING btree ("ID_ArticleFk");

--
-- Name: INDEX idx_cmddetail_article; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmddetail_article IS 'Index d’accès sur "logistique"."T_CommandeDetail". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmddetail_article ON logistique."T_CommandeDetail" USING btree ("ID_ArticleFk").';

--
-- Name: idx_cmddetail_cmd; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_cmddetail_cmd ON logistique."T_CommandeDetail" USING btree ("ID_CmdFk");

--
-- Name: INDEX idx_cmddetail_cmd; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_cmddetail_cmd IS 'Index d’accès sur "logistique"."T_CommandeDetail". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_cmddetail_cmd ON logistique."T_CommandeDetail" USING btree ("ID_CmdFk").';

--
-- Name: idx_mvt_article; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_mvt_article ON logistique."T_Mouvement" USING btree ("ID_ArticleFk");

--
-- Name: INDEX idx_mvt_article; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_mvt_article IS 'Index d’accès sur "logistique"."T_Mouvement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_mvt_article ON logistique."T_Mouvement" USING btree ("ID_ArticleFk").';

--
-- Name: idx_mvt_cmd; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_mvt_cmd ON logistique."T_Mouvement" USING btree ("ID_cmdFk");

--
-- Name: INDEX idx_mvt_cmd; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_mvt_cmd IS 'Index d’accès sur "logistique"."T_Mouvement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_mvt_cmd ON logistique."T_Mouvement" USING btree ("ID_cmdFk").';

--
-- Name: idx_reglement_client; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_reglement_client ON logistique."T_Reglements" USING btree ("ID_ClientFk");

--
-- Name: INDEX idx_reglement_client; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_reglement_client IS 'Index d’accès sur "logistique"."T_Reglements". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_reglement_client ON logistique."T_Reglements" USING btree ("ID_ClientFk").';

--
-- Name: idx_reglement_date; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX idx_reglement_date ON logistique."T_Reglements" USING btree ("DateReglement");

--
-- Name: INDEX idx_reglement_date; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.idx_reglement_date IS 'Index d’accès sur "logistique"."T_Reglements". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_reglement_date ON logistique."T_Reglements" USING btree ("DateReglement").';

--
-- Name: inventaire_annulation_bon_unique; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX inventaire_annulation_bon_unique ON logistique."T_InventaireLigne" USING btree ("ID_CommandeAnnulationFk") WHERE ("ID_CommandeAnnulationFk" IS NOT NULL);

--
-- Name: INDEX inventaire_annulation_bon_unique; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.inventaire_annulation_bon_unique IS 'Un bon compensateur par ligne d’inventaire, sans réutilisation.';

--
-- Name: inventaire_entite_date; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX inventaire_entite_date ON logistique."T_Inventaire" USING btree ("IdEntiteFk", "DateInventaire" DESC);

--
-- Name: ix_affectation_avoir; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_affectation_avoir ON logistique."T_AvoirAffectation" USING btree ("ID_AvoirFk");

--
-- Name: ix_affectation_cible; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_affectation_cible ON logistique."T_AvoirAffectation" USING btree ("ID_CommandeCibleFk");

--
-- Name: ix_article_entite; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_article_entite ON logistique."T_Article" USING btree ("IdEntiteFk", "ID_Article");

--
-- Name: INDEX ix_article_entite; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_article_entite IS 'Accès au périmètre entreprise et aux documents liés du tiers, sans dépendre du créateur actuel.';

--
-- Name: ix_avoir_entite; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_avoir_entite ON logistique."T_Avoir" USING btree ("IdEntiteFk");

--
-- Name: ix_avoir_facture; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_avoir_facture ON logistique."T_Avoir" USING btree ("ID_FactureFk");

--
-- Name: ix_client_entite_nom; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_client_entite_nom ON logistique."T_Client" USING btree ("IdEntiteFk", lower("Nom"), "ID_Client");

--
-- Name: INDEX ix_client_entite_nom; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_client_entite_nom IS 'Accès au périmètre entreprise et aux documents liés du tiers, sans dépendre du créateur actuel.';

--
-- Name: ix_commande_destination; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_commande_destination ON logistique."T_Commande" USING btree ("ID_DestinationFk") WHERE ("ID_DestinationFk" IS NOT NULL);

--
-- Name: INDEX ix_commande_destination; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_commande_destination IS 'Accélère les recherches de bons par destination géographique référencée.';

--
-- Name: ix_commande_entite; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_commande_entite ON logistique."T_Commande" USING btree ("IdEntiteFk", "DateCmd", "ID_Commande");

--
-- Name: INDEX ix_commande_entite; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_commande_entite IS 'Accès au périmètre entreprise et aux documents liés du tiers, sans dépendre du créateur actuel.';

--
-- Name: ix_commande_tiers; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_commande_tiers ON logistique."T_Commande" USING btree ("ID_TiersFk") WHERE ("ID_TiersFk" IS NOT NULL);

--
-- Name: INDEX ix_commande_tiers; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_commande_tiers IS 'Accès au périmètre entreprise et aux documents liés du tiers, sans dépendre du créateur actuel.';

--
-- Name: ix_immobilisation_entite_actif; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_immobilisation_entite_actif ON logistique."T_Immobilisation" USING btree ("IdEntiteFk", "Actif", "ID_Immobilisation");

--
-- Name: INDEX ix_immobilisation_entite_actif; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_immobilisation_entite_actif IS 'Registre et pagination stable par entreprise, état d’archivage et identifiant.';

--
-- Name: ix_immobilisation_localisation; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_immobilisation_localisation ON logistique."T_Immobilisation" USING btree ("ID_LocalisationFk") WHERE ("ID_LocalisationFk" IS NOT NULL);

--
-- Name: INDEX ix_immobilisation_localisation; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_immobilisation_localisation IS 'Biens liés à une localisation d’entreprise ; protège son propriétaire et facilite la consultation.';

--
-- Name: ix_immobilisation_responsable; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_immobilisation_responsable ON logistique."T_Immobilisation" USING btree ("ID_ResponsableFk") WHERE ("ID_ResponsableFk" IS NOT NULL);

--
-- Name: INDEX ix_immobilisation_responsable; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_immobilisation_responsable IS 'Affectations conservées par responsable ; contrôle des transferts d’entreprise et consultation de ses biens.';

--
-- Name: ix_inventaire_ligne_bon_correction; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_inventaire_ligne_bon_correction ON logistique."T_InventaireLigne" USING btree ("ID_CommandeCorrectionFk") WHERE ("ID_CommandeCorrectionFk" IS NOT NULL);

--
-- Name: INDEX ix_inventaire_ligne_bon_correction; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_inventaire_ligne_bon_correction IS 'Accélère la classification d’un bon d’écart vers son inventaire sans recherche textuelle.';

--
-- Name: ix_piece_entite; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_piece_entite ON logistique."T_PieceJustificative" USING btree ("IdEntiteFk");

--
-- Name: ix_piece_parent; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_piece_parent ON logistique."T_PieceJustificative" USING btree ("TypeObjet", "ID_Objet", "Archive");

--
-- Name: ix_reglement_tiers; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_reglement_tiers ON logistique."T_Reglements" USING btree ("ID_TiersFk") WHERE ("ID_TiersFk" IS NOT NULL);

--
-- Name: INDEX ix_reglement_tiers; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_reglement_tiers IS 'Accès au périmètre entreprise et aux documents liés du tiers, sans dépendre du créateur actuel.';

--
-- Name: ix_remboursement_avoir; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_remboursement_avoir ON logistique."T_Remboursement" USING btree ("ID_AvoirFk");

--
-- Name: ix_retour_bon_entite_date; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_retour_bon_entite_date ON logistique."T_RetourBon" USING btree ("IdEntiteFk", "DateRetour", "ID_RetourBon");

--
-- Name: INDEX ix_retour_bon_entite_date; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_retour_bon_entite_date IS 'Accélère le suivi chronologique des retours par organisation.';

--
-- Name: ix_retour_bon_origine; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX ix_retour_bon_origine ON logistique."T_RetourBon" USING btree ("ID_CommandeOrigineFk", "ID_RetourBon");

--
-- Name: INDEX ix_retour_bon_origine; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.ix_retour_bon_origine IS 'Accélère le cumul des retours par sortie d’origine sans imposer un retour unique.';

--
-- Name: lot_article_numero_unique; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX lot_article_numero_unique ON logistique."T_LotArticle" USING btree ("ID_ArticleFk", lower(btrim(("NumeroLot")::text)));

--
-- Name: mouvement_article_devise_ordre; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX mouvement_article_devise_ordre ON logistique."T_Mouvement" USING btree ("ID_ArticleFk", "ID_DeviseFk", "ID_Mvt");

--
-- Name: INDEX mouvement_article_devise_ordre; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.mouvement_article_devise_ordre IS 'Parcours CUMP dans l’ordre d’enregistrement, par article et devise.';

--
-- Name: mouvement_lot_lot; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX mouvement_lot_lot ON logistique."T_MouvementLot" USING btree ("ID_LotArticleFk");

--
-- Name: INDEX precision_stock_pk; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.precision_stock_pk IS 'Accès à une politique par son identité technique.';

--
-- Name: INDEX precision_stock_unite_unique; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.precision_stock_unite_unique IS 'Accès et unicité de la politique par unité du référentiel.';

--
-- Name: INDEX uq_article_codeinterne; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_article_codeinterne IS 'Unicité du code article par propriétaire durable, conservant la comparaison textuelle existante et les codes NULL.';

--
-- Name: INDEX uq_commande_codecmd; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_commande_codecmd IS 'Index d’unicité sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_commande_codecmd ON logistique."T_Commande" USING btree ("CodeCmd").';

--
-- Name: INDEX uq_commande_codefacture; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_commande_codefacture IS 'Index d’unicité sur "logistique"."T_Commande". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_commande_codefacture ON logistique."T_Commande" USING btree ("CodeFacture").';

--
-- Name: INDEX uq_facture_article; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_facture_article IS 'Unicité et accès aux instantanés de facturation par identité, bon, article ou demande idempotente.';

--
-- Name: INDEX uq_facture_request; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_facture_request IS 'Unicité et accès aux instantanés de facturation par identité, bon, article ou demande idempotente.';

--
-- Name: uq_mouvement_ligne_commande; Type: INDEX; Schema: logistique; Owner: -
--

CREATE UNIQUE INDEX uq_mouvement_ligne_commande ON logistique."T_Mouvement" USING btree ("ID_cmdFk", "ID_ArticleFk") WHERE ("ID_cmdFk" IS NOT NULL);

--
-- Name: INDEX uq_mouvement_ligne_commande; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.uq_mouvement_ligne_commande IS 'Un seul mouvement source par paire commande/article ; les ajustements d’article sans commande restent multiples.';

--
-- Name: valorisation_evenement_article; Type: INDEX; Schema: logistique; Owner: -
--

CREATE INDEX valorisation_evenement_article ON logistique."T_ValorisationEvenement" USING btree ("ID_ArticleFk", "ID_Evenement");

--
-- Name: INDEX valorisation_evenement_article; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON INDEX logistique.valorisation_evenement_article IS 'Historique des coûts et corrections par article, sans lecture interentreprises implicite.';

--
-- Name: V_Inventaire _RETURN; Type: RULE; Schema: logistique; Owner: -
--

CREATE OR REPLACE VIEW logistique."V_Inventaire" AS
 SELECT v."ID_Inventaire",
    v."IdEntiteFk",
    v."ID_UserFk",
    v."DateInventaire",
    v."Motif",
    v."Etat",
    v."Version",
    v."CreeLe",
    v."ModifieLe",
    v."ValideLe",
    v."ID_ValidateurFk",
    v."ValidationRequest",
    v."ValidationHash",
    v."CodeInventaire",
    v."NbArticles",
    v."NbEcarts",
    h."AnnuleLe",
    h."ID_AnnulateurFk",
    h."MotifAnnulation",
    h."AnnulationRequest",
    h."AnnulationHash"
   FROM (( SELECT h_1."ID_Inventaire",
            h_1."IdEntiteFk",
            h_1."ID_UserFk",
            h_1."DateInventaire",
            h_1."Motif",
            h_1."Etat",
            h_1."Version",
            h_1."CreeLe",
            h_1."ModifieLe",
            h_1."ValideLe",
            h_1."ID_ValidateurFk",
            h_1."ValidationRequest",
            h_1."ValidationHash",
            ('inv-'::text || h_1."ID_Inventaire") AS "CodeInventaire",
            count(l."ID_ArticleFk") AS "NbArticles",
            count(*) FILTER (WHERE (l."QteComptee" <> l."QteTheorique")) AS "NbEcarts"
           FROM (logistique."T_Inventaire" h_1
             LEFT JOIN logistique."T_InventaireLigne" l ON ((l."ID_InventaireFk" = h_1."ID_Inventaire")))
          GROUP BY h_1."ID_Inventaire") v
     JOIN logistique."T_Inventaire" h USING ("ID_Inventaire"));

--
-- Name: V_LotArticleStock _RETURN; Type: RULE; Schema: logistique; Owner: -
--

CREATE OR REPLACE VIEW logistique."V_LotArticleStock" AS
 SELECT l."ID_LotArticle",
    l."ID_ArticleFk",
    l."NumeroLot",
    l."DatePeremptionLot",
    l."Actif",
    l."CreeLe",
    l."StockLot",
    l."QuantiteEntree",
    l."QuantiteSortie",
    l."ID_DeviseFk",
    l."DeviseCode",
    l."DeviseLibelle",
        CASE
            WHEN (l."DatePeremptionLot" IS NULL) THEN 'Non renseignée'::text
            WHEN (l."DatePeremptionLot" < ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) THEN 'Périmé'::text
            WHEN (l."DatePeremptionLot" <= (((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date + COALESCE(a."NbreJoursAlerteArticle", (e."AlertePeremptionJours")::integer, 30))) THEN 'Proche'::text
            ELSE 'Valide'::text
        END AS "EtatPeremptionLot",
    ((l."DatePeremptionLot" < ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) IS TRUE) AS "EstPerime",
    (((l."DatePeremptionLot" >= ((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date) AND (l."DatePeremptionLot" <= (((CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa'::text))::date + COALESCE(a."NbreJoursAlerteArticle", (e."AlertePeremptionJours")::integer, 30)))) IS TRUE) AS "EstProche",
    COALESCE(a."NbreJoursAlerteArticle", (e."AlertePeremptionJours")::integer, 30) AS "SeuilAlerteJours",
    e."BloquerLotsPerimes"
   FROM ((( SELECT historique."ID_LotArticle",
            historique."ID_ArticleFk",
            historique."NumeroLot",
            historique."DatePeremptionLot",
            historique."Actif",
            historique."CreeLe",
            historique."StockLot",
            historique."QuantiteEntree",
            historique."QuantiteSortie",
            source."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT l_1."ID_LotArticle",
                    l_1."ID_ArticleFk",
                    l_1."NumeroLot",
                    l_1."DatePeremptionLot",
                    l_1."Actif",
                    l_1."CreeLe",
                    COALESCE(sum((ml."Quantite" * (m."SigneStock")::numeric)), ((0)::bigint)::numeric) AS "StockLot",
                    COALESCE(sum(ml."Quantite") FILTER (WHERE (m."SigneStock" = 1)), ((0)::bigint)::numeric) AS "QuantiteEntree",
                    COALESCE(sum(ml."Quantite") FILTER (WHERE (m."SigneStock" = '-1'::integer)), ((0)::bigint)::numeric) AS "QuantiteSortie"
                   FROM ((logistique."T_LotArticle" l_1
                     LEFT JOIN logistique."T_MouvementLot" ml ON ((ml."ID_LotArticleFk" = l_1."ID_LotArticle")))
                     LEFT JOIN logistique."V_MouvementStock" m ON ((m."ID_Mvt" = ml."ID_MvtFk")))
                  GROUP BY l_1."ID_LotArticle") historique
             LEFT JOIN logistique."T_Article" source ON ((source."ID_Article" = historique."ID_ArticleFk")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source."ID_DeviseFk")))) l
     JOIN logistique."T_Article" a ON ((a."ID_Article" = l."ID_ArticleFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = a."IdEntiteFk")));

--
-- Name: T_Article a00_article_creation_immuable; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a00_article_creation_immuable BEFORE UPDATE OF "CreationRequestId", "CreationPayloadHash", "ID_UserFK" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();

--
-- Name: TRIGGER a00_article_creation_immuable ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a00_article_creation_immuable ON logistique."T_Article" IS 'UUID et empreinte de creation immuables.';

--
-- Name: T_Commande a00_bon_initial_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a00_bon_initial_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();

--
-- Name: TRIGGER a00_bon_initial_protection ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a00_bon_initial_protection ON logistique."T_Commande" IS 'Origine reservee aux routines; bon initial conserve apres creation.';

--
-- Name: T_CommandeDetail a00_ligne_initiale_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a00_ligne_initiale_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();

--
-- Name: TRIGGER a00_ligne_initiale_protection ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a00_ligne_initiale_protection ON logistique."T_CommandeDetail" IS 'Ligne du stock initial creee une seule fois et conservee; corrections par un nouveau bon.';

--
-- Name: T_Facture a00_stock_initial_facture; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a00_stock_initial_facture BEFORE INSERT OR UPDATE ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();

--
-- Name: TRIGGER a00_stock_initial_facture ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a00_stock_initial_facture ON logistique."T_Facture" IS 'Refuse une facture commerciale issue d un stock initial ou d une reprise documentaire.';

--
-- Name: T_RetourBon a00_stock_initial_retour; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a00_stock_initial_retour BEFORE INSERT OR UPDATE ON logistique."T_RetourBon" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_initial_protection();

--
-- Name: TRIGGER a00_stock_initial_retour ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a00_stock_initial_retour ON logistique."T_RetourBon" IS 'Refuse un retour commercial sur un bon technique de stock initial ou de reprise.';

--
-- Name: T_Commande a01_commande_sans_stock; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a01_commande_sans_stock BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_commande_sans_stock();

--
-- Name: TRIGGER a01_commande_sans_stock ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a01_commande_sans_stock ON logistique."T_Commande" IS 'Avant toute écriture d’en-tête, distingue la commande préparatoire des entrées/sorties et protège son identité et son absence de facturation.';

--
-- Name: T_Mouvement a01_mouvement_physique; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a01_mouvement_physique BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_mouvement_physique();

--
-- Name: TRIGGER a01_mouvement_physique ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a01_mouvement_physique ON logistique."T_Mouvement" IS 'Défense SQL indépendante du service : seul un mouvement réel de même nature que son bon peut être enregistré.';

--
-- Name: T_Commande a0_numero_commande; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a0_numero_commande BEFORE INSERT OR UPDATE OF "ID_Commande", "CodeCmd", "CodeFacture", "ID_TypeCmdFk" ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_numero_commande();

--
-- Name: TRIGGER a0_numero_commande ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a0_numero_commande ON logistique."T_Commande" IS 'Attribue BE/BS selon le sens initial et conserve identite, code et sens du prefixe; anciens codes inchanges.';

--
-- Name: T_Facture a0_numero_facture; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a0_numero_facture BEFORE INSERT OR UPDATE OF "ID_CommandeFk", "CodeFacture" ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_numero_facture();

--
-- Name: TRIGGER a0_numero_facture ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a0_numero_facture ON logistique."T_Facture" IS 'Référence automatique fac-IDBon ; aucun mouvement ni recalcul financier.';

--
-- Name: T_Reglements a0_reglement_apres_avoir; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a0_reglement_apres_avoir BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_reglement_apres_avoir();

--
-- Name: TRIGGER a0_reglement_apres_avoir ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a0_reglement_apres_avoir ON logistique."T_Reglements" IS 'Garde financière SQL exécutée avant le contrôle de propriété : verrou du parent acquis avant les verrous partagés, sans conversion concurrente de verrou ni dépassement du solde.';

--
-- Name: T_Immobilisation a_immobilisation_verifier; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER a_immobilisation_verifier BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Immobilisation" FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_verifier();

--
-- Name: TRIGGER a_immobilisation_verifier ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER a_immobilisation_verifier ON logistique."T_Immobilisation" IS 'Contrôle métier du patrimoine avant chaque écriture, y compris par un autre backend ; refus des suppressions physiques.';

--
-- Name: T_Commande aa_08_code_facture_inventaire; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_08_code_facture_inventaire BEFORE UPDATE OF "CodeFacture" ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();

--
-- Name: TRIGGER aa_08_code_facture_inventaire ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_08_code_facture_inventaire ON logistique."T_Commande" IS 'Interdit aussi l’attribution directe d’un code de facture à un bon d’inventaire.';

--
-- Name: T_Facture aa_08_facture_inventaire_non_commercial; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_08_facture_inventaire_non_commercial BEFORE INSERT ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();

--
-- Name: TRIGGER aa_08_facture_inventaire_non_commercial ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_08_facture_inventaire_non_commercial ON logistique."T_Facture" IS 'Une correction ou compensation d’inventaire ne produit pas de facture commerciale.';

--
-- Name: T_InventaireLigne aa_08_ligne_inventaire_non_commercial; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_08_ligne_inventaire_non_commercial BEFORE INSERT OR UPDATE ON logistique."T_InventaireLigne" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();

--
-- Name: TRIGGER aa_08_ligne_inventaire_non_commercial ON "T_InventaireLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_08_ligne_inventaire_non_commercial ON logistique."T_InventaireLigne" IS 'Refuse un bon déjà facturé ou lié à un retour lors du rattachement au comptage.';

--
-- Name: T_RetourBon aa_08_retour_inventaire_non_commercial; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_08_retour_inventaire_non_commercial BEFORE INSERT ON logistique."T_RetourBon" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();

--
-- Name: TRIGGER aa_08_retour_inventaire_non_commercial ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_08_retour_inventaire_non_commercial ON logistique."T_RetourBon" IS 'Les bons d’inventaire sont exclus des origines et des contre-bons des retours clients.';

--
-- Name: T_Commande aa_inventaire_bon_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_inventaire_bon_protection BEFORE DELETE OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();

--
-- Name: TRIGGER aa_inventaire_bon_protection ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_inventaire_bon_protection ON logistique."T_Commande" IS 'Contrôle métier aa_inventaire_bon_protection : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_CommandeDetail aa_inventaire_ligne_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_inventaire_ligne_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();

--
-- Name: TRIGGER aa_inventaire_ligne_protection ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_inventaire_ligne_protection ON logistique."T_CommandeDetail" IS 'Contrôle métier aa_inventaire_ligne_protection : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_MouvementLot aa_inventaire_lot_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_inventaire_lot_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();

--
-- Name: TRIGGER aa_inventaire_lot_protection ON "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_inventaire_lot_protection ON logistique."T_MouvementLot" IS 'Interdit la modification des lots des corrections et annulations historiques.';

--
-- Name: T_Mouvement aa_inventaire_mouvement_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_inventaire_mouvement_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_inventaire();

--
-- Name: TRIGGER aa_inventaire_mouvement_protection ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_inventaire_mouvement_protection ON logistique."T_Mouvement" IS 'Contrôle métier aa_inventaire_mouvement_protection : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_Article aa_propriete_article; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_propriete_article BEFORE INSERT OR UPDATE ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();

--
-- Name: TRIGGER aa_propriete_article ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_propriete_article ON logistique."T_Article" IS 'Contrôle la propriété durable et la cohérence des rattachements de l’entreprise.';

--
-- Name: T_Client aa_propriete_client; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_propriete_client BEFORE INSERT OR UPDATE ON logistique."T_Client" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();

--
-- Name: TRIGGER aa_propriete_client ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_propriete_client ON logistique."T_Client" IS 'Contrôle la propriété durable et la cohérence des rattachements de l’entreprise.';

--
-- Name: T_Commande aa_propriete_commande; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_propriete_commande BEFORE INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();

--
-- Name: TRIGGER aa_propriete_commande ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_propriete_commande ON logistique."T_Commande" IS 'Contrôle la propriété durable et la cohérence des rattachements de l’entreprise.';

--
-- Name: T_CommandeDetail aa_propriete_ligne; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_propriete_ligne BEFORE INSERT OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();

--
-- Name: TRIGGER aa_propriete_ligne ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_propriete_ligne ON logistique."T_CommandeDetail" IS 'Contrôle la propriété durable et la cohérence des rattachements de l’entreprise.';

--
-- Name: T_Mouvement aa_propriete_mouvement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_propriete_mouvement BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();

--
-- Name: TRIGGER aa_propriete_mouvement ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_propriete_mouvement ON logistique."T_Mouvement" IS 'Contrôle la propriété durable et la cohérence des rattachements de l’entreprise.';

--
-- Name: T_Reglements aa_propriete_reglement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_propriete_reglement BEFORE INSERT OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();

--
-- Name: TRIGGER aa_propriete_reglement ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_propriete_reglement ON logistique."T_Reglements" IS 'Contrôle la propriété durable et la cohérence des rattachements de l’entreprise.';

--
-- Name: T_Article aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Article" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Avoir aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Avoir" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Avoir" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Client aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Client" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Client" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Commande aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Commande" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Facture aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Facture" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Immobilisation aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Immobilisation" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Immobilisation" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Mouvement aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Mouvement" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_PrecisionStock aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_PrecisionStock" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_PrecisionStock" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Reglements aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Reglements" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Remboursement aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_Remboursement" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Remboursement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_Remboursement" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_ValorisationOuverture aa_reference_champ; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON logistique."T_ValorisationOuverture" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_ValorisationOuverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON logistique."T_ValorisationOuverture" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Reglements aa_reglement_tracabilite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_reglement_tracabilite BEFORE INSERT OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_reglement_tracabilite();

--
-- Name: TRIGGER aa_reglement_tracabilite ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_reglement_tracabilite ON logistique."T_Reglements" IS 'Traçabilité technique SQL de chaque création ou modification de règlement, avant les gardes financières.';

--
-- Name: T_Commande aa_retour_commande_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_retour_commande_protection BEFORE DELETE OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_retour();

--
-- Name: TRIGGER aa_retour_commande_protection ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_retour_commande_protection ON logistique."T_Commande" IS 'Conserve les données originales et le document compensateur ; aucune suppression ni réécriture de stock après retour.';

--
-- Name: T_CommandeDetail aa_retour_ligne_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_retour_ligne_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_retour();

--
-- Name: TRIGGER aa_retour_ligne_protection ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_retour_ligne_protection ON logistique."T_CommandeDetail" IS 'Verrouille le parent puis empêche toute modification du panier lié à un retour.';

--
-- Name: T_MouvementLot aa_retour_lot_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_retour_lot_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_retour();

--
-- Name: TRIGGER aa_retour_lot_protection ON "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_retour_lot_protection ON logistique."T_MouvementLot" IS 'Conserve les quantités ventilées par lot des sorties et retours validés.';

--
-- Name: T_Mouvement aa_retour_mouvement_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER aa_retour_mouvement_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_bon_retour();

--
-- Name: TRIGGER aa_retour_mouvement_protection ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER aa_retour_mouvement_protection ON logistique."T_Mouvement" IS 'Conserve le sens, la quantité et le prix des mouvements source et compensateurs.';

--
-- Name: T_AvoirAffectation affectation_avoir_controle; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER affectation_avoir_controle BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_AvoirAffectation" FOR EACH ROW EXECUTE FUNCTION logistique.tr_utilisation_avoir();

--
-- Name: TRIGGER affectation_avoir_controle ON "T_AvoirAffectation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER affectation_avoir_controle ON logistique."T_AvoirAffectation" IS 'Imputation bornée au disponible et au solde de la facture cible.';

--
-- Name: T_Article article_poids_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER article_poids_integrite BEFORE INSERT OR UPDATE OF "PoidsUnitaire", "ID_UnitePoidsFk" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_article_poids();

--
-- Name: TRIGGER article_poids_integrite ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER article_poids_integrite ON logistique."T_Article" IS 'Valide les unités de masse lors de la saisie du poids.';

--
-- Name: T_Article article_stock_lots; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER article_stock_lots AFTER INSERT OR UPDATE ON logistique."T_Article" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();

--
-- Name: TRIGGER article_stock_lots ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER article_stock_lots ON logistique."T_Article" IS 'Vérifie que les mises à jour du stock global conservent la cohérence des lots.';

--
-- Name: T_Avoir avoir_immuable; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER avoir_immuable BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Avoir" FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_immuable();

--
-- Name: TRIGGER avoir_immuable ON "T_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER avoir_immuable ON logistique."T_Avoir" IS 'Avoir émis non modifiable ni supprimable.';

--
-- Name: T_AvoirLigne avoir_ligne_immuable; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER avoir_ligne_immuable BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_AvoirLigne" FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_ligne_immuable();

--
-- Name: TRIGGER avoir_ligne_immuable ON "T_AvoirLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER avoir_ligne_immuable ON logistique."T_AvoirLigne" IS 'Instantané des articles et budget retourné.';

--
-- Name: T_AvoirLigne avoir_lignes_total; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER avoir_lignes_total AFTER INSERT ON logistique."T_AvoirLigne" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_total();

--
-- Name: TRIGGER avoir_lignes_total ON "T_AvoirLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER avoir_lignes_total ON logistique."T_AvoirLigne" IS 'Contrôle différé de la somme des lignes d’avoir.';

--
-- Name: T_Avoir avoir_total; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER avoir_total AFTER INSERT ON logistique."T_Avoir" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_total();

--
-- Name: TRIGGER avoir_total ON "T_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER avoir_total ON logistique."T_Avoir" IS 'Contrôle différé de la somme émise.';

--
-- Name: T_BonCodeHistorique bon_code_historique_immuable; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER bon_code_historique_immuable BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_BonCodeHistorique" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_code_historique_immuable();

--
-- Name: TRIGGER bon_code_historique_immuable ON "T_BonCodeHistorique"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER bon_code_historique_immuable ON logistique."T_BonCodeHistorique" IS 'Conserve toutes les correspondances, sans dérogation applicative ni GUC permanent.';

--
-- Name: T_CategorieDossierSuivi categorie_dossier_suivi_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER categorie_dossier_suivi_integrite BEFORE INSERT OR UPDATE ON logistique."T_CategorieDossierSuivi" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_dossier_suivi();

--
-- Name: TRIGGER categorie_dossier_suivi_integrite ON "T_CategorieDossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER categorie_dossier_suivi_integrite ON logistique."T_CategorieDossierSuivi" IS 'Préserve les clés et le périmètre du classement et horodate ses modifications ; aucun effet sur le stock.';

--
-- Name: T_Commande destination_commande; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER destination_commande BEFORE INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_destination_commande();

--
-- Name: TRIGGER destination_commande ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER destination_commande ON logistique."T_Commande" IS 'Contrôle les destinations lors de la création ou d’un changement de lieu référencé, sans modifier le stock.';

--
-- Name: T_Avoir document_identite_avoir; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER document_identite_avoir AFTER INSERT ON logistique."T_Avoir" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();

--
-- Name: TRIGGER document_identite_avoir ON "T_Avoir"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER document_identite_avoir ON logistique."T_Avoir" IS 'Identité de l’émetteur figée lors de l’émission.';

--
-- Name: T_Commande document_identite_bon; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER document_identite_bon AFTER INSERT ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();

--
-- Name: TRIGGER document_identite_bon ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER document_identite_bon ON logistique."T_Commande" IS 'Identité émettrice du bon à sa création.';

--
-- Name: T_Facture document_identite_facture; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER document_identite_facture AFTER INSERT ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();

--
-- Name: TRIGGER document_identite_facture ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER document_identite_facture ON logistique."T_Facture" IS 'Identité émettrice de la facture à son émission.';

--
-- Name: T_DocumentIdentite document_identite_immuable; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER document_identite_immuable BEFORE DELETE OR UPDATE ON logistique."T_DocumentIdentite" FOR EACH ROW EXECUTE FUNCTION logistique.tr_identite_document_immuable();

--
-- Name: TRIGGER document_identite_immuable ON "T_DocumentIdentite"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER document_identite_immuable ON logistique."T_DocumentIdentite" IS 'Interdit la réécriture de l’identité historique d’un document.';

--
-- Name: T_Reglements document_identite_reglement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER document_identite_reglement AFTER INSERT ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();

--
-- Name: TRIGGER document_identite_reglement ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER document_identite_reglement ON logistique."T_Reglements" IS 'Identité émettrice du reçu lors de l’enregistrement du règlement.';

--
-- Name: T_DossierSuivi dossier_suivi_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER dossier_suivi_integrite BEFORE INSERT OR UPDATE ON logistique."T_DossierSuivi" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_dossier_suivi();

--
-- Name: TRIGGER dossier_suivi_integrite ON "T_DossierSuivi"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER dossier_suivi_integrite ON logistique."T_DossierSuivi" IS 'Préserve les clés et le périmètre du classement et horodate ses modifications ; aucun effet sur le stock.';

--
-- Name: T_DossierSuiviMembre dossier_suivi_membre_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER dossier_suivi_membre_integrite BEFORE INSERT OR UPDATE ON logistique."T_DossierSuiviMembre" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_dossier_suivi();

--
-- Name: TRIGGER dossier_suivi_membre_integrite ON "T_DossierSuiviMembre"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER dossier_suivi_membre_integrite ON logistique."T_DossierSuiviMembre" IS 'Préserve les clés et le périmètre du classement et horodate ses modifications ; aucun effet sur le stock.';

--
-- Name: T_Facture facture_apres_avoir; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_apres_avoir BEFORE DELETE OR UPDATE ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_facture_apres_avoir();

--
-- Name: TRIGGER facture_apres_avoir ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_apres_avoir ON logistique."T_Facture" IS 'Protection de la facture d’origine des avoirs.';

--
-- Name: T_Commande facture_bon_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_bon_protection BEFORE DELETE OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_bon_facture();

--
-- Name: TRIGGER facture_bon_protection ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_bon_protection ON logistique."T_Commande" IS 'Immutabilité du bon de stock après émission de sa facture.';

--
-- Name: T_CommandeDetail facture_detail_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_detail_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_stock_facture();

--
-- Name: TRIGGER facture_detail_protection ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_detail_protection ON logistique."T_CommandeDetail" IS 'Empêche une modification du panier après facturation.';

--
-- Name: T_FactureLigne facture_ligne_coherente; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER facture_ligne_coherente AFTER INSERT ON logistique."T_FactureLigne" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_verifier_snapshot_facture();

--
-- Name: TRIGGER facture_ligne_coherente ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_ligne_coherente ON logistique."T_FactureLigne" IS 'Revalide le snapshot après chaque ajout initial, même si un appelant a déjà forcé des contraintes immédiates.';

--
-- Name: T_FactureLigne facture_ligne_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_ligne_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_FactureLigne" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_ligne_facture();

--
-- Name: TRIGGER facture_ligne_protection ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_ligne_protection ON logistique."T_FactureLigne" IS 'Copie initiale unique des lignes nettes.';

--
-- Name: T_LotArticle facture_lot_identite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_lot_identite BEFORE UPDATE ON logistique."T_LotArticle" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_identite_lot_facture();

--
-- Name: TRIGGER facture_lot_identite ON "T_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_lot_identite ON logistique."T_LotArticle" IS 'Empêche un renommage ou une autre identité de lot de modifier les références d’une facture historique.';

--
-- Name: T_MouvementLot facture_mouvement_lot_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_mouvement_lot_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_stock_facture();

--
-- Name: TRIGGER facture_mouvement_lot_protection ON "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_mouvement_lot_protection ON logistique."T_MouvementLot" IS 'Vérifie les parents ancien et nouveau et conserve les ventilations historiques facturées.';

--
-- Name: T_Mouvement facture_mouvement_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_mouvement_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_stock_facture();

--
-- Name: TRIGGER facture_mouvement_protection ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_mouvement_protection ON logistique."T_Mouvement" IS 'Empêche une modification des mouvements d’origine après facturation.';

--
-- Name: T_Facture facture_protection; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER facture_protection BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_facture();

--
-- Name: TRIGGER facture_protection ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_protection ON logistique."T_Facture" IS 'Protection des données financières historiques.';

--
-- Name: T_Facture facture_snapshot_coherent; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER facture_snapshot_coherent AFTER INSERT OR UPDATE ON logistique."T_Facture" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_verifier_snapshot_facture();

--
-- Name: TRIGGER facture_snapshot_coherent ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER facture_snapshot_coherent ON logistique."T_Facture" IS 'Validation atomique en fin de transaction de l’émission et de son miroir.';

--
-- Name: T_Inventaire inventaire_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER inventaire_integrite BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Inventaire" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_inventaire();

--
-- Name: TRIGGER inventaire_integrite ON "T_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER inventaire_integrite ON logistique."T_Inventaire" IS 'Contrôle métier inventaire_integrite : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_InventaireLigne inventaire_ligne_compensation_complete; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER inventaire_ligne_compensation_complete AFTER INSERT OR DELETE OR UPDATE ON logistique."T_InventaireLigne" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_inventaire_valide();

--
-- Name: TRIGGER inventaire_ligne_compensation_complete ON "T_InventaireLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER inventaire_ligne_compensation_complete ON logistique."T_InventaireLigne" IS 'Recontrôle la complétude des corrections et compensations après toute modification des lignes, y compris un accès SQL direct.';

--
-- Name: T_InventaireLigne inventaire_ligne_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER inventaire_ligne_integrite BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_InventaireLigne" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_inventaire();

--
-- Name: TRIGGER inventaire_ligne_integrite ON "T_InventaireLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER inventaire_ligne_integrite ON logistique."T_InventaireLigne" IS 'Contrôle métier inventaire_ligne_integrite : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_InventaireLigne inventaire_ligne_non_commerciale; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER inventaire_ligne_non_commerciale AFTER INSERT OR UPDATE ON logistique."T_InventaireLigne" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.verifier_bon_inventaire_non_commercial();

--
-- Name: TRIGGER inventaire_ligne_non_commerciale ON "T_InventaireLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER inventaire_ligne_non_commerciale ON logistique."T_InventaireLigne" IS 'Contrôle au terme de la transaction les liens inventaire/facture/retour, quel que soit leur ordre de création.';

--
-- Name: T_Inventaire inventaire_validation_complete; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER inventaire_validation_complete AFTER INSERT OR UPDATE ON logistique."T_Inventaire" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_inventaire_valide();

--
-- Name: TRIGGER inventaire_validation_complete ON "T_Inventaire"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER inventaire_validation_complete ON logistique."T_Inventaire" IS 'Contrôle métier inventaire_validation_complete : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_LotArticle lot_article_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER lot_article_integrite BEFORE INSERT OR UPDATE ON logistique."T_LotArticle" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_lot_rattachement();

--
-- Name: TRIGGER lot_article_integrite ON "T_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER lot_article_integrite ON logistique."T_LotArticle" IS 'Relation article/lot immuable et numéro nettoyé.';

--
-- Name: T_LotArticle lot_retour_identite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER lot_retour_identite BEFORE UPDATE ON logistique."T_LotArticle" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_identite_lot_retour();

--
-- Name: TRIGGER lot_retour_identite ON "T_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER lot_retour_identite ON logistique."T_LotArticle" IS 'Empêche une nouvelle identité de lot de réécrire l’historique des restitutions.';

--
-- Name: T_LotArticle lot_stock_lots; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER lot_stock_lots AFTER INSERT OR UPDATE ON logistique."T_LotArticle" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();

--
-- Name: TRIGGER lot_stock_lots ON "T_LotArticle"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER lot_stock_lots ON logistique."T_LotArticle" IS 'Contrôle la cohérence du stock du lot après sa création ou sa modification.';

--
-- Name: T_MouvementLot mouvement_lot_verrou; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER mouvement_lot_verrou BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.verrouiller_ventilation_lot();

--
-- Name: TRIGGER mouvement_lot_verrou ON "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER mouvement_lot_verrou ON logistique."T_MouvementLot" IS 'Sérialise la ventilation par article et lot sans créer un mouvement supplémentaire.';

--
-- Name: T_Mouvement mouvement_stock_lots; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER mouvement_stock_lots AFTER INSERT OR DELETE OR UPDATE ON logistique."T_Mouvement" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();

--
-- Name: TRIGGER mouvement_stock_lots ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER mouvement_stock_lots ON logistique."T_Mouvement" IS 'Vérifie les lots après création, correction, inversion de sens ou annulation de mouvement.';

--
-- Name: T_Commande numero_commande_audit; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER numero_commande_audit AFTER INSERT ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_audit_numero_document();

--
-- Name: TRIGGER numero_commande_audit ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER numero_commande_audit ON logistique."T_Commande" IS 'Trace la première attribution d’une référence dans le journal existant.';

--
-- Name: T_Facture numero_facture_audit; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER numero_facture_audit AFTER INSERT ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_audit_numero_document();

--
-- Name: TRIGGER numero_facture_audit ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER numero_facture_audit ON logistique."T_Facture" IS 'Trace la première attribution du numéro de facture, sans secret ni copie du panier.';

--
-- Name: T_MouvementLot peremption_lot_sortie; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER peremption_lot_sortie BEFORE INSERT OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.controler_sortie_lot_perime();

--
-- Name: TRIGGER peremption_lot_sortie ON "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER peremption_lot_sortie ON logistique."T_MouvementLot" IS 'Applique la politique de péremption uniquement aux nouveaux prélèvements ou aux modifications de ventilation.';

--
-- Name: T_PieceJustificative piece_coherence; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER piece_coherence BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_PieceJustificative" FOR EACH ROW EXECUTE FUNCTION logistique.tr_piece_coherente();

--
-- Name: TRIGGER piece_coherence ON "T_PieceJustificative"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER piece_coherence ON logistique."T_PieceJustificative" IS 'Fichier immuable et rattachement contrôlé au document de la même entreprise.';

--
-- Name: T_PrecisionStock precision_stock_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER precision_stock_integrite BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_PrecisionStock" FOR EACH ROW EXECUTE FUNCTION logistique.tr_precision_stock();

--
-- Name: TRIGGER precision_stock_integrite ON "T_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER precision_stock_integrite ON logistique."T_PrecisionStock" IS 'Protection de la politique par unité, y compris en SQL direct ; insertion et modification sérialisées avec les validations de quantités.';

--
-- Name: T_Article quantite_unite_article; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER quantite_unite_article BEFORE INSERT OR UPDATE OF "QteArticle", "QteMinArticle", "ID_UniteFk" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();

--
-- Name: TRIGGER quantite_unite_article ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER quantite_unite_article ON logistique."T_Article" IS 'Contrôle métier quantite_unite_article : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_CommandeDetail quantite_unite_ligne; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER quantite_unite_ligne BEFORE INSERT OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();

--
-- Name: TRIGGER quantite_unite_ligne ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER quantite_unite_ligne ON logistique."T_CommandeDetail" IS 'Contrôle métier quantite_unite_ligne : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_MouvementLot quantite_unite_lot; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER quantite_unite_lot BEFORE INSERT OR UPDATE ON logistique."T_MouvementLot" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();

--
-- Name: TRIGGER quantite_unite_lot ON "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER quantite_unite_lot ON logistique."T_MouvementLot" IS 'Contrôle métier quantite_unite_lot : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_Mouvement quantite_unite_mouvement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER quantite_unite_mouvement BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_quantite_unite();

--
-- Name: TRIGGER quantite_unite_mouvement ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER quantite_unite_mouvement ON logistique."T_Mouvement" IS 'Contrôle métier quantite_unite_mouvement : précision exacte ou cohérence du comptage, sans mouvement de stock supplémentaire.';

--
-- Name: T_Remboursement remboursement_avoir_controle; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER remboursement_avoir_controle BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Remboursement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_utilisation_avoir();

--
-- Name: TRIGGER remboursement_avoir_controle ON "T_Remboursement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER remboursement_avoir_controle ON logistique."T_Remboursement" IS 'Remboursement borné au disponible de l’avoir.';

--
-- Name: T_RetourBon retour_bon_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER retour_bon_integrite BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_RetourBon" FOR EACH ROW EXECUTE FUNCTION logistique.controler_retour_bon();

--
-- Name: TRIGGER retour_bon_integrite ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER retour_bon_integrite ON logistique."T_RetourBon" IS 'Validation unique du lien après insertion des lignes et de leur ventilation, puis liaison immuable.';

--
-- Name: T_Article tr_00_devise_article; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_00_devise_article BEFORE INSERT OR UPDATE OF "ID_DeviseFk", "PUArticle", "PVArticle" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_article();

--
-- Name: TRIGGER tr_00_devise_article ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_00_devise_article ON logistique."T_Article" IS 'Devise active et verrouillage de la dénomination monétaire du catalogue déjà utilisé.';

--
-- Name: T_Commande tr_00_devise_commande; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_00_devise_commande BEFORE INSERT OR UPDATE OF "ID_DeviseFk", "MontantHT", "MontantTTC", "MontantRegleFacture", "MontantResteFacture" ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_commande();

--
-- Name: TRIGGER tr_00_devise_commande ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_00_devise_commande ON logistique."T_Commande" IS 'Contrôle monétaire avant les effets existants de lignes, totaux et mouvements.';

--
-- Name: T_Mouvement tr_00_devise_mouvement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_00_devise_mouvement BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_mouvement();

--
-- Name: TRIGGER tr_00_devise_mouvement ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_00_devise_mouvement ON logistique."T_Mouvement" IS 'Instantané de devise conservé ; le verrou métier existant sur les écritures directes reste actif.';

--
-- Name: T_Reglements tr_00_devise_reglement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_00_devise_reglement BEFORE INSERT OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_reglement();

--
-- Name: TRIGGER tr_00_devise_reglement ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_00_devise_reglement ON logistique."T_Reglements" IS 'Conserve la devise de règlement sans second calcul des montants ou du stock.';

--
-- Name: T_CommandeDetail tr_00_guard_commandedetail; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_00_guard_commandedetail BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_guard_commandedetail();

--
-- Name: TRIGGER tr_00_guard_commandedetail ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_00_guard_commandedetail ON logistique."T_CommandeDetail" IS 'BEFORE ROW : verrouille les parents et contrôle leur clôture avant la mutation de ligne et ses effets stock.';

--
-- Name: T_Article tr_crud_article_after; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_article_after AFTER INSERT OR UPDATE ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_article_after();

--
-- Name: TRIGGER tr_crud_article_after ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_article_after ON logistique."T_Article" IS 'Stock initial positif documente atomiquement; aucune entree fictive pour zero ni pour une edition descriptive.';

--
-- Name: T_Article tr_crud_article_before; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_article_before BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_article_before();

--
-- Name: TRIGGER tr_crud_article_before ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_article_before ON logistique."T_Article" IS 'BEFORE INSERT OR DELETE OR UPDATE sur "logistique"."T_Article", pour chaque ligne. Appelle "logistique"."tr_crud_article_before" : Avant INSERT/UPDATE, normalise la quantité absente à zéro et appelle ps_crud_article. Avant DELETE, bloque la suppression d’un article lié à une ligne ou un mouvement.';

--
-- Name: T_Commande tr_crud_commande; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_commande AFTER INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_commande();

--
-- Name: TRIGGER tr_crud_commande ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_commande ON logistique."T_Commande" IS 'AFTER INSERT OR UPDATE sur "logistique"."T_Commande", pour chaque ligne. Appelle "logistique"."tr_crud_commande" : Fonction de trigger AFTER INSERT/UPDATE transmettant anciens/nouveaux types et références à ps_crud_commande pour validation et réalignement des effets de stock.';

--
-- Name: T_CommandeDetail tr_crud_commandedetail; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_commandedetail AFTER INSERT OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_commandedetail();

--
-- Name: TRIGGER tr_crud_commandedetail ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_commandedetail ON logistique."T_CommandeDetail" IS 'AFTER INSERT OR UPDATE sur "logistique"."T_CommandeDetail", pour chaque ligne. Appelle "logistique"."tr_crud_commandedetail" : Fonction commune des triggers de ligne : transmet OLD/NEW à ps_crud_commandedetail. Raccordée après INSERT/UPDATE et avant DELETE pour annuler l’ancien effet avant disparition de la ligne.';

--
-- Name: T_Reglements tr_crud_reglement; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_crud_reglement BEFORE INSERT OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_reglement();

--
-- Name: TRIGGER tr_crud_reglement ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_crud_reglement ON logistique."T_Reglements" IS 'BEFORE INSERT OR UPDATE sur "logistique"."T_Reglements", pour chaque ligne. Appelle "logistique"."tr_crud_reglement" : Fonction de trigger BEFORE INSERT/UPDATE validant le mode via ps_crud_reglement ; renvoie la ligne sans mise à jour des montants de facture.';

--
-- Name: T_CommandeDetail tr_delete_commandedetail; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_delete_commandedetail BEFORE DELETE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.tr_crud_commandedetail();

--
-- Name: TRIGGER tr_delete_commandedetail ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_delete_commandedetail ON logistique."T_CommandeDetail" IS 'BEFORE DELETE sur "logistique"."T_CommandeDetail", pour chaque ligne. Appelle "logistique"."tr_crud_commandedetail" : Fonction commune des triggers de ligne : transmet OLD/NEW à ps_crud_commandedetail. Raccordée après INSERT/UPDATE et avant DELETE pour annuler l’ancien effet avant disparition de la ligne.';

--
-- Name: T_Commande tr_lock_commande_cloturee; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_lock_commande_cloturee BEFORE DELETE OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_lock_commande_cloturee();

--
-- Name: TRIGGER tr_lock_commande_cloturee ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_lock_commande_cloturee ON logistique."T_Commande" IS 'BEFORE DELETE OR UPDATE sur "logistique"."T_Commande", pour chaque ligne. Appelle "logistique"."tr_lock_commande_cloturee" : Avant UPDATE/DELETE de commande, refuse l’opération si OLD.StatusFacture vaut exactement Clôturée. La comparaison actuelle ne normalise pas la casse ou les variantes de libellé.';

--
-- Name: T_Mouvement tr_lock_mouvement_direct; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_lock_mouvement_direct BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_lock_mouvement_direct();

--
-- Name: TRIGGER tr_lock_mouvement_direct ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_lock_mouvement_direct ON logistique."T_Mouvement" IS 'BEFORE INSERT OR DELETE OR UPDATE sur "logistique"."T_Mouvement", pour chaque ligne. Appelle "logistique"."tr_lock_mouvement_direct" : Bloque les écritures sur T_Mouvement sauf si le drapeau transactionnel logistique.allow_t_mouvement_write vaut on ; valide alors la catégorie 64 du type pour INSERT/UPDATE.';

--
-- Name: T_CommandeDetail tr_totaux_commande_delete; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_totaux_commande_delete AFTER DELETE ON logistique."T_CommandeDetail" REFERENCING OLD TABLE AS lignes_anciennes FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();

--
-- Name: TRIGGER tr_totaux_commande_delete ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_totaux_commande_delete ON logistique."T_CommandeDetail" IS 'AFTER DELETE STATEMENT : recalcule les commandes distinctes des lignes supprimées ; tolère le parent déjà supprimé en cascade.';

--
-- Name: T_CommandeDetail tr_totaux_commande_insert; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_totaux_commande_insert AFTER INSERT ON logistique."T_CommandeDetail" REFERENCING NEW TABLE AS lignes_nouvelles FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();

--
-- Name: TRIGGER tr_totaux_commande_insert ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_totaux_commande_insert ON logistique."T_CommandeDetail" IS 'AFTER INSERT STATEMENT : recalcule les commandes distinctes de lignes_nouvelles, après les effets stock de chaque ligne.';

--
-- Name: T_CommandeDetail tr_totaux_commande_update; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER tr_totaux_commande_update AFTER UPDATE ON logistique."T_CommandeDetail" REFERENCING OLD TABLE AS lignes_anciennes NEW TABLE AS lignes_nouvelles FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_totaux_commande();

--
-- Name: TRIGGER tr_totaux_commande_update ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER tr_totaux_commande_update ON logistique."T_CommandeDetail" IS 'AFTER UPDATE STATEMENT : recalcule les commandes distinctes des anciennes et nouvelles lignes ; une commande est recalculée au plus une fois par instruction.';

--
-- Name: T_ValorisationOuverture valorisation_integrite; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER valorisation_integrite BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_ValorisationOuverture" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_valorisation();

--
-- Name: TRIGGER valorisation_integrite ON "T_ValorisationOuverture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER valorisation_integrite ON logistique."T_ValorisationOuverture" IS 'Contrôle propriétaire, devise et chemin de mise à jour motivé.';

--
-- Name: T_ValorisationEvenement valorisation_journal_immutable; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER valorisation_journal_immutable BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_ValorisationEvenement" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_valorisation();

--
-- Name: TRIGGER valorisation_journal_immutable ON "T_ValorisationEvenement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER valorisation_journal_immutable ON logistique."T_ValorisationEvenement" IS 'Les preuves financières de valorisation ne sont jamais modifiées ni supprimées.';

--
-- Name: T_MouvementLot ventilation_stock_lots; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE CONSTRAINT TRIGGER ventilation_stock_lots AFTER INSERT OR DELETE OR UPDATE ON logistique."T_MouvementLot" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.controler_stock_lots();

--
-- Name: TRIGGER ventilation_stock_lots ON "T_MouvementLot"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER ventilation_stock_lots ON logistique."T_MouvementLot" IS 'Contrôle final des quantités ventilées dans la transaction source.';

--
-- Name: T_Mouvement zz_cout_source_trace; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER zz_cout_source_trace BEFORE INSERT OR DELETE OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tracer_source_cout();

--
-- Name: TRIGGER zz_cout_source_trace ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER zz_cout_source_trace ON logistique."T_Mouvement" IS 'Ajoute une preuve de source sans créer de deuxième mouvement physique.';

--
-- Name: T_Immobilisation zz_immobilisation_audit; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER zz_immobilisation_audit AFTER INSERT OR UPDATE ON logistique."T_Immobilisation" FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_audit();

--
-- Name: TRIGGER zz_immobilisation_audit ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER zz_immobilisation_audit ON logistique."T_Immobilisation" IS 'Historique transactionnel unique du bien, comprenant les changements de responsable, service, état et localisation.';

--
-- Name: T_Reglements zz_reglement_audit; Type: TRIGGER; Schema: logistique; Owner: -
--

CREATE TRIGGER zz_reglement_audit AFTER INSERT OR DELETE OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_reglement_audit();

--
-- Name: TRIGGER zz_reglement_audit ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON TRIGGER zz_reglement_audit ON logistique."T_Reglements" IS 'Historique transactionnel SQL du règlement, y compris pour un futur backend ; ne crée aucun mouvement de stock.';

--
-- Name: T_CommandeDetail Fk_CmdDetail_Commande; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CommandeDetail"
    ADD CONSTRAINT "Fk_CmdDetail_Commande" FOREIGN KEY ("ID_CmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: CONSTRAINT "Fk_CmdDetail_Commande" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_CmdDetail_Commande" ON logistique."T_CommandeDetail" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_CommandeDetail". Définition : FOREIGN KEY ("ID_CmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: T_Reglements Fk_CodeFacture; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "Fk_CodeFacture" FOREIGN KEY ("CodeFactureFk") REFERENCES logistique."T_Commande"("CodeFacture");

--
-- Name: CONSTRAINT "Fk_CodeFacture" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_CodeFacture" ON logistique."T_Reglements" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("CodeFactureFk") REFERENCES logistique."T_Commande"("CodeFacture")';

--
-- Name: T_CommandeDetail Fk_ID_Article; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CommandeDetail"
    ADD CONSTRAINT "Fk_ID_Article" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_Article" ON "T_CommandeDetail"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Article" ON logistique."T_CommandeDetail" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE';

--
-- Name: T_Article Fk_ID_CategorieArticle; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_CategorieArticle" FOREIGN KEY ("ID_CategorieArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_CategorieArticle" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_CategorieArticle" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_CategorieArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Commande Fk_ID_ConditionPaiement; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_ConditionPaiement" FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_ConditionPaiement" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_ConditionPaiement" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Commande Fk_ID_ModePaiement; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_ModePaiement" FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_ModePaiement" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_ModePaiement" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Commande Fk_ID_StatutCmd; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_StatutCmd" FOREIGN KEY ("ID_StatutCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_StatutCmd" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_StatutCmd" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_StatutCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Article Fk_ID_TypeArticle; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_TypeArticle" FOREIGN KEY ("ID_TypeArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_TypeArticle" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeArticle" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeArticleFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Commande Fk_ID_TypeCmd; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_TypeCmd" FOREIGN KEY ("ID_TypeCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_TypeCmd" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeCmd" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeCmdFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Mouvement Fk_ID_TypeMvt; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "Fk_ID_TypeMvt" FOREIGN KEY ("ID_TypeMvtFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_TypeMvt" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_TypeMvt" ON logistique."T_Mouvement" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_TypeMvtFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Article Fk_ID_Unite; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_Unite" FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique");

--
-- Name: CONSTRAINT "Fk_ID_Unite" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_Unite" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique")';

--
-- Name: T_Article Fk_ID_User; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "Fk_ID_User" FOREIGN KEY ("ID_UserFK") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_User" ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_User" ON logistique."T_Article" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UserFK") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE';

--
-- Name: T_Commande Fk_ID_User; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "Fk_ID_User" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_User" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_User" ON logistique."T_Commande" IS 'Clé étrangère validée sur toutes les lignes existantes : FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE';

--
-- Name: T_Mouvement Fk_Mvt_Article; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "Fk_Mvt_Article" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_Mvt_Article" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Mvt_Article" ON logistique."T_Mouvement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_Mouvement". Définition : FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE.';

--
-- Name: T_Mouvement Fk_Mvt_Cmd; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT "Fk_Mvt_Cmd" FOREIGN KEY ("ID_cmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "Fk_Mvt_Cmd" ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Mvt_Cmd" ON logistique."T_Mouvement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_Mouvement". Définition : FOREIGN KEY ("ID_cmdFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: T_Reglements Fk_Reg_Mode; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "Fk_Reg_Mode" FOREIGN KEY ("ID_ModeReglementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_Reg_Mode" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Reg_Mode" ON logistique."T_Reglements" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "logistique"."T_Reglements". Définition : FOREIGN KEY ("ID_ModeReglementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Article T_Article_ID_UnitePoidsFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT "T_Article_ID_UnitePoidsFk_fkey" FOREIGN KEY ("ID_UnitePoidsFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_AvoirAffectation T_AvoirAffectation_ID_AvoirFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirAffectation"
    ADD CONSTRAINT "T_AvoirAffectation_ID_AvoirFk_fkey" FOREIGN KEY ("ID_AvoirFk") REFERENCES logistique."T_Avoir"("ID_Avoir") ON DELETE RESTRICT;

--
-- Name: T_AvoirAffectation T_AvoirAffectation_ID_CommandeCibleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirAffectation"
    ADD CONSTRAINT "T_AvoirAffectation_ID_CommandeCibleFk_fkey" FOREIGN KEY ("ID_CommandeCibleFk") REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT;

--
-- Name: T_AvoirAffectation T_AvoirAffectation_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirAffectation"
    ADD CONSTRAINT "T_AvoirAffectation_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_AvoirLigne T_AvoirLigne_ID_ArticleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirLigne"
    ADD CONSTRAINT "T_AvoirLigne_ID_ArticleFk_fkey" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;

--
-- Name: T_AvoirLigne T_AvoirLigne_ID_AvoirFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_AvoirLigne"
    ADD CONSTRAINT "T_AvoirLigne_ID_AvoirFk_fkey" FOREIGN KEY ("ID_AvoirFk") REFERENCES logistique."T_Avoir"("ID_Avoir") ON DELETE RESTRICT;

--
-- Name: T_Avoir T_Avoir_ID_CommandeFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_ID_CommandeFk_fkey" FOREIGN KEY ("ID_CommandeFk") REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT;

--
-- Name: T_Avoir T_Avoir_ID_DeviseFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_ID_DeviseFk_fkey" FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Avoir T_Avoir_ID_FactureFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_ID_FactureFk_fkey" FOREIGN KEY ("ID_FactureFk") REFERENCES logistique."T_Facture"("ID_Facture") ON DELETE RESTRICT;

--
-- Name: T_Avoir T_Avoir_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Avoir T_Avoir_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Avoir"
    ADD CONSTRAINT "T_Avoir_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_CategorieDossierSuivi T_CategorieDossierSuivi_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CategorieDossierSuivi"
    ADD CONSTRAINT "T_CategorieDossierSuivi_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_CategorieDossierSuivi T_CategorieDossierSuivi_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_CategorieDossierSuivi"
    ADD CONSTRAINT "T_CategorieDossierSuivi_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_Client T_Client_CreeParUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_CreeParUserFk_fkey" FOREIGN KEY ("CreeParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Client_CreeParUserFk_fkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_CreeParUserFk_fkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Client T_Client_ID_TypeClientFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_ID_TypeClientFk_fkey" FOREIGN KEY ("ID_TypeClientFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Client_ID_TypeClientFk_fkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_ID_TypeClientFk_fkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Client T_Client_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Client_IdEntiteFk_fkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_IdEntiteFk_fkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Client T_Client_IdEntiteRepresenteeFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_IdEntiteRepresenteeFk_fkey" FOREIGN KEY ("IdEntiteRepresenteeFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Client_IdEntiteRepresenteeFk_fkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_IdEntiteRepresenteeFk_fkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Client T_Client_IdProfessionnelFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_IdProfessionnelFk_fkey" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Client_IdProfessionnelFk_fkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_IdProfessionnelFk_fkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Client T_Client_IdUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_IdUserFk_fkey" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Client_IdUserFk_fkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_IdUserFk_fkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Client T_Client_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Client"
    ADD CONSTRAINT "T_Client_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Client_ModifieParUserFk_fkey" ON "T_Client"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Client_ModifieParUserFk_fkey" ON logistique."T_Client" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Commande T_Commande_ID_DestinationFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT "T_Commande_ID_DestinationFk_fkey" FOREIGN KEY ("ID_DestinationFk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Commande_ID_DestinationFk_fkey" ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Commande_ID_DestinationFk_fkey" ON logistique."T_Commande" IS 'Référence facultative à un lieu existant de niveau 5, supprimable seulement lorsqu’aucun bon ne le référence.';

--
-- Name: T_DocumentIdentite T_DocumentIdentite_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DocumentIdentite"
    ADD CONSTRAINT "T_DocumentIdentite_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_DossierSuiviMembre T_DossierSuiviMembre_ID_ArticleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuiviMembre"
    ADD CONSTRAINT "T_DossierSuiviMembre_ID_ArticleFk_fkey" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE CASCADE;

--
-- Name: T_DossierSuiviMembre T_DossierSuiviMembre_ID_CommandeFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuiviMembre"
    ADD CONSTRAINT "T_DossierSuiviMembre_ID_CommandeFk_fkey" FOREIGN KEY ("ID_CommandeFk") REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE CASCADE;

--
-- Name: T_DossierSuiviMembre T_DossierSuiviMembre_ID_DossierSuiviFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuiviMembre"
    ADD CONSTRAINT "T_DossierSuiviMembre_ID_DossierSuiviFk_fkey" FOREIGN KEY ("ID_DossierSuiviFk") REFERENCES logistique."T_DossierSuivi"("ID_DossierSuivi") ON DELETE RESTRICT;

--
-- Name: T_DossierSuivi T_DossierSuivi_ID_CategorieDossierSuiviFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuivi"
    ADD CONSTRAINT "T_DossierSuivi_ID_CategorieDossierSuiviFk_fkey" FOREIGN KEY ("ID_CategorieDossierSuiviFk") REFERENCES logistique."T_CategorieDossierSuivi"("ID_CategorieDossierSuivi") ON DELETE RESTRICT;

--
-- Name: T_DossierSuivi T_DossierSuivi_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuivi"
    ADD CONSTRAINT "T_DossierSuivi_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_DossierSuivi T_DossierSuivi_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_DossierSuivi"
    ADD CONSTRAINT "T_DossierSuivi_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_FactureLigne T_FactureLigne_ID_FactureFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_FactureLigne"
    ADD CONSTRAINT "T_FactureLigne_ID_FactureFk_fkey" FOREIGN KEY ("ID_FactureFk") REFERENCES logistique."T_Facture"("ID_Facture") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_FactureLigne_ID_FactureFk_fkey" ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_FactureLigne_ID_FactureFk_fkey" ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_ID_CommandeFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_ID_CommandeFk_fkey" FOREIGN KEY ("ID_CommandeFk") REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Facture_ID_CommandeFk_fkey" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_CommandeFk_fkey" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_ID_ConditionPaiementFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_ID_ConditionPaiementFk_fkey" FOREIGN KEY ("ID_ConditionPaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Facture_ID_ConditionPaiementFk_fkey" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_ConditionPaiementFk_fkey" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_ID_DeviseFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_ID_DeviseFk_fkey" FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Facture_ID_DeviseFk_fkey" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_DeviseFk_fkey" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_ID_ModePaiementFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_ID_ModePaiementFk_fkey" FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Facture_ID_ModePaiementFk_fkey" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_ModePaiementFk_fkey" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Facture_ID_UserFk_fkey" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_ID_UserFk_fkey" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Facture T_Facture_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Facture"
    ADD CONSTRAINT "T_Facture_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Facture_IdEntiteFk_fkey" ON "T_Facture"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Facture_IdEntiteFk_fkey" ON logistique."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Immobilisation T_Immobilisation_CreeParUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_CreeParUserFk_fkey" FOREIGN KEY ("CreeParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_CreeParUserFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_CreeParUserFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("CreeParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_ID_CategorieFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_ID_CategorieFk_fkey" FOREIGN KEY ("ID_CategorieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_ID_CategorieFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_CategorieFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("ID_CategorieFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_ID_DeviseFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_ID_DeviseFk_fkey" FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_ID_DeviseFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_DeviseFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_ID_EtatFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_ID_EtatFk_fkey" FOREIGN KEY ("ID_EtatFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_ID_EtatFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_EtatFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("ID_EtatFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_ID_LocalisationFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_ID_LocalisationFk_fkey" FOREIGN KEY ("ID_LocalisationFk") REFERENCES systeme."T_Entite_Localisation"("IdEntiteLocalisation") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_ID_LocalisationFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_LocalisationFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("ID_LocalisationFk") REFERENCES systeme."T_Entite_Localisation"("IdEntiteLocalisation") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_ID_ResponsableFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_ID_ResponsableFk_fkey" FOREIGN KEY ("ID_ResponsableFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_ID_ResponsableFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_ResponsableFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("ID_ResponsableFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_ID_ServiceFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_ID_ServiceFk_fkey" FOREIGN KEY ("ID_ServiceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_ID_ServiceFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ID_ServiceFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("ID_ServiceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_IdEntiteFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_IdEntiteFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_Immobilisation T_Immobilisation_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Immobilisation"
    ADD CONSTRAINT "T_Immobilisation_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Immobilisation_ModifieParUserFk_fkey" ON "T_Immobilisation"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Immobilisation_ModifieParUserFk_fkey" ON logistique."T_Immobilisation" IS 'Intégrité durable du patrimoine : FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT. Aucun effet de stock ou comptabilisation automatique.';

--
-- Name: T_InventaireLigne T_InventaireLigne_ID_ArticleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_InventaireLigne"
    ADD CONSTRAINT "T_InventaireLigne_ID_ArticleFk_fkey" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;

--
-- Name: T_InventaireLigne T_InventaireLigne_ID_CommandeAnnulationFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_InventaireLigne"
    ADD CONSTRAINT "T_InventaireLigne_ID_CommandeAnnulationFk_fkey" FOREIGN KEY ("ID_CommandeAnnulationFk") REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT;

--
-- Name: T_InventaireLigne T_InventaireLigne_ID_CommandeCorrectionFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_InventaireLigne"
    ADD CONSTRAINT "T_InventaireLigne_ID_CommandeCorrectionFk_fkey" FOREIGN KEY ("ID_CommandeCorrectionFk") REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT;

--
-- Name: T_InventaireLigne T_InventaireLigne_ID_InventaireFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_InventaireLigne"
    ADD CONSTRAINT "T_InventaireLigne_ID_InventaireFk_fkey" FOREIGN KEY ("ID_InventaireFk") REFERENCES logistique."T_Inventaire"("ID_Inventaire") ON DELETE RESTRICT;

--
-- Name: T_Inventaire T_Inventaire_ID_AnnulateurFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Inventaire"
    ADD CONSTRAINT "T_Inventaire_ID_AnnulateurFk_fkey" FOREIGN KEY ("ID_AnnulateurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Inventaire T_Inventaire_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Inventaire"
    ADD CONSTRAINT "T_Inventaire_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Inventaire T_Inventaire_ID_ValidateurFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Inventaire"
    ADD CONSTRAINT "T_Inventaire_ID_ValidateurFk_fkey" FOREIGN KEY ("ID_ValidateurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Inventaire T_Inventaire_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Inventaire"
    ADD CONSTRAINT "T_Inventaire_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_LotArticle T_LotArticle_ID_ArticleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_LotArticle"
    ADD CONSTRAINT "T_LotArticle_ID_ArticleFk_fkey" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;

--
-- Name: T_MouvementLot T_MouvementLot_ID_DerogationUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_MouvementLot"
    ADD CONSTRAINT "T_MouvementLot_ID_DerogationUserFk_fkey" FOREIGN KEY ("ID_DerogationUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_MouvementLot T_MouvementLot_ID_LotArticleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_MouvementLot"
    ADD CONSTRAINT "T_MouvementLot_ID_LotArticleFk_fkey" FOREIGN KEY ("ID_LotArticleFk") REFERENCES logistique."T_LotArticle"("ID_LotArticle") ON DELETE RESTRICT;

--
-- Name: T_MouvementLot T_MouvementLot_ID_MvtFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_MouvementLot"
    ADD CONSTRAINT "T_MouvementLot_ID_MvtFk_fkey" FOREIGN KEY ("ID_MvtFk") REFERENCES logistique."T_Mouvement"("ID_Mvt") ON DELETE CASCADE;

--
-- Name: T_PieceJustificative T_PieceJustificative_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_PieceJustificative"
    ADD CONSTRAINT "T_PieceJustificative_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_PieceJustificative T_PieceJustificative_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_PieceJustificative"
    ADD CONSTRAINT "T_PieceJustificative_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_Reglements T_Reglements_CreeParUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "T_Reglements_CreeParUserFk_fkey" FOREIGN KEY ("CreeParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser");

--
-- Name: CONSTRAINT "T_Reglements_CreeParUserFk_fkey" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_CreeParUserFk_fkey" ON logistique."T_Reglements" IS 'Auteur de création existant, sans déduction depuis le propriétaire de la facture.';

--
-- Name: T_Reglements T_Reglements_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT "T_Reglements_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser");

--
-- Name: CONSTRAINT "T_Reglements_ModifieParUserFk_fkey" ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT "T_Reglements_ModifieParUserFk_fkey" ON logistique."T_Reglements" IS 'Dernier auteur existant ; le changement de rattachement de cet utilisateur ne change pas l’entreprise du document.';

--
-- Name: T_Remboursement T_Remboursement_ID_AvoirFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Remboursement"
    ADD CONSTRAINT "T_Remboursement_ID_AvoirFk_fkey" FOREIGN KEY ("ID_AvoirFk") REFERENCES logistique."T_Avoir"("ID_Avoir") ON DELETE RESTRICT;

--
-- Name: T_Remboursement T_Remboursement_ID_ModePaiementFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Remboursement"
    ADD CONSTRAINT "T_Remboursement_ID_ModePaiementFk_fkey" FOREIGN KEY ("ID_ModePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Remboursement T_Remboursement_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Remboursement"
    ADD CONSTRAINT "T_Remboursement_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_ValorisationEvenement T_ValorisationEvenement_ID_ArticleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationEvenement"
    ADD CONSTRAINT "T_ValorisationEvenement_ID_ArticleFk_fkey" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;

--
-- Name: T_ValorisationEvenement T_ValorisationEvenement_ID_UserFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationEvenement"
    ADD CONSTRAINT "T_ValorisationEvenement_ID_UserFk_fkey" FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_ValorisationEvenement T_ValorisationEvenement_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationEvenement"
    ADD CONSTRAINT "T_ValorisationEvenement_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_ValorisationOuverture T_ValorisationOuverture_ID_ArticleFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationOuverture"
    ADD CONSTRAINT "T_ValorisationOuverture_ID_ArticleFk_fkey" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;

--
-- Name: T_ValorisationOuverture T_ValorisationOuverture_ID_DeviseFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationOuverture"
    ADD CONSTRAINT "T_ValorisationOuverture_ID_DeviseFk_fkey" FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_ValorisationOuverture T_ValorisationOuverture_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_ValorisationOuverture"
    ADD CONSTRAINT "T_ValorisationOuverture_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_Article article_devise_fk; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT article_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT article_devise_fk ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT article_devise_fk ON logistique."T_Article" IS 'Conserve la référence monétaire historique du catalogue ; suppression de la devise utilisée refusée.';

--
-- Name: T_Commande bon_article_initial_fk; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT bon_article_initial_fk FOREIGN KEY ("ID_ArticleInitialFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT bon_article_initial_fk ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT bon_article_initial_fk ON logistique."T_Commande" IS 'Reference durable a l article dont le stock initial est documente; suppression physique interdite.';

--
-- Name: T_Commande commande_devise_fk; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT commande_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT commande_devise_fk ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT commande_devise_fk ON logistique."T_Commande" IS 'Conserve la référence monétaire historique du bon et de sa facture.';

--
-- Name: T_Article fk_article_entite; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Article"
    ADD CONSTRAINT fk_article_entite FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_article_entite ON "T_Article"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_article_entite ON logistique."T_Article" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Commande fk_commande_entite; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT fk_commande_entite FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_commande_entite ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_commande_entite ON logistique."T_Commande" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_Commande fk_commande_tiers; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Commande"
    ADD CONSTRAINT fk_commande_tiers FOREIGN KEY ("ID_TiersFk") REFERENCES logistique."T_Client"("ID_Client") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_commande_tiers ON "T_Commande"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_commande_tiers ON logistique."T_Commande" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_FactureLigne fk_facture_ligne_origine; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_FactureLigne"
    ADD CONSTRAINT fk_facture_ligne_origine FOREIGN KEY ("ID_CmdFk", "ID_ArticleFk") REFERENCES logistique."T_CommandeDetail"("ID_CmdFk", "ID_ArticleFk") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_facture_ligne_origine ON "T_FactureLigne"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_facture_ligne_origine ON logistique."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';

--
-- Name: T_Reglements fk_reglement_tiers; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT fk_reglement_tiers FOREIGN KEY ("ID_TiersFk") REFERENCES logistique."T_Client"("ID_Client") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_reglement_tiers ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_reglement_tiers ON logistique."T_Reglements" IS 'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.';

--
-- Name: T_RetourBon fk_retour_bon_auteur; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_RetourBon"
    ADD CONSTRAINT fk_retour_bon_auteur FOREIGN KEY ("ID_UserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_retour_bon_auteur ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_retour_bon_auteur ON logistique."T_RetourBon" IS 'Conserve l’identité de l’auteur du retour.';

--
-- Name: T_RetourBon fk_retour_bon_entite; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_RetourBon"
    ADD CONSTRAINT fk_retour_bon_entite FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_retour_bon_entite ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_retour_bon_entite ON logistique."T_RetourBon" IS 'Conserve le rattachement organisationnel enregistré.';

--
-- Name: T_RetourBon fk_retour_bon_entree; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_RetourBon"
    ADD CONSTRAINT fk_retour_bon_entree FOREIGN KEY ("ID_CommandeRetourFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_retour_bon_entree ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_retour_bon_entree ON logistique."T_RetourBon" IS 'Conserve le bon d’entrée compensateur et son historique signé.';

--
-- Name: T_RetourBon fk_retour_bon_origine; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_RetourBon"
    ADD CONSTRAINT fk_retour_bon_origine FOREIGN KEY ("ID_CommandeOrigineFk") REFERENCES logistique."T_Commande"("ID_Commande") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_retour_bon_origine ON "T_RetourBon"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT fk_retour_bon_origine ON logistique."T_RetourBon" IS 'Conserve la sortie d’origine ; sa suppression et la modification de sa clé sont refusées.';

--
-- Name: T_Mouvement mouvement_devise_fk; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Mouvement"
    ADD CONSTRAINT mouvement_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT mouvement_devise_fk ON "T_Mouvement"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT mouvement_devise_fk ON logistique."T_Mouvement" IS 'Conserve la référence monétaire du mouvement sans dépendre de la devise actuelle du catalogue.';

--
-- Name: T_PrecisionStock precision_stock_unite_fk; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_PrecisionStock"
    ADD CONSTRAINT precision_stock_unite_fk FOREIGN KEY ("ID_UniteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE RESTRICT ON DELETE RESTRICT;

--
-- Name: CONSTRAINT precision_stock_unite_fk ON "T_PrecisionStock"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT precision_stock_unite_fk ON logistique."T_PrecisionStock" IS 'Référence réelle à la même nomenclature d’unités que les articles ; suppression et changement d’identité refusés.';

--
-- Name: T_Reglements reglement_devise_fk; Type: FK CONSTRAINT; Schema: logistique; Owner: -
--

ALTER TABLE ONLY logistique."T_Reglements"
    ADD CONSTRAINT reglement_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT reglement_devise_fk ON "T_Reglements"; Type: COMMENT; Schema: logistique; Owner: -
--

COMMENT ON CONSTRAINT reglement_devise_fk ON logistique."T_Reglements" IS 'Conserve la référence monétaire du règlement après son enregistrement.';

COMMENT ON CONSTRAINT "facture_snapshot_coherent" ON "logistique"."T_Facture" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';
COMMENT ON CONSTRAINT "facture_ligne_coherente" ON "logistique"."T_FactureLigne" IS 'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.';
