#!/usr/bin/env python3
#
# Port dependency manager tests
#
# Copyright 2025 Phoenix Systems
# Author: Adam Greloch
#

import pytest
import os

import io
from contextlib import redirect_stdout

import tempfile

from port_manager import DependencyManager, LogLevel, logger


PREFIX_BUILD = "normal_port_install_dir"
PREFIX_BUILD_VERSIONED = "versioned_port_install_dir"
PREFIX_PORTS = "ports"


class Utils:
    @staticmethod
    def discover_port(pm: DependencyManager, port, depends=None, optional=None,
                      conflicts=None, def_dir=None, db=None):
        args = ["", "--discover-port", port]
        if depends:
            args += ["--add-depends"] + depends
        if optional:
            args += ["--add-optional"] + optional
        if conflicts:
            args += ["--add-conflicts"] + conflicts
        if db:
            args += ["--db", db]
        args += ["--def-dir", f"ports/{port}"]
        pm.run(args)

    @staticmethod
    def resolve_dep(pm: DependencyManager, port, dep_name,
                    optional=False, db=None):
        args = ["", "--resolve-dep", port, dep_name]
        if optional:
            args += ["--optional"]
        if db:
            args += ["--db", db]

        f = io.StringIO()
        with redirect_stdout(f):
            pm.run(args)
        return f.getvalue().splitlines()

    @staticmethod
    def list_deps_to_install(pm: DependencyManager, port):
        args = ["", "--list-deps-to-install", port]
        f = io.StringIO()
        with redirect_stdout(f):
            pm.run(args)
        return f.getvalue().splitlines()

    @staticmethod
    def mark_as_installed(pm: DependencyManager, port):
        args = ["", "--mark-as-installed", port]
        pm.run(args)

    @staticmethod
    def is_installed(pm: DependencyManager, port):
        args = ["", "--is-installed", port]
        pm.run(args)

    @staticmethod
    def get_install_path(pm: DependencyManager, port):
        args = ["", "--get-install-path", port]
        f = io.StringIO()
        with redirect_stdout(f):
            pm.run(args)
        return f.getvalue().splitlines()


@pytest.fixture(scope="session")
def fix():
    os.environ["PREFIX_BUILD"] = PREFIX_BUILD
    os.environ["PREFIX_BUILD_VERSIONED"] = PREFIX_BUILD_VERSIONED
    logger.set_level(LogLevel.DEBUG if os.getenv(
        "V", "0") == "1" else LogLevel.NONE)
    yield


def test_args_bad(fix):
    pm = DependencyManager()
    pytest.raises(SystemExit, Utils.discover_port, pm,
                  port="foo-1.2.3", depends=["bar-1.1.1"])
    pytest.raises(SystemExit, Utils.discover_port, pm,
                  port="foo-1.2.3", depends=["bar>>1.1.1"])
    pytest.raises(SystemExit, Utils.discover_port, pm,
                  port="foo>=1.2.3", depends=["bar>=1.1.1"])


def test_database_simple(fix):
    with tempfile.TemporaryDirectory() as dirname:
        db_path = os.path.join(dirname, 'db.json')
        port1 = "foo-1.9.3"
        port2 = "bar-2.0.0"
        pm = DependencyManager()
        Utils.discover_port(pm, port=port1, depends=["bar>=1.1.1"],
                            db=db_path)
        Utils.discover_port(pm, port=port2, db=db_path)

        pm = DependencyManager()
        with pytest.raises(SystemExit) as ex:
            Utils.resolve_dep(
                pm, port=port1, dep_name="bar")
        assert ex.value.args[0] != 0

        pm = DependencyManager()
        assert [PREFIX_BUILD] == Utils.resolve_dep(
            pm, port=port1, dep_name="bar", db=db_path)


def test_database_malformed(fix):
    with tempfile.TemporaryDirectory() as dirname:
        bad_db_path = os.path.join(dirname, 'bad_db.json')
        with open(bad_db_path, "w+") as f:
            f.write("??????")
        with pytest.raises(SystemExit) as ex:
            pm = DependencyManager()
            Utils.discover_port(pm, port="foo-1.1.1", db=bad_db_path)
        assert ex.value.args[0] != 0


def test_port_discovery_simple(fix):
    pm = DependencyManager()
    Utils.discover_port(pm, port="foo-1.2.3", depends=["bar>=1.1.1"])
    Utils.discover_port(pm, port="bar-2.0.0")


def test_port_discovery_depends_optional(fix):
    pm = DependencyManager()
    Utils.discover_port(pm, port="foo-1.2.3", depends=["bar>=1.1.1"],
                        optional=["baz>=3.2.1"])
    Utils.discover_port(pm, port="bar-2.0.0")
    Utils.discover_port(pm, port="baz-3.2.1")


def test_port_discovery_conflicts(fix):
    pm = DependencyManager()
    Utils.discover_port(pm, port="foo-1.2.3", conflicts=["foo3*"])


def test_conflicts_itself(fix):
    pm = DependencyManager()
    pytest.raises(SystemExit, Utils.discover_port, pm, port="foo-1.2.3",
                  conflicts=["foo*"])


