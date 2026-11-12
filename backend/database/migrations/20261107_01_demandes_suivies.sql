-- Demandes suivies : une intention explicite, sans réservation ni écriture de stock.
CREATE TABLE communication."T_Demande" (
 "IdDemande" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "CodeDemande" text GENERATED ALWAYS AS ('DEM-' || "IdDemande"::text) STORED UNIQUE,
 "IdDemandeurFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "IdEntiteDemandeurFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "TypeSource" text NOT NULL CHECK ("TypeSource" IN ('product','expert','structure_n3','structure_n4','structure_n5')),
 "IdArticleFk" integer REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "IdProfessionnelFk" integer REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT,
 "IdNiveau3Fk" integer REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON DELETE RESTRICT,
 "IdNiveau4Fk" integer REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON DELETE RESTRICT,
 "IdNiveau5Fk" integer REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON DELETE RESTRICT,
 "LibelleSource" text NOT NULL,
 "IdDestinataireUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "IdEntiteDestinataireFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "SujetDemande" text NOT NULL CHECK (char_length(btrim("SujetDemande")) BETWEEN 1 AND 160),
 "DescriptionDemande" text NOT NULL CHECK (char_length(btrim("DescriptionDemande")) BETWEEN 1 AND 5000),
 "QuantiteSouhaitee" numeric(18,3) CHECK ("QuantiteSouhaitee">0),
 "UniteSouhaitee" text,
 "DestinationDemande" text CHECK (char_length("DestinationDemande")<=300),
 "EtatDemande" text NOT NULL DEFAULT 'en_attente' CHECK ("EtatDemande" IN ('en_attente','en_cours','satisfaite','non_satisfaite','annulee')),
 "VersionDemande" integer NOT NULL DEFAULT 1 CHECK ("VersionDemande">0),
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "ModifieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT demande_source_exacte CHECK (
  num_nonnulls("IdArticleFk","IdProfessionnelFk","IdNiveau3Fk","IdNiveau4Fk","IdNiveau5Fk")=1
  AND ("TypeSource"='product')=("IdArticleFk" IS NOT NULL)
  AND ("TypeSource"='expert')=("IdProfessionnelFk" IS NOT NULL)
  AND ("TypeSource"='structure_n3')=("IdNiveau3Fk" IS NOT NULL)
  AND ("TypeSource"='structure_n4')=("IdNiveau4Fk" IS NOT NULL)
  AND ("TypeSource"='structure_n5')=("IdNiveau5Fk" IS NOT NULL)),
 CONSTRAINT demande_destinataire_exact CHECK (num_nonnulls("IdDestinataireUserFk","IdEntiteDestinataireFk")=1
  AND ("TypeSource"='expert')=("IdDestinataireUserFk" IS NOT NULL)
  AND "IdDemandeurFk" IS DISTINCT FROM "IdDestinataireUserFk"),
 CONSTRAINT demande_quantite_produit CHECK ("QuantiteSouhaitee" IS NULL OR ("TypeSource"='product' AND "UniteSouhaitee" IS NOT NULL))
);
CREATE INDEX demande_demandeur_date ON communication."T_Demande" ("IdDemandeurFk","CreeLe" DESC,"IdDemande");
CREATE INDEX demande_destinataire_date ON communication."T_Demande" ("IdEntiteDestinataireFk","EtatDemande","CreeLe" DESC);
CREATE INDEX demande_professionnel_date ON communication."T_Demande" ("IdDestinataireUserFk","EtatDemande","CreeLe" DESC);

CREATE TABLE communication."T_DemandeHistorique" (
 "IdHistorique" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdDemandeFk" bigint NOT NULL REFERENCES communication."T_Demande"("IdDemande") ON DELETE RESTRICT,
 "IdAuteurFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ActionDemande" text NOT NULL CHECK ("ActionDemande" IN ('creation','transition','discussion')),
 "EtatAvant" text, "EtatApres" text NOT NULL,
 "MotifDemande" text NOT NULL DEFAULT '' CHECK (char_length("MotifDemande")<=1000),
 "CleRequete" uuid NOT NULL, "ContenuRequete" jsonb NOT NULL,
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE ("IdAuteurFk","CleRequete")
);
CREATE INDEX demande_historique_dossier ON communication."T_DemandeHistorique" ("IdDemandeFk","IdHistorique");

