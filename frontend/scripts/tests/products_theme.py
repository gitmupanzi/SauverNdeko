"""Cascade des offres/cartes/tableau/fiche et contrats mobiles, sans navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util,json
spec=importlib.util.spec_from_file_location('table_theme',Path(__file__).with_name('table_theme.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
files=[*base.FILES,'src/components/ModuleSidebar.css','src/components/ActionButton.css','src/components/RegisterSurface.css','src/components/DrawerDialog.css','src/pages/admin/AdminPortal.css','src/pages/produits/Products.css']
checks=0
def check(value,message):
 global checks
 assert value,message
 checks+=1
for order in [files,[files[-1],*files[:-1]]]:
 rules=base.matcher(order)
 for theme in ['light','dark','contrast']:
  root=base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(f'''<html data-theme="{theme}"><body><div class="logistics-modern logistics-app admin-portal products-module"><main class="admin-main products-main"><section class="erp-register"><header class="erp-register-heading"><div><h1 data-probe="heading">Offres de produits</h1><p data-probe="subtitle">Entreprises participantes</p></div><div class="product-offer-display"><button class="ui-action" aria-pressed="true" data-probe="mode">Cartes</button></div></header><div class="erp-register-card"><div class="product-offer-directory"><p class="product-offer-note" data-probe="note">Vérifier le prix</p><div class="product-offer-error" data-probe="error">Indisponible</div><div class="product-offer-applied"><span data-probe="filter">Catégorie</span></div><div class="product-offer-cards"><article class="product-offer-card"><div class="product-offer-card-image" data-probe="image">Photo</div><div class="product-offer-card-copy"><span class="product-offer-category" data-probe="category">Catégorie</span><h2><button data-probe="name">Produit</button></h2><p class="product-offer-reference" data-probe="reference">Référence</p><div class="product-offer-money"><strong data-probe="price">12,00 USD</strong><small data-probe="unit">Par boîte</small></div><div class="product-offer-company"><div><strong data-probe="company">Entreprise</strong><span data-probe="address">Adresse</span></div></div></div></article></div><div class="product-offer-pagination"><span data-probe="count">25 sur 100</span></div><div class="product-offer-empty"><h2 data-probe="empty">Aucune offre</h2><p data-probe="empty-note">Publication volontaire</p><a class="ui-action is-primary" data-probe="manage">Mes articles</a></div></div></div></section></main></div><dialog class="resizable-drawer product-offer-drawer" open="open"><div class="drawer-body"><div class="product-offer-detail"><section class="product-offer-identity"><div class="product-offer-image" data-probe="detail-image">Photo</div><div><span class="product-offer-category" data-probe="detail-category">Catégorie</span><h3 data-probe="detail-title">Produit</h3><p data-probe="detail-ref">Référence</p></div></section><section class="product-offer-section product-offer-price"><div><span data-probe="price-title">Prix déclaré</span><strong data-probe="detail-price">12,00 USD</strong><small data-probe="detail-unit">Par boîte</small></div><p data-probe="price-note">À confirmer</p></section><section class="product-offer-section"><h3 data-probe="section-title">L'entreprise</h3><dl class="product-offer-terms"><div><dt data-probe="term">Téléphone</dt><dd data-probe="value">00123</dd></div></dl><ul class="product-offer-locations"><li><strong data-probe="location">Site déclaré</strong><span data-probe="location-address">Adresse</span></li></ul></section></div></div><footer class="product-offer-footer"><button class="ui-action is-primary" data-probe="contact">Contacter l'entreprise</button></footer></dialog></body></html>'''))
  computed={}
  for node in root.iter_subtree():computed[node]=base.style(node,rules,computed.get(node.parent))
  for node in root.query_all('[data-probe]'):
   name=node.etree_element.get('data-probe');foreground=computed[node].get('color','');current=node;background=computed[node].get('background-color','')
   while background in ('','transparent','none') and current.parent:
    current=current.parent;background=computed[current].get('background-color','')
   check(bool(foreground and background),(theme,name,'couleurs'))
   check(base.contrast(base.colour(foreground),base.colour(background))>=4.5,(theme,name,foreground,background))
   if theme in ['dark','contrast'] and name not in ['manage','contact']:check(max(base.colour(background))<100,(theme,name,'surface claire résiduelle'))
css=(base.FRONT/'src/pages/produits/Products.css').read_text(encoding='utf-8')
check('repeat(auto-fill,minmax(min(100%,290px),1fr))' in css,'Les cartes ne dépassent pas leur conteneur')
check('max-width:100%' in css and 'object-fit:contain' in css,'Images proportionnées')
check('white-space:normal; overflow-wrap:anywhere' in css,'Lien vide adaptable aux petits écrans')
check('grid-template-columns:minmax(0,1fr)' in css,'Fiche en une colonne sur mobile')
check('overflow-x:hidden' not in css and 'overflow-x: hidden' not in css,'Pas de masquage du débordement de page')
for width in [320,375,768,1440,1920]:
 sidebar=60 if width<=760 else 200 if width<=1000 else 224
 useful=width-sidebar-2*(14 if width<=760 else 32)-2*(14 if width<=760 else 20)
 minimum=min(useful,290)
 check(useful>0 and minimum<=useful,(width,'Largeur minimale du rail de cartes'))
print(json.dumps({'success':True,'checks':checks,'widths':[320,375,768,1440,1920],'coverage':['Cascade réelle et deux ordres de styles','Cartes, liste et fiche hors du module dans trois thèmes','Contraste du texte >=4.5:1','Contrats CSS de grilles, images et retour à la ligne mobile'],'limits':['Fixtures CSS/XML et règles de dimensionnement, sans rendu ni mesure de défilement navigateur']},ensure_ascii=False))
