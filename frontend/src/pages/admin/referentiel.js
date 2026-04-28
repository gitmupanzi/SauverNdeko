import {
  createAdminModelRecord,
  deleteAdminModelRecord,
  fetchAdminModelItem,
  updateAdminModelRecord,
} from "../../services/api";

const SCHEMA_NAME = "referentiel";

const REFERENTIEL_VIEWS = [
  {
    schema: SCHEMA_NAME,
    name: "V_CategorieGenerique",
    title: "Categories generiques",
    description: "Permet de consulter et gerer les categories du referentiel.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Generique",
    title: "Referentiel generique",
    description: "Permet de consulter les categories et valeurs du referentiel.",
  },
];

const CATEGORY_FIELDS = [
  { name: "NomCategorieGenerique", label: "Nom categorie", type: "text", required: true, initialValue: "" },
  { name: "ModuleCategorieGenerique", label: "Module", type: "textarea", initialValue: "" },
  { name: "ValideCategorieGenerique", label: "Categorie active", type: "checkbox", initialValue: true },
];

const GENERIC_FIELDS = [
  {
    name: "ID_CategorieGeneriqueFk",
    label: "Categorie",
    type: "select",
    optionsSource: "categories",
    required: true,
    initialValue: "",
  },
  { name: "NomGenerique", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "AbrGenerique", label: "Abreviation", type: "text", initialValue: "" },
  { name: "ObsGenerique", label: "Observation", type: "textarea", initialValue: "" },
  { name: "ValideGenerique", label: "Valeur active", type: "checkbox", initialValue: true },
  { name: "VisibleNiveau_2", label: "Visible niveau 2", type: "checkbox", initialValue: true },
  { name: "VisibleNiveau_3", label: "Visible niveau 3", type: "checkbox", initialValue: true },
  { name: "VisibleNiveau_4", label: "Visible niveau 4", type: "checkbox", initialValue: true },
  { name: "VisibleNiveau_5", label: "Visible niveau 5", type: "checkbox", initialValue: true },
  { name: "VisibleArticle", label: "Visible article", type: "checkbox", initialValue: true },
  { name: "VisibleCmd", label: "Visible commande", type: "checkbox", initialValue: true },
  { name: "VisibleFacture", label: "Visible facture", type: "checkbox", initialValue: true },
  { name: "VisibleUsers", label: "Visible utilisateurs", type: "checkbox", initialValue: true },
  { name: "VisibleVoie", label: "Visible voie", type: "checkbox", initialValue: true },
  { name: "VisibleAll", label: "Visible partout", type: "checkbox", initialValue: true },
];

function normalizeViewKey(schema, name) {
  return `${schema}.${name}`;
}

const REFERENTIEL_CRUD_CONFIGS = {
  [normalizeViewKey(SCHEMA_NAME, "V_CategorieGenerique")]: {
    primaryKey: "ID_CategorieGenerique",
    resourceLabel: "categorie de referentiel",
    createLabel: "Nouvelle categorie",
    allFields: CATEGORY_FIELDS,
    fields: CATEGORY_FIELDS,
    fetchRecord: (_row, id) => fetchAdminModelItem("T_CategorieGenerique", id),
    createRecord: (payload) => createAdminModelRecord("T_CategorieGenerique", payload),
    updateRecord: (id, payload) => updateAdminModelRecord("T_CategorieGenerique", id, payload),
    deleteRecord: (id) => deleteAdminModelRecord("T_CategorieGenerique", id),
    mapRecord: (record) => ({
      NomCategorieGenerique: record?.NomCategorieGenerique || "",
      ModuleCategorieGenerique: record?.ModuleCategorieGenerique || "",
      ValideCategorieGenerique: record?.ValideCategorieGenerique !== false,
    }),
    buildPayload: (values) => ({
      NomCategorieGenerique: values.NomCategorieGenerique.trim(),
      ModuleCategorieGenerique: values.ModuleCategorieGenerique.trim() || null,
      ValideCategorieGenerique: Boolean(values.ValideCategorieGenerique),
    }),
  },
  [normalizeViewKey(SCHEMA_NAME, "V_Generique")]: {
    primaryKey: "ID_Generique",
    resourceLabel: "valeur de referentiel",
    createLabel: "Nouvelle valeur",
    allFields: GENERIC_FIELDS,
    fields: GENERIC_FIELDS,
    fetchRecord: (_row, id) => fetchAdminModelItem("T_Generique", id),
    createRecord: (payload) => createAdminModelRecord("T_Generique", payload),
    updateRecord: (id, payload) => updateAdminModelRecord("T_Generique", id, payload),
    deleteRecord: (id) => deleteAdminModelRecord("T_Generique", id),
    mapRecord: (record) => ({
      ID_CategorieGeneriqueFk: record?.ID_CategorieGeneriqueFk ? String(record.ID_CategorieGeneriqueFk) : "",
      NomGenerique: record?.NomGenerique || "",
      AbrGenerique: record?.AbrGenerique || "",
      ObsGenerique: record?.ObsGenerique || "",
      ValideGenerique: record?.ValideGenerique !== false,
      VisibleNiveau_2: record?.VisibleNiveau_2 !== false,
      VisibleNiveau_3: record?.VisibleNiveau_3 !== false,
      VisibleNiveau_4: record?.VisibleNiveau_4 !== false,
      VisibleNiveau_5: record?.VisibleNiveau_5 !== false,
      VisibleArticle: record?.VisibleArticle !== false,
      VisibleCmd: record?.VisibleCmd !== false,
      VisibleFacture: record?.VisibleFacture !== false,
      VisibleUsers: record?.VisibleUsers !== false,
      VisibleVoie: record?.VisibleVoie !== false,
      VisibleAll: record?.VisibleAll !== false,
    }),
    buildPayload: (values) => ({
      ID_CategorieGeneriqueFk: Number(values.ID_CategorieGeneriqueFk),
      NomGenerique: values.NomGenerique.trim(),
      AbrGenerique: values.AbrGenerique.trim() || null,
      ObsGenerique: values.ObsGenerique.trim() || null,
      ValideGenerique: Boolean(values.ValideGenerique),
      VisibleNiveau_2: Boolean(values.VisibleNiveau_2),
      VisibleNiveau_3: Boolean(values.VisibleNiveau_3),
      VisibleNiveau_4: Boolean(values.VisibleNiveau_4),
      VisibleNiveau_5: Boolean(values.VisibleNiveau_5),
      VisibleArticle: Boolean(values.VisibleArticle),
      VisibleCmd: Boolean(values.VisibleCmd),
      VisibleFacture: Boolean(values.VisibleFacture),
      VisibleUsers: Boolean(values.VisibleUsers),
      VisibleVoie: Boolean(values.VisibleVoie),
      VisibleAll: Boolean(values.VisibleAll),
    }),
  },
};

export const REFERENTIEL_ADMIN_SCHEMA = {
  schema: SCHEMA_NAME,
  title: "Schema referentiel",
  views: REFERENTIEL_VIEWS,
  crudConfigs: REFERENTIEL_CRUD_CONFIGS,
};
