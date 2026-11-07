import { Link } from "react-router-dom";
import AppIcon from "./AppIcon";
import useCatalogueSummary from "../hooks/useCatalogueSummary";
import { CATALOGUE_METRICS, formatCatalogueCount } from "../services/catalogueSummary";

export default function CatalogueMetrics({ destination }) {
  const { data, loading, error, retry } = useCatalogueSummary();
  return <section className="catalogue-metrics" aria-labelledby="catalogue-metrics-title">
    <div className="catalogue-metrics-heading">
      <h2 id="catalogue-metrics-title">À découvrir sur SauverNdeko</h2>
      <p>Les fiches partagées dans nos annuaires.</p>
    </div>
    <div className="catalogue-metric-grid" aria-busy={loading}>
      {CATALOGUE_METRICS.map(metric => {
        const count = data?.[metric.key];
        return <Link key={metric.key} className="catalogue-metric-card" to={destination(metric.path)}>
          <span className="catalogue-metric-icon" aria-hidden="true"><AppIcon name={metric.icon} size={25} /></span>
          <div className="catalogue-metric-content">
            <span className="catalogue-metric-count">
              {loading ? <span className="catalogue-metric-skeleton" aria-label="Chargement du total" /> : <strong className="catalogue-metric-value">{formatCatalogueCount(count)}</strong>}
              <span className="catalogue-metric-label">{metric.label}</span>
            </span>
            <span className="catalogue-metric-description">{count === 0 ? metric.empty : metric.description}</span>
          </div>
          <span className="catalogue-metric-arrow" aria-hidden="true"><AppIcon name="arrow-up-right" size={19} /></span>
        </Link>;
      })}
    </div>
    <div className="catalogue-metrics-feedback" aria-live="polite" aria-atomic="true">
      {loading ? <span>Chargement des indicateurs…</span> : error ? <div className="catalogue-metrics-error"><span>Les indicateurs sont momentanément indisponibles.</span><button type="button" onClick={retry}><AppIcon name="refresh" size={14} />Réessayer</button></div> : <span>Totaux des fiches publiées ; la disponibilité reste à confirmer auprès des organisations.</span>}
    </div>
  </section>;
}
