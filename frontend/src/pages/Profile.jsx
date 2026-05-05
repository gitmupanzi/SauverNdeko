import { useEffect, useState } from "react";
import { useAuth } from "../contexts/AuthContext";

function buildInitials(user) {
  const first = String(user?.PrenomUser || "").trim().charAt(0);
  const last = String(user?.NomUser || "").trim().charAt(0);
  return `${first}${last}`.trim().toUpperCase() || "SN";
}

function buildRoleLabel(user) {
  if (user?.role?.name) {
    return user.role.name;
  }

  if (user?.Is_Admin) {
    return "Administrateur";
  }

  if (user?.Is_staff) {
    return "Staff";
  }

  return "Utilisateur";
}

function buildStatusLabel(user) {
  return user?.ValideUser ? "Actif" : "Inactif";
}

function ProfileStatCard({ label, value, tone = "primary" }) {
  return (
    <article className={`profile-stat-card is-${tone}`}>
      <span>{label}</span>
      <strong>{value || "-"}</strong>
    </article>
  );
}

function ProfileInfoCard({ title, children, actions = null }) {
  return (
    <section className="profile-card">
      <div className="profile-card-head">
        <div className="section-head">
          <h3>{title}</h3>
        </div>
        {actions ? <div className="profile-card-actions">{actions}</div> : null}
      </div>
      <div className="profile-grid">{children}</div>
    </section>
  );
}

function ProfileField({ label, value }) {
  return (
    <div className="profile-field">
      <span>{label}</span>
      <strong>{value || "Non renseigne"}</strong>
    </div>
  );
}

function ProfileInput({ label, name, value, onChange, type = "text", required = false, placeholder = "" }) {
  return (
    <label className="profile-editor-field">
      <span>{label}</span>
      <input
        type={type}
        name={name}
        value={value}
        onChange={onChange}
        required={required}
        placeholder={placeholder}
      />
    </label>
  );
}

