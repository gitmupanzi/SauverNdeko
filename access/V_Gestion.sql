-- V_Generique
SELECT T_CategorieGenerique.NomCategorieGenerique,
    T_Generique.NomGenerique,
    T_Generique.AbreviationGenerique,
    T_Generique.MasqueProduit,
    T_Generique.MasqueCmd,
    T_Generique.MasqueFacture,
    T_Generique.MasqueBudget,
    T_Generique.MasqueIntervention,
    T_Generique.MasqueODP,
    T_Generique.MasquePersonnel,
    T_Generique.MasqueContact,
    T_Generique.MasqueSsProvince,
    T_Generique.MasqueZone,
    T_Generique.MasqueSite,
    T_Generique.MasqueTransport,
    T_Generique.MasqueAll,
    T_Generique.Observation,
    T_CategorieGenerique.ModuleCategorieGenerique,
    T_Generique.ID_Generique,
    T_Generique.ID_CategorieGenerique
FROM T_Generique
    INNER JOIN T_CategorieGenerique ON T_Generique.ID_CategorieGenerique = T_CategorieGenerique.ID_CategorieGenerique
ORDER BY T_CategorieGenerique.NomCategorieGenerique,
    T_Generique.NomGenerique,
    T_Generique.AbreviationGenerique;
-- V_Pays
SELECT T_Pays.ID_Pays,
    T_Pays.NomPays AS PAYS,
    T_Pays.CodePays AS CODE,
    DCount(
        "ID_Region",
        "T_Region",
        "ID_PaysFk=" & [T_Pays].[ID_Pays] & " AND FusionRegion=FALSE"
    ) AS NBR_PROVINCE
FROM T_Pays;
-- V_Region
SELECT T_Region.ID_PaysFk,
    T_Region.ID_AncienneRegionFk,
    T_Region.ID_Region,
    T_Pays.NomPays,
    T_AncienneRegion.NomAncien,
    T_Region.Nom_Region,
    T_Region.AbreReg,
    T_Region.CodeNationalRegion,
    T_Region.PopulationRegion,
    T_Region.LatitudeRegion,
    T_Region.LongitudeRegion,
    T_Region.EtenduRegion,
    T_Region.ObsRegion,
    T_Region.FusionRegion,
    DCount(
        "ID_Antenne",
        "T_Antenne",
        "ID_RegionFK=" & T_Region.ID_Region
    ) AS NBR_ANT,
    T_Region.MasqueProvince,
    T_Region.MasqueBudget,
    T_Region.MasqueIntervention,
    T_Region.MasqueSite
FROM (
        T_Region
        LEFT JOIN T_AncienneRegion ON T_Region.ID_AncienneRegionFk = T_AncienneRegion.ID_AncienneR
    )
    LEFT JOIN T_Pays ON T_Region.ID_PaysFk = T_Pays.ID_Pays
ORDER BY T_Pays.NomPays,
    T_Region.Nom_Region;
-- V_Antenne
SELECT T_Pays.NomPays,
    T_Region.Nom_Region,
    T_Antenne.ID_TypeAntFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & T_Antenne.ID_TypeAntFk
        ),
        " "
    ) AS TYPE,
    T_Antenne.NomAntenne,
    T_Antenne.AbreSSregion,
    T_Antenne.CodeNationalSSRegion,
    T_Antenne.PopulationAnt,
    T_Antenne.LatitudeAnt,
    T_Antenne.LongitudeAnt,
    T_Antenne.EtenduAnt,
    T_Antenne.ObsAntenne,
    T_Antenne.ID_StatutAnt,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & T_Antenne.ID_StatutAnt
        ),
        " "
    ) AS STATUT,
    T_Antenne.ID_StatusDeploiFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & T_Antenne.ID_StatusDeploiFk
        ),
        " "
    ) AS STATUS,
    T_Antenne.KmDPSANT,
    T_Antenne.ID_VoieAccesDPSANTFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & T_Antenne.ID_VoieAccesDPSANTFk
        ),
        " "
    ) AS VOIE,
    Nz(
        DCount(
            "ID_ZoneSante",
            "T_ZoneSante",
            "ID_AntenneFK=" & [T_Antenne].[ID_Antenne]
        ),
        0
    ) AS NBR_ZS
FROM (
        T_Pays
        INNER JOIN T_Region ON T_Pays.ID_Pays = T_Region.ID_PaysFk
    )
    INNER JOIN T_Antenne ON T_Region.ID_Region = T_Antenne.ID_RegionFK;
-- V_ZoneSante
SELECT T_ZoneSante.ID_ZoneSante,
    T_Pays.NomPays,
    T_Region.Nom_Region,
    T_Antenne.ID_TypeAntFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [T_Antenne].[ID_TypeAntFk]
        ),
        " "
    ) AS TYPE_ANT,
    T_Antenne.NomAntenne,
    T_ZoneSante.ID_TypeZoneFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [T_ZoneSante].[ID_TypeZoneFk]
        ),
        " "
    ) AS TYPE_ZS,
    T_ZoneSante.Nom_ZoneSante,
    T_ZoneSante.AbreSSZone,
    T_ZoneSante.CodeNationalSSZone,
    T_ZoneSante.PopulationZone,
    T_ZoneSante.LatitudeZone,
    T_ZoneSante.LongitudeZone,
    T_ZoneSante.AltitudeZone,
    T_ZoneSante.EtenduZS,
    T_ZoneSante.ObsZone,
    T_ZoneSante.ID_StatutZone,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [T_ZoneSante].[ID_StatutZone]
        ),
        " "
    ) AS STATUT_ZS,
    T_ZoneSante.ID_StatutDeploieFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [T_ZoneSante].[ID_StatutDeploieFk]
        ),
        " "
    ) AS STATUT_DEPLOI,
    T_ZoneSante.KmAntenneBCZS,
    T_ZoneSante.ID_VoieAccesANTBCZFk,
    T_ZoneSante.KmDPSBCZS,
    T_ZoneSante.ID_VoieAccesDPSBCZFk,
    Nz(
        DCount(
            "ID_StructureSanitaire",
            "T_StructureSanitaire",
            "ID_ZoneSanteFk=" & [T_ZoneSante].[ID_ZoneSante]
        ),
        0
    ) AS NBR_SITE,
    T_Pays.ID_Pays,
    T_Region.ID_Region,
    T_Antenne.ID_Antenne
FROM (
        (
            (
                T_ZoneSante
                INNER JOIN T_Antenne ON T_ZoneSante.ID_AntenneFK = T_Antenne.ID_Antenne
            )
            INNER JOIN T_Region ON T_Antenne.ID_RegionFK = T_Region.ID_Region
        )
        INNER JOIN T_Pays ON T_Region.ID_PaysFk = T_Pays.ID_Pays
    )
