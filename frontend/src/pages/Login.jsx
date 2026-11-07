import ThemePicker from "../components/ThemePicker";
import { useEffect, useRef, useState } from "react";
import { Link, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { normalizeAuthRedirect } from "../services/authNavigation";
import "./Login.css";

function LoginBrand() {
  return (
    <div className="login-brand">
      <img src="/sauverndeko-logo.jpg" alt="" width="56" height="56" />
      <div>
        <span className="login-brand-name">SauverNdeko</span>
      </div>
    </div>
  );
}

export function SessionLoading() {
  return (
    <main className="login-screen"><div className="login-theme"><ThemePicker /></div>
      <section className="login-card login-session-card" aria-label="Ouverture de SauverNdeko">
        <LoginBrand />
        <p className="login-session-status" role="status">
          <span className="login-spinner" aria-hidden="true" />
          Vérification de votre session…
        </p>
      </section>
    </main>
  );
}

function loginError(payload) {
  if (payload?.status === 429) {
    return "Trop de tentatives. Réessayez dans un instant.";
  }
  if (payload?.status === 401 || payload?.status === 403) {
    return "Connexion refusée. Vérifiez vos identifiants.";
  }
  if (payload?.status === 0 || payload?.error?.code === "NETWORK_ERROR") {
    return "Service injoignable. Vérifiez votre connexion.";
  }
  if (payload?.status >= 500) {
    return "Service indisponible. Réessayez dans un instant.";
  }
  return "Connexion impossible. Réessayez.";
}

function destinationLabel(pathname) {
  if (pathname.startsWith("/logistique")) return "Logistique";
  if (pathname.startsWith("/admin")) return "Administration";
  if (pathname.startsWith("/discussions")) return "Discussions";
  if (pathname.startsWith("/profil")) return "Votre profil";
  if (pathname.startsWith("/produits")) return "Produits";
  if (pathname.startsWith("/experts")) return "Professionnels";
  if (pathname.startsWith("/pharmacies")) return "Structures";
  if (pathname.startsWith("/territoires")) return "Organisation territoriale";
  if (pathname.startsWith("/referentiels")) return "Référentiels";
  if (pathname.startsWith("/caisse")) return "Caisse";
  if (pathname.startsWith("/support")) return "Support";
  if (pathname.startsWith("/parametres")) return "Paramètres";
  if (pathname.startsWith("/guide")) return "Guide utilisateur";
  return "La page demandée";
}

export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const { loading, isAuthenticated, login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [capsLock, setCapsLock] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [fieldErrors, setFieldErrors] = useState({});
  const [errorMessage, setErrorMessage] = useState("");
  const emailRef = useRef(null);
  const passwordRef = useRef(null);
  const alertRef = useRef(null);
  const requestRef = useRef(null);
  const busyRef = useRef(false);

  const from = location.state?.from;
  const redirectTarget = normalizeAuthRedirect(
    searchParams.get("redirect") ||
      (from ? (from.pathname || "") + (from.search || "") + (from.hash || "") : "")
  );

  useEffect(() => {
    const previousTitle = document.title;
    document.title = "Connexion | SauverNdeko";
    return () => {
      document.title = previousTitle;
      const pending = requestRef.current;
      requestRef.current = null;
      pending?.abort();
    };
  }, []);

  useEffect(() => {
    if (!loading && isAuthenticated) {
      navigate(redirectTarget, { replace: true });
    }
  }, [isAuthenticated, loading, navigate, redirectTarget]);

  useEffect(() => {
    if (errorMessage) alertRef.current?.focus();
  }, [errorMessage]);

  function changeField(name, value) {
    if (name === "email") setEmail(value);
    else setPassword(value);
    setFieldErrors((current) => ({ ...current, [name]: "" }));
    setErrorMessage("");
  }

  async function handleSubmit(event) {
    event.preventDefault();
    if (busyRef.current || loading || isAuthenticated) return;

    const errors = {};
    if (!email.trim()) errors.email = "Saisissez votre adresse e-mail.";
    else if (emailRef.current?.validity.typeMismatch) {
      errors.email = "Saisissez une adresse e-mail valide.";
    }
    if (!password) errors.password = "Saisissez votre mot de passe.";
    setFieldErrors(errors);
    setErrorMessage("");
    if (Object.keys(errors).length) {
      (errors.email ? emailRef : passwordRef).current?.focus();
      return;
    }

    const controller = new AbortController();
    requestRef.current = controller;
    busyRef.current = true;
    setSubmitting(true);
    let timedOut = false;
    const timer = window.setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, 25000);

    try {
      const payload = await login(
        { EmailUser: email.trim(), MotdepasseUser: password },
        { signal: controller.signal }
      );
      if (requestRef.current !== controller) return;
      if (timedOut) {
        setErrorMessage("Le service ne répond pas. Réessayez.");
      } else if (!controller.signal.aborted && !payload?.success) {
        setErrorMessage(loginError(payload));
      }
    } catch {
      if (!controller.signal.aborted && requestRef.current === controller) {
        setErrorMessage("Connexion impossible. Réessayez.");
      }
    } finally {
      window.clearTimeout(timer);
      if (requestRef.current === controller) {
        requestRef.current = null;
        busyRef.current = false;
        setSubmitting(false);
      }
    }
  }

  function detectCapsLock(event) {
    setCapsLock(Boolean(event.getModifierState?.("CapsLock")));
  }

  const busy = submitting || loading || isAuthenticated;

  return (
    <main className="login-screen login-entry"><div className="login-theme"><ThemePicker /></div>
      <Link to="/catalogue" className="login-home-link"><i className="bi bi-arrow-left" aria-hidden="true" />Retour à l’accueil</Link>
      <div className="login-layout">
      <section className="login-card" aria-labelledby="login-title">
        <LoginBrand />
        <header className="login-heading">
          <h1 id="login-title">Connexion</h1>
          <p>Accédez à vos applications.</p>
        </header>

        {location.state?.passwordChanged===true?<p className="login-success" role="status"><i className="bi bi-check-circle" aria-hidden="true"/>Votre mot de passe a été modifié. Reconnectez-vous.</p>:null}
        {redirectTarget !== "/espace" ? (
          <p className="login-destination">
            <i className="bi bi-arrow-return-right" aria-hidden="true" />
            Après connexion : <strong>{destinationLabel(redirectTarget)}</strong>
          </p>
        ) : null}

        <form className="login-form" onSubmit={handleSubmit} noValidate aria-busy={busy}>
          {errorMessage ? (
            <div className="login-error" role="alert" tabIndex="-1" ref={alertRef}>
              <i className="bi bi-exclamation-circle" aria-hidden="true" />
              <span>{errorMessage}</span>
            </div>
          ) : null}

          <div className="login-field">
            <label htmlFor="login-email">Adresse e-mail</label>
            <div className="login-input-wrap">
              <i className="bi bi-envelope" aria-hidden="true" />
              <input
                ref={emailRef}
                id="login-email"
                name="email"
                type="email"
                inputMode="email"
                autoComplete="username"
                autoCapitalize="none"
                spellCheck={false}
                placeholder="vous@organisation.cd"
                value={email}
                onChange={(event) => changeField("email", event.target.value)}
                disabled={busy}
                aria-invalid={Boolean(fieldErrors.email)}
                aria-describedby={fieldErrors.email ? "login-email-error" : undefined}
                required
              />
            </div>
            {fieldErrors.email ? <p className="login-field-error" id="login-email-error">{fieldErrors.email}</p> : null}
          </div>

          <div className="login-field">
            <label htmlFor="login-password">Mot de passe</label>
            <div className="login-input-wrap login-password-wrap">
              <i className="bi bi-lock" aria-hidden="true" />
              <input
                ref={passwordRef}
                id="login-password"
                name="password"
                type={showPassword ? "text" : "password"}
                autoComplete="current-password"
                placeholder="Votre mot de passe"
                value={password}
                onChange={(event) => changeField("password", event.target.value)}
                onKeyDown={detectCapsLock}
                onKeyUp={detectCapsLock}
                onBlur={() => setCapsLock(false)}
                disabled={busy}
                aria-invalid={Boolean(fieldErrors.password)}
                aria-describedby={[fieldErrors.password ? "login-password-error" : "", capsLock ? "login-caps-lock" : ""].filter(Boolean).join(" ") || undefined}
                required
              />
              <button
                className="login-password-toggle"
                type="button"
                aria-label={showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe"}
                aria-pressed={showPassword}
                aria-controls="login-password"
                onClick={() => setShowPassword((visible) => !visible)}
                disabled={busy}
              >
                <i className={showPassword ? "bi bi-eye-slash" : "bi bi-eye"} aria-hidden="true" />
              </button>
            </div>
            {fieldErrors.password ? <p className="login-field-error" id="login-password-error">{fieldErrors.password}</p> : null}
            {capsLock ? <p className="login-caps-lock" id="login-caps-lock" role="status">La touche Verr. Maj est activée.</p> : null}
          </div>

          <div className="login-assistance">
            <Link to="/reset-password" className="login-help-toggle" onClick={event=>{if(busy)event.preventDefault();}} aria-disabled={busy} tabIndex={busy?-1:undefined}>Mot de passe oublié ?</Link>
          </div>

          <button className="login-submit" type="submit" disabled={busy}>
            {busy ? <span className="login-spinner" aria-hidden="true" /> : null}
            <span>{loading ? "Vérification de la session…" : submitting || isAuthenticated ? "Connexion en cours…" : "Se connecter"}</span>
            {!busy ? <i className="bi bi-arrow-right" aria-hidden="true" /> : null}
          </button>
          <span className="login-status" role="status">{submitting ? "Connexion en cours. Veuillez patienter." : ""}</span>
        </form>

        <p className="login-register">Besoin d’un accès ? Contactez votre administrateur.</p>
      </section>
      <aside className="login-identity" aria-label="SauverNdeko"><div><span className="login-identity-kicker">Une plateforme congolaise</span><img src="/sauverndeko-logo.jpg" alt="" width="64" height="64" /><h2>Des liens de proximité.</h2><p className="login-project-lead">Produits, compétences et services.</p><p className="login-project-summary">Rapprocher les personnes des ressources dont elles ont besoin, et donner aux organisations un espace pour piloter leur activité.</p><div className="login-project-sectors" aria-label="Premiers domaines du projet"><span>Santé</span><span>Immobilier</span><span>Construction</span></div></div></aside>
      </div>
    </main>
  );
}
