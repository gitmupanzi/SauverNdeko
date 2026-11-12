-- Référentiels communs et d'entreprise, identités conservées et contrôles atomiques.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $guard$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 IF to_regprocedure('referentiel.fn_categories_champ(text,text,text,integer)') IS NULL OR EXISTS(
  SELECT FROM information_schema.columns WHERE table_schema='referentiel' AND table_name='T_Generique' AND column_name='IdEntiteFk') THEN
  RAISE EXCEPTION 'Socle09 requis ou évolution déjà installée';END IF;
END $guard$;

ALTER TABLE referentiel."T_CategorieGenerique" ADD COLUMN "IdEntiteFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;
ALTER TABLE referentiel."T_Generique" ADD COLUMN "IdEntiteFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;
COMMENT ON COLUMN referentiel."T_CategorieGenerique"."IdEntiteFk" IS 'Propriétaire durable facultatif : NULL désigne le référentiel commun. Toutes les catégories antérieures restent communes ; une propriété enregistrée est immuable.';
COMMENT ON COLUMN referentiel."T_Generique"."IdEntiteFk" IS 'Propriétaire durable facultatif : NULL commun, sinon valeur privée de cette entreprise. Une catégorie privée impose la même entreprise ; aucune réattribution des données antérieures.';
COMMENT ON TABLE referentiel."T_CategorieGenerique" IS 'Familles transversales communes ou propres à une entreprise, réutilisées par les champs catalogués. Identifiants et familles antérieures conservés.';
COMMENT ON TABLE referentiel."T_Generique" IS 'Valeurs du référentiel, identifiées par ID_Generique, classées par catégorie et protégées par une portée commune ou entreprise ; les drapeaux de visibilité historiques restent distincts.';
COMMENT ON CONSTRAINT "T_CategorieGenerique_IdEntiteFk_fkey" ON referentiel."T_CategorieGenerique" IS 'La catégorie privée appartient à une entreprise réelle qui ne peut être supprimée tant que la référence existe.';
COMMENT ON CONSTRAINT "T_Generique_IdEntiteFk_fkey" ON referentiel."T_Generique" IS 'La valeur privée appartient à une entreprise réelle ; ses identifiants métier ne sont pas déplacés à la suppression du propriétaire.';

CREATE FUNCTION referentiel.fn_normaliser_libelle(p_texte text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $$
 SELECT lower(btrim(regexp_replace(p_texte,'[[:space:]'||chr(160)||']+',' ','g'))) $$;
COMMENT ON FUNCTION referentiel.fn_normaliser_libelle(text) IS 'Clé de comparaison des libellés/codes : casse et espaces normalisés, y compris espace insécable. Les accents restent distincts ; la forme affichée et les identifiants ne sont jamais réécrits.';

CREATE FUNCTION referentiel.fn_categorie_visible(p_categorie integer,p_entite integer DEFAULT NULL) RETURNS boolean
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" c WHERE c."ID_CategorieGenerique"=p_categorie
  AND (c."IdEntiteFk" IS NULL OR c."IdEntiteFk"=p_entite)) $$;
COMMENT ON FUNCTION referentiel.fn_categorie_visible(integer,integer) IS 'Visibilité de portée uniquement : catégorie commune ou de l’entreprise explicitement indiquée, jamais d’une autre. NULL entreprise ne désigne que les catégories communes ; validité contrôlée séparément.';

CREATE FUNCTION referentiel.fn_reference_visible(p_valeur integer,p_entite integer DEFAULT NULL) RETURNS boolean
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"=p_valeur
  AND (g."IdEntiteFk" IS NULL OR g."IdEntiteFk"=p_entite)
  AND referentiel.fn_categorie_visible(g."ID_CategorieGeneriqueFk",p_entite)) $$;
COMMENT ON FUNCTION referentiel.fn_reference_visible(integer,integer) IS 'Visibilité d’une valeur et de sa famille dans le même périmètre commun/entreprise, sans autorisation d’accès supplémentaire. Ne confond ni valeur inactive ni référence hors catégorie avec une autre entreprise.';

