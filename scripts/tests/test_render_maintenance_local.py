"""Gardes de maintenance locale, sans réseau, Docker ni connexion PostgreSQL."""
import importlib.util
import os
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

DIRECTORY = Path(__file__).resolve().parents[2] / "deploy/render"
sys.path.insert(0, str(DIRECTORY))
spec = importlib.util.spec_from_file_location("maintenance_local", DIRECTORY / "maintenance_local.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

SHA = "a" * 40
DSN = "postgresql://owner:fixture-only@localhost/isolated_fixture"


def arguments(action="plan"):
    return SimpleNamespace(action=action, commit=SHA, env_file=None,
        database_host="localhost", database_name="isolated_fixture", database_port=5432,
        backup_reference="restauration-fixture-verifiee", confirm_maintenance=True)


class LocalMaintenanceTests(unittest.TestCase):
    def test_git_ignored_secret_inside_docker_context_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            path = root / "backend" / "backups" / "render-maintenance.env"
            path.parent.mkdir(parents=True)
            path.write_text("MAINTENANCE_DATABASE_URL=" + DSN, encoding="utf-8")
            with patch.object(module, "ROOT", root), patch.object(module, "git") as git, self.assertRaises(ValueError):
                module.read_values(path)
            git.assert_not_called()

    def test_private_runtime_file_is_accepted_without_interpolation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            path = root / ".runtime" / "render-maintenance.env"
            path.parent.mkdir(parents=True)
            literal = DSN.replace("fixture-only", "${DO_NOT_EXPAND}")
            path.write_text("MAINTENANCE_DATABASE_URL=" + literal, encoding="utf-8")
            with patch.object(module, "ROOT", root), patch.object(module, "git", return_value=""), \
                    patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)):
                self.assertEqual(module.read_values(path)["MAINTENANCE_DATABASE_URL"], literal)

    def test_unknown_private_keys_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.env"
            path.write_text("DATABASE_URL=" + DSN, encoding="utf-8")
            with self.assertRaises(ValueError):
                module.read_values(path)

    def test_missing_private_url_never_falls_back_to_database_url(self):
        with patch.dict(os.environ, {"DATABASE_URL": DSN}, clear=True):
            values = module.read_values(None)
            with self.assertRaises(ValueError):
                module.database_environment(values, host="localhost", name="isolated_fixture", write=False)

    def test_target_and_runtime_identity_are_checked(self):
        for values, host, name in (
            ({"MAINTENANCE_DATABASE_URL": DSN}, "other.invalid", "isolated_fixture"),
            ({"MAINTENANCE_DATABASE_URL": DSN}, "localhost", "different"),
            ({"MAINTENANCE_DATABASE_URL": DSN.replace("owner:", "sauverndeko_runtime:")}, "localhost", "isolated_fixture"),
        ):
            with self.subTest(host=host, name=name), self.assertRaises(ValueError):
                module.database_environment(values, host=host, name=name, write=False)

    def test_external_tls_cannot_be_weakened(self):
        for mode in ("disable", "require", "verify-ca"):
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                module.database_environment({"MAINTENANCE_DATABASE_URL": DSN.replace("localhost", "db.invalid"),
                    "SAUVERNDEKO_DB_SSLMODE": mode}, host="db.invalid", name="isolated_fixture", write=False)

    def test_different_port_is_not_the_same_destination(self):
        with self.assertRaises(ValueError):
            module.database_environment({"MAINTENANCE_DATABASE_URL": DSN.replace("localhost/", "localhost:5544/")},
                host="localhost", name="isolated_fixture", write=False)

    def test_external_tls_requires_existing_trusted_ca(self):
        with self.assertRaises(ValueError):
            module.database_environment({"MAINTENANCE_DATABASE_URL": DSN.replace("localhost", "db.invalid")},
                host="db.invalid", name="isolated_fixture", write=False)
        with patch.object(module.Path, "is_file", return_value=True):
            values = module.database_environment({"MAINTENANCE_DATABASE_URL": DSN.replace("localhost", "db.invalid"),
                "SAUVERNDEKO_DB_SSLROOTCERT": "fixture-ca.pem"}, host="db.invalid", name="isolated_fixture", write=False)
        self.assertEqual(values["SAUVERNDEKO_DB_READ_ONLY"], "1")
        self.assertEqual(values["DJANGO_SETTINGS_MODULE"], "config.maintenance")

    def test_build_does_not_inherit_database_or_hook(self):
        with patch.dict(os.environ, {"DATABASE_URL": DSN, "MAINTENANCE_DATABASE_URL": DSN,
                "RENDER_DEPLOY_HOOK_URL": "secret", "PGPASSWORD": "secret", "JWT_SECRET": "secret", "PATH": "fixture"}, clear=True):
            self.assertEqual(module.build_environment(), {"PATH": "fixture"})

    def test_clean_main_and_exact_remote_commit_are_required_for_apply(self):
        for answers in ((SHA, "feature"), (SHA, "main", " M tracked.py"), (SHA, "main", "", "b" * 40)):
            with self.subTest(answers=answers), patch.object(module, "git", side_effect=answers), self.assertRaises(ValueError):
                module.verify_source(SHA, clean=True)
        with patch.object(module, "git", side_effect=(SHA, "main", "", SHA)):
            module.verify_source(SHA, clean=True)

    def test_incomplete_sha_is_refused_before_git(self):
        with patch.object(module, "git") as git, self.assertRaises(ValueError):
            module.verify_source("main", clean=True)
        git.assert_not_called()

    @patch.object(module, "verify_source")
    @patch.object(module, "read_values", return_value={"MAINTENANCE_DATABASE_URL": DSN, "SAUVERNDEKO_DB_SSLMODE": "disable"})
    @patch.object(module, "run_step")
    @patch.object(module, "apply_runtime_grants")
    def test_plan_only_issues_readonly_plans(self, grants, step, values, source):
        module.execute(arguments())
        self.assertEqual(step.call_count, 2)
        for call in step.call_args_list:
            self.assertEqual(call.args[2]["SAUVERNDEKO_DB_READ_ONLY"], "1")
            self.assertNotIn("--apply", call.args[1])
        grants.assert_not_called()

    @patch.object(module, "verify_source")
    @patch.object(module, "read_values")
    @patch.object(module, "run_step")
    def test_confirmation_required_before_connection_or_build(self, step, values, source):
        for changes in ({"confirm_maintenance": False}, {"backup_reference": ""}, {"backup_reference": "abc\ninvalid"}):
            args = arguments("apply")
            for key, value in changes.items():
                setattr(args, key, value)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                module.execute(args)
        values.assert_not_called()
        step.assert_not_called()

    @patch.object(module, "verify_source")
    @patch.object(module, "read_values", return_value={"MAINTENANCE_DATABASE_URL": DSN, "SAUVERNDEKO_DB_SSLMODE": "disable"})
    @patch.object(module.shutil, "which", return_value=None)
    @patch.object(module, "run_step")
    def test_missing_docker_blocks_before_database(self, step, which, values, source):
        with self.assertRaises(ValueError):
            module.execute(arguments("apply"))
        step.assert_not_called()

    @patch.object(module, "verify_source")
    @patch.object(module, "read_values", return_value={"MAINTENANCE_DATABASE_URL": DSN, "SAUVERNDEKO_DB_SSLMODE": "disable"})
    @patch.object(module.shutil, "which", side_effect=lambda name: name)
    @patch.object(module, "run_step")
    @patch.object(module, "apply_runtime_grants")
    def test_apply_builds_then_migrates_then_verifies(self, grants, step, which, values, source):
        events = []
        step.side_effect = lambda label, args, env, **kwargs: events.append((label, args, env))
        grants.side_effect = lambda env: events.append(("grants", [], env))
        module.execute(arguments("apply"))
        labels = [event[0] for event in events]
        self.assertLess(labels.index("Construction Docker du commit"), labels.index("Migrations métier"))
        self.assertLess(labels.index("Migrations Django dans public"), labels.index("grants"))
        self.assertLess(labels.index("grants"), labels.index("Contrôle métier final"))
        apply = next(event for event in events if event[0] == "Migrations métier")
        self.assertEqual(apply[1][-3:], ["--apply", "--release", SHA])
        self.assertEqual(apply[2]["SAUVERNDEKO_DB_READ_ONLY"], "0")
        self.assertEqual(events[-1][2]["SAUVERNDEKO_DB_READ_ONLY"], "1")

    @patch.object(module.subprocess, "run")
    def test_database_failure_stops_and_redacts_password(self, run):
        run.return_value = SimpleNamespace(returncode=1, stdout="", stderr="failure " + DSN + " fixture-only")
        with patch("builtins.print") as output, self.assertRaises(RuntimeError):
            module.run_step("Plan", ["fixture"], {"MAINTENANCE_DATABASE_URL": DSN}, private=True)
        visible = " ".join(str(call) for call in output.call_args_list)
        self.assertNotIn("fixture-only", visible)
        self.assertNotIn(DSN, visible)

    def test_real_utf8_child_password_is_redacted_on_windows_too(self):
        environment = os.environ.copy()
        environment.update(PYTHONUTF8="1", MAINTENANCE_DATABASE_URL=DSN.replace("fixture-only", "test-éàç"))
        with patch("builtins.print") as output:
            module.run_step("Fixture UTF-8", [sys.executable, "-c", "print('test-éàç')"], environment, private=True)
        visible = " ".join(str(call) for call in output.call_args_list)
        self.assertNotIn("test-éàç", visible)
        self.assertNotIn("Ã", visible)
        self.assertIn("[masqué]", visible)


if __name__ == "__main__":
    unittest.main()
