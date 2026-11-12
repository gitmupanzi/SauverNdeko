ALTER TABLE logistique."T_Immobilisation"
 ADD COLUMN "DateMiseEnService" date,
 ADD CONSTRAINT ck_immobilisation_mise_en_service CHECK (
  "DateMiseEnService" IS NULL OR (
   isfinite("DateMiseEnService") AND
   ("DateAcquisition" IS NULL OR "DateMiseEnService">="DateAcquisition")
  )
 );
COMMENT ON COLUMN logistique."T_Immobilisation"."DateMiseEnService" IS 'Date facultative de mise en service déclarée. Distincte de l’acquisition, de l’entrée au registre et du départ du plan d’amortissement.';
COMMENT ON CONSTRAINT ck_immobilisation_mise_en_service ON logistique."T_Immobilisation" IS 'La mise en service ne peut pas précéder l’acquisition lorsque les deux dates sont connues.';

ALTER TABLE logistique."T_PieceJustificative" DROP CONSTRAINT "T_PieceJustificative_TypeObjet_check";
ALTER TABLE logistique."T_PieceJustificative" ADD CONSTRAINT "T_PieceJustificative_TypeObjet_check"
 CHECK ("TypeObjet" IN ('bon','facture','reglement','avoir','support','immobilisation'));
COMMENT ON CONSTRAINT "T_PieceJustificative_TypeObjet_check" ON logistique."T_PieceJustificative" IS 'Types autorisés de justificatifs privés, dont les immobilisations ; la cohérence du propriétaire est contrôlée par le trigger.';
COMMENT ON COLUMN logistique."T_PieceJustificative"."TypeObjet" IS 'Type métier du parent : bon, facture, règlement, avoir, dossier Support ou immobilisation.';

CREATE OR REPLACE FUNCTION logistique.fn_entite_document(kind text,object_id bigint) RETURNS integer
LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE result integer;
BEGIN
 IF kind='bon' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Commande" WHERE "ID_Commande"=object_id;
 ELSIF kind='facture' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Facture" WHERE "ID_CommandeFk"=object_id;
 ELSIF kind='reglement' THEN SELECT c."IdEntiteFk" INTO result FROM logistique."T_Reglements" p JOIN logistique."T_Commande" c ON c."CodeFacture"=p."CodeFactureFk" WHERE p."ID_Reglement"=object_id;
 ELSIF kind='avoir' AND to_regclass('logistique."T_Avoir"') IS NOT NULL THEN EXECUTE 'SELECT "IdEntiteFk" FROM logistique."T_Avoir" WHERE "ID_Avoir"=$1' INTO result USING object_id;
 ELSIF kind='support' THEN SELECT "IdEntiteFk" INTO result FROM support."T_Support" WHERE "ID_Support"=object_id;
 ELSIF kind='immobilisation' THEN SELECT "IdEntiteFk" INTO result FROM logistique."T_Immobilisation" WHERE "ID_Immobilisation"=object_id;
 END IF;
 RETURN result;
END $$;
COMMENT ON FUNCTION logistique.fn_entite_document(text,bigint) IS 'Résout l’entreprise propriétaire des documents autorisés, dont l’immobilisation, pour le stockage privé partagé des justificatifs.';

