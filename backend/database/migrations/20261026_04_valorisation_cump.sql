-- CUMP permanent par article / entreprise / devise ; aucun effet supplémentaire sur le stock.
-- Les anciens prix de mouvement ne sont pas assimilés silencieusement à des coûts d'achat.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors périmètre';END IF;
 IF to_regclass('logistique."T_ValorisationOuverture"') IS NOT NULL THEN RAISE EXCEPTION 'Valorisation déjà installée';END IF;
END $$;
LOCK TABLE logistique."T_Article",logistique."T_Mouvement" IN SHARE ROW EXCLUSIVE MODE;
CREATE TABLE logistique."T_ValorisationOuverture"(
 "ID_ArticleFk" integer NOT NULL REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "ID_DeviseFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ID_MvtArrete" integer NOT NULL DEFAULT 0,
 "QuantiteOuverture" numeric(14,3) NOT NULL CHECK("QuantiteOuverture">=0 OR "CoutOuverture" IS NULL),
 "CoutOuverture" numeric(22,6) CHECK("CoutOuverture">=0 AND "CoutOuverture"::text NOT IN ('NaN','Infinity','-Infinity')),
 "CoutsAnterieurs" jsonb NOT NULL DEFAULT '{}'::jsonb,
 "Version" bigint NOT NULL DEFAULT 1,
 "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY("ID_ArticleFk","ID_DeviseFk")
);
CREATE TABLE logistique."T_ValorisationEvenement"(
 "ID_Evenement" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_ArticleFk" integer NOT NULL REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ID_UserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "RequestId" uuid,
 "Operation" text NOT NULL CHECK("Operation" IN ('ouverture','reevaluation','mouvement_insert','mouvement_update','mouvement_delete')),
 "Motif" text,
 "Avant" jsonb,
 "Apres" jsonb,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE("ID_UserFk","RequestId")
);
CREATE INDEX valorisation_evenement_article ON logistique."T_ValorisationEvenement"("ID_ArticleFk","ID_Evenement");
CREATE INDEX mouvement_article_devise_ordre ON logistique."T_Mouvement"("ID_ArticleFk","ID_DeviseFk","ID_Mvt");
COMMENT ON TABLE logistique."T_ValorisationOuverture" IS 'Dernier arrêté de coût confirmé, par article, propriétaire et devise. Les articles présents avant installation restent à initialiser : aucun coût catalogue ou prix de vente historique n’est accepté implicitement.';
COMMENT ON TABLE logistique."T_ValorisationEvenement" IS 'Journal append-only des ouvertures, réévaluations et modifications de la source de valorisation ; sans mouvement physique supplémentaire. Les coûts antérieurs connus sont conservés pour valoriser les restitutions au coût de sortie.';
DO $$ DECLARE t text;c record; BEGIN
 FOREACH t IN ARRAY ARRAY['T_ValorisationOuverture','T_ValorisationEvenement'] LOOP
  FOR c IN SELECT column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name=t LOOP
   EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',t,c.column_name,
    CASE c.column_name WHEN 'CoutsAnterieurs' THEN 'Coûts unitaires prouvés des mouvements antérieurs à l’arrêté, par ID_Mvt ; permet un retour au coût de sortie historique sans prix catalogue.'
    WHEN 'ID_MvtArrete' THEN 'Dernier ID_Mvt inclus dans la quantité et le coût d’ouverture ; les événements ultérieurs suivent leur ordre d’enregistrement, même si leur date métier est antérieure.'
    WHEN 'CoutOuverture' THEN 'Coût unitaire explicitement confirmé à six décimales ; NULL signifie ouverture requise et ne vaut jamais zéro.'
    WHEN 'QuantiteOuverture' THEN 'Quantité signée du journal, dans cette devise, au moment de l’arrêté confirmé.'
    WHEN 'Avant' THEN 'Instantané JSON antérieur au changement ; contient les coûts précédents lors d’une réévaluation.'
    WHEN 'Apres' THEN 'Instantané JSON après changement ; les paramètres comptables et la source restent auditables.'
    ELSE replace(c.column_name,'Fk','')||' de valorisation ; propriété, auteur, révision ou preuve conservée dans la transaction.' END);
  END LOOP;
 END LOOP;
