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

## Switch and update the master branch
```
git switch master
git pull -r
```
Do whatever changes needed in the code (possibly merging a branch or a pull request).
Commit.

## Update changelog
Edit the `CHANGES` file.
Commit.

## Bump version
Edit the `lib/kameleon/version.rb` file and bump the version.
Commit:
```
git commit -m "v2.10.16 → v.2.10.17" lib/kameleon/version.rb
```

## Build gem
```
gem build kameleon-builder.gemspec
```

## Test
Manually install:
```
gem install --user ./kameleon-builder-2.10.17.gem
```
Test, test, test.

## Tag
If everything is ok, tag:
```
git tag -s 'v2.10.17' -m 'v2.10.17'
```

## Push git push
```
git push
```


## Push to Ruby gem repository
```
gem push kameleon-builder-2.10.17.gem
```

Note: You need a rubygem account and the owner has to give you permissions so that you can push.
To do so, create an account on https://rubygems.org/ and ask an owner to do
the following command::

```
gem owner kameleon-builder -a your@email.com
```

That's all :)

## In case a release is buggy
Yank it to remove it from the rubygems index.
```
gem yank kameleon-builder -v 2.10.16
```

For developments:
-----------------

Changes can be tested by locally installing the gem after building it:
```
gem build kameleon-builder.gemspec && gem install --user ./kameleon-builder-2.10.17.gem
```

Using git branches, github pull requests, aso, is of course good.
