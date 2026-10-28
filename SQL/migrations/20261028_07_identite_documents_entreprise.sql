-- Identité visuelle courante des entreprises, indépendante des valeurs
-- financières et identités historiques déjà conservées dans les documents.
BEGIN;
SET LOCAL lock_timeout='15s';
SET LOCAL statement_timeout='120s';
DO $preconditions$
BEGIN
 IF current_database()<>'SauverNdeko' AND left(current_database(),17)<>'sauverndeko_test_' THEN RAISE EXCEPTION 'Base cible non autorisée.';END IF;
 IF to_regprocedure('systeme.fn_identite_documentaire(integer)') IS NULL OR to_regprocedure('logistique.fn_code_bon_a_date(integer,timestamp with time zone)') IS NULL THEN RAISE EXCEPTION 'Socle documentaire et nomenclature06 requis.';END IF;
 IF EXISTS(SELECT FROM information_schema.columns WHERE table_schema='systeme' AND table_name='T_Entite' AND column_name='LogoEntite') THEN RAISE EXCEPTION 'Migration07 déjà installée : rejeu interdit.';END IF;
END $preconditions$;

ALTER TABLE systeme."T_Entite"
 ADD COLUMN "SiteWebEntite" text,
 ADD COLUMN "AfficherEnteteDocument" boolean NOT NULL DEFAULT true,
 ADD COLUMN "AfficherPiedDocument" boolean NOT NULL DEFAULT true,
 ADD COLUMN "LogoEntite" bytea,
 ADD COLUMN "LogoMimeEntite" character varying(32),
 ADD COLUMN "LogoSha256Entite" character varying(64),
 ADD COLUMN "LogoModifieLe" timestamp with time zone,
 ADD COLUMN "PhoneSecondaireEntite" character varying(20),
 ADD CONSTRAINT ck_entite_phone_secondaire CHECK("PhoneSecondaireEntite" IS NULL OR (char_length("PhoneSecondaireEntite") BETWEEN 1 AND 20 AND "PhoneSecondaireEntite"=btrim("PhoneSecondaireEntite") AND "PhoneSecondaireEntite" !~ '[[:cntrl:]]')),
 ADD CONSTRAINT ck_entite_site_web CHECK("SiteWebEntite" IS NULL OR (char_length("SiteWebEntite") BETWEEN 1 AND 255 AND "SiteWebEntite"=btrim("SiteWebEntite") AND "SiteWebEntite" ~* '^https?://[^[:space:]/?#@]+([/?#][^[:space:]]*)?$')),
 ADD CONSTRAINT ck_entite_logo_complet CHECK(num_nonnulls("LogoEntite","LogoMimeEntite","LogoSha256Entite","LogoModifieLe") IN (0,4)),
 ADD CONSTRAINT ck_entite_logo_png CHECK("LogoEntite" IS NULL OR (
  octet_length("LogoEntite") BETWEEN 45 AND 2097152
  AND "LogoMimeEntite"='image/png'
  AND substring("LogoEntite" FROM 1 FOR 8)=decode('89504e470d0a1a0a','hex')
  AND substring("LogoEntite" FROM 9 FOR 8)=decode('0000000d49484452','hex')
  AND substring("LogoEntite" FROM octet_length("LogoEntite")-11 FOR 12)=decode('0000000049454e44ae426082','hex')
  AND "LogoSha256Entite"=encode(sha256("LogoEntite"),'hex')));

-- Protéger les prochaines écritures sans réécrire ni prétendre corriger les
-- anciennes adresses éventuelles : les LF et CRLF sont des retours de ligne.
ALTER TABLE systeme."T_Entite" ADD CONSTRAINT ck_entite_adresse_documentaire
 CHECK("AdresseEntite" IS NULL OR (char_length("AdresseEntite")<=1000 AND replace(replace("AdresseEntite",E'\r\n',E'\n'),E'\n','') !~ '[[:cntrl:]]')) NOT VALID;

