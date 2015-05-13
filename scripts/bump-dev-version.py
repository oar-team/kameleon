#!/usr/bin/env python
# coding: utf-8
from __future__ import unicode_literals, print_function
import argparse
import re
import os
import subprocess


def generate_changelog_title(version):
    version_title = "Version %s" % version
    return version_title + "\n" + "-" * len(version_title)


def bump_dev_version(part='patch'):
    """ Increment the version number to the next development version

    * (Configurably) bumps the development dev version number
    * Preloads the correct changelog template for editing

    You can run it like::

        $ python scripts/next_release.py

    which, by default, will create a 'patch' dev version (0.0.1 => 0.0.2-dev).

    You can also specify a patch level (patch, minor, major) to change to::

        $ python scripts/make_release.py major

    which will create a 'major' release (0.0.2 => 1.0.0-dev).

    """

    # Dry run 'bumpversion' to find out what the new version number
    # would be. Useful side effect: exits if the working directory is not
    # clean.

    bumpver = subprocess.check_output(
        ['bumpversion', part, '--dry-run', '--verbose'],
        stderr=subprocess.STDOUT)
    m = re.search(r'Parsing version \'(\d+\.\d+\.\d+)\'', bumpver)
    current_version = m.groups(0)[0]
    m = re.search(r'New version will be \'(\d+\.\d+\.\d+)\.dev\'', bumpver)
    next_version = m.groups(0)[0] + ".dev"

    current_version_title = generate_changelog_title(current_version)
    next_version_title = generate_changelog_title(next_version)

    next_release_template = "%s\n\n**unreleased**\n\n" % next_version_title

    changes = ""
    with open('CHANGES') as fd:
        changes += fd.read()

    changes = changes.replace(current_version_title,
                              next_release_template + current_version_title)

    with open('CHANGES', "w") as fd:
            fd.write(changes)

    # Tries to load the EDITOR environment variable, else falls back to vim
    editor = os.environ.get('EDITOR', 'vim')
    os.system("{} CHANGES".format(editor))

    subprocess.check_output(['python', 'setup.py', 'sdist'])

    # Have to add it so it will be part of the commit
    subprocess.check_output(['git', 'add', 'CHANGES'])
    subprocess.check_output(
        ['git', 'commit', '-m', 'Changelog for {}'.format(next_version)])

    # Really run bumpver to set the new release and tag
    bv_args = ['bumpversion', part, '--no-tag', '--new-version', next_version]

    subprocess.check_output(bv_args)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=bump_dev_version.__doc__,
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("part", help="Part of the version to be bumped",
                        choices=["patch", "minor", "major"])
    args = parser.parse_args()
    bump_dev_version(args.part)
