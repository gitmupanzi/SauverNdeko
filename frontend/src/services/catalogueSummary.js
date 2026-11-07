// Ces totaux décrivent les fiches partagées, jamais le stock interne des entreprises.
export const CATALOGUE_METRICS = Object.freeze([
  { key: "productsCount", path: "/produits", icon: "box", label: "Offres de produits", description: "Des produits partagés par les entreprises.", empty: "Les prochaines offres apparaîtront ici." },
  { key: "expertsCount", path: "/experts", icon: "user", label: "Profils professionnels", description: "Des compétences et des services à découvrir.", empty: "Les prochains profils publiés apparaîtront ici." },
  { key: "structuresCount", path: "/pharmacies", icon: "building", label: "Structures et territoires", description: "Des établissements et des lieux référencés.", empty: "Les prochaines structures apparaîtront ici." },
]);

export function normalizeCatalogueSummary(payload) {
  if (payload?.success !== true || !payload.data || typeof payload.data !== "object") return null;
  const data = payload.data;
  if (!CATALOGUE_METRICS.every(({ key }) => Number.isSafeInteger(data[key]) && data[key] >= 0)) return null;
  if (typeof data.calculatedAt !== "string" || !Number.isFinite(Date.parse(data.calculatedAt))) return null;
  return Object.fromEntries([...CATALOGUE_METRICS.map(({ key }) => [key, data[key]]), ["calculatedAt", data.calculatedAt]]);
}

const countFormat = new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 });
export function formatCatalogueCount(value) {
  return Number.isSafeInteger(value) && value >= 0 ? countFormat.format(value) : "—";
}
