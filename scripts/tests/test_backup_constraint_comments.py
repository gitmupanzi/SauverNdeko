"""Fidélité des sauvegardes, sans connexion PostgreSQL ni données réelles."""
from contextlib import nullcontext
from io import StringIO
import json
import os
from pathlib import Path
import sys
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'backend'))
from django.conf import settings
if not settings.configured:
    settings.configure(SECRET_KEY='unit-backup-only',REST_FRAMEWORK={},USE_I18N=False,
        DATABASES={'default':{'ENGINE':'django.db.backends.dummy'}})
from django.core.management.base import CommandError
from apps.core import maintenance
from apps.core.management.commands import restaurer_recette,verifier_livraison


class BackupConstraintCommentsTests(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root=Path(self.directory.name).resolve()
        self.source=self.root/'backup'
        self.source.mkdir()
        self.comments=[
            'COMMENT ON CONSTRAINT "contrainte étrange" ON logistique."Facture" '
            "IS 'Exemple d''identité\r\nconservée';",
            'COMMENT ON CONSTRAINT caisse ON operations."Caisse" IS \'Journal\';',
        ]

    def package(self):
        comment_file=self.source/maintenance.CONSTRAINT_COMMENTS_FILE
        comment_file.write_bytes(maintenance.constraint_comments_text(self.comments).encode('utf8'))
        dump=self.source/'database.dump';dump.write_bytes(b'unit-dump')
        archive=self.source/'media.tar.gz';archive.write_bytes(b'unit-media')
        manifest={'format':2,'database':'fixture','method':'repeatable_read_snapshot',
            'fingerprintTimeZone':'UTC','tables':{},'mediaFiles':[],
            'databaseSha256':maintenance.digest_file(dump),
            'mediaSha256':maintenance.digest_file(archive),
            'constraintTriggerComments':{'file':maintenance.CONSTRAINT_COMMENTS_FILE,
                'sha256':maintenance.digest_file(comment_file),'count':len(self.comments)}}
        (self.source/'manifest.json').write_text(json.dumps(manifest),encoding='utf8')
        return manifest,comment_file

    def test_shared_export_uses_postgresql_quoting_and_scope(self):
        query=MagicMock(return_value=[{'command':value} for value in self.comments])
        self.assertEqual(maintenance.constraint_trigger_comments(['logistique'],query),self.comments)
        statement,params=query.call_args.args
        self.assertIn('%%I',statement)
        self.assertIn('%%L',statement)
        self.assertIn("k.contype='t'",statement)
        self.assertEqual(params,[['logistique'],['logistique']])

    def test_format_two_hashes_exact_utf8_metadata(self):
        manifest,path=self.package()
        self.assertEqual(maintenance.backup_constraint_comments(self.source,manifest),path)
        self.assertIn(b'\r\n',path.read_bytes())

    def test_empty_comment_set_still_requires_hashed_companion(self):
        self.comments=[]
        manifest,path=self.package()
        self.assertEqual(manifest['constraintTriggerComments']['count'],0)
        self.assertEqual(maintenance.backup_constraint_comments(self.source,manifest),path)

    def test_legacy_backup_does_not_claim_comment_proof(self):
        self.assertIsNone(maintenance.backup_constraint_comments(self.source,{'format':1}))

    def test_unsupported_or_boolean_format_refused(self):
        for value in (None,0,3,True,'2'):
            with self.subTest(value=value),self.assertRaises(RuntimeError):
                maintenance.backup_constraint_comments(self.source,{'format':value})

    def test_companion_missing_or_tampered_refused(self):
        manifest,path=self.package()
        path.write_bytes(b'ALTER TABLE unexpectedly_changed;')
        with self.assertRaises(RuntimeError):maintenance.backup_constraint_comments(self.source,manifest)
        path.unlink()
        with self.assertRaises(RuntimeError):maintenance.backup_constraint_comments(self.source,manifest)

    def test_invalid_metadata_or_path_refused(self):
        manifest,path=self.package()
        valid=manifest['constraintTriggerComments']
        for change in ({'file':'../constraint-comments.sql'},{'sha256':'f'*63},
                       {'count':True},{'count':-1},{'extra':1}):
            with self.subTest(change=change),self.assertRaises(RuntimeError):
                maintenance.backup_constraint_comments(self.source,
                    {**manifest,'constraintTriggerComments':{**valid,**change}})

    def test_verified_backup_includes_snapshot_companion(self):
        media=self.root/'media';media.mkdir();(media/'fixture.bin').write_bytes(b'private-unit-media')
        target=self.root/'new-backup'
        config=SimpleNamespace(ARTICLE_MEDIA_ROOT=media,DATABASES={'default':{'NAME':'fixture'}})
        before={'systeme.Fixture':{'n':2,'hash':'unit-row-hash'}}
        statements=[]
        def query(statement,params=()):
            statements.append(statement)
            if statement==maintenance.CONSTRAINT_COMMENTS_QUERY:
                return [{'command':command} for command in self.comments]
            return []
        def run(arguments,**kwargs):
            if arguments[0]=='pg_dump':
                Path(arguments[arguments.index('--file')+1]).write_bytes(b'unit-dump')
            return SimpleNamespace(returncode=0)
        with patch.object(maintenance,'settings',config),patch.object(maintenance.transaction,'atomic',return_value=nullcontext()),\
                patch.object(maintenance.db,'query',side_effect=query),patch.object(maintenance.db,'one',return_value={'value':'unit-snapshot'}),\
                patch.object(maintenance,'fingerprints',return_value=before),patch.object(maintenance,'pg_environment',return_value={}),\
                patch.object(maintenance,'pg_tool',side_effect=lambda name,directory:name),patch.object(maintenance.subprocess,'run',side_effect=run) as executed:
            path,manifest=maintenance.verified_backup(target)
        self.assertEqual(path,target)
        self.assertEqual(manifest['format'],2)
        self.assertEqual(manifest['tables'],before)
        self.assertEqual(manifest['constraintTriggerComments']['count'],2)
        self.assertEqual(maintenance.backup_constraint_comments(target,manifest),target/maintenance.CONSTRAINT_COMMENTS_FILE)
        self.assertEqual((target/maintenance.CONSTRAINT_COMMENTS_FILE).read_bytes(),
            maintenance.constraint_comments_text(self.comments).encode('utf8'))
        self.assertEqual(manifest['mediaFiles'][0]['path'],'fixture.bin')
        dump_call=executed.call_args_list[0].args[0]
        self.assertIn('unit-snapshot',dump_call)
        self.assertTrue(all(statement.startswith(('SET ','SELECT ')) for statement in statements))

    def test_restore_rejects_tampering_before_any_database_creation(self):
        manifest,path=self.package();path.write_bytes(b'changed')
        command=restaurer_recette.Command(stdout=StringIO())
        with patch.dict(os.environ,{'SAUVERNDEKO_RESTORE_TEST_DATABASE_URL':'postgresql://fixture@127.0.0.1/sauverndeko_test_unit'}),\
                patch.object(restaurer_recette.psycopg,'connect') as connect,\
                self.assertRaises(CommandError):
            command.handle(source=str(self.source),media_destination=str(self.root/'restored-media'),pg_bin=None)
        connect.assert_not_called()

    def test_delivery_diagnostic_checks_all_three_files(self):
        manifest,path=self.package()
        with patch.object(verifier_livraison,'settings',SimpleNamespace(DATABASES={'default':{'NAME':'fixture'}})):
            checks=verifier_livraison.backup_checks(self.source)
            self.assertEqual(checks[0]['etat'],'pret')
            self.assertEqual(checks[0]['mesures']['fichiersControles'],3)
            path.write_bytes(b'changed')
            self.assertEqual(verifier_livraison.backup_checks(self.source)[0]['etat'],'bloquant')

    def test_restore_replays_and_verifies_metadata_only_in_private_target(self):
        manifest,path=self.package()
        archive=self.source/'media.tar.gz'
        with tarfile.open(archive,'w:gz'):pass
        manifest['mediaSha256']=maintenance.digest_file(archive)
        (self.source/'manifest.json').write_text(json.dumps(manifest),encoding='utf8')
        control=MagicMock();control.__enter__.return_value=control
        control.execute.return_value.fetchone.return_value=None
        restored=MagicMock();restored.__enter__.return_value=restored
        restored.execute.return_value.fetchall.return_value=[(comment,) for comment in self.comments]
        output=StringIO();command=restaurer_recette.Command(stdout=output)
        with patch.dict(os.environ,{'SAUVERNDEKO_RESTORE_TEST_DATABASE_URL':'postgresql://fixture@127.0.0.1/sauverndeko_test_unit'}),\
                patch.object(restaurer_recette.psycopg,'connect',side_effect=[control,restored]),\
                patch.object(restaurer_recette,'pg_tool',side_effect=lambda name,directory:name),\
                patch.object(restaurer_recette,'pg_environment',side_effect=lambda config:{'PGDATABASE':config['NAME']}),\
                patch.object(restaurer_recette.subprocess,'run',return_value=SimpleNamespace(returncode=0)) as run:
            command.handle(source=str(self.source),media_destination=str(self.root/'restored-media'),pg_bin=None)
        self.assertEqual([call.args[0][0] for call in run.call_args_list],['pg_restore','psql'])
        self.assertTrue(all(call.kwargs['env']['PGDATABASE']=='sauverndeko_test_unit' for call in run.call_args_list))
        self.assertIn(str(path),run.call_args_list[1].args[0])
        report=json.loads(output.getvalue())
        self.assertTrue(report['constraintTriggerCommentsExact'])
        self.assertEqual(report['constraintTriggerCommentsVerified'],len(self.comments))


if __name__=='__main__':
    unittest.main(verbosity=2)
