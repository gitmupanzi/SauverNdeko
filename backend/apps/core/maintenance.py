"""Sauvegardes privées vérifiées pour les opérations de maintenance."""
import hashlib
import json
import os
import shutil
import subprocess
import tarfile
from pathlib import Path
from django.conf import settings
from django.db import connection, transaction
from . import db


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
        manifest={'format':1,'database':settings.DATABASES['default']['NAME'],'databaseSha256':digest_file(dump),'mediaSha256':digest_file(archive),'tables':before,'mediaFiles':files,'fingerprintTimeZone':'UTC','method':'repeatable_read_snapshot','restored':False}
        (target/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2,default=str),encoding='utf8')
    return target,manifest
