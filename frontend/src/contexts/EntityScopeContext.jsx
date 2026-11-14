import {createContext,useContext,useEffect,useLayoutEffect,useMemo,useState} from "react";
import {useAuth} from "./AuthContext";
import {accessSignature,moduleRights} from "../services/moduleAccess";
import {requestJson} from "../services/api";
import {configureEntityScope} from "../services/entityScope";

const Context=createContext(null);
export function EntityScopeProvider({children}) {
  const {user,isAuthenticated}=useAuth();
  const globalAdmin=user?.Is_Admin===true||user?.moduleAccess?.platformAdmin===true;
  const userKey=String(user?.IdUser||""),[choice,setChoice]=useState({userKey:"",value:""});
  const entityId=globalAdmin?(choice.userKey===userKey?choice.value:""):String(user?.IdEntiteFk||"");
  const [entities,setEntities]=useState([]),[loading,setLoading]=useState(false),[error,setError]=useState(""),[revision,setRevision]=useState(0);
  const scopeKey=userKey+":"+(globalAdmin?entityId||"all":entityId||"none")+":"+accessSignature(user);
  useLayoutEffect(()=>{configureEntityScope({userId:userKey,entityId,globalAdmin});},[userKey,entityId,globalAdmin]);
  useEffect(()=>{
    let active=true;setEntities([]);setError("");
    if(!isAuthenticated||!(moduleRights(user,"logistique").canRead||moduleRights(user,"caisse").canRead||moduleRights(user,"professionnels").canRead||moduleRights(user,"administration").canRead||moduleRights(user,"support").canRead||moduleRights(user,"data-science").canRead||moduleRights(user,"parametres").canRead||moduleRights(user,"guide").canRead||moduleRights(user,"structures").canManage)){setLoading(false);return()=>{active=false;};}
    setLoading(true);
    requestJson(moduleRights(user,"administration").canRead?"/api/systeme/administration/entreprises":moduleRights(user,"logistique").canRead?"/api/logistique/entreprises":moduleRights(user,"caisse").canRead?"/api/caisse/entreprises":moduleRights(user,"professionnels").canRead?"/api/professionnels/entreprises":moduleRights(user,"structures").canManage?"/api/structures/entreprises":moduleRights(user,"support").canRead?"/api/support/entreprises":moduleRights(user,"data-science").canRead?"/api/data-science/entreprises":moduleRights(user,"parametres").canRead?"/api/parametres/entreprises":"/api/guide/entreprises",{requiresAuth:true}).then(response=>{
      if(!active)return;setLoading(false);
      if(!response?.success){setError(response?.message||"Les entreprises ne sont pas disponibles.");return;}
      setEntities(Array.isArray(response.data)?response.data:[]);
    });
    return()=>{active=false;};
  },[userKey,isAuthenticated,accessSignature(user),revision]);
  function selectEntity(value){
    if(!globalAdmin||document.querySelector("dialog[open]"))return;
    const id=String(value||"");
    if(id&&!entities.some(item=>String(item.id)===id&&item.active!==false))return;
    setChoice({userKey,value:id});
  }
  const canWrite=user?.permissions?.canWriteData===true&&moduleRights(user,"logistique").canManage===true&&Boolean(entityId);
  const value=useMemo(()=>({entityId,globalAdmin,scopeKey,entities,loading,error,selectEntity,retry:()=>setRevision(x=>x+1),canWrite,canCreate:canWrite}),[entityId,globalAdmin,scopeKey,entities,loading,error,canWrite]);
  return <Context.Provider value={value}>{children}</Context.Provider>;
}
export function useEntityScope(){const value=useContext(Context);if(!value)throw Error("EntityScopeProvider manquant");return value;}
