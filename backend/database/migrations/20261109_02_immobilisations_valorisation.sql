-- Valorisation des immobilisations : plans validés et journal distinct du suivi physique.
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';

CREATE TABLE logistique."T_ImmobilisationPlan" (
    "ID_Plan" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "ID_ImmobilisationFk" integer NOT NULL REFERENCES logistique."T_Immobilisation"("ID_Immobilisation") ON DELETE RESTRICT,
    "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
    "UsagePlan" text NOT NULL,
    "Referentiel" text NOT NULL,
    "Methode" text NOT NULL,
    "CoutAcquisition" numeric(18,2) NOT NULL,
    "ValeurResiduelle" numeric(18,2) NOT NULL,
    "DateDebut" date NOT NULL,
    "DureeMois" integer,
    "DateFinExclusive" date,
    "ID_DeviseFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
    "Justification" text NOT NULL,
    "ValideLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
    "ValideParUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
    "Demande" uuid NOT NULL,
    "EmpreinteDemande" text NOT NULL,
    CONSTRAINT uq_immobilisation_plan_usage UNIQUE ("ID_ImmobilisationFk", "UsagePlan"),
    CONSTRAINT uq_immobilisation_plan_demande UNIQUE ("IdEntiteFk", "ValideParUserFk", "Demande"),
    CONSTRAINT ck_immobilisation_plan_referentiel CHECK (
        ("UsagePlan" = 'COMPTABLE' AND "Referentiel" IN ('SYSCOHADA', 'IFRS'))
        OR ("UsagePlan" = 'FISCAL' AND "Referentiel" = 'FISCAL')
    ),
    CONSTRAINT ck_immobilisation_plan_methode CHECK (
        ("Methode" = 'LINEAIRE_JOURS' AND "DureeMois" IS NOT NULL AND "DureeMois" BETWEEN 1 AND 1200
            AND "DateFinExclusive" IS NOT NULL AND "DateFinExclusive" > "DateDebut")
        OR ("Methode" = 'NON_AMORTISSABLE' AND "DureeMois" IS NULL AND "DateFinExclusive" IS NULL)
    ),
    CONSTRAINT ck_immobilisation_plan_montants CHECK (
        "CoutAcquisition" BETWEEN 0 AND 9999999999999999.99 AND "ValeurResiduelle" BETWEEN 0 AND "CoutAcquisition"
    ),
    CONSTRAINT ck_immobilisation_plan_validation CHECK (char_length(btrim("Justification")) BETWEEN 1 AND 2000)
);
COMMENT ON TABLE logistique."T_ImmobilisationPlan" IS 'Plan initial confirmé par un utilisateur habilité, séparé par bien et usage comptable ou fiscal. Aucun plan ni taux implicite et aucune écriture de comptabilité générale.';
COMMENT ON COLUMN logistique."T_ImmobilisationPlan"."DateDebut" IS 'Date choisie et justifiée pour le plan. La qualification du bien et le point de départ sont validés par le comptable de l’entreprise.';
COMMENT ON COLUMN logistique."T_ImmobilisationPlan"."DateFinExclusive" IS 'Limite du plan linéaire au prorata des jours calendaires, calculée à partir de la durée saisie.';
COMMENT ON COLUMN logistique."T_ImmobilisationPlan"."Justification" IS 'Référence obligatoire à la validation comptable des paramètres, y compris la méthode, la date, la durée et la valeur résiduelle.';
COMMENT ON CONSTRAINT uq_immobilisation_plan_usage ON logistique."T_ImmobilisationPlan" IS 'Un plan distinct par bien et par usage. Les événements ajustent la valeur sans réécrire le plan validé.';
CREATE INDEX ix_immobilisation_plan_entite ON logistique."T_ImmobilisationPlan"("IdEntiteFk", "UsagePlan", "ID_ImmobilisationFk");

CREATE TABLE logistique."T_ImmobilisationEvenementValeur" (
    "ID_EvenementValeur" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "ID_PlanFk" bigint NOT NULL REFERENCES logistique."T_ImmobilisationPlan"("ID_Plan") ON DELETE RESTRICT,
    "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
    "TypeEvenement" text NOT NULL CHECK ("TypeEvenement" IN ('DOTATION', 'AMELIORATION', 'DEPRECIATION', 'CESSION', 'REBUT')),
    "DateEffet" date NOT NULL,
    "Montant" numeric(18,2) NOT NULL,
    "Motif" text NOT NULL CHECK (char_length(btrim("Motif")) BETWEEN 1 AND 2000),
    "ValeurAvantSortie" numeric(18,2),
    "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
    "CreeParUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
    "Demande" uuid NOT NULL,
    "EmpreinteDemande" text NOT NULL,
    CONSTRAINT uq_immobilisation_valeur_demande UNIQUE ("IdEntiteFk", "CreeParUserFk", "Demande"),
    CONSTRAINT ck_immobilisation_evenement_montants CHECK (
        "Montant" BETWEEN 0 AND 9999999999999999.99 AND (
            ("TypeEvenement" IN ('CESSION', 'REBUT') AND "ValeurAvantSortie" IS NOT NULL AND "ValeurAvantSortie" >= 0
                AND ("TypeEvenement" = 'CESSION' OR "Montant" = 0))
            OR ("TypeEvenement" IN ('DOTATION', 'AMELIORATION', 'DEPRECIATION') AND "ValeurAvantSortie" IS NULL AND "Montant" > 0)
        )
    )
);
COMMENT ON TABLE logistique."T_ImmobilisationEvenementValeur" IS 'Journal append-only des dotations constatées, améliorations, pertes de valeur et sorties par plan. Aucun mouvement de stock, règlement, écriture de Caisse ou de comptabilité générale implicite.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenementValeur"."DateEffet" IS 'Date incluse pour une dotation. Une sortie arrête le calcul à la veille de sa date physique.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenementValeur"."Montant" IS 'Dotation calculée, coût d’amélioration, perte validée ou produit de cession selon le type. Montant dans la devise du plan.';
COMMENT ON COLUMN logistique."T_ImmobilisationEvenementValeur"."ValeurAvantSortie" IS 'Valeur nette juste avant sortie, conservée pour expliquer le résultat de cession ou de mise au rebut.';
CREATE INDEX ix_immobilisation_valeur_plan ON logistique."T_ImmobilisationEvenementValeur"("ID_PlanFk", "DateEffet", "ID_EvenementValeur");
CREATE UNIQUE INDEX uq_immobilisation_valeur_sortie ON logistique."T_ImmobilisationEvenementValeur"("ID_PlanFk")
    WHERE "TypeEvenement" IN ('CESSION', 'REBUT');

