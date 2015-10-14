#include "xdebug.cppo"
open VarGen
open Globals
open Gen
open Others
open Label_only
open Exc.GTable
module C = Cast
module I = Iast
module CP = Cpure
module IF = Iformula
module CF = Cformula
module MCP = Mcpure

let mem = Gen.BList.mem_eq CP.eq_spec_var
let diff = Gen.BList.difference_eq CP.eq_spec_var
let remove_dups = Gen.BList.remove_dups_eq CP.eq_spec_var
let intersect = Gen.BList.intersect_eq CP.eq_spec_var

let eq_id s1 s2 = String.compare s1 s2 == 0

let mem_id = Gen.BList.mem_eq eq_id
let subset_id = Gen.BList.subset_eq eq_id

let rec partition_by_key key_of key_eq ls = 
  match ls with
  | [] -> []
  | e::es ->
    let ke = key_of e in 
    let same_es, other_es = List.partition (fun e -> key_eq ke (key_of e)) es in
    (ke, e::same_es)::(partition_by_key key_of key_eq other_es)

let bnd_vars_of_formula fv f args = 
  let bnd_vars = diff (fv f) args in
  let bnd_vars = List.filter (fun v ->
    match CP.type_of_spec_var v with
    | HpT -> false | _ -> true 
  ) bnd_vars in
  bnd_vars

let simplify f args = 
  let simplify_f = Tpdispatcher.simplify_raw in
  let bnd_vars = bnd_vars_of_formula (CP.fv) f args in
  if bnd_vars == [] then simplify_f f 
  else
    CP.mkExists_with_simpl simplify_f bnd_vars f None (CP.pos_of_formula f)

let simplify f args = 
  let pr1 = !CP.print_formula in
  let pr2 = !CP.print_svl in
  Debug.no_2 "Syn.simplify" pr1 pr2 pr1 simplify f args

let imply a c = Tpdispatcher.imply_raw a c

let is_sat f = Tpdispatcher.is_sat_raw f

let push_exists_for_args f args =
  let bnd_vars = bnd_vars_of_formula (CF.fv) f args in
  CF.push_exists bnd_vars f

(*****************)
(***** UTILS *****)
(*****************)
let is_pre_hprel (hpr: CF.hprel) = 
  match hpr.hprel_type with
  | INFER_UNFOLD -> true
  | _ -> false
  
let is_post_hprel (hpr: CF.hprel) =
  match hpr.hprel_type with
  | INFER_FOLD -> true
  | _ -> false

let sig_of_hrel (h: CF.h_formula) =
  match h with
  | HRel (hr_sv, hr_args, _) -> (hr_sv, CF.get_node_args h)
  | _ -> failwith ("Expected a HRel h_formula instead of " ^ (!CF.print_h_formula h))

let name_of_hrel (h: CF.h_formula) = 
  fst (sig_of_hrel h) 

let args_of_hrel (h: CF.h_formula) = 
  snd (sig_of_hrel h)

let sig_of_hprel (hpr: CF.hprel) =
  let is_pre = is_pre_hprel hpr in
  let hpr_f = if is_pre then hpr.hprel_lhs else hpr.hprel_rhs in
  let f_h, _, _, _, _, _ = x_add_1 CF.split_components hpr_f in
  match f_h with
  | HRel (hr_sv, hr_args, _) -> (hr_sv, CF.get_node_args f_h)
  | _ -> failwith ("Unexpected formula in the " ^ 
                   (if is_pre then "LHS" else "RHS") ^ " of a " ^
                   (if is_pre then "pre-" else "post-") ^ "hprel " ^ 
                   (Cprinter.string_of_hprel_short hpr))

let name_of_hprel (hpr: CF.hprel) = 
  fst (sig_of_hprel hpr) 

let args_of_hprel (hpr: CF.hprel) = 
  snd (sig_of_hprel hpr)

let body_of_hprel (hpr: CF.hprel) =
  if is_pre_hprel hpr then hpr.hprel_rhs else hpr.hprel_lhs

let is_non_inst_hprel prog (hprel: CF.hprel) =
  let hprel_name = CP.name_of_spec_var (name_of_hprel hprel) in
  let hprel_def = Cast.look_up_hp_def_raw prog.Cast.prog_hp_decls hprel_name in
  let hprel_inst = hprel_def.Cast.hp_vars_inst in
  List.for_all (fun (_, i) -> i = Globals.NI) hprel_inst

let is_non_inst_hrel prog (hrel: CF.h_formula) =
  let hrel_name = CP.name_of_spec_var (name_of_hrel hrel) in
  let hrel_def = Cast.look_up_hp_def_raw prog.Cast.prog_hp_decls hrel_name in
  let hrel_inst = hrel_def.Cast.hp_vars_inst in
  List.for_all (fun (_, i) -> i = Globals.NI) hrel_inst

let get_non_inst_args_hprel_id prog id args = 
  let hprel_def = Cast.look_up_hp_def_raw prog.Cast.prog_hp_decls id in
  let hprel_inst = hprel_def.Cast.hp_vars_inst in
  let () = y_binfo_hp (add_str "args" !CP.print_svl) args in
  let () = y_binfo_hp (add_str "hprel_inst" (pr_list (pr_pair !CP.print_sv string_of_arg_kind))) hprel_inst in
  (* List.fold_left (fun acc (arg, (_, i)) ->              *)
  (*   if i = Globals.NI then acc                          *)
  (*   else acc @ [arg]) [] (List.combine args hprel_inst) *)
  let rec helper args insts =
    match args, insts with
    | _, [] -> []
    | [], _ -> []
    | arg::args, (_, i)::insts ->
      let r = helper args insts in
      if i = Globals.NI then r
      else arg::r
  in
  helper args hprel_inst

let get_non_inst_args_hprel prog (hprel: CF.hprel) =
  let hprel_name, hprel_args = sig_of_hprel hprel in
  let hprel_id = CP.name_of_spec_var hprel_name in
  get_non_inst_args_hprel_id prog hprel_id hprel_args

module Ident = struct
  type t = ident
  let compare = String.compare
  let hash = Hashtbl.hash
  let equal i1 i2 = compare i1 i2 == 0 
