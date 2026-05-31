"""Resolved at runtime so Docker/CI always report the installed wheel version."""

from __future__ import annotations

from importlib.metadata import PackageNotFoundError, version


def package_version() -> str:
    try:
        return version("fin-enterprise-api")
    except PackageNotFoundError:
        return "0.0.0-dev"
