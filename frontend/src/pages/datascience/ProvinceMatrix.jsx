import { useId, useState } from "react";
import AppIcon from "../../components/AppIcon";
import ListState from "../../components/ListState";
import SearchSelect from "../../components/SearchSelect";
import { formatCount, monthLabel, periodMonths, publishedOptions } from "./analysisModel";
import { natureLabel, sourceLabel } from "./DemandSeries";

function comparisonLabel(row) {
  return [
    row.condition === null ? row.produitLibelle : row.pathologieLibelle,
    sourceLabel(row),
    natureLabel(row),
  ].join(" · ");
}

export function provinceMatrix(rows, selection, period) {
  const comparison = rows.filter(row => row.territory !== null).map(row => ({
    ...row, comparison: [row.category, row.condition, row.source, row.nature],
  }));
  const options = publishedOptions(comparison, "comparison", comparisonLabel);
  const active = options.some(option => option.value === selection) ? selection : options[0]?.value;
  const provinces = new Map();
  for (const row of comparison) {
    if (JSON.stringify(row.comparison) !== active) continue;
    if (!provinces.has(row.territory)) provinces.set(row.territory, { label: row.territoireLibelle, months: new Map() });
    provinces.get(row.territory).months.set(row.mois, row);
  }
  const months = periodMonths(period);
  const collator = new Intl.Collator("fr");
  return {
    options, active, months,
    provinces: [...provinces.entries()]
      .sort(([, left], [, right]) => collator.compare(left.label, right.label))
      .map(([id, province]) => ({
        id, label: province.label, cells: months.map(month => province.months.get(month) ?? null),
      })),
  };
}

export default function ProvinceMatrix({ rows, period, measures, onMonth }) {
  const prefix = useId();
  const [selection, setSelection] = useState("");
  const [metric, setMetric] = useState(null);
  const { options, active, months, provinces } = provinceMatrix(rows, selection, period);
  const measure = measures.find(item => item.key === metric) || measures[0];
  let maximum = 1;
  for (const { cells } of provinces) {
    for (const cell of cells) maximum = Math.max(maximum, cell?.[measure.key] ?? 0);
  }

  return (
    <section className="data-science-panel" aria-labelledby={prefix + "-title"}>
      <header className="data-science-panel-header">
        <div>
          <h2 id={prefix + "-title"}><AppIcon name="dashboard" /> Matrice par mois et province</h2>
          <p>Comparez une même catégorie ou un même terme entre provinces pour les mois choisis.</p>
        </div>
      </header>
      {!provinces.length ? (
        <ListState title="Aucune province publiée pour ces filtres" icon="chart" />
      ) : (
        <>
          <div className="data-science-filters data-science-matrix-filters">
            <label className="data-science-field" htmlFor={prefix + "-series"}>
              <span>Série à comparer</span>
              <SearchSelect id={prefix + "-series"} label="Série à comparer" options={options} value={active} onChange={setSelection} />
            </label>
            <label className="data-science-field" htmlFor={prefix + "-measure"}>
              <span>Mesure à afficher</span>
              <SearchSelect id={prefix + "-measure"} label="Mesure à afficher" options={measures.map(({ key, label }) => ({ value: key, label }))}
                value={measure.key} onChange={setMetric} />
            </label>
          </div>
          <div className="data-science-matrix-scroll" role="region" aria-label="Matrice des valeurs publiées" tabIndex={0}>
            <table className="data-science-matrix">
              <thead>
                <tr><th scope="col">Province</th>{months.map(month => <th scope="col" key={month}>{monthLabel(month)}</th>)}</tr>
              </thead>
              <tbody>
                {provinces.map(({ id, label, cells }) => (
                  <tr key={id}>
                    <th scope="row">{label}</th>
                    {cells.map((cell, index) => {
                      if (!cell) return <td key={months[index]} className="data-science-matrix-unpublished"><abbr title="Cellule non publiée">n. p.</abbr></td>;
                      const value = cell[measure.key];
                      const accessible = value === null ? "Valeur indisponible" : formatCount(value);
                      const intensity = value ? Math.round(10 + 35 * value / maximum) : 0;
                      return (
                        <td key={months[index]}>
                          <button type="button" className="data-science-matrix-value" style={{ "--matrix-intensity": intensity + "%" }}
                            aria-label={label + " · " + monthLabel(cell.mois) + " · " + measure.label + " · " + accessible}
                            onClick={() => onMonth(cell.mois, cell.seriesKey)}>{formatCount(value)}</button>
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="data-science-reading-note">n. p. = cellule non publiée · — = mesure indisponible · 0 = zéro publié</p>
        </>
      )}
    </section>
  );
}
