import {useEffect,useId,useRef,useState} from "react";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import {requestJson} from "../../services/api";
import {formatCurrency} from "../../utils/money";
import {referenceBatchId} from "../referentiels/referenceBatch";
import {CAISSE_ROOT,caisseResponseUncertain} from "./caisseModel";

const VALIDATION_URL = CAISSE_ROOT + "/ecritures/validation";

export default function CaisseValidation({rows,onClose,onSaved}) {
  const prefix = useId();
  const [selection] = useState(() => rows.map(({id,_version,code}) => ({id,_version,code})));
  const [preview,setPreview] = useState(null);
  const [loading,setLoading] = useState(true);
  const [error,setError] = useState("");
  const [motif,setMotif] = useState("");
  const [busy,setBusy] = useState(false);
  const [uncertain,setUncertain] = useState(false);
  const [retry,setRetry] = useState(0);
  const request = useRef(null);
  const attempt = useRef(null);
  const validVersions = selection.every(row => typeof row._version === "string" && /^[1-9]\d*$/.test(row._version));
  const total = selection.length;
  const single = total === 1;

  useEffect(() => {
    const controller = new AbortController();
    setPreview(null);
    if (!total || !validVersions) {
      setLoading(false);
      setError("Rechargez le registre puis sélectionnez de nouveau les écritures.");
      return () => controller.abort();
    }
    setLoading(true);
    setError("");
    requestJson(VALIDATION_URL+"/apercu",{requiresAuth:true,method:"POST",
      body:JSON.stringify({rows:selection.map(({id,_version})=>({id,_version}))}),signal:controller.signal}).then(response=>{
      if (controller.signal.aborted) return;
      setLoading(false);
      if (response?.success) setPreview(response.data);
      else setError(response?.message || "Le contrôle de la sélection n’a pas abouti.");
    });
    return () => controller.abort();
  },[selection,total,validVersions,retry]);
  useEffect(() => () => request.current?.abort(),[]);

  const ready = preview?.rows?.length === total && preview.rows.every(row => row.eligible);
  async function submit() {
    if (request.current || (!ready && !uncertain) || !motif.trim()) return;
    if (!attempt.current) attempt.current = JSON.stringify({rows:selection.map(({id,_version})=>({id,_version})),
      requestId:referenceBatchId(),motif:motif.trim()});
    const controller = new AbortController();
    request.current = controller;
    setBusy(true);
    setError("");
    const response = await requestJson(VALIDATION_URL,{requiresAuth:true,method:"POST",body:attempt.current,signal:controller.signal});
    if (controller.signal.aborted) return;
    request.current = null;
    setBusy(false);
    if (response?.success) {
      const count = response.data?.count || total;
      onSaved({message:count===1?"Écriture validée.":count+" écritures validées."});
      return;
    }
    if (caisseResponseUncertain(response)) {
      setUncertain(true);
      setError("La confirmation est indisponible. Réessayez pour vérifier cette même validation.");
      return;
    }
    attempt.current = null;
    setUncertain(false);
    const rejection = response?.error?.details;
    setPreview(previous=>Array.isArray(rejection?.rows)
      ? {...previous,rows:rejection.rows.map(row=>({...row,eligible:row.eligible===true||row.eligible==="True"}))}
      : null);
    setError(rejection?.message || response?.message || "La validation n’a pas abouti.");
  }

  return <RecordEditorFrame title={single?"Valider l’écriture":"Valider la sélection"} icon="check-circle"
    subtitle={single?selection[0].code:undefined} loading={loading} busy={busy} error={error}
    onClose={onClose} onSubmit={submit} dirty={uncertain||Boolean(motif.trim())}
    canSubmit={Boolean((ready||uncertain)&&motif.trim())}
    onReload={error&&validVersions&&!uncertain?()=>setRetry(value=>value+1):undefined}
    submitLabel={uncertain?"Vérifier la validation":single?"Valider l’écriture":"Valider "+total+" écritures"}
    defaultWidth={820} className="caisse-editor" storageKey="sauverndeko.caisse.validation.width">
    {preview?<><section className="record-editor-section">
      <h3>{total===1?"1 écriture sélectionnée":total+" écritures sélectionnées"}</h3>
      <div className="caisse-validation-totals">{preview.totals?.map(currency=>
        <dl className="caisse-summary caisse-balance" key={currency.currencyId??currency.currency}>
          <div><dt>Encaissements</dt><dd>{formatCurrency(currency.entries,currency.currency)}</dd></div>
          <div><dt>Décaissements</dt><dd>{formatCurrency(currency.exits,currency.currency)}</dd></div>
        </dl>)}</div>
      <ul className="caisse-validation-rows" aria-label="Contrôle des écritures">
        {preview.rows.map(row=><li key={row.id}><strong>{row.code||selection.find(item=>String(item.id)===String(row.id))?.code||"Écriture"}</strong>
          {row.eligible?<span className="erp-status is-success">Prête à valider</span>:
            <span className="record-field-error">{row.reason||"Validation indisponible."}</span>}</li>)}
      </ul>
      <p className="record-editor-note">{ready?"La validation met à jour le solde de la caisse. La clôture se fait séparément."
        :"Corrigez les lignes signalées ou modifiez votre sélection dans le registre."}</p>
    </section>
    <section className="record-editor-section caisse-fields"><h3>Traçabilité</h3>
      <div className="caisse-field-grid"><label className="is-wide" htmlFor={prefix+"-motif"}><span>Motif de la validation *</span>
        <textarea id={prefix+"-motif"} rows={3} maxLength={1000} value={motif}
          disabled={busy||uncertain} onChange={event=>setMotif(event.target.value)}/>
      </label></div>
    </section></>:null}
  </RecordEditorFrame>;
}
