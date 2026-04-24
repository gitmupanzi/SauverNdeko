import { useLocation } from "react-router-dom";
import ProductCard from "../components/ProductCard";
import PublicTable from "../components/PublicTable";

export default function Products({ products, onNavigate }) {
  const location = useLocation();
  const focusId = location.state?.focusId;
  const featuredProduct = products.find((item) => item.id === focusId) || products[0];

  const columns = [
    { key: "name", label: "Nom du produit" },
    { key: "reference", label: "Référence" },
    { key: "price", label: "Prix de vente" },
    { key: "availability", label: "Disponibilité" },
    { key: "observation", label: "Observation" },
  ];

  return (
    <div className="page-shell page-products">
      <section className="page-hero-card">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Catalogue public</span>
          <h2>Produits et articles</h2>
          <p>
            Consultez uniquement les informations publiques utiles à l’orientation: nom du produit,
            référence, prix de vente, disponibilité et observation courte.
          </p>
        </div>
        <button className="secondary-action" type="button" onClick={() => onNavigate("/pharmacies")}>
          Voir les pharmacies
        </button>
      </section>

      {featuredProduct ? (
        <section className="page-highlight-grid">
          <article className="product-focus-card">
            <div className="product-focus-image">
              <img src={featuredProduct.photo || "/illustration-produits.svg"} alt={featuredProduct.name} />
            </div>
            <div className="product-focus-meta">
              <strong>{featuredProduct.name}</strong>
              <span>{featuredProduct.price}</span>
              <small>{featuredProduct.availability}</small>
            </div>
          </article>

          <article className="detail-block">
            <div className="d-flex align-items-center gap-2 mb-2">
              <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis">Observation</span>
            </div>
            <p>{featuredProduct.observation}</p>
          </article>
        </section>
      ) : null}

      <section className="cards-grid">
        {products.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </section>

      <section className="page-table-section">
        <div className="section-head">
          <h3>Vue tabulaire</h3>
          <p>Cette vue reste limitée aux champs publics. Aucun prix d’achat ni stock exact n’est exposé.</p>
        </div>
        <PublicTable columns={columns} rows={products} emptyMessage="Aucun produit public disponible pour le moment." />
      </section>
    </div>
  );
}
