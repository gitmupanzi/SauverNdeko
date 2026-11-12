-- Applications et licences au niveau de l’entité ; aucune modification des comptes ni des dates contractuelles.
BEGIN;
SET LOCAL lock_timeout='3s';
CREATE TABLE systeme."T_ModuleApplication" (
 "CodeModule" varchar(32) PRIMARY KEY,
 "Nom" varchar(120) NOT NULL,
 "EstSocle" boolean NOT NULL DEFAULT false,
 "CodeIncluant" varchar(32) REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT,
 "Actif" boolean NOT NULL DEFAULT true,
 "Ordre" integer NOT NULL DEFAULT 0,
 CHECK ("CodeIncluant" IS DISTINCT FROM "CodeModule"),
 CHECK (btrim("Nom")<>'')
);
CREATE TABLE systeme."T_LicenceModule" (
 "IdLicenceModule" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdLicenceFk" integer NOT NULL REFERENCES systeme."T_Licence"("IdLicence") ON DELETE RESTRICT,
 "CodeModule" varchar(32) NOT NULL REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT,
 "Actif" boolean NOT NULL DEFAULT true,
 "Origine" varchar(12) NOT NULL DEFAULT 'activation' CHECK ("Origine" IN ('activation','reprise')),
 "Version" integer NOT NULL DEFAULT 1 CHECK ("Version">0),
 "ModifieParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL,
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "ModifieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE ("IdLicenceFk","CodeModule")
);
CREATE TABLE systeme."T_RoleModule" (
 "IdRoleModule" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "IdRoleFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "CodeModule" varchar(32) NOT NULL REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT,
 "PeutConsulter" boolean NOT NULL DEFAULT true,
 "PeutGerer" boolean NOT NULL DEFAULT false,
 "PeutExporter" boolean NOT NULL DEFAULT false,
 "Actif" boolean NOT NULL DEFAULT true,
 "Version" integer NOT NULL DEFAULT 1 CHECK ("Version">0),
 "ModifieParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL,
 "CreeLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 "ModifieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE ("IdEntiteFk","IdRoleFk","CodeModule"),
 CHECK ("PeutConsulter" OR (NOT "PeutGerer" AND NOT "PeutExporter"))
);
CREATE FUNCTION systeme.verifier_activation_module() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF TG_TABLE_NAME='T_LicenceModule' THEN
   IF OLD."IdLicenceFk"<>NEW."IdLicenceFk" OR OLD."CodeModule"<>NEW."CodeModule" OR OLD."Origine"<>NEW."Origine" THEN RAISE EXCEPTION 'Le rattachement et son origine sont immuables.'; END IF;
  ELSE
   IF OLD."IdEntiteFk"<>NEW."IdEntiteFk" OR OLD."IdRoleFk"<>NEW."IdRoleFk" OR OLD."CodeModule"<>NEW."CodeModule" THEN RAISE EXCEPTION 'Le périmètre du rôle est immuable.'; END IF;
  END IF;
  NEW."Version"=OLD."Version"+1;
 ELSE
  NEW."Version"=1;
 END IF;
 IF TG_TABLE_NAME='T_RoleModule' THEN
  IF NOT EXISTS (SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."IdRoleFk" AND "ID_CategorieGeneriqueFk"=39) THEN RAISE EXCEPTION 'Référence de rôle invalide.'; END IF;
 END IF;
 NEW."ModifieLe"=CURRENT_TIMESTAMP;
 RETURN NEW;
END;
$$;
CREATE TRIGGER licence_module_integrite BEFORE INSERT OR UPDATE ON systeme."T_LicenceModule" FOR EACH ROW EXECUTE FUNCTION systeme.verifier_activation_module();
CREATE TRIGGER role_module_integrite BEFORE INSERT OR UPDATE ON systeme."T_RoleModule" FOR EACH ROW EXECUTE FUNCTION systeme.verifier_activation_module();
INSERT INTO systeme."T_ModuleApplication" ("CodeModule","Nom","EstSocle","Ordre") VALUES
 ('catalogue','Catalogue',false,10),('produits','Produits',false,20),('structures','Structures',false,30),('professionnels','Professionnels',false,40),('sante','Informations santé',false,50),('discussions','Discussions',true,60),('logistique','Logistique',false,70),('territoires','Organisation territoriale',true,80),('administration','Administration',true,90);
