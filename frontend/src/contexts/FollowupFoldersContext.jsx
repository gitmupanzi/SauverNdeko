import { accessSignature, moduleRights } from "../services/moduleAccess";
import { createContext, useContext, useEffect, useState } from "react";
import { useAuth } from "./AuthContext";
import { folderRequest as requestJson } from "../services/followupFolders";
import DrawerDialog from "../components/DrawerDialog";
import ActionButton from "../components/ActionButton";
import "../components/FollowupFolders.css";
const Context=createContext(null);
const BASE="/api/logistique/dossiers-suivi";
export function FollowupFoldersProvider({children}) {
  const {user}=useAuth();
  const [version,setVersion]=useState(0),[assignment,setAssignment]=useState(null);
  useEffect(()=>{setAssignment(null);setVersion(value=>value+1);},[user?.IdUser,user?.IdEntiteFk,user?.permissions?.canWriteData,accessSignature(user)]);
  const refresh=()=>setVersion(value=>value+1);
  return <Context.Provider value={{version,refresh,assign:(ids,objectType="article")=>{if(user?.permissions?.canWriteData && moduleRights(user,"logistique").canManage)setAssignment({ids:[...new Set(ids)],objectType});}}}>{children}{assignment?.ids.length?<AssignmentDrawer ids={assignment.ids} objectType={assignment.objectType} onClose={()=>setAssignment(null)} onDone={()=>{setAssignment(null);refresh();}}/>:null}</Context.Provider>;
}
function AssignmentDrawer({ids,objectType,onClose,onDone}) {
  const [payload,setPayload]=useState(null),[key,setKey]=useState(""),[saving,setSaving]=useState(false),[error,setError]=useState("");
  useEffect(()=>{const controller=new AbortController();requestJson(BASE,{requiresAuth:true,signal:controller.signal}).then(data=>{if(!controller.signal.aborted){setPayload(data);if(data.success){const first=data.data.folders.find(folder=>!folder.system && folder.mode==="manuel" && folder.objectType===objectType);setKey(first?.key || "");}else setError(data.message || "Les dossiers n’ont pas pu être chargés.");}});return()=>controller.abort();},[]);
  const folders=payload?.data?.folders?.filter(folder=>!folder.system && folder.mode==="manuel" && folder.objectType===objectType) || [];
  async function submit(event){event.preventDefault();if(!key || !payload?.data?.canWrite)return;setSaving(true);setError("");const result=await requestJson(BASE+"/"+key+"/membres",{method:"PUT",requiresAuth:true,body:{recordIds:ids,objectType,operation:"ajouter"}});setSaving(false);if(!result.success){setError(result.message || "Le classement a échoué.");return;}onDone();}
  return <DrawerDialog title={"Classer "+({article:"les articles",bon:"les bons de stock",facture:"les factures"})[objectType]} subtitle={ids.length+" élément"+(ids.length>1?"s sélectionnés":" sélectionné")} icon="folder" onClose={onClose} busy={saving} storageKey="sauverndeko.folder-assignment.width" defaultWidth={680} closeLabel="Fermer le classement" footer={<footer className="article-folder-form-footer"><ActionButton onClick={onClose} disabled={saving}>Annuler</ActionButton><ActionButton variant="primary" icon="folder" onClick={submit} disabled={saving || !key || !payload?.data?.canWrite}>{saving?"Classement…":"Ajouter au dossier"}</ActionButton></footer>}>
    {error?<p className="article-folder-error" role="alert">{error}</p>:null}
    {!payload?<p role="status">Chargement des dossiers…</p>:!payload.data?.customAvailable?<p className="article-folder-note">Les dossiers personnalisés ne sont pas encore activés.</p>:!folders.length?<p className="article-folder-note">Créez d’abord un dossier manuel de ce type dans « Dossiers de suivi ».</p>:<form className="article-folder-form" onSubmit={submit}><label><span>Dossier</span><select value={key} onChange={event=>setKey(event.target.value)} disabled={saving}>{folders.map(folder=><option key={folder.key} value={folder.key}>{folder.name}</option>)}</select></label><p className="article-folder-note">Un enregistrement peut appartenir à plusieurs dossiers de même type.</p></form>}
  </DrawerDialog>;
}
export function useFollowupFolders(){const context=useContext(Context);if(!context)throw Error("FollowupFoldersProvider manquant");return context;}
