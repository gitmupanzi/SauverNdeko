-- Motifs communs proposés pour le blocage, le retour et le refus d’une étape.
-- Les modèles continuent à choisir les motifs autorisés pour chaque action.
DO $referentiel$
DECLARE
    categorie integer;
BEGIN
    SELECT r."ID_CategorieDefautFk" INTO STRICT categorie
    FROM referentiel."T_ChampReferentiel" r
    JOIN referentiel."T_CategorieGenerique" c
      ON c."ID_CategorieGenerique" = r."ID_CategorieDefautFk"
    WHERE r."SchemaName" = 'support'
      AND r."TableName" = 'T_EtapeParcours'
      AND r."ColumnName" = 'ID_MotifBlocageFk'
      AND c."IdEntiteFk" IS NULL;

    PERFORM pg_advisory_xact_lock(hashtextextended('referentiel:valeurs:' || categorie::text, 0));

    INSERT INTO referentiel."T_Generique" (
        "ID_CategorieGeneriqueFk", "NomGenerique", "AbrGenerique", "ValideGenerique"
    )
    SELECT categorie, motif.libelle, motif.libelle, true
    FROM (VALUES
        ('Pièce manquante'),
        ('Information incomplète'),
        ('Information à corriger'),
        ('Justificatif non conforme'),
        ('Validation en attente'),
        ('Réponse externe en attente'),
        ('Dossier hors périmètre'),
        ('Critères non remplis'),
        ('Doublon confirmé')
    ) AS motif(libelle)
    WHERE NOT EXISTS (
        SELECT 1
        FROM referentiel."T_Generique" g
        WHERE g."ID_CategorieGeneriqueFk" = categorie
          AND referentiel.fn_normaliser_libelle(motif.libelle) IN (
              referentiel.fn_normaliser_libelle(g."NomGenerique"),
              referentiel.fn_normaliser_libelle(g."AbrGenerique")
          )
    );
END $referentiel$;
