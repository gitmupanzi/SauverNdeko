-- Classification de présentation commerciale, distincte des droits et licences.
-- Aucun changement de EstSocle, CodeIncluant, rôle ou abonnement existant.
BEGIN;
ALTER TABLE systeme."T_ModuleApplication"
 ADD COLUMN "TypeApplication" varchar(20) NOT NULL DEFAULT 'MODULE',
 ADD COLUMN "Commercialisable" boolean NOT NULL DEFAULT false,
 ADD COLUMN "ModuleParentCode" varchar(32),
 ADD CONSTRAINT ck_module_type_application CHECK("TypeApplication" IN('MODULE','FONCTIONNALITE')),
 ADD CONSTRAINT ck_module_commercial CHECK(NOT "Commercialisable" OR "TypeApplication"='MODULE'),
 ADD CONSTRAINT ck_module_parent CHECK("ModuleParentCode" IS DISTINCT FROM "CodeModule" AND ("TypeApplication"<>'MODULE' OR "ModuleParentCode" IS NULL)),
 ADD CONSTRAINT fk_module_parent FOREIGN KEY("ModuleParentCode") REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT;

UPDATE systeme."T_ModuleApplication"
 SET "TypeApplication"='MODULE',"Commercialisable"=true,"ModuleParentCode"=NULL
 WHERE "CodeModule" IN('catalogue','structures','professionnels','logistique','territoires','support','caisse');
UPDATE systeme."T_ModuleApplication"
 SET "TypeApplication"='FONCTIONNALITE',"Commercialisable"=false,
     "ModuleParentCode"=CASE WHEN "CodeModule" IN('produits','sante') THEN 'catalogue' ELSE NULL END
 WHERE "CodeModule" IN('produits','sante','discussions','administration','parametres','guide');

CREATE FUNCTION systeme.tr_module_classification() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('sauverndeko.catalogue.classification',0));
 IF NEW."ModuleParentCode" IS NOT NULL AND NOT EXISTS(
  SELECT FROM systeme."T_ModuleApplication" WHERE "CodeModule"=NEW."ModuleParentCode" AND "TypeApplication"='MODULE'
 ) THEN
  RAISE EXCEPTION 'Une fonctionnalité doit être rattachée à un module du catalogue.' USING ERRCODE='23514';
 END IF;
 IF NEW."TypeApplication"='FONCTIONNALITE' AND EXISTS(
  SELECT FROM systeme."T_ModuleApplication" WHERE "ModuleParentCode"=NEW."CodeModule" AND "CodeModule"<>NEW."CodeModule"
 ) THEN
  RAISE EXCEPTION 'Ce module possède des fonctionnalités ; modifiez leurs rattachements avant sa classification.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER tr_module_classification BEFORE INSERT OR UPDATE ON systeme."T_ModuleApplication"
 FOR EACH ROW EXECUTE FUNCTION systeme.tr_module_classification();
COMMENT ON COLUMN systeme."T_ModuleApplication"."TypeApplication" IS 'Nature de présentation : MODULE commercial ou FONCTIONNALITE complémentaire/commune. Ne remplace pas les règles d’accès existantes.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."Commercialisable" IS 'Le module peut être présenté comme offre commerciale ; ne donne aucun droit, ne crée ni licence ni abonnement.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."ModuleParentCode" IS 'Module de présentation de la fonctionnalité ; NULL pour une fonction commune. Distinct de CodeIncluant qui conserve les inclusions de droits historiques.';
COMMENT ON CONSTRAINT ck_module_type_application ON systeme."T_ModuleApplication" IS 'Deux natures explicites de présentation, sans dépendance aux libellés affichés.';
COMMENT ON CONSTRAINT ck_module_commercial ON systeme."T_ModuleApplication" IS 'Une fonctionnalité n’est pas proposée comme module commercial autonome.';
COMMENT ON CONSTRAINT ck_module_parent ON systeme."T_ModuleApplication" IS 'Une fonctionnalité peut dépendre d’un module ; un module est racine et ne peut se référencer lui-même.';
COMMENT ON CONSTRAINT fk_module_parent ON systeme."T_ModuleApplication" IS 'Le module parent existe et ne disparaît pas tant que des fonctionnalités le référencent.';
COMMENT ON FUNCTION systeme.tr_module_classification() IS 'Contrôle la nature du parent de présentation et empêche de reclasser en fonctionnalité un module possédant des enfants ; aucun effet sur les autorisations ou licences.';
COMMENT ON TRIGGER tr_module_classification ON systeme."T_ModuleApplication" IS 'Valide la hiérarchie de présentation MODULE/FONCTIONNALITE lors de la saisie du catalogue.';
COMMIT;
