export default function ProductCard({ product }) {
  return (
    <article className="product-card">
      <div className="product-card-media">
        <img src={product.photo || "/illustration-produits.svg"} alt={product.name} />
      </div>
      <div className="product-card-body">
        <span className="badge rounded-pill text-bg-light text-primary-emphasis mb-2">Produit</span>
        <strong>{product.name}</strong>
        <p>{product.observation}</p>
        <dl className="public-meta-list">
          <div>
            <dt>Référence</dt>
            <dd>{product.reference}</dd>
          </div>
          <div>
            <dt>Prix de vente</dt>
            <dd>{product.price}</dd>
          </div>
          <div>
            <dt>Disponibilité</dt>
            <dd>{product.availability}</dd>
          </div>
        </dl>
      </div>
    </article>
  );
}
