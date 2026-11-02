import {moduleForPath} from "./moduleAccess";

const identifier=/^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const text=value=>typeof value==="string"&&value.trim().length>0;

export function guideModuleValid(module){
  return Boolean(module&&module.key!=="guide"&&identifier.test(module.key)&&text(module.label)&&text(module.description)&&
    text(module.path)&&(moduleForPath(module.path)===module.key||(module.key==="referentiels"&&module.path==="/referentiels"))&&
    Array.isArray(module.articles)&&module.articles.every(article=>identifier.test(article.id)&&text(article.title)&&text(article.summary))&&
    new Set(module.articles.map(article=>article.id)).size===module.articles.length);
}

export function guideContextValid(data){
  return Boolean(data&&text(data.revision)&&Array.isArray(data.modules)&&data.modules.every(guideModuleValid)&&
    new Set(data.modules.map(module=>module.key)).size===data.modules.length);
}

export function guideLinkAllowed(path,modulePath){
  if(typeof path!=="string"||!path.startsWith("/")||path.startsWith("//")||/[\\\u0000-\u0020]/.test(path))return false;
  try{const parsed=new URL(path,"https://guide.invalid");return parsed.origin==="https://guide.invalid"&&parsed.pathname===modulePath&&!parsed.hash;}catch{return false;}
}

export function guideArticleValid(data,module,articleId,revision){
  const article=data?.article;
  return Boolean(data&&data.revision===revision&&data.module?.key===module.key&&data.module?.path===module.path&&
    article?.id===articleId&&text(article.title)&&text(article.summary)&&Array.isArray(article.steps)&&article.steps.length>0&&
    article.steps.every(step=>text(step.title)&&text(step.text))&&text(article.example?.title)&&text(article.example?.text)&&
    Array.isArray(article.notes)&&article.notes.every(text)&&Array.isArray(article.links)&&
    article.links.every(link=>text(link.label)&&guideLinkAllowed(link.path,module.path)));
}

const normalized=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
export function searchGuideArticles(modules,query){
  const terms=normalized(query).trim().split(/\s+/).filter(Boolean);
  return modules.flatMap(module=>module.articles.filter(article=>{
    const haystack=normalized([module.label,article.title,article.summary].join(" "));
    return terms.every(term=>haystack.includes(term));
  }).map(article=>({module,article})));
}

export function guideLocation(moduleKey="",articleId=""){
  const query=new URLSearchParams();if(moduleKey)query.set("module",moduleKey);if(articleId)query.set("article",articleId);
  return "/guide"+(query.size?"?"+query.toString():"");
}
