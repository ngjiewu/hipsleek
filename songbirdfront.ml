#include "xdebug.cppo"

open Gen.Basic
open VarGen

module SBCast = Libsongbird.Cast
module SBGlobals = Libsongbird.Globals
module SBDebug = Libsongbird.Debug
module CP = Cpure

(* translation of HIP's data structures to Songbird's data structures
   will be done here *)


let translate_loc (location:VarGen.loc) : SBGlobals.pos =
  {
    pos_begin = location.start_pos;
    pos_end = location.end_pos;
  }

let translate_back_pos (pos:SBGlobals.pos) : VarGen.loc =
  let no_pos1 = { Lexing.pos_fname = "";
                  Lexing.pos_lnum = 0;
                  Lexing.pos_bol = 0;
                  Lexing.pos_cnum = 0 } in
  {
    start_pos = pos.SBGlobals.pos_begin;
    mid_pos = no_pos1;
    end_pos = pos.SBGlobals.pos_end;
  }
let translate_type (typ: Globals.typ) : SBGlobals.typ =
  match typ with
  | Int -> TInt
  | Bool -> TInt
  | UNK -> TUnk
  | Void -> TVoid
  | _ -> Gen.Basic.report_error VarGen.no_pos "translate_type: this type is not handled"

let translate_back_type (typ) = match typ with
  | SBGlobals.TInt -> Globals.Int
  | SBGlobals.TBool -> Globals.Bool
  | SBGlobals.TUnk -> Globals.UNK
  | SBGlobals.TVoid -> Globals.Void
  | _ -> Gen.Basic.report_error VarGen.no_pos "translate_back_type: this type is not handled"


let translate_var (var: CP.spec_var): SBGlobals.var =
  match var with
  | SpecVar (typ, ident, primed) -> (ident, translate_type typ)

let translate_back_var (var : SBGlobals.var) =
  let (str, typ) = var in
  CP.SpecVar (translate_back_type typ, str, VarGen.Unprimed)

let rec translate_exp (exp: CP.exp) =
  match exp with
  | CP.Null loc -> (SBCast.Null (translate_loc loc), [])
  | CP.Var (var, loc) -> (SBCast.Var (translate_var var, translate_loc loc),[])
  | CP.IConst (num, loc) -> (SBCast.IConst (num, translate_loc loc),[])
  | CP.Add (exp1, exp2, loc) ->
        let (t_exp1, l1) = translate_exp exp1 in
        let (t_exp2, l2) = translate_exp exp2 in
        (SBCast.BinOp (Add, t_exp1, t_exp2, translate_loc loc), l1@l2)
  | CP.Subtract (exp1, exp2, loc) ->
        let (t_exp1, l1) = translate_exp exp1 in
        let (t_exp2, l2) = translate_exp exp2 in
        (SBCast.BinOp (Sub, t_exp1, t_exp2, translate_loc loc), l1@l2)
  | CP.Mult (exp1, exp2, loc) ->
        let (t_exp1, l1) = translate_exp exp1 in
        let (t_exp2, l2) = translate_exp exp2 in
        (SBCast.BinOp (Mul, t_exp1, t_exp2, translate_loc loc), l1@l2)
  | CP.Div (exp1, exp2, loc) ->
        let (t_exp1, l1) = translate_exp exp1 in
        let (t_exp2, l2) = translate_exp exp2 in
        (SBCast.BinOp (Div, t_exp1, t_exp2, translate_loc loc), l1@l2)
  | CP.Template templ ->
    let fun_name = CP.name_of_sv templ.templ_id in
    let args = templ.templ_args |> List.map translate_exp |> List.map fst in
    ((SBCast.mk_func (SBCast.FuncName fun_name) args), [templ])
  | _ -> Gen.Basic.report_error VarGen.no_pos "this exp is not handled"

let rec translate_back_exp (exp: SBCast.exp) = match exp with
  | SBCast.Null pos -> CP.Null (translate_back_pos pos)
  | SBCast.Var (var, pos) -> CP.Var (translate_back_var var, translate_back_pos
                                      pos)
  | SBCast.IConst (num, pos) -> CP.IConst (num, translate_back_pos pos)
  | SBCast.BinOp (bin_op, exp1, exp2, pos) ->
    begin
      match bin_op with
      | SBCast.Add -> CP.Add (translate_back_exp exp1, translate_back_exp exp2,
               translate_back_pos pos)
      | SBCast.Sub -> CP.Subtract (translate_back_exp exp1, translate_back_exp exp2,
               translate_back_pos pos)
      | SBCast.Mul -> CP.Mult (translate_back_exp exp1, translate_back_exp exp2,
               translate_back_pos pos)
      | SBCast.Div -> CP.Div (translate_back_exp exp1, translate_back_exp exp2,
               translate_back_pos pos)
    end
  | SBCast.LTerm (lterm, pos) ->
    let n_exp = SBCast.convert_lterm_to_exp lterm in
    translate_back_exp n_exp
  | SBCast.Func _ -> Gen.Basic.report_error VarGen.no_pos
           ("translate_back_exp:" ^ (SBCast.pr_exp exp) ^ " this Func is not handled")

