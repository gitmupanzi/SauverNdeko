import {categoricalKey} from "../../utils/categoricalValues";

/** Saisie en mémoire : aucune ligne n'est écrite avant la validation du lot. */
export const REFERENCE_BATCH_MAX = 200;
export const REFERENCE_VISIBILITY = {
  VisibleAll: "Visibilité générale", VisibleArticle: "Articles", VisibleCmd: "Bons de stock",
  VisibleFacture: "Factures", VisibleUsers: "Utilisateurs", VisibleVoie: "Voies d’accès",
  VisibleNiveau_2: "Niveau territorial 2", VisibleNiveau_3: "Niveau territorial 3",
  VisibleNiveau_4: "Niveau territorial 4", VisibleNiveau_5: "Niveau territorial 5",
};
export const BATCH_FIELDS = {
  categories: ["NomCategorieGenerique", "ModuleCategorieGenerique", "ValideCategorieGenerique"],
  values: ["NomGenerique", "AbrGenerique", "ObsGenerique", "ValideGenerique", ...Object.keys(REFERENCE_VISIBILITY)],
};
export const referenceBatchId = () => globalThis.crypto?.randomUUID?.() || "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, char => {
  const random = Math.floor(Math.random() * 16); return (char === "x" ? random : (random & 3) | 8).toString(16);
});
export function referenceBatchRow(kind, values = {}) {
  return kind === "categories"
    ? { clientRowId: referenceBatchId(), NomCategorieGenerique: "", ModuleCategorieGenerique: "", ValideCategorieGenerique: true, ...values }
    : { clientRowId: referenceBatchId(), NomGenerique: "", AbrGenerique: "", ObsGenerique: "", ValideGenerique: true, ...Object.fromEntries(Object.keys(REFERENCE_VISIBILITY).map(key => [key, true])), ...values };
}
export const referenceDuplicateKey = value => categoricalKey(value).replace(/\s+/gu, " ");
const headerKey = value => referenceDuplicateKey(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]/g, "");
const HEADER_ALIASES = {
  categorie: "NomCategorieGenerique", nomcategorie: "NomCategorieGenerique", nomdelacategorie: "NomCategorieGenerique",
  modules: "ModuleCategorieGenerique", module: "ModuleCategorieGenerique", modulesassocies: "ModuleCategorieGenerique",
  libelle: "NomGenerique", nom: "NomGenerique", valeur: "NomGenerique",
  abreviation: "AbrGenerique", code: "AbrGenerique", abreviationoucode: "AbrGenerique",
  information: "ObsGenerique", informations: "ObsGenerique", informationscomplementaires: "ObsGenerique", observation: "ObsGenerique", observations: "ObsGenerique",
};

