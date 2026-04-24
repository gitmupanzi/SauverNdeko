export default function ExpertCard({ expert, onContact }) {
  const initials = `${expert.firstName?.[0] || ""}${expert.lastName?.[0] || ""}`.trim() || "SN";

  return (
    <article className="expert-public-card">
      <div className="expert-public-head">
        <div className="expert-avatar">
          {expert.photo && expert.photo !== "/illustration-experts.svg" ? (
            <img src={expert.photo} alt={expert.fullName} />
          ) : (
            <span>{initials}</span>
          )}
        </div>
        <div>
          <strong>{expert.fullName}</strong>
          <p>{expert.professionalType}</p>
        </div>
      </div>
      <dl className="public-meta-list">
        <div>
          <dt>Specialite</dt>
          <dd>{expert.specialty}</dd>
        </div>
        <div>
          <dt>Experience</dt>
          <dd>{expert.experience != null ? `${expert.experience} an(s)` : "A confirmer"}</dd>
        </div>
        <div>
          <dt>Structure</dt>
          <dd>{expert.structure}</dd>
        </div>
        <div>
          <dt>Disponibilite</dt>
          <dd>{expert.availability}</dd>
        </div>
      </dl>
      <button
        className="contact-button d-inline-flex align-items-center gap-2"
        type="button"
        onClick={() => onContact({ type: "expert", id: expert.id, name: expert.fullName })}
      >
        <i className="bi bi-send" aria-hidden="true" />
        Contacter
      </button>
    </article>
  );
}