CREATE TABLE logistique."T_ImmobilisationClotureValeur" (
    "ID_ClotureValeur" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
    "UsagePlan" text NOT NULL CHECK ("UsagePlan" IN ('COMPTABLE', 'FISCAL')),
    "JusquAu" date NOT NULL,
    "Motif" text NOT NULL CHECK (char_length(btrim("Motif")) BETWEEN 1 AND 2000),
    "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
    "CreeParUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
    "Demande" uuid NOT NULL,
    "EmpreinteDemande" text NOT NULL,
    CONSTRAINT uq_immobilisation_cloture_usage UNIQUE ("IdEntiteFk", "UsagePlan", "JusquAu"),
    CONSTRAINT uq_immobilisation_cloture_demande UNIQUE ("IdEntiteFk", "CreeParUserFk", "Demande")
);
COMMENT ON TABLE logistique."T_ImmobilisationClotureValeur" IS 'Bornes inclusives successives de clôture de la valorisation, propres à chaque entreprise et usage. Le journal antérieur est figé.';
COMMENT ON COLUMN logistique."T_ImmobilisationClotureValeur"."JusquAu" IS 'Dernière date interdite pour une nouvelle dotation, sortie, amélioration, dépréciation ou ouverture rétroactive du plan.';

CREATE FUNCTION logistique.tr_immobilisation_valorisation_immuable() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
    IF TG_OP <> 'INSERT' OR current_user <> pg_get_userbyid(
        (SELECT c.relowner FROM pg_class c WHERE c.oid = TG_RELID)
    ) THEN
        RAISE EXCEPTION 'Le journal de valorisation est protégé. Utilisez les opérations de validation.'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END
$$;
COMMENT ON FUNCTION logistique.tr_immobilisation_valorisation_immuable() IS 'Réserve les insertions aux fonctions métier exécutées par le propriétaire et préserve les lignes déjà validées, y compris face à un TRUNCATE.';
CREATE TRIGGER a_immobilisation_plan_immuable
    BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_ImmobilisationPlan"
    FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_valorisation_immuable();
CREATE TRIGGER a_immobilisation_evenement_valeur_immuable
    BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_ImmobilisationEvenementValeur"
    FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_valorisation_immuable();
CREATE TRIGGER a_immobilisation_cloture_valeur_immuable
    BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_ImmobilisationClotureValeur"
    FOR EACH ROW EXECUTE FUNCTION logistique.tr_immobilisation_valorisation_immuable();
COMMENT ON TRIGGER a_immobilisation_plan_immuable ON logistique."T_ImmobilisationPlan" IS 'Protège le plan confirmé contre la modification ou la suppression directe.';
COMMENT ON TRIGGER a_immobilisation_evenement_valeur_immuable ON logistique."T_ImmobilisationEvenementValeur" IS 'Protège le journal des valeurs contre les écritures hors du service SQL et les réécritures.';
COMMENT ON TRIGGER a_immobilisation_cloture_valeur_immuable ON logistique."T_ImmobilisationClotureValeur" IS 'Préserve toutes les clôtures déjà confirmées.';
CREATE TRIGGER b_immobilisation_plan_interdire_truncate
    BEFORE TRUNCATE ON logistique."T_ImmobilisationPlan"
    FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_immobilisation_valorisation_immuable();
CREATE TRIGGER b_immobilisation_evenement_interdire_truncate
    BEFORE TRUNCATE ON logistique."T_ImmobilisationEvenementValeur"
    FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_immobilisation_valorisation_immuable();
CREATE TRIGGER b_immobilisation_cloture_interdire_truncate
    BEFORE TRUNCATE ON logistique."T_ImmobilisationClotureValeur"
    FOR EACH STATEMENT EXECUTE FUNCTION logistique.tr_immobilisation_valorisation_immuable();
