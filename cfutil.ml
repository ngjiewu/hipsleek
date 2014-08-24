open Globals
open Gen
open Cformula

module DD = Debug
(* module CF = Cformula *)
module CP = Cpure
module MCP = Mcpure
module C = Cast
module I = Iast
module TP = Tpdispatcher


let rec get_pos_x ls n sv=
  match ls with
    | [] -> report_error no_pos "sau.get_pos: impossible 1"
    | sv1::rest -> if CP.eq_spec_var sv sv1 then n
      else get_pos_x rest (n+1) sv

let get_pos ls n sv=
  let pr1 = !CP.print_svl in
  Debug.no_3 "sau.get_pos" pr1 string_of_int !CP.print_sv string_of_int
      (fun _ _ _ -> get_pos_x ls n sv)
      ls n sv

let rec set_pos ls pos n sv res=
  match ls with
    | [] -> res
    | sv1::rest -> if pos=n then (res@(sv::rest))
      else set_pos rest (n+1) n sv (res@[sv1])


let rec retrieve_args_from_locs_helper args locs index res=
  match args with
    | [] -> res
    | a::ss -> if List.mem index locs then
          retrieve_args_from_locs_helper ss locs (index+1) (res@[a])
        else retrieve_args_from_locs_helper ss locs (index+1) res

let retrieve_args_from_locs args locs=
  retrieve_args_from_locs_helper args locs 0 []


let rec is_empty_heap_f f0=
  let rec helper f=
    match f with
      | Base fb ->
          (is_empty_heap fb.formula_base_heap)
      | Exists fe -> (* (CF.is_empty_heap fe.CF.formula_exists_heap) *)
          let _, base_f = split_quantifiers f in
          is_empty_heap_f base_f
      | Or orf -> (helper orf.formula_or_f1) && (helper orf.formula_or_f2)
  in
  helper f0

let is_view_f f=
  match f with
    | Base {formula_base_heap = h}
    | Exists {formula_exists_heap = h} -> is_view h
    | _ -> false


let checkeq_view_node vn1 vn2=
  String.compare vn1.h_formula_view_name vn2.h_formula_view_name = 0 &&
      CP.eq_spec_var vn1.h_formula_view_node vn2.h_formula_view_node &&
      CP.eq_spec_var_order_list vn1.h_formula_view_arguments vn2.h_formula_view_arguments

let checkeq_view_node_with_null_x vnode1 vargs1 vnode2 vargs2 null_svl1 null_svl2=
  if CP.eq_spec_var vnode1 vnode2 then
    let arg_neqNull1 = CP.diff_svl vargs1 null_svl1 in
    let arg_neqNull2 = CP.diff_svl vargs2 null_svl2 in
    (List.length arg_neqNull1 = List.length arg_neqNull2) &&
            CP.diff_svl arg_neqNull1 arg_neqNull2 = []
  else false

let checkeq_view_node_with_null vnode1 vargs1 vnode2 vargs2 null_svl1 null_svl2=
  let pr1  = !CP.print_sv in
  let pr2 = !CP.print_svl in
  Debug.no_6 "checkeq_view_node_with_null" pr1 pr2 pr1 pr2 pr2 pr2 string_of_bool
      (fun _ _ _ _ _ _ -> checkeq_view_node_with_null_x vnode1 vargs1 vnode2 vargs2 null_svl1 null_svl2)
      vnode1 vargs1 vnode2 vargs2 null_svl1 null_svl2

let elim_null_vnodes_x prog sf=
  let null_detect_trans eq_nulls hf=
    match hf with
      | ViewNode vn ->
            if String.compare (CP.name_of_spec_var vn.h_formula_view_node) null_name = 0 then
              let vdcecl = Cast.look_up_view_def_raw 58 prog.Cast.prog_view_decls vn.h_formula_view_name in
              if vdcecl.Cast.view_is_segmented && CP.diff_svl vn.h_formula_view_arguments eq_nulls = [] then
                HEmp
              else hf
            else hf
      | _ -> hf
  in
  let is_base, f = base_formula_of_struc_formula sf in
  if not is_base then sf else
    let ( _,mix_f,_,_,_) = split_components f in
    let eq_nulls = ( MCP.get_null_ptrs mix_f) in
    struc_formula_trans_heap_node (formula_trans_heap_node (null_detect_trans eq_nulls)) sf

let elim_null_vnodes prog sf=
  let pr1 = !print_struc_formula in
  Debug.no_1 "elim_null_vnodes" pr1 pr1
      (fun _ -> elim_null_vnodes_x prog sf) sf

let elim_eqnull_x hn_elim_heap to_elim_null_svl f0=
  let elim_eq_null p=
    let ps = CP.list_of_conjs p in
    let ps1 = List.filter (fun p -> not (CP.is_eq_null_exp_in_list to_elim_null_svl p)) ps in
    CP.conj_of_list ps1 (CP.pos_of_formula p)
  in
  let rec helper f= match f with
    | Base b -> let nh = hn_elim_heap b.formula_base_heap in
      let np =  elim_eq_null (MCP.pure_of_mix b.formula_base_pure) in
      Base {b with formula_base_heap = nh;
          formula_base_pure = MCP.mix_of_pure np;}
    | Exists _ -> let quans, bare =  split_quantifiers f in
      let new_bare = helper bare in
      add_quantifiers quans new_bare
    | Or orf -> Or {orf with formula_or_f1 = helper orf.formula_or_f1;
              formula_or_f2 = helper orf.formula_or_f2;}
  in
  helper f0

let elim_eqnull hn_elim_heap to_elim_null_svl f0=
  let pr1 = !print_formula in
  Debug.no_2 "elim_eqnull" pr1!CP.print_svl  pr1
      (fun _ _ -> elim_eqnull_x hn_elim_heap to_elim_null_svl f0) f0 to_elim_null_svl

(* formula_trans_heap_node fct f *)
let simplify_htrue_x hf0=
  (*********INTERNAL***************)
  let rec elim_htrue_hemp hf=
    match hf with
      | HTrue -> HEmp
      | Star b -> begin let hf2 = elim_htrue_hemp b.h_formula_star_h2 in
        let hf1 = elim_htrue_hemp b.h_formula_star_h1 in
        match hf1,hf2 with
          | HEmp,HEmp -> HEmp
          | HEmp,_ -> hf2
          | _ , HEmp -> hf1
          | _ ->
            Star {b with h_formula_star_h2 = hf2; h_formula_star_h1 = hf1}
        end
      | _ -> hf
  in
  let star_elim_htrue_hemp hf htrue_left pos=
    let nhf = elim_htrue_hemp hf in
    match nhf with
      | HEmp -> HTrue
      | _ ->  if htrue_left then
          Star {h_formula_star_h1 = HTrue; h_formula_star_h2 = nhf;h_formula_star_pos = pos}
        else
          Star {h_formula_star_h2 = HTrue; h_formula_star_h1 = nhf;h_formula_star_pos = pos}
  in
  let rec dfs_elim_dups_htrue_emp hf=
    let recf =  dfs_elim_dups_htrue_emp in
    match hf with
      | Phase b -> Phase {b with h_formula_phase_rd = recf b.h_formula_phase_rd; h_formula_phase_rw = recf b.h_formula_phase_rw}
      | Star b -> begin
          let l_htrue = b.h_formula_star_h1 = HTrue in
          let r_htrue =  b.h_formula_star_h2 = HTrue in
          match  l_htrue, r_htrue with
            | true, true -> HTrue
            | true, _ -> star_elim_htrue_hemp b.h_formula_star_h2 true b.h_formula_star_pos
            | _ ,true -> star_elim_htrue_hemp b.h_formula_star_h1 false b.h_formula_star_pos
            | _ -> begin
                  let hf2 = recf b.h_formula_star_h2 in
                  let hf1 = recf b.h_formula_star_h1 in
                  match hf1,hf2 with
                    | HEmp,HEmp -> HEmp
                    | HTrue,HTrue -> HTrue
                    | HTrue,HEmp -> HTrue
                    | HEmp, HTrue -> HTrue
                    | HEmp,_ -> hf2
                    | _ , HEmp -> hf1
                    | _ ->
                          Star {b with h_formula_star_h2 = hf2; h_formula_star_h1 = hf1}
              end
        end
      | HRel _ | DataNode _ |  ViewNode _ | ThreadNode _
      | HFalse | Hole _ | FrmHole _ | HTrue | HEmp
      | Conj _ | ConjStar _|ConjConj _|StarMinus _ -> hf
  in
  (*********INTERNAL***************)
  dfs_elim_dups_htrue_emp hf0

let simplify_htrue hf=
  let pr1 = !print_h_formula in
  Debug.no_1 "simplify_htrue" pr1 pr1
      (fun _ -> simplify_htrue_x hf) hf

(*arg is global vars*)
let norm_free_vars f0 args=
  let rec helper f=
    match f with
      | Base fb -> let fr_svl = CP.remove_dups_svl (CP.diff_svl (List.filter (fun sv -> not (CP.is_hprel_typ sv))
            (* (CF.h_fv fb.CF.formula_base_heap) *)
            (fv f)
        ) args) in
        if fr_svl = [] then (f,[])
        else
          let _ = Debug.ninfo_hprint (add_str "fr_svl" !CP.print_svl) fr_svl no_pos in
          (*rename primed quantifiers*)
          let fr_svl1,ss = List.fold_left (fun (r_svl, r_ss) ((CP.SpecVar(t,id,p)) as sv) ->
              if p = Unprimed then
                (r_svl@[sv], r_ss)
              else
                (* let sv = CP.SpecVar (t, (ex_first ^ id), p ) in *)
                let fr_sv = CP.fresh_spec_var sv in
                (r_svl@[fr_sv], r_ss@[(sv,fr_sv)])
          ) ([],[]) fr_svl
          in
          let nf0 = if ss = [] then (Base fb) else
            subst ss (Base fb)
          in
          let _ = Debug.ninfo_hprint (add_str "       nf0:" !print_formula) nf0 no_pos in
          let nf = add_quantifiers fr_svl1 nf0 in
          let _ = Debug.ninfo_hprint (add_str "       nf:" !print_formula) nf no_pos in
          let tis = List.fold_left (fun ls (CP.SpecVar(t,sv,p)) ->
              let vk = Typeinfer.fresh_proc_var_kind ls t in
              let svp = sv ^(match p with Primed -> "PRM"| _ -> "") in
              ls@[(svp,vk)]
          ) [] fr_svl1 in
          (nf, tis)
      | Exists _ ->
            let qvars1, base1 = split_quantifiers f in
            let _ = Debug.ninfo_hprint (add_str "qvars1" !CP.print_svl) qvars1 no_pos in
            let base2,tis = helper base1 in
             (add_quantifiers qvars1 base2, tis)
      | Or orf ->
            let nf1, tis1 = helper orf.formula_or_f1 in
            let nf2, tis2 = helper orf.formula_or_f2 in
           (Or {orf with formula_or_f1 = nf1;
               formula_or_f2 = nf2;
           }, tis1@tis2)
  in
  let f,tis = helper f0 in
  let def = List.map fst tis in
  let rem_svl = List.filter (fun (CP.SpecVar(t,sv,p)) ->
      let n = sv ^(match p with Primed -> "PRM"| _ -> "") in
      (List.for_all (fun n2 -> String.compare n n2 != 0) def)
  ) args in
  (* let _ = Debug.ninfo_hprint (add_str "rem_svl: " !CP.print_svl) rem_svl no_pos in *)
  (* let s = CP.SpecVar (CP.type_of_spec_var (List.hd args),self,Unprimed) in *)
  let tis1 =  List.fold_left (fun ls (CP.SpecVar(t,sv,p)) ->
      let vk = Typeinfer.fresh_proc_var_kind ls t in
      let svp = sv ^(match p with Primed -> "PRM"| _ -> "") in
      ls@[(svp,vk)]
  ) [] (rem_svl) in
  (f, tis@tis1)

let baga_union_star baga1 baga2=
  List.fold_left (fun r ls1 -> let r1= List.map (fun ls2 -> (ls1@ls2)) baga2 in
  r@r1
  ) [] baga1

(*f is in normal form: **** & ..... \/ ***** & .... *)
let rec collect_baga_models_heap prog hf0=
  let rec helper hf =
    match hf with
      |Star { h_formula_star_h1 = hf1;
        h_formula_star_h2 = hf2;} ->
           let baga1 = helper hf1 in
           let baga2 = helper hf2 in
           baga_union_star baga1 baga2
      | DataNode {h_formula_data_node = c} -> let tmp = [c] in [tmp]
      | ViewNode {h_formula_view_node = p;
         h_formula_view_name = c;
         h_formula_view_arguments = vs;
         h_formula_view_pos = pos
        } ->
            let vdef = Cast.look_up_view_def pos prog.Cast.prog_view_decls c in
            let from_svs = CP.SpecVar (Named vdef.Cast.view_data_name, self, Unprimed) :: vdef.Cast.view_vars in
            let to_svs = p :: vs in
            let ss = List.combine from_svs to_svs in
            let fs = List.map (fun (f,_) -> subst ss f) vdef.Cast.view_un_struc_formula in
            List.fold_left (fun r f ->
                let m1 =  collect_consit_models prog f in
                let m12 = List.map (fun ls -> CP.intersect_svl ls to_svs) m1 in
                r@m12
            ) [] fs
      | ThreadNode _ | Hole _ | FrmHole _ | HRel _ | HTrue | HFalse| HEmp -> []
      | StarMinus _ | Conj _ | ConjStar _ | ConjConj _ | Phase _ -> raise NOT_HANDLE_YET
  in
  let r = helper hf0 in
  r

and collect_consit_models_x prog f0=
  (*****************INTERNAL******************)
  (**************END INTERNAL******************)
  let rec helper f= match f with
    | Or _ ->  raise NOT_HANDLE_YET
    | Base ({ formula_base_heap = h;
      formula_base_pure = p;
      formula_base_pos = pos}) ->
          (*collect \/ models: address from heap*)
          let h_models0 = collect_baga_models_heap prog h in
          let eqs = (MCP.ptr_equations_without_null p) in
          let h_models = List.map (fun svl -> find_close svl eqs) h_models0 in
          let _ = DD.ninfo_hprint (add_str " h_models" (pr_list !CP.print_svl))  h_models no_pos in
          (*collect must info: bag of null and bag of non-null*)
          let eqNulls = CP.remove_dups_svl ( MCP.get_null_ptrs p) in
          let eqNulls_cl = CP.remove_dups_svl (find_close eqNulls eqs) in
          let neqNulls = CP.get_neq_null_svl (MCP.pure_of_mix p) in
          let neqNulls_cl= CP.remove_dups_svl (find_close neqNulls eqs) in
          let _ = DD.ninfo_hprint (add_str "eqNulls_cl" !CP.print_svl) eqNulls_cl no_pos in
          let _ = DD.ninfo_hprint (add_str "neqNulls_cl" !CP.print_svl) neqNulls_cl no_pos in
          if eqNulls_cl != [] && neqNulls_cl!= [] &&
            CP.intersect_svl eqNulls_cl neqNulls_cl != [] then [] (*inconsistency*)
          else
            (*prune inconstent models*)
            (*prune eqnull incons*)
            let h_models1 = List.fold_left (fun r ls ->
                if CP.intersect_svl ls eqNulls_cl != [] then r else r@[ls]
            ) [] h_models in
            (*prune neqnull incons*)
            let h_models2 = List.fold_left (fun r ls ->
                if CP.diff_svl neqNulls_cl ls != [] then r else r@[ls]
            ) [] h_models1 in
            h_models2
    | Exists _ ->
          let _, base_f = split_quantifiers f in
          helper base_f
  in
  helper f0

