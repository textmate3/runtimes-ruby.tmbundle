# Runtimes

The runtimes that TextMate's bundle commands run on, and the Ruby a project asks for. A mandatory bundle, seeded into the application and updated through the catalog, so the machinery here moves without an application release.

Ruby is settled and Python is a spike. Each language has its own manager and its own resolver, and they run independently: a machine set up for one and not the other works.

TextMate names one Ruby version, the one its bundle support is tested on, and this bundle finds or installs it through [rv](https://rv.dev), Spinel's Ruby manager, which carries prebuilt Rubies. The application's own copy of `rv` lives in `Support/bin`, and a person's own `rv` is preferred when they have one, so what TextMate installs shows up in their list. The system Ruby is never used, which the application enforces on its side.

## Support/bin

- `rv`: Spinel's release for Apple silicon, with its licenses under `Support/licenses`.
- `ruby_runtime <version>`: the Ruby for bundle commands. Finds the version wherever rv looks, installs it through rv when absent, and stands in with the newest of its major series when the install cannot happen. Answers on standard output, one word per line then its arguments:
  - `ruby <directory>`: the Ruby to use, the directory whose `bin/ruby` it is.
  - `installed <version> <directory>`: an install happened first.
  - `fallback <directory> <reason>`: not the version asked for.
  - `error <message>`: nothing to run on.
- `project_ruby <directory>`: the Ruby a project pins, through `rv ruby find` in that directory, or `missing <version>` when the pin names one that is not installed, or `none` when nothing is pinned.

Both scripts hand rv the directories of the other managers, rbenv, asdf and mise, on top of the `~/.rubies` it reads by itself.

- `python_runtime <version>`: the Python for bundle commands, through [uv](https://docs.astral.sh/uv/). The same protocol with `python` in place of `ruby`, and one difference: it answers with the interpreter rather than a directory, because `uv python find` does and because a Python's layout varies more than a Ruby's.

  Every lookup passes `--managed-python`, so only uv's own installs can be answered with. This is the one place the two languages genuinely differ. rv does not know the system Ruby, so the Ruby resolver could not reach it by accident. uv finds `/usr/bin/python3` and Xcode's copy readily, so the system Python has to be excluded on purpose.

  A person's own `uv` is preferred over the bundle's, the way rv is. No `uv` is carried here yet, so this works where uv is already installed.

## Tests

From the bundle's directory:

```sh
ruby Support/tests/ruby_runtime_tests.rb
ruby Support/tests/python_runtime_tests.rb
```

The tests run the scripts against stand-in `rv` and `uv` under `Support/tests/fixtures`, so they need no network and touch no real runtime. The uv stub answers an unmanaged Python when `--managed-python` is absent, so a resolver that forgets the flag fails the tests the way the real uv would succeed: with a system Python.
