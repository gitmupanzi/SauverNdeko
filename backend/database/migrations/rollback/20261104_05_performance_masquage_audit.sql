-- Restaure l'implémentation précédente sans modifier les journaux ni leurs droits.
-- Le coût quadratique des très grands objets JSONB réapparaît après ce retour.
BEGIN;
SET LOCAL lock_timeout='10s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('systeme:audit-redaction-installation',0));
END $$;
CREATE OR REPLACE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$
DECLARE v_type text;v_result jsonb;v_key text;v_value jsonb;v_setting_secret boolean:=false;v_decoded jsonb;v_string text;
BEGIN
 IF p_data IS NULL THEN RETURN NULL;END IF;
 v_type:=jsonb_typeof(p_data);
 IF v_type='object' THEN
  SELECT coalesce(bool_or(systeme.fn_admin_cle_sensible(value#>>'{}')),false) INTO v_setting_secret FROM jsonb_each(p_data) WHERE regexp_replace(lower(key),'[^a-z0-9]','','g')='settingkey';
  v_result:='{}'::jsonb;
  FOR v_key,v_value IN SELECT key,value FROM jsonb_each(p_data) LOOP
   IF systeme.fn_admin_cle_sensible(v_key) OR regexp_replace(lower(v_key),'[^a-z0-9]','','g')='logoentite' THEN CONTINUE;END IF;
   IF v_setting_secret AND regexp_replace(lower(v_key),'[^a-z0-9]','','g') IN ('settingvalue','settingvaluejson') THEN v_result:=v_result||jsonb_build_object(v_key,'[Masqué]');
   ELSE v_result:=v_result||jsonb_build_object(v_key,systeme.fn_audit_sans_secrets(v_value));END IF;
  END LOOP;
  RETURN v_result;
 ELSIF v_type='array' THEN
  SELECT coalesce(jsonb_agg(systeme.fn_audit_sans_secrets(value) ORDER BY ord),'[]'::jsonb) INTO v_result FROM jsonb_array_elements(p_data) WITH ORDINALITY AS a(value,ord);RETURN v_result;
 ELSIF v_type='string' THEN
  v_string:=btrim(p_data#>>'{}');
  IF left(v_string,1) IN ('{','[') THEN
   BEGIN v_decoded:=v_string::jsonb;EXCEPTION WHEN invalid_text_representation THEN RETURN p_data;END;
   RETURN systeme.fn_audit_sans_secrets(v_decoded);
  END IF;
 END IF;
 RETURN p_data;
END $$;
COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) IS 'Nettoie récursivement secrets, anciennes images JSON encodées et octets LogoEntite ; conserve les métadonnées de logo comme SHA/MIME/date. N’effectue aucune réécriture des journaux antérieurs.';
COMMIT;
