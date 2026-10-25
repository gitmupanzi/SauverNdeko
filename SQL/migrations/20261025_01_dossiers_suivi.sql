-- Dossiers de suivi : installation additive, sans modification du stock.
-- Exécuter une seule fois sur SauverNdeko après validation du déploiement.
BEGIN;
SET LOCAL lock_timeout = '3s';
CREATE TABLE logistique."T_CategorieDossierSuivi" (
 "ID_CategorieDossierSuivi" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "IdEntiteFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "Nom" varchar(80) NOT NULL CHECK (btrim("Nom") <> ''),
 "Couleur" varchar(10) NOT NULL DEFAULT 'bleu' CHECK ("Couleur" IN ('vert','rouge','orange','bleu','violet','ardoise')),
 "Actif" boolean NOT NULL DEFAULT true,
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "ModifieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX categorie_dossier_suivi_nom_actif ON logistique."T_CategorieDossierSuivi" ("ID_UserFk",COALESCE("IdEntiteFk",0),lower(btrim("Nom"))) WHERE "Actif";
CREATE TABLE logistique."T_DossierSuivi" (
 "ID_DossierSuivi" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "IdEntiteFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ID_CategorieDossierSuiviFk" integer REFERENCES logistique."T_CategorieDossierSuivi"("ID_CategorieDossierSuivi") ON DELETE RESTRICT,
 "Nom" varchar(120) NOT NULL CHECK (btrim("Nom") <> ''),
 "Description" varchar(1000) NOT NULL DEFAULT '',
 "Couleur" varchar(10) NOT NULL DEFAULT 'bleu' CHECK ("Couleur" IN ('vert','rouge','orange','bleu','violet','ardoise')),
 "TypeObjet" varchar(10) NOT NULL CHECK ("TypeObjet" IN ('article','bon','facture')),
 "Mode" varchar(12) NOT NULL CHECK ("Mode" IN ('manuel','automatique')),
 "Regles" jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof("Regles")='object' AND ("Regles" - CASE "TypeObjet" WHEN 'article' THEN ARRAY['q','categorieId','typeId','uniteId','statut','stockState','peremption']::text[] WHEN 'bon' THEN ARRAY['q','client','typeId','statutId','etatBon']::text[] ELSE ARRAY['q','client','etatFacture']::text[] END)='{}'::jsonb),
 "Actif" boolean NOT NULL DEFAULT true,
 "Version" integer NOT NULL DEFAULT 1 CHECK ("Version">0),
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "ModifieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CHECK (("Mode"='manuel' AND "Regles"='{}'::jsonb) OR ("Mode"='automatique' AND "Regles"<>'{}'::jsonb))
);
CREATE UNIQUE INDEX dossier_suivi_nom_actif ON logistique."T_DossierSuivi" ("ID_UserFk",COALESCE("IdEntiteFk",0),lower(btrim("Nom"))) WHERE "Actif";
CREATE INDEX dossier_suivi_categorie ON logistique."T_DossierSuivi" ("ID_CategorieDossierSuiviFk");
CREATE TABLE logistique."T_DossierSuiviMembre" (
 "ID_DossierSuiviFk" integer NOT NULL REFERENCES logistique."T_DossierSuivi"("ID_DossierSuivi") ON DELETE RESTRICT,
 "ID_ArticleFk" integer REFERENCES logistique."T_Article"("ID_Article") ON DELETE CASCADE,
 "ID_CommandeFk" integer REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE CASCADE,
 "ID_Membre" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "Actif" boolean NOT NULL DEFAULT true,
 "AjouteLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "ModifieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE ("ID_DossierSuiviFk","ID_ArticleFk"),
 UNIQUE ("ID_DossierSuiviFk","ID_CommandeFk"),
 CHECK (num_nonnulls("ID_ArticleFk","ID_CommandeFk")=1)
);
CREATE INDEX dossier_suivi_membre_article ON logistique."T_DossierSuiviMembre" ("ID_ArticleFk","ID_DossierSuiviFk") WHERE "Actif";
CREATE INDEX dossier_suivi_membre_bon ON logistique."T_DossierSuiviMembre" ("ID_CommandeFk","ID_DossierSuiviFk") WHERE "Actif";
CREATE FUNCTION logistique.verifier_dossier_suivi() RETURNS trigger LANGUAGE plpgsql AS $$
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
   SELECT EXISTS (SELECT 1 FROM logistique."T_Article" a JOIN systeme."T_Utilisateurs" u ON u."IdUser"=a."ID_UserFK" JOIN systeme."T_Utilisateurs" owner_u ON owner_u."IdUser"=parent."ID_UserFk" WHERE a."ID_Article"=NEW."ID_ArticleFk" AND (owner_u."Is_Admin" OR (parent."IdEntiteFk" IS NOT NULL AND u."IdEntiteFk"=parent."IdEntiteFk"))) INTO permitted;
  ELSE
   IF NEW."ID_CommandeFk" IS NULL OR NEW."ID_ArticleFk" IS NOT NULL THEN RAISE EXCEPTION 'Ce dossier accepte uniquement des documents de stock ou de facturation.'; END IF;
   SELECT EXISTS (SELECT 1 FROM logistique."T_Commande" c JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."ID_UserFk" JOIN systeme."T_Utilisateurs" owner_u ON owner_u."IdUser"=parent."ID_UserFk" WHERE c."ID_Commande"=NEW."ID_CommandeFk" AND (parent."TypeObjet"='bon' OR (c."CodeFacture" IS NOT NULL AND btrim(c."CodeFacture")<>'')) AND (owner_u."Is_Admin" OR (parent."IdEntiteFk" IS NOT NULL AND u."IdEntiteFk"=parent."IdEntiteFk"))) INTO permitted;
  END IF;
  IF NOT permitted THEN RAISE EXCEPTION 'L’enregistrement ne fait pas partie du périmètre autorisé du dossier.'; END IF;
 END IF;
 NEW."ModifieLe"=CURRENT_TIMESTAMP;
 RETURN NEW;
