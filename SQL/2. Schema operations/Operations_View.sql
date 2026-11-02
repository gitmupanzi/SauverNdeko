-- Extrait canonique du catalogue installé le 02/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_Caisse; Type: VIEW; Schema: operations; Owner: -
--

CREATE VIEW operations."V_Caisse" AS
 SELECT c."IdCaisse",
    c."IdDeviseFk",
    c."MontantCaisse",
    c."IdEntiteFk",
    c."CodeCaisse",
    c."NomCaisse",
    c."IdTypeCaisseFk",
    c."IdResponsableFk",
    c."Actif",
    c."CreeLe",
    c."ModifieLe",
    c."Revision",
    c."CreationRequestId",
    c."CreationPayloadHash",
    e."NomEntite",
    COALESCE(NULLIF((g."AbrGenerique")::text, ''::text), (g."NomGenerique")::text) AS "DeviseCode",
    (g."NomGenerique")::text AS "DeviseLibelle",
    (t."NomGenerique")::text AS "TypeCaisse",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "Responsable",
    COALESCE(p.balance, (0)::numeric) AS "SoldeTheorique",
    (c."MontantCaisse" - COALESCE(p.balance, (0)::numeric)) AS "EcartsRapprochement",
    COALESCE(p.n, (0)::bigint) AS "NombreEcritures",
    COALESCE(p.d, (0)::bigint) AS "NbBrouillons",
    cl.lastdate AS "DerniereClotureLe"
   FROM ((((((operations."T_Caisse" c
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = c."IdEntiteFk")))
     JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = c."IdDeviseFk")))
     LEFT JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = c."IdTypeCaisseFk")))
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = c."IdResponsableFk")))
     LEFT JOIN LATERAL ( SELECT sum((("T_Paiement"."SensMouvement")::numeric * "T_Paiement"."MontantPaiement")) FILTER (WHERE ("T_Paiement"."EtatEcriture" = 'POSTED'::text)) AS balance,
            count(*) FILTER (WHERE ("T_Paiement"."EtatEcriture" = 'POSTED'::text)) AS n,
            count(*) FILTER (WHERE (("T_Paiement"."EtatEcriture" = 'DRAFT'::text) AND "T_Paiement"."ValidePaiement")) AS d
           FROM operations."T_Paiement"
          WHERE ("T_Paiement"."IdCaisseFk" = c."IdCaisse")) p ON (true))
     LEFT JOIN LATERAL ( SELECT max("T_ClotureCaisse"."ClotureLe") AS lastdate
           FROM operations."T_ClotureCaisse"
          WHERE ("T_ClotureCaisse"."IdCaisseFk" = c."IdCaisse")) cl ON (true));

--
-- Name: VIEW "V_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON VIEW operations."V_Caisse" IS 'Registre des caisses par entreprise et devise, avec rapprochement du journal, brouillons et dernière clôture. Aucun total multidevise.';

--
-- Name: COLUMN "V_Caisse"."IdCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."IdCaisse" IS 'Projection de lecture : IdCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."IdDeviseFk" IS 'Projection de lecture : IdDeviseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."MontantCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."MontantCaisse" IS 'Projection de lecture : MontantCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."IdEntiteFk" IS 'Projection de lecture : IdEntiteFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."CodeCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."CodeCaisse" IS 'Projection de lecture : CodeCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."NomCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."NomCaisse" IS 'Projection de lecture : NomCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."IdTypeCaisseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."IdTypeCaisseFk" IS 'Projection de lecture : IdTypeCaisseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."IdResponsableFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."IdResponsableFk" IS 'Projection de lecture : IdResponsableFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."Actif"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."Actif" IS 'Projection de lecture : Actif ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."CreeLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."CreeLe" IS 'Projection de lecture : CreeLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."ModifieLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."ModifieLe" IS 'Projection de lecture : ModifieLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."Revision"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."Revision" IS 'Projection de lecture : Revision ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."CreationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."CreationRequestId" IS 'Projection de lecture : CreationRequestId ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."CreationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."CreationPayloadHash" IS 'Projection de lecture : CreationPayloadHash ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."NomEntite"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."NomEntite" IS 'Projection de lecture : NomEntite ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."DeviseCode"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."DeviseCode" IS 'Projection de lecture : DeviseCode ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."DeviseLibelle"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."DeviseLibelle" IS 'Projection de lecture : DeviseLibelle ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."TypeCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."TypeCaisse" IS 'Projection de lecture : TypeCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."Responsable"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."Responsable" IS 'Projection de lecture : Responsable ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."SoldeTheorique"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."SoldeTheorique" IS 'Projection de lecture : SoldeTheorique ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."EcartsRapprochement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."EcartsRapprochement" IS 'Projection de lecture : EcartsRapprochement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."NombreEcritures"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."NombreEcritures" IS 'Projection de lecture : NombreEcritures ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."NbBrouillons"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."NbBrouillons" IS 'Projection de lecture : NbBrouillons ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_Caisse"."DerniereClotureLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_Caisse"."DerniereClotureLe" IS 'Projection de lecture : DerniereClotureLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: V_ClotureCaisse; Type: VIEW; Schema: operations; Owner: -
--

