-- Support transversal : dictionnaire commun, circuit dans les paramètres système,
-- données métier dans support et stockage documentaire privé existant réutilisé.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
SELECT pg_advisory_xact_lock(hashtextextended('migration:support:20261030_06',0));
DO $precondition$
BEGIN
 IF current_database()<>'SauverNdeko' AND left(current_database(),17)<>'sauverndeko_test_' THEN RAISE EXCEPTION 'Base cible non autorisée.';END IF;
 IF to_regprocedure('referentiel.fn_valider_reference_champ(text,text,text,integer,integer)') IS NULL OR to_regclass('logistique."T_Client"') IS NULL THEN RAISE EXCEPTION 'Socle référentiel, entreprise et tiers requis.';END IF;
 IF to_regclass('support."T_Support"') IS NOT NULL THEN RAISE EXCEPTION 'Support déjà installé ; vérifier le schéma avant de rejouer cette migration.';END IF;
END $precondition$;

CREATE SCHEMA IF NOT EXISTS support;
COMMENT ON SCHEMA support IS 'Dossiers d’assistance, incidents et réclamations propres aux entreprises ; les référentiels et configurations restent dans leurs schémas communs.';

CREATE TABLE support."T_Support"(
 "ID_Support" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "NumeroSupport" varchar(40) NOT NULL,
 "Objet" varchar(200) NOT NULL CHECK(length(btrim("Objet")) BETWEEN 1 AND 200),
 "Description" text NOT NULL CHECK(length(btrim("Description")) BETWEEN 1 AND 20000),
 "ID_DemandeurFk" bigint REFERENCES logistique."T_Client"("ID_Client") ON DELETE RESTRICT,
 "ID_CreateurFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ID_ResponsableFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ID_ServiceConcerneFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_TypeSupportFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_CategorieSupportFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_PrioriteFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_StatutFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_CanalOrigineFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_ImmobilisationFk" integer REFERENCES logistique."T_Immobilisation"("ID_Immobilisation") ON DELETE RESTRICT,
 "ID_CommandeFk" integer REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT,
 "ID_ArticleFk" integer REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "DateCreation" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "DateModification" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "DateEcheance" timestamptz CHECK("DateEcheance" IS NULL OR isfinite("DateEcheance")),
 "DateResolution" timestamptz,
 "DateCloture" timestamptz,
 "VersionEnregistrement" bigint NOT NULL DEFAULT 1 CHECK("VersionEnregistrement">0),
 "Archive" boolean NOT NULL DEFAULT false,
 "CircuitSnapshot" jsonb NOT NULL CHECK(jsonb_typeof("CircuitSnapshot")='object'),
 CONSTRAINT uq_support_numero_entite UNIQUE("IdEntiteFk","NumeroSupport")
);
CREATE TABLE support."T_CommentaireSupport"(
 "ID_CommentaireSupport" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_SupportFk" bigint NOT NULL REFERENCES support."T_Support"("ID_Support") ON DELETE RESTRICT,
 "ID_AuteurFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "Contenu" text NOT NULL CHECK(length(btrim("Contenu")) BETWEEN 1 AND 20000),
 "Visibilite" text NOT NULL DEFAULT 'public' CHECK("Visibilite" IN('public','interne')),
 "DateCreation" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "DateModification" timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE support."T_ResolutionSupport"(
 "ID_ResolutionSupport" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_SupportFk" bigint NOT NULL REFERENCES support."T_Support"("ID_Support") ON DELETE RESTRICT,
 "CauseIdentifiee" text NOT NULL CHECK(length(btrim("CauseIdentifiee")) BETWEEN 1 AND 10000),
 "SolutionAppliquee" text NOT NULL CHECK(length(btrim("SolutionAppliquee")) BETWEEN 1 AND 20000),
 "ID_ProposeParFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "DateProposition" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "ID_ResultatVerificationFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_VerifieParFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "DateVerification" timestamptz,
 "CommentaireVerification" text CHECK("CommentaireVerification" IS NULL OR length("CommentaireVerification")<=10000),
 CONSTRAINT ck_support_verification_complete CHECK(("ID_ResultatVerificationFk" IS NULL AND "ID_VerifieParFk" IS NULL AND "DateVerification" IS NULL) OR ("ID_ResultatVerificationFk" IS NOT NULL AND "ID_VerifieParFk" IS NOT NULL AND "DateVerification" IS NOT NULL)),
 CONSTRAINT ck_support_verificateur_distinct CHECK("ID_VerifieParFk" IS DISTINCT FROM "ID_ProposeParFk")
);
CREATE TABLE support."T_PieceSupport"(
 "ID_PieceFk" bigint PRIMARY KEY REFERENCES logistique."T_PieceJustificative"("ID_Piece") ON DELETE RESTRICT,
 "ID_SupportFk" bigint NOT NULL REFERENCES support."T_Support"("ID_Support") ON DELETE RESTRICT,
 "ID_CommentaireSupportFk" bigint REFERENCES support."T_CommentaireSupport"("ID_CommentaireSupport") ON DELETE RESTRICT,
 "Visibilite" text NOT NULL DEFAULT 'public' CHECK("Visibilite" IN('public','interne'))
);
COMMENT ON TABLE support."T_Support" IS 'Dossier d’assistance ou de réclamation appartenant durablement à une entreprise. Le numéro, l’auteur et le circuit initial sont immuables ; la résolution est distincte de sa vérification et de la clôture.';
COMMENT ON TABLE support."T_CommentaireSupport" IS 'Échanges immuables du dossier, publics pour ses lecteurs autorisés ou internes aux gestionnaires ; aucune publication Internet.';
COMMENT ON TABLE support."T_ResolutionSupport" IS 'Tentatives successives de résolution, solution documentée et vérification contradictoire immuable ; une proposition n’est pas une clôture.';
COMMENT ON TABLE support."T_PieceSupport" IS 'Liaison à clés étrangères du dossier vers le stockage privé T_PieceJustificative existant, sans duplication des octets ; commentaire facultatif du même dossier.';

CREATE FUNCTION systeme.fn_support_circuit_defaut() RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE states jsonb;verification jsonb;family integer;
BEGIN
 SELECT "ID_CategorieDefautFk" INTO family FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='support' AND "TableName"='T_Support' AND "ColumnName"='ID_StatutFk';
 SELECT jsonb_object_agg(replace("AbrGenerique",'support.status.',''),"ID_Generique") INTO states FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=family AND "IdEntiteFk" IS NULL AND "ValideGenerique" AND "AbrGenerique" IN('support.status.new','support.status.active','support.status.pending','support.status.resolved','support.status.closed');
 SELECT "ID_CategorieDefautFk" INTO family FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='support' AND "TableName"='T_ResolutionSupport' AND "ColumnName"='ID_ResultatVerificationFk';
 SELECT jsonb_object_agg(CASE "AbrGenerique" WHEN 'support.verify.ok' THEN 'accepted' ELSE 'rejected' END,"ID_Generique") INTO verification FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=family AND "IdEntiteFk" IS NULL AND "ValideGenerique" AND "AbrGenerique" IN('support.verify.ok','support.verify.ko');
 IF NOT (coalesce(states,'{}') ?& ARRAY['new','active','pending','resolved','closed']) OR NOT (coalesce(verification,'{}') ?& ARRAY['accepted','rejected']) THEN RAISE EXCEPTION 'Dictionnaire de circuit Support incomplet.' USING ERRCODE='23514';END IF;
 RETURN jsonb_build_object('version',1,'states',states,'verification',verification,'transitions','[{"from":"new","to":"active","action":"start"},{"from":"active","to":"pending","action":"pause"},{"from":"pending","to":"active","action":"resume"},{"from":"active","to":"resolved","action":"resolve"},{"from":"pending","to":"resolved","action":"resolve"},{"from":"resolved","to":"closed","action":"close"},{"from":"resolved","to":"active","action":"reopen"},{"from":"closed","to":"active","action":"reopen"}]'::jsonb);
END $$;
COMMENT ON FUNCTION systeme.fn_support_circuit_defaut() IS 'Circuit initial fermé d’installation : résout les identifiants du dictionnaire commun par codes sémantiques et familles du catalogue ; ne transporte aucune surcharge, auteur ou valeur de configuration client.';

-- Dictionnaire : aucune table de statuts, priorités, canaux ou types autonome.
LOCK TABLE referentiel."T_CategorieGenerique",referentiel."T_Generique" IN SHARE ROW EXCLUSIVE MODE;
DO $seed$
DECLARE item record;val record;family integer;n integer;defaults jsonb:='{}';states jsonb;verification jsonb;service_family integer;
BEGIN
 FOR item IN SELECT * FROM (VALUES
  ('Type de support','ID_TypeSupportFk','Type de support','types'),
  ('Catégorie de support','ID_CategorieSupportFk','Catégorie de support','categories'),
  ('Priorité du support','ID_PrioriteFk','Priorité','priorities'),
  ('Statut du support','ID_StatutFk','Statut','statuses'),
  ('Canal du support','ID_CanalOrigineFk','Canal d’origine','channels'),
  ('Vérification du support','ID_ResultatVerificationFk','Résultat de vérification','verification')) AS s(family,col,label,alias)
 LOOP
  SELECT count(*),min("ID_CategorieGenerique") INTO n,family FROM referentiel."T_CategorieGenerique" WHERE "IdEntiteFk" IS NULL AND lower(btrim("NomCategorieGenerique"))=lower(item.family);
  IF n>1 THEN RAISE EXCEPTION 'Famille % ambiguë.',item.family;END IF;
  IF family IS NULL THEN INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ModuleCategorieGenerique","ValideCategorieGenerique") VALUES(item.family,'M_SUPPORT',true) RETURNING "ID_CategorieGenerique" INTO family;END IF;
  IF NOT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=family AND "ValideCategorieGenerique") THEN RAISE EXCEPTION 'Famille % inactive.',item.family;END IF;
  defaults:=defaults||jsonb_build_object(item.alias,family);
  INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName","ID_CategorieDefautFk","AliasSourceKeys","CanConfigure","SupportsEntityScope")
  VALUES('support',CASE WHEN item.alias='verification' THEN 'T_ResolutionSupport' ELSE 'T_Support' END,item.col,item.label,'support',family,ARRAY['support.'||item.alias],true,true);
 END LOOP;
 FOR val IN SELECT * FROM (VALUES
 ('types','Incident','support.type.incident'),('types','Demande d’assistance','support.type.assistance'),('types','Réclamation','support.type.reclamation'),
 ('categories','Général','support.category.general'),('categories','Application','support.category.application'),('categories','Matériel','support.category.material'),('categories','Service','support.category.service'),
 ('priorities','Basse','support.priority.low'),('priorities','Normale','support.priority.normal'),('priorities','Haute','support.priority.high'),('priorities','Critique','support.priority.critical'),
 ('statuses','Nouveau','support.status.new'),('statuses','En cours','support.status.active'),('statuses','En attente','support.status.pending'),('statuses','Résolu','support.status.resolved'),('statuses','Clôturé','support.status.closed'),
 ('channels','Application','support.channel.app'),('channels','E-mail','support.channel.email'),('channels','Téléphone','support.channel.phone'),('channels','Sur place','support.channel.onsite'),
 ('verification','Conforme','support.verify.ok'),('verification','À reprendre','support.verify.ko')) AS v(family,label,code)
 LOOP
  family:=(defaults->>val.family)::integer;
  IF NOT EXISTS(SELECT FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=family AND "AbrGenerique"=val.code AND "IdEntiteFk" IS NULL) THEN
   INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(family,val.label,val.code,true);
  END IF;
 END LOOP;
 SELECT "ID_CategorieDefautFk" INTO service_family FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='systeme' AND "TableName"='T_Utilisateurs' AND "ColumnName"='ID_ServiceFk';
 IF service_family IS NULL THEN RAISE EXCEPTION 'Référencement du service professionnel requis.';END IF;
 INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName","ID_CategorieDefautFk","AliasSourceKeys","CanConfigure","SupportsEntityScope")
 VALUES('support','T_Support','ID_ServiceConcerneFk','Service concerné','support',service_family,ARRAY['support.services'],true,true);
 SELECT jsonb_object_agg(replace("AbrGenerique",'support.status.',''),"ID_Generique") INTO states FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=(defaults->>'statuses')::integer AND "IdEntiteFk" IS NULL AND "AbrGenerique" LIKE 'support.status.%';
 SELECT jsonb_object_agg(CASE "AbrGenerique" WHEN 'support.verify.ok' THEN 'accepted' ELSE 'rejected' END,"ID_Generique") INTO verification FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=(defaults->>'verification')::integer AND "IdEntiteFk" IS NULL AND "AbrGenerique" IN('support.verify.ok','support.verify.ko');
 INSERT INTO systeme."T_Admin_UI_Setting"("SettingScope","SettingKey","SettingLabel","SettingGroup","SettingType","SettingValueJson","IsEditable","IsSystem","ValideSetting","ObsSetting")
 VALUES('global','support.workflow','Circuit de traitement du Support','support','json',jsonb_build_object('version',1,'states',states,'verification',verification,'transitions',
 '[{"from":"new","to":"active","action":"start"},{"from":"active","to":"pending","action":"pause"},{"from":"pending","to":"active","action":"resume"},{"from":"active","to":"resolved","action":"resolve"},{"from":"pending","to":"resolved","action":"resolve"},{"from":"resolved","to":"closed","action":"close"},{"from":"resolved","to":"active","action":"reopen"},{"from":"closed","to":"active","action":"reopen"}]'::jsonb),true,true,true,'Circuit versionné : chaque nouveau dossier conserve sa copie exacte. Les dossiers existants et leurs résolutions ne sont jamais migrés par ce réglage.');
