DELETE FROM operations."T_Caisse";
DELETE FROM operations."T_Paiement";
DELETE FROM operations."T_Paiement_Archive";

SELECT * FROM operations."T_Caisse";
SELECT * FROM operations."T_Paiement";
SELECT * FROM operations."T_Paiement_Archive";


/* ============================================================================
   TEST D'INSERTION – MODULE OPERATIONS (PAIEMENTS / CAISSE / AUDIT)
   Hypothèses :
     - Les référentiels suivants existent dans referentiel."T_Generique" :
         * Catégorie = 'Role'                → 'Admin Entité'
         * Catégorie = 'Type paiement'       → 'Frais scolaires'
         * Catégorie = 'Statut paiement'     → 'Payé(e)'
         * Catégorie = 'Devise'              → 'USD'
         * Catégorie = 'Type mouvement paiement' → 'Entrée'
         * Catégorie = 'Type entite'         → 'Ecole'
   ========================================================================== */

-- ============================================================================
-- 0. VÉRIFICATIONS PRÉALABLES DES RÉFÉRENTIELS
--    (Optionnel, pour contrôle visuel)
-- ============================================================================

-- a) Vérifier les catégories utilisées
SELECT "ID_CategorieGenerique", "NomCategorieGenerique"
FROM referentiel."T_CategorieGenerique"
WHERE "NomCategorieGenerique" IN (
    'Role',
    'Type paiement',
    'Statut paiement',
    'Devise',
    'Type mouvement paiement',
    'Type entite'
)
ORDER BY "NomCategorieGenerique";

-- b) Vérifier quelques valeurs de T_Generique
SELECT
    c."NomCategorieGenerique",
    g."ID_Generique",
    g."NomGenerique",
    g."AbrGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" IN (
    'Role',
    'Type paiement',
    'Statut paiement',
    'Devise',
    'Type mouvement paiement',
    'Type entite'
)
ORDER BY c."NomCategorieGenerique", g."NomGenerique";

-- c) Vérifie que 'Payé(e)', 'En attente', etc. sont bien définis

SELECT "ID_Generique", "NomGenerique", "AbrGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" ILIKE 'Statut paiement%';

-- d) Type de mouvement
SELECT "ID_Generique", "NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" ILIKE 'Type mouvement paiement%';

-- e) confirmer USD / CDF / autre
SELECT "ID_Generique", "NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" ILIKE 'Devise%';

-- ============================================================================
-- 1. CRÉATION D’UNE ENTITÉ DE TEST (ÉCOLE PILOTE)
--    - Ne s’insère que si elle n’existe pas déjà (via EmailEntite)
-- ============================================================================

INSERT INTO systeme."T_Entite" (
    "NomEntite",
    "PhoneEntite",
    "EmailEntite",
    "AdresseEntite",
    "IdTypeEntiteFk",
    "ValideEntite"
)
SELECT
    'École Pilote TEST' AS "NomEntite",
    '+243000000000'     AS "PhoneEntite",
    'ecole.pilote@test.edu' AS "EmailEntite",
    'Adresse de test, Kinshasa' AS "AdresseEntite",
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Type entite'
          AND g."NomGenerique" = 'Ecole'
        LIMIT 1
    ) AS "IdTypeEntiteFk",
    TRUE AS "ValideEntite"
WHERE NOT EXISTS (
    SELECT 1
    FROM systeme."T_Entite"
    WHERE "EmailEntite" = 'ecole.pilote@test.edu'
);

-- Vérifier l’entité créée
SELECT * FROM systeme."T_Entite"
WHERE "EmailEntite" = 'ecole.pilote@test.edu';



-- ============================================================================
-- 2. CRÉATION D’UN UTILISATEUR DE TEST (ADMIN ENTITÉ)
--    - Ne s’insère que si l’EmailUser n’existe pas
-- ============================================================================

INSERT INTO systeme."T_Utilisateurs" (
    "NomUser",
    "PrenomUser",
    "EmailUser",
    "MotdepasseUser",
    "PhoneUser",
    "IdRoleFk",
    "SexeUser",
    "IdEntiteFk",
    "Is_staff",
    "Is_Admin"
)
SELECT
    'Doe' AS "NomUser",
    'John' AS "PrenomUser",
    'john.doe@test.edu' AS "EmailUser",
    'hashed_password_123' AS "MotdepasseUser",
    '0999999999' AS "PhoneUser",
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Role'
          AND g."NomGenerique" = 'Admin Entité'
        LIMIT 1
    ) AS "IdRoleFk",
    'M'::char(1) AS "SexeUser",
    (
        SELECT "IdEntite"
        FROM systeme."T_Entite"
        WHERE "EmailEntite" = 'ecole.pilote@test.edu'
        LIMIT 1
    ) AS "IdEntiteFk",
    TRUE AS "Is_staff",
    TRUE AS "Is_Admin"
