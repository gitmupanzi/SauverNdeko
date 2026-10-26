-- Contrôles communs des réglages d'administration ; aucune reprise de valeurs.
-- Appliquer après sauvegarde, backend compatible arrêté ou en maintenance.
-- L'auteur est fourni par SET LOCAL systeme.actor_user_id dans la transaction.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';

DO $$
BEGIN
 IF current_setting('server_version_num')::integer < 150000 THEN
  RAISE EXCEPTION 'PostgreSQL 15 minimum pour UNIQUE NULLS NOT DISTINCT';
 END IF;
 IF to_regclass('systeme."T_Admin_UI_Setting"') IS NULL OR
    to_regclass('systeme."T_Fk_Correspondance"') IS NULL THEN
  RAISE EXCEPTION 'Tables de réglages attendues absentes';
 END IF;
 IF EXISTS (
  SELECT 1 FROM pg_trigger t JOIN pg_proc p ON p.oid=t.tgfoid
  WHERE t.tgrelid IN ('systeme."T_Admin_UI_Setting"'::regclass,
                     'systeme."T_Fk_Correspondance"'::regclass)
    AND NOT t.tgisinternal AND p.proname IN ('audit_log_function','fn_admin_reglage_audit')
 ) THEN
  RAISE EXCEPTION 'Un audit SQL des réglages existe déjà : contrôler avant application';
 END IF;
END $$;

LOCK TABLE systeme."T_Admin_UI_Setting", systeme."T_Fk_Correspondance"
 IN ACCESS EXCLUSIVE MODE;

-- La création des contraintes refuse les doublons, elle ne les efface jamais.
ALTER TABLE systeme."T_Admin_UI_Setting"
 DROP CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope",
 ADD CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" UNIQUE NULLS NOT DISTINCT
  ("SettingScope","ScopeValue","SettingKey"),
 ADD CONSTRAINT "Ck_Admin_UI_Setting_ScopeValue" CHECK (
  ("SettingScope"='global' AND "ScopeValue" IS NULL) OR
  ("SettingScope"<>'global' AND nullif(btrim("ScopeValue"),'') IS NOT NULL));
ALTER TABLE systeme."T_Fk_Correspondance"
 DROP CONSTRAINT "UQ_FkCorrespondance_SourceValueScope",
 ADD CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" UNIQUE NULLS NOT DISTINCT
  ("ModuleName","SchemaName","ViewName","SourceKey","FieldName","MappingType",
   "MappingValue","SettingScope","ScopeValue"),
 ADD CONSTRAINT "Ck_FkCorrespondance_ScopeValue" CHECK (
  ("SettingScope"='global' AND "ScopeValue" IS NULL) OR
  ("SettingScope"<>'global' AND nullif(btrim("ScopeValue"),'') IS NOT NULL));

CREATE FUNCTION systeme.fn_admin_cle_sensible(p_cle text)
RETURNS boolean LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
 SELECT CASE WHEN p_cle IS NULL THEN false ELSE
  regexp_replace(lower(p_cle),'[^a-z0-9]','','g') ~
  '(password|motdepasse|privatekey|apikey|accesstoken|refreshtoken|idtoken|secret$)'
  OR regexp_replace(lower(p_cle),'[^a-z0-9]','','g') IN
   ('token','authorization','credential','credentials') END;
$$;

CREATE OR REPLACE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $$
DECLARE v_type text; v_result jsonb; v_key text; v_value jsonb;
        v_setting_secret boolean:=false; v_decoded jsonb; v_string text;
