import {useCallback, useEffect, useId, useRef, useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {requestJson} from "../../services/api";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import DrawerDialog from "../../components/DrawerDialog";
import SearchSelect from "../../components/SearchSelect";
import "./AdminPermissions.css";

const RIGHTS = [["canRead", "Consulter"], ["canManage", "Gérer"], ["canExport", "Exporter"]];
const STORED_RIGHTS = {canRead: "PeutConsulter", canManage: "PeutGerer", canExport: "PeutExporter"};

/** Same role baseline and version contract as Licences et applications. */
export function permissionsDraft(role, catalogue = []) {
  return Object.fromEntries(catalogue.map(module => {
    const stored = role?.permissions?.find(item => item.CodeModule === module.CodeModule);
    const baseline = role?.baseline?.[module.CodeModule] || {};
    const rights = Object.fromEntries(RIGHTS.map(([key]) => [key, Boolean(baseline[key] && (!stored || (stored.Actif && stored[STORED_RIGHTS[key]])))]));
    if (!rights.canRead) { rights.canManage = false; rights.canExport = false; }
    return [module.CodeModule, rights];
  }));
}

function validConfiguration(data, entity) {
  return String(data?.entityId) === entity && Array.isArray(data?.roles) && Array.isArray(data?.catalogue);
}

/** Embedded administration screen; its host guards navigation and logout. */
export default function AdminPermissions({canWrite = false, onChanged, onDirtyChange, onBusyChange, initialEntityId = ""}) {
  const {user, refreshUser} = useAuth();
  const fieldId = useId();
  const platform = user?.moduleAccess?.platformAdmin === true;
  const [organisations, setOrganisations] = useState([]);
  const [organisationsReady, setOrganisationsReady] = useState(false);
  const [organisationsLoading, setOrganisationsLoading] = useState(true);
  const [configurationLoading, setConfigurationLoading] = useState(false);
  const [entity, setEntity] = useState("");
  const [data, setData] = useState(null);
  const [roleId, setRoleId] = useState("");
  const [permissions, setPermissions] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [uncertain, setUncertain] = useState(false);
  const [organisationRetry, setOrganisationRetry] = useState(0);
  const [configurationRevision, setConfigurationRevision] = useState(0);
  const [pendingTransition, setPendingTransition] = useState(null);
  const mounted = useRef(true);
  const generation = useRef(0);
  const saveLock = useRef(false);
  const selections = useRef({entity: "", roleId: ""});
  const initialEntity = useRef(String(initialEntityId || ""));
  const notifications = useRef({onDirtyChange, onBusyChange});
  notifications.current = {onDirtyChange, onBusyChange};
  const clearConfiguration = useCallback(() => {
    setData(null); setRoleId(""); setPermissions({}); setConfigurationLoading(false); setUncertain(false);
  }, []);
  const dismissTransition = useCallback(() => setPendingTransition(null), []);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false; generation.current += 1;
      notifications.current.onDirtyChange?.(false);
      notifications.current.onBusyChange?.(false);
    };
  }, []);

  useEffect(() => {
    const controller = new AbortController(); let active = true;
    generation.current += 1;
    setOrganisations([]); setOrganisationsReady(false); setOrganisationsLoading(true);
    setEntity(""); setError(""); setMessage(""); clearConfiguration();
    async function load() {
      const result = await requestJson("/api/workspace/organisations", {requiresAuth: true, signal: controller.signal});
      if (!active || !mounted.current) return;
      if (!result?.success || !Array.isArray(result.data)) {
        setError(result?.message || "Les entreprises n’ont pas pu être chargées.");
      } else {
        const preferred = [selections.current.entity, initialEntity.current, user?.IdEntiteFk].find(id => id != null && id !== "" && result.data.some(row => String(row.IdEntite) === String(id)));
        setOrganisations(result.data); setEntity(String(preferred ?? result.data[0]?.IdEntite ?? ""));
        setOrganisationsReady(true);
      }
      setOrganisationsLoading(false);
    }
    void load();
    return () => { active = false; controller.abort(); };
  }, [user?.IdUser, user?.IdEntiteFk, organisationRetry, clearConfiguration]);

  useEffect(() => {
    const id = ++generation.current, controller = new AbortController(); let active = true;
    clearConfiguration();
    if (!organisationsReady || !entity || !organisations.some(row => String(row.IdEntite) === entity)) return;
    setConfigurationLoading(true); setError(""); setMessage("");
    async function load() {
      const result = await requestJson("/api/workspace/roles?entite=" + encodeURIComponent(entity), {requiresAuth: true, signal: controller.signal});
      if (!active || !mounted.current || generation.current !== id) return;
      if (!result?.success || !validConfiguration(result.data, entity)) {
        setError(result?.message || "Les permissions n’ont pas pu être chargées.");
      } else {
        const previous = selections.current.entity === entity ? selections.current.roleId : "";
        const role = result.data.roles.find(row => String(row.IdRoleFk) === previous) || result.data.roles[0];
        const nextRoleId = String(role?.IdRoleFk || "");
        selections.current = {entity, roleId: nextRoleId};
        setData(result.data); setRoleId(nextRoleId); setPermissions(permissionsDraft(role, result.data.catalogue));
      }
      setConfigurationLoading(false);
    }
    void load();
    return () => { active = false; controller.abort(); if (generation.current === id) generation.current += 1; };
  }, [entity, organisationsReady, organisations, configurationRevision, clearConfiguration]);

  const loading = organisationsLoading || configurationLoading;
  const scoped = organisationsReady && Boolean(entity) && validConfiguration(data, entity);
  const role = scoped ? data.roles.find(item => String(item.IdRoleFk) === roleId) : null;
  const dirty = Boolean(role) && JSON.stringify(permissions) !== JSON.stringify(permissionsDraft(role, data.catalogue));
  const canManage = Boolean(canWrite && platform && scoped && role && data?.canManage === true && !loading && !saving && !uncertain);

  useEffect(() => { notifications.current.onDirtyChange?.(dirty); }, [dirty]);
  useEffect(() => { notifications.current.onBusyChange?.(saving); }, [saving]);
  useEffect(() => {
    if (!dirty && !saving) return;
    const beforeUnload = event => { event.preventDefault(); event.returnValue = ""; };
    window.addEventListener("beforeunload", beforeUnload);
    return () => window.removeEventListener("beforeunload", beforeUnload);
  }, [dirty, saving]);

  function requestTransition(action) {
    if (saveLock.current) return;
    if (dirty) setPendingTransition({run: action}); else action();
  }
  function confirmTransition() {
    if (saveLock.current) return;
    const action = pendingTransition?.run;
    setPendingTransition(null); action?.();
  }
  function chooseEntity(id) {
    if (id === entity) return;
    requestTransition(() => { generation.current += 1; clearConfiguration(); setEntity(id); setError(""); setMessage(""); });
  }
  function chooseRole(id) {
    if (id === roleId || !scoped) return;
    requestTransition(() => {
      const next = data.roles.find(item => String(item.IdRoleFk) === id);
      selections.current = {entity, roleId: id}; setRoleId(id);
      setPermissions(permissionsDraft(next, data.catalogue)); setError(""); setMessage(""); setUncertain(false);
    });
  }
  function reload() {
    requestTransition(() => organisationsReady ? setConfigurationRevision(value => value + 1) : setOrganisationRetry(value => value + 1));
  }
  function changeRight(code, key, checked) {
    if (!canManage || saveLock.current || !role?.baseline?.[code]?.[key]) return;
    if (key !== "canRead" && !permissions[code]?.canRead) return;
    setPermissions(current => {
      const next = {...current[code], [key]: checked};
      if (key === "canRead" && !checked) { next.canManage = false; next.canExport = false; }
      return {...current, [code]: next};
    });
    setMessage("");
  }
  async function save() {
    if (!canManage || !dirty || saveLock.current) return;
    const id = generation.current, savedRoleId = roleId;
    const versions = Object.fromEntries(data.catalogue.map(module => [module.CodeModule, role.permissions?.find(item => item.CodeModule === module.CodeModule)?.Version || 0]));
    const body = {entityId: Number(entity), versions, permissions};
    saveLock.current = true; setSaving(true); setError(""); setMessage("");
    try {
      const result = await requestJson("/api/workspace/roles/" + savedRoleId, {method: "PUT", requiresAuth: true, body: JSON.stringify(body)});
      if (!mounted.current || generation.current !== id) return;
      if (!result?.success) {
        if (!result?.status || result.status >= 500 || result.status === 409) {
          setUncertain(true);
          setError(result.status === 409 ? "Ces droits ont changé. Rechargez la configuration avant de les modifier." : "La réponse de l’enregistrement est incertaine. Rechargez la configuration pour vérifier les droits enregistrés.");
        } else setError(result.message || "Les permissions n’ont pas pu être enregistrées.");
        return;
      }
      if (!validConfiguration(result.data, entity) || !result.data.roles.some(item => String(item.IdRoleFk) === savedRoleId)) {
        setUncertain(true); setError("La réponse reçue doit être vérifiée. Rechargez la configuration."); return;
      }
      const savedRole = result.data.roles.find(item => String(item.IdRoleFk) === savedRoleId);
      setData(result.data); setPermissions(permissionsDraft(savedRole, result.data.catalogue)); setUncertain(false);
      setMessage("Permissions enregistrées.");
      window.dispatchEvent(new Event("sauverndeko:applications-changed"));
      try { await refreshUser(); }
      catch { if (mounted.current && generation.current === id) setError("Les permissions sont enregistrées. Reconnectez-vous pour actualiser vos accès."); }
      if (mounted.current && generation.current === id) onChanged?.(result.data);
    } catch {
      if (mounted.current && generation.current === id) {
        setUncertain(true);
        setError("L’enregistrement doit être vérifié. Rechargez la configuration avant de modifier les droits.");
      }
    } finally {
      saveLock.current = false; if (mounted.current) setSaving(false);
    }
  }

  return <section className="admin-permissions" aria-busy={loading || saving}>
    <div className="admin-permissions-controls">
      <div><label htmlFor={fieldId + "-entity"}>Entreprise</label><SearchSelect id={fieldId + "-entity"} label="Entreprise" value={entity} onChange={chooseEntity} loading={organisationsLoading} disabled={saving || !organisationsReady || !organisations.length} options={organisations.map(item => ({value: String(item.IdEntite), label: item.NomEntite + (item.ValideEntite === false ? " · Inactive" : "")}))}/></div>
      <div><label htmlFor={fieldId + "-role"}>Rôle</label><SearchSelect id={fieldId + "-role"} label="Rôle" value={roleId} onChange={chooseRole} loading={configurationLoading} disabled={saving || !scoped || !data?.roles.length} options={(data?.roles || []).map(item => ({value: String(item.IdRoleFk), label: item.NomRole}))}/></div>
      <ActionButton icon="refresh" disabled={saving || loading} onClick={reload}>Actualiser</ActionButton>
    </div>
    {error ? <div className="admin-permissions-message is-error" role="alert"><span>{error}</span><ActionButton icon="refresh" disabled={saving || loading} onClick={reload}>Recharger</ActionButton></div> : null}
    {message ? <p className="admin-permissions-message is-success" role="status"><AppIcon name="check-circle"/>{message}</p> : null}
    {loading ? <p className="admin-permissions-state" role="status">Chargement des permissions…</p> : null}
    {!loading && organisationsReady && !organisations.length ? <p className="admin-permissions-state">Aucune entreprise disponible.</p> : null}
    {!loading && scoped && !role ? <p className="admin-permissions-state">Aucun rôle disponible pour cette entreprise.</p> : null}
    {!loading && scoped && role ? <>
      <div className="admin-permissions-context"><span className="admin-permissions-mark"><AppIcon name="shield"/></span><div><strong>{role.NomRole}</strong><span>{organisations.find(item => String(item.IdEntite) === entity)?.NomEntite}</span></div><span className="admin-permissions-mode">{canWrite && platform && data.canManage ? "Droits par application" : "Consultation"}</span></div>
      <div className="admin-permissions-table-wrap erp-results"><table className="admin-permissions-table"><thead><tr><th scope="col">Application</th>{RIGHTS.map(([key, label]) => <th scope="col" key={key}>{label}</th>)}</tr></thead><tbody>{data.catalogue.map(module => <tr key={module.CodeModule}><th scope="row"><span>{module.Nom}</span>{module.EstSocle ? <small>Socle inclus</small> : null}</th>{RIGHTS.map(([key, label]) => <td key={key}><input type="checkbox" aria-label={label + " · " + module.Nom} checked={permissions[module.CodeModule]?.[key] || false} disabled={!canManage || !role.baseline?.[module.CodeModule]?.[key] || (key !== "canRead" && !permissions[module.CodeModule]?.canRead)} onChange={event => changeRight(module.CodeModule, key, event.target.checked)}/></td>)}</tr>)}{!data.catalogue.length ? <tr><td colSpan={4}>Aucune application disponible.</td></tr> : null}</tbody></table></div>
      <p className="admin-permissions-note">Les droits restent limités aux habilitations du rôle et aux applications de l’entreprise.</p>
      <footer className="admin-permissions-footer"><span>{dirty ? "Modifications non enregistrées" : "Les accès suivent les droits enregistrés."}</span>{canWrite && platform && data.canManage ? <div><ActionButton icon="reset" disabled={saving || !dirty || uncertain} onClick={() => requestTransition(() => {setPermissions(permissionsDraft(role, data.catalogue)); setError(""); setMessage("");})}>Annuler</ActionButton><ActionButton icon="check-circle" variant="primary" disabled={!canManage || !dirty} onClick={save}>{saving ? "Enregistrement…" : "Enregistrer"}</ActionButton></div> : null}</footer>
    </> : null}
    {pendingTransition ? <DrawerDialog title="Modifications non enregistrées" icon="alert" onClose={dismissTransition} defaultWidth={560} className="admin-permissions-confirm" storageKey="sauverndeko.admin.permissions.discard.width" footer={<footer className="admin-permissions-footer"><span/><div><ActionButton onClick={dismissTransition}>Continuer la saisie</ActionButton><ActionButton variant="primary" onClick={confirmTransition}>Abandonner</ActionButton></div></footer>}><p>Continuer sans enregistrer les modifications ?</p></DrawerDialog> : null}
  </section>;
}
