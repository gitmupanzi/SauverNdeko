"""Diagnostic de livraison, sans écriture SQL ni réseau sortant."""
import hashlib
import importlib.util
import json
import math
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import DatabaseError, connection, transaction
from apps.core import db

READY, CONFIG, BLOCKED, UNVERIFIED = 'pret', 'a_configurer', 'bloquant', 'non_verifie'
STATES = {READY:'Prêt', CONFIG:'À configurer', BLOCKED:'Bloquant', UNVERIFIED:'Non vérifié'}
SCHEMAS = ['logistique','referentiel','systeme','geolocalisation','professionnel','analytics','communication','public']
VIEWS = [('logistique',n) for n in ('V_Article','V_Commande','V_CommandeDetail','V_AuditStock','V_LotDisponibilite','V_RegistreLots','V_RegistreMouvementLot','V_ValorisationStock','V_ArticlePeremption','V_SuiviReglements','V_Reglements')]
VIEWS += [('systeme','V_LicenceModule'),('systeme','V_EntiteModuleActif')]


def finding(code, label, state, observation, action='', metrics=None, *, external=False):
    if state not in STATES:
        raise ValueError('État de diagnostic inconnu.')
    return {'code':code,'libelle':label,'etat':state,'constat':observation,
            'action':action,'mesures':metrics or {},'externe':external}


def sql_guard(execute, sql, params, many, context):
    text = sql.strip()
    allowed = bool(text.split()) and text.split()[0].upper() in {'SELECT','WITH','SHOW'}
    allowed = allowed or text.upper().startswith(('SAVEPOINT ','RELEASE SAVEPOINT ','ROLLBACK TO SAVEPOINT '))
    allowed = allowed or text in {'SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY', "SET LOCAL statement_timeout='15s'"}
    if not allowed:
        raise CommandError('Instruction refusée pendant le diagnostic en lecture seule.')
    return execute(sql, params, many, context)


def scoped(entity, field='IdEntiteFk', alias='v'):
    return (alias+'.'+db.ident(field)+'=%s',[entity]) if entity is not None else ('TRUE',[])


