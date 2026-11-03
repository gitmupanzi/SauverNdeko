import {useEffect,useState} from "react";
import {requestJson} from "../../services/api";
import {PRODUCT_OFFERS_ROOT,offerQuery,offerResponse,offerError,offerLastPage} from "./productOffers";

/** Chaque lecture appartient à un compte et à une recherche appliquée. */
export function useProductOffers({owner,criteria,grid,revision=0,onPageCorrection}){
 const [state,setState]=useState({owner:"",key:"",rows:[],total:null,loading:true,error:""});
 const key=owner+":"+offerQuery(criteria,grid)+":"+revision;
 const current=state.key===key?state:{owner,key,rows:state.owner===owner?state.rows:[],total:state.owner===owner?state.total:null,loading:true,error:""};
 useEffect(()=>{
  let active=true,settled=false;const controller=new AbortController();
  setState(previous=>({...previous,owner,key,rows:previous.owner===owner?previous.rows:[],total:previous.owner===owner?previous.total:null,loading:true,error:""}));
  const finish=next=>{if(!active||settled)return;settled=true;clearTimeout(timer);setState({owner,key,rows:[],total:null,loading:false,error:"",...next});};
  const timer=setTimeout(()=>{finish({error:"La recherche prend trop de temps. Réessayez."});controller.abort();},15000);
  requestJson(PRODUCT_OFFERS_ROOT+"/offres?"+offerQuery(criteria,grid),{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(!active||settled)return;const result=offerResponse(response);
   if(!result){finish({error:offerError(response,"Les offres ne sont pas disponibles.")});return;}
   if(grid.skip>0&&grid.skip>=result.total){finish(result);onPageCorrection?.(offerLastPage(result.total,grid.take));return;}
   finish(result);
  }).catch(()=>finish({error:"La recherche n’a pas abouti. Réessayez."}));
  return()=>{active=false;clearTimeout(timer);controller.abort();};
 },[key]);
 return current;
}
export function useProductReferences(owner,revision=0){
 const [state,setState]=useState({key:"",data:{},loading:true,error:""}),key=owner+":"+revision;
 const current=state.key===key?state:{data:{},loading:true,error:""};
 useEffect(()=>{
  let active=true,settled=false;const controller=new AbortController();
  const finish=next=>{if(!active||settled)return;settled=true;clearTimeout(timer);setState({key,data:{},loading:false,error:"",...next});};
  const timer=setTimeout(()=>{finish({error:"Les filtres prennent trop de temps à charger."});controller.abort();},15000);
  requestJson(PRODUCT_OFFERS_ROOT+"/references",{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(response?.success&&response.data&&typeof response.data==="object"&&!Array.isArray(response.data))finish({data:response.data});
   else finish({error:offerError(response,"Les filtres ne sont pas disponibles.")});
  }).catch(()=>finish({error:"Les filtres ne sont pas disponibles."}));
  return()=>{active=false;clearTimeout(timer);controller.abort();};
 },[key]);
 return current;
}