END $$;
-- Un arrêté provisoire est créé uniquement pour l’existant. Les nouveaux articles démarrent à zéro.
INSERT INTO logistique."T_ValorisationOuverture"("ID_ArticleFk","ID_DeviseFk","IdEntiteFk","ID_MvtArrete","QuantiteOuverture")
 SELECT a."ID_Article",m."ID_DeviseFk",a."IdEntiteFk",max(m."ID_Mvt"),sum(m."QteMvt"*CASE WHEN g."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN g."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END)
 FROM logistique."T_Article" a JOIN logistique."T_Mouvement" m ON m."ID_ArticleFk"=a."ID_Article"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeMvtFk"
 WHERE m."ID_DeviseFk" IS NOT NULL GROUP BY a."ID_Article",m."ID_DeviseFk",a."IdEntiteFk";
CREATE FUNCTION logistique.fn_cout_mouvements(p_article integer,p_devise integer)
 RETURNS TABLE("ID_Mvt" integer,"ID_ArticleFk" integer,"ID_DeviseFk" integer,"IdEntiteFk" integer,
 "QteSignee" numeric,"CoutUnitaire" numeric,"ValeurMouvement" numeric,"StockApres" numeric,"ValeurApres" numeric,"OrigineCout" text,"EtatValorisation" text)
 LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE o record;m record; q numeric:=0;v numeric:=0;cu numeric;sgn integer;known boolean:=true;arret integer:=0;costs jsonb:='{}';source_id integer;tag text;entity integer;origins jsonb:='{}';needed integer[]:=ARRAY[]::integer[];corrections integer[]:=ARRAY[]::integer[];
