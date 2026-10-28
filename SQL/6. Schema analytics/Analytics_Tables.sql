-- Extrait canonique du catalogue installé le 28/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "analytics";
--
-- Name: SCHEMA analytics; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA analytics IS 'Domaine réservé aux recherches et analyses de la plateforme ; aucun objet applicatif installé lors du relevé du 24/10/2026.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Recherche; Type: TABLE; Schema: analytics; Owner: -
--

CREATE TABLE analytics."T_Recherche" (
    "IdRecherche" integer CONSTRAINT "T_Recherche_IdRecherche_not_null" NOT NULL,
    "IdUserFk" integer,
    "TexteRecherche" text CONSTRAINT "T_Recherche_TexteRecherche_not_null" NOT NULL,
    "TypeRecherche" character varying(80),
    "ID_ArticleResultFk" integer,
    "IdEntiteResultFk" integer,
    "IdSpecialiteFk" integer,
    "LatitudeUser" numeric(9,6),
    "LongitudeUser" numeric(9,6),
    "DateRecherche" timestamp with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Recherche_DateRecherche_not_null" NOT NULL,
    CONSTRAINT "T_Recherche_LatitudeUser_check" CHECK ((("LatitudeUser" >= ('-90'::integer)::numeric) AND ("LatitudeUser" <= (90)::numeric))),
    CONSTRAINT "T_Recherche_LongitudeUser_check" CHECK ((("LongitudeUser" >= ('-180'::integer)::numeric) AND ("LongitudeUser" <= (180)::numeric))),
    CONSTRAINT "T_Recherche_TexteRecherche_check" CHECK (((length(btrim("TexteRecherche")) >= 1) AND (length(btrim("TexteRecherche")) <= 1000)))
);

--
-- Name: TABLE "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON TABLE analytics."T_Recherche" IS 'Événements de recherche explicitement enregistrés par un service autorisé. Aucun suivi automatique ni historique fictif n’est activé par la création de ce socle. Accès administratif global ; appliquer une politique de conservation avant une collecte réelle.';

--
-- Name: COLUMN "T_Recherche"."IdRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdRecherche" IS 'Identifiant automatique de l’événement de recherche.';

--
-- Name: COLUMN "T_Recherche"."IdUserFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdUserFk" IS 'Utilisateur ayant initié la recherche si connu ; NULL après suppression de son compte.';

--
-- Name: COLUMN "T_Recherche"."TexteRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."TexteRecherche" IS 'Texte recherché non vide, limité à 1000 caractères ; peut contenir des données privées, donc accès restreint.';

--
-- Name: COLUMN "T_Recherche"."TypeRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."TypeRecherche" IS 'Qualification textuelle facultative du contexte de recherche ; ne remplace pas un résultat effectivement lié.';

--
-- Name: COLUMN "T_Recherche"."ID_ArticleResultFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."ID_ArticleResultFk" IS 'Article résultat de la recherche s’il existe ; NULL après suppression de cet article.';

--
-- Name: COLUMN "T_Recherche"."IdEntiteResultFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdEntiteResultFk" IS 'Structure résultat de la recherche ; ne constitue pas l’organisation propriétaire de l’événement.';

--
-- Name: COLUMN "T_Recherche"."IdSpecialiteFk"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."IdSpecialiteFk" IS 'Spécialité recherchée dans le référentiel si renseignée.';

--
-- Name: COLUMN "T_Recherche"."LatitudeUser"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."LatitudeUser" IS 'Latitude facultative en degrés décimaux, de -90 à 90 ; aucune collecte automatique n’est activée.';

--
-- Name: COLUMN "T_Recherche"."LongitudeUser"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."LongitudeUser" IS 'Longitude facultative en degrés décimaux, de -180 à 180 ; aucune collecte automatique n’est activée.';

--
-- Name: COLUMN "T_Recherche"."DateRecherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON COLUMN analytics."T_Recherche"."DateRecherche" IS 'Horodatage avec fuseau de l’événement, attribué par PostgreSQL si absent.';

--
-- Name: CONSTRAINT "T_Recherche_IdRecherche_not_null" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdRecherche_not_null" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : NOT NULL "IdRecherche"';

--
-- Name: CONSTRAINT "T_Recherche_TexteRecherche_not_null" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_TexteRecherche_not_null" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : NOT NULL "TexteRecherche"';

