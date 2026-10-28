import {
  createAdminModelRecord,
  deleteAdminModelRecord,
  fetchAdminModelItem,
  updateAdminModelRecord,
} from "../../services/api";

const SCHEMA_NAME = "geolocalisation";

const GEOLOCALISATION_VIEWS = [
  {
    schema: SCHEMA_NAME,
    name: "V_AS_sans_Site",
    title: "AS sans site",
    description: "Controle qualite des Aires de Sante sans structure ou site associe.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Niveau_0",
    title: "Niveau 0",
    description: "Reference du niveau 0 avec nom, code et geometrie.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Niveau_1_Old",
    title: "Niveau 1 historique",
    description: "Reference historique des anciens niveaux 1 utilises comme rattachement.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Niveau_1",
    title: "Niveau 1",
    description: "Reference des Provinces ou DPS avec codes, population, coordonnees et visibilite.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Niveau_2",
    title: "Niveau 2",
    description: "Reference du Niveau 2 avec type, statut, deploiement, voie d'acces et geometrie.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Niveau_3",
    title: "Niveau 3",
    description: "Reference des Zones de Sante avec statuts, distances, voies d'acces et geometrie.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Niveau_4",
    title: "Niveau 4",
    description: "Reference des Aires de Sante avec hierarchie complete, type, reseau et statut.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Niveau_5",
    title: "Niveau 5",
    description: "Reference des structures ou sites avec hierarchie, type, reseau, statut et geometrie.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Pop_N3_Couverte_Sites",
    title: "Population couverte N3",
    description: "Indicateur de population cumulee des sites par Zone de Sante et type de structure.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_RESEAU_AS_par_ZS",
    title: "Reseau AS par ZS",
    description: "Indicateur de connectivite des Aires de Sante par Zone de Sante.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Stats_N1_N2",
    title: "Stats N1 N2",
    description: "Indicateurs structurels du Niveau 2 par Province ou DPS et par type.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Stats_N3_Structures",
    title: "Stats N3 Structures",
    description: "Indicateurs par Zone de Sante sur les Aires de Sante et les structures par type.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_ZS_sans_AS",
    title: "ZS sans AS",
    description: "Controle qualite des Zones de Sante sans aucune Aire de Sante associee.",
  },
];

const NIVEAU_0_FIELDS = [
  { name: "NomNiveau_0", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "CodeNiveau_0", label: "Code", type: "text", initialValue: "" },
  { name: "geometryNiveau_0", label: "Geometrie", type: "textarea", initialValue: "" },
];

const NIVEAU_1_OLD_FIELDS = [
  { name: "NomNiveau_1_Old", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "surfaceNiveau_1_Old", label: "Surface", type: "text", initialValue: "" },
  { name: "geometryNiveau_1_Old", label: "Geometrie", type: "textarea", initialValue: "" },
];

const NIVEAU_1_FIELDS = [
  { name: "ID_Niveau_0_Fk", label: "Niveau 0 parent", type: "select", optionsSource: "niveaux0", required: true, initialValue: "" },
  { name: "ID_Niveau_1_Old_Fk", label: "Ancien niveau 1", type: "select", optionsSource: "niveaux1Old", initialValue: "" },
  { name: "NomNiveau_1", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "Alt1_Niveau_1", label: "Alias 1", type: "text", initialValue: "" },
  { name: "Alt2_Niveau_1", label: "Alias 2", type: "text", initialValue: "" },
  { name: "AbreNiveau_1", label: "Abreviation", type: "text", initialValue: "" },
  { name: "CodeSNIS", label: "Code SNIS", type: "text", initialValue: "" },
  { name: "CodeNiveau_1", label: "Code", type: "text", initialValue: "" },
  { name: "PopulationNiveau_1", label: "Population", type: "number", initialValue: "", step: "1", min: "0" },
  { name: "LatitudeNiveau_1", label: "Latitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "LongitudeNiveau_1", label: "Longitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "surfaceNiveau_1", label: "Surface", type: "text", initialValue: "" },
  { name: "geometryNiveau_1", label: "Geometrie", type: "textarea", initialValue: "" },
  { name: "EtenduNiveau_1", label: "Etendue", type: "textarea", initialValue: "" },
  { name: "timezoneNiveau_1", label: "Timezone", type: "text", initialValue: "" },
  { name: "wikidataNiveau_1", label: "Wikidata", type: "text", initialValue: "" },
  { name: "FusionNiveau_1", label: "Fusion active", type: "checkbox", initialValue: false },
  { name: "VisibleNiveau_1", label: "Visible niveau 1", type: "checkbox", initialValue: true },
  { name: "VisibleNiveau_5", label: "Visible niveau 5", type: "checkbox", initialValue: true },
  { name: "ObsNiveau_1", label: "Observation", type: "textarea", initialValue: "" },
];

