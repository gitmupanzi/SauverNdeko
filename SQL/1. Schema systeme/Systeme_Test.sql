SELECT * FROM systeme."T_Login";
SELECT * FROM systeme."T_Licence";
SELECT * FROM systeme."T_Audit_Log";
SELECT * FROM systeme."T_Utilisateurs";
SELECT * FROM systeme."T_Entite";

-- les tables liées à T_Utilisateurs
SELECT
    tc.table_schema   AS schema_fk,
    tc.table_name     AS table_fk,
    kcu.column_name   AS colonne_fk,
    ccu.table_schema  AS schema_pk,
    ccu.table_name    AS table_pk,
    ccu.column_name   AS colonne_pk
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
     ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
     ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_schema = 'systeme'
  AND ccu.table_name   = 'T_Utilisateurs'
ORDER BY schema_fk, table_fk;

-- Select de ces tables et suppressions
SELECT * FROM communication."T_Chat";
SELECT * FROM communication."T_Discussion";
SELECT * FROM communication."T_Communication";
SELECT * FROM logistique."T_Article";
SELECT * FROM logistique."T_Commande";
SELECT * FROM operations."T_Paiement";
SELECT * FROM systeme."T_Login";
SELECT * FROM systeme."T_Audit_Log";
SELECT * FROM systeme."T_Utilisateurs";


-- Pré-requis : vérifier les valeurs T_Generique
-- Types entité
SELECT g."ID_Generique", g."NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" = 'Type entite';

-- Rôles
SELECT g."ID_Generique", g."NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" = 'Role';

-- Type login
SELECT g."ID_Generique", g."NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" = 'Type login';

-- Statut licence
SELECT g."ID_Generique", g."NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" = 'Statut licence';

-- Créer une entité de test dans systeme."T_Entite"

INSERT INTO systeme."T_Entite" (
    "NomEntite",
    "PhoneEntite",
    "EmailEntite",
    "AdresseEntite",
    "IdTypeEntiteFk"
)
VALUES (
    'École Pilote Test',
    '+243811112222',
    'ecole.pilote@test.edu',
    'Kinshasa, Gombe',
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Type entite'
          AND g."NomGenerique" = 'Ecole'
        LIMIT 1
    )
)
RETURNING "IdEntite";

-- Créer deux utilisateurs de test dans systeme."T_Utilisateurs"
INSERT INTO systeme."T_Utilisateurs" (
    "NomUser", "PrenomUser", "EmailUser",
    "MotdepasseUser", "PhoneUser",
    "IdRoleFk", "SexeUser", "IdEntiteFk",
    "Is_staff", "Is_Admin"
)
VALUES
(
    'DOE', 'John', 'john.doe@test.edu',
    'hashed_password_123', '+243810000001',
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Role'
          AND g."NomGenerique" = 'Admin'
        LIMIT 1
    ),
    'M',
    (SELECT "IdEntite" FROM systeme."T_Entite"
      WHERE "EmailEntite" = 'ecole.pilote@test.edu'),
    TRUE,
    TRUE
),
(
    'SMITH', 'Jane', 'jane.smith@test.edu',
    'hashed_password_456', '+243810000002',
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Role'
          AND g."NomGenerique" = 'Manager'
        LIMIT 1
    ),
    'F',
    (SELECT "IdEntite" FROM systeme."T_Entite"
      WHERE "EmailEntite" = 'ecole.pilote@test.edu'),
    TRUE,
    FALSE
);

SELECT *
FROM systeme."T_Utilisateurs";

SELECT *
FROM systeme."T_Audit_Log";

-- Créer une licence de test dans systeme."T_Licence"
INSERT INTO systeme."T_Licence" (
    "IdLicence",
    "IdEntiteFk",
    "DateDebut",
    "DateFin",
    "IdStatutLicenceFk"
)
VALUES (
    1,
    (SELECT "IdEntite"
     FROM systeme."T_Entite"
     WHERE "EmailEntite" = 'ecole.pilote@test.edu'),
    NOW(),
    NOW() + INTERVAL '1 year',
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Statut licence'
          AND g."NomGenerique" = 'Active'
        LIMIT 1
    )
);

SELECT * FROM systeme."T_Licence";
SELECT * FROM systeme."T_Audit_Log" WHERE "TableName" = 'T_Licence';

-- Créer un login de test dans systeme."T_Login"
INSERT INTO systeme."T_Login" (
    "IdUserFk",
    "IdTypeLoginFk",
    "DateLogin",
    "IdEntiteFk"
)
SELECT
    u."IdUser",
    t."ID_Generique" AS "IdTypeLoginFk",
    CURRENT_TIMESTAMP,
    u."IdEntiteFk"
FROM systeme."T_Utilisateurs" u
CROSS JOIN LATERAL (
    SELECT g."ID_Generique"
    FROM referentiel."T_Generique" g
    JOIN referentiel."T_CategorieGenerique" c
      ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
    WHERE c."NomCategorieGenerique" = 'Type login'
      AND g."NomGenerique" = 'Connexion'
    LIMIT 1
) AS t
WHERE u."EmailUser" = 'john.doe@test.edu'
  AND NOT EXISTS (
      SELECT 1
      FROM systeme."T_Login" l
      WHERE l."IdUserFk"      = u."IdUser"
        AND l."IdTypeLoginFk" = t."ID_Generique"
  );


-- Petit check global
-- Entités
SELECT * FROM systeme."T_Entite";

-- Utilisateurs + Role + Entité
SELECT u."IdUser", u."NomUser", u."PrenomUser",
       u."EmailUser", u."PhoneUser",
       g."NomGenerique" AS role,
       e."NomEntite"
FROM systeme."T_Utilisateurs" u
LEFT JOIN referentiel."T_Generique" g
  ON g."ID_Generique" = u."IdRoleFk"
LEFT JOIN systeme."T_Entite" e
  ON e."IdEntite" = u."IdEntiteFk";

-- Licences + statut
SELECT l."IdLicence", e."NomEntite",
       l."DateDebut", l."DateFin",
       g."NomGenerique" AS statut_licence
FROM systeme."T_Licence" l
LEFT JOIN systeme."T_Entite" e
  ON e."IdEntite" = l."IdEntiteFk"
LEFT JOIN referentiel."T_Generique" g
  ON g."ID_Generique" = l."IdStatutLicenceFk";

-- Audit log (global)
SELECT * FROM systeme."T_Audit_Log"
ORDER BY "ChangedAt" DESC
LIMIT 50;


--- Vérification des vues
SELECT * FROM systeme."V_Audit_log";
SELECT * FROM systeme."V_Entite_Localisation_Detail";
SELECT * FROM systeme."V_Licence_active";
SELECT * FROM systeme."V_Login_history";
SELECT * FROM systeme."V_User_profil";