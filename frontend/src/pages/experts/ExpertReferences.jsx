import {Link} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {mayOpen} from "../../services/moduleAccess";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import AppIcon from "../../components/AppIcon";

export default function ExpertReferences({references={},onClose}){
 const {user}=useAuth();
 const fields=[{key:"secteurs",label:"Secteurs d’activité"},{key:"types",label:"Professions"},{key:"specialites",label:"Spécialités"},{key:"competences",label:"Compétences"},{key:"prestations",label:"Services proposés"},{key:"typesLiens",label:"Types de rattachement"}];
 return <RecordEditorFrame title="Réglages des références" subtitle="Professionnels" icon="settings" readOnly onClose={onClose} defaultWidth={850} className="expert-detail" storageKey="sauverndeko.experts.references.width"><section className="record-editor-section"><h3><AppIcon name="list"/>Listes de référence</h3><p className="record-editor-note">Les catégories configurées déterminent les choix. Les valeurs déjà enregistrées restent conservées.</p><div className="expert-references">{fields.map(field=>{const meta=references.referenceMeta?.[field.key]||references.configuration?.[field.key]||{},values=references[field.key]||[];return <section key={field.key}><h4>{field.label}</h4><p>{(meta.categoryLabels||meta.CategoryLabels||[]).join(", ")||"Catégorie non renseignée"}</p><dl className="expert-summary"><div><dt>ID catégorie</dt><dd>{(meta.categoryIds||meta.CategoryIds||[]).join(", ")||"—"}</dd></div><div><dt>Catégorie par défaut</dt><dd>{meta.defaultCategoryId??meta.DefaultCategoryId??"—"}</dd></div></dl><details><summary>Voir les {values.length} valeurs</summary><ul>{values.map(item=><li key={item.id}>{item.label||item.abbr||item.name}{item.disabled?" · Indisponible":""}</li>)}</ul></details></section>;})}</div>{mayOpen(user,"/referentiels")?<Link className="expert-references-link" to="/referentiels?onglet=champs" onClick={onClose}><AppIcon name="tag"/>Ouvrir le référencement des champs<AppIcon name="arrow-up-right"/></Link>:null}</section></RecordEditorFrame>;
}
