#!/usr/bin/env python
# coding: utf-8
from __future__ import unicode_literals, print_function
import os
import re

from io import open

import argparse
import datetime
import subprocess


def generate_changelog_title(version):
    version_title = "Version %s" % version
    return version_title + "\n" + "-" * len(version_title)


def get_release_date():
    dt = datetime.date.today()
    if 4 <= dt.day <= 20 or 24 <= dt.day <= 30:
        suffix = "th"
    else:
        suffix = ["st", "nd", "rd"][dt.day % 10 - 1]
    return dt.strftime("%%B %%d%s %%Y" % suffix)


def bumpversion():
    """ Automated software release workflow

    * (Configurably) bumps the release version number
    * Preloads the correct changelog template for editing
    * Builds a source distribution
    * Sets release date
    * Tags the release

    You can run it like::

        $ python scripts/bumpversion.py

    """

    # Dry run 'bumpversion' to find out what the new version number
    # would be. Useful side effect: exits if the working directory is not
    # clean.

    bumpver = subprocess.check_output(
        ['bumpversion', 'release', '--dry-run', '--verbose'],
        stderr=subprocess.STDOUT)
    m = re.search(r'Parsing version \'(\d+\.\d+\.\d+)\.dev\'', bumpver)
    current_version = m.groups(0)[0] + ".dev"
    m = re.search(r'New version will be \'(\d+\.\d+\.\d+)\'', bumpver)
    release_version = m.groups(0)[0]

    date = get_release_date()

    current_version_title = generate_changelog_title(current_version)
    release_version_title = generate_changelog_title(release_version)
    changes = ""
    with open('CHANGES') as fd:
        changes += fd.read()

    changes = changes.replace(current_version_title, release_version_title)\
                     .replace("**unreleased**", "Released on %s" % date)

    with open('CHANGES', "w") as fd:
            fd.write(changes)

    # Tries to load the EDITOR environment variable, else falls back to vim
    editor = os.environ.get('EDITOR', 'vim')
    os.system("{} CHANGES".format(editor))

    # Have to add it so it will be part of the commit
    subprocess.check_output(['git', 'add', 'CHANGES'])
    subprocess.check_output(
        ['git', 'commit', '-m', 'Changelog for {}'.format(release_version)])

    # Really run bumpver to set the new release and tag
    bv_args = ['bumpversion', 'release']

    bv_args += ['--new-version', release_version]

    subprocess.check_output(bv_args)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=bumpversion.__doc__,
        formatter_class=argparse.RawTextHelpFormatter
    )
    args = parser.parse_args()
    bumpversion()
