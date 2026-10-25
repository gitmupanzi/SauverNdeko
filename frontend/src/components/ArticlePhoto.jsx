import {useEffect,useState} from "react";
import {API_BASE_URL} from "../services/api";
import {getAccessToken} from "../services/authStorage";
import AppIcon from "./AppIcon";
export default function ArticlePhoto({record,publicCatalogue=false,className="",alt=""}) {
 const [url,setUrl]=useState("");
 useEffect(()=>{
  let active=true,objectUrl="";
  setUrl("");
  const source=record?.PhotoArticle;
  if(!source)return;
  if(/^https?:\/\//i.test(source)){setUrl(source);return;}
  if(!/^Article\//.test(source)||!record?.ID_Article)return;
  const controller=new AbortController();
  fetch(API_BASE_URL+(publicCatalogue?"/api/public":"/api/logistique")+"/articles/"+record.ID_Article+"/photo",{signal:controller.signal,headers:{Authorization:"Bearer "+getAccessToken()}}).then(async response=>{
    if(!response.ok)return;
    const blob=await response.blob();
    if(!active||!blob.type.startsWith("image/"))return;
    objectUrl=URL.createObjectURL(blob);setUrl(objectUrl);
  }).catch(()=>{});
  return()=>{active=false;controller.abort();if(objectUrl)URL.revokeObjectURL(objectUrl);};
 },[record?.ID_Article,record?.PhotoArticle,publicCatalogue]);
 return url?<img className={className} src={url} alt={alt||record?.NomArticle||"Photo du produit"}/>:<AppIcon name="box" size={30}/>;
}
