#!/usr/bin/env python3
#
# Port management
#
# Tests for port builder with dependency resolution
#
# Copyright 2026 Phoenix Systems
# Author: Adam Greloch
#
# SPDX-License-Identifier: BSD-3-Clause
#

import pytest
import os

from resolvelib.resolvers import (
    ResolutionImpossible,
    ResolutionTooDeep,
)
from port_manager import DependencyManager, LogLevel, logger, PhxVersion

PREFIX_BUILD = "normal_port_install_dir"
PREFIX_BUILD_VERSIONED = "versioned_port_install_dir"
PREFIX_PORTS = "ports"


@pytest.fixture(scope="session")
def fix():
    os.environ["PREFIX_BUILD"] = PREFIX_BUILD
    os.environ["PREFIX_BUILD_VERSIONED"] = PREFIX_BUILD_VERSIONED
    logger.set_level(LogLevel.VERBOSE if os.getenv("V", "0") == "1" else LogLevel.NONE)
    yield


def build_find_ports(dct):
    def closure():
        for name, port_def in dct.items():
            port_def["namever"] = name
            opt_fields = ["requires", "optional", "conflicts"]

            for field in opt_fields:
                if field not in port_def:
                    port_def[field] = []

            yield (port_def, os.path.join("somedir", name))

    return closure


def build_get_ports_to_build(dct):
    def closure():
        return dct

    return closure


def run_dry_build(all_ports, to_build):
    pm = DependencyManager(
        [],
        get_ports_to_build=build_get_ports_to_build(to_build),
        find_ports=build_find_ports(all_ports),
        dry=True,
    )
    pm.cmd_build()
    return pm


def test_port_resolution_simple(fix):
    all_ports = {"foo-1.2.3": {"requires": "bar>=1.1.1"}, "bar-2.0.0": {}}
    to_build = {"ports": [{"name": "foo"}]}
    run_dry_build(all_ports, to_build)


def test_port_resolution_depends_optional(fix):
    all_ports = {
        "foo-1.2.3": {"requires": "bar>=1.1.1", "optional": "baz>=3.2.1"},
        "bar-2.0.0": {},
    }
    to_build = {"ports": [{"name": "foo"}]}
    run_dry_build(all_ports, to_build)

    all_ports["baz-3.2.1"] = {}
    run_dry_build(all_ports, to_build)


def test_port_resolution_conflicts_itself(fix):
    all_ports = {"foo-1.2.3": {"conflicts": "foo>=1.1.1"}}
    to_build = {"ports": [{"name": "foo"}]}

    with pytest.raises(ResolutionImpossible):
        run_dry_build(all_ports, to_build)


def get_cand_from_namever(pm, namever):
    name, _ = namever.split("-")
    return pm.mapping[namever][name]


def assert_version_mapping(pm, namever, exp_mappings):
    name, ver = namever.split("-")
    resolved_mapping = pm.mapping[namever]

    assert len(resolved_mapping) == len(exp_mappings) + 1
    assert resolved_mapping[name].version == PhxVersion(ver)

    for dep_name, ver in exp_mappings.items():
        assert resolved_mapping[dep_name].version == PhxVersion(ver)


def test_port_resolution_independent_conflicts(fix):
    all_ports = {
        "foo-1.2.3": {"requires": "bar>=1.1.1"},
        "bar-2.0.0": {"conflicts": "barng>=0.0"},
        "barng-2.2.0": {"conflicts": "bar>=0.0"},
        "foo-3.2.0": {"requires": "barng>=1.1.1"},
    }

    to_build = {
        "ports": [
            {"name": "foo", "version": "1.2.3"},
            {"name": "foo", "version": "3.2.0"},
        ]
    }
    pm = run_dry_build(all_ports, to_build)
    assert_version_mapping(pm, "foo-1.2.3", {"bar": "2.0.0"})
    assert_version_mapping(pm, "foo-3.2.0", {"barng": "2.2.0"})


