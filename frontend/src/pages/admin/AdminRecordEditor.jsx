import {REFERENCE_RETAINED_HINT,referenceLabel,referenceOptions,retainReference,isRetainedReference} from "../../utils/referenceOptions";
import { useEffect, useId, useRef, useState } from "react";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import EntityProfileEditor from "../../components/EntityProfileEditor";
import { SYSTEME_ADMIN_SCHEMA } from "./systeme";
import {
  fetchAdminEntity, createAdminEntity, updateAdminEntity,
  fetchAdminModelItem, createAdminModelRecord, updateAdminModelRecord,
} from "../../services/api";
import { commandeDateInput, validCommandeDate } from "../logistique/commandeForm";
import { formatDate } from "../logistique/logistiqueShared";
import "./AdminRecordEditor.css";

const schemaConfigs = SYSTEME_ADMIN_SCHEMA.crudConfigs;
const LABELS = {
  NomUser: "Nom", PrenomUser: "Prénom", EmailUser: "Adresse e-mail", PhoneUser: "Téléphone", SexeUser: "Sexe",
  IdRoleFk: "Rôle", IdEntiteFk: "Entreprise", ValideUser: "Compte actif", Is_staff: "Accès au personnel", Is_Admin: "Administrateur de la plateforme",
  MotdepasseUser: "Mot de passe initial", NomEntite: "Nom de l’entreprise", EmailEntite: "Adresse e-mail", PhoneEntite: "Téléphone",
  IdTypeEntiteFk: "Type d’entreprise", AdresseEntite: "Adresse", ValideEntite: "Entreprise active",
  IdStatutLicenceFk: "Statut de la licence", DateDebut: "Début de validité", DateFin: "Fin de validité", ValideLicence: "Licence active", ExpireeLicence: "Licence expirée",
  NomGenerique: "Nom du rôle", AbrGenerique: "Code du rôle", ObsGenerique: "Description", ValideGenerique: "Rôle actif",
  ModuleName: "Module", SchemaName: "Schéma source", ViewName: "Vue source", SourceKey: "Clé source", FieldName: "Champ source", FieldLabel: "Libellé du champ",
  MappingType: "Type de correspondance", ReferenceSchemaName: "Schéma de référence", ReferenceObjectName: "Objet de référence", ReferenceFieldName: "Champ de référence",
  TargetCategoryIdFk: "Catégorie du référentiel", MappingValue: "Valeur de correspondance", IsDefaultMapping: "Correspondance par défaut", ValideFkCorrespondance: "Correspondance active",
  SettingScope: "Portée", ScopeValue: "Contexte", DisplayOrder: "Ordre d’affichage", ObsFkCorrespondance: "Observations",
  SettingKey: "Clé du paramètre", SettingLabel: "Libellé", SettingGroup: "Groupe", SettingValue: "Valeur", SettingValueJson: "Valeur JSON",
  SettingType: "Format de la valeur", IsEditable: "Paramètre modifiable", IsSystem: "Paramètre système", ValideSetting: "Paramètre actif", ObsSetting: "Observations",
  Latitude: "Latitude", Longitude: "Longitude", IdNiveau_3_Fk: "Niveau territorial 3", IdNiveau_4_Fk: "Niveau territorial 4", IdNiveau_5_Fk: "Niveau territorial 5", AdresseDetaillee: "Adresse détaillée",
};
const LIMITS = { NomUser: 100, PrenomUser: 100, EmailUser: 150, PhoneUser: 20, NomEntite: 255, EmailEntite: 150, PhoneEntite: 30, NomGenerique: 255, AbrGenerique: 255, ModuleName: 80, SchemaName: 80, ViewName: 120, SourceKey: 120, FieldName: 120, FieldLabel: 255, ReferenceSchemaName: 80, ReferenceObjectName: 120, ReferenceFieldName: 120, MappingValue: 120, SettingKey: 100, SettingLabel: 150, SettingGroup: 100, SettingType: 50 };
const SCOPE_OPTIONS = {
  fk: [{ value: "global", label: "Globale" }, { value: "country", label: "Pays" }, { value: "entity", label: "Entreprise" }],
  settings: [{ value: "global", label: "Globale" }, { value: "entite", label: "Entreprise" }, { value: "user", label: "Utilisateur" }, { value: "module", label: "Module" }],
};
const LOCATION_FIELDS = [
  { name: "IdEntiteFk", type: "select", optionsSource: "entities", required: true },
  { name: "IdNiveau_3_Fk", type: "select", optionsSource: "niveaux3" },
  { name: "IdNiveau_4_Fk", type: "select", optionsSource: "niveaux4" },
  { name: "IdNiveau_5_Fk", type: "select", optionsSource: "niveaux5" },
  { name: "Latitude", type: "number", step: "0.000001" },
  { name: "Longitude", type: "number", step: "0.000001" },
  { name: "AdresseDetaillee", type: "textarea" },
];
const ROLE_FIELDS = [
  { name: "NomGenerique", type: "text", required: true },
  { name: "AbrGenerique", type: "text" },
  { name: "ObsGenerique", type: "textarea" },
  { name: "ValideGenerique", type: "checkbox", initialValue: true },
];
const ENTITY_NAMES = ["NomEntite", "EmailEntite", "PhoneEntite", "IdTypeEntiteFk", "ValideEntite", "AdresseEntite"];
const userConfig = schemaConfigs["systeme.V_User_profil"];
const licenceConfig = schemaConfigs["systeme.V_Licence_active"];
const MODEL = {
  roles: "T_Generique", fk: "T_Fk_Correspondance", settings: "T_Admin_UI_Setting", locations: "T_Entite_Localisation",
};
const PRIMARY_KEYS = { users: "IdUser", profiles: "IdUser", entities: "IdEntite", licences: "IdLicence", roles: "ID_Generique", fk: "IdFkCorrespondance", settings: "IdAdminUISetting", locations: "IdEntiteLocalisation" };
const SYSTEM_SETTING_IDENTITY = new Set(["SettingKey", "SettingType", "SettingScope", "ScopeValue", "IsEditable", "IsSystem"]);
const PROFESSIONAL_FIELDS=[
  {name:"MatriculeUser",label:"Matricule",type:"text"},
  {name:"ID_ServiceFk",label:"Service",type:"select",optionsSource:"personnelServices"},
  {name:"ID_FonctionFk",label:"Fonction",type:"select",optionsSource:"personnelFonctions"},
  {name:"DateEmbauche",label:"Date d’embauche",type:"date"},
  {name:"DateFinEmploi",label:"Fin d’emploi",type:"date"},
  {name:"ObservationProfessionnelle",label:"Observations professionnelles",type:"textarea"},
];
const PROFESSIONAL_NAMES=new Set(PROFESSIONAL_FIELDS.map(field=>field.name));
Object.assign(LIMITS,{MatriculeUser:50,ObservationProfessionnelle:1000});

