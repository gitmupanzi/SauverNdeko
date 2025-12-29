/* ============================================================================
   TEST D'INSERTION – SCÉNARIO RECHERCHE & COMMANDE MÉDICAMENT
   SauverNdeko – Recherche d’un médicament, listing des pharmacies proches,
                  choix d’une pharmacie, visualisation du prix,
                  passage d’une commande et contact pharmacie.

   Hypothèses de référentiels (à adapter si besoin) :
     - referentiel."T_CategorieGenerique" / "T_Generique" contiennent :
         * Catégorie = 'Type entite'          → 'Pharmacie'
         * Catégorie = 'Type article'         → 'Médicament'
         * Catégorie = 'Devise'               → 'USD'
         * Catégorie = 'Statut commande'      → 'Enregistrée'
         * Catégorie = 'Type commande'        → 'Commande médicament'
         * Catégorie = 'Type recherche'       → 'Produit pharmaceutique'
         * Catégorie = 'Type communication'   → 'Contact pharmacie'
         * Catégorie = 'Canal communication'  → 'Appel', 'WhatsApp'
   ========================================================================== */


-- ============================================================================
-- 0. VÉRIFICATIONS PRÉALABLES DES RÉFÉRENTIELS
--    (Optionnel, pour contrôle visuel)
-- ============================================================================

-- a) Vérifier les catégories utilisées
SELECT "ID_CategorieGenerique", "NomCategorieGenerique"
FROM referentiel."T_CategorieGenerique"
WHERE "NomCategorieGenerique" IN (
    'Type entite',
    'Type article',
    'Devise',
    'Statut commande',
    'Type commande',
    'Type recherche',
    'Type communication',
    'Canal communication'
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
    'Type entite',
    'Type article',
    'Devise',
    'Statut commande',
    'Type commande',
    'Type recherche',
    'Type communication',
    'Canal communication'
)
ORDER BY c."NomCategorieGenerique", g."NomGenerique";

-- c) Vérifier la devise USD
SELECT g."ID_Generique", g."NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" = 'Devise'
  AND g."NomGenerique" = 'USD';

-- d) Vérifier le type entité = Pharmacie
SELECT g."ID_Generique", g."NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" = 'Type entite'
  AND g."NomGenerique" = 'Pharmacie';

-- e) Vérifier le type article = Médicament
SELECT g."ID_Generique", g."NomGenerique"
FROM referentiel."T_Generique" g
JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
WHERE c."NomCategorieGenerique" = 'Type article'
  AND g."NomGenerique" = 'Médicament';



/* ============================================================================
   1. CRÉATION D’UN UTILISATEUR CLIENT QUI CHERCHE LE MÉDICAMENT
   ========================================================================== */

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
    'KABILA'                 AS "NomUser",
    'PatientTest'            AS "PrenomUser",
    'patient.test@sauverndeko.cd' AS "EmailUser",
    'hashed_password_patient'     AS "MotdepasseUser",
    '+243810000000'          AS "PhoneUser",
    NULL                     AS "IdRoleFk",   -- simple user, pas admin
    'M'::char(1)             AS "SexeUser",
    NULL                     AS "IdEntiteFk", -- n’appartient à aucune entité
    FALSE                    AS "Is_staff",
    FALSE                    AS "Is_Admin"
WHERE NOT EXISTS (
    SELECT 1
    FROM systeme."T_Utilisateurs"
    WHERE "EmailUser" = 'patient.test@sauverndeko.cd'
);

-- Vérifier
SELECT "IdUser", "NomUser", "PrenomUser", "EmailUser"
FROM systeme."T_Utilisateurs"
WHERE "EmailUser" = 'patient.test@sauverndeko.cd';



/* ============================================================================
   2. CRÉATION D’UNE PHARMACIE DE TEST (ENTITÉ PRESTATAIRE)
   ========================================================================== */

INSERT INTO systeme."T_Entite" (
    "NomEntite",
    "PhoneEntite",
    "EmailEntite",
    "AdresseEntite",
    "IdTypeEntiteFk",
    "ValideEntite"
)
SELECT
    'Pharmacie SauverNdeko TEST' AS "NomEntite",
    '+243820000000'              AS "PhoneEntite",
    'pharmacie.test@sauverndeko.cd' AS "EmailEntite",
    'Référence : Marché de la Liberté, Masina, Kinshasa' AS "AdresseEntite",
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Type entite'
          AND g."NomGenerique" = 'Pharmacie'
        LIMIT 1
    ) AS "IdTypeEntiteFk",
    TRUE AS "ValideEntite"
