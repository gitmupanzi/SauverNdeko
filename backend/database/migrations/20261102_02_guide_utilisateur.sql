-- Guide utilisateur : application de consultation du socle commun.
-- Les parcours restent versionnés avec le logiciel ; leur visibilité réutilise
-- les licences et rôles des modules métier, sans copie de donnée d'entreprise.
BEGIN;

INSERT INTO systeme."T_ModuleApplication"
    ("CodeModule", "Nom", "EstSocle", "CodeIncluant", "Actif", "Ordre")
VALUES ('guide', 'Guide utilisateur', true, NULL, true, 110)
ON CONFLICT ("CodeModule") DO UPDATE
SET "Nom" = EXCLUDED."Nom", "EstSocle" = true, "CodeIncluant" = NULL,
    "Actif" = true, "Ordre" = EXCLUDED."Ordre";

COMMIT;