CREATE INDEX ix_categorie_generique_entite ON referentiel."T_CategorieGenerique"("IdEntiteFk");
CREATE INDEX ix_generique_entite_categorie ON referentiel."T_Generique"("IdEntiteFk","ID_CategorieGeneriqueFk");
CREATE INDEX ix_categorie_generique_nom_normalise ON referentiel."T_CategorieGenerique"(referentiel.fn_normaliser_libelle("NomCategorieGenerique"));
CREATE INDEX ix_generique_nom_normalise ON referentiel."T_Generique"("ID_CategorieGeneriqueFk",referentiel.fn_normaliser_libelle("NomGenerique"));
CREATE INDEX ix_generique_code_normalise ON referentiel."T_Generique"("ID_CategorieGeneriqueFk",referentiel.fn_normaliser_libelle("AbrGenerique"));
COMMENT ON INDEX referentiel.ix_categorie_generique_entite IS 'Lecture des catégories communes et propres au contexte autorisé.';
COMMENT ON INDEX referentiel.ix_generique_entite_categorie IS 'Lecture des valeurs d’une catégorie dans la portée propriétaire autorisée.';
COMMENT ON INDEX referentiel.ix_categorie_generique_nom_normalise IS 'Recherche des ambiguïtés de nom sans supprimer les anciens doublons ; la garde sérialise les nouvelles identités.';
COMMENT ON INDEX referentiel.ix_generique_nom_normalise IS 'Comparaison du libellé dans sa famille et sa portée effective ; aucune consolidation des identifiants historiques.';
COMMENT ON INDEX referentiel.ix_generique_code_normalise IS 'Comparaison du code facultatif dans la catégorie ; les anciens codes identiques restent conservés.';

CREATE FUNCTION referentiel.tr_categorie_portee_doublon() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE normalise text; duplicate_id integer;
BEGIN
 IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" THEN
  RAISE EXCEPTION 'La portée d’une catégorie enregistrée est conservée.' USING ERRCODE='23514',CONSTRAINT='ck_categorie_portee_immuable';END IF;
 normalise:=referentiel.fn_normaliser_libelle(NEW."NomCategorieGenerique");
 IF TG_OP='UPDATE' AND normalise IS NOT DISTINCT FROM referentiel.fn_normaliser_libelle(OLD."NomCategorieGenerique") THEN RETURN NEW;END IF;
 IF coalesce(normalise,'')='' THEN RAISE EXCEPTION 'Indiquez le libellé de la catégorie.' USING ERRCODE='23514',CONSTRAINT='ck_categorie_nom_requis';END IF;
 -- Un verrou commun sérialise les lots de catégories dans un ordre unique.
 PERFORM pg_advisory_xact_lock(hashtextextended('referentiel:categories:identite',0));
 SELECT "ID_CategorieGenerique" INTO duplicate_id FROM referentiel."T_CategorieGenerique" c
  WHERE c."ID_CategorieGenerique"<>NEW."ID_CategorieGenerique"
   AND referentiel.fn_normaliser_libelle(c."NomCategorieGenerique")=normalise
   AND (NEW."IdEntiteFk" IS NULL OR c."IdEntiteFk" IS NULL OR c."IdEntiteFk"=NEW."IdEntiteFk") LIMIT 1;
 IF FOUND THEN RAISE EXCEPTION 'Une catégorie de même nom existe déjà dans cette portée.' USING ERRCODE='23505',CONSTRAINT='uq_categorie_nom_effectif';END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION referentiel.tr_categorie_portee_doublon() IS 'Propriété immuable et noms non vides non ambigus entre commun et entreprise. Les identités historiques inchangées restent modifiables descriptivement ; le verrou transactionnel interdit les doublons concurrents.';
