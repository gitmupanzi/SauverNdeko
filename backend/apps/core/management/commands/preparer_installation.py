"""Paquet d'installation vierge : structure métier et dictionnaire partagé, sans clients."""
import json
import subprocess
from pathlib import Path
from django.core.management.base import BaseCommand,CommandError
from django.db import transaction
from apps.core import db
from apps.core.maintenance import pg_tool,pg_environment,digest_file

SCHEMAS=['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','systeme']

class Command(BaseCommand):
    help='Exporter un socle neuf sans utilisateurs, entreprises ni mouvements ; la liste de données est fermée au dictionnaire et aux modules.'
    def add_arguments(self,parser):
        parser.add_argument('--destination',required=True)
        parser.add_argument('--pg-bin')
    def handle(self,*args,**options):
        target=Path(options['destination']).resolve()
        if target.exists():raise CommandError('Le dossier de destination doit être nouveau.')
        target.mkdir(parents=True)
        with transaction.atomic():
            db.query('SET LOCAL statement_timeout=120000')
            for row in db.query("SELECT schemaname,tablename FROM pg_tables WHERE schemaname=ANY(%s) ORDER BY schemaname,tablename",[SCHEMAS]):db.query('LOCK TABLE '+db.qualified(row['schemaname'],row['tablename'])+' IN SHARE MODE')
            base=[pg_tool('pg_dump',options['pg_bin']),'--no-owner','--no-acl']
            structure=target/'structure.sql';refs=target/'references.sql'
            result=subprocess.run([*base,'--schema-only',*[f'--schema={schema}' for schema in SCHEMAS],'--file',str(structure)],env=pg_environment(),capture_output=True,timeout=180)
            if result.returncode:raise CommandError('Export structure refusé.')
            result=subprocess.run([*base,'--data-only','--table=referentiel."T_CategorieGenerique"','--table=referentiel."T_Generique"','--table=systeme."T_ModuleApplication"','--file',str(refs)],env=pg_environment(),capture_output=True,timeout=180)
            if result.returncode:raise CommandError('Export dictionnaire refusé.')
            migrations=sorted((Path(__file__).resolve().parents[5]/'SQL/migrations').glob('*.sql'))
            manifest={'format':1,'files':{'structure.sql':digest_file(structure),'references.sql':digest_file(refs)},'dataTables':['referentiel.T_CategorieGenerique','referentiel.T_Generique','systeme.T_ModuleApplication'],'migrationsInCode':[{ 'name':p.name,'sha256':digest_file(p)} for p in migrations]}
            (target/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
        self.stdout.write(f'Paquet vierge préparé : {target} ; aucune donnée client ni identité de compte incluse.')
