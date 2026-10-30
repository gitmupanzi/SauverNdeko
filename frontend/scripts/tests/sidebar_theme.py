"""Cascade des vraies feuilles de navigation, sans rendu navigateur."""
from pathlib import Path
import importlib.util
import json
import re
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('table_theme', Path(__file__).with_name('table_theme.py'))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
FILES = ['src/components/ModuleSidebar.css', 'src/styles.css', 'src/theme.css',
         'src/pages/logistique/LogistiqueModern.css', 'src/pages/admin/AdminPortal.css']
checks = 0


def check(value, message):
    global checks
    assert value, message
    checks += 1


def matcher(files, width):
    result = base.cssselect2.Matcher()
    def add(rules):
        for rule in rules:
            if rule.type == 'at-rule' and rule.lower_at_keyword == 'media' and rule.content:
                query = base.tinycss2.serialize(rule.prelude)
                minima = re.findall(r'min-width\s*:\s*([\d.]+)px', query)
                maxima = re.findall(r'max-width\s*:\s*([\d.]+)px', query)
                if 'prefers-reduced-motion' not in query and all(width >= float(v) for v in minima) and all(width <= float(v) for v in maxima):
                    add(base.tinycss2.parse_rule_list(rule.content, skip_comments=True, skip_whitespace=True))
            if rule.type != 'qualified-rule':
                continue
            selector = base.tinycss2.serialize(rule.prelude).replace(':hover', '.qa-hover').replace(':focus-visible', '.qa-focus')
            try:
                selectors = base.cssselect2.compile_selector_list(selector)
            except base.cssselect2.SelectorError:
                continue
            declarations = [(decl.lower_name, base.tinycss2.serialize(decl.value).strip(), decl.important)
                            for decl in base.tinycss2.parse_declaration_list(rule.content, skip_comments=True, skip_whitespace=True)
                            if decl.type == 'declaration']
            for compiled in selectors:
                result.add_selector(compiled, declarations)
    for file in files:
        add(base.tinycss2.parse_stylesheet((base.FRONT / file).read_text(encoding='utf-8'), skip_comments=True, skip_whitespace=True))
    return result


def fixture(theme, context, mode):
    wrapper = 'logistics-modern logistics-app ' + {'logistique': '', 'admin': 'admin-portal', 'references': 'references-app', 'territoires': 'territorial-module', 'catalogue': ''}[context]
    sidebar = 'logistics-sidebar-shell erp-module-sidebar'
    if mode == 'collapsed':
        wrapper += ' is-menu-collapsed'
        sidebar += ' is-collapsed'
    if mode == 'mobile-open': sidebar += ' is-mobile-open'
    if context == 'catalogue':
        sidebar += ' is-overlay is-open'
        wrapper = 'catalogue-app'
    html = f'''<html data-theme="{theme}"><body><main class="{wrapper}"><aside class="{sidebar}">
    <div class="logistics-sidebar-top"><span class="logistics-brand-copy"><strong>SauverNdeko</strong><span>Module</span></span><button class="logistics-sidebar-toggle" /></div>
    <nav class="logistics-sidebar-nav"><section class="logistics-nav-group"><button class="module-nav-group-toggle logistics-nav-heading">Accès</button><div class="module-nav-items">
    <button class="logistics-sidebar-link normal"><span class="logistics-sidebar-icon"/><span class="logistics-sidebar-label">Utilisateurs</span></button>
    <button class="logistics-sidebar-link is-active"><span class="logistics-sidebar-icon"/><span class="logistics-sidebar-label">Entreprises</span></button>
    <button class="logistics-sidebar-link qa-hover"><span class="logistics-sidebar-icon"/><span class="logistics-sidebar-label">Rôles</span></button>
    <button class="logistics-sidebar-link qa-focus"><span class="logistics-sidebar-icon"/><span class="logistics-sidebar-label">Réglages</span></button>
    </div></section></nav><div class="logistics-app-switcher"><a class="logistics-sidebar-link"><span class="logistics-sidebar-icon"/><span class="logistics-sidebar-label">Applications</span></a></div>
    </aside></main></body></html>'''
    return base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(html))


