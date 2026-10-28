import EntityProfileEditor from "./EntityProfileEditor";
export default function EntityDocumentIdentity({onClose,onSaved}){
  return <EntityProfileEditor context="active" onClose={onClose} onSaved={onSaved}/>;
}