ORDER BY T_Region.Nom_Region,
    T_Antenne.NomAntenne,
    T_ZoneSante.Nom_ZoneSante;
-- V_StructureSanitaire
SELECT T_Pays.NomPays,
    T_Region.Nom_Region,
    T_Antenne.NomAntenne,
    T_StructureSanitaire.ID_StatutDeploiementFk,
    T_StructureSanitaire.ID_TypeSiteFk,
    T_StructureSanitaire.Nom_StructureSanitaire,
    Nz(T_Generique.AbreviationGenerique, '') & " " & Nz(T_StructureSanitaire.Nom_StructureSanitaire, '') AS SITE,
    T_StructureSanitaire.AbreSSStructure,
    T_StructureSanitaire.CodeNationalStructure,
    T_StructureSanitaire.PopulationSite,
    T_StructureSanitaire.LatitudeSite,
    T_StructureSanitaire.LongitudeSite,
    T_StructureSanitaire.AltitudeSite,
    T_StructureSanitaire.ID_DispoReseauSite,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & Nz([T_StructureSanitaire].[ID_DispoReseauSite], 0)
        ),
        " "
    ) AS RESEAU,
    T_StructureSanitaire.KmZoneSanteStructure,
    T_StructureSanitaire.ID_VoieAccesZsSiteFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & Nz([T_StructureSanitaire].[ID_VoieAccesZsSiteFk], 0)
        ),
        " "
    ) AS VOIE_ZS_SITE,
    T_StructureSanitaire.ID_StatutSite,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & Nz([T_StructureSanitaire].[ID_StatutSite], 0)
        ),
        " "
    ) AS STATUT_SITE,
    T_StructureSanitaire.ID_StatutDeploiementFk,
    Nz(
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & Nz(
                [T_StructureSanitaire].[ID_StatutDeploiementFk],
                0
            )
        ),
        " "
    ) AS STATUT_DEPL,
    T_StructureSanitaire.ObsSite,
    T_ZoneSante.Nom_ZoneSante,
    T_ZoneSante.KmAntenneBCZS,
    T_StructureSanitaire.ID_TypeToitFk,
    T_ZoneSante.KmDPSBCZS,
    T_StructureSanitaire.QteODP,
    T_StructureSanitaire.PrevisionProj,
    T_StructureSanitaire.SelectSite,
    Nz(
        DCount(
            "ID_Intervention",
            "T_Intervention",
            "ID_StructureSanitaireFk=" & [T_StructureSanitaire].[ID_StructureSanitaire]
        ),
        0
    ) AS NBR_INTERV,
    Nz(
        DCount(
            "ID_Intervention",
            "T_Intervention",
            "Nomdeviation=" & [T_StructureSanitaire].[ID_StructureSanitaire]
        ),
        0
    ) AS NBR_DEV,
    Nz(
        DCount(
            "ID_CommandeFk",
            "T_CommandeDetail",
            "Lieu=" & [T_StructureSanitaire].[ID_StructureSanitaire]
        ),
        0
    ) AS NBR_CMD,
    Nz(
        DCount(
            "ID_Contact",
            "T_Contact",
            "ID_SiteFk=" & [T_StructureSanitaire].[ID_StructureSanitaire]
        ),
        0
    ) AS NBR_CONCT,
    T_Pays.ID_Pays,
    T_Region.ID_Region,
    T_Antenne.ID_TypeAntFk,
    T_Antenne.ID_Antenne,
    T_ZoneSante.ID_TypeZoneFk,
    T_StructureSanitaire.ID_ZoneSanteFk,
    T_StructureSanitaire.ID_StructureSanitaire,
    T_ZoneSante.ID_VoieAccesDPSBCZFk,
    T_ZoneSante.ID_VoieAccesANTBCZFk,
    T_StructureSanitaire.ID_VoieAccesZsSiteFk
FROM (
        (
            (
                (
                    T_StructureSanitaire
                    LEFT JOIN T_Generique ON T_StructureSanitaire.ID_TypeSiteFk = T_Generique.ID_Generique
                )
                INNER JOIN T_ZoneSante ON T_StructureSanitaire.ID_ZoneSanteFk = T_ZoneSante.ID_ZoneSante
            )
            INNER JOIN T_Antenne ON T_ZoneSante.ID_AntenneFK = T_Antenne.ID_Antenne
        )
        INNER JOIN T_Region ON T_Antenne.ID_RegionFK = T_Region.ID_Region
    )
    INNER JOIN T_Pays ON T_Region.ID_PaysFk = T_Pays.ID_Pays
ORDER BY T_Pays.NomPays,
    T_Region.Nom_Region,
    T_ZoneSante.Nom_ZoneSante,
    T_StructureSanitaire.Nom_StructureSanitaire,
    T_Pays.ID_Pays;
-- R_Deploiement
SELECT T_Pays.ID_Pays,
    T_Region.ID_Region,
    T_Antenne.ID_Antenne,
    T_ZoneSante.ID_ZoneSante,
    T_StructureSanitaire.ID_StructureSanitaire,
    T_Pays.NomPays AS PAYS,
    T_Region.Nom_Region AS PROVINCE,
    T_Antenne.NomAntenne AS ANTENNE,
    T_ZoneSante.Nom_ZoneSante AS ZONE,
    T_Generique.AbreviationGenerique AS TYPE,
    T_StructureSanitaire.Nom_StructureSanitaire,
    [AbreviationGenerique] & " " & [Nom_StructureSanitaire] AS SITE,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_VoieAccesZsSiteFk]
    ) AS VOIE_ZsSite,
    T_StructureSanitaire.KmZoneSanteStructure AS KM_BCZ_SITE,
    IIf(
        Nz([ID_VoieAccesANTBCZFk], 0) = 0,
        " ",
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [ID_VoieAccesANTBCZFk]
        )
    ) AS VoieAntBcz,
    T_ZoneSante.KmAntenneBCZS AS KM_ANT_BCZ,
    IIf(
        Nz([ID_VoieAccesDPSBCZFk], 0) = 0,
        " ",
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [ID_VoieAccesDPSBCZFk]
        )
    ) AS VoieBczDps,
    T_ZoneSante.KmDPSBCZS AS KM_DPS_BCZ,
    T_StructureSanitaire.LatitudeSite,
    T_StructureSanitaire.LongitudeSite,
    T_StructureSanitaire.ObsSite,
    DLookUp(
        "Nom",
        "rContactInterv",
        "ID_ZoneSanteFk=" & [ID_ZoneSanteFk] & " And ID_ProjetFKCont=24"
    ) AS MCZ,
    DLookUp(
        "Tel",
        "rContactInterv",
        "ID_ZoneSanteFk=" & [ID_ZoneSanteFk] & " And ID_ProjetFKCont=24"
    ) AS PHONE,
    DLookUp(
        "Email",
        "rContactInterv",
        "ID_ZoneSanteFk=" & [ID_ZoneSanteFk] & " And ID_ProjetFKCont=24"
    ) AS EMAIL
