import {useEffect,useRef,useState} from "react";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import {requestJson} from "../../services/api";
import {TERRITORY_REGISTERS,TERRITORY_ROOT} from "./territorialDefinitions";
import {OPTIONAL_BOOLEAN} from "./territorialForm";

export default function TerritoryPublicationEditor({kind,confirmation,canWrite,onClose,onSaved}){
 const {ids,published:initialValue}=confirmation;
 const [published,setPublished]=useState(initialValue);
 const [busy,setBusy]=useState(false),[error,setError]=useState("");
 const operation=useRef(null);
 const bulk=Boolean(ids);
 const title=bulk?(published?"Publier dans l’annuaire":"Retirer de l’annuaire"):"Publication par défaut";
 const dirty=!bulk&&published!==initialValue;
 useEffect(()=>()=>operation.current?.abort(),[]);

 async function submit(){
  if(operation.current||!canWrite||(!bulk&&!dirty))return;
  const controller=new AbortController();
  operation.current=controller;
  setBusy(true);
  setError("");
  const response=await requestJson(TERRITORY_ROOT+"/registres/"+kind+"/publication",{
   method:bulk?"POST":"PATCH",requiresAuth:true,signal:controller.signal,
   body:JSON.stringify(bulk?{ids,published}:{published})
  });
  if(controller.signal.aborted)return;
  operation.current=null;
  setBusy(false);
  if(response?.success)onSaved(response.data);
  else setError(response?.message||"La publication n’a pas pu être mise à jour.");
 }

 return <RecordEditorFrame title={title} subtitle={TERRITORY_REGISTERS[kind].title} icon="globe"
   onClose={onClose} onSubmit={submit} defaultWidth={620} busy={busy} dirty={dirty}
   canSubmit={canWrite&&(bulk||dirty)} submitLabel={bulk?(published?"Publier":"Retirer"):"Enregistrer"} error={error}>
  <section className="record-editor-section">
   {bulk?<><p>{ids.length===1?"1 fiche sélectionnée":ids.length+" fiches sélectionnées"}</p>
    <p className="record-editor-note">{published?"Les fiches valides et éligibles pourront apparaître dans l’annuaire.":"Les fiches sélectionnées seront retirées de l’annuaire."}</p></>
    :<div className="record-field"><label htmlFor="territory-publication-default">Publier les nouvelles fiches</label>
     <SearchSelect id="territory-publication-default" label="Publier les nouvelles fiches" value={String(published)}
      options={OPTIONAL_BOOLEAN.slice(1)} disabled={busy} onChange={value=>setPublished(value==="true")}/>
     <p className="record-editor-note">Ce réglage s’applique aux créations de ce niveau du référentiel partagé.</p></div>}
   <p className="record-editor-note">La publication des coordonnées se règle dans chaque fiche.</p>
  </section>
 </RecordEditorFrame>;
}