def database_checks(entity=None, production=False):
    checks = []
    def add(*args, **kwargs):
        checks.append(finding(*args, **kwargs))

    # Protection de cette transaction même si le service autorise ses écritures habituelles.
    with transaction.atomic(), connection.execute_wrapper(sql_guard):
        db.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
        db.query("SET LOCAL statement_timeout='15s'")
        readonly = db.one('SHOW transaction_read_only')['transaction_read_only']=='on'
        add('diagnostic_read_only','Protection du diagnostic',READY if readonly else BLOCKED,
            'La transaction PostgreSQL est protégée en lecture seule.' if readonly else 'La transaction n’est pas protégée.',
            metrics={'lectureSeule':readonly})

        def probe(code, label, fn):
            try:
                with transaction.atomic():
                    fn()
            except DatabaseError as error:
                state = getattr(getattr(error,'__cause__',None),'sqlstate',None)
                add(code,label,BLOCKED,'Le contrôle SQL n’a pas pu aboutir.',
                    'Vérifier les migrations, droits de lecture et délais PostgreSQL, puis relancer.',
                    {'sqlState':state or 'indisponible'})

        missing = [schema+'.'+name for schema,name in VIEWS
                   if not db.one('SELECT to_regclass(%s) IS NOT NULL AS present',[schema+'.'+db.ident(name)])['present']]
        add('socle_vues','Vues métier communes',BLOCKED if missing else READY,
            'Des vues requises sont absentes.' if missing else 'Les vues requises sont présentes ; ceci ne certifie pas le contenu de toutes les migrations.',
            'Installer uniquement les migrations manquantes après sauvegarde.' if missing else '',
            {'vuesAttendues':len(VIEWS),'vuesAbsentes':missing})

        def role():
            row = db.one('''SELECT r.rolsuper AS superuser,r.rolcreatedb AS createdb,
             r.rolcreaterole AS createrole,r.rolreplication AS replication,r.rolbypassrls AS bypassrls,
             EXISTS(SELECT 1 FROM pg_roles sr WHERE sr.rolname=session_user AND (sr.rolsuper OR sr.rolcreatedb OR sr.rolcreaterole OR sr.rolreplication OR sr.rolbypassrls)) AS session_privileged,
             EXISTS(SELECT 1 FROM pg_roles ar WHERE ar.oid<>r.oid AND (ar.rolsuper OR ar.rolcreatedb OR ar.rolcreaterole OR ar.rolreplication OR ar.rolbypassrls) AND pg_has_role(ar.oid,'MEMBER')) AS privileged_membership,
             EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=ANY(%s) AND p.proowner=r.oid) AS function_owner,
             EXISTS(SELECT 1 FROM pg_database d WHERE d.datname=current_database() AND d.datdba=r.oid) AS database_owner,
             EXISTS(SELECT 1 FROM pg_namespace n WHERE n.nspname=ANY(%s) AND n.nspowner=r.oid) AS schema_owner,
             EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=ANY(%s) AND c.relowner=r.oid) AS object_owner,
             has_database_privilege(current_database(),'CREATE') AS database_create,
             has_database_privilege(current_database(),'TEMP') AS temporary_create,
             EXISTS(SELECT 1 FROM pg_namespace n WHERE n.nspname=ANY(%s) AND has_schema_privilege(n.oid,'CREATE')) AS schema_create
             FROM pg_roles r WHERE r.rolname=current_user''',[SCHEMAS,SCHEMAS,SCHEMAS,SCHEMAS])
            excessive = any(row.values())
            add('role_runtime','Compte SQL du service',BLOCKED if excessive and production else CONFIG if excessive else READY,
                'Le compte courant possède des privilèges de maintenance.' if excessive else 'Le compte courant ne possède pas les privilèges administratifs ou de création contrôlés.',
                'Utiliser deploy/production/role-runtime.sql avec un compte de maintenance séparé.' if excessive else 'La recette test_role_runtime.py couvre les DML autorisés et interdits.',
                {'privilegesExcessifs':{k:bool(v) for k,v in row.items()}})
        probe('role_runtime','Compte SQL du service',role)

        def triggers():
            row = db.one('''SELECT
             (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
              WHERE n.nspname='logistique' AND NOT t.tgisinternal AND t.tgenabled NOT IN ('O','A')) AS inactifs,
             (SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
              WHERE n.nspname='logistique' AND NOT c.convalidated) AS contraintes_non_validees''')
            bad = bool(row['inactifs'] or row['contraintes_non_validees'])
            add('integrite_sql','Contrôles de stock SQL',BLOCKED if bad else READY,
                'Des contrôles SQL sont désactivés ou non validés.' if bad else 'Aucun trigger métier logistique inactif ni contrainte non validée détecté.',
                'Examiner et rétablir les contrôles avant livraison.' if bad else '',row)
        probe('integrite_sql','Contrôles de stock SQL',triggers)
        def tls_session():
            row=db.one('SELECT COALESCE((SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()),false) AS chiffree')
            add('session_tls_postgresql','Chiffrement de la session PostgreSQL',READY if row['chiffree'] else BLOCKED if production else UNVERIFIED,
                'La connexion de ce diagnostic est chiffrée.' if row['chiffree'] else 'La connexion de ce diagnostic ne présente pas de session TLS.',
                'Vérifier le certificat CA et la connexion chiffrée du serveur cible.' if not row['chiffree'] else '',row)
        probe('session_tls_postgresql','Chiffrement de la session PostgreSQL',tls_session)

        if not missing:
            def entities():
                where,values = scoped(entity,'IdEntite')
                row = db.one('''SELECT count(*) AS entreprises,count(*) FILTER(WHERE "ValideEntite" IS TRUE) AS actives,
                 count(*) FILTER(WHERE "ValideEntite" IS TRUE AND
                 (NULLIF(btrim("NomEntite"),'') IS NULL OR NULLIF(btrim("AdresseEntite"),'') IS NULL OR
                 (NULLIF(btrim("PhoneEntite"),'') IS NULL AND NULLIF(btrim("EmailEntite"),'') IS NULL))) AS identites_incompletes
                 FROM systeme."T_Entite" v WHERE '''+where,values)
                state = BLOCKED if entity is not None and row['actives']==0 else CONFIG if row['actives']==0 or row['identites_incompletes'] else READY
                add('identite_entreprise','Identité documentaire des entreprises',state,
                    'Contrôle du nom, de l’adresse et d’un contact des entreprises actives, sans exposer leurs coordonnées.',
                    'Ouvrir Logistique > Identité de l’entreprise et compléter les informations réelles ; ne pas inventer de coordonnées.' if state!=READY else '',row)
                where,values = scoped(entity,'IdEntite','e')
                row = db.one('''SELECT count(*) AS entreprises_actives,
                 count(*) FILTER(WHERE EXISTS(SELECT 1 FROM systeme."V_EntiteModuleActif" m
                  WHERE m."IdEntiteFk"=e."IdEntite" AND m."CodeModule"='logistique')) AS acces_logistique,
                 count(*) FILTER(WHERE NOT EXISTS(SELECT 1 FROM systeme."V_EntiteModuleActif" m
                  WHERE m."IdEntiteFk"=e."IdEntite" AND m."CodeModule"='logistique') AND
                  (EXISTS(SELECT 1 FROM logistique."T_Article" a WHERE a."IdEntiteFk"=e."IdEntite") OR
                   EXISTS(SELECT 1 FROM logistique."T_Commande" c WHERE c."IdEntiteFk"=e."IdEntite"))) AS donnees_sans_licence
                 FROM systeme."T_Entite" e WHERE e."ValideEntite" IS TRUE AND '''+where,values)
                bad = row['donnees_sans_licence']>0 or row['acces_logistique']==0
                add('licence_logistique','Accès de licence Logistique',CONFIG if bad else READY,
                    'Les accès viennent de V_EntiteModuleActif ; tous les modules ne sont pas requis pour chaque entreprise.',
                    'Vérifier abonnement, dates, statut et modules dans Licences et applications.' if bad else '',row)
                where,values = scoped(entity)
                row = db.one('SELECT count(DISTINCT "IdLicenceFk") AS licences_actives,count(*) AS modules_actifs FROM systeme."V_LicenceModule" v WHERE "EstAccesActif" IS TRUE AND '+where,values)
                add('licences_modules','Modules de licence actifs',READY,'Comptage des licences et modules actifs, sans lister les entreprises ni utilisateurs.',metrics=row)
            probe('entreprises_licences','Entreprises et licences',entities)

            def ownership():
                counts = {name:db.one('SELECT count(*) AS n FROM logistique.'+db.ident(name)+' WHERE "IdEntiteFk" IS NULL')['n'] for name in ('V_Article','V_Commande')}
                add('proprietaire_documents','Propriétaire des documents',BLOCKED if any(counts.values()) else READY,
                    'Comptage global des articles et bons sans entreprise propriétaire durable.',
                    'Rapprocher ces documents avec leur entreprise réelle.' if any(counts.values()) else '',counts)
                row = db.one('''SELECT count(*) FILTER(WHERE "Is_Admin" IS TRUE AND "ValideUser" IS TRUE) AS administrateurs_globaux,
                 count(*) FILTER(WHERE "Is_Admin" IS NOT TRUE AND "ValideUser" IS TRUE AND "IdEntiteFk" IS NULL) AS utilisateurs_sans_entreprise
                 FROM systeme."T_Utilisateurs"''')
                add('comptes_entreprises','Rattachement des comptes',BLOCKED if not row['administrateurs_globaux'] else CONFIG if row['utilisateurs_sans_entreprise'] else READY,
                    'Les administrateurs globaux gardent leur accès transversal.',
                    'Conserver un administrateur global actif et rattacher les autres comptes actifs à leur entreprise.',row)
            probe('proprietaire_documents','Propriétaire des documents',ownership)

            def stocks():
                where,values = scoped(entity)
                row = db.one('SELECT count(*) AS articles,count(*) FILTER(WHERE "Ecart"<>0) AS ecarts FROM logistique."V_AuditStock" v WHERE '+where,values)
                add('audit_stock','Rapprochement des stocks',BLOCKED if row['ecarts'] else READY,
                    'Le stock courant est comparé aux mouvements par la vue d’audit.',
                    'Examiner les écarts puis corriger par un comptage justifié.' if row['ecarts'] else '',row)
                row = db.one('''SELECT count(*) FILTER(WHERE "QteArticle"<0) AS stocks_negatifs,
                 count(*) FILTER(WHERE "StockVentileLots">"QteArticle") AS ventilations_excessives
                 FROM logistique."V_Article" v WHERE '''+where,values)
                row.update(db.one('SELECT count(*) AS lots,count(*) FILTER(WHERE "StockLot"<0) AS lots_negatifs FROM logistique."V_LotDisponibilite" v WHERE '+where,values))
                bad = any(row[k] for k in ('stocks_negatifs','ventilations_excessives','lots_negatifs'))
                add('integrite_lots','Stocks et ventilation par lot',BLOCKED if bad else READY,
                    'Les lots sont comparés au stock de leur article ; aucune quantité hétérogène n’est additionnée.',
                    'Examiner les ventilations puis corriger par les parcours métier.' if bad else '',row)
                row = db.one('''SELECT count(*) FILTER(WHERE "StockPerime">0) AS articles_perimes_en_stock,
                 count(*) FILTER(WHERE "StockProchePeremption">0) AS articles_proches_peremption,
                 count(*) FILTER(WHERE "StockSansDatePeremption">0) AS articles_sans_date
                 FROM logistique."V_ArticlePeremption" v WHERE '''+where,values)
                add('conservation_stock','Conservation des stocks',CONFIG if row['articles_perimes_en_stock'] else READY,
                    'Seul le stock restant alimente les alertes. Une date absente ne prouve pas qu’un article est périssable.',
                    'Définir le traitement des articles périmés et la politique de blocage/dérogation.' if row['articles_perimes_en_stock'] else '',row)
            probe('stock_lots','Stocks et lots',stocks)

            def valuation():
                where,values = scoped(entity)
                row = db.one('''WITH positions AS MATERIALIZED(
                 SELECT "QteValorisee","CoutUnitaireMoyen","ValeurStock" FROM logistique."V_ValorisationStock" v WHERE '''+where+''')
                 SELECT count(*) AS positions,
                 count(*) FILTER(WHERE "CoutUnitaireMoyen" IS NULL OR "ValeurStock" IS NULL) AS couts_inconnus,
                 count(*) FILTER(WHERE "QteValorisee"<>0 AND ("CoutUnitaireMoyen" IS NULL OR "ValeurStock" IS NULL)) AS stocks_cout_inconnu
                 FROM positions''',values)
                add('valorisation_cump','Valorisation CUMP',CONFIG if row['stocks_cout_inconnu'] else READY,
                    'Un coût inconnu reste inconnu ; aucun prix catalogue ou zéro ne le remplace.',
                    'Faire confirmer coûts d’ouverture et justificatifs des réceptions par le responsable habilité.' if row['stocks_cout_inconnu'] else '',row)
            probe('valorisation_cump','Valorisation CUMP',valuation)

            def mail():
                from apps.accounts.password_reset import smtp_configured
                configured = bool(smtp_configured())
                add('transport_mail','Configuration du transport e-mail',READY if configured else CONFIG,
                    'Le contrat SMTP et d’expéditeur est complet.' if configured else 'Le transport ou l’expéditeur est incomplet.',
                    'Vérifier les variables privées SAUVERNDEKO_EMAIL_* et l’expéditeur administratif ; aucun secret dans le rapport.' if not configured else '',
                    {'configurationPresente':configured,'connexionTestee':False,'messageEnvoye':False})
            probe('transport_mail','Configuration du transport e-mail',mail)
    return checks


