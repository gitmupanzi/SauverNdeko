import {useEffect,useId,useRef,useState} from "react";
import {Link} from "react-router-dom";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import DataTableToolbar from "../../components/DataTableToolbar";
import ExportMenu from "../../components/ExportMenu";
import ListState from "../../components/ListState";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import RegisterSurface from "../../components/RegisterSurface";
import RowActionsMenu from "../../components/RowActionsMenu";
import SearchSelect from "../../components/SearchSelect";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import useTablePreferences from "../../hooks/useTablePreferences";
import {downloadApiFile} from "../../services/api";
import {mayOpen,tabRights} from "../../services/moduleAccess";
import {SimpleTable} from "../logistique/logistiqueShared";
import SupportProcessBatch from "./SupportProcessBatch";
import SupportProcessEditor,{processModelPayload} from "./SupportProcessEditor";
import {supportCount} from "./supportForm";
import {PROCESS_URL,processOptions,useProcessMutation,useProcessQuery} from "./supportProcess";

const EMPTY_CRITERIA={q:"",typeId:"",active:"",entityId:""};
const DEFAULT_GRID={take:25,skip:0,sortBy:"name",sortDir:"asc"};
const DEFAULT_COLUMNS=["name","type","version","stageCount","active","actions"];
const STATES=[{value:"",label:"Tous les états"},{value:"true",label:"Actif"},{value:"false",label:"Inactif"}];
const MODEL_REFERENCES=[
  ["types","Types de dossier"],["services","Services"],["roles","Rôles"],
  ["users","Responsables et validateurs"],["reasons","Motifs de blocage, de retour et de refus"],
];

function modelQuery(criteria,grid={}){
  return new URLSearchParams(Object.entries({...criteria,...grid}).filter(([,value])=>value!==""));
}