--
-- Name: CONSTRAINT "T_Recherche_DateRecherche_not_null" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_DateRecherche_not_null" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : NOT NULL "DateRecherche"';

--
-- Name: CONSTRAINT "T_Recherche_LatitudeUser_check" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_LatitudeUser_check" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : CHECK ("LatitudeUser" >= ''-90''::integer::numeric AND "LatitudeUser" <= 90::numeric)';

--
-- Name: CONSTRAINT "T_Recherche_LongitudeUser_check" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_LongitudeUser_check" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : CHECK ("LongitudeUser" >= ''-180''::integer::numeric AND "LongitudeUser" <= 180::numeric)';

--
-- Name: CONSTRAINT "T_Recherche_TexteRecherche_check" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_TexteRecherche_check" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : CHECK (length(btrim("TexteRecherche")) >= 1 AND length(btrim("TexteRecherche")) <= 1000)';

--
-- Name: T_Recherche_IdRecherche_seq; Type: SEQUENCE; Schema: analytics; Owner: -
--

ALTER TABLE analytics."T_Recherche" ALTER COLUMN "IdRecherche" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME analytics."T_Recherche_IdRecherche_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Recherche_IdRecherche_seq"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON SEQUENCE analytics."T_Recherche_IdRecherche_seq" IS 'Séquence technique d’identité attribuant les identifiants sans réécrire les lignes existantes.';

--
-- Name: T_Recherche T_Recherche_pkey; Type: CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_pkey" PRIMARY KEY ("IdRecherche");

--
-- Name: CONSTRAINT "T_Recherche_pkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_pkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : PRIMARY KEY ("IdRecherche")';

--
-- Name: INDEX "T_Recherche_pkey"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON INDEX analytics."T_Recherche_pkey" IS 'Index de contrainte ou accès : CREATE UNIQUE INDEX "T_Recherche_pkey" ON analytics."T_Recherche" USING btree ("IdRecherche")';

--
-- Name: idx_recherche_article_date; Type: INDEX; Schema: analytics; Owner: -
--

CREATE INDEX idx_recherche_article_date ON analytics."T_Recherche" USING btree ("ID_ArticleResultFk", "DateRecherche");

--
-- Name: INDEX idx_recherche_article_date; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON INDEX analytics.idx_recherche_article_date IS 'Index de contrainte ou accès : CREATE INDEX idx_recherche_article_date ON analytics."T_Recherche" USING btree ("ID_ArticleResultFk", "DateRecherche")';

--
-- Name: idx_recherche_user; Type: INDEX; Schema: analytics; Owner: -
--

CREATE INDEX idx_recherche_user ON analytics."T_Recherche" USING btree ("IdUserFk");

--
-- Name: INDEX idx_recherche_user; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON INDEX analytics.idx_recherche_user IS 'Index de contrainte ou accès : CREATE INDEX idx_recherche_user ON analytics."T_Recherche" USING btree ("IdUserFk")';

--
-- Name: T_Recherche aa_reference_champ; Type: TRIGGER; Schema: analytics; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON analytics."T_Recherche" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON analytics."T_Recherche" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Recherche T_Recherche_ID_ArticleResultFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_ID_ArticleResultFk_fkey" FOREIGN KEY ("ID_ArticleResultFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "T_Recherche_ID_ArticleResultFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_ID_ArticleResultFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("ID_ArticleResultFk") REFERENCES logistique."T_Article"("ID_Article") ON UPDATE CASCADE ON DELETE SET NULL';

--
-- Name: T_Recherche T_Recherche_IdEntiteResultFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_IdEntiteResultFk_fkey" FOREIGN KEY ("IdEntiteResultFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "T_Recherche_IdEntiteResultFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdEntiteResultFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("IdEntiteResultFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL';

--
-- Name: T_Recherche T_Recherche_IdSpecialiteFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_IdSpecialiteFk_fkey" FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "T_Recherche_IdSpecialiteFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdSpecialiteFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL';

--
-- Name: T_Recherche T_Recherche_IdUserFk_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics."T_Recherche"
    ADD CONSTRAINT "T_Recherche_IdUserFk_fkey" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "T_Recherche_IdUserFk_fkey" ON "T_Recherche"; Type: COMMENT; Schema: analytics; Owner: -
--

COMMENT ON CONSTRAINT "T_Recherche_IdUserFk_fkey" ON analytics."T_Recherche" IS 'Intégrité imposée par PostgreSQL : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL';
