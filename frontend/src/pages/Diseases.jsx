import PublicTable from "../components/PublicTable";

export default function Diseases({ diseases }) {
  const columns = [
    { key: "name", label: "Nom de la maladie" },
    { key: "abbreviation", label: "Abréviation" },
    { key: "description", label: "Description / observation" },
    { key: "category", label: "Catégorie" },
  ];

  return (
    <div className="page-shell">
      <section className="page-hero-card">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Référentiel public</span>
          <h2>Maladies</h2>
          <p>
            Les maladies sont prévues côté backend depuis <code>T_Generique</code>, filtré par la catégorie
            <code> Maladie</code> dans <code>T_CategorieGenerique</code>.
          </p>
        </div>
      </section>

      <section className="cards-grid disease-grid">
        {diseases.map((disease) => (
          <article key={disease.id} className="disease-card">
            <span className="badge rounded-pill text-bg-light text-primary-emphasis mb-2">{disease.category}</span>
            <strong>{disease.name}</strong>
            <small>{disease.abbreviation}</small>
            <p>{disease.description}</p>
          </article>
        ))}
      </section>

      <section className="page-table-section">
        <div className="section-head">
          <h3>Vue tabulaire des maladies</h3>
          <p>Le rendu reste compatible avec l’API publique prévue pour les référentiels.</p>
        </div>
        <PublicTable columns={columns} rows={diseases} emptyMessage="Aucune maladie publique disponible pour le moment." />
      </section>
    </div>
  );
}