and collect_consit_models prog f0=
  let pr1 = !print_formula in
  let pr2 = pr_list !CP.print_svl in
  Debug.no_1 "collect_consit_model" pr1 pr2
      (fun _ -> collect_consit_models_x prog f0) f0

let is_unsat_heap_model_x prog f=
  let rec is_dups_svl svl=
    match svl with
      | [] -> false
      | [x] -> false
      | x::rest -> if CP.mem_svl x rest then true else is_dups_svl rest
  in
  try
    let bagas = collect_consit_models prog f in
    (*filter inconsis addr*)
    let bagas1 = List.filter (fun svl ->
        not (is_dups_svl svl)
    ) bagas in
    bagas1 = []
  with
  _ -> false

let is_unsat_heap_model prog f=
  let pr1 = !print_formula in
  Debug.no_1 "is_unsat_heap_model" pr1 string_of_bool
      (fun _ -> is_unsat_heap_model_x prog f) f

let get_data_view_name hf=
  match hf with
    | ViewNode vn -> ( vn.h_formula_view_name)
    | DataNode vn -> ( vn.h_formula_data_name)
    | _ -> ( "")


(**************** SLEEKENTAIL*************)
(* let normalize_ex_quans_conseq_x prog ante conseq= *)
(*   let normalize_formula ante_nodes f= *)
(*     match f with *)
(*       | Base _ -> f *)
(*       | Exists _ -> *)
(*             let quans,base = split_quantifiers f in *)
(*             let is_match, map = Checkeq.checkeq_formulas ante_nodes ante f in *)
(*       | Or _ -> f *)
(*   in *)
(*   conseq *)

(* let normalize_ex_quans_conseq prog ante conseq= *)
(*   let pr1 = !print_formula in *)
(*   let pr2 = !print_struc_formula in *)
(*   Debug.no_2 "normalize_ex_quans_conseq" pr1 pr2 pr2 *)
(*       (fun _ _ -> normalize_ex_quans_conseq_x prog ante conseq) *)
(*       ante conseq *)

let keep_data_view_hpargs_nodes prog f hd_nodes hv_nodes keep_rootvars keep_hpargs=
  let keep_ptrs = look_up_reachable_ptr_args prog hd_nodes hv_nodes keep_rootvars in
  drop_data_view_hpargs_nodes f check_nbelongsto_dnode check_nbelongsto_vnode
    check_neq_hpargs keep_ptrs keep_ptrs keep_hpargs

let keep_data_view_hpargs_nodes prog f hd_nodes hv_nodes keep_rootvars keep_hpargs=
  let pr1 = !print_formula in
  let pr2 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in
  Debug.no_3 "keep_data_view_hpargs_nodes" pr1 !CP.print_svl pr2 pr1
      (fun _ _ _ -> keep_data_view_hpargs_nodes prog f hd_nodes hv_nodes keep_rootvars keep_hpargs)
      f keep_rootvars keep_hpargs

let obtain_reachable_formula prog f roots=
  let (h ,mf,_,_,_) = split_components f in
  let hds, hvs, hrs = get_hp_rel_h_formula h in
  let eqsets = (MCP.ptr_equations_without_null mf) in
  let reach_ptrs= look_up_reachable_ptrs_w_alias_helper prog hds hvs eqsets roots in
  let hpargs = List.map (fun (hp,eargs,_) -> (hp, List.concat (List.map CP.afv eargs))) hrs in
  let sel_hpargs = List.filter (fun (_,args) -> CP.diff_svl args reach_ptrs = []) hpargs in
  let reach_f = keep_data_view_hpargs_nodes prog f hds hvs reach_ptrs sel_hpargs in
  reach_f

let obtain_reachable_formula prog f roots=
  let pr1 = !print_formula in
  let pr2 = !CP.print_svl in
  Debug.no_2 "obtain_reachable_formula" pr1 pr2 pr1
      (fun _ _ -> obtain_reachable_formula prog f roots)
      f roots

let checkeq_reach_heap_x prog f1 f2 roots=
  let reach_f1 = obtain_reachable_formula prog f1 roots in
  let reach_heap_f1 = formula_of_heap (join_star_conjunctions (heap_of reach_f1)) no_pos in
  let reach_f2 = obtain_reachable_formula prog f2 roots in
  let reach_heap_f2 = formula_of_heap (join_star_conjunctions (heap_of reach_f2)) no_pos in
  let is_same,_ = Checkeq.checkeq_formulas (List.map (CP.name_of_spec_var) roots) reach_heap_f1 reach_heap_f2 in
  if is_same then true else false

let checkeq_reach_heap prog f1 f2 roots=
  let pr1 = !Cformula.print_formula in
  Debug.no_3 "checkeq_reach_heap" pr1 pr1 !CP.print_svl string_of_bool
      (fun _ _ _ -> checkeq_reach_heap_x prog f1 f2 roots)
      f1 f2 roots

let find_dependent_hps_x hp_defs=
  let get_dep_hps eqs def=
    let f = disj_of_list (List.map fst def.def_rhs) no_pos in
    let hps = get_hp_rel_name_formula f in
    let hp0, _ = extract_HRel def.def_lhs in
    let n_eqs = List.fold_left  (fun r hp1 -> if CP.eq_spec_var hp0 hp1 then r
    else r@[(hp0, hp1)]) [] hps in
    eqs@n_eqs
  in
  (* let hps = List.fold_left (fun r def -> *)
  (*     match def.def_cat with *)
  (*       | CP.HPRelDefn (hp,_,_) -> r@[hp] *)
  (*       | _ -> r *)
  (* ) [] hp_defs in *)
  let tpl_aset = CP.EMapSV.mkEmpty in
  let eqs = List.fold_left (get_dep_hps) [] hp_defs in
  let tpl_aset1 = List.fold_left (fun tpl (sv1,sv2) -> CP.add_equiv_eq tpl sv1 sv2) tpl_aset eqs in
  CP.EMapSV.partition tpl_aset1

let find_dependent_hps hp_defs=
  let pr1 = pr_list_ln Cprinter.string_of_hp_rel_def in
  let pr2 = pr_list_ln !CP.print_svl in
  Debug.no_1 "find_dependent_hps" pr1 pr2
      (fun _ -> find_dependent_hps_x hp_defs) hp_defs

 (*sort order of nrec_grps to subst*)
let hp_defs_topo_sort_x hp_defs=
  (*******INTERNAL********)
  let ini_order_from_grp def=
    let hp,_ = extract_HRel def.def_lhs in
    (def,hp,0) (*called one topo*)
  in
  let is_mutrec scc_defs =
    let rec dfs working trav_hps eqs=
      match working with
        | []-> false
        | hp::rest ->
              if CP.mem_svl hp trav_hps then true else
                let child_hps = List.fold_left (fun r (sv1, sv2) ->
                    if CP.eq_spec_var hp sv1 then r@[sv2] else r
                ) [] eqs in
                dfs (rest@(CP.remove_dups_svl child_hps)) (trav_hps@[hp]) eqs
    in
    let scc_hps, deps = List.fold_left (fun (r1,r2) (def,hp, _)->
        let succ_hps = List.fold_left (fun r (f,_) -> r@(get_hp_rel_name_formula f)) [] def.def_rhs in
        (r1@[hp], r2@(List.map (fun hp1 -> (hp,hp1))
            (List.filter (fun hp1 -> not (CP.eq_spec_var hp hp1)) (CP.remove_dups_svl succ_hps))))
    ) ([],[]) scc_defs in
    ( List.exists (fun hp -> dfs [hp] [] deps) scc_hps)
  in
  let rec partition hpdefs scc res=
    match scc with
      | [] -> res
      | hp::rest ->
            try
              let hp_defs = List.find (fun ((_,hp1,_) ) -> CP.eq_spec_var hp hp1) hpdefs in
              partition hpdefs rest (res@[hp_defs])
            with _ -> partition hpdefs rest res
  in
  let topo_sort scc_defs=
    (*get name of n_rec_hps, intial its number with 0*)
    let update_order_from_def updated_hps incr (def,hp, old_n)=
      if CP.mem_svl hp updated_hps then
        (def,hp,old_n+incr)
      else (def,hp,old_n)
    in
  (*each grp, find succ_hp, add number of each succ hp + 1*)
    let process_one_def topo (def,hp,_)=
      let succ_hps = List.fold_left (fun r (f,_) -> r@(get_hp_rel_name_formula f)) [] def.def_rhs in
      (*remove dups*)
      let succ_hps1 = Gen.BList.remove_dups_eq CP.eq_spec_var succ_hps in
      (* DD.ninfo_pprint ("       process_dep_group succ_hps: " ^ (!CP.print_svl succ_hps)) no_pos; *)
      (*remove itself hp and unk_hps*)
      let succ_hps2 = List.filter (fun hp1 -> not (CP.eq_spec_var hp1 hp))  succ_hps1 in
      List.map (update_order_from_def succ_hps2 1) topo
    in
    (*detect mutrec*)
    if is_mutrec scc_defs then (true, scc_defs) else
      let topo1 = List.fold_left process_one_def scc_defs scc_defs in
      (*sort decreasing and return the topo list*)
      let topo2 = List.sort (fun (_,_,n1) (_,_,n2) -> n1-n2) topo1 in
      (false, topo2)
  in
  (******END*INTERNAL********)
  let eqhp_sccs = find_dependent_hps hp_defs in
  let hp_defs1 = List.map ini_order_from_grp hp_defs in
  let scc_hp_defs1 = List.map (fun eqs -> partition hp_defs1 eqs []) eqhp_sccs in
  let scc_hp_defs2 = List.map topo_sort scc_hp_defs1 in
  let sort_hpdefs, mutrec_hpdefs = List.fold_left (fun (r1,r2) (is_mut, scc) ->
      let hp_defs = List.map (fun (def,_,_) -> def) scc in
      if is_mut then (r1,r2@hp_defs) else (r1@[hp_defs], r2)
  ) ([],[]) scc_hp_defs2 in
  sort_hpdefs, mutrec_hpdefs

(*for debugging*)
let hp_defs_topo_sort defs=
  let pr1 = pr_list_ln Cprinter.string_of_hp_rel_def in
  Debug.no_1 "hp_defs_topo_sort" pr1 (pr_pair (pr_list_ln pr1) pr1)
      (fun _ -> hp_defs_topo_sort_x defs) defs

let classify_equiv_hp_defs_x defs=
  let classify_equiv_form (equiv_defs, non_equiv_defs, equiv) def=
    match def.def_cat with
      | CP.HPRelDefn (hp,_,_) -> begin
          match def.def_rhs with
            | [(f,_)] -> begin
                  let equiv_opt = extract_hrel_head f in
                  match equiv_opt with
                    | None -> (equiv_defs, non_equiv_defs@[def], equiv)
                    | Some hp1 -> (equiv_defs@[def], non_equiv_defs, equiv@[(hp, hp1)])
              end
            | _ -> (equiv_defs, non_equiv_defs@[def], equiv)
        end
      | _ -> (equiv_defs, non_equiv_defs@[def], equiv)
  in
  List.fold_left classify_equiv_form ([],[],[]) defs

let classify_equiv_hp_defs defs=
  let pr1 = pr_list_ln  Cprinter.string_of_hp_rel_def in
  let pr2 = pr_list (pr_pair !CP.print_sv !CP.print_sv) in
  Debug.no_1 "classify_equiv_hp_defs" pr1 (pr_triple pr1 pr1 pr2)
      (fun _ -> classify_equiv_hp_defs_x defs) defs

(*
(i) build emap for LHS/RHS 
  - eqnull -> make closure. do not subst
  - cycle nodes: DO NOT subst
  - inside one preds, do not subst
(ii) common free vars for both LHS/RHS
(iii) subs both sides to use smallest common vars
        lhs     |- P(v* )
*)

let cmp_fn sv1 sv2 = let n= String.compare (CP.name_of_spec_var sv1) (CP.name_of_spec_var sv2) in
  if n=0 then
    if CP.primed_of_spec_var sv1 = Unprimed then -1 else 1
  else n
let build_subst_comm_x args prog_vars emap comm_svl=
  (* let find_comm_eq ls_eq sv= *)
  (*   if List.exists (fun svl -> CP.mem_svl sv svl) ls_eq then ls_eq else *)
  (*     let com_eq_svl = CP.EMapSV.find_equiv_all sv emap in *)
  (*     if com_eq_svl = [] then ls_eq else *)
  (*       ls_eq@[com_eq_svl] *)
  (* in *)
  let build_subst subst evars=
    let inter1 = CP.intersect_svl evars prog_vars in
    let keep_sv = if inter1 <> [] then
      List.hd (List.sort cmp_fn inter1)
    else
      let inter2 = CP.intersect_svl evars args in
      if inter2 <> [] then
        List.hd (List.sort cmp_fn inter2)
      else
        let evars1 = List.sort cmp_fn evars in
        List.hd evars1
    in
    let new_ss = List.fold_left (fun r sv -> if CP.eq_spec_var keep_sv sv then r else r@[(sv, keep_sv)]) [] evars in
    subst@new_ss
  in
  let epart0 = CP.EMapSV.partition emap in
  (* let ls_com_eq_svl = List.fold_left find_comm_eq [] comm_svl in *)
  let ls_com_eq_svl, ls_non_com_eq_svl = List.partition (fun svl ->
      CP.intersect_svl svl comm_svl <> []
  ) epart0 in
  let ss1 =  if ls_com_eq_svl = [] then [] else
    List.fold_left build_subst [] ls_com_eq_svl
  in
  let ss2 = if ls_non_com_eq_svl = [] then [] else
    List.fold_left build_subst [] ls_non_com_eq_svl
  in
  (ss1@ss2)

let build_subst_comm args prog_vars emap comm_svl=
  let pr1 = CP.EMapSV.string_of in
  let pr2 =  !CP.print_svl in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_sv ) in
  Debug.no_4 "SAU.build_subst_comm" pr2 pr2 pr1 pr2 pr3
      (fun _ _ _ _ ->  build_subst_comm_x args prog_vars emap comm_svl)
      args prog_vars emap comm_svl

