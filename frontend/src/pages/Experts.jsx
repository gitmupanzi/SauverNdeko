import ExpertCard from "../components/ExpertCard";
import PublicTable from "../components/PublicTable";

export default function Experts({ experts, onContact }) {
  const columns = [
    { key: "fullName", label: "Nom complet" },
    { key: "professionalType", label: "Type professionnel" },
    { key: "specialty", label: "Spécialité" },
    {
      key: "experience",
      label: "Expérience",
      render: (value) => (value != null ? `${value} an(s)` : "À confirmer"),
    },
    { key: "structure", label: "Structure associée" },
  ];

  return (
    <div className="page-shell">
      <section className="page-hero-card">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Professionnels</span>
          <h2>Experts et professionnels</h2>
          <p>
            Cette page n’affiche que les informations publiques utiles à l’orientation:
            identité, type professionnel, spécialité, expérience et structure associée.
          </p>
        </div>
      </section>

      <section className="cards-grid">
        {experts.map((expert) => (
          <ExpertCard key={expert.id} expert={expert} onContact={onContact} />
        ))}
      </section>

      <section className="page-table-section">
        <div className="section-head">
          <h3>Répertoire public</h3>
          <p>Aucune donnée sensible comme mot de passe, statut admin ou téléphone personnel n’est affichée.</p>
        </div>
        <PublicTable columns={columns} rows={experts} emptyMessage="Aucun expert public disponible pour le moment." />
      </section>
    </div>
  );
}
