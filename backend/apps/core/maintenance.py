"""Sauvegardes privées vérifiées pour les opérations de maintenance."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import tarfile
from pathlib import Path
from django.conf import settings
from django.db import connection, transaction
from . import db


CONSTRAINT_COMMENTS_FILE = 'constraint-comments.sql'
CONSTRAINT_COMMENTS_QUERY = """SELECT format(
    'COMMENT ON CONSTRAINT %%I ON %%I.%%I IS %%L;',
    k.conname,n.nspname,c.relname,obj_description(k.oid,'pg_constraint')) AS command
    FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname NOT IN ('pg_catalog','information_schema')
    AND n.nspname !~ '^pg_' AND k.contype='t'
    AND obj_description(k.oid,'pg_constraint') IS NOT NULL
    AND (%s::text[] IS NULL OR n.nspname=ANY(%s))
    ORDER BY n.nspname,c.relname,k.conname"""


def constraint_trigger_comments(schemas=None, query=None):
    """Compléter les COMMENT ON CONSTRAINT omis par pg_dump PostgreSQL 18.

    PostgreSQL cite lui-même identifiants et littéraux ; aucun commentaire
    récupéré n'est interpolé par Python dans une commande SQL.
    """
    rows=(query or db.query)(CONSTRAINT_COMMENTS_QUERY,[schemas,schemas])
    return [row['command'] for row in rows]


def constraint_comments_text(commands):
    return ('-- Métadonnées des contraintes-triggers omises par pg_dump.\n'
            +''.join(command+'\n' for command in commands))


def backup_constraint_comments(source, manifest):
    """Valider le complément avant toute création de base de restauration."""
    if type(manifest.get('format')) is not int or manifest['format'] not in {1,2}:
        raise RuntimeError('Format de sauvegarde non reconnu.')
    if manifest['format']==1:
        return None
    metadata=manifest.get('constraintTriggerComments')
    if (not isinstance(metadata,dict) or set(metadata)!={'file','sha256','count'}
            or metadata['file']!=CONSTRAINT_COMMENTS_FILE
            or not isinstance(metadata['sha256'],str)
            or not re.fullmatch('[0-9a-f]{64}',metadata['sha256'])
            or type(metadata['count']) is not int or metadata['count']<0):
        raise RuntimeError('Complément des commentaires de contraintes non conforme.')
    base=Path(source).resolve()
    path=base/CONSTRAINT_COMMENTS_FILE
    if (path.is_symlink() or getattr(path,'is_junction',lambda:False)()
            or path.resolve().parent!=base or not path.is_file()
            or digest_file(path)!=metadata['sha256']):
        raise RuntimeError('Complément des commentaires de contraintes absent ou différent.')
    return path


def pg_tool(name, directory=None):
    suffix='.exe' if os.name=='nt' else ''
    candidate=Path(directory)/f'{name}{suffix}' if directory else None
    executable=str(candidate) if candidate and candidate.is_file() else shutil.which(name)
    if not executable: raise RuntimeError(f'Outil PostgreSQL requis : {name}.')
    return executable


def pg_environment(config=None):
    values=config or settings.DATABASES['default']
    env=os.environ.copy()
    env.update(PGHOST=str(values['HOST']),PGPORT=str(values['PORT']),PGUSER=str(values['USER']),PGPASSWORD=str(values['PASSWORD']),PGDATABASE=str(values['NAME']),PGCONNECT_TIMEOUT='10',PGOPTIONS='-c statement_timeout=120000')
    for key,target in {'sslmode':'PGSSLMODE','sslrootcert':'PGSSLROOTCERT','sslcert':'PGSSLCERT','sslkey':'PGSSLKEY'}.items():
        if values.get('OPTIONS',{}).get(key):env[target]=str(values['OPTIONS'][key])
    return env


def digest_file(path):
    value=hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):value.update(chunk)
    return value.hexdigest()


def fingerprints():
    tables=db.query("SELECT schemaname,tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY schemaname,tablename")
    result={}
    for row in tables:
        name=db.qualified(row['schemaname'],row['tablename'])
        value=db.one('SELECT count(*) AS n,md5(COALESCE(string_agg(h,\'\' ORDER BY h),\'\')) AS hash FROM (SELECT md5(to_jsonb(t)::text) AS h FROM '+name+' t) q')
        result[row['schemaname']+'.'+row['tablename']]=value
    return result


def verified_backup(destination,pg_bin=None):
    """Partage un instantané SQL cohérent et protège les fichiers privés copiés."""
    target=Path(destination).resolve()
    if target.exists():raise RuntimeError('Le dossier de sauvegarde doit être nouveau.')
    media=Path(settings.ARTICLE_MEDIA_ROOT).resolve()
    if target==media or media in target.parents:raise RuntimeError('Sauvegarde interdite dans le stockage média.')
    target.mkdir(parents=True)
    dump=target/'database.dump'; archive=target/'media.tar.gz'
    with transaction.atomic():
        db.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
        db.query("SET LOCAL statement_timeout='120s'")
        db.query("SET LOCAL TIME ZONE 'UTC'")
        tables=db.query("SELECT schemaname,tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY schemaname,tablename")
        for row in tables:db.query('LOCK TABLE '+db.qualified(row['schemaname'],row['tablename'])+' IN ACCESS SHARE MODE')
        snapshot=db.one('SELECT pg_export_snapshot() AS value')['value']
        before=fingerprints()
        comments=constraint_trigger_comments()
        comment_file=target/CONSTRAINT_COMMENTS_FILE
        comment_file.write_text(constraint_comments_text(comments),encoding='utf8',newline='\n')
        result=subprocess.run([pg_tool('pg_dump',pg_bin),'--snapshot',snapshot,'--format=custom','--no-owner','--no-acl','--file',str(dump)],env=pg_environment(),capture_output=True,timeout=180)
        if result.returncode:raise RuntimeError('Échec du dump PostgreSQL ; sauvegarde non validée.')
        result=subprocess.run([pg_tool('pg_restore',pg_bin),'--list',str(dump)],capture_output=True,timeout=60)
        if result.returncode:raise RuntimeError('Catalogue de sauvegarde illisible.')
        with open(os.devnull,'wb') as null:
            result=subprocess.run([pg_tool('pg_restore',pg_bin),'--file','-',str(dump)],stdout=null,stderr=subprocess.PIPE,timeout=180)
        if result.returncode:raise RuntimeError('Décodage de sauvegarde refusé.')
        files=[]
        with tarfile.open(archive,'w:gz') as tar:
            if media.exists():
                for file in sorted(media.rglob('*')):
                    if file.is_symlink():raise RuntimeError('Un lien symbolique dans les médias exige un examen.')
                    if file.is_file():
                        relative=file.relative_to(media).as_posix();sha=digest_file(file)
                        tar.add(file,arcname=relative,recursive=False)
                        if sha!=digest_file(file):raise RuntimeError('Média modifié pendant la copie ; recommencer.')
                        files.append({'path':relative,'size':file.stat().st_size,'sha256':sha})
        after=fingerprints()
        if before!=after:raise RuntimeError('La base a changé pendant sa sauvegarde.')
        manifest={'format':2,'database':settings.DATABASES['default']['NAME'],'databaseSha256':digest_file(dump),'mediaSha256':digest_file(archive),'tables':before,'mediaFiles':files,'fingerprintTimeZone':'UTC','method':'repeatable_read_snapshot','restored':False,
            'constraintTriggerComments':{'file':CONSTRAINT_COMMENTS_FILE,'sha256':digest_file(comment_file),'count':len(comments)}}
        (target/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2,default=str),encoding='utf8')
    return target,manifest
