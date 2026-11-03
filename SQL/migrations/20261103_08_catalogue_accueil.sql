-- Le catalogue devient l'accueil, distinct du lanceur et des modules achetables.
-- Les treize codes historiques et leurs inclusions de licence sont conservés.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
END $$;
LOCK TABLE systeme."T_ModuleApplication" IN SHARE ROW EXCLUSIVE MODE;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM systeme."T_ModuleApplication"
           WHERE "ModuleParentCode"='catalogue' AND "CodeModule"<>'sante') THEN
  RAISE EXCEPTION 'Un rattachement de présentation supplémentaire au catalogue doit être examiné.';
 END IF;
END $$;

-- Ce lien concerne la présentation, pas CodeIncluant : la licence Catalogue
-- continue à inclure ses domaines historiques sans modifier leurs droits.
UPDATE systeme."T_ModuleApplication" SET "ModuleParentCode"=NULL
 WHERE "CodeModule"='sante' AND "ModuleParentCode"='catalogue';

UPDATE systeme."T_ModuleApplication"
 SET "TypeApplication"='FONCTIONNALITE', "Commercialisable"=false,
     "ModuleParentCode"=NULL, "AfficherDansEspace"=false
 WHERE "CodeModule"='catalogue'
   AND ("TypeApplication", "Commercialisable", "ModuleParentCode", "AfficherDansEspace")
       IS DISTINCT FROM ('FONCTIONNALITE'::varchar,false,NULL::varchar,false);
COMMIT;
