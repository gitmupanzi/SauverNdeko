CREATE TABLE analytics."T_PerimetreRecherche" (
    "IdPerimetre" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE CASCADE,
    "DebuteLe" timestamptz NOT NULL DEFAULT statement_timestamp(),
    "TermineLe" timestamptz,
    "IdModifieParFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL,
    "IdTermineParFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL,
    CHECK ("TermineLe" IS NULL OR "TermineLe" >= "DebuteLe")
);

CREATE UNIQUE INDEX "UX_PerimetreRecherche_Actif" ON analytics."T_PerimetreRecherche" ("IdEntiteFk")
    WHERE "TermineLe" IS NULL;

CREATE TABLE communication."T_BesoinAnnuaire" (
    "IdBesoin" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "IdAuteurFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE CASCADE,
    "IdEntiteFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON DELETE CASCADE,
    "CleRequete" uuid NOT NULL,
    "Source" text NOT NULL CHECK ("Source" IN ('product','expert','structure')),
    "Nature" text NOT NULL CHECK ("Nature" IN ('recherche','besoin_sans_resultat')),
    "IdCategorieProduitFk" integer REFERENCES referentiel."T_Generique"("ID_Generique"),
    "IdPathologieFk" integer REFERENCES referentiel."T_Generique"("ID_Generique"),
    "IdTerritoireFk" integer REFERENCES geolocalisation."T_Niveau_1"("ID_Niveau_1"),
    "Consentement" boolean NOT NULL DEFAULT false,
    "Etat" text CHECK ("Etat" IN ('en_attente','satisfaite','non_satisfaite')),
    "CreeLe" timestamptz NOT NULL DEFAULT statement_timestamp(),
    "ModifieLe" timestamptz NOT NULL DEFAULT statement_timestamp(),
    UNIQUE ("IdAuteurFk","CleRequete"),
    CHECK (num_nonnulls("IdCategorieProduitFk","IdPathologieFk") <= 1),
    CHECK (("Nature" = 'recherche' AND "Consentement" AND "Etat" IS NULL
            AND num_nonnulls("IdCategorieProduitFk","IdPathologieFk") = 1)
        OR ("Nature" = 'besoin_sans_resultat' AND "Etat" IS NOT NULL))
);

CREATE INDEX "IX_BesoinAnnuaire_Auteur_Date" ON communication."T_BesoinAnnuaire"
    ("IdAuteurFk","CreeLe" DESC,"IdBesoin" DESC);
CREATE INDEX "IX_BesoinAnnuaire_Consentement_Date" ON communication."T_BesoinAnnuaire"
    ("IdEntiteFk","CreeLe") WHERE "Consentement";

CREATE FUNCTION analytics.fn_choix_recherche(p_famille text)
RETURNS TABLE (identifiant integer, libelle text)
LANGUAGE sql STABLE AS $$
    SELECT g."ID_Generique", g."AbrGenerique"::text
    FROM referentiel."T_Generique" g
    JOIN referentiel."T_CategorieGenerique" c
      ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
    WHERE lower(btrim(c."NomCategorieGenerique")) = lower(p_famille)
      AND c."IdEntiteFk" IS NULL AND g."IdEntiteFk" IS NULL
      AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE
      AND nullif(btrim(g."AbrGenerique"), '') IS NOT NULL
      AND referentiel.fn_reference_visible(g."ID_Generique", NULL::integer)
$$;

CREATE FUNCTION communication.fn_controler_besoin_annuaire() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_entite integer;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF ROW(NEW."IdBesoin",NEW."IdAuteurFk",NEW."IdEntiteFk",NEW."CleRequete",
               NEW."Source",NEW."Nature",NEW."IdCategorieProduitFk",NEW."IdPathologieFk",
               NEW."IdTerritoireFk",NEW."Consentement",NEW."CreeLe")
           IS DISTINCT FROM
           ROW(OLD."IdBesoin",OLD."IdAuteurFk",OLD."IdEntiteFk",OLD."CleRequete",
               OLD."Source",OLD."Nature",OLD."IdCategorieProduitFk",OLD."IdPathologieFk",
               OLD."IdTerritoireFk",OLD."Consentement",OLD."CreeLe") THEN
            RAISE EXCEPTION USING ERRCODE = 'PBA01', MESSAGE = 'Identité et consentement immuables.';
        END IF;
        IF NEW."Etat" IS DISTINCT FROM OLD."Etat" THEN
            IF OLD."Etat" IS DISTINCT FROM 'en_attente' OR NEW."Etat" IS NULL THEN
                RAISE EXCEPTION USING ERRCODE = 'PBA02', MESSAGE = 'Issue déjà enregistrée.';
            END IF;
            NEW."ModifieLe" := statement_timestamp();
        END IF;
        RETURN NEW;
    END IF;

    SELECT "IdEntiteFk" INTO v_entite FROM systeme."T_Utilisateurs"
    WHERE "IdUser" = NEW."IdAuteurFk" AND "ValideUser" IS TRUE FOR SHARE;
    IF NOT FOUND OR v_entite IS DISTINCT FROM NEW."IdEntiteFk" THEN
        RAISE EXCEPTION USING ERRCODE = 'PBA01', MESSAGE = 'Périmètre de l’auteur indisponible.';
    END IF;

    IF (NEW."IdCategorieProduitFk" IS NOT NULL AND NOT EXISTS (
            SELECT FROM analytics.fn_choix_recherche('Catégorie produit')
            WHERE identifiant = NEW."IdCategorieProduitFk"))
       OR (NEW."IdPathologieFk" IS NOT NULL AND NOT EXISTS (
            SELECT FROM analytics.fn_choix_recherche('Maladie')
            WHERE identifiant = NEW."IdPathologieFk"))
       OR (NEW."IdTerritoireFk" IS NOT NULL AND NOT EXISTS (
            SELECT FROM geolocalisation."T_Niveau_1"
            WHERE "ID_Niveau_1" = NEW."IdTerritoireFk"
              AND nullif(btrim("NomNiveau_1"), '') IS NOT NULL))
       OR (NEW."Nature" = 'besoin_sans_resultat' AND NEW."Etat" IS DISTINCT FROM 'en_attente') THEN
        RAISE EXCEPTION USING ERRCODE = 'PBA01', MESSAGE = 'Choix de recherche invalide.';
    END IF;

    NEW."CreeLe" := statement_timestamp();
    NEW."ModifieLe" := NEW."CreeLe";
    IF NEW."Consentement" THEN
        PERFORM FROM systeme."T_Entite" e
        WHERE e."IdEntite" = NEW."IdEntiteFk" AND e."ValideEntite" IS TRUE FOR SHARE;
        IF NOT FOUND OR NOT EXISTS (
            SELECT FROM analytics."T_PerimetreRecherche" p
            WHERE p."IdEntiteFk" = NEW."IdEntiteFk" AND p."DebuteLe" <= NEW."CreeLe" AND p."TermineLe" IS NULL
        ) THEN
            RAISE EXCEPTION USING ERRCODE = 'PBA03', MESSAGE = 'Participation de l’entreprise inactive.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER "TR_BesoinAnnuaire_Controle" BEFORE INSERT OR UPDATE