CREATE TABLE communication."T_RoutageStructure" (
 "TypeSource" text NOT NULL CHECK ("TypeSource" IN ('structure_n3','structure_n4','structure_n5')),
 "IdSource" integer NOT NULL,
 "IdNiveau3Fk" integer REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3") ON DELETE RESTRICT,
 "IdNiveau4Fk" integer REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4") ON DELETE RESTRICT,
 "IdNiveau5Fk" integer REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5") ON DELETE RESTRICT,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "VersionRoutage" integer NOT NULL DEFAULT 1,
 "Actif" boolean NOT NULL DEFAULT true,
 "IdVerificateurFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "ModifieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY ("TypeSource","IdSource"),
 CONSTRAINT routage_source_exacte CHECK (num_nonnulls("IdNiveau3Fk","IdNiveau4Fk","IdNiveau5Fk")=1
  AND "IdSource"=coalesce("IdNiveau3Fk","IdNiveau4Fk","IdNiveau5Fk")
  AND ("TypeSource"='structure_n3')=("IdNiveau3Fk" IS NOT NULL)
  AND ("TypeSource"='structure_n4')=("IdNiveau4Fk" IS NOT NULL)
  AND ("TypeSource"='structure_n5')=("IdNiveau5Fk" IS NOT NULL))
);
CREATE TABLE communication."T_RoutageStructureHistorique" (
 "IdHistorique" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "TypeSource" text NOT NULL, "IdSource" integer NOT NULL,
 "IdEntiteAvantFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "IdEntiteApresFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "VersionRoutage" integer NOT NULL,
 "IdAuteurFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "MotifRoutage" text NOT NULL CHECK (char_length(btrim("MotifRoutage")) BETWEEN 1 AND 1000),
 "CleRequete" uuid NOT NULL, "ContenuRequete" jsonb NOT NULL,
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE ("IdAuteurFk","CleRequete"),
 FOREIGN KEY ("TypeSource","IdSource") REFERENCES communication."T_RoutageStructure"("TypeSource","IdSource") ON DELETE RESTRICT
);

-- Les libellés catégoriels sont centralisés ; les transitions utilisent les codes stables.
DO $seed$
DECLARE c integer;
BEGIN
 SELECT "ID_CategorieGenerique" INTO c FROM referentiel."T_CategorieGenerique"
 WHERE "NomCategorieGenerique"='État demande suivie' AND "IdEntiteFk" IS NULL;
 IF c IS NULL THEN
  INSERT INTO referentiel."T_CategorieGenerique" ("NomCategorieGenerique","ModuleCategorieGenerique","ValideCategorieGenerique")
  VALUES ('État demande suivie','M_DISC',true) RETURNING "ID_CategorieGenerique" INTO c;
 END IF;
 INSERT INTO referentiel."T_Generique" ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique")
 SELECT c,v.code,v.label,true FROM (VALUES ('en_attente','En attente'),('en_cours','En cours'),
 ('satisfaite','Satisfaite'),('non_satisfaite','Non satisfaite'),('annulee','Annulée')) v(code,label)
 WHERE NOT EXISTS (SELECT FROM referentiel."T_Generique" g WHERE g."ID_CategorieGeneriqueFk"=c AND g."NomGenerique"=v.code);
END $seed$;

CREATE FUNCTION communication.fn_demande_compte_autorise(p_user integer,p_gestion boolean DEFAULT false) RETURNS boolean
LANGUAGE sql STABLE SET search_path TO pg_catalog AS $fn$
 SELECT EXISTS (
  SELECT FROM systeme."T_Utilisateurs" u
  LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk"
  JOIN systeme."T_ModuleApplication" m ON m."CodeModule"='discussions' AND m."Actif"
  LEFT JOIN systeme."T_RoleModule" r ON r."CodeModule"=m."CodeModule" AND r."IdEntiteFk"=u."IdEntiteFk" AND r."IdRoleFk"=u."IdRoleFk"
  WHERE u."IdUser"=p_user AND u."ValideUser" IS TRUE AND
   (u."Is_Admin" IS TRUE OR ((e."ValideEntite" IS TRUE OR u."IdEntiteFk" IS NULL)
    AND ((u."IdEntiteFk" IS NULL AND m."AccessibleSansEntite") OR EXISTS (
     SELECT FROM systeme."V_EntiteModuleActif" x WHERE x."IdEntiteFk"=u."IdEntiteFk" AND x."CodeModule"='discussions'))
    AND (r."IdRoleModule" IS NULL OR (r."Actif" AND r."PeutConsulter" AND (NOT p_gestion OR r."PeutGerer")))))
 )
$fn$;
CREATE FUNCTION communication.fn_demande_gestionnaire(p_user integer,p_entite integer) RETURNS boolean
LANGUAGE sql STABLE SET search_path TO pg_catalog AS $fn$
 SELECT EXISTS (SELECT FROM systeme."T_Utilisateurs" u
 LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique"=u."IdRoleFk"
 JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk" AND e."ValideEntite" IS TRUE
 WHERE u."IdUser"=p_user AND u."ValideUser" IS TRUE AND u."IdEntiteFk"=p_entite
 AND (u."Is_Admin" IS TRUE OR u."Is_staff" IS TRUE OR lower(coalesce(r."NomGenerique",'')) IN ('admin','administrateur'))
 AND communication.fn_demande_compte_autorise(p_user,false))
$fn$;
CREATE FUNCTION communication.fn_demande_participant(p_user integer,p_demande bigint) RETURNS boolean
LANGUAGE sql STABLE SET search_path TO pg_catalog AS $fn$
 SELECT communication.fn_demande_compte_autorise(p_user,false) AND EXISTS (
 SELECT FROM communication."T_Demande" d WHERE d."IdDemande"=p_demande AND (
 d."IdDemandeurFk"=p_user OR d."IdDestinataireUserFk"=p_user
 OR communication.fn_demande_gestionnaire(p_user,d."IdEntiteDestinataireFk")))
$fn$;