CREATE TRIGGER ab_categorie_portee_doublon BEFORE INSERT OR UPDATE ON referentiel."T_CategorieGenerique" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_categorie_portee_doublon();
COMMENT ON TRIGGER ab_categorie_portee_doublon ON referentiel."T_CategorieGenerique" IS 'Garde des nouvelles identités de familles et de leur portée durable, sans correction implicite des données anciennes.';

CREATE FUNCTION referentiel.tr_generique_portee_doublon() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE famille_entite integer; nom text; code text; nom_change boolean; code_change boolean;
BEGIN
 IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" THEN
  RAISE EXCEPTION 'La portée d’une valeur enregistrée est conservée.' USING ERRCODE='23514',CONSTRAINT='ck_generique_portee_immuable';END IF;
 SELECT "IdEntiteFk" INTO famille_entite FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=NEW."ID_CategorieGeneriqueFk" FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Catégorie introuvable.' USING ERRCODE='23503';END IF;
 IF famille_entite IS NOT NULL AND NEW."IdEntiteFk" IS DISTINCT FROM famille_entite THEN
  RAISE EXCEPTION 'Une valeur de catégorie privée appartient à la même entreprise.' USING ERRCODE='23514',CONSTRAINT='ck_generique_categorie_portee';END IF;
 IF NEW."IdEntiteFk" IS NOT NULL AND EXISTS(SELECT FROM referentiel."T_ChampReferentiel" r
  WHERE NOT r."CanConfigure" AND r."ID_CategorieDefautFk"=NEW."ID_CategorieGeneriqueFk") THEN
  RAISE EXCEPTION 'Les valeurs d’une famille de sécurité restent communes.' USING ERRCODE='23514',CONSTRAINT='ck_generique_securite_commune';END IF;
 nom:=referentiel.fn_normaliser_libelle(NEW."NomGenerique");code:=referentiel.fn_normaliser_libelle(NEW."AbrGenerique");
 nom_change:=TG_OP='INSERT';code_change:=TG_OP='INSERT';
 IF TG_OP='UPDATE' THEN
  nom_change:=nom IS DISTINCT FROM referentiel.fn_normaliser_libelle(OLD."NomGenerique") OR NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk";
  code_change:=code IS DISTINCT FROM referentiel.fn_normaliser_libelle(OLD."AbrGenerique") OR NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk";
 END IF;
 IF NOT(nom_change OR code_change) THEN RETURN NEW;END IF;
 IF nom_change AND coalesce(nom,'')='' THEN RAISE EXCEPTION 'Indiquez le libellé de la valeur.' USING ERRCODE='23514',CONSTRAINT='ck_generique_nom_requis';END IF;
 -- Une famille est commune au lot de valeurs, comme l’en-tête d’un bon.
 PERFORM pg_advisory_xact_lock(hashtextextended('referentiel:valeurs:'||NEW."ID_CategorieGeneriqueFk"::text,0));
 IF nom_change AND EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"<>NEW."ID_Generique" AND g."ID_CategorieGeneriqueFk"=NEW."ID_CategorieGeneriqueFk"
  AND referentiel.fn_normaliser_libelle(g."NomGenerique")=nom AND (NEW."IdEntiteFk" IS NULL OR g."IdEntiteFk" IS NULL OR g."IdEntiteFk"=NEW."IdEntiteFk")) THEN
  RAISE EXCEPTION 'Un libellé identique existe déjà dans cette catégorie et cette portée.' USING ERRCODE='23505',CONSTRAINT='uq_generique_nom_effectif';END IF;
 IF code_change AND coalesce(code,'')<>'' AND EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"<>NEW."ID_Generique" AND g."ID_CategorieGeneriqueFk"=NEW."ID_CategorieGeneriqueFk"
  AND referentiel.fn_normaliser_libelle(g."AbrGenerique")=code AND (NEW."IdEntiteFk" IS NULL OR g."IdEntiteFk" IS NULL OR g."IdEntiteFk"=NEW."IdEntiteFk")) THEN
  RAISE EXCEPTION 'Un code identique existe déjà dans cette catégorie et cette portée.' USING ERRCODE='23505',CONSTRAINT='uq_generique_code_effectif';END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION referentiel.tr_generique_portee_doublon() IS 'Cohérence de propriétaire catégorie/valeur et contrôle des nouveaux libellés/codes, sérialisé par famille. Les familles de sécurité non configurables restent communes. Un doublon privé entre entreprises distinctes reste autorisé ; aucun ancien doublon n’est fusionné ou effacé.';
