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
open My_std
open Format
open Log
open Pathname.Operators
open Tags.Operators
open Rule
open Tools
open Command
;;


let plugin                = "myocamlbuild"
let plugin_file           = plugin^".ml"
let plugin_config_file    = plugin^"_config.ml"
let plugin_config_file_interface = plugin^"_config.mli"
let we_have_a_plugin_source () =
  sys_file_exists plugin_file
let we_need_a_plugin_binary () =
  !Options.plugin && we_have_a_plugin_source ()
let we_have_a_plugin_binary () =
  sys_file_exists ((!Options.build_dir/plugin)^(!Options.exe))
let we_have_a_config_file () =
  sys_file_exists plugin_config_file
let we_have_a_config_file_interface () =
  sys_file_exists plugin_config_file_interface

(* exported through plugin.mli *)
let we_need_a_plugin () = we_need_a_plugin_binary ()

module Make(U:sig end) =
  struct
    let we_need_a_plugin_binary = we_need_a_plugin_binary ()
    let we_have_a_plugin_source = we_have_a_plugin_source ()
    let we_have_a_config_file = we_have_a_config_file ()
    let we_have_a_config_file_interface = we_have_a_config_file_interface ()
    let we_have_a_plugin_binary () =
      (* this remains a function as it will change during the build *)
      we_have_a_plugin_binary ()

    let up_to_date_or_copy fn =
      let fn' = !Options.build_dir/fn in
      Pathname.exists fn &&
        begin
          Pathname.exists fn' && Pathname.same_contents fn fn' ||
          begin
            Shell.cp fn fn';
            false
          end
        end

    let rebuild_plugin () =
      let a = up_to_date_or_copy plugin_file in
      let b = (not we_have_a_config_file) || up_to_date_or_copy plugin_config_file in
      let c = (not we_have_a_config_file_interface) || up_to_date_or_copy plugin_config_file_interface in
      if a && b && c && we_have_a_plugin_binary () then
        () (* Up to date *)
           (* FIXME: remove ocamlbuild_config.ml in _build/ if removed in parent *)
      else begin
        if !Options.native_plugin
            && not (sys_file_exists ((!Ocamlbuild_where.libdir)/"ocamlbuildlib.cmxa")) then
          begin
            Options.native_plugin := false;
            eprintf "Warning: Won't be able to compile a native plugin"
          end;
        let plugin_config =
          if we_have_a_config_file then
            if we_have_a_config_file_interface then
              S[P plugin_config_file_interface; P plugin_config_file]
            else P plugin_config_file
          else N in

        let cma, cmo, compiler, byte_or_native =
          if !Options.native_plugin then
            "cmxa", "cmx", !Options.plugin_ocamlopt, "native"
          else
            "cma", "cmo", !Options.plugin_ocamlc, "byte"
        in

        let (unix_spec, ocamlbuild_lib_spec, ocamlbuild_module_spec) =

          let use_ocamlfind_pkgs =
            !Options.plugin_use_ocamlfind && !Options.plugin_tags <> [] in
          (* The plugin has the following dependencies that must be
             included during compilation:

             - unix.cmxa, if it is available
             - ocamlbuildlib.cm{a,xa}, the library part of ocamlbuild
             - ocamlbuild.cm{o,x}, the module that performs the
               initialization work of the ocamlbuild executable, using
               modules of ocamlbuildlib.cmxa

             We pass all this stuff to the compilation command for the
             plugin, with an important detail to handle:

             There are risks of compilation error due to
             double-linking of native modules when the user passes its
             own tags to the plugin compilation process (as was added
             to support modular construction of
             ocamlbuild plugins). Indeed, if we hard-code linking to
             unix.cmxa in all cases, and the user
             enables -plugin-use-ocamlfind and
             passes -plugin-tag "package(unix)" (or package(foo) for
             any foo which depends on unix), the command-line finally
             executed will be

               ocamlfind ocamlopt unix.cmxa -package unix myocamlbuild.ml

             which fails with a compilation error due to doubly-passed
             native modules.

             To sanest way to solve this problem at the ocamlbuild level
             is to pass "-package unix" instead of unix.cmxa when we
             detect that such a situation may happen. OCamlfind will see
             that the same package is demanded twice, and only request
             it once to the compiler. Similarly, we use "-package
             ocamlbuild" instead of linking ocamlbuildlib.cmxa[1].

             We switch to this behavior when two conditions, embodied in
             the boolean variable [use_ocamlfind_pkgs], are met:
             (a) plugin-use-ocamlfind is enabled
             (b) the user is passing some plugin tags

             Condition (a) is overly conservative as the double-linking
             issue may also happen in non-ocamlfind situations, such as
             "-plugin-tags use_unix" -- but it's unclear how one would
             avoid the issue in that case, except by documenting that
             people should not do that, or getting rid of the
             hard-linking logic entirely, with the corresponding risks
             of regression.

             Condition (b) should not be necessary (we expect using
             ocamlfind packages to work whenever ocamlfind
             is available), but allows the behavior in absence
             of -plugin-tags to be completely unchanged, to reassure us
             about potential regressions introduced by this option.
          *)

          let unix_lib =
            if use_ocamlfind_pkgs then `Package "unix"
            else `Lib ("+unix", "unix") in

          let ocamlbuild_lib =
            if use_ocamlfind_pkgs then `Package "ocamlbuild"
            else `Local_lib "ocamlbuildlib" in

          let ocamlbuild_module =
            `Local_mod "ocamlbuild" in

          let dir = !Ocamlbuild_where.libdir in
          let dir = if Pathname.is_implicit dir then Pathname.pwd/dir else dir in

          let in_dir file =
            let path = dir/file in
            if not (sys_file_exists path) then failwith
              (sprintf "Cannot find %S in ocamlbuild -where directory" file);
            path in

          let spec = function
            | `Nothing -> N
            | `Package pkg -> S[A "-package"; A pkg]
            | `Lib (inc, lib) -> S[A "-I"; A inc; P (lib -.- cma)]
            | `Local_lib llib -> S [A "-I"; A dir; P (in_dir (llib -.- cma))]
            | `Local_mod lmod -> P (in_dir (lmod -.- cmo)) in

          (spec unix_lib, spec ocamlbuild_lib, spec ocamlbuild_module)
        in

        let plugin_tags =
          Tags.of_list !Options.plugin_tags
          ++ "ocaml" ++ "program" ++ "link" ++ byte_or_native in

        (* The plugin is compiled before [Param_tags.init()] is called
           globally, which means that parametrized tags have not been
           made effective yet. The [partial_init] calls below initializes
           precisely those that will be used during the compilation of
           the plugin, and no more.
        *)
        Param_tags.partial_init Const.Source.plugin_tag plugin_tags;

        let cmd =
          (* The argument order is important: we carefully put the
             plugin source files before the ocamlbuild.cm{o,x} module
             doing the main initialization, so that user global
             side-effects (setting options, installing flags..) are
             performed brefore ocamlbuild's main routine. This is
             a fragile thing to rely upon and we insist that our users
             use the more robust [dispatch] registration instead, but
             we still aren't going to break that now.

             For the same reason we place the user plugin-tags after
             the plugin libraries (in case a tag would, say, inject
             a .cmo that also relies on them), but before the main
             plugin source file and ocamlbuild's initialization. *)
          Cmd(S[compiler;
                unix_spec; ocamlbuild_lib_spec;
                T plugin_tags;
                plugin_config; P plugin_file;
                ocamlbuild_module_spec;
                A"-o"; Px (plugin^(!Options.exe))])
        in
        Shell.chdir !Options.build_dir;
        Shell.rm_f (plugin^(!Options.exe));
        Command.execute cmd;
      end

    let execute_plugin () =
      Shell.chdir Pathname.pwd;
      let runner = if !Options.native_plugin then N else !Options.ocamlrun in
      let argv = List.tl (Array.to_list Sys.argv) in
      let passed_argv = List.filter (fun s -> s <> "-plugin-option") argv in
      let spec = S[runner; P(!Options.build_dir/plugin^(!Options.exe));
                   A"-no-plugin"; atomize passed_argv] in
      Log.finish ();
      let rc = sys_command (Command.string_of_command_spec spec) in
      raise (Exit_silently_with_code rc)

    let main () =
      if we_need_a_plugin_binary then begin
        rebuild_plugin ();
        if not (we_have_a_plugin_binary ()) then begin
          Log.eprintf "Error: we failed to build the plugin";
          raise (Exit_with_code Exit_codes.rc_build_error);
        end
      end;
      (* if -just-plugin is passed by there is no plugin, nothing
         happens, and we decided not to emit a warning: this lets
         people that write ocamlbuild-driver scripts always run
         a first phase (ocamlbuild -just-plugin ...)  if they want to,
         without having to test for the existence of a plugin
         first. *)
      if !Options.just_plugin then begin
        Log.finish ();
        raise Exit_OK;
      end;
      (* On the contrary, not having a plugin yet passing -plugin-tags
         is probably caused by a user error that we should warn about;
         for example people may incorrectly think that -plugin-tag
         foo.ocamlbuild will enable foo's rules: they have to
         explicitly use Foo in their plugin and it's best to warn if
         they don't. *)
      if not we_have_a_plugin_source && !Options.plugin_tags <> [] then
        eprintf "Warning: option -plugin-tag(s) has no effect \
                 in absence of plugin file %S" plugin_file;
      if we_need_a_plugin_binary && we_have_a_plugin_binary () then
        execute_plugin ()
  end
;;

let execute_plugin_if_needed () =
  let module P = Make(struct end) in
  P.main ()
;;
