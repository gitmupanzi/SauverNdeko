-- Ce script a été généré par l'outil ERD (Éditeur de diagramme entité-association) dans pgAdmin 4.
-- Si vous trouvez des bogues, veuillez les signaler sur https://github.com/pgadmin-org/pgadmin4/issues/new/choose. Merci de préciser les étapes de reproduction.
BEGIN;
CREATE TABLE IF NOT EXISTS referentiel."T_CategorieGenerique" (
    "ID_CategorieGenerique" integer NOT NULL GENERATED ALWAYS AS IDENTITY (
        INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1
    ),
    "NomCategorieGenerique" character varying(255) COLLATE pg_catalog."default",
    "ModuleCategorieGenerique" text COLLATE pg_catalog."default",
    "ValideCategorieGenerique" boolean DEFAULT true,
    CONSTRAINT "T_CategorieGenerique_pkey" PRIMARY KEY ("ID_CategorieGenerique")
);
CREATE TABLE IF NOT EXISTS referentiel."T_Generique" (
    "ID_Generique" integer NOT NULL GENERATED ALWAYS AS IDENTITY (
        INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1
    ),
    "ID_CategorieGeneriqueFk" integer NOT NULL,
    "NomGenerique" character varying(255) COLLATE pg_catalog."default" NOT NULL,
    "AbrGenerique" character varying(255) COLLATE pg_catalog."default",
    "VisibleNiveau_2" boolean DEFAULT true,
    "VisibleNiveau_3" boolean DEFAULT true,
    "VisibleNiveau_4" boolean DEFAULT true,
    "VisibleNiveau_5" boolean DEFAULT true,
    "VisibleArticle" boolean DEFAULT true,
    "VisibleCmd" boolean DEFAULT true,
    "VisibleFacture" boolean DEFAULT true,
    "VisibleUsers" boolean DEFAULT true,
    "VisibleVoie" boolean DEFAULT true,
    "VisibleAll" boolean DEFAULT true,
    "ObsGenerique" text COLLATE pg_catalog."default",
    "ValideGenerique" boolean NOT NULL DEFAULT true,
    CONSTRAINT "Pk_T_Generique" PRIMARY KEY ("ID_Generique")
);
ALTER TABLE IF EXISTS referentiel."T_Generique"
ADD CONSTRAINT "Fk_ID_CategorieGenerique" FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique" ("ID_CategorieGenerique") MATCH SIMPLE ON UPDATE CASCADE ON DELETE NO ACTION;
CREATE INDEX IF NOT EXISTS idx_generique_id_categorie ON referentiel."T_Generique"("ID_CategorieGeneriqueFk");
END;