CREATE VIEW operations."V_ClotureCaisse" AS
 SELECT cl."ID_ClotureCaisse",
    cl."IdCaisseFk",
    cl."IdEntiteFk",
    cl."IdDeviseFk",
    cl."ClotureLe",
    cl."SoldeTheorique",
    cl."MontantCompte",
    cl."Ecart",
    cl."Motif",
    cl."IdUserFk",
    cl."CreationRequestId",
    cl."CreationPayloadHash",
    cl."CreeLe",
    c."CodeCaisse",
    c."NomCaisse",
    e."NomEntite",
    COALESCE(NULLIF((g."AbrGenerique")::text, ''::text), (g."NomGenerique")::text) AS "DeviseCode",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "Auteur"
   FROM ((((operations."T_ClotureCaisse" cl
     JOIN operations."T_Caisse" c ON ((c."IdCaisse" = cl."IdCaisseFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = cl."IdEntiteFk")))
     JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = cl."IdDeviseFk")))
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = cl."IdUserFk")));

--
-- Name: VIEW "V_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON VIEW operations."V_ClotureCaisse" IS 'Registre de clôture physique de caisse avec propriétaire, devise et auteur, sans modification du journal.';

--
-- Name: COLUMN "V_ClotureCaisse"."ID_ClotureCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."ID_ClotureCaisse" IS 'Projection de lecture : ID_ClotureCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."IdCaisseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."IdCaisseFk" IS 'Projection de lecture : IdCaisseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."IdEntiteFk" IS 'Projection de lecture : IdEntiteFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."IdDeviseFk" IS 'Projection de lecture : IdDeviseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."ClotureLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."ClotureLe" IS 'Projection de lecture : ClotureLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."SoldeTheorique"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."SoldeTheorique" IS 'Projection de lecture : SoldeTheorique ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."MontantCompte"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."MontantCompte" IS 'Projection de lecture : MontantCompte ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."Ecart"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."Ecart" IS 'Projection de lecture : Ecart ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."Motif"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."Motif" IS 'Projection de lecture : Motif ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."IdUserFk" IS 'Projection de lecture : IdUserFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."CreationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."CreationRequestId" IS 'Projection de lecture : CreationRequestId ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."CreationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."CreationPayloadHash" IS 'Projection de lecture : CreationPayloadHash ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."CreeLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."CreeLe" IS 'Projection de lecture : CreeLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."CodeCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."CodeCaisse" IS 'Projection de lecture : CodeCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."NomCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."NomCaisse" IS 'Projection de lecture : NomCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."NomEntite"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."NomEntite" IS 'Projection de lecture : NomEntite ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."DeviseCode"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."DeviseCode" IS 'Projection de lecture : DeviseCode ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_ClotureCaisse"."Auteur"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_ClotureCaisse"."Auteur" IS 'Projection de lecture : Auteur ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: V_FluxCaisseJournalier; Type: VIEW; Schema: operations; Owner: -
--

