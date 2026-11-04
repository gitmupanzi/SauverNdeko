"""Contrats Render sans compte cloud, secret réel, réseau ou écriture PostgreSQL."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / "deploy/render"
sys.path.insert(0, str(DIRECTORY))


def load(name):
    spec = importlib.util.spec_from_file_location("render_" + name, DIRECTORY / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


environment = load("environment")
predeploy = load("predeploy")
release = load("release")
serve = load("serve")


def release_environment():
    return {
        "GITHUB_REF": "refs/heads/main", "GITHUB_SHA": "a" * 40,
        "CONFIRM_MAINTENANCE": "true", "BACKUP_REFERENCE": "backup-verifie-20261104",
        "MAINTENANCE_DATABASE_URL": "postgresql://owner:fixture-only@database.invalid/db",
        "RENDER_DEPLOY_HOOK_URL": "https://api.render.com/deploy/srv-fixture?key=fixture-only",
    }


class RenderEnvironmentTests(unittest.TestCase):
    def test_render_defaults_and_private_backend(self):
        values = environment.configure({"RENDER_EXTERNAL_HOSTNAME": "sauverndeko.onrender.com"})
        self.assertEqual(values["DJANGO_ALLOWED_HOSTS"], "sauverndeko.onrender.com")
        self.assertEqual(values["SAUVERNDEKO_FRONTEND_URL"], "https://sauverndeko.onrender.com")
        self.assertEqual(values["PORT"], "10000")
        self.assertEqual(values["SAUVERNDEKO_WSGI_LISTEN"], "127.0.0.1:5000")
        self.assertEqual(values["SAUVERNDEKO_TRUSTED_PROXY"], "127.0.0.1")
        self.assertEqual(values["SAUVERNDEKO_MEDIA_ROOT"], "/var/data/media")

    def test_custom_domain_is_preserved(self):
        values = environment.configure({"DJANGO_ALLOWED_HOSTS": "erp.example.org",
            "SAUVERNDEKO_FRONTEND_URL": "https://erp.example.org", "PORT": "12000"})
        self.assertEqual(values["SAUVERNDEKO_FRONTEND_URL"], "https://erp.example.org")
        self.assertEqual(values["PORT"], "12000")

    def test_invalid_hosts_and_origins_are_refused(self):
        for host in ("*", "example.org/path", "example.org:8000", "a..example.org", ".example.org"):
            with self.subTest(host=host), self.assertRaises(RuntimeError):
                environment.configure({"RENDER_EXTERNAL_HOSTNAME": host})
        for url in ("http://erp.example.org", "https://erp.example.org/subpath",
                    "https://user:pass@erp.example.org", "https://erp.example.org?q=1"):
            with self.subTest(url=url), self.assertRaises(RuntimeError):
                environment.configure({"DJANGO_ALLOWED_HOSTS": "erp.example.org", "SAUVERNDEKO_FRONTEND_URL": url})

    def test_maintenance_secrets_are_refused_on_web(self):
        for key in ("MAINTENANCE_DATABASE_URL", "SAUVERNDEKO_MIGRATION_DATABASE_URL",
                    "SAUVERNDEKO_MAINTENANCE_DATABASE_URL"):
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                environment.configure({"RENDER_EXTERNAL_HOSTNAME": "test.onrender.com", key: "fixture"})

    def test_private_listener_cannot_be_overridden(self):
        values = environment.configure({"RENDER_EXTERNAL_HOSTNAME": "test.onrender.com",
            "SAUVERNDEKO_WSGI_LISTEN": "0.0.0.0:5000", "SAUVERNDEKO_TRUSTED_PROXY": "*"})
        self.assertEqual(values["SAUVERNDEKO_WSGI_LISTEN"], "127.0.0.1:5000")
        self.assertEqual(values["SAUVERNDEKO_TRUSTED_PROXY"], "127.0.0.1")

    def test_invalid_ports_refused(self):
        for port in ("80", "5000", "65536", "oops"):
            with self.subTest(port=port), self.assertRaises(RuntimeError):
                environment.configure({"RENDER_EXTERNAL_HOSTNAME": "test.onrender.com", "PORT": port})


class RenderPredeployTests(unittest.TestCase):
    @patch.object(predeploy.subprocess, "run")
    def test_checks_do_not_apply_migrations(self, run):
        run.return_value.returncode = 0
        with patch.dict(os.environ, {"RENDER_EXTERNAL_HOSTNAME": "test.onrender.com"}, clear=True):
            self.assertEqual(predeploy.main(), 0)
        arguments = [call.args[0] for call in run.call_args_list]
        self.assertEqual(len(arguments), 4)
        self.assertTrue(arguments[0][-1].endswith("runtime_role.py"))
        self.assertEqual(arguments[2][-2:], ["migrer_metier", "--check"])
        self.assertEqual(arguments[3][-2:], ["migrate", "--check"])
        self.assertTrue(all("--apply" not in args for args in arguments))
        self.assertTrue(all(call.kwargs["env"]["SAUVERNDEKO_DB_READ_ONLY"] == "1" for call in run.call_args_list))

    @patch.object(predeploy.subprocess, "run")
    def test_failed_check_blocks_following_steps(self, run):
        run.side_effect = [MagicMock(returncode=0), MagicMock(returncode=1)]
        with patch.dict(os.environ, {"RENDER_EXTERNAL_HOSTNAME": "test.onrender.com"}, clear=True):
            self.assertEqual(predeploy.main(), 1)
        self.assertEqual(run.call_count, 2)


class RenderReleaseTests(unittest.TestCase):
    def test_exact_commit_replaces_existing_hook_ref(self):
        url = release.deploy_url("https://api.render.com/deploy/srv-fixture?key=fixture-only&ref=old", "b" * 40)
        self.assertIn("ref=" + "b" * 40, url)
        self.assertNotIn("ref=old", url)

    def test_hook_is_restricted_to_render_https(self):
        for url in ("http://api.render.com/deploy/srv?key=x", "https://evil.invalid/deploy/srv?key=x",
                    "https://api.render.com/other?key=x", "https://user:pass@api.render.com/deploy/srv?key=x",
                    "https://api.render.com/deploy/srv"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                release.deploy_url(url, "a" * 40)

    def test_confirmation_backup_and_main_are_required(self):
        self.assertEqual(release.validate_release(release_environment()), "a" * 40)
        for key, value in (("CONFIRM_MAINTENANCE", "false"), ("BACKUP_REFERENCE", ""),
                           ("GITHUB_REF", "refs/heads/test"), ("GITHUB_SHA", "latest"),
                           ("MAINTENANCE_DATABASE_URL", ""), ("RENDER_DEPLOY_HOOK_URL", "")):
            values = release_environment()
            values[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                release.validate_release(values)

    @patch.object(release.subprocess, "run")
    def test_grants_pass_credentials_only_through_environment(self, run):
        run.return_value.returncode = 0
        with patch.dict(os.environ, {**release_environment(), "SAUVERNDEKO_DB_SSLMODE": "verify-full"}, clear=True):
            release.refresh_runtime_grants()
        arguments = run.call_args.args[0]
        self.assertEqual(arguments[:3], ["psql", "-X", "--set=ON_ERROR_STOP=1"])
        self.assertNotIn("fixture-only", " ".join(arguments))
        self.assertEqual(run.call_args.kwargs["env"]["PGSSLMODE"], "verify-full")
        self.assertEqual(run.call_args.kwargs["env"]["PGPASSWORD"], "fixture-only")

    @patch.object(release.subprocess, "run")
    def test_failed_grants_are_not_accepted(self, run):
        run.return_value.returncode = 1
        with patch.dict(os.environ, release_environment(), clear=True), self.assertRaises(RuntimeError):
            release.refresh_runtime_grants()


class RenderLifecycleTests(unittest.TestCase):
    def test_children_are_stopped_and_overdue_child_is_killed(self):
        first, second = MagicMock(), MagicMock()
        first.poll.return_value = None
        second.poll.return_value = None
        second.wait.side_effect = [subprocess.TimeoutExpired("fixture", 1), 0]
        serve.stop([first, second])
        first.terminate.assert_called_once()
        second.terminate.assert_called_once()
        second.kill.assert_called_once()

    def test_blueprint_and_docker_preserve_separation(self):
        blueprint = (ROOT / "render.yaml").read_text(encoding="utf8")
        self.assertIn("autoDeployTrigger: off", blueprint)
        self.assertIn("preDeployCommand: python deploy/render/predeploy.py", blueprint)
        self.assertIn("mountPath: /var/data", blueprint)
        self.assertNotIn("MAINTENANCE_DATABASE_URL", blueprint)
        docker = (DIRECTORY / "Dockerfile").read_text(encoding="utf8")
        self.assertNotIn("migrer_metier", docker)
        self.assertNotIn("manage.py migrate", docker)
        self.assertIn('CMD ["python", "deploy/render/serve.py"]', docker)
        self.assertIn("skills/document-mise-en-forme/assets/charte_sauverndeko.json", docker)
        self.assertIn("caddy validate --config /app/deploy/render/Caddyfile --adapter caddyfile", docker)
        caddy = (DIRECTORY / "Caddyfile").read_text(encoding="utf8")
        self.assertIn("reverse_proxy 127.0.0.1:5000", caddy)
        self.assertIn("trusted_proxies static private_ranges", caddy)
        self.assertIn("client_ip_headers CF-Connecting-IP", caddy)
        self.assertIn("header_up X-Forwarded-For {client_ip}", caddy)
        self.assertNotIn("{http.request.header.X-Forwarded-For}", caddy)
        self.assertIn("/django-admin /django-admin/* /health /health/", caddy)
        self.assertIn("handle @privateFiles", caddy)
        self.assertNotIn("/var/data/media", caddy)
        role = (DIRECTORY / "runtime_role.py").read_text(encoding="utf8")
        self.assertIn('systeme."T_MigrationSchema"', role)
        self.assertIn("INSERT,UPDATE,DELETE,TRUNCATE", role)
        self.assertIn("has_any_column_privilege", role)
        workflow = (ROOT / ".github/workflows/livraison-render.yml").read_text(encoding="utf8")
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("pull_request", workflow)
        self.assertNotIn("push:", workflow)
        self.assertIn("needs: maintenance", workflow)
        self.assertIn("python backend/manage.py migrer_metier --apply", workflow)
        self.assertIn("cancel-in-progress: false", workflow)

    def test_all_backend_root_routes_are_proxied(self):
        import ast
        tree = ast.parse((ROOT / "backend/config/urls.py").read_text(encoding="utf8"))
        prefixes = {
            node.args[0].value.removeprefix("^").split("/")[0].removesuffix("?$")
            for node in ast.walk(tree)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
            and node.func.id == "re_path" and node.args
            and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str)
        }
        matcher = next(line for line in (DIRECTORY / "Caddyfile").read_text(encoding="utf8").splitlines()
                       if line.strip().startswith("@backend path "))
        paths = matcher.strip().split()[2:]
        for prefix in prefixes:
            with self.subTest(prefix=prefix):
                self.assertIn("/" + prefix, paths)


if __name__ == "__main__":
    unittest.main()
