-- View: operations.V_AuditCaisse

-- DROP VIEW operations."V_AuditCaisse";

CREATE OR REPLACE VIEW operations."V_AuditCaisse"
 AS
 WITH paiements_union AS (
         SELECT p."IdDeviseFk",
            p."IdEntiteFk",
            p."IdTypeMouvementFk",
            p."MontantPaiement",
            p."IdStatutPaiementFk"
           FROM operations."T_Paiement" p
        UNION ALL
         SELECT pa."IdDeviseFk",
            pa."IdEntiteFk",
            pa."IdTypeMouvementFk",
            pa."MontantPaiement",
            pa."IdStatutPaiementFk"
           FROM operations."T_Paiement_Archive" pa
        ), flux AS (
         SELECT u."IdDeviseFk",
            u."IdEntiteFk",
            sum(
                CASE
                    WHEN u."IdStatutPaiementFk" = 21 AND u."IdTypeMouvementFk" = 81 AND (u."IdDeviseFk" = ANY (ARRAY[36, 37])) THEN u."MontantPaiement"
                    WHEN u."IdStatutPaiementFk" = 21 AND u."IdTypeMouvementFk" = 80 AND (u."IdDeviseFk" = ANY (ARRAY[36, 37])) THEN - u."MontantPaiement"
                    ELSE 0::numeric
                END) AS solde_theorique
           FROM paiements_union u
          GROUP BY u."IdDeviseFk", u."IdEntiteFk"
        )
 SELECT c."IdCaisse",
    c."IdDeviseFk",
    dev."NomGenerique" AS "NomDevise",
    c."IdEntiteFk",
    ent."NomEntite",
    c."MontantCaisse" AS "SoldeCaisse",
    COALESCE(f.solde_theorique, 0::numeric) AS "SoldeTheorique",
    c."MontantCaisse" - COALESCE(f.solde_theorique, 0::numeric) AS "Ecart"
   FROM operations."T_Caisse" c
     LEFT JOIN flux f ON f."IdDeviseFk" = c."IdDeviseFk" AND f."IdEntiteFk" = c."IdEntiteFk"
     LEFT JOIN referentiel."T_Generique" dev ON dev."ID_Generique" = c."IdDeviseFk"
     LEFT JOIN systeme."T_Entite" ent ON ent."IdEntite" = c."IdEntiteFk";

ALTER TABLE operations."V_AuditCaisse"
    OWNER TO postgres;
COMMENT ON VIEW operations."V_AuditCaisse"
    IS 'Audit des caisses : comparaison du solde enregistré avec le solde théorique recalculé à partir des paiements (actifs + archivés).';

-- View: operations.V_CaisseDetail

-- DROP VIEW operations."V_CaisseDetail";

CREATE OR REPLACE VIEW operations."V_CaisseDetail"
 AS
 SELECT c."IdCaisse",
    c."IdDeviseFk",
    dev."NomGenerique" AS "NomDevise",
    c."IdEntiteFk",
    ent."NomEntite",
    c."MontantCaisse"
   FROM operations."T_Caisse" c
     LEFT JOIN referentiel."T_Generique" dev ON dev."ID_Generique" = c."IdDeviseFk"
     LEFT JOIN systeme."T_Entite" ent ON ent."IdEntite" = c."IdEntiteFk";

ALTER TABLE operations."V_CaisseDetail"
    OWNER TO postgres;
COMMENT ON VIEW operations."V_CaisseDetail"
    IS 'Détail des caisses par devise et entité avec libellés (NomDevise, NomEntite).';

-- View: operations.V_PaiementDetail

-- DROP VIEW operations."V_PaiementDetail";

CREATE OR REPLACE VIEW operations."V_PaiementDetail"
 AS
 SELECT p."IdPaiement",
    p."CodePaiement",
    p."DatePaiement",
    p."MontantPaiement",
    p."ObsPaiement",
    p."ValidePaiement",
    p."IdDeviseFk",
    dev."NomGenerique" AS "NomDevise",
    p."IdTypePaiementFk",
    typep."NomGenerique" AS "NomTypePaiement",
    p."IdStatutPaiementFk",
    statut."NomGenerique" AS "NomStatutPaiement",
    p."IdTypeMouvementFk",
    mvt."NomGenerique" AS "NomTypeMouvement",
    p."IdEntiteFk",
    ent."NomEntite",
    p."IdUserFk",
    u."NomUser",
    p."IdPayeurFk",
    payeur."NomUser" AS "NomPayeur"
   FROM operations."T_Paiement" p
     LEFT JOIN referentiel."T_Generique" dev ON dev."ID_Generique" = p."IdDeviseFk"
     LEFT JOIN referentiel."T_Generique" typep ON typep."ID_Generique" = p."IdTypePaiementFk"
     LEFT JOIN referentiel."T_Generique" statut ON statut."ID_Generique" = p."IdStatutPaiementFk"
     LEFT JOIN referentiel."T_Generique" mvt ON mvt."ID_Generique" = p."IdTypeMouvementFk"
     LEFT JOIN systeme."T_Entite" ent ON ent."IdEntite" = p."IdEntiteFk"
     LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p."IdUserFk"
     LEFT JOIN systeme."T_Utilisateurs" payeur ON payeur."IdUser" = p."IdPayeurFk";

ALTER TABLE operations."V_PaiementDetail"
    OWNER TO postgres;
