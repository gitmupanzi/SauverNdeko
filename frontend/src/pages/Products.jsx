import { useLocation } from "react-router-dom";
import ProductCard from "../components/ProductCard";
import ArticlePhoto from "../components/ArticlePhoto";
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
    { key: "company", label: "Entreprise" },
    { key: "address", label: "Adresse" },
    { key: "phone", label: "Téléphone" },
  ];

  return (
    <div className="page-shell page-products">
      <section className="page-hero-card">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Annuaire des produits</span>
          <h2>Produits et articles</h2>
          <p>
            Consultez les fiches partagées par les entreprises. Contactez-les pour confirmer
            la disponibilité et le prix.
          </p>
        </div>
        <button className="secondary-action" type="button" onClick={() => onNavigate("/pharmacies")}>
          Voir les structures
        </button>
      </section>

      {featuredProduct ? (
        <section className="page-highlight-grid">
          <article className="product-focus-card">
            <div className="product-focus-image">
              <ArticlePhoto record={{ID_Article:featuredProduct.id,NomArticle:featuredProduct.name,PhotoArticle:featuredProduct.photo}} publicCatalogue alt={featuredProduct.name}/>
            </div>
            <div className="product-focus-meta">
              <strong>{featuredProduct.name}</strong>
              <span>{featuredProduct.price}</span>
              <small>{featuredProduct.availability}</small>
            </div>
          </article>

          <article className="detail-block">
            <div className="d-flex align-items-center gap-2 mb-2">
              <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis">{featuredProduct.company}</span>
            </div>
            <p>{featuredProduct.address} · {featuredProduct.phone}</p><p>{featuredProduct.observation}</p>
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
          <p>Les informations affichées sont déclarées par les entreprises.</p>
        </div>
        <PublicTable columns={columns} rows={products} emptyMessage="Aucun produit public disponible pour le moment." />
      </section>
    </div>
  );
}
