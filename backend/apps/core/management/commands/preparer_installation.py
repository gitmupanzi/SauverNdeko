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
        project=Path(__file__).resolve().parents[5]
        closed_mapping_seed=project/'SQL/1. Schema systeme/Systeme_FK_Correspondance_Seed_Defaults.sql'
        if not closed_mapping_seed.is_file():raise CommandError('Initialisation fermée des correspondances indisponible.')
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
            # pg_dump omet les commentaires des contraintes associées à des
            # constraint triggers. Conserver ces métadonnées, sans données.
            comments=db.query("SELECT format('COMMENT ON CONSTRAINT %%I ON %%I.%%I IS %%L;',k.conname,n.nspname,c.relname,obj_description(k.oid,'pg_constraint')) AS command FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=ANY(%s) AND k.contype='t' AND obj_description(k.oid,'pg_constraint') IS NOT NULL ORDER BY n.nspname,c.relname,k.conname",[SCHEMAS])
            if comments:
                with structure.open('ab') as output:output.write(('\n'+''.join(row['command']+'\n' for row in comments)).encode('utf8'))
            result=subprocess.run([*base,'--data-only','--table=referentiel."T_CategorieGenerique"','--table=referentiel."T_Generique"','--table=referentiel."T_InterfaceTableau"','--table=systeme."T_ModuleApplication"','--table=logistique."T_PrecisionStock"','--file',str(refs)],env=pg_environment(),capture_output=True,timeout=180)
            if result.returncode:raise CommandError('Export dictionnaire refusé.')
            mappings=target/'correspondances.sql';mappings.write_bytes(closed_mapping_seed.read_bytes())
            instructions=target/'LIRE-MOI.md'
            instructions.write_text("# Installation vierge SauverNdeko\n\nCe paquet ne contient aucun compte, entreprise, bien, stock, document client ou préférence personnelle. Les correspondances sont une initialisation fermée du code ; aucune configuration privée de la base source n’est copiée.\n\nUtiliser une base vide PostgreSQL18 et créer l’extension pg_trgm dans public. Vérifier les SHA-256 du manifeste. Appliquer avec psql -X -v ON_ERROR_STOP=1, dans cet ordre :\n\n1. structure.sql\n2. references.sql\n3. correspondances.sql\n\nLe troisième fichier initialise les correspondances globales, notamment celles du patrimoine. Ne pas le rejouer sur une configuration cliente personnalisée sans examen. Configurer ensuite le backend vers la nouvelle base, appliquer les migrations natives Django dans public et créer le premier administrateur avec la commande dédiée. Les profils, logos, licences et données de l’entreprise de destination sont à renseigner après installation. La liste migrationsInCode inventorie les fichiers livrés ; elle ne prouve pas à elle seule leur installation sur une base existante.\n",encoding='utf8')
            migrations=sorted((project/'SQL/migrations').glob('*.sql'))
            manifest={'format':2,'files':{'structure.sql':digest_file(structure),'references.sql':digest_file(refs),'correspondances.sql':digest_file(mappings),'LIRE-MOI.md':digest_file(instructions)},'installationOrder':['structure.sql','references.sql','correspondances.sql'],'dataTables':['referentiel.T_CategorieGenerique','referentiel.T_Generique','referentiel.T_InterfaceTableau','systeme.T_ModuleApplication','logistique.T_PrecisionStock'],'mappingSeed':'closed-code-defaults','constraintTriggerCommentsSupplemented':len(comments),'migrationsInCode':[{ 'name':p.name,'sha256':digest_file(p)} for p in migrations]}
            (target/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
        self.stdout.write(f'Paquet vierge préparé : {target} ; aucune donnée client ni identité de compte incluse.')
