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

from resolvelib.resolvers import ResolverException, ResolutionImpossible
from port_manager import DependencyManager, LogLevel, logger


PREFIX_BUILD = "normal_port_install_dir"
PREFIX_BUILD_VERSIONED = "versioned_port_install_dir"
PREFIX_PORTS = "ports"


class Utils:
    @staticmethod
    def discover_port(
        pm: DependencyManager,
        port,
        depends=None,
        optional=None,
        conflicts=None,
        def_dir=None,
        db=None,
    ):
        args = [""]
        if db:
            args += ["--db", db]
        args += ["discover", port]
        if depends:
            args += ["--requires"] + depends
        if optional:
            args += ["--optional"] + optional
        if conflicts:
            args += ["--conflicts"] + conflicts
        args += ["--def-dir", f"ports/{port}"]
        pm.run(args)

    @staticmethod
    def resolve(pm: DependencyManager, ports, db=None):
        args = [""]
        if db:
            args += ["--db", db]
        args += ["resolve"] + ports
        f = io.StringIO()
        with redirect_stdout(f):
            pm.run(args)
        return f.getvalue().splitlines()

    @staticmethod
    def dep_install_path(pm: DependencyManager, port, dep_name, db=None):
        args = [""]
        if db:
            args += ["--db", db]
        args += ["query", "dep-install-path", port, dep_name]
        f = io.StringIO()
        with redirect_stdout(f):
            pm.run(args)
        return f.getvalue().splitlines()

    @staticmethod
    def list_deps_to_install(pm: DependencyManager, port):
        args = ["", "query", "deps-to-install", port]
        f = io.StringIO()
        with redirect_stdout(f):
            pm.run(args)
        return f.getvalue().splitlines()

    @staticmethod
    def mark_as_installed(pm: DependencyManager, port):
        args = ["", "installed", port]
        pm.run(args)

    @staticmethod
    def is_installed(pm: DependencyManager, port):
        args = ["", "query", "is-installed", port]
        pm.run(args)

    @staticmethod
    def install_path(pm: DependencyManager, port):
        args = ["", "query", "install-path", port]
        f = io.StringIO()
        with redirect_stdout(f):
            pm.run(args)
        return f.getvalue().splitlines()

    @staticmethod
    def assert_not_installed(pm: DependencyManager, port, dep_name):
        with pytest.raises(SystemExit) as ex:
            Utils.dep_install_path(pm, port, dep_name)
        assert ex.value.args[0] != 0


@pytest.fixture(scope="session")
def fix():
    os.environ["PREFIX_BUILD"] = PREFIX_BUILD
    os.environ["PREFIX_BUILD_VERSIONED"] = PREFIX_BUILD_VERSIONED
    logger.set_level(LogLevel.VERBOSE if os.getenv("V", "0") == "1" else LogLevel.NONE)
    yield


def test_args_bad(fix):
    pm = DependencyManager()
    pytest.raises(
        Exception, Utils.discover_port, pm, port="foo-1.2.3", depends=["bar-1.1.1"]
    )
    pytest.raises(
        Exception, Utils.discover_port, pm, port="foo-1.2.3", depends=["bar>>1.1.1"]
    )
    pytest.raises(
        Exception, Utils.discover_port, pm, port="foo>=1.2.3", depends=["bar>=1.1.1"]
    )


def test_database_simple(fix):
    with tempfile.TemporaryDirectory() as db_path:
        db_file = os.path.join(db_path, "ports.json")

        foo = "foo-1.9.3"
        bar = "bar-2.0.0"
        pm = DependencyManager()
        Utils.discover_port(pm, port=foo, depends=["bar>=1.1.1"], db=db_file)
        Utils.discover_port(pm, port=bar, db=db_file)

        pm = DependencyManager()
        with pytest.raises(ResolutionImpossible):
            Utils.resolve(pm, ports=[foo])

        pm = DependencyManager()
        Utils.resolve(pm, ports=[foo], db=db_file)
        assert [PREFIX_BUILD] == Utils.dep_install_path(
            pm, port=foo, dep_name="bar", db=db_file
        )


def test_port_discovery_simple(fix):
    pm = DependencyManager()
    Utils.discover_port(pm, port="foo-1.2.3", depends=["bar>=1.1.1"])
    Utils.discover_port(pm, port="bar-2.0.0")


def test_port_discovery_depends_optional(fix):
    pm = DependencyManager()
    Utils.discover_port(
        pm, port="foo-1.2.3", depends=["bar>=1.1.1"], optional=["baz>=3.2.1"]
    )
    Utils.discover_port(pm, port="bar-2.0.0")
    Utils.discover_port(pm, port="baz-3.2.1")