END;
$$;
CREATE TRIGGER categorie_dossier_suivi_integrite BEFORE INSERT OR UPDATE ON logistique."T_CategorieDossierSuivi" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_dossier_suivi();
CREATE TRIGGER dossier_suivi_integrite BEFORE INSERT OR UPDATE ON logistique."T_DossierSuivi" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_dossier_suivi();
CREATE TRIGGER dossier_suivi_membre_integrite BEFORE INSERT OR UPDATE ON logistique."T_DossierSuiviMembre" FOR EACH ROW EXECUTE FUNCTION logistique.verifier_dossier_suivi();
CREATE VIEW logistique."V_CategorieDossierSuivi" AS SELECT "ID_CategorieDossierSuivi","ID_UserFk","IdEntiteFk","Nom","Couleur","Actif","CreeLe","ModifieLe" FROM logistique."T_CategorieDossierSuivi";
CREATE VIEW logistique."V_DossierSuivi" AS SELECT d."ID_DossierSuivi",d."ID_UserFk",d."IdEntiteFk",d."ID_CategorieDossierSuiviFk",d."Nom",d."Description",d."Couleur",d."TypeObjet",d."Mode",d."Regles",d."Actif",d."Version",d."CreeLe",d."ModifieLe",c."Nom" AS "CategorieDossier" FROM logistique."T_DossierSuivi" d LEFT JOIN logistique."T_CategorieDossierSuivi" c ON c."ID_CategorieDossierSuivi"=d."ID_CategorieDossierSuiviFk";
CREATE VIEW logistique."V_DossierSuiviMembre" AS SELECT m."ID_Membre",m."ID_DossierSuiviFk",m."ID_ArticleFk",m."ID_CommandeFk",d."TypeObjet",m."Actif",m."AjouteLe",m."ModifieLe",d."ID_UserFk",d."IdEntiteFk",d."Nom" AS "NomDossier",d."Couleur" FROM logistique."T_DossierSuiviMembre" m JOIN logistique."T_DossierSuivi" d ON d."ID_DossierSuivi"=m."ID_DossierSuiviFk" WHERE d."Mode"='manuel';
COMMENT ON FUNCTION logistique.verifier_dossier_suivi() IS 'Contrôle le périmètre propriétaire/catégorie, le mode immuable et les rattachements manuels. Ne modifie jamais le stock ni les mouvements.';
COMMENT ON TABLE logistique."T_CategorieDossierSuivi" IS 'Dossiers de suivi privés : articles, bons de stock ou factures ; aucun effet sur les écritures métier.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."ID_CategorieDossierSuivi" IS 'Identifiant permanent de la catégorie de dossiers.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."IdEntiteFk" IS 'Organisation du contexte à la création ; nullable et immuable.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."CreeLe" IS 'Instant de création.';
COMMENT ON COLUMN logistique."T_CategorieDossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';
COMMENT ON TABLE logistique."T_DossierSuivi" IS 'Dossiers de suivi privés : articles, bons de stock ou factures ; aucun effet sur les écritures métier.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."ID_DossierSuivi" IS 'Identifiant permanent du dossier ; indépendant de son libellé.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."IdEntiteFk" IS 'Organisation du contexte à la création ; nullable et immuable.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."ID_CategorieDossierSuiviFk" IS 'Catégorie de classement du même propriétaire et du même périmètre.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."Description" IS 'Description facultative du suivi.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."Mode" IS 'manuel pour les rattachements explicites, automatique pour une sélection dynamique.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."Regles" IS 'Critères JSON autorisés selon TypeObjet, interprétés par le serveur ; aucun fragment SQL utilisateur.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."Version" IS 'Version de concurrence optimiste des métadonnées du dossier.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."CreeLe" IS 'Instant de création.';
COMMENT ON COLUMN logistique."T_DossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';
COMMENT ON TABLE logistique."T_DossierSuiviMembre" IS 'Dossiers de suivi privés : articles, bons de stock ou factures ; aucun effet sur les écritures métier.';
COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_DossierSuiviFk" IS 'Dossier manuel actif du rattachement.';
COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_ArticleFk" IS 'Article classé ; clé de la vue et de la table article existantes.';
COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."Actif" IS 'État actif ; false conserve le classement archivé.';
COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."AjouteLe" IS 'Date du premier rattachement manuel ; conservée lors d’une réactivation.';
COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';
COMMENT ON VIEW logistique."V_CategorieDossierSuivi" IS 'Projection de lecture du classement des articles, à filtrer par propriétaire et organisation.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."ID_CategorieDossierSuivi" IS 'Identifiant permanent de la catégorie de dossiers.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."IdEntiteFk" IS 'Organisation du contexte à la création ; nullable et immuable.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."CreeLe" IS 'Instant de création.';
COMMENT ON COLUMN logistique."V_CategorieDossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';
COMMENT ON VIEW logistique."V_DossierSuivi" IS 'Projection de lecture du classement des articles, à filtrer par propriétaire et organisation.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."ID_DossierSuivi" IS 'Identifiant permanent du dossier ; indépendant de son libellé.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."IdEntiteFk" IS 'Organisation du contexte à la création ; nullable et immuable.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."ID_CategorieDossierSuiviFk" IS 'Catégorie de classement du même propriétaire et du même périmètre.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."Nom" IS 'Libellé métier du dossier ou de sa catégorie.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."Description" IS 'Description facultative du suivi.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."Mode" IS 'manuel pour les rattachements explicites, automatique pour une sélection dynamique.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."Regles" IS 'Critères JSON autorisés selon TypeObjet, interprétés par le serveur ; aucun fragment SQL utilisateur.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."Actif" IS 'État actif ; false conserve le classement archivé.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."Version" IS 'Version de concurrence optimiste des métadonnées du dossier.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."CreeLe" IS 'Instant de création.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."CategorieDossier" IS 'Libellé de la catégorie du dossier, sans modifier la catégorie de l’article.';
COMMENT ON VIEW logistique."V_DossierSuiviMembre" IS 'Projection de lecture du classement des articles, à filtrer par propriétaire et organisation.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_DossierSuiviFk" IS 'Dossier manuel actif du rattachement.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_ArticleFk" IS 'Article classé ; clé de la vue et de la table article existantes.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."Actif" IS 'État actif ; false conserve le classement archivé.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."AjouteLe" IS 'Date du premier rattachement manuel ; conservée lors d’une réactivation.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ModifieLe" IS 'Instant de dernière modification, fixé par le trigger.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_UserFk" IS 'Propriétaire du classement ; imposé par le compte authentifié et immuable.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."IdEntiteFk" IS 'Organisation du contexte à la création ; nullable et immuable.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."NomDossier" IS 'Libellé du dossier manuel associé.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."Couleur" IS 'Repère visuel de palette ; ne déclenche aucune action sur le stock.';
COMMENT ON TRIGGER categorie_dossier_suivi_integrite ON logistique."T_CategorieDossierSuivi" IS 'Préserve les clés et le périmètre du classement et horodate ses modifications ; aucun effet sur le stock.';
COMMENT ON TRIGGER dossier_suivi_integrite ON logistique."T_DossierSuivi" IS 'Préserve les clés et le périmètre du classement et horodate ses modifications ; aucun effet sur le stock.';
COMMENT ON TRIGGER dossier_suivi_membre_integrite ON logistique."T_DossierSuiviMembre" IS 'Préserve les clés et le périmètre du classement et horodate ses modifications ; aucun effet sur le stock.';

