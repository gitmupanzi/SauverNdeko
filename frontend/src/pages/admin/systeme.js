import {
  createAdminEntity,
  createAdminLicence,
  createAdminModelRecord,
  createAdminUser,
  deleteAdminModelRecord,
  deleteAdminEntity,
  deleteAdminLicence,
  deleteAdminUser,
  fetchAdminEntity,
  fetchAdminLicence,
  fetchAdminModelItem,
  fetchAdminUser,
  updateAdminEntity,
  updateAdminLicence,
  updateAdminModelRecord,
  updateAdminUser,
} from "../../services/api";

const SCHEMA_NAME = "systeme";

const SYSTEME_VIEWS = [
  {
    schema: SCHEMA_NAME,
    name: "dashboard",
    title: "Tableau de bord",
    description: "Vue d'ensemble du module Administration.",
    virtual: true,
    renderMode: "dashboard",
    icon: "bi-grid-1x2",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_User_profil_users",
    title: "Utilisateurs",
    description: "Gestion des utilisateurs du systeme.",
    virtual: true,
    dataView: {
      schema: SCHEMA_NAME,
      name: "V_User_profil",
    },
    crudConfigKey: `${SCHEMA_NAME}.V_User_profil`,
    icon: "bi-people",
    preferredColumns: [
      "IdUser",
      "NomUser",
      "PrenomUser",
      "EmailUser",
      "PhoneUser",
      "SexeUser",
      "NomEntite",
      "ValideUser",
      "DatecreationUser",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Roles",
    title: "Roles",
    description: "Gestion des roles a partir du referentiel disponible.",
    virtual: true,
    dataView: {
      schema: "referentiel",
      name: "V_Generique",
    },
    crudConfigKey: "referentiel.V_Generique",
    icon: "bi-person-badge",
    defaultFilters: {
      NomCategorieGenerique: "Role",
    },
    preferredColumns: [
      "ID_Generique",
      "AbrGenerique",
      "NomGenerique",
      "ObsGenerique",
      "ValideGenerique",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Permissions",
    title: "Permissions",
    description: "Ecran prevu pour la gestion des permissions. Aucune vue systeme dediee n'est encore exposee.",
    virtual: true,
    renderMode: "empty",
    icon: "bi-shield-check",
    emptyTitle: "Aucune source permissions detectee",
    emptyMessage:
      "Le schema systeme ne fournit pas encore de vue SQL dediee aux permissions. L'ecran est prepare pour une integration ulterieure sans casser la navigation Administration.",
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Audit_log",
    title: "Journaux d'audit",
    description: "Historique des activites systeme en lecture seule.",
    icon: "bi-journal-text",
    preferredColumns: ["IdLog", "ChangedAt", "TableName", "NomEntite", "Operation", "OldData", "NewData"],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Fk_Correspondance_Detail",
    title: "Correspondances FK",
    description: "Mappings FK, categories generiques et portees d'affichage.",
    icon: "bi-link-45deg",
    preferredColumns: [
      "ModuleName",
      "SchemaName",
      "ViewName",
      "SourceKey",
      "FieldName",
      "FieldLabel",
      "MappingType",
      "NomCategorieGenerique",
      "MappingValue",
      "SettingScope",
      "ValideFkCorrespondance",
      "UpdatedAt",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Entite_Localisation_Detail",
    title: "Localisations entites",
    description: "Entites, contacts et coordonnees geographiques.",
    icon: "bi-geo-alt",
    preferredColumns: [
      "IdEntiteLocalisation",
      "IdEntite",
      "NomEntite",
      "TypeEntite",
      "PhoneEntite",
      "EmailEntite",
      "Latitude",
      "Longitude",
      "NomNiveau_3",
      "NomNiveau_4",
      "NomNiveau_5",
      "AdresseDetaillee",
      "DateCreation",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Licence_active",
    title: "Licences",
    description: "Suivi des licences et de leur etat d'expiration.",
    icon: "bi-file-earmark-text",
    preferredColumns: [
      "IdLicence",
      "NomEntite",
      "DateDebut",
      "DateFin",
      "ValideLicence",
      "ExpireeLicence",
      "statut_licence",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Login_history",
    title: "Historique de connexion",
    description: "Connexions et deconnexions en lecture seule.",
    icon: "bi-clock-history",
    preferredColumns: [
      "IdLogin",
      "DateLogin",
      "TypeLogin",
      "IdUser",
      "NomUser",
      "PrenomUser",
      "EmailUser",
      "NomEntite",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_User_profil_profiles",
    title: "Profils utilisateurs",
    description: "Vue profil complete des utilisateurs et de leur entite.",
    virtual: true,
    dataView: {
      schema: SCHEMA_NAME,
      name: "V_User_profil",
    },
    crudConfigKey: `${SCHEMA_NAME}.V_User_profil`,
    icon: "bi-person-vcard",
    preferredColumns: [
      "IdUser",
      "NomUser",
      "PrenomUser",
      "EmailUser",
      "PhoneUser",
      "SexeUser",
      "ValideUser",
      "Is_staff",
      "Is_Admin",
      "DatecreationUser",
      "NomEntite",
      "EmailEntite",
      "PhoneEntite",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Admin_UI_Setting",
    title: "Parametres UI",
    description: "Parametres partages et scopes de personnalisation.",
    icon: "bi-sliders",
    preferredColumns: [
      "SettingGroup",
      "SettingKey",
      "SettingLabel",
      "SettingType",
      "SettingValue",
      "SettingScope",
      "ScopeValue",
      "IsEditable",
      "IsSystem",
      "UpdatedAt",
      "UpdatedByName",
    ],
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Admin_UI_Setting_Audit",
    title: "Audit parametres UI",
    description: "Historique des modifications des parametres UI.",
    icon: "bi-clock",
    showInNavigation: false,
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Fk_Correspondance_Audit",
    title: "Audit correspondances FK",
    description: "Historique des modifications des correspondances FK.",
    icon: "bi-clock",
    showInNavigation: false,
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Fk_Correspondance",
    title: "Synthese correspondances FK",
    description: "Vue agregée des correspondances FK.",
    icon: "bi-diagram-3",
    showInNavigation: false,
  },
  {
    schema: SCHEMA_NAME,
    name: "V_Admin_UI_Setting_Group",
    title: "Groupes parametres UI",
    description: "Synthese des groupes de parametres UI.",
    icon: "bi-collection",
    showInNavigation: false,
  },
];

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
      { value: "F", label: "Feminin" },
      { value: "M", label: "Masculin" },
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
  { name: "IdNiveau_3_Fk", label: "Niveau 3", type: "select", optionsSource: "niveaux3", initialValue: "" },
  { name: "IdNiveau_4_Fk", label: "Niveau 4", type: "select", optionsSource: "niveaux4", initialValue: "" },
  { name: "IdNiveau_5_Fk", label: "Niveau 5", type: "select", optionsSource: "niveaux5", initialValue: "" },
  { name: "AdresseDetaillee", label: "Adresse detaillee", type: "textarea", initialValue: "" },
];

const ENTITY_FIELDS = [...ENTITY_CORE_FIELDS, ...LOCATION_FIELDS];

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

const FK_CORRESPONDANCE_FIELDS = [
  { name: "ModuleName", label: "Module", type: "text", required: true, initialValue: "systeme" },
  { name: "SchemaName", label: "Schema", type: "text", required: true, initialValue: "systeme" },
  { name: "ViewName", label: "Vue", type: "text", initialValue: "" },
  { name: "SourceKey", label: "Cle source", type: "text", required: true, initialValue: "" },
  { name: "FieldName", label: "Champ", type: "text", required: true, initialValue: "" },
  { name: "FieldLabel", label: "Libelle champ", type: "text", initialValue: "" },
  {
    name: "MappingType",
    label: "Type mapping",
    type: "select",
    required: true,
    initialValue: "generic_category",
    options: [
      { value: "generic_category", label: "generic_category" },
      { value: "hierarchy_mode", label: "hierarchy_mode" },
    ],
  },
  { name: "ReferenceSchemaName", label: "Schema reference", type: "text", initialValue: "" },
  { name: "ReferenceObjectName", label: "Objet reference", type: "text", initialValue: "" },
  { name: "ReferenceFieldName", label: "Champ reference", type: "text", initialValue: "" },
  {
    name: "TargetCategoryIdFk",
    label: "Categorie generique",
    type: "select",
    optionsSource: "categories",
    initialValue: "",
  },
  { name: "MappingValue", label: "Valeur mapping", type: "text", required: true, initialValue: "" },
  { name: "IsDefaultMapping", label: "Mapping par defaut", type: "checkbox", initialValue: false },
  { name: "ValideFkCorrespondance", label: "Mapping actif", type: "checkbox", initialValue: true },
  {
    name: "SettingScope",
    label: "Scope",
    type: "select",
    required: true,
    initialValue: "global",
    options: [
      { value: "global", label: "Global" },
      { value: "entity", label: "Entite" },
      { value: "user", label: "Utilisateur" },
      { value: "module", label: "Module" },
    ],
  },
  { name: "ScopeValue", label: "Valeur scope", type: "text", initialValue: "" },
  { name: "DisplayOrder", label: "Ordre", type: "number", initialValue: "0", min: "0" },
  { name: "UpdatedByUserFk", label: "Mis a jour par", type: "number", initialValue: "" },
  { name: "ObsFkCorrespondance", label: "Observation", type: "textarea", initialValue: "" },
];

const ADMIN_UI_SETTING_FIELDS = [
  {
    name: "SettingScope",
    label: "Scope",
    type: "select",
    required: true,
    initialValue: "global",
    options: [
      { value: "global", label: "Global" },
      { value: "entity", label: "Entite" },
      { value: "user", label: "Utilisateur" },
      { value: "module", label: "Module" },
    ],
  },
  { name: "ScopeValue", label: "Valeur scope", type: "text", initialValue: "" },
  { name: "SettingKey", label: "Cle", type: "text", required: true, initialValue: "" },
  { name: "SettingLabel", label: "Libelle", type: "text", initialValue: "" },
  { name: "SettingGroup", label: "Groupe", type: "text", initialValue: "general" },
  { name: "SettingValue", label: "Valeur texte", type: "textarea", initialValue: "" },
  { name: "SettingValueJson", label: "Valeur JSON", type: "textarea", initialValue: "" },
  { name: "SettingType", label: "Type", type: "text", initialValue: "text" },
  { name: "DisplayOrder", label: "Ordre", type: "number", initialValue: "0", min: "0" },
  { name: "IsEditable", label: "Modifiable", type: "checkbox", initialValue: true },
  { name: "IsSystem", label: "Systeme", type: "checkbox", initialValue: false },
  { name: "ValideSetting", label: "Actif", type: "checkbox", initialValue: true },
  { name: "UpdatedByUserFk", label: "Mis a jour par", type: "number", initialValue: "" },
  { name: "ObsSetting", label: "Observation", type: "textarea", initialValue: "" },
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

const SYSTEME_CRUD_CONFIGS = {
  [normalizeViewKey(SCHEMA_NAME, "V_Entite_Localisation_Detail")]: {
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
  [normalizeViewKey(SCHEMA_NAME, "V_User_profil")]: {
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
  [normalizeViewKey(SCHEMA_NAME, "V_Licence_active")]: {
    primaryKey: "IdLicence",
    resourceLabel: "licence",
    createLabel: "Nouvelle licence",
    allFields: LICENSE_FIELDS,
    fields: LICENSE_FIELDS,
    getFields: (mode) =>
      mode === "create" ? LICENSE_FIELDS : LICENSE_FIELDS.filter((field) => field.name !== "IdLicence"),
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
  [normalizeViewKey(SCHEMA_NAME, "V_Fk_Correspondance_Detail")]: {
    primaryKey: "IdFkCorrespondance",
    resourceLabel: "correspondance FK",
    createLabel: "Nouvelle correspondance",
    allFields: FK_CORRESPONDANCE_FIELDS,
    fields: FK_CORRESPONDANCE_FIELDS,
    fetchRecord: (_row, id) => fetchAdminModelItem("T_Fk_Correspondance", id),
    createRecord: (payload) => createAdminModelRecord("T_Fk_Correspondance", payload),
    updateRecord: (id, payload) => updateAdminModelRecord("T_Fk_Correspondance", id, payload),
    deleteRecord: (id) => deleteAdminModelRecord("T_Fk_Correspondance", id),
    mapRecord: (record) => ({
      ModuleName: record?.ModuleName || "systeme",
      SchemaName: record?.SchemaName || "systeme",
      ViewName: record?.ViewName || "",
      SourceKey: record?.SourceKey || "",
      FieldName: record?.FieldName || "",
      FieldLabel: record?.FieldLabel || "",
      MappingType: record?.MappingType || "generic_category",
      ReferenceSchemaName: record?.ReferenceSchemaName || "",
      ReferenceObjectName: record?.ReferenceObjectName || "",
      ReferenceFieldName: record?.ReferenceFieldName || "",
      TargetCategoryIdFk: record?.TargetCategoryIdFk ? String(record.TargetCategoryIdFk) : "",
      MappingValue: record?.MappingValue || "",
      IsDefaultMapping: Boolean(record?.IsDefaultMapping),
      ValideFkCorrespondance: record?.ValideFkCorrespondance !== false,
      SettingScope: record?.SettingScope || "global",
      ScopeValue: record?.ScopeValue || "",
      DisplayOrder: record?.DisplayOrder != null ? String(record.DisplayOrder) : "0",
      UpdatedByUserFk: record?.UpdatedByUserFk != null ? String(record.UpdatedByUserFk) : "",
      ObsFkCorrespondance: record?.ObsFkCorrespondance || "",
    }),
    buildPayload: (values) => ({
      ModuleName: values.ModuleName.trim(),
      SchemaName: values.SchemaName.trim(),
      ViewName: values.ViewName.trim() || null,
      SourceKey: values.SourceKey.trim(),
      FieldName: values.FieldName.trim(),
      FieldLabel: values.FieldLabel.trim() || null,
      MappingType: values.MappingType,
      ReferenceSchemaName: values.ReferenceSchemaName.trim() || null,
      ReferenceObjectName: values.ReferenceObjectName.trim() || null,
      ReferenceFieldName: values.ReferenceFieldName.trim() || null,
      TargetCategoryIdFk: values.TargetCategoryIdFk ? Number(values.TargetCategoryIdFk) : null,
      MappingValue: values.MappingValue.trim(),
      IsDefaultMapping: Boolean(values.IsDefaultMapping),
      ValideFkCorrespondance: Boolean(values.ValideFkCorrespondance),
      SettingScope: values.SettingScope,
      ScopeValue: values.ScopeValue.trim() || null,
      DisplayOrder: values.DisplayOrder === "" ? 0 : Number(values.DisplayOrder),
      UpdatedByUserFk: values.UpdatedByUserFk ? Number(values.UpdatedByUserFk) : null,
      ObsFkCorrespondance: values.ObsFkCorrespondance.trim() || null,
    }),
  },
  [normalizeViewKey(SCHEMA_NAME, "V_Admin_UI_Setting")]: {
    primaryKey: "IdAdminUISetting",
    resourceLabel: "parametre UI",
    createLabel: "Nouveau parametre",
    allFields: ADMIN_UI_SETTING_FIELDS,
    fields: ADMIN_UI_SETTING_FIELDS,
    fetchRecord: (_row, id) => fetchAdminModelItem("T_Admin_UI_Setting", id),
    createRecord: (payload) => createAdminModelRecord("T_Admin_UI_Setting", payload),
    updateRecord: (id, payload) => updateAdminModelRecord("T_Admin_UI_Setting", id, payload),
    deleteRecord: (id) => deleteAdminModelRecord("T_Admin_UI_Setting", id),
    mapRecord: (record) => ({
      SettingScope: record?.SettingScope || "global",
      ScopeValue: record?.ScopeValue || "",
      SettingKey: record?.SettingKey || "",
      SettingLabel: record?.SettingLabel || "",
      SettingGroup: record?.SettingGroup || "general",
      SettingValue: record?.SettingValue || "",
      SettingValueJson:
        record?.SettingValueJson == null
          ? ""
          : typeof record.SettingValueJson === "string"
            ? record.SettingValueJson
            : JSON.stringify(record.SettingValueJson, null, 2),
      SettingType: record?.SettingType || "text",
      DisplayOrder: record?.DisplayOrder != null ? String(record.DisplayOrder) : "0",
      IsEditable: record?.IsEditable !== false,
      IsSystem: Boolean(record?.IsSystem),
      ValideSetting: record?.ValideSetting !== false,
      UpdatedByUserFk: record?.UpdatedByUserFk != null ? String(record.UpdatedByUserFk) : "",
      ObsSetting: record?.ObsSetting || "",
    }),
    buildPayload: (values) => {
      const jsonValue = values.SettingValueJson.trim();
      let parsedJson = null;

      if (jsonValue) {
        parsedJson = JSON.parse(jsonValue);
      }

      return {
        SettingScope: values.SettingScope,
        ScopeValue: values.ScopeValue.trim() || null,
        SettingKey: values.SettingKey.trim(),
        SettingLabel: values.SettingLabel.trim() || null,
        SettingGroup: values.SettingGroup.trim() || "general",
        SettingValue: values.SettingValue.trim() || null,
        SettingValueJson: parsedJson,
        SettingType: values.SettingType.trim() || "text",
        DisplayOrder: values.DisplayOrder === "" ? 0 : Number(values.DisplayOrder),
        IsEditable: Boolean(values.IsEditable),
        IsSystem: Boolean(values.IsSystem),
        ValideSetting: Boolean(values.ValideSetting),
        UpdatedByUserFk: values.UpdatedByUserFk ? Number(values.UpdatedByUserFk) : null,
        ObsSetting: values.ObsSetting.trim() || null,
      };
    },
  },
  [normalizeViewKey(SCHEMA_NAME, "V_User_profil_users")]:
    null,
  [normalizeViewKey(SCHEMA_NAME, "V_User_profil_profiles")]:
    null,
};

SYSTEME_CRUD_CONFIGS[normalizeViewKey(SCHEMA_NAME, "V_User_profil_users")] =
  SYSTEME_CRUD_CONFIGS[normalizeViewKey(SCHEMA_NAME, "V_User_profil")];
SYSTEME_CRUD_CONFIGS[normalizeViewKey(SCHEMA_NAME, "V_User_profil_profiles")] =
  SYSTEME_CRUD_CONFIGS[normalizeViewKey(SCHEMA_NAME, "V_User_profil")];

export const SYSTEME_ADMIN_SCHEMA = {
  schema: SCHEMA_NAME,
  title: "Schema systeme",
  views: SYSTEME_VIEWS,
  crudConfigs: SYSTEME_CRUD_CONFIGS,
};