def runtime_checks(production=False):
    rows = []
    def add(*args, **kwargs):
        rows.append(finding(*args, **kwargs))
    def config(code, label, valid, observation, action):
        add(code,label,READY if valid else BLOCKED if production else CONFIG,observation,action if not valid else '')

    config('debug','Mode débogage',not settings.DEBUG,'Le paramètre Django DEBUG est contrôlé.',
           'Désactiver DJANGO_DEBUG dans le profil cible.')
    config('profil_production','Profil de production',getattr(settings,'SETTINGS_MODULE','')=='config.production',
           'Le profil actif est contrôlé ; Vite/runserver ne servent pas les clients en production.',
           'Utiliser config.production et le service WSGI derrière le frontal HTTPS.')
    try:
        origin = urlsplit(getattr(settings,'PASSWORD_RESET_FRONTEND_URL',''))
        origin.port
    except (ValueError,TypeError):
        origin = urlsplit('')
    hosts = settings.ALLOWED_HOSTS
    exact = bool(hosts) and not any('*' in h for h in hosts) and not any(h in {'localhost','127.0.0.1','::1','testserver'} for h in hosts)
    exact = exact and origin.scheme=='https' and origin.hostname in hosts and not origin.username and not origin.password
    exact = exact and not origin.query and not origin.fragment and origin.path in ('','/')
    config('origine_https','Origine et hôtes HTTPS',exact,
           'Les hôtes autorisés et l’origine HTTPS sont contrôlés sans les afficher.',
           'Définir les hôtes exacts et SAUVERNDEKO_FRONTEND_URL avec l’origine HTTPS réelle.')
    secure = bool(settings.SECURE_SSL_REDIRECT and settings.SESSION_COOKIE_SECURE and settings.CSRF_COOKIE_SECURE and getattr(settings,'SECURE_HSTS_SECONDS',0)>0)
    config('protection_https','Protection HTTPS Django',secure,'Redirection HTTPS, cookies sécurisés et HSTS sont contrôlés.',
           'Utiliser le profil production et le proxy de confiance, puis vérifier le frontal.')
    secrets = [getattr(settings,key,'') for key in ('SECRET_KEY','JWT_SECRET','JWT_REFRESH_SECRET')]
    strong = all(isinstance(v,str) for v in secrets) and len(secrets[0])>=50 and all(len(v)>=32 for v in secrets[1:]) and len(set(secrets))==3
    config('secrets_distincts','Secrets de service',strong,
           'Seuls présence, longueur minimale et caractère distinct sont vérifiés ; aucune valeur ni empreinte n’est exposée.',
           'Fournir des secrets aléatoires longs et distincts dans la configuration privée.')
    config('mots_de_passe_herites','Ancien mode de mot de passe',not settings.LEGACY_PLAINTEXT_PASSWORDS,
           'Le mode d’acceptation des anciens mots de passe en clair doit être désactivé.',
           'Désactiver SAUVERNDEKO_ALLOW_LEGACY_PLAINTEXT_PASSWORDS.')
    tls = settings.DATABASES['default'].get('OPTIONS',{}).get('sslmode')
    config('tls_postgresql','TLS PostgreSQL configuré',tls in {'verify-full','verify-ca'},
           'Le mode de vérification TLS est contrôlé, sans afficher la connexion.',
           'Configurer SAUVERNDEKO_DB_SSLMODE=verify-full et le certificat CA sur le serveur cible.')
    add('ecritures_application','Mode applicatif',CONFIG if settings.DB_READ_ONLY else READY,
        'Les écritures applicatives sont désactivées.' if settings.DB_READ_ONLY else 'Les écritures sont soumises aux droits existants ; ce diagnostic reste en lecture seule.',
        'Ouvrir les écritures uniquement après validation de la recette et des droits.' if settings.DB_READ_ONLY else '',
        {'ecrituresAutorisees':not settings.DB_READ_ONLY})
    available = importlib.util.find_spec('waitress') is not None
    config('runtime_wsgi','Runtime WSGI disponible',available,
           'Le paquet Waitress est disponible.' if available else 'Le paquet Waitress est absent.',
           'Installer le requirements.txt unique dans l’environnement du serveur.')
    root = Path(settings.ARTICLE_MEDIA_ROOT).resolve()
    project = Path(settings.BASE_DIR).parent
    public = [project/'frontend'/'public',project/'frontend'/'dist',Path(settings.STATIC_ROOT)]
    private = not any(root==p.resolve() or root.is_relative_to(p.resolve()) for p in public)
    config('stockage_media','Stockage privé des médias',private,
           'Le stockage configuré est distinct des répertoires statiques publics.',
           'Utiliser un volume privé persistant, hors frontend/public, frontend/dist et STATIC_ROOT.')
    for code,label,action in [
        ('https_externe','Accès HTTPS externe','Vérifier DNS, certificat réel, frontal et accès depuis un autre poste.'),
        ('mail_delivrance','Délivrance des e-mails','Effectuer ultérieurement un test explicitement autorisé ; ce diagnostic n’envoie rien.'),
        ('plan_sauvegarde','Planification et rétention des sauvegardes','Vérifier la tâche planifiée, la rétention, le chiffrement et une copie hors du serveur.'),
        ('medias_exploitation','Persistance et droits des médias','Vérifier le volume, ses droits et le téléversement sans publier le répertoire.')]:
        add(code,label,UNVERIFIED,'Ce contrôle externe n’est pas exécuté par la commande.',action,external=True)
    return rows


