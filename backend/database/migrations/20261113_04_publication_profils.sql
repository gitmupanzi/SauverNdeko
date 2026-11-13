ALTER TABLE systeme."T_Entite"
    ADD COLUMN IF NOT EXISTS "PartageProfilsPublicParDefaut" boolean NOT NULL DEFAULT true;
COMMENT ON COLUMN systeme."T_Entite"."PartageProfilsPublicParDefaut" IS
    'Publication proposée à la création des profils de cette entreprise, sous réserve des contrôles de l’annuaire. Sans effet sur les profils existants.';