BEGIN
 SELECT a."IdEntiteFk" INTO entity FROM logistique."T_Article" a WHERE a."ID_Article"=p_article;
 SELECT * INTO o FROM logistique."T_ValorisationOuverture" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise;
 IF FOUND THEN q=o."QuantiteOuverture";v=q*o."CoutOuverture";known=o."CoutOuverture" IS NOT NULL;arret=o."ID_MvtArrete";costs=o."CoutsAnterieurs";END IF;
 -- Préparer les liens réellement utilisés dans cet historique, une fois par article/devise.
 -- Le calcul est relu après un futur retour : son coût d’origine sera alors mis en cache.
 WITH child_commands AS (SELECT DISTINCT x."ID_cmdFk" AS child FROM logistique."T_Mouvement" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise AND x."ID_cmdFk" IS NOT NULL),
 links AS (SELECT r."ID_CommandeRetourFk" AS child,r."ID_CommandeOrigineFk" AS origin,0 AS priority FROM logistique."T_RetourBon" r JOIN child_commands c ON c.child=r."ID_CommandeRetourFk"
 UNION ALL SELECT i."ID_CommandeAnnulationFk",i."ID_CommandeCorrectionFk",1 FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article AND i."ID_CommandeAnnulationFk" IS NOT NULL),
 chosen AS (SELECT DISTINCT ON (x.child) x.child,x.origin FROM links x ORDER BY x.child,x.priority)
 SELECT coalesce(jsonb_object_agg(x.child::text,to_jsonb((SELECT y."ID_Mvt" FROM logistique."T_Mouvement" y WHERE y."ID_cmdFk"=x.origin AND y."ID_ArticleFk"=p_article AND y."ID_DeviseFk"=p_devise ORDER BY y."ID_Mvt" LIMIT 1))),'{}'::jsonb) INTO origins FROM chosen x;
 SELECT coalesce(array_agg(DISTINCT x.value::integer) FILTER(WHERE x.value IS NOT NULL),ARRAY[]::integer[]) INTO needed FROM jsonb_each_text(origins) x;
 SELECT coalesce(array_agg(DISTINCT i."ID_CommandeCorrectionFk") FILTER(WHERE i."ID_CommandeCorrectionFk" IS NOT NULL),ARRAY[]::integer[]) INTO corrections FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article;
 FOR m IN SELECT x.*,g."AbrGenerique" AS sens FROM logistique."T_Mouvement" x JOIN referentiel."T_Generique" g ON g."ID_Generique"=x."ID_TypeMvtFk"
  WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise ORDER BY x."ID_Mvt" LOOP
  "ID_Mvt"=m."ID_Mvt";"ID_ArticleFk"=p_article;"ID_DeviseFk"=p_devise;"IdEntiteFk"=entity;
  sgn=CASE WHEN m.sens ILIKE 'entr%' THEN 1 WHEN m.sens ILIKE 'sort%' THEN -1 ELSE 0 END;
  "QteSignee"=m."QteMvt"*sgn;cu=NULL;tag=NULL;
  IF m."ID_Mvt"<=arret THEN
   "CoutUnitaire"=(costs->>m."ID_Mvt"::text)::numeric;"ValeurMouvement"="QteSignee"*"CoutUnitaire";"StockApres"=NULL;"ValeurApres"=NULL;
   "OrigineCout"='Avant arrêté';"EtatValorisation"=CASE WHEN "CoutUnitaire" IS NULL THEN 'Historique non valorisé' ELSE 'Coût conservé' END;RETURN NEXT;CONTINUE;
  END IF;
  source_id=(origins->>m."ID_cmdFk"::text)::integer;
  IF origins ? coalesce(m."ID_cmdFk"::text,'') THEN
   -- Un lien sans mouvement source reste sans coût, sans repli sur le prix commercial.
   cu=(costs->>source_id::text)::numeric;tag='Coût du mouvement d’origine';
  ELSIF sgn=1 THEN
   -- Un gain d’inventaire utilise le coût moyen, une réception son prix d’achat réel.
   IF m."ID_cmdFk"=ANY(corrections) THEN cu=CASE WHEN q>0 THEN v/q ELSE NULL END;tag='Correction d’inventaire';
   ELSE cu=m."PUMvt";tag='Prix d’achat de réception';END IF;
  ELSIF sgn=-1 THEN cu=CASE WHEN q>0 THEN v/q ELSE NULL END;tag='CUMP avant sortie';
  ELSE cu=0;tag='Sans effet de stock';END IF;
  IF NOT known OR cu IS NULL OR cu<0 OR cu::text IN ('NaN','Infinity','-Infinity') THEN known=false;END IF;
  IF known THEN v=v+"QteSignee"*cu;END IF;
  q=q+"QteSignee";
  IF q<0 OR (known AND v< -0.000000000001) THEN known=false;END IF;
  IF q=0 THEN v=0;known=true;END IF;
  IF known AND cu IS NOT NULL AND m."ID_Mvt"=ANY(needed) THEN costs=jsonb_set(costs,ARRAY[m."ID_Mvt"::text],to_jsonb(cu));END IF;
  "CoutUnitaire"=CASE WHEN known THEN cu ELSE NULL END;"ValeurMouvement"=CASE WHEN known THEN round("QteSignee"*cu,2) ELSE NULL END;
  "StockApres"=q;"ValeurApres"=CASE WHEN known THEN round(v,12) ELSE NULL END;"OrigineCout"=tag;
  "EtatValorisation"=CASE WHEN known THEN 'Calculé' WHEN o."CoutOuverture" IS NULL AND arret>0 THEN 'À initialiser' ELSE 'Coût à vérifier' END;
  RETURN NEXT;
 END LOOP;
