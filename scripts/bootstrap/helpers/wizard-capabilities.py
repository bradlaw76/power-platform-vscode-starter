"""Component: runtime capability probe, v1.0.
Architecture: selected interpreter metadata and installed API inspection.
Security: no credentials, network, installer, worker or native execution.
"""
import importlib.metadata
import importlib.util
import inspect
import json
import pathlib
import sys
import argparse
import ast


def probe() -> dict:
    result = {"available": False, "version": None, "origin": None, "coverage": False, "windowsSupervision": False, "platform": sys.platform}
    try:
        result["version"] = importlib.metadata.version("power-platform-demo-builder")
        spec = importlib.util.find_spec("demo_builder")
        result["origin"] = str(pathlib.Path(spec.origin).resolve()) if spec and spec.origin else None
        result["available"] = result["version"] == "0.2.1" and bool(result["origin"])
        try:
            from demo_builder import windows_process
            result["windowsSupervision"] = (
                windows_process.WINDOWS_SUPERVISION_VERSION == "1.0"
                and callable(windows_process.OwnedJob) and callable(windows_process.identity_alive)
            )
        except (ImportError, AttributeError):
            pass
        from demo_builder import functional

        signature = inspect.signature(functional.load_requirements_coverage)
        result["coverage"] = (
            functional.COVERAGE_VERSION == "1.0"
            and "path" in signature.parameters and "task_ids" in signature.parameters
        )
    except (ImportError, AttributeError, ValueError, importlib.metadata.PackageNotFoundError) as exc:
        result["reason"] = type(exc).__name__
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", action="append", default=[])
    parser.add_argument("--runtime", action="store_true")
    args = parser.parse_args()
    value = probe() if args.runtime else {"available": False, "status": "not-requested"}
    value["sourceErrors"] = []
    for name in args.source:
        path = pathlib.Path(name)
        try:
            ast.parse(path.read_text(encoding="utf-8-sig"), filename=path.name)
        except (OSError, SyntaxError) as exc:
            value["sourceErrors"].append(f"{path.name}: {type(exc).__name__}")
    print(json.dumps(value))
    sys.exit(0)
