import {useEffect,useRef,useState} from "react";
import {demandFailure} from "./demandModel";

export default function useDemandRead({identity,revision=0,load,parse=value=>value,message="Les informations n’ont pas pu être chargées."}){
 const key=identity+":"+revision,[state,setState]=useState({key:"",data:null,loading:true,error:""}),previous=useRef(null);
 useEffect(()=>{
  let active=true,settled=false;const controller=new AbortController();
  const retained=previous.current?.identity===identity?previous.current.data:null;
  setState({key,data:retained,loading:true,error:""});
  const finish=next=>{if(!active||settled)return;settled=true;clearTimeout(timer);if(next.data)previous.current={identity,data:next.data};setState({key,data:retained,loading:false,error:"",...next});};
  const timer=setTimeout(()=>{finish({error:"Le chargement prend trop de temps. Réessayez."});controller.abort();},15000);
  Promise.resolve().then(()=>load(controller.signal)).then(response=>{if(!active||settled)return;const data=response?.success?parse(response):null;finish(data?{data}:{error:demandFailure(response,message)});}).catch(()=>finish({error:message}));
  return()=>{active=false;clearTimeout(timer);controller.abort();};
 },[key]);
 return state.key===key?state:{data:previous.current?.identity===identity?previous.current.data:null,loading:true,error:""};
}
