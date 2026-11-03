export default function StatsCards({ stats, health }) {
  return (
    <div className="desktop-overview-stats">
      <article>
        <strong>{stats.productsCount}</strong>
        <span>Produits visibles</span>
      </article>
      <article>
        <strong>{stats.structuresCount ?? "—"}</strong>
        <span>Structures répertoriées</span>
      </article>
      <article>
        <strong>{stats.expertsCount}</strong>
        <span>Profils publiés</span>
      </article>
      <article>
        <strong>{health.loading ? "Chargement…" : health.ok ? "Accessible" : "Indisponible"}</strong>
        <span>{health.ok ? "Service de consultation" : "Réessayez dans un instant"}</span>
      </article>
    </div>
  );
}