WHERE NOT EXISTS (
    SELECT 1
    FROM systeme."T_Entite"
    WHERE "EmailEntite" = 'pharmacie.test@sauverndeko.cd'
);

-- Vérifier
SELECT *
FROM systeme."T_Entite"
WHERE "EmailEntite" = 'pharmacie.test@sauverndeko.cd';



/* ============================================================================
   3. LOCALISATION DE LA PHARMACIE (OPTIONNEL, À ADAPTER À TA STRUCTURE)
   ========================================================================== */

-- ⚠️ Adapter selon ta table réelle : systeme."T_Entite_Localisation" ou autre

-- Exemple indicatif (si tu as une table de liaison entité ↔ géolocalisation) :

/*
INSERT INTO systeme."T_Entite_Localisation" (
    "IdEntiteFk",
    "Latitude",
    "Longitude",
    "IdNiveau0Fk",
    "IdNiveau1Fk",
    "IdNiveau2Fk",
    "AdresseDetaillee"
)
SELECT
    e."IdEntite",
    -4.363000,              -- latitude approximative Masina
    15.365000,              -- longitude approximative
    n0."IdNiveau0",
    n1."IdNiveau1",
    n2."IdNiveau2",
    'Réf. Marché de la Liberté, Masina'
FROM systeme."T_Entite" e
JOIN geolocalisation."T_Niveau_0" n0 ON n0."NomNiveau0" = 'RDC'
JOIN geolocalisation."T_Niveau_1" n1 ON n1."NomNiveau1" = 'Kinshasa'
JOIN geolocalisation."T_Niveau_2" n2 ON n2."NomNiveau2" = 'Masina'
WHERE e."EmailEntite" = 'pharmacie.test@sauverndeko.cd'
  AND NOT EXISTS (
      SELECT 1 FROM systeme."T_Entite_Localisation" el
      WHERE el."IdEntiteFk" = e."IdEntite"
  );
*/



/* ============================================================================
   4. CRÉATION D’UN MÉDICAMENT DANS LE CATALOGUE PRODUITS
   ========================================================================== */

INSERT INTO logistique."T_Article" (
    "CodeArticle",
    "NomArticle",
    "DescriptionArticle",
    "IdTypeArticleFk",
    "PrixUnitaire",
    "IdDeviseFk",
    "ActifArticle"
)
SELECT
    'MED_AMOXI_500'             AS "CodeArticle",
    'Amoxicilline 500 mg gélule' AS "NomArticle",
    'Boîte de 20 gélules'        AS "DescriptionArticle",
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Type article'
          AND g."NomGenerique" = 'Médicament'
        LIMIT 1
    ) AS "IdTypeArticleFk",
    7.50::numeric                AS "PrixUnitaire",  -- prix par boîte
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Devise'
          AND g."NomGenerique" = 'USD'
        LIMIT 1
    ) AS "IdDeviseFk",
    TRUE AS "ActifArticle"
WHERE NOT EXISTS (
    SELECT 1
    FROM logistique."T_Article"
    WHERE "CodeArticle" = 'MED_AMOXI_500'
);

-- Vérifier
SELECT "ID_Article", "CodeArticle", "NomArticle", "PrixUnitaire"
FROM logistique."T_Article"
WHERE "CodeArticle" = 'MED_AMOXI_500';



/* ============================================================================
   5. SIMULATION DU STOCK DE CE MÉDICAMENT DANS LA PHARMACIE
   ========================================================================== */

-- ⚠️ Adapter à ta structure de stock :
--   - soit table logistique."T_Stock"
--   - soit seulement logistique."T_Mouvement" (entrées/sorties)

-- Exemple avec une table de stock direct "T_Stock" :

/*
INSERT INTO logistique."T_Stock" (
    "IdEntiteFk",
    "ID_ArticleFk",
    "QuantiteStock",
    "DateDerniereMaj"
)
SELECT
    e."IdEntite",
    a."ID_Article",
    100::integer          AS "QuantiteStock",
    NOW()                 AS "DateDerniereMaj"
FROM systeme."T_Entite" e
JOIN logistique."T_Article" a ON a."CodeArticle" = 'MED_AMOXI_500'
WHERE e."EmailEntite" = 'pharmacie.test@sauverndeko.cd'
  AND NOT EXISTS (
      SELECT 1
      FROM logistique."T_Stock" s
      WHERE s."IdEntiteFk" = e."IdEntite"
        AND s."ID_ArticleFk" = a."ID_Article"
  );
*/