def test_port_discovery_conflicts(fix):
    pm = DependencyManager()
    Utils.discover_port(pm, port="foo-1.2.3", conflicts=["foo3>=0.0"])
    Utils.resolve(pm, ports=["foo-1.2.3"])


def test_conflicts_itself(fix):
    pm = DependencyManager()
    foo = "foo-1.2.3"
    Utils.discover_port(pm, foo, conflicts=["foo>=0.0"])
    pytest.raises(ResolutionImpossible, Utils.resolve, pm, ports=[foo])


def test_resolution_simple(fix):
    pm = DependencyManager()
    foo = "foo-1.9.3"
    bar = "bar-2.0.0"
    Utils.discover_port(pm, port=foo, depends=["bar>=1.1.1"])
    Utils.discover_port(pm, port=bar)
    Utils.resolve(pm, ports=[foo])
    assert [PREFIX_BUILD] == Utils.dep_install_path(pm, port=foo, dep_name="bar")


def test_resolution_conflicting_simple(fix):
    pm = DependencyManager()
    foo = "foo-1.0.2"
    bar = "bar-2.0.0"
    barng = "barng-2.1.0"
    Utils.discover_port(pm, port=foo, depends=["bar>=1.1.1"])
    Utils.discover_port(pm, port=bar, conflicts=["barng>=2.1"])
    Utils.discover_port(pm, port=barng, conflicts=["bar>=0.0"])
    Utils.resolve(pm, ports=[foo])
    assert [os.path.join(PREFIX_BUILD_VERSIONED, bar)] == Utils.dep_install_path(
        pm, port=foo, dep_name="bar"
    )


def test_resolution_conflicting_version_alternatives(fix):
    pm = DependencyManager()
    foo = "foo-1.0.2"
    Utils.discover_port(pm, port=foo, depends=["bar>=1.1.1"])

    bar = "bar-2.0.0"
    Utils.discover_port(pm, port=bar, conflicts=["barng>=0.0"])

    barng = "barng-2.2.0"
    Utils.discover_port(pm, port=barng, conflicts=["bar>=0.0"])

    foo_v3 = "foo-3.2.0"
    Utils.discover_port(pm, port=foo_v3, depends=["barng>=1.1.1"])

    Utils.resolve(pm, ports=[foo, foo_v3])
    assert [os.path.join(PREFIX_BUILD_VERSIONED, bar)] == Utils.dep_install_path(
        pm, port=foo, dep_name="bar"
    )
    Utils.assert_not_installed(pm, port=foo, dep_name="barng")


def test_resolution_conflicting_independent(fix):
    pm = DependencyManager()
    foo = "foo-1.0.2"
    Utils.discover_port(pm, port=foo, depends=["bar>=1.1.1"])

    bar = "bar-2.0.0"
    Utils.discover_port(pm, port=bar, conflicts=["barng>=0.0"])

    barng = "barng-2.2.0"
    Utils.discover_port(pm, port=barng, conflicts=["bar>=0.0"])

    baz = "baz-1.2.3"
    Utils.discover_port(pm, port=baz, depends=["barng>=1.1.1"])

    Utils.resolve(pm, ports=[foo, baz])
    assert [os.path.join(PREFIX_BUILD_VERSIONED, bar)] == Utils.dep_install_path(
        pm, port=foo, dep_name="bar"
    )
    Utils.assert_not_installed(pm, port=foo, dep_name="barng")

    assert [os.path.join(PREFIX_BUILD_VERSIONED, barng)] == Utils.dep_install_path(
        pm, port=baz, dep_name="barng"
    )
    Utils.assert_not_installed(pm, port=baz, dep_name="bar")


def test_resolution_two_conflicts_in_single_port(fix):
    pm = DependencyManager()

    foo = "foo-1.0.2"
    Utils.discover_port(pm, port=foo, depends=["bar>=1.1.1"])

    bar = "bar-2.0.0"
    Utils.discover_port(pm, port=bar, conflicts=["barng>=0.0"])

    barng = "barng-2.2.0"
    Utils.discover_port(pm, port=barng, conflicts=["bar>=0.0"])

    baz = "baz-3.2.0"
    Utils.discover_port(pm, port=baz, depends=["barng>=1.1.1"])

    faz = "faz-4.2.0"
    Utils.discover_port(pm, port=faz, depends=["baz>=1.1.1", "foo>=1.0"])

    with pytest.raises(ResolverException):
        Utils.resolve(pm, ports=[faz])


def test_detect_pending_resolution(fix):
    pm = DependencyManager()

    foo = "foo-1.9.3"
    Utils.discover_port(pm, port=foo)

    with pytest.raises(SystemExit) as ex:
        Utils.dep_install_path(pm, port=foo, dep_name="bar")
    assert ex.value.args[0] != 0


