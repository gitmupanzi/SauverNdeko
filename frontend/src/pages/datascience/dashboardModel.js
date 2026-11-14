import { periodMonths } from "./analysisModel";

function sumPublished(rows, key) {
  if (!rows.length || rows.some(row => row[key] === null)) return null;
  const total = rows.reduce((sum, row) => sum + row[key], 0);
  return Number.isSafeInteger(total) ? total : null;
}

function distinctCount(rows, key) {
  return new Set(rows.map(row => row[key]).filter(value => value !== null)).size;
}

export function dashboardAnalysis(rows, period, showResearch) {
  const demands = rows.filter(row => row.nature !== "recherche");
  const research = showResearch ? rows.filter(row => row.nature === "recherche") : [];
  const visible = [...demands, ...research];
  const groups = [];
  const populations = new Map();

  function metric(key, label, icon, tone, value, population, measure) {
    populations.set(key, { rows: population, measure });
    return { key, label, icon, tone, value, canOpen: value !== null && population.length > 0 };
  }

  function volume(key, label, icon, tone, population, measure = key) {
    return metric(key, label, icon, tone, sumPublished(population, measure), population, measure);
  }

  function coverage(key, label, icon, tone, dimension) {
    return metric(key, label, icon, tone, visible.length ? distinctCount(visible, dimension) : null,
      visible.filter(row => row[dimension] !== null));
  }

  const unmet = demands.filter(row => row.nature === "besoin_sans_resultat");
  groups.push({ key: "demandes", label: "Demandes et besoins", icon: "clipboard", metrics: [
    volume("demandes", "Demandes et besoins déclarés", "clipboard", "blue", demands),
    volume("besoins", "Besoins après une recherche sans résultat", "search", "amber", unmet, "demandes"),
    volume("satisfaites", "Demandes satisfaites", "check-circle", "teal", demands),
    volume("nonSatisfaites", "Demandes non satisfaites", "alert", "coral", demands),
  ] });
  if (showResearch) {
    groups.push({ key: "recherches", label: "Recherches déclarées", icon: "search", metrics: [
      volume("recherches", "Recherches déclarées", "search", "purple", research),
      volume("avecResultat", "Avec résultat", "check-circle", "teal", research),
      volume("sansResultat", "Sans résultat", "alert", "amber", research),
    ] });
  }
  groups.push({ key: "couverture", label: "Couverture des données", icon: "globe", metrics: [
    coverage("provinces", "Provinces représentées", "globe", "teal", "territory"),
    coverage("categories", "Catégories de produits représentées", "tag", "purple", "category"),
    ...(showResearch ? [coverage("conditions", "Termes de maladie représentés", "search", "slate", "condition")] : []),
  ] });
  const points = periodMonths(period).map(mois => ({
    mois,
    demandes: sumPublished(demands.filter(row => row.mois === mois), "demandes"),
    recherches: sumPublished(research.filter(row => row.mois === mois), "recherches"),
  }));
  return { groups, points, populations };
}
