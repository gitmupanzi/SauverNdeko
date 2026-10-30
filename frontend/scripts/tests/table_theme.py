"""CSS cascade proof, without a browser or application connection.

Uses tinycss2 + cssselect2, installed for this check in .runtime/css-qa-deps.
Evaluates the real stylesheets against page and detached-dialog fixtures. It
does not claim browser layout/rendering coverage. :hover is represented by a
fixture class of identical specificity.
"""
from pathlib import Path
import json
import re
import sys
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / '.runtime' / 'css-qa-deps'))
import tinycss2
import cssselect2

FRONT = ROOT / 'frontend'
FILES = ['node_modules/bootstrap/dist/css/bootstrap.min.css', 'src/styles.css',
         'src/theme.css', 'src/pages/logistique/LogistiqueModern.css',
         'src/components/DataTable.css']
checks = 0


def check(condition, message):
    global checks
    assert condition, message
    checks += 1


def matcher(files):
    result = cssselect2.Matcher()
    for file in files:
        parsed = tinycss2.parse_stylesheet((FRONT / file).read_text(encoding='utf-8'),
                                           skip_comments=True, skip_whitespace=True)
        for rule in parsed:
            if rule.type != 'qualified-rule':
                continue  # Viewport/container/media layout is outside this colour proof.
            selector = tinycss2.serialize(rule.prelude).replace(':hover', '.qa-hover')
            try:
                selectors = cssselect2.compile_selector_list(selector)
            except cssselect2.SelectorError:
                continue
            declarations = [(decl.lower_name, tinycss2.serialize(decl.value).strip(), decl.important)
                            for decl in tinycss2.parse_declaration_list(rule.content, skip_comments=True, skip_whitespace=True)
                            if decl.type == 'declaration']
            for compiled in selectors:
                result.add_selector(compiled, declarations)
    return result


def variables_in(text, variables, seen=()):
    tokens = tinycss2.parse_component_value_list(text)
    def render(token):
        if token.type == 'function' and token.lower_name == 'var':
            parts = tinycss2.serialize(token.arguments).split(',', 1)
            name = parts[0].strip()
            if name in seen:
                return parts[1].strip() if len(parts) > 1 else ''
            return variables_in(variables.get(name, parts[1].strip() if len(parts) > 1 else ''), variables, (*seen, name))
        if token.type == 'function':
            return token.name + '(' + ''.join(render(item) for item in token.arguments) + ')'
        return tinycss2.serialize([token])
    return ''.join(render(token) for token in tokens).strip()


def style(element, rules, parent=None, pseudo=None):
    winning = {}
    for specificity, order, matched_pseudo, declarations in rules.match(element):
        if pseudo != matched_pseudo:
            continue
        for index, (name, value, important) in enumerate(declarations):
            priority = (important, specificity, order, index)
            targets = [name]
            if name == 'background':
                targets.append('background-color')
            for target in targets:
                if target not in winning or priority >= winning[target][0]:
                    winning[target] = priority, value
    variables = dict(parent.get('variables', {}) if parent else {})
    variables.update({name: value for name, (_, value) in winning.items() if name.startswith('--')})
    variables = {name: variables_in(value, variables, (name,)) for name, value in variables.items()}
    result = {'variables': variables, 'color': parent.get('color', '#000') if parent else '#000',
              'background-color': 'transparent', 'opacity': '1'}
    for name, (_, value) in winning.items():
        if name.startswith('--'):
            continue
        resolved = variables_in(value, variables)
        result[name] = (parent or {}).get(name, '') if resolved == 'inherit' else resolved
    return result


def fixture(theme):
    table = '''<div class="logistics-advanced-table erp-data-grid"><div class="public-table-wrap logistics-table-wrap admin-table-wrap">
      <table class="public-table logistics-table admin-table table table-hover"><thead><tr>
      <th class="admin-table-head-cell is-pinned"><button class="admin-header-trigger" disabled="disabled"><span class="admin-header-label">Article</span></button></th>
      <th class="admin-table-head-cell"><button class="admin-header-trigger"><span class="admin-header-label">Quantité</span></button></th>
      <th class="admin-table-head-cell"><span class="admin-header-label">Actions</span></th></tr></thead><tbody>'''
    for row, state in enumerate(['', '', 'is-selected', 'logistics-row-selected', 'qa-hover', 'qa-hover is-selected'], 1):
        table += f'<tr class="admin-table-row {state}" data-row="{row}"><td class="admin-table-cell is-pinned">Matériel</td><td class="admin-table-cell">10</td><td class="admin-table-cell admin-actions-cell">⋯</td></tr>'
    table += '</tbody></table></div></div>'
    html = f'<html data-theme="{theme}"><body><main class="logistics-modern logistics-screen-table-card erp-results" data-context="page">{table}</main><dialog class="resizable-drawer" open="open" data-context="portal">{table}</dialog></body></html>'
    return cssselect2.ElementWrapper.from_html_root(ET.fromstring(html))


