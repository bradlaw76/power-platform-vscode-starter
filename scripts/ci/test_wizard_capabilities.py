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
    def probe(self, modules, version="0.2.1"):
        package = ModuleType("demo_builder")
        package.__path__ = []
        modules = {"demo_builder": package, **modules}
        with patch.dict(sys.modules, modules), patch.object(
            capabilities.importlib.metadata, "version", return_value=version
        ), patch.object(capabilities.importlib.util, "find_spec", return_value=SimpleNamespace(origin="demo_builder/__init__.py")):
            return capabilities.probe()

    def functional(self, version="1.0"):
        module = ModuleType("demo_builder.functional")
        module.COVERAGE_VERSION = version
        module.load_requirements_coverage = lambda path, *, task_ids=None: {}
        return module

    def test_legacy_package_remains_available_without_new_api(self):
        result = self.probe({})
        self.assertTrue(result["available"])
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


if __name__ == "__main__":
    unittest.main()
