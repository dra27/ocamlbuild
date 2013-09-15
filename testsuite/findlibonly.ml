#use "internal_test_header.ml";;
#use "findlibonly_test_header.ml";;

test "camlp4.opt"
  ~description:"Fixes PR#5652"
  ~options:[`package "camlp4.macro";`tags ["camlp4o.opt"; "syntax\\(camp4o\\)"];
            `ppflag "camlp4o.opt"; `ppflag "-parser"; `ppflag "macro";
            `ppflag "-DTEST"]
  ~tree:[T.f "dummy.ml"
            ~content:"IFDEF TEST THEN\nprint_endline \"Hello\";;\nENDIF;;"]
  ~matching:[M.x "dummy.native" ~output:"Hello"]
  ~targets:("dummy.native",[]) ();;

test "ThreadAndArchive"
  ~description:"Fixes PR#6058"
  ~options:[`use_ocamlfind; `package "threads"; `tag "thread"]
  ~tree:[T.f "t.ml" ~content:""]
  ~matching:[M.f "_build/t.cma"]
  ~targets:("t.cma",[]) ();;

test "SyntaxFlag"
  ~options:[`use_ocamlfind; `package "camlp4.macro"; `syntax "camlp4o"]
  ~description:"-syntax for ocamlbuild"
  ~tree:[T.f "dummy.ml" ~content:"IFDEF TEST THEN\nprint_endline \"Hello\";;\nENDIF;;"]
  ~matching:[M.f "dummy.native"]
  ~targets:("dummy.native",[]) ();;

run ~root:"_test_findlibonly";;