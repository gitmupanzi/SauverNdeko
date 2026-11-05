import {useEffect,useState} from "react";
import {requestJson} from "../services/api";

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
