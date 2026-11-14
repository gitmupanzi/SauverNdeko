import { useEffect, useId, useRef, useState } from "react";
import { useAuth } from "../../contexts/AuthContext";
import { useEntityScope } from "../../contexts/EntityScopeContext";
import { requestJson } from "../../services/api";
import { newMessageRequestId } from "../../services/communication";
import { accessSignature } from "../../services/moduleAccess";
import ActionButton from "../../components/ActionButton";
import SearchSelect from "../../components/SearchSelect";
import { SimpleTable, formatDate } from "../logistique/logistiqueShared";
import { demandDeliveryUncertain, demandFailure } from "./demandModel";
import useDemandRead from "./useDemandRead";

const root = "/api/discussions/besoins";
const sources = [
  { value: "product", label: "Produit" },
  { value: "expert", label: "Professionnel" },
  { value: "structure", label: "Structure" },
];
const natures = [
  { value: "besoin_sans_resultat", label: "Besoin sans résultat" },
  { value: "recherche", label: "Partage de recherche" },
];
const states = {
  en_attente: "En attente",
  satisfaite: "Satisfait",
  non_satisfaite: "Non satisfait",
};
const read = (path, signal) => requestJson(root + path, { requiresAuth: true, signal });
const write = (path, body) => requestJson(root + path, {
  requiresAuth: true, method: "POST", body: JSON.stringify(body),
});
const optionValue = value => value ? Number(value) : null;
const labelOf = (options, value) => options.find(option => option.value === value)?.label || "—";
const withBlank = (options, label) => [
  { value: "", label }, ...options.map(option => ({ ...option, value: String(option.value) })),
];

export function needHandoff(value) {
  if (!sources.some(source => source.value === value?.source)) return null;
  return { source: value.source, nature: value.nature === "recherche" ? "recherche" : "besoin_sans_resultat" };
}

export default function NeedRegister({ handoff }) {
  const { user } = useAuth();
  const scope = useEntityScope();
  const owner = [user?.IdUser, scope.scopeKey, accessSignature(user)].join(":");
  return <OwnedNeedRegister key={owner} owner={owner} handoff={handoff}/>;
}

