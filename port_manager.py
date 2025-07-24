#!/usr/bin/env python3
#
# Port dependency manager
#
# Copyright 2025 Phoenix Systems
# Author: Adam Greloch
#

import re
import fnmatch
import argparse
import sys
import json
import os
from colorama import Fore, Style

from enum import Enum

# TODO: what about openssl>=1.1.1a<3.0.0 ? do we care?
# captures e.g. openssl>=1.1.1a ~> ['openssl', '>=', '1.1.1a"]
p = re.compile("(^[^<>=]+)([<>=]+)(.*)")


class LogLevel(Enum):
    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
    NONE = 4


class Logger:
    print_level = LogLevel.WARNING

    def _print(self, fmt, level: LogLevel, color: Fore):
        if level.value >= self.print_level.value:
            print(
                color + f"{level.name}: " + Style.RESET_ALL + str(fmt), file=sys.stderr
            )

    def set_level(self, n):
        self.print_level = n

    def debug(self, fmt):
        self._print(fmt, LogLevel.DEBUG, Fore.GREEN)

    def info(self, fmt):
        self._print(fmt, LogLevel.INFO, Fore.CYAN)

    def warning(self, fmt):
        self._print(fmt, LogLevel.WARNING, Fore.YELLOW)

    def error(self, fmt):
        self._print(fmt, LogLevel.ERROR, Fore.RED)


logger = Logger()


def compare_versions_lex(ver1, rel, ver2):
    match rel:
        case ">=":
            return ver1 >= ver2
        case "<=":
            return ver1 <= ver2
        case "=":
            return ver1 == ver2
        case ">":
            return ver1 > ver2
        case "<":
            return ver1 < ver2
        case _:
            sys.exit(f"invalid rel: '{rel}'")


def read_vargs(vargs):
    if vargs is None:
        return None
    res = []
    for s in vargs:
        res += s.split()
    return res