CREATE TRIGGER ab_generique_portee_doublon BEFORE INSERT OR UPDATE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_generique_portee_doublon();
COMMENT ON TRIGGER ab_generique_portee_doublon ON referentiel."T_Generique" IS 'Valide la portée et les changements d’identité ; respecte les gardes métier existantes des devises, unités et types de bon utilisés.';

CREATE OR REPLACE FUNCTION referentiel.fn_valider_reference_champ(p_schema text,p_table text,p_colonne text,p_valeur integer,p_entite integer DEFAULT NULL) RETURNS boolean
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT p_valeur IS NULL OR EXISTS(SELECT FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  JOIN referentiel."T_ChampReferentiel" r ON r."SchemaName"=p_schema AND r."TableName"=p_table AND r."ColumnName"=p_colonne
  WHERE g."ID_Generique"=p_valeur AND g."ValideGenerique" AND c."ValideCategorieGenerique"
   AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(p_schema,p_table,p_colonne,p_entite))
   AND referentiel.fn_reference_visible(p_valeur,CASE WHEN r."SupportsEntityScope" THEN p_entite END)) $$;
COMMENT ON FUNCTION referentiel.fn_valider_reference_champ(text,text,text,integer,integer) IS 'Nouvelle sélection active de la catégorie configurée et de la portée propriétaire réelle. Les champs communs excluent toutes les valeurs privées ; les références historiques inchangées restent gérées par la garde physique existante.';

CREATE FUNCTION systeme.tr_correspondance_categorie_portee() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cible_entite integer;
BEGIN
 IF NEW."MappingType"<>'generic_category' OR NEW."TargetCategoryIdFk" IS NULL THEN RETURN NEW;END IF;
 SELECT "IdEntiteFk" INTO cible_entite FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=NEW."TargetCategoryIdFk" FOR SHARE;
 IF cible_entite IS NOT NULL AND (NEW."SettingScope"<>'entity' OR NEW."ScopeValue" IS DISTINCT FROM cible_entite::text
  OR EXISTS(SELECT FROM referentiel."T_ChampReferentiel" c WHERE NOT c."SupportsEntityScope" AND
   (c."ID_ChampReferentiel"=NEW."IdChampReferentielFk" OR NEW."SourceKey"=ANY(c."AliasSourceKeys")))) THEN
  RAISE EXCEPTION 'Une catégorie privée exige le champ et la portée de son entreprise.' USING ERRCODE='23514',CONSTRAINT='ck_correspondance_categorie_portee';END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION systeme.tr_correspondance_categorie_portee() IS 'Une famille privée ne peut configurer que son entreprise et un champ supportant réellement ce contexte ; protège aussi les anciens alias sans modifier leur résolution.';
CREATE TRIGGER ab_correspondance_categorie_portee BEFORE INSERT OR UPDATE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.tr_correspondance_categorie_portee();
COMMENT ON TRIGGER ab_correspondance_categorie_portee ON systeme."T_Fk_Correspondance" IS 'Complète la garde canonique existante par la propriété de la catégorie choisie.';

CREATE OR REPLACE VIEW referentiel."V_CategorieGenerique" AS SELECT c."ID_CategorieGenerique",c."NomCategorieGenerique",c."ModuleCategorieGenerique",c."ValideCategorieGenerique",
 c."IdEntiteFk",e."NomEntite",CASE WHEN c."IdEntiteFk" IS NULL THEN 'Commun'::text ELSE 'Entreprise'::text END AS "Portee"
 FROM referentiel."T_CategorieGenerique" c LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=c."IdEntiteFk"
 ORDER BY c."NomCategorieGenerique",c."ModuleCategorieGenerique";
