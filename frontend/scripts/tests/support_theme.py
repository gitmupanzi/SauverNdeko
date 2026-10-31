"""Cascade Support réelle sur fixtures XML : ne remplace pas un rendu navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('shared_table_theme', Path(__file__).with_name('table_theme.py'))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
FILES = [*base.FILES, 'src/components/ActionButton.css', 'src/components/RegisterSurface.css',
         'src/components/RecordEditor.css', 'src/components/DrawerDialog.css',
         'src/components/ConsultationTabs.css', 'src/pages/admin/AdminPortal.css',
         'src/pages/support/Support.css']
checks = 0


def check(value, message):
    global checks
    assert value, message
    checks += 1


def fixture(theme):
    source = f'''<html data-theme="{theme}"><body>
     <main class="logistics-modern logistics-app admin-portal support-module">
      <section class="admin-dashboard-panel"><header><h2 data-probe="heading">Répartition</h2></header>
       <div class="support-chart"><button><span data-probe="chart">En cours</span><strong data-probe="count">45</strong></button></div></section>
      <section class="support-kanban-column"><header><h2 data-probe="column">Nouveau</h2></header>
       <button class="support-kanban-card"><span data-probe="code">SUP-17</span><strong data-probe="subject">Demande d’assistance</strong>
        <small data-probe="requester">Demandeur externe</small></button></section>
     </main>
     <dialog class="resizable-drawer support-editor" open="open"><div class="record-editor-body">
      <section class="record-editor-section"><h3 data-probe="section">Demande</h3>
       <label class="support-field"><span data-probe="label">Objet</span><input value="Demande" data-probe="input" /></label>
       <label class="support-field"><span>Description</span><textarea data-probe="description">Description</textarea></label>
       <p class="record-editor-note" data-probe="hint">Heure de Kinshasa.</p></section>
      <section class="record-editor-section" hidden="hidden" data-hidden="panel"><h3>Affectation</h3></section>
     </div></dialog>
     <dialog class="resizable-drawer support-detail" open="open"><div class="record-editor-body">
      <section class="record-editor-section"><p class="support-content" data-probe="content">Solution appliquée</p>
       <dl class="support-info-grid"><div><dt data-probe="term">Responsable</dt><dd data-probe="value">Agent habilité</dd></div></dl>
       <div class="support-verification"><div><strong data-probe="verification">Vérification conforme</strong><small data-probe="verified-by">Autre responsable</small></div></div></section>
      <div hidden="hidden" data-hidden="thread"><p>Échanges</p></div>
     </div></dialog>
    </body></html>'''
    return base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(source))


for order in [FILES, [FILES[-1], *FILES[:-1]]]:
    rules = base.matcher(order)
    for theme in ['light', 'dark', 'contrast']:
        # Le même tableau doit conserver sa lisibilité dans les pages et drawers.
        base.evaluate(rules, theme)
        root = fixture(theme)
        computed = {}
        for element in root.iter_subtree():
            computed[element] = base.style(element, rules, computed.get(element.parent))
        for element in root.query_all('[data-probe]'):
            values = computed[element]
            current = element
            background = values.get('background-color', '')
            while background in ('', 'transparent', 'none') and current.parent:
                current = current.parent
                background = computed[current].get('background-color', '')
            text = values.get('color', '')
            check(bool(text) and bool(background), f'{theme}: couleurs définies pour {element.etree_element.get("data-probe")}')
            check(base.contrast(base.colour(text), base.colour(background)) >= 4.5,
                  f'{theme}: texte lisible dans {element.etree_element.get("data-probe")} ({text} sur {background})')
            if theme in ('dark', 'contrast'):
                check(max(base.colour(background)) < 100, f'{theme}: aucune surface blanche résiduelle')
        for element in root.query_all('[data-hidden]'):
            check(computed[element].get('display') == 'none', f'{theme}: rubrique inactive masquée')

report = {'success': True, 'checks': checks + base.checks,
          'coverage': ['Cascade des vraies feuilles Support et tableaux communs',
                       'Clair, sombre, contraste élevé ; deux ordres de chargement',
                       'Cartes Kanban, graphiques, champs, résolutions et drawers',
                       'Contraste texte 4.5 et absence de surface blanche en sombre',
                       'Tableaux page/drawer : entêtes, lignes, sélection et actions'],
          'limits': ['Fixtures CSS/XML, aucun navigateur ni capture visuelle',
                     'Disposition responsive et dimensions réelles non évaluées']}
(ROOT / '.runtime' / 'support-theme-tests.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