FROM (
        (
            T_Pays
            INNER JOIN T_Region ON T_Pays.ID_Pays = T_Region.ID_PaysFk
        )
        INNER JOIN (
            T_Antenne
            INNER JOIN T_ZoneSante ON T_Antenne.ID_Antenne = T_ZoneSante.ID_AntenneFK
        ) ON T_Region.ID_Region = T_Antenne.ID_RegionFK
    )
    INNER JOIN (
        T_StructureSanitaire
        LEFT JOIN T_Generique ON T_StructureSanitaire.ID_TypeSiteFk = T_Generique.ID_Generique
    ) ON T_ZoneSante.ID_ZoneSante = T_StructureSanitaire.ID_ZoneSanteFk
ORDER BY T_Pays.NomPays,
    T_Region.Nom_Region,
    T_Antenne.NomAntenne,
    T_ZoneSante.Nom_ZoneSante,
    [AbreviationGenerique] & " " & [Nom_StructureSanitaire];
-- V_ODP
SELECT T_Pays.NomPays AS PAYS,
    T_Region.Nom_Region AS PROVINCE,
    T_Antenne.NomAntenne AS ANTENNE,
    T_ZoneSante.Nom_ZoneSante AS BCZ,
    IIf(
        Nz([ID_SiteDeviation], 0) = 0,
        [Nom_ZoneSante],
        IIf(
            [ID_ZoneSanteFk] = DLookUp(
                "ID_ZoneSante",
                "R_Deploiement",
                "ID_StructureSanitaire=" & [ID_SiteDeviation]
            ),
            [Nom_ZoneSante],
            [Nom_ZoneSante] & "/" & DLookUp(
                "ZONE",
                "R_Deploiement",
                "ID_StructureSanitaire=" & [ID_SiteDeviation]
            )
        )
    ) AS [ZONE],
    T_Generique.AbreviationGenerique,
    T_StructureSanitaire.Nom_StructureSanitaire,
    IIf(
        Nz([ID_SiteDeviation], 0) = 0,
        [AbreviationGenerique] & " " & [Nom_StructureSanitaire],
        [AbreviationGenerique] & " " & [Nom_StructureSanitaire] & "/" & DLookUp(
            "SITE",
            "R_Deploiement",
            "ID_StructureSanitaire=" & [ID_SiteDeviation]
        )
    ) AS SITE,
    T_StructureSanitaire.LivraisonEquip,
    T_StructureSanitaire.LivraisonEquip AS LIVRAISON,
    T_StructureSanitaire.ID_StatutDeploiementFk AS STATUT_LOC,
    T_StructureSanitaire.QteODP,
    Nz([QteODP], "") AS NBR_EQUIP,
    T_StructureSanitaire.SourceAlimentation AS SOURCE,
    T_StructureSanitaire.VolumeStockage AS VOLUME,
    T_StructureSanitaire.SuiviDistance AS DL,
    T_StructureSanitaire.ObsODP AS OBS_ODP,
    T_StructureSanitaire.ObsSite AS OBS_SITE,
    T_StructureSanitaire.PrevisionProj AS PREV_PROJET,
    T_StructureSanitaire.SelectSite,
    T_Pays.ID_Pays,
    T_Region.ID_Region,
    T_Antenne.ID_Antenne,
    T_StructureSanitaire.ID_ZoneSanteFk,
    T_StructureSanitaire.ID_StructureSanitaire,
    T_StructureSanitaire.ID_StatutDeploiementFk,
    T_ZoneSante.ID_VoieAccesDPSBCZFk,
    T_ZoneSante.ID_VoieAccesANTBCZFk,
    T_StructureSanitaire.ID_VoieAccesZsSiteFk,
    T_ZoneSante.ID_TypeZoneFk,
    T_StructureSanitaire.ID_TypeSiteFk,
    T_StructureSanitaire.ID_TypeToitFk,
    T_StructureSanitaire.ID_TypeEquipFk,
    T_StructureSanitaire.ID_ProjetFK,
    T_StructureSanitaire.ID_TypeMontagePanneauFk,
    T_StructureSanitaire.ID_SiteDeviation,
    T_Region.FusionRegion,
    IIf(
        Nz([ID_SiteDeviation], "Vide") = "Vide",
        "Vide",
        "Site"
    ) AS ListVerCodeCmpte,
    IIf(
        Nz([ID_TypeToitFk], 0) = 0,
        " ",
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [ID_TypeToitFk]
        )
    ) AS TOITURE,
    IIf(
        Nz([ID_TypeEquipFk], 0) = 0,
        " ",
        DLookUp(
            "NomCategorie",
            "T_CategorieProduit",
            "ID_CategorieProduit=" & [ID_TypeEquipFk]
        )
    ) AS EQUIP,
    IIf(
        Nz([ID_ProjetFk], 0) = 0,
        " ",
        DLookUp(
            "Nom_Projet",
            "T_Projet",
            "ID_Projet=" & [ID_ProjetFK]
        )
    ) AS PROJET,
    IIf(
        Nz([ID_TypeMontagePanneauFk], 0) = 0,
        " ",
        DLookUp(
            "AbreviationGenerique",
            "T_Generique",
            "ID_Generique=" & [ID_TypeMontagePanneauFk]
        )
    ) AS MONTAGE
FROM (
        (
            (
                (
                    T_StructureSanitaire
                    INNER JOIN T_ZoneSante ON T_StructureSanitaire.ID_ZoneSanteFk = T_ZoneSante.ID_ZoneSante
                )
                INNER JOIN T_Antenne ON T_ZoneSante.ID_AntenneFK = T_Antenne.ID_Antenne
            )
            INNER JOIN T_Region ON T_Antenne.ID_RegionFK = T_Region.ID_Region
        )
        INNER JOIN T_Pays ON T_Region.ID_PaysFk = T_Pays.ID_Pays
    )
    INNER JOIN T_Generique ON T_StructureSanitaire.ID_TypeSiteFk = T_Generique.ID_Generique
WHERE T_Region.FusionRegion = False
ORDER BY T_Pays.NomPays,
    T_Region.Nom_Region,
    T_ZoneSante.Nom_ZoneSante,
    T_Generique.AbreviationGenerique,
    T_StructureSanitaire.Nom_StructureSanitaire,
    T_Pays.ID_Pays;
