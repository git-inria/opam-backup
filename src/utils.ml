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

let filter_map f l =
  let rec loop accu = function
    | []     -> List.rev accu
    | h :: t ->
        match f h with
        | None   -> loop accu t
        | Some x -> loop (x::accu) t in
  loop [] l

module IntMap = Map.Make(struct type t = int let compare = compare end)  
module StringMap = Map.Make(struct type t = string let compare = compare end)  
module IntSet = Set.Make(struct type t = int let compare = compare end)  

let (|>) f g x = g (f x) 

let string_strip str =
  let p = ref 0 in
  let l = String.length str in
  let fn = function
    | ' ' | '\t' | '\r' | '\n' -> true
    | _ -> false in 
  while !p < l && fn (String.unsafe_get str !p) do
    incr p;
  done;
  let p = !p in
  let l = ref (l - 1) in
  while !l >= p && fn (String.unsafe_get str !l) do
    decr l;
  done;
  String.sub str p (!l - p + 1)

let starts_with ~prefix s =
  String.length s >= String.length prefix
  && String.sub s 0 (String.length prefix) = prefix

let ends_with ~suffix s =
  String.length s >= String.length suffix
  && String.sub s (String.length s - String.length suffix) (String.length suffix) = suffix

let remove_prefix ~prefix s =
  if starts_with prefix s then
    String.sub s (String.length prefix) (String.length s - String.length prefix)
  else
    Globals.error_and_exit "%s is not a prefix of %s" prefix s

let is_inet_address address =
  try
    let (_:Unix.inet_addr) = Unix.inet_addr_of_string address
    in true
  with _ -> false

let cut_at_aux fn s sep =
  try
    let i = fn s sep in
    let name = String.sub s 0 i in
    let version = String.sub s (i+1) (String.length s - i - 1) in
    Some (name, version)
  with _ ->
    None

let cut_at = cut_at_aux String.index

let rcut_at = cut_at_aux String.rindex

let contains s c =
  try let _ = String.index s c in true
  with Not_found -> false

let split s c =
  Pcre.split (Pcre.regexp (String.make 1 c)) s

(* Remove from a ':' separated list of string the one with the given prefix *)
let reset_env_value ~prefix v =
  let v = split v ':' in
  List.filter (fun v -> not (starts_with ~prefix v)) v

(* if rsync -arv return 4 lines, this means that no files have changed *)
let rsync_trim = function
  | [] -> []
  | _ :: t ->
      match List.rev t with
      | _ :: _ :: _ :: l -> List.filter ((<>) "./") l
      | _ -> []
