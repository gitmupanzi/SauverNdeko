export default function PharmacyCard({ pharmacy, onContact }) {
  return (
    <article className="pharmacy-public-card">
      <div className="pharmacy-card-head">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-2">
            {pharmacy.type}
          </span>
          <strong>{pharmacy.name}</strong>
          <p>{pharmacy.address}</p>
        </div>
        <span className="status-pill">{pharmacy.status}</span>
      </div>
      <dl className="public-meta-list">
        <div>
          <dt>Telephone</dt>
          <dd>{pharmacy.phone}</dd>
        </div>
        <div>
          <dt>Horaires</dt>
          <dd>{pharmacy.hours}</dd>
        </div>
        <div>
          <dt>Disponibilite</dt>
          <dd>{pharmacy.status}</dd>
        </div>
      </dl>
      <button
        className="secondary-action"
        type="button"
        onClick={() => onContact({ type: "structure", id: pharmacy.id, name: pharmacy.name })}
      >
        Contacter la structure
      </button>
    </article>
  );
}