CREATE FUNCTION communication.fn_demande_source(p_type text,p_id integer) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path TO pg_catalog AS $fn$
DECLARE v jsonb;
BEGIN
 IF p_type='product' THEN
  SELECT jsonb_build_object('type',p_type,'id',p_id,'label',o."NomArticle",'entityId',o."IdEntite",'recipientName',o."NomEntite",
   'unit',o."Unite",'quantityDecimals',coalesce(pr."DecimalesStock",0)) INTO v
  FROM logistique."V_OffreArticle" o JOIN logistique."T_Article" a ON a."ID_Article"=o."ID_Article"
  LEFT JOIN logistique."T_PrecisionStock" pr ON pr."ID_UniteFk"=a."ID_UniteFk" WHERE o."ID_Article"=p_id;
 ELSIF p_type='expert' THEN
  SELECT jsonb_build_object('type',p_type,'id',p_id,'label',p."NomComplet",'userId',p."IdUserFk",'recipientName',p."NomComplet") INTO v
  FROM professionnel."V_Professionnel_Public" p WHERE p."IdProfessionnel"=p_id AND p."ContactAutorise" IS TRUE;
 ELSIF p_type IN ('structure_n3','structure_n4','structure_n5') THEN
  SELECT jsonb_build_object('type',p_type,'id',p_id,'label',s."NomStructure",'entityId',CASE WHEN r."Actif" AND e."IdEntite" IS NOT NULL THEN r."IdEntiteFk" END,'recipientName',CASE WHEN r."Actif" THEN e."NomEntite" END) INTO v
  FROM geolocalisation."V_StructureSanitairePublique" s
  LEFT JOIN communication."T_RoutageStructure" r ON r."TypeSource"=p_type AND r."IdSource"=p_id
  LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=r."IdEntiteFk" AND e."ValideEntite" IS TRUE
  WHERE s."NiveauStructure"=right(p_type,1)::integer AND s."ID_Structure"=p_id;
 END IF;
 RETURN v;
END $fn$;

CREATE FUNCTION communication.fn_demande_garder_historique() RETURNS trigger
LANGUAGE plpgsql SET search_path TO pg_catalog AS $fn$
BEGIN
 RAISE EXCEPTION 'L’historique des demandes ne peut pas être modifié ou supprimé.' USING ERRCODE='PDE03';
END $fn$;
CREATE TRIGGER demande_historique_immuable BEFORE UPDATE OR DELETE ON communication."T_DemandeHistorique"
FOR EACH ROW EXECUTE FUNCTION communication.fn_demande_garder_historique();
CREATE TRIGGER routage_historique_immuable BEFORE UPDATE OR DELETE ON communication."T_RoutageStructureHistorique"
FOR EACH ROW EXECUTE FUNCTION communication.fn_demande_garder_historique();

CREATE FUNCTION communication.fn_demande_proteger_identite() RETURNS trigger
LANGUAGE plpgsql SET search_path TO pg_catalog AS $fn$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une demande suivie reste dans l’historique.' USING ERRCODE='PDE03'; END IF;
 -- Une colonne générée est recalculée après BEFORE UPDATE : ne pas comparer sa valeur NEW.
 IF (to_jsonb(NEW)-ARRAY['CodeDemande','EtatDemande','VersionDemande','ModifieLe']) IS DISTINCT FROM
    (to_jsonb(OLD)-ARRAY['CodeDemande','EtatDemande','VersionDemande','ModifieLe']) THEN
  RAISE EXCEPTION 'L’identité, la source et le destinataire de la demande sont figés.' USING ERRCODE='PDE03';
 END IF;
 IF NEW."VersionDemande"<>OLD."VersionDemande"+1 OR OLD."EtatDemande" IN ('satisfaite','non_satisfaite','annulee')
 OR NOT ((OLD."EtatDemande"='en_attente' AND NEW."EtatDemande" IN ('en_cours','non_satisfaite','annulee'))
 OR (OLD."EtatDemande"='en_cours' AND NEW."EtatDemande" IN ('satisfaite','non_satisfaite','annulee'))) THEN
  RAISE EXCEPTION 'Transition incompatible avec l’état de la demande.' USING ERRCODE='PDE03';
 END IF;
 NEW."ModifieLe":=CURRENT_TIMESTAMP;
 RETURN NEW;
END $fn$;
CREATE TRIGGER demande_identite_immuable BEFORE UPDATE OR DELETE ON communication."T_Demande"
FOR EACH ROW EXECUTE FUNCTION communication.fn_demande_proteger_identite();

CREATE FUNCTION communication.fn_demande_creer(p_user integer,p_type text,p_id integer,p_sujet text,p_description text,p_quantite numeric,p_destination text,p_cle uuid)
RETURNS bigint LANGUAGE plpgsql SET search_path TO pg_catalog AS $fn$
DECLARE s jsonb; n bigint; org integer; h communication."T_DemandeHistorique"%ROWTYPE;
 payload jsonb:=jsonb_build_object('action','creation','sourceType',p_type,'sourceId',p_id,'subject',btrim(p_sujet),
 'description',btrim(p_description),'quantity',p_quantite,'destination',nullif(btrim(p_destination),''));