-- Exemple avec un mouvement d’entrée (si tu ne gères que les mouvements) :

/*
INSERT INTO logistique."T_Mouvement" (
    "IdEntiteFk",
    "ID_ArticleFk",
    "QuantiteMouvement",
    "TypeMouvement",        -- entrée/sortie (adapter à ton modèle)
    "DateMouvement",
    "ObsMouvement"
)
SELECT
    e."IdEntite",
    a."ID_Article",
    100::integer,
    'ENTREE',
    NOW(),
    'Stock initial test Amoxicilline 500 mg'
FROM systeme."T_Entite" e
JOIN logistique."T_Article" a ON a."CodeArticle" = 'MED_AMOXI_500'
WHERE e."EmailEntite" = 'pharmacie.test@sauverndeko.cd';
*/



/* ============================================================================
   6. SIMULATION DE LA RECHERCHE PAR L’UTILISATEUR
   ========================================================================== */

-- On enregistre une ligne dans analytics."T_Recherche"
-- ⚠️ Adapter exactement à ton schéma (noms de colonnes).

INSERT INTO analytics."T_Recherche" (
    "IdUserFk",
    "TexteRecherche",
    "IdTypeRechercheFk",
    "IdArticleFk",
    "LatitudeUser",
    "LongitudeUser",
    "DateRecherche",
    "ObsRecherche"
)
SELECT
    u."IdUser",
    'Amoxicilline 500 mg' AS "TexteRecherche",
    (
        SELECT g."ID_Generique"
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE c."NomCategorieGenerique" = 'Type recherche'
          AND g."NomGenerique" = 'Produit pharmaceutique'
        LIMIT 1
    ) AS "IdTypeRechercheFk",
    a."ID_Article"         AS "IdArticleFk",
    -4.36::numeric         AS "LatitudeUser",   -- Pos. utilisateur (ex. Masina)
    15.35::numeric         AS "LongitudeUser",
    NOW()                  AS "DateRecherche",
    'Recherche test Amoxicilline pour scénario SauverNdeko' AS "ObsRecherche"
FROM systeme."T_Utilisateurs" u
JOIN logistique."T_Article" a ON a."CodeArticle" = 'MED_AMOXI_500'
WHERE u."EmailUser" = 'patient.test@sauverndeko.cd';

-- Vérifier
SELECT *
FROM analytics."T_Recherche"
ORDER BY "IdRecherche" DESC
LIMIT 5;



/* ============================================================================
   7. SIMULATION DU CHOIX D’UNE PHARMACIE + COMMANDE
   ========================================================================== */

-- a) Création d’une commande logistique."T_Commande"

INSERT INTO logistique."T_Commande" (
    "CodeCommande",
    "IdClientUserFk",         -- l’utilisateur patient
    "IdEntiteFk",             -- la pharmacie choisie
    "IdTypeCommandeFk",
    "IdStatutCommandeFk",
    "DateCommande",
    "ObsCommande",
    "ValideCommande"
)
VALUES (
    'CMD_TEST_AMOXI_001',

    -- IdClientUserFk
    (SELECT "IdUser"
     FROM systeme."T_Utilisateurs"
     WHERE "EmailUser" = 'patient.test@sauverndeko.cd'
     LIMIT 1),

    -- IdEntiteFk : la pharmacie
    (SELECT "IdEntite"
     FROM systeme."T_Entite"
     WHERE "EmailEntite" = 'pharmacie.test@sauverndeko.cd'
     LIMIT 1),

    -- Type commande : 'Commande médicament'
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Type commande'
       AND g."NomGenerique" = 'Commande médicament'
     LIMIT 1),

    -- Statut commande : 'Enregistrée'
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Statut commande'
       AND g."NomGenerique" = 'Enregistrée'
     LIMIT 1),

    NOW(),    -- DateCommande
    'Commande test Amoxicilline 500 mg (SauverNdeko)',
    TRUE      -- ValideCommande
);

-- Vérifier la commande
SELECT *
FROM logistique."T_Commande"
ORDER BY "IdCommande" DESC
LIMIT 5;


