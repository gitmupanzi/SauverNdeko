-- Politique d'accès par application, indépendante des souscriptions historiques.
SET LOCAL lock_timeout = '5s';

ALTER TABLE systeme."T_ModuleApplication"
    ADD COLUMN "ReservePlateforme" boolean NOT NULL DEFAULT false,
    ADD COLUMN "AccessibleSansEntite" boolean NOT NULL DEFAULT false,
    ADD CONSTRAINT ck_module_reserve_plateforme
        CHECK (NOT "ReservePlateforme" OR (NOT "EstSocle" AND NOT "Commercialisable")),
    ADD CONSTRAINT ck_module_acces_sans_entite
        CHECK (NOT "AccessibleSansEntite" OR ("EstSocle" AND NOT "ReservePlateforme"));

UPDATE systeme."T_ModuleApplication"
SET "EstSocle" = true, "Commercialisable" = false, "AccessibleSansEntite" = true
WHERE "CodeModule" IN ('produits', 'structures', 'professionnels');

UPDATE systeme."T_ModuleApplication"
SET "EstSocle" = false, "Commercialisable" = true
WHERE "CodeModule" IN ('discussions', 'logistique', 'caisse', 'support');

UPDATE systeme."T_ModuleApplication"
SET "EstSocle" = false, "Commercialisable" = false, "ReservePlateforme" = true
WHERE "CodeModule" = 'territoires';

COMMENT ON COLUMN systeme."T_ModuleApplication"."ReservePlateforme" IS
    'Réserve l’application aux administrateurs de la plateforme. Les rattachements historiques d’une entreprise n’accordent pas d’accès.';
COMMENT ON COLUMN systeme."T_ModuleApplication"."AccessibleSansEntite" IS
    'Inclut la consultation de cet annuaire pour les comptes authentifiés sans entreprise. Les API conservent leurs règles de publication.';
COMMENT ON CONSTRAINT ck_module_reserve_plateforme ON systeme."T_ModuleApplication" IS
    'Une application réservée à la plateforme est exclue du socle client et de l’offre commerciale.';
COMMENT ON CONSTRAINT ck_module_acces_sans_entite ON systeme."T_ModuleApplication" IS
    'Seule une application du socle client peut être consultée par un compte sans entreprise.';

CREATE OR REPLACE VIEW systeme."V_LicenceModule" AS
SELECT lm.*, l."IdEntiteFk", e."NomEntite", m."Nom" AS "NomModule",
    m."EstSocle", m."CodeIncluant", l."DateDebut", l."DateFin",
    (e."ValideEntite" IS TRUE AND m."Actif" AND NOT m."ReservePlateforme"
        AND lm."Actif" AND l."ValideLicence" IS TRUE
        AND (l."DateDebut" IS NULL OR l."DateDebut" <= CURRENT_TIMESTAMP)
        AND l."DateFin" > CURRENT_TIMESTAMP) AS "EstAccesActif",
    CASE
        WHEN m."ReservePlateforme" THEN 'Réservé à la plateforme'
        WHEN e."ValideEntite" IS NOT TRUE THEN 'Entité inactive'
        WHEN NOT m."Actif" THEN 'Module indisponible'
        WHEN NOT lm."Actif" THEN 'Désactivé'
        WHEN l."ValideLicence" IS NOT TRUE THEN 'Licence inactive'
        WHEN l."DateDebut" > CURRENT_TIMESTAMP THEN 'À venir'
        WHEN l."DateFin" IS NULL THEN 'Échéance manquante'
        WHEN l."DateFin" <= CURRENT_TIMESTAMP THEN 'Licence expirée'
        ELSE 'Actif'
    END AS "EtatAcces"
FROM systeme."T_LicenceModule" lm
JOIN systeme."T_Licence" l ON l."IdLicence" = lm."IdLicenceFk"
JOIN systeme."T_Entite" e ON e."IdEntite" = l."IdEntiteFk"
JOIN systeme."T_ModuleApplication" m ON m."CodeModule" = lm."CodeModule";

CREATE OR REPLACE VIEW systeme."V_EntiteModuleActif" AS
SELECT e."IdEntite" AS "IdEntiteFk", m."CodeModule"
FROM systeme."T_Entite" e
CROSS JOIN systeme."T_ModuleApplication" m
WHERE e."ValideEntite" IS TRUE AND m."Actif" AND m."EstSocle" AND NOT m."ReservePlateforme"
UNION
SELECT l."IdEntiteFk", m."CodeModule"
FROM systeme."V_LicenceModule" l
JOIN systeme."T_ModuleApplication" m
    ON m."CodeModule" = l."CodeModule" OR m."CodeIncluant" = l."CodeModule"
WHERE l."EstAccesActif" AND m."Actif" AND NOT m."ReservePlateforme";

COMMENT ON VIEW systeme."V_LicenceModule" IS
    'Historique des activations par licence et calcul des accès effectifs. Les modules réservés à la plateforme restent visibles dans l’historique, sans conférer d’accès.';
COMMENT ON COLUMN systeme."V_LicenceModule"."EstAccesActif" IS
    'Accès commercial effectif pour l’entité et la période de licence, hors applications réservées à la plateforme.';
COMMENT ON COLUMN systeme."V_LicenceModule"."EtatAcces" IS
    'Motif de disponibilité, de suspension ou de réservation à la plateforme.';
COMMENT ON VIEW systeme."V_EntiteModuleActif" IS
    'Accès d’une entité active au socle et aux modules couverts par une licence valide. Les applications de plateforme en sont exclues. Les droits du rôle sont vérifiés ensuite.';