COMMENT ON VIEW referentiel."V_CategorieGenerique" IS 'Registre transversal des catégories, avec propriétaire et portée explicites. L’API limite les lignes au commun et à l’entreprise autorisée ; aucun nom ne sert de clé.';
CREATE OR REPLACE VIEW referentiel."V_Generique" AS SELECT g."ID_CategorieGeneriqueFk",c."NomCategorieGenerique",c."ModuleCategorieGenerique",g."ID_Generique",g."NomGenerique",g."AbrGenerique",
 g."VisibleNiveau_2",g."VisibleNiveau_3",g."VisibleNiveau_4",g."VisibleNiveau_5",g."VisibleArticle",g."VisibleCmd",g."VisibleFacture",g."VisibleUsers",g."VisibleVoie",g."VisibleAll",g."ObsGenerique",g."ValideGenerique",
 g."IdEntiteFk",e."NomEntite",CASE WHEN g."IdEntiteFk" IS NULL THEN 'Commun'::text ELSE 'Entreprise'::text END AS "Portee",c."IdEntiteFk" AS "IdEntiteCategorieFk"
 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=g."IdEntiteFk" ORDER BY c."NomCategorieGenerique",g."NomGenerique",g."AbrGenerique";
COMMENT ON VIEW referentiel."V_Generique" IS 'Valeurs, catégories et visibilités inchangées, avec portée durable et propriétaire de la famille pour les contrôles de lecture/export ; aucun filtre implicite de validité.';

CREATE VIEW referentiel."V_InterfaceTableau" AS SELECT i."CleInterface",replace(replace(i."CleInterface",'.',' · '),'_',' ') AS "Libelle",i."Module",i."Version",i."Colonnes",i."Actif",i."ModifieLe",jsonb_array_length(i."Colonnes") AS "NbColonnes"
 FROM referentiel."T_InterfaceTableau" i;
COMMENT ON VIEW referentiel."V_InterfaceTableau" IS 'Catalogue réel des interfaces de tableaux et exports, en consultation. Libellé lisible dérivé de la clé, colonnes structurées et nombre calculé ; les préférences personnelles utilisent leur service existant.';
DO $comments$ DECLARE r record;BEGIN
 FOR r IN SELECT * FROM (VALUES
  ('V_CategorieGenerique','IdEntiteFk','Propriétaire de la famille, NULL commun.'),('V_CategorieGenerique','NomEntite','Nom actuel de l’entreprise propriétaire, absent pour le commun.'),('V_CategorieGenerique','Portee','Portée lisible calculée depuis la FK propriétaire.'),
  ('V_Generique','IdEntiteFk','Propriétaire de la valeur, NULL commun.'),('V_Generique','NomEntite','Nom actuel du propriétaire de la valeur, absent pour le commun.'),('V_Generique','Portee','Portée calculée depuis le propriétaire de la valeur.'),('V_Generique','IdEntiteCategorieFk','Propriétaire de la famille pour vérifier que toute valeur privée est dans le même contexte.'),
  ('V_InterfaceTableau','CleInterface','Clé stable du catalogue PostgreSQL et des services de préférences.'),('V_InterfaceTableau','Libelle','Libellé de lecture dérivé de la clé, sans deuxième définition persistée.'),('V_InterfaceTableau','Module','Application propriétaire déclarée par le catalogue réel.'),('V_InterfaceTableau','Version','Version effective de la définition des colonnes.'),('V_InterfaceTableau','Colonnes','Définitions JSON validées des colonnes, de leurs usages et de leur ordre par défaut.'),('V_InterfaceTableau','Actif','Disponibilité de cette interface dans le catalogue.'),('V_InterfaceTableau','ModifieLe','Horodatage du dernier changement de définition.'),('V_InterfaceTableau','NbColonnes','Nombre de définitions de colonnes calculé depuis le JSON.')) AS x(v,c,d) LOOP
  EXECUTE format('COMMENT ON COLUMN referentiel.%I.%I IS %L',r.v,r.c,r.d);
 END LOOP;
