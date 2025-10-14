#!/usr/bin/env python3
#
# Port dependency manager
#
# Copyright 2025 Phoenix Systems
# Author: Adam Greloch
#

# requires python 'resolvelib', 'pyparsing', and 'packaging' packages

from __future__ import annotations
import sys
import operator
import resolvelib
import os
import jsonpickle

from colorama import Fore, Style
from enum import Enum

import pyparsing as pp
from argparse import Namespace, ArgumentParser

from packaging.version import Version
from functools import cache, cmp_to_key

# Our package manager uses Python's resolvelib library:
# https://pip.pypa.io/en/stable/topics/more-dependency-resolution/

from collections.abc import Iterable
from typing import (
    Any,
    Protocol,
    Mapping,
    Iterator,
    Sequence,
    TypeVar,
    Union,
    Callable,
    Tuple,
    Set,
)


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
    @property
    def name(self) -> str:
        """The name identifying this candidate in the resolver.

        This is different from ``project_name`` if this candidate contains
        extras, where ``project_name`` would not contain the ``[...]`` part.
        """
        raise NotImplementedError("Override in subclass")

    @property
    def version(self) -> PhxVersion:
        raise NotImplementedError("Override in subclass")

    @property
    def installed(self) -> bool:
        raise NotImplementedError("Override in subclass")

    @property
    def install_path(self) -> str:
        raise NotImplementedError("Override in subclass")

    @property
    def definition_path(self) -> str:
        raise NotImplementedError("Override in subclass")

    def iter_dependencies(self) -> Iterable[Requirement]:
        raise NotImplementedError("Override in subclass")

    def iter_conflicts(self) -> Iterable[ConflictRequirement]:
        raise NotImplementedError("Override in subclass")


KT = TypeVar("KT")  # Identifier.
RT = TypeVar("RT")  # Requirement.
CT = TypeVar("CT")  # Candidate.

Matches = Union[Iterable[CT], Callable[[], Iterable[CT]]]


PreferenceInformation = resolvelib.structs.RequirementInformation[
    Requirement, Candidate
]


class Preference(Protocol):
    def __lt__(self, __other: Any) -> bool: ...


class PhxVersion (Version):
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
    version_op = pp.one_of(">= <= == > <")
    e1 = pp.Group(package + version_op + version)
    e0 = e1 + pp.ZeroOrMore(e1)

    # TODO: foo>3 parses to nothing - fix

    @staticmethod
    def parse_string(s: str):
        return VersionGrammar.e0.parse_string(s)


T = TypeVar("T")