let translate_pf (pure_f: CP.formula)  =
  match pure_f with
  | CP.BForm (b_formula, _) ->
    let (p_formula, _) = b_formula in
    begin
    match p_formula with
      | Eq (exp1, exp2, loc) ->
        let (sb_exp1, l1) = translate_exp exp1 in
        let (sb_exp2, l2) = translate_exp exp2 in
        let sb_loc = translate_loc loc in
         (SBCast.BinRel (Eq, sb_exp1, sb_exp2, sb_loc), l1@l2)
     | _ -> Gen.Basic.report_error VarGen.no_pos "this p_formula is not handled"
  end

  | _ -> Gen.Basic.report_error VarGen.no_pos "this pure formula not handled"

let translate_back_pf (pf : SBCast.pure_form) = match pf with
  | SBCast.BConst (b, pos)
    -> CP.BForm ((CP.BConst (b, translate_back_pos pos), None), None)
  | SBCast.BinRel (br, exp1, exp2, pos) ->
    let exp1_hip = translate_back_exp exp1 in
    let exp2_hip = translate_back_exp exp2 in
    let loc = translate_back_pos pos in
    begin
      match br with
      | SBCast.Lt -> CP.BForm((CP.Lt (exp1_hip, exp2_hip, loc), None), None)
      | SBCast.Le -> CP.BForm((CP.Lte (exp1_hip, exp2_hip, loc), None), None)
      | SBCast.Gt -> CP.BForm((CP.Gt (exp1_hip, exp2_hip, loc), None), None)
      | SBCast.Ge -> CP.BForm((CP.Gte (exp1_hip, exp2_hip, loc), None), None)
      | SBCast.Eq -> CP.BForm((CP.Eq (exp1_hip, exp2_hip, loc), None), None)
      | SBCast.Ne -> CP.BForm((CP.Neq (exp1_hip, exp2_hip, loc), None), None)
    end
  | _ -> Gen.Basic.report_error VarGen.no_pos "this type of lhs not handled"


(* translate lhs of the entalment e.g. res = x + 1 to template form: res = f(x)*)
(* let translate_lhs_to_fdefn (lhs: SBCast.pure_form) (\* : SBCast.pure_form *\) =
 *   match lhs with
 *   | BinRel (rel, exp1, exp2, pos) ->
 *     let exp2_vars = SBCast.fv_exp exp2 in
 *       let exp2_args = List.map (SBCast.mk_exp_var) exp2_vars in
 *       let func_exp = SBCast.mk_func (SBCast.FuncName "f") exp2_args in
 *       (Libsongbird.Cast.BinRel (rel, exp1, func_exp, pos), exp2_vars)
 *   | _ -> Gen.Basic.report_error VarGen.no_pos "this type of lhs not handled" *)


(* Input: lhs and rhs
   Create template for lhs
   Adding template f(args) = ?
   Output: Input for songbird infer_unknown_functions
*)
let create_templ_prog prog (lhs: SBCast.pure_form) (rhs: SBCast.pure_form) templ
  =
  let program = SBCast.mk_program "hip_input" in
  let fun_name = CP.name_of_sv templ.CP.templ_id in
  let args = templ.templ_args |> List.map CP.get_var |> List.map translate_var in
  let f_defn = SBCast.mk_func_defn_unknown fun_name args in
  let ifr_typ = SBGlobals.IfrStrong in
  let entail = SBCast.mk_pure_entail lhs rhs in
  let infer_func = {
    SBCast.ifr_typ = ifr_typ;
    SBCast.ifr_rels = [entail]
  }
  in
  let nprog = {program with
             prog_funcs = [f_defn];
             prog_commands = [SBCast.InferFuncs infer_func]
            }
  in
  let () = SBDebug.nhprint "prog: " SBCast.pr_program nprog in
  let () = SBDebug.nhprint "pure entails: " SBCast.pr_pent entail in
  let (ifds, inferred_prog) = Libsongbird.Prover.infer_unknown_functions ifr_typ nprog [entail] in
  let () = SBDebug.nhprint " ==> Result: \n" Libsongbird.Proof.pr_ifds
      ifds in
  (* let func_defns = ifds |> List.map (fun ifd -> Libsongbird.Proof.get_ifd_fdefns
   *                                       ifd) |> List.concat in
   * let lhs_repaired = Libsongbird.Cast.unfold_func_pf func_defns lhs in *)
  let () = SBDebug.nhprint "inferred prog: " SBCast.pr_program inferred_prog in
  let lhs_repaired = SBCast.unfold_func_pf inferred_prog.prog_funcs lhs in
  lhs_repaired

let get_repair_candidate prog (lhs: CP.formula) (rhs: CP.formula) =
  let (sb_lhs, tmpl_list) = translate_pf lhs in
  let (sb_rhs, _) = translate_pf rhs in
  let templ = List.hd tmpl_list in
  let repaired_lhs = create_templ_prog prog sb_lhs sb_rhs templ in
  let () = SBDebug.nhprint "repaired pf: " SBCast.pr_pf repaired_lhs in
  translate_back_pf repaired_lhs
