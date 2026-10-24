import { useEffect, useState } from "react";
import { Link, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { fetchPublicPharmacies } from "../services/api";

import { normalizeAuthRedirect } from "../services/authNavigation";

function buildInitialFormState() {
  return {
    NomUser: "",
    PrenomUser: "",
    EmailUser: "",
    MotdepasseUser: "",
    confirmationMotdepasse: "",
    PhoneUser: "",
    SexeUser: "M",
    IdEntiteFk: "",
  };
}

export default function Register() {
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const { loading, isAuthenticated, register } = useAuth();
  const [formData, setFormData] = useState(buildInitialFormState);
  const [entities, setEntities] = useState([]);
  const [loadingEntities, setLoadingEntities] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");

  const redirectTarget = normalizeAuthRedirect(
    searchParams.get("redirect") || `${location.state?.from?.pathname || ""}${location.state?.from?.search || ""}`,
    "/"
  );

  useEffect(() => {
    if (!loading && isAuthenticated) {
      navigate(redirectTarget, { replace: true });
    }
  }, [isAuthenticated, loading, navigate, redirectTarget]);

  useEffect(() => {
    let active = true;

    async function loadEntities() {
      const payload = await fetchPublicPharmacies({ take: 100 });

      if (!active) {
        return;
      }

      if (payload?.success && Array.isArray(payload.data)) {
        setEntities(payload.data);
      }

      setLoadingEntities(false);
    }

    loadEntities();

    return () => {
      active = false;
    };
  }, []);

  function handleChange(event) {
    const { name, value } = event.target;
    setFormData((current) => ({
      ...current,
      [name]: value,
    }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);
    setErrorMessage("");

    if (formData.MotdepasseUser !== formData.confirmationMotdepasse) {
      setErrorMessage("La confirmation du mot de passe ne correspond pas.");
      setSubmitting(false);
      return;
    }

    if (formData.MotdepasseUser.length < 6) {
      setErrorMessage("Le mot de passe doit contenir au moins 6 caracteres.");
      setSubmitting(false);
      return;
    }

    const payload = await register({
      NomUser: formData.NomUser.trim(),
      PrenomUser: formData.PrenomUser.trim(),
      EmailUser: formData.EmailUser.trim(),
      MotdepasseUser: formData.MotdepasseUser,
      PhoneUser: formData.PhoneUser.trim(),
      SexeUser: formData.SexeUser,
      IdEntiteFk: formData.IdEntiteFk || null,
    });

    if (payload?.success) {
      navigate(redirectTarget, { replace: true });
      return;
    }

    setErrorMessage(
      payload === null ? "Impossible de contacter le backend pour le moment." : payload?.message || "Inscription impossible."
    );
    setSubmitting(false);
  }

  return (
    <div className="page-shell auth-page-shell">
      <section className="auth-layout">
        <article className="auth-card auth-card-brand">
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis">Creation de compte</span>
          <h2>Creez votre compte SauverNdeko</h2>
          <p>
            Le compte est cree dans `systeme.T_Utilisateurs`, puis la session JWT est ouverte
            automatiquement pour acceder au profil et aux discussions.
          </p>

          <div className="auth-brand-points">
            <div>
              <strong>Champs principaux</strong>
              <p>Nom, prenom, email, telephone, sexe et mot de passe sont saisis dans le formulaire.</p>
            </div>
            <div>
              <strong>Entite optionnelle</strong>
              <p>Le rattachement a une structure vient du backend et reste facultatif.</p>
            </div>
            <div>
              <strong>Champs sensibles proteges</strong>
              <p>Le role, `Is_staff` et `Is_Admin` restent controles cote backend.</p>
            </div>
          </div>
        </article>

        <article className="auth-card auth-card-form">
          <div className="auth-form-head">
            <span className="status-pill">Inscription</span>
            <h2>Creer un compte</h2>
            <p>Les donnees de rattachement et l'enregistrement final proviennent du backend SauverNdeko.</p>
          </div>

          {errorMessage ? <div className="auth-alert">{errorMessage}</div> : null}

          <form className="auth-form" onSubmit={handleSubmit}>
            <div className="auth-field-grid">
              <label className="auth-field">
                <span>Nom</span>
                <input
                  type="text"
                  name="NomUser"
                  value={formData.NomUser}
                  onChange={handleChange}
                  disabled={submitting}
                  required
                />
              </label>

              <label className="auth-field">
                <span>Prenom</span>
                <input
                  type="text"
                  name="PrenomUser"
                  value={formData.PrenomUser}
                  onChange={handleChange}
                  disabled={submitting}
                  required
                />
              </label>

              <label className="auth-field">
                <span>Email</span>
                <input
                  type="email"
                  name="EmailUser"
                  value={formData.EmailUser}
                  onChange={handleChange}
                  disabled={submitting}
                  required
                />
              </label>

              <label className="auth-field">
                <span>Telephone</span>
                <input
                  type="text"
                  name="PhoneUser"
                  value={formData.PhoneUser}
                  onChange={handleChange}
                  disabled={submitting}
                  placeholder="+243..."
                />
              </label>

              <label className="auth-field">
                <span>Sexe</span>
                <select
                  name="SexeUser"
                  value={formData.SexeUser}
                  onChange={handleChange}
                  disabled={submitting}
                >
                  <option value="M">Masculin</option>
                  <option value="F">Feminin</option>
                </select>
              </label>

              <label className="auth-field">
                <span>Structure de rattachement</span>
                <select
                  name="IdEntiteFk"
                  value={formData.IdEntiteFk}
                  onChange={handleChange}
                  disabled={submitting || loadingEntities}
                >
                  <option value="">Aucune structure</option>
                  {entities.map((entity) => (
                    <option key={entity.IdEntite} value={entity.IdEntite}>
                      {entity.NomEntite}
                    </option>
                  ))}
                </select>
              </label>

              <label className="auth-field">
                <span>Mot de passe</span>
                <input
                  type="password"
                  name="MotdepasseUser"
                  value={formData.MotdepasseUser}
                  onChange={handleChange}
                  disabled={submitting}
                  minLength={6}
                  required
                />
              </label>

              <label className="auth-field">
                <span>Confirmer le mot de passe</span>
                <input
                  type="password"
                  name="confirmationMotdepasse"
                  value={formData.confirmationMotdepasse}
                  onChange={handleChange}
                  disabled={submitting}
                  minLength={6}
                  required
                />
              </label>
            </div>

            <div className="auth-form-footer">
              <p className="auth-note">
                {loadingEntities
                  ? "Chargement des structures depuis le backend..."
                  : "Les roles d'administration ne sont pas saisissables depuis ce formulaire public."}
              </p>
              <button className="primary-action" type="submit" disabled={submitting || loading}>
                {submitting ? "Creation..." : "Creer mon compte"}
              </button>
              <p className="auth-switch-note">
                Vous avez deja un compte ?{" "}
                <Link className="auth-switch-link" to={`/login?redirect=${encodeURIComponent(redirectTarget)}`}>
                  Se connecter
                </Link>
              </p>
            </div>
          </form>
        </article>
      </section>
    </div>
  );
}