CREATE TABLE logistique."T_ImmobilisationEvenement" (
 "ID_Evenement" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_ImmobilisationFk" integer NOT NULL REFERENCES logistique."T_Immobilisation"("ID_Immobilisation") ON DELETE RESTRICT,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "TypeEvenement" text NOT NULL,
 "DateEvenement" date NOT NULL,
 "Motif" text NOT NULL,
 "Observation" text,
 "QuantiteComptee" numeric,
 "QuantiteTheorique" numeric,
 "ID_PieceFk" bigint REFERENCES logistique."T_PieceJustificative"("ID_Piece") ON DELETE RESTRICT,
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "CreeLe" timestamptz NOT NULL,
 "RequestId" uuid NOT NULL,
 "PayloadHash" text NOT NULL,
 CONSTRAINT ck_immobilisation_evenement_type CHECK ("TypeEvenement" IN ('ENTRETIEN','INVENTAIRE','CESSION','REBUT')),
 CONSTRAINT ck_immobilisation_evenement_date CHECK (isfinite("DateEvenement")),
 CONSTRAINT ck_immobilisation_evenement_texte CHECK (
  char_length("Motif") BETWEEN 1 AND 1000 AND "Motif"=btrim("Motif") AND "Motif" !~ '[[:cntrl:]]'
  AND ("Observation" IS NULL OR (
   char_length("Observation")<=4000
   AND replace(replace("Observation",E'\r\n',E'\n'),E'\n','') !~ '[[:cntrl:]]'
  ))
 ),
 CONSTRAINT ck_immobilisation_evenement_comptage CHECK (
  ("TypeEvenement"='INVENTAIRE' AND "QuantiteComptee" IS NOT NULL AND "QuantiteTheorique" IS NOT NULL
    AND "QuantiteComptee">=0 AND "QuantiteComptee"<=999999999999999999 AND "QuantiteComptee"=trunc("QuantiteComptee")
    AND "QuantiteTheorique">0 AND "QuantiteTheorique"<=999999999999999999 AND "QuantiteTheorique"=trunc("QuantiteTheorique"))
  OR ("TypeEvenement"<>'INVENTAIRE' AND "QuantiteComptee" IS NULL AND "QuantiteTheorique" IS NULL)
 ),
 CONSTRAINT ck_immobilisation_evenement_empreinte CHECK ("PayloadHash" ~ '^[0-9a-f]{64}$'),
 CONSTRAINT uq_immobilisation_evenement_requete UNIQUE ("IdEntiteFk","ID_UserFk","RequestId")
);
CREATE UNIQUE INDEX uq_immobilisation_sortie ON logistique."T_ImmobilisationEvenement"("ID_ImmobilisationFk")
 WHERE "TypeEvenement" IN ('CESSION','REBUT');
CREATE INDEX ix_immobilisation_evenement_historique
 ON logistique."T_ImmobilisationEvenement"("ID_ImmobilisationFk","DateEvenement" DESC,"ID_Evenement" DESC);
CREATE INDEX ix_immobilisation_evenement_piece
 ON logistique."T_ImmobilisationEvenement"("ID_PieceFk") WHERE "ID_PieceFk" IS NOT NULL;

COMMENT ON TABLE logistique."T_ImmobilisationEvenement" IS 'Registre des événements physiques du patrimoine : entretiens, constats d’inventaire et sorties définitives. Les affectations restent dans l’audit de la fiche. Chaque événement est conservé avec son auteur et son justificatif éventuel.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."ID_Evenement" IS 'Identifiant technique immuable de l’événement physique.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."ID_ImmobilisationFk" IS 'Bien auquel appartient exclusivement l’événement.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."IdEntiteFk" IS 'Entreprise du bien, contrôlée sous verrou lors de l’écriture.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."TypeEvenement" IS 'Nature de l’événement : ENTRETIEN, INVENTAIRE, CESSION ou REBUT.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."DateEvenement" IS 'Date civile de réalisation du fait physique, distincte de son enregistrement.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."Motif" IS 'Motif obligatoire en une ligne, limité à 1 000 caractères.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."Observation" IS 'Note facultative de 4 000 caractères au maximum.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."QuantiteComptee" IS 'Nombre entier d’unités constaté lors d’un inventaire physique, zéro compris.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."QuantiteTheorique" IS 'Quantité théorique de la fiche à l’enregistrement du comptage, figée par le serveur sous verrou du bien.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."ID_PieceFk" IS 'Justificatif privé facultatif de l’événement, nécessairement rattaché au même bien.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."ID_UserFk" IS 'Auteur actif issu du contexte d’écriture transactionnel.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."CreeLe" IS 'Horodatage serveur de l’enregistrement de l’événement.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."RequestId" IS 'Identifiant de requête fourni pour reconnaître un rejeu au sein d’une entreprise et d’un auteur.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenement"."PayloadHash" IS 'Empreinte du contenu de la requête calculée par le service pour distinguer rejeu et modification.';
COMMENT ON CONSTRAINT ck_immobilisation_evenement_type ON logistique."T_ImmobilisationEvenement" IS 'Liste fermée des faits physiques pris en charge.';
COMMENT ON CONSTRAINT ck_immobilisation_evenement_date ON logistique."T_ImmobilisationEvenement" IS 'Date civile finie obligatoire.';
COMMENT ON CONSTRAINT ck_immobilisation_evenement_texte ON logistique."T_ImmobilisationEvenement" IS 'Motif lisible, taille des champs et absence de caractères de contrôle hors sauts de ligne dans la note.';
COMMENT ON CONSTRAINT ck_immobilisation_evenement_comptage ON logistique."T_ImmobilisationEvenement" IS 'Quantités entières positives ou nulles selon leur nature, réservées aux constats d’inventaire.';
COMMENT ON CONSTRAINT ck_immobilisation_evenement_empreinte ON logistique."T_ImmobilisationEvenement" IS 'Format hexadécimal de l’empreinte SHA-256 de la requête.';
COMMENT ON CONSTRAINT uq_immobilisation_evenement_requete ON logistique."T_ImmobilisationEvenement" IS 'Une seule requête d’événement par entreprise et auteur.';
COMMENT ON INDEX logistique.uq_immobilisation_sortie IS 'Une seule sortie physique pour la totalité d’une fiche individuelle ou d’un lot homogène.';
COMMENT ON INDEX logistique.ix_immobilisation_evenement_historique IS 'Historique du bien ordonné par date du fait puis par identifiant stable.';
COMMENT ON INDEX logistique.ix_immobilisation_evenement_piece IS 'Recherche des événements qui citent un justificatif privé.';

