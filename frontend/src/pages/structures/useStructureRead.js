import {useEffect,useState} from "react";
import {requestJson} from "../../services/api";
import {structureError} from "./structureModel";

/** Une lecture d’annuaire ne réutilise jamais les données du compte précédent. */
export default function useStructureRead({owner,path,parse,revision=0,retain=false,enabled=true,message="Les informations ne sont pas disponibles."}){
 const [state,setState]=useState({owner:"",key:"",data:null,loading:true,error:""}),key=owner+":"+path+":"+revision;
 const current=!enabled?{data:null,loading:false,error:""}:state.key===key?state:{data:retain&&state.owner===owner?state.data:null,loading:true,error:""};
 useEffect(()=>{
  if(!enabled)return;
  let active=true,settled=false;const controller=new AbortController();
  setState(previous=>({owner,key,data:retain&&previous.owner===owner?previous.data:null,loading:true,error:""}));
  const finish=next=>{if(!active||settled)return;settled=true;clearTimeout(timer);setState({owner,key,data:null,loading:false,error:"",...next});};
  const timer=setTimeout(()=>{finish({error:"Le chargement prend trop de temps. Réessayez."});controller.abort();},15000);
  requestJson(path,{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(!active||settled)return;const data=parse(response);
   if(data==null)finish({error:structureError(response,message)});else finish({data});
  }).catch(()=>finish({error:message}));
  return()=>{active=false;clearTimeout(timer);controller.abort();};
 },[key,enabled]);
 return current;
}
