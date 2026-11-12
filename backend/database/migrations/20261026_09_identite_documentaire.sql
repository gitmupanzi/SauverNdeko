-- Identité documentaire de l’entreprise : champs facultatifs et instantanés immuables.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
ALTER TABLE systeme."T_Entite" ADD COLUMN "IdentifiantsLegauxEntite" jsonb NOT NULL DEFAULT '[]'::jsonb,
 ADD COLUMN "MentionDocumentaireEntite" varchar(1000);
CREATE FUNCTION systeme.fn_identifiants_legaux_valides(p_value jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $fn$
DECLARE item jsonb; labels text[]:='{}'; label text; value text;
BEGIN
 IF p_value IS NULL OR jsonb_typeof(p_value)<>'array' THEN RETURN false; END IF;
 IF jsonb_array_length(p_value)>10 THEN RETURN false; END IF;
 FOR item IN SELECT jsonb_array_elements(p_value) LOOP
  IF jsonb_typeof(item)<>'object' OR (SELECT count(*) FROM jsonb_object_keys(item))<>2
     OR NOT item ?& ARRAY['libelle','valeur'] THEN RETURN false; END IF;
  IF jsonb_typeof(item->'libelle')<>'string' OR jsonb_typeof(item->'valeur')<>'string' THEN RETURN false; END IF;
  label:=item->>'libelle'; value:=item->>'valeur';
  IF char_length(btrim(label)) NOT BETWEEN 1 AND 60 OR char_length(btrim(value)) NOT BETWEEN 1 AND 180
     OR label ~ '[[:cntrl:]]' OR value ~ '[[:cntrl:]]' THEN RETURN false; END IF;
  IF lower(btrim(label))=ANY(labels) THEN RETURN false; END IF;
  labels:=array_append(labels,lower(btrim(label)));
 END LOOP;
 RETURN true;
END $fn$;
ALTER TABLE systeme."T_Entite" ADD CONSTRAINT ck_entite_identifiants_legaux
 CHECK(systeme.fn_identifiants_legaux_valides("IdentifiantsLegauxEntite"));
ALTER TABLE systeme."T_Entite" ADD CONSTRAINT ck_entite_mention_documentaire
 CHECK("MentionDocumentaireEntite" IS NULL OR replace("MentionDocumentaireEntite",E'\n','') !~ '[[:cntrl:]]');
CREATE FUNCTION systeme.fn_identite_documentaire(p_entite integer) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT jsonb_build_object('IdEntite',"IdEntite",'NomEntite',"NomEntite",'AdresseEntite',"AdresseEntite",
 'EmailEntite',"EmailEntite",'PhoneEntite',"PhoneEntite",'IdentifiantsLegauxEntite',"IdentifiantsLegauxEntite",
 'MentionDocumentaireEntite',"MentionDocumentaireEntite") FROM systeme."T_Entite" WHERE "IdEntite"=p_entite
$fn$;
CREATE VIEW systeme."V_IdentiteDocumentaire" AS
 SELECT "IdEntite","NomEntite","AdresseEntite","EmailEntite","PhoneEntite","IdentifiantsLegauxEntite",
 "MentionDocumentaireEntite",xmin::text AS "_version" FROM systeme."T_Entite";
CREATE OR REPLACE FUNCTION logistique.tr_document_identite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE kind text; key_id bigint; company integer; entity jsonb; third_id bigint; third_party jsonb;
BEGIN
 kind=CASE TG_TABLE_NAME WHEN 'T_Commande' THEN 'bon' WHEN 'T_Facture' THEN 'facture' WHEN 'T_Reglements' THEN 'reglement' ELSE 'avoir' END;
 key_id=CASE kind WHEN 'bon' THEN (to_jsonb(NEW)->>'ID_Commande')::bigint WHEN 'facture' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::bigint WHEN 'reglement' THEN (to_jsonb(NEW)->>'ID_Reglement')::bigint ELSE (to_jsonb(NEW)->>'ID_Avoir')::bigint END;
 company=logistique.fn_entite_document(kind,key_id);
 IF company IS NULL THEN RETURN NEW; END IF;
 entity:=systeme.fn_identite_documentaire(company);
 third_id=NULLIF(to_jsonb(NEW)->>'ID_TiersFk','')::bigint;
 IF third_id IS NULL AND kind IN ('facture','reglement','avoir') THEN
  SELECT c."ID_TiersFk" INTO third_id FROM logistique."T_Commande" c WHERE c."ID_Commande"=CASE WHEN kind='facture' THEN key_id WHEN kind='avoir' THEN (to_jsonb(NEW)->>'ID_CommandeFk')::bigint ELSE (SELECT "ID_Commande" FROM logistique."T_Commande" WHERE "CodeFacture"=to_jsonb(NEW)->>'CodeFactureFk') END;
 END IF;
 IF third_id IS NOT NULL THEN SELECT to_jsonb(t)-ARRAY['ID_UserFk','IdUserFk','IdProfessionnelFk'] INTO third_party FROM logistique."T_Client" t WHERE t."ID_Client"=third_id AND t."IdEntiteFk"=company; END IF;
 INSERT INTO logistique."T_DocumentIdentite"("TypeObjet","ID_Objet","IdEntiteFk","IdentiteEmetteur","IdentiteTiers") VALUES(kind,key_id,company,entity,third_party) ON CONFLICT("TypeObjet","ID_Objet") DO NOTHING;
 RETURN NEW;
END $fn$;
COMMENT ON COLUMN systeme."T_Entite"."IdentifiantsLegauxEntite" IS 'Identifiants déclarés par l’entreprise, sans pays ni régime fiscal imposé : liste facultative de dix couples libelle/valeur. Figés lors de la création de chaque nouveau document.';
COMMENT ON COLUMN systeme."T_Entite"."MentionDocumentaireEntite" IS 'Mention libre facultative de l’émetteur, limitée à 1000 caractères, conservée dans les nouveaux instantanés documentaires. Aucun taux ou texte légal n’est inventé.';
COMMENT ON FUNCTION systeme.fn_identifiants_legaux_valides(jsonb) IS 'Contrôle la structure, les longueurs, les libellés uniques et les caractères de contrôle des identifiants déclaratifs, y compris en SQL direct.';
COMMENT ON FUNCTION systeme.fn_identite_documentaire(integer) IS 'Source canonique de l’identité documentaire actuelle d’une entreprise. Ne modifie jamais les identités déjà émises.';
COMMENT ON VIEW systeme."V_IdentiteDocumentaire" IS 'Profil documentaire courant et révision de l’entreprise. Le service impose une entreprise active et les droits de gestion ; les documents émis lisent leurs instantanés.';
COMMENT ON CONSTRAINT ck_entite_mention_documentaire ON systeme."T_Entite" IS 'Mention documentaire sans caractères de contrôle, à l’exception du saut de ligne pour sa mise en forme.';
COMMENT ON CONSTRAINT ck_entite_identifiants_legaux ON systeme."T_Entite" IS 'Identifiants facultatifs génériques, sans doublon de libellé ni structure JSON arbitraire.';
COMMENT ON FUNCTION logistique.tr_document_identite() IS 'Fige le profil documentaire canonique et le tiers à la création seulement ; les instantanés existants, stocks et montants restent inchangés.';
DO $comments$
DECLARE r record;
BEGIN
 FOR r IN SELECT column_name FROM information_schema.columns WHERE table_schema='systeme' AND table_name='V_IdentiteDocumentaire' LOOP
 EXECUTE format('COMMENT ON COLUMN systeme."V_IdentiteDocumentaire".%I IS %L',r.column_name,
 CASE r.column_name WHEN '_version' THEN 'Révision opaque du profil, obligatoire avant modification concurrente.' WHEN 'IdEntite' THEN 'Entreprise propriétaire dont le profil est consulté.' WHEN 'IdentifiantsLegauxEntite' THEN 'Couples libelle/valeur facultatifs déclarés par l’entreprise.' WHEN 'MentionDocumentaireEntite' THEN 'Mention libre reprise uniquement par les nouveaux documents.' ELSE 'Valeur actuelle '||r.column_name||' de l’entreprise émettrice.' END);
 END LOOP;
END $comments$;
COMMIT;