-- b) Détail de la commande : 2 boîtes d’Amoxicilline 500 mg

INSERT INTO logistique."T_CommandeDetail" (
    "IdCommandeFk",
    "ID_ArticleFk",
    "Quantite",
    "PrixUnitaire",
    "MontantLigne"
)
SELECT
    c."IdCommande",
    a."ID_Article",
    2::integer AS "Quantite",
    a."PrixUnitaire",
    (2::numeric * a."PrixUnitaire") AS "MontantLigne"
FROM logistique."T_Commande" c
JOIN logistique."T_Article" a
  ON a."CodeArticle" = 'MED_AMOXI_500'
WHERE c."CodeCommande" = 'CMD_TEST_AMOXI_001';

-- Vérifier
SELECT *
FROM logistique."T_CommandeDetail" d
JOIN logistique."T_Commande" c ON c."IdCommande" = d."IdCommandeFk"
WHERE c."CodeCommande" = 'CMD_TEST_AMOXI_001';



/* ============================================================================
   8. SIMULATION DU CONTACT PHARMACIE (APPEL / WHATSAPP)
   ========================================================================== */

-- On enregistre un événement de communication dans communication."T_Communication"
-- ⚠️ Adapter à ton modèle : type communication, canal, etc.

INSERT INTO communication."T_Communication" (
    "IdUserEmetteurFk",
    "IdEntiteDestinataireFk",
    "IdTypeCommunicationFk",
    "IdCanalCommunicationFk",
    "ObjetCommunication",
    "MessageCommunication",
    "DateEnvoi",
    "ValideCommunication"
)
VALUES (
    -- utilisateur patient
    (SELECT "IdUser"
     FROM systeme."T_Utilisateurs"
     WHERE "EmailUser" = 'patient.test@sauverndeko.cd'
     LIMIT 1),

    -- entité : pharmacie
    (SELECT "IdEntite"
     FROM systeme."T_Entite"
     WHERE "EmailEntite" = 'pharmacie.test@sauverndeko.cd'
     LIMIT 1),

    -- Type communication : Contact pharmacie
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Type communication'
       AND g."NomGenerique" = 'Contact pharmacie'
     LIMIT 1),

    -- Canal communication : WhatsApp (par ex.)
    (SELECT g."ID_Generique"
     FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
     WHERE c."NomCategorieGenerique" = 'Canal communication'
       AND g."NomGenerique" = 'WhatsApp'
     LIMIT 1),

    'Demande de disponibilité Amoxicilline 500 mg',
    'Bonjour, je souhaite confirmer la disponibilité de 2 boîtes d’Amoxicilline 500 mg avant de me déplacer. Merci.',
    NOW(),
    TRUE
);

-- Vérifier
SELECT *
FROM communication."T_Communication"
ORDER BY "IdCommunication" DESC
LIMIT 10;



/* ============================================================================
   9. RÉCAPITULATIF RAPIDE – CONTRÔLES GLOBAUX
   ========================================================================== */

-- Utilisateur client
SELECT "IdUser", "NomUser", "PrenomUser", "EmailUser"
FROM systeme."T_Utilisateurs"
WHERE "EmailUser" = 'patient.test@sauverndeko.cd';

-- Pharmacie
SELECT "IdEntite", "NomEntite", "EmailEntite"
FROM systeme."T_Entite"
WHERE "EmailEntite" = 'pharmacie.test@sauverndeko.cd';

-- Médicament
SELECT "ID_Article", "CodeArticle", "NomArticle", "PrixUnitaire"
FROM logistique."T_Article"
WHERE "CodeArticle" = 'MED_AMOXI_500';

-- Dernières recherches
SELECT *
FROM analytics."T_Recherche"
ORDER BY "IdRecherche" DESC
LIMIT 5;

-- Dernières commandes
SELECT *
FROM logistique."T_Commande"
ORDER BY "IdCommande" DESC
LIMIT 5;

SELECT d.*
FROM logistique."T_CommandeDetail" d
JOIN logistique."T_Commande" c ON c."IdCommande" = d."IdCommandeFk"
WHERE c."CodeCommande" = 'CMD_TEST_AMOXI_001';

-- Dernières communications
SELECT *
FROM communication."T_Communication"
ORDER BY "IdCommunication" DESC
LIMIT 10;

