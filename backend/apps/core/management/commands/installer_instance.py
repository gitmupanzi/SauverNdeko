"""Installation d'un paquet structurel validé vers une base strictement vide."""
import json
import subprocess
from pathlib import Path
from django.core.management import call_command
from django.core.management.base import BaseCommand,CommandError
from apps.core import db
from apps.core.maintenance import pg_tool,pg_environment,digest_file

class Command(BaseCommand):
    help='Installer un paquet structurel dans une base existante entièrement vide, puis migrer public.'
    requires_system_checks=[]
    def add_arguments(self,parser):
        parser.add_argument('--source',required=True)
        parser.add_argument('--pg-bin')
        parser.add_argument('--apply',action='store_true')
    def handle(self,*args,**options):
        source=Path(options['source']).resolve()
        try:manifest=json.loads((source/'manifest.json').read_text(encoding='utf8'))
        except (OSError,ValueError):raise CommandError('Manifeste du paquet absent ou invalide.') from None
        if not isinstance(manifest,dict) or not isinstance(manifest.get('files'),dict):raise CommandError('Paquet structurel non conforme.')
        package_format=manifest.get('format')
        if package_format==1 and set(manifest.get('files',{}))=={'structure.sql','references.sql'}:
            installation_order=['structure.sql','references.sql']
        elif package_format==2 and set(manifest.get('files',{}))=={'structure.sql','references.sql','correspondances.sql','LIRE-MOI.md'} and manifest.get('installationOrder')==['structure.sql','references.sql','correspondances.sql'] and manifest.get('mappingSeed')=='closed-code-defaults':
            installation_order=manifest['installationOrder']
        else:raise CommandError('Paquet structurel non conforme.')
        if db.one("SELECT count(*) n FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema')")['n']:raise CommandError('Base non vide : installation refusée. Utiliser le parcours de mise à jour.')
        for name,sha in manifest['files'].items():
            if not (source/name).is_file():raise CommandError('Fichier du paquet absent.')
            if digest_file(source/name)!=sha:raise CommandError('Empreinte du paquet différente.')
        if not options['apply']:
            self.stdout.write('Plan : extension pg_trgm, structure métier, dictionnaire'+(', correspondances globales fermées' if package_format==2 else '')+', migrations natives public. Aucun compte ou entreprise créé.');return
        db.ensure_writable()
        # Les chemins sont transmis à psql via argv, jamais interpolés dans du SQL.
        for name in installation_order:
            # Le seed fermé porte déjà sa transaction BEGIN/COMMIT.
            args=[pg_tool('psql',options['pg_bin']),'-X','--set=ON_ERROR_STOP=1',*(['--single-transaction'] if name!='correspondances.sql' else []),'--file',str(source/name)]
            if name=='structure.sql':
                result=subprocess.run([pg_tool('psql',options['pg_bin']),'-X','--set=ON_ERROR_STOP=1','--command','CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public'],env=pg_environment(),capture_output=True,timeout=60)
                if result.returncode:raise CommandError('Installation de pg_trgm refusée.')
            result=subprocess.run(args,env=pg_environment(),capture_output=True,timeout=180)
            if result.returncode:raise CommandError(f'Installation refusée pendant {name}. Base laissée pour diagnostic ; ne pas rejouer partiellement.')
        call_command('migrate',interactive=False,verbosity=0)
        empty={name:db.one('SELECT count(*) n FROM '+table)['n'] for name,table in {'users':'systeme."T_Utilisateurs"','entities':'systeme."T_Entite"','articles':'logistique."T_Article"','orders':'logistique."T_Commande"','movements':'logistique."T_Mouvement"'}.items()}
        for name,table in {'immobilisations':'logistique."T_Immobilisation"','preferences':'referentiel."T_PreferenceTableau"'}.items():
            if db.one('SELECT to_regclass(%s) relation',[table])['relation']:empty[name]=db.one('SELECT count(*) n FROM '+table)['n']
        if any(empty.values()):raise CommandError('Une table client n’est pas vide après installation.')
        self.stdout.write(json.dumps({'installed':True,'emptyBusinessTables':empty,'modules':db.one('SELECT count(*) n FROM systeme."T_ModuleApplication"')['n']}))
