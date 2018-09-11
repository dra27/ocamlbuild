# OCamlbuild #

OCamlbuild is a generic build tool, that has built-in rules for
building OCaml library and programs.

OCamlbuild was distributed as part of the OCaml distribution for OCaml
versions between 3.10.0 and 4.02.3. Starting from OCaml 4.03, it is
now released separately.

Your should refer to the [OCambuild
manual](https://github.com/ocaml/ocamlbuild/blob/master/manual/manual.adoc)
for more informations on how to use ocamlbuild.

## Automatic Installation ##

With [opam](https://opam.ocaml.org/):

```
opam install ocamlbuild
```

If you are testing a not yet released version of OCaml, you may need
to use the development version of OCamlbuild. With opam:

```
opam pin add ocamlbuild --kind=git "https://github.com/ocaml/ocamlbuild.git#master"
```

## Compilation from source ##

Compilation requires Dune and cppo.

1. Configure.

The installation location is determined by the installation location
of the ocaml compiler. You can set the following configuration
variables by writing to files in `src/`:

- bindir.probed specifies where ocamlbuild will be installed. It defaults
  to either `opam config var bin` or the directory where ocaml is found.

- libdir.probed specifies the directory to which the ocamlbuild libraries
  should be installed and is either `opam config var lib`,
  `ocamlfind printconf destdir` or `ocamlc -where`.

- native.probed should contain `true` if native compilation is available
  on your machine, `false` otherwise.

2. Compile the sources.
```
dune build @install
```

3. Install.
```
opam-installer ocamlbuild.install
```