-- V_Contact
SELECT T_Contact.ID_Contact,
    T_Region.Nom_Region AS PROVINCE,
    T_Antenne.NomAntenne AS ANTENNE,
    T_ZoneSante.Nom_ZoneSante AS BCZ,
    T_Generique.AbreviationGenerique,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeSiteFk]
    ) & " " & [Nom_StructureSanitaire] AS SITE,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeSiteFk]
    ) AS TYPE,
    T_StructureSanitaire.Nom_StructureSanitaire,
    T_Contact.Nom AS NOM,
    T_Contact.Tel AS TELEPHONE,
    Replace([Tel], "/", Chr(13) & Chr(10)) AS [TELEPHONE 2],
    T_Contact.Email AS EMAIL,
    T_Contact.ObservationContact AS OBS,
    T_Contact.SelectContact,
    T_Contact.ID_FonctionFk,
    T_Contact.ID_SiteFk,
    T_Contact.ID_ProjetFKCont,
    IIf(
        Nz([ID_ProjetFKCont], 0) = 0,
        " ",
        DLookUp(
            "Nom_Projet",
            "T_Projet",
            "ID_Projet=" & [ID_ProjetFKCont]
        )
    ) AS PROJET,
    IIf(
        [AbreviationGenerique] = "DPS",
        [PROVINCE],
        IIf(
            [AbreviationGenerique] = "MCA"
            Or [AbreviationGenerique] = "Transporteur",
            [ANTENNE],
            IIf([AbreviationGenerique] = "MCZ", [BCZ], [BCZ])
        )
    ) AS LIEU
FROM (
        T_Region
        INNER JOIN (
            T_Antenne
            INNER JOIN T_ZoneSante ON T_Antenne.ID_Antenne = T_ZoneSante.ID_AntenneFK
        ) ON T_Region.ID_Region = T_Antenne.ID_RegionFK
    )
    INNER JOIN (
        T_StructureSanitaire
        INNER JOIN (
            T_Contact
            INNER JOIN T_Generique ON T_Contact.ID_FonctionFk = T_Generique.ID_Generique
        ) ON T_StructureSanitaire.ID_StructureSanitaire = T_Contact.ID_SiteFk
    ) ON T_ZoneSante.ID_ZoneSante = T_StructureSanitaire.ID_ZoneSanteFk
ORDER BY T_Region.Nom_Region,
    T_ZoneSante.Nom_ZoneSante,
    T_Contact.Tel;
-- V_Personnel
SELECT [NomPersonne] & " " & [PrenomPersonne] AS NOMS,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_GroupeTravail]
    ) AS GROUPE,
    T_Personne.Code AS CODE,
    T_Personne.SexePersonne AS SEXE,
    T_Personne.TelephonePersonne AS [TELEPHONE 2],
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypePersonneFk]
    ) AS TYPE,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_FonctionFk]
    ) AS FONCTION,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_ServiceFk]
    ) AS SERVICE,
    Nz(
        Replace([TelephonePersonne], "/", Chr(13) & Chr(10)),
        "0"
    ) AS TELEPHONE,
    T_Personne.EmailPersonne AS [EMAIL 2],
    Replace([EmailPersonne], "/", Chr(13) & Chr(10)) AS EMAIL,
    T_Personne.LieuNaissance AS [LIEU NAISS],
    T_Personne.DateNaissance AS [DATE NAISS],
    Round((Date() - [DateNaissance]) / 365, 2) & "" AS AGE,
    T_Personne.ObservationPer AS OBS,
    DCount(
        "ID_Commande",
        "T_Commande",
        "ID_Client=" & [ID_Personne]
    ) AS CMD,
    DCount(
        "ID_BudgetTechnicien",
        "T_BudgetTechnicien",
        "ID_TechnicienFk=" & [ID_Personne]
    ) AS BUDG,
    DCount(
        "ID_Technicien",
        "T_Intervention",
        "ID_Technicien=" & [ID_Personne]
    ) AS INTERV,
    T_Personne.LieuTravail,
    T_Personne.ValidePerso AS VALIDE,
    T_Personne.Contentieux AS CONTENTIEUX,
    T_Personne.ID_Personne,
    T_Personne.ID_TypePersonneFk,
    T_Personne.ID_GroupeTravail,
    T_Personne.ID_FonctionFk,
    T_Personne.ID_ServiceFk,
    T_Personne.ID_AdresseFk
FROM T_Personne
WHERE ([NomPersonne] & " " & [PrenomPersonne]) <> "na na"
ORDER BY [NomPersonne] & " " & [PrenomPersonne],
    T_Personne.ID_Personne,
    T_Personne.ID_TypePersonneFk,
    T_Personne.ID_FonctionFk,
    T_Personne.ID_ServiceFk,
    T_Personne.ID_AdresseFk;
-- V_TraceConnect
SELECT T_TraceConnect.ID_Trace,
    T_TraceConnect.LDate AS [DATE],
    T_TraceConnect.Heure AS HEURE,
    T_TraceConnect.InfoConnect AS INFO,
    T_User.NomUser AS NOM,
    T_Roles.LibRole AS ROLE,
    T_User.EmailUser AS EMAIL
FROM (
        T_TraceConnect
        INNER JOIN T_User ON T_TraceConnect.ID_User = T_User.ID_User
    )
    INNER JOIN T_Roles ON T_User.ID_Role = T_Roles.ID_Role
ORDER BY T_TraceConnect.LDate DESC,
    T_TraceConnect.Heure;
-- V_User
SELECT T_User.ID_User,
    T_User.ID_Role,
    T_User.NomUser AS NOM,
    T_User.CodeUser AS CODE,
    T_User.login AS LOGIN,
    T_User.password AS [PASSWORD],
    T_User.passwordreel AS [PASSWORD REEL],
    T_User.TelephoneUser AS TELEPHONE,
    T_User.EmailUser AS EMAIL,
    T_User.PhotoUser AS PHOTO,
    T_Roles.LibRole AS ROLE,
    DCount("ID_User", "T_User", "ID_User >= " & [ID_User]) AS Nordre
FROM T_Roles
    INNER JOIN T_User ON T_Roles.ID_Role = T_User.ID_Role
ORDER BY T_User.ID_User DESC;
--  V_AccesForms
SELECT T_AccesForms.ID_AccesForms,
    T_Roles.LibRole AS ROLE,
    T_AccesForms.NomForm AS FORMULAIRE,
    T_AccesForms.Acces AS ACCESS,
    T_AccesForms.Modif AS MODIFI
