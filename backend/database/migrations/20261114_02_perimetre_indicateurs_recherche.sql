-- Rattachement stable à l’entreprise de la déclaration, pour le seuil par entreprise.
CREATE OR REPLACE VIEW analytics."V_ObservationDemandeRecherche" AS
SELECT date_trunc('month', b."CreeLe" AT TIME ZONE 'Africa/Kinshasa')::date AS "Mois",
       b."IdCategorieProduitFk" AS "IdProduitFk",
       g."AbrGenerique" AS "ProduitLibelle",
       b."IdTerritoireFk", n."NomNiveau_1" AS "TerritoireLibelle",
       b."Etat" AS "EtatDemande", b."IdAuteurFk" AS "Contributeur",
       b."Source", b."Nature",
       CASE WHEN b."Nature" = 'recherche' THEN b."IdPathologieFk" END AS "IdPathologieFk",
       CASE WHEN b."Nature" = 'recherche' THEN m."AbrGenerique" END AS "PathologieLibelle",
       CASE WHEN b."Nature" = 'besoin_sans_resultat' THEN 'sans_resultat' END AS "ResultatRecherche",
       b."IdEntiteFk"
FROM communication."T_BesoinAnnuaire" b
JOIN analytics."T_PerimetreRecherche" p ON p."IdEntiteFk" = b."IdEntiteFk"
    AND p."TermineLe" IS NULL AND b."CreeLe" >= p."DebuteLe"
JOIN systeme."T_Entite" e ON e."IdEntite" = p."IdEntiteFk" AND e."ValideEntite" IS TRUE
LEFT JOIN geolocalisation."T_Niveau_1" n ON n."ID_Niveau_1" = b."IdTerritoireFk"
LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = b."IdCategorieProduitFk"
LEFT JOIN referentiel."T_Generique" m ON m."ID_Generique" = b."IdPathologieFk"
WHERE b."Consentement";

COMMENT ON VIEW analytics."V_ObservationDemandeRecherche" IS
    'Source interne des agrégats mensuels. Le seuil de confidentialité est appliqué par entreprise avant toute consolidation.';
COMMENT ON COLUMN analytics."V_ObservationDemandeRecherche"."IdEntiteFk" IS
    'Entreprise enregistrée au moment de la déclaration consentie. Utilisée pour l’isolation et jamais exposée par cellule du rapport.';
