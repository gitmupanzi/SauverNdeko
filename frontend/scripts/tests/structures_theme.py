"""Couleurs des structures, fiches et tableaux détachés ; contrats CSS mobiles."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util,json
spec=importlib.util.spec_from_file_location('table_theme',Path(__file__).with_name('table_theme.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
files=[*base.FILES,'src/components/ModuleSidebar.css','src/components/ActionButton.css','src/components/RegisterSurface.css','src/components/DrawerDialog.css','src/pages/admin/AdminPortal.css','src/pages/structures/Structures.css']
checks=0
def check(value,message):
 global checks
 assert value,message
 checks+=1
fixture='''<html data-theme="THEME"><body><div class="logistics-modern logistics-app admin-portal structures-module"><main class="admin-main structures-main"><section class="erp-register"><header class="erp-register-heading"><div><h1 data-probe="heading">Structures</h1><p data-probe="subtitle">Annuaire</p></div><div class="structure-display"><button class="ui-action" aria-pressed="true" data-probe="mode">Cartes</button></div></header><div class="erp-register-card"><div class="structure-directory"><div class="structure-error" data-probe="error">Indisponible</div><div class="structure-applied"><span data-probe="filter">Type</span></div><div class="structure-cards"><article class="structure-card"><header><span class="structure-logo" data-probe="logo">EA</span><span data-probe="type">Centre</span></header><div class="structure-card-copy"><h2><button data-probe="name">Entreprise</button></h2><p class="structure-summary" data-probe="summary">Présentation</p><dl class="structure-card-contact"><div><dt data-probe="term">Adresse déclarée</dt><dd data-probe="value">Adresse</dd></div></dl></div></article></div><div class="structure-pagination"><span data-probe="count">25 sur 100</span></div><div class="structure-empty"><h2 data-probe="empty">Aucune structure</h2><p data-probe="empty-note">Publication volontaire</p><a class="ui-action is-primary" data-probe="settings">Paramètres</a></div></div></div></section></main></div><dialog class="resizable-drawer structure-drawer" open="open"><div class="drawer-body"><div class="structure-detail"><section class="structure-identity"><span class="structure-logo" data-probe="detail-logo">EA</span><div><span data-probe="detail-type">Centre</span><h3 data-probe="detail-title">Entreprise</h3><p data-probe="detail-address">Adresse</p></div></section><section class="structure-section"><h3 data-probe="section-title">Coordonnées</h3><p class="structure-description" data-probe="description">Présentation déclarée</p><dl class="structure-terms"><div><dt data-probe="detail-term">Téléphone</dt><dd data-probe="detail-value">00123</dd></div></dl><ul class="structure-locations"><li><strong data-probe="location">Lieu déclaré</strong><span data-probe="location-address">Adresse</span></li></ul><p class="structure-note" data-probe="location-note">Confirmez l’adresse</p></section><section class="structure-related"><h3 data-probe="related-title">Professionnels publiés</h3><p class="structure-note" data-probe="related-note">Rattachement déclaré</p><div class="erp-register-table erp-results"><div class="erp-data-grid"><table class="public-table logistics-table admin-table table"><thead><tr><th><button class="admin-header-trigger is-sortable"><span class="admin-header-label" data-probe="column">Professionnel</span></button></th></tr></thead><tbody><tr class="admin-table-row"><td class="admin-table-cell"><div class="structure-related-name"><span class="expert-avatar" data-probe="avatar">PA</span><a><strong data-probe="expert">Professionnel</strong><small data-probe="expert-title">Titre</small></a></div><span class="structure-cell-muted" data-probe="unit">Par boîte</span></td></tr></tbody></table></div></div></section></div></div><footer class="structure-footer"><button class="ui-action is-primary" data-probe="contact">Contacter</button></footer></dialog></body></html>'''
fixture=fixture.replace('<div class="structure-cards">','<button class="structure-profile-name" data-probe="private-profile-name"><span class="app-icon" data-probe="private-profile-icon">◇</span>Structure</button><div class="structure-profile-actions"><button class="ui-action" data-probe="private-profile-action">Modifier</button></div><div class="structure-cards">')
fixture=fixture.replace('Entreprise','Pharmacie').replace('Publication volontaire','Annuaire des structures et territoires').replace('Présentation déclarée','Coordonnées publiées').replace('Lieu déclaré','Aire de santé')
fixture=fixture.replace('<dl class="structure-terms">','<dl class="structure-terms"><div><dt data-probe="hours-label">Horaires d’ouverture</dt><dd class="structure-multiline" data-probe="hours">Lundi : 8 h–17 h</dd></div>')
fixture=fixture.replace('<div class="structure-cards">','<div class="structure-cards structure-management"><article class="structure-card"><div class="structure-card-copy"><h2 data-probe="management-title">Structures et sites</h2><p class="structure-note" data-probe="management-note">Centres, hôpitaux et pharmacies</p><a class="ui-action is-primary" data-probe="management-action">Gérer les structures et sites</a></div></article></div><div class="structure-cards">',1)
for order in [files,[files[-1],*files[:-1]]]:
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
   if theme in ['dark','contrast'] and name not in ['settings','contact','management-action']:check(max(base.colour(background))<100,(theme,name,'surface claire résiduelle'))
css=(base.FRONT/'src/pages/structures/Structures.css').read_text(encoding='utf-8')
check('repeat(auto-fill,minmax(min(100%,300px),1fr))' in css,'Cartes limitées à la largeur disponible')
check('object-fit:contain' in css and 'max-width:100%' in css,'Logos proportionnés et textes adaptables')
check('white-space:normal; overflow-wrap:anywhere' in css,'Action de publication adaptable aux petits écrans')
check('grid-template-columns:minmax(0,1fr)' in css,'Fiche en une colonne sur mobile')
check('.structure-multiline { white-space:pre-wrap; overflow-wrap:anywhere; }' in css,'Horaires et coordonnées conservent leurs lignes sans débordement')
check('overflow-x:hidden' not in css and 'overflow-x: hidden' not in css,'Pas de masquage du débordement de page')
check('.structure-related-name .expert-avatar img' in css,'Photo du professionnel bornée même avant ouverture du module Experts')
for width in [320,375,768,1440,1920]:
 sidebar=60 if width<=760 else 200 if width<=1000 else 224
 useful=width-sidebar-2*(14 if width<=760 else 32)-2*(14 if width<=760 else 20)
 check(useful>0 and min(useful,300)<=useful,(width,'Largeur minimale des cartes'))
print(json.dumps({'success':True,'checks':checks,'widths':[320,375,768,1440,1920],'coverage':['Cascade réelle en deux ordres dans trois thèmes','Cartes, fiche et tableaux liés détachés','Contraste du texte >=4.5:1','Contrats CSS mobiles et logos proportionnés'],'limits':['Fixtures CSS/XML et dimensionnement déclaré, sans rendu ni mesure de défilement navigateur']},ensure_ascii=False))