COMMENT ON TRIGGER b_immobilisation_plan_interdire_truncate ON logistique."T_ImmobilisationPlan" IS 'Interdit de vider le registre des plans.';
COMMENT ON TRIGGER b_immobilisation_evenement_interdire_truncate ON logistique."T_ImmobilisationEvenementValeur" IS 'Interdit de vider le journal de valorisation.';
COMMENT ON TRIGGER b_immobilisation_cloture_interdire_truncate ON logistique."T_ImmobilisationClotureValeur" IS 'Interdit de vider l’historique des clôtures.';

CREATE VIEW logistique."V_ImmobilisationPlan" AS
SELECT p."ID_Plan", p."ID_ImmobilisationFk", p."IdEntiteFk", p."UsagePlan", p."Referentiel",
       p."Methode", p."CoutAcquisition", p."ValeurResiduelle", p."DateDebut", p."DureeMois",
       p."DateFinExclusive", p."ID_DeviseFk", p."Justification", p."ValideLe", p."ValideParUserFk",
       d."AbrGenerique" AS "Devise",
       p."CoutAcquisition" + coalesce(e.ameliorations, 0) AS "CoutBrut",
       coalesce(e.amortissements, 0) AS "AmortissementsCumules",
       coalesce(e.pertes, 0) AS "PertesCumulees",
       CASE WHEN e.date_sortie IS NULL THEN p."CoutAcquisition" + coalesce(e.ameliorations, 0)
            - coalesce(e.amortissements, 0) - coalesce(e.pertes, 0) ELSE 0 END AS "ValeurNetteComptable",
       e.date_sortie AS "DateSortie", e.derniere_dotation AS "DerniereDateAmortie",
       e.dernier_ajustement AS "DerniereDateAjustement",
       phys."DateEvenement" AS "DateSortiePhysique", phys."TypeEvenement" AS "TypeSortiePhysique",
       c.jusqu_au AS "ClotureJusquAu",
       md5(concat_ws('|', p."ID_Plan", coalesce(e.derniere_ecriture, 0),
                     coalesce(c.jusqu_au - DATE '1900-01-01', -2147483648),
                     coalesce(phys."DateEvenement" - DATE '1900-01-01', -2147483648))) AS "_version"
FROM logistique."T_ImmobilisationPlan" p
JOIN referentiel."T_Generique" d ON d."ID_Generique" = p."ID_DeviseFk"
LEFT JOIN LATERAL (
    SELECT sum(v."Montant") FILTER (WHERE v."TypeEvenement" = 'AMELIORATION') AS ameliorations,
           sum(v."Montant") FILTER (WHERE v."TypeEvenement" = 'DOTATION') AS amortissements,
           sum(v."Montant") FILTER (WHERE v."TypeEvenement" = 'DEPRECIATION') AS pertes,
           max(v."DateEffet") FILTER (WHERE v."TypeEvenement" IN ('CESSION', 'REBUT')) AS date_sortie,
           max(v."DateEffet") FILTER (WHERE v."TypeEvenement" = 'DOTATION') AS derniere_dotation,
           max(v."DateEffet") FILTER (WHERE v."TypeEvenement" IN ('AMELIORATION', 'DEPRECIATION')) AS dernier_ajustement,
           max(v."ID_EvenementValeur") AS derniere_ecriture
    FROM logistique."T_ImmobilisationEvenementValeur" v WHERE v."ID_PlanFk" = p."ID_Plan"
) e ON true
LEFT JOIN LATERAL (
    SELECT s."DateEvenement", s."TypeEvenement"
    FROM logistique."T_ImmobilisationEvenement" s
    WHERE s."ID_ImmobilisationFk" = p."ID_ImmobilisationFk" AND s."TypeEvenement" IN ('CESSION', 'REBUT')
    ORDER BY s."DateEvenement" LIMIT 1
) phys ON true
LEFT JOIN LATERAL (
    SELECT max(h."JusquAu") AS jusqu_au FROM logistique."T_ImmobilisationClotureValeur" h
    WHERE h."IdEntiteFk" = p."IdEntiteFk" AND h."UsagePlan" = p."UsagePlan"
) c ON true;
COMMENT ON VIEW logistique."V_ImmobilisationPlan" IS 'Situation issue des seuls événements constatés. La prévision mensuelle est séparée. Le compte applicatif doit filtrer l’entreprise autorisée.';
COMMENT ON COLUMN logistique."V_ImmobilisationPlan"."ValeurNetteComptable" IS 'Valeur nette de l’usage considéré, sans les dotations prévisionnelles. Elle tombe à zéro lors de la sortie comptable.';
COMMENT ON COLUMN logistique."V_ImmobilisationPlan"."_version" IS 'Révision opaque intégrant le journal, la borne de clôture et la date de sortie physique.';

