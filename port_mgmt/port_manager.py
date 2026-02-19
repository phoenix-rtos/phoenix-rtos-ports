#!/usr/bin/env python3
#
# Port management
#
# Port builder with dependency resolution
#
# Copyright 2026 Phoenix Systems
# Author: Adam Greloch
#
# SPDX-License-Identifier: BSD-3-Clause
#

# requires python 'resolvelib', 'pyparsing', and 'packaging' packages

from __future__ import annotations
import sys
import operator

import os
import json
import yaml
import time

import resolvelib

from pathlib import Path

import subprocess

from enum import Enum

import pyparsing as pp
from argparse import Namespace, ArgumentParser

from packaging.version import Version
from functools import cache, cmp_to_key

# Our package manager uses Python's resolvelib library:
# https://pip.pypa.io/en/stable/topics/more-dependency-resolution/

from collections import deque
from typing import (
    Any,
    Protocol,
    Mapping,
    Iterator,
    Sequence,
    TypeVar,
    Callable,
    Tuple,
    Set,
    List,
    Iterable,
    Generator,
    Dict,
)

if Version(resolvelib.__version__) >= Version("1.1.1"):
    from resolvelib.structs import RequirementInformation, State, KT, RT, CT
    from resolvelib.resolvers.criterion import Criterion
else:
    # TODO: Drop the else once python3-resolvelib gets updated to >=1.1.1 on LTS
    # (24.04 LTS has 1.0.1)

    from typing import TYPE_CHECKING, Generic, NamedTuple, Union
    from collections import namedtuple

    KT = TypeVar("KT")  # Identifier.
    RT = TypeVar("RT")  # Requirement.
    CT = TypeVar("CT")  # Candidate.

    Matches = Union[Iterable[CT], Callable[[], Iterable[CT]]]

    if TYPE_CHECKING:

        class RequirementInformation(NamedTuple, Generic[RT, CT]):
            requirement: RT
            parent: CT | None

        class State(NamedTuple, Generic[RT, CT, KT]):
            """Resolution state in a round."""

            mapping: dict[KT, CT]
            criteria: dict[KT, Criterion[RT, CT]]
            backtrack_causes: list[RequirementInformation[RT, CT]]

    else:
        RequirementInformation = namedtuple(
            "RequirementInformation", ["requirement", "parent"]
        )
        State = namedtuple("State", ["mapping", "criteria", "backtrack_causes"])


class Requirement:
    @property
    def name(self) -> str:
        """The name identifying this requirement in the resolver.

        This is different from ``project_name`` if this requirement contains
        extras, where ``project_name`` would not contain the ``[...]`` part.
        """
        raise NotImplementedError("Subclass should override")

    def is_satisfied_by(self, candidate: Candidate) -> bool:
        return False


class Candidate:
    def __init__(
        self,
        name: str,
        version: PhxVersion,
        requirements: Iterable[Requirement],
        conflicts: Iterable[ConflictRequirement],
        definition_path: str,
        exposed_use_flags: List[str],
    ):
        self.name = name
        self.version = version
        self.installed = False
        self._requirements = requirements
        self._conflicts = conflicts
        self.definition_path = definition_path
        self.build_tests = False
        self.exposed_use_flags = exposed_use_flags
        self.use_flags: List[str] = []

    def __repr__(self):
        return f"{self.name}-{self.version}"

    def set_use_flags(self, flags):
        diff = list(set(flags) - set(self.exposed_use_flags))
        if diff:
            logger.error(f"unrecognized flags for {self}:", diff)
            sys.exit(1)

    def iter_dependencies(self) -> Iterable[Requirement]:
        return self._requirements

    def iter_conflicts(self) -> Iterable[ConflictRequirement]:
        return self._conflicts

    def conflicts_with(self, candidate: Candidate) -> bool:
        for creq in self._conflicts:
            if creq.is_satisfied_by(candidate):
                return True
        return False

    def is_optional(self, candidate: Candidate) -> bool:
        for req in self._requirements:
            if (
                req.name == candidate.name
                and req.is_satisfied_by(candidate)
                and isinstance(req, OptionalRequirement)
            ):
                return True
        return False

    @property
    def install_path(self) -> str:
        if self._conflicts:
            # If port is conflictable, it has a special installation directory
            prefix = ensure_getenv("PREFIX_BUILD_VERSIONED")
            return os.path.join(prefix, f"{self.name}-{str(self.version)}")
        else:
            # Otherwise, it is treated like normal libs
            prefix = ensure_getenv("PREFIX_BUILD")
            return f"{prefix}"

    def to_dict(self) -> dict[str, str | list[str]]:
        return {
            "version": str(self.version),
            "requirements": [str(r) for r in self.iter_dependencies()],
            "conflicts": [str(r) for r in self.iter_conflicts()],
            "port_def_path": str(self.definition_path),
            "iuse": self.exposed_use_flags,
        }