END $$;
COMMENT ON FUNCTION logistique.fn_cout_mouvements(integer,integer) IS 'CUMP par ordre stable d’enregistrement ID_Mvt, indépendant des dates métier rétroactives. Entrées au prix d’achat ; sorties au coût moyen ; retours/annulations au coût prouvé d’origine. Calcul numeric sans conversion ; absence de coût, stock négatif par devise ou coût incohérent restent indéterminables. Aucun stock modifié.';
CREATE FUNCTION logistique.fn_revision_valorisation(p_article integer,p_devise integer,p_version bigint) RETURNS text
 LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT p_version::text||':'||md5(jsonb_build_object(
 'article',(SELECT jsonb_build_object('stock',a."QteArticle",'unite',a."ID_UniteFk",'proprietaire',a."IdEntiteFk") FROM logistique."T_Article" a WHERE a."ID_Article"=p_article),
 'mouvements',(SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY m."ID_Mvt"),'[]'::jsonb) FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=p_article AND m."ID_DeviseFk"=p_devise),
 'retours',(SELECT COALESCE(jsonb_agg(to_jsonb(r) ORDER BY r."ID_RetourBon"),'[]'::jsonb) FROM logistique."T_RetourBon" r WHERE EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=p_article AND m."ID_DeviseFk"=p_devise AND m."ID_cmdFk" IN (r."ID_CommandeOrigineFk",r."ID_CommandeRetourFk"))),
 'inventaires',(SELECT COALESCE(jsonb_agg(jsonb_build_array(i."ID_InventaireFk",i."ID_CommandeCorrectionFk",i."ID_CommandeAnnulationFk") ORDER BY i."ID_InventaireFk"),'[]'::jsonb) FROM logistique."T_InventaireLigne" i WHERE i."ID_ArticleFk"=p_article)
 )::text)
$$;
COMMENT ON FUNCTION logistique.fn_revision_valorisation(integer,integer,bigint) IS 'Révision opaque commune à la lecture et à la confirmation : arrêté, stock physique, mouvements et liens de retours/corrections qui déterminent le coût. STABLE conserve le même instantané que les positions affichées ; ne remplace pas les contrôles de droits.';

CREATE VIEW logistique."V_CoutMouvement" AS
 SELECT f."ID_Mvt",k."ID_ArticleFk",k."ID_DeviseFk",a."IdEntiteFk",f."QteSignee",round(f."CoutUnitaire",6) AS "CoutUnitaire",f."ValeurMouvement",f."StockApres",f."ValeurApres",f."OrigineCout",f."EtatValorisation",
 m."DateMvt",m."ID_cmdFk",c."CodeCmd",g."AbrGenerique" AS "DeviseCode"
 FROM (SELECT DISTINCT "ID_ArticleFk","ID_DeviseFk" FROM logistique."T_Mouvement" WHERE "ID_DeviseFk" IS NOT NULL) k
 JOIN logistique."T_Article" a ON a."ID_Article"=k."ID_ArticleFk"
 CROSS JOIN LATERAL logistique.fn_cout_mouvements(k."ID_ArticleFk",k."ID_DeviseFk") f
 JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=f."ID_Mvt" LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=m."ID_cmdFk"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=k."ID_DeviseFk";
CREATE VIEW logistique."V_ValorisationStock" AS
 WITH keys AS (SELECT "ID_ArticleFk","ID_DeviseFk" FROM logistique."T_ValorisationOuverture" UNION SELECT "ID_ArticleFk","ID_DeviseFk" FROM logistique."T_Mouvement" WHERE "ID_DeviseFk" IS NOT NULL)
 SELECT a."ID_Article",a."IdEntiteFk",k."ID_DeviseFk",g."AbrGenerique" AS "DeviseCode",a."NomArticle",
 COALESCE(l."StockApres",o."QuantiteOuverture",0) AS "QteValorisee",
 CASE WHEN l."ID_Mvt" IS NOT NULL THEN CASE WHEN l."ValeurApres" IS NULL THEN NULL WHEN l."StockApres">0 THEN round(l."ValeurApres"/l."StockApres",6) ELSE 0::numeric END ELSE o."CoutOuverture" END AS "CoutUnitaireMoyen",
 CASE WHEN l."ID_Mvt" IS NOT NULL THEN round(l."ValeurApres",2) ELSE round(o."QuantiteOuverture"*o."CoutOuverture",2) END AS "ValeurStock",
 CASE WHEN o."ID_ArticleFk" IS NOT NULL AND o."CoutOuverture" IS NULL THEN 'À initialiser' ELSE COALESCE(l."EtatValorisation",'Calculé') END AS "EtatValorisation",
 o."CoutOuverture",o."QuantiteOuverture",o."ID_MvtArrete",COALESCE(o."Version",0) AS "Version"
 FROM keys k JOIN logistique."T_Article" a ON a."ID_Article"=k."ID_ArticleFk"
 JOIN referentiel."T_Generique" g ON g."ID_Generique"=k."ID_DeviseFk"
 LEFT JOIN logistique."T_ValorisationOuverture" o ON o."ID_ArticleFk"=k."ID_ArticleFk" AND o."ID_DeviseFk"=k."ID_DeviseFk"
 LEFT JOIN LATERAL (SELECT f.* FROM logistique.fn_cout_mouvements(k."ID_ArticleFk",k."ID_DeviseFk") f WHERE f."StockApres" IS NOT NULL ORDER BY f."ID_Mvt" DESC LIMIT 1) l ON true;
