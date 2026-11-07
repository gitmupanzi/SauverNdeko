import {useEffect,useState} from "react";
import {requestJson} from "../services/api";

// Le masquage du menu n'altère ni l'identité d'un lien ni les contrôles d'accès.
export function moduleTabKey(tabs, key, fallback = "dashboard") {
  return tabs.find(tab => tab.key === key)?.key ?? fallback;
}

export function presentedModuleTabs(tabs, presentation) {
  return tabs.filter(tab => !presentation?.hiddenTabs?.includes(tab.key)).map(tab => ({
    ...tab,
    label:presentation?.tabLabels?.[tab.key] || tab.label,
  }));
}

export function useModulePresentation(moduleKey,{entityId,scopeKey}) {
  const [state,setState]=useState(null);
  const [revision,setRevision]=useState(0);
  const current=entityId&&state?.scopeKey===scopeKey&&state.moduleKey===moduleKey?state:null;
  useEffect(()=>{
    if(!entityId)return;
    const controller=new AbortController();
    requestJson("/api/"+moduleKey+"/presentation",{requiresAuth:true,signal:controller.signal}).then(response=>{
      if(controller.signal.aborted)return;
      const presentation=response?.success&&String(response.data?.entityId)===String(entityId)?response.data:null;
      setState({scopeKey,moduleKey,presentation});
    });
    return()=>controller.abort();
  },[moduleKey,entityId,scopeKey,revision]);
  return {
    presentation:current?.presentation,
    loading:Boolean(entityId&&!current),
    error:Boolean(current&&!current.presentation),
    retry:()=>setRevision(value=>value+1),
  };
}