COMMENT ON TABLE systeme."T_Entite" IS 'Entreprises propriétaires : identité, coordonnées, licence et profil documentaire courant avec logo PNG privé, site et options d’en-tête/pied. L’identité de présentation peut évoluer sans modifier les écritures ou instantanés historiques.';
COMMENT ON COLUMN systeme."T_Entite"."SiteWebEntite" IS 'Site web facultatif actuel de l’entreprise, HTTP ou HTTPS, sans identifiants intégrés ni espace ; maximum255 caractères.';
COMMENT ON COLUMN systeme."T_Entite"."AfficherEnteteDocument" IS 'Affiche l’identité courante de l’entreprise en haut de ses PDF métier ; true par défaut. Aucun effet sur les montants et lignes historiques.';
COMMENT ON COLUMN systeme."T_Entite"."AfficherPiedDocument" IS 'Affiche le nom, les identifiants et mentions courants ainsi que la pagination dans le pied des PDF métier ; true par défaut. false supprime entièrement le pied de page.';
COMMENT ON COLUMN systeme."T_Entite"."LogoEntite" IS 'Octets PNG privés normalisés par le service après décodage image ; maximum2Mo, signature/structure externe et SHA-256 contrôlés en SQL. Jamais inclus dans les vues JSON, audits ou exports génériques.';
COMMENT ON COLUMN systeme."T_Entite"."LogoMimeEntite" IS 'MIME du logo normalisé : image/png ; NULL en l’absence de logo. Cohérent avec les trois autres champs du logo.';
COMMENT ON COLUMN systeme."T_Entite"."LogoSha256Entite" IS 'Empreinte SHA-256 hexadécimale minuscule des octets PNG exacts stockés en base ; vérifiée indépendamment par PostgreSQL.';
COMMENT ON COLUMN systeme."T_Entite"."LogoModifieLe" IS 'Horodatage serveur de la dernière installation du logo normalisé ; NULL si aucune image. Métadonnée contrôlée par le service de téléversement.';
COMMENT ON COLUMN systeme."T_Entite"."PhoneSecondaireEntite" IS 'Deuxième numéro de téléphone facultatif courant de l’entreprise ; 1 à 20 caractères sans espaces extérieurs ni contrôles. NULL signifie non renseigné.';
COMMENT ON COLUMN systeme."T_Entite"."IdentifiantsLegauxEntite" IS 'Dix identifiants déclaratifs génériques facultatifs au maximum : RCCM, NIF, identification nationale ou autre libellé/valeur. Source courante pour la présentation ; les instantanés historiques restent conservés.';
COMMENT ON COLUMN systeme."T_Entite"."MentionDocumentaireEntite" IS 'Mention courante facultative, maximum1000 caractères avec sauts de ligne ; ne modifie jamais les montants, tiers ou identités historiques conservés.';
COMMENT ON CONSTRAINT ck_entite_site_web ON systeme."T_Entite" IS 'URL de présentation facultative limitée à HTTP/HTTPS et255 caractères ; refus des espaces, contrôles et identifiants dans l’autorité.';
COMMENT ON CONSTRAINT ck_entite_phone_secondaire ON systeme."T_Entite" IS 'Téléphone secondaire facultatif limité à20 caractères, non vide, sans contrôles ni espaces avant ou après ; aucun numéro supposé ou généré.';
COMMENT ON CONSTRAINT ck_entite_logo_complet ON systeme."T_Entite" IS 'Logo absent : quatre champs NULL ; logo présent : octets, MIME, empreinte et horodatage obligatoires ensemble.';
COMMENT ON CONSTRAINT ck_entite_logo_png ON systeme."T_Entite" IS 'Signature PNG, IHDR et fin IEND, taille45octets à2Mo, MIME PNG et SHA exact ; le décodage complet et la normalisation relèvent du service image.';
COMMENT ON CONSTRAINT ck_entite_adresse_documentaire ON systeme."T_Entite" IS 'Nouvelles écritures d’adresse limitées à1000 caractères, avec LF/CRLF autorisés et autres contrôles refusés ; NOT VALID préserve les données historiques sans les réécrire.';
DO $commentaires_non_nuls$
DECLARE item record;
BEGIN
 FOR item IN SELECT conname FROM pg_constraint WHERE conrelid='systeme."T_Entite"'::regclass AND contype='n' AND conkey && ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid='systeme."T_Entite"'::regclass AND attname='AfficherEnteteDocument'),(SELECT attnum FROM pg_attribute WHERE attrelid='systeme."T_Entite"'::regclass AND attname='AfficherPiedDocument')]::smallint[] LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON systeme."T_Entite" IS %L',item.conname,'Option documentaire obligatoire ; true par défaut, false explicite pour masquer cette zone.');
 END LOOP;
END $commentaires_non_nuls$;

CREATE OR REPLACE FUNCTION systeme.fn_identite_documentaire(p_entite integer) RETURNS jsonb
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('IdEntite',"IdEntite",'NomEntite',"NomEntite",'AdresseEntite',"AdresseEntite",
  'EmailEntite',"EmailEntite",'PhoneEntite',"PhoneEntite",'IdentifiantsLegauxEntite',"IdentifiantsLegauxEntite",'MentionDocumentaireEntite',"MentionDocumentaireEntite",
  'SiteWebEntite',"SiteWebEntite",'AfficherEnteteDocument',"AfficherEnteteDocument",'AfficherPiedDocument',"AfficherPiedDocument",
  'HasLogo',"LogoEntite" IS NOT NULL,'LogoMimeEntite',"LogoMimeEntite",'LogoSha256Entite',"LogoSha256Entite",'LogoModifieLe',"LogoModifieLe",'PhoneSecondaireEntite',"PhoneSecondaireEntite")
 FROM systeme."T_Entite" WHERE "IdEntite"=p_entite