CREATE FUNCTION logistique.tr_immobilisation_evenement_verifier() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE
 bien logistique."T_Immobilisation"%ROWTYPE;
 acteur integer:=systeme.fn_admin_actor_user_id();
 entite_acteur integer;
 admin_acteur boolean;
 sortie boolean;
BEGIN
 IF TG_OP<>'INSERT' THEN
  RAISE EXCEPTION 'Un événement du patrimoine est conservé dans l’historique.' USING ERRCODE='23514';
 END IF;
 SELECT * INTO bien FROM logistique."T_Immobilisation"
  WHERE "ID_Immobilisation"=NEW."ID_ImmobilisationFk" FOR UPDATE;
 IF NOT FOUND OR bien."IdEntiteFk" IS DISTINCT FROM NEW."IdEntiteFk" THEN
  RAISE EXCEPTION 'Bien hors entreprise de l’événement.' USING ERRCODE='42501';
 END IF;
 IF acteur IS NULL THEN
  RAISE EXCEPTION 'Auteur actif requis pour enregistrer un événement.' USING ERRCODE='42501';
 END IF;
 SELECT "IdEntiteFk","Is_Admin" INTO entite_acteur,admin_acteur
  FROM systeme."T_Utilisateurs" WHERE "IdUser"=acteur AND "ValideUser" FOR SHARE;
 IF NOT FOUND OR (admin_acteur IS NOT TRUE AND entite_acteur IS DISTINCT FROM bien."IdEntiteFk") THEN
  RAISE EXCEPTION 'Entreprise du bien hors périmètre de son auteur.' USING ERRCODE='42501';
 END IF;
 IF NOT bien."Actif" THEN
  RAISE EXCEPTION 'Restaurez la fiche archivée avant d’ajouter un événement.' USING ERRCODE='23514';
 END IF;
 IF EXISTS (
  SELECT FROM logistique."T_ImmobilisationEvenement"
  WHERE "ID_ImmobilisationFk"=bien."ID_Immobilisation" AND "TypeEvenement" IN ('CESSION','REBUT')
 ) THEN
  RAISE EXCEPTION 'Une sortie a déjà été enregistrée pour ce bien.' USING ERRCODE='23514';
 END IF;

 sortie:=NEW."TypeEvenement" IN ('CESSION','REBUT');
 IF NEW."DateEvenement">(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date THEN
  RAISE EXCEPTION 'La date de l’événement doit être aujourd’hui ou antérieure.' USING ERRCODE='23514';
 END IF;
 IF NEW."DateEvenement"<bien."DateAcquisition" THEN
  RAISE EXCEPTION 'La date de l’événement ne peut pas précéder l’acquisition.' USING ERRCODE='23514';
 END IF;
 IF sortie AND (NEW."DateEvenement"<bien."DateMiseEnService" OR EXISTS (
  SELECT FROM logistique."T_ImmobilisationEvenement"
  WHERE "ID_ImmobilisationFk"=bien."ID_Immobilisation" AND "DateEvenement">NEW."DateEvenement"
 )) THEN
  RAISE EXCEPTION 'La sortie doit suivre la mise en service et les événements déjà enregistrés.' USING ERRCODE='23514';
 END IF;

 IF NEW."ID_PieceFk" IS NOT NULL THEN
  PERFORM FROM logistique."T_PieceJustificative"
   WHERE "ID_Piece"=NEW."ID_PieceFk" AND "TypeObjet"='immobilisation'
    AND "ID_Objet"=bien."ID_Immobilisation" AND "IdEntiteFk"=bien."IdEntiteFk" AND NOT "Archive"
   FOR SHARE;
  IF NOT FOUND THEN
   RAISE EXCEPTION 'Choisissez un justificatif actif du même bien.' USING ERRCODE='23503';
  END IF;
 END IF;

 NEW."QuantiteTheorique":=CASE WHEN NEW."TypeEvenement"='INVENTAIRE' THEN bien."Quantite" END;
 NEW."ID_UserFk":=acteur;
 NEW."CreeLe":=clock_timestamp();
 RETURN NEW;
END $$;

CREATE TRIGGER a_immobilisation_evenement_verifier
 BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_ImmobilisationEvenement"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_evenement_verifier();
COMMENT ON FUNCTION logistique.tr_immobilisation_evenement_verifier() IS 'Sérialise l’écriture sur le bien, vérifie entreprise, auteur, chronologie, justificatif et sortie unique, puis fige le constat et ses métadonnées.';
COMMENT ON TRIGGER a_immobilisation_evenement_verifier ON logistique."T_ImmobilisationEvenement" IS 'Garde les événements physiques immuables et contrôle tout ajout avant enregistrement.';

CREATE FUNCTION logistique.tr_immobilisation_cycle_verifier() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS (
  SELECT FROM logistique."T_ImmobilisationEvenement"
  WHERE "ID_ImmobilisationFk"=OLD."ID_Immobilisation" AND "TypeEvenement" IN ('CESSION','REBUT')
 ) AND (to_jsonb(NEW)-ARRAY['Actif','ModifieLe','ModifieParUserFk'])
  IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['Actif','ModifieLe','ModifieParUserFk']) THEN
  RAISE EXCEPTION 'La fiche d’un bien sorti est conservée telle qu’à sa sortie.' USING ERRCODE='23514';
 END IF;
 IF NEW."DateAcquisition" IS DISTINCT FROM OLD."DateAcquisition" AND EXISTS (
  SELECT FROM logistique."T_ImmobilisationEvenement"
  WHERE "ID_ImmobilisationFk"=OLD."ID_Immobilisation" AND "DateEvenement"<NEW."DateAcquisition"
 ) THEN
  RAISE EXCEPTION 'La date d’acquisition doit précéder les événements déjà enregistrés.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER b_immobilisation_cycle_verifier BEFORE UPDATE ON logistique."T_Immobilisation"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_cycle_verifier();