COMMENT ON VIEW logistique."V_CoutMouvement" IS 'Justification commune des coûts et valeurs du journal, distincte des prix commerciaux. Une ligne par mouvement avec devise et propriétaire explicites ; les valeurs avant un arrêté sans coût prouvé restent vides.';
COMMENT ON VIEW logistique."V_ValorisationStock" IS 'Stock valorisé CUMP par article, entreprise et devise. Aucune somme multidevise ni substitution du prix catalogue. À initialiser indique un coût d’ouverture historique non confirmé.';
DO $$ DECLARE t text;c record;BEGIN FOREACH t IN ARRAY ARRAY['V_CoutMouvement','V_ValorisationStock'] LOOP
 FOR c IN SELECT column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name=t LOOP EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',t,c.column_name,c.column_name||' : valeur exacte issue du calcul CUMP, avec contexte entreprise et devise ; NULL = coût non prouvé.');END LOOP;
END LOOP;END $$;
CREATE FUNCTION logistique.proteger_valorisation() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$ BEGIN
 IF TG_TABLE_NAME='T_ValorisationEvenement' THEN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Journal de valorisation conservé' USING ERRCODE='23514';END IF;RETURN NEW;
 END IF;
 IF current_setting('logistique.allow_valuation_write',true) IS DISTINCT FROM 'on' THEN RAISE EXCEPTION 'Utilisez la procédure de valorisation motivée' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Un arrêté de coût est conservé' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_Article"=NEW."ID_ArticleFk" AND a."IdEntiteFk"=NEW."IdEntiteFk") OR
 NOT EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"=NEW."ID_DeviseFk" AND g."ID_CategorieGeneriqueFk"=42) THEN RAISE EXCEPTION 'Propriété ou devise incohérente' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND (NEW."ID_ArticleFk",NEW."ID_DeviseFk",NEW."IdEntiteFk") IS DISTINCT FROM (OLD."ID_ArticleFk",OLD."ID_DeviseFk",OLD."IdEntiteFk") THEN RAISE EXCEPTION 'Identité de valorisation immuable' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER valorisation_integrite BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_ValorisationOuverture" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_valorisation();
