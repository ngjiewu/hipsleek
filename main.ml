(******************************************)
(* command line processing                *)
(******************************************)

let parse_only = ref false

let to_java = ref false

let comp_pred = ref false

let rtc = ref false

let pred_to_compile = ref ([] : string list)

let set_pred arg = 
  comp_pred := true;
  pred_to_compile := arg :: !pred_to_compile


let usage_msg = Sys.argv.(0) ^ " [options] <source files>"

let set_source_file arg = 
  Globals.source_files := arg :: !Globals.source_files

let set_proc_verified arg =
  let procs = Util.split_by "," arg in
	Globals.procs_verified := procs @ !Globals.procs_verified

let process_cmd_line () = Arg.parse [
	("--no-omega-simpl", Arg.Clear Globals.omega_simpl,
	"Do not use Omega to simplify the arithmetic constraints when using other solver");
	("--simpl-pure-part", Arg.Set Globals.simplify_pure,
	"Simplify the pure part of the formulas");
	("--combined-lemma-heuristic", Arg.Set Globals.lemma_heuristic,
	"Use the combined coerce&match + history heuristic for lemma application");
	("--move-exist-to-LHS", Arg.Set Globals.move_exist_to_LHS,
	"Move instantiation (containing existential vars) to the LHS at the end of the folding process");
	("--max-renaming", Arg.Set Globals.max_renaming,
	"Always rename the bound variables");
	("--no-anon-exist", Arg.Clear Globals.anon_exist,
	"Disallow anonymous variables in the precondition to be existential");
	("--LHS-wrap-exist", Arg.Set Globals.wrap_exist,
	"Existentially quantify the fresh vars in the residue after applying ENT-LHS-EX");
  ("-noee", Arg.Clear Tpdispatcher.elim_exists_flag,
   "No eleminate existential quantifiers before calling TP.");
  ("-nofilter", Arg.Clear Tpdispatcher.filtering_flag,
   "No assumption filtering.");
  ("-cp", Arg.String set_pred,
   "Compile specified predicate to Java.");
  ("-rtc", Arg.Set rtc,
   "Compile to Java with runtime checks.");
  ("-nopp", Arg.String Rtc.set_nopp,
   "-nopp caller:callee: do not check callee's pre/post in caller");
  ("-nofield", Arg.String Rtc.set_nofield,
   "-nofield proc: do not perform field check in proc");
  ("--verify-callees", Arg.Set Globals.verify_callees,
   "Verify callees of the specified procedures");
  ("--check-coercions", Arg.Set Globals.check_coercions,
   "Check coercion validity");
  ("-dd", Arg.Set Debug.devel_debug_on,
   "Turn on devel_debug");
  ("-gist", Arg.Set Globals.show_gist,
   "Show gist when implication fails");
  ("--hull-pre-inv", Arg.Set Globals.hull_pre_inv,
   "Hull precondition invariant at call sites");
  ("-inline", Arg.String Inliner.set_inlined,
   "Procedures to be inlined");
  (*("-java", Arg.Set to_java,
   "Convert source code to Java");*)
  ("--sat-timeout", Arg.Set_float Globals.sat_timeout,
   "Timeout for sat checking");
  ("--imply-timeout", Arg.Set_float Globals.imply_timeout,
   "Timeout for imply checking");
  ("--log-proof", Arg.String Prooftracer.set_proof_file,
   "Log (failed) proof to file");
  ("--trace-all", Arg.Set Globals.trace_all,
   "Trace all proof paths");
  ("--log-cvcl", Arg.String Cvclite.set_log_file,
   "Log all CVC Lite formula to specified log file");
   ("--log-cvc3", Arg.String Cvc3.set_log_file,
   "Log all CVC3 formula to specified log file");
  ("--log-omega", Arg.Set Omega.log_all_flag,
   "Log all formulae sent to Omega Calculator in file allinput.oc");
  ("--log-isabelle", Arg.Set Isabelle.log_all_flag,
   "Log all formulae sent to Isabelle in file allinput.thy");
  ("--log-coq", Arg.Set Coq.log_all_flag,
   "Log all formulae sent to Coq in file allinput.v");
  ("--log-mona", Arg.Set Mona.log_all_flag,
   "Log all formulae sent to Mona in file allinput.mona");
  ("--log-redlog", Arg.Set Redlog.is_log_all,
    "Log all formulae sent to Reduce/Redlog in file allinput.rl");
  ("--use-isabelle-bag", Arg.Set Isabelle.bag_flag,
   "Use the bag theory from Isabelle, instead of the set theory");
  ("--no-coercion", Arg.Clear Globals.use_coercion,
   "Turn off coercion mechanism");
  ("--no-exists-elim", Arg.Clear Globals.elim_exists,
   "Turn off existential quantifier elimination during type-checking");
  ("--no-diff", Arg.Set Solver.no_diff,
   "Drop disequalities generated from the separating conjunction");
  ("--no-set", Arg.Clear Globals.use_set,
   "Turn off set-of-states search");
  ("--unsat-elim", Arg.Set Globals.elim_unsat,
   "Turn on unsatisfiable formulae elimination during type-checking");
  ("-nxpure", Arg.Set_int Globals.n_xpure,
   "Number of unfolding using XPure");
  ("-p", Arg.String set_proc_verified, 
   "Procedure to be verified. If none specified, all are verified.");
  ("-parse", Arg.Set parse_only,
   "Parse only");
  ("-print", Arg.Set Globals.print_proc,
   "Print procedures being checked");
  ("--print-iparams", Arg.Set Globals.print_mvars,
   "Print input parameters of predicates");
  ("--print-x-inv", Arg.Set Globals.print_x_inv,
   "Print computed view invariants");
  ("-stop", Arg.Clear Globals.check_all,
   "Stop checking on erroneous procedure");
  ("--build-image", Arg.Symbol (["true"; "false"], Isabelle.building_image),
   "Build the image theory in Isabelle - default false");
   ("-tp", Arg.Symbol (["cvcl"; "cvc3"; "omega"; "co"; "isabelle"; "coq"; "mona"; "om";
   "oi"; "set"; "cm"; "redlog"; "rm"; "prm" ], Tpdispatcher.set_tp),
   "Choose theorem prover:\n\tcvcl: CVC Lite\n\tcvc3: CVC3\n\tomega: Omega Calculator (default)\n\tco: CVC Lite then Omega\n\tisabelle: Isabelle\n\tcoq: Coq\n\tmona: Mona\n\tom: Omega and Mona\n\toi: Omega and Isabelle\n\tset: Use MONA in set mode.\n\tcm: CVC Lite then MONA.");
  ("--use-field", Arg.Set Globals.use_field,
   "Use field construct instead of bind");
  ("--use-large-bind", Arg.Set Globals.large_bind,
   "Use large bind construct, where the bound variable may be changed in the body of bind");
  ("-v", Arg.Set Debug.debug_on, "Verbose");
  ("--pipe", Arg.Unit Tpdispatcher.Netprover.set_use_pipe, "use external prover via pipe");
  ("--dsocket", Arg.Unit (fun () -> Tpdispatcher.Netprover.set_use_socket "loris-7:8888"), "<host:port>: use external prover via loris-7:8888");
  ("--socket", Arg.String Tpdispatcher.Netprover.set_use_socket, "<host:port>: use external prover via socket");
  ("--prover", Arg.String Tpdispatcher.set_tp, "<p,q,..> comma-separated list of provers to try in parallel");
  ("--enable-sat-stat", Arg.Set Globals.enable_sat_statistics, "enable sat statistics");
  ("--epi", Arg.Set Globals.profiling, "enable profiling statistics");
  ("--sbc", Arg.Set Globals.enable_syn_base_case, "use only syntactic base case detection");
  ("--eci", Arg.Set Globals.enable_case_inference,"enable struct formula inference");
  ("--dprun", Arg.Clear Globals.allow_pruning,"disable predicate pruning");
  ("--duslice", Arg.Clear Globals.allow_umemo_slicing,"disable unsat slicing based on relevand memoized constraints");
  (*("--dislice", Arg.Clear Globals.allow_imemo_slicing,"disable imply slicing based on relevand memoized constraints");
  ("--eagressu", Arg.Set Globals.agressive_unsat,"enable agressive unsat slicing");
  ("--eagressi", Arg.Set Globals.agressive_imply,"enable agressive imply slicing");*)
  ("--pcp", Arg.Set Globals.print_core,"print core representation");
  ("--pgbv", Arg.Set Globals.pass_global_by_value, "pass read global variables by value");
  ("--pip", Arg.Set Globals.print_input,"print input representation");
  ("--sqt", Arg.Set Globals.seq_to_try,"translate seq to try");
   ("--slk-err", Arg.Set Globals.print_err_sleek,"print sleek errors");
  ("--web", Arg.String (fun s -> (Tpdispatcher.Netprover.set_use_socket_for_web s); Tpdispatcher.webserver := true; Typechecker.webserver := true; Paralib1v2.webs := true; Paralib1.webs := true) , "<host:port>: use external web service via socket");
  ("-para", Arg.Int Typechecker.parallelize, "Use Paralib map_para instead of List.map in typecheker");
  ("--priority",Arg.String Tpdispatcher.Netprover.set_prio_list, "<proc_name1:prio1;proc_name2:prio2;...> To be used along with webserver");
  ("--decrprio",Arg.Set Tpdispatcher.decr_priority , "use a decreasing priority scheme");
  ("--redlog-int-relax", Arg.Set Redlog.integer_relax_mode, "use redlog real q.e to prove intefer formula  *experiment*");
  ("--redlog-ee", Arg.Set Redlog.is_ee, "enable Redlog existential quantifier elimination");
  ("--redlog-presburger", Arg.Set Redlog.is_presburger, "use presburger arithmetic for redlog");
  ("--redlog-timeout", Arg.Set_int Redlog.timeout, "<sec> checking a formula using redlog with a timeout after <sec> seconds");
  ("--redlog-manual", Arg.Set Redlog.manual_mode, " manual config for reduce/redlog");
  ("--dpc", Arg.Clear Globals.enable_prune_cache,"disable prune caching");
  ("--delimrc", Arg.Set Globals.disable_elim_redundant_ctr, "disable redundant constraint elimination in memo pure");
  ("--dcounters", Arg.Clear Globals.enable_counters, "disable counters");
	] set_source_file usage_msg