def evaluate(rules, theme, context, width, mode):
    root = fixture(theme, context, mode)
    computed = {}
    wrappers = list(root.iter_subtree())
    for node in wrappers:
        computed[node] = base.style(node, rules, computed.get(node.parent))
    aside = next(node for node in wrappers if node.local_name == 'aside')
    background = base.colour(computed[aside]['background-color'])
    check(computed[aside]['display'] == 'flex', 'Sidebar remains a column shell')
    check(max(background) < 100, f'{theme}/{context}/{width}: no white sidebar')
    nav = next(node for node in wrappers if 'logistics-sidebar-nav' in node.classes)
    check(computed[nav].get('overflow') == 'auto' or computed[nav].get('overflow-y') == 'auto', 'Scrollable menu remains independent')
    for node in wrappers:
        if 'logistics-sidebar-link' not in node.classes: continue
        values = computed[node]
        fill = values['background-color']
        row_background = background if fill == 'transparent' else base.colour(fill)
        check(base.contrast(base.colour(values['color']), row_background) >= 4.5, f'{theme}/{context}/{width}: readable link')
        icon = next(child for child in node.iter_children() if 'logistics-sidebar-icon' in child.classes)
        check(computed[icon]['background-color'] == 'transparent', f'{theme}/{context}/{width}/{mode}: outline icon background {computed[icon]["background-color"]}')
        check(base.contrast(base.colour(computed[icon]['color']), row_background) >= 4.5, 'Readable navigation icon')
        label = next(child for child in node.iter_children() if 'logistics-sidebar-label' in child.classes)
        rail = context != 'catalogue' and (mode == 'collapsed' or width <= 760) and mode != 'mobile-open'
        check((computed[label].get('display') == 'none') == rail, 'Rail labels hidden only in compact mode')
        if 'qa-focus' in node.classes:
            check('2px' in values.get('outline', '') and values.get('outline-offset') == '2px', 'Keyboard focus remains visible')
    group = next(node for node in wrappers if 'module-nav-group-toggle' in node.classes)
    expected_group = 'none' if context != 'catalogue' and (mode == 'collapsed' or width <= 760) and mode != 'mobile-open' else 'flex'
    check(computed[group].get('display') == expected_group, 'Group headings adapt to rail and mobile menu')
    if context != 'catalogue':
        main = next(node for node in wrappers if node.local_name == 'main')
        expected_width = '60px' if width <= 760 else '76px' if mode == 'collapsed' else '226px' if width <= 1000 else '250px'
        check(computed[main]['variables']['--sidebar-width'] == expected_width, 'Content offset matches sidebar width')
    if mode == 'mobile-open' or context == 'catalogue':
        check(computed[aside].get('z-index') == '80', 'Mobile menu above its backdrop')


if __name__ == '__main__':
    for order in [FILES, [*FILES[1:], FILES[0]]]:
        for width in [1440, 900, 390]:
            rules = matcher(order, width)
            for theme in ['light', 'dark', 'contrast']:
                for context in ['logistique', 'admin', 'references', 'territoires', 'catalogue']:
                    for mode in (['expanded', 'collapsed', 'mobile-open'] if width <= 760 and context != 'catalogue' else ['expanded', 'collapsed'] if context != 'catalogue' else ['expanded']):
                        evaluate(rules, theme, context, width, mode)
    report = {'success': True, 'checks': checks, 'coverage': ['Actual CSS cascade', 'Five navigation surfaces', 'Light/dark/high contrast', '1440/900/390 media rules', 'Expanded, rail and mobile menu', 'Two stylesheet orders', 'Text and icon contrast >= 4.5'], 'limits': ['CSS and XML fixtures, no browser layout or screenshot']}
    (ROOT / '.runtime/sidebar-theme-tests.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
