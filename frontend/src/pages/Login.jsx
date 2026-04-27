import { useEffect, useState } from "react";
import { Link, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

function normalizeRedirectPath(rawValue, fallbackPath) {
  if (!rawValue || typeof rawValue !== "string") {
    return fallbackPath;
  }

  if (
    !rawValue.startsWith("/") ||
    rawValue.startsWith("//") ||
    rawValue.startsWith("/login") ||
    rawValue.startsWith("/register")
  ) {
    return fallbackPath;
  }

  return rawValue;
}

export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const { loading, isAuthenticated, login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");

  const redirectTarget = normalizeRedirectPath(
    searchParams.get("redirect") || `${location.state?.from?.pathname || ""}${location.state?.from?.search || ""}`,
    "/profil"
  );

  useEffect(() => {
    if (!loading && isAuthenticated) {
      navigate(redirectTarget, { replace: true });
    }
  }, [isAuthenticated, loading, navigate, redirectTarget]);

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);
    setErrorMessage("");

    const payload = await login({
      EmailUser: email.trim(),
      MotdepasseUser: password,
    });

    if (payload?.success) {
      navigate(redirectTarget, { replace: true });
      return;
    }

    if (payload === null) {
      setErrorMessage("Impossible de contacter le backend pour le moment.");
    } else {
      setErrorMessage(payload?.message || "Connexion impossible.");
    }

    setSubmitting(false);
  }

  return (
    <div className="page-shell auth-page-shell">
      <section className="auth-layout">
        <article className="auth-card auth-card-brand">
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis">Authentification</span>
          <h2>Connectez-vous a votre espace SauverNdeko</h2>
          <p>
            Votre session permet d'acceder aux discussions, au profil utilisateur et aux futures
            fonctionnalites privees reliees au backend.
          </p>

          <div className="auth-brand-points">
            <div>
              <strong>Discussions privees</strong>
              <p>Chaque conversation est automatiquement rattachee a l'utilisateur authentifie.</p>
            </div>
            <div>
              <strong>Profil centralise</strong>
              <p>Les informations affichees proviennent directement du backend SauverNdeko.</p>
            </div>
            <div>
              <strong>Session restauree</strong>
              <p>Le frontend verifie votre session au chargement et reutilise le token existant.</p>
            </div>
          </div>
        </article>

        <article className="auth-card auth-card-form">
          <div className="auth-form-head">
            <span className="status-pill">Connexion JWT</span>
            <h2>Se connecter</h2>
            <p>Utilisez l'email et le mot de passe de votre utilisateur deja present en base.</p>
          </div>

          {errorMessage ? <div className="auth-alert">{errorMessage}</div> : null}

          <form className="auth-form" onSubmit={handleSubmit}>
            <label className="auth-field">
              <span>Adresse email</span>
              <input
                type="email"
                name="email"
                autoComplete="email"
                placeholder="exemple@domaine.cd"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                disabled={submitting}
                required
              />
            </label>

            <label className="auth-field">
              <span>Mot de passe</span>
              <input
                type="password"
                name="password"
                autoComplete="current-password"
                placeholder="Votre mot de passe"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                disabled={submitting}
                required
              />
            </label>

            <div className="auth-form-footer">
              <p className="auth-note">
                Redirection apres connexion: <strong>{redirectTarget}</strong>
              </p>
              <button className="primary-action" type="submit" disabled={submitting || loading}>
                {submitting ? "Connexion..." : "Se connecter"}
              </button>
              <p className="auth-switch-note">
                Pas encore de compte ?{" "}
                <Link className="auth-switch-link" to={`/register?redirect=${encodeURIComponent(redirectTarget)}`}>
                  Creer un compte
                </Link>
              </p>
            </div>
          </form>
        </article>
      </section>
    </div>
  );
}