Constraint = Tuple[str, PhxVersion]


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
        self.all_candidates: Mapping[str,
                                     Mapping[str, Candidate]] = all_candidates
        self.masked_requirements: Set[OptionalRequirement] = set()

    def identify(self, requirement_or_candidate: Requirement | Candidate) -> str:
        return requirement_or_candidate.name

    def mask_optional(self, req: OptionalRequirement) -> None:
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
        # TODO: when the performance becomes a problem, narrow selections to speed up the resolution
        return identifiers

    def get_preference(
        self,
        identifier: str,
        resolutions: Mapping[str, Candidate],
        candidates: Mapping[str, Iterator[Candidate]],
        information: Mapping[str, Iterable[PreferenceInformation]],
        backtrack_causes: Sequence[PreferenceInformation],
    ) -> Preference:
        # TODO: when the performance becomes a problem, add preferences to speed up the resolution
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
            logger.debug(candidate, "requirements:",
                         candidate.iter_dependencies())

            if candidate in incompatibilities.values():
                continue
            good = True
            logger.debug(candidate, "conflict list:",
                         candidate.iter_conflicts())
            for conflict in candidate.iter_conflicts():
                if conflict.cname in requirements:
                    logger.error(
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

        def cmp(a, b):
            return (a > b) - (a < b)

        return sorted(res, key=cmp_to_key(lambda a, b: cmp(a.version, b.version)))

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


def constraint_satisfied(candidate_version: PhxVersion, constraint: Tuple[str, PhxVersion]):
    (relation, constraint_version) = constraint
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
        return "!:" + self.cname

    @property
    def cname(self):
        return self._cname

    def is_satisfied_by(self, candidate: Candidate) -> bool:
        return self._cname != candidate.name


class OptionalRequirement(BaseRequirement):
    def __repr__(self):
        return "O:" + super().__repr__()


def ensure_getenv(var: str):
    prefix = os.getenv(var)
    if prefix is None:
        raise EnvironmentError(f"{var} undefined")
    return prefix


def parse_namever(namever: str) -> Tuple[str, PhxVersion]:
    elems = namever.split("-")
    if len(elems) != 2:
        raise ValueError(
            f"bad name-ver - expected NAME-VERSION, got '{namever}'")
    return (elems[0], PhxVersion(elems[1]))


class InstallableCandidate(Candidate):
    def __init__(
        self,
        name: str,
        version: PhxVersion,
        requirements: Iterable[Requirement],
        conflicts: Iterable[ConflictRequirement],
        definition_path: str,
    ) -> None:
        self._name = name
        self._version = version
        self._installed = False
        self._requirements = requirements
        self._conflicts = conflicts
        self._definition_path = definition_path

    @property
    def name(self) -> str:
        return self._name

    def __repr__(self):
        return f"{self._name}-{self.version}"

    @property
    def installed(self) -> bool:
        return self._installed

    def mark_as_installed(self) -> None:
        self._installed = True

    @property
    def version(self) -> PhxVersion:
        return self._version

    @property
    def definition_path(self) -> str:
        return self._definition_path

    def iter_dependencies(self) -> Iterable[Requirement]:
        return self._requirements

    def iter_conflicts(self) -> Iterable[ConflictRequirement]:
        return self._conflicts

    def conflicts_with(self, candidate: Candidate) -> bool:
        for creq in self._conflicts:
            if creq.is_satisfied_by(candidate):
                return True
        return False

    @property
    def install_path(self) -> str:
        if self._conflicts:
            # If port is conflictable, it has a special installation directory
            prefix = ensure_getenv("PREFIX_BUILD_VERSIONED")
            return f"{prefix}/{self._name}-{str(self._version)}"
        else:
            # Otherwise, it is treated like normal libs
            prefix = ensure_getenv("PREFIX_BUILD")
            return f"{prefix}"


class LogLevel(Enum):
    VERBOSE = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
    NONE = 4


class Logger:
    print_level: LogLevel = LogLevel.WARNING

    def _print(self, fmt: str, level: LogLevel, color: Fore, sep: str = " ", **kwargs):
        if level.value >= self.print_level.value:
            print(
                color + f"{level.name}: " + Style.RESET_ALL + fmt,
                file=sys.stderr,
                **kwargs,
            )

    def set_level(self, n: LogLevel) -> None:
        self.print_level = n

    def debug(self, *fmt: object, sep: str = " ", **kwargs) -> None:
        self._print(
            sep.join(map(str, fmt)), level=LogLevel.VERBOSE, color=Fore.GREEN, **kwargs
        )

    def info(self, *fmt: object, sep: str = " ", **kwargs) -> None:
        self._print(
            sep.join(map(str, fmt)), level=LogLevel.INFO, color=Fore.CYAN, **kwargs
        )

    def warning(self, *fmt: object, sep: str = " ", **kwargs) -> None:
        self._print(
            sep.join(map(str, fmt)), level=LogLevel.WARNING, color=Fore.YELLOW, **kwargs
        )

    def error(self, *fmt: object, sep: str = " ", **kwargs) -> None:
        self._print(
            sep.join(map(str, fmt)), level=LogLevel.ERROR, color=Fore.RED, **kwargs
        )


logger = Logger()


class MyReporter(resolvelib.BaseReporter):
    _redo = False

    def __init__(self, provider) -> None:
        self.provider = provider

    @property
    def redo(self) -> bool:
        res = self._redo
        self._redo = False
        return res

    def ending(self, state: resolvelib.structs.State[RT, CT, KT]) -> None:
        logger.debug("ending", state)

    def adding_requirement(self, requirement: RT, parent: CT | None) -> None:
        logger.debug("adding a requirement:", requirement, "parent:", parent)

    def rejecting_candidate(
        self, criterion: resolvelib.structs.Criterion[RT, CT], candidate: CT
    ) -> None:
        for req_info in criterion.information:
            req, parent = req_info.requirement, req_info.parent
            if isinstance(req, OptionalRequirement):
                logger.debug(
                    f"{parent} optional requirement for {
                        req} unsatisfiable, dropping"
                )
                self._redo = True
                self.provider.mask_optional(req)
            else:
                logger.debug(f"{parent} requirement for {req} unsatisfiable")


