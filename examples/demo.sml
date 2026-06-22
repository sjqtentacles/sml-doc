(* demo.sml - deterministic `make example` asset for sml-doc:
   generate an HTML documentation index for a tiny fixture package. *)

val ordSig =
  String.concatWith "\n"
    [ "(** A total order over values of type t. *)"
    , "signature ORD ="
    , "sig"
    , "  (** the ordered element type *)"
    , "  type t"
    , "  (** the comparison, returning LESS/EQUAL/GREATER *)"
    , "  val compare : t * t -> order"
    , "end" ]

val html =
  Doc.renderString
    { title = "mini-collections", files = [("ord.sig", ordSig)] }

val () = print "generated HTML index (Doc.renderString):\n\n"
val () = print html
