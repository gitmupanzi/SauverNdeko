-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_CategorieGenerique; Type: VIEW; Schema: referentiel; Owner: -
--

CREATE VIEW referentiel."V_CategorieGenerique" AS
 SELECT c."ID_CategorieGenerique",
    c."NomCategorieGenerique",
    c."ModuleCategorieGenerique",
    c."ValideCategorieGenerique",
    c."IdEntiteFk",
    e."NomEntite",
        CASE
            WHEN (c."IdEntiteFk" IS NULL) THEN 'Commun'::text
            ELSE 'Entreprise'::text
        END AS "Portee"
   FROM (referentiel."T_CategorieGenerique" c
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = c."IdEntiteFk")))
  ORDER BY c."NomCategorieGenerique", c."ModuleCategorieGenerique";

--
-- Name: VIEW "V_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_CategorieGenerique" IS 'Registre transversal des catégories, avec propriétaire et portée explicites. L’API limite les lignes au commun et à l’entreprise autorisée ; aucun nom ne sert de clé.';

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
-- Name: COLUMN "V_CategorieGenerique"."IdEntiteFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."IdEntiteFk" IS 'Propriétaire de la famille, NULL commun.';

--
-- Name: COLUMN "V_CategorieGenerique"."NomEntite"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."NomEntite" IS 'Nom actuel de l’entreprise propriétaire, absent pour le commun.';

