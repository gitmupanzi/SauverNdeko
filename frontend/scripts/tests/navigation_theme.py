"""Cascade des nouveaux repères/navigation, sans navigateur ni mesure de mise en page."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util,json
spec=importlib.util.spec_from_file_location('table_theme',Path(__file__).with_name('table_theme.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
files=[*base.FILES,'src/pages/WorkspaceHome.css','src/components/ModuleSidebar.css','src/components/ModuleHeader.css']
fixture='''<html data-theme="THEME"><body><div class="logistics-modern logistics-app"><aside class="logistics-sidebar-shell erp-module-sidebar"><div class="module-menu-search"><div class="module-menu-search-field"><input data-probe="search"/><button data-probe="clear">X</button></div><span class="module-menu-result" data-probe="count">2 menus</span></div><nav class="logistics-sidebar-nav"><button class="module-nav-group-toggle logistics-nav-heading"><span data-probe="group">Accès</span></button><a class="logistics-sidebar-link is-active"><span class="logistics-sidebar-label" data-probe="active">Utilisateurs</span></a><a class="logistics-sidebar-link"><span class="logistics-sidebar-label" data-probe="entry">Rôles</span></a><p class="module-menu-empty" data-probe="empty">Aucun menu</p></nav></aside><header class="workspace-bar module-header"><button class="module-skip-content" data-probe="skip">Aller au contenu</button><nav class="module-location"><a class="module-apps-link" data-probe="apps">Applications</a><span class="module-header-title" data-probe="title">Administration</span></nav></header></div><span class="module-rail-hint" data-probe="hint">Utilisateurs</span></body></html>'''
checks=0
def check(value,message):
 global checks
 assert value,message
 checks+=1
for order in [files,[files[-1],files[-2],*files[:-2]]]:
 rules=base.matcher(order)
 for theme in ['light','dark','contrast']:
  root=base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(fixture.replace('THEME',theme)))
  computed={}
  for node in root.iter_subtree():computed[node]=base.style(node,rules,computed.get(node.parent))
  for node in root.query_all('[data-probe]'):
   name=node.etree_element.get('data-probe');foreground=computed[node].get('color','');current=node;background=computed[node].get('background-color','')
   while background in ('','transparent','none') and current.parent:
    current=current.parent;background=computed[current].get('background-color','')
   check(bool(foreground and background),(theme,name,'couleurs'))
   check(base.contrast(base.colour(foreground),base.colour(background))>=4.5,(theme,name,foreground,background))
   if name=='search':
    placeholder=base.style(node,rules,computed[node],pseudo='placeholder')['color']
    check(base.contrast(base.colour(placeholder),base.colour(background))>=4.5,(theme,'placeholder',placeholder,background))
sidebar=(base.FRONT/'src/components/ModuleSidebar.css').read_text(encoding='utf8')
header=(base.FRONT/'src/components/ModuleHeader.css').read_text(encoding='utf8')
for width in [320,375,768,1440,1920]:
 # Contrats déclarés : le menu ouvert et son infobulle sont bornés au viewport.
 menu=min(286,width-44);hint=min(240,width-100)
 check(0<menu<width and 0<hint<width,(width,'largeurs bornées'))
check('calc(100vw - 44px)' in sidebar and 'calc(100vw - 100px)' in sidebar,'Bornes réelles des surfaces')
check('.module-menu-search' in sidebar and 'min-width:0' in sidebar,'Recherche adaptable au menu')
check('flex-wrap:wrap' in header and 'text-overflow:ellipsis' in header,'En-tête adaptable sans débordement masqué')
check('overflow-x:hidden' not in header,'Pas de masquage du débordement de page')
check('prefers-reduced-motion:reduce' in sidebar,'Réduction des animations conservée')
print(json.dumps({'success':True,'checks':checks,'themes':['light','dark','contrast'],'widths':[320,375,768,1440,1920],'coverage':['Cascade réelle des styles, deux ordres de chargement','Recherche menu, entrée active, texte vide, en-tête et infobulle','Contraste texte et placeholder >=4.5:1','Bornes CSS déclarées à cinq largeurs'],'limits':['Fixtures CSS/XML et contrats de dimensions, sans rendu ni défilement navigateur']},ensure_ascii=False))
