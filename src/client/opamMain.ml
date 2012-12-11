(***********************************************************************)
(*                                                                     *)
(*    Copyright 2012 OCamlPro                                          *)
(*    Copyright 2012 INRIA                                             *)
(*                                                                     *)
(*  All rights reserved.  This file is distributed under the terms of  *)
(*  the GNU Public License version 3.0.                                *)
(*                                                                     *)
(*  OPAM is distributed in the hope that it will be useful,            *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of     *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the      *)
(*  GNU General Public License for more details.                       *)
(*                                                                     *)
(***********************************************************************)

open OpamTypes
open Cmdliner

(*
let ano_args = ref []
let anon s =
  ano_args := s :: !ano_args

exception Bad of string * string

let bad_argument cmd fmt =
  Printf.ksprintf (fun msg -> raise (Bad (cmd, msg))) fmt

let noanon cmd s =
  raise (Bad (cmd, s ^ " is not expected"))

(* Useful for switch, which can overwrite the default verbose flag *)
let quiet = ref false


let global_args = [
  "--debug"     , Arg.Set OpamGlobals.debug   , " Print internal debug messages (very verbose)";
  "--verbose"   , Arg.Set OpamGlobals.verbose , " Display the output of subprocesses";
  "--quiet"     , Arg.Clear quiet         , " Do not display the output of subprocesses";
  "--version"   , Arg.Unit OpamVersion.message, " Display version information";
  "--switch"    , Arg.String set_switch       , " Use the given alias instead of looking into the config file";
  "--yes"       , Arg.Set OpamGlobals.yes     , " Answer yes to all questions";
  "--makecmd"   , Arg.String (fun s -> OpamGlobals.makecmd := lazy s),
    Printf.sprintf " Set the 'make' program used when compiling packages";
  "--root"      , Arg.String set_root_dir,
    (Printf.sprintf " Change root path (default is %s)" OpamGlobals.default_opam_dir);
  "--no-checksums", Arg.Clear OpamGlobals.verify_checksums, " Do not verify checksums on download";
  "--keep-build-dir", Arg.Set OpamGlobals.keep_build_dir, " Keep the build directory";
]

let parse_args fn () =
  fn (List.rev !ano_args)

(* opam init [-kind $kind] $repo $adress *)
let init =
  let kind = ref None in
  let comp = ref None in
  let cores = ref OpamGlobals.default_cores in
  let repo_priority = 0 in
{
  name     = "init";
  usage    = "";
  synopsis = "Initial setup";
  help     = "Create the initial config files";
  specs    = [
    ("-comp" , Arg.String (fun s -> comp := Some (OpamCompiler.of_string s)), " Which compiler version to use");
    ("-cores", Arg.Set_int cores   , " Set the number of cores");
    ("-kind" , Arg.String (fun s -> kind := Some s) , " Set the repository kind");
    ("-no-base-packages", Arg.Clear OpamGlobals.base_packages, " Do not install the base packages");
  ];
  anon;
  main     =
    parse_args (function
    | [] ->
        OpamClient.init OpamRepository.default !comp !cores
    | [address] ->
        let repo_name = OpamRepositoryName.default in
        let repo_kind = guess_repository_kind !kind address in
        let repo_address = OpamRepository.repository_address address in
        let repo = { repo_name; repo_kind; repo_address; repo_priority } in
        OpamClient.init repo !comp !cores
    | [name; address] ->
        let repo_name = OpamRepositoryName.of_string name in
        let repo_kind = guess_repository_kind !kind address in
        let repo_address = OpamRepository.repository_address address in
        let repo = { repo_name; repo_address; repo_kind; repo_priority } in
        OpamClient.init repo !comp !cores
    | _ -> bad_argument "init" "Need a repository name and address")
}

(* opam list [PACKAGE_REGEXP]* *)
let list =
  let print_short = ref false in
  let installed_only = ref false in
{
  name     = "list";
  usage    = "<package-regexp>*";
  synopsis = "Display the list of available packages";
  help     = "";
  specs    = [
    ("-short"    , Arg.Set print_short   , " Minimize the output by displaying only package name");
    ("-installed", Arg.Set installed_only, " Display only the list of installed packages");
  ];
  anon;
  main     =
    parse_args (function args ->
      let print_short = !print_short in
      let installed_only = !installed_only in
      OpamClient.list ~print_short ~installed_only args
    )
}

(* opam search [PACKAGE_REGEXP]* *)
let search =
  let print_short = ref false in
  let installed_only = ref false in
  let case_sensitive = ref false in
{
  name     = "search";
  usage    = "<package-regexp>*";
  synopsis = "Search into the package list";
  help     = "";
  specs    = [
    ("-short"    , Arg.Set print_short   , " Minimize the output by displaying only package name");
    ("-installed", Arg.Set installed_only, " Display only the list of installed packages");
    ("-case-sensitive", Arg.Set case_sensitive, " Force the search in case sensitive (insensitive by default)");
  ];

  anon;
  main     =
    parse_args (function args ->
      let print_short = !print_short in
      let installed_only = !installed_only in
      let case_sensitive = !case_sensitive in
      OpamClient.list ~print_short ~installed_only ~name_only:false ~case_sensitive args
    )
}

(* opam info [PACKAGE] *)
let info = {
  name     = "info";
  usage    = "[package]+";
  synopsis = "Display information about specific packages";
  help     = "";
  specs    = [];
  anon;
  main     =
    parse_args (function
    | [] -> bad_argument "info" "Missing package argument"
    | l  -> OpamClient.info l)
}

(* opam config [-r [-I|-bytelink|-asmlink] PACKAGE+ *)
let config =
let has_cmd = ref false in
let is_rec = ref false in
let is_link = ref false in
let is_byte = ref false in
let bytecomp () =  has_cmd := true; is_byte := true ; is_link := false in
let bytelink () =  has_cmd := true; is_byte := true ; is_link := true in
let asmcomp  () =  has_cmd := true; is_byte := false; is_link := false in
let asmlink  () =  has_cmd := true; is_byte := false; is_link := true in
let command = ref None in
let csh = ref false in
let set cmd () =
  has_cmd := true;
  command := Some cmd in
let specs = [
  ("-r"        , Arg.Set is_rec       , " Recursive search");
  ("-I"        , Arg.Unit (set `I)    , " Display include options");
  ("-bytecomp" , Arg.Unit bytecomp    , " Display bytecode compile options");
  ("-asmcomp"  , Arg.Unit asmcomp     , " Display native compile options");
  ("-bytelink" , Arg.Unit bytelink    , " Display bytecode link options");
  ("-asmlink"  , Arg.Unit asmlink     , " Display native link options");
  ("-list-vars", Arg.Unit (set `List) , " Display the contents of all available variables");
  ("-var"      , Arg.Unit (set `Var)  , " Display the content of a variable");
  ("-subst"    , Arg.Unit (set `Subst), " Substitute variables in files");
  ("-env"      , Arg.Unit (set `Env)  , " Display the compiler environment variables");
  ("-c"        , Arg.Set csh          , " Use csh-compatible output mode");
] in
let mk options =
  if not !has_cmd then
    bad_argument "config"
      "Wrong options (has_cmd=%b is_rec=%b,is_link=%b,is_byte=%b)"
      !has_cmd !is_rec !is_link !is_byte
  else
    CCompil {
      conf_is_rec  = !is_rec;
      conf_is_link = !is_link;
      conf_is_byte = !is_byte;
      conf_options = List.map OpamVariable.Section.Full.of_string options;
    } in
{
  name     = "config";
  usage    = "[...]+";
  synopsis = "Display configuration options for packages";
  help     = "";
  specs;
  anon;
  main = function () ->
    let names = List.rev !ano_args in
    let config = match !command with
      | Some `Env   -> CEnv !csh
      | Some `I     -> CIncludes (!is_rec, List.map OpamPackage.Name.of_string names)
      | Some `List  -> CList
      | Some `Var when List.length names = 1
                    -> CVariable (OpamVariable.Full.of_string (List.hd names))
      | Some `Var   ->
          bad_argument "config" "-var takes exactly one parameter"
      | Some `Subst -> CSubst (List.map OpamFilename.Base.of_string names)
      | None        -> mk names in
    OpamClient.config config
}

(* opam install <PACKAGE>+ *)
let install = {
  name     = "install";
  usage    = "[package]+";
  synopsis = "Install a list of packages";
  help     = "";
  specs    = [];
  anon;
  main     = parse_args (fun names ->
    if names <> [] then
      let names = List.map OpamPackage.Name.of_string names in
      OpamClient.install (OpamPackage.Name.Set.of_list names)
    else OpamGlobals.error_and_exit "You need to specify at least one package to install."
  )
}

(* opam reinstall <PACKAGE>+ *)
let reinstall = {
  name     = "reinstall";
  usage    = "[package]+";
  synopsis = "Reinstall a list of packages";
  help     = "";
  specs    = [];
  anon;
  main     = parse_args (fun names ->
    let names = List.map OpamPackage.Name.of_string names in
    OpamClient.reinstall (OpamPackage.Name.Set.of_list names)
  )
}

(* opam update *)
let update = {
  name     = "update";
  usage    = "[repo]*";
  synopsis = "Update the list of available packages";
  help     = "";
  specs    = [];
  anon;
  main     = parse_args (fun names ->
    OpamClient.update (List.map OpamRepositoryName.of_string names)
  )
}

(* opam upgrade *)
let upgrade = {
  name     = "upgrade";
  usage    = "[package]*";
  synopsis = "Upgrade the installed package to latest version";
  help     = "";
  specs    = [];
  anon;
  main     = parse_args (fun names ->
    let names = List.map OpamPackage.Name.of_string names in
    OpamClient.upgrade (OpamPackage.Name.Set.of_list names);
  )
}

(* opam upload PACKAGE *)
let upload =
  let opam = ref "" in
  let descr = ref "" in
  let archive = ref "" in
  let repo = ref "" in
{
  name     = "upload";
  usage    = "";
  synopsis = "Upload a package to an OPAM repository";
  help     = "";
  specs    = [
    ("-opam"   , Arg.Set_string opam   , " specify the OPAM file to upload");
    ("-descr"  , Arg.Set_string descr  , " specify the description file to upload");
    ("-archive", Arg.Set_string archive, " specify the archive file to upload");
    ("-repo"   , Arg.Set_string repo   , " (optional) specify the repository to upload")
  ];
  anon = noanon "upload";
  main     = (function () ->
    if !opam = "" then
      bad_argument "upload" "missing OPAM file";
    if !descr = "" then
      bad_argument "upload" "missing description file";
    if !archive = "" then
      bad_argument "upload" "missing archive file";
    let upl_opam = OpamFilename.of_string !opam in
    let upl_descr = OpamFilename.of_string !descr in
    let upl_archive = OpamFilename.of_string !archive in
    let repo = if !repo = "" then None else Some (OpamRepositoryName.of_string !repo) in
    OpamClient.upload { upl_opam; upl_descr; upl_archive } repo)
}

(* opam remove PACKAGE *)
let remove = {
  name     = "remove";
  usage    = "[package]+";
  synopsis = "Remove a list of packages";
  help     = "";
  specs    = [];
  anon;
  main     = parse_args (fun names ->
    if names <> [] then
      let names = List.map OpamPackage.Name.of_string names in
      OpamClient.remove (OpamPackage.Name.Set.of_list names)
    else OpamGlobals.error_and_exit "You need to specify at least one package to remove."
  )
}

(* opam remote [-list|-add <url>|-rm <url>] *)
let remote =
  let kind = ref None in
  let command : [`add|`list|`rm|`priority] option ref = ref None in
  let set c () = command := Some c in
  let add name address priority =
    let name = OpamRepositoryName.of_string name in
    let kind = guess_repository_kind !kind address in
    let address = OpamRepository.repository_address address in
    OpamClient.remote (RAdd (name, kind, address, priority)) in
{
  name     = "remote";
  usage    = "[-list|add <name> <address>|rm <name>]";
  synopsis = "Manage remote servers";
  help     = "";
  specs    = [
    ("-list" , Arg.Unit (set `list), " List the repositories");
    ("-add"  , Arg.Unit (set `add) , " Add a new repository");
    ("-rm"   , Arg.Unit (set `rm)  , " Remove a remote repository");
    ("-kind" , Arg.String (fun s -> kind := Some s) , " (optional) Specify the repository kind");
    ("-priority", Arg.Unit (set `priority) , " Set the repository priority (higher is better)");
  ];
  anon;
  main     = parse_args (fun args ->
    match !command, args with
    | Some `priority, [name; p]    ->
      OpamClient.remote (RPriority (OpamRepositoryName.of_string name, int_of_string p))
    | Some `list, []                -> OpamClient.remote RList
    | Some `rm,   [ name ]          -> OpamClient.remote (RRm (OpamRepositoryName.of_string name))
    | Some `add , [ name; address ] -> add name address None
    | Some `add ,
      [ name; address; priority ]   -> add name address (Some (int_of_string priority))
    | None, _  -> bad_argument "remote" "Command missing [-list|-add|-rm]"
    | _        -> bad_argument "remote" "Wrong arguments")
}

(* opam switch [-clone] OVERSION *)
let switch =
  let alias_of = ref "" in
  let command = ref `switch in
  let set c () =
    if !command <> `switch then
      bad_argument "switch" "two many sub-commands";
    command := c in
  let no_alias_of () =
    if !alias_of <> "" then
      bad_argument "switch" "invalid -alias-of option" in
  let mk_comp alias = match !alias_of with
    | ""   -> OpamCompiler.of_string alias
    | comp -> OpamCompiler.of_string comp in
{
  name     = "switch";
  usage    = "[compiler-name]";
  synopsis = "Manage multiple installation of compilers";
  help     = "";
  specs    = [
    ("-alias-of"        , Arg.Set_string alias_of        , " Compiler name");
    ("-no-base-packages", Arg.Clear OpamGlobals.base_packages, " Do not install the base packages");
    ("-install"         , Arg.Unit (set `install)        , " Install the given compiler");
    ("-remove"          , Arg.Unit (set `remove)         , " Remove the given compiler");
    ("-export"          , Arg.String (fun s -> set (`export s) ()), " Export the libraries installed with the given alias");
    ("-import"          , Arg.String (fun s -> set (`import s) ()), " Import the libraries installed with the given alias");
    ("-reinstall"       , Arg.Unit (set `reinstall)      , " Reinstall the given compiler");
    ("-list"            , Arg.Unit (set `list)           , " List the available compilers");
    ("-current"         , Arg.Unit (set `current)        , " Display the current compiler");
  ];
  anon;
  main     = parse_args (function args ->
    match !command, args with
    | `install, [switch] ->
        OpamClient.switch_install !quiet (OpamSwitch.of_string switch) (mk_comp switch)
    | `export f, [] ->
        no_alias_of ();
        OpamClient.switch_export (OpamFilename.of_string f)
    | `import f, [] ->
        no_alias_of ();
        OpamClient.switch_import (OpamFilename.of_string f)
    | `remove, switches ->
        no_alias_of ();
        List.iter (fun switch -> OpamClient.switch_remove (OpamSwitch.of_string switch)) switches
    | `reinstall, [switch] ->
        no_alias_of ();
        OpamClient.switch_reinstall (OpamSwitch.of_string switch)
    | `list, [] ->
        no_alias_of ();
        OpamClient.switch_list ()
    | `current, [] ->
        no_alias_of ();
        OpamClient.switch_current ()
    | `switch, [switch] ->
        begin match !alias_of with
          | "" -> OpamClient.switch !quiet (OpamSwitch.of_string switch)
          | _  -> OpamClient.switch_install !quiet (OpamSwitch.of_string switch) (mk_comp switch)
        end
    | _ -> bad_argument "switch" "too many arguments"
  )
}

(* opam pin [-list|<package> <version>|<package> <path>] *)
let pin =
  let list = ref false in
  let kind = ref None in
  let set_kind s = kind := Some s in
{
  name     = "pin";
  usage    = "<package> [<version>|<url>|none]";
  synopsis = "Pin a given package to a specific version";
  help     = "";
  specs    = [
    ("-list", Arg.Set list       , " List the current status of pinned packages");
    ("-kind", Arg.String set_kind, " Force the pin action (options are: 'git', 'rsync', 'version'");
  ];
  anon;
  main     = parse_args (function
    | [] when !list    -> OpamClient.pin_list ()
    | [name; arg]      -> OpamClient.pin { pin_package = OpamPackage.Name.of_string name; pin_arg = pin_option_of_string ?kind:!kind arg }
    | _                -> bad_argument "pin" "Wrong arguments")
}

let commands = [
  init;
  list;
  search;
  info;
  config;
  install;
  reinstall;
  update;
  upgrade;
  upload;
  remove;
  remote;
  switch;
  pin;
]

let f () =
  Sys.catch_break true;
  Printexc.register_printer (function
    | Unix.Unix_error (e,fn, msg) ->
      let msg = if msg = "" then "" else " on " ^ msg in
      let error = Printf.sprintf "%s: %S failed%s: %s" Sys.argv.(0) fn msg (Unix.error_message e) in
      Some error
    | _ -> None);
  List.iter SubCommand.register commands;
  try ArgExt.parse ~man_fun:
        (fun cmd -> ignore (Sys.command ("man opam-" ^ cmd))) global_args
  with
  | OpamGlobals.Exit 0 -> ()
  | e ->
    OpamGlobals.error "  '%s' failed\n" (String.concat " " (Array.to_list Sys.argv));
    match e with
    | Bad (cmd, msg) ->
        ArgExt.pp_print_help (ArgExt.SubCommand cmd) Format.err_formatter global_args ();
        OpamGlobals.error "%s" msg;
        exit 1;
    | Failure ("no subcommand defined" as s) ->
        ArgExt.pp_print_help ArgExt.NoSubCommand Format.err_formatter global_args ();
        OpamGlobals.error "%s" s;
        exit 2
    | OpamGlobals.Exit i -> exit i
    | e ->
      let bt = Printexc.get_backtrace () in
      let bt = if bt = "" then "" else Printf.sprintf "    at\n %s\n" bt in
      Printf.fprintf stderr "Fatal error: exception %s\n%s%!"
        (Printexc.to_string e) bt;
      exit 2

let global_args = [
  "--no-checksums", Arg.Clear OpamGlobals.verify_checksums, " Do not verify checksums on download";
  "--keep-build-dir", Arg.Set OpamGlobals.keep_build_dir, " Keep the build directory";
]

*)
type global_options = {
  debug  : bool;
  verbose: bool;
  switch : string option;
  yes    : bool;
  root   : string;
}

let set_global_options o =
  OpamGlobals.debug    := o.debug;
  OpamGlobals.verbose  := o.verbose;
  OpamGlobals.switch   := o.switch;
  OpamGlobals.root_dir := OpamSystem.real_path o.root

let help copts man_format cmds topic = match topic with
  | None       -> `Help (`Pager, None) (* help about the program. *)
  | Some topic ->
    let topics = "topics" :: cmds in
    let conv, _ = Cmdliner.Arg.enum (List.rev_map (fun s -> (s, s)) topics) in
    match conv topic with
    | `Error e -> `Error (false, e)
    | `Ok t when t = "topics" -> List.iter print_endline topics; `Ok ()
    | `Ok t -> `Help (man_format, Some t)

(* Help sections common to all commands *)
let global_option_section = "COMMON OPTIONS"
let help_sections = [
  `S global_option_section;
  `P "These options are common to all commands.";
  `S "MORE HELP";
  `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command.";`Noblank;
  `P "Use `$(mname) help patterns' for help on patch matching."; `Noblank;
  `P "Use `$(mname) help environment' for help on environment variables.";
  `S "BUGS"; `P "Check bug reports at https://github.com/OCamlPro/opam/issues.";]

(* Options common to all commands *)
let create_global_options debug verbose switch yes root =
  { debug; verbose; switch; yes; root }

let global_options =
  let docs = global_option_section in
  let debug =
    let doc = Arg.info ~docs ~doc:"Print debug message on stdout." ["d";"debug"] in
    Arg.(value & flag & doc) in
  let verbose =
    let quiet =
      let doc = Arg.info ["q"; "quiet"] ~docs ~doc:"Suppress informational output." in
      false, doc in
    let verbose =
      let doc = Arg.info ["v"; "verbose"] ~docs ~doc:"Give verbose output." in
      true, doc in
    Arg.(last & vflag_all [false] [quiet; verbose]) in
  let switch =
    let doc = Arg.info ~docs ~doc:"Overwrite the compiler switch name." ["s";"switch"] in
    Arg.(value & opt (some string) !OpamGlobals.switch & doc) in
  let yes =
    let doc = Arg.info ~docs ~doc:"Disable interactive mode and answer yes \
                               to all questions that would otherwise be\
                               asked to the user." ["y";"yes"] in
    Arg.(value & flag & doc) in
  let root =
    let doc = Arg.info ~docs ~doc:"Change the root path." ["r";"root"]  in
    Arg.(value & opt string !OpamGlobals.root_dir & doc) in
  Term.(pure create_global_options $ debug $ verbose $ switch $ yes $ root)

let guess_repository_kind kind address =
  match kind with
  | None  ->
    let address = OpamFilename.Dir.to_string address in
    if Sys.file_exists address then
      "local"
    else if OpamMisc.starts_with ~prefix:"git" address
        || OpamMisc.ends_with ~suffix:"git" address then
      "git"
    else
      OpamGlobals.default_repository_kind
  | Some k -> k

(* Converters *)
let pr_str = Format.pp_print_string

let repository_name =
  let parse str = `Ok (OpamRepositoryName.of_string str) in
  let print ppf name = pr_str ppf (OpamRepositoryName.to_string name) in
  parse, print

let repository_address =
  let parse str = `Ok (OpamFilename.raw_dir str) in
  let print ppf address = pr_str ppf (OpamFilename.Dir.to_string address) in
  parse, print

let compiler: compiler Arg.converter =
  let parse str = `Ok (OpamCompiler.of_string str) in
  let print ppf comp = pr_str ppf (OpamCompiler.to_string comp) in
  parse, print

(* Commands *)

(* INIT *)
let init =
  let doc = "Initialize opam." in
  let man = [
    `S "DESCRIPTION";
    `P "The init command creates a fresh client state, that is initialize opam
        configuration in ~/.opam and setup a default repository.";
    `P "Additional repositories can later be added by using the $(b,opam remote) command.";
    `P "The local cache of a repository state can be updated by using $(b,opam update).";
  ] @ help_sections
  in
  let cores =
    let doc = Arg.info ~docv:"CORES" ~doc:"Number of cores." ["j";"cores"] in
    Arg.(value & opt int 1 & doc) in
  let compiler =
    let doc = Arg.info ~docv:"COMPILER" ~doc:"Which compiler version to use." ["c";"comp"] in
    Arg.(value & opt compiler OpamCompiler.default & doc) in
  let repo_kind =
    let doc = Arg.info ~docv:"KIND" ~doc:"Specify the kind of the repository to be set." ["kind"] in
    let kinds = List.map (fun x -> x,x) [ "http";"rsync"; "git" ] in
    Arg.(value & opt (some (enum kinds)) None & doc) in
  let repo_name =
    let doc = Arg.info ~docv:"NAME" ~doc:"Name of the repository." [] in
    Arg.(value & pos ~rev:true 1 repository_name OpamRepositoryName.default & doc) in
  let repo_address =
    let doc = Arg.info ~docv:"ADDRESS" ~doc:"Address of the repository." [] in
    Arg.(value & pos ~rev:true 0 repository_address OpamRepository.default_address & doc) in
  let init global_options repo_kind repo_name repo_address compiler cores =
    set_global_options global_options;
    let repo_kind = guess_repository_kind repo_kind repo_address in
    let repo_priority = 0 in
    let repository = { repo_name; repo_kind; repo_address; repo_priority } in
    OpamClient.init repository compiler cores in
  Term.(pure init $global_options $repo_kind $repo_name $repo_address $ compiler $cores),
  Term.info "init" ~sdocs:global_option_section ~doc ~man

(* LIST *)
let list =
  let doc = "Display the list of available packages." in
  let man = [
    `S "DESCRIPTION";
    `P "This command displays the list of available packages, or the list of
         installed packages if the $(i,-installed) switch is used.";
    `P "Unless the $(i,-short) switch is used, the output format displays one
        package per line, and each line contains the name of the package, the
        installed version or -- if the package is not installed, and a short
        description.";
    `P " The full description can be obtained by doing $(b,opam info <package>).
         You can search into the package list with the $(b,opam search) command."
  ] @ help_sections in
  let packages =
    let doc = Arg.info ~docv:"PACKAGES" ~doc:"List of regular expressions to match." [] in
    Arg.(value & pos_all string [] & doc) in
  let print_short =
    let doc = Arg.info ~docv:"SHORT" ~doc:"Output the names of packages separated\
                                           by one whitespace instead of using the\
                                           usual formatting." ["s";"short"] in
    Arg.(value & flag & doc) in
  let installed_only =
    let doc = Arg.info ~docv:"INSTALLED" ~doc:"List installed packages only." ["i";"installed"] in
    Arg.(value & flag & doc) in
  let list global_options print_short installed_only packages =
    set_global_options global_options;
    OpamClient.list ~print_short ~installed_only packages in
  Term.(pure list $global_options $print_short $installed_only $packages),
  Term.info "list" ~sdocs:global_option_section ~doc ~man

let help =
  let doc = "display help about opam and opam commands" in
  let man =
    [`S "DESCRIPTION";
     `P "Prints help about opam commands"] @ help_sections
  in
  let topic =
    let doc = Arg.info [] ~docv:"TOPIC" ~doc:"The topic to get help on. `topics' lists the topics." in
    Arg.(value & pos 0 (some string) None & doc )
  in
  Term.(ret (pure help $ global_options $ Term.man_format $ Term.choice_names $ topic)),
  Term.info "help" ~doc ~man

let default =
  let doc = "a Package Manager for OCaml" in
  let man = [
    `S "DESCRIPTION";
    `P "OPAM is a package manager for OCaml. It uses the powerful mancoosi
        tools to handle dependencies, including support for version
        constraints, optional dependencies, and conflicts management.";
    `P "It has support for different repository backends such as HTTP, rsync and
        git. It handles multiple OCaml versions concurrently, and is flexible
        enough to allow you to use your own repositories and packages in
        addition of the ones it provides.";
  ] @  help_sections
  in
  Term.(ret (pure (fun _ -> `Help (`Pager, None)) $ global_options)),
  Term.info "opam"
    ~version:(OpamVersion.to_string OpamVersion.current)
    ~sdocs:global_option_section
    ~doc
    ~man

let cmds = [
  init; list; help
]

let () =
  Sys.catch_break true;
  Printexc.register_printer (function
    | Unix.Unix_error (e,fn, msg) ->
      let msg = if msg = "" then "" else " on " ^ msg in
      let error = Printf.sprintf "%s: %S failed%s: %s" Sys.argv.(0) fn msg (Unix.error_message e) in
      Some error
    | _ -> None);
  try
    match Term.eval_choice ~catch:false default cmds with
    | `Error _ -> exit 1
    | _        -> exit 0
  with
  | OpamGlobals.Exit 0 -> ()
  | e ->
    OpamGlobals.error "  '%s' failed.\n" (String.concat " " (Array.to_list Sys.argv));
    match e with
    | OpamGlobals.Exit i -> exit i
    | e ->
      let bt = Printexc.get_backtrace () in
      let bt = if bt = "" then "" else Printf.sprintf "    at\n %s\n" bt in
      Printf.fprintf stderr "Fatal error: exception %s\n%s%!"
        (Printexc.to_string e) bt;
      exit 2
