import {categoricalKey, sameCategory} from "../../utils/categoricalValues";
import {parseExcelTsv, referenceBatchId} from "../referentiels/referenceBatch";
import {caisseErrors, caisseOptions, caissePayload, caisseValues, cashboxOptions, validCaisseDate} from "./caisseModel";

export const MAX_CAISSE_BATCH_ROWS = 100;
export const CAISSE_BATCH_FIELDS = {
  caisses: ["NomCaisse", "IdDeviseFk", "IdTypeCaisseFk", "IdResponsableFk", "Actif", "motif"],
  ecritures: ["IdCaisseFk", "DatePaiement", "SensMouvement", "LibellePaiement", "MontantPaiement",
    "IdTypePaiementFk", "IdTiersFk", "ReferenceExterne", "ObsPaiement", "motif"],
  clotures: ["IdCaisseFk", "ClotureLe", "MontantCompte", "motif"],
};
export const CAISSE_BATCH_LABELS = {
  NomCaisse:"Nom de la caisse", IdDeviseFk:"Devise", IdTypeCaisseFk:"Type de caisse",
  IdResponsableFk:"Responsable", Actif:"État", IdCaisseFk:"Caisse", DatePaiement:"Date et heure",
  SensMouvement:"Mouvement", LibellePaiement:"Libellé", MontantPaiement:"Montant",
  IdTypePaiementFk:"Type d’opération", IdTiersFk:"Tiers", ReferenceExterne:"Référence",
  ObsPaiement:"Observations", ClotureLe:"Date et heure du comptage",
  MontantCompte:"Montant compté", motif:"Motif", _version:"Solde théorique",
};
const SENSES = [{value:"1",label:"Encaissement"},{value:"-1",label:"Décaissement"}];
const STATES = [{value:"true",label:"Active"},{value:"false",label:"Inactive"}];
const REFERENCE_FIELDS = {
  IdDeviseFk:"devises", IdTypeCaisseFk:"typesCaisses", IdResponsableFk:"responsables",
  IdTypePaiementFk:"typesPaiements", IdTiersFk:"tiers",
};
export const TEXT_LIMITS = {NomCaisse:160, LibellePaiement:255, ReferenceExterne:255, ObsPaiement:4000, motif:1000};
export const isBatchDate = key => key === "DatePaiement" || key === "ClotureLe";
export const isBatchAmount = key => key === "MontantCompte" || key === "MontantPaiement";
const header = value => categoricalKey(value).normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]/g,"");

export function caisseBatchChoices(field, references) {
  if (field === "IdCaisseFk") return cashboxOptions(references);
  if (field === "SensMouvement") return SENSES;
  if (field === "Actif") return STATES;
  if (REFERENCE_FIELDS[field]) {
    const optional = field !== "IdDeviseFk";
    return caisseOptions(references[REFERENCE_FIELDS[field]], optional ? "Non renseigné" : "Choisir…");
  }
  return null;
}

export function caisseBatchRow(kind, references, defaults = {}, imported) {
  const values = {...caisseValues(kind, null, references, defaults), ...imported};
  return {clientRowId:referenceBatchId(), values, pristine:!imported,
    balance:null};
}

export function caisseBatchErrors(kind, rows, references) {
  const issues = {};
  const cashboxLines = new Map();
  for (const row of rows) {
    const values = row.values;
    const errors = caisseErrors(kind, values);
    if (kind !== "clotures") delete errors.motif;
    for (const field of CAISSE_BATCH_FIELDS[kind]) {
      const value = String(values[field] ?? "");
      const choices = caisseBatchChoices(field, references);
      if (value && choices && !choices.some(option => option.value === value && !option.disabled)) {
        errors[field] = "Choisissez une valeur disponible.";
      }
      if (TEXT_LIMITS[field] && value.trim().length > TEXT_LIMITS[field]) {
        errors[field] = "Maximum " + TEXT_LIMITS[field] + " caractères.";
      }
    }
    if (kind === "clotures" && values.IdCaisseFk && !errors.IdCaisseFk) {
      if (!row.balance?.version) {
        errors._version = "Vérifiez le solde à la date du comptage.";
      } else if (Number(row.balance.record?.NombreBrouillons) > 0) {
        errors._version = "Traitez les brouillons avant de clôturer cette caisse.";
      }
      const first = cashboxLines.get(values.IdCaisseFk);
      if (first) {
        const message = "Une seule clôture par caisse dans ce panier.";
        errors.IdCaisseFk = message;
        (issues[first] ||= {}).IdCaisseFk = message;
      }
      cashboxLines.set(values.IdCaisseFk, row.clientRowId);
    }
    if (Object.keys(errors).length) issues[row.clientRowId] = errors;
  }
  return issues;
}

