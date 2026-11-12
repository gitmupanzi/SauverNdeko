import {useEffect,useRef,useState} from "react";
import {requestJson} from "../../services/api";
import {referenceOptions,retainReference} from "../../utils/referenceOptions";
import {SUPPORT_ROOT,supportUncertain} from "./supportForm";

export const PROCESS_URL=SUPPORT_ROOT+"/processus";
export const PROCESS_METRICS=[
  {key:"active",label:"Parcours en cours",icon:"folder"},
  {key:"late",label:"Délais dépassés",icon:"clock"},
  {key:"blocked",label:"Parcours bloqués",icon:"alert"},
  {key:"awaitingReceipt",label:"Étapes à réceptionner",icon:"check-circle"},
];
export const PROCESS_ACTIONS={
  start:{label:"Démarrer le parcours",icon:"plus"},
  receive:{label:"Confirmer la réception",icon:"check-circle"},
  advance:{label:"Transmettre à l’étape suivante",icon:"arrow-right"},
  return:{label:"Renvoyer à une étape précédente",icon:"movements"},
  approve:{label:"Valider l’étape",icon:"check-circle"},
  reject:{label:"Refuser la validation",icon:"close"},
  block:{label:"Signaler un blocage",icon:"alert"},
  unblock:{label:"Lever le blocage",icon:"check-circle"},
  assign:{label:"Changer le responsable",icon:"user"},
};

export const PROCESS_EVENTS={
  start:"Parcours démarré",
  receive:"Réception confirmée",
  advance:"Étape transmise",
  return:"Retour à une étape précédente",
  approve:"Validation accordée",
  reject:"Validation refusée",
  block:"Blocage signalé",
  unblock:"Blocage levé",
  assign:"Responsable modifié",
  complete:"Parcours terminé",
};

export function processOptions(rows,value="",emptyLabel="Non renseigné"){
  const options=retainReference(referenceOptions(rows||[]),value,"Valeur actuelle hors des choix disponibles");
  return [{value:"",label:emptyLabel},...options];
}

export function useProcessQuery(url,refresh=0){
  const [retry,setRetry]=useState(0);
  const [state,setState]=useState(null);
  const key=url+"|"+refresh+"|"+retry;

  useEffect(()=>{
    if(!url)return;
    const controller=new AbortController();
    requestJson(url,{requiresAuth:true,signal:controller.signal}).then(response=>{
      if(controller.signal.aborted)return;
      setState({
        key,
        data:response?.success?response.data:null,
        error:response?.success?"":response?.message||"Les données n’ont pas pu être chargées.",
      });
    });
    return ()=>controller.abort();
  },[key,url]);

  const current=state?.key===key?state:null;
  const loading=Boolean(url&&!current);
  return {
    data:current?.data??null,previousData:loading?state?.data:null,error:current?.error||"",loading,
    reload:()=>setRetry(value=>value+1),
  };
}

export function useProcessMutation(){
  const attempt=useRef(null);
  const active=useRef(null);
  const [state,setState]=useState({busy:false,uncertain:false,error:"",details:null});

  useEffect(()=>()=>active.current?.abort(),[]);

  async function save(url,method,values,onSaved){
    if(active.current)return;
    if(!attempt.current)attempt.current=JSON.stringify(values);
    const controller=new AbortController();
    active.current=controller;
    setState({busy:true,uncertain:false,error:"",details:null});
    const response=await requestJson(url,{requiresAuth:true,method,body:attempt.current,signal:controller.signal});
    if(controller.signal.aborted)return;
    active.current=null;
    const uncertain=!response?.success&&supportUncertain(response);
    if(!uncertain)attempt.current=null;
    setState({
      busy:false,
      uncertain,
      error:response?.success?"":response?.message||"L’enregistrement n’a pas abouti.",
      details:response?.error?.details??null,
    });
    if(response?.success)onSaved(response.data);
  }

  function clearError(){
    if(!active.current&&!attempt.current)setState({busy:false,uncertain:false,error:"",details:null});
  }

  return {...state,save,clearError};
}

export function processQuery(criteria,page,take){
  return new URLSearchParams(Object.entries({...criteria,take,skip:(page-1)*take}).filter(([,value])=>value!==""&&value!=null)).toString();
}
