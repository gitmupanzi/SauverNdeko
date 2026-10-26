"""Provisionnement explicite d'une entreprise et d'une licence tous modules."""
import json
from django.core.management.base import BaseCommand,CommandError
from django.db import transaction
from apps.accounts.authentication import actor_by_id
from apps.core import db
from apps.core.application_licences import catalogue_rows,save_license_modules
from apps.core.maintenance import verified_backup
from apps.core.repository import mutate,audit


class Command(BaseCommand):
    help='Créer une entreprise et une licence tous modules, sans compte utilisateur ni données métier.'
    def add_arguments(self,parser):
        parser.add_argument('--nom',required=True)
        parser.add_argument('--actor',required=True,type=int)
        parser.add_argument('--ans',type=int,default=5)
        parser.add_argument('--email',default='')
        parser.add_argument('--backup-dir',required=True)
        parser.add_argument('--pg-bin')
        parser.add_argument('--apply',action='store_true')
    def handle(self,*args,**options):
        actor=actor_by_id(options['actor'])
        if not actor.global_admin:raise CommandError('Administrateur de plateforme requis.')
        name=options['nom'].strip()
        if not name or len(name)>150 or not 1<=options['ans']<=10:raise CommandError('Nom ou durée invalide.')
        previous=db.one('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData"->>\'name\'=%s ORDER BY "ChangedAt" DESC LIMIT 1',['PROVISION_ENTITY',name])
        if previous:
            self.stdout.write(json.dumps({'replayed':True,**previous['NewData']},ensure_ascii=False,default=str));return
        if db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE lower(trim("NomEntite"))=lower(%s)',[name]):raise CommandError('Cette entreprise existe déjà ; sa licence doit être administrée explicitement.')
        if not options['apply']:
            self.stdout.write(json.dumps({'preview':True,'name':name,'years':options['ans'],'modules':[r['CodeModule'] for r in catalogue_rows()]},ensure_ascii=False));return
        db.ensure_writable()
        backup,_=verified_backup(options['backup_dir'],options['pg_bin'])
        with transaction.atomic():
            db.one('SELECT pg_advisory_xact_lock(hashtext(%s))',['sauverndeko:provision:'+name.casefold()])
            if db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE lower(trim("NomEntite"))=lower(%s)',[name]):raise CommandError('Création concurrente détectée ; relancer la commande.')
            statuses=db.query('SELECT g."ID_Generique" FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE lower(c."NomCategorieGenerique")=%s AND lower(g."NomGenerique") IN (%s,%s) AND g."ValideGenerique"',['statut licence','active','actif'])
            if len(statuses)!=1:raise CommandError('Statut de licence active ambigu ou manquant dans le référentiel.')
            stamp=db.one("SELECT LOCALTIMESTAMP AS start,LOCALTIMESTAMP+make_interval(years=>%s) AS finish",[options['ans']])
            entity=mutate('T_Entite',actor,{'NomEntite':name,'EmailEntite':options['email'],'DateCreationEntite':stamp['start'].isoformat(),'ValideEntite':True})
            licence=mutate('T_Licence',actor,{'IdEntiteFk':entity['IdEntite'],'DateDebut':stamp['start'].isoformat(),'DateFin':stamp['finish'].isoformat(),'IdStatutLicenceFk':statuses[0]['ID_Generique'],'ValideLicence':True})
            codes=[r['CodeModule'] for r in catalogue_rows() if not r['EstSocle']]
            result=save_license_modules(actor,licence['IdLicence'],{'enabled':codes,'versions':{code:0 for code in codes}})
            available=db.query('SELECT "CodeModule" FROM systeme."V_EntiteModuleActif" WHERE "IdEntiteFk"=%s ORDER BY "CodeModule"',[entity['IdEntite']])
            expected={r['CodeModule'] for r in catalogue_rows() if r['Actif']}
            if {r['CodeModule'] for r in available}!=expected:raise CommandError('Les modules de la licence ne sont pas tous actifs.')
            summary={'name':name,'entityId':entity['IdEntite'],'licenceId':licence['IdLicence'],'startsAt':stamp['start'].isoformat(),'expiresAt':stamp['finish'].isoformat(),'modules':sorted(expected)}
            audit({'schema':'systeme','name':'T_Entite'},'PROVISION_ENTITY',new=summary,actor=actor)
        self.stdout.write(json.dumps({'replayed':False,**summary,'backup':str(backup)},ensure_ascii=False))
