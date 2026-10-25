-- Documents métier : identité de l'émetteur figée et justificatifs privés.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
CREATE TABLE logistique."T_DocumentIdentite" (
 "ID_DocumentIdentite" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "TypeObjet" text NOT NULL CHECK("TypeObjet" IN ('bon','facture','reglement','avoir')),
 "ID_Objet" bigint NOT NULL CHECK("ID_Objet">0),
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "IdentiteEmetteur" jsonb NOT NULL CHECK(jsonb_typeof("IdentiteEmetteur")='object'),
 "IdentiteTiers" jsonb,
 "RepriseHistorique" boolean NOT NULL DEFAULT false,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE("TypeObjet","ID_Objet")
);
CREATE TABLE logistique."T_PieceJustificative" (
 "ID_Piece" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "TypeObjet" text NOT NULL CHECK("TypeObjet" IN ('bon','facture','reglement','avoir')),
 "ID_Objet" bigint NOT NULL CHECK("ID_Objet">0),
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "NomFichier" varchar(180) NOT NULL CHECK(length(btrim("NomFichier"))>0),
 "MimeType" text NOT NULL CHECK("MimeType" IN ('application/pdf','image/jpeg','image/png','image/webp')),
 "TailleOctets" integer NOT NULL CHECK("TailleOctets">0 AND "TailleOctets"<=8388608),
 "Sha256" text NOT NULL CHECK("Sha256" ~ '^[a-f0-9]{64}$'),
 "Contenu" bytea NOT NULL CHECK(octet_length("Contenu")="TailleOctets"),
 "Archive" boolean NOT NULL DEFAULT false,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX ix_piece_parent ON logistique."T_PieceJustificative"("TypeObjet","ID_Objet","Archive");
CREATE INDEX ix_piece_entite ON logistique."T_PieceJustificative"("IdEntiteFk");
CREATE FUNCTION logistique.fn_entite_document(kind text,object_id bigint) RETURNS integer LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE result integer;
BEGIN
 IF kind='bon' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Commande" WHERE "ID_Commande"=object_id;
 ELSIF kind='facture' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Facture" WHERE "ID_CommandeFk"=object_id;
 ELSIF kind='reglement' THEN SELECT c."IdEntiteFk" INTO result FROM logistique."T_Reglements" p JOIN logistique."T_Commande" c ON c."CodeFacture"=p."CodeFactureFk" WHERE p."ID_Reglement"=object_id;
 ELSIF kind='avoir' AND to_regclass('logistique."T_Avoir"') IS NOT NULL THEN EXECUTE 'SELECT "IdEntiteFk" FROM logistique."T_Avoir" WHERE "ID_Avoir"=$1' INTO result USING object_id;
 END IF;
 RETURN result;
END $fn$;
CREATE FUNCTION logistique.tr_document_identite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE kind text; key_id bigint; company integer; entity jsonb; third_id bigint; third_party jsonb;
BEGIN
 kind=CASE TG_TABLE_NAME WHEN 'T_Commande' THEN 'bon' WHEN 'T_Facture' THEN 'facture' WHEN 'T_Reglements' THEN 'reglement' ELSE 'avoir' END;
 key_id=CASE kind WHEN 'bon' THEN (to_jsonb(NEW)->>'ID_Commande')::bigint WHEN 'facture' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::bigint WHEN 'reglement' THEN (to_jsonb(NEW)->>'ID_Reglement')::bigint ELSE (to_jsonb(NEW)->>'ID_Avoir')::bigint END;
 company=logistique.fn_entite_document(kind,key_id);
 IF company IS NULL THEN RETURN NEW; END IF;
 SELECT jsonb_build_object('IdEntite',"IdEntite",'NomEntite',"NomEntite",'AdresseEntite',"AdresseEntite",'EmailEntite',"EmailEntite",'PhoneEntite',"PhoneEntite") INTO entity FROM systeme."T_Entite" WHERE "IdEntite"=company;
 third_id=NULLIF(to_jsonb(NEW)->>'ID_TiersFk','')::bigint;
 IF third_id IS NULL AND kind IN ('facture','reglement','avoir') THEN
  SELECT c."ID_TiersFk" INTO third_id FROM logistique."T_Commande" c WHERE c."ID_Commande"=CASE WHEN kind='facture' THEN key_id WHEN kind='avoir' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::bigint ELSE (SELECT "ID_Commande" FROM logistique."T_Commande" WHERE "CodeFacture"=to_jsonb(NEW)->>'CodeFactureFk') END;
 END IF;
 IF third_id IS NOT NULL THEN SELECT to_jsonb(t)-ARRAY['ID_UserFk','IdUserFk','IdProfessionnelFk'] INTO third_party FROM logistique."T_Client" t WHERE t."ID_Client"=third_id AND t."IdEntiteFk"=company; END IF;
 INSERT INTO logistique."T_DocumentIdentite"("TypeObjet","ID_Objet","IdEntiteFk","IdentiteEmetteur","IdentiteTiers") VALUES(kind,key_id,company,entity,third_party) ON CONFLICT("TypeObjet","ID_Objet") DO NOTHING;
 RETURN NEW;
END $fn$;
CREATE TRIGGER document_identite_bon AFTER INSERT ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();
CREATE TRIGGER document_identite_facture AFTER INSERT ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();
CREATE TRIGGER document_identite_reglement AFTER INSERT ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();
CREATE FUNCTION logistique.tr_piece_coherente() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Les justificatifs sont archivés et conservés.' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' AND (to_jsonb(NEW)-'Archive') IS DISTINCT FROM (to_jsonb(OLD)-'Archive') THEN RAISE EXCEPTION 'Le justificatif est immuable.' USING ERRCODE='23514'; END IF;
 IF NEW."IdEntiteFk" IS DISTINCT FROM logistique.fn_entite_document(NEW."TypeObjet",NEW."ID_Objet") THEN RAISE EXCEPTION 'Justificatif hors entreprise du document.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER piece_coherence BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_PieceJustificative" FOR EACH ROW EXECUTE FUNCTION logistique.tr_piece_coherente();
CREATE FUNCTION logistique.tr_identite_document_immuable() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN RAISE EXCEPTION 'L’identité documentaire est conservée.' USING ERRCODE='23514'; END $fn$;
CREATE TRIGGER document_identite_immuable BEFORE UPDATE OR DELETE ON logistique."T_DocumentIdentite" FOR EACH ROW EXECUTE FUNCTION logistique.tr_identite_document_immuable();
-- Reprise déclarée comme historique : pas d'identité d'entreprise inventée pour les objets non résolus.
INSERT INTO logistique."T_DocumentIdentite"("TypeObjet","ID_Objet","IdEntiteFk","IdentiteEmetteur","RepriseHistorique")
 SELECT 'bon',c."ID_Commande",e."IdEntite",jsonb_build_object('IdEntite',e."IdEntite",'NomEntite',e."NomEntite",'AdresseEntite',e."AdresseEntite",'EmailEntite',e."EmailEntite",'PhoneEntite',e."PhoneEntite"),true FROM logistique."T_Commande" c JOIN systeme."T_Entite" e ON e."IdEntite"=c."IdEntiteFk";
INSERT INTO logistique."T_DocumentIdentite"("TypeObjet","ID_Objet","IdEntiteFk","IdentiteEmetteur","RepriseHistorique")
 SELECT 'facture',f."ID_CommandeFk",e."IdEntite",jsonb_build_object('IdEntite',e."IdEntite",'NomEntite',e."NomEntite",'AdresseEntite',e."AdresseEntite",'EmailEntite',e."EmailEntite",'PhoneEntite',e."PhoneEntite"),true FROM logistique."T_Facture" f JOIN systeme."T_Entite" e ON e."IdEntite"=f."IdEntiteFk";
INSERT INTO logistique."T_DocumentIdentite"("TypeObjet","ID_Objet","IdEntiteFk","IdentiteEmetteur","RepriseHistorique")
 SELECT 'reglement',p."ID_Reglement",e."IdEntite",jsonb_build_object('IdEntite',e."IdEntite",'NomEntite',e."NomEntite",'AdresseEntite',e."AdresseEntite",'EmailEntite',e."EmailEntite",'PhoneEntite',e."PhoneEntite"),true FROM logistique."T_Reglements" p JOIN logistique."T_Commande" c ON c."CodeFacture"=p."CodeFactureFk" JOIN systeme."T_Entite" e ON e."IdEntite"=c."IdEntiteFk";
CREATE VIEW logistique."V_PieceJustificative" AS SELECT "ID_Piece","TypeObjet","ID_Objet","IdEntiteFk","ID_UserFk","NomFichier","MimeType","TailleOctets","Sha256","Archive","CreeLe" FROM logistique."T_PieceJustificative";
COMMENT ON TABLE logistique."T_DocumentIdentite" IS 'Instantané privé de l’identité de l’émetteur et du tiers à la création du document ; reprises historiques signalées.';
COMMENT ON TABLE logistique."T_PieceJustificative" IS 'Justificatifs privés de documents logistiques, téléchargés après contrôle du parent et conservés après archivage.';
COMMENT ON VIEW logistique."V_PieceJustificative" IS 'Métadonnées des pièces privées, sans contenu binaire ; le service impose le périmètre du document.';
COMMENT ON FUNCTION logistique.fn_entite_document(text,bigint) IS 'Résout uniquement les types de documents autorisés et leur entreprise propriétaire durable.';
COMMENT ON FUNCTION logistique.tr_document_identite() IS 'Fige l’identité autorisée de l’entreprise et du tiers sans modifier le stock ni les montants.';
COMMENT ON FUNCTION logistique.tr_piece_coherente() IS 'Interdit les justificatifs interentreprises et la modification des fichiers déjà enregistrés.';
COMMENT ON FUNCTION logistique.tr_identite_document_immuable() IS 'Conserve les identités des documents émis.';
COMMENT ON TRIGGER document_identite_bon ON logistique."T_Commande" IS 'Identité émettrice du bon à sa création.';
COMMENT ON TRIGGER document_identite_facture ON logistique."T_Facture" IS 'Identité émettrice de la facture à son émission.';
COMMENT ON TRIGGER document_identite_reglement ON logistique."T_Reglements" IS 'Identité émettrice du reçu lors de l’enregistrement du règlement.';
COMMENT ON TRIGGER piece_coherence ON logistique."T_PieceJustificative" IS 'Fichier immuable et rattachement contrôlé au document de la même entreprise.';
COMMENT ON TRIGGER document_identite_immuable ON logistique."T_DocumentIdentite" IS 'Interdit la réécriture de l’identité historique d’un document.';
DO $comments$ DECLARE r record; BEGIN
 FOR r IN SELECT n.nspname,c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped WHERE n.nspname='logistique' AND c.relname IN ('T_DocumentIdentite','T_PieceJustificative','V_PieceJustificative') LOOP
 EXECUTE format('COMMENT ON COLUMN %I.%I.%I IS %L',r.nspname,r.relname,r.attname,CASE r.attname WHEN 'IdEntiteFk' THEN 'Entreprise propriétaire du document, indépendante du rattachement actuel du créateur.' WHEN 'Contenu' THEN 'Fichier privé limité à 8 Mo, jamais servi par un chemin public.' WHEN 'Sha256' THEN 'Empreinte du contenu binaire enregistré.' WHEN 'RepriseHistorique' THEN 'Identité reprise lors de l’installation, sans prétendre connaître l’identité antérieure.' WHEN 'Archive' THEN 'Pièce retirée du parcours actif, contenu et historique conservés.' WHEN 'IdentiteEmetteur' THEN 'Nom et coordonnées de l’entreprise figés pour l’édition du document.' WHEN 'IdentiteTiers' THEN 'Identité facultative du client ou fournisseur à la création du document.' ELSE 'Champ documentaire '||r.attname||' du justificatif ou de son identité historique.' END);
 END LOOP;
END $comments$;
COMMIT;
