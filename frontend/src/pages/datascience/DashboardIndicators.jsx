import { useId, useState } from "react";
import AppIcon from "../../components/AppIcon";
import { formatCount } from "./analysisModel";
import "../logistique/DashboardLogistique.css";

function IndicatorGroup({ group, activeMetric, onMetric, detailsId }) {
  const id = useId();
  const [open, setOpen] = useState(true);
  return (
    <section className="erp-indicator-block" aria-labelledby={id + "-title"}>
      <header className="erp-block-header">
        <h2 id={id + "-title"}>
          <span className="erp-block-icon"><AppIcon name={group.icon} size={18} /></span>
          {group.label}
        </h2>
        <button type="button" aria-expanded={open} aria-controls={id + "-body"}
          aria-label={(open ? "Masquer " : "Afficher ") + group.label} onClick={() => setOpen(value => !value)}>
          <AppIcon name={open ? "chevron-up" : "chevron-down"} />
        </button>
      </header>
      <div id={id + "-body"} className="erp-block-body" hidden={!open}>
        <div className="erp-group-grid">
          {group.metrics.map(metric => {
            const selected = activeMetric?.groupKey === group.key && activeMetric.key === metric.key;
            const value = formatCount(metric.value);
            const content = (
              <>
                <span className="erp-kpi-icon"><AppIcon name={metric.icon} size={17} /></span>
                <span className="erp-kpi-copy"><span className="erp-kpi-label">{metric.label}</span></span>
                <strong>{metric.value === null ? (
                  <><span aria-hidden="true">{value}</span><span className="visually-hidden">Valeur indisponible</span></>
                ) : value}</strong>
              </>
            );
            return (
              <article key={metric.key} className={"erp-kpi is-" + metric.tone + (metric.canOpen === false ? " is-informative" : "")}>
                {metric.canOpen === false ? (
                  <div className="erp-kpi-main">{content}</div>
                ) : (
                  <button type="button" className="erp-kpi-main" aria-expanded={selected}
                    aria-controls={selected ? detailsId : undefined}
                    aria-label={metric.label + " · " + (metric.value === null ? "Valeur indisponible" : value)}
                    onClick={event => onMetric(group.key, metric, event.currentTarget)}>
                    {content}
                    <AppIcon name="chevron-right" size={12} className="erp-kpi-chevron" />
                  </button>
                )}
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}

export default function DashboardIndicators({ groups, activeMetric, onMetric, detailsId }) {
  if (!groups.length) return null;
  return (
    <div className={"erp-dashboard-sections" + (groups.length === 1 ? " is-single-column" : "")}>
      {groups.map(group => (
        <IndicatorGroup key={group.key} group={group} activeMetric={activeMetric} onMetric={onMetric} detailsId={detailsId} />
      ))}
    </div>
  );
}
