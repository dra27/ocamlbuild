(***********************************************************************)
(*                                                                     *)
(*                             ocamlbuild                              *)
(*                                                                     *)
(*  Nicolas Pouillard, Berke Durak, projet Gallium, INRIA Rocquencourt *)
(*                                                                     *)
(*  Copyright 2007 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)


(* Original author: Nicolas Pouillard *)
exception Error of (string * Loc.location)

type conf_values =
  { plus_tags   : (string * Loc.location)  list;
    minus_tags  : (string * Loc.location) list }

type conf = (Glob.globber * conf_values) list

val ocamldep_output : Loc.source -> Lexing.lexbuf -> (string * string list) list
val space_sep_strings : Loc.source -> Lexing.lexbuf -> string list
val blank_sep_strings : Loc.source -> Lexing.lexbuf -> string list
val comma_sep_strings : Loc.source -> Lexing.lexbuf -> string list
val comma_or_blank_sep_strings : Loc.source -> Lexing.lexbuf -> string list
val trim_blanks : Loc.source -> Lexing.lexbuf -> string

val conf_lines : string option -> Loc.source -> Lexing.lexbuf -> conf
val path_scheme : bool -> Loc.source -> Lexing.lexbuf ->
  [ `Word of string
  | `Var of (string * Glob.globber)
  ] list

val ocamlfind_query : Loc.source -> Lexing.lexbuf ->
  string * string * string * string * string * string

val tag_gen : Loc.source -> Lexing.lexbuf -> string * string option
