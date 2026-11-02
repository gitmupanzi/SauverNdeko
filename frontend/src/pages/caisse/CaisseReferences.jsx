import {Link} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {mayOpen} from "../../services/moduleAccess";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import AppIcon from "../../components/AppIcon";

export default function CaisseReferences({references={},onClose}){
 const {user}=useAuth(),fields=[{key:"devises",label:"Devises des caisses"},{key:"typesCaisses",label:"Types de caisse"},{key:"typesPaiements",label:"Types d’opération"}];
 return <RecordEditorFrame title="Réglages des références" subtitle="Caisse" icon="settings" readOnly onClose={onClose} defaultWidth={850} storageKey="sauverndeko.caisse.references.width"><section className="record-editor-section"><h3><AppIcon name="list"/>Listes de référence</h3><p className="record-editor-note">Les catégories configurées déterminent les choix proposés. Les valeurs déjà enregistrées restent conservées.</p>{fields.map(field=>{const meta=references.referenceMeta?.[field.key],options=references[field.key]||[];return <section className="caisse-reference" key={field.key}><strong>{field.label}</strong><p>{meta?.categoryLabels?.join(", ")||"Catégorie non renseignée"}</p><dl><div><dt>ID catégorie</dt><dd>{meta?.categoryIds?.join(", ")||"—"}</dd></div><div><dt>Catégorie par défaut</dt><dd>{meta?.defaultCategoryId??"—"}</dd></div></dl><details><summary>Voir les {options.length} valeurs</summary><ul>{options.map(item=><li key={item.id}>{item.abbr||item.label}{item.disabled?" · Indisponible":""}</li>)}</ul></details></section>;})}{mayOpen(user,"/referentiels")?<Link className="caisse-reference-link" to="/referentiels?onglet=champs" onClick={onClose}><AppIcon name="tag"/>Ouvrir le référencement des champs<AppIcon name="arrow-up-right"/></Link>:null}</section></RecordEditorFrame>;
}
