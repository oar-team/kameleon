About releases:
===============
You can use the script ``./scripts/bumpversion.py`` which will handle
everything (incrementation, git tag creation, changelog update).
First you need to install bumpversion using pip::
```
sudo pip install bumpversion
```
Assuming work is done in the devel branch.

For stable releases:
--------------------

## Merge devel into master:
```
git checkout master
git merge devel
```

## Fix anything needed
Should be no conflict but...
Make sure changelog is up to date.

## Bump version
***Warning*** Make sure that there is no dirty file (not committed) before the following.
```
./scripts/bumpversion.py release  # will do 2.7.0.dev -> 2.7.0 + git tag + changelog
git push
```

## Build gem
```
gem build kameleon-builder.gemspec
```

## Push to Ruby gem repository
```
  gem push kameleon-builder-2.7.0.gem
```

Note: You need a rubygem account and the owner has to give you permissions so that you can push.
To do so, create an account on https://rubygems.org/ and ask an owner to do
the following command::

```
  gem owner kameleon-builder -a your@email.com
```

That's all :)

For devel releases:
-------------------

## Move to the devel branch and rebase on master
```
git checkout devel
git rebase master
```

## Prepare the new version 
Create the new devel version (e.g. 2.7.0 dev)
```
  ./scripts/bumpversion.py newversion patch  # 2.6.7 -> 2.7.0.dev
```

At this point, do work, commit, and so on.
And same as above to build "devel" gem and use them locally, or push them if really wanted.

Up to the time to build a new stable version.