CREATE TRIGGER valorisation_journal_immutable BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_ValorisationEvenement" FOR EACH ROW EXECUTE FUNCTION logistique.proteger_valorisation();
CREATE FUNCTION logistique.tracer_source_cout() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE a record;m record;bound integer;BEGIN
 IF TG_OP='DELETE' THEN m=OLD;ELSE m=NEW;END IF;
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=m."ID_ArticleFk" FOR NO KEY UPDATE;
 IF TG_OP IN ('UPDATE','DELETE') THEN
  SELECT "ID_MvtArrete" INTO bound FROM logistique."T_ValorisationOuverture" WHERE "ID_ArticleFk"=OLD."ID_ArticleFk" AND "ID_DeviseFk"=OLD."ID_DeviseFk" AND "CoutOuverture" IS NOT NULL;
  IF bound IS NOT NULL AND OLD."ID_Mvt"<=bound THEN RAISE EXCEPTION 'Ce mouvement appartient à un arrêté de coût ; corrigez par un bon compensateur' USING ERRCODE='23514';END IF;
 END IF;
 INSERT INTO logistique."T_ValorisationEvenement"("ID_ArticleFk","IdEntiteFk","ID_UserFk","Operation","Avant","Apres")
 VALUES(a."ID_Article",a."IdEntiteFk",NULL,'mouvement_'||lower(TG_OP),CASE WHEN TG_OP<>'INSERT' THEN to_jsonb(OLD) END,CASE WHEN TG_OP<>'DELETE' THEN to_jsonb(NEW) END);
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END $$;
CREATE TRIGGER zz_cout_source_trace BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Mouvement" FOR EACH ROW EXECUTE FUNCTION logistique.tracer_source_cout();
CREATE FUNCTION logistique.enregistrer_cout_ouverture(p_article integer,p_devise integer,p_cout numeric,p_motif text,p_auteur integer,p_version bigint,p_request uuid,p_entite integer,p_revision text DEFAULT NULL)
 RETURNS void LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE a record;u record;o record;lastid integer;qty numeric;costs jsonb;last_request record;priorflag text;newrow jsonb;
BEGIN
 IF p_request IS NULL OR p_revision IS NULL OR p_version IS NULL OR p_version<0 OR p_cout IS NULL OR p_cout<0 OR p_cout>9999999999.999999 OR p_cout<>round(p_cout,6) OR p_cout::text IN ('NaN','Infinity','-Infinity') OR p_motif IS NULL OR length(btrim(p_motif)) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Coût, motif et demande valides requis' USING ERRCODE='23514';END IF;
 SELECT x.*,g."NomGenerique" AS role INTO u FROM systeme."T_Utilisateurs" x LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=x."IdRoleFk" WHERE x."IdUser"=p_auteur;
 IF u."ValideUser" IS NOT TRUE OR (u."Is_Admin" IS TRUE OR u."IdEntiteFk"=p_entite AND (u."Is_staff" IS TRUE OR lower(u.role) IN ('admin','administrateur'))) IS NOT TRUE THEN RAISE EXCEPTION 'Droits de valorisation requis' USING ERRCODE='42501';END IF;
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=p_article AND "IdEntiteFk"=p_entite FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Article hors entreprise' USING ERRCODE='42501';END IF;
 SELECT * INTO last_request FROM logistique."T_ValorisationEvenement" WHERE "ID_UserFk"=p_auteur AND "RequestId"=p_request;
 IF FOUND THEN
  IF last_request."ID_ArticleFk"=p_article AND (last_request."Apres"->>'ID_DeviseFk')::integer=p_devise AND (last_request."Apres"->>'CoutOuverture')::numeric=p_cout AND last_request."Motif"=btrim(p_motif) AND (last_request."Apres"->>'RevisionDemande') IS NOT DISTINCT FROM p_revision AND (last_request."Avant"->>'Version')::bigint=p_version THEN RETURN;END IF;
  RAISE EXCEPTION 'Cette demande possède un autre contenu' USING ERRCODE='23505';
 END IF;
 SELECT * INTO o FROM logistique."T_ValorisationOuverture" WHERE "ID_ArticleFk"=p_article AND "ID_DeviseFk"=p_devise;
 IF COALESCE(o."Version",0)<>p_version THEN RAISE EXCEPTION 'Valorisation modifiée : rechargez la fiche' USING ERRCODE='40001';END IF;
 IF p_revision<>logistique.fn_revision_valorisation(p_article,p_devise,p_version) THEN RAISE EXCEPTION 'La source du coût a changé : rechargez la fiche' USING ERRCODE='40001';END IF;
 SELECT coalesce(max(m."ID_Mvt"),0),coalesce(sum(m."QteMvt"*CASE WHEN g."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN g."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END),0)
 INTO lastid,qty FROM logistique."T_Mouvement" m JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeMvtFk" WHERE m."ID_ArticleFk"=p_article AND m."ID_DeviseFk"=p_devise;
 IF qty<0 THEN RAISE EXCEPTION 'Stock négatif dans cette devise : rapprochez les documents avant valorisation' USING ERRCODE='23514';END IF;
 SELECT coalesce(jsonb_object_agg(f."ID_Mvt"::text,to_jsonb(f."CoutUnitaire")) FILTER(WHERE f."CoutUnitaire" IS NOT NULL),'{}'::jsonb) INTO costs FROM logistique.fn_cout_mouvements(p_article,p_devise) f;
 priorflag=coalesce(current_setting('logistique.allow_valuation_write',true),'off');PERFORM set_config('logistique.allow_valuation_write','on',true);
 INSERT INTO logistique."T_ValorisationOuverture"("ID_ArticleFk","ID_DeviseFk","IdEntiteFk","ID_MvtArrete","QuantiteOuverture","CoutOuverture","CoutsAnterieurs") VALUES(p_article,p_devise,p_entite,lastid,qty,p_cout,costs)
 ON CONFLICT("ID_ArticleFk","ID_DeviseFk") DO UPDATE SET "ID_MvtArrete"=excluded."ID_MvtArrete","QuantiteOuverture"=excluded."QuantiteOuverture","CoutOuverture"=excluded."CoutOuverture","CoutsAnterieurs"=excluded."CoutsAnterieurs","Version"=logistique."T_ValorisationOuverture"."Version"+1,"ModifieLe"=clock_timestamp();
 PERFORM set_config('logistique.allow_valuation_write',priorflag,true);
 SELECT to_jsonb(x)||jsonb_build_object('RevisionDemande',p_revision) INTO newrow FROM logistique."T_ValorisationOuverture" x WHERE x."ID_ArticleFk"=p_article AND x."ID_DeviseFk"=p_devise;
 INSERT INTO logistique."T_ValorisationEvenement"("ID_ArticleFk","IdEntiteFk","ID_UserFk","RequestId","Operation","Motif","Avant","Apres") VALUES(p_article,p_entite,p_auteur,p_request,CASE WHEN o."CoutOuverture" IS NULL THEN 'ouverture' ELSE 'reevaluation' END,btrim(p_motif),coalesce(to_jsonb(o),'{}'::jsonb)||jsonb_build_object('Version',coalesce(o."Version",0)),newrow);