class OsCandidate(Candidate):
    def __init__(self, name: str, version: PhxVersion):
        super().__init__(name, version, [], [], "", [])

    def __repr__(self):
        return f"OS:{self.name}-{self.version}"


PreferenceInformation = RequirementInformation[Requirement, Candidate]


class Preference(Protocol):
    def __lt__(self, __other: Any) -> bool: ...


class PhxVersion(Version):
    def __str__(self) -> str:
        """
        A modified Version.__str__ that does not print added zeros in
        pre-release, so that '1.1.1a' is printed as '1.1.1a', not as '1.1.1a0'
        """
        parts = []

        # Epoch
        if self.epoch != 0:
            parts.append(f"{self.epoch}!")

        # Release segment
        parts.append(".".join(str(x) for x in self.release))

        # Pre-release
        if self.pre is not None and len(self.pre) > 1:
            parts.append("".join(str(x) for x in self.pre[:-1]))

        # Post-release
        if self.post is not None:
            parts.append(f".post{self.post}")

        # Development release
        if self.dev is not None:
            parts.append(f".dev{self.dev}")

        # Local self segment
        if self.local is not None:
            parts.append(f"+{self.local}")

        return "".join(parts)


class VersionGrammar:
    package = pp.Word(pp.alphanums + "_")
    version = (
        pp.Regex(r"\b\d+(?:\.\d+){1,2}[a-z]?\b")
        .set_name("version")
        .set_parse_action(pp.token_map(PhxVersion))
    )
    no_version_op = pp.Empty().set_parse_action(lambda: ">=")
    no_version = (
        pp.Empty().set_name("version").set_parse_action(lambda: PhxVersion("0.0"))
    )
    version_op = pp.one_of(">= <= == > <")
    e1 = pp.Group(package + version_op + version) ^ pp.Group(
        package + no_version_op + no_version
    )
    e0 = e1 + pp.ZeroOrMore(e1)

    # TODO: foo>3 parses to nothing - fix

    @staticmethod
    def parse_string(s: str):
        ret = VersionGrammar.e0.parse_string(s)
        logger.debug(ret)
        return ret


T = TypeVar("T")

Constraint = Tuple[str, PhxVersion]


PORT_MGMT_DIR = Path(__file__).parent
PORTS_DIR = PORT_MGMT_DIR.parent


def parse_requirements(s: str, f: Callable[[str, list[Constraint]], T]) -> list[T]:
    requirements_objects = []
    if s:
        requirements_tuples: dict[str, list[Constraint]] = dict()

        res = VersionGrammar.parse_string(s)
        for rname, rel, ver in res:
            if rname not in requirements_tuples:
                requirements_tuples[rname] = []
            requirements_tuples[rname].append((rel, ver))

        for rname, constraints in requirements_tuples.items():
            logger.debug(constraints)
            requirements_objects.append(f(rname, constraints))

    return requirements_objects