def backup_checks(directory=None, max_age_hours=72):
    if directory is None:
        return [finding('sauvegarde','Sauvegarde explicite',UNVERIFIED,
            'Aucun dossier de sauvegarde n’a été fourni.',
            'Relancer avec --backup-dir vers un dossier produit par sauvegarder_instance ; aucune recherche automatique.',external=True)]
    base = Path(directory)
    try:
        if base.is_symlink() or getattr(base,'is_junction',lambda:False)() or not base.is_dir():
            raise ValueError()
        base = base.resolve()
        manifest_path = base/'manifest.json'
        for name in ('manifest.json','database.dump','media.tar.gz'):
            target = base/name
            if target.is_symlink() or getattr(target,'is_junction',lambda:False)() or target.resolve().parent!=base or not target.is_file():
                raise ValueError()
        if manifest_path.stat().st_size>8*1024*1024:
            raise ValueError()
        data = json.loads(manifest_path.read_text(encoding='utf8'))
        if (not isinstance(data,dict) or type(data.get('format')) is not int or data['format']!=1
            or data.get('database')!=settings.DATABASES['default']['NAME']
            or data.get('method')!='repeatable_read_snapshot' or data.get('fingerprintTimeZone')!='UTC'
            or not isinstance(data.get('tables'),dict) or not isinstance(data.get('mediaFiles'),list)):
            raise ValueError()

        def matches(name, key):
            expected = data.get(key)
            if not isinstance(expected,str) or not re.fullmatch('[a-f0-9]{64}',expected):
                return False
            path = base/name
            before = path.stat()
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                for chunk in iter(lambda:stream.read(1024*1024),b''):
                    digest.update(chunk)
            after = path.stat()
            return before.st_size==after.st_size and before.st_mtime_ns==after.st_mtime_ns and digest.hexdigest()==expected

        valid = matches('database.dump','databaseSha256') and matches('media.tar.gz','mediaSha256')
        age = (datetime.now(timezone.utc).timestamp()-manifest_path.stat().st_mtime)/3600
        if not math.isfinite(age) or age<(-5/60):
            raise ValueError()
        stale = age>max_age_hours
        return [
            finding('sauvegarde_empreintes','Intégrité des fichiers de sauvegarde',READY if valid else BLOCKED,
                'Les deux fichiers correspondent aux empreintes du manifeste.' if valid else 'Une empreinte ne correspond pas au manifeste.',
                'Ne pas utiliser cette sauvegarde ; en créer et vérifier une nouvelle.' if not valid else 'La correspondance des empreintes ne remplace pas une restauration.',
                {'fichiersControles':2,'tablesInventoriees':len(data['tables']),'mediasInventories':len(data['mediaFiles'])}),
            finding('sauvegarde_anciennete','Ancienneté du manifeste',CONFIG if stale else READY,
                'Ancienneté fondée sur la modification observée du manifeste ; ce n’est pas une preuve de restauration.',
                'Produire une sauvegarde fraîche avant livraison.' if stale else '',
                {'heuresDepuisModification':round(max(age,0),2),'seuilHeures':max_age_hours}),
            finding('restauration','Restauration de contrôle',UNVERIFIED,
                'Cette commande ne restaure rien et ne certifie pas une ancienne restauration.',
                'Exécuter restaurer_recette sur une base privée neuve et conserver son rapport vérifié.',external=True)]
    except (OSError,ValueError,TypeError,UnicodeError):
        return [finding('sauvegarde','Dossier de sauvegarde',BLOCKED,
            'Dossier absent, lié, non conforme, inaccessible ou manifeste d’une autre instance.',
            'Fournir le dossier privé complet produit par sauvegarder_instance ; ne pas modifier les empreintes.')]