let expose_expl_closure_eq_null_x lhs_b lhs_args emap0=
  let rec find_equiv_all eparts sv all_parts=
    match eparts with
      | [] -> [],all_parts
      | ls::rest -> if CP.mem_svl sv ls then (ls,all_parts@rest) else
          find_equiv_all rest sv (all_parts@[ls])
  in
  let look_up_eq_null (epart, ls_null_args, ls_expl_eqs, ss) sv=
    (* let eq_nulls,rem_parts = find_equiv_all epart sv [] in *)
    let eq_nulls,rem_parts = find_equiv_all epart sv [] in
    let eq_null_args = CP.intersect_svl eq_nulls lhs_args in
    if List.length eq_null_args > 1 then
      let eq_null_args1 = (List.sort cmp_fn eq_null_args) in
      let keep_sv = List.hd eq_null_args1 in
      let ss2 = List.fold_left (fun ss1 sv ->
          if CP.eq_spec_var keep_sv sv then ss1
          else ss1@[(sv, keep_sv)]
      ) [] eq_nulls
      in
      let ss3 = List.map (fun sv -> (sv, keep_sv) ) (List.tl eq_null_args1) in
      (rem_parts, ls_null_args@eq_null_args, ls_expl_eqs@ss3,ss@ss2)
    else (epart, ls_null_args, ls_expl_eqs, ss)
  in
  let eq_null_svl = CP.remove_dups_svl (MCP.get_null_ptrs lhs_b.formula_base_pure) in
  let epart0 = CP.EMapSV.partition emap0 in
  let rem_parts, eq_null_args, expl_eq_args, ss = List.fold_left look_up_eq_null (epart0, [],[],[]) eq_null_svl in
  let cls_e_null = List.map (fun sv -> CP.mkNull sv no_pos) eq_null_args in
  (* let expl_eq_ps = List.map (fun (sv1,sv2) -> CP.mkEqVar sv1 sv2 no_pos) expl_eq_args in *)
  (CP.EMapSV.un_partition rem_parts, (* expl_eq_ps@ *)cls_e_null, ss)


let expose_expl_closure_eq_null lhs_b lhs_args emap=
  let pr1 = CP.EMapSV.string_of in
  let pr2 = pr_list !CP.print_formula in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_sv ) in
  Debug.no_1 "SAU.expose_expl_closure_eq_null" pr1 (pr_triple pr1 pr2 pr3)
      (fun _ -> expose_expl_closure_eq_null_x lhs_b lhs_args emap) emap
(*
  - cycle nodes: DO NOT subst
  - inside one preds, do not subst

for each ls_eqs, if it contains at least two vars of the same group,
  - we remove this ls_eqs
  - add equality in lhs
 input:
  - emap: global emap (no r_qemap)
  - groups of args of unknown preds + args + data nodes
 output:
  - triple of (remain emap, equalifty formula to be added to lhs, ss for pure of lhs
  rhs
*)
let expose_expl_eqs_x emap0 prog_vars vars_grps0=
  (*move root to behind, donot loss it*)
  (* let roots = List.fold_left (fun roots0 args -> match args with *)
  (*   | r::_ -> roots0@[r] *)
  (*   | _ -> roots0 *)
  (* ) [] vars_grps0 in *)
  let all_vars = List.concat vars_grps0 in
  let process_one_ls_eq ls_eqs =
    let ls_eq_args = List.fold_left (fun r args ->
        let inter = CP.intersect_svl args ls_eqs in
        if List.length inter > 1 then r@[inter] else r
        ) [] vars_grps0 in
    let ls_eq_args1 = List.sort (fun ls1 ls2 -> List.length ls2 - List.length ls1) ls_eq_args in
    let ls_eq_args2 = Gen.BList.remove_dups_eq (Gen.BList.subset_eq CP.eq_spec_var) ls_eq_args1 in
    if ls_eq_args2=[] then (false,[],[])
    else
      (* let _ = Debug.info_hprint (add_str  "ls_eq_args2 " (pr_list !CP.print_svl)) ls_eq_args2 no_pos in *)
      (*explicit equalities*)
      let expl_eqs, link_svl = List.fold_left (fun (r, keep_svl) ls ->
          let ls1 = List.sort cmp_fn ls in
          (* let inter = CP.intersect_svl roots ls1 in *)
          let keep_sv = (* if inter <> [] then List.hd inter else *) List.hd ls1 in
          (r@(List.map (fun sv -> (sv, keep_sv)) (List.tl ls1)), keep_svl@[keep_sv])
      ) ([],[]) ls_eq_args2
      in
      (*link among grps*)
      let link_expl_eqs = if link_svl = [] then [] else
        let link_svl1 = List.sort cmp_fn link_svl in
        let fst_sv = List.hd link_svl1 in
        List.map (fun sv -> (sv, fst_sv)) (List.tl link_svl1)
      in
      (*subst for others*)
      let keep_sv =
        let _ = Debug.ninfo_hprint (add_str  "link_svl" !CP.print_svl) link_svl no_pos in
        let inters1 = CP.intersect_svl (prog_vars) link_svl in
        let _ = Debug.ninfo_hprint (add_str  "inters1" !CP.print_svl) inters1 no_pos in
        if inters1 != [] then List.hd inters1 else
          (* let inters0 = CP.intersect_svl roots link_svl in *)
          (* let _ = Debug.info_hprint (add_str  "inters0" !CP.print_svl) inters0 no_pos in *)
          (* if inters0 != [] then List.hd (inters0) else *)
            let inters = CP.intersect_svl all_vars link_svl in
            let _ = Debug.ninfo_hprint (add_str  "inters" !CP.print_svl) inters no_pos in
          if inters = [] then List.hd (List.sort cmp_fn link_svl)
          else List.hd inters
      in
      (* let _ = Debug.info_hprint (add_str  "keep_sv " !CP.print_sv) keep_sv no_pos in *)
      (* let _ = Debug.info_hprint (add_str  "ls_eqs " !CP.print_svl) ls_eqs no_pos in *)
      let ss2 = List.fold_left (fun ss1 sv ->
          if CP.eq_spec_var keep_sv sv then ss1
          else ss1@[(sv, keep_sv)]
      ) [] ls_eqs
      in
      (true, expl_eqs@link_expl_eqs,ss2)
  in
  let epart0 = CP.EMapSV.partition emap0 in
  let rem_eparts, ls_eq_args, expl_eq_args,sst = List.fold_left (fun (r_eparts, r_eq_args, r_eqs, r_ss) ls_eqs->
      let b, n_eqs, n_ss = process_one_ls_eq ls_eqs in
      if b then
        (r_eparts, r_eq_args@[ls_eqs], r_eqs@n_eqs, r_ss@n_ss)
      else (r_eparts@[ls_eqs], r_eq_args, r_eqs, r_ss)
  ) ([],[],[],[]) epart0 in
  let expl_eq_ps = List.map (fun (sv1,sv2) -> CP.mkEqVar sv1 sv2 no_pos) expl_eq_args in
  (CP.EMapSV.un_partition rem_eparts, ls_eq_args, expl_eq_ps ,sst)

let expose_expl_eqs emap prog_vars vars_grps=
  let pr1 = pr_list_ln !CP.print_svl in
  let pr2 = CP.EMapSV.string_of in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_sv ) in
  let pr4 = pr_quad pr2 pr1 (pr_list !CP.print_formula) pr3 in
  Debug.no_2 "SAU.expose_expl_eqs" pr2 pr1 pr4
      (fun _ _ -> expose_expl_eqs_x emap prog_vars vars_grps)
      emap vars_grps

let h_subst ss ls_eq_args0 hf0=
  let rec is_expl_eqs ls_eq_args svl =
    match ls_eq_args with
      | [] -> false
      | eqs::rest ->
            if List.length (CP.intersect_svl eqs svl) > 1 then true else
              is_expl_eqs rest svl
  in
  match hf0 with
    | DataNode dn ->
          let svl = dn.h_formula_data_node::dn.h_formula_data_arguments in
          if is_expl_eqs ls_eq_args0 svl then hf0 else
            let hf1 = h_subst ss hf0 in
            hf1
    | ViewNode vn ->
          let svl = vn.h_formula_view_node::vn.h_formula_view_arguments in
          if is_expl_eqs ls_eq_args0 svl then hf0 else
            let hf1 = h_subst ss hf0 in
            hf1
    | HRel (hp, eargs, pos) ->
          let svl = List.fold_left List.append [] (List.map CP.afv eargs) in
          let _ = Debug.ninfo_hprint (add_str  "svl " !CP.print_svl) svl no_pos in
          if is_expl_eqs ls_eq_args0 svl then hf0 else
            let hf1 = h_subst ss hf0 in
            hf1
    | _ -> hf0


let smart_subst_new_x lhs_b rhs_b hpargs l_emap r_emap r_qemap unk_svl prog_vars=
  let largs= h_fv lhs_b.formula_base_heap in
  let rargs= h_fv rhs_b.formula_base_heap in
  let all_args = CP.remove_dups_svl (largs@rargs) in
  (*---------------------------------------*)
  let lsvl = fv (Base lhs_b) in
  let rsvl = (fv (Base rhs_b))@(CP.EMapSV.get_elems r_emap)@(CP.EMapSV.get_elems r_qemap) in
  let comm_svl = CP.intersect_svl lsvl rsvl in
  let lhs_b1, rhs_b1, prog_vars =
    if comm_svl = [] then
      (lhs_b, rhs_b, prog_vars)
    else
      let l_emap1, null_ps, null_sst = expose_expl_closure_eq_null lhs_b all_args l_emap in
      let emap0 = CP.EMapSV.merge_eset l_emap r_emap in
      let vars_grps = (get_data_node_ptrs_group_hf lhs_b.formula_base_heap)@(get_data_node_ptrs_group_hf rhs_b.formula_base_heap)@
        (List.map snd hpargs)
      in
      let emap0a, ls_eq_args, expl_eqs_ps, eq_sst = expose_expl_eqs emap0 prog_vars vars_grps in
      (* let _ = Debug.info_hprint (add_str  "ls_eq_args " (pr_list !CP.print_svl)) ls_eq_args no_pos in *)
      let emap1 = CP.EMapSV.merge_eset emap0a r_qemap in
      let ss = build_subst_comm all_args prog_vars emap1 comm_svl in
      (* let pr_ss = pr_list (pr_pair !CP.print_sv !CP.print_sv) in *)
      (* let _ = Debug.info_hprint (add_str  "ss " (pr_ss)) ss no_pos in *)
      (*LHS*)
      let lhs_b1 = subst_b ss lhs_b in
      let lhs_pure1 = MCP.pure_of_mix lhs_b1.formula_base_pure in
      let lhs_pure2 = CP.subst (null_sst@eq_sst) lhs_pure1 in
      let lpos = pos_of_formula (Base lhs_b1) in
      let lhs_pure_w_expl = CP.conj_of_list (lhs_pure2::(null_ps@expl_eqs_ps)) lpos in
      let lhs_b2 = {lhs_b1 with formula_base_pure = MCP.mix_of_pure
              (CP.remove_redundant lhs_pure_w_expl);
          formula_base_heap = trans_heap_hf (h_subst (null_sst@eq_sst) ls_eq_args) lhs_b1.formula_base_heap;
      } in
      (*RHS*)
      let rhs_b1 = subst_b ss rhs_b in
      (* let _ = Debug.info_hprint (add_str  "rhs_b1 " Cprinter.prtt_string_of_formula) (Base rhs_b1) no_pos in *)
      let rhs_b2 = {rhs_b1 with formula_base_pure = MCP.mix_of_pure
              (CP.remove_redundant (MCP.pure_of_mix rhs_b1.formula_base_pure));
          formula_base_heap = trans_heap_hf (h_subst (null_sst@eq_sst) ls_eq_args) rhs_b1.formula_base_heap;
      } in
      (lhs_b2, rhs_b2, CP.subst_var_list (ss@null_sst@eq_sst) prog_vars)
  in
  (lhs_b1, rhs_b1, prog_vars)

let smart_subst_new lhs_b rhs_b hpargs l_emap r_emap r_qemap unk_svl prog_vars=
  let pr1 = Cprinter.string_of_formula_base in
  let pr2 = !CP.print_svl in
  let pr3 = CP.EMapSV.string_of in
  let pr4 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in
  Debug.no_7 "smart_subst_new" pr1 pr1 pr4 pr2 pr3 pr3 pr3 (pr_triple pr1 pr1 pr2)
      (fun _ _ _ _ _ _ _-> smart_subst_new_x lhs_b rhs_b hpargs l_emap r_emap r_qemap unk_svl prog_vars)
      lhs_b rhs_b hpargs prog_vars l_emap r_emap r_qemap

let elim_dangling_conj_star_hf unk_hps f0 =
  let rec helper f=
    match f with
      | HRel _
      | DataNode _ | ViewNode _ 
      | HTrue | HFalse | HEmp | Hole _ | FrmHole _ |  ThreadNode _ -> f
      | Phase b -> Phase {b with h_formula_phase_rd = helper b.h_formula_phase_rd;
            h_formula_phase_rw = helper b.h_formula_phase_rw}
      | Conj b -> begin
           let hpargs1_opt = get_HRel b.h_formula_conj_h1 in
           let hpargs2_opt = get_HRel b.h_formula_conj_h2 in
           match hpargs1_opt,hpargs2_opt with
             | Some (hp1,_), Some (hp2, _) -> begin
                 let b1 = CP.mem_svl hp1 unk_hps in
                 let b2 = CP.mem_svl hp2 unk_hps in
                 match b1,b2 with
                   | false,false -> f
                   | true,false -> b.h_formula_conj_h2
                   | _ -> b.h_formula_conj_h1
               end
             | Some (hp1, _),_ -> if CP.mem_svl hp1 unk_hps then b.h_formula_conj_h2 else f
             | _ , Some (hp2, _) -> if CP.mem_svl hp2 unk_hps then b.h_formula_conj_h1 else f
             | _ -> f
        end
      | Star b -> begin let hf2 = helper b.h_formula_star_h2 in
        let hf1 = helper b.h_formula_star_h1 in
        match hf1,hf2 with
          | HEmp,HEmp -> HEmp
          | HEmp,_ -> hf2
          | _ , HEmp -> hf1
          | _ ->
            Star {b with h_formula_star_h2 = hf2; h_formula_star_h1 = hf1}
        end
      | ConjStar _|ConjConj _|StarMinus _ -> f
  in
  helper f0

let rec elim_dangling_conj_star struc_trav f =
  let recf = elim_dangling_conj_star struc_trav in
  match f with
    | Base b-> Base{b with  formula_base_heap = struc_trav b.formula_base_heap}
    | Exists b-> Exists{b with  formula_exists_heap =  struc_trav b.formula_exists_heap}
    | Or b-> Or {b with formula_or_f1 = recf b.formula_or_f1;formula_or_f2 = recf b.formula_or_f2}

let is_heap_conjs_hf hf0=
  let rec helper hf=
    match hf with
      | Conj _ -> true
      | Star b -> (helper b.h_formula_star_h2) || (helper b.h_formula_star_h1)
      | _ -> false
  in
  helper hf0

let rec is_heap_conjs f=
  match f with
    | Base b-> is_heap_conjs_hf b.formula_base_heap
    | Exists b->  is_heap_conjs_hf b.formula_exists_heap
    | Or b-> is_heap_conjs b.formula_or_f1 || is_heap_conjs b.formula_or_f2

let contain_folall_pure f=
  let p = get_pure f in
  CP.is_forall p


let unfold_non_rec_views prog unfold_fnc is_view_rec_fnc f=
  let vnodes = get_views f in
  if vnodes = [] then
    f
  else
    (*filter non_rec vnodes*)
    let nrec_vnodes = List.filter (fun vn ->
        try
          not (is_view_rec_fnc vn.h_formula_view_name)
        with _ -> false
    ) vnodes in
    if nrec_vnodes = [] then f else
      let nf, _ = List.fold_left (fun (f,ss) sv0 ->
          let sv = CP.subst_var_par ss sv0 in
          (* let _ = print_endline ("-- unfold lsh on " ^ (Cprinter.string_of_spec_var sv)) in *)
          let nf,ss1 = unfold_fnc f sv in
          (nf, ss@ss1)
      ) (f, []) (List.map (fun vn -> vn.h_formula_view_node) nrec_vnodes)
      in nf