(******************************************)
(* main function                          *)
(******************************************)

let parse_file_full file_name = 
  let org_in_chnl = open_in file_name in
  let input = Lexing.from_channel org_in_chnl in
    try
    (*let ptime1 = Unix.times () in
	  let t1 = ptime1.Unix.tms_utime +. ptime1.Unix.tms_cutime in
     *)
		print_string "Parsing...\n"; flush stdout;
        let _ = Util.push_time "Parsing" in
    Iparser.file_name := file_name;
		let prog = Iparser.program (Ilexer.tokenizer file_name) input in
		  close_in org_in_chnl;
         let _ = Util.pop_time "Parsing" in
    (*		  let ptime2 = Unix.times () in
		  let t2 = ptime2.Unix.tms_utime +. ptime2.Unix.tms_cutime in
			print_string ("done in " ^ (string_of_float (t2 -. t1)) ^ " second(s)\n"); *)
			prog 
    with
		End_of_file -> exit 0	  

let process_source_full source =
  print_string ("\nProcessing file \"" ^ source ^ "\"\n"); flush stdout;
  let _ = Util.push_time "Preprocessing" in
  let prog = parse_file_full source in
	if !to_java then begin
	  print_string ("Converting to Java..."); flush stdout;
	  let tmp = Filename.chop_extension (Filename.basename source) in
	  let main_class = Util.replace_minus_with_uscore tmp in
	  let java_str = Java.convert_to_java prog main_class in
	  let tmp2 = Util.replace_minus_with_uscore (Filename.chop_extension source) in
	  let jfile = open_out ("output/" ^ tmp2 ^ ".java") in
		output_string jfile java_str;
		close_out jfile;
		print_string (" done.\n"); flush stdout;
		exit 0
	end;
  	if (!parse_only) then 
      let _ = Util.pop_time "Preprocessing" in
      print_string (Iprinter.string_of_program prog)
	else 
      let _ = Tpdispatcher.start_prover () in
	  (* Global variables translating *)
      let _ = Util.push_time "Translating global var" in
   	  let _ = print_string ("Translating global variables to procedure parameters...\n"); flush stdout in
	  let intermediate_prog = Globalvars.trans_global_to_param prog in
	  let intermediate_prog = Iast.label_procs_prog intermediate_prog in
	  let _ = if (!Globals.print_input) then print_string (Iprinter.string_of_program intermediate_prog) else () in
      let _ = Util.pop_time "Translating global var" in
	  (* Global variables translated *)
	  (* let ptime1 = Unix.times () in
	  let t1 = ptime1.Unix.tms_utime +. ptime1.Unix.tms_cutime in *)
      let _ = Util.push_time "Translating to Core" in
	  let _ = print_string ("Translating to core language...\n"); flush stdout in
	  let cprog = Astsimp.trans_prog intermediate_prog in
	  let _ = print_string (" done\n"); flush stdout in
	  let _ = if (!Globals.print_core) then print_string (Cprinter.string_of_program cprog) else () in
	  let _ = 
		if !Globals.verify_callees then begin
		  let tmp = Cast.procs_to_verify cprog !Globals.procs_verified in
			Globals.procs_verified := tmp
		end in
      let _ = Util.pop_time "Translating to Core" in
	  (* let ptime2 = Unix.times () in
	  let t2 = ptime2.Unix.tms_utime +. ptime2.Unix.tms_cutime in
	  let _ = print_string (" done in " ^ (string_of_float (t2 -. t1)) ^ " second(s)\n") in *)
	  let _ =
		if !comp_pred then begin
		  let _ = print_string ("Compiling predicates to Java..."); flush stdout in
		  let compile_one_view vdef = 
			if (!pred_to_compile = ["all"] || List.mem vdef.Cast.view_name !pred_to_compile) then
			  let data_def, pbvars = Predcomp.gen_view cprog vdef in
			  let java_str = Java.java_of_data data_def pbvars in
			  let jfile = open_out (vdef.Cast.view_name ^ ".java") in
				print_string ("\n\tWriting Java file " ^ vdef.Cast.view_name ^ ".java");
				output_string jfile java_str;
				close_out jfile
			else
			  ()
		  in
			ignore (List.map compile_one_view cprog.Cast.prog_view_decls);
			print_string ("\nDone.\n"); flush stdout;
			exit 0
		end 
	  in
	  let _ =
		if !rtc then begin
		  Rtc.compile_prog cprog source;
		  exit 0
		end
	  in
	    let _ = Util.pop_time "Preprocessing" in
		ignore (Typechecker.check_prog cprog);
    (* i.e. stop Reduce/Redlog if it is running. *)
    let _ = Tpdispatcher.finalize () in
		(* Stopping the prover (in case of Coq) *)
		let _ = Tpdispatcher.stop_prover () in
		
		let ptime4 = Unix.times () in
		let t4 = ptime4.Unix.tms_utime +. ptime4.Unix.tms_cutime +. ptime4.Unix.tms_stime +. ptime4.Unix.tms_cstime   in
		print_string ("\n"^(string_of_int (List.length !Globals.false_ctx_line_list))^" false contexts at: ("^
		(List.fold_left (fun a c-> a^" ("^(string_of_int c.Globals.start_pos.Lexing.pos_lnum)^","^
		( string_of_int (c.Globals.start_pos.Lexing.pos_cnum-c.Globals.start_pos.Lexing.pos_bol))^") ") "" !Globals.false_ctx_line_list)^")\n");
		  print_string ("\nTotal verification time: " 
						^ (string_of_float t4) ^ " second(s)\n"
						^ "\tTime spent in main process: " 
						^ (string_of_float (ptime4.Unix.tms_utime+.ptime4.Unix.tms_stime)) ^ " second(s)\n"
						^ "\tTime spent in child processes: " 
						^ (string_of_float (ptime4.Unix.tms_cutime +. ptime4.Unix.tms_cstime)) ^ " second(s)\n")

	  
