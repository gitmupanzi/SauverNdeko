/* ============================================================================
   TEST UNITAIRE – MODULE COMMUNICATION
   Scénario :
     - Un utilisateur envoie un message à une pharmacie
     - On vérifie le stockage de la communication

   Hypothèses :
     - communication."T_Communication" a au moins :
         IdCommunication (PK), IdUserFk, IdTypeCommunication (nullable),
         ContenuCommunication, DateCommunication, ObsCommunication,
         ValideCommunication, LectureCommunication, IdEntiteFk
   ========================================================================== */

BEGIN;

-------------------------------------------------------------------------------
-- 0. CRÉATION / VÉRIFICATION USER + ENTITÉ POUR COMMUNICATION
-------------------------------------------------------------------------------

-- a) User de test communication
INSERT INTO systeme."T_Utilisateurs" (
    "NomUser",
    "PrenomUser",
    "EmailUser",
    "MotdepasseUser",
    "PhoneUser",
    "IdRoleFk",
    "ValideUser",
    "SexeUser",
    "IdEntiteFk",
    "Is_staff",
    "Is_Admin"
)
SELECT
    'PATIENT',
    'Communication',
    'patient.comm@sauverndeko.cd',
    'hashed_password_comm',
    '+243810001999',
    NULL,
    TRUE,
    'F'::char(1),
    NULL,
    FALSE,
    FALSE
WHERE NOT EXISTS (
    SELECT 1 FROM systeme."T_Utilisateurs"
    WHERE "EmailUser" = 'patient.comm@sauverndeko.cd'
);

-- b) Pharmacie de test communication
INSERT INTO systeme."T_Entite" (
    "NomEntite",
    "PhoneEntite",
    "EmailEntite",
    "AdresseEntite",
    "IdTypeEntiteFk",
    "ValideEntite"
)
SELECT
    'Pharmacie Comm TEST',
    '+243820009999',
    'pharmacie.comm@sauverndeko.cd',
    'Kinshasa – test communication',
    (
        SELECT g."ID_Generique"
        FROM   referentiel."T_Generique" g
        JOIN   referentiel."T_CategorieGenerique" c
               ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE  c."NomCategorieGenerique" = 'Type entite'
        AND    g."NomGenerique" = 'Pharmacie'
        LIMIT  1
    ),
    TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM systeme."T_Entite"
    WHERE "EmailEntite" = 'pharmacie.comm@sauverndeko.cd'
);

-------------------------------------------------------------------------------
-- 1. INSERTION DE MESSAGES DE TEST
-------------------------------------------------------------------------------

-- Message 1 : style WhatsApp
INSERT INTO communication."T_Communication" (
    "IdUserFk",
    "IdTypeCommunication",
    "ContenuCommunication",
    "DateCommunication",
    "ObsCommunication",
    "ValideCommunication",
    "LectureCommunication",
    "IdEntiteFk"
)
SELECT
    u."IdUser",
    NULL,   -- type à typifier plus tard si tu relies à T_Generique
    'Bonjour, je souhaite savoir si vous avez du paracétamol 500 mg en stock.',
    NOW(),
    'Message test – demande disponibilité',
    TRUE,
    FALSE,
    e."IdEntite"
FROM   systeme."T_Utilisateurs" u
CROSS JOIN systeme."T_Entite" e
WHERE  u."EmailUser"   = 'patient.comm@sauverndeko.cd'
AND    e."EmailEntite" = 'pharmacie.comm@sauverndeko.cd';

-- Message 2 : style appel (trace textuelle)
INSERT INTO communication."T_Communication" (
    "IdUserFk",
    "IdTypeCommunication",
    "ContenuCommunication",
    "DateCommunication",
    "ObsCommunication",
    "ValideCommunication",
    "LectureCommunication",
    "IdEntiteFk"
)
SELECT
    u."IdUser",
    NULL,
    'Appel téléphonique simulé : confirmation de disponibilité et du prix.',
    NOW(),
    'Message test – trace d’appel',
    TRUE,
    FALSE,
    e."IdEntite"
FROM   systeme."T_Utilisateurs" u
CROSS JOIN systeme."T_Entite" e
WHERE  u."EmailUser"   = 'patient.comm@sauverndeko.cd'
AND    e."EmailEntite" = 'pharmacie.comm@sauverndeko.cd';

-------------------------------------------------------------------------------
-- 2. CONTRÔLES COMMUNICATION
-------------------------------------------------------------------------------

SELECT
    c."IdCommunication",
    u."EmailUser",
    e."NomEntite",
    c."ContenuCommunication",
    c."DateCommunication",
    c."LectureCommunication",
    c."ObsCommunication"
FROM   communication."T_Communication" c
JOIN   systeme."T_Utilisateurs" u
       ON u."IdUser" = c."IdUserFk"
JOIN   systeme."T_Entite" e
       ON e."IdEntite" = c."IdEntiteFk"
WHERE  u."EmailUser"   = 'patient.comm@sauverndeko.cd'
AND    e."EmailEntite" = 'pharmacie.comm@sauverndeko.cd'
ORDER BY c."DateCommunication" DESC;

-------------------------------------------------------------------------------
-- FIN TEST COMMUNICATION
-------------------------------------------------------------------------------

-- Pour garder l’historique des messages :
-- COMMIT;

-- Pour annuler :
ROLLBACK;