BEGIN
 IF p_data IS NULL THEN RETURN NULL; END IF;
 v_type:=jsonb_typeof(p_data);
 IF v_type='object' THEN
  SELECT coalesce(bool_or(systeme.fn_admin_cle_sensible(value #>> '{}')),false)
   INTO v_setting_secret FROM jsonb_each(p_data)
   WHERE regexp_replace(lower(key),'[^a-z0-9]','','g')='settingkey';
  v_result:='{}'::jsonb;
  FOR v_key,v_value IN SELECT key,value FROM jsonb_each(p_data) LOOP
   IF systeme.fn_admin_cle_sensible(v_key) THEN CONTINUE; END IF;
   IF v_setting_secret AND regexp_replace(lower(v_key),'[^a-z0-9]','','g')
      IN ('settingvalue','settingvaluejson') THEN
    v_result:=v_result||jsonb_build_object(v_key,'[Masqué]');
   ELSE
    v_result:=v_result||jsonb_build_object(v_key,systeme.fn_audit_sans_secrets(v_value));
   END IF;
  END LOOP;
  RETURN v_result;
 ELSIF v_type='array' THEN
  SELECT coalesce(jsonb_agg(systeme.fn_audit_sans_secrets(value) ORDER BY ord),'[]'::jsonb)
   INTO v_result FROM jsonb_array_elements(p_data) WITH ORDINALITY AS a(value,ord);
  RETURN v_result;
 ELSIF v_type='string' THEN
  -- Les anciennes images JSON parfois doublement encodées restent nettoyables.
  v_string:=btrim(p_data #>> '{}');
  IF left(v_string,1) IN ('{','[') THEN
   BEGIN v_decoded:=v_string::jsonb;
   EXCEPTION WHEN invalid_text_representation THEN RETURN p_data; END;
   RETURN systeme.fn_audit_sans_secrets(v_decoded);
  END IF;
 END IF;
 RETURN p_data;
END $$;

CREATE FUNCTION systeme.fn_admin_actor_user_id()
RETURNS integer LANGUAGE plpgsql STABLE AS $$
DECLARE v_raw text:=nullif(current_setting('systeme.actor_user_id',true),''); v_id integer;
BEGIN
 IF v_raw IS NULL OR v_raw !~ '^[1-9][0-9]{0,9}$' THEN RETURN NULL; END IF;
 BEGIN v_id:=v_raw::integer;
 EXCEPTION WHEN numeric_value_out_of_range THEN RETURN NULL; END;
 IF EXISTS (SELECT 1 FROM systeme."T_Utilisateurs"
            WHERE "IdUser"=v_id AND "ValideUser" IS TRUE) THEN RETURN v_id; END IF;
 RETURN NULL;
END $$;

CREATE FUNCTION systeme.fn_admin_ui_setting_proteger()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD."IsEditable" IS NOT TRUE OR OLD."IsSystem" IS TRUE THEN
   RAISE EXCEPTION 'Ce paramètre ne peut pas être supprimé' USING ERRCODE='23514';
  END IF;
  RETURN OLD;
 END IF;
 IF OLD."IsEditable" IS NOT TRUE AND
  (to_jsonb(NEW)-ARRAY['UpdatedAt','UpdatedByUserFk']) IS DISTINCT FROM
  (to_jsonb(OLD)-ARRAY['UpdatedAt','UpdatedByUserFk']) THEN
  RAISE EXCEPTION 'Ce paramètre est protégé contre les modifications' USING ERRCODE='23514';
 END IF;
 IF OLD."IsSystem" IS TRUE AND
  ROW(NEW."IdAdminUISetting",NEW."SettingKey",NEW."SettingType",NEW."SettingScope",
      NEW."ScopeValue",NEW."IsEditable",NEW."IsSystem",NEW."CreatedAt") IS DISTINCT FROM
  ROW(OLD."IdAdminUISetting",OLD."SettingKey",OLD."SettingType",OLD."SettingScope",
      OLD."ScopeValue",OLD."IsEditable",OLD."IsSystem",OLD."CreatedAt") THEN
  RAISE EXCEPTION 'Identité et protections du paramètre système immuables' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION systeme.fn_admin_ui_setting_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 NEW."UpdatedAt":=CURRENT_TIMESTAMP;
 NEW."UpdatedByUserFk":=systeme.fn_admin_actor_user_id();
 IF TG_OP='INSERT' THEN NEW."CreatedAt":=CURRENT_TIMESTAMP;
 ELSE NEW."CreatedAt":=OLD."CreatedAt"; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER tr_admin_ui_setting_set_updated_at ON systeme."T_Admin_UI_Setting";
CREATE TRIGGER tr_admin_ui_setting_proteger BEFORE UPDATE OR DELETE
 ON systeme."T_Admin_UI_Setting" FOR EACH ROW
 EXECUTE FUNCTION systeme.fn_admin_ui_setting_proteger();
CREATE TRIGGER tr_admin_ui_setting_set_updated_at BEFORE INSERT OR UPDATE
 ON systeme."T_Admin_UI_Setting" FOR EACH ROW
 EXECUTE FUNCTION systeme.fn_admin_ui_setting_set_updated_at();

CREATE FUNCTION systeme.fn_fk_correspondance_actualiser()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 -- Le type existant reste timestamp sans fuseau ; heure civile métier de Kinshasa.
 NEW."UpdatedAt":=CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa';
 NEW."UpdatedByUserFk":=systeme.fn_admin_actor_user_id();
 RETURN NEW;
END $$;
CREATE TRIGGER tr_fk_correspondance_actualiser BEFORE INSERT OR UPDATE
 ON systeme."T_Fk_Correspondance" FOR EACH ROW
 EXECUTE FUNCTION systeme.fn_fk_correspondance_actualiser();

CREATE FUNCTION systeme.fn_admin_reglage_audit()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_before jsonb; v_after jsonb; v_actor integer:=systeme.fn_admin_actor_user_id();
        v_identity jsonb:=jsonb_build_object('IdUser',NULL,'NomComplet',NULL);
        v_scope text; v_scope_value text; v_entity integer;
BEGIN
 IF v_actor IS NOT NULL THEN
  SELECT jsonb_build_object('IdUser',"IdUser",'NomComplet',
         concat_ws(' ',"PrenomUser","NomUser")) INTO v_identity
   FROM systeme."T_Utilisateurs" WHERE "IdUser"=v_actor;
 END IF;
 IF TG_OP IN ('DELETE','UPDATE') THEN
  v_before:=systeme.fn_audit_sans_secrets(to_jsonb(OLD));
  IF v_identity IS NOT NULL THEN v_before:=v_before||jsonb_build_object('_actor',v_identity); END IF;
 END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN
  v_after:=systeme.fn_audit_sans_secrets(to_jsonb(NEW));
  IF v_identity IS NOT NULL THEN v_after:=v_after||jsonb_build_object('_actor',v_identity); END IF;
 END IF;
 v_scope:=coalesce(v_after->>'SettingScope',v_before->>'SettingScope');
 v_scope_value:=coalesce(v_after->>'ScopeValue',v_before->>'ScopeValue');
 IF v_scope IN ('entity','entite') AND v_scope_value ~ '^[1-9][0-9]{0,9}$' THEN
  BEGIN v_entity:=v_scope_value::integer;
  EXCEPTION WHEN numeric_value_out_of_range THEN v_entity:=NULL; END;
  IF NOT EXISTS(SELECT 1 FROM systeme."T_Entite" WHERE "IdEntite"=v_entity) THEN v_entity:=NULL; END IF;
 END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk")
 VALUES(TG_TABLE_NAME,TG_OP,v_before,v_after,CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa',v_entity);
 RETURN NULL;
END $$;
CREATE TRIGGER tr_admin_ui_setting_audit AFTER INSERT OR UPDATE OR DELETE
 ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_reglage_audit();
CREATE TRIGGER tr_fk_correspondance_audit AFTER INSERT OR UPDATE OR DELETE
 ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_reglage_audit();

-- Les vues acceptent les images de lignes SQL PascalCase et le camelCase historique.
CREATE OR REPLACE VIEW systeme."V_Admin_UI_Setting_Audit" AS
 SELECT a."IdLog",a."TableName",a."Operation",a."ChangedAt",
 coalesce(n->>'SettingScope',n->>'settingScope',o->>'SettingScope',o->>'settingScope','global') AS "SettingScope",
 coalesce(n->>'ScopeValue',n->>'scopeValue',o->>'ScopeValue',o->>'scopeValue') AS "ScopeValue",
 coalesce(n->>'SettingKey',n->>'settingKey',o->>'SettingKey',o->>'settingKey') AS "SettingKey",
 coalesce(n->>'SettingLabel',n->>'settingLabel',o->>'SettingLabel',o->>'settingLabel') AS "SettingLabel",
 coalesce(n->>'SettingGroup',n->>'settingGroup',o->>'SettingGroup',o->>'settingGroup') AS "SettingGroup",
 CASE WHEN n IS NOT NULL THEN coalesce(n->>'SettingValue',n->>'settingValue')
      ELSE coalesce(o->>'SettingValue',o->>'settingValue') END AS "SettingValue",
 CASE WHEN coalesce(n,o) ? '_actor' THEN coalesce(n,o)#>>'{_actor,NomComplet}'
      ELSE coalesce(n->>'updatedByName',o->>'updatedByName') END AS "UpdatedByName",
 CASE WHEN coalesce(n,o) ? '_actor' THEN coalesce(n,o)#>>'{_actor,IdUser}'
      ELSE coalesce(n->>'UpdatedByUserFk',n->>'updatedByUserId',o->>'UpdatedByUserFk',o->>'updatedByUserId') END AS "UpdatedByUserId",
 coalesce(n->>'UpdatedAt',n->>'updatedAt',o->>'UpdatedAt',o->>'updatedAt') AS "UpdatedSettingAt",
 o AS "OldData",n AS "NewData"
 FROM systeme."T_Audit_Log" a
 CROSS JOIN LATERAL (SELECT systeme.fn_audit_sans_secrets(a."NewData") AS n,
                           systeme.fn_audit_sans_secrets(a."OldData") AS o) cleaned
 WHERE a."TableName"='T_Admin_UI_Setting' ORDER BY a."ChangedAt" DESC;
CREATE OR REPLACE VIEW systeme."V_Fk_Correspondance_Audit" AS
 SELECT a."IdLog",a."TableName",a."Operation",a."ChangedAt",
 coalesce(n->>'SettingScope',n->>'settingScope',o->>'SettingScope',o->>'settingScope','global') AS "SettingScope",
 coalesce(n->>'ScopeValue',n->>'scopeValue',o->>'ScopeValue',o->>'scopeValue') AS "ScopeValue",
 CASE WHEN coalesce(n,o) ? '_actor' THEN coalesce(n,o)#>>'{_actor,NomComplet}'
      ELSE coalesce(n->>'updatedByName',o->>'updatedByName') END AS "UpdatedByName",
 CASE WHEN coalesce(n,o) ? '_actor' THEN coalesce(n,o)#>>'{_actor,IdUser}'
      ELSE coalesce(n->>'UpdatedByUserFk',n->>'updatedByUserId',o->>'UpdatedByUserFk',o->>'updatedByUserId') END AS "UpdatedByUserId",
 coalesce(n->>'UpdatedAt',n->>'updatedAt',o->>'UpdatedAt',o->>'updatedAt') AS "UpdatedSettingAt",
 o AS "OldData",n AS "NewData"
 FROM systeme."T_Audit_Log" a
 CROSS JOIN LATERAL (SELECT systeme.fn_audit_sans_secrets(a."NewData") AS n,
                           systeme.fn_audit_sans_secrets(a."OldData") AS o) cleaned
 WHERE a."TableName"='T_Fk_Correspondance' ORDER BY a."ChangedAt" DESC;

COMMENT ON TABLE systeme."T_Admin_UI_Setting" IS 'Paramètres partagés par portée et clé ; unicité y compris portée globale NULL, protections SQL et audit des écritures. Un paramètre système éditable conserve la modification de sa valeur.';
COMMENT ON TABLE systeme."T_Fk_Correspondance" IS 'Correspondances de références par source et portée ; unicité y compris contexte NULL, auteur transactionnel et audit SQL.';
COMMENT ON CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" ON systeme."T_Admin_UI_Setting" IS 'Une seule clé par portée et contexte ; NULL global est une valeur unique.';
COMMENT ON CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" ON systeme."T_Fk_Correspondance" IS 'Une seule correspondance logique, même sans vue ou contexte explicite.';
COMMENT ON CONSTRAINT "Ck_Admin_UI_Setting_ScopeValue" ON systeme."T_Admin_UI_Setting" IS 'Contexte NULL pour global ; contexte non vide pour entite, user ou module.';
COMMENT ON CONSTRAINT "Ck_FkCorrespondance_ScopeValue" ON systeme."T_Fk_Correspondance" IS 'Contexte NULL pour global ; contexte non vide pour country ou entity.';
COMMENT ON FUNCTION systeme.fn_admin_cle_sensible(text) IS 'Détecte les noms de mots de passe, jetons et secrets sans dépendre de la casse ni des séparateurs.';
COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(jsonb) IS 'Nettoie récursivement objets, listes et images JSON encodées ; retire les clés secrètes et masque les valeurs des SettingKey sensibles sans réécrire les journaux historiques.';
COMMENT ON FUNCTION systeme.fn_admin_actor_user_id() IS 'Auteur actif existant de la GUC transactionnelle systeme.actor_user_id ; NULL si absence ou valeur invalide. Métadonnée de traçabilité, jamais autorisation SQL.';
COMMENT ON FUNCTION systeme.fn_admin_ui_setting_proteger() IS 'Refuse les modifications d’un paramètre non éditable et la suppression/altération d’identité d’un paramètre système ; sa valeur reste modifiable si IsEditable=true.';
COMMENT ON FUNCTION systeme.fn_admin_ui_setting_set_updated_at() IS 'Horodate et attribue les paramètres à l’auteur transactionnel validé ; conserve CreatedAt après création.';
COMMENT ON FUNCTION systeme.fn_fk_correspondance_actualiser() IS 'Actualise la date civile de Kinshasa et l’auteur transactionnel de chaque correspondance écrite.';
COMMENT ON FUNCTION systeme.fn_admin_reglage_audit() IS 'Un événement SQL par écriture de réglage ou correspondance, avec images nettoyées et auteur de l’opération, y compris suppression.';
COMMENT ON TRIGGER tr_admin_ui_setting_proteger ON systeme."T_Admin_UI_Setting" IS 'Protection des identités système et des paramètres non éditables avant toute mise à jour ou suppression.';
COMMENT ON TRIGGER tr_admin_ui_setting_set_updated_at ON systeme."T_Admin_UI_Setting" IS 'Date et auteur SQL des paramètres ; les champs fournis par le client ne font pas foi.';
COMMENT ON TRIGGER tr_fk_correspondance_actualiser ON systeme."T_Fk_Correspondance" IS 'Date et auteur SQL des correspondances avant insertion ou mise à jour.';
COMMENT ON TRIGGER tr_admin_ui_setting_audit ON systeme."T_Admin_UI_Setting" IS 'Audit SQL unique des paramètres ; le backend ne produit pas un second événement.';
COMMENT ON TRIGGER tr_fk_correspondance_audit ON systeme."T_Fk_Correspondance" IS 'Audit SQL unique des correspondances, compatible avec les remplacements transactionnels du réglage historique.';
COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedAt" IS 'Instant de dernière écriture, imposé par PostgreSQL.';
COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedByUserFk" IS 'Auteur actif validé depuis systeme.actor_user_id ; NULL pour une écriture directe sans acteur applicatif.';
COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedAt" IS 'Dernière écriture en heure civile Africa/Kinshasa, type historique sans fuseau conservé.';
COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedByUserFk" IS 'Auteur actif validé depuis systeme.actor_user_id ; NULL pour une écriture directe sans acteur applicatif.';
COMMENT ON VIEW systeme."V_Admin_UI_Setting_Audit" IS 'Audit nettoyé des paramètres ; une ligne par événement, contexte PascalCase SQL ou camelCase historique et auteur de l’opération.';
COMMENT ON VIEW systeme."V_Fk_Correspondance_Audit" IS 'Audit nettoyé des correspondances ; une ligne par événement, contexte PascalCase SQL ou camelCase historique et auteur de l’opération.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingScope" IS 'Portée extraite de l’image SQL PascalCase ou de l’ancien événement camelCase.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingKey" IS 'Clé du paramètre concerné par l’événement SQL ou historique.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingValue" IS 'Valeur textuelle nettoyée ; [Masqué] lorsque la clé du paramètre est sensible.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."OldData" IS 'Image avant l’écriture, nettoyée récursivement à la lecture sans modifier l’historique stocké.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."NewData" IS 'Image après l’écriture, nettoyée récursivement à la lecture sans modifier l’historique stocké.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."SettingScope" IS 'Portée de correspondance extraite de l’image SQL PascalCase ou historique camelCase.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."OldData" IS 'Image avant l’écriture, nettoyée récursivement ; NULL pour une insertion.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."NewData" IS 'Image après l’écriture, nettoyée récursivement ; NULL pour une suppression.';
COMMIT;
