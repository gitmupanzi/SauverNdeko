-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "professionnel";
--
-- Name: SCHEMA professionnel; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA professionnel IS 'Profils professionnels, spécialités et rattachements aux entités.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Professionnel; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel" (
    "IdProfessionnel" integer CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" NOT NULL,
    "IdUserFk" integer CONSTRAINT "T_Professionnel_IdUserFk_not_null" NOT NULL,
    "IdTypeProfessionnelFk" integer CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" NOT NULL,
    "IdSpecialiteFk" integer CONSTRAINT "T_Professionnel_IdSpecialiteFk_not_null" NOT NULL,
    "NumeroIdentification" character varying(50),
    "ExperienceAns" integer,
    "ObsProfessionnel" text,
    "ValideProfessionnel" boolean DEFAULT true,
    CONSTRAINT "Chk_Prof_Experience_NonNegative" CHECK ((("ExperienceAns" IS NULL) OR ("ExperienceAns" >= 0))),
    CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" CHECK ((("NumeroIdentification" IS NULL) OR (length(TRIM(BOTH FROM "NumeroIdentification")) > 0)))
);

--
-- Name: TABLE "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel" IS 'Profil professionnel lié à un utilisateur, avec type, spécialité, identification, expérience et validité.';

--
-- Name: COLUMN "T_Professionnel"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdProfessionnel" IS 'Identifiant du profil professionnel.';

--
-- Name: COLUMN "T_Professionnel"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdSpecialiteFk" IS 'Spécialité du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."NumeroIdentification" IS 'Numéro d’identification professionnel déclaré ; une chaîne vide est interdite si renseigné.';

--
-- Name: COLUMN "T_Professionnel"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ExperienceAns" IS 'Nombre d’années d’expérience déclaré pour le professionnel ; valeur négative interdite.';

--
-- Name: COLUMN "T_Professionnel"."ObsProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ObsProfessionnel" IS 'Observations enregistrées sur le profil professionnel.';

--
-- Name: COLUMN "T_Professionnel"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ValideProfessionnel" IS 'Indique si le profil professionnel est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdProfessionnel".';

--
-- Name: CONSTRAINT "T_Professionnel_IdUserFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdUserFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdUserFk".';

--
-- Name: CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdTypeProfessionnelFk".';

--
-- Name: CONSTRAINT "T_Professionnel_IdSpecialiteFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdSpecialiteFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdSpecialiteFk".';

--
-- Name: CONSTRAINT "Chk_Prof_Experience_NonNegative" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_Prof_Experience_NonNegative" ON professionnel."T_Professionnel" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel". Définition : CHECK ("ExperienceAns" IS NULL OR "ExperienceAns" >= 0).';

--
-- Name: CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" ON professionnel."T_Professionnel" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel". Définition : CHECK ("NumeroIdentification" IS NULL OR length(TRIM(BOTH FROM "NumeroIdentification")) > 0).';

--
-- Name: T_Professionnel_Entite; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel_Entite" (
    "IdProfessionnelFk" integer CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" NOT NULL,
    "IdTypeLienFk" integer,
    "DateDebut" timestamp without time zone,
    "DateFin" timestamp without time zone,
    "EstPrincipal" boolean DEFAULT false,
    "ObsLien" text,
    CONSTRAINT "Chk_ProfEnt_Period" CHECK ((("DateFin" IS NULL) OR ("DateDebut" IS NULL) OR ("DateFin" >= "DateDebut")))
);

--
-- Name: TABLE "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel_Entite" IS 'Rattachement d’un professionnel à une entité, identifié par leur couple, avec type de lien, période et indicateur de lien principal.';

--
-- Name: COLUMN "T_Professionnel_Entite"."IdProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: COLUMN "T_Professionnel_Entite"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel_Entite"."IdTypeLienFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdTypeLienFk" IS 'Type de relation entre professionnel et entité. Relation imposée : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel_Entite"."DateDebut"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."DateDebut" IS 'Début du rattachement professionnel à l’entité.';

--
-- Name: COLUMN "T_Professionnel_Entite"."DateFin"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."DateFin" IS 'Fin éventuelle du rattachement ; ne peut précéder DateDebut lorsque les deux dates sont renseignées.';

--
-- Name: COLUMN "T_Professionnel_Entite"."EstPrincipal"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."EstPrincipal" IS 'Indique si ce rattachement professionnel est marqué comme principal.';

--
-- Name: COLUMN "T_Professionnel_Entite"."ObsLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."ObsLien" IS 'Observations enregistrées sur le rattachement professionnel.';

--
-- Name: CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" ON professionnel."T_Professionnel_Entite" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel_Entite". Définition : NOT NULL "IdProfessionnelFk".';

--
-- Name: CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" ON professionnel."T_Professionnel_Entite" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel_Entite". Définition : NOT NULL "IdEntiteFk".';

--
-- Name: CONSTRAINT "Chk_ProfEnt_Period" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_ProfEnt_Period" ON professionnel."T_Professionnel_Entite" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel_Entite". Définition : CHECK ("DateFin" IS NULL OR "DateDebut" IS NULL OR "DateFin" >= "DateDebut").';

--
-- Name: T_Professionnel_IdProfessionnel_seq; Type: SEQUENCE; Schema: professionnel; Owner: -
--

ALTER TABLE professionnel."T_Professionnel" ALTER COLUMN "IdProfessionnel" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME professionnel."T_Professionnel_IdProfessionnel_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Professionnel_IdProfessionnel_seq"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON SEQUENCE professionnel."T_Professionnel_IdProfessionnel_seq" IS 'Séquence de génération de "professionnel"."T_Professionnel"."IdProfessionnel". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Professionnel Pk_IdProfessionnel; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Pk_IdProfessionnel" PRIMARY KEY ("IdProfessionnel");