END $$;
COMMENT ON FUNCTION logistique.enregistrer_cout_ouverture(integer,integer,numeric,text,integer,bigint,uuid,integer,text) IS 'Confirme ou réévalue le stock courant dans une devise, sous verrou article, avec droit gestionnaire, motif, version et demande idempotente. Conserve les coûts prouvés antérieurs et journalise avant/après. Aucun mouvement de quantité et aucune écriture de comptabilité générale.';
COMMENT ON FUNCTION logistique.proteger_valorisation() IS 'Protège identité, devise et caractère append-only des preuves ; les arrêtés sont écrits par la procédure motivée.';
COMMENT ON FUNCTION logistique.tracer_source_cout() IS 'Trace chaque changement de source et refuse la réécriture d’un mouvement déjà inclus dans un arrêté confirmé. Les corrections postérieures restent recalculées dans les vues CUMP.';
COMMENT ON TRIGGER valorisation_integrite ON logistique."T_ValorisationOuverture" IS 'Contrôle propriétaire, devise et chemin de mise à jour motivé.';
COMMENT ON TRIGGER valorisation_journal_immutable ON logistique."T_ValorisationEvenement" IS 'Les preuves financières de valorisation ne sont jamais modifiées ni supprimées.';
COMMENT ON TRIGGER zz_cout_source_trace ON logistique."T_Mouvement" IS 'Ajoute une preuve de source sans créer de deuxième mouvement physique.';
COMMENT ON INDEX logistique.valorisation_evenement_article IS 'Historique des coûts et corrections par article, sans lecture interentreprises implicite.';
COMMENT ON INDEX logistique.mouvement_article_devise_ordre IS 'Parcours CUMP dans l’ordre d’enregistrement, par article et devise.';
COMMIT;