let unfold_non_rec_views prog unfold_fnc is_view_rec_fnc f=
  let pr1 = !print_formula in
  Debug.no_1 "unfold_non_rec_views" pr1 pr1
      (fun _ -> unfold_non_rec_views prog unfold_fnc is_view_rec_fnc f)
      f
let check_inconsistency hf mixf=
  let new_mf = xpure_for_hnodes hf in
  let cmb_mf = MCP.merge_mems new_mf mixf true in
  not (TP.is_sat_raw cmb_mf)

let check_inconsistency_f f0 pure_f=
  let p = MCP.mix_of_pure (get_pure pure_f) in
  let rec helper f=
    match f with
      | Base fb -> check_inconsistency fb.formula_base_heap p
      | Or orf -> (helper orf.formula_or_f1) && (helper orf.formula_or_f2)
      | Exists fe ->
        (*may not correct*)
          check_inconsistency fe.formula_exists_heap p
  in
  helper f0

let rec is_unsat_x f0=
  let rec helper f=
    match f with
      | Base fb -> check_inconsistency fb.formula_base_heap fb.formula_base_pure
      | Or orf -> (helper orf.formula_or_f1) || (helper orf.formula_or_f2)
      | Exists fe ->
        (*may not correct*)
          check_inconsistency fe.formula_exists_heap fe.formula_exists_pure
  in
  helper f0

and is_unsat f=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 = string_of_bool in
  Debug.no_1 "is_unsat" pr1 pr2
      (fun _ -> is_unsat_x f) f

let check_separation_unsat f0=
  let rec helper f=
    match  f with
      | Base fb -> let hds, hvs, _ (*hvs, hrs*) = get_hp_rel_h_formula fb.formula_base_heap in
        let d_ptrs = List.map (fun dn -> dn.h_formula_data_node) hds in
        let v_ptrs = List.map (fun vn -> vn.h_formula_view_node) hvs in
        if CP.intersect_svl d_ptrs v_ptrs = [] then
          let p = (MCP.pure_of_mix fb.formula_base_pure) in
          if (CP.isConstTrue p) then false else
            let null_svl = MCP.get_null_ptrs fb.formula_base_pure in
            let nNull_svl = (* CP.get_neq_null_svl p *)[] in
            if (null_svl = []) && nNull_svl =[] then false else
              (CP.intersect_svl null_svl nNull_svl !=[]) || (CP.intersect_svl (d_ptrs@v_ptrs) (null_svl@nNull_svl) !=[])
        else true
      | Or orf -> (helper orf.formula_or_f1) && (helper orf.formula_or_f2)
      | Exists _ ->
            let _,base = split_quantifiers f in
          helper base
  in
  helper f0

let check_separation_unsat f0=
  let pr1 =  Cprinter.prtt_string_of_formula in
  let pr2 = string_of_bool in
  Debug.no_1 "check_separation_unsat" pr1 pr2
      (fun _ -> check_separation_unsat f0)
      f0

let check_tail_rec_rec_lemma_x prog lhs rhs l_reach_dns l_reach_vns r_reach_dns r_reach_vns =
  (* rhs is is_tail_recursive, lhs is non tail rec form*)
   (****************************)
  (*Loc: this check does not work properly. reverse a chain, how to transform pure? *)
  let cfutil_tp_imply_x ante conseq  = (* Tpdispatcher.imply_raw ante conseq *) true in
  let cfutil_tp_imply ante conseq=
    let pr1 = !CP.print_formula in
    Debug.no_2 "cfutil_tp_imply" pr1 pr1 string_of_bool
        (fun _ _ -> cfutil_tp_imply_x ante conseq) ante conseq
  in
  (* let tp_sat p1 p2 = (\* Tpdispatcher.is_sat_raw (Mcpure.mix_of_pure (CP.mkAnd p1 p2 no_pos)) *\) true in *)
  let rec is_horm_h_formula_x hfs1 hfs2 =
    match hfs1,hfs2 with
      | [],[] -> true
      | hf1::rest1,hf2::rest2 -> begin
          match hf1,hf2 with
            | DataNode dn1, DataNode dn2 ->
                  if String.compare dn1.h_formula_data_name dn2.h_formula_data_name = 0 then
                    is_horm_h_formula_x rest1 rest2
                  else false
            | ViewNode vn1, ViewNode vn2 ->
                   if String.compare vn1.h_formula_view_name vn2.h_formula_view_name = 0 then
                    is_horm_h_formula_x rest1 rest2
                  else false
            | _ -> false
        end
      | _ -> false
  in
  let is_horm_h_formula hfs1 hfs2=
    let pr1 = pr_list !print_h_formula in
    Debug.no_2 "is_horm_h_formula" pr1 pr1 string_of_bool
        (fun _ _ -> is_horm_h_formula_x hfs1 hfs2) hfs1 hfs2
  in
  (*should have better machenism to static defined the meaning- relation of predicate arguments*)
  let is_horm_dllseg root hfs=
    try
      let hds,hvs = List.fold_left (fun (r1,r2) hf -> match hf with
        | ViewNode hv -> (r1,r2@[hv])
        | DataNode hn -> (r1@[hn],r2)
        | _ -> (r1,r2)
      ) ([],[]) hfs in
      let hv = List.find (fun hv -> CP.eq_spec_var root hv.h_formula_view_node) hvs in
      let arg_length = List.length hv.h_formula_view_arguments in
      if arg_length > 1 then
        let last_arg = List.nth hv.h_formula_view_arguments (arg_length-1) in
        let reach_hd = List.find (fun hd -> CP.eq_spec_var hd.h_formula_data_node last_arg) hds in
        let hn_arg_length = List.length reach_hd.h_formula_data_arguments in
        if hn_arg_length > 1 then
        CP.eq_spec_var ( List.nth hv.h_formula_view_arguments 0) (List.nth reach_hd.h_formula_data_arguments 1)
        else true
      else true
    with _ -> true
  in
  let heaps_of_formula args f =
    let f0 = Cfout.rearrange_formula args f in
    List.fold_left (fun r f1 -> r@(split_star_conjunctions f1)) [] (heap_of f0)
  in
  (****************************)
  if r_reach_dns != [] then
    match l_reach_dns, l_reach_vns, r_reach_dns, r_reach_vns with
      | [ldn],[lvn],[rdn],[rvn] ->
            (*unfold case*)
            if ( CP.eq_spec_var rdn.Cformula.h_formula_data_node lvn.Cformula.h_formula_view_node || (*fold case*)
                CP.eq_spec_var ldn.Cformula.h_formula_data_node rvn.Cformula.h_formula_view_node) &&
              String.compare ldn.Cformula.h_formula_data_name rdn.Cformula.h_formula_data_name = 0 &&
              String.compare lvn.Cformula.h_formula_view_name rvn.Cformula.h_formula_view_name =0 then
                3
            else -1
      | _ -> -1
  else
    match r_reach_vns with
      | [rvn] ->
            let rvdcl = Cast.look_up_view_def_raw 57 prog.Cast.prog_view_decls rvn.h_formula_view_name in
            let self_sv =  CP.SpecVar (Named rvdcl.Cast.view_data_name, self, Unprimed) in
            let sst = List.combine (self_sv::rvdcl.Cast.view_vars) (rvn.h_formula_view_node::rvn.h_formula_view_arguments) in
            let rec_def_heaps = List.fold_left (fun r (f,_) ->
                let views = Cformula.get_views f in
                if List.exists (fun vn -> String.compare vn.Cformula.h_formula_view_name rvdcl.Cast.view_name = 0) views then
                  let f1 = (subst sst (elim_exists f)) in
                  let _ = DD.ninfo_hprint (add_str "f1" !print_formula) f1 no_pos in
                  let hfs = heaps_of_formula [rvn.h_formula_view_node] f1 in
                  let pure = get_pure f1 in
                  r@[(pure, hfs)]
                else r
            ) [] rvdcl.Cast.view_un_struc_formula in
            let rhs_pure = CP.mkAnd (get_pure rhs) (get_pure lhs) no_pos in
            let rev_l_hfs = List.rev (heaps_of_formula [rvn.h_formula_view_node] lhs) in
            if not ((is_horm_dllseg rvn.h_formula_view_node rev_l_hfs)) then -1 else
              if List.exists (fun (br_pure,hfs) -> (cfutil_tp_imply rhs_pure br_pure) &&
                  (List.length hfs = List.length rev_l_hfs) &&
                  is_horm_h_formula hfs rev_l_hfs
              ) rec_def_heaps then
                3 (* gen -> lemma: right lemma application is not working properly.
                     todo: should be <- *)
              else -1
      | _ -> -1

let check_tail_rec_rec_lemma prog lhs rhs l_reach_dns l_reach_vns r_reach_dns r_reach_vns =
  let pr1 vn = !print_h_formula (ViewNode vn) in
  let pr2 dn = !print_h_formula (DataNode dn) in
  let pr3 = !print_formula in
  Debug.no_6 "check_tail_rec_rec_lemma" pr3 pr3 (pr_list pr2) (pr_list pr1)
      (pr_list pr2) (pr_list pr1) string_of_int
      (fun _ _ _ _ _ _ -> check_tail_rec_rec_lemma_x prog lhs rhs l_reach_dns l_reach_vns r_reach_dns r_reach_vns)
      lhs rhs l_reach_dns l_reach_vns r_reach_dns r_reach_vns

(*check whether can use pure properties to unfold. IF YES, postpone the lemma synthesis after unfold*)
let poss_prune_pred_x prog vnode f=
  let pure_svl = List.filter (fun sv -> not (CP.is_node_typ sv)) vnode.h_formula_view_arguments in
  let pure_constr = CP.filter_var (get_pure f) pure_svl in
  let ps = List.filter (fun p -> not (CP.is_eq_between_vars p) &&
      not (CP.isConstTrue p)) (CP.list_of_conjs pure_constr) in
  (ps != [])

let poss_prune_pred prog vnode f=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 vn = Cprinter.prtt_string_of_h_formula (ViewNode vnode) in
  Debug.no_2 "poss_prune_pred" pr2 pr1 string_of_bool
      (fun _ _ -> poss_prune_pred_x prog vnode f)
      vnode f

(*
  res = -1: NO cyclic - not syn lemma (gen_lemma_action_invalid)
  res = 0: syn Left lemma
  res = 1: syn Right lemma
  res = 2 : syn lemma_infer
  res = 3: syn Left lemma for tail-rec and non tail rec
*)

let is_out_of_scope prog lvnode rvnode=
  if String.compare lvnode.h_formula_view_name rvnode.h_formula_view_name = 0 then
    let vdcl = Cast.look_up_view_def_raw 61 prog.Cast.prog_view_decls lvnode.h_formula_view_name in
    List.exists (fun (f, _) ->
        let vns = get_views f in
        let rec_vns, other = List.partition (fun vn ->
            String.compare vn.h_formula_view_name lvnode.h_formula_view_name = 0
        ) vns in
        (rec_vns != [] && other != [])
    ) vdcl.Cast.view_un_struc_formula
  else false

let need_cycle_checkpoint_x prog lvnode lhs0 rvnode rhs0 reqset=
  if not (!Globals.lemma_syn && is_lem_syn_in_bound()) || (check_separation_unsat rhs0) || (check_separation_unsat lhs0) (* || (is_out_of_scope prog lvnode rvnode) *) then -1 else
    (*check root has unfold information??*)
    (* let null_neq_svl = (get_neqNull lhs)@(get_null_svl lhs) in *)
    (* if CP.mem_svl lvnode.h_formula_view_node null_neq_svl then -1 else *)
    let _ = DD.ninfo_hprint (add_str "rhs0" !print_formula) rhs0 no_pos in
    let rhs1 = subst (reqset) rhs0 in
    let ( _,mix_f,_,_,_) = split_components rhs1 in
    let reqs = (MCP.ptr_equations_without_null mix_f) in
    let _ = DD.ninfo_hprint (add_str "reqs" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) reqs no_pos in
    let rhs = subst (reqs) rhs1 in
    let ( _,lmf,_,_,_) = split_components lhs0 in
    let leqs = (MCP.ptr_equations_without_null lmf) in
    let lhs = subst (leqs) lhs0 in
    let leqNulls = ( MCP.get_null_ptrs lmf) in
    let reqNulls = ( MCP.get_null_ptrs mix_f) in
    let is_ident = checkeq_view_node_with_null lvnode.h_formula_view_node lvnode.h_formula_view_arguments rvnode.h_formula_view_node rvnode.h_formula_view_arguments (find_close leqNulls leqs) (find_close reqNulls (reqset@reqs))  in
    if is_ident then -1 else
      let l_reach_ptrs, l_reach_dns,l_reach_vns = look_up_reachable_ptrs_w_alias prog lhs [lvnode.h_formula_view_node] 3 in
      let l_hns, l_hvs,_ = Cformula.get_hp_rel_formula lhs in
      let rev_reach_ptrs = Cformula.look_up_rev_reachable_ptr_args prog l_hns l_hvs [lvnode.h_formula_view_node] in
      if CP.diff_svl rev_reach_ptrs [lvnode.h_formula_view_node] != [] then -1 else
        let r_reach_ptrs, r_reach_dns,r_reach_vns = look_up_reachable_ptrs_w_alias prog rhs [rvnode.h_formula_view_node] 3 in
        let lnlength = List.length l_reach_dns in
        let lvlength = List.length l_reach_vns in
        let rnlength = List.length r_reach_dns in
        let rvlength = List.length r_reach_vns in
        let lview_names = List.map (fun v -> v.h_formula_view_name) l_reach_vns in
        let rview_names = List.map (fun v -> v.h_formula_view_name) r_reach_vns in
        if lnlength = 0 && lvlength =1  && rnlength = 0 && rvlength =1  then
          if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then 0
          else gen_lemma_action_invalid
        else
          if lvlength = rvlength then
            if (lnlength != rnlength) then
              if lvlength = rvlength then
                let lem_type =  check_tail_rec_rec_lemma prog lhs rhs l_reach_dns l_reach_vns r_reach_dns r_reach_vns in
                if lem_type = gen_lemma_action_invalid then 0 else lem_type
              else 0
            else
              let _ = DD.ninfo_hprint (add_str "lview_names" (pr_list pr_id)) lview_names no_pos in
              if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then
                1
              else
                let reqnull = CP.intersect_svl r_reach_ptrs reqNulls in
                let leqnull = CP.intersect_svl l_reach_ptrs leqNulls in
                if (leqnull !=[] && reqnull = []) || (leqnull =[] && reqnull != []) then gen_lemma_action_invalid
                else
                  if checkeq_reach_heap prog lhs rhs [(lvnode.h_formula_view_node)] then -1 else 1
          else
            if (lvlength > rvlength) then
              0
            else gen_lemma_action_invalid

