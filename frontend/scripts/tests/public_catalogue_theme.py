"""Contraste de l'accueil et de sa synthèse publique, sans recette navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util,json
spec=importlib.util.spec_from_file_location('table_theme',Path(__file__).with_name('table_theme.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
files=['node_modules/bootstrap/dist/css/bootstrap.min.css','src/styles.css','src/theme.css','src/components/ThemePicker.css','src/pages/PublicCatalogue.css']
checks=0
for order in [files,[files[-1],*files[:-1]]]:
 rules=base.matcher(order)
 for theme in ['light','dark','contrast']:
  root=base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(f'''<html data-theme="{theme}"><body><div class="public-catalogue">
  <header class="catalogue-header"><div class="catalogue-header-inner"><a class="catalogue-brand" data-probe="brand">SauverNdeko</a><nav class="catalogue-nav"><a data-probe="nav">La plateforme</a></nav><div class="catalogue-header-actions"><a class="catalogue-button is-outline" data-probe="signin">Se connecter</a></div></div></header>
  <main><section class="catalogue-hero"><div class="catalogue-hero-copy"><span class="catalogue-eyebrow" data-probe="eyebrow">Plateforme</span><h1 data-probe="title">Des produits.<span data-probe="accent">Des liens</span></h1><p data-probe="lede">Information</p><div class="catalogue-hero-actions"><a class="catalogue-button is-primary" data-probe="cta">Produits</a><a class="catalogue-text-link" data-probe="link">Professionnels</a></div><p class="catalogue-access-note" data-probe="access">Connexion</p></div>
  <aside class="catalogue-journey"><div class="catalogue-journey-heading"><div><span class="catalogue-overline" data-probe="overline">Votre parcours</span><h2 data-probe="journey-title">Du besoin au contact</h2></div></div><ol><li><div><h3 data-probe="step">Consulter</h3><p data-probe="step-note">Une fiche</p></div></li></ol><p class="catalogue-journey-note" data-probe="journey-note">Santé</p></aside>
  <section class="catalogue-metrics"><div class="catalogue-metrics-heading"><h2 data-probe="metrics-title">À découvrir</h2><p data-probe="metrics-note">Les informations partagées sur SauverNdeko.</p></div><div class="catalogue-metric-grid">
  <a class="catalogue-metric-card" href="/produits" data-probe="metric-card"><span class="catalogue-metric-icon" data-probe="metric-icon">□</span><span class="catalogue-metric-count"><strong class="catalogue-metric-value" data-probe="metric-value">12 345</strong><span class="catalogue-metric-label" data-probe="metric-label">Offres de produits</span></span><span class="catalogue-metric-description" data-probe="metric-description">Produits partagés</span></a>
  <a class="catalogue-metric-card qa-hover" href="/experts" data-probe="metric-hover"><span class="catalogue-metric-icon" data-probe="metric-second-icon">□</span><span class="catalogue-metric-count"><strong class="catalogue-metric-value" data-probe="metric-hover-value">0</strong><span class="catalogue-metric-label" data-probe="metric-hover-label">Profils publiés</span></span><span class="catalogue-metric-description" data-probe="metric-hover-description">Trouver un professionnel</span></a>
  </div><div class="catalogue-metrics-feedback"><div class="catalogue-metrics-error" data-probe="metrics-error">Les chiffres sont momentanément indisponibles. <button class="catalogue-button is-outline" data-probe="metrics-retry">Réessayer</button></div></div></section></section>
  <section class="catalogue-services"><div class="catalogue-section-heading"><div><h2 data-probe="section">La plateforme</h2></div><p data-probe="section-note">Point de départ</p></div><div class="catalogue-service-grid"><article class="catalogue-service-card"><div class="catalogue-service-top"><span class="catalogue-service-label" data-probe="service-label">Produits</span><span class="catalogue-status" data-probe="status">En amélioration</span></div><h3 data-probe="service-title">Produits référencés</h3><p data-probe="service-text">Description</p><a class="catalogue-text-link" data-probe="service-link">Consulter</a></article></div><p class="catalogue-section-note" data-probe="footnote">Organisations participantes</p></section>
  <section><div class="catalogue-business"><div class="catalogue-business-copy"><h2 data-probe="business-title">Entreprise</h2><p data-probe="business-copy">Un espace dédié</p></div><div class="catalogue-business-features"><div><h3 data-probe="business-feature">Stock</h3><p data-probe="business-feature-copy">Traçabilité</p></div></div></div></section>
  <div class="catalogue-container catalogue-more"><section class="catalogue-research"><div><h2 data-probe="research-title">Mesurer</h2><p data-probe="research-copy">À évaluer</p></div></section>
  <section class="catalogue-faq"><div class="catalogue-faq-list"><details open="open"><summary data-probe="faq-title">Accès</summary><p data-probe="faq-copy">Connexion</p></details></div></section>
  </div></main>
  <footer class="catalogue-footer"><div class="catalogue-container"><p data-probe="footer">Plateforme en développement</p><a data-probe="back">Retour en haut</a></div></footer>
  </div></body></html>'''))
  computed={}
  for element in root.iter_subtree():computed[element]=base.style(element,rules,computed.get(element.parent))
  for element in root.query_all('[data-probe]'):
   foreground=computed[element].get('color','');current=element;background=computed[current].get('background-color','')
   while background in ('','transparent','none') and current.parent:
    current=current.parent;background=computed[current].get('background-color','')
   probe=element.etree_element.get('data-probe')
   assert foreground and background,(theme,probe,'Couleurs manquantes');checks+=1
   assert base.contrast(base.colour(foreground),base.colour(background))>=4.5,(theme,probe,foreground,background);checks+=1
   if theme in ('dark','contrast') and probe!='cta':assert max(base.colour(background))<100,(theme,probe,'Surface claire résiduelle');checks+=1
print(json.dumps({'success':True,'checks':checks,'coverage':['Cascade réelle de l’accueil dans deux ordres CSS','Synthèse : valeurs, libellés, descriptions, survol, erreur et reprise','Clair, sombre, contraste élevé','Texte >=4.5:1 et surfaces de thème'],'limits':['Fixtures CSS/XML, pas de mise en page navigateur']},ensure_ascii=False))
