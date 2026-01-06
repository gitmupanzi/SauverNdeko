-- View: communication.V_Chat

-- DROP VIEW communication."V_Chat";

CREATE OR REPLACE VIEW communication."V_Chat"
 AS
 SELECT c."IdChat",
    c."TextChat",
    c."ChatFile",
    c."ChatLink",
    c."AuthorIdFk" AS "IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    e."IdEntite",
    e."NomEntite"
   FROM communication."T_Chat" c
     LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = c."AuthorIdFk"
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk";

ALTER TABLE communication."V_Chat"
    OWNER TO postgres;

-- View: communication.V_Communication

-- DROP VIEW communication."V_Communication";

CREATE OR REPLACE VIEW communication."V_Communication"
 AS
 SELECT com."IdCommunication",
    com."DateCommunication",
    com."ContenuCommunication",
    com."ObsCommunication",
    com."ValideCommunication",
    com."LectureCommunication",
    com."IdUserFk" AS "IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    com."IdEntiteFk" AS "IdEntite",
    e."NomEntite",
    com."IdTypeCommunication",
    tg."AbrGenerique" AS "TypeCommunicationAbr",
    tg."NomGenerique" AS "TypeCommunicationLibelle"
   FROM communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = com."IdUserFk"
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = com."IdEntiteFk"
     LEFT JOIN referentiel."T_Generique" tg ON tg."ID_Generique" = com."IdTypeCommunication";

ALTER TABLE communication."V_Communication"
    OWNER TO postgres;

-- View: communication.V_Communication_non_lues

-- DROP VIEW communication."V_Communication_non_lues";

CREATE OR REPLACE VIEW communication."V_Communication_non_lues"
 AS
 SELECT com."IdCommunication",
    com."DateCommunication",
    com."ContenuCommunication",
    com."ObsCommunication",
    com."ValideCommunication",
    com."LectureCommunication",
    com."IdUserFk" AS "IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    com."IdEntiteFk" AS "IdEntite",
    e."NomEntite",
    com."IdTypeCommunication",
    tg."AbrGenerique" AS "TypeCommunicationAbr",
    tg."NomGenerique" AS "TypeCommunicationLibelle"
   FROM communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = com."IdUserFk"
     LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = com."IdEntiteFk"
     LEFT JOIN referentiel."T_Generique" tg ON tg."ID_Generique" = com."IdTypeCommunication"
  WHERE com."LectureCommunication" = false AND com."ValideCommunication" = true;

ALTER TABLE communication."V_Communication_non_lues"
    OWNER TO postgres;