const NIVEAU_2_FIELDS = [
  { name: "ID_Niveau_1_FK", label: "Niveau 1 parent", type: "select", optionsSource: "niveaux1", required: true, initialValue: "" },
  { name: "ID_TypeNiveau_2_Fk", label: "Type", type: "select", optionsSource: "niveau2Types", initialValue: "" },
  { name: "NomNiveau_2", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "Alt1_NomNiveau_2", label: "Alias", type: "text", initialValue: "" },
  { name: "AbreNiveau_2", label: "Abreviation", type: "text", initialValue: "" },
  { name: "CodeNiveau_2", label: "Code", type: "text", initialValue: "" },
  { name: "PopulationNiveau_2", label: "Population", type: "number", initialValue: "", step: "1", min: "0" },
  { name: "LatitudeNiveau_2", label: "Latitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "LongitudeNiveau_2", label: "Longitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "AltitudeNiveau_2", label: "Altitude", type: "number", initialValue: "", step: "0.01" },
  { name: "surfaceNiveau_2", label: "Surface", type: "text", initialValue: "" },
  { name: "geometryNiveau_2", label: "Geometrie", type: "textarea", initialValue: "" },
  { name: "EtenduNiveau_2", label: "Etendue", type: "textarea", initialValue: "" },
  { name: "ObsNiveau_2", label: "Observation", type: "textarea", initialValue: "" },
  { name: "ID_StatutNiveau_2", label: "Statut", type: "select", optionsSource: "niveau2Statuses", initialValue: "" },
  { name: "ID_StatusDeploiFk", label: "Statut deploiement", type: "select", optionsSource: "deploymentStatuses", initialValue: "" },
  { name: "KmDPSANT", label: "Distance DPS", type: "number", initialValue: "", step: "0.01", min: "0" },
  { name: "ID_VoieAccesDPSANTFk", label: "Voie acces DPS", type: "select", optionsSource: "dpsAccessRoutes", initialValue: "" },
  { name: "SelectNiveau_2", label: "Selection active", type: "checkbox", initialValue: false },
];