export default function SupportProcessModels({title="Modèles de suivi",refresh}){
  const {user}=useAuth(),scope=useEntityScope(),prefix=useId();
  const anchor=useRef(null),download=useRef(null);
  const [drawer,setDrawer]=useState(null),[feedback,setFeedback]=useState("");
  const [criteria,setCriteria]=useState(EMPTY_CRITERIA),[draft,setDraft]=useState(EMPTY_CRITERIA);
  const [grid,setGrid]=useState(DEFAULT_GRID),[density,setDensity]=useState("compact");
  const [filtersOpen,setFiltersOpen]=useState(false),[settings,setSettings]=useState(false);
  const [selected,setSelected]=useState([]),[selectionReset,setSelectionReset]=useState(0);
  const [downloading,setDownloading]=useState(false),[downloadError,setDownloadError]=useState("");
  const preferences=useTablePreferences("support.modeles");
  const models=useProcessQuery(PROCESS_URL+"?"+modelQuery(criteria,grid),refresh);
  const data=models.data??models.previousData, rows=data?.items??[], references=data?.references??{};
  const available=data?.available===true;
  const canManage=available&&data.canManage===true&&Boolean(scope.entityId)&&user?.permissions?.canWriteData===true;
  const canExport=available&&data.canExport===true&&tabRights(user,"support","processus").canExport&&user?.permissions?.canExportData!==false;
  const showCompany=scope.globalAdmin&&!scope.entityId;
  const pending=Object.keys(criteria).some(key=>criteria[key]!==draft[key]);
  const allowExport=canExport&&preferences.ready&&preferences.canExport&&preferences.exportKeys.length>0;
  const count=data?.count??rows.length;
  const typeOptions=processOptions(data?.filterTypes??references.types,draft.typeId,"Tous les types");
  const companyOptions=processOptions(scope.entities,draft.entityId,"Toutes les entreprises");

  useEffect(()=>{
    setSelected([]);
    setSelectionReset(value=>value+1);
    setDownloading(false);
    setDownloadError("");
    return ()=>{download.current?.abort();download.current=null;};
  },[criteria,grid,refresh]);

  useEffect(()=>{
    if(models.data?.available&&grid.skip>0&&grid.skip>=models.data.count)
      setGrid(previous=>({...previous,skip:Math.max(0,(Math.ceil(models.data.count/previous.take)-1)*previous.take)}));
  },[models.data,grid.skip]);

  function changeGrid(patch){setGrid(previous=>({...previous,...patch}));}
  function setFilter(key,value){setDraft(previous=>({...previous,[key]:value}));}
  function apply(){
    const next={...draft,q:draft.q.trim()};
    if(!Object.keys(next).some(key=>next[key]!==criteria[key])&&grid.skip===0)models.reload();
    else{
      setCriteria(next);
      changeGrid({skip:0});
    }
    setDraft(next);
  }
  function reset(){
    setCriteria(EMPTY_CRITERIA);
    setDraft(EMPTY_CRITERIA);
    changeGrid({skip:0});
  }
  function removeFilter(key){
    setCriteria(previous=>({...previous,[key]:""}));
    setFilter(key,"");
    changeGrid({skip:0});
  }
  async function downloadFile(path,fallback){
    if(download.current)return;
    const controller=new AbortController();
    download.current=controller;
    setDownloading(true);
    setDownloadError("");
    try{await downloadApiFile(PROCESS_URL+path,{signal:controller.signal});}
    catch(error){if(!controller.signal.aborted)setDownloadError(error.message||fallback);}
    finally{
      if(download.current===controller){
        download.current=null;
        setDownloading(false);
      }
    }
  }
  function exportFile(format,selection){
    if(!allowExport||pending||models.loading||models.error||!count)return;
    const query=modelQuery(criteria,{sortBy:grid.sortBy,sortDir:grid.sortDir,columns:JSON.stringify(preferences.exportKeys)});
    if(selection)query.set("selection",JSON.stringify(selection.map(row=>row.id)));
    return downloadFile("/export."+format+"?"+query,"L’export des modèles n’a pas abouti.");
  }
  function open(kind,model=null){
    setFeedback("");
    setDrawer({kind,model});
  }
  function onSaved(message){
    setDrawer(null);
    setFeedback(message);
    setSelected([]);
    setSelectionReset(value=>value+1);
    models.reload();
  }

  const actions=(
    <>
      <RegisterSettingsButton buttonRef={anchor} expanded={settings} onTableSettings={()=>setSettings(true)}/>
      {canManage?<>
        <ActionButton icon="download" disabled={models.loading||downloading}
          onClick={()=>downloadFile("/modele.xlsx","Le modèle Excel n’a pas pu être téléchargé.")}>Télécharger le modèle Excel</ActionButton>
        <ActionButton icon="upload" disabled={models.loading} onClick={()=>open("batch")}>Importer un fichier Excel</ActionButton>
        <ActionButton icon="plus" variant="primary" disabled={models.loading} onClick={()=>open("new")}>Nouveau modèle</ActionButton>
      </>:null}
    </>
  );
  const filterFields=[
    {key:"typeId",label:"Type de dossier",options:typeOptions},
    {key:"active",label:"État",options:STATES},
    ...(showCompany?[{key:"entityId",label:"Entreprise",options:companyOptions}]:[]),
  ];
  const chips=[
    ...(criteria.q?[{key:"q",label:"Recherche : "+criteria.q}]:[]),
    ...filterFields.filter(({key})=>criteria[key]).map(({key,label,options})=>({key,
      label:label+" : "+(options.find(option=>option.value===criteria[key])?.label??criteria[key])})),
  ];
  const toolbar=<>
    <DataTableToolbar showSettings={false} search={draft.q} setSearch={q=>setFilter("q",q)} onApply={apply} onReset={reset}
      pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen}
      toggleFilters={()=>setFiltersOpen(value=>!value)} filterControlsId={prefix+"-filters"} activeFilters={chips.length}
      density={density} toggleDensity={()=>setDensity(value=>value==="compact"?"airy":"compact")} loading={models.loading}
      exportFile={canExport?()=>exportFile("xlsx"):undefined} exportCsv={canExport?()=>exportFile("csv"):undefined}
      exporting={downloading} exportDisabled={!allowExport||!count||Boolean(models.error)}
      error={downloadError||preferences.error} placeholder="Rechercher un modèle, un type ou une description…"/>
    {filtersOpen?<form id={prefix+"-filters"} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}>
      <div className="erp-register-filter-grid">{filterFields.map(({key,label,options})=><div className="support-field" key={key}>
        <label htmlFor={prefix+key}>{label}</label>
        <SearchSelect id={prefix+key} label={label} value={draft[key]} options={options} onChange={value=>setFilter(key,value)}/>
      </div>)}</div>
      <div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={models.loading}>Appliquer les filtres</ActionButton></div>
    </form>:null}
    {chips.length?<div className="erp-register-chips">{chips.map(chip=><span key={chip.key} className="erp-register-chip">
      {chip.label}<button type="button" aria-label={"Retirer "+chip.label} onClick={()=>removeFilter(chip.key)}><AppIcon name="close" size={13}/></button>
    </span>)}</div>:null}
  </>;
  const columns=[
    {key:"name",label:"Modèle",width:260,render:row=><span>
      <strong className="support-record-code">{row.name}</strong>
      {showCompany?<small className="support-model-company">{companyName(row)}</small>:null}
    </span>},
    {key:"entityName",label:"Entreprise",width:180,render:companyName},
    {key:"type",label:"Type de dossier",width:180,render:row=>row.type||typeOptions.find(option=>option.value===String(row.typeId))?.label||"Type indisponible"},
    {key:"version",label:"Version",width:100},
    {key:"stageCount",label:"Étapes",width:100,render:row=>supportCount(row.stageCount??row.stages?.length)},
    {key:"active",label:"État",width:120,render:row=><span className={"erp-status "+(row.active?"is-success":"is-neutral")}>{row.active?"Actif":"Inactif"}</span>},
    {key:"description",label:"Description",width:260,render:row=>row.description||"—"},
    {key:"actions",label:"Actions",sortable:false,width:108,render:row=><div className="erp-row-actions" onClick={event=>event.stopPropagation()}>
      <button type="button" className="erp-row-consult" aria-label={"Consulter "+row.name} onClick={()=>open("read",row)}><AppIcon name="eye"/></button>
      <RowActionsMenu label={row.name} items={[
        {label:"Consulter",icon:"eye",onSelect:()=>open("read",row)},
        ...(canManage?[
          {label:"Modifier",icon:"edit",onSelect:()=>open("edit",row)},
          {label:"Dupliquer",icon:"document",onSelect:()=>open("copy",row)},
          {label:row.active?"Désactiver":"Réactiver",icon:row.active?"close":"check-circle",onSelect:()=>open("toggle",row)},
        ]:[]),
      ]}/>
    </div>},
  ];
  function companyName(row){return row.entityName||companyOptions.find(option=>option.value===String(row.entityId))?.label||"—";}

  return <RegisterSurface title={title} subtitle="Définissez les étapes de traitement de vos tickets." actions={available?actions:null}>
    <div className="erp-register-table erp-results" data-density={density} aria-busy={models.loading}>
      {showCompany?<p className="record-editor-note">Sélectionnez une entreprise pour gérer ses modèles.</p>:null}
      {feedback?<p className="admin-feedback" role="status"><AppIcon name="check-circle"/>{feedback}
        <button type="button" aria-label="Fermer le message" onClick={()=>setFeedback("")}><AppIcon name="close"/></button>
      </p>:null}
      {models.error?<div className="admin-error" role="alert"><span>{models.error}</span>
        <ActionButton icon="refresh" onClick={models.reload}>Réessayer</ActionButton></div>:null}
      {data?.available===false?<ListState title="Les modèles de suivi sont indisponibles"
        description="La mise à jour du module Support est nécessaire."
        action={<ActionButton icon="refresh" onClick={models.reload}>Réessayer</ActionButton>}/>
        :available?<>{selected.length?<div className="erp-register-selection">
          <strong>{selected.length} {selected.length===1?"modèle sélectionné":"modèles sélectionnés"}</strong>
          {canExport?<ExportMenu selection exportFile={()=>exportFile("xlsx",selected)} exportCsv={()=>exportFile("csv",selected)}
            disabled={!allowExport||pending||downloading||models.loading} exporting={downloading}/>:null}
          <ActionButton icon="close" aria-label="Effacer la sélection" onClick={()=>setSelectionReset(value=>value+1)}/>
        </div>:null}
          <SimpleTable rows={rows} columns={columns} getRowId={row=>row.id} tablePreferences={preferences}
            defaultVisibleColumns={DEFAULT_COLUMNS} defaultPinnedColumns={[]} loading={models.loading} showSearch={false}
            serverMeta={{filteredCount:count,take:grid.take}} serverState={grid} onServerChange={changeGrid}
            enableSelection={canExport} selectionResetKey={selectionReset} onSelectionChange={setSelected}
            tableSettingsActions={Object.keys(references).length ? [{ label: "Références", icon: "list", onSelect: () => open("references") }] : []}
            columnsPanelOpen={settings} columnsAnchorRef={anchor} onColumnsPanelClose={()=>setSettings(false)}
            onRowConsult={row=>open("read",row)} consultColumns={["name"]} toolbar={toolbar}
            emptyMessage={chips.length?"Aucun modèle pour ces critères.":"Aucun modèle de suivi."}
            tableLabel="Modèles de suivi"/>
        </>:models.loading?<ListState title="Chargement des modèles…" role="status" loading/>:models.error?toolbar:null}
    </div>
    {drawer&&available?(
      drawer.kind==="references"?<ModelReferences references={references} onClose={()=>setDrawer(null)}/>
      :drawer.kind==="batch"?<SupportProcessBatch references={references} canManage={canManage} onClose={()=>setDrawer(null)}
        onSaved={result=>onSaved(result.count+" "+(result.count===1?"modèle enregistré.":"modèles enregistrés."))}/>
      :drawer.kind==="toggle"?<ModelActivation model={drawer.model} canManage={canManage} onClose={()=>setDrawer(null)} onSaved={onSaved}/>
      :<SupportProcessEditor key={drawer.kind+":"+drawer.model?.id} model={drawer.kind==="copy"?null:drawer.model}
        draft={drawer.kind==="copy"?duplicateDraft(drawer.model):undefined} readOnly={drawer.kind==="read"}
        references={references} canManage={canManage} onClose={()=>setDrawer(null)} onSaved={()=>onSaved("Le modèle a été enregistré.")}/>
    ):null}
  </RegisterSurface>;
}