class DependencyManager:
    def __init__(self) -> None:
        self.candidates: dict[str, dict[str, Candidate]] = dict()
        self.mapping: dict[str, dict[str, Candidate]] = dict()
        self.db_path = None

    CANDIDATES_FILE = "ports.json"
    TREE_FILE = "mapping.json"

    def get_db_file_path(self, filename: str) -> str:
        if not self.db_path:
            raise ValueError("db path empty")
        return os.path.join(self.db_path, filename)

    def set_db_path(self, path: str):
        if path:
            if path and os.path.exists(path) and not os.path.isfile(path):
                raise ValueError(f"not a file: {path}")
            self.db_path = path

    # WARN: this db I/O are obviously not concurrent-safe. if you plan to
    # run the script concurrently, implement some sort of db file lock
    # mechanism
    # TODO: The db format should probably be optimized for performance and size
    def read_candidates(self) -> None:
        path = self.db_path
        if path and os.path.exists(path):
            with open(path, "r") as f:
                (self.candidates, self.mapping) = jsonpickle.decode(f.read())

    def write_candidates(self) -> None:
        path = self.db_path
        if path:
            with open(path, "w+") as f:
                json_text = jsonpickle.encode(
                    (self.candidates, self.mapping), indent=2)
                f.write(json_text)

    def add_candidate(self, candidate: Candidate) -> None:
        name = candidate.name
        version = str(candidate.version)
        if name not in self.candidates:
            self.candidates[name] = dict()

        self.candidates[name][version] = candidate

        logger.debug(
            f"added {candidate} reqs={
                list(candidate.iter_dependencies())}"
        )

        logger.debug(f"self.candidates={self.candidates}")

    def lookup_candidate(
        self, name: str, version: PhxVersion, candidate_type: type | None = None
    ) -> Candidate:
        candidate = self.candidates[name][str(version)]
        if candidate_type:
            if not isinstance(candidate, candidate_type):
                raise TypeError(f"{candidate} is not of type {candidate_type}")
        return candidate

    def cmd_discover(self, args: Namespace) -> None:
        self.read_candidates()

        def safe_join(s):
            return " ".join(s) if s else ""

        name, version = parse_namever(args.namever)

        req = parse_requirements(safe_join(args.requires), BaseRequirement)
        req += parse_requirements(safe_join(args.optional),
                                  OptionalRequirement)

        conflicts = parse_requirements(
            safe_join(args.conflicts),
            lambda rname, constraints: ConflictRequirement(
                name, rname, constraints),
        )

        self.add_candidate(
            InstallableCandidate(name, version, req, conflicts, args.def_dir)
        )

        self.write_candidates()

    def cmd_resolve(self, args: Namespace) -> None:
        self.read_candidates()

        user_requirements = dict()

        for namever in args.namevers:
            name, version = parse_namever(namever)
            user_requirements[namever] = BaseRequirement(
                name, [("==", version)])

        provider = PhxProvider(self.candidates)
        reporter = MyReporter(provider)

        prev_candidates = self.candidates

        while True:
            try:
                resolver = resolvelib.Resolver(provider, reporter)
                for namever, ureq in user_requirements.items():
                    logger.debug("resolving", ureq)
                    result = resolver.resolve([ureq])
                    self.mapping[namever] = result.mapping
                logger.debug(self.mapping)
                self.candidates = prev_candidates
                break
            except resolvelib.resolvers.ResolverException as e:
                logger.error(type(e).__name__)
                if not reporter.redo:
                    self.candidates = prev_candidates
                    raise

        self.write_candidates()

    def cmd_query(self, args: Namespace) -> None:
        self.read_candidates()

        def print_candidate(candidate: Candidate, indent=0):
            def iprint(*args):
                print(indent * " " + " ".join(map(str, args)))

            iprint("name:", name)
            iprint("version:", candidate.version)
            iprint("requirements:", candidate.iter_dependencies())
            iprint("conflicts:", candidate.iter_conflicts())
            iprint("definition directory:", candidate.definition_path)
            namever = f"{name}-{candidate.version}"
            if namever in self.mapping:
                iprint("mapping:", self.mapping[namever])
            if isinstance(candidate, InstallableCandidate):
                iprint("installed:", candidate.installed)
                iprint("install path:", candidate.install_path)
        try:
            match args.args:
                case ["summary"]:
                    namevers = []
                    for name, versions in self.candidates.items():
                        for candidate in versions.values():
                            if isinstance(candidate, InstallableCandidate) and candidate.installed:
                                namevers.append(f"{name}-{candidate.version}")
                    print(" ".join(namevers))
                case ["all"]:
                    next = False
                    for name, versions in self.candidates.items():
                        for candidate in versions.values():
                            if next:
                                print("")
                            print_candidate(candidate)
                            next = True
                case ["pkg", namever]:
                    name, version = parse_namever(namever)
                    candidate = self.lookup_candidate(name, version)
                    print_candidate(candidate)
                case ["name", namever]:
                    name, version = parse_namever(namever)
                    candidate = self.lookup_candidate(name, version)
                    print(candidate.name)
                case ["is-installed", namever]:
                    name, version = parse_namever(namever)
                    candidate = self.lookup_candidate(
                        name, version, candidate_type=InstallableCandidate
                    )
                    sys.exit(0 if candidate.installed else 1)
                case ["install-path", namever]:
                    name, version = parse_namever(namever)
                    candidate = self.lookup_candidate(
                        name, version, candidate_type=InstallableCandidate
                    )
                    print(candidate.install_path)
                case ["deps-to-install", namever]:
                    name, version = parse_namever(namever)
                    candidate = self.lookup_candidate(
                        name, version, candidate_type=InstallableCandidate
                    )
                    logger.debug(self.mapping)
                    for dep in candidate.iter_dependencies():
                        dep_candidate = self.mapping[namever][dep.name]
                        if not dep_candidate.installed:
                            print(dep_candidate.definition_path)
                case ["dep-install-path", namever, dep_name]:
                    print(self.mapping[namever][dep_name].install_path)
                case []:
                    logger.error("""Must pass query arguments.
Examples:
    query summary
    query pkg busybox-1.27.2
Possible queries:
    summary
    all
    {pkg,name,is-installed,install-path,deps-to-install} <namever>
    dep-install-path <namever> <dep_name>""")
                    sys.exit(1)
                case _ as arg:
                    logger.error(f"unrecognized arguments: {" ".join(arg)}")
                    sys.exit(1)
        except KeyError as e:
            logger.error(
                f"package/dependency unrecognized: {e}"
                + " - hint: did you run 'resolve' command before querying?"
            )
            sys.exit(1)

    def cmd_installed(self, args: Namespace) -> None:
        self.read_candidates()

        name, version = parse_namever(args.namever)
        candidadate = self.lookup_candidate(name, version)

        if isinstance(candidadate, InstallableCandidate):
            candidadate.mark_as_installed()
            logger.info(f"{candidadate} marked as installed")
        else:
            raise ValueError(f"{candidadate} is not installable")

        self.write_candidates()

    def build_argument_parser(self) -> ArgumentParser:
        parser = ArgumentParser()

        namever_help = "e.g. 'foo-1.2'"

        parser.add_argument("--db", help="specify database directory")
        parser.add_argument("-v", action="store_true")
        parser.add_argument("--quiet", action="store_true")

        subparsers = parser.add_subparsers(title="subcommands")
        discover = subparsers.add_parser(
            "discover", help="add port to dep tree")
        discover.add_argument("namever", help=namever_help)
        discover.set_defaults(func=self.cmd_discover)

        discover.add_argument("--def-dir", help="add port def dir")
        discover.add_argument(
            "--requires", nargs="*", help="add dependencies to the discovered port"
        )
        discover.add_argument(
            "--optional",
            nargs="*",
            help="add optional dependencies to the discovered port",
        )
        discover.add_argument(
            "--conflicts", nargs="*", help="add conflicts to the discovered port"
        )

        resolve = subparsers.add_parser(
            "resolve", help="perform dependency resolution")
        resolve.add_argument("namevers", nargs="*", help=namever_help)
        resolve.set_defaults(func=self.cmd_resolve)

        resolve.add_argument(
            "--optional", help="resolve as optional", action="store_true"
        )

        installed = subparsers.add_parser(
            "installed", help="mark port as installed")
        installed.add_argument("namever", help=namever_help)
        installed.set_defaults(func=self.cmd_installed)

        query = subparsers.add_parser("query", help="query port information")
        query.add_argument("args", nargs="*")
        query.set_defaults(func=self.cmd_query)

        return parser

    def parse_arguments(self, argv: Sequence[str]) -> Namespace:
        parser = self.build_argument_parser()
        if len(argv) == 1:
            parser.print_help()
        args = parser.parse_args(argv[1:])

        logger.set_level(LogLevel.INFO)

        if args.v:
            logger.set_level(LogLevel.VERBOSE)
        if args.quiet:
            logger.set_level(LogLevel.NONE)

        return args

    def run(self, argv: Sequence[str]) -> None:
        args = self.parse_arguments(argv)
        if "func" in args:
            self.set_db_path(args.db)
            args.func(args)


def main():
    dm = DependencyManager()
    dm.run(sys.argv)


if __name__ == "__main__":
    main()
