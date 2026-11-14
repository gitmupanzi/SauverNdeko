export const DEMANDS_ANALYSIS_PATH = "/api/data-science/indicateurs/demandes";
export const DEMAND_MEASURES = [
  { key: "demandes", label: "Demandes", color: "requests" },
  { key: "satisfaites", label: "Satisfaites", color: "fulfilled" },
  { key: "nonSatisfaites", label: "Non satisfaites", color: "unfulfilled" },
];
export const SEARCH_MEASURES = [
  { key: "recherches", label: "Recherches déclarées", color: "requests" },
  { key: "avecResultat", label: "Avec résultat", color: "fulfilled" },
  { key: "sansResultat", label: "Sans résultat", color: "unfulfilled" },
];
export const STOCK_MEASURES = [
  { key: "observationsStock", label: "Observations de stock" },
  { key: "ruptures", label: "Ruptures" },
  { key: "reapprovisionnements", label: "Réapprovisionnements" },
];
export const SOURCE_LABELS = { product: "Produits", expert: "Professionnels", structure: "Structures" };

const monthPattern = /^([1-9]\d{3})-(0[1-9]|1[0-2])$/;
const monthFormatter = new Intl.DateTimeFormat("fr-CD", { month: "short", year: "numeric", timeZone: "UTC" });
const reportDateFormatter = new Intl.DateTimeFormat("sv-SE", {
  timeZone: "Africa/Kinshasa", year: "numeric", month: "2-digit", day: "2-digit",
});
const numberFormatter = new Intl.NumberFormat("fr-CD");
const collation = new Intl.Collator("fr", { numeric: true });

function monthIndex(value) {
  const match = monthPattern.exec(value);
  return match ? Number(match[1]) * 12 + Number(match[2]) - 1 : null;
}

export function periodError({ debut, fin }) {
  const start = monthIndex(debut);
  const end = monthIndex(fin);
  if (start === null || end === null) return "Indiquez les deux mois au format AAAA-MM.";
  if (end < start) return "Le mois de fin doit suivre le mois de début ou lui être égal.";
  if (end - start >= 12) return "Sélectionnez une période de 12 mois maximum.";
  return "";
}

export function reportToday(now = new Date()) {
  return reportDateFormatter.format(now);
}

function isCalendarDate(value) {
  if (!/^[1-9]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/.test(value)) return false;
  const date = new Date(value + "T00:00:00Z");
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

export function reportDatePeriod({ debut, fin }, today = reportToday()) {
  if (!isCalendarDate(debut) || !isCalendarDate(fin)) {
    return { error: "Indiquez deux dates valides." };
  }
  if (debut > fin) return { error: "La date de début doit précéder la date de fin ou lui être égale." };
  if (fin > today) return { error: "La date de fin doit être aujourd’hui ou dans le passé." };
  const period = { debut: debut.slice(0, 7), fin: fin.slice(0, 7) };
  const error = periodError(period);
  return error ? { error } : { period, error: "" };
}

export function reportPeriodDates({ debut, fin }, today = reportToday()) {
  const [year, month] = fin.split("-").map(Number);
  const lastDay = new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10);
  return { debut: debut + "-01", fin: fin === today.slice(0, 7) ? today : lastDay };
}

export function analysisPath(period, view) {
  const params = new URLSearchParams(period || {});
  if (view) params.set("vue", view);
  const query = params.toString();
  return query ? DEMANDS_ANALYSIS_PATH + "?" + query : DEMANDS_ANALYSIS_PATH;
}

export function monthLabel(value) {
  if (monthIndex(value) === null) return "—";
  return monthFormatter.format(new Date(value + "-01T00:00:00Z"));
}

export function periodMonths(period) {
  if (!period || periodError(period)) return [];
  const start = monthIndex(period.debut);
  const end = monthIndex(period.fin);
  return Array.from({ length: end - start + 1 }, (_, offset) => {
    const month = start + offset;
    return Math.floor(month / 12) + "-" + String(month % 12 + 1).padStart(2, "0");
  });
}

const measureKeys = [...DEMAND_MEASURES, ...SEARCH_MEASURES, ...STOCK_MEASURES].map(item => item.key);

function count(value) {
  if (typeof value === "string" && /^\d+$/.test(value)) value = Number(value);
  return Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function dimensionId(value) {
  return (typeof value === "string" && value) || Number.isSafeInteger(value) ? String(value) : null;
}

function dimensionLabel(value, fallback) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

export function formatCount(value) {
  return value === null ? "—" : numberFormatter.format(value);
}

export function analysisPayload(data) {
  if (!data || !data.periode || periodError(data.periode) || !Array.isArray(data.cellules)) return null;
  const scope = data.perimetre;
  if (scope && !(
    (scope.type === "global" && scope.entrepriseId === null)
    || (scope.type === "entreprise" && Number.isSafeInteger(scope.entrepriseId) && scope.entrepriseId > 0)
  )) return null;
  const rows = [];
  const keys = new Set();
  for (const cell of data.cellules) {
    if (!cell || !monthPattern.test(cell.mois) || cell.mois < data.periode.debut || cell.mois > data.periode.fin) return null;
    const category = dimensionId(cell.produitId);
    const territory = dimensionId(cell.territoireId);
    const condition = dimensionId(cell.pathologieId);
    const source = dimensionId(cell.source);
    const nature = dimensionId(cell.nature);
    const seriesKey = JSON.stringify([category, territory, source, nature, condition]);
    const key = seriesKey + ":" + cell.mois;
    if (keys.has(key)) return null;
    keys.add(key);
    const measures = Object.fromEntries(measureKeys.map(field => [field, count(cell[field])]));
    rows.push({
      key, seriesKey, mois: cell.mois, category, territory, source, nature, condition,
      produitLibelle: dimensionLabel(cell.produitLibelle, "Catégorie non renseignée"),
      territoireLibelle: dimensionLabel(cell.territoireLibelle, "Province non renseignée"),
      pathologieLibelle: dimensionLabel(cell.pathologieLibelle, "Terme non renseigné"),
      offrePubliee: typeof cell.offrePubliee === "boolean" ? cell.offrePubliee : null,
      ...measures,
    });
  }
  return {
    periode: data.periode,
    perimetre: scope || null,
    cellules: rows,
    seuilConfidentialite: count(data.seuilConfidentialite),
    rapprochementDisponible: data.rapprochementDisponible === true,
    associationMaladieProduitDisponible: data.associationMaladieProduitDisponible === true,
    collecteDisponible: data.statutCollecte !== "indisponible",
  };
}

export function publishedOptions(rows, key, label) {
  const options = new Map();
  for (const row of rows) {
    const value = JSON.stringify(row[key]);
    if (!options.has(value)) options.set(value, { value, label: label(row) });
  }
  return [...options.values()].sort((left, right) => collation.compare(left.label, right.label));
}

export function seriesRows(rows, key, period) {
  const byMonth = new Map(rows.filter(row => row.seriesKey === key).map(row => [row.mois, row]));
  return periodMonths(period).map(mois => ({ mois, row: byMonth.get(mois) || null }));
}