COMMENT ON VIEW operations."V_PaiementDetail"
    IS 'Vue détaillée des paiements avec libellés (devise, type, statut, mouvement, entité, utilisateurs).';

-- View: operations.V_PaiementsActifsEtArchives

-- DROP VIEW operations."V_PaiementsActifsEtArchives";

CREATE OR REPLACE VIEW operations."V_PaiementsActifsEtArchives"
 AS
 SELECT 'Actif'::text AS "SourcePaiement",
    p."IdPaiement" AS "IdPaiementSource",
    p."CodePaiement",
    p."IdUserFk",
    p."IdTypePaiementFk",
    p."MontantPaiement",
    p."IdStatutPaiementFk",
    p."DatePaiement",
    p."ObsPaiement",
    p."ValidePaiement",
    p."IdDeviseFk",
    p."IdPayeurFk",
    p."IdTypeMouvementFk",
    p."IdEntiteFk"
   FROM operations."T_Paiement" p
UNION ALL
 SELECT 'Archive'::text AS "SourcePaiement",
    pa."IdPaiement" AS "IdPaiementSource",
    pa."CodePaiement",
    pa."IdUserFk",
    pa."IdTypePaiementFk",
    pa."MontantPaiement",
    pa."IdStatutPaiementFk",
    pa."DatePaiement",
    pa."ObsPaiement",
    pa."ValidePaiement",
    pa."IdDeviseFk",
    pa."IdPayeurFk",
    pa."IdTypeMouvementFk",
    pa."IdEntiteFk"
   FROM operations."T_Paiement_Archive" pa;

ALTER TABLE operations."V_PaiementsActifsEtArchives"
    OWNER TO postgres;
COMMENT ON VIEW operations."V_PaiementsActifsEtArchives"
    IS 'Historique unifié des paiements (actifs + archivés) avec indication de la source.';

-- View: operations.V_PaiementsJournalier

-- DROP VIEW operations."V_PaiementsJournalier";

CREATE OR REPLACE VIEW operations."V_PaiementsJournalier"
 AS
 SELECT date_trunc('day'::text, p."DatePaiement") AS "DateJour",
    p."IdDeviseFk",
    dev."NomGenerique" AS "NomDevise",
    p."IdEntiteFk",
    ent."NomEntite",
    sum(
        CASE
            WHEN p."IdStatutPaiementFk" = 21 AND p."IdTypeMouvementFk" = 81 THEN p."MontantPaiement"
            ELSE 0::numeric
        END) AS "MontantEntree",
    sum(
        CASE
            WHEN p."IdStatutPaiementFk" = 21 AND p."IdTypeMouvementFk" = 80 THEN p."MontantPaiement"
            ELSE 0::numeric
        END) AS "MontantSortie",
    sum(
        CASE
            WHEN p."IdStatutPaiementFk" = 21 AND p."IdTypeMouvementFk" = 81 THEN p."MontantPaiement"
            WHEN p."IdStatutPaiementFk" = 21 AND p."IdTypeMouvementFk" = 80 THEN - p."MontantPaiement"
            ELSE 0::numeric
        END) AS "NetJour"
   FROM operations."T_Paiement" p
     LEFT JOIN referentiel."T_Generique" dev ON dev."ID_Generique" = p."IdDeviseFk"
     LEFT JOIN systeme."T_Entite" ent ON ent."IdEntite" = p."IdEntiteFk"
  GROUP BY (date_trunc('day'::text, p."DatePaiement")), p."IdDeviseFk", dev."NomGenerique", p."IdEntiteFk", ent."NomEntite";

ALTER TABLE operations."V_PaiementsJournalier"
    OWNER TO postgres;
COMMENT ON VIEW operations."V_PaiementsJournalier"
    IS 'Flux journalier de caisse par devise et entité (entrées, sorties, net).';
-- View: operations.V_PaiementsParStatut

-- DROP VIEW operations."V_PaiementsParStatut";

CREATE OR REPLACE VIEW operations."V_PaiementsParStatut"
 AS
 SELECT date_trunc('day'::text, p."DatePaiement") AS "DateJour",
    p."IdStatutPaiementFk",
    statut."NomGenerique" AS "NomStatutPaiement",
    p."IdDeviseFk",
    dev."NomGenerique" AS "NomDevise",
    p."IdEntiteFk",
    ent."NomEntite",
    count(*) AS "NbPaiements",
    sum(p."MontantPaiement") AS "MontantTotal"
   FROM operations."T_Paiement" p
     LEFT JOIN referentiel."T_Generique" statut ON statut."ID_Generique" = p."IdStatutPaiementFk"
     LEFT JOIN referentiel."T_Generique" dev ON dev."ID_Generique" = p."IdDeviseFk"
     LEFT JOIN systeme."T_Entite" ent ON ent."IdEntite" = p."IdEntiteFk"
  GROUP BY (date_trunc('day'::text, p."DatePaiement")), p."IdStatutPaiementFk", statut."NomGenerique", p."IdDeviseFk", dev."NomGenerique", p."IdEntiteFk", ent."NomEntite";

ALTER TABLE operations."V_PaiementsParStatut"
    OWNER TO postgres;
COMMENT ON VIEW operations."V_PaiementsParStatut"
    IS 'Agrégats de paiements par jour, statut, devise et entité (nombre et montant total).';


