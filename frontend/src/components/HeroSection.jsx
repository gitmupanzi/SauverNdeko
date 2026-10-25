import AppIcon from "./AppIcon";
export default function HeroSection({ onOpenSearch, onProducts, onExperts }) {
  return (
    <div className="desktop-overview-copy">
      <span className="desktop-kicker">Plateforme publique SauverNdeko</span>
      <h2>Retrouvez un produit, une structure ou un expert depuis une interface claire et rassurante.</h2>
      <div className="d-flex flex-wrap gap-2">
        <span className="badge text-bg-primary rounded-pill px-3 py-2">Recherche rapide</span>
        <span className="badge text-bg-light rounded-pill px-3 py-2 text-primary">Orientation fiable</span>
        <span className="badge text-bg-light rounded-pill px-3 py-2 text-primary">Parcours public</span>
      </div>
      <div className="desktop-overview-actions">
        <button className="desktop-primary d-inline-flex align-items-center gap-2" type="button" onClick={onOpenSearch}>
          <AppIcon name="search" size={18} />
          Lancer une recherche
        </button>
        <button className="desktop-secondary d-inline-flex align-items-center gap-2" type="button" onClick={onProducts}>
          <i className="bi bi-capsule" aria-hidden="true" />
          Voir les produits
        </button>
        <button className="desktop-secondary d-inline-flex align-items-center gap-2" type="button" onClick={onExperts}>
          <i className="bi bi-people" aria-hidden="true" />
          Voir les experts
        </button>
      </div>
    </div>
  );
}