END $seed$;

CREATE OR REPLACE FUNCTION referentiel.fn_entite_reference_champ(p_schema text, p_table text, p_ligne jsonb) RETURNS integer
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE owner_id integer;
BEGIN
 -- L'entreprise de l'utilisateur ou d'un résultat de recherche n'est pas
 -- un propriétaire durable d'une ligne partagée.
 IF p_ligne IS NULL OR NOT EXISTS(SELECT FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "SupportsEntityScope") THEN RETURN NULL;END IF;
 IF (p_schema,p_table)=('logistique','T_PrecisionStock') THEN
  SELECT "IdEntiteFk" INTO owner_id FROM referentiel."T_Generique" WHERE "ID_Generique"=nullif(p_ligne->>'ID_UniteFk','')::integer;RETURN owner_id;END IF;
 IF (p_schema,p_table)=('systeme','T_Entite') THEN RETURN nullif(p_ligne->>'IdEntite','')::integer;END IF;
 owner_id:=coalesce(nullif(p_ligne->>'IdEntiteFk','')::integer,nullif(p_ligne->>'ID_EntiteFk','')::integer);
 IF owner_id IS NOT NULL THEN RETURN owner_id;END IF;
 IF p_schema='support' AND p_table='T_ResolutionSupport' THEN
  SELECT "IdEntiteFk" INTO owner_id FROM support."T_Support" WHERE "ID_Support"=nullif(p_ligne->>'ID_SupportFk','')::bigint;RETURN owner_id;END IF;
 IF p_schema='logistique' THEN
  CASE p_table
   WHEN 'T_Mouvement' THEN
    SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "ID_Commande"=nullif(p_ligne->>'ID_cmdFk','')::integer;
    IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Article" WHERE "ID_Article"=nullif(p_ligne->>'ID_ArticleFk','')::integer;END IF;
   WHEN 'T_Reglements' THEN
    SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Facture" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';
    IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';END IF;
   WHEN 'T_Remboursement' THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Avoir" WHERE "ID_Avoir"=nullif(p_ligne->>'ID_AvoirFk','')::bigint;
   ELSE NULL;
  END CASE;
 END IF;
 RETURN owner_id;