let need_cycle_checkpoint prog lvnode lhs rvnode rhs reqset=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 vn= Cprinter.prtt_string_of_h_formula (ViewNode vn) in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_sv) in
  Debug.no_5 "need_cycle_checkpoint" pr2 pr2 pr1 pr1 pr3 string_of_int
      (fun _ _ _ _ _ -> need_cycle_checkpoint_x prog lvnode lhs rvnode rhs reqset)
      lvnode rvnode lhs rhs reqset

let need_cycle_checkpoint_fold_helper prog lroots lhs rroots rhs=
  (****************************)
  (* let rec is_horm_h_formula_x hfs1 hfs2 = *)
  (*   match hfs1,hfs2 with *)
  (*     | [],[] -> true *)
  (*     | hf1::rest1,hf2::rest2 -> begin *)
  (*         match hf1,hf2 with *)
  (*           | DataNode dn1, DataNode dn2 -> *)
  (*                 if String.compare dn1.h_formula_data_name dn2.h_formula_data_name = 0 then *)
  (*                   is_horm_h_formula_x rest1 rest2 *)
  (*                 else false *)
  (*           | ViewNode vn1, ViewNode vn2 -> *)
  (*                  if String.compare vn1.h_formula_view_name vn2.h_formula_view_name = 0 then *)
  (*                   is_horm_h_formula_x rest1 rest2 *)
  (*                 else false *)
  (*           | _ -> false *)
  (*       end *)
  (*     | _ -> false *)
  (* in *)
  (* let is_horm_h_formula hfs1 hfs2= *)
  (*   let pr1 = pr_list !print_h_formula in *)
  (*   Debug.no_2 "is_horm_h_formula" pr1 pr1 string_of_bool *)
  (*       (fun _ _ -> is_horm_h_formula_x hfs1 hfs2) hfs1 hfs2 *)
  (* in *)
  (* let heaps_of_formula args f = *)
  (*   let f0 = Cfout.rearrange_formula args f in *)
  (*   List.fold_left (fun r f1 -> r@(split_star_conjunctions f1)) [] (heap_of f0) *)
  (* in *)
  (****************************)
  let _, l_reach_dns,l_reach_vns = look_up_reachable_ptrs_w_alias prog lhs lroots 3 in
  let _, r_reach_dns,r_reach_vns = look_up_reachable_ptrs_w_alias prog rhs rroots 3 in
    (* let lnlength = List.length l_reach_dns in *)
    let lview_names = List.map (fun v -> v.h_formula_view_name) l_reach_vns in
    (* let rnlength = List.length r_reach_dns in *)
    let rview_names = List.map (fun v -> v.h_formula_view_name) r_reach_vns in
    if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then
      1 (* gen <- lemma *)
    else
      (* rhs is is_tail_recursive, lhs is non tail rec form*)
      check_tail_rec_rec_lemma prog lhs rhs l_reach_dns l_reach_vns r_reach_dns r_reach_vns
      (* if r_reach_dns != [] then -1 else *)
      (* match r_reach_vns with *)
      (*   | [rvn] -> *)
      (*         let rvdcl = Cast.look_up_view_def_raw 57 prog.Cast.prog_view_decls rvn.h_formula_view_name in *)
      (*         let self_sv =  CP.SpecVar (Named rvdcl.Cast.view_data_name, self, Unprimed) in *)
      (*         let rec_def_heaps = List.fold_left (fun r (f,_) -> *)
      (*             let views = Cformula.get_views f in *)
      (*             if List.exists (fun vn -> String.compare vn.Cformula.h_formula_view_name rvdcl.Cast.view_name = 0) views then *)
      (*               let hfs = heaps_of_formula [self_sv] f in *)
      (*               r@[hfs] *)
      (*             else r *)
      (*         ) [] rvdcl.Cast.view_un_struc_formula in *)
      (*         let rev_l_hfs = List.rev (heaps_of_formula [rvn.h_formula_view_node] lhs) in *)
      (*         if List.exists (fun hfs -> (List.length hfs = List.length rev_l_hfs) && is_horm_h_formula hfs rev_l_hfs) rec_def_heaps then *)
      (*           0 (\* gen -> lemma: right lemma application is not working properly. *)
      (*             todo: should be <- *\) *)
      (*         else -1 *)
      (*   | _ -> -1 *)

let need_cycle_checkpoint_fold_x prog ldnode lhs0 rvnode rhs0 reqset=
  if not (!Globals.lemma_syn && is_lem_syn_in_bound() )
    || (check_separation_unsat rhs0) || (check_separation_unsat lhs0) then -1 else
    (* let _, l_reach_dns,l_reach_vns = look_up_reachable_ptrs_w_alias prog lhs [ldnode.h_formula_data_node] 3 in *)
    (* let _, r_reach_dns,r_reach_vns = look_up_reachable_ptrs_w_alias prog rhs [rvnode.h_formula_view_node] 3 in *)
    (* (\* let lnlength = List.length l_reach_dns in *\) *)
    (* let lview_names = List.map (fun v -> v.h_formula_view_name) l_reach_vns in *)
    (* (\* let rnlength = List.length r_reach_dns in *\) *)
    (* let rview_names = List.map (fun v -> v.h_formula_view_name) r_reach_vns in *)
    (* if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then *)
    (*   1 *)
    (* else -1 *)
      if not (CP.eq_spec_var ldnode.h_formula_data_node rvnode.h_formula_view_node) then -1 else
      let rhs1 = subst (reqset) rhs0 in
      let ( _,mix_f,_,_,_) = split_components rhs1 in
      let eqs = (MCP.ptr_equations_without_null mix_f) in
      let ( _,lmf,_,_,_) = split_components lhs0 in
      let leqs = (MCP.ptr_equations_without_null lmf) in
      let rhs = subst (leqs@eqs) rhs1 in
      let lhs = subst (leqs) lhs0 in
      let _, l_hvs,_ = Cformula.get_hp_rel_formula lhs in
      let is_same,_ = Checkeq.checkeq_formulas [(CP.name_of_spec_var ldnode.h_formula_data_node)] lhs rhs in
      if is_same then -1 else
      if List.exists (fun vn -> CP.eq_spec_var vn.h_formula_view_node rvnode.h_formula_view_node && CP.diff_svl vn.h_formula_view_arguments rvnode.h_formula_view_arguments = []) l_hvs then -1 else
        need_cycle_checkpoint_fold_helper prog [ldnode.h_formula_data_node] lhs [rvnode.h_formula_view_node] rhs


let need_cycle_checkpoint_fold prog ldnode lhs rvnode rhs reqset=
  let pr1 = Cprinter.prtt_string_of_formula in
  Debug.no_2 "need_cycle_checkpoint_fold" pr1 pr1 string_of_int
      (fun _ _ -> need_cycle_checkpoint_fold_x prog ldnode lhs rvnode rhs reqset)
      lhs rhs

let is_seg_fold_form_helper prog lroot largs lhs0 rroot rargs rhs0 remap conseq_pure_opt=
  let is_full_match lnulls rnulls leqs reqs=
    let rroots = find_close [rroot] (leqs@reqs) in
    if CP.mem_svl lroot rroots then
      let largs1 = CP.subst_var_list leqs largs in
      let rargs1 = CP.subst_var_list reqs rargs in
      let l_neqNull = CP.diff_svl largs1 lnulls in
      let r_neqNull = CP.diff_svl rargs1 rnulls in
      (List.length r_neqNull = List.length l_neqNull) && (CP.diff_svl r_neqNull l_neqNull = [])
    else false
  in
  let is_cycle hds hvs eqs sv=
    let cl_sv = find_close [sv] eqs in
      ((List.exists (fun hd -> CP.mem_svl hd.h_formula_data_node cl_sv) hds)
      || List.exists (fun hv -> CP.mem_svl hv.h_formula_view_node cl_sv) hvs) &&
          ((List.exists (fun hd -> CP.intersect_svl cl_sv hd.h_formula_data_arguments != []) hds)
          || List.exists (fun hv -> CP.intersect_svl cl_sv hv.h_formula_view_arguments != []) hvs)
  in
  let rhs1 = subst (remap) rhs0 in
  let ( _,mix_f,_,_,_) = split_components rhs1 in
  let eqs = (MCP.ptr_equations_without_null mix_f) in
  let rhs = subst (eqs) rhs1 in
  let reqNulls0 = find_close (MCP.get_null_ptrs mix_f) eqs in
  let extra_reqNulls = match conseq_pure_opt with
    | None -> []
    | Some mf -> find_close (MCP.get_null_ptrs mf) (eqs@remap)
  in
  let reqNulls = reqNulls0@extra_reqNulls in
  let ( _,lmf,_,_,_) = split_components lhs0 in
  let leqs = (MCP.ptr_equations_without_null lmf) in
  let lhs = subst (leqs) lhs0 in
  let leqNulls = find_close (MCP.get_null_ptrs lmf) leqs in
  if is_full_match leqNulls reqNulls leqs (remap@eqs) then false
  else
    let lhds, lhvs,_ = get_hp_rel_formula lhs in
    let l_reach_ptrs0, l_reach_hds,l_reach_hvs = look_up_reachable_ptrs_w_alias prog lhs [lroot] 3 in
    let _ = DD.ninfo_hprint (add_str " l_reach_ptrs0" !CP.print_svl) l_reach_ptrs0  no_pos in
    let l_reach_ptrs = List.filter (fun sv -> not (List.exists (fun hd -> CP.eq_spec_var hd.h_formula_data_node sv) lhds) && not (List.exists (fun hv -> CP.eq_spec_var hv.h_formula_view_node sv) lhvs)) l_reach_ptrs0 in
    let _ = DD.ninfo_hprint (add_str " l_reach_ptrs" !CP.print_svl) l_reach_ptrs no_pos in
    let rhds, rhvs,_ = get_hp_rel_formula rhs in
    let r_reach_ptrs0,r_reach_hds,r_reach_hvs = (* look_up_reachable_ptr_args *) look_up_reachable_ptrs_w_alias prog rhs [rroot] 3 in
    let r_reach_ptrs = List.filter (fun sv -> not (List.exists (fun hd -> CP.eq_spec_var hd.h_formula_data_node sv) rhds) && not (List.exists (fun hv -> CP.eq_spec_var hv.h_formula_view_node sv) rhvs)) r_reach_ptrs0 in
    let reqnull = CP.intersect_svl r_reach_ptrs reqNulls in
    let leqnull = CP.intersect_svl l_reach_ptrs leqNulls in
    (* let l_cyc_svl = List.filter (is_cycle l_reach_hds l_reach_hvs) l_reach_ptrs0 in *)
    (* let r_cyc_svl = List.filter (is_cycle r_reach_hds r_reach_hvs) r_reach_ptrs0 in *)
    let cl_rargs = find_close rargs (Gen.BList.remove_dups_eq CP.eq_pair_spec_var (eqs@remap)) in
    (* let cl_largs = find_close largs (leqs) in *)
    (* let _ = DD.info_hprint (add_str " l_cyc_svl" !CP.print_svl) l_cyc_svl  no_pos in *)
    let _ = DD.ninfo_hprint (add_str " cl_rargs" !CP.print_svl) cl_rargs  no_pos in
     (* teminate by null *)
    if (reqnull != [] && leqnull != []) ||
      (* todo: next pt is pto *)
      (* or loop*)
      ((CP.mem_svl rroot cl_rargs) && (is_cycle l_reach_hds l_reach_hvs leqs lroot)) then
        let r_reach_ptrs1 = CP.diff_svl r_reach_ptrs reqNulls in
        let l_reach_ptrs1 = CP.diff_svl l_reach_ptrs leqNulls in
        (List.length r_reach_ptrs1 = List.length l_reach_ptrs1 ) && (CP.diff_svl r_reach_ptrs1 l_reach_ptrs1 = [])
    else false

(*
 -1; not seg form
 0: x::view<p> * ...<y> |- x::view<y>
 1: x::one_barch_of_view * ...<y> |- x::view<y>
2: not handle from 0: backward?
3: not handle from 1: backward?
*)
let is_seg_view2_fold_form_x prog lvnode lhs0 rvnode rhs0 remap conseq_pure_opt=
  let seg_fold_view lvnode rvnode=
    if String.compare lvnode.h_formula_view_name rvnode.h_formula_view_name = 0 then
      let vdcl = Cast.look_up_view_def_raw 59 prog.Cast.prog_view_decls lvnode.h_formula_view_name in
      if vdcl.Cast.view_is_segmented then
        let fwd_seg_ptrs = CP.intersect vdcl.Cast.view_cont_vars vdcl.Cast.view_forward_ptrs in
        if List.length fwd_seg_ptrs  = 1 then
          0
        else
          let back_seg_ptrs = CP.intersect vdcl.Cast.view_cont_vars vdcl.Cast.view_backward_ptrs in
          if List.length back_seg_ptrs  = 1 then 2 else -1
      else -1
    else -1
  in
  if (is_seg_fold_form_helper prog lvnode.h_formula_view_node lvnode.h_formula_view_arguments lhs0 rvnode.h_formula_view_node rvnode.h_formula_view_arguments rhs0 remap conseq_pure_opt) then
    seg_fold_view lvnode rvnode
  else -1

(*
-1: not the form
0: x::view<p> * p...<y> |- x::view<y> (y = null or y|-> )
1: x::.....<y>  |- x::view<y> (y = null or y|-> )
*)
let is_seg_view2_fold_form prog lvnode lhs rvnode rhs remap conseq_pure_opt=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 vn = Cprinter.prtt_string_of_h_formula (ViewNode vn) in
  let pr3 = pr_option Cprinter.string_of_mix_formula in
  Debug.no_5 "is_seg_view2_fold_form" pr2 pr2 pr1 pr1 pr3 string_of_int
      (fun _ _ _ _ _ -> is_seg_view2_fold_form_x prog lvnode lhs rvnode rhs remap conseq_pure_opt)
      lvnode rvnode lhs rhs conseq_pure_opt