BEGIN
 IF NOT communication.fn_demande_compte_autorise(p_user,true) THEN RAISE EXCEPTION 'Accès Discussions requis.' USING ERRCODE='PDE02'; END IF;
 IF p_cle IS NULL OR char_length(btrim(p_sujet)) NOT BETWEEN 1 AND 160 OR char_length(btrim(p_description)) NOT BETWEEN 1 AND 5000
 OR p_sujet IS NULL OR p_description IS NULL OR p_sujet ~ '[\r\n]' OR char_length(p_destination)>300 THEN
  RAISE EXCEPTION 'Vérifiez l’objet et la description.' USING ERRCODE='PDE04'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('demande:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_DemandeHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND THEN
  IF h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
  RETURN h."IdDemandeFk";
 END IF;
 -- Le verrou de la fiche source empêche de publier une demande pendant son retrait.
 IF p_type='product' THEN
  PERFORM FROM logistique."T_Article" WHERE "ID_Article"=p_id FOR SHARE;
 ELSIF p_type='expert' THEN
  PERFORM FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=p_id FOR SHARE;
 ELSIF p_type IN ('structure_n3','structure_n4','structure_n5') THEN
  PERFORM pg_advisory_xact_lock(hashtextextended('routage:'||p_type||':'||p_id,0));
  IF p_type='structure_n3' THEN PERFORM FROM geolocalisation."T_Niveau_3" WHERE "ID_Niveau_3"=p_id FOR SHARE;
  ELSIF p_type='structure_n4' THEN PERFORM FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=p_id FOR SHARE;
  ELSE PERFORM FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=p_id FOR SHARE; END IF;
 END IF;
 s:=communication.fn_demande_source(p_type,p_id);
 IF s IS NULL THEN RAISE EXCEPTION 'Cette fiche n’est plus publiée.' USING ERRCODE='PDE01'; END IF;
 IF (s->>'userId')::integer=p_user THEN RAISE EXCEPTION 'Vous ne pouvez pas vous adresser cette demande.' USING ERRCODE='PDE04'; END IF;
 IF s->>'userId' IS NOT NULL THEN
  PERFORM FROM systeme."T_Utilisateurs" WHERE "IdUser"=(s->>'userId')::integer FOR SHARE;
  PERFORM FROM systeme."T_Entite" e JOIN systeme."T_Utilisateurs" u ON u."IdEntiteFk"=e."IdEntite"
   WHERE u."IdUser"=(s->>'userId')::integer FOR SHARE OF e;
  IF NOT communication.fn_demande_compte_autorise((s->>'userId')::integer,false) THEN RAISE EXCEPTION 'Destinataire indisponible.' USING ERRCODE='PDE03'; END IF;
 ELSIF s->>'entityId' IS NOT NULL THEN
  PERFORM FROM systeme."T_Entite" WHERE "IdEntite"=(s->>'entityId')::integer AND "ValideEntite" IS TRUE FOR SHARE;
  IF NOT FOUND OR NOT EXISTS (SELECT FROM systeme."T_Utilisateurs" u WHERE communication.fn_demande_gestionnaire(u."IdUser",(s->>'entityId')::integer)) THEN
   RAISE EXCEPTION 'Aucun gestionnaire autorisé pour cette entreprise.' USING ERRCODE='PDE03'; END IF;
 ELSE RAISE EXCEPTION 'Aucun destinataire vérifié pour cette structure.' USING ERRCODE='PDE03'; END IF;
 IF communication.fn_demande_source(p_type,p_id) IS DISTINCT FROM s THEN
  RAISE EXCEPTION 'La fiche publiée a changé pendant l’opération.' USING ERRCODE='PDE03'; END IF;
 IF p_quantite IS NOT NULL AND (p_type<>'product' OR p_quantite<=0 OR p_quantite>=1000000000000000
  OR p_quantite<>round(p_quantite,coalesce((s->>'quantityDecimals')::integer,0))) THEN
  RAISE EXCEPTION 'Quantité incompatible avec l’unité du produit.' USING ERRCODE='PDE04'; END IF;
 SELECT "IdEntiteFk" INTO org FROM systeme."T_Utilisateurs" WHERE "IdUser"=p_user FOR SHARE;
 INSERT INTO communication."T_Demande" ("IdDemandeurFk","IdEntiteDemandeurFk","TypeSource","IdArticleFk","IdProfessionnelFk","IdNiveau3Fk","IdNiveau4Fk","IdNiveau5Fk",
  "LibelleSource","IdDestinataireUserFk","IdEntiteDestinataireFk","SujetDemande","DescriptionDemande","QuantiteSouhaitee","UniteSouhaitee","DestinationDemande")
 VALUES(p_user,org,p_type,CASE WHEN p_type='product' THEN p_id END,CASE WHEN p_type='expert' THEN p_id END,
 CASE WHEN p_type='structure_n3' THEN p_id END,CASE WHEN p_type='structure_n4' THEN p_id END,CASE WHEN p_type='structure_n5' THEN p_id END,
 s->>'label',(s->>'userId')::integer,(s->>'entityId')::integer,btrim(p_sujet),btrim(p_description),p_quantite,s->>'unit',nullif(btrim(p_destination),'')) RETURNING "IdDemande" INTO n;
 INSERT INTO communication."T_DemandeHistorique" ("IdDemandeFk","IdAuteurFk","ActionDemande","EtatApres","CleRequete","ContenuRequete")
 VALUES(n,p_user,'creation','en_attente',p_cle,payload);
 RETURN n;
END $fn$;

CREATE FUNCTION communication.fn_demande_transition(p_user integer,p_id bigint,p_etat text,p_version integer,p_motif text,p_cle uuid)
RETURNS bigint LANGUAGE plpgsql SET search_path TO pg_catalog AS $fn$
DECLARE d communication."T_Demande"%ROWTYPE; h communication."T_DemandeHistorique"%ROWTYPE; requester boolean; receiver boolean;
 payload jsonb:=jsonb_build_object('action','transition','id',p_id,'state',p_etat,'version',p_version,'reason',btrim(p_motif));
BEGIN
 IF p_cle IS NULL OR NOT communication.fn_demande_compte_autorise(p_user,true) OR NOT communication.fn_demande_participant(p_user,p_id) THEN
  RAISE EXCEPTION 'Demande inaccessible.' USING ERRCODE='PDE02'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('demande:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_DemandeHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND THEN
  IF h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
  RETURN h."IdDemandeFk";
 END IF;
 SELECT * INTO d FROM communication."T_Demande" WHERE "IdDemande"=p_id FOR UPDATE;
 IF d."VersionDemande" IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Fiche modifiée par un autre utilisateur.' USING ERRCODE='PDE05'; END IF;
 requester:=d."IdDemandeurFk"=p_user;
 receiver:=coalesce(d."IdDestinataireUserFk"=p_user,false) OR communication.fn_demande_gestionnaire(p_user,d."IdEntiteDestinataireFk");
 IF p_motif IS NULL OR char_length(btrim(p_motif))>1000 OR (p_etat<>'en_cours' AND char_length(btrim(p_motif))<1) THEN RAISE EXCEPTION 'Un motif est obligatoire pour cette transition.' USING ERRCODE='PDE04'; END IF;
 IF NOT ((requester AND p_etat IN ('annulee','non_satisfaite')) OR (requester AND p_etat='satisfaite' AND d."EtatDemande"='en_cours')
 OR (receiver AND p_etat IN ('en_cours','non_satisfaite'))) THEN RAISE EXCEPTION 'Action réservée au participant autorisé.' USING ERRCODE='PDE02'; END IF;
 UPDATE communication."T_Demande" SET "EtatDemande"=p_etat,"VersionDemande"="VersionDemande"+1 WHERE "IdDemande"=p_id;
 INSERT INTO communication."T_DemandeHistorique" ("IdDemandeFk","IdAuteurFk","ActionDemande","EtatAvant","EtatApres","MotifDemande","CleRequete","ContenuRequete")
 VALUES(p_id,p_user,'transition',d."EtatDemande",p_etat,btrim(p_motif),p_cle,payload);
 RETURN p_id;
END $fn$;

CREATE FUNCTION communication.fn_demande_routage(p_user integer,p_type text,p_id integer,p_entite integer,p_version integer,p_motif text,p_cle uuid)
RETURNS integer LANGUAGE plpgsql SET search_path TO pg_catalog AS $fn$
DECLARE r communication."T_RoutageStructure"%ROWTYPE; h communication."T_RoutageStructureHistorique"%ROWTYPE; v integer;
 payload jsonb:=jsonb_build_object('action','routage','sourceType',p_type,'sourceId',p_id,'entityId',p_entite,'version',p_version,'reason',btrim(p_motif));
BEGIN
 IF NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=p_user AND "Is_Admin" IS TRUE AND "ValideUser" IS TRUE)
 OR NOT communication.fn_demande_compte_autorise(p_user,true) THEN RAISE EXCEPTION 'Administration globale requise.' USING ERRCODE='PDE02'; END IF;
 IF p_cle IS NULL OR p_type NOT IN ('structure_n3','structure_n4','structure_n5') OR p_motif IS NULL OR char_length(btrim(p_motif)) NOT BETWEEN 1 AND 1000
 THEN RAISE EXCEPTION 'Structure et motif obligatoires.' USING ERRCODE='PDE04'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('routage-requete:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_RoutageStructureHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND THEN
  IF h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
  RETURN h."VersionRoutage";
 END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('routage:'||p_type||':'||p_id,0));
 IF communication.fn_demande_source(p_type,p_id) IS NULL THEN RAISE EXCEPTION 'Structure non publiée.' USING ERRCODE='PDE01'; END IF;
 SELECT * INTO r FROM communication."T_RoutageStructure" WHERE "TypeSource"=p_type AND "IdSource"=p_id FOR UPDATE;
 IF coalesce(r."VersionRoutage",0) IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Routage modifié par un autre administrateur.' USING ERRCODE='PDE05'; END IF;
 IF p_entite IS NULL THEN
  IF r."IdEntiteFk" IS NULL THEN RAISE EXCEPTION 'Aucun routage à désactiver.' USING ERRCODE='PDE04'; END IF;
 ELSE
  PERFORM FROM systeme."T_Entite" WHERE "IdEntite"=p_entite AND "ValideEntite" IS TRUE FOR SHARE;
  IF NOT FOUND OR NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" u WHERE communication.fn_demande_gestionnaire(u."IdUser",p_entite)) THEN
   RAISE EXCEPTION 'Entreprise sans gestionnaire Discussions autorisé.' USING ERRCODE='PDE04'; END IF;
 END IF;
 v:=p_version+1;
 INSERT INTO communication."T_RoutageStructure" ("TypeSource","IdSource","IdNiveau3Fk","IdNiveau4Fk","IdNiveau5Fk","IdEntiteFk","VersionRoutage","IdVerificateurFk","Actif")
 VALUES(p_type,p_id,CASE WHEN p_type='structure_n3' THEN p_id END,CASE WHEN p_type='structure_n4' THEN p_id END,CASE WHEN p_type='structure_n5' THEN p_id END,coalesce(p_entite,r."IdEntiteFk"),v,p_user,p_entite IS NOT NULL)
 ON CONFLICT("TypeSource","IdSource") DO UPDATE SET "IdEntiteFk"=excluded."IdEntiteFk","VersionRoutage"=excluded."VersionRoutage","IdVerificateurFk"=p_user,"ModifieLe"=CURRENT_TIMESTAMP,"Actif"=excluded."Actif";
 INSERT INTO communication."T_RoutageStructureHistorique" ("TypeSource","IdSource","IdEntiteAvantFk","IdEntiteApresFk","VersionRoutage","IdAuteurFk","MotifRoutage","CleRequete","ContenuRequete")
 VALUES(p_type,p_id,r."IdEntiteFk",p_entite,v,p_user,btrim(p_motif),p_cle,payload);
 RETURN v;
END $fn$;

ALTER TABLE communication."T_Discussion" ADD COLUMN "IdDemandeFk" bigint UNIQUE REFERENCES communication."T_Demande"("IdDemande") ON DELETE RESTRICT,
 DROP CONSTRAINT "Ck_Discussion_Type", DROP CONSTRAINT "Ck_Discussion_Target",
 ADD CONSTRAINT "Ck_Discussion_Type" CHECK ("TypeDiscussion" IN ('expert','structure','user','demande')),
 ADD CONSTRAINT "Ck_Discussion_Target" CHECK (
 ("TypeDiscussion"='demande' AND "IdDemandeFk" IS NOT NULL AND "IdProfessionnelFk" IS NULL AND "IdEntiteFk" IS NULL AND "IdUserDestinataireFk" IS NULL)
 OR ("IdDemandeFk" IS NULL AND (("TypeDiscussion"='expert' AND "IdProfessionnelFk" IS NOT NULL AND "IdEntiteFk" IS NULL AND "IdUserDestinataireFk" IS NULL)
 OR ("TypeDiscussion"='structure' AND "IdEntiteFk" IS NOT NULL AND "IdProfessionnelFk" IS NULL AND "IdUserDestinataireFk" IS NULL)
 OR ("TypeDiscussion"='user' AND "IdProfessionnelFk" IS NULL AND ("IdUserClientFk" IS NULL OR "IdUserDestinataireFk" IS NULL OR "IdUserClientFk"<>"IdUserDestinataireFk")))));

-- Colonnes existantes conservées dans leur ordre ; la nouvelle clé est ajoutée à la fin de la vue.
CREATE OR REPLACE VIEW communication."V_DiscussionBoite" AS
SELECT d."IdDiscussion",d."IdUserClientFk",d."IdProfessionnelFk",d."IdEntiteFk",d."TypeDiscussion",d."SujetDiscussion",d."DateCreation",d."DernierMessageAt",d."ValideDiscussion",d."IdUserDestinataireFk",
 btrim(concat_ws(' ',u."PrenomUser",u."NomUser")) AS "NomInitiateur",
 btrim(concat_ws(' ',cible."PrenomUser",cible."NomUser")) AS "NomDestinataire",p."IdUserFk" AS "IdCompteProfessionnel",
 btrim(concat_ws(' ',expert."PrenomUser",expert."NomUser")) AS "NomProfessionnel",NULLIF(btrim(s."AbrGenerique"),'') AS "SpecialiteProfessionnel",e."NomEntite" AS "NomStructure",m."DernierMessage",d."IdDemandeFk"
FROM communication."T_Discussion" d
LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=d."IdUserClientFk"
LEFT JOIN systeme."T_Utilisateurs" cible ON cible."IdUser"=d."IdUserDestinataireFk"
LEFT JOIN professionnel."T_Professionnel" p ON p."IdProfessionnel"=d."IdProfessionnelFk"
LEFT JOIN systeme."T_Utilisateurs" expert ON expert."IdUser"=p."IdUserFk"
LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique"=p."IdSpecialiteFk"
LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=d."IdEntiteFk"
LEFT JOIN LATERAL (SELECT jsonb_build_object('IdChat',c."IdChat",'TextChat',c."TextChat",'DateChat',c."DateChat",'ChatFile',c."ChatFile",'ChatLink',c."ChatLink",'LuChat',c."LuChat",'author',jsonb_build_object('IdUser',c."IdUser",'NomUser',c."NomUser",'PrenomUser',c."PrenomUser")) AS "DernierMessage"
FROM communication."V_Chat" c WHERE c."IdDiscussionFk"=d."IdDiscussion" ORDER BY c."DateChat" DESC,c."IdChat" DESC LIMIT 1) m ON true;

CREATE FUNCTION communication.fn_demande_discussion(p_user integer,p_id bigint,p_version integer,p_cle uuid)
RETURNS integer LANGUAGE plpgsql SET search_path TO pg_catalog AS $fn$
DECLARE d communication."T_Demande"%ROWTYPE; h communication."T_DemandeHistorique"%ROWTYPE; n integer;
 payload jsonb:=jsonb_build_object('action','discussion','id',p_id,'version',p_version);
BEGIN
 IF p_cle IS NULL OR NOT communication.fn_demande_compte_autorise(p_user,true) OR NOT communication.fn_demande_participant(p_user,p_id) THEN
  RAISE EXCEPTION 'Demande inaccessible.' USING ERRCODE='PDE02'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('demande:'||p_user||':'||p_cle,0));
 SELECT * INTO h FROM communication."T_DemandeHistorique" WHERE "IdAuteurFk"=p_user AND "CleRequete"=p_cle;
 IF FOUND AND h."ContenuRequete"<>payload THEN RAISE EXCEPTION 'Clé utilisée pour une autre opération.' USING ERRCODE='PDE03'; END IF;
 SELECT * INTO d FROM communication."T_Demande" WHERE "IdDemande"=p_id FOR UPDATE;
 IF h."IdHistorique" IS NULL AND d."VersionDemande" IS DISTINCT FROM p_version THEN RAISE EXCEPTION 'Fiche modifiée par un autre utilisateur.' USING ERRCODE='PDE05'; END IF;
 SELECT "IdDiscussion" INTO n FROM communication."T_Discussion" WHERE "IdDemandeFk"=p_id;
 IF n IS NULL THEN
  INSERT INTO communication."T_Discussion" ("IdUserClientFk","TypeDiscussion","SujetDiscussion","IdDemandeFk")
  VALUES(d."IdDemandeurFk",'demande',d."CodeDemande"||' · '||d."SujetDemande",p_id) RETURNING "IdDiscussion" INTO n;
 END IF;
 IF h."IdHistorique" IS NULL THEN
  INSERT INTO communication."T_DemandeHistorique" ("IdDemandeFk","IdAuteurFk","ActionDemande","EtatAvant","EtatApres","CleRequete","ContenuRequete")
  VALUES(p_id,p_user,'discussion',d."EtatDemande",d."EtatDemande",p_cle,payload);
 END IF;
 RETURN n;
