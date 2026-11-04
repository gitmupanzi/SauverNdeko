// Le contexte ne remplace jamais l'identité ni les contrôles de périmètre serveur.
let current={userId:"",entityId:"",globalAdmin:false,generation:0};
export function configureEntityScope({userId="",entityId="",globalAdmin=false}={}) {
  const next={userId:String(userId||""),entityId:String(entityId||""),globalAdmin:globalAdmin===true};
  if(next.userId!==current.userId||next.entityId!==current.entityId||next.globalAdmin!==current.globalAdmin)current={...next,generation:current.generation+1};
}
export function captureEntityScope(path) {
  const sharedSanitary=/^\/api\/structures\/annuaire-sanitaire(?:[/?]|$)/.test(String(path));
  const scoped=!sharedSanitary&&/^\/api\/(?:logistique|caisse|professionnels|structures|support|parametres|guide|tableaux|referentiel|views\/referentiel|systeme\/(?:administration|utilisateurs|entites|entite-localisations|licences|fk-correspondances|admin-ui-settings|personnel))(?:[/?]|$)/.test(String(path));
  return {scoped,generation:current.generation,headers:scoped&&current.globalAdmin&&/^[1-9]\d*$/.test(current.entityId)?{"X-Entite-ID":current.entityId}:{}};
}
export function entityScopeIsCurrent(snapshot){return !snapshot?.scoped||snapshot.generation===current.generation;}
