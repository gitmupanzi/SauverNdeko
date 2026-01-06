-- View: professionnel.V_Professionnel_Detail

-- DROP VIEW professionnel."V_Professionnel_Detail";

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Detail"
 AS
 SELECT p."IdProfessionnel",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    p."IdTypeProfessionnelFk",
    tp."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    sp."NomGenerique" AS "Specialite",
    p."NumeroIdentification",
    p."ExperienceAns",
    p."ValideProfessionnel",
    u."PhoneUser",
    u."SexeUser",
    u."UrlPhoto"
   FROM professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p."IdUserFk"
     LEFT JOIN referentiel."T_Generique" tp ON tp."ID_Generique" = p."IdTypeProfessionnelFk"
     LEFT JOIN referentiel."T_Generique" sp ON sp."ID_Generique" = p."IdSpecialiteFk";

ALTER TABLE professionnel."V_Professionnel_Detail"
    OWNER TO postgres;

-- View: professionnel.V_Professionnel_Global

-- DROP VIEW professionnel."V_Professionnel_Global";

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Global"
 AS
 SELECT p."IdProfessionnel",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    u."PhoneUser",
    p."IdTypeProfessionnelFk",
    type_prof."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    spec."NomGenerique" AS "Specialite",
    p."NumeroIdentification",
    p."ExperienceAns",
    p."ValideProfessionnel",
    p."ObsProfessionnel",
    pe."IdEntiteFk" AS "IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    pe."IdTypeLienFk",
    type_lien."NomGenerique" AS "TypeLien",
    pe."EstPrincipal",
    pe."DateDebut",
    pe."DateFin",
    pe."ObsLien",
    el."IdEntiteLocalisation",
    el."Latitude",
    el."Longitude",
    el."IdNiveau_3_Fk",
    el."IdNiveau_4_Fk",
    el."IdNiveau_5_Fk",
    el."AdresseDetaillee"
   FROM professionnel."T_Professionnel" p
     JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p."IdUserFk"
     JOIN professionnel."T_Professionnel_Entite" pe ON pe."IdProfessionnelFk" = p."IdProfessionnel"
     JOIN systeme."T_Entite" e ON e."IdEntite" = pe."IdEntiteFk"
     LEFT JOIN systeme."T_Entite_Localisation" el ON el."IdEntiteFk" = e."IdEntite"
     LEFT JOIN referentiel."T_Generique" type_prof ON type_prof."ID_Generique" = p."IdTypeProfessionnelFk"
     LEFT JOIN referentiel."T_Generique" spec ON spec."ID_Generique" = p."IdSpecialiteFk"
     LEFT JOIN referentiel."T_Generique" type_lien ON type_lien."ID_Generique" = pe."IdTypeLienFk";

ALTER TABLE professionnel."V_Professionnel_Global"
    OWNER TO postgres;

-- View: professionnel.V_Professionnel_Par_Entite

-- DROP VIEW professionnel."V_Professionnel_Par_Entite";

CREATE OR REPLACE VIEW professionnel."V_Professionnel_Par_Entite"
 AS
 SELECT pe."IdProfessionnelFk",
    p."IdUserFk",
    u."NomUser",
    u."PrenomUser",
    p."IdTypeProfessionnelFk",
    tp."NomGenerique" AS "TypeProfessionnel",
    p."IdSpecialiteFk",
    sp."NomGenerique" AS "Specialite",
    pe."IdEntiteFk",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    e."AdresseEntite",
    e."IdTypeEntiteFk",
    te."NomGenerique" AS "TypeEntite",
    pe."EstPrincipal",
    pe."DateDebut",
    pe."DateFin",
    pe."IdTypeLienFk",
    tl."NomGenerique" AS "TypeLien",
    p."ValideProfessionnel"
   FROM professionnel."T_Professionnel_Entite" pe
     JOIN professionnel."T_Professionnel" p ON p."IdProfessionnel" = pe."IdProfessionnelFk"
     JOIN systeme."T_Utilisateurs" u ON u."IdUser" = p."IdUserFk"
     JOIN systeme."T_Entite" e ON e."IdEntite" = pe."IdEntiteFk"
     LEFT JOIN referentiel."T_Generique" tp ON tp."ID_Generique" = p."IdTypeProfessionnelFk"
     LEFT JOIN referentiel."T_Generique" sp ON sp."ID_Generique" = p."IdSpecialiteFk"
     LEFT JOIN referentiel."T_Generique" te ON te."ID_Generique" = e."IdTypeEntiteFk"
     LEFT JOIN referentiel."T_Generique" tl ON tl."ID_Generique" = pe."IdTypeLienFk";

ALTER TABLE professionnel."V_Professionnel_Par_Entite"
    OWNER TO postgres;