--
-- Name: COLUMN "V_CategorieGenerique"."Portee"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_CategorieGenerique"."Portee" IS 'Portée lisible calculée depuis la FK propriétaire.';

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
    g."ValideGenerique",
    g."IdEntiteFk",
    e."NomEntite",
        CASE
            WHEN (g."IdEntiteFk" IS NULL) THEN 'Commun'::text
            ELSE 'Entreprise'::text
        END AS "Portee",
    c."IdEntiteFk" AS "IdEntiteCategorieFk"
   FROM ((referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c ON ((c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = g."IdEntiteFk")))
  ORDER BY c."NomCategorieGenerique", g."NomGenerique", g."AbrGenerique";

--
-- Name: VIEW "V_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_Generique" IS 'Valeurs, catégories et visibilités inchangées, avec portée durable et propriétaire de la famille pour les contrôles de lecture/export ; aucun filtre implicite de validité.';

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

--
-- Name: COLUMN "V_Generique"."IdEntiteFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."IdEntiteFk" IS 'Propriétaire de la valeur, NULL commun.';

--
-- Name: COLUMN "V_Generique"."NomEntite"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."NomEntite" IS 'Nom actuel du propriétaire de la valeur, absent pour le commun.';

--
-- Name: COLUMN "V_Generique"."Portee"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."Portee" IS 'Portée calculée depuis le propriétaire de la valeur.';

--
-- Name: COLUMN "V_Generique"."IdEntiteCategorieFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_Generique"."IdEntiteCategorieFk" IS 'Propriétaire de la famille pour vérifier que toute valeur privée est dans le même contexte.';

--
-- Name: V_InterfaceTableau; Type: VIEW; Schema: referentiel; Owner: -
--

CREATE VIEW referentiel."V_InterfaceTableau" AS
 SELECT "CleInterface",
    replace(replace("CleInterface", '.'::text, ' · '::text), '_'::text, ' '::text) AS "Libelle",
    "Module",
    "Version",
    "Colonnes",
    "Actif",
    "ModifieLe",
    jsonb_array_length("Colonnes") AS "NbColonnes"
   FROM referentiel."T_InterfaceTableau" i;

--
-- Name: VIEW "V_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_InterfaceTableau" IS 'Catalogue réel des interfaces de tableaux et exports, en consultation. Libellé lisible dérivé de la clé, colonnes structurées et nombre calculé ; les préférences personnelles utilisent leur service existant.';

--
-- Name: COLUMN "V_InterfaceTableau"."CleInterface"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."CleInterface" IS 'Clé stable du catalogue PostgreSQL et des services de préférences.';

--
-- Name: COLUMN "V_InterfaceTableau"."Libelle"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."Libelle" IS 'Libellé de lecture dérivé de la clé, sans deuxième définition persistée.';

--
-- Name: COLUMN "V_InterfaceTableau"."Module"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."Module" IS 'Application propriétaire déclarée par le catalogue réel.';

--
-- Name: COLUMN "V_InterfaceTableau"."Version"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."Version" IS 'Version effective de la définition des colonnes.';

--
-- Name: COLUMN "V_InterfaceTableau"."Colonnes"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."Colonnes" IS 'Définitions JSON validées des colonnes, de leurs usages et de leur ordre par défaut.';

--
-- Name: COLUMN "V_InterfaceTableau"."Actif"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."Actif" IS 'Disponibilité de cette interface dans le catalogue.';

--
-- Name: COLUMN "V_InterfaceTableau"."ModifieLe"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."ModifieLe" IS 'Horodatage du dernier changement de définition.';

--
-- Name: COLUMN "V_InterfaceTableau"."NbColonnes"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_InterfaceTableau"."NbColonnes" IS 'Nombre de définitions de colonnes calculé depuis le JSON.';

--
-- Name: V_ReferencementChamp; Type: VIEW; Schema: referentiel; Owner: -
--

CREATE VIEW referentiel."V_ReferencementChamp" AS
 SELECT c."ID_ChampReferentiel",
    c."SchemaName",
    c."TableName",
    c."ColumnName",
    c."ChampLabel",
    c."ModuleName",
    c."ID_CategorieDefautFk",
    c."AliasSourceKeys",
    c."CanConfigure",
    c."SupportsEntityScope",
    c."Revision",
    c."CreeLe",
    c."ModifieLe",
    c."ModifieParUserFk",
    s."CategoryIds",
    ARRAY( SELECT x."NomCategorieGenerique"
           FROM (unnest(s."CategoryIds") WITH ORDINALITY a(id, ord)
             JOIN referentiel."T_CategorieGenerique" x ON ((x."ID_CategorieGenerique" = a.id)))
          ORDER BY a.ord) AS "CategoryLabels",
    array_to_string(ARRAY( SELECT x."NomCategorieGenerique"
           FROM (unnest(s."CategoryIds") WITH ORDINALITY a(id, ord)
             JOIN referentiel."T_CategorieGenerique" x ON ((x."ID_CategorieGenerique" = a.id)))
          ORDER BY a.ord), ', '::text) AS "CategoriesActuelles",
    d."NomCategorieGenerique" AS "CategorieDefaut",
    c."ID_CategorieDefautFk" AS "DefaultCategoryId",
    s."OrigineReglage",
    (c."Revision")::text AS _version,
    (((c."SchemaName")::text = 'logistique'::text) AND ((((c."TableName")::text = ANY ((ARRAY['T_Mouvement'::character varying, 'T_Facture'::character varying, 'T_Avoir'::character varying, 'T_Reglements'::character varying, 'T_ValorisationOuverture'::character varying])::text[])) AND ((c."ColumnName")::text = 'ID_DeviseFk'::text)) OR (((c."TableName")::text = 'T_Mouvement'::text) AND ((c."ColumnName")::text = 'ID_TypeMvtFk'::text)) OR (((c."TableName")::text = 'T_Facture'::text) AND ((c."ColumnName")::text = ANY ((ARRAY['ID_ModePaiementFk'::character varying, 'ID_ConditionPaiementFk'::character varying])::text[]))))) AS "ReferenceHeriteeParent"
   FROM ((referentiel."T_ChampReferentiel" c
     LEFT JOIN referentiel."T_CategorieGenerique" d ON ((d."ID_CategorieGenerique" = c."ID_CategorieDefautFk")))
     CROSS JOIN LATERAL referentiel.fn_resolution_champ((c."SchemaName")::text, (c."TableName")::text, (c."ColumnName")::text, NULL::integer) s("CategoryIds", "OrigineReglage"));

--
-- Name: VIEW "V_ReferencementChamp"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON VIEW referentiel."V_ReferencementChamp" IS 'Registre des 60 champs physiques, familles globales effectives et défauts prouvés ; pour un contexte entreprise utiliser le même résolveur avec son identifiant autorisé.';

--
-- Name: COLUMN "V_ReferencementChamp"."ID_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ID_ChampReferentiel" IS 'Projection de référencement : ID_ChampReferentiel. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."SchemaName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."SchemaName" IS 'Projection de référencement : SchemaName. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."TableName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."TableName" IS 'Projection de référencement : TableName. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."ColumnName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ColumnName" IS 'Projection de référencement : ColumnName. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."ChampLabel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ChampLabel" IS 'Projection de référencement : ChampLabel. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."ModuleName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ModuleName" IS 'Projection de référencement : ModuleName. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."ID_CategorieDefautFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ID_CategorieDefautFk" IS 'Projection de référencement : ID_CategorieDefautFk. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."AliasSourceKeys"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."AliasSourceKeys" IS 'Projection de référencement : AliasSourceKeys. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."CanConfigure"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."CanConfigure" IS 'Projection de référencement : CanConfigure. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."SupportsEntityScope"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."SupportsEntityScope" IS 'Projection de référencement : SupportsEntityScope. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."Revision"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."Revision" IS 'Projection de référencement : Revision. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."CreeLe"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."CreeLe" IS 'Projection de référencement : CreeLe. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."ModifieLe"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ModifieLe" IS 'Projection de référencement : ModifieLe. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."ModifieParUserFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ModifieParUserFk" IS 'Projection de référencement : ModifieParUserFk. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."CategoryIds"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."CategoryIds" IS 'Projection de référencement : CategoryIds. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."CategoryLabels"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."CategoryLabels" IS 'Projection de référencement : CategoryLabels. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."CategoriesActuelles"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."CategoriesActuelles" IS 'Projection de référencement : CategoriesActuelles. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."CategorieDefaut"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."CategorieDefaut" IS 'Projection de référencement : CategorieDefaut. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."DefaultCategoryId"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."DefaultCategoryId" IS 'Projection de référencement : DefaultCategoryId. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."OrigineReglage"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."OrigineReglage" IS 'Projection de référencement : OrigineReglage. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"._version; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"._version IS 'Projection de référencement : _version. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';

--
-- Name: COLUMN "V_ReferencementChamp"."ReferenceHeriteeParent"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."V_ReferencementChamp"."ReferenceHeriteeParent" IS 'Projection de référencement : ReferenceHeriteeParent. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.';
