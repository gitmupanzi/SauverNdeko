import AppIcon from "../../components/AppIcon";
import ListState from "../../components/ListState";
import SearchSelect from "../../components/SearchSelect";
import { formatCount, monthLabel, publishedOptions, seriesRows, SOURCE_LABELS } from "./analysisModel";

export const NATURE_LABELS = {
  demande_suivie: "Demandes suivies",
  besoin_sans_resultat: "Besoins sans résultat",
  recherche: "Recherche déclarée",
};

export function sourceLabel(row) {
  return SOURCE_LABELS[row.source] || "Origine non renseignée";
}

export function natureLabel(row) {
  return NATURE_LABELS[row.nature] || "Nature non renseignée";
}

function seriesLabel(row) {
  const dimension = row.condition === null ? row.produitLibelle : row.pathologieLibelle;
  return [dimension, row.territoireLibelle, sourceLabel(row), natureLabel(row)].join(" · ");
}

export default function DemandSeries({ rows, period, measures, selected, onSelect, onMonth }) {
  const options = publishedOptions(rows, "seriesKey", seriesLabel);
  const effective = options.some(option => option.value === selected) ? selected : options[0]?.value;
  const key = effective ? JSON.parse(effective) : null;
  const points = key ? seriesRows(rows, key, period) : [];
  const measurements = points.flatMap(point => measures.map(({ key }) => point.row?.[key] ?? 0));
  const max = Math.max(1, ...measurements);
  const hasMeasures = points.some(point => point.row && measures.some(({ key }) => point.row[key] !== null));

  return (
    <section className="data-science-panel" aria-label="Évolution mensuelle">
      <header className="data-science-panel-header">
        <div>
          <h2><AppIcon name="chart" /> Évolution mensuelle</h2>
          <p>Choisissez une série pour suivre son évolution.</p>
        </div>
        {options.length > 1 && <SearchSelect label="Série à afficher" options={options} value={effective} onChange={onSelect} />}
      </header>
      {!hasMeasures ? <ListState title="Aucune mesure affichable pour cette série" icon="chart" /> : (
        <>
          <p className="data-science-series-name">{options.find(option => option.value === effective)?.label}</p>
          <ul className="data-science-legend" aria-label="Légende">
            {measures.map(({ key, label, color }) => <li key={key}><i aria-hidden="true" className={"data-science-tone-" + color} />{label}</li>)}
          </ul>
          <div className="data-science-chart-scroll" role="region" aria-label="Graphique des mesures par mois" tabIndex={0}>
            <div className="data-science-chart" style={{ "--data-science-months": points.length }}>
              {points.map(({ mois, row }) => {
                const label = monthLabel(mois);
                if (!row) return <div key={mois} className="data-science-chart-empty"><span>—</span><small>{label}</small></div>;
                const metrics = measures.map(measure => measure.label + " " + formatCount(row[measure.key]));
                return (
                  <button key={mois} type="button" aria-label={label + " · " + metrics.join(" · ")} title={metrics.join(" · ")} onClick={event => onMonth(mois, row.seriesKey, event.currentTarget)}>
                    <strong>{formatCount(row[measures[0].key])}</strong>
                    <span className="data-science-bars" aria-hidden="true">
                      {measures.map(({ key, color }) => (
                        <i key={key} className={row[key] === null ? "is-unavailable" : "data-science-tone-" + color} style={{ height: row[key] === null ? undefined : row[key] === 0 ? "2px" : Math.max(2, 100 * row[key] / max) + "%" }} />
                      ))}
                    </span>
                    <small>{label}</small>
                  </button>
                );
              })}
            </div>
          </div>
        </>
      )}
    </section>
  );
}