CREATE FUNCTION logistique.fn_dotation_restante_immobilisation(p_plan bigint, p_jusqu_au date) RETURNS numeric
LANGUAGE sql STABLE SET search_path = pg_catalog AS $$
    SELECT CASE WHEN p."Methode" = 'NON_AMORTISSABLE' OR p."DateSortie" IS NOT NULL
        OR bornes.jusqu_au < bornes.debut THEN 0::numeric
        ELSE greatest(0, round(
            greatest(0, p."ValeurNetteComptable" + coalesce(d.montant, 0) - p."ValeurResiduelle")
            * (bornes.jusqu_au - bornes.debut + 1) / (p."DateFinExclusive" - bornes.debut),
            2
        ) - coalesce(d.montant, 0)) END
    FROM logistique."V_ImmobilisationPlan" p
    CROSS JOIN LATERAL (
        SELECT greatest(p."DateDebut", p."DerniereDateAjustement") AS debut,
               least(p_jusqu_au, p."DateFinExclusive" - 1, p."DateSortiePhysique" - 1) AS jusqu_au
    ) bornes
    LEFT JOIN LATERAL (
        SELECT sum(v."Montant") AS montant
        FROM logistique."T_ImmobilisationEvenementValeur" v
        WHERE v."ID_PlanFk" = p."ID_Plan" AND v."TypeEvenement" = 'DOTATION'
          AND v."DateEffet" >= bornes.debut
    ) d ON true
    WHERE p."ID_Plan" = p_plan;
$$;
COMMENT ON FUNCTION logistique.fn_dotation_restante_immobilisation(bigint, date) IS 'Calcule le reliquat arrondi au centime sur le segment courant. Un ajustement validé ouvre un segment prospectif sur la durée restante.';

CREATE FUNCTION logistique.fn_echeancier_immobilisation(p_plan bigint)
RETURNS TABLE ("DateDebut" date, "DateFin" date, "Montant" numeric)
LANGUAGE sql STABLE SET search_path = pg_catalog AS $$
    SELECT mois.debut, mois.fin, mois.cumul - lag(mois.cumul, 1, 0::numeric) OVER (ORDER BY mois.debut)
    FROM logistique."V_ImmobilisationPlan" p
    CROSS JOIN LATERAL (
        SELECT greatest(p."DateDebut", p."DerniereDateAjustement", p."DerniereDateAmortie" + 1, p."ClotureJusquAu" + 1) AS debut,
               least(p."DateFinExclusive" - 1, p."DateSortiePhysique" - 1) AS fin
    ) bornes
    CROSS JOIN LATERAL (
        SELECT greatest(d::date, bornes.debut) AS debut,
               least((d + interval '1 month')::date - 1, bornes.fin) AS fin,
               logistique.fn_dotation_restante_immobilisation(p_plan, least((d + interval '1 month')::date - 1, bornes.fin)) AS cumul
        FROM generate_series(date_trunc('month', bornes.debut::timestamp), bornes.fin::timestamp, interval '1 month') s(d)
        WHERE bornes.debut <= bornes.fin
    ) mois
    WHERE p."ID_Plan" = p_plan AND p."Methode" = 'LINEAIRE_JOURS' AND p."DateSortie" IS NULL
    ORDER BY mois.debut;
$$;
COMMENT ON FUNCTION logistique.fn_echeancier_immobilisation(bigint) IS 'Échéancier mensuel du reliquat linéaire. Répète le même calcul que la dotation et compense les arrondis par différence de cumuls. Lecture sans écriture.';

CREATE FUNCTION logistique.fn_contexte_valorisation_immobilisation(
    p_entite integer, p_acteur integer, p_demande uuid, p_hash text, p_motif text
) RETURNS void
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
    IF p_acteur IS NULL OR systeme.fn_admin_actor_user_id() IS DISTINCT FROM p_acteur
        OR NOT EXISTS (
            SELECT FROM systeme."T_Utilisateurs" u
            WHERE u."IdUser" = p_acteur AND u."ValideUser" IS TRUE
              AND (u."Is_Admin" IS TRUE OR u."IdEntiteFk" = p_entite)
        ) THEN
        RAISE EXCEPTION 'Auteur actif et entreprise autorisée requis.' USING ERRCODE = '42501';
    END IF;
    IF p_entite IS NULL OR p_demande IS NULL OR p_hash IS NULL OR p_hash !~ '^[a-fA-F0-9]{64}$'
       OR p_motif IS NULL OR char_length(btrim(p_motif)) NOT BETWEEN 1 AND 2000 THEN
        RAISE EXCEPTION 'Indiquez une référence de validation ou un motif de 1 à 2 000 caractères.'
            USING ERRCODE = '23514';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtext('logistique.immobilisation.valorisation'), p_entite);
END
$$;
COMMENT ON FUNCTION logistique.fn_contexte_valorisation_immobilisation(integer, integer, uuid, text, text) IS 'Contrôle l’auteur de transaction et sérialise les écritures de valorisation et les clôtures par entreprise. Les permissions métier sont contrôlées par le service applicatif.';

CREATE FUNCTION logistique.fn_rejouer_valorisation_immobilisation(
    p_entite integer, p_acteur integer, p_demande uuid, p_hash text, p_operation text
) RETURNS bigint
LANGUAGE plpgsql STABLE SET search_path = pg_catalog AS $$
DECLARE
    historique record;