const NIVEAU_3_FIELDS = [
  { name: "ID_Niveau_2_FK", label: "Niveau 2 parent", type: "select", optionsSource: "niveaux2", required: true, initialValue: "" },
  { name: "ID_TypeNiveau_2_Fk", label: "Type", type: "select", optionsSource: "niveau3Types", initialValue: "" },
  { name: "NomNiveau_3", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "Alt_Niveau_3", label: "Alias", type: "text", initialValue: "" },
  { name: "AbreNiveau_3", label: "Abreviation", type: "text", initialValue: "" },
  { name: "CodeNiveau_3", label: "Code", type: "text", initialValue: "" },
  { name: "PopulationNiveau_3", label: "Population", type: "number", initialValue: "", step: "1", min: "0" },
  { name: "LatitudeNiveau_3", label: "Latitude", type: "number", initialValue: "", step: "0.00001" },
  { name: "LongitudeNiveau_3", label: "Longitude", type: "number", initialValue: "", step: "0.00001" },
  { name: "AltitudeNiveau_3", label: "Altitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "surfaceNiveau_3", label: "Surface", type: "text", initialValue: "" },
  { name: "geometryNiveau_3", label: "Geometrie", type: "textarea", initialValue: "" },
  { name: "EtenduNiveau_3", label: "Etendue", type: "textarea", initialValue: "" },
  { name: "ObsNiveau_3", label: "Observation", type: "textarea", initialValue: "" },
  { name: "ID_StatutNiveau_3_Fk", label: "Statut", type: "select", optionsSource: "niveau3Statuses", initialValue: "" },
  { name: "ID_StatutDeploieFk", label: "Statut deploiement", type: "select", optionsSource: "deploymentStatuses", initialValue: "" },
  { name: "KmAntenneBCZS", label: "Distance antenne BCZS", type: "number", initialValue: "", step: "0.01", min: "0" },
  { name: "ID_VoieAccesANTBCZFk", label: "Voie acces antenne BCZS", type: "select", optionsSource: "antBczAccessRoutes", initialValue: "" },
  { name: "KmDPSBCZS", label: "Distance DPS", type: "number", initialValue: "", step: "0.01", min: "0" },
  { name: "ID_VoieAccesDPSBCZFk", label: "Voie acces DPS", type: "select", optionsSource: "dpsBczAccessRoutes", initialValue: "" },
  { name: "SelectNiveau_3", label: "Selection active", type: "checkbox", initialValue: false },
];

const NIVEAU_4_FIELDS = [
  { name: "ID_Niveau_3_Fk", label: "Niveau 3 parent", type: "select", optionsSource: "niveaux3", required: true, initialValue: "" },
  { name: "ID_TypeNiveau_4_Fk", label: "Type", type: "select", optionsSource: "niveau4Types", initialValue: "" },
  { name: "NomNiveau_4", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "AbreNiveau_4", label: "Abreviation", type: "text", initialValue: "" },
  { name: "CodeNiveau_4", label: "Code", type: "text", initialValue: "" },
  { name: "PopulationNiveau_4", label: "Population", type: "number", initialValue: "", step: "1", min: "0" },
  { name: "LatitudeNiveau_4", label: "Latitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "LongitudeNiveau_4", label: "Longitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "AltitudeNiveau_4", label: "Altitude", type: "number", initialValue: "", step: "0.01" },
  { name: "KmZoneSanteAS", label: "Distance zone de sante", type: "number", initialValue: "", step: "0.01", min: "0" },
  { name: "surfaceNiveau_4", label: "Surface", type: "text", initialValue: "" },
  { name: "geometryNiveau_4", label: "Geometrie", type: "textarea", initialValue: "" },
  { name: "ID_DispoReseauNiveau_4", label: "Disponibilite reseau", type: "select", optionsSource: "networkAvailabilities", initialValue: "" },
  { name: "ID_VoieAccesZsASFk", label: "Voie acces ZS-AS", type: "select", optionsSource: "zsAsAccessRoutes", initialValue: "" },
  { name: "ID_StatutNiveau_4", label: "Statut", type: "select", optionsSource: "niveau4Statuses", initialValue: "" },
  { name: "ID_StatutDeploiementFk", label: "Statut deploiement", type: "select", optionsSource: "deploymentStatuses", initialValue: "" },
  { name: "SelectNiveau_4", label: "Selection active", type: "checkbox", initialValue: false },
  { name: "ObsNiveau_4", label: "Observation", type: "textarea", initialValue: "" },
];

const NIVEAU_5_FIELDS = [
  { name: "ID_Niveau_4_Fk", label: "Niveau 4 parent", type: "select", optionsSource: "niveaux4", required: true, initialValue: "" },
  { name: "ID_Niveau_3_Fk", label: "Niveau 3 parent", type: "select", optionsSource: "niveaux3", initialValue: "" },
  { name: "ID_TypeNiveau_5_Fk", label: "Type", type: "select", optionsSource: "niveau5Types", initialValue: "" },
  { name: "NomNiveau_5", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "AbreNiveau_5", label: "Abreviation", type: "text", initialValue: "" },
  { name: "CodeNiveau_5", label: "Code", type: "text", initialValue: "" },
  { name: "PopulationNiveau_5", label: "Population", type: "number", initialValue: "", step: "1", min: "0" },
  { name: "LatitudeNiveau_5", label: "Latitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "LongitudeNiveau_5", label: "Longitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "AltitudeNiveau_5", label: "Altitude", type: "number", initialValue: "", step: "0.01" },
  { name: "KmZoneSanteNiveau_5", label: "Distance zone de sante", type: "number", initialValue: "", step: "0.01", min: "0" },
  { name: "surfaceNiveau_5", label: "Surface", type: "text", initialValue: "" },
  { name: "geometryNiveau_5", label: "Geometrie", type: "textarea", initialValue: "" },
  { name: "ID_DispoReseauNiveau_5", label: "Disponibilite reseau", type: "select", optionsSource: "networkAvailabilities", initialValue: "" },
  { name: "ID_VoieAccesZsSiteFk", label: "Voie acces ZS-Site", type: "select", optionsSource: "zsSiteAccessRoutes", initialValue: "" },
  { name: "ID_StatutNiveau_5", label: "Statut", type: "select", optionsSource: "niveau5Statuses", initialValue: "" },
  { name: "ID_StatutDeploiementFk", label: "Statut deploiement", type: "select", optionsSource: "deploymentStatuses", initialValue: "" },
  { name: "ID_TypeToitFk", label: "Type de toit", type: "select", optionsSource: "roofTypes", initialValue: "" },
  { name: "SelectNiveau_5", label: "Selection active", type: "checkbox", initialValue: false },
  { name: "ObsNiveau_5", label: "Observation", type: "textarea", initialValue: "" },
];

function normalizeViewKey(schema, name) {
  return `${schema}.${name}`;
}

function toOptionalNumber(value) {
  if (value === "" || value == null) {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function toOptionalString(value) {
  const normalized = String(value ?? "").trim();
  return normalized || null;
}

function stringifyNullableValue(value) {
  return value == null ? "" : String(value);
}

function createCrudConfig({ viewName, model, primaryKey, resourceLabel, createLabel, fields, buildPayload, mapRecord }) {
  return {
    model,
    primaryKey,
    resourceLabel,
    createLabel,
    allFields: fields,
    fields,
    fetchRecord: (_row, id) => fetchAdminModelItem(model, id),
    createRecord: (payload) => createAdminModelRecord(model, payload),
    updateRecord: (id, payload) => updateAdminModelRecord(model, id, payload),
    deleteRecord: (id) => deleteAdminModelRecord(model, id),
    mapRecord,
    buildPayload,
  };
}

function buildNiveau0Payload(values) {
  return {
    NomNiveau_0: toOptionalString(values.NomNiveau_0),
    CodeNiveau_0: toOptionalString(values.CodeNiveau_0),
    geometryNiveau_0: toOptionalString(values.geometryNiveau_0),
  };
}

function buildNiveau1OldPayload(values) {
  return {
    NomNiveau_1_Old: toOptionalString(values.NomNiveau_1_Old),
    surfaceNiveau_1_Old: toOptionalString(values.surfaceNiveau_1_Old),
    geometryNiveau_1_Old: toOptionalString(values.geometryNiveau_1_Old),
  };
}

function buildNiveau1Payload(values) {
  return {
    ID_Niveau_0_Fk: toOptionalNumber(values.ID_Niveau_0_Fk),
    ID_Niveau_1_Old_Fk: toOptionalNumber(values.ID_Niveau_1_Old_Fk),
    NomNiveau_1: toOptionalString(values.NomNiveau_1),
    Alt1_Niveau_1: toOptionalString(values.Alt1_Niveau_1),
    Alt2_Niveau_1: toOptionalString(values.Alt2_Niveau_1),
    AbreNiveau_1: toOptionalString(values.AbreNiveau_1),
    CodeSNIS: toOptionalString(values.CodeSNIS),
    CodeNiveau_1: toOptionalString(values.CodeNiveau_1),
    PopulationNiveau_1: toOptionalNumber(values.PopulationNiveau_1),
    LatitudeNiveau_1: toOptionalNumber(values.LatitudeNiveau_1),
    LongitudeNiveau_1: toOptionalNumber(values.LongitudeNiveau_1),
    surfaceNiveau_1: toOptionalString(values.surfaceNiveau_1),
    geometryNiveau_1: toOptionalString(values.geometryNiveau_1),
    EtenduNiveau_1: toOptionalString(values.EtenduNiveau_1),
    timezoneNiveau_1: toOptionalString(values.timezoneNiveau_1),
    wikidataNiveau_1: toOptionalString(values.wikidataNiveau_1),
    FusionNiveau_1: Boolean(values.FusionNiveau_1),
    VisibleNiveau_1: Boolean(values.VisibleNiveau_1),
    VisibleNiveau_5: Boolean(values.VisibleNiveau_5),
    ObsNiveau_1: toOptionalString(values.ObsNiveau_1),
  };
}

function buildNiveau2Payload(values) {
  return {
    ID_Niveau_1_FK: toOptionalNumber(values.ID_Niveau_1_FK),
    ID_TypeNiveau_2_Fk: toOptionalNumber(values.ID_TypeNiveau_2_Fk),
    NomNiveau_2: toOptionalString(values.NomNiveau_2),
    Alt1_NomNiveau_2: toOptionalString(values.Alt1_NomNiveau_2),
    AbreNiveau_2: toOptionalString(values.AbreNiveau_2),
    CodeNiveau_2: toOptionalString(values.CodeNiveau_2),
    PopulationNiveau_2: toOptionalNumber(values.PopulationNiveau_2),
    LatitudeNiveau_2: toOptionalNumber(values.LatitudeNiveau_2),
    LongitudeNiveau_2: toOptionalNumber(values.LongitudeNiveau_2),
    AltitudeNiveau_2: toOptionalNumber(values.AltitudeNiveau_2),
    surfaceNiveau_2: toOptionalString(values.surfaceNiveau_2),
    geometryNiveau_2: toOptionalString(values.geometryNiveau_2),
    EtenduNiveau_2: toOptionalString(values.EtenduNiveau_2),
    ObsNiveau_2: toOptionalString(values.ObsNiveau_2),
    ID_StatutNiveau_2: toOptionalNumber(values.ID_StatutNiveau_2),
    ID_StatusDeploiFk: toOptionalNumber(values.ID_StatusDeploiFk),
    KmDPSANT: toOptionalNumber(values.KmDPSANT),
    ID_VoieAccesDPSANTFk: toOptionalNumber(values.ID_VoieAccesDPSANTFk),
    SelectNiveau_2: Boolean(values.SelectNiveau_2),
  };
}

function buildNiveau3Payload(values) {
  return {
    ID_Niveau_2_FK: toOptionalNumber(values.ID_Niveau_2_FK),
    ID_TypeNiveau_2_Fk: toOptionalNumber(values.ID_TypeNiveau_2_Fk),
    NomNiveau_3: toOptionalString(values.NomNiveau_3),
    Alt_Niveau_3: toOptionalString(values.Alt_Niveau_3),
    AbreNiveau_3: toOptionalString(values.AbreNiveau_3),
    CodeNiveau_3: toOptionalString(values.CodeNiveau_3),
    PopulationNiveau_3: toOptionalNumber(values.PopulationNiveau_3),
    LatitudeNiveau_3: toOptionalNumber(values.LatitudeNiveau_3),
    LongitudeNiveau_3: toOptionalNumber(values.LongitudeNiveau_3),
    AltitudeNiveau_3: toOptionalNumber(values.AltitudeNiveau_3),
    surfaceNiveau_3: toOptionalString(values.surfaceNiveau_3),
    geometryNiveau_3: toOptionalString(values.geometryNiveau_3),
    EtenduNiveau_3: toOptionalString(values.EtenduNiveau_3),
    ObsNiveau_3: toOptionalString(values.ObsNiveau_3),
    ID_StatutNiveau_3_Fk: toOptionalNumber(values.ID_StatutNiveau_3_Fk),
    ID_StatutDeploieFk: toOptionalNumber(values.ID_StatutDeploieFk),
    KmAntenneBCZS: toOptionalNumber(values.KmAntenneBCZS),
    ID_VoieAccesANTBCZFk: toOptionalNumber(values.ID_VoieAccesANTBCZFk),
    KmDPSBCZS: toOptionalNumber(values.KmDPSBCZS),
    ID_VoieAccesDPSBCZFk: toOptionalNumber(values.ID_VoieAccesDPSBCZFk),
    SelectNiveau_3: Boolean(values.SelectNiveau_3),
  };
}

function buildNiveau4Payload(values) {
  return {
    ID_Niveau_3_Fk: toOptionalNumber(values.ID_Niveau_3_Fk),
    ID_TypeNiveau_4_Fk: toOptionalNumber(values.ID_TypeNiveau_4_Fk),
    NomNiveau_4: toOptionalString(values.NomNiveau_4),
    AbreNiveau_4: toOptionalString(values.AbreNiveau_4),
    CodeNiveau_4: toOptionalString(values.CodeNiveau_4),
    PopulationNiveau_4: toOptionalNumber(values.PopulationNiveau_4),
    LatitudeNiveau_4: toOptionalNumber(values.LatitudeNiveau_4),
    LongitudeNiveau_4: toOptionalNumber(values.LongitudeNiveau_4),
    AltitudeNiveau_4: toOptionalNumber(values.AltitudeNiveau_4),
    KmZoneSanteAS: toOptionalNumber(values.KmZoneSanteAS),
    surfaceNiveau_4: toOptionalString(values.surfaceNiveau_4),
    geometryNiveau_4: toOptionalString(values.geometryNiveau_4),
    ID_DispoReseauNiveau_4: toOptionalNumber(values.ID_DispoReseauNiveau_4),
    ID_VoieAccesZsASFk: toOptionalNumber(values.ID_VoieAccesZsASFk),
    ID_StatutNiveau_4: toOptionalNumber(values.ID_StatutNiveau_4),
    ID_StatutDeploiementFk: toOptionalNumber(values.ID_StatutDeploiementFk),
    SelectNiveau_4: Boolean(values.SelectNiveau_4),
    ObsNiveau_4: toOptionalString(values.ObsNiveau_4),
  };
}

function buildNiveau5Payload(values) {
  return {
    ID_Niveau_4_Fk: toOptionalNumber(values.ID_Niveau_4_Fk),
    ID_Niveau_3_Fk: toOptionalNumber(values.ID_Niveau_3_Fk),
    ID_TypeNiveau_5_Fk: toOptionalNumber(values.ID_TypeNiveau_5_Fk),
    NomNiveau_5: toOptionalString(values.NomNiveau_5),
    AbreNiveau_5: toOptionalString(values.AbreNiveau_5),
    CodeNiveau_5: toOptionalString(values.CodeNiveau_5),
    PopulationNiveau_5: toOptionalNumber(values.PopulationNiveau_5),
    LatitudeNiveau_5: toOptionalNumber(values.LatitudeNiveau_5),
    LongitudeNiveau_5: toOptionalNumber(values.LongitudeNiveau_5),
    AltitudeNiveau_5: toOptionalNumber(values.AltitudeNiveau_5),
    KmZoneSanteNiveau_5: toOptionalNumber(values.KmZoneSanteNiveau_5),
    surfaceNiveau_5: toOptionalString(values.surfaceNiveau_5),
    geometryNiveau_5: toOptionalString(values.geometryNiveau_5),
    ID_DispoReseauNiveau_5: toOptionalNumber(values.ID_DispoReseauNiveau_5),
    ID_VoieAccesZsSiteFk: toOptionalNumber(values.ID_VoieAccesZsSiteFk),
    ID_StatutNiveau_5: toOptionalNumber(values.ID_StatutNiveau_5),
    ID_StatutDeploiementFk: toOptionalNumber(values.ID_StatutDeploiementFk),
    ID_TypeToitFk: toOptionalNumber(values.ID_TypeToitFk),
    SelectNiveau_5: Boolean(values.SelectNiveau_5),
    ObsNiveau_5: toOptionalString(values.ObsNiveau_5),
  };
}

const GEOLOCALISATION_CRUD_CONFIGS = {
  [normalizeViewKey(SCHEMA_NAME, "V_Niveau_0")]: createCrudConfig({
    viewName: "V_Niveau_0",
    model: "T_Niveau_0",
    primaryKey: "ID_Niveau_0",
    resourceLabel: "niveau 0",
    createLabel: "Nouveau niveau 0",
    fields: NIVEAU_0_FIELDS,
    buildPayload: buildNiveau0Payload,
    mapRecord: (record) => ({
      NomNiveau_0: record?.NomNiveau_0 || "",
      CodeNiveau_0: record?.CodeNiveau_0 || "",
      geometryNiveau_0: record?.geometryNiveau_0 || "",
    }),
  }),
  [normalizeViewKey(SCHEMA_NAME, "V_Niveau_1_Old")]: createCrudConfig({
    viewName: "V_Niveau_1_Old",
    model: "T_Niveau_1_Old",
    primaryKey: "ID_Niveau_1_Old",
    resourceLabel: "niveau 1 historique",
    createLabel: "Nouveau niveau 1 historique",
    fields: NIVEAU_1_OLD_FIELDS,
    buildPayload: buildNiveau1OldPayload,
    mapRecord: (record) => ({
      NomNiveau_1_Old: record?.NomNiveau_1_Old || "",
      surfaceNiveau_1_Old: record?.surfaceNiveau_1_Old || "",
      geometryNiveau_1_Old: record?.geometryNiveau_1_Old || "",
    }),
  }),
  [normalizeViewKey(SCHEMA_NAME, "V_Niveau_1")]: createCrudConfig({
    viewName: "V_Niveau_1",
    model: "T_Niveau_1",
    primaryKey: "ID_Niveau_1",
    resourceLabel: "niveau 1",
    createLabel: "Nouveau niveau 1",
    fields: NIVEAU_1_FIELDS,
    buildPayload: buildNiveau1Payload,
    mapRecord: (record) => ({
      ID_Niveau_0_Fk: stringifyNullableValue(record?.ID_Niveau_0_Fk),
      ID_Niveau_1_Old_Fk: stringifyNullableValue(record?.ID_Niveau_1_Old_Fk),
      NomNiveau_1: record?.NomNiveau_1 || "",
      Alt1_Niveau_1: record?.Alt1_Niveau_1 || "",
      Alt2_Niveau_1: record?.Alt2_Niveau_1 || "",
      AbreNiveau_1: record?.AbreNiveau_1 || "",
      CodeSNIS: record?.CodeSNIS || "",
      CodeNiveau_1: record?.CodeNiveau_1 || "",
      PopulationNiveau_1: stringifyNullableValue(record?.PopulationNiveau_1),
      LatitudeNiveau_1: stringifyNullableValue(record?.LatitudeNiveau_1),
      LongitudeNiveau_1: stringifyNullableValue(record?.LongitudeNiveau_1),
      surfaceNiveau_1: record?.surfaceNiveau_1 || "",
      geometryNiveau_1: record?.geometryNiveau_1 || "",
      EtenduNiveau_1: record?.EtenduNiveau_1 || "",
      timezoneNiveau_1: record?.timezoneNiveau_1 || "",
      wikidataNiveau_1: record?.wikidataNiveau_1 || "",
      FusionNiveau_1: Boolean(record?.FusionNiveau_1),
      VisibleNiveau_1: record?.VisibleNiveau_1 !== false,
      VisibleNiveau_5: record?.VisibleNiveau_5 !== false,
      ObsNiveau_1: record?.ObsNiveau_1 || "",
    }),
  }),
  [normalizeViewKey(SCHEMA_NAME, "V_Niveau_2")]: createCrudConfig({
    viewName: "V_Niveau_2",
    model: "T_Niveau_2",
    primaryKey: "ID_Niveau_2",
    resourceLabel: "niveau 2",
    createLabel: "Nouveau niveau 2",
    fields: NIVEAU_2_FIELDS,
    buildPayload: buildNiveau2Payload,
    mapRecord: (record) => ({
      ID_Niveau_1_FK: stringifyNullableValue(record?.ID_Niveau_1_FK),
      ID_TypeNiveau_2_Fk: stringifyNullableValue(record?.ID_TypeNiveau_2_Fk),
      NomNiveau_2: record?.NomNiveau_2 || "",
      Alt1_NomNiveau_2: record?.Alt1_NomNiveau_2 || "",
      AbreNiveau_2: record?.AbreNiveau_2 || "",
      CodeNiveau_2: record?.CodeNiveau_2 || "",
      PopulationNiveau_2: stringifyNullableValue(record?.PopulationNiveau_2),
      LatitudeNiveau_2: stringifyNullableValue(record?.LatitudeNiveau_2),
      LongitudeNiveau_2: stringifyNullableValue(record?.LongitudeNiveau_2),
      AltitudeNiveau_2: stringifyNullableValue(record?.AltitudeNiveau_2),
      surfaceNiveau_2: record?.surfaceNiveau_2 || "",
      geometryNiveau_2: record?.geometryNiveau_2 || "",
      EtenduNiveau_2: record?.EtenduNiveau_2 || "",
      ObsNiveau_2: record?.ObsNiveau_2 || "",
      ID_StatutNiveau_2: stringifyNullableValue(record?.ID_StatutNiveau_2),
      ID_StatusDeploiFk: stringifyNullableValue(record?.ID_StatusDeploiFk),
      KmDPSANT: stringifyNullableValue(record?.KmDPSANT),
      ID_VoieAccesDPSANTFk: stringifyNullableValue(record?.ID_VoieAccesDPSANTFk),
      SelectNiveau_2: Boolean(record?.SelectNiveau_2),
    }),
  }),
  [normalizeViewKey(SCHEMA_NAME, "V_Niveau_3")]: createCrudConfig({
    viewName: "V_Niveau_3",
    model: "T_Niveau_3",
    primaryKey: "ID_Niveau_3",
    resourceLabel: "niveau 3",
    createLabel: "Nouveau niveau 3",
    fields: NIVEAU_3_FIELDS,
    buildPayload: buildNiveau3Payload,
    mapRecord: (record) => ({
      ID_Niveau_2_FK: stringifyNullableValue(record?.ID_Niveau_2_FK),
      ID_TypeNiveau_2_Fk: stringifyNullableValue(record?.ID_TypeNiveau_2_Fk),
      NomNiveau_3: record?.NomNiveau_3 || "",
      Alt_Niveau_3: record?.Alt_Niveau_3 || "",
      AbreNiveau_3: record?.AbreNiveau_3 || "",
      CodeNiveau_3: record?.CodeNiveau_3 || "",
      PopulationNiveau_3: stringifyNullableValue(record?.PopulationNiveau_3),
      LatitudeNiveau_3: stringifyNullableValue(record?.LatitudeNiveau_3),
      LongitudeNiveau_3: stringifyNullableValue(record?.LongitudeNiveau_3),
      AltitudeNiveau_3: stringifyNullableValue(record?.AltitudeNiveau_3),
      surfaceNiveau_3: record?.surfaceNiveau_3 || "",
      geometryNiveau_3: record?.geometryNiveau_3 || "",
      EtenduNiveau_3: record?.EtenduNiveau_3 || "",
      ObsNiveau_3: record?.ObsNiveau_3 || "",
      ID_StatutNiveau_3_Fk: stringifyNullableValue(record?.ID_StatutNiveau_3_Fk),
      ID_StatutDeploieFk: stringifyNullableValue(record?.ID_StatutDeploieFk),
      KmAntenneBCZS: stringifyNullableValue(record?.KmAntenneBCZS),
      ID_VoieAccesANTBCZFk: stringifyNullableValue(record?.ID_VoieAccesANTBCZFk),
      KmDPSBCZS: stringifyNullableValue(record?.KmDPSBCZS),
      ID_VoieAccesDPSBCZFk: stringifyNullableValue(record?.ID_VoieAccesDPSBCZFk),
      SelectNiveau_3: Boolean(record?.SelectNiveau_3),
    }),
  }),
  [normalizeViewKey(SCHEMA_NAME, "V_Niveau_4")]: createCrudConfig({
    viewName: "V_Niveau_4",
    model: "T_Niveau_4",
    primaryKey: "ID_Niveau_4",
    resourceLabel: "niveau 4",
    createLabel: "Nouveau niveau 4",
    fields: NIVEAU_4_FIELDS,
    buildPayload: buildNiveau4Payload,
    mapRecord: (record) => ({
      ID_Niveau_3_Fk: stringifyNullableValue(record?.ID_Niveau_3_Fk),
      ID_TypeNiveau_4_Fk: stringifyNullableValue(record?.ID_TypeNiveau_4_Fk),
      NomNiveau_4: record?.NomNiveau_4 || "",
      AbreNiveau_4: record?.AbreNiveau_4 || "",
      CodeNiveau_4: record?.CodeNiveau_4 || "",
      PopulationNiveau_4: stringifyNullableValue(record?.PopulationNiveau_4),
      LatitudeNiveau_4: stringifyNullableValue(record?.LatitudeNiveau_4),
      LongitudeNiveau_4: stringifyNullableValue(record?.LongitudeNiveau_4),
      AltitudeNiveau_4: stringifyNullableValue(record?.AltitudeNiveau_4),
      KmZoneSanteAS: stringifyNullableValue(record?.KmZoneSanteAS),
      surfaceNiveau_4: record?.surfaceNiveau_4 || "",
      geometryNiveau_4: record?.geometryNiveau_4 || "",
      ID_DispoReseauNiveau_4: stringifyNullableValue(record?.ID_DispoReseauNiveau_4),
      ID_VoieAccesZsASFk: stringifyNullableValue(record?.ID_VoieAccesZsASFk),
      ID_StatutNiveau_4: stringifyNullableValue(record?.ID_StatutNiveau_4),
      ID_StatutDeploiementFk: stringifyNullableValue(record?.ID_StatutDeploiementFk),
      SelectNiveau_4: Boolean(record?.SelectNiveau_4),
      ObsNiveau_4: record?.ObsNiveau_4 || "",
    }),
  }),
  [normalizeViewKey(SCHEMA_NAME, "V_Niveau_5")]: createCrudConfig({
    viewName: "V_Niveau_5",
    model: "T_Niveau_5",
    primaryKey: "ID_Niveau_5",
    resourceLabel: "niveau 5",
    createLabel: "Nouveau niveau 5",
    fields: NIVEAU_5_FIELDS,
    buildPayload: buildNiveau5Payload,
    mapRecord: (record) => ({
      ID_Niveau_4_Fk: stringifyNullableValue(record?.ID_Niveau_4_Fk),
      ID_Niveau_3_Fk: stringifyNullableValue(record?.ID_Niveau_3_Fk),
      ID_TypeNiveau_5_Fk: stringifyNullableValue(record?.ID_TypeNiveau_5_Fk),
      NomNiveau_5: record?.NomNiveau_5 || "",
      AbreNiveau_5: record?.AbreNiveau_5 || "",
      CodeNiveau_5: record?.CodeNiveau_5 || "",
      PopulationNiveau_5: stringifyNullableValue(record?.PopulationNiveau_5),
      LatitudeNiveau_5: stringifyNullableValue(record?.LatitudeNiveau_5),
      LongitudeNiveau_5: stringifyNullableValue(record?.LongitudeNiveau_5),
      AltitudeNiveau_5: stringifyNullableValue(record?.AltitudeNiveau_5),
      KmZoneSanteNiveau_5: stringifyNullableValue(record?.KmZoneSanteNiveau_5),
      surfaceNiveau_5: record?.surfaceNiveau_5 || "",
      geometryNiveau_5: record?.geometryNiveau_5 || "",
      ID_DispoReseauNiveau_5: stringifyNullableValue(record?.ID_DispoReseauNiveau_5),
      ID_VoieAccesZsSiteFk: stringifyNullableValue(record?.ID_VoieAccesZsSiteFk),
      ID_StatutNiveau_5: stringifyNullableValue(record?.ID_StatutNiveau_5),
      ID_StatutDeploiementFk: stringifyNullableValue(record?.ID_StatutDeploiementFk),
      ID_TypeToitFk: stringifyNullableValue(record?.ID_TypeToitFk),
      SelectNiveau_5: Boolean(record?.SelectNiveau_5),
      ObsNiveau_5: record?.ObsNiveau_5 || "",
    }),
  }),
};

export const GEOLOCALISATION_ADMIN_SCHEMA = {
  schema: SCHEMA_NAME,
  title: "Schema geolocalisation",
  views: GEOLOCALISATION_VIEWS,
  crudConfigs: GEOLOCALISATION_CRUD_CONFIGS,
};
