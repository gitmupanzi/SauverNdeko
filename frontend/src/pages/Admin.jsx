import { useEffect, useMemo, useRef, useState } from "react";
import {
  createAdminEntity,
  createAdminLicence,
  createAdminModelRecord,
  createAdminUser,
  deleteAdminLicence,
  deleteAdminEntity,
  deleteAdminModelRecord,
  deleteAdminUser,
  fetchAdminEntities,
  fetchAdminEntity,
  fetchAdminLicence,
  fetchAdminLicences,
  fetchAdminModelItem,
  fetchAdminModelList,
  fetchAdminUser,
  fetchAvailableViews,
  fetchViewData,
  updateAdminLicence,
  updateAdminEntity,
  updateAdminModelRecord,
  updateAdminUser,
} from "../services/api";

const ADMIN_VIEWS = [
  {
    schema: "systeme",
    name: "V_Audit_log",
    title: "Journal d'audit",
    description: "Consulte les modifications tracees dans le systeme.",
  },
  {
    schema: "systeme",
    name: "V_Entite_Localisation_Detail",
    title: "Localisation des entites",
    description: "Affiche les entites, leurs contacts et leur positionnement geographique.",
  },
  {
    schema: "systeme",
    name: "V_Licence_active",
    title: "Licences actives",
    description: "Controle les licences par entite et leur statut d'expiration.",
  },
  {
    schema: "systeme",
    name: "V_Login_history",
    title: "Historique des connexions",
    description: "Suit les connexions et deconnexions enregistrees.",
  },
  {
    schema: "systeme",
    name: "V_User_profil",
    title: "Profils utilisateurs",
    description: "Expose les comptes utilisateurs et leur rattachement.",
  },
  {
    schema: "referentiel",
    name: "V_Generique",
    title: "Referentiel generique",
    description: "Permet de consulter les categories et valeurs du referentiel.",
  },
];

const SCHEMA_TITLES = {
  systeme: "Schema systeme",
  referentiel: "Schema referentiel",
};

const DEFAULT_ROWS_PER_PAGE = 25;
const MIN_COLUMN_WIDTH = 120;
const ADMIN_VIEW_STORAGE_PREFIX = "sauverndeko.admin.view.";
const NOTIFICATION_TIMEOUT = 4000;

const USER_FIELDS = [
  { name: "NomUser", label: "Nom", type: "text", required: true, initialValue: "" },
  { name: "PrenomUser", label: "Prenom", type: "text", required: true, initialValue: "" },
  { name: "EmailUser", label: "Email", type: "email", required: true, initialValue: "" },
  {
    name: "MotdepasseUser",
    label: "Mot de passe",
    type: "password",
    requiredOnCreate: true,
    initialValue: "",
    placeholderCreate: "Mot de passe initial",
    placeholderEdit: "Laisser vide pour conserver l'ancien mot de passe",
  },
  { name: "PhoneUser", label: "Telephone", type: "text", initialValue: "" },
  {
    name: "SexeUser",
    label: "Sexe",
    type: "select",
    required: true,
    initialValue: "M",
    options: [
      { value: "M", label: "Masculin" },
      { value: "F", label: "Feminin" },
    ],
  },
  { name: "IdRoleFk", label: "Role", type: "select", optionsSource: "roles", initialValue: "" },
  { name: "IdEntiteFk", label: "Entite", type: "select", optionsSource: "entities", initialValue: "" },
  { name: "ValideUser", label: "Compte valide", type: "checkbox", initialValue: true },
  { name: "Is_staff", label: "Acces staff", type: "checkbox", initialValue: false },
  { name: "Is_Admin", label: "Acces administrateur", type: "checkbox", initialValue: false },
  { name: "UrlPhoto", label: "Photo URL", type: "text", initialValue: "" },
];

const ENTITY_CORE_FIELDS = [
  { name: "NomEntite", label: "Nom entite", type: "text", required: true, initialValue: "" },
  { name: "EmailEntite", label: "Email entite", type: "email", required: true, initialValue: "" },
  { name: "PhoneEntite", label: "Telephone entite", type: "text", initialValue: "" },
  { name: "IdTypeEntiteFk", label: "Type entite", type: "select", optionsSource: "entityTypes", initialValue: "" },
  { name: "ValideEntite", label: "Entite valide", type: "checkbox", initialValue: true },
  { name: "AdresseEntite", label: "Adresse entite", type: "textarea", initialValue: "" },
];

const LOCATION_FIELDS = [
  { name: "Latitude", label: "Latitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "Longitude", label: "Longitude", type: "number", initialValue: "", step: "0.000001" },
  { name: "IdNiveau_3_Fk", label: "Id niveau 3", type: "number", initialValue: "", min: "1" },
  { name: "IdNiveau_4_Fk", label: "Id niveau 4", type: "number", initialValue: "", min: "1" },
  { name: "IdNiveau_5_Fk", label: "Id niveau 5", type: "number", initialValue: "", min: "1" },
  { name: "AdresseDetaillee", label: "Adresse detaillee", type: "textarea", initialValue: "" },
];

const ENTITY_FIELDS = [...ENTITY_CORE_FIELDS, ...LOCATION_FIELDS];

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

const LICENSE_FIELDS = [
  { name: "IdLicence", label: "Id licence", type: "number", required: true, initialValue: "", min: "1" },
  { name: "IdEntiteFk", label: "Entite", type: "select", optionsSource: "entities", required: true, initialValue: "" },
  {
    name: "IdStatutLicenceFk",
    label: "Statut licence",
    type: "select",
    optionsSource: "licenseStatuses",
    required: true,
    initialValue: "",
  },
  { name: "DateDebut", label: "Date debut", type: "datetime-local", initialValue: "" },
  { name: "DateFin", label: "Date fin", type: "datetime-local", required: true, initialValue: "" },
  { name: "ValideLicence", label: "Licence valide", type: "checkbox", initialValue: true },
  { name: "ExpireeLicence", label: "Licence expiriee", type: "checkbox", initialValue: false },
];

function normalizeViewKey(schema, name) {
  return `${schema}.${name}`;
}

function buildViewLabel(view) {
  return `${view.schema}.${view.name}`;
}

function isLikelyIsoDateTimeString(value) {
  if (typeof value !== "string") {
    return false;
  }

  return /^\d{4}-\d{2}-\d{2}(?:[T\s]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})?)?$/.test(value.trim());
}

function formatDisplayDateTime(value) {
  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  const normalized = String(value).trim();
  const hasTime = /[T\s]\d{2}:\d{2}/.test(normalized);

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    ...(hasTime
      ? {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        }
      : {}),
  }).format(parsed);
}

function formatCellValue(value) {
  if (value == null) {
    return "-";
  }

  if (typeof value === "object") {
    return JSON.stringify(value, null, 2);
  }

  if (isLikelyIsoDateTimeString(value)) {
    const formattedDateTime = formatDisplayDateTime(value);

    if (formattedDateTime) {
      return formattedDateTime;
    }
  }

  return String(value);
}