function duplicateDraft(model){
  const {name,description,typeId,globalMinutes,reminderMinutes,stages}=model;
  return {name:name.slice(0,112)+" (copie)",description,typeId,globalMinutes,reminderMinutes,stages,active:false};
}

function ModelActivation({model,canManage,onClose,onSaved}){
  const mutation=useProcessMutation();
  const label=model.active?"Désactiver le modèle":"Réactiver le modèle";
  function save(){
    if(!canManage||mutation.busy)return;
    const payload=processModelPayload({...model,active:!model.active},crypto.randomUUID());
    mutation.save(PROCESS_URL+"/"+model.id,"PUT",payload,()=>onSaved(model.active?"Le modèle a été désactivé.":"Le modèle a été réactivé."));
  }
  return <RecordEditorFrame title={label} subtitle={model.name} icon={model.active?"alert":"check-circle"} defaultWidth={560}
    onClose={onClose} onSubmit={save} readOnly={!canManage} busy={mutation.busy} dirty={mutation.uncertain}
    submitLabel={mutation.uncertain?"Vérifier l’enregistrement":label} error={mutation.error}
    discardMessage="Fermer n’annule pas un éventuel enregistrement. Vérifiez l’état du modèle dans le registre.">
    <section className="record-editor-section">
      <p>{model.active?"Ce modèle ne sera plus proposé pour les nouveaux parcours.":"Ce modèle sera de nouveau proposé pour les nouveaux parcours de ce type."}</p>
      <p className="record-editor-note">Les parcours déjà démarrés conservent leur version.</p>
    </section>
  </RecordEditorFrame>;
}