def test_port_resolution_independent_conflicts_choose_alternative(fix):
    all_ports = {
        "foo-1.2.3": {"requires": "bar>=1.1.1"},
        "bar-2.0.0": {"conflicts": "barng>=0.0"},
        "barng-2.2.0": {"conflicts": "bar>=0.0"},
        "foo-3.2.0": {"requires": "barng>=1.1.1"},
        "baz-1.1.1": {"requires": "foo>=1.1.1"},
    }

    to_build = {"ports": [{"name": "baz"}]}
    pm = run_dry_build(all_ports, to_build)

    # Resolver should pick alternative with newest version
    assert_version_mapping(pm, "baz-1.1.1", {"foo": "3.2.0", "barng": "2.2.0"})


def test_resolution_conflicting_port_dependencies(fix):
    all_ports = {
        "foo-1.2.3": {"requires": "bar>=1.1.1"},
        "bar-2.0.0": {"conflicts": "barng>=0.0"},
        "barng-2.2.0": {"conflicts": "bar>=0.0"},
        "baz-3.2.0": {"requires": "barng>=1.1.1"},
        "faz-4.2.0": {"requires": "foo>=1.0 baz>=1.0"},
    }

    to_build = {"ports": [{"name": "faz"}]}

    with pytest.raises(ResolutionTooDeep):
        run_dry_build(all_ports, to_build)


def test_resolution_unsatisfiable_simple(fix):
    all_ports = {"foo-1.2.3": {"requires": "bar>=1.1.1"}}

    to_build = {"ports": [{"name": "foo"}]}

    with pytest.raises(ResolutionImpossible):
        run_dry_build(all_ports, to_build)


def test_resolution_unsatisfiable_version(fix):
    unsatisfiable_bar_requires = [
        "bar>=3.1.1",
        "bar<2.0.1",
        "bar<=2.0.0",
        "bar>2.0.1",
        "bar>=2.0.2",
        "bar==2.0.10",
    ]

    for req in unsatisfiable_bar_requires:
        all_ports = {
            "foo-1.2.3": {"requires": req},
            "bar-2.0.1": {},
        }

        to_build = {"ports": [{"name": "foo"}]}

        with pytest.raises(ResolutionImpossible):
            run_dry_build(all_ports, to_build)


def test_install_path(fix):
    all_ports = {
        "foo-1.2.3": {"requires": "bar>=1.1.1"},
        "bar-2.0.0": {"conflicts": "barng>=0.0"},
    }
    to_build = {"ports": [{"name": "foo"}]}
    pm = run_dry_build(all_ports, to_build)

    assert PREFIX_BUILD == get_cand_from_namever(pm, "foo-1.2.3").install_path
    assert (
        os.path.join(PREFIX_BUILD_VERSIONED, "bar-2.0.0")
        == get_cand_from_namever(pm, "bar-2.0.0").install_path
    )


def test_install_bad_env(fix):
    del os.environ["PREFIX_BUILD"]

    all_ports = {"foo-1.2.3": {"requires": "bar>=1.1.1"}, "bar-2.0.0": {}}
    to_build = {"ports": [{"name": "foo"}]}

    with pytest.raises(EnvironmentError) as ex:
        run_dry_build(all_ports, to_build)
    assert ex.value.args[0] == "PREFIX_BUILD undefined"

    os.environ["PREFIX_BUILD"] = PREFIX_BUILD

    del os.environ["PREFIX_BUILD_VERSIONED"]

    all_ports = {
        "foo-1.2.3": {"requires": "bar>=1.1.1"},
        "bar-2.0.0": {"conflicts": "barng>=0.0"},
    }
    to_build = {"ports": [{"name": "foo"}]}
    with pytest.raises(EnvironmentError) as ex:
        run_dry_build(all_ports, to_build)
    assert ex.value.args[0] == "PREFIX_BUILD_VERSIONED undefined"

    os.environ["PREFIX_BUILD_VERSIONED"] = PREFIX_BUILD_VERSIONED

