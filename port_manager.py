#!/usr/bin/env python3
#
# Port dependency manager
#
# Copyright 2025 Phoenix Systems
# Author: Adam Greloch
#

import re
import argparse
import sys
import json
import os

from enum import Enum

# e.g. openssl>=1.1.1a ~> ['openssl', '>=', '1.1.1a"]
p = re.compile("(^[^<>=]+)([<>]=?|=)(.*)")


class AnsiColors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"


class LogLevel(Enum):
    DEBUG = 0
    INFO = 1
    WARNING = 2
    ERROR = 3
    NONE = 4


class Logger:
    print_level = LogLevel.WARNING

    def _print(self, fmt, level: LogLevel, color: AnsiColors):
        if level.value >= self.print_level.value:
            print(
                color + f"{level.name}: " + AnsiColors.ENDC + str(fmt), file=sys.stderr
            )

    def set_level(self, n):
        self.print_level = n

    def debug(self, fmt):
        self._print(fmt, LogLevel.DEBUG, AnsiColors.OKGREEN)

    def info(self, fmt):
        self._print(fmt, LogLevel.INFO, AnsiColors.OKCYAN)

    def warning(self, fmt):
        self._print(fmt, LogLevel.WARNING, AnsiColors.WARNING)

    def error(self, fmt):
        self._print(fmt, LogLevel.ERROR, AnsiColors.FAIL)


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
            logger.error(f"invalid rel: '{rel}'")
            exit(1)


def read_vargs(vargs):
    res = []
    for s in vargs:
        res += s.split()
    return res