end

module CG = Graph.Persistent.Digraph.Concrete(Ident)
module CGC = Graph.Components.Make(CG)

let rec dependent_graph_of_formula dg hprel_name hprel_f =
  match hprel_f with
  | CF.Base { formula_base_heap = f_h; }
  | CF.Exists { formula_exists_heap = f_h; } ->
    let f_hrels = List.filter CF.is_hrel (CF.split_star_conjunctions f_h) in
    let f_hrels_name = List.map (fun hr -> CP.name_of_spec_var (name_of_hrel hr)) f_hrels in
    List.fold_left (fun dg hr_name -> CG.add_edge dg hprel_name hr_name) dg f_hrels_name
  | CF.Or { formula_or_f1 = f1; formula_or_f2 = f2; } ->
    let dg = dependent_graph_of_formula dg hprel_name f1 in
    dependent_graph_of_formula dg hprel_name f2

let dependent_graph_of_hprel dg hprel = 
  let hpr_name = CP.name_of_spec_var (name_of_hprel hprel) in 
  let hpr_f = body_of_hprel hprel in
  let dg = CG.add_vertex dg hpr_name in
  dependent_graph_of_formula dg hpr_name hpr_f

let dependent_graph_of_hprel_list hprel_list =
  let dg = CG.empty in
  List.fold_left (fun dg hprel -> dependent_graph_of_hprel dg hprel) dg hprel_list

let compare_hprel dg hpr1 hpr2 = 
  let _, scc_f = CGC.scc dg in
  let hpr1_name = CP.name_of_spec_var (name_of_hprel hpr1) in
  let hpr2_name = CP.name_of_spec_var (name_of_hprel hpr2) in
  (scc_f hpr1_name) - (scc_f hpr2_name)

let sort_hprel_list hprel_list = 
  let dg = dependent_graph_of_hprel_list hprel_list in
  (* let _, scc_f = CGC.scc dg in                                   *)
  (* let compare_hprel hpr1 hpr2 =                                  *)
  (*   let hpr1_name = CP.name_of_spec_var (name_of_hprel hpr1) in  *)
  (*   let hpr2_name = CP.name_of_spec_var (name_of_hprel hpr2) in  *)
  (*   (scc_f hpr1_name) - (scc_f hpr2_name)                        *)
  (* in                                                             *)
  List.sort (compare_hprel dg) hprel_list

module SV = struct
  type t = CP.spec_var
  let equal = CP.eq_spec_var 
  let compare sv1 sv2 =
    if equal sv1 sv2 then 0
    else String.compare (CP.name_of_spec_var sv1) (CP.name_of_spec_var sv2) 
  let hash = Hashtbl.hash
  
end

module VG = Graph.Persistent.Digraph.Concrete(SV)
module VGC = Graph.Components.Make(CG)
module VGO = Graph.Oper.P(VG)

let heap_chain_of_formula aset f =
  let dg = VG.empty in
  let rec helper dg f =
    match f with
    | CF.Base { formula_base_heap = f_h; }
    | CF.Exists { formula_exists_heap = f_h; } ->
      let f_h_elems = CF.split_star_conjunctions f_h in
      List.fold_left (fun dg e ->
        match e with
        | CF.DataNode { h_formula_data_node = r; h_formula_data_arguments = args }
        | CF.ViewNode { h_formula_view_node = r; h_formula_view_arguments = args } ->
          let r_aliases = CP.EMapSV.find_equiv_all_new r aset in
          let args_aliases = List.concat (List.map (fun arg -> CP.EMapSV.find_equiv_all_new arg aset) args) in
          List.fold_left (fun dg r ->
            List.fold_left (fun dg arg -> VG.add_edge dg r arg) dg args_aliases) dg r_aliases
        | CF.HRel _ (* TODO: root of HRel *) 
        | _ -> dg) dg f_h_elems
    | CF.Or { formula_or_f1 = f1; formula_or_f2 = f2; } ->
      let dg = helper dg f1 in
      helper dg f2
  in
  helper dg f

let mk_num_args args = 
  fst (List.fold_left (fun (acc, i) arg -> (acc @ [(arg, i)], i + 1)) ([], 0) args)

let find_root_hprel_formula_base prog hprel_name num_args f =
  let f_fv = CF.fv f in
  let args = List.map fst num_args in
  (* let ni_args = get_non_inst_args_hprel_id prog hprel_name args in *)
  let feasible_num_args = List.filter (fun (sv, _) -> 
    (CP.is_node_typ sv) && 
    (* not (mem sv ni_args) && *)
    (mem sv f_fv)) num_args in
  match feasible_num_args with
  | [] -> None
  | r::[] -> Some r
  | _ ->
    let f_h, f_p, _, _, _, _ = CF.split_components f in
    let aliases = MCP.ptr_equations_without_null f_p in
    let aset = CP.EMapSV.build_eset aliases in
    let dg = heap_chain_of_formula aset f in
    (begin 
      try
        (* Find root of heap chain *)
        let r = List.find (fun (sv, _) -> 
            (is_empty (VG.pred dg sv)) &&
            not (is_empty (VG.succ dg sv))) feasible_num_args in
        Some r
      with _ ->
        let trans_dg = VGO.transitive_closure ~reflexive:true dg in
        let f_hrels = List.filter CF.is_hrel (CF.split_star_conjunctions f_h) in
        let f_rec_hrels = List.filter (fun hr -> 
            eq_str hprel_name (CP.name_of_spec_var (name_of_hrel hr))) f_hrels in
        let rec helper f_rec_hrels = 
          match f_rec_hrels with
          | [] -> None
          | h::hs ->
            let h_args = args_of_hrel h in
            let potential_roots = List.find_all (fun (ln, n) ->
                let rn = List.nth h_args n in
                VG.mem_edge trans_dg ln rn) feasible_num_args in
            if is_empty potential_roots then
              let has_backward_prt = List.exists (fun (ln, n) ->
                  let rn = List.nth h_args n in
                  VG.mem_edge trans_dg rn ln) feasible_num_args in
              if not has_backward_prt then helper hs
              else
                try
                  (* Find unchanged argument as a root *)
                  (* e.g lseg(a, x) -> lseg(b, x) * b::node(a) *)
                  let r = List.find (fun (ln, n) ->
                      let rn = List.nth h_args n in
                      mem rn (CP.EMapSV.find_equiv_all_new ln aset)) feasible_num_args
                  in Some r 
                with _ -> helper hs
            else
              try
                (* Find root in the highest scc *)
                let r = List.find (fun (r, n) ->
                    let others = List.filter (fun (_, i) -> i != n) potential_roots in
                    not (List.exists (fun (o, _) -> VG.mem_edge trans_dg o r) others)
                  ) potential_roots
                in Some r
              with _ -> helper hs
        in
        helper f_rec_hrels
    end)

