-- Extrait canonique du catalogue installé le 24/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "referentiel";
--
-- Name: fn_guard_sens_stock(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_guard_sens_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE old_sign integer; new_sign integer;
BEGIN
 IF OLD."ID_CategorieGeneriqueFk"=64 AND (
 EXISTS(SELECT 1 FROM logistique."T_Commande" WHERE "ID_TypeCmdFk"=OLD."ID_Generique") OR
 EXISTS(SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_TypeMvtFk"=OLD."ID_Generique")) THEN
  old_sign:=CASE WHEN OLD."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN OLD."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END;
  new_sign:=CASE WHEN NEW."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN NEW."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF NEW."ID_CategorieGeneriqueFk"<>64 OR new_sign<>old_sign THEN
   RAISE EXCEPTION 'Le sens d’un type de stock déjà utilisé ne peut pas être changé.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;$$;


--
-- Name: FUNCTION fn_guard_sens_stock(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_guard_sens_stock() IS 'Protège le signe Entrée/Sortie et la catégorie 64 d’un type déjà utilisé par une commande ou un mouvement ; évite une réinterprétation rétroactive du stock. Un changement de libellé conservant le signe reste permis.';


--
-- Name: T_Generique; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_Generique" (
    "ID_Generique" integer CONSTRAINT "T_Generique_ID_Generique_not_null" NOT NULL,
    "ID_CategorieGeneriqueFk" integer CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" NOT NULL,
    "NomGenerique" character varying(255) CONSTRAINT "T_Generique_NomGenerique_not_null" NOT NULL,
    "AbrGenerique" character varying(255),
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
    "ObsGenerique" text,
    "ValideGenerique" boolean DEFAULT true CONSTRAINT "T_Generique_ValideGenerique_not_null" NOT NULL
);


--
-- Name: TABLE "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_Generique" IS 'Valeurs des nomenclatures rattachées à une catégorie : libellé, abréviation, visibilité par usage et validité. La signification métier dépend de la catégorie.';


--
-- Name: COLUMN "T_Generique"."ID_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ID_Generique" IS 'Identifiant d’une valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."ID_CategorieGeneriqueFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ID_CategorieGeneriqueFk" IS 'Catégorie à laquelle appartient cette valeur de nomenclature. Relation imposée : FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Generique"."NomGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."NomGenerique" IS 'Libellé métier de la valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."AbrGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."AbrGenerique" IS 'Abréviation de la valeur de nomenclature ; peut porter un code de type utilisé par les règles métier.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_2"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_2" IS 'Indicateur de visibilité pour le niveau géographique de niveau 2.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_3"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_3" IS 'Indicateur de visibilité pour le niveau géographique de niveau 3.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_4"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_4" IS 'Indicateur de visibilité pour le niveau géographique de niveau 4.';


--
-- Name: COLUMN "T_Generique"."VisibleNiveau_5"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5.';


--
-- Name: COLUMN "T_Generique"."VisibleArticle"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleArticle" IS 'Indique la visibilité de la valeur de nomenclature pour les articles.';


--
-- Name: COLUMN "T_Generique"."VisibleCmd"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleCmd" IS 'Indique la visibilité de la valeur de nomenclature pour les commandes.';


--
-- Name: COLUMN "T_Generique"."VisibleFacture"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleFacture" IS 'Indique la visibilité de la valeur de nomenclature pour les factures.';


--
-- Name: COLUMN "T_Generique"."VisibleUsers"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleUsers" IS 'Indique la visibilité de la valeur de nomenclature pour les utilisateurs.';


--
-- Name: COLUMN "T_Generique"."VisibleVoie"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleVoie" IS 'Indique la visibilité de la valeur de nomenclature pour les voies d’accès.';


--
-- Name: COLUMN "T_Generique"."VisibleAll"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleAll" IS 'Indique la visibilité générale de la valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."ObsGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ObsGenerique" IS 'Observations enregistrées sur la valeur de nomenclature.';


--
-- Name: COLUMN "T_Generique"."ValideGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ValideGenerique" IS 'Indique si la valeur de nomenclature est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_Generique_ID_Generique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ID_Generique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ID_Generique".';


--
-- Name: CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ID_CategorieGeneriqueFk".';


--
-- Name: CONSTRAINT "T_Generique_NomGenerique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_NomGenerique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "NomGenerique".';


--
-- Name: CONSTRAINT "T_Generique_ValideGenerique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ValideGenerique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ValideGenerique".';


--
-- Name: T_CategorieGenerique; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_CategorieGenerique" (
    "ID_CategorieGenerique" integer CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" NOT NULL,
    "NomCategorieGenerique" character varying(255),
    "ModuleCategorieGenerique" text,
    "ValideCategorieGenerique" boolean DEFAULT true
);


--
-- Name: TABLE "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_CategorieGenerique" IS 'Catégories de nomenclature : nom, module d’usage et validité. Regroupe les valeurs de T_Generique.';


--
-- Name: COLUMN "T_CategorieGenerique"."ID_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ID_CategorieGenerique" IS 'Identifiant de la catégorie de nomenclature.';


--
-- Name: COLUMN "T_CategorieGenerique"."NomCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature.';


--
-- Name: COLUMN "T_CategorieGenerique"."ModuleCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ModuleCategorieGenerique" IS 'Module ou domaine d’usage de la catégorie de nomenclature.';


--
-- Name: COLUMN "T_CategorieGenerique"."ValideCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ValideCategorieGenerique" IS 'Indique si la catégorie est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" ON referentiel."T_CategorieGenerique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_CategorieGenerique". Définition : NOT NULL "ID_CategorieGenerique".';


--
-- Name: T_CategorieGenerique_ID_CategorieGenerique_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_CategorieGenerique" ALTER COLUMN "ID_CategorieGenerique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME referentiel."T_CategorieGenerique_ID_CategorieGenerique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_CategorieGenerique_ID_CategorieGenerique_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_CategorieGenerique_ID_CategorieGenerique_seq" IS 'Séquence de génération de "referentiel"."T_CategorieGenerique"."ID_CategorieGenerique". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Generique_ID_Generique_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_Generique" ALTER COLUMN "ID_Generique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME referentiel."T_Generique_ID_Generique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Generique_ID_Generique_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_Generique_ID_Generique_seq" IS 'Séquence de génération de "referentiel"."T_Generique"."ID_Generique". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Generique Pk_T_Generique; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_Generique"
    ADD CONSTRAINT "Pk_T_Generique" PRIMARY KEY ("ID_Generique");


--
-- Name: CONSTRAINT "Pk_T_Generique" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_T_Generique" ON referentiel."T_Generique" IS 'Clé primaire : identifie de manière unique chaque ligne dans "referentiel"."T_Generique". Définition : PRIMARY KEY ("ID_Generique").';


--
-- Name: T_CategorieGenerique T_CategorieGenerique_pkey; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_CategorieGenerique"
    ADD CONSTRAINT "T_CategorieGenerique_pkey" PRIMARY KEY ("ID_CategorieGenerique");


--
-- Name: CONSTRAINT "T_CategorieGenerique_pkey" ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_CategorieGenerique_pkey" ON referentiel."T_CategorieGenerique" IS 'Clé primaire : identifie de manière unique chaque ligne dans "referentiel"."T_CategorieGenerique". Définition : PRIMARY KEY ("ID_CategorieGenerique").';


--
-- Name: INDEX "Pk_T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."Pk_T_Generique" IS 'Index support de la clé primaire sur "referentiel"."T_Generique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_T_Generique" ON referentiel."T_Generique" USING btree ("ID_Generique").';


--
-- Name: INDEX "T_CategorieGenerique_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_CategorieGenerique_pkey" IS 'Index support de la clé primaire sur "referentiel"."T_CategorieGenerique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_CategorieGenerique_pkey" ON referentiel."T_CategorieGenerique" USING btree ("ID_CategorieGenerique").';


--
-- Name: idx_generique_id_categorie; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_generique_id_categorie; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.idx_generique_id_categorie IS 'Index d’accès sur "referentiel"."T_Generique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: T_Generique tr_guard_sens_stock; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER tr_guard_sens_stock BEFORE UPDATE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.fn_guard_sens_stock();


--
-- Name: TRIGGER tr_guard_sens_stock ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER tr_guard_sens_stock ON referentiel."T_Generique" IS 'Empêche qu’une modification du référentiel inverse ou efface le sens d’un historique de stock existant.';


--
-- Name: T_Generique Fk_ID_CategorieGenerique; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_Generique"
    ADD CONSTRAINT "Fk_ID_CategorieGenerique" FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_ID_CategorieGenerique" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_CategorieGenerique" ON referentiel."T_Generique" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "referentiel"."T_Generique". Définition : FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE.';
