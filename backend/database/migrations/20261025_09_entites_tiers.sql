-- Propriété durable et tiers. Exécuter après 08, dans une transaction sauvegardée.
-- Aucune conversion des anciens ID_ClientFk : leur identité n'est pas démontrée.
BEGIN;
SET LOCAL lock_timeout='10s';
ALTER TABLE logistique."T_Article" ADD COLUMN "IdEntiteFk" integer;
ALTER TABLE logistique."T_Commande" ADD COLUMN "IdEntiteFk" integer;
ALTER TABLE logistique."T_Commande" ADD COLUMN "ID_TiersFk" bigint;
ALTER TABLE logistique."T_Reglements" ADD COLUMN "ID_TiersFk" bigint;
ALTER TABLE logistique."T_Commande" DISABLE TRIGGER facture_bon_protection;
ALTER TABLE logistique."T_Commande" DISABLE TRIGGER aa_retour_commande_protection;
-- Les instantanés déjà émis prévalent sur l'affectation actuelle d'un auteur.
UPDATE logistique."T_Commande" c SET "IdEntiteFk"=f."IdEntiteFk" FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=c."ID_Commande";
UPDATE logistique."T_Commande" c SET "IdEntiteFk"=r."IdEntiteFk" FROM logistique."T_RetourBon" r WHERE c."ID_Commande" IN (r."ID_CommandeOrigineFk",r."ID_CommandeRetourFk") AND c."IdEntiteFk" IS NULL AND r."IdEntiteFk" IS NOT NULL;
UPDATE logistique."T_Commande" c SET "IdEntiteFk"=u."IdEntiteFk" FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=c."ID_UserFk" AND c."IdEntiteFk" IS NULL;
UPDATE logistique."T_Article" a SET "IdEntiteFk"=u."IdEntiteFk" FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=a."ID_UserFK";
DO $check$ BEGIN
 IF EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" d JOIN logistique."T_Article" a ON a."ID_Article"=d."ID_ArticleFk" JOIN logistique."T_Commande" c ON c."ID_Commande"=d."ID_CmdFk" WHERE a."IdEntiteFk"<>c."IdEntiteFk") OR EXISTS(SELECT 1 FROM logistique."T_RetourBon" r JOIN logistique."T_Commande" c ON c."ID_Commande" IN(r."ID_CommandeOrigineFk",r."ID_CommandeRetourFk") WHERE r."IdEntiteFk" IS NOT NULL AND c."IdEntiteFk" IS NOT NULL AND r."IdEntiteFk"<>c."IdEntiteFk") THEN
  RAISE EXCEPTION 'Reprise interrompue : liens métier entre entreprises contradictoires.' USING ERRCODE='23514';
 END IF;