let rec find_root_hprel_formula prog hprel_name num_args f =
  match f with
  | CF.Or { formula_or_f1 = f1; formula_or_f2 = f2; } ->
    let r1 = x_add find_root_hprel_formula prog hprel_name num_args f1 in
    (match r1 with
    | None -> find_root_hprel_formula prog hprel_name num_args f2
    | _ -> r1)
  | _ -> find_root_hprel_formula_base prog hprel_name num_args f

let find_root_one_hprel prog hprel = 
  let hprel_name, hprel_args = sig_of_hprel hprel in
  let pr = Cprinter.string_of_hprel_short in
  match hprel_args with
  | [] -> failwith ("Unexpected hprel with empty arguments: " ^ (pr hprel))
  | r::[] -> if CP.is_node_typ r then (r, 0) else failwith ("Cannot find root of the hprel " ^ (pr hprel))
  | _ ->
    let hprel_body = body_of_hprel hprel in
    let num_args = mk_num_args hprel_args in
    let root = find_root_hprel_formula prog (CP.name_of_spec_var hprel_name) num_args hprel_body in
    (begin match root with
    | None ->
      (begin try
        let r = List.find (fun (sv, _) -> CP.is_node_typ sv) num_args in
        let () = report_warning no_pos ("Choose the first heap arguments of hprel as its root at our own risk.") in
        r
      with _ -> failwith ("Cannot find root of the hprel " ^ (pr hprel)) end)
    | Some s -> s end)

let find_root_one_hprel prog hprel =
  let pr1 = Cprinter.string_of_hprel_short in
  let pr2 = pr_pair !CP.print_sv string_of_int in
  Debug.no_1 "Syn.find_root_one_hprel" pr1 pr2 
    (find_root_one_hprel prog) hprel

let find_root_hprel prog hprel = 
  let hprel_name, hprel_args = sig_of_hprel hprel in
  let hprel_id = CP.name_of_spec_var hprel_name in
  try
    let root_pos = x_add C.get_proot_hp_def_raw prog.C.prog_hp_decls hprel_id in
    (List.nth hprel_args root_pos, root_pos)
  with _ -> 
    let root_var, root_pos = find_root_one_hprel prog hprel in
    let hp_decl = C.set_proot_hp_def_raw root_pos prog.C.prog_hp_decls hprel_id in
    (root_var, root_pos)

let find_root_hprel prog hprel =
  let pr1 = Cprinter.string_of_hprel_short in
  let pr2 = pr_pair !CP.print_sv string_of_int in
  Debug.no_1 "Syn.find_root_hprel" pr1 pr2 (find_root_hprel prog) hprel

(* hprels must have the same sig *)
let find_root_hprel_list prog hprels =
  match hprels with
  | [] -> None
  | h::hs ->
    let _, h_i = x_add find_root_hprel prog h in
    let hs_roots = List.map (x_add find_root_hprel prog) hs in
    let is_consistent = List.for_all (fun (_, i) -> i == h_i) hs_roots in
    if not is_consistent then
      failwith ("TO FIX: Inconsistency in find_root_hprel_list")
    else Some h_i

let get_root_args_hp prog id all_args =
  let root_pos = C.get_proot_hp_def_raw prog.C.prog_hp_decls id in
  let root = List.nth all_args root_pos in
  let args = diff all_args [root] in
  root, args

let select_obj name_of obj_list obj_id_list = 
  List.partition (fun obj -> mem_id (name_of obj) obj_id_list) obj_list

let select_hprel_assume hprel_list hprel_id_list = 
  select_obj (fun hpr -> CP.name_of_spec_var (name_of_hprel hpr)) hprel_list hprel_id_list

