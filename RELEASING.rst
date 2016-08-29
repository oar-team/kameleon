You can use the script ``./scripts/bumpversion.py`` which will handle
everything (incrementation, git tag creation, changelog update).
First you need to install bumpversion using pip::

  sudo pip2 install bumpversion

Then for the actual releasing:

1) After each release, a new version has to be created (in this example, the 2.7.0 dev)::

  python2 ./scripts/bumpversion.py newversion minor  # 2.6.7 -> 2.7.0.dev

2) [work/commit] 
3) **Warning:** Be sure that there is no dirty file (not committed) before
   doing this.

   Releasing a new version::

  python2 ./scripts/bumpversion.py release  # 2.7.0.dev -> 2.7.0 + git tag + changelog
  gem build kameleon-builder.gemspec
  gem push kameleon-builder-2.7.0.gem

You need a rubygem account and I have to give you permissions so that you can push.