export function caisseBatchPayload(kind, rows, valider, requestId = referenceBatchId()) {
  return {
    requestId,
    ...(kind === "ecritures" ? {valider} : {}),
    rows:rows.map(row => {
      const {data, motif, _version} = caissePayload(kind, row.values, {version:row.balance?.version});
      return {clientRowId:row.clientRowId, data, motif, ...(_version ? {_version} : {})};
    }),
  };
}

function resolveChoice(field, value, references) {
  const choices = caisseBatchChoices(field, references);
  if (!choices) return value;
  if (field === "Actif") {
    if (["oui", "actif", "active", "true", "1"].includes(categoricalKey(value))) return true;
    if (["non", "inactif", "inactive", "false", "0"].includes(categoricalKey(value))) return false;
    return value;
  }
  if (field === "SensMouvement") {
    if (sameCategory(value, "entrée") || sameCategory(value, "entree")) return "1";
    if (["sortie", "décaissement", "decaissement"].includes(categoricalKey(value))) return "-1";
  }
  const allowed = choices.filter(option => option.value && !option.disabled);
  const byId = allowed.find(option => option.value === value);
  if (byId) return byId.value;
  if (field === "IdCaisseFk") {
    const cashboxes = new Map((references.caisses || []).map(item => [String(item.IdCaisse), item]));
    const exact = allowed.filter(option => option.label === value || cashboxes.get(option.value)?.CodeCaisse === value);
    if (exact.length) return exact.length === 1 ? exact[0].value : value;
    const matches = allowed.filter(option => sameCategory(cashboxes.get(option.value)?.NomCaisse, value));
    return matches.length === 1 ? matches[0].value : value;
  }
  const matches = allowed.filter(option => sameCategory(option.label, value));
  return matches.length === 1 ? matches[0].value : value;
}

function excelValue(field, raw, references) {
  const value = raw.trim();
  if (!value) return "";
  if (isBatchAmount(field) && /^\d{1,3}(?:[ \u00a0\u202f]\d{3})+(?:[,.]\d{1,2})?$/.test(value)) {
    return value.replace(/[ \u00a0\u202f]/g,"");
  }
  if (isBatchDate(field)) {
    const date = /^(\d{2})\/(\d{2})\/(\d{4})[ T](\d{2}:\d{2}(?::\d{2})?)$/.exec(value);
    if (date) return date[3]+"-"+date[2]+"-"+date[1]+"T"+date[4];
    const iso = value.replace(" ", "T");
    return validCaisseDate(iso) ? iso : value;
  }
  return resolveChoice(field, value, references);
}

export function caisseBatchPaste(kind, text, references, defaults) {
  return caisseBatchFromMatrix(kind, parseExcelTsv(text), references, defaults);
}

export function caisseBatchFromMatrix(kind, cells, references, defaults) {
  if (!Array.isArray(cells) || !cells.every(row => Array.isArray(row) && row.every(cell => typeof cell === "string"))) {
    throw new Error("Le contenu du fichier Excel n’a pas pu être lu.");
  }
  const [head = [], ...data] = cells;
  if (!data.length) throw new Error("Collez les en-têtes et au moins une ligne.");
  if (data.length > MAX_CAISSE_BATCH_ROWS) throw new Error("Le panier accepte au maximum "+MAX_CAISSE_BATCH_ROWS+" lignes.");
  const fields = CAISSE_BATCH_FIELDS[kind];
  const aliases = new Map(kind === "caisses" ? [["caisse", "NomCaisse"], ["active", "Actif"]] : []);
  const columns = head.map(cell => aliases.get(header(cell)) || fields.find(field => header(field) === header(cell) || header(CAISSE_BATCH_LABELS[field]) === header(cell)));
  if (!columns.length || columns.some(field => !field) || new Set(columns).size !== columns.length) {
    throw new Error("Vérifiez les noms des colonnes et retirez les en-têtes en double.");
  }
  return data.map((cells, index) => {
    if (cells.slice(columns.length).some(cell => cell.trim())) throw new Error("La ligne "+(index+2)+" contient une cellule sans en-tête.");
    const values = Object.fromEntries(columns.map((field, position) => [field, excelValue(field, cells[position] || "", references)]));
    // Un comptage ou une opération collée doit porter sa propre date.
    const dateKey = kind === "clotures" ? "ClotureLe" : "DatePaiement";
    if (kind !== "caisses") values[dateKey] ||= "";
    if (kind === "caisses" && values.Actif === "") delete values.Actif;
    return caisseBatchRow(kind, references, defaults, values);
  });
}