UPDATE systeme."T_ModuleApplication" SET "CodeIncluant"='catalogue' WHERE "CodeModule" IN ('produits','structures','professionnels','sante');
-- Reprise documentée des applications déjà disponibles dans les licences existantes, sans nouvelle licence ni facturation.
INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Origine") SELECT l."IdLicence",m."CodeModule",'reprise' FROM systeme."T_Licence" l CROSS JOIN systeme."T_ModuleApplication" m WHERE NOT m."EstSocle";
CREATE VIEW systeme."V_LicenceModule" AS
 SELECT lm.*,l."IdEntiteFk",e."NomEntite",m."Nom" AS "NomModule",m."EstSocle",m."CodeIncluant",l."DateDebut",l."DateFin",
 (e."ValideEntite" IS TRUE AND m."Actif" AND lm."Actif" AND l."ValideLicence" IS TRUE AND (l."DateDebut" IS NULL OR l."DateDebut"<=CURRENT_TIMESTAMP) AND l."DateFin">CURRENT_TIMESTAMP) AS "EstAccesActif",
 CASE WHEN e."ValideEntite" IS NOT TRUE THEN 'Entité inactive' WHEN NOT m."Actif" THEN 'Module indisponible' WHEN NOT lm."Actif" THEN 'Désactivé' WHEN l."ValideLicence" IS NOT TRUE THEN 'Licence inactive' WHEN l."DateDebut">CURRENT_TIMESTAMP THEN 'À venir' WHEN l."DateFin" IS NULL THEN 'Échéance manquante' WHEN l."DateFin"<=CURRENT_TIMESTAMP THEN 'Licence expirée' ELSE 'Actif' END AS "EtatAcces"
 FROM systeme."T_LicenceModule" lm JOIN systeme."T_Licence" l ON l."IdLicence"=lm."IdLicenceFk" JOIN systeme."T_Entite" e ON e."IdEntite"=l."IdEntiteFk" JOIN systeme."T_ModuleApplication" m ON m."CodeModule"=lm."CodeModule";
CREATE VIEW systeme."V_EntiteModuleActif" AS
 SELECT e."IdEntite" AS "IdEntiteFk",m."CodeModule" FROM systeme."T_Entite" e CROSS JOIN systeme."T_ModuleApplication" m WHERE e."ValideEntite" IS TRUE AND m."Actif" AND m."EstSocle"
 UNION
 SELECT l."IdEntiteFk",m."CodeModule" FROM systeme."V_LicenceModule" l JOIN systeme."T_ModuleApplication" m ON (m."CodeModule"=l."CodeModule" OR m."CodeIncluant"=l."CodeModule") WHERE l."EstAccesActif" AND m."Actif";