END $comments$;
-- Colonnes facultatives, ajoutées sans changer l’ordre ou les choix existants.
DO $scope_columns$ DECLARE r record;entries jsonb;position integer;BEGIN
 FOR r IN SELECT * FROM referentiel."T_InterfaceTableau" WHERE "CleInterface" IN('referentiels.categories','referentiels.valeurs') FOR UPDATE LOOP
  position:=jsonb_array_length(r."Colonnes");entries:=r."Colonnes";
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(entries) x WHERE x->>'id'='IdEntiteFk') THEN
   entries:=entries||jsonb_build_array(jsonb_build_object('id','IdEntiteFk','label','Portée','type','integer','defaultVisible',false,'defaultOrder',position,'defaultExportOrder',position,'defaultExport',false,'exportable',true,'tableAvailable',true));position:=position+1;
  END IF;
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(entries) x WHERE x->>'id'='NomEntite') THEN
   entries:=entries||jsonb_build_array(jsonb_build_object('id','NomEntite','label','Entreprise propriétaire','type','text','defaultVisible',false,'defaultOrder',position,'defaultExportOrder',position,'defaultExport',false,'exportable',true,'tableAvailable',false));
  END IF;
  UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=entries,"Version"="Version"+1 WHERE "CleInterface"=r."CleInterface";
 END LOOP;
END $scope_columns$;
-- Défauts physiques et financiers dans leur périmètre réel.
CREATE OR REPLACE FUNCTION logistique.fn_devise_usd()
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE identifiant integer; nombre bigint;
BEGIN
 SELECT min(g."ID_Generique"),count(*) INTO identifiant,nombre
 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Article','ID_DeviseFk',NULL))
   AND c."ValideCategorieGenerique" IS TRUE AND g."ValideGenerique" IS TRUE
   AND referentiel.fn_reference_visible(g."ID_Generique",NULL)
   AND logistique.fn_code_devise(g."AbrGenerique")='USD';
 IF nombre<>1 THEN
  RAISE EXCEPTION 'Une seule devise USD active est requise dans la catégorie Devise active (trouvées : %).',nombre USING ERRCODE='23514';
 END IF;
 RETURN identifiant;
