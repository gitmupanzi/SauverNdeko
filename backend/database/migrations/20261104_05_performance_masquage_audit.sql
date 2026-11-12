-- Masquage des journaux volumineux : agrégation des objets en un seul passage.
-- La fonction conserve son identité, ses droits et toutes ses règles de secret.
-- Aucun journal, aucune preuve et aucune donnée métier n'est réécrit.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 IF to_regprocedure('systeme.fn_audit_sans_secrets(jsonb)') IS NULL
    OR to_regprocedure('systeme.fn_admin_cle_sensible(text)') IS NULL THEN
  RAISE EXCEPTION 'Le socle de masquage des journaux doit être installé avant cette optimisation.';
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('systeme:audit-redaction-installation',0));
END $$;

CREATE OR REPLACE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $$
DECLARE
 v_type text; v_result jsonb; v_setting_secret boolean:=false;
 v_decoded jsonb; v_string text;
BEGIN
 IF p_data IS NULL THEN RETURN NULL;END IF;
 v_type:=jsonb_typeof(p_data);
 IF v_type='object' THEN
  SELECT coalesce(bool_or(systeme.fn_admin_cle_sensible(value#>>'{}')),false)
    INTO v_setting_secret FROM jsonb_each(p_data)
   WHERE regexp_replace(lower(key),'[^a-z0-9]','','g')='settingkey';
  -- Une concaténation JSONB à chaque clé recopierait tout l'objet précédent.
  -- L'agrégat JSON conserve les types, puis un seul cast restitue le JSONB.
  -- jsonb_object_agg réencapsule trop coûteusement les gros objets imbriqués.
  SELECT coalesce(json_object_agg(key,
    CASE WHEN v_setting_secret AND regexp_replace(lower(key),'[^a-z0-9]','','g') IN ('settingvalue','settingvaluejson')
         THEN to_jsonb('[Masqué]'::text)
         WHEN jsonb_typeof(value) IN ('object','array')
           OR (jsonb_typeof(value)='string' AND left(btrim(value#>>'{}'),1) IN ('{','['))
         THEN systeme.fn_audit_sans_secrets(value)
         ELSE value END),'{}'::json)::jsonb
    INTO v_result FROM jsonb_each(p_data)
   WHERE NOT systeme.fn_admin_cle_sensible(key)
     AND regexp_replace(lower(key),'[^a-z0-9]','','g')<>'logoentite';
  RETURN v_result;
 ELSIF v_type='array' THEN
  SELECT coalesce(json_agg(
    CASE WHEN jsonb_typeof(value) IN ('object','array')
           OR (jsonb_typeof(value)='string' AND left(btrim(value#>>'{}'),1) IN ('{','['))
         THEN systeme.fn_audit_sans_secrets(value)
         ELSE value END ORDER BY ord),'[]'::json)::jsonb
    INTO v_result FROM jsonb_array_elements(p_data) WITH ORDINALITY AS a(value,ord);
  RETURN v_result;
 ELSIF v_type='string' THEN
  v_string:=btrim(p_data#>>'{}');
  IF left(v_string,1) IN ('{','[') THEN
   BEGIN v_decoded:=v_string::jsonb;EXCEPTION WHEN invalid_text_representation THEN RETURN p_data;END;
   RETURN systeme.fn_audit_sans_secrets(v_decoded);
  END IF;
 END IF;
 RETURN p_data;
END $$;
COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(jsonb) IS 'Nettoie récursivement secrets, anciennes images JSON encodées et octets LogoEntite ; conserve les métadonnées de logo comme SHA/MIME/date. Agrège objets et listes en JSON structuré puis reconvertit une seule fois en JSONB, sans concaténations quadratiques ni réécriture des journaux antérieurs. Les scalaires ordinaires restent inchangés.';
COMMIT;