class DependencyManager:
    def __init__(self):
        self.ports = dict()

    # WARN: read_db/write_db are obviously not concurrent-safe. if you plan to
    # run the script concurrently, implement some sort of db file lock
    # mechanism
    def read_db(self, db_path):
        with open(db_path, "r") as f:
            try:
                self.ports = json.load(f)
            except json.decoder.JSONDecodeError:
                sys.exit(f"malformed db: {db_path}")

    def write_db(self, db_path):
        with open(db_path, "w+") as f:
            json_text = json.dumps(self.ports, indent=2)
            logger.debug(json_text)
            f.write(json_text)

    @staticmethod
    def split_namever(port_name_ver):
        s = port_name_ver.split("-")
        if len(s) != 2:
            sys.exit(f"bad namever: {port_name_ver}")
        return tuple(port_name_ver.split("-"))

    def parse_deps(self, deps):
        if deps is None:
            return dict()
        res = dict()
        for dep in deps:
            cap = p.match(dep)
            if cap is None:
                sys.exit(f"bad dep: '{dep}'")
            g = p.match(dep).groups()
            pkgname = g[0]
            if pkgname not in self.ports:
                logger.warning(f"unrecognized port: {pkgname}")

            rel = g[1]
            ver = g[2]

            # check relation correctness
            compare_versions_lex(ver, rel, ver)

            res[pkgname] = (rel, ver)
        return res

    def conflicts_with(self, port_name, conflicts):
        if conflicts is None:
            return False
        for conflict in conflicts:
            if fnmatch.fnmatch(port_name, conflict):
                return True
        return False

    def discover_port(self, port_name, port_ver, port_def_dir, deps, opts,
                      conflicts=[]):
        if port_name not in self.ports:
            self.ports[port_name] = dict()

        # ensure port is not conflicting with itself
        if self.conflicts_with(port_name, conflicts):
            sys.exit(
                f"{port_name}-{port_ver} conflicts with itself: {conflicts}")

        # TODO: handle incremental build?
        parsed_deps = self.parse_deps(deps)
        parsed_opts = self.parse_deps(opts)
        self.ports[port_name][port_ver] = {
            "def_dir": port_def_dir,
            "deps": parsed_deps,
            "opts": parsed_opts,
            "installed": False,
            "conflicts": conflicts,
        }
        logger.info(
            f"added port {
                port_name}-{port_ver} with deps: {parsed_deps} opts: {parsed_opts}"
        )

    def get_port(self, name, ver):
        try:
            return self.ports[name][ver]
        except KeyError:
            sys.exit(f"{name}-{ver} not recognized")

    def list_deps_to_install(self, port_name, port_ver, optional=False):
        deps = self.resolve_deps(port_name, port_ver, optional=optional)
        if deps is not None:
            for dep_name, dep_ver in deps.items():
                port = self.get_port(dep_name, dep_ver)
                if not port["installed"]:
                    logger.info(f"{dep_name}-{dep_ver} installed? no")
                    print(port["def_dir"])
                else:
                    logger.info(f"{dep_name}-{dep_ver} installed? yes")

    def mark_as_installed(self, port_name, port_ver):
        self.ports[port_name][port_ver]["installed"] = True
        logger.info(f"{port_name}-{port_ver} marked as installed")

    def resolve_deps(self, port_name, port_ver, depth=0, optional=False):
        indent = depth * "  "

        deps_resolved = dict()

        port = self.get_port(port_name, port_ver)
        deps = port["deps"].copy()
        opts = port["opts"]

        if optional:
            deps |= opts

        if not deps:
            logger.debug(indent + f"{port_name}-{port_ver} has no deps")
            return dict()

        logger.debug(indent + f"resolving {port_name}-{port_ver} deps")

        for dep in deps.items():
            dep_name, (rel, dep_ver) = dep
            found = False

            logger.debug(indent + f"need {(dep_name, (rel, dep_ver))}")

            if dep_name not in self.ports:
                if opts and dep_name in opts:
                    logger.warning(
                        indent + f"optional dependency {dep} not satisfiable"
                    )
                    continue
                else:
                    sys.exit(f"{dep_name} not found in available ports")

            for candidate_ver in self.ports[dep_name].keys():
                logger.debug(indent + f"{dep_name}-{candidate_ver} ok?")
                if compare_versions_lex(candidate_ver, rel, dep_ver):
                    dep_deps = self.resolve_deps(
                        dep_name, candidate_ver, depth + 1)
                    logger.debug(indent + f"{dep_name}-{candidate_ver} OK")

                    deps_resolved |= dep_deps
                    deps_resolved[dep_name] = candidate_ver

                    found = True
                    break
                else:
                    logger.debug(indent + f"{dep_name}-{candidate_ver} BAD")

            if not found:
                sys.exit(f"dependency {dep} not satisfiable")

        logger.info(
            indent + f"{port_name}-{port_ver} satisfiable: {deps_resolved}")
        return deps_resolved

    @staticmethod
    def ensure_getenv(var):
        prefix = os.getenv(var)
        if prefix is None:
            sys.exit(f"{var} undefined")
        return prefix

    def get_install_path(self, port_name, port_ver):
        port = self.get_port(port_name, port_ver)

        # If port is conflictable, it has a special installation
        # directory. Otherwise it is treated like normal libs
        if port['conflicts']:
            prefix = DependencyManager.ensure_getenv("PREFIX_BUILD_VERSIONED")
            return f"{prefix}/{port_name}-{port_ver}"
        else:
            prefix = DependencyManager.ensure_getenv("PREFIX_BUILD")
            return f"{prefix}"

    def parse_args(self, argv):
        parser = DependencyManager.get_arg_parser()
        if len(argv) == 1:
            parser.print_help()
        args = parser.parse_args(argv[1:])

        if args.v:
            logger.set_level(LogLevel.INFO)
        if args.vv:
            logger.set_level(LogLevel.DEBUG)
        if args.quiet:
            logger.set_level(LogLevel.NONE)

        logger.debug(f"{args=}")
        return args

    def run(self, argv):
        logger.debug(self.ports)
        args = self.parse_args(argv)

        db_path = args.db
        optional = args.optional
        update_db = False

        if db_path and os.path.isfile(db_path):
            self.read_db(db_path)

        if args.list_deps_to_install:
            namever = args.list_deps_to_install
            (port_name, port_ver) = DependencyManager.split_namever(namever)
            self.list_deps_to_install(port_name, port_ver, optional)

        if args.mark_as_installed:
            namever = args.mark_as_installed
            (port_name, port_ver) = DependencyManager.split_namever(namever)
            self.mark_as_installed(port_name, port_ver)
            update_db = True

        if args.is_installed:
            namever = args.is_installed
            (port_name, port_ver) = DependencyManager.split_namever(namever)
            if self.ports[port_name][port_ver]["installed"]:
                exit(0)
            else:
                exit(1)

        if args.discover_port:
            namever = args.discover_port
            port_def_dir = args.def_dir

            deps = read_vargs(args.add_depends)
            opts = read_vargs(args.add_optional)
            conflicts = read_vargs(args.add_conflicts)

            (port_name, port_ver) = DependencyManager.split_namever(namever)
            self.discover_port(port_name, port_ver, port_def_dir, deps, opts,
                               conflicts)

            update_db = True

        if args.get_install_path:
            (port_name, port_ver) = DependencyManager.split_namever(
                args.get_install_path)
            print(self.get_install_path(port_name, port_ver))

        if args.resolve_dep:
            (port_namever, dep_name) = args.resolve_dep
            (port_name, port_ver) = DependencyManager.split_namever(port_namever)

            deps = self.resolve_deps(port_name, port_ver, 0, optional)
            if dep_name not in deps:
                sys.exit(f"{dep_name} {"optional" if optional else ""} dependency for {port_namever} unsatisfiable")

            dep_ver = deps[dep_name]
            print(self.get_install_path(dep_name, dep_ver))

        if update_db and db_path:
            logger.debug(f"saved {db_path}")
            self.write_db(db_path)

    @staticmethod
    def get_arg_parser():
        parser = argparse.ArgumentParser(description="Port dependency manager")
        parser.add_argument("--discover-port", help="Add port to dep tree")
        parser.add_argument("--def-dir", help="Add port def dir")
        parser.add_argument(
            "--add-depends", nargs="*", help="Add dependencies to the discovered port"
        )
        parser.add_argument(
            "--add-optional",
            nargs="*",
            help="Add optional dependencies to the discovered port",
        )
        parser.add_argument(
            "--add-conflicts", nargs="*", help="Add conflicts to the discovered port"
        )

        parser.add_argument("--resolve-dep", nargs=2,
                            help="Resolve port dependency")
        parser.add_argument(
            "--optional", help="Enable optional dependencies", action="store_true"
        )

        parser.add_argument("--list-deps-to-install")

        parser.add_argument("--mark-as-installed")
        parser.add_argument("--is-installed")

        parser.add_argument("--db", help="Read/write port database from file")

        parser.add_argument("--get-install-path", help="Get port install path")

        parser.add_argument("-v", action="store_true")
        parser.add_argument("-vv", action="store_true")
        parser.add_argument("--quiet", action="store_true")

        return parser


def main():
    pm = DependencyManager()
    pm.run(sys.argv)


if __name__ == "__main__":
    main()