ON communication."T_BesoinAnnuaire" FOR EACH ROW
EXECUTE FUNCTION communication.fn_controler_besoin_annuaire();

CREATE VIEW analytics."V_ObservationDemandeRecherche" AS
SELECT date_trunc('month', b."CreeLe" AT TIME ZONE 'Africa/Kinshasa')::date AS "Mois",
       b."IdCategorieProduitFk" AS "IdProduitFk",
       g."AbrGenerique" AS "ProduitLibelle",
       b."IdTerritoireFk", n."NomNiveau_1" AS "TerritoireLibelle",
       b."Etat" AS "EtatDemande", b."IdAuteurFk" AS "Contributeur",
       b."Source", b."Nature",
       CASE WHEN b."Nature" = 'recherche' THEN b."IdPathologieFk" END AS "IdPathologieFk",
       CASE WHEN b."Nature" = 'recherche' THEN m."AbrGenerique" END AS "PathologieLibelle",
       CASE WHEN b."Nature" = 'besoin_sans_resultat' THEN 'sans_resultat' END AS "ResultatRecherche"
FROM communication."T_BesoinAnnuaire" b
JOIN analytics."T_PerimetreRecherche" p ON p."IdEntiteFk" = b."IdEntiteFk"
    AND p."TermineLe" IS NULL AND b."CreeLe" >= p."DebuteLe"
JOIN systeme."T_Entite" e ON e."IdEntite" = p."IdEntiteFk" AND e."ValideEntite" IS TRUE
LEFT JOIN geolocalisation."T_Niveau_1" n ON n."ID_Niveau_1" = b."IdTerritoireFk"
LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = b."IdCategorieProduitFk"
LEFT JOIN referentiel."T_Generique" m ON m."ID_Generique" = b."IdPathologieFk"
WHERE b."Consentement";

COMMENT ON TABLE analytics."T_PerimetreRecherche" IS 'Entreprises participant à l’étude. Une réactivation démarre un nouveau périmètre temporel.';
COMMENT ON TABLE communication."T_BesoinAnnuaire" IS 'Déclarations volontaires privées. Aucun terme libre, destinataire, localisation fine ni diagnostic.';
COMMENT ON COLUMN communication."T_BesoinAnnuaire"."IdPathologieFk" IS 'Sujet d’intérêt déclaré. Cette référence ne représente pas un diagnostic ni une indication thérapeutique.';
COMMENT ON FUNCTION analytics.fn_choix_recherche(text) IS 'Abréviations actives du référentiel commun utilisables pour une déclaration structurée.';
COMMENT ON FUNCTION communication.fn_controler_besoin_annuaire() IS 'Contrôle le périmètre, les référentiels, le consentement et l’issue des besoins.';
COMMENT ON TRIGGER "TR_BesoinAnnuaire_Controle" ON communication."T_BesoinAnnuaire" IS 'Empêche le changement d’auteur, de périmètre et de consentement après création.';
COMMENT ON VIEW analytics."V_ObservationDemandeRecherche" IS 'Source interne de l’agrégation mensuelle. Les identifiants contributeurs servent uniquement au seuil de confidentialité.';
COMMENT ON INDEX communication."IX_BesoinAnnuaire_Auteur_Date" IS 'Pagination du registre privé d’un utilisateur.';
COMMENT ON INDEX communication."IX_BesoinAnnuaire_Consentement_Date" IS 'Lecture analytique des déclarations consenties dans le périmètre de l’étude.';