FROM T_AccesForms
    INNER JOIN T_Roles ON T_AccesForms.ID_Role = T_Roles.ID_Role
ORDER BY T_Roles.LibRole,
    T_AccesForms.NomForm;
-- V_Mouvement
SELECT T_Mouvement.DateMov AS [DATE],
    T_Mouvement.HeureMov AS HEURE,
    T_Mouvement.QteCommande AS QTE,
    T_Mouvement.PrixUnitaire AS PU,
    T_Produit.NomProduit AS NOM,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeProduitFk]
    ) AS [TYPE PRODUIT],
    T_Produit.ReferenceProduit AS REFERENCE,
    T_Produit.NSerie,
    T_Produit.MODELE,
    T_Produit.MARQUE,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_CategorieProduitFk]
    ) AS CATEGORIE,
    T_Produit.Provenance AS PROVENANCE,
    T_Produit.ObservationProduit AS OBS,
    T_Mouvement.TypeMov AS TYPE,
    T_Mouvement.CodeTypeMov,
    T_Mouvement.ID_Mouvement,
    T_Commande.ID_Commande,
    T_Mouvement.ID_Produit,
    [NSerie] & " /" & [MARQUE] & "/" & [MODELE] AS RefPro,
    T_Produit.QteStock
FROM (
        T_Produit
        INNER JOIN T_Mouvement ON T_Produit.ID_Produit = T_Mouvement.ID_Produit
    )
    INNER JOIN T_Commande ON T_Mouvement.ID_Commande = T_Commande.ID_Commande
ORDER BY T_Mouvement.DateMov DESC,
    T_Produit.NomProduit,
    T_Produit.NSerie,
    T_Produit.QteStock;
--  V_Commande
SELECT T_Commande.ID_Commande,
    T_Commande.DateCommande AS [DATE],
    T_Commande.TypeCommande AS TYPE,
    DSum(
        "QteCommande",
        "T_CommandeDetail",
        "ID_CommandeFk=" & [ID_Commande]
    ) AS QTE,
    T_Commande.CodeCommande AS CODE,
    T_Projet.Nom_Projet AS PROJET,
    T_Projet.MasqueCMD,
    T_Projet.MasqueAll,
    [NomPersonne] & " " & [PrenomPersonne] AS BENEFICIAIRE,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypePersonneFk]
    ) AS NomTypePersonne,
    T_Personne.TelephonePersonne,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_FonctionFk]
    ) AS NomFonction,
    T_Region.Nom_Region AS PROVINCE,
    T_Commande.ValideRemise AS REMISE,
    T_Commande.Status,
    [CodeCommande] & [Nom_Projet] & [NomPersonne] & [PrenomPersonne] & [Nom_Region] & [NomPersonne] & [PrenomPersonne] & [CodeFacture] & [ObsCmd] AS RechercheCmd,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_StatutCmd]
    ) AS STATUTCMD,
    T_Commande.Sujet AS LIBELLE,
    T_Commande.RefCommande AS REF,
    T_Commande.CodeFacture AS [CODE FAC],
    T_Commande.DateFacture AS [DATE FAC],
    T_Commande.DateEcheance AS [DATE ECH],
    T_Commande.[ID_ModePaiement] AS [MODE PAIE],
    T_User.NomUser AS [USER],
    T_Commande.ObsCmd,
    T_Commande.Sujet,
    T_Commande.ID_Client,
    T_Personne.ID_TypePersonneFk,
    T_Commande.ID_ConditionPaiement,
    T_Commande.ID_PaysFk,
    T_Commande.ID_RegionFk,
    T_Commande.ID_ProjetFk,
    T_Commande.ID_UserFk,
    T_Personne.ID_FonctionFk,
    T_Region.FusionRegion,
    T_Commande.SelectCmd,
    T_Commande.ID_StatutCmd
FROM T_Personne
    INNER JOIN (
        (
            T_Region
            INNER JOIN (
                T_Projet
                INNER JOIN T_Commande ON T_Projet.ID_Projet = T_Commande.[ID_ProjetFk]
            ) ON T_Region.ID_Region = T_Commande.[ID_RegionFk]
        )
        INNER JOIN T_User ON T_Commande.ID_UserFk = T_User.ID_User
    ) ON T_Personne.ID_Personne = T_Commande.ID_Client
ORDER BY T_Commande.DateCommande DESC,
    T_Commande.CodeCommande DESC;
-- V_CommandeDetail
SELECT T_CommandeDetail.ID_CommandeFk,
    T_CommandeDetail.ID_ProduitFk,
    T_CommandeDetail.Lieu,
    T_CommandeDetail.QteCommande AS QTE_CMD,
    T_CommandeDetail.QteRemise AS QTE_RM,
    T_CommandeDetail.ObservationPr AS OBS_DETAIL,
    T_CommandeDetail.SelectCmdDetail,
    T_Commande.CodeCommande AS CODE_CMD,
    T_Commande.TypeCommande AS TYPE_CMD,
    T_Commande.DateCommande AS DATE_CMD,
    T_Commande.ObsCmd AS OBS_CMD,
    T_Projet.Nom_Projet AS PROJET,
    T_Region.Nom_Region AS PROVINCE,
    T_Personne.NomPersonne & " " & T_Personne.PrenomPersonne AS BENEFICIAIRE,
    T_StructureSanitaire.Nom_StructureSanitaire AS SITE,
    T_Produit.NomProduit AS PRODUIT,
    T_Produit.ReferenceProduit AS REFERENCE,
    T_Produit.NSerie,
    T_Produit.MODELE,
    T_Produit.MARQUE,
    T_Produit.PrixUnitaireProduit AS PU,
    T_Produit.Provenance,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [T_Produit].[ID_TypeProduitFk]
    ) AS TYPE_PRODUIT,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [T_Produit].[ID_CategorieProduitFk]
    ) AS CATEGORIE
FROM (
        (
            (
                (
                    (
                        T_CommandeDetail
                        INNER JOIN T_Commande ON T_CommandeDetail.ID_CommandeFk = T_Commande.ID_Commande
                    )
                    INNER JOIN T_Produit ON T_CommandeDetail.ID_ProduitFk = T_Produit.ID_Produit
                )
                INNER JOIN T_Projet ON T_Commande.ID_ProjetFk = T_Projet.ID_Projet
            )
            INNER JOIN T_Region ON T_Commande.ID_RegionFk = T_Region.ID_Region
        )
        INNER JOIN T_Personne ON T_Commande.ID_Client = T_Personne.ID_Personne
    )
    INNER JOIN T_StructureSanitaire ON T_CommandeDetail.Lieu = T_StructureSanitaire.ID_StructureSanitaire