--
-- Name: CONSTRAINT "Pk_IdProfessionnel" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdProfessionnel" ON professionnel."T_Professionnel" IS 'Clé primaire : identifie de manière unique chaque ligne dans "professionnel"."T_Professionnel". Définition : PRIMARY KEY ("IdProfessionnel").';

--
-- Name: T_Professionnel_Entite Pk_Professionnel_Entite; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Pk_Professionnel_Entite" PRIMARY KEY ("IdProfessionnelFk", "IdEntiteFk");

--
-- Name: CONSTRAINT "Pk_Professionnel_Entite" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_Professionnel_Entite" ON professionnel."T_Professionnel_Entite" IS 'Clé primaire : identifie de manière unique chaque ligne dans "professionnel"."T_Professionnel_Entite". Définition : PRIMARY KEY ("IdProfessionnelFk", "IdEntiteFk").';

--
-- Name: T_Professionnel Uq_Prof_IdUser; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Uq_Prof_IdUser" UNIQUE ("IdUserFk");

--
-- Name: CONSTRAINT "Uq_Prof_IdUser" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Prof_IdUser" ON professionnel."T_Professionnel" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "professionnel"."T_Professionnel". Définition : UNIQUE ("IdUserFk").';

--
-- Name: T_Professionnel Uq_Prof_NumeroIdentification; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Uq_Prof_NumeroIdentification" UNIQUE ("NumeroIdentification");

--
-- Name: CONSTRAINT "Uq_Prof_NumeroIdentification" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Prof_NumeroIdentification" ON professionnel."T_Professionnel" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "professionnel"."T_Professionnel". Définition : UNIQUE ("NumeroIdentification").';

--
-- Name: INDEX "Pk_IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Pk_IdProfessionnel" IS 'Index support de la clé primaire sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdProfessionnel" ON professionnel."T_Professionnel" USING btree ("IdProfessionnel").';

--
-- Name: INDEX "Pk_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Pk_Professionnel_Entite" IS 'Index support de la clé primaire sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_Professionnel_Entite" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk", "IdEntiteFk").';

--
-- Name: Uq_ProfEnt_Principal_Par_Prof; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE UNIQUE INDEX "Uq_ProfEnt_Principal_Par_Prof" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk") WHERE ("EstPrincipal" IS TRUE);

--
-- Name: INDEX "Uq_ProfEnt_Principal_Par_Prof"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_ProfEnt_Principal_Par_Prof" IS 'Index d’unicité sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_ProfEnt_Principal_Par_Prof" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk") WHERE ("EstPrincipal" IS TRUE).';

--
-- Name: INDEX "Uq_Prof_IdUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_Prof_IdUser" IS 'Index d’unicité sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Prof_IdUser" ON professionnel."T_Professionnel" USING btree ("IdUserFk").';

--
-- Name: INDEX "Uq_Prof_NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_Prof_NumeroIdentification" IS 'Index d’unicité sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Prof_NumeroIdentification" ON professionnel."T_Professionnel" USING btree ("NumeroIdentification").';

--
-- Name: idx_prof_specialite; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_prof_specialite ON professionnel."T_Professionnel" USING btree ("IdSpecialiteFk");

--
-- Name: INDEX idx_prof_specialite; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_prof_specialite IS 'Index d’accès sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_prof_specialite ON professionnel."T_Professionnel" USING btree ("IdSpecialiteFk").';

--
-- Name: idx_prof_type; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_prof_type ON professionnel."T_Professionnel" USING btree ("IdTypeProfessionnelFk");

--
-- Name: INDEX idx_prof_type; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_prof_type IS 'Index d’accès sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_prof_type ON professionnel."T_Professionnel" USING btree ("IdTypeProfessionnelFk").';

--
-- Name: idx_profent_datedebut; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profent_datedebut ON professionnel."T_Professionnel_Entite" USING btree ("DateDebut");

--
-- Name: INDEX idx_profent_datedebut; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profent_datedebut IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profent_datedebut ON professionnel."T_Professionnel_Entite" USING btree ("DateDebut").';

--
-- Name: idx_profent_entite; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profent_entite ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk");

--
-- Name: INDEX idx_profent_entite; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profent_entite IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profent_entite ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk").';

--
-- Name: idx_profession_principal; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profession_principal ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk") WHERE ("EstPrincipal" = true);

--
-- Name: INDEX idx_profession_principal; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profession_principal IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profession_principal ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk") WHERE ("EstPrincipal" = true).';

--
-- Name: T_Professionnel aa_reference_champ; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON professionnel."T_Professionnel" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Professionnel_Entite aa_reference_champ; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel_Entite" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON professionnel."T_Professionnel_Entite" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Professionnel_Entite Fk_ProfEnt_Entite; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_ProfEnt_Entite" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_Entite" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel_Entite Fk_ProfEnt_Prof; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_Prof" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: CONSTRAINT "Fk_ProfEnt_Prof" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_Prof" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: T_Professionnel_Entite Fk_ProfEnt_TypeLien; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_TypeLien" FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_ProfEnt_TypeLien" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_TypeLien" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel Fk_Prof_Specialite; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_Specialite" FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_Prof_Specialite" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_Specialite" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel Fk_Prof_TypeProfessionnel; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_TypeProfessionnel" FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_Prof_TypeProfessionnel" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_TypeProfessionnel" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel Fk_Prof_User; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_User" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_Prof_User" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_User" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';
