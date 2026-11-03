"""Contrat CSS adaptatif à cinq largeurs ; ne remplace pas un moteur de rendu."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util,json,re
spec=importlib.util.spec_from_file_location('theme',Path(__file__).with_name('table_theme.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
css=(base.FRONT/'src/pages/PublicCatalogue.css').read_text(encoding='utf-8')
checks=0
def check(condition,message):
 global checks
 assert condition,message
 checks+=1
def responsive_rules(width):
 matcher=base.cssselect2.Matcher()
 def add(rules):
  for rule in rules:
   if rule.type=='at-rule' and rule.lower_at_keyword=='media':
    query=base.tinycss2.serialize(rule.prelude)
    bounds=re.findall(r'\((min|max)-width:\s*(\d+)px\)',query)
    if bounds and all(width>=int(value) if kind=='min' else width<=int(value) for kind,value in bounds):
     add(base.tinycss2.parse_rule_list(rule.content,skip_comments=True,skip_whitespace=True))
   elif rule.type=='qualified-rule':
    declarations=[(item.lower_name,base.tinycss2.serialize(item.value).strip(),item.important) for item in base.tinycss2.parse_declaration_list(rule.content,skip_comments=True,skip_whitespace=True) if item.type=='declaration']
    try:selectors=base.cssselect2.compile_selector_list(base.tinycss2.serialize(rule.prelude))
    except base.cssselect2.SelectorError:continue
    for selector in selectors:matcher.add_selector(selector,declarations)
 add(base.tinycss2.parse_stylesheet(css,skip_comments=True,skip_whitespace=True))
 return matcher
def pixels(value,width):
 if value.endswith('px'):return float(value[:-2])
 match=re.fullmatch(r'clamp\((\d+)px,\s*([\d.]+)vw,\s*(\d+)px\)',value)
 assert match,('Mesure non reconnue',value)
 return max(float(match[1]),min(width*float(match[2])/100,float(match[3])))
for width in [320,375,768,1440,1920]:
 root=base.cssselect2.ElementWrapper.from_html_root(ET.fromstring('''<div class="public-catalogue"><header class="catalogue-header"><div class="catalogue-header-inner" data-check="header"><a class="catalogue-brand">SauverNdeko</a><div class="catalogue-header-actions" data-check="actions"><a class="catalogue-button is-outline">Se connecter</a></div></div></header><main><section class="catalogue-container catalogue-hero" data-check="hero"><div><h1>Titre</h1></div><aside class="catalogue-journey" data-check="journey"><ol data-check="steps"><li>Étape</li></ol></aside></section><section class="catalogue-container" data-check="section"><div class="catalogue-service-grid" data-check="services"><article class="catalogue-service-card">Produit</article></div><div class="catalogue-business" data-check="business"><div class="catalogue-business-features" data-check="features">Services</div></div></section><section class="catalogue-container catalogue-start"><a class="catalogue-button" data-check="mobile-cta">Se connecter</a></section></main><footer class="catalogue-footer"><div class="catalogue-container" data-check="footer">SauverNdeko</div></footer></div>'''))
 rules=responsive_rules(width);computed={}
 for node in root.iter_subtree():computed[node]=base.style(node,rules,computed.get(node.parent))
 items={node.etree_element.get('data-check'):computed[node] for node in root.query_all('[data-check]')}
 check(computed[root].get('width')=='100%',(width,'Page pleine largeur'))
 for name in ['header','hero','section','footer']:
  style=items[name]
  check(style.get('width')=='100%',(width,name,'Largeur disponible'))
  check(style.get('max-width')=='none',(width,name,'Aucun plafond de largeur'))
  check(style.get('box-sizing')=='border-box',(width,name,'Marges incluses dans la largeur'))
  gutter=pixels(style['padding-inline'],width)
  check(gutter==16 if width<=600 else 24<=gutter<=40,(width,name,gutter))
  check(width-2*gutter>0,(width,name,'Largeur utile positive'))
 check(items['header'].get('flex-wrap')=='wrap',(width,'En-tête pouvant revenir à la ligne'))
 check(items['actions'].get('flex-wrap')=='wrap',(width,'Actions flexibles'))
 check(items['actions'].get('max-width')=='100%',(width,'Actions dans leur conteneur'))
 check(items['mobile-cta'].get('max-width')=='100%',(width,'Bouton sans débordement imposé'))
 if width<=900:
  for name in ['hero','services','business']:check(items[name]['grid-template-columns']=='minmax(0,1fr)',(width,name,'Colonne unique'))
  check(items['journey'].get('max-width')=='none',(width,'Parcours sans ancien plafond'))
 else:
  check(items['services']['grid-template-columns']=='repeat(3,minmax(0,1fr))',(width,'Trois cartes fluides'))
 if width<=600:
  check(items['features']['grid-template-columns']=='minmax(0,1fr)',(width,'Fonctions empilées'))
  check(items['steps']['grid-template-columns']=='minmax(0,1fr)',(width,'Parcours empilé'))
  check(items['mobile-cta'].get('width')=='100%',(width,'Bouton mobile pleine largeur'))
 if width==1920:check(width-2*pixels(items['hero']['padding-inline'],width)==1840,'1840 px utiles sur un écran de 1920 px')
check('overflow-x:hidden' not in css and 'overflow-x: hidden' not in css,'Aucun masquage de débordement horizontal utilisé comme correctif')
check('width:min(1240px' not in css and 'width:min(1360px' not in css,'Anciens plafonds supprimés')
check('overflow-wrap:anywhere' in css,'Libellés longs pouvant revenir à la ligne')
print(json.dumps({'success':True,'checks':checks,'widths':[320,375,768,1440,1920],'coverage':['Cascade CSS avec media queries','Page, en-tête et pied sans plafond de largeur','Gouttières de 16 px sur mobile, 24 à 40 px sur grand écran','Grilles fluides, empilement mobile et boutons adaptés'],'limits':['Contrat CSS et dimensions calculées, sans recette navigateur ni mesure de défilement réel']},ensure_ascii=False))