def report(entity=None, production=False, backup_dir=None, max_backup_age_hours=72):
    if entity is not None and (type(entity) is not int or entity<=0 or entity>2147483647):
        raise CommandError('Identifiant d’entreprise invalide.')
    if type(max_backup_age_hours) not in (int,float) or not math.isfinite(max_backup_age_hours) or not 1<=max_backup_age_hours<=8760:
        raise CommandError('Le seuil de sauvegarde doit être compris entre 1 et 8760 heures.')
    try:
        checks = database_checks(entity,production)
    except DatabaseError as error:
        state=getattr(getattr(error,'__cause__',None),'sqlstate',None)
        checks=[finding('connexion_postgresql','Connexion PostgreSQL',BLOCKED,'La connexion ou l’inspection initiale est indisponible.',
            'Vérifier la disponibilité de PostgreSQL et les droits du compte, sans afficher son URL ni son mot de passe.',{'sqlState':state or 'indisponible'})]
    checks += runtime_checks(production)+backup_checks(backup_dir,max_backup_age_hours)
    counts = {state:sum(row['etat']==state for row in checks) for state in STATES}
    state = next((s for s in (BLOCKED,CONFIG,UNVERIFIED) if counts[s]),READY)
    return {'version':1,'genereLe':datetime.now(timezone.utc).isoformat(),
            'mode':'production' if production else 'preparation','entrepriseId':entity,
            'etat':state,'totaux':counts,'controleLectureSeule':any(row['code']=='diagnostic_read_only' and row['mesures'].get('lectureSeule') is True for row in checks),'connexionSmtpExecutee':False,'checks':checks,
            'portee':'Diagnostic local, pas une autorisation de production ni une certification de délivrance ou restauration.'}