COMMENT ON COLUMN logistique."T_DossierSuivi"."TypeObjet" IS 'Type immuable du dossier : article, bon ou facture. Une facture correspond au bon portant sa référence de facture dans le modèle actuel.';
COMMENT ON COLUMN logistique."V_DossierSuivi"."TypeObjet" IS 'Type immuable du dossier : article, bon ou facture. Une facture correspond au bon portant sa référence de facture dans le modèle actuel.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."TypeObjet" IS 'Type immuable du dossier : article, bon ou facture. Une facture correspond au bon portant sa référence de facture dans le modèle actuel.';
COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_CommandeFk" IS 'Bon classé, ou bon portant la facture classée ; exclusif de ID_ArticleFk. La facture reste soumise à son existence actuelle.';
COMMENT ON COLUMN logistique."T_DossierSuiviMembre"."ID_Membre" IS 'Identifiant permanent du rattachement ; unicité par dossier et objet classé.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_CommandeFk" IS 'Bon classé, ou bon portant la facture classée ; exclusif de ID_ArticleFk. La facture reste soumise à son existence actuelle.';
COMMENT ON COLUMN logistique."V_DossierSuiviMembre"."ID_Membre" IS 'Identifiant permanent du rattachement ; unicité par dossier et objet classé.';
COMMIT;
