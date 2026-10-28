-- Extrait canonique du catalogue installé le 28/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_CategorieGenerique; Type: VIEW; Schema: referentiel; Owner: -
--

CREATE VIEW referentiel."V_CategorieGenerique" AS
 SELECT "ID_CategorieGenerique",
    "NomCategorieGenerique",
    "ModuleCategorieGenerique",
    "ValideCategorieGenerique"
   FROM referentiel."T_CategorieGenerique" c
  ORDER BY "NomCategorieGenerique", "ModuleCategorieGenerique";

--
-- Name: VIEW "V_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_CategorieGenerique" IS 'Projection au grain catégorie de nomenclature : identité, module d’usage et validité. Aucun filtre de validité n’est appliqué.';

--
-- Name: COLUMN "V_CategorieGenerique"."ID_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."ID_CategorieGenerique" IS 'Identifiant de la catégorie de nomenclature. Expression projetée : "ID_CategorieGenerique".';

--
-- Name: COLUMN "V_CategorieGenerique"."NomCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature. Expression projetée : "NomCategorieGenerique".';

--
-- Name: COLUMN "V_CategorieGenerique"."ModuleCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."ModuleCategorieGenerique" IS 'Module ou domaine d’usage de la catégorie de nomenclature. Expression projetée : "ModuleCategorieGenerique".';

--
-- Name: COLUMN "V_CategorieGenerique"."ValideCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."ValideCategorieGenerique" IS 'Indique si la catégorie est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : "ValideCategorieGenerique".';

--
-- Name: V_Generique; Type: VIEW; Schema: referentiel; Owner: -
--

CREATE VIEW referentiel."V_Generique" AS
 SELECT g."ID_CategorieGeneriqueFk",
    c."NomCategorieGenerique",
    c."ModuleCategorieGenerique",
    g."ID_Generique",
    g."NomGenerique",
    g."AbrGenerique",
    g."VisibleNiveau_2",
    g."VisibleNiveau_3",
    g."VisibleNiveau_4",
    g."VisibleNiveau_5",
    g."VisibleArticle",
    g."VisibleCmd",
    g."VisibleFacture",
    g."VisibleUsers",
    g."VisibleVoie",
    g."VisibleAll",
    g."ObsGenerique",
    g."ValideGenerique"
   FROM (referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c ON ((g."ID_CategorieGeneriqueFk" = c."ID_CategorieGenerique")))
  ORDER BY c."NomCategorieGenerique", g."NomGenerique", g."AbrGenerique";

--
-- Name: VIEW "V_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_Generique" IS 'Valeurs de nomenclature enrichies avec leur catégorie et module, au grain valeur générique ; expose visibilité et validité sans filtrer les valeurs inactives.';

--
-- Name: COLUMN "V_Generique"."ID_CategorieGeneriqueFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ID_CategorieGeneriqueFk" IS 'Catégorie à laquelle appartient cette valeur de nomenclature. Expression projetée : g."ID_CategorieGeneriqueFk".';

--
-- Name: COLUMN "V_Generique"."NomCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature. Expression projetée : c."NomCategorieGenerique".';

--
-- Name: COLUMN "V_Generique"."ModuleCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ModuleCategorieGenerique" IS 'Module ou domaine d’usage de la catégorie de nomenclature. Expression projetée : c."ModuleCategorieGenerique".';

--
-- Name: COLUMN "V_Generique"."ID_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ID_Generique" IS 'Identifiant d’une valeur de nomenclature. Expression projetée : g."ID_Generique".';

--
-- Name: COLUMN "V_Generique"."NomGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."NomGenerique" IS 'Libellé métier de la valeur de nomenclature. Expression projetée : g."NomGenerique".';

--
-- Name: COLUMN "V_Generique"."AbrGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."AbrGenerique" IS 'Abréviation de la valeur de nomenclature ; peut porter un code de type utilisé par les règles métier. Expression projetée : g."AbrGenerique".';

--
-- Name: COLUMN "V_Generique"."VisibleNiveau_2"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_2" IS 'Indicateur de visibilité pour le niveau géographique de niveau 2. Expression projetée : g."VisibleNiveau_2".';

--
-- Name: COLUMN "V_Generique"."VisibleNiveau_3"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_3" IS 'Indicateur de visibilité pour le niveau géographique de niveau 3. Expression projetée : g."VisibleNiveau_3".';

--
-- Name: COLUMN "V_Generique"."VisibleNiveau_4"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_4" IS 'Indicateur de visibilité pour le niveau géographique de niveau 4. Expression projetée : g."VisibleNiveau_4".';

--
-- Name: COLUMN "V_Generique"."VisibleNiveau_5"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5. Expression projetée : g."VisibleNiveau_5".';

--
-- Name: COLUMN "V_Generique"."VisibleArticle"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleArticle" IS 'Indique la visibilité de la valeur de nomenclature pour les articles. Expression projetée : g."VisibleArticle".';

--
-- Name: COLUMN "V_Generique"."VisibleCmd"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleCmd" IS 'Indique la visibilité de la valeur de nomenclature pour les commandes. Expression projetée : g."VisibleCmd".';

--
-- Name: COLUMN "V_Generique"."VisibleFacture"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleFacture" IS 'Indique la visibilité de la valeur de nomenclature pour les factures. Expression projetée : g."VisibleFacture".';

--
-- Name: COLUMN "V_Generique"."VisibleUsers"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleUsers" IS 'Indique la visibilité de la valeur de nomenclature pour les utilisateurs. Expression projetée : g."VisibleUsers".';

--
-- Name: COLUMN "V_Generique"."VisibleVoie"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleVoie" IS 'Indique la visibilité de la valeur de nomenclature pour les voies d’accès. Expression projetée : g."VisibleVoie".';

--
-- Name: COLUMN "V_Generique"."VisibleAll"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."VisibleAll" IS 'Indique la visibilité générale de la valeur de nomenclature. Expression projetée : g."VisibleAll".';

--
-- Name: COLUMN "V_Generique"."ObsGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ObsGenerique" IS 'Observations enregistrées sur la valeur de nomenclature. Expression projetée : g."ObsGenerique".';

--
-- Name: COLUMN "V_Generique"."ValideGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."ValideGenerique" IS 'Indique si la valeur de nomenclature est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues. Expression projetée : g."ValideGenerique".';