END $fn$;

CREATE VIEW communication."V_Demande" AS
SELECT d.*,coalesce(d."IdArticleFk",d."IdProfessionnelFk",d."IdNiveau3Fk",d."IdNiveau4Fk",d."IdNiveau5Fk") AS "IdSource",
 btrim(concat_ws(' ',a."PrenomUser",a."NomUser")) AS "NomDemandeur",
 CASE WHEN d."IdDestinataireUserFk" IS NOT NULL THEN btrim(concat_ws(' ',u."PrenomUser",u."NomUser")) ELSE e."NomEntite" END AS "NomDestinataire",
 g."AbrGenerique" AS "LibelleEtat",t."IdDiscussion"
FROM communication."T_Demande" d
JOIN systeme."T_Utilisateurs" a ON a."IdUser"=d."IdDemandeurFk"
LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=d."IdDestinataireUserFk"
LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=d."IdEntiteDestinataireFk"
LEFT JOIN LATERAL (SELECT v."AbrGenerique" FROM referentiel."T_Generique" v JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=v."ID_CategorieGeneriqueFk"
 WHERE c."NomCategorieGenerique"='État demande suivie' AND c."IdEntiteFk" IS NULL AND v."NomGenerique"=d."EtatDemande" ORDER BY v."ID_Generique" LIMIT 1) g ON true
