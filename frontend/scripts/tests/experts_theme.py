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
         'src/components/ProductPhotoPicker.css','src/pages/experts/Experts.css']
checks = 0


def check(value, message):
    global checks
    assert value, message
    checks += 1


def fixture(theme):
    return base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(f'''<html data-theme="{theme}"><body>
      <main class="logistics-modern logistics-app admin-portal experts-module">
        <p class="expert-scope-note" data-probe="scope">Entreprise A</p>
        <section class="expert-directory"><article class="expert-directory-card">
          <header><span class="expert-avatar" data-probe="avatar">AB</span><div><span class="expert-sector" data-probe="sector">Santé</span><h2><button data-probe="name">Expert Exemple</button></h2><p data-probe="title">Oncologue</p></div></header>
          <span class="expert-specialty" data-probe="specialty">Oncologie</span><p class="expert-card-summary" data-probe="summary">Présentation</p><div class="expert-tags"><span data-probe="tag">Consultation</span></div><footer><span data-probe="locality">Kinshasa</span></footer>
        </article><div class="expert-empty"><h2 data-probe="empty">Aucun résultat</h2><p data-probe="empty-hint">Élargissez les critères.</p></div></section>
      </main>
      <dialog class="resizable-drawer expert-editor" open="open"><div class="record-editor-body"><section class="record-editor-section expert-editor-panel"><div class="expert-fields">
        <div class="product-photo-picker"><div class="product-photo-preview"><img data-probe="photo-background" /></div><div class="product-photo-tools"><strong data-probe="photo-label">Photo de profil</strong><span data-probe="photo-hint">8 Mo maximum</span></div></div><label><span data-probe="input-label">Titre</span><input data-probe="input" value="Oncologue" /></label><label><span>Présentation</span><textarea data-probe="textarea">Parcours</textarea></label><label><span>Utilisateur</span><input data-probe="disabled" disabled="disabled" value="Expert Exemple" /></label>
        <small data-probe="hint">Information interne.</small><small class="expert-field-error" data-probe="error">Champ obligatoire.</small>
      </div><div class="expert-choices"><h4 data-probe="choice-title">Compétences</h4><ul><li data-probe="choice">Oncologie</li></ul></div></section></div></dialog>
      <dialog class="resizable-drawer expert-detail" open="open"><div class="record-editor-body"><section class="record-editor-section"><div class="expert-profile-heading"><div><h2 data-probe="profile">Expert Exemple</h2><p data-probe="profession">Oncologue</p></div></div><p class="expert-profile-text" data-probe="presentation">Présentation</p><dl class="expert-summary"><div><dt data-probe="term">Expérience</dt><dd data-probe="value">10 ans</dd></div></dl><ul class="expert-capabilities"><li data-probe="capability">Conseil</li></ul><div class="expert-structures"><article><h4 data-probe="structure">Structure</h4><p data-probe="address">Adresse</p></article></div><div class="expert-references"><section><h4 data-probe="ref-title">Secteur</h4><p data-probe="ref-label">Catégorie</p><details><summary data-probe="ref-values">Valeurs</summary></details></section></div></section></div></dialog>
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

print(json.dumps({'success':True,'checks':checks+base.checks,'coverage':['Cascade CSS réelle annuaire, fiches, formulaires, références','Thèmes clair/sombre/contraste','Texte >= 4.5:1 et aucune surface blanche résiduelle sombre','Deux ordres de chargement CSS'],'limits':['Fixtures CSS et XML, aucune recette visuelle navigateur']},ensure_ascii=False))