BEGIN
    SELECT * INTO historique FROM (
        SELECT 'PLAN'::text AS operation, p."ID_Plan" AS id, p."EmpreinteDemande" AS empreinte
        FROM logistique."T_ImmobilisationPlan" p
        WHERE p."IdEntiteFk" = p_entite AND p."ValideParUserFk" = p_acteur AND p."Demande" = p_demande
        UNION ALL
        SELECT 'EVENEMENT', e."ID_EvenementValeur", e."EmpreinteDemande"
        FROM logistique."T_ImmobilisationEvenementValeur" e
        WHERE e."IdEntiteFk" = p_entite AND e."CreeParUserFk" = p_acteur AND e."Demande" = p_demande
        UNION ALL
        SELECT 'CLOTURE', c."ID_ClotureValeur", c."EmpreinteDemande"
        FROM logistique."T_ImmobilisationClotureValeur" c
        WHERE c."IdEntiteFk" = p_entite AND c."CreeParUserFk" = p_acteur AND c."Demande" = p_demande
    ) demandes;
    IF FOUND AND (historique.operation <> p_operation OR historique.empreinte <> p_hash) THEN
        RAISE EXCEPTION 'Cette demande a déjà été utilisée pour une autre opération.' USING ERRCODE = '23505';
    END IF;
    RETURN historique.id;
END
$$;
COMMENT ON FUNCTION logistique.fn_rejouer_valorisation_immobilisation(integer, integer, uuid, text, text) IS 'Reconnaît une répétition par entreprise, auteur, identifiant et empreinte. À appeler après acquisition du verrou de valorisation.';
REVOKE EXECUTE ON FUNCTION logistique.fn_rejouer_valorisation_immobilisation(integer, integer, uuid, text, text) FROM PUBLIC;

