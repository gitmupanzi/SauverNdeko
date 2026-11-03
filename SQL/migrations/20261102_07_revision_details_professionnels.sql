-- Les détails font partie de la version concurrente de la fiche professionnelle.
-- Aucun profil, référence ou compte n'est créé ni réattribué par cette évolution.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 IF to_regprocedure('professionnel.tr_professionnel_integrite()') IS NULL THEN RAISE EXCEPTION 'Migration professionnelle06 requise.';END IF;
END $$;

CREATE FUNCTION professionnel.tr_detail_professionnel_revision() RETURNS trigger
 LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE profile_id integer;actor_id integer:=nullif(current_setting('professionnel.actor_id',true),'')::integer;
BEGIN
 IF TG_OP='UPDATE' AND to_jsonb(NEW) IS NOT DISTINCT FROM to_jsonb(OLD) THEN RETURN NULL;END IF;
 profile_id:=CASE WHEN TG_OP='DELETE' THEN OLD."IdProfessionnelFk" ELSE NEW."IdProfessionnelFk" END;
 -- La garde BEFORE du détail a déjà verrouillé ce même parent. Un UPDATE
 -- ordinaire réutilise sa garde, sa révision, son horodatage et son audit.
 -- Sans acteur explicite, le dernier auteur devient inconnu plutôt que
 -- d'attribuer le changement au compte affecté ou à un ancien éditeur.
 IF actor_id IS NOT NULL AND NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor_id) THEN actor_id:=NULL;END IF;
 UPDATE professionnel."T_Professionnel" SET "ModifieParUserFk"=actor_id WHERE "IdProfessionnel"=profile_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Fiche professionnelle parente introuvable.' USING ERRCODE='23503';END IF;
 RETURN NULL;
END $$;
COMMENT ON FUNCTION professionnel.tr_detail_professionnel_revision() IS 'Après un véritable ajout, changement ou retrait de détail, touche le parent sous le verrou existant pour incrémenter sa révision SQL et son horodatage/audit. Une mise à jour sans différence ne change pas sa version. Aucun compte ou propriétaire n’est déduit ; auteur NULL en l’absence de contexte explicite. Tout est annulé avec la transaction en cas de rejet.';

DO $$ DECLARE table_name text;BEGIN
 FOREACH table_name IN ARRAY ARRAY['T_Professionnel_Competence','T_Professionnel_Prestation','T_Professionnel_Entite'] LOOP
  EXECUTE format('CREATE TRIGGER zy_detail_professionnel_revision AFTER INSERT OR UPDATE OR DELETE ON professionnel.%I FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_revision()',table_name);
  EXECUTE format('COMMENT ON TRIGGER zy_detail_professionnel_revision ON professionnel.%I IS %L',table_name,'Révision atomique du parent après une mutation réelle de ce détail, avant son audit ; aucune version nouvelle sur un simple UPDATE identique.');
 END LOOP;
END $$;
COMMIT;
