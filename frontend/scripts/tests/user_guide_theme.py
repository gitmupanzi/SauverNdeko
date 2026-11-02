"""Contraste des vrais styles Guide utilisateur, sans navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('shared_theme', Path(__file__).with_name('table_theme.py'))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
FILES = [*base.FILES, 'src/components/ActionButton.css', 'src/pages/admin/AdminPortal.css',
         'src/pages/GuideUtilisateur.css']
checks = 0


def check(value, message):
    global checks
    assert value, message
    checks += 1


def fixture(theme):
    return base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(f'''<html data-theme="{theme}"><body>
     <main class="logistics-modern logistics-app admin-portal guide-module guide-main admin-main">
      <header class="guide-heading"><div><p class="guide-eyebrow" data-probe="eyebrow">PRISE EN MAIN</p>
       <h1 data-probe="title">Guide utilisateur</h1><p data-probe="intro">Des étapes simples.</p></div></header>
      <form class="guide-search"><input data-probe="search" value="stock"/><kbd data-probe="badge">Guide</kbd></form>
      <div class="guide-section-heading"><h2 data-probe="section">Vos applications</h2><span data-probe="count">12 guides</span></div>
      <div class="guide-module-grid"><a class="guide-module-card"><h2 data-probe="card-title">Logistique</h2>
       <p data-probe="card-description">Articles et bons.</p><span class="guide-module-foot" data-probe="card-count">12 tutoriels</span></a></div>
      <a class="guide-article-card"><small data-probe="article-module">Logistique</small><span class="guide-article-title"><strong data-probe="article-title">Recevoir du stock</strong></span><p data-probe="article-summary">Préparez le bon.</p></a>
      <nav class="guide-breadcrumb"><a data-probe="breadcrumb">Tous les guides</a><span data-probe="current">Logistique</span></nav>
      <article class="guide-lesson"><p class="guide-lesson-intro" data-probe="lesson-intro">Les étapes du bon.</p>
       <ol class="guide-steps"><li><span class="guide-step-number" data-probe="step-number">1</span><div><h2 data-probe="step-title">Ouvrir les bons</h2><p data-probe="step-text">Choisissez le registre.</p></div></li></ol>
       <section class="guide-example"><div><small data-probe="example-label">EXEMPLE CONCRET</small><h2 data-probe="example-title">Un exemple fictif</h2><p data-probe="example-text">Recevez dix cartons.</p></div></section>
       <section class="guide-notes"><h2 data-probe="notes-title">À retenir</h2><ul><li data-probe="note">Un bon CMD ne touche pas au stock.</li></ul></section>
      </article>
      <aside class="guide-contents"><h2 data-probe="toc-title">Dans ce tutoriel</h2><ol><li><a data-probe="toc-link">Enregistrer</a></li></ol><a data-probe="toc-back">Tous les tutoriels</a></aside>
      <div class="guide-message"><div><h2 data-probe="empty-title">Aucun tutoriel</h2><p data-probe="empty-text">Essayez un autre terme.</p></div></div>
      <p class="guide-scope-note" data-probe="scope-note">Les guides suivent vos applications.</p>
     </main>
    </body></html>'''))


for files in [FILES, [FILES[-1], *FILES[:-1]]]:
    rules = base.matcher(files)
    for theme in ['light', 'dark', 'contrast']:
        tree = fixture(theme)
        computed = {}
        for element in tree.iter_subtree():
            computed[element] = base.style(element, rules, computed.get(element.parent))
        for element in tree.query_all('[data-probe]'):
            values = computed[element]
            current = element
            background = values.get('background-color', '')
            while background in ('', 'transparent', 'none') and current.parent:
                current = current.parent
                background = computed[current].get('background-color', '')
            text = values.get('color', '')
            check(bool(text) and bool(background), f'{theme}: couleurs définies')
            check(base.contrast(base.colour(text), base.colour(background)) >= 4.5,
                  f'{theme}: {element.etree_element.get("data-probe")} illisible ({text} sur {background})')
            if theme in ('dark', 'contrast'):
                check(max(base.colour(background)) < 100, f'{theme}: surface blanche')

result = {'success': True, 'checks': checks,
          'scope': 'Titres, recherche, cartes, étapes, exemple et sommaire en clair/sombre/contraste élevé',
          'limits': ['Fixtures CSS/XML ; aucune disposition ou recette visuelle navigateur']}
(ROOT / '.runtime' / 'guide-theme-tests.json').write_text(json.dumps(result, indent=2), encoding='utf8')
print(json.dumps(result))