CREATE FUNCTION logistique.fn_creer_plan_immobilisation(
    p_bien bigint, p_entite integer, p_acteur integer, p_demande uuid, p_hash text, p_usage text,
    p_referentiel text, p_methode text, p_cout numeric, p_residuel numeric, p_debut date,
    p_duree integer, p_devise integer, p_justification text, p_version text
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE
    bien record;
    identifiant bigint;
BEGIN
    PERFORM logistique.fn_contexte_valorisation_immobilisation(p_entite, p_acteur, p_demande, p_hash, p_justification);
    identifiant := logistique.fn_rejouer_valorisation_immobilisation(p_entite, p_acteur, p_demande, p_hash, 'PLAN');
    IF identifiant IS NOT NULL THEN RETURN identifiant; END IF;

    SELECT i."Actif", i."DateAcquisition", i.xmin::text AS revision INTO bien
    FROM logistique."T_Immobilisation" i
    WHERE i."ID_Immobilisation" = p_bien AND i."IdEntiteFk" = p_entite
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bien indisponible dans cette entreprise.' USING ERRCODE = '42501';
    END IF;
    IF bien.revision IS DISTINCT FROM p_version THEN
        RAISE EXCEPTION 'La fiche du bien a changé. Actualisez-la avant de continuer.' USING ERRCODE = '40001';
    END IF;
    IF bien."Actif" IS NOT TRUE OR EXISTS (
        SELECT FROM logistique."T_ImmobilisationEvenement" s
        WHERE s."ID_ImmobilisationFk" = p_bien AND s."TypeEvenement" IN ('CESSION', 'REBUT')
    ) THEN
        RAISE EXCEPTION 'Un bien sorti ou archivé ne peut plus recevoir de nouveau plan.' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (
        SELECT FROM logistique."T_ImmobilisationPlan" p
        WHERE p."ID_ImmobilisationFk" = p_bien AND p."UsagePlan" = p_usage
    ) THEN
        RAISE EXCEPTION 'Un plan validé existe déjà pour cet usage.' USING ERRCODE = '23505';
    END IF;
    IF p_usage IS NULL OR p_referentiel IS NULL OR NOT (
        (p_usage = 'COMPTABLE' AND p_referentiel IN ('SYSCOHADA', 'IFRS'))
        OR (p_usage = 'FISCAL' AND p_referentiel = 'FISCAL')
    ) THEN
        RAISE EXCEPTION 'Choisissez un référentiel correspondant à l’usage du plan.' USING ERRCODE = '23514';
    END IF;
    IF p_methode IS NULL OR p_methode NOT IN ('LINEAIRE_JOURS', 'NON_AMORTISSABLE')
        OR (p_methode = 'LINEAIRE_JOURS' AND (p_duree IS NULL OR p_duree NOT BETWEEN 1 AND 1200))
        OR (p_methode = 'NON_AMORTISSABLE' AND p_duree IS NOT NULL) THEN
        RAISE EXCEPTION 'Indiquez la méthode validée et, pour le linéaire, une durée de 1 à 1 200 mois.'
            USING ERRCODE = '23514';
    END IF;
    IF p_debut IS NULL OR p_debut NOT BETWEEN DATE '1900-01-01' AND DATE '9899-12-31'
        OR p_debut < bien."DateAcquisition" THEN
        RAISE EXCEPTION 'Indiquez une date de départ valide, au plus tôt à l’acquisition du bien.'
            USING ERRCODE = '23514';
    END IF;
    IF EXISTS (
        SELECT FROM logistique."T_ImmobilisationClotureValeur" h
        WHERE h."IdEntiteFk" = p_entite AND h."UsagePlan" = p_usage AND h."JusquAu" >= p_debut
    ) THEN
        RAISE EXCEPTION 'La date de départ appartient à une période clôturée.' USING ERRCODE = '23514';
    END IF;
    IF p_cout IS NULL OR p_residuel IS NULL OR p_cout NOT BETWEEN 0 AND 9999999999999999.99
        OR p_residuel NOT BETWEEN 0 AND p_cout OR round(p_cout, 2) <> p_cout OR round(p_residuel, 2) <> p_residuel THEN
        RAISE EXCEPTION 'Le coût et la valeur résiduelle doivent être explicites, à deux décimales au plus. La valeur résiduelle doit être comprise entre zéro et le coût.'
            USING ERRCODE = '23514';
    END IF;
    IF p_devise IS NULL OR NOT logistique.fn_reference_immobilisation_valide(p_devise, 'devise', p_entite) THEN
        RAISE EXCEPTION 'Choisissez une devise active autorisée pour cette entreprise.' USING ERRCODE = '23514';
    END IF;

    INSERT INTO logistique."T_ImmobilisationPlan" (
        "ID_ImmobilisationFk", "IdEntiteFk", "UsagePlan", "Referentiel", "Methode", "CoutAcquisition",
        "ValeurResiduelle", "DateDebut", "DureeMois", "DateFinExclusive", "ID_DeviseFk", "Justification",
        "ValideParUserFk", "Demande", "EmpreinteDemande"
    ) VALUES (
        p_bien, p_entite, p_usage, p_referentiel, p_methode, p_cout, p_residuel, p_debut, p_duree,
        (p_debut + make_interval(months => p_duree))::date, p_devise, btrim(p_justification), p_acteur, p_demande, p_hash
    ) RETURNING "ID_Plan" INTO identifiant;
    RETURN identifiant;
END
$$;
COMMENT ON FUNCTION logistique.fn_creer_plan_immobilisation(bigint, integer, integer, uuid, text, text, text, text, numeric, numeric, date, integer, integer, text, text)
    IS 'Valide un plan explicite sous verrous entreprise puis bien, avec contrôle de révision, de l’historique physique, de la clôture et du rejeu exact.';

CREATE FUNCTION logistique.fn_enregistrer_evenement_valorisation(
    p_plan bigint, p_entite integer, p_acteur integer, p_demande uuid, p_hash text, p_version text,
    p_type text, p_date_effet date, p_montant numeric, p_motif text
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE
    plan logistique."V_ImmobilisationPlan"%ROWTYPE;
    identifiant bigint;
    montant_effectif numeric;
    valeur_sortie numeric;
    date_locale date := (clock_timestamp() AT TIME ZONE 'Africa/Kinshasa')::date;
BEGIN
    PERFORM logistique.fn_contexte_valorisation_immobilisation(p_entite, p_acteur, p_demande, p_hash, p_motif);
    identifiant := logistique.fn_rejouer_valorisation_immobilisation(p_entite, p_acteur, p_demande, p_hash, 'EVENEMENT');
    IF identifiant IS NOT NULL THEN RETURN identifiant; END IF;

    PERFORM FROM logistique."T_Immobilisation" i
    JOIN logistique."T_ImmobilisationPlan" p ON p."ID_ImmobilisationFk" = i."ID_Immobilisation"
    WHERE p."ID_Plan" = p_plan AND p."IdEntiteFk" = p_entite AND i."IdEntiteFk" = p_entite
    FOR UPDATE OF i;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Plan indisponible dans cette entreprise.' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO STRICT plan FROM logistique."V_ImmobilisationPlan" WHERE "ID_Plan" = p_plan;
    IF plan."_version" IS DISTINCT FROM p_version THEN
        RAISE EXCEPTION 'La valorisation a changé. Actualisez la fiche avant de continuer.' USING ERRCODE = '40001';
    END IF;
    IF plan."DateSortie" IS NOT NULL THEN
        RAISE EXCEPTION 'La sortie de ce plan a déjà été constatée.' USING ERRCODE = '23514';
    END IF;
    IF p_date_effet IS NULL OR p_date_effet NOT BETWEEN plan."DateDebut" AND date_locale THEN
        RAISE EXCEPTION 'Choisissez une date comprise entre le départ du plan et aujourd’hui.' USING ERRCODE = '23514';
    END IF;
    IF p_date_effet <= plan."ClotureJusquAu" THEN
        RAISE EXCEPTION 'Cette date appartient à une période clôturée.' USING ERRCODE = '23514';
    END IF;
    IF p_type IS NULL OR p_type NOT IN ('DOTATION', 'AMELIORATION', 'DEPRECIATION', 'CESSION', 'REBUT') THEN
        RAISE EXCEPTION 'Choisissez un type d’événement de valorisation autorisé.' USING ERRCODE = '23514';
    END IF;
    IF p_date_effet <= plan."DerniereDateAmortie" OR p_date_effet < plan."DerniereDateAjustement" THEN
        RAISE EXCEPTION 'Cette date est antérieure aux écritures déjà constatées ou déjà amortie.' USING ERRCODE = '23514';
    END IF;
    IF p_type IN ('CESSION', 'REBUT') THEN
        IF plan."TypeSortiePhysique" IS DISTINCT FROM p_type OR plan."DateSortiePhysique" IS DISTINCT FROM p_date_effet THEN
            RAISE EXCEPTION 'La sortie comptable doit correspondre au type et à la date de la sortie physique.' USING ERRCODE = '23514';
        END IF;
    ELSIF p_date_effet >= plan."DateSortiePhysique" THEN
        RAISE EXCEPTION 'Une écriture antérieure à la sortie physique est requise.' USING ERRCODE = '23514';
    END IF;

    IF p_type = 'DOTATION' THEN
        IF p_montant IS NOT NULL OR plan."Methode" <> 'LINEAIRE_JOURS' OR p_date_effet >= plan."DateFinExclusive" THEN
            RAISE EXCEPTION 'La dotation est calculée jusqu’à une date du plan linéaire. Laissez le montant vide.' USING ERRCODE = '23514';
        END IF;
        montant_effectif := logistique.fn_dotation_restante_immobilisation(p_plan, p_date_effet);
        IF montant_effectif <= 0 THEN
            RAISE EXCEPTION 'Aucune dotation supplémentaire à constater jusqu’à cette date.' USING ERRCODE = '23514';
        END IF;
    ELSE
        IF logistique.fn_dotation_restante_immobilisation(p_plan, p_date_effet - 1) > 0 THEN
            RAISE EXCEPTION 'Constatez les dotations dues jusqu’à la veille de l’événement.' USING ERRCODE = '23514';
        END IF;
        IF p_montant IS NOT NULL AND (p_montant NOT BETWEEN 0 AND 9999999999999999.99 OR round(p_montant, 2) <> p_montant) THEN
            RAISE EXCEPTION 'Indiquez un montant positif ou nul à deux décimales au plus.' USING ERRCODE = '23514';
        END IF;
        montant_effectif := p_montant;
        CASE p_type
            WHEN 'AMELIORATION' THEN
                IF p_montant IS NULL OR p_montant <= 0 OR plan."CoutBrut" + p_montant > 9999999999999999.99 THEN
                    RAISE EXCEPTION 'Indiquez un coût d’amélioration positif compatible avec la valeur du bien.' USING ERRCODE = '23514';
                END IF;
                IF p_date_effet >= plan."DateFinExclusive" THEN
                    RAISE EXCEPTION 'Une amélioration après la fin du plan nécessite une nouvelle base validée hors de ce parcours.' USING ERRCODE = '23514';
                END IF;
            WHEN 'DEPRECIATION' THEN
                IF p_montant IS NULL OR p_montant <= 0 OR p_montant > plan."ValeurNetteComptable" THEN
                    RAISE EXCEPTION 'La perte doit être positive et au plus égale à la valeur nette du plan.' USING ERRCODE = '23514';
                END IF;
            WHEN 'CESSION' THEN
                IF p_montant IS NULL THEN
                    RAISE EXCEPTION 'Indiquez le produit de cession, zéro compris.' USING ERRCODE = '23514';
                END IF;
                valeur_sortie := plan."ValeurNetteComptable";
            WHEN 'REBUT' THEN
                IF coalesce(p_montant, 0) <> 0 THEN
                    RAISE EXCEPTION 'Le montant d’une mise au rebut est zéro.' USING ERRCODE = '23514';
                END IF;
                montant_effectif := 0;
                valeur_sortie := plan."ValeurNetteComptable";
        END CASE;
    END IF;

    INSERT INTO logistique."T_ImmobilisationEvenementValeur" (
        "ID_PlanFk", "IdEntiteFk", "TypeEvenement", "DateEffet", "Montant", "Motif",
        "ValeurAvantSortie", "CreeParUserFk", "Demande", "EmpreinteDemande"
    ) VALUES (
        p_plan, p_entite, p_type, p_date_effet, montant_effectif, btrim(p_motif),
        valeur_sortie, p_acteur, p_demande, p_hash
    ) RETURNING "ID_EvenementValeur" INTO identifiant;
    RETURN identifiant;
END
$$;
COMMENT ON FUNCTION logistique.fn_enregistrer_evenement_valorisation(bigint, integer, integer, uuid, text, text, text, date, numeric, text)
    IS 'Constate une dotation ou un événement validé. Empêche les doubles écritures, les dépassements et les événements contradictoires avec le suivi physique ou une clôture.';

CREATE FUNCTION logistique.fn_cloturer_valorisation(
    p_entite integer, p_acteur integer, p_demande uuid, p_hash text, p_usage text, p_jusqu_au date, p_motif text
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE
    identifiant bigint;
BEGIN
    PERFORM logistique.fn_contexte_valorisation_immobilisation(p_entite, p_acteur, p_demande, p_hash, p_motif);
    identifiant := logistique.fn_rejouer_valorisation_immobilisation(p_entite, p_acteur, p_demande, p_hash, 'CLOTURE');
    IF identifiant IS NOT NULL THEN RETURN identifiant; END IF;

    IF p_usage IS NULL OR p_usage NOT IN ('COMPTABLE', 'FISCAL') OR p_jusqu_au IS NULL
        OR p_jusqu_au NOT BETWEEN DATE '1900-01-01' AND (clock_timestamp() AT TIME ZONE 'Africa/Kinshasa')::date THEN
        RAISE EXCEPTION 'Indiquez l’usage et une date de clôture qui ne dépasse pas aujourd’hui.' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (
        SELECT FROM logistique."T_ImmobilisationClotureValeur" h
        WHERE h."IdEntiteFk" = p_entite AND h."UsagePlan" = p_usage AND h."JusquAu" >= p_jusqu_au
    ) THEN
        RAISE EXCEPTION 'La nouvelle clôture doit avancer la dernière date clôturée.' USING ERRCODE = '23514';
    END IF;
    PERFORM FROM logistique."T_Immobilisation" i
    JOIN logistique."T_ImmobilisationPlan" p ON p."ID_ImmobilisationFk" = i."ID_Immobilisation"
    WHERE p."IdEntiteFk" = p_entite AND p."UsagePlan" = p_usage
    ORDER BY i."ID_Immobilisation" FOR UPDATE OF i;
    IF EXISTS (
        SELECT FROM logistique."V_ImmobilisationPlan" p
        WHERE p."IdEntiteFk" = p_entite AND p."UsagePlan" = p_usage AND p."DateDebut" <= p_jusqu_au
          AND ((p."DateSortiePhysique" <= p_jusqu_au AND p."DateSortie" IS NULL)
              OR logistique.fn_dotation_restante_immobilisation(p."ID_Plan", p_jusqu_au) > 0)
    ) THEN
        RAISE EXCEPTION 'Constatez les dotations et les sorties en attente avant la clôture.' USING ERRCODE = '23514';
    END IF;
    INSERT INTO logistique."T_ImmobilisationClotureValeur" (
        "IdEntiteFk", "UsagePlan", "JusquAu", "Motif", "CreeParUserFk", "Demande", "EmpreinteDemande"
    ) VALUES (
        p_entite, p_usage, p_jusqu_au, btrim(p_motif), p_acteur, p_demande, p_hash
    ) RETURNING "ID_ClotureValeur" INTO identifiant;
    RETURN identifiant;
END
$$;
COMMENT ON FUNCTION logistique.fn_cloturer_valorisation(integer, integer, uuid, text, text, date, text)
    IS 'Ajoute une borne de clôture indépendante par usage après rapprochement des dotations et sorties physiques, sous verrou des biens concernés.';

CREATE FUNCTION logistique.tr_immobilisation_sortie_valorisation() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
    IF EXISTS (
        SELECT FROM logistique."V_ImmobilisationPlan" p
        WHERE p."ID_ImmobilisationFk" = NEW."ID_ImmobilisationFk"
          AND (NEW."DateEvenement" < p."DateDebut" OR NEW."DateEvenement" <= p."ClotureJusquAu"
            OR NEW."DateEvenement" <= p."DerniereDateAmortie" OR NEW."DateEvenement" <= p."DerniereDateAjustement")
    ) THEN
        RAISE EXCEPTION 'La date de sortie est incompatible avec un plan validé, des écritures déjà constatées ou une clôture. Faites vérifier la date par le responsable comptable.'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END
$$;
COMMENT ON FUNCTION logistique.tr_immobilisation_sortie_valorisation() IS 'Sous le verrou du bien pris par le trigger physique précédent, refuse une date qui contredirait les valeurs constatées. La sortie physique peut être enregistrée avant sa constatation comptable.';
CREATE TRIGGER b_immobilisation_sortie_valorisation
    BEFORE INSERT ON logistique."T_ImmobilisationEvenement"
    FOR EACH ROW WHEN (NEW."TypeEvenement" IN ('CESSION', 'REBUT'))
    EXECUTE FUNCTION logistique.tr_immobilisation_sortie_valorisation();
COMMENT ON TRIGGER b_immobilisation_sortie_valorisation ON logistique."T_ImmobilisationEvenement"
    IS 'Protège les plans comptable et fiscal pendant l’enregistrement d’une sortie physique.';

REVOKE EXECUTE ON FUNCTION logistique.fn_contexte_valorisation_immobilisation(integer, integer, uuid, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION logistique.fn_creer_plan_immobilisation(bigint, integer, integer, uuid, text, text, text, text, numeric, numeric, date, integer, integer, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION logistique.fn_enregistrer_evenement_valorisation(bigint, integer, integer, uuid, text, text, text, date, numeric, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION logistique.fn_cloturer_valorisation(integer, integer, uuid, text, text, date, text) FROM PUBLIC;
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'sauverndeko_runtime') THEN
        REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON logistique."T_ImmobilisationPlan",
            logistique."T_ImmobilisationEvenementValeur", logistique."T_ImmobilisationClotureValeur" FROM sauverndeko_runtime;
        GRANT SELECT ON logistique."T_ImmobilisationPlan", logistique."T_ImmobilisationEvenementValeur",
            logistique."T_ImmobilisationClotureValeur", logistique."V_ImmobilisationPlan" TO sauverndeko_runtime;
        GRANT EXECUTE ON FUNCTION logistique.fn_creer_plan_immobilisation(bigint, integer, integer, uuid, text, text, text, text, numeric, numeric, date, integer, integer, text, text) TO sauverndeko_runtime;
        GRANT EXECUTE ON FUNCTION logistique.fn_enregistrer_evenement_valorisation(bigint, integer, integer, uuid, text, text, text, date, numeric, text) TO sauverndeko_runtime;
        GRANT EXECUTE ON FUNCTION logistique.fn_cloturer_valorisation(integer, integer, uuid, text, text, date, text) TO sauverndeko_runtime;
    END IF;
END
$$;
