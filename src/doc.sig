(* doc.sig

   A documentation generator built on the sml-mlast frontend and the sml-html
   renderer. It parses .sig/.sml sources, extracts the documented items
   (signatures, structures, functors and their val/type/datatype/exception
   members) together with `(** ... *)` doc-comments, and emits a static HTML
   (or Markdown) index.

   The pure core (`modules`, `renderString`, `markdownString`) is deterministic
   and golden-tested; `render` is the thin file-I/O shell. *)

signature DOC =
sig
  (* A documented member of a module. `detail` is the rendered signature-ish
     line; `doc` is the associated (** ... *) text, or "" if none. *)
  type item = { kind : string, name : string, detail : string, doc : string }

  (* A top-level signature / structure / functor and its members. *)
  type modul = { kind : string, name : string, doc : string, items : item list }

  (* Extract the modules documented in a single source string. *)
  val modules : string -> modul list

  (* Pure HTML index page for a set of (filename, source) inputs. *)
  val renderString   : { title : string, files : (string * string) list } -> string

  (* Pure Markdown index for the same inputs. *)
  val markdownString : { title : string, files : (string * string) list } -> string

  (* Scan directory `root` for .sig/.sml files and write an HTML index to the
     file `out`. Thin I/O shell over `renderString`. *)
  val render : { root : string, out : string } -> unit
end