def colour(text):
    text = text.strip().lower()
    if text == 'white': return (255., 255., 255.)
    if text == 'black': return (0., 0., 0.)
    if text.startswith('#'):
        value = text[1:]
        if len(value) == 3: value = ''.join(char * 2 for char in value)
        return tuple(float(int(value[index:index + 2], 16)) for index in (0, 2, 4))
    if text.startswith('color-mix(in srgb,'):
        parts = text[len('color-mix(in srgb,'):-1].split(',')
        left, right = parts[0].strip(), parts[1].strip()
        proportion = re.search(r'\s+(\d+(?:\.\d+)?)%$', left)
        weight = float(proportion.group(1)) / 100 if proportion else .5
        first, second = colour(left[:proportion.start()] if proportion else left), colour(right)
        return tuple(a * weight + b * (1 - weight) for a, b in zip(first, second))
    raise AssertionError('Unexpected colour (legacy gradient/white overlay?): ' + text)


def contrast(first, second):
    def luminance(rgb):
        linear = [value / 3294.6 if value <= 10.31475 else ((value / 255 + .055) / 1.055) ** 2.4 for value in rgb]
        return sum(value * coefficient for value, coefficient in zip(linear, [.2126, .7152, .0722]))
    values = sorted([luminance(first), luminance(second)])
    return (values[1] + .05) / (values[0] + .05)


def evaluate(rules, theme):
    root = fixture(theme)
    computed = {}
    for element in root.iter_subtree():
        computed[element.etree_element] = style(element, rules, computed.get(element.parent.etree_element) if element.parent else None)
    for context in root.query_all('[data-context]'):
        context_name = context.etree_element.attrib['data-context']
        for label in context.query_all('.admin-header-label'):
            values = computed[label.etree_element]
            header = next(parent for parent in label.ancestors[::-1] if parent.etree_element.tag == 'th')
            background = computed[header.etree_element]['background-color']
            check(colour(background) == colour(values['variables']['--erp-raised']), f'{theme}/{context_name}: header surface')
            check(contrast(colour(values['color']), colour(background)) >= 4.5, f'{theme}/{context_name}: header contrast')
        disabled = next(context.query_all('.admin-header-trigger[disabled]'))
        check(computed[disabled.etree_element]['opacity'] == '1', f'{theme}/{context_name}: non-sortable header readable')
        for row in context.query_all('tbody tr'):
            cells = list(row.query_all('td'))
            row_styles = [computed[cell.etree_element] for cell in cells]
            backgrounds = [colour(value['background-color']) for value in row_styles]
            check(all(background == backgrounds[0] for background in backgrounds), f'{theme}/{context_name}: pinned/action cells match row')
            for cell, values, background in zip(cells, row_styles, backgrounds):
                check(contrast(colour(values['color']), background) >= 4.5, f'{theme}/{context_name}: body text contrast')
                check('var(--erp-border' not in values.get('border-bottom', ''), 'Border token resolved')
                for pseudo in ('before', 'after') if 'admin-actions-cell' in cell.classes else ():
                    check(style(cell, rules, values, pseudo)['display'] == 'none', f'{theme}/{context_name}: no legacy action overlay')
            if theme in ('dark', 'contrast'):
                check(max(backgrounds[0]) < 100, f'{theme}/{context_name}: no pale/white row')
    return True


if __name__ == '__main__':
    # Both normal and adverse load orders: the shared component is independent of portal ancestry and legacy CSS timing.
    for order in [FILES, [FILES[-1], *FILES[:-1]]]:
        rules = matcher(order)
        for theme in ['light', 'dark', 'contrast']:
            evaluate(rules, theme)
    report = {'success': True, 'checks': checks, 'coverage': ['Real CSS cascade via tinycss2/cssselect2', 'Light/dark/high contrast',
              'Page and detached dialog without erp-results ancestor', 'Headers, normal/striped/selected/hover rows',
              'Pinned and action cells; legacy overlays disabled', 'Two stylesheet load orders', 'WCAG 4.5 text contrast'],
              'limits': ['Colour cascade fixtures; no browser layout or screenshot test', 'Media/container layout not evaluated']}
    (ROOT / '.runtime' / 'table-theme-tests.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