function normalizeSearchText(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function getFilterableCellValue(value) {
  if (value == null) {
    return "";
  }

  if (typeof value === "object") {
    return "";
  }

  return String(value);
}

function compareSortableValues(leftValue, rightValue) {
  if (leftValue == null && rightValue == null) {
    return 0;
  }

  if (leftValue == null) {
    return 1;
  }

  if (rightValue == null) {
    return -1;
  }

  const leftNumber = Number(leftValue);
  const rightNumber = Number(rightValue);
  const leftIsNumber = String(leftValue).trim() !== "" && Number.isFinite(leftNumber);
  const rightIsNumber = String(rightValue).trim() !== "" && Number.isFinite(rightNumber);

  if (leftIsNumber && rightIsNumber) {
    return leftNumber - rightNumber;
  }

  const leftDate = Date.parse(leftValue);
  const rightDate = Date.parse(rightValue);
  const leftIsDate = Number.isFinite(leftDate);
  const rightIsDate = Number.isFinite(rightDate);

  if (leftIsDate && rightIsDate) {
    return leftDate - rightDate;
  }

  return normalizeSearchText(leftValue).localeCompare(normalizeSearchText(rightValue), "fr");
}

function escapeCsvValue(value) {
  const normalized = String(value ?? "");

  if (/[",;\n]/.test(normalized)) {
    return `"${normalized.replace(/"/g, '""')}"`;
  }

  return normalized;
}

function buildColumnFilterSummary(selectedValues) {
  if (!Array.isArray(selectedValues) || selectedValues.length === 0) {
    return "Toutes les valeurs";
  }

  if (selectedValues.length === 1) {
    return selectedValues[0];
  }

  return `${selectedValues.length} valeurs`;
}

function createInitialValues(fields) {
  return fields.reduce((accumulator, field) => {
    accumulator[field.name] = field.type === "checkbox" ? Boolean(field.initialValue) : field.initialValue ?? "";
    return accumulator;
  }, {});
}

function normalizeCategoryName(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "");
}

function toOptionalNumber(value) {
  if (value === "" || value == null) {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function toOptionalDecimal(value) {
  if (value === "" || value == null) {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function buildEntityPayload(values) {
  return {
    NomEntite: values.NomEntite.trim(),
    EmailEntite: values.EmailEntite.trim(),
    PhoneEntite: values.PhoneEntite.trim() || null,
    AdresseEntite: values.AdresseEntite.trim() || null,
    IdTypeEntiteFk: toOptionalNumber(values.IdTypeEntiteFk),
    ValideEntite: Boolean(values.ValideEntite),
  };
}

function buildLocationPayload(values) {
  return {
    IdEntiteLocalisation: toOptionalNumber(values.IdEntiteLocalisation),
    Latitude: toOptionalDecimal(values.Latitude),
    Longitude: toOptionalDecimal(values.Longitude),
    IdNiveau_3_Fk: toOptionalNumber(values.IdNiveau_3_Fk),
    IdNiveau_4_Fk: toOptionalNumber(values.IdNiveau_4_Fk),
    IdNiveau_5_Fk: toOptionalNumber(values.IdNiveau_5_Fk),
    AdresseDetaillee: values.AdresseDetaillee.trim() || null,
  };
}

function getDefaultColumnWidth(column) {
  const normalized = normalizeSearchText(column);

  if (/olddata|newdata|description|adresse|detaillee|email/.test(normalized)) {
    return 280;
  }

  if (/date|time|login/.test(normalized)) {
    return 210;
  }

  if (/phone|telephone|nom|prenom|role|type|statut/.test(normalized)) {
    return 180;
  }

  if (/id|sexe|admin|staff|valide|visible/.test(normalized)) {
    return 150;
  }

  return 200;
}

function getSchemaTitle(schema) {
  return SCHEMA_TITLES[schema] || `Schema ${schema}`;
}

function formatDateTimeLocalValue(value) {
  if (!value) {
    return "";
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return "";
  }

  const offset = parsed.getTimezoneOffset();
  const local = new Date(parsed.getTime() - offset * 60 * 1000);
  return local.toISOString().slice(0, 16);
}

function toIsoDateTimeOrNull(value) {
  if (!value) {
    return null;
  }

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

function getAdminViewStorageKey(viewKey) {
  return `${ADMIN_VIEW_STORAGE_PREFIX}${viewKey}`;
}

function loadStoredAdminViewState(viewKey) {
  if (!viewKey) {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(getAdminViewStorageKey(viewKey));
    return raw ? JSON.parse(raw) : null;
  } catch (error) {
    return null;
  }
}

function saveStoredAdminViewState(viewKey, state) {
  if (!viewKey) {
    return;
  }

  try {
    window.localStorage.setItem(getAdminViewStorageKey(viewKey), JSON.stringify(state));
  } catch (error) {
    console.warn("Impossible d'enregistrer les preferences admin.", error);
  }
}

function getFieldOptions(field, supportData) {
  if (Array.isArray(field.options)) {
    return field.options;
  }

  if (field.optionsSource === "roles") {
    return supportData.roles.map((item) => ({
      value: String(item.ID_Generique),
      label: item.NomGenerique || `Role ${item.ID_Generique}`,
    }));
  }

  if (field.optionsSource === "entities") {
    return supportData.entities.map((item) => ({
      value: String(item.IdEntite),
      label: item.NomEntite || `Entite ${item.IdEntite}`,
    }));
  }

  if (field.optionsSource === "categories") {
    return supportData.categories.map((item) => ({
      value: String(item.ID_CategorieGenerique),
      label: item.NomCategorieGenerique || `Categorie ${item.ID_CategorieGenerique}`,
    }));
  }

  if (field.optionsSource === "entityTypes") {
    return supportData.entityTypes.map((item) => ({
      value: String(item.ID_Generique),
      label: item.NomGenerique || `Type ${item.ID_Generique}`,
    }));
  }

  if (field.optionsSource === "licenseStatuses") {
    return supportData.licenseStatuses.map((item) => ({
      value: String(item.ID_Generique),
      label: item.NomGenerique || `Statut ${item.ID_Generique}`,
    }));
  }

  return [];
}

async function fetchEntityViewRecord(row) {
  const [entityPayload, locationPayload] = await Promise.all([
    fetchAdminEntity(row.IdEntite),
    row.IdEntiteLocalisation
      ? fetchAdminModelItem("T_Entite_Localisation", row.IdEntiteLocalisation)
      : Promise.resolve({ success: true, data: null }),
  ]);

  if (!entityPayload?.success) {
    return entityPayload;
  }

  if (row.IdEntiteLocalisation && !locationPayload?.success) {
    return locationPayload;
  }

  return {
    success: true,
    data: {
      entity: entityPayload.data,
      location: locationPayload?.data || entityPayload.data?.T_Entite_Localisation?.[0] || null,
    },
  };
}

async function createEntityViewRecord(payload) {
  const entityResponse = await createAdminEntity(payload.entity);

  if (!entityResponse?.success) {
    return entityResponse;
  }

  const entityId = entityResponse.data?.IdEntite;
  const locationResponse = await createAdminModelRecord("T_Entite_Localisation", {
    ...payload.location,
    IdEntiteFk: entityId,
  });

  if (!locationResponse?.success) {
    if (entityId) {
      await deleteAdminEntity(entityId).catch?.(() => {});
    }

    return {
      success: false,
      message:
        locationResponse?.message ||
        "L'entite a ete creee mais sa localisation n'a pas pu etre finalisee.",
    };
  }

  return {
    success: true,
    data: {
      entity: entityResponse.data,
      location: locationResponse.data,
    },
  };
}

async function updateEntityViewRecord(id, payload) {
  const entityResponse = await updateAdminEntity(id, payload.entity);

  if (!entityResponse?.success) {
    return entityResponse;
  }

  const locationId = payload.location.IdEntiteLocalisation;
  const locationBody = {
    Latitude: payload.location.Latitude,
    Longitude: payload.location.Longitude,
    IdNiveau_3_Fk: payload.location.IdNiveau_3_Fk,
    IdNiveau_4_Fk: payload.location.IdNiveau_4_Fk,
    IdNiveau_5_Fk: payload.location.IdNiveau_5_Fk,
    AdresseDetaillee: payload.location.AdresseDetaillee,
  };

  const locationResponse = locationId
    ? await updateAdminModelRecord("T_Entite_Localisation", locationId, locationBody)
    : await createAdminModelRecord("T_Entite_Localisation", {
        ...locationBody,
        IdEntiteFk: id,
      });

  if (!locationResponse?.success) {
    return {
      success: false,
      message:
        locationResponse?.message ||
        "L'entite a ete mise a jour mais la localisation n'a pas pu etre synchronisee.",
    };
  }

  return {
    success: true,
    data: {
      entity: entityResponse.data,
      location: locationResponse.data,
    },
  };
}

const CRUD_CONFIGS = {
  "systeme.V_Entite_Localisation_Detail": {
    primaryKey: "IdEntite",
    resourceLabel: "entite",
    createLabel: "Nouvelle entite",
    allFields: ENTITY_FIELDS,
    fields: ENTITY_FIELDS,
    rowActions: [
      { mode: "edit-entity", label: "Modifier entite" },
      { mode: "edit-location", label: "Modifier localisation" },
      { mode: "delete", label: "Supprimer", tone: "danger" },
    ],
    getFields: (mode) => {
      if (mode === "edit-entity") {
        return ENTITY_CORE_FIELDS;
      }

      if (mode === "edit-location") {
        return LOCATION_FIELDS;
      }

      return ENTITY_FIELDS;
    },
    getModeLabel: (mode) => {
      if (mode === "edit-entity") {
        return "Modifier l'entite";
      }

      if (mode === "edit-location") {
        return "Modifier la localisation";
      }

      return "Nouvelle entite";
    },
    getModeDescription: (mode) => {
      if (mode === "edit-entity") {
        return "Mettez a jour les informations principales de l'entite.";
      }

      if (mode === "edit-location") {
        return "Mettez a jour les coordonnees et la localisation detaillee.";
      }

      return "Les champs saisis seront envoyes au backend admin.";
    },
    getSuccessMessage: (mode) => {
      if (mode === "edit-entity") {
        return "Entite mise a jour avec succes.";
      }

      if (mode === "edit-location") {
        return "Localisation mise a jour avec succes.";
      }

      return "Entite creee avec succes.";
    },
    fetchRecord: (row) => fetchEntityViewRecord(row),
    createRecord: (payload) => createEntityViewRecord(payload),
    updateRecord: (id, payload) => updateEntityViewRecord(id, payload),
    deleteRecord: (_id, row) => deleteAdminEntity(row.IdEntite),
    deleteConfirmation:
      "Voulez-vous vraiment supprimer cette entite ? Ses localisations associees seront aussi supprimees.",
    mapRecord: (record) => ({
      NomEntite: record?.entity?.NomEntite || "",
      EmailEntite: record?.entity?.EmailEntite || "",
      PhoneEntite: record?.entity?.PhoneEntite || "",
      AdresseEntite: record?.entity?.AdresseEntite || "",
      IdTypeEntiteFk: record?.entity?.IdTypeEntiteFk ? String(record.entity.IdTypeEntiteFk) : "",
      ValideEntite: record?.entity?.ValideEntite !== false,
      Latitude: record?.location?.Latitude != null ? String(record.location.Latitude) : "",
      Longitude: record?.location?.Longitude != null ? String(record.location.Longitude) : "",
      IdNiveau_3_Fk: record?.location?.IdNiveau_3_Fk ? String(record.location.IdNiveau_3_Fk) : "",
      IdNiveau_4_Fk: record?.location?.IdNiveau_4_Fk ? String(record.location.IdNiveau_4_Fk) : "",
      IdNiveau_5_Fk: record?.location?.IdNiveau_5_Fk ? String(record.location.IdNiveau_5_Fk) : "",
      AdresseDetaillee: record?.location?.AdresseDetaillee || "",
      IdEntiteLocalisation: record?.location?.IdEntiteLocalisation ? String(record.location.IdEntiteLocalisation) : "",
    }),
    buildPayload: (values) => ({
      entity: buildEntityPayload(values),
      location: buildLocationPayload(values),
    }),
  },
  "systeme.V_User_profil": {
    primaryKey: "IdUser",
    resourceLabel: "utilisateur",
    createLabel: "Nouvel utilisateur",
    allFields: USER_FIELDS,
    fields: USER_FIELDS,
    fetchRecord: (_row, id) => fetchAdminUser(id),
    createRecord: (payload) => createAdminUser(payload),
    updateRecord: (id, payload) => updateAdminUser(id, payload),
    deleteRecord: (id) => deleteAdminUser(id),
    mapRecord: (record) => ({
      NomUser: record?.NomUser || "",
      PrenomUser: record?.PrenomUser || "",
      EmailUser: record?.EmailUser || "",
      MotdepasseUser: "",
      PhoneUser: record?.PhoneUser || "",
      SexeUser: record?.SexeUser || "M",
      IdRoleFk: record?.IdRoleFk ? String(record.IdRoleFk) : "",
      IdEntiteFk: record?.IdEntiteFk ? String(record.IdEntiteFk) : "",
      ValideUser: Boolean(record?.ValideUser),
      Is_staff: Boolean(record?.Is_staff),
      Is_Admin: Boolean(record?.Is_Admin),
      UrlPhoto: record?.UrlPhoto || "",
    }),
    buildPayload: (values, mode) => {
      const payload = {
        NomUser: values.NomUser.trim(),
        PrenomUser: values.PrenomUser.trim(),
        EmailUser: values.EmailUser.trim(),
        PhoneUser: values.PhoneUser.trim() || null,
        SexeUser: values.SexeUser,
        IdRoleFk: values.IdRoleFk ? Number(values.IdRoleFk) : null,
        IdEntiteFk: values.IdEntiteFk ? Number(values.IdEntiteFk) : null,
        ValideUser: Boolean(values.ValideUser),
        Is_staff: Boolean(values.Is_staff),
        Is_Admin: Boolean(values.Is_Admin),
        UrlPhoto: values.UrlPhoto.trim() || null,
      };

      if (mode === "create" || values.MotdepasseUser.trim()) {
        payload.MotdepasseUser = values.MotdepasseUser;
      }

      return payload;
    },
  },
  "systeme.V_Licence_active": {
    primaryKey: "IdLicence",
    resourceLabel: "licence",
    createLabel: "Nouvelle licence",
    allFields: LICENSE_FIELDS,
    fields: LICENSE_FIELDS,
    getFields: (mode) => (mode === "create" ? LICENSE_FIELDS : LICENSE_FIELDS.filter((field) => field.name !== "IdLicence")),
    fetchRecord: (_row, id) => fetchAdminLicence(id),
    createRecord: (payload) => createAdminLicence(payload),
    updateRecord: (id, payload) => updateAdminLicence(id, payload),
    deleteRecord: (id) => deleteAdminLicence(id),
    mapRecord: (record) => ({
      IdLicence: record?.IdLicence ? String(record.IdLicence) : "",
      IdEntiteFk: record?.IdEntiteFk ? String(record.IdEntiteFk) : "",
      IdStatutLicenceFk: record?.IdStatutLicenceFk ? String(record.IdStatutLicenceFk) : "",
      DateDebut: formatDateTimeLocalValue(record?.DateDebut),
      DateFin: formatDateTimeLocalValue(record?.DateFin),
      ValideLicence: record?.ValideLicence !== false,
      ExpireeLicence: Boolean(record?.ExpireeLicence),
    }),
    buildPayload: (values) => ({
      IdLicence: Number(values.IdLicence),
      IdEntiteFk: Number(values.IdEntiteFk),
      IdStatutLicenceFk: Number(values.IdStatutLicenceFk),
      DateDebut: toIsoDateTimeOrNull(values.DateDebut),
      DateFin: toIsoDateTimeOrNull(values.DateFin),
      ValideLicence: Boolean(values.ValideLicence),
      ExpireeLicence: Boolean(values.ExpireeLicence),
    }),
  },
  "referentiel.V_Generique": {
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

const DEFAULT_ADMIN_VIEW_KEY =
  ADMIN_VIEWS.map((view) => normalizeViewKey(view.schema, view.name)).find((viewKey) => Boolean(CRUD_CONFIGS[viewKey])) ||
  normalizeViewKey(ADMIN_VIEWS[0].schema, ADMIN_VIEWS[0].name);

function AdminMultiSelectFilter({
  definition,
  selectedValues,
  isOpen,
  searchValue,
  onToggleOpen,
  onSearchChange,
  onToggleValue,
  onSelectAll,
  onClear,
}) {
  const visibleOptions = useMemo(
    () => definition.values.filter((value) => normalizeSearchText(value).includes(normalizeSearchText(searchValue))),
    [definition.values, searchValue]
  );

  return (
    <div className="admin-multiselect">
      <span>{definition.column}</span>
      <button
        type="button"
        className={`admin-multiselect-trigger ${isOpen ? "is-open" : ""}`}
        onClick={onToggleOpen}
      >
        <strong>{buildColumnFilterSummary(selectedValues)}</strong>
        <small>{isOpen ? "-" : "+"}</small>
      </button>

      {isOpen ? (
        <div className="admin-multiselect-panel">
          <div className="admin-multiselect-actions">
            <button type="button" className="secondary-action" onClick={onSelectAll}>
              Tout cocher
            </button>
            <button type="button" className="secondary-action" onClick={onClear}>
              Effacer
            </button>
          </div>

          <input
            className="admin-multiselect-search"
            type="search"
            value={searchValue}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder={`Rechercher dans ${definition.column}`}
          />

          <div className="admin-multiselect-options">
            {visibleOptions.length > 0 ? (
              visibleOptions.map((value) => {
                const checked = selectedValues.includes(value);

                return (
                  <label key={`${definition.column}-${value}`} className="admin-multiselect-option">
                    <input type="checkbox" checked={checked} onChange={() => onToggleValue(value)} />
                    <span>{value}</span>
                  </label>
                );
              })
            ) : (
              <div className="admin-multiselect-empty">Aucune valeur ne correspond a cette recherche.</div>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function AdminSummaryCard({ title, value, tone = "primary" }) {
  return (
    <article className={`admin-summary-card ${tone}`}>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  );
}

function AdminViewButton({ view, isActive, onSelect }) {
  return (
    <button className={`admin-view-button ${isActive ? "is-active" : ""}`} type="button" onClick={onSelect}>
      <strong>{view.title}</strong>
      <span>{buildViewLabel(view)}</span>
      <p>{view.description}</p>
    </button>
  );
}

export default function Admin() {
  const [availableViews, setAvailableViews] = useState([]);
  const [selectedViewKey, setSelectedViewKey] = useState(DEFAULT_ADMIN_VIEW_KEY);
  const [rows, setRows] = useState([]);
  const [viewMeta, setViewMeta] = useState({
    totalCount: 0,
    filteredCount: 0,
    take: DEFAULT_ROWS_PER_PAGE,
    skip: 0,
    sortBy: "",
    sortDir: "asc",
    columns: [],
  });
  const [loadingViews, setLoadingViews] = useState(true);
  const [loadingData, setLoadingData] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");
  const [supportData, setSupportData] = useState({
    roles: [],
    entities: [],
    categories: [],
    entityTypes: [],
    licenseStatuses: [],
  });
  const [loadingSupport, setLoadingSupport] = useState(true);
  const [supportError, setSupportError] = useState("");
  const [editorMode, setEditorMode] = useState(null);
  const [editorRecordId, setEditorRecordId] = useState(null);
  const [editorValues, setEditorValues] = useState({});
  const [loadingEditor, setLoadingEditor] = useState(false);
  const [submittingEditor, setSubmittingEditor] = useState(false);
  const [actionFeedback, setActionFeedback] = useState(null);
  const [showSearchPanel, setShowSearchPanel] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [columnFilters, setColumnFilters] = useState({});
  const [filterSearchTerms, setFilterSearchTerms] = useState({});
  const [openFilterColumn, setOpenFilterColumn] = useState("");
  const [showExportMenu, setShowExportMenu] = useState(false);
  const [showNavigationMenu, setShowNavigationMenu] = useState(false);
  const [sortConfig, setSortConfig] = useState({
    column: "",
    direction: "",
  });
  const [visibleColumns, setVisibleColumns] = useState([]);
  const [columnWidths, setColumnWidths] = useState({});
  const [pinnedColumns, setPinnedColumns] = useState([]);
  const [rowsPerPage, setRowsPerPage] = useState(DEFAULT_ROWS_PER_PAGE);
  const [currentPage, setCurrentPage] = useState(1);
  const [collapsedSchemas, setCollapsedSchemas] = useState({});
  const [notifications, setNotifications] = useState([]);
  const [selectedRowIds, setSelectedRowIds] = useState([]);
  const [expandedCells, setExpandedCells] = useState({});
  const resizingRef = useRef(null);
  const tableWrapRef = useRef(null);
  const exportMenuRef = useRef(null);
  const navigationMenuRef = useRef(null);
  const [horizontalScrollState, setHorizontalScrollState] = useState({
    overflow: false,
    canScrollLeft: false,
    canScrollRight: false,
  });

  const adminViews = useMemo(() => {
    const availableKeys = new Set(availableViews.map((view) => normalizeViewKey(view.schema, view.name)));
    return ADMIN_VIEWS.filter((view) => availableKeys.has(normalizeViewKey(view.schema, view.name)));
  }, [availableViews]);

  const selectedView = useMemo(
    () => adminViews.find((view) => normalizeViewKey(view.schema, view.name) === selectedViewKey) || null,
    [adminViews, selectedViewKey]
  );

  const selectedCrudConfig = selectedView ? CRUD_CONFIGS[normalizeViewKey(selectedView.schema, selectedView.name)] || null : null;

  const editorFields =
    selectedCrudConfig && editorMode
      ? selectedCrudConfig.getFields?.(editorMode) || selectedCrudConfig.fields
      : selectedCrudConfig?.fields || [];

  const columns = useMemo(() => {
    if (Array.isArray(viewMeta.columns) && viewMeta.columns.length > 0) {
      return viewMeta.columns;
    }

    return rows.length > 0 ? Object.keys(rows[0]) : [];
  }, [rows, viewMeta.columns]);

  const effectiveVisibleColumns = useMemo(() => {
    if (columns.length === 0) {
      return [];
    }

    if (!Array.isArray(visibleColumns) || visibleColumns.length === 0) {
      return columns;
    }

    const nextVisibleColumns = visibleColumns.filter((column) => columns.includes(column));
    const missingColumns = columns.filter((column) => !nextVisibleColumns.includes(column));
    return [...nextVisibleColumns, ...missingColumns];
  }, [columns, visibleColumns]);

  const filterableColumns = useMemo(
    () =>
      columns.filter((column) => {
        if (/OldData|NewData/i.test(column)) {
          return false;
        }

        return rows.some((row) => {
          const value = row[column];
          return value != null && typeof value !== "object";
        });
      }),
    [columns, rows]
  );

  const columnFilterDefinitions = useMemo(
    () =>
      filterableColumns.map((column) => {
        const values = Array.from(
          new Set(
            rows
              .map((row) => getFilterableCellValue(row[column]).trim())
              .filter((value) => Boolean(value))
          )
        ).sort((leftValue, rightValue) => compareSortableValues(leftValue, rightValue));

        return {
          column,
          values,
          useMultiSelect: values.length > 1 && values.length <= 80,
        };
      }),
    [filterableColumns, rows]
  );

  const filteredRows = rows;
  const sortedRows = rows;
  const selectedRows = useMemo(() => {
    if (!selectedCrudConfig) {
      return [];
    }

    return rows.filter((row) => selectedRowIds.includes(String(row[selectedCrudConfig.primaryKey])));
  }, [rows, selectedCrudConfig, selectedRowIds]);

  const selectedPrimaryRow = selectedRows[0] || null;

  const totalPages = useMemo(
    () => Math.max(1, Math.ceil((viewMeta.filteredCount || rows.length || 1) / rowsPerPage)),
    [rows.length, rowsPerPage, viewMeta.filteredCount]
  );

  const paginatedRows = rows;

  const schemaGroups = useMemo(() => {
    const schemaOrder = Array.from(new Set(ADMIN_VIEWS.map((view) => view.schema)));

    return schemaOrder
      .map((schema) => {
        const views = adminViews.filter((view) => view.schema === schema);
        const crudViews = views.filter((view) => Boolean(CRUD_CONFIGS[normalizeViewKey(view.schema, view.name)]));
        const readOnlyViews = views.filter((view) => !CRUD_CONFIGS[normalizeViewKey(view.schema, view.name)]);

        return {
          schema,
          title: getSchemaTitle(schema),
          crudViews,
          readOnlyViews,
        };
      })
      .filter((group) => group.crudViews.length > 0 || group.readOnlyViews.length > 0);
  }, [adminViews]);

  const activeFilterChips = useMemo(() => {
    const chips = [];

    if (searchTerm.trim()) {
      chips.push({
        key: "global-search",
        label: `Recherche: ${searchTerm.trim()}`,
        onRemove: () => setSearchTerm(""),
      });
    }

    Object.entries(columnFilters).forEach(([column, filterValue]) => {
      if (Array.isArray(filterValue) && filterValue.length > 0) {
        chips.push({
          key: `filter-${column}`,
          label: `${column}: ${filterValue.join(", ")}`,
          onRemove: () => handleClearMultiFilter(column),
        });
      } else if (typeof filterValue === "string" && filterValue.trim()) {
        chips.push({
          key: `filter-${column}`,
          label: `${column}: ${filterValue.trim()}`,
          onRemove: () => handleColumnFilterChange(column, ""),
        });
      }
    });

    if (sortConfig.column && sortConfig.direction) {
      chips.push({
        key: "sort",
        label: `Tri: ${sortConfig.column} (${sortConfig.direction === "asc" ? "croissant" : "decroissant"})`,
        onRemove: () =>
          setSortConfig({
            column: "",
            direction: "",
          }),
      });
    }

    if (pinnedColumns.length > 0) {
      chips.push({
        key: "pinned",
        label: `Colonnes gelees: ${pinnedColumns.join(", ")}`,
        onRemove: () => setPinnedColumns([]),
      });
    }

    return chips;
  }, [columnFilters, pinnedColumns, searchTerm, sortConfig]);

  const pinnedOffsets = useMemo(() => {
    const offsets = {};
    let currentLeft = 0;

    effectiveVisibleColumns.forEach((column) => {
      if (!pinnedColumns.includes(column)) {
        return;
      }

      offsets[column] = currentLeft;
      currentLeft += columnWidths[column] || getDefaultColumnWidth(column);
    });

    return offsets;
  }, [columnWidths, effectiveVisibleColumns, pinnedColumns]);

  function pushNotification(type, message) {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

    setNotifications((current) => [...current, { id, type, message }]);
    window.setTimeout(() => {
      setNotifications((current) => current.filter((item) => item.id !== id));
    }, NOTIFICATION_TIMEOUT);
  }

  function dismissNotification(notificationId) {
    setNotifications((current) => current.filter((item) => item.id !== notificationId));
  }

  function toggleExpandedCell(cellKey) {
    setExpandedCells((current) => ({
      ...current,
      [cellKey]: !current[cellKey],
    }));
  }

  function buildServerFilters(sourceFilters = columnFilters) {
    return Object.entries(sourceFilters).reduce((accumulator, [column, value]) => {
      if (Array.isArray(value) && value.length > 0) {
        accumulator[column] = value;
      } else if (typeof value === "string" && value.trim()) {
        accumulator[column] = value.trim();
      }

      return accumulator;
    }, {});
  }

  function getSelectedRows() {
    if (!selectedCrudConfig) {
      return [];
    }

    return selectedRows;
  }

  function exportRowsToExcel(rowsToExport, fileLabel) {
    const exportColumns = effectiveVisibleColumns;
    const headerHtml = exportColumns.map((column) => `<th>${column}</th>`).join("");
    const rowsHtml = rowsToExport
      .map(
        (row) =>
          `<tr>${exportColumns
            .map((column) => `<td>${String(formatCellValue(row[column])).replace(/</g, "&lt;").replace(/>/g, "&gt;")}</td>`)
            .join("")}</tr>`
      )
      .join("");

    const html = `
      <html>
        <head><meta charset="utf-8" /></head>
        <body>
          <table border="1">
            <thead><tr>${headerHtml}</tr></thead>
            <tbody>${rowsHtml}</tbody>
          </table>
        </body>
      </html>
    `;

    const blob = new Blob([html], { type: "application/vnd.ms-excel;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${fileLabel}.xls`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  function exportRowsToPdf(rowsToExport, fileLabel) {
    const exportColumns = effectiveVisibleColumns;
    const headerHtml = exportColumns.map((column) => `<th>${column}</th>`).join("");
    const rowsHtml = rowsToExport
      .map(
        (row) =>
          `<tr>${exportColumns
            .map((column) => `<td>${String(formatCellValue(row[column])).replace(/</g, "&lt;").replace(/>/g, "&gt;")}</td>`)
            .join("")}</tr>`
      )
      .join("");

    const printWindow = window.open("", "_blank", "noopener,noreferrer,width=1200,height=800");

    if (!printWindow) {
      pushNotification("error", "Impossible d'ouvrir la fenetre PDF.");
      return;
    }

    printWindow.document.write(`
      <html>
        <head>
          <meta charset="utf-8" />
          <title>${fileLabel}</title>
          <style>
            body { font-family: Arial, sans-serif; padding: 24px; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid #cfd7e4; padding: 8px; text-align: left; vertical-align: top; }
            th { background: #eef4ff; }
          </style>
        </head>
        <body>
          <h1>${fileLabel}</h1>
          <table>
            <thead><tr>${headerHtml}</tr></thead>
            <tbody>${rowsHtml}</tbody>
          </table>
        </body>
      </html>
    `);
    printWindow.document.close();
    printWindow.focus();
    printWindow.print();
  }

  useEffect(() => {
    async function handleMouseMove(event) {
      if (!resizingRef.current) {
        return;
      }

      const { column, startX, startWidth } = resizingRef.current;
      const width = Math.max(MIN_COLUMN_WIDTH, startWidth + (event.clientX - startX));

      setColumnWidths((current) => ({
        ...current,
        [column]: width,
      }));
    }

    function handleMouseUp() {
      if (resizingRef.current) {
        resizingRef.current = null;
      }
    }

    window.addEventListener("mousemove", handleMouseMove);
    window.addEventListener("mouseup", handleMouseUp);

    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      window.removeEventListener("mouseup", handleMouseUp);
    };
  }, []);

  useEffect(() => {
    const tableElement = tableWrapRef.current;

    if (!tableElement) {
      return undefined;
    }

    function updateHorizontalScrollState() {
      const overflow = tableElement.scrollWidth - tableElement.clientWidth > 2;
      const maxScrollLeft = Math.max(0, tableElement.scrollWidth - tableElement.clientWidth);
      const canScrollLeft = tableElement.scrollLeft > 2;
      const canScrollRight = tableElement.scrollLeft < maxScrollLeft - 2;

      setHorizontalScrollState({
        overflow,
        canScrollLeft,
        canScrollRight,
      });
    }

    const resizeObserver =
      typeof ResizeObserver !== "undefined"
        ? new ResizeObserver(() => {
            updateHorizontalScrollState();
          })
        : null;

    updateHorizontalScrollState();

    tableElement.addEventListener("scroll", updateHorizontalScrollState);
    resizeObserver?.observe(tableElement);
    window.addEventListener("resize", updateHorizontalScrollState);

    return () => {
      tableElement.removeEventListener("scroll", updateHorizontalScrollState);
      resizeObserver?.disconnect();
      window.removeEventListener("resize", updateHorizontalScrollState);
    };
  }, [rows, effectiveVisibleColumns, columnWidths, selectedViewKey, loadingData]);

  async function loadViewRows(view, overrides = {}) {
    if (!view) {
      setRows([]);
      setViewMeta((current) => ({
        ...current,
        columns: [],
        totalCount: 0,
        filteredCount: 0,
      }));
      setLoadingData(false);
      return;
    }

    setLoadingData(true);
    setErrorMessage("");

    const effectiveSortColumn =
      overrides.sortConfig?.column !== undefined ? overrides.sortConfig.column : sortConfig.column;
    const effectiveSortDirection =
      overrides.sortConfig?.direction !== undefined ? overrides.sortConfig.direction : sortConfig.direction;
    const effectiveSearchTerm = overrides.searchTerm !== undefined ? overrides.searchTerm : searchTerm;
    const effectiveFilters = overrides.columnFilters !== undefined ? overrides.columnFilters : columnFilters;
    const effectiveRowsPerPage = overrides.rowsPerPage || rowsPerPage;
    const effectiveCurrentPage = overrides.currentPage || currentPage;

    const payload = await fetchViewData(view.schema, view.name, {
      take: effectiveRowsPerPage,
      skip: (effectiveCurrentPage - 1) * effectiveRowsPerPage,
      q: effectiveSearchTerm.trim() || undefined,
      sortBy: effectiveSortColumn || undefined,
      sortDir: effectiveSortDirection || undefined,
      filters: JSON.stringify(buildServerFilters(effectiveFilters)),
    });

    if (payload?.success && Array.isArray(payload.data)) {
      setRows(payload.data);
      setViewMeta({
        columns: Array.isArray(payload.meta?.columns) ? payload.meta.columns : [],
        totalCount: Number(payload.meta?.totalCount || payload.data.length || 0),
        filteredCount: Number(payload.meta?.filteredCount || payload.data.length || 0),
        take: Number(payload.meta?.take || effectiveRowsPerPage),
        skip: Number(payload.meta?.skip || 0),
        sortBy: payload.meta?.sortBy || effectiveSortColumn || "",
        sortDir: payload.meta?.sortDir || effectiveSortDirection || "asc",
      });
    } else {
      setRows([]);
      setViewMeta((current) => ({
        ...current,
        columns: [],
        totalCount: 0,
        filteredCount: 0,
      }));
      setErrorMessage(payload?.message || "Impossible de charger les donnees de la vue selectionnee.");
    }

    setLoadingData(false);
  }

  useEffect(() => {
    let active = true;

    async function loadViews() {
      const payload = await fetchAvailableViews();

      if (!active) {
        return;
      }

      if (payload?.success && Array.isArray(payload.data)) {
        setAvailableViews(payload.data);
      } else {
        setErrorMessage(payload?.message || "Impossible de charger la liste des vues d'administration.");
      }

      setLoadingViews(false);
    }

    loadViews();

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    let active = true;

    async function loadSupportData() {
      setLoadingSupport(true);
      setSupportError("");

      const [entitiesPayload, categoriesPayload, genericsPayload, licencesPayload] = await Promise.all([
        fetchAdminEntities({ take: 100 }),
        fetchAdminModelList("T_CategorieGenerique", { take: 200 }),
        fetchViewData("referentiel", "V_Generique", { take: 500 }),
        fetchAdminLicences({ take: 50 }),
      ]);

      if (!active) {
        return;
      }

      const generics = genericsPayload?.success && Array.isArray(genericsPayload.data) ? genericsPayload.data : [];

      setSupportData({
        entities: entitiesPayload?.success && Array.isArray(entitiesPayload.data) ? entitiesPayload.data : [],
        categories: categoriesPayload?.success && Array.isArray(categoriesPayload.data) ? categoriesPayload.data : [],
        roles: generics.filter((item) => normalizeCategoryName(item.NomCategorieGenerique) === "role"),
        entityTypes: generics.filter((item) => normalizeCategoryName(item.NomCategorieGenerique).includes("typeentite")),
        licenseStatuses: generics.filter((item) =>
          normalizeCategoryName(item.NomCategorieGenerique).includes("statutlicence")
        ),
      });

      if (!entitiesPayload?.success || !categoriesPayload?.success || !genericsPayload?.success || !licencesPayload?.success) {
        setSupportError("Certaines listes de support n'ont pas pu etre chargees. Le CRUD reste disponible.");
      }

      setLoadingSupport(false);
    }

    loadSupportData();

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (adminViews.length === 0) {
      return;
    }

    const selectedExists = adminViews.some((view) => normalizeViewKey(view.schema, view.name) === selectedViewKey);

    if (!selectedExists) {
      const fallbackView =
        adminViews.find((view) => Boolean(CRUD_CONFIGS[normalizeViewKey(view.schema, view.name)])) || adminViews[0];

      if (fallbackView) {
        setSelectedViewKey(normalizeViewKey(fallbackView.schema, fallbackView.name));
      }
    }
  }, [adminViews, selectedViewKey]);

  useEffect(() => {
    let active = true;

    async function refreshSelectedView() {
      await loadViewRows(selectedView);

      if (!active) {
        return;
      }
    }

    refreshSelectedView();

    return () => {
      active = false;
    };
  }, [selectedView, searchTerm, columnFilters, sortConfig, rowsPerPage, currentPage]);

  useEffect(() => {
    const storedState = loadStoredAdminViewState(selectedViewKey);

    setEditorMode(null);
    setEditorRecordId(null);
    setEditorValues({});
    setLoadingEditor(false);
    setSubmittingEditor(false);
    setActionFeedback(null);
    setSearchTerm(storedState?.searchTerm || "");
    setColumnFilters(storedState?.columnFilters || {});
    setFilterSearchTerms(storedState?.filterSearchTerms || {});
    setOpenFilterColumn("");
    setShowSearchPanel(Boolean(storedState?.showSearchPanel));
    setSortConfig(
      storedState?.sortConfig || {
        column: "",
        direction: "",
      }
    );
    setVisibleColumns(storedState?.visibleColumns || []);
    setPinnedColumns(storedState?.pinnedColumns || []);
    setRowsPerPage(Number(storedState?.rowsPerPage || DEFAULT_ROWS_PER_PAGE));
    setSelectedRowIds([]);
    setCurrentPage(1);
    setShowExportMenu(false);
    setShowNavigationMenu(false);
  }, [selectedViewKey]);

  useEffect(() => {
    function handleDocumentPointerDown(event) {
      if (!exportMenuRef.current?.contains(event.target)) {
        setShowExportMenu(false);
      }

      if (!navigationMenuRef.current?.contains(event.target)) {
        setShowNavigationMenu(false);
      }
    }

    document.addEventListener("mousedown", handleDocumentPointerDown);

    return () => {
      document.removeEventListener("mousedown", handleDocumentPointerDown);
    };
  }, []);

  useEffect(() => {
    setVisibleColumns((current) => {
      if (columns.length === 0) {
        return [];
      }

      if (!Array.isArray(current) || current.length === 0) {
        return columns;
      }

      const nextVisibleColumns = current.filter((column) => columns.includes(column));
      const missingColumns = columns.filter((column) => !nextVisibleColumns.includes(column));
      return [...nextVisibleColumns, ...missingColumns];
    });

    setColumnWidths((current) => {
      const next = {};
      columns.forEach((column) => {
        next[column] = current[column] || getDefaultColumnWidth(column);
      });
      return next;
    });

    setPinnedColumns((current) => {
      const nextPinned = current.filter((column) => columns.includes(column));

      if (nextPinned.length > 0) {
        return nextPinned;
      }

      return columns[0] ? [columns[0]] : [];
    });
  }, [columns]);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, columnFilters, sortConfig, rowsPerPage, selectedViewKey]);

  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  useEffect(() => {
    saveStoredAdminViewState(selectedViewKey, {
      searchTerm,
      columnFilters,
      filterSearchTerms,
      sortConfig,
      visibleColumns,
      pinnedColumns,
      rowsPerPage,
      showSearchPanel,
    });
  }, [
    columnFilters,
    filterSearchTerms,
    pinnedColumns,
    rowsPerPage,
    searchTerm,
    selectedViewKey,
    showSearchPanel,
    sortConfig,
    visibleColumns,
  ]);

  useEffect(() => {
    if (!selectedCrudConfig) {
      setSelectedRowIds([]);
      return;
    }

    const rowIds = new Set(rows.map((row) => String(row[selectedCrudConfig.primaryKey])));
    setSelectedRowIds((current) => current.filter((item) => rowIds.has(item)));
  }, [rows, selectedCrudConfig]);

  useEffect(() => {
    setCollapsedSchemas((current) => {
      const nextState = {};

      schemaGroups.forEach((group) => {
        nextState[group.schema] = current[group.schema] ?? false;
      });

      return nextState;
    });
  }, [schemaGroups]);

  function getColumnWidth(column) {
    return columnWidths[column] || getDefaultColumnWidth(column);
  }

  function getCellStyle(column, isHeader = false) {
    const isPinned = pinnedColumns.includes(column);
    const width = getColumnWidth(column);

    return {
      width,
      minWidth: width,
      ...(isPinned
        ? {
            left: pinnedOffsets[column] || 0,
            zIndex: isHeader ? 6 : 3,
          }
        : null),
    };
  }

  function handleEditorValueChange(fieldName, nextValue) {
    setEditorValues((current) => ({
      ...current,
      [fieldName]: nextValue,
    }));
  }

  function handleColumnFilterChange(column, value) {
    setColumnFilters((current) => ({
      ...current,
      [column]: value,
    }));
  }

  function handleToggleMultiFilterValue(column, value) {
    setColumnFilters((current) => {
      const currentValues = Array.isArray(current[column]) ? current[column] : [];
      const nextValues = currentValues.includes(value)
        ? currentValues.filter((item) => item !== value)
        : [...currentValues, value];

      return {
        ...current,
        [column]: nextValues,
      };
    });
  }

  function handleSelectAllMultiFilter(column, values) {
    setColumnFilters((current) => ({
      ...current,
      [column]: values,
    }));
  }

  function handleClearMultiFilter(column) {
    setColumnFilters((current) => ({
      ...current,
      [column]: [],
    }));
  }

  function handleToggleVisibleColumn(column) {
    setVisibleColumns((current) => {
      const baselineColumns = current.length > 0 ? current : columns;

      if (baselineColumns.includes(column)) {
        const nextColumns = baselineColumns.filter((item) => item !== column);
        return nextColumns.length > 0 ? nextColumns : current;
      }

      return [...baselineColumns, column];
    });
  }

  function handleShowAllColumns() {
    setVisibleColumns(columns);
  }

  function handleResetColumns() {
    setVisibleColumns(columns);
    setPinnedColumns(columns[0] ? [columns[0]] : []);
    setColumnWidths(columns.reduce((accumulator, column) => {
      accumulator[column] = getDefaultColumnWidth(column);
      return accumulator;
    }, {}));
  }

  function handleSortColumn(column) {
    setSortConfig((current) => {
      if (current.column !== column) {
        return {
          column,
          direction: "asc",
        };
      }

      if (current.direction === "asc") {
        return {
          column,
          direction: "desc",
        };
      }

      if (current.direction === "desc") {
        return {
          column: "",
          direction: "",
        };
      }

      return {
        column,
        direction: "asc",
      };
    });
  }

  function handleToggleSchema(schema) {
    setCollapsedSchemas((current) => ({
      ...current,
      [schema]: !current[schema],
    }));
  }

  function handleTogglePinnedColumn(column) {
    setPinnedColumns((current) => {
      if (current.includes(column)) {
        return current.filter((item) => item !== column);
      }

      return [...current, column].sort(
        (leftValue, rightValue) => effectiveVisibleColumns.indexOf(leftValue) - effectiveVisibleColumns.indexOf(rightValue)
      );
    });
  }

  function handleResetColumnWidth(column) {
    setColumnWidths((current) => ({
      ...current,
      [column]: getDefaultColumnWidth(column),
    }));
  }

  function handleResizeStart(column, event) {
    event.preventDefault();
    event.stopPropagation();

    resizingRef.current = {
      column,
      startX: event.clientX,
      startWidth: getColumnWidth(column),
    };
  }

  function handleResetFilters() {
    setSearchTerm("");
    setColumnFilters({});
    setFilterSearchTerms({});
    setOpenFilterColumn("");
    setSortConfig({
      column: "",
      direction: "",
    });
    setCurrentPage(1);
  }

  function scrollTableHorizontally(mode) {
    const tableElement = tableWrapRef.current;

    if (!tableElement) {
      return;
    }

    const maxScrollLeft = Math.max(0, tableElement.scrollWidth - tableElement.clientWidth);
    const pageStep = Math.max(240, Math.round(tableElement.clientWidth * 0.75));

    if (mode === "start") {
      tableElement.scrollTo({ left: 0, behavior: "smooth" });
      return;
    }

    if (mode === "end") {
      tableElement.scrollTo({ left: maxScrollLeft, behavior: "smooth" });
      return;
    }

    const delta = mode === "left" ? -pageStep : pageStep;
    tableElement.scrollBy({ left: delta, behavior: "smooth" });
  }

  function handleNavigationAction(mode) {
    scrollTableHorizontally(mode);
    setShowNavigationMenu(false);
  }

  function handleTableWrapKeyDown(event) {
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      scrollTableHorizontally("left");
      return;
    }

    if (event.key === "ArrowRight") {
      event.preventDefault();
      scrollTableHorizontally("right");
    }
  }

  function handleToggleRowSelection(row) {
    if (!selectedCrudConfig) {
      return;
    }

    const recordId = String(row[selectedCrudConfig.primaryKey]);

    setSelectedRowIds((current) =>
      current.includes(recordId) ? current.filter((item) => item !== recordId) : [...current, recordId]
    );
  }

  function handleTogglePageSelection() {
    if (!selectedCrudConfig) {
      return;
    }

    const pageIds = rows.map((row) => String(row[selectedCrudConfig.primaryKey]));
    const everySelected = pageIds.length > 0 && pageIds.every((id) => selectedRowIds.includes(id));

    setSelectedRowIds((current) =>
      everySelected ? current.filter((id) => !pageIds.includes(id)) : Array.from(new Set([...current, ...pageIds]))
    );
  }

  function handleActivateRow(row, event) {
    if (!selectedCrudConfig) {
      return;
    }

    const interactiveTarget = event.target.closest("button, input, a, select, textarea, label");

    if (interactiveTarget) {
      return;
    }

    const recordId = String(row[selectedCrudConfig.primaryKey]);
    setSelectedRowIds((current) => (current.length === 1 && current[0] === recordId ? [] : [recordId]));
  }

  function handleExportCsv() {
    const rowsToExport = selectedRowIds.length > 0 ? getSelectedRows() : rows;
    const exportColumns = effectiveVisibleColumns;
    const csvRows = [
      exportColumns.join(";"),
      ...rowsToExport.map((row) =>
        exportColumns.map((column) => escapeCsvValue(getFilterableCellValue(row[column]))).join(";")
      ),
    ];

    const csvContent = "\uFEFF" + csvRows.join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${selectedView?.name || "tableau-admin"}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    setShowExportMenu(false);
  }

  function handleExportExcel() {
    const rowsToExport = selectedRowIds.length > 0 ? getSelectedRows() : rows;
    exportRowsToExcel(rowsToExport, selectedView?.name || "tableau-admin");
    pushNotification("success", "Export Excel prepare.");
    setShowExportMenu(false);
  }

  function handleExportPdf() {
    const rowsToExport = selectedRowIds.length > 0 ? getSelectedRows() : rows;
    exportRowsToPdf(rowsToExport, selectedView?.name || "tableau-admin");
    setShowExportMenu(false);
  }

  function handleCreate() {
    if (!selectedCrudConfig) {
      return;
    }

    setActionFeedback(null);
    setEditorMode("create");
    setEditorRecordId(null);
    setEditorValues(createInitialValues(selectedCrudConfig.allFields || selectedCrudConfig.fields));
  }

  async function handleEdit(row, mode = "edit") {
    if (!selectedCrudConfig) {
      return;
    }

    const recordId = row[selectedCrudConfig.primaryKey];

    if (!recordId) {
      setActionFeedback({
        type: "error",
        message: "Impossible d'identifier la ligne a modifier.",
      });
      return;
    }

    setActionFeedback(null);
    setLoadingEditor(true);

    const payload = await selectedCrudConfig.fetchRecord(row, recordId);

    if (payload?.success && payload.data) {
      setEditorMode(mode);
      setEditorRecordId(recordId);
      setEditorValues(selectedCrudConfig.mapRecord(payload.data));
    } else {
      setEditorMode(null);
      setEditorRecordId(null);
      setEditorValues({});
      setActionFeedback({
        type: "error",
        message: payload?.message || "Impossible de charger cet enregistrement.",
      });
    }

    setLoadingEditor(false);
  }

  function handleCancelEditor() {
    setEditorMode(null);
    setEditorRecordId(null);
    setEditorValues({});
  }

  async function handleSubmitEditor(event) {
    event.preventDefault();

    if (!selectedCrudConfig || !editorMode) {
      return;
    }

    setSubmittingEditor(true);
    setActionFeedback(null);

    const payload = selectedCrudConfig.buildPayload(editorValues, editorMode);
    const response =
      editorMode === "create"
        ? await selectedCrudConfig.createRecord(payload)
        : await selectedCrudConfig.updateRecord(editorRecordId, payload, editorValues);

    if (response?.success) {
      const successMessage = selectedCrudConfig.getSuccessMessage
        ? selectedCrudConfig.getSuccessMessage(editorMode)
        : editorMode === "create"
          ? `${selectedCrudConfig.resourceLabel} cree avec succes.`
          : `${selectedCrudConfig.resourceLabel} mis a jour avec succes.`;

      setActionFeedback({
        type: "success",
        message: successMessage,
      });
      pushNotification("success", successMessage);
      setEditorMode(null);
      setEditorRecordId(null);
      setEditorValues({});
      await loadViewRows(selectedView);
    } else {
      setActionFeedback({
        type: "error",
        message: response?.message || "L'operation a echoue.",
      });
      pushNotification("error", response?.message || "L'operation a echoue.");
    }

    setSubmittingEditor(false);
  }

  async function handleDelete(row) {
    if (!selectedCrudConfig) {
      return;
    }

    const recordId = row[selectedCrudConfig.primaryKey];

    if (!recordId) {
      setActionFeedback({
        type: "error",
        message: "Impossible d'identifier la ligne a supprimer.",
      });
      return;
    }

    const confirmed = window.confirm(
      selectedCrudConfig.deleteConfirmation || "Voulez-vous vraiment supprimer cet enregistrement ?"
    );

    if (!confirmed) {
      return;
    }

    setActionFeedback(null);

    const response = await selectedCrudConfig.deleteRecord(recordId, row);

    if (response?.success) {
      setActionFeedback({
        type: "success",
        message: `${selectedCrudConfig.resourceLabel} supprime avec succes.`,
      });
      pushNotification("success", `${selectedCrudConfig.resourceLabel} supprime avec succes.`);
      await loadViewRows(selectedView);
    } else {
      setActionFeedback({
        type: "error",
        message: response?.message || "La suppression a echoue.",
      });
      pushNotification("error", response?.message || "La suppression a echoue.");
    }
  }

  function renderEditorField(field) {
    const value = editorValues[field.name];

    if (field.type === "checkbox") {
      return (
        <label key={field.name} className="admin-checkbox-field">
          <input
            type="checkbox"
            checked={Boolean(value)}
            onChange={(event) => handleEditorValueChange(field.name, event.target.checked)}
          />
          <span>{field.label}</span>
        </label>
      );
    }

    if (field.type === "select") {
      const options = getFieldOptions(field, supportData);

      return (
        <label key={field.name} className="admin-form-field">
          <span>{field.label}</span>
          <select
            value={value ?? ""}
            onChange={(event) => handleEditorValueChange(field.name, event.target.value)}
            required={Boolean(field.required)}
          >
            <option value="">Selectionner</option>
            {options.map((option) => (
              <option key={`${field.name}-${option.value}`} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
      );
    }

    if (field.type === "textarea") {
      return (
        <label key={field.name} className="admin-form-field admin-form-field-wide">
          <span>{field.label}</span>
          <textarea
            value={value ?? ""}
            onChange={(event) => handleEditorValueChange(field.name, event.target.value)}
            rows={4}
          />
        </label>
      );
    }

    const isRequired = Boolean(field.required || (field.requiredOnCreate && editorMode === "create"));
    const placeholder = editorMode === "create" ? field.placeholderCreate : field.placeholderEdit;

    return (
      <label key={field.name} className="admin-form-field">
        <span>{field.label}</span>
        <input
          type={field.type}
          value={value ?? ""}
          onChange={(event) => handleEditorValueChange(field.name, event.target.value)}
          required={isRequired}
          placeholder={placeholder || ""}
          step={field.step}
          min={field.min}
        />
      </label>
    );
  }

  function renderTableCell(row, column, rowIndex) {
    const rawValue = row[column];
    const cellKey = `${selectedViewKey}-${rowIndex}-${column}`;
    const isObjectValue = typeof rawValue === "object" && rawValue !== null;
    const formattedValue = formatCellValue(rawValue);
    const isLongText = String(formattedValue).length > 180 || isObjectValue;
    const isExpanded = Boolean(expandedCells[cellKey]);

    if (isLongText) {
      return (
        <div className="admin-cell-stack">
          <pre className={`admin-json-cell ${isExpanded ? "is-expanded" : "is-collapsed"}`}>{formattedValue}</pre>
          <button
            type="button"
            className="admin-json-toggle"
            onClick={() => toggleExpandedCell(cellKey)}
          >
            {isExpanded ? "Voir moins" : "Voir plus"}
          </button>
        </div>
      );
    }

    return formatCellValue(rawValue);
  }

  return (
    <div className="page-shell admin-page-shell">
      {notifications.length > 0 ? (
        <div className="admin-notification-stack">
          {notifications.map((notification) => (
            <button
              key={notification.id}
              type="button"
              className={`admin-notification is-${notification.type}`}
              onClick={() => dismissNotification(notification.id)}
            >
              <strong>{notification.type === "success" ? "Succes" : "Attention"}</strong>
              <span>{notification.message}</span>
            </button>
          ))}
        </div>
      ) : null}

      <section className="admin-workspace">
        <aside className="admin-sidebar-card">
          <div className="section-head">
            <h3>Sources d'administration</h3>
            <p>Choisissez la vue a consulter.</p>
          </div>

          {loadingViews ? (
            <div className="table-empty-state">Chargement des vues...</div>
          ) : schemaGroups.length > 0 ? (
            <div className="admin-view-list">
              {schemaGroups.map((group) => (
                <section key={group.schema} className="admin-schema-group">
                  <div className="admin-schema-group-head">
                    <div className="admin-schema-group-title">
                      <strong>{group.title}</strong>
                      <span>{group.crudViews.length + group.readOnlyViews.length}</span>
                    </div>
                    <button
                      type="button"
                      className="admin-schema-toggle"
                      onClick={() => handleToggleSchema(group.schema)}
                      aria-expanded={!collapsedSchemas[group.schema]}
                    >
                      {collapsedSchemas[group.schema] ? "Derouler" : "Rouler"}
                    </button>
                  </div>

                  {!collapsedSchemas[group.schema] ? (
                    <>
                      {group.crudViews.length > 0 ? (
                        <div className="admin-view-group">
                          <div className="admin-view-group-head">
                            <strong>Vues avec CRUD</strong>
                            <span>{group.crudViews.length}</span>
                          </div>

                          {group.crudViews.map((view) => {
                            const viewKey = normalizeViewKey(view.schema, view.name);

                            return (
                              <AdminViewButton
                                key={viewKey}
                                view={view}
                                isActive={selectedViewKey === viewKey}
                                onSelect={() => setSelectedViewKey(viewKey)}
                              />
                            );
                          })}
                        </div>
                      ) : null}

                      {group.readOnlyViews.length > 0 ? (
                        <div className="admin-view-group">
                          <div className="admin-view-group-head">
                            <strong>Vues en lecture seule</strong>
                            <span>{group.readOnlyViews.length}</span>
                          </div>

                          {group.readOnlyViews.map((view) => {
                            const viewKey = normalizeViewKey(view.schema, view.name);

                            return (
                              <AdminViewButton
                                key={viewKey}
                                view={view}
                                isActive={selectedViewKey === viewKey}
                                onSelect={() => setSelectedViewKey(viewKey)}
                              />
                            );
                          })}
                        </div>
                      ) : null}
                    </>
                  ) : null}
                </section>
              ))}
            </div>
          ) : (
            <div className="table-empty-state">Aucune vue d'administration cible n'est disponible.</div>
          )}
        </aside>

        <div className="admin-main-column">
          <section className="page-hero-card admin-hero-card">
            <div>
              <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Administration</span>
              <h2>Fenetre d'administration</h2>
              <p>
                Cet espace est reserve aux administrateurs et consomme directement les vues du backend
                pour suivre les activites systeme.
              </p>
            </div>
            <span className="status-pill">Acces admin</span>
          </section>

          <section className="admin-summary-grid">
            <AdminSummaryCard title="Vues admin disponibles" value={String(adminViews.length)} />
            <AdminSummaryCard title="Vue selectionnee" value={selectedView ? selectedView.title : "Aucune"} tone="soft" />
            <AdminSummaryCard
              title="Lignes visibles"
              value={loadingData ? "..." : `${rows.length}/${viewMeta.filteredCount || rows.length}`}
              tone="soft"
            />
          </section>

          <section className="admin-content-card">
          <div className="admin-sticky-panel">
            <div className="admin-content-head">
              <div className="section-head">
                <h3>{selectedView?.title || "Vue d'administration"}</h3>
                <p>{selectedView?.description || "Selectionnez une vue."}</p>
              </div>
              {selectedView ? <span className="status-pill">{buildViewLabel(selectedView)}</span> : null}
            </div>

            <div className="admin-toolbar">
              <div className="admin-toolbar-meta">
                <span className={`status-pill ${selectedCrudConfig ? "" : "is-muted"}`}>
                  {selectedCrudConfig ? "CRUD disponible" : "Lecture seule"}
                </span>
                <span className="status-pill is-muted">
                  {`${viewMeta.filteredCount || rows.length}/${viewMeta.totalCount || rows.length} lignes`}
                </span>
                <span className="status-pill is-muted">{`${pinnedColumns.length} colonnes gelees`}</span>
                {horizontalScrollState.overflow ? (
                  <span className="status-pill is-muted">Defilement horizontal actif</span>
                ) : null}
                {selectedCrudConfig ? (
                  <span className="status-pill is-muted">{`${selectedRowIds.length} selectionnees`}</span>
                ) : null}
                {loadingSupport ? <small>Chargement des listes de support...</small> : null}
                {supportError ? <small>{supportError}</small> : null}
              </div>

              <div className="admin-toolbar-actions">
                <button
                  className="secondary-action"
                  type="button"
                  onClick={() => setShowSearchPanel((current) => !current)}
                >
                  {showSearchPanel ? "Masquer filtres" : "Filtres"}
                </button>
                <div ref={exportMenuRef} className="admin-scroll-menu" aria-label="Options d'export">
                  <button
                    className={`secondary-action admin-scroll-trigger ${showExportMenu ? "is-active" : ""}`}
                    type="button"
                    onClick={() => {
                      setShowNavigationMenu(false);
                      setShowExportMenu((current) => !current);
                    }}
                    disabled={rows.length === 0}
                    aria-expanded={showExportMenu}
                    aria-haspopup="true"
                  >
                    Exporter
                  </button>
                  {showExportMenu ? (
                    <div className="admin-scroll-menu-panel">
                      <button className="secondary-action" type="button" onClick={handleExportCsv} disabled={sortedRows.length === 0}>
                        Export CSV
                      </button>
                      <button className="secondary-action" type="button" onClick={handleExportExcel} disabled={rows.length === 0}>
                        Export Excel
                      </button>
                      <button className="secondary-action" type="button" onClick={handleExportPdf} disabled={rows.length === 0}>
                        Export PDF
                      </button>
                    </div>
                  ) : null}
                </div>
                <div ref={navigationMenuRef} className="admin-scroll-menu" aria-label="Controles de defilement horizontal">
                  <button
                    className={`secondary-action admin-scroll-trigger ${showNavigationMenu ? "is-active" : ""}`}
                    type="button"
                    onClick={() => {
                      setShowExportMenu(false);
                      setShowNavigationMenu((current) => !current);
                    }}
                    disabled={!horizontalScrollState.overflow}
                    aria-expanded={showNavigationMenu}
                    aria-haspopup="true"
                  >
                    Navigation
                  </button>
                  {showNavigationMenu ? (
                    <div className="admin-scroll-menu-panel">
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("start")}
                        disabled={!horizontalScrollState.canScrollLeft}
                      >
                        Debut
                      </button>
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("left")}
                        disabled={!horizontalScrollState.canScrollLeft}
                      >
                        Gauche
                      </button>
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("right")}
                        disabled={!horizontalScrollState.canScrollRight}
                      >
                        Droite
                      </button>
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("end")}
                        disabled={!horizontalScrollState.canScrollRight}
                      >
                        Fin
                      </button>
                    </div>
                  ) : null}
                </div>

                {selectedCrudConfig ? (
                  <button
                    className="primary-action"
                    type="button"
                    onClick={handleCreate}
                    disabled={loadingSupport || loadingEditor || submittingEditor}
                  >
                    {selectedCrudConfig.createLabel}
                  </button>
                ) : null}
              </div>
            </div>

            {selectedCrudConfig ? (
              <div className="admin-selection-strip">
                <div className="admin-bulk-actions">
                  <div className="admin-bulk-actions-main">
                    <span>{selectedRowIds.length > 0 ? `${selectedRowIds.length} lignes selectionnees` : "Aucune ligne selectionnee"}</span>
                    {selectedPrimaryRow ? (
                      <small>{`Ligne active: ${selectedCrudConfig.primaryKey} ${selectedPrimaryRow[selectedCrudConfig.primaryKey]}`}</small>
                    ) : (
                      <small>Cliquez sur une ligne du tableau pour afficher ses actions hors de la grille.</small>
                    )}
                  </div>
                </div>

                <div className="admin-selection-actions">
                  <div className="admin-selection-actions-head">
                    <strong>Actions de la ligne selectionnee</strong>
                    <span>
                      {selectedPrimaryRow
                        ? `Vous agissez hors du tableau sur la ligne ${selectedPrimaryRow[selectedCrudConfig.primaryKey]}.`
                        : selectedRowIds.length > 1
                          ? "Plusieurs lignes sont selectionnees. Gardez une seule ligne active pour voir ses actions."
                          : "Selectionnez une seule ligne pour voir ses actions metier."}
                    </span>
                  </div>
                  <div className="admin-selection-actions-buttons">
                    {selectedPrimaryRow ? (
                      (selectedCrudConfig.rowActions || []).length > 0 ? (
                        selectedCrudConfig.rowActions.map((action) =>
                          action.mode === "delete" ? (
                            <button
                              key={action.mode}
                              type="button"
                              className="admin-danger-button"
                              onClick={() => handleDelete(selectedPrimaryRow)}
                              disabled={selectedRowIds.length !== 1 || submittingEditor}
                            >
                              {action.label}
                            </button>
                          ) : (
                            <button
                              key={action.mode}
                              type="button"
                              className="secondary-action"
                              onClick={() => handleEdit(selectedPrimaryRow, action.mode)}
                              disabled={selectedRowIds.length !== 1 || submittingEditor}
                            >
                              {action.label}
                            </button>
                          )
                        )
                      ) : (
                        <>
                          <button
                            type="button"
                            className="secondary-action"
                            onClick={() => handleEdit(selectedPrimaryRow)}
                            disabled={selectedRowIds.length !== 1 || submittingEditor}
                          >
                            Modifier
                          </button>
                          <button
                            type="button"
                            className="admin-danger-button"
                            onClick={() => handleDelete(selectedPrimaryRow)}
                            disabled={selectedRowIds.length !== 1 || submittingEditor}
                          >
                            Supprimer
                          </button>
                        </>
                      )
                    ) : null}
                  </div>
                </div>
              </div>
            ) : null}

            <div className="admin-global-search-bar">
              <label className="admin-form-field admin-global-search-field">
                <span>Recherche globale</span>
                <input
                  type="search"
                  value={searchTerm}
                  onChange={(event) => setSearchTerm(event.target.value)}
                  placeholder="Rechercher une information dans le tableau"
                />
              </label>
            </div>
          </div>

          {showSearchPanel ? (
            <section className="admin-search-card">
              <div className="admin-search-head">
                <div className="section-head">
                  <h3>Filtres</h3>
                  <p>Affinez le tableau, gelez et redimensionnez les colonnes importantes.</p>
                </div>
                <button className="secondary-action" type="button" onClick={handleResetFilters}>
                  Reinitialiser
                </button>
              </div>

              {activeFilterChips.length > 0 ? (
                <div className="admin-filter-chips">
                  {activeFilterChips.map((chip) => (
                    <button key={chip.key} type="button" className="admin-filter-chip" onClick={chip.onRemove}>
                      <span>{chip.label}</span>
                      <small>x</small>
                    </button>
                  ))}
                </div>
              ) : null}

              <div className="admin-search-grid">
                {selectedViewKey === "systeme.V_Login_history" && filterableColumns.includes("TypeLogin") ? (
                  <div className="admin-quick-filters admin-form-field-wide">
                    <span>Filtre rapide historique</span>
                    <div className="admin-quick-filter-actions">
                      {[
                        { label: "Tout", values: [] },
                        { label: "Connexion", values: ["Connexion"] },
                        { label: "D\u00e9connexion", values: ["Deconnexion", "D\u00e9connexion"] },
                      ].map((option) => {
                        const isActive = JSON.stringify(columnFilters.TypeLogin || []) === JSON.stringify(option.values);

                        return (
                          <button
                            key={option.label}
                            type="button"
                            className={`secondary-action ${isActive ? "is-active" : ""}`}
                            onClick={() => handleSelectAllMultiFilter("TypeLogin", option.values)}
                          >
                            {option.label}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ) : null}

                {columnFilterDefinitions.map((definition) =>
                  definition.useMultiSelect ? (
                    <AdminMultiSelectFilter
                      key={definition.column}
                      definition={definition}
                      selectedValues={Array.isArray(columnFilters[definition.column]) ? columnFilters[definition.column] : []}
                      isOpen={openFilterColumn === definition.column}
                      searchValue={filterSearchTerms[definition.column] || ""}
                      onToggleOpen={() =>
                        setOpenFilterColumn((current) => (current === definition.column ? "" : definition.column))
                      }
                      onSearchChange={(value) =>
                        setFilterSearchTerms((current) => ({
                          ...current,
                          [definition.column]: value,
                        }))
                      }
                      onToggleValue={(value) => handleToggleMultiFilterValue(definition.column, value)}
                      onSelectAll={() => handleSelectAllMultiFilter(definition.column, definition.values)}
                      onClear={() => handleClearMultiFilter(definition.column)}
                    />
                  ) : (
                    <label key={definition.column} className="admin-form-field">
                      <span>{definition.column}</span>
                      <input
                        type="search"
                        value={typeof columnFilters[definition.column] === "string" ? columnFilters[definition.column] : ""}
                        onChange={(event) => handleColumnFilterChange(definition.column, event.target.value)}
                        placeholder={`Filtrer ${definition.column}`}
                      />
                    </label>
                  )
                )}

                <div className="admin-visibility-card admin-form-field-wide">
                  <div className="admin-visibility-head">
                    <span>Colonnes visibles, gelees et largeur</span>
                    <div className="admin-visibility-actions">
                      <button type="button" className="secondary-action" onClick={handleShowAllColumns}>
                        Tout afficher
                      </button>
                      <button type="button" className="secondary-action" onClick={handleResetColumns}>
                        Reinitialiser
                      </button>
                    </div>
                  </div>
                  <div className="admin-visibility-grid">
                    {columns.map((column) => {
                      const isPinned = pinnedColumns.includes(column);

                      return (
                        <div key={`visible-${column}`} className="admin-column-option">
                          <label className="admin-multiselect-option">
                            <input
                              type="checkbox"
                              checked={effectiveVisibleColumns.includes(column)}
                              onChange={() => handleToggleVisibleColumn(column)}
                            />
                            <span>{column}</span>
                          </label>
                          <div className="admin-column-option-actions">
                            <button
                              type="button"
                              className={`secondary-action ${isPinned ? "is-active" : ""}`}
                              onClick={() => handleTogglePinnedColumn(column)}
                            >
                              {isPinned ? "Degeler" : "Geler"}
                            </button>
                            <button
                              type="button"
                              className="secondary-action"
                              onClick={() => handleResetColumnWidth(column)}
                            >
                              Largeur auto
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </section>
          ) : null}

          {actionFeedback ? (
            <section className={`profile-feedback ${actionFeedback.type === "success" ? "is-success" : "is-error"}`}>
              {actionFeedback.message}
            </section>
          ) : null}

          {selectedCrudConfig && editorMode ? (
            <section className="admin-editor-card">
              <div className="admin-editor-head">
                <div className="section-head">
                  <h3>
                    {selectedCrudConfig.getModeLabel
                      ? selectedCrudConfig.getModeLabel(editorMode)
                      : editorMode === "create"
                        ? selectedCrudConfig.createLabel
                        : "Modifier l'enregistrement"}
                  </h3>
                  <p>
                    {selectedCrudConfig.getModeDescription
                      ? selectedCrudConfig.getModeDescription(editorMode)
                      : editorMode === "create"
                        ? "Les champs saisis seront envoyes au backend admin."
                        : "Modifiez les informations puis validez la mise a jour."}
                  </p>
                </div>
                {loadingEditor ? <span className="status-pill">Chargement...</span> : null}
              </div>

              <form className="admin-editor-form" onSubmit={handleSubmitEditor}>
                <div className="admin-editor-grid">{editorFields.map(renderEditorField)}</div>

                <div className="admin-editor-actions">
                  <button className="secondary-action" type="button" onClick={handleCancelEditor} disabled={submittingEditor}>
                    Annuler
                  </button>
                  <button className="primary-action" type="submit" disabled={loadingEditor || submittingEditor}>
                    {submittingEditor ? "Enregistrement..." : "Enregistrer"}
                  </button>
                </div>
              </form>
            </section>
          ) : null}

          {errorMessage ? <section className="table-empty-state">{errorMessage}</section> : null}

          {loadingData ? (
            <section className="table-empty-state">Chargement des donnees...</section>
          ) : rows.length > 0 ? (
            <>
              <div
                ref={tableWrapRef}
                className="public-table-wrap admin-table-wrap"
                tabIndex={0}
                onKeyDown={handleTableWrapKeyDown}
                aria-label="Tableau d'administration avec defilement horizontal et vertical"
              >
                <table className="public-table admin-table">
                  <colgroup>
                    {selectedCrudConfig ? <col style={{ width: 64 }} /> : null}
                    {effectiveVisibleColumns.map((column) => (
                      <col key={`col-${column}`} style={{ width: getColumnWidth(column) }} />
                    ))}
                  </colgroup>
                  <thead>
                    <tr>
                      {selectedCrudConfig ? (
                        <th className="admin-select-column">
                          <input
                            type="checkbox"
                            checked={rows.length > 0 && rows.every((row) => selectedRowIds.includes(String(row[selectedCrudConfig.primaryKey])))}
                            onChange={handleTogglePageSelection}
                            aria-label="Selectionner la page"
                          />
                        </th>
                      ) : null}
                      {effectiveVisibleColumns.map((column) => {
                        const isPinned = pinnedColumns.includes(column);

                        return (
                          <th
                            key={column}
                            className={`admin-table-head-cell ${isPinned ? "is-pinned" : ""}`}
                            style={getCellStyle(column, true)}
                          >
                            <div className="admin-header-cell">
                              <button
                                type="button"
                                className={`admin-sort-button ${sortConfig.column === column ? "is-active" : ""} ${
                                  sortConfig.column === column && sortConfig.direction ? `is-${sortConfig.direction}` : ""
                                }`}
                                onClick={() => handleSortColumn(column)}
                              >
                                <span>{column}</span>
                                <small>
                                  {sortConfig.column === column
                                    ? sortConfig.direction === "asc"
                                      ? "Asc"
                                      : sortConfig.direction === "desc"
                                        ? "Desc"
                                        : "Tri"
                                    : "Tri"}
                                </small>
                              </button>

                              <div className="admin-header-tools">
                                <button
                                  type="button"
                                  className={`admin-pin-button ${isPinned ? "is-active" : ""}`}
                                  onClick={() => handleTogglePinnedColumn(column)}
                                >
                                  {isPinned ? "Degeler" : "Geler"}
                                </button>
                                <div
                                  className="admin-resize-handle"
                                  onMouseDown={(event) => handleResizeStart(column, event)}
                                  role="separator"
                                  aria-orientation="vertical"
                                  aria-label={`Redimensionner la colonne ${column}`}
                                />
                              </div>
                            </div>
                          </th>
                        );
                      })}
                    </tr>
                  </thead>
                  <tbody>
                    {paginatedRows.map((row, rowIndex) => (
                      <tr
                        key={`${selectedViewKey}-${row[selectedCrudConfig?.primaryKey] || "row"}-${row.IdEntiteLocalisation || rowIndex}`}
                        className={
                          selectedCrudConfig &&
                          selectedRowIds.includes(String(row[selectedCrudConfig.primaryKey]))
                            ? "admin-table-row is-selected"
                            : "admin-table-row"
                        }
                        onClick={(event) => handleActivateRow(row, event)}
                      >
                        {selectedCrudConfig ? (
                          <td className="admin-select-column">
                            <input
                              type="checkbox"
                              checked={selectedRowIds.includes(String(row[selectedCrudConfig.primaryKey]))}
                              onChange={() => handleToggleRowSelection(row)}
                              aria-label="Selectionner la ligne"
                            />
                          </td>
                        ) : null}
                        {effectiveVisibleColumns.map((column) => {
                          const isPinned = pinnedColumns.includes(column);

                          return (
                            <td
                              key={`${rowIndex}-${column}`}
                              className={isPinned ? "admin-table-cell is-pinned" : "admin-table-cell"}
                              style={getCellStyle(column)}
                            >
                              {renderTableCell(row, column, rowIndex)}
                            </td>
                          );
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {!loadingData && viewMeta.filteredCount === 0 ? (
                <section className="table-empty-state">
                  Aucun resultat ne correspond a votre recherche ou a vos filtres.
                </section>
              ) : null}

              {sortedRows.length > 0 ? (
                <section className="admin-table-footer">
                  <div className="admin-table-footer-meta">
                    <span>{`Page ${currentPage} sur ${totalPages}`}</span>
                    <span>{`${rows.length} lignes affichees sur ${viewMeta.filteredCount || rows.length}`}</span>
                  </div>

                  <div className="admin-table-footer-actions">
                    <label className="admin-page-size">
                      <span>Lignes par page</span>
                      <select value={rowsPerPage} onChange={(event) => setRowsPerPage(Number(event.target.value))}>
                        {[10, 25, 50, 100].map((value) => (
                          <option key={value} value={value}>
                            {value}
                          </option>
                        ))}
                      </select>
                    </label>

                    <div className="admin-pagination">
                      <button type="button" className="secondary-action" onClick={() => setCurrentPage(1)} disabled={currentPage === 1}>
                        1ere
                      </button>
                      <button
                        type="button"
                        className="secondary-action"
                        onClick={() => setCurrentPage((current) => Math.max(1, current - 1))}
                        disabled={currentPage === 1}
                      >
                        Prec
                      </button>
                      <button
                        type="button"
                        className="secondary-action"
                        onClick={() => setCurrentPage((current) => Math.min(totalPages, current + 1))}
                        disabled={currentPage === totalPages}
                      >
                        Suiv
                      </button>
                      <button
                        type="button"
                        className="secondary-action"
                        onClick={() => setCurrentPage(totalPages)}
                        disabled={currentPage === totalPages}
                      >
                        Dern
                      </button>
                    </div>
                  </div>
                </section>
              ) : null}
            </>
          ) : (
            <section className="table-empty-state">
              {selectedCrudConfig
                ? "Aucune donnee disponible pour cette vue. Vous pouvez creer un nouvel enregistrement."
                : "Aucune donnee disponible pour cette vue."}
            </section>
          )}
          </section>
        </div>
      </section>
    </div>
  );
}
