-- Présentation du lanceur uniquement ; droits, socle et licences inchangés.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
END $$;

ALTER TABLE systeme."T_ModuleApplication"
 ADD COLUMN IF NOT EXISTS "AfficherDansEspace" boolean NOT NULL DEFAULT true;
COMMENT ON COLUMN systeme."T_ModuleApplication"."AfficherDansEspace" IS
 'Affiche une tuile dans le lanceur des applications autorisées ; ne change ni les droits, ni les licences, ni les données ou les API du module.';
COMMENT ON CONSTRAINT "T_ModuleApplication_AfficherDansEspace_not_null" ON systeme."T_ModuleApplication" IS
 'La visibilité du lanceur est explicite pour chaque application ; elle vaut Oui par défaut sans modifier ses habilitations.';

UPDATE systeme."T_ModuleApplication"
 SET "TypeApplication"='MODULE', "Commercialisable"=true, "ModuleParentCode"=NULL
 WHERE "CodeModule" IN ('produits','discussions')
   AND ("TypeApplication", "Commercialisable", "ModuleParentCode")
       IS DISTINCT FROM ('MODULE'::varchar,true,NULL::varchar);

-- Retrait de la tuile uniquement. L'historique et les habilitations santé
-- demeurent accessibles aux routes déjà autorisées.
UPDATE systeme."T_ModuleApplication" SET "AfficherDansEspace"=false
 WHERE "CodeModule"='sante' AND "AfficherDansEspace";
COMMIT;