ORDER BY T_Commande.DateCommande DESC,
    T_Commande.CodeCommande,
    T_Produit.NomProduit;
-- V_Produit
SELECT IIf([QteStock] = 0, "Faible", "Pas Faible") AS StatutFaible,
    IIf(
        ([DatePeremptionAlerte] <= Date())
        And ([NbreJoursAlerte] <> 0),
        "Périmé",
        "Non périmé"
    ) AS StatutPerime,
    [StatutPerime] & "/" & [StatutFaible] AS InfoProduit,
    T_Produit.DateEnreProduit AS [DATE],
    T_Produit.DatePeremption,
    T_Produit.DatePeremptionAlerte,
    T_Produit.NomProduit AS NOM,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeProduitFk]
    ) AS TYPE,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_CategorieProduitFk]
    ) AS CATEGORIE,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_UniteFk]
    ) AS UNITE,
    IIf(
        [ReferenceProduit] = "na",
        "",
        [ReferenceProduit]
    ) AS REFERENCE,
    IIf([NSerie] = "na", "", [NSerie]) & " /" & IIf([MARQUE] = "na", "", [MARQUE]) & "/" & IIf([MODELE] = "na", "", [MODELE]) AS RefPro,
    T_Produit.IMEI,
    T_Produit.NSerie,
    T_Produit.MODELE,
    T_Produit.MARQUE,
    T_Produit.RemisePr AS REMISE,
    T_Produit.QteMin AS [QTE Min],
    T_Produit.QteStock AS QTE,
    T_Produit.PrixUnitaireProduit AS PU,
    T_Produit.PrixVente AS PV,
    T_Produit.CodeProduitInterne AS [CODE INT],
    T_Produit.CodeProduitExterne AS [CODE EXT],
    T_Produit.MotifProd AS MOTIF,
    T_Produit.ObservationProduit AS OBS,
    T_Produit.Provenance AS PROVENANCE,
    T_Produit.Taux AS TAUX,
    T_Produit.NbreJoursAlerte,
    T_Produit.PhotoProduit,
    T_Produit.SelectProduit,
    DCount(
        "ID_CommandeFk",
        "T_CommandeDetail",
        "ID_ProduitFk=" & [ID_Produit]
    ) AS [NBR CMD],
    T_Produit.ID_Produit,
    T_Produit.ID_TypeProduitFk,
    T_Produit.ID_CategorieProduitFk,
    T_Produit.ID_UniteFk,
    [NomProduit] & [ReferenceProduit] & [NSerie] & [MARQUE] & [MODELE] & [MotifProd] & [ObservationProduit] & [Provenance] & [PrixUnitaireProduit] AS Recherche
FROM T_Produit
ORDER BY T_Produit.NomProduit,
    T_Produit.NSerie;
-- V_Livraison
SELECT T_Livraison.ID_Livraison,
    T_Livraison.DateHeureLivraison,
    T_Livraison.DateInitialeLivraison,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeLivraison]
    ) AS TypeLivraison,
    T_Livraison.ID_TypeLivraison,
    T_Livraison.ID_ProjetFk,
    T_Livraison.ID_Livreur,
    T_Livraison.ID_UserFk,
    T_Livraison.CodeT,
    T_Livraison.CoutBudget,
    T_Livraison.NbreJour,
    DSum(
        "QteLivraison",
        "T_LivraisonDetail",
        "ID_LivraisonFk=" & [ID_Livraison]
    ) AS QteLivr,
    DSum(
        "PULivraison",
        "T_LivraisonDetail",
        "ID_LivraisonFk=" & [ID_Livraison]
    ) AS PULivr,
    DSum(
        "QteIntervention",
        "T_LivraisonDetail",
        "ID_LivraisonFk=" & [ID_Livraison]
    ) AS QteInterv,
    DSum(
        "PUIntervention",
        "T_LivraisonDetail",
        "ID_LivraisonFk=" & [ID_Livraison]
    ) AS PUInterv,
    T_Livraison.ObsLivraison,
    T_Livraison.ID_StatutLivraison
FROM T_Livraison
ORDER BY T_Livraison.DateHeureLivraison DESC,
    T_Livraison.CodeT;
-- V_Projet
SELECT T_Projet.ID_Projet,
    T_Projet.Nom_Projet AS NOMS,
    T_Projet.Date_Projet AS [DATE D],
    T_Projet.DateFin AS [DATE F],
    T_Projet.ModeleEquip AS MODELE_EQUIP,
    T_Projet.IntervObs AS INTERV_OBS,
    T_Projet.ObsProjet AS OBS,
    T_Projet.OrdreMissionInterv,
    DCount(
        "ID_ProjetFk",
        "T_Commande",
        "ID_ProjetFk=" & [ID_Projet]
    ) AS [NBR CMD],
    T_Projet.MasqueCMD AS [M CMD],
    DCount(
        "ID_ProjetFk",
        "T_BudgetTechnicien",
        "ID_ProjetFk=" & [ID_Projet]
    ) AS [NBR BDG],
    T_Projet.MasqueBudget AS [M BDG],
    DCount(
        "ID_ProjetFk",
        "T_Intervention",
        "ID_ProjetFk=" & [ID_Projet]
    ) & "  (" & DCount(
        "ID_ProjetFk",
        "T_Intervention",
        "ID_ProjetFk=" & [ID_Projet] & " AND TypeIntervention=72"
    ) & " / " & DCount(
        "ID_ProjetFk",
        "T_Intervention",
        "ID_ProjetFk=" & [ID_Projet] & " AND TypeIntervention=73"
    ) & ")" AS [NBR INTERV],
    T_Projet.MasqueInterv AS [M INTERV],
    T_Projet.MasqueAll AS [M ALL],
    T_Projet.CommandeEqui AS [QTE EQUIP],
    T_Projet.NbrBatch AS [NBR BATCH],
    [Nom_Projet] & [CommandeEqui] & [ObsProjet] & [ModeleEquip] & [IntervObs] & [Date_Projet] & [DateFin] AS RechercheP
FROM T_Projet
ORDER BY T_Projet.Nom_Projet,
    T_Projet.Date_Projet DESC;
