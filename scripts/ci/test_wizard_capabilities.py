"""Component: capability compatibility regressions v1.0.
Architecture: installed API boundary mocks, no worker launch.
Security: synthetic unit evidence only; no installation or native ownership claim.
"""
import importlib.util
from pathlib import Path
import sys
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "wizard_capabilities", Path(__file__).resolve().parents[1] / "bootstrap" / "helpers" / "wizard-capabilities.py"
)
capabilities = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capabilities)


class Capabilities(unittest.TestCase):
    def probe(self, modules, version="0.2.1", origin="demo_builder/__init__.py"):
        package = ModuleType("demo_builder")
        package.__path__ = []
        modules = {"demo_builder": package, **modules}
        with patch.dict(sys.modules, modules), patch.object(
            capabilities.importlib.metadata, "version", return_value=version
        ), patch.object(capabilities.importlib.util, "find_spec", return_value=SimpleNamespace(origin=origin)):
            return capabilities.probe()

    def functional(self, version="1.0"):
        module = ModuleType("demo_builder.functional")
        module.COVERAGE_VERSION = version
        module.load_requirements_coverage = lambda path, *, task_ids=None: {}
        return module

    def test_legacy_package_without_required_api_is_unavailable(self):
        result = self.probe({})
        self.assertFalse(result["available"])
        self.assertFalse(result["coverage"])
        self.assertFalse(result["windowsSupervision"])

    def test_coverage_and_windows_need_real_selected_module_interfaces(self):
        windows = ModuleType("demo_builder.windows_process")
        windows.WINDOWS_SUPERVISION_VERSION = "1.0"
        windows.OwnedJob = lambda: None
        windows.identity_alive = lambda identity: False
        result = self.probe({"demo_builder.functional": self.functional(), "demo_builder.windows_process": windows})
        self.assertTrue(result["coverage"])
        self.assertTrue(result["windowsSupervision"])
        self.assertFalse(self.probe({"demo_builder.functional": self.functional("future")})["coverage"])

    def test_package_version_and_api_shape_are_not_inferred_from_source(self):
        module = self.functional()
        module.load_requirements_coverage = lambda unrelated: {}
        self.assertFalse(self.probe({"demo_builder.functional": module})["coverage"])
        self.assertFalse(self.probe({"demo_builder.functional": self.functional()}, "future")["available"])

    def test_only_explicit_versions_with_required_apis_are_available(self):
        windows = ModuleType("demo_builder.windows_process")
        windows.WINDOWS_SUPERVISION_VERSION = "1.0"
        windows.OwnedJob = lambda: None
        windows.identity_alive = lambda identity: False
        modules = {"demo_builder.functional": self.functional(), windows.__name__: windows}
        for version in ("0.2.1", "0.2.2rc1", "0.2.2rc2"):
            with self.subTest(version=version):
                self.assertTrue(self.probe(modules, version)["available"])
                self.assertFalse(self.probe(modules, version, origin=None)["available"])
                self.assertFalse(self.probe({"demo_builder.functional": self.functional("future")}, version)["available"])
        for version in ("0.2.2", "0.2.2rc3", "9.0.0"):
            with self.subTest(version=version):
                self.assertFalse(self.probe(modules, version)["available"])
        with patch.object(capabilities.sys, "platform", "win32"):
            windows.OwnedJob = None
            for version in ("0.2.1", "0.2.2rc1", "0.2.2rc2"):
                self.assertFalse(self.probe(modules, version)["available"])


if __name__ == "__main__":
    unittest.main()