def test_resolution_simple(fix):
    pm = DependencyManager()
    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"
    Utils.discover_port(pm, port=port1, depends=["bar>=1.1.1"])
    Utils.discover_port(pm, port=port2)
    assert [PREFIX_BUILD] == Utils.resolve_dep(
        pm, port=port1, dep_name="bar")


def test_resolution_conflicting(fix):
    pm = DependencyManager()
    port1 = "foo-1.0.2"
    port1_depends = ["bar>=1.1.1"]
    port2 = "bar-2.0.0"
    Utils.discover_port(pm, port=port1,
                        depends=port1_depends)
    Utils.discover_port(pm, port=port2, conflicts=["wooo"])
    assert [os.path.join(PREFIX_BUILD_VERSIONED, port2)] == Utils.resolve_dep(
        pm, port=port1, dep_name="bar")


def test_resolution_optional(fix):
    pm = DependencyManager()
    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"
    Utils.discover_port(pm, port=port1, optional=["bar>=1.1.1"])

    with pytest.raises(SystemExit) as ex:
        Utils.resolve_dep(pm, port=port1, dep_name="bar")
    assert ex.value.args[0] != 0

    with pytest.raises(SystemExit) as ex:
        Utils.resolve_dep(pm, port=port1, dep_name="bar", optional=True)
    assert ex.value.args[0] != 0

    Utils.discover_port(pm, port=port2)

    with pytest.raises(SystemExit) as ex:
        Utils.resolve_dep(pm, port=port1, dep_name="bar")
    assert ex.value.args[0] != 0

    assert [PREFIX_BUILD] == Utils.resolve_dep(
        pm, port=port1, dep_name="bar", optional=True)


def test_resolution_unsatisfiable(fix):
    port1 = "foo-1.5.8"
    port2 = "bar-2.0.1"

    pm = DependencyManager()
    Utils.discover_port(pm, port=port1,
                        depends=["bar=2.0.0"])
    # no port2 discovery at all
    with pytest.raises(SystemExit) as ex:
        Utils.resolve_dep(pm, port=port1, dep_name="bar")
    assert ex.value.args[0] != 0

    port1_unsatisfiable_bar_deps = [
        "bar>=3.1.1", "bar<2.0.1", "bar<=2.0.0", "bar>2.0.1", "bar>=2.0.2",
        "bar=2.0.10"]

    for bar_dep in port1_unsatisfiable_bar_deps:
        pm = DependencyManager()
        Utils.discover_port(pm, port=port1,
                            depends=[bar_dep])
        Utils.discover_port(pm, port=port2)

        with pytest.raises(SystemExit) as ex:
            Utils.resolve_dep(pm, port=port1, dep_name="bar")
        assert ex.value.args[0] != 0


def test_install_simple(fix):
    pm = DependencyManager()
    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"

    Utils.discover_port(pm, port=port1, depends=["bar>=1.1.1"])
    Utils.discover_port(pm, port=port2)

    assert [] == Utils.list_deps_to_install(pm, port2)
    assert [os.path.join(PREFIX_PORTS, port2)
            ] == Utils.list_deps_to_install(pm, port1)

    with pytest.raises(SystemExit) as ex:
        Utils.is_installed(pm, port2)
    assert ex.value.args[0] != 0

    Utils.mark_as_installed(pm, port=port2)

    with pytest.raises(SystemExit) as ex:
        Utils.is_installed(pm, port2)
    assert ex.value.args[0] == 0

    assert [] == Utils.list_deps_to_install(pm, port1)


def test_install_unsatisfiable(fix):
    pm = DependencyManager()
    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"

    Utils.discover_port(pm, port=port1, depends=["bar>=3.1.1"])
    Utils.discover_port(pm, port=port2)

    with pytest.raises(SystemExit) as ex:
        Utils.list_deps_to_install(pm, port1)
    assert ex.value.args[0] != SystemExit(0)

    Utils.mark_as_installed(pm, port=port2)

    with pytest.raises(SystemExit) as ex:
        Utils.list_deps_to_install(pm, port1)
    assert ex.value.args[0] != SystemExit(0)


def test_install_path(fix):
    pm = DependencyManager()
    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"
    port3 = "baz-1.2.3"

    Utils.discover_port(pm, port=port1)
    Utils.discover_port(pm, port=port2)

    assert [PREFIX_BUILD] == Utils.get_install_path(pm, port1)
    assert [PREFIX_BUILD] == Utils.get_install_path(pm, port2)

    Utils.discover_port(pm, port=port3, conflicts=["bazng"])
    assert [os.path.join(PREFIX_BUILD_VERSIONED, port3)
            ] == Utils.get_install_path(pm, port3)


def test_install_bad_env(fix):
    del os.environ["PREFIX_BUILD"]
    del os.environ["PREFIX_BUILD_VERSIONED"]

    pm = DependencyManager()

    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"

    Utils.discover_port(pm, port=port1)
    with pytest.raises(SystemExit) as ex:
        Utils.get_install_path(pm, port1)
    assert ex.value.args[0] != 0

    Utils.discover_port(pm, port=port2, conflicts=["cafe"])
    with pytest.raises(SystemExit) as ex:
        Utils.get_install_path(pm, port2)
    assert ex.value.args[0] != 0

    os.environ["PREFIX_BUILD"] = PREFIX_BUILD
    os.environ["PREFIX_BUILD_VERSIONED"] = PREFIX_BUILD_VERSIONED