-- V_CaisseMouvement
SELECT T_CaisseMouvement.DateCaisseMouv AS [DATE],
    T_CaisseMouvement.ID_CaisseMouvement,
    T_TypeMouvement.LibTypeMouvement AS TYPE_MVT,
    [ID_Code] & "/" & [Designation] AS OPERATION,
    T_CaisseMouvement.LibelleOperation AS LIBELLE,
    [NomPersonne] & " " & [PrenomPersonne] AS TIERS,
    [MontantOperation] & " " & [CodeDevise] AS MONTANT,
    [CumulOperation] & " " & [CodeDevise] AS CUMUL,
    T_Projet.Nom_Projet AS PROJET,
    T_User.NomUser AS [USER],
    T_TypeCaisse.TypeComptes AS [TYPE CMPTE],
    T_CaisseMouvement.ObsOperation AS OBS,
    T_Devise.CodeDevise AS DEVISE,
    Format([T_CaisseMouvement] ! [DateCaisseMouv], "mmmm") AS LMois,
    Format([T_CaisseMouvement] ! [DateCaisseMouv], "yyyy") AS LAnnee,
    [LibelleOperation] & [MontantOperation] & [CumulOperation] & [ID_CaisseMouvement] & [ObsOperation] AS RechercheC,
    T_CaisseMouvement.SelectMvt,
    T_CaisseMouvement.DateHeureMvt,
    T_CaisseMouvement.ID_ClientFk,
    T_CaisseMouvement.ID_UserFk,
    T_CaisseMouvement.ID_CompteFk,
    T_CaisseMouvement.ID_DeviseFk,
    T_CaisseMouvement.ID_TypeCompteFk,
    T_CaisseMouvement.ID_ProjetFk,
    T_CaisseMouvement.ID_TypeMouvFk,
    T_CaisseMouvement.MontantOperation,
    T_CaisseMouvement.CumulOperation
FROM T_User
    INNER JOIN (
        T_TypeMouvement
        INNER JOIN (
            T_TypeCaisse
            INNER JOIN (
                T_Projet
                INNER JOIN (
                    T_Personne
                    INNER JOIN (
                        T_Ohada
                        INNER JOIN (
                            T_Devise
                            INNER JOIN T_CaisseMouvement ON T_Devise.ID_Devise = T_CaisseMouvement.ID_DeviseFk
                        ) ON T_Ohada.ID_Code = T_CaisseMouvement.ID_CompteFk
                    ) ON T_Personne.ID_Personne = T_CaisseMouvement.ID_ClientFk
                ) ON T_Projet.ID_Projet = T_CaisseMouvement.ID_ProjetFk
            ) ON T_TypeCaisse.ID_TypeCompte = T_CaisseMouvement.ID_TypeCompteFk
        ) ON T_TypeMouvement.ID_TypeMouvement = T_CaisseMouvement.ID_TypeMouvFk
    ) ON T_User.ID_User = T_CaisseMouvement.ID_UserFk
ORDER BY T_CaisseMouvement.DateCaisseMouv DESC,
    T_CaisseMouvement.ID_CaisseMouvement DESC;
-- V_Materiel
SELECT T_Materiel.ID_Materiel,
    T_Materiel.DateEntree AS [DATE],
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeMateriel]
    ) AS CATEGORIE,
    T_Materiel.Nom_Materiel AS MATERIEL,
    T_Materiel.Reference AS REFERENCE,
    [NomPersonne] & " " & [PrenomPersonne] AS UTILISATEUR,
    T_Materiel.Caracteristique AS CARACTERISTIQUE,
    T_Materiel.Qte AS QTE,
    T_Materiel.PrixUnitaire AS PU,
    T_Materiel.Observation AS OBS,
    T_Materiel.EtatMat AS ETAT,
    [Nom_Materiel] & [Reference] & [Caracteristique] & [Observation] & [NomPersonne] & [PrenomPersonne] AS RECHERC,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_ServiceFk]
    ) AS SERVICE,
    T_Materiel.ID_TypeMateriel,
    T_Materiel.ID_AgentFk,
    T_Personne.ID_ServiceFk,
    Year([T_Materiel] ! [DateEntree]) AS LAnnee
FROM T_Personne
    INNER JOIN T_Materiel ON T_Personne.ID_Personne = T_Materiel.ID_AgentFk
ORDER BY T_Materiel.Nom_Materiel,
    [NomPersonne] & " " & [PrenomPersonne];
-- V_Reglements
-- 1. La requête TRANSFORM (requête croisée dynamique / pivot)
TRANSFORM Sum(T_Reglements.MontantRegle) AS SommeMontant
SELECT T_Personne.NomPersonne & " " & T_Personne.PrenomPersonne AS NomCompletPersonne,
    Year(T_Reglements.DateReglement) AS LAnnee
FROM T_Reglements
    INNER JOIN T_Personne ON T_Reglements.ID_Client = T_Personne.ID_Personne
GROUP BY T_Personne.NomPersonne & " " & T_Personne.PrenomPersonne,
    Year(T_Reglements.DateReglement) PIVOT Format(T_Reglements.DateReglement, "mmmm") IN (
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
    );
ou -- 2. La requête SELECT classique
SELECT T_Reglements.ID_Reglement,
    T_Reglements.CodeFacture,
    T_Reglements.ID_ModeReglement,
    T_Reglements.DateReglement,
    T_Reglements.MontantRegle,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_ModeReglement]
    ) AS LibReglement,
    T_Personne.ID_Personne,
    T_Personne.NomPersonne,
    T_Personne.PrenomPersonne,
    [NomPersonne] & " " & [PrenomPersonne] AS NomCompletPersonne
FROM T_Reglements
    INNER JOIN T_Personne ON T_Reglements.ID_Client = T_Personne.ID_Personne;
