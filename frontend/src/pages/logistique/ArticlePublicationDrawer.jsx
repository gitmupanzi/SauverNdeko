import {useEffect,useRef,useState} from "react";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import {setLogistiqueArticlePublication} from "../../services/logistique";

export default function ArticlePublicationDrawer({selection,onClose,onSaved}) {
  const [busy,setBusy]=useState(false), [error,setError]=useState("");
  const mounted=useRef(false), saving=useRef(false);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  const count=selection.ids.length;
  const title=selection.visible?"Publier dans l’annuaire":"Retirer de l’annuaire";

  async function submit(){
    if(saving.current)return;
    saving.current=true;
    setBusy(true);
    setError("");
    const result=await setLogistiqueArticlePublication(selection.ids,selection.visible);
    if(!mounted.current)return;
    saving.current=false;
    setBusy(false);
    if(result?.success){onSaved(result.data);return;}
    setError(result?.message||"La visibilité n’a pas pu être modifiée.");
  }

  return <RecordEditorFrame title={title} icon="globe" onClose={onClose} onSubmit={submit} busy={busy} error={error} submitLabel={selection.visible?"Publier":"Retirer"} defaultWidth={520} storageKey="sauverndeko.article-publication.width">
    <section className="record-editor-section">
      <h3>{count===1?"1 article sélectionné":count+" articles sélectionnés"}</h3>
      <p className="record-editor-note">{selection.visible?"Les articles sélectionnés seront visibles dans l’annuaire des produits.":"Les articles sélectionnés ne seront plus visibles dans l’annuaire des produits."}</p>
    </section>
  </RecordEditorFrame>;
}