class PhxProvider(resolvelib.AbstractProvider):
    def __init__(self, all_candidates: Mapping[str, Mapping[str, Candidate]]):
        self.all_candidates: Mapping[str, Mapping[str, Candidate]] = all_candidates
        self.masked_requirements: Set[OptionalRequirement] = set()

    def identify(self, requirement_or_candidate: Requirement | Candidate) -> str:
        return requirement_or_candidate.name

    def mask_optional(self, req: OptionalRequirement):
        logger.debug("masking the optional", req)
        self.masked_requirements.add(req)

    def narrow_requirement_selection(
        self,
        identifiers: Iterable[str],
        resolutions: Mapping[str, Candidate],
        candidates: Mapping[str, Iterator[Candidate]],
        information: Mapping[str, Iterator[PreferenceInformation]],
        backtrack_causes: Sequence[PreferenceInformation],
    ) -> Iterable[str]:
        # TODO: when performance becomes a problem, narrow selections to speed up the resolution
        return identifiers

    def get_preference(
        self,
        identifier: str,
        resolutions: Mapping[str, Candidate],
        candidates: Mapping[str, Iterator[Candidate]],
        information: Mapping[str, Iterable[PreferenceInformation]],
        backtrack_causes: Sequence[PreferenceInformation],
    ) -> Preference:
        # TODO: when performance becomes a problem, add preferences to speed up the resolution
        return 0

    def find_matches(
        self,
        identifier: str,
        requirements: Mapping[str, Iterator[Requirement]],
        incompatibilities: Mapping[str, Iterator[Candidate]],
    ) -> Iterable[Candidate]:
        """Find all possible candidates that satisfy all requirements and are
        not included in incompatibilities.

        Returned iterable is ordered by preference. In our case newer version
        comes first.
        """
        if identifier not in self.all_candidates:
            return []

        logger.debug("find_matches", identifier, requirements)

        res: list[Candidate] = []
        for candidate in self.all_candidates[identifier].values():
            logger.debug(candidate, "requirements:", candidate.iter_dependencies())

            if candidate in incompatibilities.values():
                continue
            good = True
            logger.debug(candidate, "conflict list:", candidate.iter_conflicts())
            for conflict in candidate.iter_conflicts():
                if conflict.cname in requirements:
                    logger.debug(
                        candidate,
                        "conflicts with",
                        conflict.cname,
                        "but it is in requirements",
                    )
                    good = False
                    break
            for requirement in requirements[identifier]:
                if not requirement.is_satisfied_by(candidate):
                    logger.debug(candidate, "doesn't satisfy", requirement)
                    good = False
                    break
                if good:
                    logger.debug(candidate, "satisfies", requirement)
                    res.append(candidate)

        logger.debug("resulting matches", res)

        def cmp_cands(a: Candidate, b: Candidate):
            def cmp(a: PhxVersion, b: PhxVersion):
                return (a > b) - (a < b)

            return -cmp(a.version, b.version)

        # Sort newer versions first
        return sorted(res, key=cmp_to_key(cmp_cands))

    @staticmethod
    @cache
    def is_satisfied_by(requirement: Requirement, candidate: Candidate) -> bool:
        return requirement.is_satisfied_by(candidate)

    def get_dependencies(self, candidate: Candidate) -> Iterable[Requirement]:
        return (
            r
            for r in candidate.iter_dependencies()
            if r is not None
            if r not in self.masked_requirements
        )


def constraint_satisfied(
    candidate_version: PhxVersion, constraint: Tuple[str, PhxVersion]
):
    relation, constraint_version = constraint
    match relation:
        case ">=":
            op = operator.ge
        case "<=":
            op = operator.le
        case "==":
            op = operator.eq
        case ">":
            op = operator.gt
        case "<":
            op = operator.lt
        case _:
            sys.exit(f"invalid/unsupported relation: '{relation}'")
    return op(candidate_version, constraint_version)


class BaseRequirement(Requirement):
    def __init__(self, name: str, constraints: Iterable[Tuple[str, PhxVersion]]):
        self._name = name
        self.constraints = constraints

    def __repr__(self):
        return self._name + ",".join(
            [rel + str(ver) for (rel, ver) in self.constraints]
        )

    @property
    def name(self) -> str:
        return self._name

    def is_satisfied_by(self, candidate: Candidate) -> bool:
        for constraint in self.constraints:
            if not constraint_satisfied(candidate.version, constraint):
                return False
        return True


