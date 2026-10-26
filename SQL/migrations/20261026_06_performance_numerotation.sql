-- Historique anti-réutilisation indexé ; aucune identité existante ni trace modifiée.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
SET LOCAL search_path=pg_catalog;
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors périmètre'; END IF;
 IF to_regprocedure('logistique.fn_identite_commande_deja_utilisee(integer)') IS NULL THEN RAISE EXCEPTION 'Numérotation 20261025_08 requise';END IF;
 IF to_regprocedure('logistique.fn_identites_audit(jsonb)') IS NOT NULL OR to_regclass('systeme.audit_document_identites_old_gin') IS NOT NULL OR to_regclass('systeme.audit_document_identites_new_gin') IS NOT NULL THEN RAISE EXCEPTION 'Optimisation déjà installée ou installation partielle'; END IF;
END $$;
CREATE FUNCTION logistique.fn_identites_audit(p_document jsonb) RETURNS numeric[]
 LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $$
DECLARE result numeric[]:=ARRAY[]::numeric[]; raw text; digits text; key text; value numeric;
BEGIN
 IF jsonb_typeof(p_document)<>'object' THEN RETURN result;END IF;
 FOREACH key IN ARRAY ARRAY['ID_Commande','ID_CommandeFk','ID_CommandeRetourFk','CodeCmd','CodeFacture'] LOOP
  raw=p_document->>key;
  IF raw IS NULL THEN CONTINUE; END IF;
  IF key='CodeCmd' THEN
   IF raw ~* '^C_[0-9]+$' THEN digits=substr(raw,3);
   ELSIF raw ~* '^cmd-[0-9]+$' THEN digits=substr(raw,5);ELSE CONTINUE; END IF;
  ELSIF key='CodeFacture' THEN
   IF raw ~* '^F_[0-9]+$' THEN digits=substr(raw,3);
   ELSIF raw ~* '^fac-[0-9]+$' THEN digits=substr(raw,5);ELSE CONTINUE; END IF;
  ELSE
   IF raw !~ '^[0-9]+$' THEN CONTINUE; END IF;
   digits=raw;
  END IF;
  digits=ltrim(digits,'0');
  -- Aucun identifiant public integer ne dépasse 10 chiffres. Conserver aussi les
  -- grands nombres historiques usuels sans permettre une clé GIN démesurée.
  IF digits='' OR length(digits)>1000 THEN CONTINUE; END IF;
  value=digits::numeric;
  result=array_append(result,value);
 END LOOP;
 SELECT coalesce(array_agg(DISTINCT x ORDER BY x),ARRAY[]::numeric[]) INTO result FROM unnest(result) x;
 RETURN result;
END $$;
CREATE INDEX audit_document_identites_old_gin ON systeme."T_Audit_Log" USING gin(logistique.fn_identites_audit("OldData")) WHERE "TableName" IN ('logistique.T_Commande','T_Commande','logistique.T_Facture');
CREATE INDEX audit_document_identites_new_gin ON systeme."T_Audit_Log" USING gin(logistique.fn_identites_audit("NewData")) WHERE "TableName" IN ('logistique.T_Commande','T_Commande','logistique.T_Facture');
CREATE OR REPLACE FUNCTION logistique.fn_identite_commande_deja_utilisee(p_id integer) RETURNS boolean LANGUAGE sql STABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT 1 FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_id
  OR c."CodeCmd"=logistique.fn_code_commande(p_id) OR c."CodeFacture"=logistique.fn_code_facture(p_id))
 OR EXISTS(SELECT 1 FROM systeme."T_Audit_Log" a WHERE a."TableName" IN ('logistique.T_Commande','T_Commande','logistique.T_Facture') AND logistique.fn_identites_audit(a."OldData") @> ARRAY[p_id::numeric])
 OR EXISTS(SELECT 1 FROM systeme."T_Audit_Log" a WHERE a."TableName" IN ('logistique.T_Commande','T_Commande','logistique.T_Facture') AND logistique.fn_identites_audit(a."NewData") @> ARRAY[p_id::numeric]);
$$;
COMMENT ON FUNCTION logistique.fn_identites_audit(jsonb) IS 'Extraction immuable indexable des identités top-level ID_Commande/ID_CommandeFk/ID_CommandeRetourFk et codes C_/cmd-/F_/fac-. Normalise les zéros initiaux, déduplique, ignore données non numériques ou non objet ; numeric évite le débordement des anciens grands identifiants. Les chaînes de plus de 1000 chiffres significatifs, impossibles pour une identité integer publique, sont ignorées pour borner la taille GIN.';
COMMENT ON FUNCTION logistique.fn_identite_commande_deja_utilisee(integer) IS 'Détecte les identités/références courantes ou historiques via deux index GIN des audits, anciens formats et zéros initiaux inclus ; aucun parcours intégral par nouveau bon.';
COMMENT ON INDEX systeme.audit_document_identites_old_gin IS 'Identités de bons/factures présentes avant une écriture auditée ; évite regex et parcours complet du journal à chaque réservation.';
COMMENT ON INDEX systeme.audit_document_identites_new_gin IS 'Identités de bons/factures présentes après une écriture auditée ; garde la non-réutilisation après suppression.';
ANALYZE systeme."T_Audit_Log";
COMMIT;
