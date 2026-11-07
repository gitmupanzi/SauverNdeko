"""Restauration contrôlée d'une sauvegarde vers une base privée neuve."""
import json
import os
import re
import subprocess
import tarfile
from pathlib import Path
from urllib.parse import urlsplit,unquote
import psycopg
from psycopg import sql
from django.core.management.base import BaseCommand,CommandError
from apps.core.maintenance import (digest_file,pg_tool,pg_environment,
    backup_constraint_comments,constraint_trigger_comments,constraint_comments_text)

class Command(BaseCommand):
    help='Restaurer et contrôler DB et médias dans une base locale sauverndeko_test_* neuve ; jamais la base applicative.'
    def add_arguments(self,parser):
        parser.add_argument('--source',required=True)
        parser.add_argument('--media-destination',required=True)
        parser.add_argument('--pg-bin')
    def handle(self,*args,**options):
        raw=os.environ.get('SAUVERNDEKO_RESTORE_TEST_DATABASE_URL','');u=urlsplit(raw)
        name=unquote(u.path.lstrip('/'))
        if u.scheme not in ('postgres','postgresql') or u.hostname not in ('localhost','127.0.0.1') or not re.fullmatch(r'sauverndeko_test_[a-z0-9_]{1,45}',name):raise CommandError('Définir une destination locale dédiée sauverndeko_test_* ; aucune base de secours.')
        source=Path(options['source']).resolve()
        try:
            manifest=json.loads((source/'manifest.json').read_text(encoding='utf8'))
            if not isinstance(manifest,dict):raise ValueError()
            comment_file=backup_constraint_comments(source,manifest)
        except (OSError,ValueError,RuntimeError):
            raise CommandError('Manifeste ou complément de sauvegarde invalide.') from None
        dump=source/'database.dump';archive=source/'media.tar.gz';media=Path(options['media_destination']).resolve()
        if media.exists():raise CommandError('Le répertoire média de destination doit être nouveau.')
        if digest_file(dump)!=manifest['databaseSha256'] or digest_file(archive)!=manifest['mediaSha256']:raise CommandError('Empreinte de sauvegarde incorrecte.')
        cfg={'HOST':u.hostname,'PORT':u.port or 5432,'USER':unquote(u.username or ''),'PASSWORD':unquote(u.password or ''),'NAME':name}
        conn_args={'host':cfg['HOST'],'port':cfg['PORT'],'user':cfg['USER'],'password':cfg['PASSWORD']}
        with psycopg.connect(dbname='postgres',autocommit=True,**conn_args) as control:
            if control.execute('SELECT 1 FROM pg_database WHERE datname=%s',[name]).fetchone():raise CommandError('La base de destination existe déjà ; aucune suppression automatique.')
            control.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
        result=subprocess.run([pg_tool('pg_restore',options['pg_bin']),'--no-owner','--no-acl','--exit-on-error','--single-transaction','--dbname',name,str(dump)],env=pg_environment(cfg),capture_output=True,timeout=240)
        if result.returncode:raise CommandError('Restauration SQL refusée ; la base isolée est conservée pour diagnostic.')
        if comment_file is not None:
            result=subprocess.run([pg_tool('psql',options['pg_bin']),'-X','--set=ON_ERROR_STOP=1',
                '--single-transaction','--file',str(comment_file)],env=pg_environment(cfg),capture_output=True,timeout=60)
            if result.returncode:raise CommandError('Restauration des commentaires refusée ; la base isolée est conservée pour diagnostic.')
        actual={}
        with psycopg.connect(dbname=name,**conn_args) as restored:
            restored.execute("SET LOCAL TIME ZONE 'UTC'")
            if comment_file is not None:
                comments=constraint_trigger_comments(query=lambda query,params:[
                    {'command':row[0]} for row in restored.execute(query,params).fetchall()])
                expected=constraint_comments_text(comments)
                if (len(comments)!=manifest['constraintTriggerComments']['count']
                        or comment_file.read_bytes().decode('utf8')!=expected):
                    raise CommandError('Les commentaires de contraintes restaurés diffèrent de la sauvegarde.')
            for key in manifest['tables']:
                schema,table=key.split('.',1)
                n,h=restored.execute(sql.SQL("SELECT count(*),md5(COALESCE(string_agg(h,'' ORDER BY h),'')) FROM (SELECT md5(to_jsonb(t)::text) h FROM {}.{} t) q").format(sql.Identifier(schema),sql.Identifier(table))).fetchone()
                actual[key]={'n':n,'hash':h}
        if actual!=manifest['tables']:raise CommandError('Les empreintes des tables restaurées diffèrent de la sauvegarde.')
        with tarfile.open(archive,'r:gz') as tar:
            for member in tar.getmembers():
                target=(media/member.name).resolve()
                if not target.is_relative_to(media) or not member.isfile():raise CommandError('Archive média non conforme.')
            media.mkdir(parents=True)
            tar.extractall(media,filter='data')
        for file in manifest['mediaFiles']:
            target=media/file['path']
            if not target.is_file() or target.stat().st_size!=file['size'] or digest_file(target)!=file['sha256']:raise CommandError('Média restauré manquant ou différent.')
        report={'database':name,'tablesVerified':len(actual),'mediaVerified':len(manifest['mediaFiles']),'databaseExact':True,'mediaExact':True,
            'constraintTriggerCommentsVerified':manifest['constraintTriggerComments']['count'] if comment_file is not None else None,
            'constraintTriggerCommentsExact':comment_file is not None}
        (media.parent/(media.name+'-restoration.json')).write_text(json.dumps(report,indent=2),encoding='utf8')
        self.stdout.write(json.dumps(report))
