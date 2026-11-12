-- Annuaire Structures : publication explicite, distincte du partage des articles.
-- Aucun compte, stock, document, prix ni classement d'entreprise existant n'est modifié.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 IF to_regclass('systeme."V_Entite_Public"') IS NULL
    OR to_regclass('systeme."V_Entite_Localisation_Detail"') IS NULL
    OR to_regprocedure('referentiel.fn_categories_champ(text,text,text,integer)') IS NULL THEN
  RAISE EXCEPTION 'Identité, localisations et référencement central des entreprises requis.';
 END IF;
END $$;

ALTER TABLE systeme."T_Entite"
 ADD COLUMN IF NOT EXISTS "VisibleAnnuaireEntite" boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS "PresentationPubliqueEntite" text;
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_constraint WHERE conrelid='systeme."T_Entite"'::regclass
               AND conname='ck_entite_presentation_publique') THEN
  ALTER TABLE systeme."T_Entite" ADD CONSTRAINT ck_entite_presentation_publique
   CHECK (char_length("PresentationPubliqueEntite")<=5000);
 END IF;
END $$;
COMMENT ON COLUMN systeme."T_Entite"."VisibleAnnuaireEntite" IS 'Autorisation explicite de publier la fiche professionnelle dans l’annuaire Structures authentifié. False par défaut, y compris pour les entreprises antérieures. Une entreprise inactive reste masquée. Indépendant du partage des articles : ce choix ne modifie aucune offre ni quantité de stock.';
COMMENT ON COLUMN systeme."T_Entite"."PresentationPubliqueEntite" IS 'Présentation professionnelle facultative de 5 000 caractères au maximum, visible seulement pour une entreprise active ayant autorisé sa publication. Texte affiché sans interprétation HTML ; aucune donnée légale, RH ou de connexion n’est déduite de cette présentation.';
COMMENT ON CONSTRAINT ck_entite_presentation_publique ON systeme."T_Entite" IS 'Limite la présentation professionnelle facultative de l’annuaire Structures à 5 000 caractères. NULL signifie absence de présentation.';
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT conname FROM pg_constraint
  WHERE conrelid='systeme."T_Entite"'::regclass AND contype='n'
   AND conkey=ARRAY[(SELECT attnum FROM pg_attribute WHERE attrelid='systeme."T_Entite"'::regclass
                     AND attname='VisibleAnnuaireEntite')]::smallint[]
 LOOP EXECUTE format('COMMENT ON CONSTRAINT %I ON systeme."T_Entite" IS %L',r.conname,
  'Le consentement de publication de la fiche entreprise est toujours explicite : true ou false, jamais une absence interprétée comme autorisation.');
 END LOOP;
END $$;

-- Contrat historique exact : six colonnes conservées dans le même ordre.
CREATE OR REPLACE VIEW systeme."V_Entite_Public" AS
 SELECT e."IdEntite",e."NomEntite",e."PhoneEntite",e."AdresseEntite",e."ValideEntite",
        jsonb_build_object('ID_Generique',g."ID_Generique",'NomGenerique',g."NomGenerique",
                           'AbrGenerique',g."AbrGenerique") AS "T_Generique"
 FROM systeme."T_Entite" e
 LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=e."IdTypeEntiteFk"
 WHERE e."ValideEntite" IS TRUE AND e."VisibleAnnuaireEntite" IS TRUE;
COMMENT ON VIEW systeme."V_Entite_Public" IS 'Projection historique à six colonnes des entreprises actives ayant explicitement publié leur fiche Structures. Nom, adresse, téléphone professionnel et type central uniquement. Le nom technique historique du parcours pharmacies ne qualifie pas toutes ces entreprises de pharmacie. Authentification, licence et droits restent contrôlés par les API.';

