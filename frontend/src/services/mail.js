import {requestJson} from "./api";
export function fetchMailSettings(){return requestJson("/api/systeme/messagerie",{requiresAuth:true});}
export function saveMailSettings(values){return requestJson("/api/systeme/messagerie",{method:"PUT",requiresAuth:true,body:JSON.stringify(values)});}

export function testMailConnection(){return requestJson("/api/systeme/messagerie/test",{method:"POST",requiresAuth:true,body:JSON.stringify({})});}