CREATE VIEW operations."V_FluxCaisseJournalier" AS
 SELECT ((p."DatePaiement" AT TIME ZONE 'Africa/Kinshasa'::text))::date AS "DateJour",
    p."IdEntiteFk",
    p."IdCaisseFk",
    p."IdDeviseFk",
    c."NomCaisse",
    c."CodeCaisse",
    e."NomEntite",
    COALESCE(NULLIF((g."AbrGenerique")::text, ''::text), (g."NomGenerique")::text) AS "DeviseCode",
    COALESCE(sum(p."MontantPaiement") FILTER (WHERE (p."SensMouvement" = 1)), (0)::numeric) AS "MontantEntree",
    COALESCE(sum(p."MontantPaiement") FILTER (WHERE (p."SensMouvement" = '-1'::integer)), (0)::numeric) AS "MontantSortie",
    sum(((p."SensMouvement")::numeric * p."MontantPaiement")) AS "NetJour",
    count(*) AS "NbEcritures"
   FROM (((operations."T_Paiement" p
     JOIN operations."T_Caisse" c ON ((c."IdCaisse" = p."IdCaisseFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = p."IdEntiteFk")))
     JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = p."IdDeviseFk")))
  WHERE (p."EtatEcriture" = 'POSTED'::text)
  GROUP BY (((p."DatePaiement" AT TIME ZONE 'Africa/Kinshasa'::text))::date), p."IdEntiteFk", p."IdCaisseFk", p."IdDeviseFk", c."NomCaisse", c."CodeCaisse", e."NomEntite", COALESCE(NULLIF((g."AbrGenerique")::text, ''::text), (g."NomGenerique")::text);

--
-- Name: VIEW "V_FluxCaisseJournalier"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON VIEW operations."V_FluxCaisseJournalier" IS 'Flux validés journaliers à Kinshasa par caisse, entreprise et devise ; entrées, sorties et compensations restent dans le même journal.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."DateJour"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."DateJour" IS 'Projection de lecture : DateJour ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."IdEntiteFk" IS 'Projection de lecture : IdEntiteFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."IdCaisseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."IdCaisseFk" IS 'Projection de lecture : IdCaisseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."IdDeviseFk" IS 'Projection de lecture : IdDeviseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."NomCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."NomCaisse" IS 'Projection de lecture : NomCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."CodeCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."CodeCaisse" IS 'Projection de lecture : CodeCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."NomEntite"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."NomEntite" IS 'Projection de lecture : NomEntite ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."DeviseCode"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."DeviseCode" IS 'Projection de lecture : DeviseCode ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."MontantEntree"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."MontantEntree" IS 'Projection de lecture : MontantEntree ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."MontantSortie"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."MontantSortie" IS 'Projection de lecture : MontantSortie ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."NetJour"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."NetJour" IS 'Projection de lecture : NetJour ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_FluxCaisseJournalier"."NbEcritures"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_FluxCaisseJournalier"."NbEcritures" IS 'Projection de lecture : NbEcritures ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: V_JournalCaisse; Type: VIEW; Schema: operations; Owner: -
--

CREATE VIEW operations."V_JournalCaisse" AS
 SELECT p."IdPaiement",
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
    p."IdEntiteFk",
    p."IdCaisseFk",
    p."SensMouvement",
    p."EtatEcriture",
    p."LibellePaiement",
    p."ReferenceExterne",
    p."IdTiersFk",
    p."IdReglementFk",
    p."IdPaiementOrigineFk",
    p."CreationRequestId",
    p."CreationPayloadHash",
    p."ValidationRequestId",
    p."ValidationPayloadHash",
    p."CreeLe",
    p."ModifieLe",
    p."ValideLe",
    p."IdValidateurFk",
    p."Revision",
    p."DeviseCodeSnapshot",
    c."CodeCaisse",
    c."NomCaisse",
    e."NomEntite",
    COALESCE(p."DeviseCodeSnapshot", NULLIF((g."AbrGenerique")::text, ''::text), (g."NomGenerique")::text) AS "DeviseCode",
    (g."NomGenerique")::text AS "DeviseLibelle",
    (t."NomGenerique")::text AS "TypePaiement",
    tiers."Nom" AS "NomTiers",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "Auteur",
    concat_ws(' '::text, v."PrenomUser", v."NomUser") AS "Validateur",
    r."CodeFactureFk",
    o."CodePaiement" AS "CodePaiementOrigine",
    cp."IdPaiement" AS "IdCompensateurFk",
    cp."CodePaiement" AS "CodeCompensateur",
        CASE
            WHEN (p."EtatEcriture" = 'POSTED'::text) THEN ((p."SensMouvement")::numeric * p."MontantPaiement")
            ELSE (0)::numeric
        END AS "MontantSigne",
        CASE
            WHEN (p."EtatEcriture" = 'POSTED'::text) THEN sum(
            CASE
                WHEN (p."EtatEcriture" = 'POSTED'::text) THEN ((p."SensMouvement")::numeric * p."MontantPaiement")
                ELSE (0)::numeric
            END) OVER (PARTITION BY p."IdCaisseFk" ORDER BY p."ValideLe", p."IdPaiement" ROWS UNBOUNDED PRECEDING)
            ELSE NULL::numeric
        END AS "SoldeApres"
   FROM ((((((((((operations."T_Paiement" p
     JOIN operations."T_Caisse" c ON ((c."IdCaisse" = p."IdCaisseFk")))
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = p."IdEntiteFk")))
     JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = p."IdDeviseFk")))
     LEFT JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = p."IdTypePaiementFk")))
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = p."IdUserFk")))
     LEFT JOIN systeme."T_Utilisateurs" v ON ((v."IdUser" = p."IdValidateurFk")))
     LEFT JOIN logistique."T_Client" tiers ON ((tiers."ID_Client" = p."IdTiersFk")))
     LEFT JOIN logistique."T_Reglements" r ON ((r."ID_Reglement" = p."IdReglementFk")))
     LEFT JOIN operations."T_Paiement" o ON ((o."IdPaiement" = p."IdPaiementOrigineFk")))
     LEFT JOIN operations."T_Paiement" cp ON ((cp."IdPaiementOrigineFk" = p."IdPaiement")));