let is_seg_view_br_fold_form_x prog ldnode lhs0 rvnode rhs0 remap conseq_pure_opt=
  let rec is_seg_match diffs =
    match diffs with
      | [] -> false
      | (mt, f1 ,f2)::rest ->
            let _ = Debug.ninfo_hprint (add_str "mt" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) mt no_pos in
            let _ = Debug.ninfo_hprint (add_str "f1" (!print_formula)) f1 no_pos in
            let _ = Debug.ninfo_hprint (add_str "f2" (!print_formula)) f2 no_pos in
            if is_empty_f f2 then true
            else is_seg_match rest
  in
  let exist_full_fold lhs rvnode=
    let vdecl = Cast.look_up_view_def_raw 60 prog.Cast.prog_view_decls rvnode.h_formula_view_name in
    let self_sv =  CP.SpecVar (Named vdecl.Cast.view_data_name, self, Unprimed) in
    let sst = [(self_sv,rvnode.h_formula_view_node)] in
    let ivars = [CP.name_of_spec_var rvnode.h_formula_view_node] in
    let init_mtl = [[]] in
    List.exists (fun (f,_) ->
        let dns = get_datas f in
        if List.exists (fun dn -> CP.eq_spec_var self_sv dn.h_formula_data_node) dns then
          let f1 = elim_exists f in
          let _,new_f = split_quantifiers f1 in
          let f2 = subst sst new_f in
          let f3 = formula_of_heap (join_star_conjunctions (heap_of f2)) (pos_of_formula f) in
          let (r,diffs) = Checkeq.checkeq_formulas_with_diff_mt ivars ([],[]) lhs f3 init_mtl in
          if r then true else
            is_seg_match diffs
        else false
    ) vdecl.Cast.view_un_struc_formula
  in
  let seg_fold_view ldnode rvnode=
    let vdcl = Cast.look_up_view_def_raw 59 prog.Cast.prog_view_decls rvnode.h_formula_view_name in
    if String.compare ldnode.h_formula_data_name vdcl.Cast.view_data_name = 0 then
      if vdcl.Cast.view_is_segmented then
        let fwd_seg_ptrs = CP.intersect vdcl.Cast.view_cont_vars vdcl.Cast.view_forward_ptrs in
        if List.length fwd_seg_ptrs  = 1 then
          if exist_full_fold lhs0 rvnode then 1 else -1
        else
          let back_seg_ptrs = CP.intersect vdcl.Cast.view_cont_vars vdcl.Cast.view_backward_ptrs in
          if List.length back_seg_ptrs  = 1 then -1 (* 3 *) else -1
      else -1
    else -1
  in
  if not (CP.eq_spec_var ldnode.h_formula_data_node rvnode.h_formula_view_node) then -1 else
  if (is_seg_fold_form_helper prog ldnode.h_formula_data_node ldnode.h_formula_data_arguments lhs0 rvnode.h_formula_view_node rvnode.h_formula_view_arguments rhs0 remap conseq_pure_opt) then
    seg_fold_view ldnode rvnode
  else -1

(*
-1: not the form
0: x::view<p> * p...<y> |- x::view<y>
1: x::.....<y>  |- x::view<y>
*)
let is_seg_view_br_fold_form prog ldnode lhs rvnode rhs remap conseq_pure_opt=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 dn = Cprinter.prtt_string_of_h_formula (DataNode dn) in
  let pr3 vn = Cprinter.prtt_string_of_h_formula (ViewNode vn) in
  let pr4 = pr_option Cprinter.string_of_mix_formula in
  Debug.no_5 "is_seg_view_br_fold_form" pr2 pr3 pr1 pr1 pr4 string_of_int
      (fun _ _ _ _ _ -> is_seg_view_br_fold_form_x prog ldnode lhs rvnode rhs remap conseq_pure_opt)
      ldnode rvnode lhs rhs conseq_pure_opt

let update_conseq conseq rhs_b rvnode new_rcmb=
  let subst_hf new_hf hf=
    match hf with
      | ViewNode vn ->
            if checkeq_view_node vn rvnode then
              new_hf
            else hf
      | _ -> hf
  in
  let n_conseq = formula_trans_heap_node (subst_hf new_rcmb) conseq in
  let n_rhs_b = {rhs_b with formula_base_heap = heap_trans_heap_node
          (subst_hf new_rcmb) rhs_b.formula_base_heap} in
  (n_conseq, n_rhs_b)

let split_r_vnode cut_points cont_args_pos rvnode conseq rhs_b = match cut_points with
  | [p] ->
        (*split rvnode into two view segments*)
        let rvnode_seg1 = {rvnode with h_formula_view_arguments = set_pos rvnode.h_formula_view_arguments 0
                (List.hd cont_args_pos ) p [];
            h_formula_view_original = true;
            h_formula_view_unfold_num = 0;
        } in
        let rvnode_seg2 = {rvnode with h_formula_view_node = p;
            h_formula_view_original = true;
            h_formula_view_unfold_num = 0 ;
        } in
        let cmb = mkStarH (ViewNode rvnode_seg1) (ViewNode rvnode_seg2) no_pos in
        (* update: rvnode = rvnode_seg1 * rvnode_seg2 *)
        let n_conseq, n_rhs_b =  update_conseq conseq rhs_b rvnode cmb in
        (true, n_conseq, n_rhs_b)
  | _ -> (false, conseq, rhs_b)

let seg_fold_view2_x prog lvnode rvnode conseq rhs_b=
  let vdecl = Cast.look_up_view_def_raw 60 prog.Cast.prog_view_decls lvnode.h_formula_view_name in
  (* get pos of fwd seg ptrs. todo: backward seg ptrs *)
  let cont_args_pos = List.map (fun sv -> get_pos vdecl.Cast.view_vars 0  sv)
    (CP.intersect_svl vdecl.Cast. view_forward_ptrs vdecl.Cast.view_cont_vars) in
  (* get cont args of lvnode *)
  let cont_act_args = retrieve_args_from_locs lvnode.h_formula_view_arguments cont_args_pos in
  split_r_vnode cont_act_args cont_args_pos rvnode conseq rhs_b

let seg_fold_view2 prog lvnode rvnode conseq rhs_b=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 vn = Cprinter.prtt_string_of_h_formula (ViewNode vn) in
  let pr3 bf = pr1 (Base bf) in
  Debug.no_4 "seg_fold_view2" pr2 pr2 pr1 pr3 (pr_triple string_of_bool pr1 pr3)
      (fun _ _ _ _ -> seg_fold_view2_x prog lvnode rvnode conseq rhs_b)
      lvnode rvnode conseq rhs_b


(*
-1: nothing_todo
0: need fold
1: OK
*)
let seg_fold_view_br_x prog ldnode rvnode ante conseq rhs_b=
  let is_seg_view f vname fwd_seg_args=
    let vns =  get_views f in
    match vns with
      | [vn] ->
            String.compare vn.h_formula_view_name vname = 0 &&
            CP.intersect_svl vn.h_formula_view_arguments fwd_seg_args !=[]
      | _ -> false
  in
  let get_seg_view f fwd_seg_args=
    let vns =  get_views f in
    match vns with
      | [vn] ->
            let seg_svl =  CP.intersect_svl vn.h_formula_view_arguments fwd_seg_args in
            List.map (fun sv -> (vn.h_formula_view_node, sv)) seg_svl
      | _ -> []
  in
  let subst_heap_node sst hf=
    match hf with
      | ViewNode vn ->
            ViewNode {vn with h_formula_view_node = CP.subs_one sst vn.h_formula_view_node}
      | DataNode vn ->
            DataNode {vn with h_formula_data_node = CP.subs_one sst vn.h_formula_data_node}
      | _ -> hf
  in
  let rec is_seg_match fwd_seg_args diffs dist_seg=
    match diffs with
      | [] -> [],dist_seg
      | (mt, f1 ,f2)::rest ->
            let _ = Debug.ninfo_hprint (add_str "mt" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) mt no_pos in
            let _ = Debug.ninfo_hprint (add_str "f1" (!print_formula)) f1 no_pos in
            let _ = Debug.ninfo_hprint (add_str "f2" (!print_formula)) f2 no_pos in
            if is_empty_f f2 then mt,dist_seg
            else if is_seg_view f2 rvnode.h_formula_view_name fwd_seg_args then
              is_seg_match fwd_seg_args rest (dist_seg@[(mt,f1,f2)])
            else is_seg_match fwd_seg_args rest dist_seg
  in
  let rec find_first_seg_match ivars init_mtl fwd_seg_args fs res dist_segs0=
    match fs with
      | f::rest ->
            let (r,diffs) = Checkeq.checkeq_formulas_with_diff_mt ivars ([],[]) ante f init_mtl in
            if r then find_first_seg_match ivars init_mtl fwd_seg_args rest res dist_segs0
            else
              let sst, dist_segs = is_seg_match fwd_seg_args diffs [] in
              if sst = [] then
                find_first_seg_match ivars init_mtl fwd_seg_args rest (res@[(f, diffs)]) ( dist_segs0@dist_segs)
              else
                sst,res,dist_segs0
      | [] -> [],res,dist_segs0
  in
  let vdecl = Cast.look_up_view_def_raw 60 prog.Cast.prog_view_decls rvnode.h_formula_view_name in
  (* get pos of fwd seg ptrs. todo: backward seg ptrs *)
  let fwd_seg_args = (CP.intersect_svl vdecl.Cast.view_forward_ptrs vdecl.Cast.view_cont_vars) in
  let cont_args_pos = List.map (fun sv -> get_pos vdecl.Cast.view_vars 0 sv)
    fwd_seg_args in
  (* fwd *)
  let self_sv =  CP.SpecVar (Named vdecl.Cast.view_data_name, self, Unprimed) in
  let sst = [(self_sv,rvnode.h_formula_view_node)] in
  let rhs_fs = List.fold_left (fun r (f,_) ->
      let dns = get_datas f in
      if List.exists (fun dn -> CP.eq_spec_var self_sv dn.h_formula_data_node) dns then
         let f1 = elim_exists f in
         let _,new_f = split_quantifiers f1 in
         let _ = Debug.ninfo_hprint (add_str "new_f" (!print_formula)) new_f no_pos in
         (* let f12 = Cformula.force_elim_exists new_f quans in *)
         (* let _ = Debug.ninfo_hprint (add_str "f12" (!print_formula)) f12 no_pos in *)
        let f2 = formula_of_heap (join_star_conjunctions (heap_of new_f)) (pos_of_formula f) in
        r@[(subst sst f2)]
      else r
  ) [] vdecl.Cast.view_un_struc_formula in
  let ivars = [(CP.name_of_spec_var rvnode.h_formula_view_node)] in
  let _ = Debug.ninfo_hprint (add_str "fwd_seg_args" !CP.print_svl) fwd_seg_args no_pos in
  let sst1, fs_diffs, dist_segs = find_first_seg_match ivars
    [[]] fwd_seg_args rhs_fs [] [] in
  let _ = Debug.ninfo_hprint (add_str "sst1" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) sst1 no_pos in
  let _ = Debug.ninfo_hprint (add_str "fs_diffs" (pr_list_ln (pr_pair !print_formula (pr_list_ln (pr_triple (pr_list (pr_pair !CP.print_sv !CP.print_sv)) !print_formula !print_formula))))) fs_diffs no_pos in
  let _ = Debug.ninfo_hprint (add_str "dist_segs" ( (pr_list_ln (pr_triple (pr_list (pr_pair !CP.print_sv !CP.print_sv)) !print_formula !print_formula)))) dist_segs no_pos in
  let cut_points = List.fold_left (fun r (sv1,sv2) ->
      if CP.mem_svl sv2 fwd_seg_args then r@[sv1] else r
  ) [] sst1 in
  if cut_points != [] then
    let is_ok, nc_cons, n_rhs_b = split_r_vnode cut_points cont_args_pos rvnode conseq rhs_b in
    let res_ok = if is_ok then 1 else -1 in
    (res_ok, nc_cons, n_rhs_b,[])
  else begin
    let lhvs = (get_views ante) in
    let l_non_dist_views = List.fold_left (fun r hv ->
        if String.compare hv.h_formula_view_name rvnode.h_formula_view_name != 0 then
          r@[hv.h_formula_view_node]
        else r
    ) [] lhvs in
    let _ = Debug.ninfo_hprint (add_str "l_non_dist_views" !CP.print_svl) l_non_dist_views no_pos in
    let dist_segs = [] in
    match dist_segs with
      | [(mt,f1,f2)] ->
            let sst = get_seg_view f2 fwd_seg_args in
            if sst = [] then
              (-1, conseq, rhs_b, [])
            else
              let mt1 = List.map (fun (sv1, sv2) -> (sv1, CP.subs_one sst sv2)) mt in
              let cut_points = List.fold_left (fun r (sv1,sv2) ->
                  if CP.mem_svl sv2 fwd_seg_args && not (CP.mem_svl sv1 l_non_dist_views) then r@[sv1] else r
              ) [] mt1 in
              let _ = Debug.ninfo_hprint (add_str "cut_points 2" !CP.print_svl) cut_points no_pos in
              if cut_points != [] then
                let is_ok, nc_cons, n_rhs_b = split_r_vnode cut_points cont_args_pos rvnode conseq rhs_b in
                let res_ok = if is_ok then 1 else -1 in
                (res_ok, nc_cons, n_rhs_b,[])
              else
                (-1, conseq, rhs_b, [])
      | _ ->
            (* aux info: nested linked list*)
            match fs_diffs with
              | [br, diffs] -> begin
                  let _ = Debug.ninfo_hprint (add_str "br" (!print_formula)) br no_pos in
                  let sst2 = List.combine vdecl.Cast.view_vars rvnode.h_formula_view_arguments in
                  match diffs with
                    | [(mt,_,_)] ->
                          (* let eqs = List.fold_left (fun r (sv2,sv) -> *)
                          (*     if not (CP.mem_svl sv vdecl.Cast.view_vars) then *)
                          (*       r@[(sv,sv2)] *)
                          (*     else r *)
                          (*     ) [] mt in *)
                          (* let ps = List.map (fun (sv1, sv2) -> CP.mkPtrEqn sv1 sv2 no_pos) eqs in *)
                          (* let eq_p = MCP.mix_of_pure (CP.conj_of_list ps no_pos) in *)
                          (* let br1 = subst sst2 ( br) in *)
                          (* let br2 = formula_trans_heap_node (subst_heap_node eqs) br1 in *)
                          (* let _ = Debug.ninfo_hprint (add_str "br2" (!print_formula)) br2 no_pos in *)
                          (* let cmb = (join_star_conjunctions (heap_of br2)) in *)
                          (* let n_conseq, n_rhs_b = update_conseq conseq rhs_b rvnode cmb in *)
                          (* (1, mkAnd_pure n_conseq eq_p no_pos, mkAnd_base_pure n_rhs_b eq_p no_pos,eqs) *)
                          (0, conseq, rhs_b, [])
                    | _ -> (-1, conseq, rhs_b, [])
                end
      | _ -> (-1, conseq, rhs_b, [])
  end

let seg_fold_view_br prog ldnode rvnode ante conseq rhs_b=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2a vn = Cprinter.prtt_string_of_h_formula (ViewNode vn) in
  let pr2b dn = Cprinter.prtt_string_of_h_formula (DataNode dn) in
  let pr3 bf = pr1 (Base bf) in
  let pr4 = pr_list (pr_pair !CP.print_sv !CP.print_sv) in
  Debug.no_5 "seg_fold_view_br" pr2b pr2a pr1 pr1 pr3
      (pr_quad string_of_int pr1 pr3 pr4)
      (fun _ _ _ _ _ -> seg_fold_view_br_x prog ldnode rvnode ante conseq rhs_b)
      ldnode rvnode ante conseq rhs_b

let need_cycle_checkpoint_unfold_x prog lvnode lhs0 rdnode rhs0 reqset=
  if not (!Globals.lemma_syn && is_lem_syn_in_bound() )
    || (check_separation_unsat rhs0) || (check_separation_unsat lhs0)  then -1 else
      let rhs1 = subst (reqset) rhs0 in
      let ( _,mix_f,_,_,_) = split_components rhs1 in
      let eqs = (MCP.ptr_equations_without_null mix_f) in
      let rhs = subst (eqs) rhs1 in
      let ( _,lmf,_,_,_) = split_components lhs0 in
      let leqs = (MCP.ptr_equations_without_null lmf) in
      let lhs = subst (leqs) lhs0 in
      let is_same,_ = Checkeq.checkeq_formulas [(CP.name_of_spec_var lvnode.h_formula_view_node)] lhs rhs in
      if is_same then -1 else
      let _, l_reach_dns,l_reach_vns = look_up_reachable_ptrs_w_alias prog lhs [lvnode.h_formula_view_node] 3 in
      let _, r_reach_dns,r_reach_vns = look_up_reachable_ptrs_w_alias prog rhs [rdnode.h_formula_data_node] 3 in
      (* let lnlength = List.length l_reach_dns in *)
      let lview_names = List.map (fun v -> v.h_formula_view_name) l_reach_vns in
      (* let rnlength = List.length r_reach_dns in *)
      let rview_names = List.map (fun v -> v.h_formula_view_name) r_reach_vns in
      if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then
        0
      else
        let lem_type =  check_tail_rec_rec_lemma prog lhs rhs l_reach_dns l_reach_vns r_reach_dns r_reach_vns in
        lem_type