END $$;
COMMENT ON FUNCTION referentiel.fn_entite_reference_champ(text,text,jsonb) IS 'Résout le propriétaire durable de la vraie ligne, y compris la résolution Support via son parent ; aucune entreprise déduite du compte actuel.';

CREATE FUNCTION systeme.fn_support_circuit(p_entite integer) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE r systeme."T_Admin_UI_Setting";
BEGIN
 SELECT * INTO r FROM systeme."T_Admin_UI_Setting" WHERE "SettingKey"='support.workflow' AND "ValideSetting" AND (("SettingScope"='entite' AND "ScopeValue"=p_entite::text) OR ("SettingScope"='global' AND "ScopeValue" IS NULL)) ORDER BY CASE WHEN "SettingScope"='entite' THEN 0 ELSE 1 END LIMIT 1;
 IF NOT FOUND OR r."SettingType"<>'json' OR jsonb_typeof(r."SettingValueJson") IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Circuit de traitement Support indisponible.' USING ERRCODE='23514';END IF;
 RETURN r."SettingValueJson"||jsonb_build_object('settingId',r."IdAdminUISetting",'settingUpdatedAt',r."UpdatedAt");
END $$;
COMMENT ON FUNCTION systeme.fn_support_circuit(integer) IS 'Résout le circuit Support dans les paramètres système existants, entreprise puis global ; ne crée aucune configuration parallèle et capture sa version lors de la création.';

CREATE FUNCTION systeme.tr_support_circuit_valider() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v jsonb:=NEW."SettingValueJson";r record;entity_id integer;cnt integer;
BEGIN
 IF NEW."SettingKey"<>'support.workflow' THEN RETURN NEW;END IF;
 IF NEW."SettingScope" NOT IN('global','entite') OR NEW."SettingType"<>'json' OR jsonb_typeof(v) IS DISTINCT FROM 'object' OR coalesce(v->>'version','') !~ '^[1-9][0-9]{0,8}$' OR jsonb_typeof(v->'states') IS DISTINCT FROM 'object' OR jsonb_typeof(v->'verification') IS DISTINCT FROM 'object' OR jsonb_typeof(v->'transitions') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Structure du circuit Support invalide.' USING ERRCODE='23514';END IF;
 IF NEW."SettingScope"='entite' THEN
  IF coalesce(NEW."ScopeValue",'') !~ '^[1-9][0-9]{0,8}$' OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"::text=NEW."ScopeValue") THEN RAISE EXCEPTION 'Entreprise du circuit inconnue.' USING ERRCODE='23514';END IF;
  entity_id:=NEW."ScopeValue"::integer;
 END IF;
 SELECT count(DISTINCT value) INTO cnt FROM jsonb_each_text(v->'states');
 IF cnt<>5 OR NOT (v->'states' ?& ARRAY['new','active','pending','resolved','closed']) OR systeme.fn_support_object_size(v->'states')<>5 THEN RAISE EXCEPTION 'Les cinq états distincts du circuit sont requis.' USING ERRCODE='23514';END IF;
 FOR r IN SELECT * FROM jsonb_each_text(v->'states') LOOP
  IF r.value !~ '^[1-9][0-9]{0,8}$' OR NOT referentiel.fn_valider_reference_champ('support','T_Support','ID_StatutFk',r.value::integer,entity_id) THEN RAISE EXCEPTION 'Statut de circuit hors référentiel actif.' USING ERRCODE='23514';END IF;
 END LOOP;
 IF NOT (v->'verification' ?& ARRAY['accepted','rejected']) OR v->'verification'->>'accepted'=v->'verification'->>'rejected' THEN RAISE EXCEPTION 'Résultats de vérification distincts requis.' USING ERRCODE='23514';END IF;
 FOR r IN SELECT * FROM jsonb_each_text(v->'verification') LOOP
  IF r.value !~ '^[1-9][0-9]{0,8}$' OR NOT referentiel.fn_valider_reference_champ('support','T_ResolutionSupport','ID_ResultatVerificationFk',r.value::integer,entity_id) THEN RAISE EXCEPTION 'Vérification hors référentiel actif.' USING ERRCODE='23514';END IF;
 END LOOP;
 FOR r IN SELECT value edge FROM jsonb_array_elements(v->'transitions') LOOP
  IF jsonb_typeof(r.edge) IS DISTINCT FROM 'object' OR NOT (v->'states' ? (r.edge->>'from')) OR NOT (v->'states' ? (r.edge->>'to')) OR r.edge->>'from'=r.edge->>'to' OR NOT EXISTS(
   SELECT FROM (VALUES('new','active','start'),('active','pending','pause'),('pending','active','resume'),('active','resolved','resolve'),('pending','resolved','resolve'),('resolved','closed','close'),('resolved','active','reopen'),('closed','active','reopen')) allowed(src,dst,action)
   WHERE allowed.src=r.edge->>'from' AND allowed.dst=r.edge->>'to' AND allowed.action=r.edge->>'action') THEN RAISE EXCEPTION 'Transition du circuit invalide ou action incompatible.' USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN NEW;
END $$;
-- PostgreSQL fournit jsonb_object_keys ; compter évite toute dépendance à une extension.
CREATE FUNCTION systeme.fn_support_object_size(p_value jsonb) RETURNS integer LANGUAGE sql IMMUTABLE STRICT AS $$SELECT count(*)::integer FROM jsonb_object_keys(p_value)$$;
COMMENT ON FUNCTION systeme.fn_support_object_size(jsonb) IS 'Nombre de propriétés d’un objet JSON du circuit, sans extension ni identifiant métier codé en dur.';
COMMENT ON FUNCTION systeme.tr_support_circuit_valider() IS 'Contrôle les états et transitions du circuit dans T_Admin_UI_Setting contre le référencement physique courant ; les libellés restent exclusivement dans T_Generique.';

CREATE FUNCTION support.fn_etat_support(p_circuit jsonb,p_statut integer) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT key FROM jsonb_each_text(p_circuit->'states') WHERE value=p_statut::text LIMIT 1$$;
COMMENT ON FUNCTION support.fn_etat_support(jsonb,integer) IS 'Rôle sémantique d’un statut dans la copie exacte du circuit du dossier ; aucun libellé ni ID de catégorie dupliqué.';

