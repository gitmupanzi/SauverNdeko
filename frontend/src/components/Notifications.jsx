import { useCallback, useEffect, useRef, useState } from "react";
import { requestJson } from "../services/api";
import { markNotificationRead, onNotificationsChanged, refreshNotifications } from "../services/communication";
import { useAuth } from "../contexts/AuthContext";
import { formatDate } from "../pages/logistique/logistiqueShared";
import AppIcon from "./AppIcon";
import DrawerDialog from "./DrawerDialog";
import HeaderPopover from "./HeaderPopover";
import SearchSelect from "./SearchSelect";

function useNotifications(page,pageSize,filter,version){
  const {user}=useAuth();
  const scope=String(user?.IdUser||'')+':'+String(user?.IdEntiteFk||'');
  const [state,setState]=useState({scope,items:[],meta:null,loading:true,error:''});
  useEffect(()=>{
    let active=true;
    setState(previous=>previous.scope===scope?{...previous,loading:true,error:''}:{scope,items:[],meta:null,loading:true,error:''});
    requestJson('/api/notifications?'+new URLSearchParams({page,pageSize,read:filter}),{requiresAuth:true}).then(payload=>{
      if(!active)return;
      if(payload?.success&&Array.isArray(payload.data)&&payload.meta)setState({scope,items:payload.data,meta:payload.meta,loading:false,error:''});
      else setState(previous=>({...previous,loading:false,error:'Les notifications ne sont pas disponibles. Réessayez.'}));
    });
    return()=>{active=false;};
  },[page,pageSize,filter,version,user?.IdUser,user?.IdEntiteFk]);
  return state.scope===scope?state:{scope,items:[],meta:null,loading:true,error:''};
}
function NotificationItems({items,canMarkRead,onRead,busy,loading}){
  return <ul className="account-notification-list" aria-busy={loading}>{items.map(item=><li key={item.id} className={(item.read?"":"is-unread")+(item.announcementId?" is-announcement":"")}>
    <span className="account-notification-icon"><AppIcon name="bell" size={18}/></span><div className="account-notification-copy"><strong>{item.title||'Notification'}{!item.read?<span className="account-unread-dot" title="Non lue"/>:null}</strong>{item.body?<p>{item.body}</p>:null}<div className="account-notification-meta"><time>{formatDate(item.createdAt)}</time>{!item.read&&canMarkRead?<button type="button" onClick={()=>onRead(item.id)} disabled={Boolean(busy)||loading}>{busy===item.id?'Enregistrement…':'Marquer comme lue'}</button>:null}{item.read?<span>Lue</span>:null}</div></div>
  </li>)}</ul>;
}
function StateMessage({state,onRetry}){
  if(state.error)return <div className="account-notification-state" role="alert"><AppIcon name="alert" size={24}/><p>{state.error}</p><button type="button" className="ui-action is-secondary" onClick={onRetry}><AppIcon name="refresh"/>Réessayer</button></div>;
  if(state.loading&&!state.meta)return <div className="account-notification-state" role="status"><AppIcon name="clock" size={24}/><p>Chargement des notifications…</p></div>;
  if(!state.loading&&!state.items.length)return <div className="account-notification-state"><span className="account-empty-bell"><AppIcon name="bell" size={26}/></span><strong>Aucune notification</strong><p>Vos nouvelles communications apparaîtront ici.</p></div>;
  return null;
}
function AllNotifications({onClose}){
  const [page,setPage]=useState(1),[filter,setFilter]=useState('all'),[version,setVersion]=useState(0),[busy,setBusy]=useState(null),[error,setError]=useState('');
  const lock=useRef(false),state=useNotifications(page,20,filter,version);
  useEffect(()=>onNotificationsChanged(()=>setVersion(value=>value+1)),[]);
  async function markRead(id){
    if(lock.current)return;lock.current=true;setBusy(id);setError('');
    try{const payload=await markNotificationRead(id);if(payload?.success){setPage(1);refreshNotifications();}else setError(payload?.message||'Cette notification n’a pas pu être mise à jour.');}
    finally{lock.current=false;setBusy(null);}
  }
  return <DrawerDialog title="Notifications" subtitle="Vos communications personnelles" icon="bell" onClose={onClose} busy={Boolean(busy)} defaultWidth={680} storageKey="sauverndeko.notifications.width"><div className="account-notifications-all">
    <div className="account-notification-tools"><SearchSelect label="Afficher les notifications" value={filter} onChange={value=>{setFilter(value);setPage(1);}} options={[{value:'all',label:'Toutes les notifications'},{value:'unread',label:'Non lues'}]} disabled={Boolean(busy)}/><button type="button" className="account-icon-button" aria-label="Actualiser les notifications" disabled={state.loading||Boolean(busy)} onClick={()=>setVersion(value=>value+1)}><AppIcon name="refresh"/></button></div>
    {error?<p role="alert" className="account-notification-error">{error}</p>:null}<StateMessage state={state} onRetry={()=>setVersion(value=>value+1)}/>
    {!state.error&&state.items.length?<NotificationItems items={state.items} canMarkRead={state.meta?.canMarkRead} onRead={markRead} busy={busy} loading={state.loading}/>:null}
    {state.meta&&!state.error?<div className="account-notification-pagination"><span>{state.meta.total} notification{state.meta.total===1?'':'s'}</span><div><button type="button" aria-label="Notifications précédentes" disabled={state.loading||Boolean(busy)||page<=1} onClick={()=>setPage(value=>value-1)}><AppIcon name="chevron-left"/></button><span>Page {page} sur {Math.max(1,Math.ceil(state.meta.total/20))}</span><button type="button" aria-label="Notifications suivantes" disabled={state.loading||Boolean(busy)||!state.meta.hasNext} onClick={()=>setPage(value=>value+1)}><AppIcon name="chevron-right"/></button></div></div>:null}
  </div></DrawerDialog>;
}
export default function Notifications(){
  const [open,setOpen]=useState(false),[all,setAll]=useState(false),[version,setVersion]=useState(0),[busy,setBusy]=useState(null),[error,setError]=useState('');
  const anchor=useRef(null),lock=useRef(false),state=useNotifications(1,6,'all',version);
  const refresh=useCallback(()=>setVersion(value=>value+1),[]);
  useEffect(()=>onNotificationsChanged(refresh),[refresh]);
  const close=useCallback((restore=false)=>{setOpen(false);if(restore)anchor.current?.focus({preventScroll:true});},[]);
  useEffect(()=>{const visible=()=>{if(document.visibilityState==='visible')refresh();};window.addEventListener('focus',visible);const timer=setInterval(visible,60000);return()=>{window.removeEventListener('focus',visible);clearInterval(timer);};},[refresh]);
  async function markRead(id){if(lock.current)return;lock.current=true;setBusy(id);setError('');try{const payload=await markNotificationRead(id);if(payload?.success)refreshNotifications();else setError(payload?.message||'Cette notification n’a pas pu être mise à jour.');}finally{lock.current=false;setBusy(null);}}
  const unread=state.error?null:state.meta?.unreadCount;
  return <><button ref={anchor} type="button" className="account-icon-button account-bell" aria-label={'Notifications'+(typeof unread==='number'?', '+unread+' non lue'+(unread===1?'':'s'):'')} aria-haspopup="dialog" aria-expanded={open} onClick={()=>{setOpen(value=>!value);if(!open)refresh();}}><AppIcon name="bell" size={20}/>{unread>0?<span className="account-notification-count" aria-hidden="true">{unread>99?'99+':unread}</span>:null}</button>
    {open?<HeaderPopover anchor={anchor} label="Notifications" width={400} onClose={close} className="account-notification-panel"><div className="account-panel-heading"><h2>Notifications</h2><button type="button" className="account-icon-button" aria-label="Fermer les notifications" onClick={()=>close(true)}><AppIcon name="close"/></button></div>{error?<p className="account-notification-error" role="alert">{error}</p>:null}<div className="account-notification-scroll"><StateMessage state={state} onRetry={refresh}/>{!state.error&&state.items.length?<NotificationItems items={state.items} canMarkRead={state.meta?.canMarkRead} onRead={markRead} busy={busy} loading={state.loading}/>:null}</div><div className="account-panel-footer"><button type="button" className="ui-action is-secondary" onClick={()=>{close(true);setAll(true);}}>Toutes les notifications<AppIcon name="chevron-right"/></button></div></HeaderPopover>:null}
    {all?<AllNotifications onClose={()=>setAll(false)}/>:null}
  </>;
}