/** TSV Excel : cellules entre guillemets, sauts de ligne et guillemets doublés. */
export function parseExcelTsv(text) {
  if (typeof text !== "string" || !text.trim()) return [];
  if (text.length > 2_000_000) throw new Error("Le collage dépasse la taille autorisée.");
  const source = text.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n"), rows = [];
  let row = [], cell = "", quoted = false, closed = false;
  for (let index = 0; index < source.length; index++) {
    const char = source[index];
    if (quoted) {
      if (char === '"' && source[index + 1] === '"') { cell += '"'; index++; }
      else if (char === '"') { quoted = false; closed = true; }
      else cell += char;
      continue;
    }
    if (char === '"' && cell === "" && !closed) { quoted = true; continue; }
    if (closed && char !== "\t" && char !== "\n") throw new Error("Vérifiez les guillemets du collage Excel.");
    if (char === "\t" || char === "\n") {
      row.push(cell); cell = ""; closed = false;
      if (char === "\n") { rows.push(row); row = []; }
    } else cell += char;
  }
  if (quoted) throw new Error("Une cellule entre guillemets n’est pas terminée.");
  row.push(cell); rows.push(row);
  return rows.filter(cells => cells.some(value => value.trim() !== ""));
}
export function referenceBatchFromExcel(kind, text, { hasHeaders = false } = {}) {
  return referenceBatchFromMatrix(kind, parseExcelTsv(text), { hasHeaders });
}
/** Les fichiers et le collage remplissent le même brouillon, sans écriture. */
export function referenceBatchFromMatrix(kind, cells, { hasHeaders = true, maxRows = REFERENCE_BATCH_MAX } = {}) {
  if (!Array.isArray(cells) || cells.some(row => !Array.isArray(row) || row.some(value => typeof value !== "string"))) throw new Error("Le fichier reçu ne contient pas un tableau valide.");
  const matrix = cells.map(row => [...row]), fields = BATCH_FIELDS[kind];
  if (!fields) throw new Error("Ce type de saisie n’est pas disponible.");
  if (!matrix.length) return [];
  let columns = fields;
  if (hasHeaders) {
    const state = kind === "categories" ? "ValideCategorieGenerique" : "ValideGenerique";
    columns = matrix.shift().map(value => {
      const normalized = headerKey(value);
      const direct = fields.find(key => headerKey(key) === normalized);
      const key = direct || (["actif", "active", "etat", "valide", "categorieactive"].includes(normalized) ? state : HEADER_ALIASES[normalized])
        || Object.entries(REFERENCE_VISIBILITY).find(([, label]) => headerKey(label) === normalized)?.[0];
      if (!key || !fields.includes(key)) throw new Error("En-tête non reconnu : « " + value + " ».");
      return key;
    });
    if (new Set(columns).size !== columns.length) throw new Error("Un même en-tête apparaît plusieurs fois.");
    if (!columns.includes(fields[0])) throw new Error("Le collage doit contenir la colonne « " + (kind === "categories" ? "Catégorie" : "Libellé") + " ».");
  }
  if (matrix.length > maxRows) throw new Error("Limitez la saisie à " + maxRows + " lignes.");
  const booleanValue = (value, key) => {
    const token = referenceDuplicateKey(value);
    if (["oui", "true", "vrai", "1", "actif", "active"].includes(token)) return true;
    if (["non", "false", "faux", "0", "inactif", "inactive"].includes(token)) return false;
    if (key.startsWith("Visible") && ["null", "non renseigné", "non renseigne"].includes(token)) return null;
    return value;
  };
  return matrix.map((cells, index) => {
    if (cells.length > columns.length) throw new Error("La ligne " + (index + (hasHeaders ? 2 : 1)) + " contient trop de colonnes.");
    const values = {};
    cells.forEach((value, column) => {
      const field = columns[column];
      if (field.startsWith("Visible") || field.startsWith("Valide")) { if (value.trim() !== "") values[field] = booleanValue(value, field); }
      else values[field] = value;
    });
    return referenceBatchRow(kind, values);
  });
}
export function validateReferenceBatch(kind, rows, { categoryId = "", categories = [], scope = "global", scopeValue = "" } = {}) {
  const header = {}, errors = {}, fields = BATCH_FIELDS[kind], name = fields?.[0];
  if (!fields) return { header: { kind: "Ce type de saisie n’est pas disponible." }, rows: {} };
  if (!rows.length) header.rows = "Ajoutez au moins une ligne.";
  if (rows.length > REFERENCE_BATCH_MAX) header.rows = "Limitez la saisie à " + REFERENCE_BATCH_MAX + " lignes.";
  if (scope === "entity" && !/^[1-9]\d*$/.test(String(scopeValue))) header.scopeValue = "Choisissez une entreprise dans l’en-tête du module.";
  if (kind === "values") {
    const category = categories.find(item => String(item.ID_CategorieGenerique) === String(categoryId));
    if (!category || category.ValideCategorieGenerique === false) header.categoryId = "Choisissez une catégorie active.";
    else if (category.IdEntiteFk != null && (scope !== "entity" || String(category.IdEntiteFk) !== String(scopeValue))) header.categoryId = "Cette catégorie appartient à une autre portée.";
  }
  const duplicateFields = kind === "categories" ? [name] : [name, "AbrGenerique"];
  const seen = Object.fromEntries(duplicateFields.map(field => [field, new Map()]));
  for (const row of rows) {
    const issues = {};
    if (!String(row[name] ?? "").trim()) issues[name] = "Renseignez " + (kind === "categories" ? "le nom de la catégorie." : "le libellé.");
    for (const field of fields) {
      const value = row[field];
      const maximum = field === "ModuleCategorieGenerique" ? 4000 : field === "ObsGenerique" ? 20000 : 255;
      if (field.startsWith("Visible") ? value !== null && typeof value !== "boolean" : field.startsWith("Valide") ? typeof value !== "boolean" : typeof value !== "string" || value.length > maximum) issues[field] = field.startsWith("Visible") || field.startsWith("Valide") ? "Choisissez Oui ou Non." : "Utilisez au maximum " + maximum + " caractères.";
    }
    for (const field of duplicateFields) {
      const key = referenceDuplicateKey(row[field]);
      if (!key) continue;
      if (seen[field].has(key)) {
        issues[field] = "Cette valeur apparaît déjà dans le panier.";
        const previous = seen[field].get(key);
        errors[previous] = { ...(errors[previous] || {}), [field]: "Cette valeur apparaît déjà dans le panier." };
      } else seen[field].set(key, row.clientRowId);
    }
    if (Object.keys(issues).length) errors[row.clientRowId] = { ...(errors[row.clientRowId] || {}), ...issues };
  }
  return { header, rows: errors };
}
export function referenceBatchPayload(kind, rows, { categoryId, scope = "global", scopeValue, requestId = referenceBatchId() } = {}) {
  return { requestId, scope, ...(scope === "entity" ? { scopeValue: Number(scopeValue) } : {}), ...(kind === "values" ? { categoryId: Number(categoryId) } : {}),
    rows: rows.map(row => ({ clientRowId: row.clientRowId, ...Object.fromEntries(BATCH_FIELDS[kind].map(field => [field, typeof row[field] === "string" ? row[field].trim() : row[field]])) })) };
}