function ModelReferences({references,onClose}){
  const {user}=useAuth(),[search,setSearch]=useState("");
  const normalized=normalize(search);
  return <RecordEditorFrame title="Réglages des références" subtitle="Modèles de suivi" icon="settings"
    readOnly onClose={onClose} defaultWidth={850}>
    <section className="record-editor-section">
      <h3>Listes utilisées dans les modèles</h3>
      <label className="support-field"><span>Rechercher une liste ou une valeur</span>
        <input type="search" value={search} onChange={event=>setSearch(event.target.value)}/>
      </label>
      {MODEL_REFERENCES.map(([key,label])=>{
        const values=processOptions(references[key]).slice(1);
        const matches=normalize(label).includes(normalized)?values:values.filter(option=>normalize(option.label).includes(normalized));
        if(normalized&&!matches.length&&!normalize(label).includes(normalized))return null;
        return <div className="support-reference" key={key}>
          <strong>{label}</strong><details open={normalized?true:undefined}><summary>{supportCount(matches.length)} valeurs</summary>
            <ul>{matches.map(value=><li key={value.value}>{value.label}{value.disabled?" · Indisponible":""}</li>)}</ul>
          </details>
        </div>;
      })}
      {user?.Is_Admin===true&&mayOpen(user,"/referentiels")?<Link className="support-reference-link" to="/referentiels?onglet=champs" onClick={onClose}>
        <AppIcon name="tag"/>Ouvrir le référencement des champs<AppIcon name="arrow-up-right"/>
      </Link>:null}
    </section>
  </RecordEditorFrame>;
}

function normalize(value){return value.trim().normalize("NFD").replace(/\p{M}/gu,"").toLowerCase();}
