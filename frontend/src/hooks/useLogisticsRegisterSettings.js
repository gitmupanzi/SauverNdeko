import {useEffect,useRef,useState} from "react";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {moduleRights,tabRights} from "../services/moduleAccess";
import {downloadApiFile} from "../services/api";
import useTablePreferences from "./useTablePreferences";

// Logistics registers share the same persistent table and export contract.
export default function useLogisticsRegisterSettings(kind,{query={},grid={},loading=false,pending=false,error="",count=0,permissionTab=null}={}){
 const preferences=useTablePreferences("logistique."+kind),{user}=useAuth(),scope=useEntityScope();
 const columnsAnchorRef=useRef(null),request=useRef(null),[columnsOpen,setColumnsOpen]=useState(false),[exporting,setExporting]=useState(false),[exportError,setExportError]=useState("");
 const signature=JSON.stringify({query,sortBy:grid.sortBy,sortDir:grid.sortDir,scope:scope.scopeKey,account:user?.IdUser});
 useEffect(()=>{request.current?.abort();request.current=null;setExporting(false);setExportError("");return()=>request.current?.abort();},[signature]);
 useEffect(()=>{setColumnsOpen(false);},[scope.scopeKey,user?.IdUser]);
 const canExport=user?.permissions?.canExportData!==false&&moduleRights(user,"logistique").canExport===true
  && (!permissionTab||tabRights(user,"logistique",permissionTab).canExport===true);
 const exportDisabled=loading||pending||Boolean(error)||!count||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length;
 async function exportFile(format="xlsx"){
  if(!canExport||exportDisabled||exporting)return;
  const controller=new AbortController();request.current?.abort();request.current=controller;setExporting(true);setExportError("");
  const params=new URLSearchParams(Object.entries({...query,sortBy:grid.sortBy,sortDir:grid.sortDir,timeZone:"Africa/Kinshasa",columns:JSON.stringify(preferences.exportKeys)}).filter(([,value])=>value!=null&&value!=="").map(([key,value])=>[key,String(value)]));
  try{await downloadApiFile("/api/logistique/"+kind+"/export."+format+"?"+params,{signal:controller.signal});}
  catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export n’a pas pu être préparé.");}
  finally{if(request.current===controller){request.current=null;setExporting(false);}}
 }
 return {preferences,columnsOpen,columnsAnchorRef,open:()=>setColumnsOpen(true),close:()=>setColumnsOpen(false),
  tableProps:{tablePreferences:preferences,columnsPanelOpen:columnsOpen,columnsAnchorRef,onColumnsPanelClose:()=>setColumnsOpen(false)},
  toolbarProps:{showSettings:false,columnsOpen,columnsButtonRef:columnsAnchorRef,exportFile:canExport?()=>exportFile():undefined,exportCsv:canExport?()=>exportFile("csv"):undefined,exporting,exportDisabled,error:exportError||preferences.error}};
}