CREATE OR REPLACE VIEW systeme."V_StructurePublique" AS
 SELECT e."IdEntite",e."NomEntite",e."IdTypeEntiteFk",
        coalesce(nullif(t."AbrGenerique",''),t."NomGenerique")::text AS "TypeEntite",
        e."AdresseEntite",e."PhoneEntite",e."SiteWebEntite",e."PresentationPubliqueEntite",
        (e."LogoEntite" IS NOT NULL) AS "HasLogo",e."LogoMimeEntite",e."LogoSha256Entite"
 FROM systeme."T_Entite" e
 LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=e."IdTypeEntiteFk"
 WHERE e."ValideEntite" IS TRUE AND e."VisibleAnnuaireEntite" IS TRUE;
COMMENT ON VIEW systeme."V_StructurePublique" IS 'Annuaire transversal des entreprises actives dont la publication a été explicitement autorisée. Grain entreprise, projection fermée : identité professionnelle, type central déjà enregistré, coordonnées professionnelles déclarées, présentation et métadonnées du logo. Exclut comptes, données RH, e-mail, identifiants fiscaux/légaux et octets du logo. Ne prouve ni qualification médicale, agrément, horaires ni proximité. Aucune permission applicative ni publication d’article n’est accordée par cette vue.';
COMMENT ON COLUMN systeme."V_StructurePublique"."IdEntite" IS 'Identifiant de la structure publiée ; le détail et le logo doivent revérifier sa publication actuelle.';
COMMENT ON COLUMN systeme."V_StructurePublique"."NomEntite" IS 'Nom courant déclaré de l’entreprise ayant autorisé sa publication, sans requalification automatique.';
COMMENT ON COLUMN systeme."V_StructurePublique"."IdTypeEntiteFk" IS 'Valeur centrale ID_Generique déjà enregistrée sur l’entreprise. Le référencement du champ détermine la famille proposée aux nouvelles saisies.';
COMMENT ON COLUMN systeme."V_StructurePublique"."TypeEntite" IS 'Abréviation courante de la valeur centrale de type, ou son nom si elle est absente. Une ancienne valeur reste identifiable sans être réécrite.';
COMMENT ON COLUMN systeme."V_StructurePublique"."AdresseEntite" IS 'Adresse professionnelle générale déclarée par l’entreprise ; aucune géolocalisation automatique ni distance calculée.';
COMMENT ON COLUMN systeme."V_StructurePublique"."PhoneEntite" IS 'Téléphone professionnel déclaré de l’entreprise publiée, distinct des coordonnées personnelles des comptes.';
COMMENT ON COLUMN systeme."V_StructurePublique"."SiteWebEntite" IS 'Site web facultatif déclaré de l’entreprise. Son affichage ne constitue pas une validation ou un agrément.';
COMMENT ON COLUMN systeme."V_StructurePublique"."PresentationPubliqueEntite" IS 'Présentation professionnelle facultative autorisée à la publication, affichée comme texte sans interprétation HTML.';
COMMENT ON COLUMN systeme."V_StructurePublique"."HasLogo" IS 'Indique la présence du logo existant validé par les contraintes de l’identité documentaire ; ses octets sont exclus de la projection.';
COMMENT ON COLUMN systeme."V_StructurePublique"."LogoMimeEntite" IS 'Type MIME du logo validé, permettant la réponse binaire authentifiée après contrôle de publication.';
COMMENT ON COLUMN systeme."V_StructurePublique"."LogoSha256Entite" IS 'Empreinte du logo validé destinée à sa révision de lecture ; aucun contenu binaire ou chemin privé n’est exposé.';

CREATE OR REPLACE VIEW systeme."V_StructureLocalisation" AS
 SELECT s."IdEntite",
        coalesce(nullif(l."NomNiveau_5",''),nullif(l."NomNiveau_4",''),
                 nullif(l."NomNiveau_3",''),nullif(l."AdresseDetaillee",''))::text AS label,
        nullif(l."AdresseDetaillee",'')::text AS address,
        nullif(l."NomNiveau_3",'')::text AS zone,
        nullif(l."NomNiveau_4",'')::text AS area,
        nullif(l."NomNiveau_5",'')::text AS site
 FROM systeme."V_StructurePublique" s
 JOIN systeme."V_Entite_Localisation_Detail" l ON l."IdEntite"=s."IdEntite"
 WHERE l."IdEntiteLocalisation" IS NOT NULL
   AND coalesce(nullif(l."NomNiveau_5",''),nullif(l."NomNiveau_4",''),
                nullif(l."NomNiveau_3",''),nullif(l."AdresseDetaillee",'')) IS NOT NULL;