def test_resolution_optional(fix):
    pm = DependencyManager()

    foo = "foo-1.9.3"
    Utils.discover_port(pm, port=foo, optional=["bar>=1.1.1"])
    Utils.resolve(pm, ports=[foo])

    with pytest.raises(SystemExit) as ex:
        Utils.dep_install_path(pm, port=foo, dep_name="bar")
    assert ex.value.args[0] != 0

    bar = "bar-2.0.0"
    Utils.discover_port(pm, port=bar)
    Utils.resolve(pm, ports=[foo])

    assert [PREFIX_BUILD] == Utils.dep_install_path(pm, port=foo, dep_name="bar")


def test_resolution_unsatisfiable(fix):
    foo = "foo-1.5.8"
    bar = "bar-2.0.1"

    pm = DependencyManager()
    Utils.discover_port(pm, port=foo, depends=["bar==2.0.0"])

    with pytest.raises(ResolutionImpossible):
        Utils.resolve(pm, ports=[foo])

    port1_unsatisfiable_bar_deps = [
        "bar>=3.1.1",
        "bar<2.0.1",
        "bar<=2.0.0",
        "bar>2.0.1",
        "bar>=2.0.2",
        "bar==2.0.10",
    ]

    for bar_dep in port1_unsatisfiable_bar_deps:
        pm = DependencyManager()
        Utils.discover_port(pm, port=foo, depends=[bar_dep])
        Utils.discover_port(pm, port=bar)

        with pytest.raises(ResolutionImpossible):
            Utils.resolve(pm, ports=[foo])


def test_install_simple(fix):
    pm = DependencyManager()
    foo = "foo-1.9.3"
    bar = "bar-2.0.0"

    Utils.discover_port(pm, port=foo, depends=["bar>=1.1.1"])
    Utils.discover_port(pm, port=bar)

    Utils.resolve(pm, ports=[foo, bar])

    assert [] == Utils.list_deps_to_install(pm, bar)
    assert [os.path.join(PREFIX_PORTS, bar)] == Utils.list_deps_to_install(pm, foo)

    with pytest.raises(SystemExit) as ex:
        Utils.is_installed(pm, bar)
    assert ex.value.args[0] != 0

    Utils.mark_as_installed(pm, port=bar)

    with pytest.raises(SystemExit) as ex:
        Utils.is_installed(pm, bar)
    assert ex.value.args[0] == 0

    assert [] == Utils.list_deps_to_install(pm, foo)


def test_install_unsatisfiable(fix):
    pm = DependencyManager()
    foo = "foo-1.9.3"
    bar = "bar-2.0.0"

    Utils.discover_port(pm, port=foo, depends=["bar>=3.1.1"])
    Utils.discover_port(pm, port=bar)

    with pytest.raises(ResolutionImpossible):
        Utils.resolve(pm, ports=[foo])

    Utils.mark_as_installed(pm, port=bar)

    with pytest.raises(ResolutionImpossible):
        Utils.resolve(pm, ports=[foo])


def test_install_path(fix):
    pm = DependencyManager()
    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"
    port3 = "baz-1.2.3"

    Utils.discover_port(pm, port=port1)
    Utils.discover_port(pm, port=port2)

    assert [PREFIX_BUILD] == Utils.install_path(pm, port1)
    assert [PREFIX_BUILD] == Utils.install_path(pm, port2)

    Utils.discover_port(pm, port=port3, conflicts=["bazng>=0.0"])
    assert [os.path.join(PREFIX_BUILD_VERSIONED, port3)] == Utils.install_path(
        pm, port3
    )


def test_install_bad_env(fix):
    del os.environ["PREFIX_BUILD"]
    del os.environ["PREFIX_BUILD_VERSIONED"]

    pm = DependencyManager()

    port1 = "foo-1.9.3"
    port2 = "bar-2.0.0"

    Utils.discover_port(pm, port=port1)
    with pytest.raises(EnvironmentError) as ex:
        Utils.install_path(pm, port1)
    assert ex.value.args[0] == "PREFIX_BUILD undefined"

    Utils.discover_port(pm, port=port2, conflicts=["barng>=0.0"])
    with pytest.raises(EnvironmentError) as ex:
        Utils.install_path(pm, port2)
    assert ex.value.args[0] == "PREFIX_BUILD_VERSIONED undefined"

    os.environ["PREFIX_BUILD"] = PREFIX_BUILD
    os.environ["PREFIX_BUILD_VERSIONED"] = PREFIX_BUILD_VERSIONED
