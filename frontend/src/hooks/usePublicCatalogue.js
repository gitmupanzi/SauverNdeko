import { useEffect, useState } from "react";
import { useAuth } from "../contexts/AuthContext";
import { moduleRights, accessSignature } from "../services/moduleAccess";
import { requestJson } from "../services/api";
import { getCollection, mapArticlePublic, mapDiseasePublic, mapExpertPublic, mapPharmacyPublic } from "../services/mappers";

const EMPTY_STATS={productsCount:"—",pharmaciesCount:"—",expertsCount:"—",diseasesCount:"—",activeStructures:"—",latestAnnouncements:"—",responseLabel:""};
const EMPTY={articles:[],pharmacies:[],experts:[],diseases:[],stats:EMPTY_STATS};
const SOURCES=[
  ["catalogue","stats","stats",null],
  ["produits","articles","articles",mapArticlePublic],
  ["structures","pharmacies","pharmacies",mapPharmacyPublic],
  ["professionnels","experts","experts",mapExpertPublic],
  ["sante","diseases","maladies",mapDiseasePublic],
];
export function usePublicCatalogue() {
  const {user}=useAuth();
  const scope=[user?.IdUser,user?.IdEntiteFk,accessSignature(user)].join(":");
  const [state,setState]=useState({scope:"",health:{loading:true,ok:false},catalogue:EMPTY});
  useEffect(()=>{
    let active=true;
    const allowed=SOURCES.filter(([key])=>moduleRights(user,key).canRead);
    setState({scope,health:{loading:true,ok:false},catalogue:EMPTY});
    async function load() {
      const results=await Promise.allSettled(allowed.map(([, ,endpoint])=>requestJson("/api/public/"+endpoint,{requiresAuth:true})));
      if(!active)return;
      const catalogue={...EMPTY},errors=[];
      results.forEach((result,index)=>{
        const [,field,,mapper]=allowed[index],payload=result.status==="fulfilled"?result.value:null;
        if(!payload?.success){errors.push(payload?.message || "Certaines données sont indisponibles.");return;}
        if(mapper)catalogue[field]=getCollection(payload).map(mapper);
        else catalogue.stats={...EMPTY_STATS,...payload.data};
      });
      setState({scope,catalogue,health:{loading:false,ok:errors.length===0,source:"api",error:errors[0] || ""}});
    }
    void load();
    return()=>{active=false;};
  },[scope]);
  return state.scope===scope ? state : {health:{loading:true,ok:false},catalogue:EMPTY};
}
