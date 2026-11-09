-- Restrictions individuelles superposées aux licences et aux droits de rôle.
CREATE TABLE systeme."T_UtilisateurModule" (
    "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite"),
    "IdUserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE CASCADE,
    "CodeModule" varchar(32) NOT NULL REFERENCES systeme."T_ModuleApplication"("CodeModule"),
    "CodeOnglet" varchar(40) NOT NULL DEFAULT '',
    "PeutConsulter" boolean NOT NULL,
    "PeutGerer" boolean NOT NULL,
    "PeutExporter" boolean NOT NULL,
    "Version" integer NOT NULL DEFAULT 1 CHECK ("Version" > 0),
    "ModifieParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL,
    "ModifieLe" timestamptz NOT NULL DEFAULT statement_timestamp(),
    PRIMARY KEY ("IdEntiteFk", "IdUserFk", "CodeModule", "CodeOnglet"),
    CHECK ("PeutConsulter" OR (NOT "PeutGerer" AND NOT "PeutExporter")),
    CHECK ("CodeOnglet" = '' OR ("CodeModule", "CodeOnglet") = ('logistique', 'immobilisations'))
);
CREATE INDEX utilisateur_module_user_idx ON systeme."T_UtilisateurModule" ("IdUserFk");

COMMENT ON TABLE systeme."T_UtilisateurModule" IS 'Limites individuelles d’accès dans l’entreprise du compte. Elles ne peuvent ajouter aucun droit au rôle ni à la licence.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."IdEntiteFk" IS 'Entreprise dans laquelle la restriction s’applique.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."IdUserFk" IS 'Compte auquel la restriction s’applique.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."CodeModule" IS 'Code stable de l’application concernée.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."CodeOnglet" IS 'Vide pour le module entier. Sinon, code stable d’un onglet couvert côté serveur.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."PeutConsulter" IS 'La restriction individuelle laisse la consultation au rôle.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."PeutGerer" IS 'La restriction individuelle laisse les écritures au rôle.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."PeutExporter" IS 'La restriction individuelle laisse les exports au rôle.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."Version" IS 'Version utilisée pour détecter une modification concurrente.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification.';
COMMENT ON COLUMN systeme."T_UtilisateurModule"."ModifieLe" IS 'Instant de la dernière modification de la règle.';
