import { useEffect, useMemo, useState } from "react";
import {
  createAdminEntity,
  createAdminModelRecord,
  createAdminUser,
  deleteAdminEntity,
  deleteAdminModelRecord,
  deleteAdminUser,
  fetchAdminEntities,
  fetchAdminEntity,
  fetchAdminModelItem,
  fetchAdminModelList,
  fetchAdminUser,
  fetchAvailableViews,
  fetchViewData,
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

function normalizeViewKey(schema, name) {
  return `${schema}.${name}`;
}

function buildViewLabel(view) {
  return `${view.schema}.${view.name}`;
}

function formatCellValue(value) {
  if (value == null) {
    return "-";
  }

  if (typeof value === "object") {
    return JSON.stringify(value, null, 2);
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
      { mode: "edit-entity", label: "Modifier entite", tone: "secondary" },
      { mode: "edit-location", label: "Modifier localisation", tone: "secondary" },
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
    () =>
      definition.values.filter((value) => normalizeSearchText(value).includes(normalizeSearchText(searchValue))),
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
        <small>{isOpen ? "−" : "+"}</small>
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

export default function Admin() {
  const [availableViews, setAvailableViews] = useState([]);
  const [selectedViewKey, setSelectedViewKey] = useState(DEFAULT_ADMIN_VIEW_KEY);
  const [rows, setRows] = useState([]);
  const [loadingViews, setLoadingViews] = useState(true);
  const [loadingData, setLoadingData] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");
  const [supportData, setSupportData] = useState({
    roles: [],
    entities: [],
    categories: [],
    entityTypes: [],
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
  const [sortConfig, setSortConfig] = useState({
    column: "",
    direction: "",
  });
  const [visibleColumns, setVisibleColumns] = useState([]);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [currentPage, setCurrentPage] = useState(1);

  async function loadViewRows(view) {
    if (!view) {
      setRows([]);
      setLoadingData(false);
      return;
    }

    setLoadingData(true);
    setErrorMessage("");

    const payload = await fetchViewData(view.schema, view.name);

    if (payload?.success && Array.isArray(payload.data)) {
      setRows(payload.data);
    } else {
      setRows([]);
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

      const [entitiesPayload, categoriesPayload, genericsPayload] = await Promise.all([
        fetchAdminEntities({ take: 100 }),
        fetchAdminModelList("T_CategorieGenerique", { take: 200 }),
        fetchViewData("referentiel", "V_Generique"),
      ]);

      if (!active) {
        return;
      }

      const generics = genericsPayload?.success && Array.isArray(genericsPayload.data) ? genericsPayload.data : [];
      const nextSupportData = {
        entities: entitiesPayload?.success && Array.isArray(entitiesPayload.data) ? entitiesPayload.data : [],
        categories: categoriesPayload?.success && Array.isArray(categoriesPayload.data) ? categoriesPayload.data : [],
        roles: generics.filter((item) => normalizeCategoryName(item.NomCategorieGenerique) === "role"),
        entityTypes: generics.filter((item) => normalizeCategoryName(item.NomCategorieGenerique).includes("typeentite")),
      };

      setSupportData(nextSupportData);

      if (!entitiesPayload?.success || !categoriesPayload?.success || !genericsPayload?.success) {
        setSupportError("Certaines listes de support n'ont pas pu etre chargees. Le CRUD reste disponible.");
      }

      setLoadingSupport(false);
    }

    loadSupportData();

    return () => {
      active = false;
    };
  }, []);

  const adminViews = useMemo(() => {
    const availableKeys = new Set(availableViews.map((view) => normalizeViewKey(view.schema, view.name)));
    return ADMIN_VIEWS.filter((view) => availableKeys.has(normalizeViewKey(view.schema, view.name)));
  }, [availableViews]);

  const crudAdminViews = useMemo(
    () => adminViews.filter((view) => Boolean(CRUD_CONFIGS[normalizeViewKey(view.schema, view.name)])),
    [adminViews]
  );

  const readOnlyAdminViews = useMemo(
    () => adminViews.filter((view) => !CRUD_CONFIGS[normalizeViewKey(view.schema, view.name)]),
    [adminViews]
  );

  const selectedView =
    adminViews.find((view) => normalizeViewKey(view.schema, view.name) === selectedViewKey) ||
    crudAdminViews[0] ||
    readOnlyAdminViews[0] ||
    null;

  const selectedCrudConfig = selectedView ? CRUD_CONFIGS[normalizeViewKey(selectedView.schema, selectedView.name)] || null : null;
  const editorFields =
    selectedCrudConfig && editorMode
      ? selectedCrudConfig.getFields?.(editorMode) || selectedCrudConfig.fields
      : selectedCrudConfig?.fields || [];
  const effectiveVisibleColumns = visibleColumns.length > 0 ? visibleColumns : columns;

  useEffect(() => {
    setEditorMode(null);
    setEditorRecordId(null);
    setEditorValues({});
    setLoadingEditor(false);
    setSubmittingEditor(false);
    setActionFeedback(null);
    setSearchTerm("");
    setColumnFilters({});
    setFilterSearchTerms({});
    setOpenFilterColumn("");
    setShowSearchPanel(false);
    setSortConfig({
      column: "",
      direction: "",
    });
    setVisibleColumns([]);
    setRowsPerPage(25);
    setCurrentPage(1);
  }, [selectedViewKey]);

  useEffect(() => {
    if (adminViews.length === 0) {
      return;
    }

    const selectedExists = adminViews.some((view) => normalizeViewKey(view.schema, view.name) === selectedViewKey);

    if (!selectedExists) {
      const fallbackView = crudAdminViews[0] || readOnlyAdminViews[0] || null;

      if (fallbackView) {
        setSelectedViewKey(normalizeViewKey(fallbackView.schema, fallbackView.name));
      }
    }
  }, [adminViews, crudAdminViews, readOnlyAdminViews, selectedViewKey]);

  useEffect(() => {
    let active = true;

    async function refreshSelectedView() {
      if (!selectedView) {
        setRows([]);
        setLoadingData(false);
        return;
      }

      setLoadingData(true);
      setErrorMessage("");

      const payload = await fetchViewData(selectedView.schema, selectedView.name);

      if (!active) {
        return;
      }

      if (payload?.success && Array.isArray(payload.data)) {
        setRows(payload.data);
      } else {
        setRows([]);
        setErrorMessage(payload?.message || "Impossible de charger les donnees de la vue selectionnee.");
      }

      setLoadingData(false);
    }

    refreshSelectedView();

    return () => {
      active = false;
    };
  }, [selectedView]);

  const columns = rows.length > 0 ? Object.keys(rows[0]) : [];
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

        const useMultiSelect = values.length > 1 && values.length <= 80;

        return {
          column,
          values,
          useMultiSelect,
        };
      }),
    [filterableColumns, rows]
  );

  const filteredRows = useMemo(() => {
    const normalizedSearchTerm = normalizeSearchText(searchTerm);

    return rows.filter((row) => {
      const matchesGlobalSearch =
        !normalizedSearchTerm ||
        filterableColumns.some((column) =>
          normalizeSearchText(getFilterableCellValue(row[column])).includes(normalizedSearchTerm)
        );

      if (!matchesGlobalSearch) {
        return false;
      }

      return Object.entries(columnFilters).every(([column, filterValue]) => {
        if (Array.isArray(filterValue)) {
          if (filterValue.length === 0) {
            return true;
          }

          return filterValue.some(
            (item) => normalizeSearchText(getFilterableCellValue(row[column])) === normalizeSearchText(item)
          );
        }

        if (!filterValue) {
          return true;
        }

        return normalizeSearchText(getFilterableCellValue(row[column])).includes(normalizeSearchText(filterValue));
      });
    });
  }, [columnFilters, filterableColumns, rows, searchTerm]);

  const sortedRows = useMemo(() => {
    if (!sortConfig.column || !sortConfig.direction) {
      return filteredRows;
    }

    const directionFactor = sortConfig.direction === "asc" ? 1 : -1;
    const nextRows = [...filteredRows];

    nextRows.sort((leftRow, rightRow) => {
      const leftValue = getFilterableCellValue(leftRow[sortConfig.column]);
      const rightValue = getFilterableCellValue(rightRow[sortConfig.column]);
      return compareSortableValues(leftValue, rightValue) * directionFactor;
    });

    return nextRows;
  }, [filteredRows, sortConfig]);

  const totalPages = useMemo(
    () => Math.max(1, Math.ceil(sortedRows.length / rowsPerPage)),
    [rowsPerPage, sortedRows.length]
  );

  const paginatedRows = useMemo(() => {
    const startIndex = (currentPage - 1) * rowsPerPage;
    return sortedRows.slice(startIndex, startIndex + rowsPerPage);
  }, [currentPage, rowsPerPage, sortedRows]);

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

    return chips;
  }, [columnFilters, searchTerm, sortConfig]);

  useEffect(() => {
    setVisibleColumns((current) => {
      if (columns.length === 0) {
        return [];
      }

      if (!current || current.length === 0) {
        return columns;
      }

      const nextVisibleColumns = current.filter((column) => columns.includes(column));
      const missingColumns = columns.filter((column) => !nextVisibleColumns.includes(column));
      return [...nextVisibleColumns, ...missingColumns];
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

  function handleExportCsv() {
    const exportColumns = effectiveVisibleColumns;
    const csvRows = [
      exportColumns.join(";"),
      ...sortedRows.map((row) =>
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
      setEditorMode(null);
      setEditorRecordId(null);
      setEditorValues({});
      await loadViewRows(selectedView);
    } else {
      setActionFeedback({
        type: "error",
        message: response?.message || "L'operation a echoue.",
      });
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
      await loadViewRows(selectedView);
    } else {
      setActionFeedback({
        type: "error",
        message: response?.message || "La suppression a echoue.",
      });
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

  return (
    <div className="page-shell">
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
        <AdminSummaryCard title="Lignes chargees" value={loadingData ? "..." : String(rows.length)} tone="soft" />
      </section>

      <section className="admin-layout">
        <aside className="admin-sidebar-card">
          <div className="section-head">
            <h3>Sources d'administration</h3>
            <p>Choisissez la vue a consulter.</p>
          </div>

          {loadingViews ? (
            <div className="table-empty-state">Chargement des vues...</div>
          ) : adminViews.length > 0 ? (
            <div className="admin-view-list">
              {crudAdminViews.length > 0 ? (
                <section className="admin-view-group">
                  <div className="admin-view-group-head">
                    <strong>Vues avec CRUD</strong>
                    <span>{crudAdminViews.length}</span>
                  </div>

                  {crudAdminViews.map((view) => {
                    const viewKey = normalizeViewKey(view.schema, view.name);

                    return (
                      <button
                        key={viewKey}
                        className={`admin-view-button ${selectedViewKey === viewKey ? "is-active" : ""}`}
                        type="button"
                        onClick={() => setSelectedViewKey(viewKey)}
                      >
                        <strong>{view.title}</strong>
                        <span>{buildViewLabel(view)}</span>
                        <p>{view.description}</p>
                      </button>
                    );
                  })}
                </section>
              ) : null}

              {readOnlyAdminViews.length > 0 ? (
                <section className="admin-view-group">
                  <div className="admin-view-group-head">
                    <strong>Vues en lecture seule</strong>
                    <span>{readOnlyAdminViews.length}</span>
                  </div>

                  {readOnlyAdminViews.map((view) => {
                    const viewKey = normalizeViewKey(view.schema, view.name);

                    return (
                      <button
                        key={viewKey}
                        className={`admin-view-button ${selectedViewKey === viewKey ? "is-active" : ""}`}
                        type="button"
                        onClick={() => setSelectedViewKey(viewKey)}
                      >
                        <strong>{view.title}</strong>
                        <span>{buildViewLabel(view)}</span>
                        <p>{view.description}</p>
                      </button>
                    );
                  })}
                </section>
              ) : null}
            </div>
          ) : (
            <div className="table-empty-state">Aucune vue d'administration cible n'est disponible.</div>
          )}
        </aside>

        <section className="admin-content-card">
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
              <span className="status-pill is-muted">{`${sortedRows.length}/${rows.length} lignes apres filtres`}</span>
              {loadingSupport ? <small>Chargement des listes de support...</small> : null}
              {supportError ? <small>{supportError}</small> : null}
            </div>

            <div className="admin-toolbar-actions">
              <button
                className="secondary-action"
                type="button"
                onClick={() => setShowSearchPanel((current) => !current)}
              >
                {showSearchPanel ? "Masquer recherche" : "Recherche et filtres"}
              </button>
              <button className="secondary-action" type="button" onClick={handleExportCsv} disabled={sortedRows.length === 0}>
                Export CSV
              </button>

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

          {showSearchPanel ? (
            <section className="admin-search-card">
              <div className="admin-search-head">
                <div className="section-head">
                  <h3>Recherche et filtres</h3>
                  <p>Recherchez dans le tableau et filtrez les colonnes importantes.</p>
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
                      <small>×</small>
                    </button>
                  ))}
                </div>
              ) : null}

              <div className="admin-search-grid">
                <label className="admin-form-field admin-form-field-wide">
                  <span>Recherche globale</span>
                  <input
                    type="search"
                    value={searchTerm}
                    onChange={(event) => setSearchTerm(event.target.value)}
                    placeholder="Rechercher une information dans le tableau"
                  />
                </label>

                {selectedViewKey === "systeme.V_Login_history" && filterableColumns.includes("TypeLogin") ? (
                  <div className="admin-quick-filters admin-form-field-wide">
                    <span>Filtre rapide historique</span>
                    <div className="admin-quick-filter-actions">
                      {["", "Connexion", "D\u00e9connexion"].map((value) => (
                        <button
                          key={value || "all"}
                          type="button"
                          className={`secondary-action ${JSON.stringify(columnFilters.TypeLogin || []) === JSON.stringify(value ? [value] : []) ? "is-active" : ""}`}
                          onClick={() => handleSelectAllMultiFilter("TypeLogin", value ? [value] : [])}
                        >
                          {value || "Tout"}
                        </button>
                      ))}
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
                    <span>Colonnes visibles</span>
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
                    {columns.map((column) => (
                      <label key={`visible-${column}`} className="admin-multiselect-option">
                        <input
                          type="checkbox"
                          checked={effectiveVisibleColumns.includes(column)}
                          onChange={() => handleToggleVisibleColumn(column)}
                        />
                        <span>{column}</span>
                      </label>
                    ))}
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
                  <button
                    className="secondary-action"
                    type="button"
                    onClick={handleCancelEditor}
                    disabled={submittingEditor}
                  >
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
            <div className="public-table-wrap admin-table-wrap">
              <table className="public-table admin-table">
                <thead>
                  <tr>
                    {effectiveVisibleColumns.map((column) => (
                      <th key={column}>
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
                                ? "↑"
                                : sortConfig.direction === "desc"
                                  ? "↓"
                                  : "↕"
                              : "↕"}
                          </small>
                        </button>
                      </th>
                    ))}
                    {selectedCrudConfig ? <th>Actions</th> : null}
                  </tr>
                </thead>
                <tbody>
                  {paginatedRows.map((row, rowIndex) => (
                    <tr key={`${selectedViewKey}-${row[selectedCrudConfig?.primaryKey] || "row"}-${row.IdEntiteLocalisation || rowIndex}`}>
                      {effectiveVisibleColumns.map((column) => (
                        <td key={`${rowIndex}-${column}`}>
                          {typeof row[column] === "object" && row[column] !== null ? (
                            <pre className="admin-json-cell">{formatCellValue(row[column])}</pre>
                          ) : (
                            formatCellValue(row[column])
                          )}
                        </td>
                      ))}
                      {selectedCrudConfig ? (
                        <td className="admin-actions-cell">
                          <div className="admin-row-actions">
                            {(selectedCrudConfig.rowActions || []).length > 0 ? (
                              selectedCrudConfig.rowActions.map((action) =>
                                action.mode === "delete" ? (
                                  <button
                                    key={action.mode}
                                    type="button"
                                    className="admin-danger-button"
                                    onClick={() => handleDelete(row)}
                                  >
                                    {action.label}
                                  </button>
                                ) : (
                                  <button
                                    key={action.mode}
                                    type="button"
                                    className="secondary-action"
                                    onClick={() => handleEdit(row, action.mode)}
                                  >
                                    {action.label}
                                  </button>
                                )
                              )
                            ) : (
                              <>
                                <button type="button" className="secondary-action" onClick={() => handleEdit(row)}>
                                  Modifier
                                </button>
                                <button type="button" className="admin-danger-button" onClick={() => handleDelete(row)}>
                                  Supprimer
                                </button>
                              </>
                            )}
                          </div>
                        </td>
                      ) : null}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <section className="table-empty-state">
              {selectedCrudConfig
                ? "Aucune donnee disponible pour cette vue. Vous pouvez creer un nouvel enregistrement."
                : "Aucune donnee disponible pour cette vue."}
            </section>
          )}

          {!loadingData && rows.length > 0 && filteredRows.length === 0 ? (
            <section className="table-empty-state">Aucun resultat ne correspond a votre recherche ou a vos filtres.</section>
          ) : null}

          {!loadingData && sortedRows.length > 0 ? (
            <section className="admin-table-footer">
              <div className="admin-table-footer-meta">
                <span>{`Page ${currentPage} sur ${totalPages}`}</span>
                <span>{`${paginatedRows.length} lignes affichees sur ${sortedRows.length}`}</span>
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
                    «
                  </button>
                  <button
                    type="button"
                    className="secondary-action"
                    onClick={() => setCurrentPage((current) => Math.max(1, current - 1))}
                    disabled={currentPage === 1}
                  >
                    ‹
                  </button>
                  <button
                    type="button"
                    className="secondary-action"
                    onClick={() => setCurrentPage((current) => Math.min(totalPages, current + 1))}
                    disabled={currentPage === totalPages}
                  >
                    ›
                  </button>
                  <button
                    type="button"
                    className="secondary-action"
                    onClick={() => setCurrentPage(totalPages)}
                    disabled={currentPage === totalPages}
                  >
                    »
                  </button>
                </div>
              </div>
            </section>
          ) : null}
        </section>
      </section>
    </div>
  );
}