function OwnedNeedRegister({ owner, handoff }) {
  const prefix = useId();
  const [draft, setDraft] = useState(() => ({
    source: handoff?.source || "", nature: handoff?.nature || "besoin_sans_resultat",
    provinceId: "", categoryId: "", topicId: "", consent: false,
  }));
  const [grid, setGrid] = useState({ take: 25, skip: 0 });
  const [revision, setRevision] = useState(0);
  const [busy, setBusy] = useState("");
  const [issue, setIssue] = useState("");
  const [notice, setNotice] = useState("");
  const [uncertain, setUncertain] = useState(false);
  const running = useRef(false);
  const alive = useRef(false);
  const attempted = useRef(null);
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);

  const options = useDemandRead({
    identity: owner + ":need-options", revision, load: signal => read("/options", signal),
    parse: response => {
      const data = response.data;
      return typeof data?.canWrite === "boolean" &&
        [data.provinces, data.categories, data.topics].every(Array.isArray) ? data : null;
    },
    message: "Les choix n’ont pas pu être chargés.",
  });
  const list = useDemandRead({
    identity: owner + ":needs:" + grid.take + ":" + grid.skip,
    revision, load: signal => read("?" + new URLSearchParams(grid), signal),
    parse: response => Array.isArray(response.data?.rows) &&
      Number.isSafeInteger(response.data.total) && response.data.total >= response.data.rows.length
      ? response.data : null,
    message: "Vos besoins n’ont pas pu être chargés.",
  });
  const canWrite = options.data?.canWrite === true && !options.loading && !options.error;
  const isSearch = draft.nature === "recherche";
  const ready = canWrite && Boolean(draft.source) &&
    (!isSearch || (draft.consent && Boolean(draft.categoryId || draft.topicId)));
  const frozen = Boolean(busy) || uncertain || !canWrite;

  function update(key, value) {
    setDraft(previous => ({
      ...previous,
      ...(key === "topicId" && value ? { categoryId: "" } : {}),
      ...(key === "categoryId" && value ? { topicId: "" } : {}),
      ...(key === "nature" || key === "source" ? { consent: false } : {}),
      [key]: value,
    }));
    setIssue("");
    setNotice("");
  }

  async function submit(event) {
    event.preventDefault();
    if (!ready || running.current) return;
    running.current = true;
    setBusy("intake");
    setIssue("");
    setNotice("");
    const body = attempted.current || {
      ...draft, requestId: newMessageRequestId(), provinceId: optionValue(draft.provinceId),
      categoryId: optionValue(draft.categoryId), topicId: optionValue(draft.topicId),
    };
    attempted.current = body;
    const result = await write("", body);
    if (!alive.current) return;
    running.current = false;
    setBusy("");
    const unknown = !result?.success && demandDeliveryUncertain(result);
    setUncertain(unknown);
    if (!unknown) attempted.current = null;
    if (result?.success) {
      setNotice("Enregistrement confirmé. Aucun message n’a été envoyé.");
      setDraft(previous => ({ ...previous, provinceId: "", categoryId: "", topicId: "", consent: false }));
      setGrid(previous => ({ ...previous, skip: 0 }));
      setRevision(value => value + 1);
    } else {
      setIssue(unknown ? "Enregistrement non confirmé. Réessayez avec les mêmes choix."
        : demandFailure(result, "Le besoin n’a pas pu être enregistré."));
    }
  }

  async function mark(row, state) {
    if (!canWrite || uncertain || running.current) return;
    running.current = true;
    setBusy(String(row.id));
    setIssue("");
    setNotice("");
    const result = await write("/" + encodeURIComponent(row.id) + "/issue", { state });
    if (!alive.current) return;
    running.current = false;
    setBusy("");
    if (!result?.success) setIssue(demandFailure(result, "L’issue n’a pas pu être confirmée."));
    else setNotice("Issue enregistrée.");
    setRevision(value => value + 1);
  }

  function field(key, label, options) {
    const id = prefix + "-" + key;
    return <label htmlFor={id}><span>{label}</span>
      <SearchSelect id={id} label={label} options={options} value={draft[key]}
        onChange={value => update(key, value)} disabled={frozen}/>
    </label>;
  }

  const columns = [
    { key: "source", label: "Domaine", sortable: false, render: row => labelOf(sources, row.source) },
    { key: "nature", label: "Type", sortable: false, render: row => labelOf(natures, row.nature) },
    { key: "province", label: "Province", sortable: false, render: row => row.province || "—" },
    { key: "classification", label: "Catégorie ou thème", sortable: false, render: row => row.category || row.topic || "—" },
    { key: "createdAt", label: "Date", sortable: false, render: row => formatDate(row.createdAt) },
    { key: "state", label: "Issue", sortable: false, render: row => states[row.state] || "—" },
    ...(canWrite ? [{ key: "actions", label: "Déclarer l’issue", sortable: false, render: row =>
      row.state === "en_attente" ? <div className="demand-actions">
        <ActionButton disabled={Boolean(busy) || uncertain || list.loading} onClick={() => mark(row, "satisfaite")}>Satisfait</ActionButton>
        <ActionButton disabled={Boolean(busy) || uncertain || list.loading} onClick={() => mark(row, "non_satisfaite")}>Non satisfait</ActionButton>
      </div> : null,
    }] : []),
  ];
  return <div className="demand-register-content erp-results">
    {notice && <p className="demand-feedback" role="status">{notice}</p>}
    {issue && <p className="demand-feedback" role="alert">{issue}</p>}
    {options.error && <div className="demand-feedback" role="alert">{options.error}
      <ActionButton icon="refresh" onClick={() => setRevision(value => value + 1)}>Réessayer</ActionButton>
    </div>}
    {options.loading && <p className="demand-note" role="status">Chargement des choix…</p>}
    {canWrite && <form className="record-editor-section" onSubmit={submit} aria-busy={busy === "intake"}>
      <h3>{isSearch ? "Partager une recherche" : "Exprimer un besoin"}</h3>
      <p className="demand-note">Choisissez les informations à enregistrer. Aucun message n’est envoyé. Une recherche de professionnel ne constitue pas un diagnostic.</p>
      <div className="demand-fields">
        {field("source", "Domaine", withBlank(sources, "Choisir le domaine"))}
        {field("nature", "Type", natures)}
        {field("provinceId", "Province (facultatif)", withBlank(options.data.provinces, "Non renseignée"))}
        {field("categoryId", "Catégorie", withBlank(options.data.categories, "Aucune catégorie"))}
        {field("topicId", "Thème", withBlank(options.data.topics, "Aucun thème"))}
      </div>
      {isSearch && <p className="demand-note">Choisissez une catégorie ou un thème pour partager cette recherche.</p>}
      <div className="demand-actions">
        <label><input type="checkbox" checked={draft.consent} disabled={frozen}
          onChange={event => update("consent", event.target.checked)}/> J’accepte l’utilisation des choix sélectionnés pour les analyses agrégées.</label>
        <ActionButton type="submit" variant="primary" disabled={!ready || Boolean(busy)}>
          {uncertain ? "Vérifier l’enregistrement" : "Confirmer l’enregistrement"}
        </ActionButton>
      </div>
    </form>}
    <h3>Mes besoins et recherches partagées</h3>
    {list.error && <div className="demand-feedback" role="alert">{list.error}
      <ActionButton icon="refresh" onClick={() => setRevision(value => value + 1)}>Réessayer</ActionButton>
    </div>}
    <SimpleTable rows={list.error ? [] : list.data?.rows || []} columns={columns}
      getRowId={row => String(row.id)} enableSelection={false} showControls={false}
      loading={list.loading} tableLabel="Mes besoins et recherches partagées"
      serverState={grid} onServerChange={change => setGrid(previous => ({ ...previous, ...change }))}
      serverMeta={list.data && !list.error ? { ...grid, totalCount: list.data.total, filteredCount: list.data.total } : null}
      emptyMessage={list.error ? "La liste est indisponible." : "Vous n’avez encore enregistré aucun besoin ou recherche."}/>
  </div>;
}