COMMENT ON VIEW systeme."V_StructureLocalisation" IS 'Lieux professionnels existants explicitement déclarés par une entreprise actuellement publiée. Grain entreprise/localisation, noms et adresse seulement ; aucune ligne fictive sans point. Exclut GPS brut, identifiant de point, auteur et historique. Les liens territoriaux absents ne sont pas inférés et aucune proximité ou présence de produits/professionnels n’est déduite.';
COMMENT ON COLUMN systeme."V_StructureLocalisation"."IdEntite" IS 'Entreprise actuellement active et publiée portant le lieu professionnel déclaré.';
COMMENT ON COLUMN systeme."V_StructureLocalisation".label IS 'Libellé déclaré le plus précis : niveau 5, sinon 4, sinon 3, sinon adresse détaillée.';
COMMENT ON COLUMN systeme."V_StructureLocalisation".address IS 'Adresse détaillée professionnelle enregistrée sur ce point, sans coordonnée de son auteur.';
COMMENT ON COLUMN systeme."V_StructureLocalisation".zone IS 'Nom du niveau 3 explicitement rattaché au point ; aucune parenté non renseignée n’est inventée.';
COMMENT ON COLUMN systeme."V_StructureLocalisation".area IS 'Nom du niveau 4 explicitement rattaché au point, sans résolution automatique d’une hiérarchie internationale.';
COMMENT ON COLUMN systeme."V_StructureLocalisation".site IS 'Nom du niveau 5 explicitement rattaché au point, sans certification ou qualification de la structure.';

-- Nomenclature commune, résolue par le champ physique ; aucun ID de famille figé.
-- Un libellé existant est conservé intégralement ; une ambiguïté impose un examen.
DO $$ DECLARE families integer[]; family_id integer; v text; matches integer; active boolean; BEGIN
 families:=referentiel.fn_categories_champ('systeme','T_Entite','IdTypeEntiteFk',NULL);
 IF coalesce(cardinality(families),0)<>1 THEN
  RAISE EXCEPTION 'Une seule famille commune active est requise pour le type d’entreprise.';
 END IF;
 family_id:=families[1];
 PERFORM FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=family_id
  AND "IdEntiteFk" IS NULL AND "ValideCategorieGenerique" IS TRUE FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'La famille de type d’entreprise doit être commune et active.';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('referentiel:valeurs:'||family_id::text,0));
 FOREACH v IN ARRAY ARRAY['Pharmacie','Dépôt pharmaceutique','Établissement de santé',
  'Agence immobilière','Promoteur immobilier','Entreprise de construction',
  'Bureau d’études','Cabinet d’architecture'] LOOP
  SELECT count(*),bool_and(g."ValideGenerique" AND g."IdEntiteFk" IS NULL
                  AND referentiel.fn_normaliser_libelle(g."NomGenerique")=referentiel.fn_normaliser_libelle(v))
   INTO matches,active FROM referentiel."T_Generique" g
   WHERE g."ID_CategorieGeneriqueFk"=family_id
    AND (referentiel.fn_normaliser_libelle(g."NomGenerique")=referentiel.fn_normaliser_libelle(v)
         OR referentiel.fn_normaliser_libelle(g."AbrGenerique")=referentiel.fn_normaliser_libelle(v));
  IF matches>1 OR (matches=1 AND active IS DISTINCT FROM true) THEN
   RAISE EXCEPTION 'Type d’entreprise ambigu, privé ou inactif : % ; aucune valeur existante modifiée.',v;
  ELSIF matches=0 THEN
   INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique",
    "ValideGenerique","IdEntiteFk") VALUES(family_id,v,v,true,NULL);
  END IF;
 END LOOP;
END $$;
COMMIT;