function ProfileSelect({ label, name, value, onChange, options }) {
  return (
    <label className="profile-editor-field">
      <span>{label}</span>
      <select name={name} value={value} onChange={onChange}>
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

function buildProfileForm(user) {
  return {
    NomUser: user?.NomUser || "",
    PrenomUser: user?.PrenomUser || "",
    EmailUser: user?.EmailUser || "",
    PhoneUser: user?.PhoneUser || "",
    SexeUser: user?.SexeUser || "M",
    UrlPhoto: user?.UrlPhoto || "",
  };
}

export default function Profile() {
  const { user, updateProfile } = useAuth();
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [formData, setFormData] = useState(buildProfileForm(user));
  const [feedback, setFeedback] = useState({ type: "", message: "" });

  useEffect(() => {
    setFormData(buildProfileForm(user));
  }, [user]);

  function handleChange(event) {
    const { name, value } = event.target;
    setFormData((current) => ({
      ...current,
      [name]: value,
    }));
  }

  function handleCancel() {
    setFormData(buildProfileForm(user));
    setIsEditing(false);
    setFeedback({ type: "", message: "" });
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setIsSaving(true);
    setFeedback({ type: "", message: "" });

    const payload = await updateProfile({
      NomUser: formData.NomUser,
      PrenomUser: formData.PrenomUser,
      EmailUser: formData.EmailUser,
      PhoneUser: formData.PhoneUser,
      SexeUser: formData.SexeUser,
      UrlPhoto: formData.UrlPhoto,
    });

    if (payload?.success) {
      setFeedback({
        type: "success",
        message: payload.message || "Profil mis a jour avec succes.",
      });
      setIsEditing(false);
      setIsSaving(false);
      return;
    }

    setFeedback({
      type: "error",
      message:
        payload === null
          ? "Impossible de joindre le backend pour enregistrer le profil."
          : payload?.message || "La mise a jour du profil a echoue.",
    });
    setIsSaving(false);
  }

  return (
    <div className="page-shell">
      <section className="page-hero-card profile-hero-card">
        <div className="profile-hero-main">
          <div className="profile-avatar-shell">
            {user?.UrlPhoto ? (
              <img className="profile-avatar-image" src={user.UrlPhoto} alt="Photo de profil" />
            ) : (
              <div className="profile-avatar-fallback">{buildInitials(user)}</div>
            )}
          </div>

          <div className="profile-hero-copy">
            <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">
              Espace utilisateur
            </span>
            <h2>
              {user?.PrenomUser} {user?.NomUser}
            </h2>
            <p>Consultez vos informations personnelles, votre rattachement et mettez a jour votre profil en toute simplicite.</p>
            <div className="profile-hero-meta">
              <span className="status-pill">{buildRoleLabel(user)}</span>
              <span className={`profile-status-badge ${user?.ValideUser ? "is-active" : "is-inactive"}`}>
                {buildStatusLabel(user)}
              </span>
              {user?.entite?.NomEntite ? <span className="status-pill is-muted">{user.entite.NomEntite}</span> : null}
            </div>
          </div>
        </div>

        <div className="profile-hero-actions">
          {!isEditing ? (
            <button className="primary-action" type="button" onClick={() => setIsEditing(true)}>
              Modifier le profil
            </button>
          ) : null}
        </div>
      </section>

      <section className="profile-stats-grid">
        <ProfileStatCard label="Role" value={buildRoleLabel(user)} tone="primary" />
        <ProfileStatCard label="Statut" value={buildStatusLabel(user)} tone={user?.ValideUser ? "success" : "danger"} />
        <ProfileStatCard label="Entite" value={user?.entite?.NomEntite || "Non renseignee"} tone="soft" />
        <ProfileStatCard label="Contact" value={user?.PhoneUser || user?.EmailUser || "Non renseigne"} tone="info" />
      </section>

      {feedback.message ? (
        <section className={`profile-feedback ${feedback.type === "success" ? "is-success" : "is-error"}`}>
          {feedback.message}
        </section>
      ) : null}

      <form onSubmit={handleSubmit}>
        <div className="profile-section-grid">
          <ProfileInfoCard
            title="Informations personnelles"
            actions={
              isEditing ? (
                <>
                  <button className="secondary-action" type="button" onClick={handleCancel} disabled={isSaving}>
                    Annuler
                  </button>
                  <button className="primary-action" type="submit" disabled={isSaving}>
                    {isSaving ? "Enregistrement..." : "Enregistrer"}
                  </button>
                </>
              ) : null
            }
          >
            {isEditing ? (
              <>
                <ProfileInput
                  label="Nom"
                  name="NomUser"
                  value={formData.NomUser}
                  onChange={handleChange}
                  required
                />
                <ProfileInput
                  label="Prenom"
                  name="PrenomUser"
                  value={formData.PrenomUser}
                  onChange={handleChange}
                  required
                />
                <ProfileInput
                  label="Email"
                  name="EmailUser"
                  type="email"
                  value={formData.EmailUser}
                  onChange={handleChange}
                  required
                />
                <ProfileInput
                  label="Telephone"
                  name="PhoneUser"
                  value={formData.PhoneUser}
                  onChange={handleChange}
                  placeholder="+243..."
                />
                <ProfileSelect
                  label="Sexe"
                  name="SexeUser"
                  value={formData.SexeUser}
                  onChange={handleChange}
                  options={[
                    { value: "M", label: "Masculin" },
                    { value: "F", label: "Feminin" },
                  ]}
                />
                <ProfileInput
                  label="Photo URL"
                  name="UrlPhoto"
                  value={formData.UrlPhoto}
                  onChange={handleChange}
                  placeholder="https://..."
                />
              </>
            ) : (
              <>
                <ProfileField label="Nom" value={user?.NomUser} />
                <ProfileField label="Prenom" value={user?.PrenomUser} />
                <ProfileField label="Email" value={user?.EmailUser} />
                <ProfileField label="Telephone" value={user?.PhoneUser} />
                <ProfileField label="Sexe" value={user?.SexeUser === "F" ? "Feminin" : user?.SexeUser === "M" ? "Masculin" : user?.SexeUser} />
                <ProfileField label="Statut" value={buildStatusLabel(user)} />
              </>
            )}
          </ProfileInfoCard>

          <ProfileInfoCard title="Rattachement">
            <ProfileField label="Role" value={buildRoleLabel(user)} />
            <ProfileField label="Entite" value={user?.entite?.NomEntite} />
            <ProfileField label="Email entite" value={user?.entite?.EmailEntite} />
            <ProfileField label="Telephone entite" value={user?.entite?.PhoneEntite} />
            <ProfileField label="Adresse entite" value={user?.entite?.AdresseEntite} />
            <ProfileField label="Id utilisateur" value={user?.IdUser != null ? String(user.IdUser) : ""} />
          </ProfileInfoCard>
        </div>
      </form>
    </div>
  );
}
