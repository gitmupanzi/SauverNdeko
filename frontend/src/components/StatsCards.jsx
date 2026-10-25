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
        <strong>{health.loading ? "Chargement…" : health.ok ? "À jour" : "Indisponible"}</strong>
        <span>{health.ok ? "Catalogue actualisé" : "Réessayez dans un instant"}</span>
      </article>
    </div>
  );
}