WHERE NOT EXISTS (
    SELECT 1
    FROM systeme."T_Utilisateurs"
    WHERE "EmailUser" = 'john.doe@test.edu'
);

-- Vérifier l’utilisateur créé
SELECT "IdUser", "NomUser", "PrenomUser", "EmailUser", "IdRoleFk", "IdEntiteFk"
FROM systeme."T_Utilisateurs"
WHERE "EmailUser" = 'john.doe@test.edu';



-- ============================================================================
-- 3. INSERTION D’UN PAIEMENT DE TEST DANS operations."T_Paiement"
--    - Tous les FK sont résolus automatiquement via des sous-requêtes
--    - Ce paiement doit déclencher :
--        * gestion_caisse_on_paiement  → mise à jour T_Caisse
--        * audit_log_function          → insertion dans T_Audit_Log
--        * notification_payment_success (communication.T_Communication)
--        * archive_paiements           → pas d’effet immédiat (date > 2 ans)
-- ============================================================================

INSERT INTO operations."T_Paiement" (
    "CodePaiement",
    "IdUserFk",
    "IdTypePaiementFk",
    "MontantPaiement",
    "IdStatutPaiementFk",
    "DatePaiement",
    "ObsPaiement",
    "ValidePaiement",
    "IdDeviseFk",
    "IdPayeurFk",
    "IdTypeMouvementFk",
    "IdEntiteFk"
)
VALUES (
    'P_TEST_001',

    -- IdUserFk : l’utilisateur "john.doe@test.edu"
    (SELECT "IdUser"
     FROM systeme."T_Utilisateurs"
     WHERE "EmailUser" = 'john.doe@test.edu'
     LIMIT 1),

    -- IdTypePaiementFk : 'Frais scolaires' dans catégorie 'Type paiement'
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Type paiement'
       AND g."NomGenerique" = 'Frais scolaires'
     LIMIT 1),

    -- MontantPaiement : 100 USD par exemple
    100.00,

    -- IdStatutPaiementFk : 'Payé(e)' dans catégorie 'Statut paiement'
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Statut paiement'
       AND g."NomGenerique" = 'Payé(e)'
     LIMIT 1),

    -- DatePaiement : maintenant
    NOW(),

    -- ObsPaiement
    'Paiement de test pour frais scolaires',

    -- ValidePaiement
    TRUE,

    -- IdDeviseFk : 'USD' dans catégorie 'Devise'
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Devise'
       AND g."NomGenerique" = 'USD'
     LIMIT 1),

    -- IdPayeurFk : même utilisateur pour le test
    (SELECT "IdUser"
     FROM systeme."T_Utilisateurs"
     WHERE "EmailUser" = 'john.doe@test.edu'
     LIMIT 1),

    -- IdTypeMouvementFk : 'Entrée' dans catégorie 'Type mouvement paiement'
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Type mouvement paiement'
       AND g."NomGenerique" = 'Entrée'
     LIMIT 1),

    -- IdEntiteFk : École Pilote TEST
    (SELECT "IdEntite"
     FROM systeme."T_Entite"
     WHERE "EmailEntite" = 'ecole.pilote@test.edu'
     LIMIT 1)
);

-- Vérifier le paiement inséré
SELECT *
FROM operations."T_Paiement"
ORDER BY "IdPaiement" DESC
LIMIT 5;



-- ============================================================================
-- 4. CONTRÔLES DES EFFETS ANNEXES
-- ============================================================================

-- a) Caisse : doit être mise à jour par operations.gestion_caisse_on_paiement
SELECT *
FROM operations."T_Caisse"
ORDER BY "IdCaisse";

-- b) Audit log : opérations sur T_Paiement et T_Caisse
SELECT *
FROM systeme."T_Audit_Log"
ORDER BY "ChangedAt" DESC
LIMIT 20;

-- c) T_Communication
SELECT *
FROM communication."T_Communication";

-- d) Paiements archivés (normalement vide pour ce test récent)
SELECT *
FROM operations."T_Paiement_Archive"
ORDER BY "IdPaiementArchive" DESC
LIMIT 10;