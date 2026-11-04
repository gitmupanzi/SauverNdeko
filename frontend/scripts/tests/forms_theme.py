"""Contraste réel des champs/tiroirs et contrats responsive, sans navigateur."""
from pathlib import Path
from xml.etree import ElementTree as ET
import importlib.util,json
spec=importlib.util.spec_from_file_location('table_theme',Path(__file__).with_name('table_theme.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
files=[*base.FILES,'src/components/ActionButton.css','src/components/SearchSelect.css','src/components/RecordEditor.css','src/components/DrawerDialog.css']
checks=0
def check(value,message):
 global checks
 assert value,message
 checks+=1
source='''<html data-theme="THEME"><body>
<dialog class="resizable-drawer" open="open"><header class="drawer-header"><span class="drawer-mark" data-probe="mark">◇</span><div class="drawer-heading"><h2 data-probe="title">Modifier le profil</h2><p data-probe="subtitle">Entreprise sélectionnée</p></div><div class="drawer-controls"><button data-probe="close">×</button></div></header>
<div class="record-editor-body"><div class="record-editor-error" tabindex="-1" role="alert" data-probe="error">Vérifiez la quantité.</div>
<form><section class="record-editor-section"><h3 data-probe="section">Informations</h3><div class="record-editor-grid"><div class="record-field"><label data-probe="label">Désignation</label><input data-probe="input" value="Libellé"/><small data-probe="hint">Utilisez le nom courant.</small><span class="record-field-error" data-probe="field-error">La quantité doit être positive.</span></div><div class="record-field"><label data-probe="select-label">Unité</label><button class="search-select-trigger" data-probe="trigger"><span data-probe="trigger-value">pcs</span></button><input disabled="disabled" data-probe="disabled" value="Valeur conservée"/></div></div></section></form></div>
<footer class="record-editor-footer"><span role="status" data-probe="status">Modifications non enregistrées</span><div><button class="ui-action is-secondary" data-probe="cancel">Annuler</button><button class="ui-action is-primary" disabled="disabled" data-probe="submit-disabled">Enregistrer</button></div></footer>
<footer class="record-editor-footer"><div class="record-discard"><span data-probe="discard">Abandonner les modifications ?</span><div><button class="ui-action is-secondary" data-probe="continue">Continuer</button><button class="ui-action is-danger" data-probe="discard-action">Abandonner</button></div></div></footer></dialog>
<div class="search-select-panel"><label class="search-select-search"><input data-probe="search" value="recherche"/></label><div class="search-select-options"><button role="option" aria-selected="true" data-probe="selected"><span>Valeur retenue</span></button><button role="option" data-probe="option"><span>Autre valeur</span></button><button role="option" disabled="disabled" data-probe="option-disabled">Ancienne valeur</button><button role="option" aria-selected="true" disabled="disabled" data-probe="selected-disabled">Valeur conservée</button><p role="status" data-probe="empty">Aucun choix disponible.</p><p role="alert" data-probe="options-error">Réessayer la lecture.</p></div><div class="search-select-footer"><span role="status" data-probe="option-count">2 options</span><button data-probe="retry">Réessayer</button></div></div>
</body></html>'''
for order in [files,[files[-1],files[-2],*files[:-2]]]:
 rules=base.matcher(order)
 for theme in ['light','dark','contrast']:
  root=base.cssselect2.ElementWrapper.from_html_root(ET.fromstring(source.replace('THEME',theme)));computed={}
  for node in root.iter_subtree():computed[node]=base.style(node,rules,computed.get(node.parent))
  for node in root.query_all('[data-probe]'):
   name=node.etree_element.get('data-probe');values=computed[node];foreground=values['color'];current=node;background=values.get('background-color','')
   while background in ('','transparent','none') and current.parent:
    current=current.parent;background=computed[current].get('background-color','')
   check(bool(foreground and background),(theme,name,'couleurs définies'))
   check(base.contrast(base.colour(foreground),base.colour(background))>=4.5,(theme,name,foreground,background))
   if theme in ['dark','contrast'] and name not in ['selected','mark']:
    check(max(base.colour(background))<110,(theme,name,'absence de surface blanche'))
  for node in root.query_all('[disabled]'):
   check(computed[node].get('opacity') in ('1','1.0'),(theme,node.etree_element.get('data-probe'),'action indisponible lisible'))
css=(base.FRONT/'src/components/SearchSelect.css').read_text(encoding='utf8')
check('overscroll-behavior:contain' in css and 'min-height:0;flex:1' in css,'La liste défile dans le popup borné')
check('calc(100dvh - 24px)' in css,'Plafond mobile du menu')
check('@media(pointer:coarse)' in css and '@media(prefers-reduced-motion:reduce)' in css,'Tactile et réduction des animations')
drawer=(base.FRONT/'src/components/DrawerDialog.css').read_text(encoding='utf8')
check('overscroll-behavior:contain' in drawer and 'scroll-padding-block:16px' in drawer,'Défilement contenu dans la fiche')
check('min-width:44px;min-height:44px' in drawer,'Cibles tactiles des commandes')
record=(base.FRONT/'src/components/RecordEditor.css').read_text(encoding='utf8')
check('env(safe-area-inset-bottom)' in record,'Actions éloignées du bord système mobile')
check('@media(max-width:480px)' in record and 'flex-wrap:wrap' in record,'Actions de confirmation adaptées au mobile')
report={'success':True,'checks':checks,'coverage':['Cascade des vraies feuilles en trois thèmes et deux ordres','Contraste texte >=4.5, y compris actions désactivées','Champs, sélecteurs, erreurs et confirmations dans les fenêtres latérales','Contrats mobiles/tactiles et défilement contenu'],'limits':['Fixtures CSS/XML, aucun rendu visuel ou mesure réelle de navigateur']}
(base.ROOT/'.runtime/forms-theme-tests.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