class ConflictRequirement(BaseRequirement):
    def __init__(
        self, name: str, cname: str, constraints: Iterable[Tuple[str, PhxVersion]]
    ):
        super().__init__(name, constraints)
        self._cname = cname

    def __repr__(self):
        return "[!]" + self.cname

    @property
    def cname(self):
        return self._cname

    def is_satisfied_by(self, candidate: Candidate) -> bool:
        return self._cname != candidate.name


class OptionalRequirement(BaseRequirement):
    def __repr__(self):
        return "[o]" + super().__repr__()


def ensure_getenv(var: str):
    prefix = os.getenv(var)
    if prefix is None:
        raise EnvironmentError(f"{var} undefined")
    return prefix


def parse_namever(namever: str) -> Tuple[str, PhxVersion]:
    elems = namever.split("-")
    if len(elems) != 2:
        raise ValueError(f"bad name-ver - expected NAME-VERSION, got '{namever}'")
    return (elems[0], PhxVersion(elems[1]))


class LogLevel(Enum):
    VERBOSE = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
    NONE = 4


class Color:
    CYAN = "\033[0;36m"
    BLUE = "\033[0;34m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    RED = "\033[0;31m"
    END = "\033[0m"


class Logger:
    print_level: LogLevel = LogLevel.WARNING

    def _print(self, fmt: str, level: LogLevel, color: str, **kwargs):
        if level.value >= self.print_level.value:
            print(
                color + f"{level.name}: " + Color.END + fmt + color + Color.END,
                file=sys.stderr,
                **kwargs,
            )

    def set_level(self, n: LogLevel):
        self.print_level = n

    def debug(self, *fmt: object, sep: str = " ", **kwargs):
        self._print(
            sep.join(map(str, fmt)), level=LogLevel.VERBOSE, color=Color.GREEN, **kwargs
        )

    def info(self, *fmt: object, sep: str = " ", **kwargs):
        self._print(
            sep.join(map(str, fmt)), level=LogLevel.INFO, color=Color.CYAN, **kwargs
        )

    def warning(self, *fmt: object, sep: str = " ", **kwargs):
        self._print(
            sep.join(map(str, fmt)),
            level=LogLevel.WARNING,
            color=Color.YELLOW,
            **kwargs,
        )

    def error(self, *fmt: object, sep: str = " ", **kwargs):
        self._print(
            sep.join(map(str, fmt)), level=LogLevel.ERROR, color=Color.RED, **kwargs
        )


logger = Logger()


class MyReporter(resolvelib.BaseReporter):
    _redo = False

    def __init__(self, provider):
        self.provider = provider

    def redo_with_masked_optional(self) -> bool:
        res = self._redo
        self._redo = False
        return res

    def ending(self, state: State[RT, CT, KT]):
        logger.debug("ending", state)

    def adding_requirement(self, requirement: RT, parent: CT | None):
        logger.debug("adding a requirement:", requirement, "parent:", parent)

    def rejecting_candidate(self, criterion: Criterion[RT, CT], candidate: CT):
        for req_info in criterion.information:
            req, parent = req_info.requirement, req_info.parent
            if isinstance(req, OptionalRequirement):
                logger.debug(
                    f"{parent} optional requirement for {req} unsatisfiable, dropping"
                )
                self._redo = True
                self.provider.mask_optional(req)
            else:
                logger.debug(f"{parent} requirement for {req} unsatisfiable")


def find_ports_from_port_defs() -> Generator[Tuple[Dict[str, str], Path]]:
    for port_def in PORTS_DIR.rglob("*.def.sh"):
        result = subprocess.run(
            ["bash", PORT_MGMT_DIR / "port_def_to_json.sh", port_def],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            logger.error(f"during loading of {port_def}:\n", result.stderr)
            sys.exit(1)

        dct = json.loads(result.stdout)
        logger.debug(dct)

        assert isinstance(dct, dict)
        yield (dct, port_def)


class DependencyManager:
    def __init__(
        self,
        argv,
        find_ports=find_ports_from_port_defs,
        get_ports_to_build=None,
        dry=False,
    ):
        self.candidates: dict[str, dict[str, Candidate]] = dict()
        self.mapping: dict[str, dict[str, Candidate]] = dict()
        self.roll_logs = False
        self.find_ports = find_ports
        self.dry = dry  # self.dry may be overwritten by _parse_arguments
        self.args = self._parse_arguments(argv)

        # Add OS dummy candidates
        self.add_candidate(
            OsCandidate("phoenix", PhxVersion(ensure_getenv("PHOENIX_VER")))
        )
        self.add_candidate(OsCandidate("host", PhxVersion("0")))

        if get_ports_to_build:
            self.get_ports_to_build = get_ports_to_build
        else:

            def get_ports_to_build_from_ports_yaml() -> (
                Dict[str, str | Dict[str, str]] | None
            ):
                if not os.path.exists(self.args.ports_yaml):
                    logger.warning(f"'{self.args.ports_yaml}' does not exist")
                    return None
                with open(self.args.ports_yaml, "r", encoding="utf-8") as f:
                    return yaml.safe_load(f)

            self.get_ports_to_build = get_ports_to_build_from_ports_yaml

    def add_candidate(self, candidate: Candidate):
        name = candidate.name
        version = str(candidate.version)
        if name not in self.candidates:
            self.candidates[name] = dict()

        self.candidates[name][version] = candidate

        logger.debug(f"added {candidate} reqs={list(candidate.iter_dependencies())}")

    def lookup_candidate(self, name: str, version: PhxVersion) -> Candidate:
        return self.candidates[name][str(version)]

    def discover_ports(self):
        for port, def_path in self.find_ports():
            name, version = parse_namever(port["namever"])

            req = parse_requirements(port["requires"], BaseRequirement)
            req += parse_requirements(port["optional"], OptionalRequirement)
            req += parse_requirements(port["supports"], BaseRequirement)

            conflicts = parse_requirements(
                port["conflicts"],
                lambda r, c: ConflictRequirement(name, r, c),
            )

            if not def_path:
                raise ValueError("Empty definition path")

            available_flags = port["iuse"].split()

            self.add_candidate(
                Candidate(name, version, req, conflicts, def_path, available_flags)
            )

    def resolve(self, cands):
        user_requirements = dict()

        for cand in cands:
            user_requirements[str(cand)] = BaseRequirement(
                cand.name, [("==", cand.version)]
            )

        provider = PhxProvider(self.candidates)
        reporter = MyReporter(provider)

        while True:
            try:
                resolver = resolvelib.Resolver(provider, reporter)
                for namever, ureq in user_requirements.items():
                    result = resolver.resolve([ureq])
                    self.mapping[namever] = result.mapping
                logger.debug(self.mapping)
                break
            except resolvelib.resolvers.ResolutionTooDeep as e:
                logger.error(
                    f"Requirements unsatisfiable despite {e.round_count} attempts"
                )
                # NOTE: rethrow resolution exceptions instead of sys.exit(1)
                # to catch exact resolution failures in resolver tests
                raise
            except resolvelib.resolvers.ResolutionImpossible as e:
                causes_strs = []
                for cause in e.causes:
                    causes_strs.append(
                        f"-> {cause.requirement} required by {cause.parent}"
                    )
                logger.error("Requirements unsatisfiable:\n" + "\n".join(causes_strs))
                if reporter.redo_with_masked_optional():
                    logger.debug("Redoing resolution with masked optional")
                else:
                    raise

    def iter_cand_deps(self, cand: Candidate) -> Generator[Candidate]:
        mapped_deps = self.mapping[str(cand)]
        for dep in cand.iter_dependencies():
            if dep.name not in mapped_deps:
                # this is an optional dependency, otherwise resolver would
                # raise resolution error earlier
                continue
            yield mapped_deps[dep.name]

    def iter_namever_deps(self, namever: str) -> Generator[Candidate]:
        name, version = parse_namever(namever)
        candidate = self.lookup_candidate(name, version)
        logger.debug(self.mapping)
        return self.iter_cand_deps(candidate)

    def run_process(
        self, cmd, env, pass_fds=(), output_len=5, color=Color.BLUE
    ) -> subprocess.Popen:
        if not self.roll_logs:
            return subprocess.Popen(
                cmd,
                env=env,
                pass_fds=pass_fds,
                text=True,
            )

        proc = subprocess.Popen(
            cmd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            pass_fds=pass_fds,
            text=True,
        )

        last_lines: deque[str] = deque(maxlen=output_len)

        if proc.stdout:
            for line in proc.stdout:
                sys.stdout.write("\033[F" * len(last_lines))
                last_lines.append(line.rstrip()[: os.get_terminal_size()[0] * 8 // 10])

                for line in last_lines:
                    sys.stdout.write(color + "=> \033[K" + line + "\n" + Color.END)

                sys.stdout.flush()

        return proc

    def prepare_cand(self, cand: Candidate, env: dict[str, str]) -> dict[str, str]:
        r_fd, w_fd = os.pipe()

        logger.info(f"Prepare {cand}")

        proc = self.run_process(
            [
                "bash",
                PORT_MGMT_DIR / "port_prepare.sh",
                cand.definition_path,
                str(w_fd),
            ],
            pass_fds=(w_fd,),
            env=env,
            output_len=10,
            color=Color.CYAN,
        )

        if proc.wait() != 0:
            logger.error(f"Preparing {cand} failed")
            sys.exit(1)

        os.close(w_fd)
        with os.fdopen(r_fd) as r:
            env_output = r.read()

        for line in env_output.split("\0"):
            if "=" in line:
                key, value = line.split("=", 1)
                env[key] = value

        return env

    def build_cand(self, cand: Candidate, env: dict[str, str]):
        log_file_path = os.path.join(env["PREFIX_PORT_BUILD"], "build.log")

        cmd = [
            "bash",
            str(PORT_MGMT_DIR / "port_build.sh"),
            cand.definition_path,
            log_file_path,
        ]

        logger.info(f"Build {cand}")

        proc = self.run_process(cmd, env=env)

        retcode = proc.wait()

        if retcode != 0:
            logger.error(
                f"Building {cand} failed. Full logs written to {log_file_path}"
            )
            sys.exit(1)

    def install_cand(self, cand: Candidate, dep_of: Candidate | None = None):
        if isinstance(cand, OsCandidate):
            return

        info = f"Installing {cand}"
        extras_info = []

        port_env = os.environ.copy()

        if dep_of:
            extras_info.append(f"dependency of {dep_of}")

        if len(cand.use_flags) > 0:
            for use_flag in cand.use_flags:
                port_env[f"PORT_USE_{use_flag}"] = "y"

            extras_info.append("+USE flags: " + " ".join(cand.use_flags))

        if cand.build_tests:
            port_env["PORT_BUILD_TESTS"] = "y"

            extras_info.append("+tests")

        if len(extras_info) > 0:
            info += f" ({', '.join(extras_info)})"

        logger.info(info)

        port_env["PREFIX_PORT_INSTALL"] = cand.install_path

        self.resolve([cand])

        # install required dependencies
        for dep_candidate in self.iter_cand_deps(cand):
            if not dep_candidate.installed:
                if cand.is_optional(dep_candidate):
                    logger.warning(
                        f"{dep_candidate} is an optional dependency for {cand} that must be explicitly enabled"
                    )
                else:
                    self.install_cand(dep_candidate, cand)

        lib_path_set = set()
        pkg_config_path_set = set()
        for dep_candidate in self.iter_cand_deps(cand):
            env_name = f"PORT_DEP_{dep_candidate.name}"
            if dep_candidate.installed:
                port_env[env_name] = dep_candidate.install_path
                pkg_config_path_set.add(
                    os.path.join(dep_candidate.install_path, "lib", "pkgconfig")
                )
                lib_path_set.add("-L" + os.path.join(dep_candidate.install_path, "lib"))
            else:
                port_env[env_name] = ""

            logger.debug(
                env_name,
                dep_candidate.install_path if dep_candidate.installed else "<empty>",
            )

        if self.dry:
            cand.installed = True
            return

        port_env["PKG_CONFIG_PATH"] = ":".join(list(pkg_config_path_set))

        port_env = self.prepare_cand(cand, port_env)

        self.build_cand(cand, port_env)

        logger.info(f"Installed {cand}")

        cand.installed = True

    def cmd_build(self):
        start = time.time()

        self.discover_ports()

        ports_dict = self.get_ports_to_build()

        if not ports_dict:
            logger.warning("ports.yaml not found or empty. Nothing to do")
            sys.exit(0)

        cands = []

        build_all_tests = ports_dict.get("tests", False)

        if "ports" not in ports_dict or not ports_dict["ports"]:
            logger.error("no ports to install? (`ports:` not present in ports.yaml)")
            sys.exit(1)

        # set per-port options
        for port in ports_dict["ports"]:
            port_name = port["name"]

            if port_name not in self.candidates:
                logger.error("unrecognized port:", port_name)
                sys.exit(1)

            port_cands = self.candidates[port_name]
            if "version" in port:
                # normalize
                ver = str(PhxVersion(port["version"]))

                if ver in port_cands:
                    cand = port_cands[ver]
                else:
                    logger.error(
                        f"Version '{ver}' for '{port_name}' not found. Possible choices: {list(port_cands.keys())}"
                    )
                    sys.exit(1)
            else:
                # pick any
                cand = next(iter(port_cands.values()))

            cand.use_flags = port.get("use", [])
            cand.build_tests = port.get("tests", False) and build_all_tests

            cands.append(cand)

        for i, cand in enumerate(cands):
            cand_start = time.time()
            self.install_cand(cand)
            cand_stop = time.time()
            logger.info(
                f"[{i + 1}/{len(cands)}, {cand_stop - cand_start:.2f} s] Installed {cand}"
            )

        namevers = []
        for name, versions in self.candidates.items():
            for candidate in versions.values():
                if candidate.installed:
                    namevers.append(f"{name}-{candidate.version}")

        stop = time.time()
        logger.info(
            f"[Total {stop - start:.2f} s] Installed ports:", " ".join(namevers)
        )

    def cmd_validate(self):
        start = time.time()
        self.discover_ports()
        stop = time.time()
        cand_str = json.dumps(self.candidates, indent=2, default=lambda o: o.to_dict())
        logger.info(
            f"[Total {stop - start:.2f} s] Validated {len(self.candidates)} ports:\n",
            cand_str,
        )

    def _build_argument_parser(self) -> ArgumentParser:
        parser = ArgumentParser()

        parser.add_argument(
            "--dry", action="store_true", help="don't build ports (resolve only)"
        )
        parser.add_argument("--res", help="specify destination metadata file")
        parser.add_argument("-v", action="store_true")
        parser.add_argument(
            "-r",
            action="store_true",
            default=False,
            help="roll build logs (i.e. for interactive environment)",
        )
        parser.add_argument("--quiet", action="store_true")

        subparsers = parser.add_subparsers(title="subcommands")

        build = subparsers.add_parser(
            "build", help="build ports based on ports.yaml config"
        )
        build.add_argument("ports_yaml")
        build.set_defaults(func=self.cmd_build)

        build = subparsers.add_parser(
            "validate", help=f"validate all port definitions in {PORTS_DIR}"
        )
        build.set_defaults(func=self.cmd_validate)

        return parser

    def _parse_arguments(self, argv: Sequence[str]) -> Namespace:
        parser = self._build_argument_parser()
        if len(argv) == 1:
            parser.print_help()
        args = parser.parse_args(argv[1:])

        logger.set_level(LogLevel.INFO)

        if args.v:
            logger.set_level(LogLevel.VERBOSE)
        if args.quiet:
            logger.set_level(LogLevel.NONE)
        if args.r:
            self.roll_logs = True
        if args.dry:
            logger.warning("Dry run")
            self.dry = True

        return args

    def run_cmd(self):
        if "func" in self.args:
            self.args.func()


def main():
    dm = DependencyManager(sys.argv)
    dm.run_cmd()


if __name__ == "__main__":
    main()