LEFT JOIN communication."T_Discussion" t ON t."IdDemandeFk"=d."IdDemande";

COMMENT ON TABLE communication."T_Demande" IS 'Intention suivie, privée, issue d’une offre ou fiche publiée. Source, demandeur réel, destinataire vérifié et unité sont figés. Ne réserve aucun stock et ne crée aucune facture ni conversation.';
COMMENT ON TABLE communication."T_DemandeHistorique" IS 'Journal immuable des créations, transitions et ouvertures explicites de conversation ; protège également le rejeu exact par auteur et UUID.';
COMMENT ON TABLE communication."T_RoutageStructure" IS 'Représentation explicitement vérifiée d’un territoire par une entreprise. Aucune inférence depuis la localisation d’une entreprise.';
COMMENT ON TABLE communication."T_RoutageStructureHistorique" IS 'Versions successives et motif obligatoire de chaque routage, immuables ; un nouveau routage ne déplace jamais les anciennes demandes.';
COMMENT ON VIEW communication."V_Demande" IS 'Projection des demandes et libellés catégoriels pour le serveur, à filtrer obligatoirement par fn_demande_participant ; aucune ouverture globale des échanges privés.';
COMMENT ON COLUMN communication."T_Discussion"."IdDemandeFk" IS 'Demande suivie d’origine ; une seule conversation créée sur action explicite, sans message automatique.';
COMMENT ON TABLE communication."T_Discussion" IS 'Fils privés entre comptes, auprès d’un professionnel ou d’une entreprise, et fils explicitement rattachés à une demande suivie. Seuls les participants autorisés accèdent aux échanges.';
COMMENT ON COLUMN communication."T_Discussion"."TypeDiscussion" IS 'Canal privé : expert, structure entreprise, user interne ou demande suivie ; chaque canal impose ses clés et ses participants.';
COMMENT ON COLUMN communication."V_DiscussionBoite"."IdDemandeFk" IS 'Demande suivie liée au fil privé, si celui-ci a été ouvert explicitement.';
COMMENT ON CONSTRAINT "Ck_Discussion_Target" ON communication."T_Discussion" IS 'Contrôle les clés propres aux quatre canaux ; un fil de demande ne porte pas un destinataire déduit ou modifiable.';
COMMENT ON CONSTRAINT "Ck_Discussion_Type" ON communication."T_Discussion" IS 'Canaux privés expert, structure entreprise, user interne et demande suivie.';
COMMENT ON FUNCTION communication.fn_demande_compte_autorise(integer,boolean) IS 'Vérifie le compte actif, l’entreprise réelle et la licence/règle Discussions ; le contexte choisi dans l’interface ne change jamais l’identité.';
COMMENT ON FUNCTION communication.fn_demande_gestionnaire(integer,integer) IS 'Gestionnaire actif de l’entreprise destinataire réelle, avec accès Discussions ; un administrateur global sans rattachement réel ne devient pas participant.';
COMMENT ON FUNCTION communication.fn_demande_participant(integer,bigint) IS 'Accès privé : demandeur, destinataire professionnel figé ou gestionnaire de l’entreprise destinataire ; aucun privilège global implicite.';
COMMENT ON FUNCTION communication.fn_demande_source(text,integer) IS 'Projection publique minimale publiée et destinataire vérifié ; ne retourne ni quantité de stock exacte, coût d’achat ni coordonnées privées.';
COMMENT ON FUNCTION communication.fn_demande_garder_historique() IS 'Interdit modification et suppression des historiques de demande et de routage.';
COMMENT ON FUNCTION communication.fn_demande_proteger_identite() IS 'Fige l’identité et la source, impose les cinq états, leur sens de transition et la révision monotone ; aucun effacement des demandes.';
COMMENT ON FUNCTION communication.fn_demande_creer(integer,text,integer,text,text,numeric,text,uuid) IS 'Crée atomiquement une demande et son historique après validation de la publication, du destinataire et de la quantité exacte facultative ; rejeu sans doublon.';
COMMENT ON FUNCTION communication.fn_demande_transition(integer,bigint,text,integer,text,uuid) IS 'Transition métier avec droits du participant réel, motif, verrou, révision et rejeu exact ; historique conservé.';
COMMENT ON FUNCTION communication.fn_demande_routage(integer,text,integer,integer,integer,text,uuid) IS 'Validation globale explicite du représentant d’une structure territoriale, avec motif, concurrence et historique ; ne change pas les anciens dossiers.';
COMMENT ON FUNCTION communication.fn_demande_discussion(integer,bigint,integer,uuid) IS 'Ouvre sur action explicite une unique conversation liée à la demande pour ses participants, sans message, stock, facture ni notification automatique.';
COMMENT ON TRIGGER demande_identite_immuable ON communication."T_Demande" IS 'Préserve source et destinataire historiques et les transitions valides.';
COMMENT ON TRIGGER demande_historique_immuable ON communication."T_DemandeHistorique" IS 'Conserve les preuves de suivi et de rejeu.';
COMMENT ON TRIGGER routage_historique_immuable ON communication."T_RoutageStructureHistorique" IS 'Conserve les preuves de validation du destinataire territorial.';