END;
$function$
;
COMMENT ON FUNCTION logistique.fn_devise_usd() IS 'Défaut USD actif unique du référentiel commun, sans compter les devises privées des entreprises. Les services propriétaires résolvent explicitement leur contexte.';
CREATE OR REPLACE FUNCTION logistique.fn_materialiser_stock_initial(p_article integer, p_mouvement integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE a record;m logistique."T_Mouvement"%ROWTYPE;num record;kind integer;command_id integer;qty numeric;price numeric;business_date timestamp;origin text;prior_article text:=coalesce(current_setting('logistique.stock_initial_article',true),'');prior_movement text:=coalesce(current_setting('logistique.stock_initial_mouvement',true),'');
BEGIN
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=p_article FOR NO KEY UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Article absent.' USING ERRCODE='23503';END IF;
 IF p_mouvement IS NULL THEN
  SELECT "ID_Commande" INTO command_id FROM logistique."T_Commande" WHERE "ID_ArticleInitialFk"=p_article AND "OrigineBon"='stock_initial';
  IF FOUND THEN RETURN command_id;END IF;
  qty=a."QteArticle";price=a."PUArticle";business_date=coalesce(a."DateHeureAuto"::timestamp,clock_timestamp()::timestamp);origin='stock_initial';
  IF coalesce(qty,0)=0 THEN RETURN NULL;END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=p_article) THEN RAISE EXCEPTION 'Stock deja historise: rapprochez les mouvements existants.' USING ERRCODE='23514';END IF;
  SELECT g."ID_Generique" INTO kind FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE referentiel.fn_valider_reference_champ('logistique','T_Commande','ID_TypeCmdFk',g."ID_Generique",a."IdEntiteFk") AND g."AbrGenerique" ILIKE 'entr%' AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE ORDER BY g."ID_Generique" LIMIT 1;
 ELSE
  SELECT * INTO m FROM logistique."T_Mouvement" WHERE "ID_Mvt"=p_mouvement AND "ID_ArticleFk"=p_article FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mouvement absent.' USING ERRCODE='23503';END IF;
  IF m."ID_cmdFk" IS NOT NULL THEN RETURN m."ID_cmdFk";END IF;
  qty=m."QteMvt";price=m."PUMvt";business_date=m."DateMvt";kind=m."ID_TypeMvtFk";origin='reprise_mouvement';
 END IF;
 IF qty IS NULL OR qty<=0 OR price IS NULL OR price<0 OR kind IS NULL THEN RAISE EXCEPTION 'Quantite, prix d achat et type requis pour le stock initial.' USING ERRCODE='23514';END IF;
 PERFORM set_config('logistique.stock_initial_article',p_article::text,true);
 PERFORM set_config('logistique.stock_initial_mouvement',coalesce(p_mouvement::text,''),true);
 SELECT * INTO num FROM logistique.fn_reserver_identite_commande();
 INSERT INTO logistique."T_Commande"("ID_Commande","ID_TypeCmdFk","ID_UserFk","IdEntiteFk","ID_DeviseFk","DateCmd","DateHeureAutoCmd","RefCmd","ObsCmd","OrigineBon","ID_ArticleInitialFk")
 VALUES(num."ID_Commande",kind,CASE WHEN p_mouvement IS NULL THEN a."ID_UserFK" END,a."IdEntiteFk",coalesce(m."ID_DeviseFk",a."ID_DeviseFk"),business_date,clock_timestamp(),CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Reprise mouvement historique / '||p_mouvement::text END,CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Rattachement documentaire sans variation de stock. Auteur historique non prouvé; dates, prix et mouvement conservés.' END,origin,p_article)
 RETURNING "ID_Commande" INTO command_id;
 INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail","ObsCmdDetail") VALUES(command_id,p_article,qty,price,CASE WHEN p_mouvement IS NULL THEN 'Stock initial de la fiche article' ELSE 'Mouvement historique conservé #'||p_mouvement::text END);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk") VALUES('logistique.T_Commande',CASE WHEN p_mouvement IS NULL THEN 'INITIAL_STOCK_DOCUMENT' ELSE 'HISTORICAL_STOCK_DOCUMENT' END,jsonb_build_object('ID_Commande',command_id,'ID_Article',p_article,'ID_Mvt',coalesce(p_mouvement,(SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=command_id AND "ID_ArticleFk"=p_article)),'OrigineBon',origin,'AuteurOrigineProuve',p_mouvement IS NULL),a."IdEntiteFk");
 PERFORM set_config('logistique.stock_initial_article',prior_article,true);
 PERFORM set_config('logistique.stock_initial_mouvement',prior_movement,true);
 RETURN command_id;
