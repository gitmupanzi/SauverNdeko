"""Contraste et contrats CSS des outils communs, sans rendu navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util
import json
import re

spec = importlib.util.spec_from_file_location('table_theme', Path(__file__).with_name('table_theme.py'))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
common = ['src/components/ActionButton.css', 'src/components/DataTable.css',
          'src/components/TablePagination.css', 'src/components/ListState.css',
          'src/components/RowActionsMenu.css', 'src/components/RegisterSurface.css',
          'src/components/AppliedCriteria.css', 'src/pages/WorkspaceHome.css']
files = [*base.FILES[:-1], *common]
checks = 0
failures = []


def check(value, message):
    global checks
    if not value:
        failures.append(message)
    checks += 1


def matches_media(condition, width, coarse, reduced):
    def matches_branch(branch):
        tests = re.findall(r'\(([^)]+)\)', branch)
        for test in tests:
            key, _, value = test.partition(':')
            key, value = key.strip(), value.strip()
            if key in ('max-width', 'min-width'):
                limit = float(value.removesuffix('px'))
                if not (width <= limit if key == 'max-width' else width >= limit):
                    return False
            elif key == 'pointer':
                if (value == 'coarse') != coarse:
                    return False
            elif key == 'prefers-reduced-motion':
                if (value == 'reduce') != reduced:
                    return False
            else:
                return False  # Do not infer an unsupported media environment.
        return bool(tests)
    return any(matches_branch(branch) for branch in condition.split(','))


def matcher(order, width=1440, coarse=False, reduced=False):
    result = base.cssselect2.Matcher()

    def add_rules(rules):
        for rule in rules:
            if rule.type == 'at-rule' and rule.lower_at_keyword == 'media' and rule.content:
                if matches_media(base.tinycss2.serialize(rule.prelude), width, coarse, reduced):
                    add_rules(base.tinycss2.parse_rule_list(rule.content, skip_comments=True, skip_whitespace=True))
            elif rule.type == 'qualified-rule':
                selector = base.tinycss2.serialize(rule.prelude).replace(':hover', '.qa-hover').replace(':focus-visible', '.qa-focus-visible')
                try:
                    selectors = base.cssselect2.compile_selector_list(selector)
                except base.cssselect2.SelectorError:
                    continue
                declarations = [(decl.lower_name, base.tinycss2.serialize(decl.value).strip(), decl.important)
                                for decl in base.tinycss2.parse_declaration_list(rule.content, skip_comments=True, skip_whitespace=True)
                                if decl.type == 'declaration']
                for selector in selectors:
                    result.add_selector(selector, declarations)
    for file in order:
        add_rules(base.tinycss2.parse_stylesheet((base.FRONT / file).read_text(encoding='utf8'), skip_comments=True, skip_whitespace=True))
    return result


fixture = '''<html data-theme="THEME"><body><main class="logistics-modern erp-results erp-register"><form class="erp-table-toolbar">
<label class="erp-table-search"><input data-probe="search"/></label>
<button class="ui-action is-primary" data-probe="primary">Rechercher</button>
<button class="ui-action is-secondary qa-hover" data-probe="secondary">Filtrer</button>
<button class="ui-action is-secondary" disabled="disabled" data-probe="disabled">Réinitialiser</button>
<button class="ui-action is-secondary is-active" aria-expanded="true" data-probe="filter">Filtrer <span class="erp-filter-count" data-probe="count">2</span></button>
<label class="erp-table-size"><span data-probe="size">Lignes</span><select><option>25</option></select></label></form>
<p class="erp-table-pending" data-probe="pending">Validez la recherche</p><p class="erp-table-error" data-probe="error">Export indisponible</p>
<div class="applied-criteria"><button class="applied-criterion" data-probe="criterion"><span>Recherche : <strong>Souris</strong></span></button><button class="applied-criterion" data-probe="criterion-disabled" disabled="disabled"><span>Catégorie : Bureautique</span></button></div>
<div class="erp-data-grid"><div class="logistics-table-wrap"><table class="admin-table"><tbody><tr class="erp-grid-empty"><td>
<div class="ui-list-state is-loading"><span class="ui-list-state-icon" data-probe="empty-icon"><svg class="app-icon"/></span>
<div class="ui-list-state-copy"><strong data-probe="empty-title">Aucun résultat</strong><div class="ui-list-state-description" data-probe="empty-help">Essayez un autre mot</div></div>
<div class="ui-list-state-action"><button class="ui-action" data-probe="empty-action">Effacer les critères</button></div></div></td></tr></tbody></table></div></div>
<footer class="table-pagination"><div class="table-pagination-summary" data-probe="summary">1–25 sur 55</div><nav class="table-pagination-nav">
<button class="ui-action" data-probe="previous"><svg class="app-icon"/><span class="table-pagination-step-label" data-label="previous">Précédent</span></button>
<div class="table-pagination-pages"><button class="table-pagination-number" data-probe="page">1</button><span class="table-pagination-number is-current" data-probe="current">2</span></div>
<button class="ui-action" data-probe="next"><span class="table-pagination-step-label" data-label="next">Suivant</span></button></nav></footer>
<div class="erp-register-table"><div class="erp-row-actions"><button class="erp-row-consult" data-target="consult">Voir</button><button class="erp-row-menu-trigger" data-target="more">…</button></div></div>
</main><div class="erp-row-menu"><button data-probe="menu">Consulter</button><button class="is-danger" data-probe="danger">Archiver</button><button class="is-danger qa-hover" data-probe="danger-hover">Archiver</button><button disabled="disabled" data-probe="menu-disabled">Supprimer</button><button aria-checked="true" data-probe="menu-selected">Tableau</button></div>
<div class="workspace-home"><main class="workspace-main"><form class="workspace-search"><input type="search"/><button type="button" class="workspace-search-clear" data-probe="workspace-clear"><svg class="app-icon"/></button></form></main></div></body></html>'''


def computed_fixture(theme, rules):
    root = base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(fixture.replace('THEME', theme)))
    computed = {}
    for node in root.iter_subtree():
        computed[node] = base.style(node, rules, computed.get(node.parent))
    return root, computed


for order in [files, [*common, *base.FILES[:-1]]]:
    rules = matcher(order)
    for theme in ['light', 'dark', 'contrast']:
        root, computed = computed_fixture(theme, rules)
        for node in root.query_all('[data-probe]'):
            name = node.etree_element.get('data-probe')
            foreground = computed[node]['color']
            current, background = node, computed[node]['background-color']
            while background in ('transparent', '', 'none') and current.parent:
                current = current.parent
                background = computed[current]['background-color']
            check(base.contrast(base.colour(foreground), base.colour(background)) >= 4.5,
                  (theme, name, foreground, background))
            check(computed[node]['opacity'] == '1', (theme, name, 'pas de texte estompé'))

for width in [320, 375, 768, 1440, 1920]:
    root, computed = computed_fixture('dark', matcher(files, width=width, coarse=True, reduced=True))
    for name in ['primary', 'previous', 'next']:
        node = next(root.query_all('[data-probe="' + name + '"]'))
        check(float(computed[node]['min-height'].removesuffix('px')) >= 44, (width, name, 'hauteur tactile'))
    for name in ['previous', 'next']:
        node = next(root.query_all('[data-probe="' + name + '"]'))
        label = next(node.query_all('[data-label]'))
        if width > 760:
            check(computed[label].get('display') != 'none', (width, name, 'libellé conservé'))
            check(computed[node].get('width', 'auto') == 'auto', (width, name, 'largeur libre pour le libellé'))
        else:
            check(computed[label].get('display') == 'none', (width, name, 'libellé mobile masqué'))
    for node in root.query_all('[data-target]'):
        check(float(computed[node]['min-width'].removesuffix('px')) >= 44, (width, node.etree_element.get('data-target'), 'cible tactile'))
    for name in ['criterion', 'criterion-disabled']:
        node = next(root.query_all('[data-probe="' + name + '"]'))
        check(float(computed[node]['min-height'].removesuffix('px')) >= 44, (width, name, 'hauteur tactile'))
    if width in [320, 375, 768]:
        node = next(root.query_all('[data-probe="workspace-clear"]'))
        for dimension in ['width', 'height']:
            check(float(computed[node][dimension].removesuffix('px')) >= 44, (width, 'effacer recherche', dimension))
        form = next(root.query_all('.workspace-search'))
        check(computed[form].get('display') in ('flex', 'inline-flex', 'grid') or computed[node].get('position') == 'absolute',
              (width, 'bouton de recherche dans le champ ou sa ligne'))
    spinner = next(root.query_all('.ui-list-state-icon .app-icon'))
    check(computed[spinner].get('animation') == 'none', (width, 'animation réduite'))

print(json.dumps({'success': not failures, 'checks': checks, 'failures': failures, 'themes': ['light', 'dark', 'contrast'],
                  'coverage': ['Cascade réelle de huit styles communs, deux ordres de chargement',
                               'Contraste >=4.5:1 : recherche, filtres, messages, états de liste, pagination et menus',
                               'Puces appliquées normales/désactivées, cible44 et effacement recherche espace à320/375/768',
                               'Contrats tactiles et pagination à cinq largeurs, réduction des animations'],
                  'limits': ['Fixtures CSS/XML, sans rendu ni mesure de mise en page dans le navigateur',
                             'Media queries de largeur, pointeur et réduction des animations ; container queries hors mesure']}, ensure_ascii=False))
if failures:
    raise SystemExit(1)