DO $comments$
DECLARE r record;
BEGIN
 FOR r IN SELECT table_name,column_name FROM information_schema.columns WHERE table_schema='communication'
 AND table_name IN ('T_Demande','T_DemandeHistorique','T_RoutageStructure','T_RoutageStructureHistorique','V_Demande') LOOP
  EXECUTE format('COMMENT ON COLUMN communication.%I.%I IS %L',r.table_name,r.column_name,
   CASE r.column_name WHEN 'QuantiteSouhaitee' THEN 'Quantité souhaitée facultative, exacte à la précision de l’unité ; aucune réservation de stock.'
    WHEN 'UniteSouhaitee' THEN 'Libellé d’unité figé à la création depuis l’offre publiée ; jamais saisi par le demandeur.'
    WHEN 'ContenuRequete' THEN 'Contenu canonique privé utilisé uniquement pour reconnaître un rejeu exact ; non exposé dans les API.'
    WHEN 'IdEntiteDemandeurFk' THEN 'Entreprise réelle du demandeur à la création, indépendante de son contexte administrateur.'
    WHEN 'EtatDemande' THEN 'Code métier stable ; le libellé affiché provient de AbrGenerique, catégorie État demande suivie.'
    ELSE 'Champ persistant du suivi : '||r.column_name||'. Source et historique préservés par les fonctions métier.' END);
 END LOOP;
END $comments$;

COMMENT ON INDEX communication.demande_demandeur_date IS 'Pagination des demandes envoyées par le compte réel.';
COMMENT ON INDEX communication.demande_destinataire_date IS 'Suivi des demandes reçues par entreprise et état.';
COMMENT ON INDEX communication.demande_professionnel_date IS 'Suivi des demandes reçues par compte professionnel figé.';
COMMENT ON INDEX communication.demande_historique_dossier IS 'Lecture chronologique de l’historique d’un dossier privé.';
