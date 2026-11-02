"""Couleurs des regroupements accueil/catalogue/licence, sans rendu navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('table_theme', Path(__file__).with_name('table_theme.py'))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
FILES = [*base.FILES, 'src/components/ActionButton.css', 'src/pages/WorkspaceHome.css', 'src/pages/Applications.css']
checks = 0


def check(value, message):
    global checks
    assert value, message
    checks += 1


def fixture(theme):
    return base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(f'''<html data-theme="{theme}"><body>
      <main class="workspace-home"><div class="workspace-main"><div class="workspace-title-row"><div><h1 data-probe="home-title">Vos applications</h1><p data-probe="home-intro">Entreprise A</p></div></div>
        <form class="workspace-search"><input data-probe="search" /></form>
        <section class="workspace-application-group"><header><h2 data-probe="modules-title">Modules métier</h2><p data-probe="module-count">2 modules disponibles</p></header>
          <nav class="workspace-modules"><a class="workspace-app"><strong data-probe="module">Caisse</strong><span class="workspace-app-description" data-probe="description">Encaissements et clôtures.</span></a></nav></section>
        <section class="workspace-application-group is-features"><header><h2 data-probe="features-title">Fonctionnalités associées</h2><p data-probe="feature-count">1 sur 2 fonctionnalités</p></header>
          <nav class="workspace-modules"><a class="workspace-app"><strong data-probe="feature">Produits</strong><span class="workspace-app-description" data-probe="feature-description">Consulter les produits.</span><small class="workspace-app-parent" data-probe="parent">Associé à Catalogue</small></a></nav></section>
      </div></main>
      <main class="applications-page"><div class="applications-main"><section class="application-catalogue-group"><header><h2 data-probe="catalogue-title">Modules métier</h2><span data-probe="catalogue-count">2 modules · 1 accessible</span></header>
        <p class="application-group-note" data-probe="catalogue-note">Sans souscription séparée.</p><article class="application-card workspace-app"><h2 data-probe="card-title">Caisse</h2><p data-probe="card-description">Soldes et mouvements.</p><span class="application-badge is-enabled" data-probe="badge">Activé</span></article></section>
        <section class="application-settings"><div class="application-settings-head"><div><h2 data-probe="licence-title">Offre de la licence</h2><p data-probe="licence-note">Les règles d’accès restent conservées.</p></div></div>
          <div class="application-licence-groups"><section><header><h3 data-probe="licence-group">Fonctionnalités associées</h3><span data-probe="licence-count">2 fonctionnalités</span></header>
            <p class="application-group-note" data-probe="licence-explanation">Configuration des accès.</p><div class="application-module-list"><label class="application-module-row"><span><strong data-probe="access-label">Produits</strong><small data-probe="inclusion">Inclus avec Catalogue</small></span></label></div></section></div>
          <div class="application-role-table"><table class="application-rights-table"><tbody><tr class="application-rights-group"><th data-probe="rights-group">Modules métier</th></tr><tr><th data-probe="rights-row">Caisse</th></tr></tbody></table></div>
        </section></div></main>
    </body></html>'''))


for order in [FILES, [*FILES[-2:], *FILES[:-2]]]:
    rules = base.matcher(order)
    for theme in ['light', 'dark', 'contrast']:
        base.evaluate(rules, theme)
        root, computed = fixture(theme), {}
        for element in root.iter_subtree():
            computed[element] = base.style(element, rules, computed.get(element.parent))
        for element in root.query_all('[data-probe]'):
            text, current = computed[element].get('color', ''), element
            background = computed[current].get('background-color', '')
            while background in ('', 'transparent', 'none') and current.parent:
                current = current.parent
                background = computed[current].get('background-color', '')
            probe = element.etree_element.get('data-probe')
            check(bool(text) and bool(background), f'{theme}: couleurs définies {probe}')
            check(base.contrast(base.colour(text), base.colour(background)) >= 4.5,
                  f'{theme}: contraste {probe}, {text} sur {background}')
            if theme in ('dark', 'contrast'):
                check(max(base.colour(background)) < 100, f'{theme}: surface blanche {probe}')

report = {'success': True, 'checks': checks + base.checks,
          'coverage': ['Accueil, catalogue et configuration de licence',
                       'Modules métier/fonctionnalités, compteurs, parents, champs et droits',
                       'Clair, sombre, contraste élevé et deux ordres de cascade',
                       'Contraste des textes 4.5 et absence de surfaces blanches résiduelles'],
          'limits': ['Fixtures CSS/XML ; dimensions et disposition responsive non évaluées dans un navigateur']}
(ROOT / '.runtime' / 'application-catalogue-theme-tests.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
