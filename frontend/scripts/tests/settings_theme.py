"""Couleurs des vrais composants Paramètres/TVA sur fixtures, sans navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('shared_table_theme', Path(__file__).with_name('table_theme.py'))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
FILES = [*base.FILES, 'src/components/ActionButton.css', 'src/components/RecordEditor.css',
         'src/components/DrawerDialog.css', 'src/components/ConsultationTabs.css',
         'src/pages/admin/AdminPortal.css', 'src/components/EntityDocumentIdentity.css',
         'src/components/InvoiceTaxSummary.css', 'src/pages/Parametres.css']
checks = 0


def check(value, message):
    global checks
    assert value, message
    checks += 1


def fixture(theme):
    return base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(f'''<html data-theme="{theme}"><body>
     <main class="logistics-modern logistics-app admin-portal settings-module">
      <header class="settings-heading"><h1 data-probe="titre">Fiscalité</h1><p data-probe="entreprise">Entreprise A</p></header>
      <div class="settings-content"><section class="record-editor-section"><h2 data-probe="section">Coordonnées</h2>
       <dl class="settings-details"><div><dt data-probe="label">Nom de l'entreprise</dt><dd data-probe="value">Entreprise A</dd></div></dl>
       <div class="record-editor-grid"><div class="record-field entity-profile-tax"><label data-probe="tva-label">Taux de TVA (%)</label>
       <div class="entity-profile-rate"><input readonly="readonly" data-probe="tva-value" value="16.1250"/><span data-probe="percent">%</span></div>
       <small data-probe="hint">Appliqué aux nouvelles factures.</small></div></div></section></div>
      <dl class="invoice-tax-summary"><div><dt data-probe="ht">Montant HT</dt><dd data-probe="ht-value">100,00 USD</dd></div>
       <div><dt data-probe="tax">TVA (16,125 %)</dt><dd data-probe="tax-value">16,13 USD</dd></div><div><dt>Montant TTC</dt><dd data-probe="ttc">116,13 USD</dd></div></dl>
     </main>
     <dialog class="resizable-drawer entity-profile-editor" open="open"><div class="record-editor-body">
      <section class="record-editor-section"><h3 data-probe="drawer-title">TVA</h3><div class="record-field entity-profile-tax">
       <label data-probe="drawer-label">Taux de TVA (%)</label><div class="entity-profile-rate"><input data-probe="drawer-input" value="16.1250"/><span data-probe="drawer-percent">%</span></div>
       <small data-probe="drawer-hint">Les factures émises restent inchangées.</small></div></section>
     </div></dialog>
    </body></html>'''))


for files in [FILES, [FILES[-1], FILES[-2], *FILES[:-2]]]:
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
          'scope': 'Couleurs Paramètres, TVA et totaux, dans la page et la fenêtre, clair/sombre/contraste élevé',
          'limits': ['Fixtures CSS/XML ; aucune disposition ou recette visuelle navigateur']}
(ROOT / '.runtime' / 'settings-theme-tests.json').write_text(json.dumps(result, indent=2), encoding='utf8')
print(json.dumps(result))
