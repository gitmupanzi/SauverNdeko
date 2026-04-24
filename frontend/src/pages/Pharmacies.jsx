import PharmacyCard from "../components/PharmacyCard";
import PublicTable from "../components/PublicTable";

export default function Pharmacies({ pharmacies, onContact }) {
  const columns = [
    { key: "name", label: "Nom" },
    { key: "address", label: "Adresse" },
    { key: "phone", label: "Téléphone public" },
    { key: "type", label: "Type de structure" },
    { key: "status", label: "Disponibilité / statut" },
  ];

  return (
    <div className="page-shell">
      <section className="page-hero-card">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Structures publiques</span>
          <h2>Pharmacies et structures</h2>
          <p>
            Retrouvez les structures publiques répertoriées avec leur adresse, téléphone public,
            type de structure et statut de disponibilité.
          </p>
        </div>
      </section>

      <section className="cards-grid">
        {pharmacies.map((pharmacy) => (
          <PharmacyCard key={pharmacy.id} pharmacy={pharmacy} onContact={onContact} />
        ))}
      </section>

      <section className="page-table-section">
        <div className="section-head">
          <h3>Liste publique des structures</h3>
          <p>Les informations affichées ici sont limitées au périmètre public de la plateforme.</p>
        </div>
        <PublicTable
          columns={columns}
          rows={pharmacies}
          emptyMessage="Aucune pharmacie publique disponible pour le moment."
        />
      </section>
    </div>
  );
}