CREATE VIEW systeme."V_RoleModule" AS SELECT r.*,g."NomGenerique" AS "NomRole",m."Nom" AS "NomModule" FROM systeme."T_RoleModule" r JOIN referentiel."T_Generique" g ON g."ID_Generique"=r."IdRoleFk" JOIN systeme."T_ModuleApplication" m ON m."CodeModule"=r."CodeModule";
COMMENT ON TABLE systeme."T_ModuleApplication" IS 'Catalogue des applications SauverNdeko ; le socle partagé reste distinct des modules compris dans une licence.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."CodeModule" IS 'Code stable utilisé par les contrôles serveur et la navigation.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."Nom" IS 'Nom métier de l’application.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."EstSocle" IS 'Application incluse au socle d’une entité active ; les droits du rôle restent nécessaires.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."CodeIncluant" IS 'Application dont la licence inclut aussi ce module, sans créer une seconde souscription.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."Actif" IS 'Disponibilité du module dans le catalogue.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."Ordre" IS 'Ordre de présentation du catalogue.';
COMMENT ON TABLE systeme."T_LicenceModule" IS 'Modules compris dans une licence existante. L’entité et la période sont celles de T_Licence ; aucun abonnement individuel.';
COMMENT ON COLUMN systeme."T_LicenceModule"."IdLicenceModule" IS 'Identifiant permanent de la ligne d’activation.';
COMMENT ON COLUMN systeme."T_LicenceModule"."IdLicenceFk" IS 'Licence de l’entité ; cette relation est immuable.';
COMMENT ON COLUMN systeme."T_LicenceModule"."CodeModule" IS 'Application activée dans cette licence ; code immuable.';
COMMENT ON COLUMN systeme."T_LicenceModule"."Actif" IS 'Activation explicite du module dans la licence.';
COMMENT ON COLUMN systeme."T_LicenceModule"."Origine" IS 'Reprise identifie les accès conservés lors de la migration ; ce champ ne constitue pas une facturation.';
COMMENT ON COLUMN systeme."T_LicenceModule"."Version" IS 'Version utilisée pour refuser les modifications concurrentes.';
COMMENT ON COLUMN systeme."T_LicenceModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification ; NULL pour la migration initiale.';
COMMENT ON COLUMN systeme."T_LicenceModule"."CreeLe" IS 'Instant de création du rattachement.';
COMMENT ON COLUMN systeme."T_LicenceModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';
COMMENT ON TABLE systeme."T_RoleModule" IS 'Restrictions par rôle, application et entité. Elles complètent les droits existants sans accorder le rôle d’administrateur.';
COMMENT ON COLUMN systeme."T_RoleModule"."IdRoleModule" IS 'Identifiant permanent du paramétrage.';
COMMENT ON COLUMN systeme."T_RoleModule"."IdEntiteFk" IS 'Entité à laquelle s’applique cette règle ; immuable.';
COMMENT ON COLUMN systeme."T_RoleModule"."IdRoleFk" IS 'Rôle du référentiel, catégorie Rôles (39) ; immuable.';
COMMENT ON COLUMN systeme."T_RoleModule"."CodeModule" IS 'Application concernée par les restrictions ; code immuable.';
COMMENT ON COLUMN systeme."T_RoleModule"."PeutConsulter" IS 'Autorise la consultation si la licence et les droits préexistants l’autorisent aussi.';
COMMENT ON COLUMN systeme."T_RoleModule"."PeutGerer" IS 'Autorise les créations, modifications et suppressions permises par les services métier existants.';
COMMENT ON COLUMN systeme."T_RoleModule"."PeutExporter" IS 'Autorise les exports officiels du module.';
COMMENT ON COLUMN systeme."T_RoleModule"."Actif" IS 'Une règle inactive refuse ces accès ; son absence conserve les droits antérieurs.';
COMMENT ON COLUMN systeme."T_RoleModule"."Version" IS 'Version du paramétrage pour la concurrence optimiste.';
COMMENT ON COLUMN systeme."T_RoleModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification.';
COMMENT ON COLUMN systeme."T_RoleModule"."CreeLe" IS 'Instant de création du paramétrage.';
COMMENT ON COLUMN systeme."T_RoleModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';
COMMENT ON VIEW systeme."V_LicenceModule" IS 'Activation effective par licence et entité ; les dates sont évaluées à la lecture sans modifier le contrat.';
COMMENT ON COLUMN systeme."V_LicenceModule"."IdLicenceModule" IS 'Identifiant permanent de la ligne d’activation.';
COMMENT ON COLUMN systeme."V_LicenceModule"."IdLicenceFk" IS 'Licence de l’entité ; cette relation est immuable.';
COMMENT ON COLUMN systeme."V_LicenceModule"."CodeModule" IS 'Application activée dans cette licence ; code immuable.';
COMMENT ON COLUMN systeme."V_LicenceModule"."Actif" IS 'Activation explicite du module dans la licence.';
COMMENT ON COLUMN systeme."V_LicenceModule"."Origine" IS 'Reprise identifie les accès conservés lors de la migration ; ce champ ne constitue pas une facturation.';
COMMENT ON COLUMN systeme."V_LicenceModule"."Version" IS 'Version utilisée pour refuser les modifications concurrentes.';
COMMENT ON COLUMN systeme."V_LicenceModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification ; NULL pour la migration initiale.';
COMMENT ON COLUMN systeme."V_LicenceModule"."CreeLe" IS 'Instant de création du rattachement.';
COMMENT ON COLUMN systeme."V_LicenceModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';
COMMENT ON COLUMN systeme."V_LicenceModule"."IdEntiteFk" IS 'Entité propriétaire de la licence, obtenue par la clé étrangère T_Licence.';
COMMENT ON COLUMN systeme."V_LicenceModule"."NomEntite" IS 'Nom de l’entité propriétaire.';
COMMENT ON COLUMN systeme."V_LicenceModule"."NomModule" IS 'Libellé de l’application.';
COMMENT ON COLUMN systeme."V_LicenceModule"."EstSocle" IS 'Application comprise dans le socle.';
COMMENT ON COLUMN systeme."V_LicenceModule"."CodeIncluant" IS 'Application parente qui inclut ce module.';
COMMENT ON COLUMN systeme."V_LicenceModule"."DateDebut" IS 'Début contractuel conservé depuis T_Licence.';
COMMENT ON COLUMN systeme."V_LicenceModule"."DateFin" IS 'Échéance contractuelle conservée depuis T_Licence.';
COMMENT ON COLUMN systeme."V_LicenceModule"."EstAccesActif" IS 'Licence, entité, module et activation valides à l’instant de lecture.';
COMMENT ON COLUMN systeme."V_LicenceModule"."EtatAcces" IS 'Motif de disponibilité ou de suspension.';
COMMENT ON VIEW systeme."V_EntiteModuleActif" IS 'Modules effectivement disponibles à une entité active : socle, licence valide et inclusions du Catalogue. Les droits du rôle sont vérifiés ensuite.';
COMMENT ON COLUMN systeme."V_EntiteModuleActif"."IdEntiteFk" IS 'Entité autorisée.';
COMMENT ON COLUMN systeme."V_EntiteModuleActif"."CodeModule" IS 'Application comprise dans son socle ou sa licence active.';
COMMENT ON VIEW systeme."V_RoleModule" IS 'Restrictions par rôle d’une entité ; aucune souscription n’est attribuée individuellement aux utilisateurs.';
COMMENT ON COLUMN systeme."V_RoleModule"."IdRoleModule" IS 'Identifiant permanent du paramétrage.';
COMMENT ON COLUMN systeme."V_RoleModule"."IdEntiteFk" IS 'Entité à laquelle s’applique cette règle ; immuable.';
COMMENT ON COLUMN systeme."V_RoleModule"."IdRoleFk" IS 'Rôle du référentiel, catégorie Rôles (39) ; immuable.';
COMMENT ON COLUMN systeme."V_RoleModule"."CodeModule" IS 'Application concernée par les restrictions ; code immuable.';
COMMENT ON COLUMN systeme."V_RoleModule"."PeutConsulter" IS 'Autorise la consultation si la licence et les droits préexistants l’autorisent aussi.';
COMMENT ON COLUMN systeme."V_RoleModule"."PeutGerer" IS 'Autorise les créations, modifications et suppressions permises par les services métier existants.';
COMMENT ON COLUMN systeme."V_RoleModule"."PeutExporter" IS 'Autorise les exports officiels du module.';
COMMENT ON COLUMN systeme."V_RoleModule"."Actif" IS 'Une règle inactive refuse ces accès ; son absence conserve les droits antérieurs.';
COMMENT ON COLUMN systeme."V_RoleModule"."Version" IS 'Version du paramétrage pour la concurrence optimiste.';
COMMENT ON COLUMN systeme."V_RoleModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification.';
COMMENT ON COLUMN systeme."V_RoleModule"."CreeLe" IS 'Instant de création du paramétrage.';
COMMENT ON COLUMN systeme."V_RoleModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';
COMMENT ON COLUMN systeme."V_RoleModule"."NomRole" IS 'Libellé du rôle du référentiel.';
COMMENT ON COLUMN systeme."V_RoleModule"."NomModule" IS 'Libellé de l’application.';
COMMENT ON FUNCTION systeme.verifier_activation_module() IS 'Préserve les rattachements et leur provenance, contrôle la catégorie de rôle et fixe version et horodatage ; ne crée aucune licence.';
COMMENT ON TRIGGER licence_module_integrite ON systeme."T_LicenceModule" IS 'Rattachement licence/module immuable et versionné ; les dates de licence ne sont pas modifiées.';
COMMENT ON TRIGGER role_module_integrite ON systeme."T_RoleModule" IS 'Périmètre entité/rôle/module immuable ; les restrictions ne constituent pas un rôle administrateur.';
COMMIT;
