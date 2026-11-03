import {Link} from "react-router-dom";
import ExpertAvatar from "../pages/experts/ExpertAvatar";
export default function ExpertCard({ expert, onContact }) {

  return (
    <article className="expert-public-card">
      <div className="expert-public-head">
        <ExpertAvatar record={expert}/>
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
      <Link className="contact-button" to="/experts" state={{focusId:expert.id}}>Voir le profil</Link>
      {expert.canContact?<button
        className="contact-button d-inline-flex align-items-center gap-2"
        type="button"
        onClick={() => onContact({ type: "expert", id: expert.id, name: expert.fullName })}
      >
        <i className="bi bi-send" aria-hidden="true" />
        Contacter
      </button>:null}
    </article>
  );
}