class DependencyManager:
    ports = dict()

    # WARN: read_db/write_db are obviously not concurrent-safe. if you plan to
    # run the script concurrently, implement some sort of db file lock
    # mechanism
    def read_db(self, db_path):
        with open(db_path, "r") as f:
            try:
                self.ports = json.load(f)
            except json.decoder.JSONDecodeError:
                logger.warning("malformed db, not loading")

    def write_db(self, db_path):
        with open(db_path, "w+") as f:
            json_text = json.dumps(self.ports, indent=2)
            logger.debug(json_text)
            f.write(json_text)

    @staticmethod
    def split_name_ver(pkg_name_ver):
        return tuple(pkg_name_ver.split("-"))

    def parse_deps(self, deps):
        res = dict()
        for dep in deps:
            g = p.match(dep).groups()
            pkgname = g[0]
            if pkgname not in self.ports:
                logger.warning(f"unrecognized port: {pkgname}")

            rel = g[1]
            ver = g[2]
            res[pkgname] = (rel, ver)
        return res

    def discover_port(self, pkg_name, pkg_ver, port_def_dir, deps, opts):
        if pkg_name not in self.ports:
            self.ports[pkg_name] = dict()

        # TODO: handle incremental build
        parsed_deps = self.parse_deps(deps)
        parsed_opts = self.parse_deps(opts)
        self.ports[pkg_name][pkg_ver] = {
            "def_dir": port_def_dir,
            "deps": parsed_deps,
            "opts": parsed_opts,
            "installed": False,
        }
        logger.info(
            f"added port {
                pkg_name}-{pkg_ver} with deps: {parsed_deps} opts: {parsed_opts}"
        )

    def list_deps_to_install(self, pkg_name, pkg_ver, optional=False):
        deps = self.resolve_deps(pkg_name, pkg_ver, optional=optional)
        if deps is not None:
            for dep_name, dep_ver in deps.items():
                if not self.ports[dep_name][dep_ver]["installed"]:
                    logger.info(f"{dep_name}-{dep_ver} installed? no")
                    print(self.ports[dep_name][dep_ver]["def_dir"])
                else:
                    logger.info(f"{dep_name}-{dep_ver} installed? yes")

    def mark_as_installed(self, pkg_name, pkg_ver):
        self.ports[pkg_name][pkg_ver]["installed"] = True
        logger.info(f"{pkg_name}-{pkg_ver} marked as installed")

    def resolve_deps(self, pkg_name, pkg_ver, depth=0, optional=False):
        indent = depth * "  "

        deps_resolved = dict()

        if pkg_name not in self.ports or pkg_ver not in self.ports[pkg_name]:
            logger.error(indent + f"{pkg_name}-{pkg_ver} port unrecognized")
            return None

        deps = self.ports[pkg_name][pkg_ver]["deps"]
        opts = self.ports[pkg_name][pkg_ver]["opts"]

        if optional:
            deps |= opts

        if not deps:
            logger.debug(indent + f"{pkg_name}-{pkg_ver} has no deps")
            return dict()

        logger.debug(indent + f"resolving {pkg_name}-{pkg_ver} deps")

        for dep in deps.items():
            dep_name, (rel, dep_ver) = dep
            found = False

            logger.debug(indent + f"need {(dep_name, (rel, dep_ver))}")

            if dep_name not in self.ports:
                logger.error(
                    indent + f"{dep_name} not found in available ports")
                return None

            for candidate_ver in self.ports[dep_name].keys():
                logger.debug(indent + f"{dep_name}-{candidate_ver} ok?")
                if compare_versions_lex(candidate_ver, rel, dep_ver):
                    dep_deps = self.resolve_deps(
                        dep_name, candidate_ver, depth + 1)
                    if dep_deps is None:
                        return None
                    logger.debug(indent + f"{dep_name}-{candidate_ver} OK")

                    deps_resolved |= dep_deps
                    deps_resolved[dep_name] = candidate_ver

                    found = True
                    break
                else:
                    logger.debug(indent + f"{dep_name}-{candidate_ver} BAD")

            if not found:
                if dep_name in opts:
                    logger.warning(
                        indent + f"optional dependency {dep} not satisfiable"
                    )
                else:
                    logger.error(indent + f"dependency {dep} not satisfiable")
                    return None

        logger.info(
            indent + f"{pkg_name}-{pkg_ver} satisfiable: {deps_resolved}")
        return deps_resolved

    def run(self, args):
        db_path = args["db"]
        update_db = False
        optional = args["optional"]

        if db_path and os.path.isfile(db_path):
            self.read_db(db_path)

        if args["list_deps_to_install"]:
            namever = args["list_deps_to_install"]
            (pkg_name, pkg_ver) = DependencyManager.split_name_ver(namever)
            self.list_deps_to_install(pkg_name, pkg_ver, optional)

        if args["mark_as_installed"]:
            namever = args["mark_as_installed"]
            (pkg_name, pkg_ver) = DependencyManager.split_name_ver(namever)
            self.mark_as_installed(pkg_name, pkg_ver)
            update_db = True

        if args["is_installed"]:
            namever = args["is_installed"]
            (pkg_name, pkg_ver) = DependencyManager.split_name_ver(namever)
            if self.ports[pkg_name][pkg_ver]["installed"]:
                exit(0)
            else:
                exit(1)

        if args["discover_port"]:
            namever = args["discover_port"]
            port_def_dir = args["def_dir"]

            deps = read_vargs(args["add_depends"])
            opts = read_vargs(args["add_optional"])

            (pkg_name, pkg_ver) = DependencyManager.split_name_ver(namever)
            self.discover_port(pkg_name, pkg_ver, port_def_dir, deps, opts)

            if args["check_deps"]:
                deps = self.resolve_deps(pkg_name, pkg_ver, 0)
                if deps is None:
                    exit(1)

            update_db = True

        if args["resolve_dep"]:
            (pkg, dep) = args["resolve_dep"]
            (pkg_name, pkg_ver) = DependencyManager.split_name_ver(pkg)

            deps = self.resolve_deps(pkg_name, pkg_ver, 0, optional)
            if deps is None:
                if not optional:
                    exit(1)
            else:
                if args["build_prefix"]:
                    dep_ver = deps[dep]
                    print(f"{args['build_prefix']}/{dep}-{dep_ver}")

        if update_db and db_path:
            logger.debug(f"saved {db_path}")
            self.write_db(db_path)


def main():
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
        "--check-deps", help="Check if all deps are resolvable", action="store_true"
    )

    parser.add_argument("--list-deps-to-install")

    parser.add_argument("--mark-as-installed")
    parser.add_argument("--is-installed")

    parser.add_argument("--db", help="Read/write port database from file")

    parser.add_argument("--resolve-dep", nargs=2,
                        help="Resolve port dependency")
    parser.add_argument(
        "--optional", help="Enable optional dependencies", action="store_true"
    )
    parser.add_argument(
        "--build-prefix", help="Path to build prefix to base the dependencies at"
    )

    parser.add_argument("-v", action="store_true")
    parser.add_argument("-vv", action="store_true")
    parser.add_argument("--quiet", action="store_true")

    args = vars(parser.parse_args())

    if len(sys.argv) == 1:
        parser.print_help()

    if args["v"]:
        logger.set_level(LogLevel.INFO)

    if args["vv"]:
        logger.set_level(LogLevel.DEBUG)

    if args["quiet"]:
        logger.set_level(LogLevel.NONE)

    logger.debug(f"{args=}")

    pm = DependencyManager()

    pm.run(args)


if __name__ == "__main__":
    main()
