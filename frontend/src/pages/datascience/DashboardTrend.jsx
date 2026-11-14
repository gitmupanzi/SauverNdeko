import AppIcon from "../../components/AppIcon";
import ListState from "../../components/ListState";
import { formatCount, monthLabel } from "./analysisModel";
import "./DashboardTrend.css";

const DEMANDS = { key: "demandes", label: "Demandes et besoins" };
const RESEARCH = { key: "recherches", label: "Recherches déclarées" };
const TOP = 6;
const BOTTOM = 94;

function chartTicks(peak) {
  const interval = Math.max(1, peak / 4);
  const magnitude = 10 ** Math.floor(Math.log10(interval));
  const step = [1, 2, 5, 10].map(factor => magnitude * factor).find(value => value >= interval);
  const divisions = Math.max(1, Math.ceil(peak / step));
  return Array.from({ length: divisions + 1 }, (_, index) => index * step);
}

export default function DashboardTrend({ points, showResearch, onMonth, detailsId }) {
  const series = showResearch ? [DEMANDS, RESEARCH] : [DEMANDS];
  const hasPublished = point => series.some(({ key }) => point[key] !== null);
  const peak = Math.max(0, ...points.flatMap(point => series.map(({ key }) => point[key] ?? 0)));
  const ticks = chartTicks(peak);
  const maximum = ticks[ticks.length - 1];
  const ordinate = value => BOTTOM - (BOTTOM - TOP) * value / maximum;
  const abscissa = index => 100 * (index + 0.5) / points.length;

  return (
    <section className="data-science-panel" aria-label="Évolution mensuelle">
      <header className="data-science-panel-header">
        <div>
          <h2><AppIcon name="chart" /> Évolution mensuelle</h2>
          <p>Volumes dans les groupes publiés. Sélectionnez un mois pour afficher son détail.</p>
        </div>
      </header>
      {!points.some(hasPublished) ? <ListState title="Aucun mois avec des données publiées" icon="chart" /> : (
        <>
          <ul className="data-science-legend" aria-label="Légende">
            {series.map(({ key, label }) => <li key={key}><i aria-hidden="true" className={"data-science-trend-" + key} />{label}</li>)}
          </ul>
          <div className="data-science-chart-scroll" role="region" aria-label="Volumes mensuels" tabIndex={0}>
            <div className="data-science-trend" style={{
              "--trend-min-width": points.length * 64 + "px",
              "--trend-axis-width": formatCount(maximum).length + 2 + "ch",
            }}>
              <div className="data-science-trend-axis" aria-hidden="true">
                {ticks.map(value => <span key={value} style={{ top: ordinate(value) + "%" }}>{formatCount(value)}</span>)}
              </div>
              <div className="data-science-trend-plot" style={{ "--trend-months": points.length }}>
                <svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true" focusable="false">
                  {ticks.map(value => <line key={value} className="data-science-trend-gridline" x1={0}
                    y1={ordinate(value)} x2={100} y2={ordinate(value)} vectorEffect="non-scaling-stroke" />)}
                  {series.map(({ key }) => {
                    const path = points.map((point, index) => {
                      if (point[key] === null) return "";
                      const command = index === 0 || points[index - 1][key] === null ? "M" : "L";
                      return command + abscissa(index) + " " + ordinate(point[key]);
                    }).join(" ");
                    return <path key={key} className={"data-science-trend-" + key} d={path} vectorEffect="non-scaling-stroke" />;
                  })}
                </svg>
                {points.map((point, index) => {
                  const month = monthLabel(point.mois);
                  const values = series.map(({ key, label }) => label + " " +
                    (point[key] === null ? "non publié" : formatCount(point[key]))).join(" · ");
                  return (
                    <div key={point.mois} className="data-science-trend-month">
                      {hasPublished(point) ? (
                        <button type="button" aria-controls={detailsId} aria-label={month + " · " + values} title={values}
                          onClick={event => onMonth(point.mois, event.currentTarget)}>
                          <span>{month}</span>
                        </button>
                      ) : <span className="data-science-trend-gap">{month}<span className="visually-hidden"> · aucune donnée publiée</span></span>}
                      {series.map(({ key }) => point[key] === null ? null : (
                        <i key={key} className={"data-science-trend-" + key}
                          style={{ left: abscissa(index) + "%", top: ordinate(point[key]) + "%" }} aria-hidden="true" />
                      ))}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </>
      )}
    </section>
  );
}
