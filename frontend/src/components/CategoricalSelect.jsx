import {Children,isValidElement,useId,useEffect,useLayoutEffect,useRef,useState} from "react";
import SearchSelect from "./SearchSelect";
import "./CategoricalSelect.css";

function optionText(children){return Children.toArray(children).map(child=>typeof child==="string"||typeof child==="number"?String(child):isValidElement(child)?optionText(child.props.children):"").join("");}
function optionList(children,group="",disabled=false){return Children.toArray(children).flatMap(child=>{
  if(!isValidElement(child))return [];
  if(child.type==="optgroup")return optionList(child.props.children,child.props.label,disabled||child.props.disabled);
  if(child.type!=="option")return optionList(child.props.children,group,disabled);
  if(child.props.hidden)return [];
  const text=optionText(child.props.children),value=String(child.props.value??text);
  return [{value,label:group?group+" · "+text:text,disabled:Boolean(disabled||child.props.disabled)}];
});}

// Adaptateur des formulaires contrôlés : même sélecteur visuel, validation HTML conservée.
export default function CategoricalSelect({id,name,value="",onChange,children,disabled=false,required=false,className="",style,label,placeholder="Choisir…",loading=false,...attributes}){
  const generated=useId(),controlId=id||generated,native=useRef(null);
  const [invalid,setInvalid]=useState(false),[inheritedDisabled,setInheritedDisabled]=useState(false),[caption,setCaption]=useState("");
  const options=optionList(children),current=String(value??"");
  const suppliedLabel=attributes["aria-label"]||label;
  useLayoutEffect(()=>{
    const element=native.current;
    const container=element.closest("label")||Array.from(document.querySelectorAll("label[for]")).find(item=>item.htmlFor===controlId);
    if(container){const text=Array.from(container.childNodes).filter(node=>!node.contains?.(element)&&!["SMALL","P"].includes(node.nodeName)).map(node=>node.textContent||"").join(" ").trim();setCaption(previous=>previous===text?previous:text);}
    const update=()=>setInheritedDisabled(element.matches(":disabled"));update();
    const observer=new MutationObserver(update);
    for(let parent=element.parentElement;parent;parent=parent.parentElement)if(parent.tagName==="FIELDSET")observer.observe(parent,{attributes:true,attributeFilter:["disabled"]});
    return()=>observer.disconnect();
  },[controlId,disabled]);
  useEffect(()=>{if(invalid&&native.current?.validity.valid)setInvalid(false);},[current,required,disabled,children,invalid]);
  function change(next){
    if(disabled||loading||native.current?.matches(":disabled"))return;
    setInvalid(false);
    const target={name,value:String(next)};
    onChange?.({target,currentTarget:target});
  }
  function reportInvalid(event){
    attributes.onInvalid?.(event);
    event.preventDefault();setInvalid(true);
    const element=native.current,first=element.form?.querySelector("input:invalid,select:invalid,textarea:invalid");
    if(!first||first===element)requestAnimationFrame(()=>document.getElementById(controlId)?.focus());
  }
  const errorId=controlId+"-validation",describedBy=[attributes["aria-describedby"],invalid?errorId:""].filter(Boolean).join(" ")||undefined;
  return <div className={"categorical-select "+className} style={style}>
    <SearchSelect id={controlId} label={suppliedLabel||caption||name||"Choisir une valeur"} value={current} options={options} onChange={change} disabled={disabled||inheritedDisabled} loading={loading} invalid={invalid||attributes["aria-invalid"]===true||attributes["aria-invalid"]==="true"} describedBy={describedBy} placeholder={placeholder}/>
    <select ref={native} className="categorical-select-native" name={name} value={current} disabled={disabled||loading} required={required} tabIndex={-1} aria-hidden="true" onChange={onChange} onInvalid={reportInvalid}>
      {!options.some(option=>option.value==="")?<option value="" hidden/>:null}{children}
    </select>
    {invalid?<small className="categorical-select-error" id={errorId} role="alert">Choisissez une valeur.</small>:null}
  </div>;
}