let main1 () =
  (* Cprinter.fmt_set_margin 40; *)
  (* Cprinter.fmt_string "TEST1.................................."; *)
  (* Cprinter.fmt_cut (); *)
  (* Cprinter.fmt_string "TEST2...............................................................'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''............"; *)
  (* Cprinter.fmt_cut (); *)
  (* Cprinter.fmt_string "TEST3....."; *)
  (*  Cprinter.fmt_cut (); *)
  (* Cprinter.fmt_string "TEST3....."; *)
  (*  Cprinter.fmt_cut (); *)
  (* Cprinter.fmt_string "TEST3....."; *)
  (*    Cprinter.fmt_string "TEST3....."; *)
  (* Cprinter.fmt_string "TEST4..............................."; *)
  (* Cprinter.fmt_cut (); *)
  (* Cprinter.fmt_string "TEST5.................................."; *)
  (* Cprinter.fmt_cut (); *)
  (* Cprinter.fmt_string "TEST6.................................."; *)
  (* Cprinter.fmt_cut (); *)
  (* Cprinter.fmt_string "TEST7.................................."; *)
  (*  Cprinter.fmt_cut (); *)
  process_cmd_line ();
  
  (* i.e. pre-start Reduce/Redlog if it will be used. *)
  let _ = Tpdispatcher.prepare () in
    
    if List.length (!Globals.source_files) = 0 then begin
      (* print_string (Sys.argv.(0) ^ " -help for usage information\n") *)
      Globals.procs_verified := ["f3"];
      Globals.source_files := ["examples/test5.ss"]
    end;
    let _ = Util.push_time "Overall" in
    let _ = List.map process_source_full !Globals.source_files in
    let _ = Util.pop_time "Overall" in
      (* Tpdispatcher.print_stats (); *)
      ()
	  
let _ = 
  main1 ();
  (*let rec check_aux (t1,t2,t3,t4) l = match l with
  | [] -> true
  | (p1,p2,p3,p4)::l1 -> if (p1<=t1 && p2<=t2&& p3<=t3&& p4<=t4) then check_aux (p1,p2,p3,p4) l1
						 else false in
  let check_sorted l = match l with
	  | a::b -> check_aux a b
	  | [] -> true  in
  let _ = print_string ("stack height: "^(string_of_int (List.length !Util.profiling_stack))^"\n") in
  let _ = print_string ("get time length: "^(string_of_int (List.length !Util.time_list))^" "^
  (string_of_bool (check_sorted !Util.time_list))^"\n" ) in*)
  let _ = print_string (Util.string_of_counters ()) in
  let _ = Util.print_profiling_info () in
  ()

  