COMMENT ON FUNCTION logistique.tr_immobilisation_cycle_verifier() IS 'Protège la chronologie du registre et fige les données métier dès la sortie physique. La fiche peut être archivée ou restaurée administrativement.';
COMMENT ON TRIGGER b_immobilisation_cycle_verifier ON logistique."T_Immobilisation" IS 'Contrôle la compatibilité des modifications du bien avec ses événements physiques.';

CREATE FUNCTION logistique.tr_immobilisation_justificatif_conserver() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF NEW."TypeObjet"='immobilisation' AND NEW."Archive" AND NOT OLD."Archive" THEN
  IF EXISTS (SELECT FROM logistique."T_ImmobilisationEvenement" WHERE "ID_PieceFk"=NEW."ID_Piece") THEN
   RAISE EXCEPTION 'Ce justificatif est lié à un événement et reste consultable dans l’historique.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER immobilisation_justificatif_conserver BEFORE UPDATE OF "Archive" ON logistique."T_PieceJustificative"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_justificatif_conserver();
COMMENT ON FUNCTION logistique.tr_immobilisation_justificatif_conserver() IS 'Conserve en consultation les justificatifs cités dans un événement physique.';
COMMENT ON TRIGGER immobilisation_justificatif_conserver ON logistique."T_PieceJustificative" IS 'Empêche l’archivage d’un justificatif d’immobilisation déjà cité dans le registre physique.';