END $function$
;
COMMENT ON FUNCTION logistique.fn_materialiser_stock_initial(integer,integer) IS 'Stock initial physique inchangé, un BE/ligne/mouvement atomique. Le type d’entrée est actif, dans la catégorie et la portée réelles de l’article, sans choisir le type privé d’une autre entreprise.';
CREATE OR REPLACE FUNCTION referentiel.fn_entite_reference_champ(p_schema text, p_table text, p_ligne jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
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
END $function$
;
COMMENT ON FUNCTION referentiel.fn_entite_reference_champ(text,text,jsonb) IS 'Propriétaire stable de la vraie ligne : FK directe, PK Entité, parent logistique ou unité de précision à propriétaire immuable. Les tables partagées sans propriétaire restent globales ; aucune déduction depuis l’utilisateur ou la session.';

-- Une unité privée conserve une précision unique par son identifiant stable.
-- Évolution fermée de cette seule définition, pas de déverrouillage permanent.
DO $precision$ BEGIN
 IF (SELECT count(*) FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='logistique' AND "TableName"='T_PrecisionStock' AND "ColumnName"='ID_UniteFk' AND "SupportsEntityScope" IS FALSE)<>1 THEN
  RAISE EXCEPTION 'Définition de précision inattendue';END IF;
END $precision$;
DROP TRIGGER tr_catalogue_champ_integrite ON referentiel."T_ChampReferentiel";
WITH old AS (SELECT to_jsonb(c) AS before_data FROM referentiel."T_ChampReferentiel" c WHERE "SchemaName"='logistique' AND "TableName"='T_PrecisionStock' AND "ColumnName"='ID_UniteFk'),
 changed AS (UPDATE referentiel."T_ChampReferentiel" SET "SupportsEntityScope"=true,"Revision"="Revision"+1,"ModifieLe"=clock_timestamp() WHERE "SchemaName"='logistique' AND "TableName"='T_PrecisionStock' AND "ColumnName"='ID_UniteFk' RETURNING *)
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData")
 SELECT 'referentiel.T_ChampReferentiel','REFERENCE_SCOPE_EVOLUTION',old.before_data,to_jsonb(changed)||jsonb_build_object('Migration','20261030_01','Motif','Précision d’une unité privée au propriétaire durable prouvé') FROM old,changed;
CREATE TRIGGER tr_catalogue_champ_integrite BEFORE INSERT OR UPDATE OR DELETE ON referentiel."T_ChampReferentiel" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_catalogue_champ_integrite();
COMMENT ON TRIGGER tr_catalogue_champ_integrite ON referentiel."T_ChampReferentiel" IS 'Catalogue et défauts fermés aux écritures ordinaires ; version alimentée par les jeux de correspondances.';

INSERT INTO referentiel."T_InterfaceTableau"("CleInterface","Module","Version","Colonnes") VALUES ('referentiels.tableaux','referentiels',1,'[{"id": "CleInterface", "label": "Tableau", "type": "text", "defaultVisible": true, "defaultOrder": 0, "defaultExportOrder": 0, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "Libelle", "label": "Libellé", "type": "text", "defaultVisible": true, "defaultOrder": 1, "defaultExportOrder": 1, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "Module", "label": "Module", "type": "text", "defaultVisible": true, "defaultOrder": 2, "defaultExportOrder": 2, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "NbColonnes", "label": "Colonnes", "type": "integer", "defaultVisible": true, "defaultOrder": 3, "defaultExportOrder": 3, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "PreferenceTableau", "label": "Tableau personnalisé", "type": "boolean", "defaultVisible": true, "defaultOrder": 4, "defaultExportOrder": 4, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "PreferenceExport", "label": "Export personnalisé", "type": "boolean", "defaultVisible": true, "defaultOrder": 5, "defaultExportOrder": 5, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "actions", "label": "Actions", "type": "text", "defaultVisible": true, "defaultOrder": 6, "defaultExportOrder": 6, "defaultExport": false, "exportable": false, "tableAvailable": true}, {"id": "Version", "label": "Version", "type": "integer", "defaultVisible": false, "defaultOrder": 7, "defaultExportOrder": 7, "defaultExport": false, "exportable": true, "tableAvailable": true}, {"id": "Actif", "label": "Actif", "type": "boolean", "defaultVisible": false, "defaultOrder": 8, "defaultExportOrder": 8, "defaultExport": false, "exportable": true, "tableAvailable": true}, {"id": "ModifieLe", "label": "Modifié le", "type": "timestamp with time zone", "defaultVisible": false, "defaultOrder": 9, "defaultExportOrder": 9, "defaultExport": false, "exportable": true, "tableAvailable": true}]'::jsonb);
COMMIT;
