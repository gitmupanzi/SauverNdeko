import { useEffect, useId, useRef, useState } from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import { ANNOUNCEMENT_TITLE_LIMIT, ANNOUNCEMENT_BODY_LIMIT, newMessageRequestId, publishAnnouncement, uncertainDelivery } from "../../services/communication";

const scopes = [
  { value: "companies", label: "Entreprises sélectionnées" },
  { value: "all", label: "Toutes les entreprises" },
];

export default function AnnouncementComposer({ context, onClose, onSent }) {
  const prefix = useId();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scope, setScope] = useState("companies");
  const [companyIds, setCompanyIds] = useState([]);
  const [confirmation, setConfirmation] = useState(false);
  const [errors, setErrors] = useState({});
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [uncertain, setUncertain] = useState(false);
  const attempt = useRef(null);
  const lock = useRef(false);
  const mounted = useRef(false);
  const preview = useRef(null);
  const companies = context.companies || [];
  const selected = companies.filter(company => companyIds.includes(String(company.id)));
  const options = companies.filter(company => !companyIds.includes(String(company.id)))
    .map(company => ({ value: String(company.id), label: company.name }));

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);
  useEffect(() => {
    if (confirmation) preview.current?.focus({ preventScroll: true });
  }, [confirmation]);

  function validate() {
    const fields = {};
    if (!title.trim()) fields.title = "Saisissez un titre.";
    if (!body.trim()) fields.body = "Saisissez votre message.";
    if (context.platformAdmin && scope === "companies" && !companyIds.length) fields.companies = "Choisissez au moins une entreprise.";
    setErrors(fields);
    if (Object.keys(fields).length) {
      setError("Complétez les champs indiqués.");
      return false;
    }
    return true;
  }

  async function submit() {
    if (lock.current || !context.canPublish) return;
    if (!confirmation) {
      if (validate()) { setError(""); setConfirmation(true); }
      return;
    }
    lock.current = true;
    setBusy(true);
    setError("");
    attempt.current ||= JSON.stringify({
      title: title.trim(),
      body: body.trim(),
      scope,
      companyIds: scope === "companies" ? companyIds.map(Number) : [],
      requestId: newMessageRequestId(),
    });
    const result = await publishAnnouncement(attempt.current);
    if (!mounted.current) return;
    setBusy(false);
    lock.current = false;
    if (result?.success) {
      onSent(result.data);
      return;
    }
    const pending = uncertainDelivery(result) || (uncertain && result?.status === 409);
    setUncertain(pending);
    if (!pending) attempt.current = null;
    setError(pending
      ? "Impossible de confirmer la diffusion. Réessayez avec cette même annonce."
      : result?.message || "L’annonce n’a pas pu être diffusée.");
  }

  return <RecordEditorFrame title="Nouvelle annonce" icon="bell" onClose={onClose} onSubmit={submit}
    defaultWidth={650} storageKey="sauverndeko.discussions.announcement.width"
    submitLabel={uncertain ? "Vérifier la diffusion" : confirmation ? "Diffuser l’annonce" : "Vérifier l’annonce"}
    busy={busy} error={error} dirty={Boolean(title || body || companyIds.length)}
    discardMessage={uncertain ? "Fermer cette annonce dont la diffusion reste à vérifier ?" : "Abandonner cette annonce ?"}>
    <div className="communication-form">
      {confirmation ? <>
        <section className="communication-announcement-preview" ref={preview} tabIndex={-1} aria-label="Aperçu de l’annonce">
          <h3>{title.trim()}</h3>
          <p>{body.trim()}</p>
        </section>
        <section className="communication-audience" aria-label="Destinataires">
          <AppIcon name="building" size={20} />
          <div><strong>{scope === "all" ? "Toutes les entreprises actives" : context.platformAdmin
            ? selected.map(company => company.name).join(", ") : companies[0]?.name || "Votre entreprise"}</strong>
          <p>L’annonce apparaîtra dans les notifications des membres actifs concernés.</p></div>
        </section>
        {!uncertain && <ActionButton icon="edit" disabled={busy} onClick={() => { setError(""); setConfirmation(false); }}>Modifier l’annonce</ActionButton>}
      </> : <>
        <div className="communication-field">
          <label htmlFor={prefix + "-title"}>Titre</label>
          <input id={prefix + "-title"} value={title} onChange={event => setTitle(event.target.value)} maxLength={ANNOUNCEMENT_TITLE_LIMIT}
            required aria-invalid={Boolean(errors.title)} aria-describedby={errors.title ? prefix + "-title-error" : undefined} />
          {errors.title && <span className="communication-field-error" id={prefix + "-title-error"}>{errors.title}</span>}
        </div>
        <div className="communication-field">
          <label htmlFor={prefix + "-body"}>Message</label>
          <textarea id={prefix + "-body"} rows={7} value={body} onChange={event => setBody(event.target.value)}
            maxLength={ANNOUNCEMENT_BODY_LIMIT} required aria-invalid={Boolean(errors.body)}
            aria-describedby={errors.body ? prefix + "-body-error" : prefix + "-body-count"} />
          {errors.body ? <span className="communication-field-error" id={prefix + "-body-error"}>{errors.body}</span>
            : <small id={prefix + "-body-count"}>{body.length.toLocaleString("fr-FR")} / {ANNOUNCEMENT_BODY_LIMIT.toLocaleString("fr-FR")}</small>}
        </div>
        {context.platformAdmin ? <>
          <div className="communication-field">
            <label htmlFor={prefix + "-scope"}>Diffuser à</label>
            <SearchSelect id={prefix + "-scope"} label="Diffuser à" value={scope} onChange={setScope} options={scopes} />
          </div>
          {scope === "companies" && <div className="communication-field">
            <label htmlFor={prefix + "-companies"}>Destinataires</label>
            <SearchSelect id={prefix + "-companies"} label="Ajouter une entreprise" value=""
              placeholder="Ajouter une entreprise…" onChange={value => setCompanyIds(previous => [...previous, value])}
              options={options} disabled={companyIds.length >= 100} invalid={Boolean(errors.companies)}
              describedBy={errors.companies ? prefix + "-companies-error" : undefined} />
            {errors.companies && <span className="communication-field-error" id={prefix + "-companies-error"}>{errors.companies}</span>}
            {selected.length > 0 && <ul className="communication-audience-list">{selected.map(company => <li key={company.id}>
              <button type="button" aria-label={"Retirer " + company.name}
                onClick={() => setCompanyIds(previous => previous.filter(value => value !== String(company.id)))}>
                {company.name}<AppIcon name="close" />
              </button>
            </li>)}</ul>}
            {companyIds.length >= 100 && <small>100 entreprises au maximum pour une sélection.</small>}
          </div>}
        </> : <section className="communication-audience" aria-label="Destinataires">
          <AppIcon name="building" size={20} /><div><strong>{companies[0]?.name || "Votre entreprise"}</strong>
          <p>Membres actifs de votre entreprise</p></div>
        </section>}
      </>}
    </div>
  </RecordEditorFrame>;
}