CREATE VIEW logistique."V_ImmobilisationEvenement" AS
 SELECT ev."ID_Evenement",ev."ID_ImmobilisationFk",ev."IdEntiteFk",ev."TypeEvenement",
  ev."DateEvenement",ev."Motif",ev."Observation",ev."QuantiteComptee",ev."QuantiteTheorique",
  ev."ID_PieceFk",ev."ID_UserFk",ev."CreeLe",
  ev."QuantiteComptee"-ev."QuantiteTheorique" AS "EcartInventaire",
  nullif(concat_ws(' ',u."PrenomUser",u."NomUser"),'') AS "Auteur",p."NomFichier"
 FROM logistique."T_ImmobilisationEvenement" ev
 LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=ev."ID_UserFk"
 LEFT JOIN logistique."V_PieceJustificative" p ON p."ID_Piece"=ev."ID_PieceFk";
COMMENT ON VIEW logistique."V_ImmobilisationEvenement" IS 'Événements physiques avec écart d’inventaire calculé, nom de l’auteur et nom du justificatif, sans contenu binaire ni clés de rejeu.';
COMMENT ON COLUMN logistique."V_ImmobilisationEvenement"."EcartInventaire" IS 'Quantité comptée moins quantité théorique figée. Un écart ne modifie pas automatiquement la quantité de la fiche.';
COMMENT ON COLUMN logistique."V_ImmobilisationEvenement"."Auteur" IS 'Nom et prénom de l’auteur, sans autre donnée personnelle.';
COMMENT ON COLUMN logistique."V_ImmobilisationEvenement"."NomFichier" IS 'Nom du justificatif lié, sans son contenu.';

CREATE OR REPLACE VIEW logistique."V_Immobilisation" AS
 SELECT i."ID_Immobilisation",i."IdEntiteFk",i."CodeImmobilisation",i."NomImmobilisation",
  i."Reference",i."Caracteristiques",i."SuiviIndividuel",i."Quantite",i."PrixUnitaire",i."ID_DeviseFk",
  i."ID_CategorieFk",i."ID_EtatFk",i."ID_ResponsableFk",i."ID_ServiceFk",i."ID_LocalisationFk",
  i."LocalisationComplement",i."DateEntree",i."DateAcquisition",i."NumeroSerie",i."Observations",
  i."Actif",i."CreeLe",i."ModifieLe",i."CreeParUserFk",i."ModifieParUserFk",
  e."NomEntite",c."NomGenerique" AS "CategorieMateriel",s."NomGenerique" AS "EtatMateriel",service."NomGenerique" AS "Service",
  nullif(concat_ws(' ',u."PrenomUser",u."NomUser"),'') AS "Responsable",d."AbrGenerique" AS "DeviseCode",d."NomGenerique" AS "DeviseLibelle",
  CASE WHEN i."PrixUnitaire" IS NULL THEN NULL ELSE round(i."Quantite"*i."PrixUnitaire",2) END AS "ValeurAcquisition",
  nullif(concat_ws(' · ',nullif(l."AdresseDetaillee",''),nullif(l."NomNiveau_5",''),nullif(l."NomNiveau_4",''),nullif(l."NomNiveau_3",'')),'') AS "Localisation",
  i.xmin::text AS "_version",i."DateMiseEnService",sortie."TypeEvenement" AS "TypeSortie",sortie."DateEvenement" AS "DateSortie",
  CASE WHEN sortie."ID_Evenement" IS NOT NULL THEN 'SORTI'
   WHEN i."DateMiseEnService"<=(CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa')::date THEN 'EN_SERVICE'
   ELSE 'A_METTRE_EN_SERVICE' END AS "StatutCycle"
 FROM logistique."T_Immobilisation" i LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=i."IdEntiteFk"
 LEFT JOIN referentiel."T_Generique" c ON c."ID_Generique"=i."ID_CategorieFk" LEFT JOIN referentiel."T_Generique" s ON s."ID_Generique"=i."ID_EtatFk"
 LEFT JOIN referentiel."T_Generique" service ON service."ID_Generique"=i."ID_ServiceFk" LEFT JOIN referentiel."T_Generique" d ON d."ID_Generique"=i."ID_DeviseFk"
 LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=i."ID_ResponsableFk" AND u."IdEntiteFk"=i."IdEntiteFk"
 LEFT JOIN systeme."V_Entite_Localisation_Detail" l ON l."IdEntiteLocalisation"=i."ID_LocalisationFk" AND l."IdEntite"=i."IdEntiteFk"
 LEFT JOIN logistique."T_ImmobilisationEvenement" sortie ON sortie."ID_ImmobilisationFk"=i."ID_Immobilisation"
  AND sortie."TypeEvenement" IN ('CESSION','REBUT');
COMMENT ON VIEW logistique."V_Immobilisation" IS 'Registre physique au grain un bien ou lot homogène. Les biens sans affectataire restent visibles. La date et le type de sortie proviennent du registre d’événements.';
COMMENT ON COLUMN logistique."V_Immobilisation"."DateMiseEnService" IS 'Date civile de mise en service déclarée, si connue.';
COMMENT ON COLUMN logistique."V_Immobilisation"."TypeSortie" IS 'CESSION ou REBUT si le bien est sorti. NULL lorsque le bien est détenu.';
COMMENT ON COLUMN logistique."V_Immobilisation"."DateSortie" IS 'Date civile de la sortie physique, indépendante de l’archivage administratif.';

COMMENT ON COLUMN logistique."V_Immobilisation"."StatutCycle" IS 'État physique calculé : à mettre en service, en service à la date locale, ou sorti. Indépendant de l’archivage administratif.';

DO $commentaires$
DECLARE
 item record;
BEGIN
 FOR item IN
  SELECT conname,pg_get_constraintdef(oid,true) AS definition
  FROM pg_constraint WHERE conrelid='logistique."T_ImmobilisationEvenement"'::regclass
   AND obj_description(oid,'pg_constraint') IS NULL
 LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON logistique."T_ImmobilisationEvenement" IS %L',
   item.conname,'Intégrité du registre physique. '||item.definition);
 END LOOP;
 FOR item IN
  SELECT c.relname FROM pg_index k JOIN pg_class c ON c.oid=k.indexrelid
  WHERE k.indrelid='logistique."T_ImmobilisationEvenement"'::regclass AND (k.indisprimary OR k.indisunique)
   AND obj_description(c.oid,'pg_class') IS NULL
 LOOP
  EXECUTE format('COMMENT ON INDEX logistique.%I IS %L',item.relname,'Unicité technique de l’événement ou de sa requête.');
 END LOOP;
 FOR item IN
  SELECT view_col.attname,col_description(table_col.attrelid,table_col.attnum) AS description
  FROM pg_attribute view_col
  JOIN pg_attribute table_col ON table_col.attrelid='logistique."T_ImmobilisationEvenement"'::regclass
   AND table_col.attname=view_col.attname
  WHERE view_col.attrelid='logistique."V_ImmobilisationEvenement"'::regclass AND view_col.attnum>0
 LOOP
  EXECUTE format('COMMENT ON COLUMN logistique."V_ImmobilisationEvenement".%I IS %L',item.attname,item.description);
 END LOOP;
 EXECUTE format('COMMENT ON SEQUENCE %s IS %L',
  pg_get_serial_sequence('logistique."T_ImmobilisationEvenement"','ID_Evenement'),
  'Identifiant technique des événements physiques, attribué par PostgreSQL.');
