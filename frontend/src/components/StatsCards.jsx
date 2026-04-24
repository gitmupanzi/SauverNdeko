export default function StatsCards({ stats, health }) {
  return (
    <div className="desktop-overview-stats">
      <article>
        <strong>{stats.productsCount}</strong>
        <span>Produits visibles</span>
      </article>
      <article>
        <strong>{stats.pharmaciesCount}</strong>
        <span>Pharmacies et dépôts</span>
      </article>
      <article>
        <strong>{stats.expertsCount}</strong>
        <span>Experts disponibles</span>
      </article>
      <article>
        <strong>{health.ok ? "API OK" : "MODE DÉMO"}</strong>
        <span>{health.ok ? "Données publiques synchronisées" : "Données mock utilisées temporairement"}</span>
      </article>
    </div>
  );
}
