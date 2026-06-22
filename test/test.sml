(* test.sml - sml-doc golden HTML/Markdown index for a fixture package.

   The RED vector set: the generated HTML index for a small fixture package
   equals a fixed golden string (byte-identical on both compilers). We also
   assert doc-comment extraction and item structure. *)

structure Tests =
struct
  open Harness

  val fixtureSig =
    String.concatWith "\n"
      [ "(** A total order over values of type t. *)"
      , "signature ORD ="
      , "sig"
      , "  (** the ordered element type *)"
      , "  type t"
      , "  (** compare two elements *)"
      , "  val compare : t * t -> order"
      , "end" ]

  val fixtureSml =
    String.concatWith "\n"
      [ "(** Binary search trees over an ordered key. *)"
      , "structure Tree ="
      , "struct"
      , "  (** the tree type *)"
      , "  datatype 'a t = Leaf | Node of 'a t * 'a * 'a t"
      , "  (** the empty tree *)"
      , "  val empty = Leaf"
      , "  (** insert a key *)"
      , "  fun insert x t = t"
      , "end" ]

  val files = [("ord.sig", fixtureSig), ("tree.sml", fixtureSml)]

  val goldenHtml =
    "<!DOCTYPE html>\n\
    \<html lang=\"en\">\n\
    \<head>\n\
    \<meta charset=\"utf-8\">\n\
    \<title>demo</title>\n\
    \</head>\n\
    \<body>\n\
    \<h1>demo</h1>\n\
    \<section>\n\
    \<h2>signature ORD</h2>\n\
    \<p class=\"doc\">A total order over values of type t.</p>\n\
    \<ul>\n\
    \<li><code>type t</code> - <span class=\"doc\">the ordered element type</span></li>\n\
    \<li><code>val compare : t * t -&gt; order</code> - <span class=\"doc\">compare two elements</span></li>\n\
    \</ul>\n\
    \</section>\n\
    \<section>\n\
    \<h2>structure Tree</h2>\n\
    \<p class=\"doc\">Binary search trees over an ordered key.</p>\n\
    \<ul>\n\
    \<li><code>datatype &#x27;a t = Leaf | Node of &#x27;a t * &#x27;a * &#x27;a t</code> - <span class=\"doc\">the tree type</span></li>\n\
    \<li><code>val empty</code> - <span class=\"doc\">the empty tree</span></li>\n\
    \<li><code>fun insert</code> - <span class=\"doc\">insert a key</span></li>\n\
    \</ul>\n\
    \</section>\n\
    \</body>\n\
    \</html>\n"

  fun runAll () =
    let
      val () = section "module / item extraction"
      val mods = Doc.modules fixtureSig
      val () = checkInt "one module in ord.sig" (1, List.length mods)
      val ord = hd mods
      val () = checkString "module name" ("ORD", #name ord)
      val () = checkString "module kind" ("signature", #kind ord)
      val () = checkString "module doc"
                 ("A total order over values of type t.", #doc ord)
      val () = checkInt "two items" (2, List.length (#items ord))
      val () = checkString "first item doc"
                 ("the ordered element type", #doc (hd (#items ord)))

      val () = section "golden HTML index"
      val got = Doc.renderString {title = "demo", files = files}
      val () =
        if got = goldenHtml then check "html index matches golden" true
        else (print ("    --- got ---\n" ^ got ^ "\n    --- want ---\n"
                     ^ goldenHtml ^ "\n");
              check "html index matches golden" false)

      val () = section "markdown index"
      val md = Doc.markdownString {title = "demo", files = files}
      val () = check "markdown has module heading"
                 (String.isSubstring "## signature ORD" md)
      val () = check "markdown has item"
                 (String.isSubstring "`val compare : t * t -> order`" md)
    in () end

  fun run () = (reset (); runAll (); Harness.run ())
end