export function adminEditorFields(type, creating) {
  let fields;
  if (type === "users" || type === "profiles") fields = userConfig.allFields.filter(field => !["UrlPhoto", ...(!creating ? ["MotdepasseUser"] : [])].includes(field.name));
  else if (type === "entities") fields = schemaConfigs["systeme.V_Entite_Localisation_Detail"].allFields.filter(field => ENTITY_NAMES.includes(field.name));
  else if (type === "licences") fields = licenceConfig.allFields.filter(field => !["IdLicence", "ExpireeLicence"].includes(field.name));
  else if (type === "roles") fields = ROLE_FIELDS;
  else if (type === "locations") fields = LOCATION_FIELDS;
  else fields = schemaConfigs[type === "fk" ? "systeme.V_Fk_Correspondance_Detail" : "systeme.V_Admin_UI_Setting"]?.allFields.filter(field => !["UpdatedByUserFk", "IsSystem"].includes(field.name)) || [];
  if(["users","profiles"].includes(type))fields=[...fields,...PROFESSIONAL_FIELDS];
  return fields.map(field => ({ ...field, label: LABELS[field.name] || field.label || field.name }));
}
export function adminEditorValues(fields, record) {
  return Object.fromEntries(fields.map(field => {
    const value = record?.[field.name];
    if (record) {
      if (field.type === "checkbox") return [field.name, value == null ? null : value];
      if (field.type === "datetime-local") return [field.name, commandeDateInput(value)];
      if (field.name === "SettingValueJson") return [field.name, value == null ? "" : JSON.stringify(value, null, 2)];
      return [field.name, value == null ? "" : String(value)];
    }
    return [field.name, field.initialValue ?? (field.type === "checkbox" ? false : "")];
  }));
}
function titleFor(type, mode) {
  const words = { users: ["Utilisateur", "Nouvel utilisateur", "Modifier l’utilisateur"], profiles: ["Profil utilisateur", "Nouvel utilisateur", "Modifier l’utilisateur"], entities: ["Entreprise", "Nouvelle entreprise", "Modifier l’entreprise"], licences: ["Licence", "Nouvelle licence", "Modifier la licence"], roles: ["Rôle", "Nouveau rôle", "Modifier le rôle"], fk: ["Correspondance FK", "Nouvelle correspondance", "Modifier la correspondance"], settings: ["Paramètre d’interface", "Nouveau paramètre", "Modifier le paramètre"], locations: ["Localisation de l’entreprise", "Nouvelle localisation", "Modifier la localisation"] };
  return (words[type] || words.settings)[mode === "view" ? 0 : mode === "create" ? 1 : 2];
}
function identity(type, record, values) {
  if (type === "users" || type === "profiles") return [values.PrenomUser, values.NomUser].filter(Boolean).join(" ");
  return values.NomEntite || values.NomGenerique || values.SettingLabel || values.SettingKey || values.FieldLabel || values.FieldName || record?.NomEntite || (type === "licences" && record?.IdLicence ? "Licence #" + record.IdLicence : "");
}
async function getRecord(type, id) {
  if (type === "users" || type === "profiles") return userConfig.fetchRecord(null, id);
  if (type === "licences") return licenceConfig.fetchRecord(null, id);
  if (type === "entities") return fetchAdminEntity(id);
  return fetchAdminModelItem(MODEL[type], id);
}
async function saveRecord(type, id, payload) {
  if (type === "users" || type === "profiles") return id == null ? userConfig.createRecord(payload) : userConfig.updateRecord(id, payload);
  if (type === "licences") return id == null ? licenceConfig.createRecord(payload) : licenceConfig.updateRecord(id, payload);
  if (type === "entities") return id == null ? createAdminEntity(payload) : updateAdminEntity(id, payload);
  return id == null ? createAdminModelRecord(MODEL[type], payload) : updateAdminModelRecord(MODEL[type], id, payload);
}
function groupsFor(type, fields) {
  const names = fields.map(field => field.name);
  const filtered = groups => groups.map(group => ({ ...group, names: group.names.filter(name => names.includes(name)) })).filter(group => group.names.length);
  if (type === "users" || type === "profiles") return filtered([
    { key: "identity", label: "Informations personnelles", icon: "user", names: ["PrenomUser", "NomUser", "EmailUser", "PhoneUser", "SexeUser"] },
    {key:"professional",label:"Professionnel",icon:"building",names:[...PROFESSIONAL_NAMES]},
    { key: "access", label: "Organisation et accès", icon: "shield", names: ["IdEntiteFk", "IdRoleFk", "MotdepasseUser", "ValideUser", "Is_staff", "Is_Admin"] },
  ]);
  if (type === "fk") return filtered([
    { key: "identity", label: "Source", icon: "list", names: ["ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "FieldLabel"] },
    { key: "reference", label: "Référence", icon: "tag", names: ["MappingType", "TargetCategoryIdFk", "MappingValue", "ReferenceSchemaName", "ReferenceObjectName", "ReferenceFieldName"] },
    { key: "scope", label: "Portée", icon: "globe", names: ["SettingScope", "ScopeValue", "DisplayOrder", "IsDefaultMapping", "ValideFkCorrespondance", "ObsFkCorrespondance"] },
  ]);
  if (type === "settings") return filtered([
    { key: "identity", label: "Identification", icon: "settings", names: ["SettingLabel", "SettingKey", "SettingGroup", "SettingType"] },
    { key: "value", label: "Valeur", icon: "edit", names: ["SettingValue", "SettingValueJson", "ObsSetting"] },
    { key: "scope", label: "Portée", icon: "globe", names: ["SettingScope", "ScopeValue", "DisplayOrder", "IsEditable", "ValideSetting"] },
  ]);
  return [{ key: "identity", label: type === "licences" ? "Validité" : type === "locations" ? "Localisation" : "Identification", icon: type === "locations" ? "globe" : "document", names }];
}

export function adminEditorOptions(type,field,values,support) {
    if (field.name === "ScopeValue" && ["entity", "entite"].includes(values.SettingScope)) return (support.entities || []).map(entity => ({ value: String(entity.IdEntite), label: entity.NomEntite || "Entreprise sans nom" }));
    if (field.name === "SettingScope") return SCOPE_OPTIONS[type];
    if (field.name === "MappingType") return [{ value: "generic_category", label: "Catégorie du référentiel" }, { value: "direct_source", label: "Source directe" }, { value: "hierarchy_mode", label: "Hiérarchie" }];
    if (field.name === "SettingType") return ["text", "number", "boolean", "select", "json", "color", "file", "email", "phone", "url", "textarea"].map(value => ({ value, label: ({ text: "Texte", number: "Nombre", boolean: "Oui / Non", select: "Liste", json: "JSON", color: "Couleur", file: "Fichier", email: "Adresse e-mail", phone: "Téléphone", url: "Lien", textarea: "Texte long" })[value] }));
    if (field.options) return field.options.map(option => ({ ...option, label: ({ Feminin: "Féminin", Masculin: "Masculin" })[option.label] || option.label }));
    const source = field.optionsSource;
    if(["personnelServices","personnelFonctions"].includes(source))return referenceOptions(support[source]||[]);
    if (source === "entities") return (support.entities || []).map(entity => ({ value: String(entity.IdEntite), label: entity.NomEntite || "Entreprise sans nom", disabled: entity.ValideEntite === false }));
    if (source === "categories") return (support.categories || []).map(category => ({ value: String(category.ID_CategorieGenerique), label: category.NomCategorieGenerique || "Catégorie sans nom", disabled: category.ValideCategorieGenerique === false }));
    if (["roles","entityTypes","licenseStatuses"].includes(source)) return referenceOptions(support.referenceOptions?.[source]||[]);

    if (["niveaux3", "niveaux4", "niveaux5"].includes(source)) {
      const level = source.slice(-1);
      return (support[source] || []).filter(item => source === "niveaux4" && values.IdNiveau_3_Fk ? String(item.ID_Niveau_3_Fk) === values.IdNiveau_3_Fk : source === "niveaux5" && values.IdNiveau_4_Fk ? String(item.ID_Niveau_4_Fk) === values.IdNiveau_4_Fk : true).map(item => ({ value: String(item["ID_Niveau_" + level]), label: item["NomNiveau_" + level] || "Localisation sans nom" }));
    }
    return [];
}

export function adminEditorErrors(type,fields,values,initial,support,creating,optionsFor) {
    const issues = {};
    for (const field of fields) {
      const value = values[field.name], changed = creating || value !== initial[field.name];
      if (!changed) continue;
      if ((field.required || (creating && field.requiredOnCreate)) && !String(value ?? "").trim()) issues[field.name] = "Renseignez ce champ.";
      if (LIMITS[field.name] && String(value ?? "").length > LIMITS[field.name]) issues[field.name] = "Limitez ce champ à " + LIMITS[field.name] + " caractères.";
      if (field.type === "email" && value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) issues[field.name] = "Renseignez une adresse e-mail valide.";
      if ((field.type === "select" || field.name === "SettingType") && value && changed && !optionsFor(field).some(option => String(option.value) === String(value) && !option.disabled)) issues[field.name] = "Choisissez une valeur active de la liste.";
      if (field.type === "datetime-local" && value && !validCommandeDate(value)) issues[field.name] = "Renseignez une date et une heure valides.";
      if(field.type==="date"&&value&&(!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(Date.parse(value+"T00:00:00Z"))||new Date(value+"T00:00:00Z").toISOString().slice(0,10)!==value))issues[field.name]="Renseignez une date valide.";
      if(PROFESSIONAL_NAMES.has(field.name)&&String(value??"").length>(field.name==="MatriculeUser"?50:field.name==="ObservationProfessionnelle"?1000:Infinity))issues[field.name]="Ce texte est trop long.";
      if (field.type === "number" && value !== "" && (!Number.isFinite(Number(value)) || (field.name === "DisplayOrder" && (!/^\d+$/.test(String(value)) || Number(value) > 2147483647)))) issues[field.name] = "Renseignez un nombre valide.";
      if (["Latitude", "Longitude"].includes(field.name) && value !== "" && !/^-?\d+(?:\.\d{1,6})?$/.test(String(value))) issues[field.name] = "Utilisez au maximum 6 décimales.";
    }
    if(creating&&["users","profiles"].includes(type)&&values.Is_Admin!==true&&!values.IdEntiteFk)issues.IdEntiteFk="Choisissez l’entreprise du compte.";
    if (creating && type === "roles" && !/^[1-9]\d*$/.test(String(support.roleCategoryId||""))) issues.NomGenerique="La famille des rôles est indisponible. Rechargez les références.";
    if (creating && values.MotdepasseUser?.length < 12) issues.MotdepasseUser = "Utilisez au moins 12 caractères.";
    if (type === "licences" && values.DateDebut && values.DateFin && values.DateFin <= values.DateDebut) issues.DateFin = "La fin doit être postérieure au début.";
    if(["users","profiles"].includes(type)&&values.DateEmbauche&&values.DateFinEmploi&&values.DateFinEmploi<values.DateEmbauche)issues.DateFinEmploi="La fin de l’emploi ne peut pas précéder l’embauche.";
    if (type === "locations") {
      if (values.Latitude !== "" && Math.abs(Number(values.Latitude)) > 90) issues.Latitude = "Choisissez une latitude entre −90 et 90.";
      if (values.Longitude !== "" && Math.abs(Number(values.Longitude)) > 180) issues.Longitude = "Choisissez une longitude entre −180 et 180.";
    }
    if (type === "settings" && values.SettingValueJson && (creating || values.SettingValueJson !== initial.SettingValueJson)) {
      try { JSON.parse(values.SettingValueJson); } catch { issues.SettingValueJson = "Renseignez un JSON valide."; }
    }
    return issues;
}

/** Ne transmet que les valeurs éditables modifiées ; les valeurs absentes et masquées restent intactes. */
export function buildAdminEditorPayload(type, fields, values, initial, { creating = false, roleCategoryId = null } = {}) {
  const result = {};
  for (const field of fields) {
    const name = field.name, value = values[name];
    if (!creating && value === initial[name]) continue;
    if (type === "locations" && !creating && name === "IdEntiteFk") continue;
    if (name === "MotdepasseUser") { if (creating) result[name] = value; continue; }
    if (name === "SettingValueJson") result[name] = value.trim() ? JSON.parse(value) : null;
    else if (field.type === "checkbox") result[name] = value;
    else if (field.type === "number" || (field.type === "select" && (name.startsWith("Id") || name.startsWith("ID_") || name.endsWith("IdFk")))) result[name] = value === "" ? null : Number(value);
    else result[name] = String(value ?? "").trim() || null;
  }
  if (creating && type === "roles" && roleCategoryId) result.ID_CategorieGeneriqueFk = Number(roleCategoryId);
  if (creating && type === "settings") result.IsSystem = false;
  if (creating && type === "licences" && !result.DateDebut) delete result.DateDebut;
  return result;
}

/** Fenêtre commune d’administration : identifiants stables, fiche fraîche et modification partielle. */
export default function AdminRecordEditor(props){
  return props.type==="entities"?<EntityProfileEditor context="admin" recordId={props.recordId??null} mode={props.mode||"create"} support={props.support} canWrite={props.canWrite===true} onClose={props.onClose} onSaved={props.onSaved}/>:<AdminGenericRecordEditor {...props}/>;
}
function AdminGenericRecordEditor({ type = "users", recordId = null, mode = "create", row = null, support = {}, canWrite = false, onClose, onSaved, draft = null, onDraftSave }) {
  const prefix = useId(), creating = recordId == null;
  const fields = adminEditorFields(type, creating), groups = groupsFor(type, fields);
  const [record, setRecord] = useState(null), [values, setValues] = useState(() => adminEditorValues(fields, null)), [initial, setInitial] = useState(null);
  const [sensitive, setSensitive] = useState(false);
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false), [error, setError] = useState(""), [errors, setErrors] = useState({});
  const [active, setActive] = useState("identity"), [reload, setReload] = useState(0), [confirmReload, setConfirmReload] = useState(false), [uncertain, setUncertain] = useState(false);
  const generation = useRef(0), alive = useRef(true), saving = useRef(false), context = useRef({ type, recordId });
  const protectedSetting = type === "settings" && record && (record.IsEditable !== true || sensitive);
  const systemSettingIdentityLocked = type === "settings" && record?.IsSystem === true;
  const readOnly = mode === "view" || !canWrite || protectedSetting;
  const disabled = readOnly || loading || busy || uncertain;
  const dirty = Boolean(initial) && JSON.stringify(values) !== JSON.stringify(initial);
  const displayName = identity(type, record || row, values);

  useEffect(() => { alive.current = true; return () => { alive.current = false; generation.current++; }; }, []);
  useEffect(() => {
    let current = true; const token = ++generation.current;
    context.current = { type, recordId };
    setLoading(true); setInitial(null); setRecord(null); setSensitive(false); setError(""); setErrors({}); setUncertain(false); setConfirmReload(false); setActive("identity"); setBusy(false); saving.current = false;
    async function load() {
      const result = creating ? { success: true, data: null } : await getRecord(type, recordId);
      if (!current || generation.current !== token) return;
      setLoading(false);
      if (!result?.success || (!creating && !result.data)) { setError(result?.message || "La fiche n’a pas pu être chargée."); return; }
      if (!creating && String(result.data[PRIMARY_KEYS[type]]) !== String(recordId)) { setError("La fiche reçue ne correspond pas à la ligne choisie. Rechargez-la."); return; }
      // La vue de localisation expose l’entreprise sous son alias IdEntite.
      // La mutation conserve sa FK réelle et la PK propre à la localisation.
      const data = type === "locations" && result.data
        ? { ...result.data, IdEntiteFk: result.data.IdEntiteFk ?? result.data.IdEntite }
        : result.data;
      const next = draft ? {...adminEditorValues(fields,null),...draft.values} : adminEditorValues(fields, data);
      if (creating && !draft && (type === "users" || type === "profiles")) next.SexeUser = "";
      if (creating && !draft && type === "roles") next.ValideGenerique = true;
      if (creating && type === "locations" && row?.IdEntite) next.IdEntiteFk = String(row.IdEntite);
      setSensitive(result.meta?.sensitive === true); setRecord(data); setValues(next); setInitial({ ...next });
    }
    void load();
    return () => { current = false; };
  }, [type, recordId, mode, reload]);

  function change(name, value) {
    if (disabled || saving.current) return;
    setValues(current => ({ ...current, [name]: value,
      ...(name === "SettingScope" && value !== current.SettingScope ? { ScopeValue: "" } : {}),
      ...(name === "IdNiveau_3_Fk" && value !== current.IdNiveau_3_Fk ? { IdNiveau_4_Fk: "", IdNiveau_5_Fk: "" } : {}),
      ...(name === "IdNiveau_4_Fk" && value !== current.IdNiveau_4_Fk ? { IdNiveau_5_Fk: "" } : {}),
    })); setErrors(current => ({ ...current, [name]: "" }));
  }
  function optionsFor(field) {
    const options = [...(adminEditorOptions(type,field,values,support) || [])];
    if (!field.required) options.unshift({ value: "", label: "Non renseigné" });
    const value = values[field.name];
    if (value && !options.some(option => String(option.value) === String(value))) {
      const fallback = field.name === "IdEntiteFk" ? record?.NomEntite || row?.NomEntite : ["IdRoleFk","IdStatutLicenceFk","ID_ServiceFk","ID_FonctionFk","IdTypeEntiteFk"].includes(field.name)?referenceLabel({ID_Generique:value}):null;
      options.push({ value: String(value), label: fallback || "Valeur actuelle",disabled:true,incompatible:true });
    }
    return options;
  }
  function focusIssue(issues) {
    const name = Object.keys(issues)[0];
    setActive(groups.find(group => group.names.includes(name))?.key || "identity");
    requestAnimationFrame(() => document.getElementById(prefix + name)?.focus());
  }
  function payload() {
    const result = buildAdminEditorPayload(type, fields, values, initial, { creating, roleCategoryId: support.roleCategoryId });
    if (systemSettingIdentityLocked) for (const name of SYSTEM_SETTING_IDENTITY) delete result[name];
    return result;
  }
  async function submit() {
    if (disabled || !initial || saving.current || (!creating && !dirty)) return;
    const issues = adminEditorErrors(type,fields,values,initial,support,creating,optionsFor); setErrors(issues); setError("");
    if (Object.keys(issues).length) { focusIssue(issues); return; }
    if(draft){onDraftSave?.({values:{...values}});return;}
    const token = generation.current;
    saving.current = true; setBusy(true);
    const response = await saveRecord(type, recordId, payload());
    if (!alive.current || token !== generation.current) return;
    saving.current = false; setBusy(false);
    if (!response?.success) {
      if (creating && (!response?.status || response.status >= 500)) { setUncertain(true); setError("La réponse est incertaine. Vérifiez la liste avant de créer à nouveau cette fiche."); return; }
      const details = response?.error?.details;
      const issues = details && typeof details === "object" && !Array.isArray(details) ? Object.fromEntries(Object.entries(details).filter(([name]) => fields.some(field => field.name === name)).map(([name, message]) => [name, Array.isArray(message) ? message.join(" ") : String(message)])) : {};
      setErrors(issues); setError(Object.keys(issues).length ? "Vérifiez les champs indiqués." : response?.message || "L’enregistrement n’a pas abouti.");
      if (Object.keys(issues).length) focusIssue(issues);
      return;
    }
    setInitial({ ...values }); onSaved?.(response.data, { type, mode: creating ? "create" : "edit" });
  }
  function requestReload() { if (dirty) setConfirmReload(true); else setReload(value => value + 1); }
  function renderField(field) {
    const name = field.name, id = prefix + name, issue = errors[name];
    const locked = disabled || (support.platformAdmin===false && ["Is_Admin","Is_staff","IdEntiteFk"].includes(name)) || (draft && support.entityId && name === "IdEntiteFk") || (type === "locations" && !creating && name === "IdEntiteFk") || (systemSettingIdentityLocked && SYSTEM_SETTING_IDENTITY.has(name));
    if (field.type === "checkbox") return <label className="admin-record-check" key={name} htmlFor={id}><span><strong>{field.label}</strong>{values[name] == null ? <small>Non renseigné</small> : null}</span><input ref={element => { if (element) element.indeterminate = values[name] == null; }} id={id} type="checkbox" disabled={locked} checked={Boolean(values[name])} onChange={event => change(name, event.target.checked)}/></label>;
    const select = field.type === "select" || name === "SettingType" || (name === "ScopeValue" && ["entity", "entite"].includes(values.SettingScope));
    return <div className={"record-field" + (field.type === "textarea" || name.startsWith("Nom") ? " is-wide" : "")} key={name}>
      <label htmlFor={id}>{field.label}{field.required || (creating && field.requiredOnCreate) ? " *" : ""}</label>
      {select ? <SearchSelect id={id} label={field.label} value={values[name] ?? ""} onChange={value => change(name, value)} options={optionsFor(field)} disabled={locked} invalid={Boolean(issue)} describedBy={issue ? id + "-error" : undefined}/>
        : field.type === "textarea" ? <textarea id={id} rows={name === "SettingValueJson" ? 7 : 3} value={values[name] ?? ""} disabled={locked} onChange={event => change(name, event.target.value)} aria-invalid={Boolean(issue)} aria-describedby={issue ? id + "-error" : undefined} spellCheck={name !== "SettingValueJson"}/>
          : <input id={id} type={name.startsWith("Phone") ? "tel" : field.type || "text"} value={values[name] ?? ""} disabled={locked} onChange={event => change(name, event.target.value)} step={field.type === "datetime-local" ? 1 : field.step} maxLength={LIMITS[name]} autoComplete={field.type === "password" ? "new-password" : "off"} aria-invalid={Boolean(issue)} aria-describedby={issue ? id + "-error" : undefined}/>
      }
      {issue ? <small className="record-field-error" id={id + "-error"}>{issue}</small> : null}
      {select&&isRetainedReference(optionsFor(field),values[name])?<small className="record-editor-note">{REFERENCE_RETAINED_HINT}</small>:null}
      {field.type === "datetime-local" ? <small>Heure de Kinshasa.</small> : null}
      {name === "MotdepasseUser" ? <small>Au moins 12 caractères.</small> : null}
    </div>;
  }
  const trace = record ? [["Créé le", record.DatecreationUser || record.DateCreationEntite || record.DateCreation || record.CreatedAt], ["Modifié le", record.DateModificationUser || record.UpdatedAt]].filter(([, value]) => value) : [];
  const tabs = [...groups.map(({ key, label, icon }) => ({ key, label, icon })), ...(trace.length ? [{ key: "trace", label: "Traçabilité", icon: "clock" }] : [])];
  return <RecordEditorFrame title={titleFor(type, readOnly ? "view" : creating ? "create" : "edit")} subtitle={displayName} icon={type === "users" || type === "profiles" ? "user" : type === "locations" ? "globe" : type === "roles" ? "shield" : type === "fk" ? "list" : type === "settings" ? "settings" : "document"} defaultWidth={900} onClose={onClose} onSubmit={submit} loading={loading} busy={busy} dirty={!readOnly && dirty} readOnly={readOnly} submitLabel={draft?"Appliquer à la ligne":"Enregistrer"} canSubmit={Boolean(initial) && !uncertain && (creating || dirty)} error={error} onReload={!uncertain && error ? requestReload : null} className="admin-record-editor" storageKey="sauverndeko.admin.record.width">
    {confirmReload ? <div className="record-editor-error" role="alert"><span>Recharger la fiche et abandonner les modifications ?</span><div className="admin-record-inline"><ActionButton onClick={() => setConfirmReload(false)}>Continuer</ActionButton><ActionButton icon="refresh" onClick={() => setReload(value => value + 1)}>Recharger</ActionButton></div></div> : null}
    {!loading && initial ? <>
      <div className="admin-record-context"><span className="admin-record-symbol"><AppIcon name={type === "users" || type === "profiles" ? "user" : type === "roles" ? "shield" : type === "settings" ? "settings" : "document"}/></span><div><strong>{displayName || titleFor(type, "create")}</strong><small>{type === "users" || type === "profiles" ? values.EmailUser || "Compte utilisateur" : titleFor(type, "view")}</small></div>{record && type === "licences" ? <span className={"erp-status is-" + (record.ExpireeLicence ? "warning" : "neutral")}>{record.ExpireeLicence ? "Expirée" : "Licence #" + record.IdLicence}</span> : null}</div>
      {protectedSetting ? <p className="admin-record-protected"><AppIcon name="lock"/>Ce paramètre est protégé et reste en consultation.</p> : null}
      {!protectedSetting && systemSettingIdentityLocked ? <p className="admin-record-protected"><AppIcon name="lock"/>Identité du paramètre système conservée.</p> : null}
      <ConsultationTabs tabs={tabs} value={active} onChange={setActive} label="Rubriques de la fiche" idPrefix={prefix}/>
      {active === "trace" ? <section className="record-editor-section" role="tabpanel" id={prefix + "-panel-trace"} aria-labelledby={prefix + "-tab-trace"}><h3><AppIcon name="clock"/>Traçabilité</h3><dl className="admin-record-facts">{trace.map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{formatDate(value, { withTime: true, withSeconds: true })}</dd></div>)}</dl></section>
        : groups.filter(group => group.key === active).map(group => <section className="record-editor-section" role="tabpanel" id={prefix + "-panel-" + group.key} aria-labelledby={prefix + "-tab-" + group.key} key={group.key}><h3><AppIcon name={group.icon}/>{group.label}</h3><div className="record-editor-grid">{group.names.map(name => fields.find(field => field.name === name)).filter(Boolean).map(renderField)}</div></section>)}
    </> : null}
  </RecordEditorFrame>;
}