-- V_BudgetTechnicien
SELECT T_Personne.TelephonePersonne AS PHONE,
    T_AncienneRegion.NomAncien AS [REGION ANC],
    T_Region.Nom_Region AS PROVINCE,
    [NomPersonne] & " " & [PrenomPersonne] AS TECHNICIEN,
    T_Region.FusionRegion,
    T_Region.MasqueProvince,
    T_Region.MasqueBudget,
    T_Projet.Nom_Projet AS PROJET,
    T_Projet.MasqueBudget,
    T_Projet.MasqueInterv,
    T_Projet.MasqueAll,
    T_BudgetTechnicien.Axe AS AXE,
    T_BudgetTechnicien.BudgetAttribue AS ATTRIBUER,
    T_BudgetTechnicien.NbreEquipementInstall AS [NBRE EQUI],
    T_BudgetTechnicien.ID_StatutIntervention,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_StatutIntervention]
    ) AS [OBS INTERV],
    T_BudgetTechnicien.CodeCompt,
    T_BudgetTechnicien.CodeBudgetTechnicien AS CODE,
    T_BudgetTechnicien.CodeCompt AS CODE_CMP,
    T_BudgetTechnicien.FusionBdg AS FUSION,
    IIf(Nz([codeCompt], "Vide") = "Vide", "Vide", "Code") AS VerCodeCompt,
    [CodeBudgetTechnicien] & [Nom_Projet] & [NomPersonne] & [PrenomPersonne] & [NomAncien] & [Nom_Region] & [RefBudgt] & [Axe] & [NomPersonne] & [PrenomPersonne] & [StructureSanitaire] & [ObservationBudg] & [FusionBdg] & [CodeCompt] & [CommentBudg] & [DateMission] & [ButMission] AS RechercheBudg,
    T_BudgetTechnicien.ID_TypeBudgetTechnicien,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeBudgetTechnicien]
    ) AS [TYPE BUDG],
    T_BudgetTechnicien.ID_BudgetTechnicien,
    T_BudgetTechnicien.DateHeureEnregistrement,
    T_BudgetTechnicien.ButMission AS BUT,
    T_BudgetTechnicien.DateMission AS [DATE],
    T_BudgetTechnicien.NbreJourMission AS [NBRE JRS],
    T_BudgetTechnicien.NbrePM,
    T_BudgetTechnicien.NbreSiteSup1Ref,
    T_BudgetTechnicien.SomFraisTransport AS [FRAIS TRANS],
    T_BudgetTechnicien.SomFraisPers AS [FRAIS PERS],
    [SomFraisTransport] + [SomFraisPers] AS [FRAIS MISSION],
    T_BudgetTechnicien.AcomptCompt AS ACOMPTE,
    T_BudgetTechnicien.SoldeCompt AS SOLDE,
    T_BudgetTechnicien.RefBudgt AS REF,
    T_BudgetTechnicien.ObservationBudg AS OBS,
    T_BudgetTechnicien.CommentBudg,
    T_BudgetTechnicien.StructureSanitaire AS SITE,
    T_BudgetTechnicien.MoyenTransport AS TRANSPORT,
    T_BudgetTechnicien.FraisManutention,
    T_BudgetTechnicien.FraisAutres,
    T_BudgetTechnicien.FraisAutres2,
    T_BudgetTechnicien.NbreJrFraisAutres2,
    T_BudgetTechnicien.NbreJrFraisAutres,
    T_BudgetTechnicien.NbreManutention,
    T_BudgetTechnicien.GoPass,
    T_BudgetTechnicien.NbreJrGopass,
    T_BudgetTechnicien.NbreJoursInstallation,
    T_BudgetTechnicien.NbreJoursCirculation,
    T_BudgetTechnicien.IdemniteInstallation,
    T_BudgetTechnicien.IdemniteCirculation,
    T_BudgetTechnicien.Logement,
    T_BudgetTechnicien.MatTransporte,
    T_BudgetTechnicien.CodeRemise,
    T_BudgetTechnicien.ObjetMission AS OBJET,
    DCount(
        "ID_BudgetTechnicienFk",
        "T_BudgetTechnicienDetail",
        "ID_BudgetTechnicienFk=" & [ID_BudgetTechnicien]
    ) AS [NBRE LIGNE DETAIL],
    T_Personne.TelephonePersonne,
    T_BudgetTechnicien.ID_TechnicienFk,
    T_Personne.ID_Personne,
    T_BudgetTechnicien.ID_ProjetFk,
    T_Region.ID_PaysFk,
    T_Region.ID_Region,
    T_Region.ID_AncienneRegionFk,
    T_BudgetTechnicien.ID_ProvinceFk,
    IIf(
        RapportBudgetDetail(
            "T_BudgetTechnicienDetail",
            [ID_BudgetTechnicien],
            272,
            "RoutingAvion"
        ) = "",
        "Non",
        "Oui"
    ) AS AVION
FROM (
        T_AncienneRegion
        RIGHT JOIN T_Region ON T_AncienneRegion.ID_AncienneR = T_Region.ID_AncienneRegionFk
    )
    INNER JOIN (
        T_Projet
        INNER JOIN (
            T_BudgetTechnicien
            INNER JOIN T_Personne ON T_BudgetTechnicien.[ID_TechnicienFk] = T_Personne.ID_Personne
        ) ON T_Projet.ID_Projet = T_BudgetTechnicien.ID_ProjetFk
    ) ON T_Region.ID_Region = T_BudgetTechnicien.ID_ProvinceFk
ORDER BY T_Region.Nom_Region,
    [NomPersonne] & " " & [PrenomPersonne],
    T_BudgetTechnicien.Axe,
    T_BudgetTechnicien.DateMission;
-- V_BudgetTechnicienDetail
SELECT T_BudgetTechnicien.ID_BudgetTechnicien,
    T_BudgetTechnicienDetail.ID_BudgetTechnicienDetail,
    T_BudgetTechnicien.ID_TypeBudgetTechnicien,
    T_BudgetTechnicienDetail.ID_TransportFk,
    T_Region.Nom_Region,
    T_BudgetTechnicien.StructureSanitaire,
    T_BudgetTechnicien.Axe,
    T_BudgetTechnicienDetail.AxeSite,
    T_Projet.Nom_Projet,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TransportFk]
    ) AS MoyenTransport,
    T_BudgetTechnicienDetail.Routing,
    T_BudgetTechnicienDetail.CoutTransport,
    [NomPersonne] & " " & [PrenomPersonne] AS NomCompletPersonne,
    T_BudgetTechnicien.CodeBudgetTechnicien,
    T_BudgetTechnicien.SomFraisPers,
    T_BudgetTechnicien.SomFraisTransport,
    [SomFraisTransport] + [SomFraisPers] AS FraisMission,
    [Nom_Region] & [Axe] & [AxeSite] & [Routing] & [CoutTransport] & [NomPersonne] & [PrenomPersonne] & [StructureSanitaire] AS RechercherR,
    T_BudgetTechnicienDetail.SelectBudDetail,
    DLookUp(
        "AbreviationGenerique",
        "T_Generique",
        "ID_Generique=" & [ID_TypeBudgetTechnicien]
    ) AS TypeB
FROM T_Region
    INNER JOIN (
        T_Projet
        INNER JOIN (
            (
                T_BudgetTechnicien
                INNER JOIN T_Personne ON T_BudgetTechnicien.[ID_TechnicienFk] = T_Personne.ID_Personne
            )
            INNER JOIN T_BudgetTechnicienDetail ON T_BudgetTechnicien.ID_BudgetTechnicien = T_BudgetTechnicienDetail.ID_BudgetTechnicienFk
        ) ON T_Projet.ID_Projet = T_BudgetTechnicien.ID_ProjetFk
    ) ON T_Region.ID_Region = T_BudgetTechnicien.ID_ProvinceFk
ORDER BY T_Region.Nom_Region,
    T_BudgetTechnicien.Axe,
    T_Projet.Nom_Projet;