END $commentaires$;

DO $catalogue$
DECLARE
 colonnes jsonb;
 additions jsonb;
 dernier_ordre integer;
BEGIN
 SELECT "Colonnes" INTO colonnes FROM referentiel."T_InterfaceTableau"
  WHERE "CleInterface"='logistique.immobilisations' FOR UPDATE;
 IF NOT FOUND THEN RETURN; END IF;
 SELECT coalesce(max((v->>'defaultOrder')::integer),-1) INTO dernier_ordre FROM jsonb_array_elements(colonnes) v;
 SELECT jsonb_agg(jsonb_build_object(
  'id',c.id,'label',c.libelle,'type',c.type,'tableAvailable',true,'exportable',true,
  'defaultVisible',false,'defaultExport',false,'defaultOrder',dernier_ordre+c.ordre,
  'defaultExportOrder',dernier_ordre+c.ordre+100
 ) ORDER BY c.ordre) INTO additions
 FROM (VALUES
  ('DateMiseEnService','Date de mise en service','date',1),
  ('StatutCycle','Situation du bien','text',2),
  ('DateSortie','Date de sortie','date',3)
 ) AS c(id,libelle,type,ordre)
 WHERE NOT EXISTS (SELECT FROM jsonb_array_elements(colonnes) v WHERE v->>'id'=c.id);
 IF additions IS NOT NULL THEN
  UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=colonnes||additions,"Version"="Version"+1
   WHERE "CleInterface"='logistique.immobilisations';
 END IF;
END $catalogue$;