CREATE FUNCTION support.tr_support_verifier() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE actor integer:=systeme.fn_admin_actor_user_id();actor_entity integer;actor_global boolean;old_state text;new_state text;cfg jsonb;ctx jsonb;reason text;f record;latest support."T_ResolutionSupport";target_entity integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Archivez le dossier pour conserver son historique.' USING ERRCODE='23514';END IF;
 IF actor IS NULL THEN RAISE EXCEPTION 'Auteur actif requis.' USING ERRCODE='23514';END IF;
 SELECT "IdEntiteFk","Is_Admin" INTO actor_entity,actor_global FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor;
 IF NOT actor_global AND actor_entity IS DISTINCT FROM NEW."IdEntiteFk" THEN RAISE EXCEPTION 'Dossier hors entreprise de l’auteur.' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" AND "ValideEntite") THEN RAISE EXCEPTION 'Entreprise active requise.' USING ERRCODE='23514';END IF;
 BEGIN ctx:=coalesce(nullif(current_setting('support.mutation',true),'')::jsonb,'{}'::jsonb);EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Contexte de traitement invalide.' USING ERRCODE='23514';END;
 reason:=nullif(btrim(ctx->>'motif'),'');
 IF TG_OP='INSERT' THEN
  NEW."NumeroSupport":='SUP-'||NEW."ID_Support"::text;NEW."ID_CreateurFk":=actor;NEW."CircuitSnapshot":=systeme.fn_support_circuit(NEW."IdEntiteFk");
  NEW."ID_StatutFk":=(NEW."CircuitSnapshot"->'states'->>'new')::integer;NEW."VersionEnregistrement":=1;
  NEW."DateCreation":=clock_timestamp();NEW."DateResolution":=NULL;NEW."DateCloture":=NULL;NEW."Archive":=false;
  -- Vérifier la configuration au moment de son utilisation, même si modifiée avant installation du garde.
  FOR f IN SELECT * FROM jsonb_each_text(NEW."CircuitSnapshot"->'states') LOOP
   IF f.value !~ '^[1-9][0-9]{0,8}$' OR NOT referentiel.fn_valider_reference_champ('support','T_Support','ID_StatutFk',f.value::integer,NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Le circuit ne correspond plus aux statuts configurés.' USING ERRCODE='23514';END IF;
  END LOOP;
 ELSE
  IF ROW(NEW."ID_Support",NEW."IdEntiteFk",NEW."NumeroSupport",NEW."ID_CreateurFk",NEW."DateCreation",NEW."CircuitSnapshot") IS DISTINCT FROM ROW(OLD."ID_Support",OLD."IdEntiteFk",OLD."NumeroSupport",OLD."ID_CreateurFk",OLD."DateCreation",OLD."CircuitSnapshot") THEN RAISE EXCEPTION 'Identité, propriétaire et circuit initial du dossier immuables.' USING ERRCODE='23514';END IF;
  IF NEW."VersionEnregistrement"<>OLD."VersionEnregistrement" THEN RAISE EXCEPTION 'La révision est attribuée par la base.' USING ERRCODE='23514';END IF;
  NEW."VersionEnregistrement":=OLD."VersionEnregistrement"+1;
  old_state:=support.fn_etat_support(OLD."CircuitSnapshot",OLD."ID_StatutFk");
  IF OLD."Archive" AND NEW."Archive" THEN RAISE EXCEPTION 'Restaurez le dossier avant modification.' USING ERRCODE='23514';END IF;
  IF NOT OLD."Archive" AND NEW."Archive" AND old_state<>'closed' THEN RAISE EXCEPTION 'Seul un dossier clôturé peut être archivé.' USING ERRCODE='23514';END IF;
  IF OLD."Archive" IS DISTINCT FROM NEW."Archive" AND reason IS NULL THEN RAISE EXCEPTION 'Motif d’archivage ou de restauration obligatoire.' USING ERRCODE='23514';END IF;
  IF OLD."Archive" IS DISTINCT FROM NEW."Archive" AND (to_jsonb(NEW)-ARRAY['Archive','VersionEnregistrement','DateModification']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['Archive','VersionEnregistrement','DateModification']) THEN RAISE EXCEPTION 'Archivage et modification se font séparément.' USING ERRCODE='23514';END IF;
 END IF;
 NEW."DateModification":=clock_timestamp();
 new_state:=support.fn_etat_support(NEW."CircuitSnapshot",NEW."ID_StatutFk");
 IF new_state IS NULL THEN RAISE EXCEPTION 'Statut absent du circuit du dossier.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."ID_StatutFk" IS DISTINCT FROM OLD."ID_StatutFk" THEN
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(NEW."CircuitSnapshot"->'transitions') e WHERE e->>'from'=old_state AND e->>'to'=new_state) THEN RAISE EXCEPTION 'Transition non autorisée par le circuit du dossier.' USING ERRCODE='23514';END IF;
  IF (new_state='pending' OR (old_state IN('resolved','closed') AND new_state='active')) AND reason IS NULL THEN RAISE EXCEPTION 'Un motif est obligatoire pour la mise en attente ou la réouverture.' USING ERRCODE='23514';END IF;
  IF new_state IN('active','pending','resolved') AND NEW."ID_ResponsableFk" IS NULL THEN RAISE EXCEPTION 'Responsable requis avant prise en charge.' USING ERRCODE='23514';END IF;
  SELECT * INTO latest FROM support."T_ResolutionSupport" WHERE "ID_SupportFk"=NEW."ID_Support" ORDER BY "ID_ResolutionSupport" DESC LIMIT 1;
  IF new_state='resolved' THEN
   IF latest."ID_ResolutionSupport" IS NULL OR latest."ID_ResultatVerificationFk" IS NOT NULL OR latest."DateProposition"<OLD."DateModification" THEN RAISE EXCEPTION 'Nouvelle solution documentée requise avant résolution.' USING ERRCODE='23514';END IF;
   NEW."DateResolution":=clock_timestamp();NEW."DateCloture":=NULL;
  ELSIF new_state='closed' THEN
   IF old_state<>'resolved' OR latest."ID_ResultatVerificationFk" IS DISTINCT FROM (NEW."CircuitSnapshot"->'verification'->>'accepted')::integer OR latest."ID_VerifieParFk" IS NULL OR latest."ID_VerifieParFk"=latest."ID_ProposeParFk" THEN RAISE EXCEPTION 'Résolution vérifiée conforme par un autre responsable requise avant clôture.' USING ERRCODE='23514';END IF;
   NEW."DateCloture":=clock_timestamp();
  ELSIF old_state IN('resolved','closed') THEN NEW."DateCloture":=NULL;NEW."DateResolution":=NULL;
  END IF;
 ELSIF TG_OP='UPDATE' THEN NEW."DateResolution":=OLD."DateResolution";NEW."DateCloture":=OLD."DateCloture";
 END IF;
 IF TG_OP='UPDATE' AND old_state='closed' AND new_state='closed' AND NEW."Archive"=OLD."Archive" THEN RAISE EXCEPTION 'Rouvrez le dossier avant modification.' USING ERRCODE='23514';END IF;
 IF NEW."ID_ResponsableFk" IS NOT NULL THEN PERFORM 1 FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_ResponsableFk" FOR SHARE;END IF;
 IF NEW."ID_DemandeurFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Client" WHERE "ID_Client"=NEW."ID_DemandeurFk" FOR SHARE;END IF;
 IF NEW."ID_ImmobilisationFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Immobilisation" WHERE "ID_Immobilisation"=NEW."ID_ImmobilisationFk" FOR SHARE;END IF;
 IF NEW."ID_CommandeFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CommandeFk" FOR SHARE;END IF;
 IF NEW."ID_ArticleFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk" FOR SHARE;END IF;
 IF NEW."ID_ResponsableFk" IS NOT NULL AND (TG_OP='INSERT' OR NEW."ID_ResponsableFk" IS DISTINCT FROM OLD."ID_ResponsableFk") AND NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_ResponsableFk" AND "ValideUser" AND ("IdEntiteFk"=NEW."IdEntiteFk" OR "Is_Admin")) THEN RAISE EXCEPTION 'Responsable actif hors entreprise.' USING ERRCODE='23514';END IF;
 IF new_state IN('active','pending','resolved') AND NEW."ID_ResponsableFk" IS NULL THEN RAISE EXCEPTION 'Responsable requis pendant le traitement.' USING ERRCODE='23514';END IF;
 IF NEW."ID_DemandeurFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Client" WHERE "ID_Client"=NEW."ID_DemandeurFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Demandeur hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."ID_ImmobilisationFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Immobilisation" WHERE "ID_Immobilisation"=NEW."ID_ImmobilisationFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Matériel hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."ID_CommandeFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CommandeFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Bon hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."ID_ArticleFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Article hors entreprise.' USING ERRCODE='23514';END IF;
 FOR f IN SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='support' AND "TableName"='T_Support' AND "ColumnName"<>'ID_StatutFk' LOOP
  IF TG_OP='UPDATE' AND to_jsonb(NEW)->f."ColumnName" IS NOT DISTINCT FROM to_jsonb(OLD)->f."ColumnName" THEN CONTINUE;END IF;
  IF to_jsonb(NEW)->>f."ColumnName" IS NOT NULL THEN PERFORM 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=(to_jsonb(NEW)->>f."ColumnName")::integer FOR SHARE;END IF;
  IF NOT referentiel.fn_valider_reference_champ('support','T_Support',f."ColumnName",(to_jsonb(NEW)->>f."ColumnName")::integer,NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Référence inactive ou incompatible : %.',f."ColumnName" USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION support.tr_support_verifier() IS 'Socle métier SQL : propriété et identité immuables, copie initiale du circuit, références dynamiques, cohérence d’entreprise, responsable obligatoire, motif, solution puis vérification distincte avant clôture ; révision et dates exclusivement attribuées par la base.';

CREATE FUNCTION support.tr_enfant_support_verifier() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE actor integer:=systeme.fn_admin_actor_user_id();parent support."T_Support";state text;piece logistique."T_PieceJustificative";entity_id integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Les échanges, résolutions et preuves du dossier sont conservés.' USING ERRCODE='23514';END IF;
 SELECT * INTO parent FROM support."T_Support" WHERE "ID_Support"=NEW."ID_SupportFk" FOR UPDATE;
 IF NOT FOUND OR parent."Archive" THEN RAISE EXCEPTION 'Dossier inexistant ou archivé.' USING ERRCODE='23514';END IF;
 state:=support.fn_etat_support(parent."CircuitSnapshot",parent."ID_StatutFk");
 IF actor IS NULL OR NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor AND ("Is_Admin" OR "IdEntiteFk"=parent."IdEntiteFk")) THEN RAISE EXCEPTION 'Auteur hors entreprise du dossier.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_CommentaireSupport' THEN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Les commentaires sont conservés sans réécriture.' USING ERRCODE='23514';END IF;
  IF state='closed' THEN RAISE EXCEPTION 'Rouvrez le dossier avant de commenter.' USING ERRCODE='23514';END IF;
  NEW."ID_AuteurFk":=actor;NEW."DateCreation":=clock_timestamp();NEW."DateModification":=NEW."DateCreation";
 ELSIF TG_TABLE_NAME='T_ResolutionSupport' THEN
  IF TG_OP='INSERT' THEN
   IF state NOT IN('active','pending') OR parent."ID_ResponsableFk" IS NULL THEN RAISE EXCEPTION 'Le dossier doit être pris en charge avant proposition de solution.' USING ERRCODE='23514';END IF;
   IF NEW."ID_ResultatVerificationFk" IS NOT NULL OR NEW."ID_VerifieParFk" IS NOT NULL OR NEW."DateVerification" IS NOT NULL THEN RAISE EXCEPTION 'La vérification intervient après la proposition.' USING ERRCODE='23514';END IF;
   NEW."ID_ProposeParFk":=actor;NEW."DateProposition":=clock_timestamp();
  ELSE
   IF ROW(NEW."ID_ResolutionSupport",NEW."ID_SupportFk",NEW."CauseIdentifiee",NEW."SolutionAppliquee",NEW."ID_ProposeParFk",NEW."DateProposition") IS DISTINCT FROM ROW(OLD."ID_ResolutionSupport",OLD."ID_SupportFk",OLD."CauseIdentifiee",OLD."SolutionAppliquee",OLD."ID_ProposeParFk",OLD."DateProposition") OR OLD."ID_ResultatVerificationFk" IS NOT NULL THEN RAISE EXCEPTION 'La tentative et sa vérification sont immuables ; créez une nouvelle tentative.' USING ERRCODE='23514';END IF;
   IF state<>'resolved' OR NEW."ID_ResolutionSupport" IS DISTINCT FROM (SELECT max("ID_ResolutionSupport") FROM support."T_ResolutionSupport" WHERE "ID_SupportFk"=parent."ID_Support") THEN RAISE EXCEPTION 'Seule la dernière résolution en attente peut être vérifiée.' USING ERRCODE='23514';END IF;
   IF actor=NEW."ID_ProposeParFk" THEN RAISE EXCEPTION 'La vérification doit être faite par une autre personne habilitée.' USING ERRCODE='23514';END IF;
   IF NEW."ID_ResultatVerificationFk" NOT IN((parent."CircuitSnapshot"->'verification'->>'accepted')::integer,(parent."CircuitSnapshot"->'verification'->>'rejected')::integer) OR NEW."ID_ResultatVerificationFk" IS NULL THEN RAISE EXCEPTION 'Résultat absent du circuit du dossier.' USING ERRCODE='23514';END IF;
   IF nullif(btrim(NEW."CommentaireVerification"),'') IS NULL THEN RAISE EXCEPTION 'Commentaire de vérification obligatoire.' USING ERRCODE='23514';END IF;
   NEW."ID_VerifieParFk":=actor;NEW."DateVerification":=clock_timestamp();
  END IF;
 ELSE
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Le rattachement documentaire est immuable.' USING ERRCODE='23514';END IF;
  IF state='closed' THEN RAISE EXCEPTION 'Rouvrez le dossier avant ajout de preuve.' USING ERRCODE='23514';END IF;
  SELECT * INTO piece FROM logistique."T_PieceJustificative" WHERE "ID_Piece"=NEW."ID_PieceFk";
  IF piece."TypeObjet" IS DISTINCT FROM 'support' OR piece."ID_Objet" IS DISTINCT FROM NEW."ID_SupportFk" OR piece."IdEntiteFk" IS DISTINCT FROM parent."IdEntiteFk" THEN RAISE EXCEPTION 'Preuve liée à un autre dossier ou une autre entreprise.' USING ERRCODE='23514';END IF;
  IF NEW."ID_CommentaireSupportFk" IS NOT NULL AND NOT EXISTS(SELECT FROM support."T_CommentaireSupport" WHERE "ID_CommentaireSupport"=NEW."ID_CommentaireSupportFk" AND "ID_SupportFk"=parent."ID_Support" AND ("Visibilite"='public' OR NEW."Visibilite"='interne')) THEN RAISE EXCEPTION 'Commentaire de preuve incompatible avec le dossier ou sa visibilité.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION support.tr_enfant_support_verifier() IS 'Verrouille le parent puis valide les échanges, les tentatives successives et les liaisons documentaires ; aucune confusion entre identifiant de tiers et compte, aucune preuve interentreprise, vérification par un auteur distinct.';