let process_hprel_assumes_others s hprel_assume_stk (ids: regex_id_list) f_proc = 
  let () = print_endline_quiet "\n========================" in
  let () = print_endline_quiet (" Performing "^s) in
  let () = print_endline_quiet "========================" in
  let () = hprel_assume_stk # set (CF.add_infer_type_to_hprel (hprel_assume_stk # get)) in
  let sel_hprel_assume_list, others =
    match ids with
    | REGEX_STAR -> hprel_assume_stk # get, []
    | REGEX_LIST hps -> select_hprel_assume (hprel_assume_stk # get) hps
  in
  let res = f_proc others sel_hprel_assume_list in
  hprel_assume_stk # set (res @ others)

let process_hprel_assumes_res s hprel_assume_stk hprel_assume_of_res (ids: regex_id_list) f_proc = 
  let () = print_endline_quiet "\n========================" in
  let () = print_endline_quiet (" Performing "^s) in
  let () = print_endline_quiet "========================" in
  let () = hprel_assume_stk # set (CF.add_infer_type_to_hprel (hprel_assume_stk # get)) in
  let sel_hprel_assume_list, others =
    match ids with
    | REGEX_STAR -> hprel_assume_stk # get, []
    | REGEX_LIST hps -> select_hprel_assume (hprel_assume_stk # get) hps
  in
  let res = f_proc others sel_hprel_assume_list in
  let () = hprel_assume_stk # set ((hprel_assume_of_res res) @ others) in
  res

(*********************)
(* UTILS FOR FORMULA *)
(*********************)
let combine_Star prog f1 f2 = 
  let comb_base f1 f2 =
    let comb_f = CF.mkStar f1 f2 CF.Flow_combine no_pos in
    Solver.elim_unsat_all prog comb_f in
  let rec comb_base_f1 f1 f2 =
    match f2 with
    | CF.Base _
    | CF.Exists _ -> comb_base f1 f2
    | CF.Or { 
        formula_or_f1 = f2_1;
        formula_or_f2 = f2_2;
        formula_or_pos = pos; } ->
      let comb_f1 = comb_base_f1 f1 f2_1 in
      let comb_f2 = comb_base_f1 f1 f2_2 in
      CF.mkOr comb_f1 comb_f2 pos
  in
  let rec comb_formula f1 f2 =
    match f1 with
    | CF.Base _
    | CF.Exists _ -> comb_base_f1 f1 f2
    | CF.Or { 
        formula_or_f1 = f1_1;
        formula_or_f2 = f1_2;
        formula_or_pos = pos; } ->
      let comb_f1 = comb_formula f1_1 f2 in
      let comb_f2 = comb_formula f1_2 f2 in
      CF.mkOr comb_f1 comb_f2 pos
  in
  comb_formula f1 f2

let combine_Star prog f1 f2 = 
  let pr = !CF.print_formula in
  Debug.no_2 "combine_Star" pr pr pr (combine_Star prog) f1 f2

(* let trans_heap_formula f_h_f (f: CF.formula) =                                       *)
(*   let somef2 _ f = Some (f, []) in                                                   *)
(*   let id2 f _ = (f, []) in                                                           *)
(*   let ida _ f = (f, []) in                                                           *)
(*   let f_arg = (voidf2, voidf2, voidf2, (voidf2, voidf2, voidf2), voidf2) in          *)
(*   CF.trans_formula f ()                                                              *)
(*     (nonef2, nonef2, f_h_f, (somef2, somef2, somef2), (somef2, id2, ida, id2, id2))  *)
(*     f_arg List.concat                                                                *)

let rec trans_pure_formula f_m_f (f: CF.formula) = 
  match f with
  | CF.Base b ->
    let n_pure = f_m_f b.formula_base_pure in
    CF.Base { b with formula_base_pure = n_pure; }
  | CF.Or o ->
    let n_f1 = trans_pure_formula f_m_f o.formula_or_f1 in
    let n_f2 = trans_pure_formula f_m_f o.formula_or_f2 in
    CF.Or { o with formula_or_f1 = n_f1; formula_or_f2 = n_f2; }
  | CF.Exists e ->
    let n_pure = f_m_f e.formula_exists_pure in
    CF.Exists { e with formula_exists_pure = n_pure; }

let simplify_hprel (hprel: CF.hprel) =
  (* let args = args_of_hprel hprel in *)
  let h_fv_lhs = 
    (CF.fv_heap_of hprel.hprel_lhs) @
    (if is_post_hprel hprel then args_of_hprel hprel else []) 
  in
  let h_fv_lhs = remove_dups h_fv_lhs in
  let h_fv_guard = match hprel.hprel_guard with None -> [] | Some g -> CF.fv_heap_of g in
  let h_fv_guard = remove_dups h_fv_guard in
  let h_fv_rhs = (CF.fv_heap_of hprel.hprel_rhs) @ (CF.fv hprel.hprel_lhs) in
  let h_fv_rhs = remove_dups h_fv_rhs in
  let f_m_f args m_f =
    let p_f = MCP.pure_of_mix m_f in
    let simpl_p_f = simplify p_f args in
    MCP.mix_of_pure simpl_p_f 
  in
  { hprel with
    hprel_lhs = trans_pure_formula (f_m_f h_fv_lhs) hprel.hprel_lhs;
    hprel_guard = map_opt (trans_pure_formula (f_m_f h_fv_guard)) hprel.hprel_guard; 
    hprel_rhs = trans_pure_formula (f_m_f h_fv_rhs) hprel.hprel_rhs; }

let simplify_hprel (hprel: CF.hprel) =
  let pr = Cprinter.string_of_hprel_short in
  Debug.no_1 "simplify_hprel" pr pr simplify_hprel hprel

let get_feasible_node_args prog (hf: CF.h_formula) =
  match hf with
  | HRel (hrel, el, _) ->
    let hrel_name = CP.name_of_spec_var hrel in
    let hprel_def = Cast.look_up_hp_def_raw prog.Cast.prog_hp_decls hrel_name in
    let el_inst = 
      try List.combine el (List.map snd hprel_def.Cast.hp_vars_inst)
      with Invalid_argument _ -> failwith ("SynUtils: Number of arguments of HRel " ^ hrel_name ^ " mismatched.")
    in
    List.fold_left (fun acc (e, i) ->
        match e with
        | CP.Var (sv, _) -> if i = Globals.NI then acc else acc @ [sv]
        | _ -> failwith ("Unexpected exp (not CP.Var) in HRel " ^ hrel_name ^ "'s arguments.")) 
      [] el_inst
  | _ -> CF.get_node_args hf

let collect_feasible_heap_args_formula prog null_aliases (f: CF.formula) : CP.spec_var list = 
  let rec helper f = 
    match f with
    | CF.Base ({ formula_base_heap = h; formula_base_pure = p; })
    | CF.Exists ({ formula_exists_heap = h; formula_exists_pure = p; }) ->
      let heaps = CF.split_star_conjunctions h in
      let heaps = List.filter (fun h ->
          match h with | CF.HEmp | CF.HTrue -> false | _ -> true) heaps
      in
      let heap_args = Gen.BList.remove_dups_eq CP.eq_spec_var 
          (List.concat (List.map (fun h ->
            let heap_node = try [CF.get_node_var h] with _ -> []
            in heap_node @ (get_feasible_node_args prog h)) heaps)) in
      if is_empty null_aliases then heap_args
      else
        List.filter (fun arg -> not (Gen.BList.mem_eq CP.eq_spec_var arg null_aliases)) heap_args
    | CF.Or ({ formula_or_f1 = f1; formula_or_f2 = f2; }) ->
      (helper f1) @ (helper f2)
  in helper f

let collect_feasible_heap_args_formula prog null_aliases (f: CF.formula) : CP.spec_var list = 
  Debug.no_2 "collect_feasible_heap_args_formula" !CP.print_svl !CF.print_formula !CP.print_svl
    (collect_feasible_heap_args_formula prog) null_aliases f

let rec ctx_of_formula (f: CF.formula) = 
  let empty_es = CF.empty_es (CF.mkNormalFlow ()) Label_only.Lab2_List.unlabelled no_pos in
  let empty_ctx = CF.Ctx empty_es in
  CF.build_context empty_ctx f no_pos

let heap_entail_formula prog (ante: CF.formula) (conseq: CF.formula) =
  let ctx = ctx_of_formula ante in
  let rs, _ = x_add Solver.heap_entail_one_context 21 prog false ctx conseq None None None no_pos in
  let residue_f = CF.formula_of_list_context rs in
  match rs with
  | CF.FailCtx _ -> (false, residue_f)
  | CF.SuccCtx lst -> (true, residue_f) 

let heap_entail_formula prog (ante: CF.formula) (conseq: CF.formula) =
  let pr1 = !CF.print_formula in
  let pr2 = pr_pair string_of_bool pr1 in
  Debug.no_2 "Syn.heap_entail_formula" pr1 pr1 pr2 
    (fun _ _ -> heap_entail_formula prog ante conseq) ante conseq

let heap_entail_exact_formula prog (ante: CF.formula) (conseq: CF.formula) =
  fst (Wrapper.wrap_classic (Some true) (heap_entail_formula prog ante) conseq)

let heap_entail_exact_formula prog (ante: CF.formula) (conseq: CF.formula) =
  let pr1 = !CF.print_formula in
  let pr2 = string_of_bool in
  Debug.no_2 "Syn.heap_entail_exact_formula" pr1 pr1 pr2 
    (fun _ _ -> heap_entail_exact_formula prog ante conseq) ante conseq

let get_equiv_pred prog vid =
  try
    let vdef = C.look_up_view_def_raw 40 prog.Cast.prog_view_decls vid in
    if not !Globals.pred_equiv then vid
    else if vdef.C.view_equiv_set # is_empty then vid
    else
      let (_, subs_vid) = vdef.C.view_equiv_set # get in
      subs_vid
  with _ -> vid

let trans_hrel_to_view_formula prog (f: CF.formula) = 
  let f_h_f _ hf = 
    match hf with
    | CF.HRel _ ->
      let hrel_name, hrel_args = sig_of_hrel hf in
      let hrel_id = CP.name_of_spec_var hrel_name in
      let subs_hrel_name, view_args =
          try
            let vdef = C.look_up_view_def_raw 40 prog.Cast.prog_view_decls hrel_id in
            if not !Globals.pred_equiv then hrel_name, vdef.view_vars
            else if vdef.C.view_equiv_set # is_empty then hrel_name, vdef.view_vars
            else
              let (_, subs_hrel_id) = vdef.C.view_equiv_set # get in
              let equiv_pred = match hrel_name with
                | CP.SpecVar (t, n, p) -> CP.SpecVar (t, subs_hrel_id, p) in
              let equiv_pred_args = 
                try 
                  let edef = C.look_up_view_def_raw 50 prog.Cast.prog_view_decls subs_hrel_id in
                  edef.view_vars
                with _ ->
                  let () = report_warning no_pos ("Cannot find the definition of the equiv pred " ^ subs_hrel_id) in 
                  vdef.view_vars
              in
              equiv_pred, equiv_pred_args
          with _ -> hrel_name, []
      in
      let hrel_root, hrel_args = get_root_args_hp prog hrel_id hrel_args in
      let extn_args =
        (* Get the extn pred arguments *)
        let rec helper h_args v_args =
          match h_args, v_args with
          | [], _ -> v_args
          | _, [] -> []
          | h::hs, v::vs -> helper hs vs 
        in
        helper hrel_args view_args  
      in
      let n_hf = CF.mk_HRel_as_view_w_root subs_hrel_name hrel_root (hrel_args @ extn_args) no_pos in
      (match n_hf with
      | CF.ViewNode v ->
        (* Setting imm is important for lemma proving *)
        let n_hf = CF.ViewNode { v with CF.h_formula_view_imm = CP.ConstAnn(Mutable); } in
        Some (n_hf, extn_args)
      | _ -> None)
    | _ -> None
  in
  CF.trans_heap_formula f_h_f f

let trans_hrel_to_view_formula prog (f: CF.formula) = 
  let pr1 = !CF.print_formula in
  let pr2 = pr_pair (add_str "trans_f" pr1) (add_str "extn_args" !CP.print_svl) in
  Debug.no_1 "Syn.trans_hrel_to_view_formula" pr1 pr2 
    (fun _ -> trans_hrel_to_view_formula prog f) f

let rec trans_hrel_to_view_struc_formula prog (sf: CF.struc_formula) =
  match sf with
  | CF.EList el -> CF.EList (List.map (fun (sld, sf) -> (sld, (trans_hrel_to_view_struc_formula prog) sf)) el)
  | CF.ECase ec -> 
    CF.ECase { ec with
      CF.formula_case_branches = List.map (fun (c, sf) -> 
          (c, trans_hrel_to_view_struc_formula prog sf)) ec.CF.formula_case_branches; }
  | CF.EBase eb -> 
    let n_base, extn_args = trans_hrel_to_view_formula prog eb.CF.formula_struc_base in
    CF.EBase { eb with
      CF.formula_struc_base = n_base;
      CF.formula_struc_implicit_inst = remove_dups (eb.CF.formula_struc_implicit_inst @ extn_args);
      CF.formula_struc_continuation = map_opt (trans_hrel_to_view_struc_formula prog) eb.CF.formula_struc_continuation; }
  | CF.EAssume ea ->
    CF.EAssume { ea with 
      CF.formula_assume_simpl = fst (trans_hrel_to_view_formula prog ea.CF.formula_assume_simpl);
      CF.formula_assume_struc = trans_hrel_to_view_struc_formula prog ea.CF.formula_assume_struc; }
  | EInfer ei -> 
    CF.EInfer { ei with 
      CF.formula_inf_continuation = trans_hrel_to_view_struc_formula prog ei.CF.formula_inf_continuation; }

(* let trans_hrel_to_view_spec_proc cprog proc =                                            *)
(*   let spec = proc.C.proc_stk_of_static_specs # top in                                    *)
(*   let nspec = trans_hrel_to_view_struc_formula spec in                                   *)
(*   let () = proc.C.proc_stk_of_static_specs # push_pr ("SynUtils:" ^ x_loc) nspec in      *)
(*   let nproc = { proc with                                                                *)
(*     C.proc_static_specs = nspec;                                                         *)
(*     C.proc_dynamic_specs = trans_hrel_to_view_struc_formula proc.C.proc_dynamic_specs; } *)
(*   in                                                                                     *)
(*   nproc                                                                                  *)

(* let trans_hrel_to_view_spec_scc cprog scc_procs =                                        *)
(*   let n_tbl = Cast.proc_decls_map (fun proc ->                                           *)
(*       if mem_id proc.C.proc_name scc_procs then                                          *)
(*         trans_hrel_to_view_spec_proc cprog proc                                          *)
(*       else proc) cprog.Cast.new_proc_decls in                                            *)
(*   { cprog with Cast.new_proc_decls = n_tbl }                                             *)

let rec remove_inf_vars_struc_formula inf_vars (sf: CF.struc_formula) =
  match sf with
  | CF.EList el -> CF.EList (List.map (fun (sld, sf) -> (sld, remove_inf_vars_struc_formula inf_vars sf)) el)
  | CF.ECase ec -> 
    CF.ECase { ec with
      CF.formula_case_branches = List.map (fun (c, sf) -> 
          (c, remove_inf_vars_struc_formula inf_vars sf)) ec.CF.formula_case_branches; }
  | CF.EBase eb -> 
    CF.EBase { eb with
      CF.formula_struc_continuation = map_opt (remove_inf_vars_struc_formula inf_vars) eb.CF.formula_struc_continuation; }
  | CF.EAssume _ -> sf
  | EInfer ei -> 
    let () = ei.CF.formula_inf_obj # reset (INF_EXTN []) in
    CF.EInfer { ei with 
      CF.formula_inf_vars = diff ei.CF.formula_inf_vars inf_vars;
      CF.formula_inf_continuation = remove_inf_vars_struc_formula inf_vars ei.CF.formula_inf_continuation; }

let trans_spec_proc trans_f cprog proc =
  let spec = proc.C.proc_stk_of_static_specs # top in
  let nspec = trans_f spec in
  let pr_spec = Cprinter.string_of_struc_formula_for_spec in
  let () = y_tinfo_hp (add_str "spec" pr_spec) spec in
  let () = y_tinfo_hp (add_str "nspec" pr_spec) nspec in
  let () = proc.C.proc_stk_of_static_specs # push_pr ("SynUtils:" ^ x_loc) nspec in
  let nproc = { proc with
    C.proc_static_specs = nspec;
    C.proc_dynamic_specs = trans_f proc.C.proc_dynamic_specs; }
  in
  nproc

let trans_spec_scc trans_f cprog scc_procs =
  let n_tbl = Cast.proc_decls_map (fun proc ->
      if mem_id proc.C.proc_name scc_procs then
        trans_spec_proc trans_f cprog proc
      else proc) cprog.Cast.new_proc_decls in
  { cprog with Cast.new_proc_decls = n_tbl }

let trans_hrel_to_view_spec_scc cprog scc_procs =
  trans_spec_scc (trans_hrel_to_view_struc_formula cprog) cprog scc_procs

let remove_inf_vars_spec_scc cprog scc_procs inf_vars = 
  trans_spec_scc (remove_inf_vars_struc_formula inf_vars) cprog scc_procs

let rec get_inf_pred_extn_struc_formula f = 
  match f with
  | CF.EInfer ei -> ei.formula_inf_obj # get_infer_extn_lst
  | CF.EBase eb -> begin
      match eb.formula_struc_continuation with
      | None -> []
      | Some c -> get_inf_pred_extn_struc_formula c
    end 
  | CF.EAssume _ -> []
  | CF.ECase ec -> List.concat (List.map 
      (fun (_, c) -> get_inf_pred_extn_struc_formula c) ec.formula_case_branches)
  | CF.EList el -> List.concat (List.map (fun (_, c) -> get_inf_pred_extn_struc_formula c) el)

let find_heap_node root (f: CF.formula) =
  let _, f_p, _, _, _, _ = CF.split_components f in
  let aliases = MCP.ptr_equations_without_null f_p in
  let aset = CP.EMapSV.build_eset aliases in
  let root_aliases = CP.EMapSV.find_equiv_all_new root aset in
  let f_h_f _ h_f =
    match h_f with
    | CF.DataNode ({ h_formula_data_node = pt; } as h_data) ->
      if mem pt root_aliases then Some (CF.HEmp, [h_data])
      else None
    | _ -> None
  in
  let n_f, root_node = CF.trans_heap_formula f_h_f f in
  n_f, root_node

let is_consistent_node_list nodes = 
  match nodes with
  | [] -> true
  | n::ns -> List.for_all (fun d -> 
      (eq_str d.CF.h_formula_data_name n.CF.h_formula_data_name) &&
      (List.length n.CF.h_formula_data_arguments == List.length d.CF.h_formula_data_arguments)) ns

let norm_node_list nodes =
  match nodes with
  | [] -> failwith "Unexpected empty node list."
  | n::_ ->
    let n_args = CP.fresh_spec_vars n.CF.h_formula_data_arguments in
    let sst_list = List.map (fun n -> List.combine n.CF.h_formula_data_arguments n_args) nodes in
    let norm_root = { n with CF.h_formula_data_arguments = n_args; } in
    norm_root, sst_list
  
let rec find_common_node_chain root (fs: CF.formula list) =
  let residue_fs, root_node_list = List.split (List.map (find_heap_node root) fs) in
  if List.exists is_empty root_node_list then (fs, [])
  else if List.exists (fun ns -> List.length ns > 1) root_node_list then
    failwith "There is a formula which has more than one root nodes."
  else 
    let root_node_list = List.map List.hd root_node_list in
    if not (is_consistent_node_list root_node_list) then
      failwith "The list of root nodes is not consistent."
    else
      let root_node, sst_list = norm_node_list root_node_list in
      let root_node = { root_node with CF.h_formula_data_node = root } in
      let norm_fs = List.map (fun (f, sst) -> CF.subst_all sst f) (List.combine residue_fs sst_list) in
      List.fold_left (fun (fs, node_chain) arg -> 
          let n_fs, arg_node_chain = find_common_node_chain arg fs in
          n_fs, (node_chain @ arg_node_chain)) 
        (norm_fs, [CF.DataNode root_node]) (List.filter CP.is_node_typ root_node.CF.h_formula_data_arguments)

let find_common_node_chain root (fs: CF.formula list) =
  let pr1 = !CP.print_sv in
  let pr2 = pr_list !CF.print_formula in
  let pr3 = pr_list !CF.print_h_formula in
  let pr4 = fun (_, h_l) -> pr3 h_l in
  Debug.no_2 "find_common_node_chain" pr1 pr2 (* (pr_pair pr2 pr3) *) pr4
    find_common_node_chain root fs

let find_common_node_chain_branches root (fs: CF.formula list) =
  let common_node_list = List.map (fun f -> snd (find_heap_node root f)) fs in
  if List.exists (fun ns -> List.length ns > 1) common_node_list then
    failwith "There is a formula which has more than one root nodes."
  else
    let fs_share_heap_node, others = List.partition 
        (fun (_, ns) -> not (is_empty ns)) 
        (List.combine fs common_node_list) in
    let other_fs = List.map fst others in
    let _, node_chain = find_common_node_chain root (List.map fst fs_share_heap_node) in
    node_chain, other_fs

let get_all_node_name (h_f: CF.h_formula): ident list =
  let f_h_f _ h_f =
    try
      let name = CF.get_node_name 20 h_f in
      Some (h_f, [name])
    with _ -> None
  in
  snd (CF.trans_h_formula h_f () f_h_f voidf2 List.concat)

let rec get_all_node_name_formula (f: CF.formula): ident list = 
  match f with
  | CF.Base _
  | CF.Exists _ ->
    let f_h, _, _, _, _, _ = CF.split_components f in
    get_all_node_name f_h
  | CF.Or { formula_or_f1 = f1; formula_or_f2 = f2; } ->
    (get_all_node_name_formula f1) @ (get_all_node_name_formula f2)

let is_pred_base_case mut_pred_list (f: CF.formula) =
  let f_h, _, _, _, _, _ = CF.split_components f in
  let f_node_names = get_all_node_name f_h in
  not (Gen.BList.overlap_eq eq_str f_node_names mut_pred_list)

let find_pred_base_case (pred: C.view_decl): CF.formula list =
  let pred_f = C.formula_of_unstruc_view_f pred in
  let pred_cases = CF.list_of_disjuncts pred_f in
  let mut_pred_list =
    try
      List.find (fun scc -> Gen.BList.mem_eq eq_str pred.C.view_name scc) !Astsimp.view_scc
    with _ -> [pred.C.view_name]
  in
  List.find_all (fun f -> is_pred_base_case mut_pred_list f) pred_cases

(******************)
(* UTILS FOR VIEW *)
(******************)
let view_decl_of_hprel prog (hprel: CF.hprel) =
  let hprel_name, hprel_args = sig_of_hprel hprel in
  let pos = no_pos in
  (* let hprel_self = CP.to_unprimed (List.hd hprel_args) in *)
  let hprel_root = fst (x_add find_root_hprel prog hprel) in
  let hprel_self = CP.to_unprimed hprel_root in
  let vself = match hprel_self with CP.SpecVar (t, _, p) -> CP.SpecVar (t, Globals.self, p) in
  let vargs = List.map (fun sv -> (sv, NI)) (diff hprel_args [hprel_root]) (* List.tl hprel_args *) in
  let vbody = if is_pre_hprel hprel then hprel.hprel_rhs else hprel.hprel_lhs in
  let vbody = CF.elim_prm vbody in
  let vbody, _ = trans_hrel_to_view_formula prog vbody in
  let vbody = CF.subst [(hprel_self, vself)] vbody in
  (* Set flow for view *)
  let vbody = CF.set_flow_in_formula_override 
      { CF.formula_flow_interval = !top_flow_int; CF.formula_flow_link = None } 
      vbody in
  let vdecl = Cast.mk_view_decl_for_hp_rel (CP.name_of_spec_var hprel_name) vargs false pos in
  let vdecl_w_def = { vdecl with 
      Cast.view_formula = CF.formula_to_struc_formula vbody;
      Cast.view_un_struc_formula = [(vbody, (fresh_int (), ""))];
      Cast.view_kind = View_NORM; } in
  (* let () = Cast.update_view_decl prog vdecl_w_def in *)
  vdecl_w_def

let view_decl_of_hprel prog (hprel: CF.hprel) =
  let pr1 = Cprinter.string_of_hprel_short in
  let pr2 = Cprinter.string_of_view_decl in
  Debug.no_1 "Syn.view_decl_of_hprel" pr1 pr2 (view_decl_of_hprel prog) hprel

let norm_derived_views iprog cprog derived_views = 
  (* The iprog.I.prog_view_decls are also normalized by SleekUtils.process_selective_iview_decls *)
  let iviews = List.map Rev_ast.rev_trans_view_decl derived_views in
  let cviews = SleekUtils.process_selective_iview_decls false iprog iviews in
  let norm_cviews = (* SleekUtils.norm_cview_decls iprog cprog *) cviews in
  let () = List.iter (Cast.update_view_decl cprog) norm_cviews in
  let () = y_tinfo_hp (add_str "derived_views" Cprinter.string_of_view_decl_list) derived_views in
  let () = y_tinfo_hp (add_str "iviews" Iprinter.string_of_view_decl_list) iviews in
  let () = y_tinfo_hp (add_str "cviews" Cprinter.string_of_view_decl_list) cviews in
  let () = y_tinfo_hp (add_str "norm_cviews" Cprinter.string_of_view_decl_list) norm_cviews in
  norm_cviews

let norm_derived_views iprog cprog derived_views =
  let pr = pr_list Cprinter.string_of_view_decl in
  Debug.no_1 "norm_derived_views" pr pr 
    (norm_derived_views iprog cprog) derived_views

let norm_single_view iprog cprog view = 
  let norm_view = norm_derived_views iprog cprog [view] in
  match norm_view with
  | v::[] -> v
  | _ -> view

let restore_view iprog cprog view = 
  let iview = Rev_ast.rev_trans_view_decl view in
  let () = C.update_view_decl cprog view in
  let () = I.update_view_decl iprog iview in
  ()

let elim_useless_vars svl = 
  List.filter (fun v -> not (CP.is_var_typ v)) svl

let mk_self_node typ_name f =
  try
    List.find (fun sv -> eq_str (CP.name_of_spec_var sv) Globals.self) (CF.fv f)
  with _ -> CP.SpecVar (Named typ_name, Globals.self, Unprimed)
  
let unfolding_formula cprog f_unfold f =
  let f_views = CF.get_views f in
  if is_empty f_views then f
  else
    let unfold_f, _ = List.fold_left (fun (f, sst) vv ->
        let vv = CP.subst_var_par sst vv in
        let n_f, n_sst = f_unfold f vv in
        (n_f, sst @ n_sst)) 
      (f, []) (List.map (fun vn -> vn.CF.h_formula_view_node) f_views)
    in unfold_f

let unfolding_formula cprog f_unfold f =
  let pr = !CF.print_formula in
  Debug.no_1 "Syn.unfolding_formula" pr pr 
    (unfolding_formula cprog f_unfold) f

let unfolding_view iprog cprog view =
  let f_unfold f sv = Solver.unfold_nth 50 (cprog, None) f sv true 0 no_pos in
  let view_f = C.formula_of_unstruc_view_f view in
  let view_branches = CF.list_of_disjuncts view_f in
  let view_branches = List.map (fun f -> unfolding_formula cprog f_unfold f) view_branches in
  let unfold_view_f = CF.formula_of_disjuncts view_branches in
  let self_node = mk_self_node view.C.view_name unfold_view_f in
  let () = 
    view.C.view_formula <- CF.formula_to_struc_formula 
        (Typeinfer.case_normalize_renamed_formula iprog (self_node::(elim_useless_vars view.C.view_vars)) [] unfold_view_f);
    view.C.view_un_struc_formula <- [(unfold_view_f, (fresh_int (), ""))];
  in
  let norm_view = norm_single_view iprog cprog view in
  norm_view

let unfolding_view iprog cprog view =
  let pr = Cprinter.string_of_view_decl in
  Debug.no_1 "Syn.unfolding_view" pr pr 
    (unfolding_view iprog cprog) view

(*******************)
(* UTILS FOR LEMMA *)
(*******************)
let is_not_global_hp_def prog i =
  try
    let todo_unk = C.look_up_hp_def_raw prog.C.prog_hp_decls i 
    in false
  with _ -> true

let is_not_global_rel prog i =
  try
    let todo_unk = C.look_up_rel_def_raw (prog.C.prog_rel_decls # get_stk) i 
    in false
  with _ -> true

let univ_vars_of_lemma l_head = 
  let h, p, vp, _, _,_ = CF.split_components l_head in
  let pvars = MCP.mfv p in
  let pvars = List.filter (fun (CP.SpecVar (_,id,_)) -> 
    not (id = Globals.cyclic_name || 
         id = Globals.acyclic_name || 
         id = Globals.concrete_name || 
         id = Globals.set_comp_name)) pvars in (* ignore cyclic & acyclic rels *)
  let hvars = CF.h_fv h in
  let univ_vars = Gen.BList.difference_eq CP.eq_spec_var pvars hvars in 
  Gen.BList.remove_dups_eq CP.eq_spec_var univ_vars

let mater_vars_of_lemma prog l_head l_body = 
  let args = CF.fv_simple_formula l_head in 
  let m_vars = Astsimp.find_materialized_prop args [] l_body in
  let m_vars = List.map (fun m -> 
    let vs = m.C.mater_target_view in
    let vs2 = List.filter (fun v -> (is_not_global_rel prog v) && (is_not_global_hp_def prog v)) vs in
    (m, vs, vs2)) m_vars in
  let m_vars = List.filter (fun (m, vs, vs2) -> vs == [] || vs2 != []) m_vars in
  let m_vars = List.map (fun (m, vs, vs2) -> { m with C.mater_target_view = vs2 }) m_vars in
  m_vars

(* Adapted from Astsimp.trans_one_coercion_x *)
let mk_lemma prog l_name l_is_classic l_ivars l_itypes l_kind l_type l_head l_body pos =
  let iobj = new Globals.inf_obj_sub in
  let () = iobj # set_list l_itypes in
  { C.coercion_type = l_type;
    C.coercion_exact = l_is_classic;
    C.coercion_name = l_name;
    C.coercion_head = l_head;
    C.coercion_head_norm = l_head (* CF.mkTrue (CF.mkNormalFlow ()) pos *);
    C.coercion_body = l_body; 
    C.coercion_body_norm = CF.struc_formula_of_formula l_body (* (CF.mkTrue (CF.mkNormalFlow ()) pos) *) pos;
    C.coercion_impl_vars = [];
    C.coercion_univ_vars = univ_vars_of_lemma l_head;
    C.coercion_infer_vars = l_ivars;
    C.coercion_infer_obj = iobj;
    C.coercion_fold_def = new Gen.mut_option;
    C.coercion_head_view = Astsimp.find_view_name l_head Globals.self pos;
    C.coercion_body_view = Astsimp.find_view_name l_body Globals.self pos;
    C.coercion_body_pred_list = CF.extr_pred_list l_body;
    C.coercion_mater_vars = mater_vars_of_lemma prog l_head l_body;
    C.coercion_case = C.case_of_coercion l_head l_body;
    C.coercion_type_orig = None;
    C.coercion_kind = l_kind;
    C.coercion_origin = LEM_GEN; }
