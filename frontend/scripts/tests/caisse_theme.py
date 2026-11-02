"""Cascade Caisse réelle sur fixtures XML, sans substituer une recette navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('table_theme', Path(__file__).with_name('table_theme.py'))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
FILES = [*base.FILES, 'src/components/ActionButton.css', 'src/components/RegisterSurface.css',
         'src/components/RecordEditor.css', 'src/components/DrawerDialog.css',
         'src/components/ConsultationTabs.css', 'src/pages/admin/AdminPortal.css',
         'src/pages/caisse/Caisse.css']
checks = 0


def check(value, message):
    global checks
    assert value, message
    checks += 1


def fixture(theme):
    return base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(f'''<html data-theme="{theme}"><body>
      <main class="logistics-modern logistics-app admin-portal caisse-module">
        <p class="caisse-scope-note" data-probe="scope">Entreprise A</p>
        <form class="caisse-dashboard-filters"><label><span data-probe="label">Du</span><input data-probe="date" /></label></form>
        <section class="caisse-currency-block"><header><div><h2 data-probe="currency">USD</h2><p data-probe="currency-name">Dollar</p></div></header>
          <div class="caisse-kpi-grid"><button class="caisse-kpi"><span data-probe="kpi-label">Solde disponible</span><strong data-probe="kpi-value">150,00 USD</strong></button></div>
          <div class="caisse-flow-chart"><h3 data-probe="chart-title">Flux quotidiens</h3><div class="caisse-flow-row"><time data-probe="flow-date">02/11/2026</time><span data-probe="flow-value">150,00 USD<small data-probe="flow-out">0,00 USD</small></span></div></div>
        </section>
        <section class="caisse-drill-register"><header><h3 data-probe="drill-title">Encaissements</h3></header></section>
      </main>
      <dialog class="resizable-drawer caisse-editor" open="open"><div class="record-editor-body"><section class="record-editor-section caisse-fields">
        <h3 data-probe="section">Informations de l’écriture</h3><div class="caisse-field-grid">
          <label><span data-probe="input-label">Montant</span><input data-probe="input" value="150.00" /></label>
          <label><span>Référence</span><input data-probe="disabled" disabled="disabled" /></label>
          <label><span>Motif</span><textarea data-probe="motif">Justification</textarea></label>
          <div class="caisse-balance"><span data-probe="balance-label">Solde théorique</span><strong data-probe="balance-value">150,00 USD</strong></div>
        </div><p class="record-editor-note" data-probe="hint">Heure de Kinshasa.</p></section></div></dialog>
      <dialog class="resizable-drawer caisse-detail" open="open"><div class="record-editor-body"><section class="record-editor-section">
        <div class="caisse-detail-heading"><div><h2 data-probe="code">ECR-12</h2><p data-probe="description">Encaissement</p></div></div>
        <dl class="caisse-summary"><div><dt data-probe="term">Auteur</dt><dd data-probe="value">Agent habilité</dd></div></dl>
      </section></div></dialog>
    </body></html>'''))


for order in [FILES, [FILES[-1], *FILES[:-1]]]:
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
            check(bool(text) and bool(background), f'{theme}: couleurs définies pour {probe}')
            check(base.contrast(base.colour(text), base.colour(background)) >= 4.5,
                  f'{theme}: contraste du texte {probe}: {text} sur {background}')
            if theme in ('dark', 'contrast'):
                check(max(base.colour(background)) < 100, f'{theme}: surface blanche résiduelle {probe}')

report = {'success': True, 'checks': checks + base.checks,
          'coverage': ['Feuilles réelles Caisse et tableaux communs',
                       'Clair, sombre, contraste élevé et deux ordres de cascade',
                       'Dashboard, montants, graphique, champs et drawers',
                       'Contraste de texte 4.5 et absence de surfaces blanches résiduelles'],
          'limits': ['Fixtures CSS/XML ; dimensions et disposition non évaluées dans un navigateur']}
(ROOT / '.runtime' / 'caisse-theme-tests.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