$$;
COMMENT ON FUNCTION systeme.fn_identite_documentaire(integer) IS 'Identité de présentation courante et métadonnées du logo, sans octets binaires. Source des PDF à la demande du propriétaire ; les instantanés financiers et identités antérieurs restent immuables et ne sont pas réécrits.';

CREATE OR REPLACE VIEW systeme."V_IdentiteDocumentaire" AS
 SELECT "IdEntite","NomEntite","AdresseEntite","EmailEntite","PhoneEntite","IdentifiantsLegauxEntite","MentionDocumentaireEntite",xmin::text AS "_version",
  "SiteWebEntite","AfficherEnteteDocument","AfficherPiedDocument","LogoEntite" IS NOT NULL AS "HasLogo","LogoMimeEntite","LogoSha256Entite","LogoModifieLe","PhoneSecondaireEntite"
 FROM systeme."T_Entite";
COMMENT ON VIEW systeme."V_IdentiteDocumentaire" IS 'Profil de présentation courant et révision de l’entreprise : identité, coordonnées, identifiants déclaratifs, site, options PDF et métadonnées du logo. Aucun octet binaire ; le service impose le parent et les droits de son entreprise.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."MentionDocumentaireEntite" IS 'Mention courante affichée selon le réglage du pied ; les instantanés documentaires historiques restent séparés.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."SiteWebEntite" IS 'Site web actuel de l’entreprise, facultatif et validé en SQL.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."AfficherEnteteDocument" IS 'Option persistante du haut de page PDF, activée par défaut.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."AfficherPiedDocument" IS 'Option persistante du pied de page PDF, activée par défaut.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."HasLogo" IS 'Présence d’un logo PNG courant ; les octets restent exclusivement dans T_Entite et les routes binaires autorisées.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."LogoMimeEntite" IS 'MIME du logo courant, sans contenu binaire.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."LogoSha256Entite" IS 'Version d’intégrité du logo courant, utilisable après autorisation du parent.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."LogoModifieLe" IS 'Date de dernière installation du logo courant, sans modifier les dates d’émission des documents.';
COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."PhoneSecondaireEntite" IS 'Téléphone secondaire courant facultatif de l’entreprise ; seconde coordonnée distincte du téléphone principal.';

CREATE OR REPLACE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $$
DECLARE v_type text;v_result jsonb;v_key text;v_value jsonb;v_setting_secret boolean:=false;v_decoded jsonb;v_string text;
BEGIN
 IF p_data IS NULL THEN RETURN NULL;END IF;
 v_type:=jsonb_typeof(p_data);
 IF v_type='object' THEN
  SELECT coalesce(bool_or(systeme.fn_admin_cle_sensible(value#>>'{}')),false) INTO v_setting_secret FROM jsonb_each(p_data) WHERE regexp_replace(lower(key),'[^a-z0-9]','','g')='settingkey';
  v_result:='{}'::jsonb;
  FOR v_key,v_value IN SELECT key,value FROM jsonb_each(p_data) LOOP
   IF systeme.fn_admin_cle_sensible(v_key) OR regexp_replace(lower(v_key),'[^a-z0-9]','','g')='logoentite' THEN CONTINUE;END IF;
   IF v_setting_secret AND regexp_replace(lower(v_key),'[^a-z0-9]','','g') IN ('settingvalue','settingvaluejson') THEN v_result:=v_result||jsonb_build_object(v_key,'[Masqué]');
   ELSE v_result:=v_result||jsonb_build_object(v_key,systeme.fn_audit_sans_secrets(v_value));END IF;
  END LOOP;
  RETURN v_result;
 ELSIF v_type='array' THEN
  SELECT coalesce(jsonb_agg(systeme.fn_audit_sans_secrets(value) ORDER BY ord),'[]'::jsonb) INTO v_result FROM jsonb_array_elements(p_data) WITH ORDINALITY AS a(value,ord);RETURN v_result;
 ELSIF v_type='string' THEN
  v_string:=btrim(p_data#>>'{}');
  IF left(v_string,1) IN ('{','[') THEN
   BEGIN v_decoded:=v_string::jsonb;EXCEPTION WHEN invalid_text_representation THEN RETURN p_data;END;
   RETURN systeme.fn_audit_sans_secrets(v_decoded);
  END IF;
 END IF;
 RETURN p_data;
END $$;
COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(jsonb) IS 'Nettoie récursivement secrets, anciennes images JSON encodées et octets LogoEntite ; conserve les métadonnées de logo comme SHA/MIME/date. N’effectue aucune réécriture des journaux antérieurs.';

COMMIT;