--
-- Name: VIEW "V_JournalCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON VIEW operations."V_JournalCaisse" IS 'Journal enrichi et solde après validation dans l’ordre technique ValideLe/IdPaiement ; les brouillons n’affectent aucun solde.';

--
-- Name: COLUMN "V_JournalCaisse"."IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdPaiement" IS 'Projection de lecture : IdPaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CodePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CodePaiement" IS 'Projection de lecture : CodePaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdUserFk" IS 'Projection de lecture : IdUserFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdTypePaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdTypePaiementFk" IS 'Projection de lecture : IdTypePaiementFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."MontantPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."MontantPaiement" IS 'Projection de lecture : MontantPaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdStatutPaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdStatutPaiementFk" IS 'Projection de lecture : IdStatutPaiementFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."DatePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."DatePaiement" IS 'Projection de lecture : DatePaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."ObsPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."ObsPaiement" IS 'Projection de lecture : ObsPaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."ValidePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."ValidePaiement" IS 'Projection de lecture : ValidePaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdDeviseFk" IS 'Projection de lecture : IdDeviseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdPayeurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdPayeurFk" IS 'Projection de lecture : IdPayeurFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdTypeMouvementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdTypeMouvementFk" IS 'Projection de lecture : IdTypeMouvementFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdEntiteFk" IS 'Projection de lecture : IdEntiteFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdCaisseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdCaisseFk" IS 'Projection de lecture : IdCaisseFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."SensMouvement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."SensMouvement" IS 'Projection de lecture : SensMouvement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."EtatEcriture"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."EtatEcriture" IS 'Projection de lecture : EtatEcriture ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."LibellePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."LibellePaiement" IS 'Projection de lecture : LibellePaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."ReferenceExterne"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."ReferenceExterne" IS 'Projection de lecture : ReferenceExterne ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdTiersFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdTiersFk" IS 'Projection de lecture : IdTiersFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdReglementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdReglementFk" IS 'Projection de lecture : IdReglementFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdPaiementOrigineFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdPaiementOrigineFk" IS 'Projection de lecture : IdPaiementOrigineFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CreationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CreationRequestId" IS 'Projection de lecture : CreationRequestId ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CreationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CreationPayloadHash" IS 'Projection de lecture : CreationPayloadHash ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."ValidationRequestId"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."ValidationRequestId" IS 'Projection de lecture : ValidationRequestId ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."ValidationPayloadHash"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."ValidationPayloadHash" IS 'Projection de lecture : ValidationPayloadHash ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CreeLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CreeLe" IS 'Projection de lecture : CreeLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."ModifieLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."ModifieLe" IS 'Projection de lecture : ModifieLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."ValideLe"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."ValideLe" IS 'Projection de lecture : ValideLe ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdValidateurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdValidateurFk" IS 'Projection de lecture : IdValidateurFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."Revision"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."Revision" IS 'Projection de lecture : Revision ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."DeviseCodeSnapshot"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."DeviseCodeSnapshot" IS 'Projection de lecture : DeviseCodeSnapshot ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CodeCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CodeCaisse" IS 'Projection de lecture : CodeCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."NomCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."NomCaisse" IS 'Projection de lecture : NomCaisse ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."NomEntite"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."NomEntite" IS 'Projection de lecture : NomEntite ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."DeviseCode"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."DeviseCode" IS 'Projection de lecture : DeviseCode ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."DeviseLibelle"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."DeviseLibelle" IS 'Projection de lecture : DeviseLibelle ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."TypePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."TypePaiement" IS 'Projection de lecture : TypePaiement ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."NomTiers"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."NomTiers" IS 'Projection de lecture : NomTiers ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."Auteur"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."Auteur" IS 'Projection de lecture : Auteur ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."Validateur"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."Validateur" IS 'Projection de lecture : Validateur ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CodeFactureFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CodeFactureFk" IS 'Projection de lecture : CodeFactureFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CodePaiementOrigine"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CodePaiementOrigine" IS 'Projection de lecture : CodePaiementOrigine ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."IdCompensateurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."IdCompensateurFk" IS 'Projection de lecture : IdCompensateurFk ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."CodeCompensateur"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."CodeCompensateur" IS 'Projection de lecture : CodeCompensateur ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."MontantSigne"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."MontantSigne" IS 'Projection de lecture : MontantSigne ; périmètre entreprise et devise du registre de caisse.';

--
-- Name: COLUMN "V_JournalCaisse"."SoldeApres"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."V_JournalCaisse"."SoldeApres" IS 'Projection de lecture : SoldeApres ; périmètre entreprise et devise du registre de caisse.';
