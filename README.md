# Runtimes Ruby

The Ruby that TextMate's bundle commands run on, and the Ruby a project asks for. A mandatory bundle, seeded into the application and updated through the catalog, so the machinery here moves without an application release.

Ruby is not optional. Every bundle's support library is Ruby, and an application whose Ruby is missing is one where most commands fail. That is why this bundle carries [rv](https://rv.dev), Spinel's Ruby manager, rather than asking a person to install one.

TextMate names one Ruby version, the one its bundle support is tested on, and this bundle finds or installs it through rv, which carries prebuilt Rubies. The application's own copy of `rv` lives in `Support/bin`, and a person's own `rv` is preferred when they have one, so what TextMate installs shows up in their list. The system Ruby is never used, which the application enforces on its side.

The protocol both these scripts answer in is described in the [Runtimes](https://github.com/textmate3/runtimes.tmbundle) bundle, which this one depends on.

## Support/bin

- `rv`: Spinel's release for Apple silicon, with its licenses under `Support/licenses` and its version in `Support/VERSIONS`.
- `ruby_runtime <version>`: the Ruby for bundle commands. Finds the version wherever rv looks, installs it through rv when absent, and stands in with the newest of its major series when the install cannot happen. It answers with a directory rather than an interpreter, the directory whose `bin/ruby` it is.
- `project_ruby <directory>`: the Ruby a project pins, through `rv ruby find` in that directory, or `missing <version>` when the pin names one that is not installed, or `none` when nothing is pinned.

Both scripts hand rv the directories of the other managers, rbenv, asdf and mise, on top of the `~/.rubies` it reads by itself.

## Tests

From the bundle's directory:

```sh
ruby Support/tests/ruby_runtime_tests.rb
```

The tests run the scripts against a stand-in `rv` under `Support/tests/fixtures`, so they need no network and touch no real Ruby.