class Command(BaseCommand):
    help = 'Livraison en lecture seule : entreprise, licence, stock, CUMP, runtime et sauvegarde explicite ; aucun SMTP.'

    def add_arguments(self, parser):
        parser.add_argument('--entity',type=int)
        parser.add_argument('--production',action='store_true')
        parser.add_argument('--json',action='store_true')
        parser.add_argument('--strict',action='store_true')
        parser.add_argument('--backup-dir')
        parser.add_argument('--max-backup-age-hours',type=float,default=72)

    def handle(self, *args, **options):
        value = report(options.get('entity'),options.get('production',False),options.get('backup_dir'),options.get('max_backup_age_hours',72))
        if options.get('json'):
            self.stdout.write(json.dumps(value,ensure_ascii=False,allow_nan=False))
        else:
            self.stdout.write('Préparation de livraison — '+STATES[value['etat']])
            self.stdout.write('Transaction PostgreSQL en lecture seule ; aucun SMTP ni envoi e-mail.')
            for row in value['checks']:
                self.stdout.write('['+STATES[row['etat']]+'] '+row['libelle']+' : '+row['constat'])
                if row['mesures']:
                    self.stdout.write('  Mesures : '+json.dumps(row['mesures'],ensure_ascii=False))
                if row['action']:
                    self.stdout.write('  Action : '+row['action'])
            self.stdout.write(value['portee'])
        if options.get('strict') and (value['totaux'][BLOCKED] or value['totaux'][CONFIG]):
            raise CommandError('Des contrôles bloquants ou paramètres à configurer restent à traiter.')
