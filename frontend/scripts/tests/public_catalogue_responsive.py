"""Contrat CSS adaptatif de l'accueil compact ; sans moteur de rendu navigateur."""
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
for width in [320,375,768,1100,1440,1920]:
 root=base.cssselect2.ElementWrapper.from_html_root(ET.fromstring('''<div class="public-catalogue"><header class="catalogue-header" data-check="sticky-header"><div class="catalogue-header-inner" data-check="header"><a class="catalogue-brand">SauverNdeko</a><div class="catalogue-header-actions" data-check="actions"><a class="catalogue-button is-outline" data-check="mobile-cta">Se connecter</a></div></div></header><main><section class="catalogue-container catalogue-hero" data-check="hero"><div class="catalogue-hero-copy" data-check="copy"><h1 data-check="hero-title">Titre</h1></div><aside class="catalogue-journey" data-check="journey"><ol data-check="steps"><li>Étape</li></ol></aside><section class="catalogue-metrics" data-check="metrics"><div class="catalogue-metrics-heading"><h2>À découvrir</h2></div><div class="catalogue-metric-grid" data-check="metric-grid"><a class="catalogue-metric-card" data-check="metric-card" href="/produits"><div class="catalogue-metric-content" data-check="metric-content"><span class="catalogue-metric-count" data-check="metric-count"><strong class="catalogue-metric-value">123 456 789</strong><span class="catalogue-metric-label">Offres de produits</span></span><span class="catalogue-metric-description">Informations partagées</span></div></a></div></section></section><section class="catalogue-container" data-check="section"><div class="catalogue-service-grid" data-check="services"><article class="catalogue-service-card" data-check="service-card"><div class="catalogue-service-top" data-check="service-top">Produits</div><div class="catalogue-service-media" data-check="service-media"><img data-check="image" src="/illustration-produits.svg" alt="" /></div><h3 data-check="service-title">Consulter les produits référencés</h3><p data-check="service-description">Informations partagées par les entreprises.</p><a class="catalogue-text-link" data-check="service-action">Consulter les produits</a></article></div><div class="catalogue-business" data-check="business"><div class="catalogue-business-features" data-check="features">Services</div></div></section><div class="catalogue-container catalogue-more" data-check="more"><section class="catalogue-research" data-check="research"><div>Notre vision</div></section><section class="catalogue-faq" data-check="faq"><div class="catalogue-faq-list"><details><summary>Repères</summary></details></div></section></div></main><footer class="catalogue-footer"><div class="catalogue-container" data-check="footer">SauverNdeko</div></footer></div>'''))
 rules=responsive_rules(width);computed={}
 for node in root.iter_subtree():computed[node]=base.style(node,rules,computed.get(node.parent))
 items={node.etree_element.get('data-check'):computed[node] for node in root.query_all('[data-check]')}
 check(computed[root].get('width')=='100%',(width,'Page pleine largeur'))
 check(items['sticky-header'].get('position')=='sticky' and items['sticky-header'].get('top')=='0',(width,'Navigation reste fixe pendant le défilement'))
 for name in ['header','hero','section','footer']:
  style=items[name]
  check(style.get('width')=='100%',(width,name,'Largeur disponible'))
  check(style.get('max-width')=='1440px',(width,name,'Largeur de lecture bornée sur grand écran'))
  check(style.get('margin-inline')=='auto',(width,name,'Contenu centré'))
  check(style.get('box-sizing')=='border-box',(width,name,'Marges incluses dans la largeur'))
  gutter=pixels(style['padding-inline'],width)
  check(gutter==16 if width<=600 else 24<=gutter<=32,(width,name,gutter))
  check(min(width,1440)-2*gutter>0,(width,name,'Largeur utile positive'))
 check(items['header'].get('flex-wrap')=='wrap',(width,'En-tête pouvant revenir à la ligne'))
 check(items['actions'].get('flex-wrap')=='wrap',(width,'Actions flexibles'))
 check(items['actions'].get('max-width')=='100%',(width,'Actions dans leur conteneur'))
 check(items['mobile-cta'].get('max-width')=='100%',(width,'Bouton sans débordement imposé'))
 check(items['copy'].get('grid-area')=='copy',(width,'Texte du héros dans sa zone'))
 check(items['journey'].get('grid-area')=='journey',(width,'Parcours dans sa zone'))
 check(items['metrics'].get('grid-area')=='metrics',(width,'Indicateurs dans leur zone'))
 check(items['metrics'].get('min-width')=='0',(width,'Indicateurs pouvant rétrécir'))
 check(items['metric-grid'].get('grid-template-columns')==('minmax(0,1fr)' if width<=600 else 'repeat(3,minmax(0,1fr))'),(width,'Grille de trois indicateurs, empilée sur téléphone'))
 check(items['metric-card'].get('min-width')=='0',(width,'Carte de chiffre sans largeur incompressible'))
 check(items['metric-content'].get('min-width')=='0',(width,'Valeur et libellé peuvent rétrécir'))
 areas=items['hero'].get('grid-template-areas','')
 check(re.findall(r'[a-z]+',areas)==(['copy','metrics','journey'] if width<=900 else ['copy','journey','metrics','metrics']),(width,'Indicateurs immédiatement après le texte sur mobile'))
 if width<=900:
  for name in ['hero','services','business']:check(items[name]['grid-template-columns']=='minmax(0,1fr)',(width,name,'Colonne unique'))
  check(items['journey'].get('max-width')=='none',(width,'Parcours sans ancien plafond'))
  check(items['service-card'].get('display')=='grid',(width,'Carte de service compacte avec illustration latérale'))
  for name,area in [('service-top','top'),('service-media','media'),('service-title','title'),('service-description','description'),('service-action','action')]:
   check(items[name].get('grid-area')==area,(width,name,'Élément dans sa zone sans chevauchement intentionnel'))
 else:
  check(items['services']['grid-template-columns']=='repeat(3,minmax(0,1fr))',(width,'Trois cartes fluides'))
 if width<=600:
  check(items['features']['grid-template-columns']=='minmax(0,1fr)',(width,'Fonctions empilées'))
  check(items['steps']['grid-template-columns']=='minmax(0,1fr)',(width,'Parcours empilé'))
  check(pixels(items['mobile-cta'].get('min-height','0px'),width)>=44,(width,'Bouton mobile conserve une cible utilisable'))
 check(items['more'].get('grid-template-columns')==('minmax(0,1fr)' if width<=1100 else 'repeat(2,minmax(0,1fr))'),(width,'Vision et repères côte à côte sur grand écran, empilés autrement'))
 check(items['more'].get('min-width')=='0',(width,'Informations complémentaires pouvant rétrécir'))
 for name in ['research','faq']:
  check(items[name].get('min-width')=='0',(width,name,'Pas de largeur incompressible dans le bloc partagé'))
 check(pixels(items['image']['height'],width)<=136,(width,'Illustration conservée dans un gabarit compact'))
 check(items['image'].get('object-fit')=='contain',(width,'Illustration entière, sans découpe'))
 check(items['image'].get('display')=='block',(width,'Illustrations restent affichées'))
 check(pixels(items['metric-card']['min-height'],width)<=112,(width,'Indicateur compact sans modifier le nombre'))
 check(pixels(items['hero-title']['font-size'],width)>=32,(width,'Titre principal reste lisible sans zoom artificiel'))
 if width==1920:check(min(width,1440)-2*pixels(items['hero']['padding-inline'],width)==1376,'1376 px utiles centrés sur un écran de 1920 px')
check('overflow-x:hidden' not in css and 'overflow-x: hidden' not in css,'Aucun masquage de débordement horizontal utilisé comme correctif')
check('width:min(1240px' not in css and 'width:min(1360px' not in css,'Anciens plafonds supprimés')
check('overflow-wrap:anywhere' in css,'Libellés longs pouvant revenir à la ligne')
check(not re.search(r'(?<![-a-z])zoom\s*:|transform\s*:\s*scale\s*\(',css),'Aucune réduction par zoom ou mise à l’échelle artificielle')
print(json.dumps({'success':True,'checks':checks,'widths':[320,375,768,1100,1440,1920],'coverage':['Cascade CSS avec media queries','Contenu centré et borné à 1440 px, mobile sur toute la largeur disponible','Gouttières de 16 px sur mobile, 24 à 32 px sur grand écran','Grilles fluides, empilement mobile et boutons adaptés','Trois indicateurs fluides, placés avant le parcours sur mobile','Vision et repères côte à côte, illustrations conservées dans un gabarit compact sans zoom'],'limits':['Contrat CSS et dimensions calculées, sans recette navigateur ni mesure de défilement réel']},ensure_ascii=False))