let need_cycle_checkpoint_unfold prog lvnode lhs rdnode rhs reqset=
  let pr1 = Cprinter.prtt_string_of_formula in
  Debug.no_2 "need_cycle_checkpoint_unfold" pr1 pr1 string_of_int
      (fun _ _ -> need_cycle_checkpoint_unfold_x prog lvnode lhs rdnode rhs reqset)
      lhs rhs

let get_shortest_length_base_x fs vname=
  let find_dnode_of_base r f=
    let hds, hvs, _ = get_hp_rel_formula f in
    if List.for_all (fun hv -> String.compare vname hv.h_formula_view_name !=0 ) hvs then
      r@[(hds)]
    else r
  in
  let process_one shortest dns=
    let dn = List.length dns in
    if dn < shortest then dn else shortest
  in
  let base_fs = List.fold_left find_dnode_of_base [] fs in
  match base_fs with
    | [] -> 0
    | dns::rest ->
          let ini = List.length dns in
          List.fold_left process_one ini rest

let get_shortest_length_base fs view_name=
  let pr1 = pr_list !print_formula in
  Debug.no_2 "get_shortest_length_base" pr1 pr_id string_of_int
      (fun _ _ -> get_shortest_length_base_x fs view_name)
      fs view_name


let norm_seg_split_x prog vname0 r other_args unk_hps defs=
  (**************INTERNAL**********)
  let look_up_continuous_para non_root_args f=
    let vns = get_views f in
    let rec_vns, other_vns = List.partition (fun vn ->
        (List.exists (fun vn -> String.compare vn.h_formula_view_name vname0=0) vns)
    ) vns in
      if other_vns != [] then [] else
        let ( _,mix_f,_,_,_) = split_components f in
        let eqs = (MCP.ptr_equations_without_null mix_f) in
        (*cont paras are para not changed, just forwarded*)
        let cont_paras = List.fold_left (fun cur_cont_paras vn ->
            let f_wo_rec_hps = drop_views_formula f [vname0] in
            let all_svl = fv f_wo_rec_hps in
            let all_svl1 = CP.diff_svl all_svl (CP.remove_dups_svl (
                List.fold_left (fun r (sv1,sv2) -> r@[sv1;sv2]) [] eqs)) in
            let cont_args = CP.diff_svl vn.h_formula_view_arguments all_svl1 in
            let closed_rec_args = find_close cont_args eqs in
            CP.intersect_svl cur_cont_paras closed_rec_args
        ) non_root_args rec_vns
        in
        cont_paras
  in
  (********END INTERNAL*************)
  (*classify base vs. rec*)
  let rec_fs,base_fs = List.partition (fun f ->
      let vns = get_views f in
      (List.exists (fun vn -> String.compare vn.h_formula_view_name vname0=0) vns)
  ) defs in
  (*in rec branches, one parameter is continuous*)
  let cont_args = List.fold_left (look_up_continuous_para) other_args rec_fs in
  let _ = Debug.info_hprint (add_str "cont_args: " !CP.print_svl) cont_args no_pos in
  if cont_args = [] then
    (false, (r::other_args ,[]))
  else
    (*in base branches, root is closed and continuos parameter is contant*)
    (*if there are > segments: need generation. NOW: ASSUME one base case*)
    let rem_args = r::(CP.diff_svl other_args cont_args) in
     (true, (rem_args, cont_args))

let norm_seg_split prog vname r other_args unk_hps defs=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 = pr_list_ln pr1 in
  let pr3 = pr_pair !CP.print_svl !CP.print_svl in
  Debug.no_4 "CFU.norm_seg_split" pr_id !CP.print_sv !CP.print_svl pr2 (pr_pair string_of_bool pr3)
      (fun _ _ _ _ -> norm_seg_split_x prog vname r other_args unk_hps defs)
      vname r other_args defs


let check_seg_split_pred_x prog es_formula vdef vnode dnode=
  let ss0 = List.combine vdef.C.view_vars vnode.h_formula_view_arguments in
  let cont_args = CP.subst_var_list ss0 vdef.C.view_cont_vars in
  let ( _,mix_f,_,_,_) = split_components es_formula in
  let eqs = (MCP.ptr_equations_without_null mix_f) in
  let deqset = find_close [dnode.h_formula_data_node] eqs in
  if CP.intersect_svl deqset cont_args !=[] then
    let eqs1 = List.map (fun (sv1,sv2) -> if CP.mem_svl sv1 vnode.h_formula_view_arguments then
      (sv2,sv1) else (sv1,sv2)
    ) eqs in
    Some (vnode, {dnode with h_formula_data_node = CP.subs_one eqs1 dnode.h_formula_data_node})
  else
    None

let check_seg_split_pred prog es_formula vdef vnode dnode=
  let pr1 vn = Cprinter.prtt_string_of_h_formula (ViewNode vn) in
  let pr2 vn = Cprinter.prtt_string_of_h_formula (DataNode vn) in
  Debug.no_3 "check_seg_split_pred" Cprinter.prtt_string_of_formula pr1 pr2 (pr_option (pr_pair pr1 pr2))
      (fun _ _ _ -> check_seg_split_pred_x prog es_formula vdef vnode dnode)
      es_formula vnode dnode


let subst_rel_def_x f rel_defs=
  let ls_rel_args = get_list_rel_args f in
  if ls_rel_args = [] || rel_defs = [] then f else
    let rel_p, substed_rels = List.fold_left (fun (p, acc_rels) (rel_sv, rel_def) ->
        (*normalize the paras (convert back to the orig)*)
        let rel_args_opt = CP.get_relargs_opt rel_sv in
        let rel_def1,n_acc_rels =
          match rel_args_opt with
            | Some (rel,args) -> begin
                try
                  let _,args0 = List.find (fun (rel1,_) -> CP.eq_spec_var rel rel1) ls_rel_args in
                  let ss0 = List.combine args args0 in
                  (CP.subst ss0 rel_def, acc_rels@[rel])
                with _ -> rel_def,acc_rels
              end
            | None -> rel_def,acc_rels
      in
        let _ = Debug.ninfo_hprint (add_str "rel_def1:\n " (!CP.print_formula)) rel_def1 no_pos in
        (CP.mkAnd p rel_def1 no_pos, n_acc_rels)
    ) ((CP.mkTrue no_pos),[]) rel_defs in
    let f1 = drop_sel_rel substed_rels f in
    let f2 = mkAnd_pure f1 (MCP.mix_of_pure rel_p) no_pos in
    f2

let subst_rel_def f rel_defs=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 = pr_list_ln (pr_pair !CP.print_formula !CP.print_formula) in
  Debug.no_2 "subst_rel_def" pr1 pr2 pr1
      (fun _ _ -> subst_rel_def_x f rel_defs)
      f rel_defs

let subst_rel_def_4_hpdef hp_def rel_defs=
  {hp_def with def_rhs = List.map (fun (f, og) ->
      let nf = subst_rel_def f rel_defs in
      let nog = match og with
        | None -> None
        | Some f -> Some (subst_rel_def f rel_defs)
      in
      (nf, nog)
  ) hp_def.def_rhs}


let analyse_error () =
  (*size*)
  (* iSIZE_PROP *)
  0
  (* BAG_VAL_PROP 1 *)


(*******************************************************************)
(************************GRAPH*****************************************)
(*******************************************************************)
let rec get_ptrs_connected_w_args_f_x (f0: formula)=
  let rec helper f=
    match f with
      | Base fb ->
            (get_ptrs_connected_w_args fb.formula_base_heap)
      | Exists _ ->
            let f1 = elim_exists f in helper f1
      | _ -> report_error no_pos "CF.get_ptrs_connected_w_args_f_x: not handle yet"
  in
  helper f0

and get_ptrs_connected_w_args_f (f: formula)=
  let pr1 = !print_formula in
  let pr2 = pr_list !CP.print_svl in
  Debug.no_1 "CF.get_ptrs_connected_w_args_f" pr1 pr2
      (fun _ -> get_ptrs_connected_w_args_f_x f) f

and get_ptrs_connected_w_args (f0: h_formula): CP.spec_var list list =
  (* let rec insert ls comps done_comps= *)
  (*   match comps with *)
  (*     | [] -> *)
  (*           (\* let pr1 = pr_list !CP.print_svl in *\) *)
  (*           (\* let _ = Debug.info_pprint (" ls: "^ (!CP.print_svl ls)) no_pos in *\) *)
  (*           (\* let _ = Debug.info_pprint (" done_comps: "^ (pr1 done_comps)) no_pos in *\) *)
  (*           done_comps@[ls] *)
  (*     | comp::rest -> if List.exists (fun sv -> CP.mem_svl sv comp) ls then *)
  (*         done_comps@((CP.remove_dups_svl (ls@comp))::rest) *)
  (*       else insert ls rest (done_comps@[comp]) *)
  (* in *)
  (* let rec combine ls comps rest_comps= *)
  (*     match comps with *)
  (*     | [] -> (ls::rest_comps) *)
  (*     | comp::rs -> if List.exists (fun sv -> CP.mem_svl sv comp) ls then *)
  (*         combine (ls@comp) rs rest_comps *)
  (*       else combine ls rs(rest_comps@[comp]) *)
  (* in *)
  (* let rec fix_helper comps= *)
  (*   match comps with *)
  (*     | [] -> [] *)
  (*     | [a] -> [a] *)
  (*     | ls::rest -> *)
  (*           let n_comps = combine ls rest [] in *)
  (*           if List.length comps = List.length n_comps then comps *)
  (*           else fix_helper n_comps *)
  (* in *)
  let rec find_comp marked_vs es cur_comp=
    if es = [] then (CP.remove_dups_svl (cur_comp@marked_vs), []) else
      match marked_vs with
        | [] -> (CP.remove_dups_svl cur_comp,es)
        | v::vs ->
              let inter_es,rem_es = List.partition (fun ls ->
                  (* match ls with *)
                  (*   | [] -> false *)
                  (*   | sv1:: _ ->  *)(CP.mem_svl v ls)
              ) es in
              let inter_vs = List.fold_left (fun ls1 ls2 ->
                  (* match ls with *)
                  (*   | [] -> [] *)
                  (*   |_::ls2 ->  *)ls1 @ls2
              ) [] inter_es in
              find_comp (CP.remove_dups_svl (vs@inter_vs)) rem_es (cur_comp@[v])
  in
  let rec part_connected_graph vertexs edges comps =
    if vertexs = [] || edges = [] then comps else
      let comp, e_rest = find_comp [List.hd vertexs] edges [] in
      part_connected_graph (CP.diff_svl (List.tl vertexs) comp) e_rest (comps@[comp])
  in
  let rec helper f comps0=
    match f with
      | ViewNode {h_formula_view_node = c;
        h_formula_view_arguments = args}
      | DataNode {h_formula_data_node = c;
        h_formula_data_arguments = args}-> (comps0@[c::args])
            (* insert (c::((\* List.filter CP.is_node_typ *\) args)) comps0 [] *)
      | Conj {h_formula_conj_h1 = h1; h_formula_conj_h2 = h2}
      | Star {h_formula_star_h1 = h1; h_formula_star_h2 = h2}
      | Phase {h_formula_phase_rd = h1; h_formula_phase_rw = h2}
          -> let comps1 = helper h1 comps0 in
            helper h2 comps1
      | _ -> comps0
  in
  let edges = helper f0 [] in
  let vetexs = CP.remove_dups_svl (List.fold_left (fun ls1 ls2 -> ls1@ls2) [] edges) in
  (* fix_helper comps *) part_connected_graph vetexs edges []

