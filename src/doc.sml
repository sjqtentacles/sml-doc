(* doc.sml - see doc.sig *)

structure Doc :> DOC =
struct
  open Ast

  type item = { kind : string, name : string, detail : string, doc : string }
  type modul = { kind : string, name : string, doc : string, items : item list }

  (* ---- small rendering helpers (reusing PpAst.ppTy for types) ---- *)

  fun tv [] = ""
    | tv [a] = a ^ " "
    | tv xs = "(" ^ String.concatWith ", " xs ^ ") "

  fun conStr (c, NONE) = c
    | conStr (c, SOME t) = c ^ " of " ^ PpAst.ppTy t

  fun datbindStr ({tyvars, name, cons} : datbind) =
    "datatype " ^ tv tyvars ^ name ^ " = "
    ^ String.concatWith " | " (List.map conStr cons)

  (* ---- doc-comment scanner: pairs (** ... *) with the following decl name ---- *)

  fun normalizeWs s =
    let
      val toks = String.tokens Char.isSpace s
    in String.concatWith " " toks end

  fun collectDocs src =
    let
      val n = String.size src
      fun ch i = String.sub (src, i)
      val docs = ref ([] : (string * string) list)
      val pending = ref (NONE : string option)
      fun isIdCh c =
        Char.isAlphaNum c orelse c = #"_" orelse c = #"'" orelse c = #"."
      fun isKw w =
        List.exists (fn k => k = w)
          ["val", "fun", "type", "datatype", "exception",
           "structure", "signature", "functor", "eqtype"]
      fun skipString (i, q) =
        if i >= n then i
        else if ch i = #"\\" andalso i + 1 < n then skipString (i + 2, q)
        else if ch i = q then i + 1
        else skipString (i + 1, q)
      fun readComment (i, depth) =
        if depth = 0 then i
        else if i + 1 < n andalso ch i = #"(" andalso ch (i + 1) = #"*"
          then readComment (i + 2, depth + 1)
        else if i + 1 < n andalso ch i = #"*" andalso ch (i + 1) = #")"
          then readComment (i + 2, depth - 1)
        else if i < n then readComment (i + 1, depth)
        else i
      fun readIdent i =
        let fun go j = if j < n andalso isIdCh (ch j) then go (j + 1) else j
        in go i end
      fun skipWs j = if j < n andalso Char.isSpace (ch j) then skipWs (j + 1) else j
      fun afterKw i =
        let
          val j = skipWs i
          (* skip a tyvar seq: 'a  or  ( ... ) *)
          val j =
            if j < n andalso ch j = #"'" then readIdent j
            else if j < n andalso ch j = #"(" then
              let
                fun go (k, d) =
                  if k >= n then k
                  else if ch k = #"(" then go (k + 1, d + 1)
                  else if ch k = #")" then (if d = 1 then k + 1 else go (k + 1, d - 1))
                  else go (k + 1, d)
              in go (j, 0) end
            else j
          val j = skipWs j
          val e = readIdent j
        in (String.substring (src, j, e - j), e) end
      fun loop i =
        if i >= n then ()
        else
          let val c = ch i in
            if i + 1 < n andalso c = #"(" andalso ch (i + 1) = #"*" then
              let
                val isDoc =
                  i + 2 < n andalso ch (i + 2) = #"*"
                  andalso not (i + 3 < n andalso ch (i + 3) = #")")
                val e = readComment (i + 2, 1)
              in
                if isDoc then
                  let val inner = String.substring (src, i + 3, (e - 2) - (i + 3))
                  in pending := SOME (normalizeWs inner); loop e end
                else loop e
              end
            else if c = #"\"" then loop (skipString (i + 1, #"\""))
            else if Char.isAlpha c then
              let
                val e = readIdent i
                val w = String.substring (src, i, e - i)
              in
                if isKw w then
                  let val (name, e2) = afterKw e
                  in (case !pending of
                          SOME d => (docs := (name, d) :: !docs; pending := NONE)
                        | NONE => ());
                     loop e2
                  end
                else loop e
              end
            else loop (i + 1)
          end
      val () = loop 0
    in List.rev (!docs) end

  (* ---- item extraction from the AST ---- *)

  fun itemsOfSpec sp =
    case sp of
        SpecVal binds =>
          List.map (fn (v, t) =>
            { kind = "val", name = v, detail = "val " ^ v ^ " : " ^ PpAst.ppTy t,
              doc = "" }) binds
      | SpecType binds =>
          List.map (fn (tvs, nm) =>
            { kind = "type", name = nm, detail = "type " ^ tv tvs ^ nm, doc = "" })
            binds
      | SpecEqtype binds =>
          List.map (fn (tvs, nm) =>
            { kind = "type", name = nm, detail = "eqtype " ^ tv tvs ^ nm, doc = "" })
            binds
      | SpecTypeDef binds =>
          List.map (fn (tvs, nm, t) =>
            { kind = "type", name = nm,
              detail = "type " ^ tv tvs ^ nm ^ " = " ^ PpAst.ppTy t, doc = "" })
            binds
      | SpecDatatype dbs =>
          List.map (fn db =>
            { kind = "datatype", name = #name db, detail = datbindStr db, doc = "" })
            dbs
      | SpecException ebs =>
          List.map (fn (c, tyo) =>
            { kind = "exception", name = c, detail = "exception " ^ conStr (c, tyo),
              doc = "" }) ebs
      | SpecStructure binds =>
          List.map (fn (nm, _) =>
            { kind = "structure", name = nm, detail = "structure " ^ nm, doc = "" })
            binds
      | SpecInclude _ =>
          [ { kind = "include", name = "include", detail = "include", doc = "" } ]

  fun itemsOfDec d =
    case d of
        DVal (_, binds, _) =>
          List.mapPartial
            (fn (PVar name, _) =>
                  SOME { kind = "val", name = name, detail = "val " ^ name, doc = "" }
              | _ => NONE) binds
      | DFun (_, funs) =>
          List.map (fn (name, _) =>
            { kind = "fun", name = name, detail = "fun " ^ name, doc = "" }) funs
      | DType binds =>
          List.map (fn (tvs, nm, t) =>
            { kind = "type", name = nm,
              detail = "type " ^ tv tvs ^ nm ^ " = " ^ PpAst.ppTy t, doc = "" })
            binds
      | DDatatype (dbs, _) =>
          List.map (fn db =>
            { kind = "datatype", name = #name db, detail = datbindStr db, doc = "" })
            dbs
      | DException ebs =>
          List.map (fn (c, tyo) =>
            { kind = "exception", name = c, detail = "exception " ^ conStr (c, tyo),
              doc = "" }) ebs
      | DStructure binds =>
          List.map (fn (nm, _) =>
            { kind = "structure", name = nm, detail = "structure " ^ nm, doc = "" })
            binds
      | DSignature binds =>
          List.map (fn (nm, _) =>
            { kind = "signature", name = nm, detail = "signature " ^ nm, doc = "" })
            binds
      | _ => []

  fun itemsOfSigexp se =
    case se of
        SigSig sps => List.concat (List.map itemsOfSpec sps)
      | SigWhere (se, _) => itemsOfSigexp se
      | SigId _ => []

  fun itemsOfStrexp se =
    case se of
        StrStruct ds => List.concat (List.map itemsOfDec ds)
      | StrConstraint (_, sg, _) => itemsOfSigexp sg
      | StrLet (_, se) => itemsOfStrexp se
      | StrApp _ => []
      | StrId _ => []

  fun modules src =
    let
      val prog = Parser.parseString src
      val docMap = collectDocs src
      fun docOf nm =
        case List.find (fn (k, _) => k = nm) docMap of
            SOME (_, d) => d | NONE => ""
      fun attach (it : item) =
        { kind = #kind it, name = #name it, detail = #detail it, doc = docOf (#name it) }
      fun moduleOfDec d =
        case d of
            DSignature binds =>
              SOME (List.map (fn (nm, se) =>
                { kind = "signature", name = nm, doc = docOf nm,
                  items = List.map attach (itemsOfSigexp se) }) binds)
          | DStructure binds =>
              SOME (List.map (fn (nm, se) =>
                { kind = "structure", name = nm, doc = docOf nm,
                  items = List.map attach (itemsOfStrexp se) }) binds)
          | DFunctor binds =>
              SOME (List.map (fn fb =>
                { kind = "functor", name = #name fb, doc = docOf (#name fb),
                  items = List.map attach (itemsOfStrexp (#body fb)) }) binds)
          | _ => NONE
    in
      List.concat (List.mapPartial moduleOfDec prog)
    end

  (* ---- HTML rendering via sml-html ---- *)

  fun itemNode (it : item) =
    Html.el "li" []
      ([ Html.el "code" [] [Html.text (#detail it)] ]
       @ (if #doc it = "" then []
          else [ Html.text " - ",
                 Html.el "span" [("class", "doc")] [Html.text (#doc it)] ]))

  fun moduleNode (m : modul) =
    Html.el "section" []
      ([ Html.raw "\n",
         Html.el "h2" [] [Html.text (#kind m ^ " " ^ #name m)],
         Html.raw "\n" ]
       @ (if #doc m = "" then []
          else [ Html.el "p" [("class", "doc")] [Html.text (#doc m)],
                 Html.raw "\n" ])
       @ [ Html.el "ul" []
             (List.concat (List.map (fn it => [Html.raw "\n", itemNode it]) (#items m))
              @ [Html.raw "\n"]),
           Html.raw "\n" ])

  fun htmlIndex (title, mods) =
    Html.el "html" [("lang", "en")]
      [ Html.raw "\n",
        Html.el "head" []
          [ Html.raw "\n",
            Html.void "meta" [("charset", "utf-8")],
            Html.raw "\n",
            Html.el "title" [] [Html.text title],
            Html.raw "\n" ],
        Html.raw "\n",
        Html.el "body" []
          ([ Html.raw "\n",
             Html.el "h1" [] [Html.text title],
             Html.raw "\n" ]
           @ List.concat (List.map (fn m => [moduleNode m, Html.raw "\n"]) mods)),
        Html.raw "\n" ]

  fun renderString {title, files} =
    let val mods = List.concat (List.map (fn (_, src) => modules src) files)
    in Html.document (htmlIndex (title, mods)) ^ "\n" end

  fun markdownString {title, files} =
    let
      val mods = List.concat (List.map (fn (_, src) => modules src) files)
      fun itemMd (it : item) =
        "- `" ^ #detail it ^ "`"
        ^ (if #doc it = "" then "" else " - " ^ #doc it)
      fun modMd (m : modul) =
        "## " ^ #kind m ^ " " ^ #name m ^ "\n"
        ^ (if #doc m = "" then "" else "\n" ^ #doc m ^ "\n")
        ^ "\n" ^ String.concatWith "\n" (List.map itemMd (#items m)) ^ "\n"
    in "# " ^ title ^ "\n\n" ^ String.concatWith "\n" (List.map modMd mods) end

  (* ---- thin file-I/O shell ---- *)

  fun sortStrings xs =
    let
      fun insert (x, []) = [x]
        | insert (x, y :: ys) =
            if String.<= (x, y) then x :: y :: ys else y :: insert (x, ys)
    in List.foldr insert [] xs end

  fun readFile path =
    let
      val ins = TextIO.openIn path
      val s = TextIO.inputAll ins
      val () = TextIO.closeIn ins
    in s end

  fun render {root, out} =
    let
      val dir = OS.FileSys.openDir root
      fun readEntries acc =
        case OS.FileSys.readDir dir of
            SOME e => readEntries (e :: acc) | NONE => acc
      val entries = readEntries []
      val () = OS.FileSys.closeDir dir
      val srcs = sortStrings
        (List.filter (fn e =>
            String.isSuffix ".sig" e orelse String.isSuffix ".sml" e) entries)
      val files = List.map (fn e => (e, readFile (OS.Path.concat (root, e)))) srcs
      val html = renderString {title = OS.Path.file root, files = files}
      val outs = TextIO.openOut out
      val () = TextIO.output (outs, html)
      val () = TextIO.closeOut outs
    in () end
end