END $check$;
-- Historiques non démontrés : NULL en quarantaine, jamais de rattachement arbitraire.
-- Vider les contrôles différés de la reprise avant les ALTER TABLE.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
ALTER TABLE logistique."T_Commande" ENABLE TRIGGER facture_bon_protection;
ALTER TABLE logistique."T_Commande" ENABLE TRIGGER aa_retour_commande_protection;
ALTER TABLE logistique."T_Article" ADD CONSTRAINT fk_article_entite FOREIGN KEY("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Commande" ADD CONSTRAINT fk_commande_entite FOREIGN KEY("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;
CREATE INDEX ix_article_entite ON logistique."T_Article"("IdEntiteFk","ID_Article");
CREATE INDEX ix_commande_entite ON logistique."T_Commande"("IdEntiteFk","DateCmd","ID_Commande");
CREATE TABLE logistique."T_Client" (
 "ID_Client" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "Nature" text NOT NULL DEFAULT 'personne' CHECK("Nature" IN('personne','entreprise')),
 "ID_TypeClientFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "Nom" text NOT NULL CHECK(btrim("Nom")<>''),
 "Email" text,"Telephone" text,"Adresse" text,
 "IdUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "IdProfessionnelFk" integer REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT,
 "IdEntiteRepresenteeFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ObsClient" text,"Actif" boolean NOT NULL DEFAULT true,
 "CreeParUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ModifieParUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "DateCreation" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "DateModification" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX ix_client_entite_nom ON logistique."T_Client"("IdEntiteFk",lower("Nom"),"ID_Client");
ALTER TABLE logistique."T_Commande" ADD CONSTRAINT fk_commande_tiers FOREIGN KEY("ID_TiersFk") REFERENCES logistique."T_Client"("ID_Client") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Reglements" ADD CONSTRAINT fk_reglement_tiers FOREIGN KEY("ID_TiersFk") REFERENCES logistique."T_Client"("ID_Client") ON DELETE RESTRICT;
CREATE INDEX ix_commande_tiers ON logistique."T_Commande"("ID_TiersFk") WHERE "ID_TiersFk" IS NOT NULL;
CREATE INDEX ix_reglement_tiers ON logistique."T_Reglements"("ID_TiersFk") WHERE "ID_TiersFk" IS NOT NULL;
DO $types$ DECLARE category integer;label text; BEGIN
 SELECT "ID_CategorieGenerique" INTO STRICT category FROM referentiel."T_CategorieGenerique" WHERE lower(btrim("NomCategorieGenerique"))='type de personne';
 FOREACH label IN ARRAY ARRAY['Fournisseur','Partenaire'] LOOP
 INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") SELECT category,label,label,true WHERE NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=category AND lower(btrim("NomGenerique"))=lower(label));
 END LOOP;
END $types$;
CREATE VIEW logistique."V_Client" AS SELECT t.*,g."NomGenerique" AS "TypeClient",e."NomEntite" AS "Entreprise",e."NomEntite",concat_ws(' ',u."PrenomUser",u."NomUser") AS "NomUtilisateur",concat_ws(' ',pu."PrenomUser",pu."NomUser") AS "NomProfessionnel",rep."NomEntite" AS "NomEntiteRepresentee" FROM logistique."T_Client" t JOIN systeme."T_Entite" e ON e."IdEntite"=t."IdEntiteFk" LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=t."ID_TypeClientFk" LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=t."IdUserFk" LEFT JOIN professionnel."T_Professionnel" p ON p."IdProfessionnel"=t."IdProfessionnelFk" LEFT JOIN systeme."T_Utilisateurs" pu ON pu."IdUser"=p."IdUserFk" LEFT JOIN systeme."T_Entite" rep ON rep."IdEntite"=t."IdEntiteRepresenteeFk";
CREATE FUNCTION logistique.controler_propriete_logistique() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE parent_entity integer; article_entity integer; client_entity integer; parent_tiers bigint;
BEGIN
 IF TG_TABLE_NAME IN('T_Article','T_Commande','T_Client') THEN
  IF NEW."IdEntiteFk" IS NULL THEN RAISE EXCEPTION 'Entreprise propriétaire requise.' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND NOT (OLD."IdEntiteFk" IS NULL AND NEW."IdEntiteFk" IS NOT NULL AND current_setting('sauverndeko.owner_assignment',true)='on') THEN RAISE EXCEPTION 'Entreprise propriétaire immuable.' USING ERRCODE='23514';END IF;
 END IF;
 IF TG_TABLE_NAME='T_Client' THEN
  IF TG_OP='UPDATE' AND (NEW."CreeParUserFk" IS DISTINCT FROM OLD."CreeParUserFk" OR NEW."DateCreation" IS DISTINCT FROM OLD."DateCreation") THEN RAISE EXCEPTION 'Auteur et date de création immuables.' USING ERRCODE='23514';END IF;
  IF NEW."IdProfessionnelFk" IS NOT NULL AND NEW."IdUserFk" IS NOT NULL AND NOT EXISTS(SELECT 1 FROM professionnel."T_Professionnel" p WHERE p."IdProfessionnel"=NEW."IdProfessionnelFk" AND p."IdUserFk"=NEW."IdUserFk") THEN RAISE EXCEPTION 'Identités du tiers incompatibles.' USING ERRCODE='23514';END IF;
  IF NEW."ID_TypeClientFk" IS NOT NULL AND NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_Generique"=NEW."ID_TypeClientFk" AND lower(btrim(c."NomCategorieGenerique"))='type de personne') THEN RAISE EXCEPTION 'Type de client incompatible.' USING ERRCODE='23514';END IF;
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
END $fn$;
CREATE TRIGGER aa_propriete_article BEFORE INSERT OR UPDATE ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();
CREATE TRIGGER aa_propriete_commande BEFORE INSERT OR UPDATE ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();
CREATE TRIGGER aa_propriete_client BEFORE INSERT OR UPDATE ON logistique."T_Client" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();
CREATE TRIGGER aa_propriete_ligne BEFORE INSERT OR UPDATE ON logistique."T_CommandeDetail" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();
CREATE TRIGGER aa_propriete_mouvement BEFORE INSERT OR UPDATE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();
CREATE TRIGGER aa_propriete_reglement BEFORE INSERT OR UPDATE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.controler_propriete_logistique();
-- Remplacer uniquement les recherches d'affectation dans les protections déjà installées.
DO $patch$
DECLARE definition text;
BEGIN
 definition:=pg_get_functiondef('logistique.tr_proteger_facture()'::regprocedure);
 definition:=replace(definition,'SELECT "IdEntiteFk" INTO source_entity FROM systeme."T_Utilisateurs" WHERE "IdUser"=parent."ID_UserFk" FOR SHARE;','source_entity:=parent."IdEntiteFk";');EXECUTE definition;
 definition:=pg_get_functiondef('logistique.controler_retour_bon()'::regprocedure);
 definition:=replace(definition,'SELECT "IdEntiteFk" INTO source_entite FROM systeme."T_Utilisateurs" WHERE "IdUser"=origine."ID_UserFk" FOR SHARE;','SELECT "IdEntiteFk" INTO source_entite FROM logistique."T_Commande" WHERE "ID_Commande"=origine."ID_Commande" FOR SHARE;');
 definition:=replace(definition,'acteur_entite IS DISTINCT FROM NEW."IdEntiteFk"','(acteur_entite IS DISTINCT FROM NEW."IdEntiteFk" AND NOT EXISTS(SELECT 1 FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=NEW."ID_UserFk" AND u."Is_Admin" IS TRUE))');EXECUTE definition;
END $patch$;
CREATE OR REPLACE FUNCTION logistique.verifier_dossier_suivi() RETURNS trigger LANGUAGE plpgsql AS $$
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
-- Étendre les vues sans remplacer leurs calculs métier ni leur ordre de colonnes existant.
DO $views$
DECLARE item record; definition text; join_sql text; extra text; root_name text; root_key text; field_name text;
BEGIN
 FOR item IN SELECT table_name FROM information_schema.views WHERE table_schema='logistique' AND table_name IN('V_Article','V_Commande','V_CommandesSansDetails','V_SuiviReglements','V_CommandeDetail','V_Reglements','V_Mouvement','V_MouvementStock','V_AuditStock','V_AlertStock','V_CouvertureStock','V_ConsoMensuelle') LOOP
  root_name:=NULL;root_key:=NULL;field_name:=NULL;
  SELECT column_name INTO field_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name=item.table_name AND column_name IN('ID_Commande','ID_CmdFk','ID_cmdFk') ORDER BY CASE column_name WHEN 'ID_Commande' THEN 0 ELSE 1 END LIMIT 1;
  IF field_name IS NOT NULL THEN root_name:='T_Commande';root_key:='ID_Commande';
  ELSIF item.table_name='V_Reglements' THEN root_name:='T_Commande';root_key:='CodeFacture';field_name:='CodeFactureFk';
  ELSE SELECT column_name INTO field_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name=item.table_name AND column_name IN('ID_Article','ID_ArticleFk') ORDER BY CASE column_name WHEN 'ID_Article' THEN 0 ELSE 1 END LIMIT 1;IF field_name IS NOT NULL THEN root_name:='T_Article';root_key:='ID_Article';END IF;END IF;
  IF root_name IS NULL THEN CONTINUE;END IF;
  extra:='';IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='logistique' AND table_name=item.table_name AND column_name='IdEntiteFk') THEN extra:=extra||',r."IdEntiteFk"';END IF;
  join_sql:=format(' LEFT JOIN logistique.%I r ON r.%I=source.%I',root_name,root_key,field_name);
  IF root_name='T_Commande' THEN
   extra:=extra||',r."ID_TiersFk",t."Nom" AS "TiersNom"';join_sql:=join_sql||' LEFT JOIN logistique."T_Client" t ON t."ID_Client"=r."ID_TiersFk"';
  END IF;
  definition:=rtrim(pg_get_viewdef(format('logistique.%I',item.table_name)::regclass,true),';'||chr(10)||' ');
  EXECUTE format('CREATE OR REPLACE VIEW logistique.%I AS SELECT source.*%s FROM (%s) source %s',item.table_name,extra,definition,join_sql);
 END LOOP;
END $views$;
CREATE VIEW logistique."V_ProprietairesARevoir" AS SELECT 'article'::text AS "TypeObjet","ID_Article" AS "Identifiant" FROM logistique."T_Article" WHERE "IdEntiteFk" IS NULL UNION ALL SELECT 'commande',"ID_Commande" FROM logistique."T_Commande" WHERE "IdEntiteFk" IS NULL;
COMMENT ON VIEW logistique."V_ProprietairesARevoir" IS 'Diagnostic de quarantaine des propriétaires historiques non démontrés ; réservé à la plateforme.';
COMMENT ON TABLE logistique."T_Client" IS 'Tiers collaboratif appartenant durablement à une entreprise, utilisable comme client et fournisseur, sans compte obligatoire.';
COMMENT ON VIEW logistique."V_Client" IS 'Fiche commune de tiers avec catégorie et entreprise propriétaire ; filtrage serveur obligatoire.';
COMMENT ON FUNCTION logistique.controler_propriete_logistique() IS 'Conserve les entreprises propriétaires et interdit les liens de tiers, articles, bons et règlements entre entreprises.';
DO $comments$ DECLARE t text;c record; BEGIN
 FOREACH t IN ARRAY ARRAY['T_Article','T_Commande'] LOOP EXECUTE format('COMMENT ON COLUMN logistique.%I."IdEntiteFk" IS %L',t,'Entreprise propriétaire obligatoire et immuable ; indépendante de l’affectation future de l’auteur.');END LOOP;
 FOR c IN SELECT column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name='T_Client' LOOP EXECUTE format('COMMENT ON COLUMN logistique."T_Client".%I IS %L',c.column_name,'Attribut du tiers : '||c.column_name||'. La propriété de l’entreprise est distincte du compte ou professionnel facultatif.');END LOOP;
 FOR c IN SELECT event_object_table,trigger_name FROM information_schema.triggers WHERE trigger_schema='logistique' AND trigger_name LIKE 'aa_propriete_%' GROUP BY event_object_table,trigger_name LOOP EXECUTE format('COMMENT ON TRIGGER %I ON logistique.%I IS %L',c.trigger_name,c.event_object_table,'Contrôle la propriété durable et la cohérence des rattachements de l’entreprise.');END LOOP;
END $comments$;
COMMENT ON COLUMN logistique."T_Commande"."ID_TiersFk" IS 'Nouvelle FK explicite vers T_Client ; ne convertit pas les anciens ID_ClientFk ambigus.';
COMMENT ON COLUMN logistique."T_Reglements"."ID_TiersFk" IS 'Tiers explicite conservé depuis le bon de la facture ; distinct de l’ancien identifiant client.';
DO $documentation$ DECLARE r record;BEGIN
 FOR r IN SELECT c.conname,n.nspname,t.relname FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='logistique' AND (t.relname='T_Client' OR c.conname IN('fk_article_entite','fk_commande_entite','fk_commande_tiers','fk_reglement_tiers')) LOOP EXECUTE format('COMMENT ON CONSTRAINT %I ON %I.%I IS %L',r.conname,r.nspname,r.relname,'Garantie du rattachement durable du tiers, de son identité ou de son entreprise propriétaire.');END LOOP;
 FOR r IN SELECT indexname FROM pg_indexes WHERE schemaname='logistique' AND indexname IN('ix_article_entite','ix_commande_entite','ix_client_entite_nom','ix_commande_tiers','ix_reglement_tiers') LOOP EXECUTE format('COMMENT ON INDEX logistique.%I IS %L',r.indexname,'Accès au périmètre entreprise et aux documents liés du tiers, sans dépendre du créateur actuel.');END LOOP;
 FOR r IN SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name LIKE 'V_%' AND column_name IN('IdEntiteFk','ID_TiersFk','TiersNom','TypeClient') LOOP EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',r.table_name,r.column_name,'Rattachement ou libellé vérifié du propriétaire ou du tiers, utilisé par les lectures communes.');END LOOP;
END $documentation$;
COMMIT;