(*duplicate with filter_var_..*)
let slice_framing_heaps_x hf0 framing_svl =
  let rec helper hf=
    match hf with
      | Star {h_formula_star_h1 = hf1;
        h_formula_star_h2 = hf2;
        h_formula_star_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            (match n_hf1,n_hf2 with
              | (HEmp,HEmp) -> HEmp
              | (HEmp,_) -> n_hf2
              | (_,HEmp) -> n_hf1
              | _ -> Star {h_formula_star_h1 = n_hf1;
                h_formula_star_h2 = n_hf2;
                h_formula_star_pos = pos}
        )
      | StarMinus { h_formula_starminus_h1 = hf1;
        h_formula_starminus_h2 = hf2;
        h_formula_starminus_aliasing = a;
        h_formula_starminus_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            StarMinus { h_formula_starminus_h1 = n_hf1;
            h_formula_starminus_h2 = n_hf2;
            h_formula_starminus_aliasing =a;
            h_formula_starminus_pos = pos}
      | Conj { h_formula_conj_h1 = hf1;
        h_formula_conj_h2 = hf2;
        h_formula_conj_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            Conj { h_formula_conj_h1 = n_hf1;
            h_formula_conj_h2 = n_hf2;
            h_formula_conj_pos = pos}
      | ConjStar { h_formula_conjstar_h1 = hf1;
        h_formula_conjstar_h2 = hf2;
        h_formula_conjstar_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            ConjStar { h_formula_conjstar_h1 = n_hf1;
            h_formula_conjstar_h2 = n_hf2;
            h_formula_conjstar_pos = pos}
      | ConjConj { h_formula_conjconj_h1 = hf1;
        h_formula_conjconj_h2 = hf2;
        h_formula_conjconj_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            ConjConj { h_formula_conjconj_h1 = n_hf1;
            h_formula_conjconj_h2 = n_hf2;
            h_formula_conjconj_pos = pos}
      | Phase { h_formula_phase_rd = hf1;
        h_formula_phase_rw = hf2;
        h_formula_phase_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            Phase { h_formula_phase_rd = n_hf1;
            h_formula_phase_rw = n_hf2;
            h_formula_phase_pos = pos}
      | DataNode hd -> if not(CP.mem_svl hd.h_formula_data_node framing_svl) then
          HEmp
        else hf
      | ViewNode hv -> if not(CP.mem_svl hv.h_formula_view_node framing_svl) then
          HEmp
        else hf
      | HRel _
      | Hole _ | FrmHole _ | ThreadNode _
      | HTrue
      | HFalse
      | HEmp -> hf
  in
  helper hf0

let slice_framing_heaps hf0 framing_svl =
  let pr1 = !print_h_formula in
  let pr2 = !CP.print_svl in
  (* let pr3 = pr_list pr1 in *)
  Debug.no_2 "slice_framing_heaps" pr1 pr2 pr1
      (fun _ _ -> slice_framing_heaps_x hf0 framing_svl) hf0 framing_svl

let slice_frame_x (f0: formula) comps=
  let slice_helper hf p all_ptrs comp=
    let irr_svl = CP.diff_svl all_ptrs comp in
    let _,np = Cpgraph.prune_irr_neq_new p irr_svl in
    let nhf = slice_framing_heaps hf comp in
    (nhf,np)
  in
  let rec helper f=
  match f with
    | Base fb ->
          let p = MCP.pure_of_mix fb.formula_base_pure in
          let all_ptrs = CP.remove_dups_svl (CP.fv p) in
          let ls_h_p = List.map (slice_helper fb.formula_base_heap p all_ptrs) comps in
          List.map (fun (h,p) -> Base {fb with formula_base_heap = h;
              formula_base_pure = MCP.mix_of_pure p;
          }) ls_h_p
    | Exists _ -> let f1 = elim_exists f in
      helper f1
    | _ -> report_error no_pos "CF.slice_frame: not handle yet"
  in
  helper f0

let slice_frame (f: formula) comps=
  let pr1 = !print_formula in
  let pr2 = pr_list !CP.print_svl in
  Debug.no_2 "CF.slice_frame" pr1 pr2 (pr_list_ln pr1)
      (fun _ _ -> slice_frame_x f comps) f comps

let elim_emp hf0 svl =
  let rec helper hf=
    match hf with
      | Star {h_formula_star_h1 = hf1;
        h_formula_star_h2 = hf2;
        h_formula_star_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            (match n_hf1,n_hf2 with
              | (HEmp,HEmp) -> HEmp
              | (HEmp,_) -> n_hf2
              | (_,HEmp) -> n_hf1
              | _ -> Star {h_formula_star_h1 = n_hf1;
                h_formula_star_h2 = n_hf2;
                h_formula_star_pos = pos}
        )
      | StarMinus { h_formula_starminus_h1 = hf1;
        h_formula_starminus_h2 = hf2;
        h_formula_starminus_aliasing =a ;
        h_formula_starminus_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            StarMinus { h_formula_starminus_h1 = n_hf1;
            h_formula_starminus_h2 = n_hf2;
            h_formula_starminus_aliasing =a;
            h_formula_starminus_pos = pos}
      | Conj { h_formula_conj_h1 = hf1;
        h_formula_conj_h2 = hf2;
        h_formula_conj_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            Conj { h_formula_conj_h1 = n_hf1;
            h_formula_conj_h2 = n_hf2;
            h_formula_conj_pos = pos}
      | ConjStar { h_formula_conjstar_h1 = hf1;
        h_formula_conjstar_h2 = hf2;
        h_formula_conjstar_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            ConjStar { h_formula_conjstar_h1 = n_hf1;
            h_formula_conjstar_h2 = n_hf2;
            h_formula_conjstar_pos = pos}
      | ConjConj { h_formula_conjconj_h1 = hf1;
        h_formula_conjconj_h2 = hf2;
        h_formula_conjconj_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            ConjConj { h_formula_conjconj_h1 = n_hf1;
            h_formula_conjconj_h2 = n_hf2;
            h_formula_conjconj_pos = pos}
      | Phase { h_formula_phase_rd = hf1;
        h_formula_phase_rw = hf2;
        h_formula_phase_pos = pos} ->
            let n_hf1 = helper hf1 in
            let n_hf2 = helper hf2 in
            Phase { h_formula_phase_rd = n_hf1;
            h_formula_phase_rw = n_hf2;
            h_formula_phase_pos = pos}
      | DataNode hd -> if (CP.mem_svl hd.h_formula_data_node svl) then
          HEmp
        else hf
      | ViewNode hv -> if (CP.mem_svl hv.h_formula_view_node svl) then
          HEmp
        else hf
      | HRel _
      | Hole _ | FrmHole _ | ThreadNode _
      | HTrue
      | HFalse
      | HEmp -> hf
  in
  if svl = [] then hf0 else helper hf0


let update_f_x f0 drop_hvns inferred_ps=
  let rec helper f=
  match f with
    | Base fb ->
          let nh = elim_emp fb.formula_base_heap drop_hvns in
          let np =  List.fold_left (fun p1 p2->  CP.mkAnd p1 p2 no_pos)
            (MCP.pure_of_mix fb.formula_base_pure) inferred_ps in
          Base {fb with formula_base_heap = nh;
              formula_base_pure = MCP.mix_of_pure np;
          }
    | Exists fe -> let qvars, base1 = split_quantifiers f in
      let nf = helper base1 in
        add_quantifiers qvars nf
    | _ -> report_error no_pos "CF.slice_frame: not handle yet"
  in
  helper f0

let update_f f drop_hvns inferred_ps=
  let pr1 = !print_formula in
  let pr2 = !CP.print_svl in
  Debug.no_2 "CF.update_f" pr1 pr2  pr1
      (fun _ _ -> update_f_x f drop_hvns inferred_ps) f drop_hvns

(*pto consistent, nemps
*)
let xpure_graph_pto_x prog seg_datas oamap_view_datas f=
  (******************************)
(*
 x::pto<_> * x::pto<_> -> false
  x::pto<a> * x::lseg<a> -> false
*)
  let rec check_inconsistent dns=
    match dns with
      | [] -> false
      | dn::rest -> if List.exists (fun dn1 ->
            CP.eq_spec_var dn.h_formula_data_node dn1.h_formula_data_node
        ) rest then true else
          check_inconsistent rest
  in
  let dn2vn dn vname=
    let args = List.filter (CP.is_node_typ) dn.h_formula_data_arguments in
    let args_orig,_ = List.fold_left (fun (r,i) sv -> (r@[(CP.SVArg sv, i)], i+1)) ([],0) args in
    let args_annot,_ = List.fold_left (fun (r,i) sv -> (r@[(CP.ImmAnn (CP.ConstAnn Mutable),i)], i+1) ) ([],0) args in
    {
        h_formula_view_node = dn.h_formula_data_node;
        h_formula_view_name = vname;
        h_formula_view_derv = dn.h_formula_data_derv;
        h_formula_view_imm = dn.h_formula_data_imm;
        h_formula_view_perm = dn.h_formula_data_perm;
        h_formula_view_arguments = args;
        h_formula_view_annot_arg = args_annot;
        h_formula_view_args_orig = args_orig;
        h_formula_view_modes = [];
        h_formula_view_coercible = false;
        h_formula_view_origins = dn.h_formula_data_origins;
        h_formula_view_original = false;
        h_formula_view_lhs_case = false;
        h_formula_view_unfold_num = 0;
        h_formula_view_remaining_branches = dn.h_formula_data_remaining_branches;
        h_formula_view_pruning_conditions = dn.h_formula_data_pruning_conditions;
        h_formula_view_label = None;
        h_formula_view_pos = dn. h_formula_data_pos;
    }
  in
  let rec oa_node2view hf=
    match hf with
      | DataNode dn -> begin
            try
              let oa_vname, dname = List.find (fun (_, dname1) ->
                  String.compare dname1 dn.h_formula_data_name = 0
              ) oamap_view_datas in
              ViewNode (dn2vn dn oa_vname)
            with _ -> hf
        end
      | _ -> hf
  in
  (*****************************)
  let dns, hvs,_ = get_hp_rel_formula f in
  let seg_dns = List.filter (fun dn -> List.exists (fun vn ->
      String.compare dn.h_formula_data_name vn == 0
  ) seg_datas) dns in
  let nemps = List.fold_left (fun r dn ->
      r@(List.map (fun a -> (dn.h_formula_data_node,a))
          (List.filter (fun (CP.SpecVar (t,id,_)) ->
              match t with
                | Named _ -> begin try
                    (String.compare (String.sub id 0 5) "Anon_" != 0)
                  with _ -> true
          end
                | _ -> false
          ) dn.h_formula_data_arguments))
  ) [] seg_dns in
  let is_inconst = check_inconsistent dns in
  (*********abstract x!=y ******)
  (* let view_ptrs = List.fold_left (fun r vn -> *)
  (*     r@(vn.h_formula_view_node::vn.h_formula_view_arguments) *)
  (* ) [] hvs in *)
  (* let nemps1 = List.filter (fun (sv1,sv2) -> CP.mem_svl sv1 view_ptrs && *)
  (*     CP.mem_svl sv2 view_ptrs *)
  (* ) nemps in *)
  let ps = List.map (fun (sv1, sv2) -> CP.mkPtrNeqEqn sv1 sv2 no_pos) nemps in
  let oa_p = (CP.conj_of_list ps no_pos) in
  let oa_f = formula_trans_heap_node oa_node2view f in
  let oa_f2 = mkAnd_pure oa_f (MCP.mix_of_pure oa_p) no_pos in
  oa_f2,is_inconst,nemps, oa_p

let xpure_graph_pto prog seg_datas oamap_data_views f=
  let pr1 = !print_formula in
  let pr2 = pr_list (pr_pair !CP.print_sv !CP.print_sv) in
  Debug.no_3 "xpure_graph_pto" (pr_list pr_id) (pr_list (pr_pair pr_id pr_id)) pr1
      (pr_quad pr1 string_of_bool pr2 !CP.print_formula)
      (fun _ _ _ -> xpure_graph_pto_x prog seg_datas oamap_data_views f) seg_datas oamap_data_views f



(* todo:
  x::pto<p> --> x::vname<p>: if
  - data_name of vname is pto
  - p is segment

Assumption: work with the first segment parameter
*)
let oa_node2view_x prog f vname=
  f

let oa_node2view prog f vname=
  let pr1 = !print_formula in
  Debug.no_2 "oa_node2view" pr1 pr_id pr1
      (fun _ _ -> oa_node2view_x prog f vname) f vname

(*
  rename clash argument of views
*)
let norm_rename_clash_args_node_x init_args0 f0=
  (******************************************************)
  let mkPtrEqns sst=
    let ps = List.map  (fun (sv1, sv2) -> CP.mkPtrEqn sv1 sv2 no_pos) sst in
     Mcpure.mix_of_pure (CP.conj_of_list ps no_pos)
  in
  let rec hn_rename args quans hf=
    match hf with
      | Star s ->
            let nh1, args1, quans1,sst1 =  hn_rename args [] s.h_formula_star_h1 in
            let nh2, args2, quans2,sst2 =  hn_rename args1 [] s.h_formula_star_h2 in
            (Star {s with h_formula_star_h1 = nh1;
                h_formula_star_h2 = nh2
            }, args2, quans@quans1@quans2,sst1@sst2)
      | ViewNode vn ->
             let _ = Debug.ninfo_hprint (add_str "args" !CP.print_svl) args no_pos in
             let _ = Debug.ninfo_hprint (add_str "vn.h_formula_view_arguments args" !CP.print_svl) vn.h_formula_view_arguments no_pos in
             let inter = CP.intersect_svl vn.h_formula_view_arguments args in
             let ident_ptrs = vn.h_formula_view_node::vn.h_formula_view_arguments in
             if inter = [] then
               (hf, args@ident_ptrs (* vn.h_formula_view_arguments *),quans,[])
             else
               let fr_inter = CP.fresh_spec_vars inter in
               let sst = List.combine inter fr_inter in
               let vn1 = {vn with h_formula_view_arguments = CP.subst_var_list sst
                       vn.h_formula_view_arguments} in
               (ViewNode vn1, args@(CP.diff_svl ident_ptrs (* vn.h_formula_view_arguments *) args), quans@fr_inter,sst)
      | DataNode dn ->
            let _ = Debug.ninfo_hprint (add_str "args" !CP.print_svl) args no_pos in
            let _ = Debug.ninfo_hprint (add_str "dn.h_formula_data_arguments args" !CP.print_svl) dn.h_formula_data_arguments no_pos in
            let inter = CP.intersect_svl dn.h_formula_data_arguments args in
            let ident_ptrs = dn.h_formula_data_node::dn.h_formula_data_arguments in
            if inter = [] then
              (hf, args@ident_ptrs (* dn.h_formula_data_arguments *),quans,[])
            else
              let fr_inter = CP.fresh_spec_vars inter in
              let _ = Debug.ninfo_hprint (add_str "fr_inter" !CP.print_svl) fr_inter no_pos in
              let sst = List.combine inter fr_inter in
              let dn1 = {dn with h_formula_data_arguments = CP.subst_var_list sst
              dn.h_formula_data_arguments} in
              (DataNode dn1, args@(CP.diff_svl ident_ptrs (* dn.h_formula_data_arguments *) args), quans@fr_inter,sst)
      | _ -> (hf,args,quans,[])
  in
  let rec rename_helper init_args f=
    match f with
      | Base fb ->
            let nh,args,quans,sst =  hn_rename init_args [] fb.formula_base_heap in
            let bare = Base {fb with formula_base_heap = nh} in
            (add_quantifiers quans (mkAnd_pure bare (mkPtrEqns sst) no_pos),args)
      | Exists _ ->
            let quans,bare = split_quantifiers f in
            let nf,args = rename_helper init_args bare in
            (add_quantifiers quans nf, args)
      | Or orf ->
            let nf1,args1= (rename_helper init_args orf.formula_or_f1) in
            let nf2,args2 = (rename_helper init_args orf.formula_or_f2) in
            (Or {orf with formula_or_f1 = nf1;
                formula_or_f2 = nf2;
            }, args1@args2)
  in
  (******************************************************)
  rename_helper init_args0 f0

 let norm_rename_clash_args_node init_quans f=
   let pr1 = !print_formula in
   Debug.no_2 "norm_rename_clash_args_node" !CP.print_svl pr1 (pr_pair pr1 !CP.print_svl)
       (fun _ _ -> norm_rename_clash_args_node_x init_quans f) init_quans f


(*******************************************************************)
(************************END GRAPH*****************************************)
(*******************************************************************)


 let find_view_match hf rhs_node=
   let elim_vn vn hf=
     match hf with
       | ViewNode vn1 -> if CP.eq_spec_var vn.h_formula_view_node vn1.h_formula_view_node && CP.diff_svl  vn.h_formula_view_arguments vn1.h_formula_view_arguments = [] then
           HEmp
         else hf
       | _ -> hf
   in
   match rhs_node with
     | ViewNode vn ->
           let vns = get_views (formula_of_heap hf no_pos) in
           let sel_vns = List.filter (fun vn1 -> CP.eq_spec_var vn.h_formula_view_node vn1.h_formula_view_node) vns in
           if sel_vns = [] then raise Not_found else
             let vl = List.hd sel_vns in
             let lhs_rest = heap_trans_heap_node (elim_vn vl) hf in
             (vl, vn, lhs_rest)
     | _ -> raise Not_found


 let transform_bexpr_x f0=
   let rec recf f=match f with
     | Base fb ->
           Base {fb with formula_base_pure =  MCP.mix_of_pure (CP.transform_bexpr (MCP.pure_of_mix fb.formula_base_pure))}
     | Exists fe ->
           Exists {fe with formula_exists_pure = MCP.mix_of_pure (CP.transform_bexpr (MCP.pure_of_mix fe.formula_exists_pure))}
     | Or orf -> Or {orf with formula_or_f1 = recf orf.formula_or_f1;
           formula_or_f2 = recf orf.formula_or_f2}
   in
   recf f0

let transform_bexpr f0=
  let pr1 = !print_formula in
  Debug.no_1 "CF.transform_bexpr" pr1 pr1
      (fun _ -> transform_bexpr_x f0) f0
