# sml-doc

> A pure Standard ML documentation generator emitting static HTML/Markdown.

[![CI](https://github.com/sjqtentacles/sml-doc/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-doc/actions)

A **documentation generator for Standard ML** built on the
[`sml-mlast`](https://github.com/sjqtentacles/sml-mlast) frontend and the
[`sml-html`](https://github.com/sjqtentacles/sml-html) renderer. It parses
`.sig`/`.sml` sources, extracts the documented items (signatures, structures,
functors and their `val`/`type`/`datatype`/`exception` members) along with
`(** ... *)` doc-comments, and emits a static HTML or Markdown index. Pure SML,
byte-identical under [MLton](http://mlton.org/) and
[Poly/ML](https://www.polyml.org/).

```sml
val html = Doc.renderString
  { title = "my-pkg", files = [("ord.sig", source)] }

Doc.render { root = "src", out = "doc/index.html" }   (* whole directory *)
```

## Install (smlpkg)

```sh
smlpkg add github.com/sjqtentacles/sml-doc
```

or add it to your package's `sml.pkg`:

```
require {
  github.com/sjqtentacles/sml-doc
}
```

## API

```sml
type item  = { kind : string, name : string, detail : string, doc : string }
type modul = { kind : string, name : string, doc : string, items : item list }

val modules        : string -> modul list
val renderString   : { title : string, files : (string * string) list } -> string
val markdownString : { title : string, files : (string * string) list } -> string
val render         : { root : string, out : string } -> unit
```

The pure core (`modules`, `renderString`, `markdownString`) is deterministic
and golden-tested; `render` is the thin file-I/O shell that scans a directory
and writes a file. Doc-comments use the `(** ... *)` convention and attach to
the declaration they precede.

## Build & test

```sh
make test        # MLton: build + run the golden-index suite
make test-poly   # Poly/ML: run the same suite
make all-tests   # both compilers
make example     # generate an HTML index for a fixture package
```

Both compilers report `9 passed, 0 failed` with byte-identical output. The RED
vector set is the exact golden HTML index for a small fixture package.

## Example

`make example` documents a one-signature package:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>mini-collections</title>
</head>
<body>
<h1>mini-collections</h1>
<section>
<h2>signature ORD</h2>
<p class="doc">A total order over values of type t.</p>
<ul>
<li><code>type t</code> - <span class="doc">the ordered element type</span></li>
<li><code>val compare : t * t -&gt; order</code> - <span class="doc">the comparison, returning LESS/EQUAL/GREATER</span></li>
</ul>
</section>
</body>
</html>
```

## Layout

Layout B (vendoring): own sources in `src/`; the
[`sml-mlast`](https://github.com/sjqtentacles/sml-mlast) and
[`sml-html`](https://github.com/sjqtentacles/sml-html) trees (the latter
vendoring `sml-buffer`) are vendored byte-for-byte under
`lib/github.com/sjqtentacles/` (verified with `diff -rq`) and loaded first.

## License

MIT — see [LICENSE](LICENSE).
