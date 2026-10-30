"""Paquet d'installation vierge : structure métier et dictionnaire partagé, sans clients."""
import json
import subprocess
from pathlib import Path
from django.core.management.base import BaseCommand,CommandError
from django.db import transaction
from apps.core import db
from apps.core.maintenance import pg_tool,pg_environment,digest_file

SCHEMAS=['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','systeme']


def common_dictionary_seed():
    """Exporter les identifiants communs, sans copier les données d'entreprise.

    Les doublons hérités sont conservés au chargement initial seulement. Les
    deux gardes des nouvelles identités sont réactivées dans la transaction de
    l'installateur ; les autres contraintes et triggers restent en service.
    """
    tables=[('referentiel','T_CategorieGenerique','ID_CategorieGenerique','"IdEntiteFk" IS NULL'),
            ('referentiel','T_Generique','ID_Generique','"IdEntiteFk" IS NULL')]
    commands=["-- Dictionnaire commun uniquement ; installation dans des tables vides.\n",
              "DO $$ BEGIN IF EXISTS(SELECT FROM referentiel.\"T_CategorieGenerique\") OR EXISTS(SELECT FROM referentiel.\"T_Generique\") THEN RAISE EXCEPTION 'Dictionnaire non vide : chargement initial refusé';END IF;END $$;\n",
              'ALTER TABLE referentiel."T_CategorieGenerique" DISABLE TRIGGER ab_categorie_portee_doublon;\n',
              'ALTER TABLE referentiel."T_Generique" DISABLE TRIGGER ab_generique_portee_doublon;\n']
    counts={}
    for schema,table,key,condition in tables:
        payload=db.one('SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY '+db.ident(key)+"),'[]'::jsonb)::text payload,count(*) n FROM "+db.qualified(schema,table)+' t WHERE '+condition)
        counts[schema+'.'+table]=payload['n']
        # jsonb est un littéral SQL, jamais un fragment exécutable. Les quotes
        # provenant des libellés sont doublées avant la sérialisation du seed.
        literal="'"+payload['payload'].replace("'","''")+"'::jsonb"
        commands.append('INSERT INTO '+db.qualified(schema,table)+' OVERRIDING SYSTEM VALUE SELECT * FROM jsonb_populate_recordset(NULL::'+db.qualified(schema,table)+','+literal+');\n')
        commands.append("SELECT pg_catalog.setval(pg_get_serial_sequence('"+db.qualified(schema,table)+"','"+key+"'),coalesce((SELECT max("+db.ident(key)+') FROM '+db.qualified(schema,table)+'),1),EXISTS(SELECT FROM '+db.qualified(schema,table)+'));\n')
    commands.extend(['ALTER TABLE referentiel."T_Generique" ENABLE TRIGGER ab_generique_portee_doublon;\n',
                     'ALTER TABLE referentiel."T_CategorieGenerique" ENABLE TRIGGER ab_categorie_portee_doublon;\n'])
    return ''.join(commands),counts


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
            scoped=bool(db.one("SELECT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='referentiel' AND table_name='T_Generique' AND column_name='IdEntiteFk') active")['active'])
            dictionary_tables=[] if scoped else ['--table=referentiel."T_CategorieGenerique"','--table=referentiel."T_Generique"']
            result=subprocess.run([*base,'--data-only',*dictionary_tables,'--table=referentiel."T_InterfaceTableau"','--table=systeme."T_ModuleApplication"','--file',str(refs)],env=pg_environment(),capture_output=True,timeout=180)
            if result.returncode:raise CommandError('Export dictionnaire refusé.')
            common_counts={}
            if scoped:
                seed,common_counts=common_dictionary_seed()
                with refs.open('ab') as output:output.write(('\n'+seed).encode('utf8'))
            # Le catalogue physique est une métadonnée fermée. Ses révisions,
            # dates et auteurs décrivent en revanche l'activité de la source :
            # ne jamais les recopier vers une autre installation.
            field_catalogue=[]
            if db.one("SELECT to_regclass('referentiel.\"T_ChampReferentiel\"') relation")['relation']:
                field_catalogue=db.query("SELECT format('INSERT INTO referentiel.\"T_ChampReferentiel\"(\"ID_ChampReferentiel\",\"SchemaName\",\"TableName\",\"ColumnName\",\"ChampLabel\",\"ModuleName\",\"ID_CategorieDefautFk\",\"AliasSourceKeys\",\"CanConfigure\",\"SupportsEntityScope\") OVERRIDING SYSTEM VALUE VALUES(%%L,%%L,%%L,%%L,%%L,%%L,%%L,%%L,%%L,%%L);',\"ID_ChampReferentiel\",\"SchemaName\",\"TableName\",\"ColumnName\",\"ChampLabel\",\"ModuleName\",\"ID_CategorieDefautFk\",\"AliasSourceKeys\"::text,\"CanConfigure\",\"SupportsEntityScope\") command FROM referentiel.\"T_ChampReferentiel\" ORDER BY \"ID_ChampReferentiel\"")
                with refs.open('ab') as output:
                    output.write(('\n-- Catalogue physique fermé ; révisions, dates et auteurs réinitialisés localement.\n'+''.join(row['command']+'\n' for row in field_catalogue)+"SELECT pg_catalog.setval(pg_get_serial_sequence('referentiel.\"T_ChampReferentiel\"','ID_ChampReferentiel'),coalesce((SELECT max(\"ID_ChampReferentiel\") FROM referentiel.\"T_ChampReferentiel\"),1),EXISTS(SELECT FROM referentiel.\"T_ChampReferentiel\"));\n").encode('utf8'))
            # La précision est validée par le même catalogue que les articles :
            # son chargement vient donc après les familles et définitions.
            if scoped:
                payload=db.one('SELECT coalesce(jsonb_agg(to_jsonb(p)-\'ModifieLe\' ORDER BY "ID_PrecisionStock"),\'[]\'::jsonb)::text payload,count(*) n FROM logistique."T_PrecisionStock" p WHERE referentiel.fn_reference_visible(p."ID_UniteFk",NULL)')
                literal="'"+payload['payload'].replace("'","''")+"'::jsonb"
                precision='INSERT INTO logistique."T_PrecisionStock" OVERRIDING SYSTEM VALUE SELECT * FROM jsonb_populate_recordset(NULL::logistique."T_PrecisionStock",'+literal+');\n'
                precision+="SELECT pg_catalog.setval(pg_get_serial_sequence('logistique.\"T_PrecisionStock\"','ID_PrecisionStock'),coalesce((SELECT max(\"ID_PrecisionStock\") FROM logistique.\"T_PrecisionStock\"),1),EXISTS(SELECT FROM logistique.\"T_PrecisionStock\"));\n"
                with refs.open('ab') as output:output.write(('\n'+precision).encode('utf8'))
                common_counts['logistique.T_PrecisionStock']=payload['n']
            else:
                precision=subprocess.run([*base,'--data-only','--table=logistique."T_PrecisionStock"'],env=pg_environment(),capture_output=True,timeout=180)
                if precision.returncode:raise CommandError('Export précision des unités refusé.')
                with refs.open('ab') as output:output.write(b'\n'+precision.stdout)
            mappings=target/'correspondances.sql';mappings.write_bytes(closed_mapping_seed.read_bytes())
            instructions=target/'LIRE-MOI.md'
            instructions.write_text("# Installation vierge SauverNdeko\n\nCe paquet ne contient aucun compte, entreprise, bien, stock, document client ou préférence personnelle. Seuls les catégories, valeurs et précisions d’unités communes sont incluses ; les références privées des entreprises sont exclues. Les correspondances sont une initialisation fermée du code ; aucune configuration privée de la base source n’est copiée.\n\nUtiliser une base vide PostgreSQL18 et créer l’extension pg_trgm dans public. Vérifier les SHA-256 du manifeste. Appliquer avec psql -X -v ON_ERROR_STOP=1 --single-transaction pour les deux premiers fichiers, dans cet ordre :\n\n1. structure.sql\n2. references.sql\n3. correspondances.sql (porte sa propre transaction)\n\nLe chargement des références communes conserve les doublons historiques sans fusionner leurs identifiants. Deux gardes d’identité sont suspendues uniquement dans cette transaction initiale et réactivées avant sa validation ; le chargement refuse un dictionnaire non vide. Le troisième fichier initialise les correspondances globales, notamment celles du patrimoine. Ne pas le rejouer sur une configuration cliente personnalisée sans examen. Configurer ensuite le backend vers la nouvelle base, appliquer les migrations natives Django dans public et créer le premier administrateur avec la commande dédiée. Les profils, logos, licences et données de l’entreprise de destination sont à renseigner après installation. La liste migrationsInCode inventorie les fichiers livrés ; elle ne prouve pas à elle seule leur installation sur une base existante.\n",encoding='utf8')
            migrations=sorted((project/'SQL/migrations').glob('*.sql'))
            manifest={'format':2,'files':{'structure.sql':digest_file(structure),'references.sql':digest_file(refs),'correspondances.sql':digest_file(mappings),'LIRE-MOI.md':digest_file(instructions)},'installationOrder':['structure.sql','references.sql','correspondances.sql'],'dataTables':['referentiel.T_CategorieGenerique','referentiel.T_Generique','referentiel.T_InterfaceTableau','systeme.T_ModuleApplication','logistique.T_PrecisionStock'],'mappingSeed':'closed-code-defaults','constraintTriggerCommentsSupplemented':len(comments),'migrationsInCode':[{ 'name':p.name,'sha256':digest_file(p)} for p in migrations]}
            if field_catalogue:
                manifest['sanitizedDataTables']={'referentiel.T_ChampReferentiel':{'rows':len(field_catalogue),'excludedColumns':['Revision','CreeLe','ModifieLe','ModifieParUserFk'],'currentMappingsCopied':False}}
            if scoped:
                manifest['dictionaryScope']={'mode':'common-only','privateEnterpriseRowsCopied':False,'rows':common_counts,'legacyDuplicateIdsPreserved':True,'initialIdentityGuardsReenabled':True}
                manifest.setdefault('sanitizedDataTables',{})['logistique.T_PrecisionStock']={'rows':common_counts['logistique.T_PrecisionStock'],'excludedColumns':['ModifieLe'],'privateUnitPrecisionCopied':False}
            (target/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
        self.stdout.write(f'Paquet vierge préparé : {target} ; aucune donnée client ni identité de compte incluse.')