CREATE FUNCTION support.tr_support_audit() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE before_data jsonb;after_data jsonb:=to_jsonb(NEW);ctx jsonb;parent_id bigint;entity_id integer;actor integer:=systeme.fn_admin_actor_user_id();
BEGIN
 IF TG_OP='UPDATE' THEN before_data:=to_jsonb(OLD);END IF;
 BEGIN ctx:=coalesce(nullif(current_setting('support.mutation',true),'')::jsonb,'{}'::jsonb);EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Contexte d’audit invalide.' USING ERRCODE='23514';END;
 IF ctx<>'{}'::jsonb AND (coalesce(ctx->>'requestId','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR coalesce(ctx->>'payloadHash','') !~ '^[a-f0-9]{64}$' OR length(coalesce(ctx->>'motif',''))>2000) THEN RAISE EXCEPTION 'Preuve de requête invalide.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_Support' THEN parent_id:=NEW."ID_Support";entity_id:=NEW."IdEntiteFk";
 ELSE parent_id:=NEW."ID_SupportFk";SELECT "IdEntiteFk" INTO entity_id FROM support."T_Support" WHERE "ID_Support"=parent_id;END IF;
 after_data:=systeme.fn_audit_sans_secrets(after_data)||jsonb_build_object('_actor',jsonb_build_object('IdUser',actor),'ID_SupportFk',parent_id,'requestId',ctx->>'requestId','payloadHash',ctx->>'payloadHash','operation',coalesce(ctx->>'operation',lower(TG_OP)),'_motif',ctx->>'motif');
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk") VALUES('support.'||TG_TABLE_NAME,coalesce(ctx->>'operation',TG_OP),systeme.fn_audit_sans_secrets(before_data),after_data,CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa',entity_id);
 RETURN NULL;
END $$;
COMMENT ON FUNCTION support.tr_support_audit() IS 'Réutilise le journal système pour une image par écriture métier, acteur, entreprise, motif et preuve UUID/hash, dans la même transaction ; aucun contenu binaire n’est dupliqué.';

CREATE TRIGGER a_support_verifier BEFORE INSERT OR UPDATE OR DELETE ON support."T_Support" FOR EACH ROW EXECUTE FUNCTION support.tr_support_verifier();
CREATE TRIGGER z_support_audit AFTER INSERT OR UPDATE ON support."T_Support" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();
CREATE TRIGGER a_commentaire_verifier BEFORE INSERT OR UPDATE OR DELETE ON support."T_CommentaireSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_enfant_support_verifier();
CREATE TRIGGER z_commentaire_audit AFTER INSERT OR UPDATE ON support."T_CommentaireSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();
CREATE TRIGGER a_resolution_verifier BEFORE INSERT OR UPDATE OR DELETE ON support."T_ResolutionSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_enfant_support_verifier();
CREATE TRIGGER z_resolution_audit AFTER INSERT OR UPDATE ON support."T_ResolutionSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();
CREATE TRIGGER a_piece_support_verifier BEFORE INSERT OR UPDATE OR DELETE ON support."T_PieceSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_enfant_support_verifier();
CREATE TRIGGER z_piece_support_audit AFTER INSERT OR UPDATE ON support."T_PieceSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();
CREATE TRIGGER support_circuit_valider BEFORE INSERT OR UPDATE ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.tr_support_circuit_valider();

-- Extension du stockage existant, sans déplacer ni réécrire ses fichiers.
ALTER TABLE logistique."T_PieceJustificative" DROP CONSTRAINT "T_PieceJustificative_TypeObjet_check";
ALTER TABLE logistique."T_PieceJustificative" ADD CONSTRAINT "T_PieceJustificative_TypeObjet_check" CHECK("TypeObjet" IN('bon','facture','reglement','avoir','support'));
CREATE OR REPLACE FUNCTION logistique.fn_entite_document(kind text,object_id bigint) RETURNS integer LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE result integer;
BEGIN
 IF kind='bon' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Commande" WHERE "ID_Commande"=object_id;
 ELSIF kind='facture' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Facture" WHERE "ID_CommandeFk"=object_id;
 ELSIF kind='reglement' THEN SELECT c."IdEntiteFk" INTO result FROM logistique."T_Reglements" p JOIN logistique."T_Commande" c ON c."CodeFacture"=p."CodeFactureFk" WHERE p."ID_Reglement"=object_id;
 ELSIF kind='avoir' AND to_regclass('logistique."T_Avoir"') IS NOT NULL THEN EXECUTE 'SELECT "IdEntiteFk" FROM logistique."T_Avoir" WHERE "ID_Avoir"=$1' INTO result USING object_id;
 ELSIF kind='support' THEN SELECT "IdEntiteFk" INTO result FROM support."T_Support" WHERE "ID_Support"=object_id;
 END IF;RETURN result;
END $$;
COMMENT ON FUNCTION logistique.fn_entite_document(text,bigint) IS 'Résout les propriétaires des documents autorisés, y compris Support ; stockage binaire privé existant réutilisé avec liaison FK contrôlée.';

CREATE VIEW support."V_Support" AS
 SELECT s.*,e."NomEntite",e."NomEntite" AS "Entreprise",d."Nom" AS "Demandeur",concat_ws(' ',u."PrenomUser",u."NomUser") AS "Createur",nullif(concat_ws(' ',r."PrenomUser",r."NomUser"),'') AS "Responsable",
  typ."NomGenerique" AS "TypeSupport",cat."NomGenerique" AS "CategorieSupport",pri."NomGenerique" AS "Priorite",sta."NomGenerique" AS "Statut",can."NomGenerique" AS "CanalOrigine",ser."NomGenerique" AS "ServiceConcerne",
  support.fn_etat_support(s."CircuitSnapshot",s."ID_StatutFk") AS "StatutCode",
  (NOT s."Archive" AND support.fn_etat_support(s."CircuitSnapshot",s."ID_StatutFk") NOT IN('resolved','closed')) AS "Ouvert",
  (NOT s."Archive" AND support.fn_etat_support(s."CircuitSnapshot",s."ID_StatutFk") NOT IN('resolved','closed') AND s."DateEcheance"<clock_timestamp()) AS "EnRetard",
  i."CodeImmobilisation",i."NomImmobilisation",c."CodeCmd",a."NomArticle",i."NomImmobilisation" AS "Immobilisation",c."CodeCmd" AS "BonStock",a."NomArticle" AS "Article",
  (SELECT count(*) FROM support."T_CommentaireSupport" x WHERE x."ID_SupportFk"=s."ID_Support") AS "NbCommentaires",
  (SELECT count(*) FROM support."T_ResolutionSupport" x WHERE x."ID_SupportFk"=s."ID_Support") AS "NbResolutions",
  (SELECT count(*) FROM support."T_PieceSupport" x JOIN logistique."T_PieceJustificative" p ON p."ID_Piece"=x."ID_PieceFk" WHERE x."ID_SupportFk"=s."ID_Support" AND NOT p."Archive") AS "NbDocuments"
 FROM support."T_Support" s JOIN systeme."T_Entite" e ON e."IdEntite"=s."IdEntiteFk"
 LEFT JOIN logistique."T_Client" d ON d."ID_Client"=s."ID_DemandeurFk"
 JOIN systeme."T_Utilisateurs" u ON u."IdUser"=s."ID_CreateurFk" LEFT JOIN systeme."T_Utilisateurs" r ON r."IdUser"=s."ID_ResponsableFk"
 JOIN referentiel."T_Generique" typ ON typ."ID_Generique"=s."ID_TypeSupportFk" LEFT JOIN referentiel."T_Generique" cat ON cat."ID_Generique"=s."ID_CategorieSupportFk"
 JOIN referentiel."T_Generique" pri ON pri."ID_Generique"=s."ID_PrioriteFk" JOIN referentiel."T_Generique" sta ON sta."ID_Generique"=s."ID_StatutFk"
 JOIN referentiel."T_Generique" can ON can."ID_Generique"=s."ID_CanalOrigineFk" LEFT JOIN referentiel."T_Generique" ser ON ser."ID_Generique"=s."ID_ServiceConcerneFk"
 LEFT JOIN logistique."T_Immobilisation" i ON i."ID_Immobilisation"=s."ID_ImmobilisationFk" LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=s."ID_CommandeFk" LEFT JOIN logistique."T_Article" a ON a."ID_Article"=s."ID_ArticleFk";
COMMENT ON VIEW support."V_Support" IS 'Une ligne par dossier avec labels de référence courants, rôles du circuit capturé, entreprise durable et indicateurs exacts ; le service applique le périmètre utilisateur et la visibilité des échanges.';
CREATE VIEW support."V_CommentaireSupport" AS SELECT x.*,s."IdEntiteFk",concat_ws(' ',u."PrenomUser",u."NomUser") AS "Auteur" FROM support."T_CommentaireSupport" x JOIN support."T_Support" s ON s."ID_Support"=x."ID_SupportFk" JOIN systeme."T_Utilisateurs" u ON u."IdUser"=x."ID_AuteurFk";
COMMENT ON VIEW support."V_CommentaireSupport" IS 'Échanges du dossier avec auteur et propriétaire, sans octets documentaires ; le filtre de visibilité interne reste obligatoire avant réponse API.';
CREATE VIEW support."V_ResolutionSupport" AS SELECT x.*,s."IdEntiteFk",concat_ws(' ',u."PrenomUser",u."NomUser") AS "ProposePar",nullif(concat_ws(' ',v."PrenomUser",v."NomUser"),'') AS "VerifiePar",g."NomGenerique" AS "ResultatVerification" FROM support."T_ResolutionSupport" x JOIN support."T_Support" s ON s."ID_Support"=x."ID_SupportFk" JOIN systeme."T_Utilisateurs" u ON u."IdUser"=x."ID_ProposeParFk" LEFT JOIN systeme."T_Utilisateurs" v ON v."IdUser"=x."ID_VerifieParFk" LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=x."ID_ResultatVerificationFk";
COMMENT ON VIEW support."V_ResolutionSupport" IS 'Toutes les tentatives successives et leurs vérifications, distinctes du statut courant du dossier.';
CREATE VIEW support."V_PieceSupport" AS SELECT x.*,s."IdEntiteFk",p."ID_UserFk",p."NomFichier",p."MimeType",p."TailleOctets",p."Sha256",p."Archive",p."CreeLe" FROM support."T_PieceSupport" x JOIN support."T_Support" s ON s."ID_Support"=x."ID_SupportFk" JOIN logistique."T_PieceJustificative" p ON p."ID_Piece"=x."ID_PieceFk";
COMMENT ON VIEW support."V_PieceSupport" IS 'Métadonnées de preuves liées par vraie FK, sans contenu binaire ; téléchargement autorisé via le parent et le niveau de visibilité.';

CREATE INDEX ix_support_entite_statut ON support."T_Support"("IdEntiteFk","Archive","ID_StatutFk","DateCreation" DESC);
CREATE INDEX ix_support_responsable ON support."T_Support"("IdEntiteFk","ID_ResponsableFk");
CREATE INDEX ix_support_echeance ON support."T_Support"("IdEntiteFk","DateEcheance") WHERE NOT "Archive";
CREATE INDEX ix_support_commentaire_parent ON support."T_CommentaireSupport"("ID_SupportFk","ID_CommentaireSupport");
CREATE INDEX ix_support_resolution_parent ON support."T_ResolutionSupport"("ID_SupportFk","ID_ResolutionSupport" DESC);
CREATE INDEX ix_support_piece_parent ON support."T_PieceSupport"("ID_SupportFk");
CREATE UNIQUE INDEX ix_support_audit_rejeu ON systeme."T_Audit_Log"("TableName",("NewData"->>'requestId'),("NewData"->'_actor'->>'IdUser'),"IdEntiteFk") WHERE "TableName" LIKE 'support.%' AND "NewData"->>'requestId' IS NOT NULL;

-- Protection dans les deux sens : on ne déplace pas après coup les objets liés.
CREATE FUNCTION support.tr_lien_proprietaire_conserver() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE old_id bigint;col text;
BEGIN
 IF NEW."IdEntiteFk" IS NOT DISTINCT FROM OLD."IdEntiteFk" THEN RETURN NEW;END IF;
 CASE TG_TABLE_NAME
 WHEN 'T_Client' THEN old_id:=OLD."ID_Client";col:='ID_DemandeurFk';
 WHEN 'T_Immobilisation' THEN old_id:=OLD."ID_Immobilisation";col:='ID_ImmobilisationFk';
 WHEN 'T_Commande' THEN old_id:=OLD."ID_Commande";col:='ID_CommandeFk';
 WHEN 'T_Article' THEN old_id:=OLD."ID_Article";col:='ID_ArticleFk';
 WHEN 'T_Utilisateurs' THEN
  IF EXISTS(SELECT FROM support."T_Support" WHERE "ID_ResponsableFk"=OLD."IdUser") THEN RAISE EXCEPTION 'Utilisateur affecté à un dossier Support ; entreprise conservée.' USING ERRCODE='23514';END IF;RETURN NEW;
 ELSE RAISE EXCEPTION 'Lien métier non pris en charge.';
 END CASE;
 IF EXISTS(SELECT FROM support."T_Support" s WHERE (to_jsonb(s)->>col)::bigint=old_id) THEN RAISE EXCEPTION 'Objet lié à un dossier Support ; entreprise conservée.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION support.tr_lien_proprietaire_conserver() IS 'Empêche le déplacement interentreprise d’un tiers, article, bon, matériel ou affectataire déjà lié à un dossier, actif ou archivé ; complète les contrôles lors du rattachement.';
CREATE TRIGGER support_client_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON logistique."T_Client" FOR EACH ROW EXECUTE FUNCTION support.tr_lien_proprietaire_conserver();
CREATE TRIGGER support_materiel_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON logistique."T_Immobilisation" FOR EACH ROW EXECUTE FUNCTION support.tr_lien_proprietaire_conserver();
CREATE TRIGGER support_bon_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION support.tr_lien_proprietaire_conserver();
CREATE TRIGGER support_article_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION support.tr_lien_proprietaire_conserver();
CREATE TRIGGER support_user_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION support.tr_lien_proprietaire_conserver();

CREATE FUNCTION support.tr_piece_liaison_complete() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW."TypeObjet"='support' AND EXISTS(SELECT FROM logistique."T_PieceJustificative" WHERE "ID_Piece"=NEW."ID_Piece") AND NOT EXISTS(SELECT FROM support."T_PieceSupport" WHERE "ID_PieceFk"=NEW."ID_Piece" AND "ID_SupportFk"=NEW."ID_Objet") THEN RAISE EXCEPTION 'Une preuve Support exige sa liaison métier dans la même transaction.' USING ERRCODE='23514';END IF;
 RETURN NULL;
END $$;
COMMENT ON FUNCTION support.tr_piece_liaison_complete() IS 'Contrainte différée : un fichier Support du stockage commun possède sa liaison FK de dossier avant commit ; aucune preuve orpheline publiée.';
CREATE CONSTRAINT TRIGGER support_piece_liaison AFTER INSERT OR UPDATE ON logistique."T_PieceJustificative" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION support.tr_piece_liaison_complete();

-- Catalogue du module et du tableau commun : aucun droit ou abonnement ajouté implicitement.
INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom","EstSocle","Actif","Ordre") VALUES('support','Support',false,true,95) ON CONFLICT("CodeModule") DO NOTHING;
ALTER TABLE referentiel."T_InterfaceTableau" DROP CONSTRAINT ck_interface_tableau_module;
ALTER TABLE referentiel."T_InterfaceTableau" ADD CONSTRAINT ck_interface_tableau_module CHECK("Module" IN('logistique','referentiels','administration','territoires','support'));
DO $catalogue$
DECLARE columns jsonb;item record;position integer:=0;
BEGIN
 columns:='[]';
 FOR item IN SELECT * FROM (VALUES
 ('NumeroSupport','N° dossier','text',true),('Objet','Objet','text',true),('Demandeur','Demandeur','text',true),('Responsable','Responsable','text',true),('Priorite','Priorité','text',true),('Statut','Statut','text',true),('DateCreation','Créé le','timestamp with time zone',true),('DateEcheance','Échéance','timestamp with time zone',true),('TypeSupport','Type','text',false),('CategorieSupport','Catégorie','text',false),('Entreprise','Entreprise','text',false),('ServiceConcerne','Service','text',false),('CanalOrigine','Canal','text',false),('DateModification','Modifié le','timestamp with time zone',false),('DateResolution','Résolu le','timestamp with time zone',false),('DateCloture','Clôturé le','timestamp with time zone',false),('actions','Actions','text',true)) AS c(id,label,type,visible)
 LOOP
  position:=position+1;columns:=columns||jsonb_build_array(jsonb_build_object('id',item.id,'label',item.label,'type',item.type,'defaultVisible',item.visible,'defaultOrder',position,'defaultExport',item.visible AND item.id<>'actions','exportable',item.id<>'actions','tableAvailable',true,'align','left'));
 END LOOP;
 INSERT INTO referentiel."T_InterfaceTableau"("CleInterface","Module","Colonnes") VALUES('support.tickets','support',columns) ON CONFLICT("CleInterface") DO NOTHING;
END $catalogue$;

-- Commentaires de toutes colonnes, y compris projections : utiles et indépendants du code.
DO $comments$
DECLARE r record;descr text;
BEGIN
 FOR r IN SELECT c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid WHERE n.nspname='support' AND c.relkind IN('r','v') AND a.attnum>0 AND NOT a.attisdropped LOOP
  descr:=CASE r.attname
   WHEN 'IdEntiteFk' THEN 'Entreprise propriétaire durable, indépendante du rattachement actuel du créateur.'
   WHEN 'NumeroSupport' THEN 'Numéro court SUP-identifiant attribué par PostgreSQL ; unique dans son entreprise et non modifiable.'
   WHEN 'ID_DemandeurFk' THEN 'Tiers de T_Client dans la même entreprise ; peut ne pas disposer de compte connecté.'
   WHEN 'ID_CreateurFk' THEN 'Compte actif ayant réellement créé le dossier ; identité attribuée depuis le contexte transactionnel validé.'
   WHEN 'ID_ResponsableFk' THEN 'Compte actif affectataire de la même entreprise ou administrateur de plateforme ; requis pour traiter le dossier.'
   WHEN 'CircuitSnapshot' THEN 'Copie immuable du circuit système et de sa version à la création, avec les ID_Generique des états et résultats ; une modification de configuration ne migre aucun dossier.'
   WHEN 'VersionEnregistrement' THEN 'Révision positive augmentée atomiquement à chaque écriture ; le service compare la version reçue sous verrou avant modification.'
   WHEN 'ID_StatutFk' THEN 'ID_Generique de l’état courant dans le circuit initial du dossier, distinct de son libellé modifiable.'
   WHEN 'Visibilite' THEN 'public : lecteurs autorisés du dossier ; interne : gestionnaires habilités uniquement, jamais un partage Internet.'
   WHEN 'ID_PieceFk' THEN 'Vraie FK vers le stockage binaire privé existant logistique.T_PieceJustificative ; aucun octet dupliqué.'
   WHEN 'ID_CommentaireSupportFk' THEN 'Commentaire facultatif appartenant au même dossier ; une preuve interne ne devient pas publique.'
   WHEN 'ID_ResultatVerificationFk' THEN 'Résultat dans T_Generique, parmi ceux capturés dans le circuit ; NULL tant que la solution n’est pas vérifiée.'
   WHEN 'ID_VerifieParFk' THEN 'Personne habilitée ayant vérifié la dernière solution, obligatoirement différente de son auteur.'
   WHEN 'ID_ProposeParFk' THEN 'Auteur réel de cette tentative de résolution ; les tentatives antérieures restent conservées.'
   WHEN 'DateResolution' THEN 'Instant effectif de passage à Résolu ; remise à NULL après réouverture, valeur antérieure conservée dans l’audit.'
   WHEN 'DateCloture' THEN 'Instant de clôture après vérification conforme de la dernière solution ; NULL pendant un traitement rouvert.'
   WHEN 'StatutCode' THEN 'Rôle du statut dans le circuit capturé : new, active, pending, resolved ou closed ; les libellés proviennent du référentiel.'
   WHEN 'EnRetard' THEN 'Dossier non archivé toujours ouvert avec échéance passée ; critère partagé par indicateur et liste.'
   WHEN 'Ouvert' THEN 'Dossier non archivé non résolu et non clôturé ; inclut les états Nouveau, En cours et En attente.'
   WHEN 'Archive' THEN 'Retrait du parcours actif sans suppression du dossier, de ses échanges, résolutions et preuves.'
   WHEN 'ID_ImmobilisationFk' THEN 'Matériel facultatif lié par FK réelle, propriétaire vérifié ; aucune opération de stock.'
   WHEN 'ID_CommandeFk' THEN 'Bon facultatif lié par FK réelle et limité à la même entreprise.'
   WHEN 'ID_ArticleFk' THEN 'Article facultatif lié par FK réelle et limité à la même entreprise.'
   ELSE 'Donnée Support '||r.attname||' : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.' END;
  EXECUTE format('COMMENT ON COLUMN support.%I.%I IS %L',r.relname,r.attname,descr);
 END LOOP;
 FOR r IN SELECT n.nspname,c.relname,t.tgname FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND (n.nspname='support' OR t.tgname LIKE 'support_%') LOOP
  EXECUTE format('COMMENT ON TRIGGER %I ON %I.%I IS %L',r.tgname,r.nspname,r.relname,'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.');
 END LOOP;
 FOR r IN SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='i' AND ((n.nspname='support') OR (n.nspname='systeme' AND c.relname='ix_support_audit_rejeu')) LOOP EXECUTE format('COMMENT ON INDEX %I.%I IS %L',r.nspname,r.relname,'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.');END LOOP;
END $comments$;
COMMENT ON TABLE logistique."T_PieceJustificative" IS 'Stockage privé des justificatifs métier, partagé avec Support via une liaison FK dédiée ; téléchargement après contrôle du parent, entreprise et visibilité, contenu conservé après archivage.';
COMMENT ON COLUMN logistique."T_PieceJustificative"."TypeObjet" IS 'Type métier fermé du parent, dont support ; le dossier Support possède en plus une liaison réelle à clés étrangères.';
COMMENT ON CONSTRAINT "T_PieceJustificative_TypeObjet_check" ON logistique."T_PieceJustificative" IS 'Types explicitement autorisés dans le stockage privé commun, dont support ; le parent et la liaison métier sont contrôlés séparément.';
COMMENT ON CONSTRAINT ck_interface_tableau_module ON referentiel."T_InterfaceTableau" IS 'Modules possédant un catalogue de tableau et export, incluant Support sans accorder un accès ou une licence.';
COMMIT;
