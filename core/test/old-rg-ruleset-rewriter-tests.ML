local
structure Test_RG_BangGraphSubst : GRAPH_SUBST = BangGraphSubst(Test_RG_BGMatchState);
structure Test_RG_RulesetRewriter : RULESET_REWRITER = RulesetRewriter(
  structure Ruleset = Test_RG_Ruleset;
  structure MatchSearch = Test_RG_GreedyMatcher;
  structure GraphSubst = Test_RG_BangGraphSubst;
);
open Test_RG_MkG;
structure Rule = Test_RG_Rule;
structure Ruleset = Test_RG_Ruleset;
structure IO = Test_IO_Interface_v2;
structure RulesetRewriter = Test_RG_RulesetRewriter;
structure Ruleset = Test_RG_Ruleset;
structure GraphSubst = Test_RG_BangGraphSubst;
structure MatchSearch = Test_RG_GreedyMatcher;
val ruleset = "../../test/rulesets/basic_v2.rules" 
              |> XMLReader.read_from_file
              |> IO.Input.Ruleset.input;

val isom_rule = Ruleset.get_rule ruleset (R.mk "isometry_red");
val x_abelian1_rule = Ruleset.get_rule ruleset (R.mk "x_abelian1");

fun list_of_rule_matches r g = 
    let val (r', matches) = RulesetRewriter.rule_matches r g;
    in (r', Seq.list_of matches) end;

in

val _ = Testing.test "rule2: !match(isom_rule, X - X - Z)" (fn () => let
  (* Example of applications of rule that does not match *)
  val g = G.empty;
  val (n1, g) = g |> G.add_vertex (mkX zero_angle);
  val (n2, g) = g |> G.add_vertex (mkX zero_angle);
  val (n3, g) = g |> G.add_vertex (mkZ zero_angle);
  val (_,  g) = g |> G.add_edge undir_edge n1 n3;
  val (_,  g) = g |> G.add_edge undir_edge n2 n3;
  val _ = G.print g;
  val (_, []) = list_of_rule_matches isom_rule g;
  in writeln "Ex2" end) ();


val _ = Testing.test "rule3: [g1,g2,g3,g4] = subst(isom_lhs, isom_lhs)" (fn () => let
  (* test rewriting isometry lhs with isometry rule *)
  val g = G.empty;
  val (b1, g) = g |> G.add_vertex bvert;
  val (n1, g) = g |> G.add_vertex (mkX zero_angle);
  val (n2, g) = g |> G.add_vertex (mkX zero_angle);
  val (b2, g) = g |> G.add_vertex bvert;
  val (_,  g) = g |> G.add_edge undir_edge b1 n1;
  val (_,  g) = g |> G.add_edge undir_edge n1 n2;
  val (_,  g) = g |> G.add_edge undir_edge n1 n2;
  val (_,  g) = g |> G.add_edge undir_edge n2 b2;
  val _ = G.print g;

  val (r',[m1,m2,m3,m4]) = list_of_rule_matches isom_rule g;
  val _ = Rule.print r';
  val _ = RulesetRewriter.print_match m1;
  val inst_isom_rule = RulesetRewriter.instantiate_rule m1 r';
  val _ = Rule.print inst_isom_rule;
  val _ = RulesetRewriter.rewrite r' m1;
  val _ = RulesetRewriter.rewrite r' m2;
  val _ = RulesetRewriter.rewrite r' m3;
  val _ = RulesetRewriter.rewrite r' m4;
  in writeln "success" end) ();

val _ = Testing.test "rule4: rewriting bialgebra (self-matches)" (fn () => let
  val r = Ruleset.get_rule ruleset (R.mk "bialgebra1");
  val g = Rule.get_lhs r;
  val (r',[m1,m2,m3,m4]) = list_of_rule_matches r g;
  val _ = Rule.print r';
  val _ = RulesetRewriter.print_match m1;
  val inst_isom_rule = RulesetRewriter.instantiate_rule m1 r';
  val _ = Rule.print inst_isom_rule;
  val _ = RulesetRewriter.rewrite r' m1;
  val _ = RulesetRewriter.rewrite r' m2;
  val _ = RulesetRewriter.rewrite r' m3;
  val _ = RulesetRewriter.rewrite r' m4;
  in writeln "success" end) ();  
  

  (* Self-Loop, we create two vertices with self-loops and try to rewrite the
   * whole graph. *)
  val _ = Testing.test "rule5: rewriting x_abelian1 (loop)" (fn () => let
  val g = G.empty;
  val (n1, g) = g |> G.add_vertex (mkX zero_angle);
  val (n2, g) = g |> G.add_vertex (mkX zero_angle);
  val (_,  g) = g |> G.add_edge undir_edge n1 n1;
  val (_,  g) = g |> G.add_edge undir_edge n2 n2;
  val _ = G.print g;

  val (r', m1) = list_of_rule_matches x_abelian1_rule g;
  val _ = Rule.print r';
  val _ = RulesetRewriter.print_match (hd m1);
  val (_,g) = RulesetRewriter.rewrite r' (hd m1);
  val (r', m1) = list_of_rule_matches x_abelian1_rule g;
  val (_,g) = RulesetRewriter.rewrite r' (hd m1);
  val _ = G.print g;

  in writeln "success" end) ();  


val _ = Testing.test "rule6: X(a+b)- => X(a)-X(b)-, matching X(c)-Z(b): renaming of internal variables prior to rewriting." (fn () => let
  (* lhs *)
  val lhs = let val g = G.empty;
      val (b1, g) = g |> G.add_vertex bvert;
      val (x1, g) = g |> G.add_vertex (mkX (parse_angle "a + b"));
      val (_,  g) = g |> G.add_edge undir_edge x1 b1;
  in g end;
  val _ = G.print lhs;
  (* rhs *)
  val rhs = let val g = G.empty;
      val (b1, g) = g |> G.add_vertex bvert;
      val (x1, g) = g |> G.add_vertex (mkX (parse_angle "a"));
      val (x2, g) = g |> G.add_vertex (mkX (parse_angle "b"));
      val (_,  g) = g |> G.add_edge undir_edge x1 x2;
      val (_,  g) = g |> G.add_edge undir_edge x2 b1;
  in g end;
  val _ = G.print rhs;
  val rule = Rule.mk (lhs,rhs);
  (* tgt graph *)
  val tgt = let val g = G.empty;
      val (x1, g) = g |> G.add_vertex (mkX (parse_angle "c"));
      val (x2, g) = g |> G.add_vertex (mkZ (parse_angle "b"));
      val (_,  g) = g |> G.add_vertex bvert;
      val (_,  g) = g |> G.add_edge undir_edge x1 x2;
  in g end
  
  val (rule', _) = list_of_rule_matches rule tgt;
  val _ = Rule.print rule';
  
  val rule_xnames = Rule.get_xnames rule'; 
  val _ = Pretty.writeln (Pretty.str "XNames in rule: ");
  val _ = X.NSet.print rule_xnames;
  
  val SOME vname = (* FIXME: brittle: hardcoded right choice of fresh name *)
                    (X.mk "d") 
                    |> G.Param.dep_vnames_of_xname 
                        (Rule.get_lhs rule' |> G.get_param)
                    |> V.NSet.tryget_singleton;
  
  val d = G.get_vertex_data (Rule.get_lhs rule') vname;
  val _ = G.Param.of_vertex d;
  
  val false = X.NSet.contains rule_xnames (X.mk "b");
  val true = X.NSet.contains rule_xnames (X.mk "a");
  in writeln "success" end) ();


val _ = Testing.test "rule7: isom_rule rewrites subgraph" (fn () => let
  (* Example of applications of rule that does not match *)
  val g = G.empty;
  val (x1, g) = g |> G.add_vertex (mkX zero_angle);
  val (x2, g) = g |> G.add_vertex (mkX zero_angle);
  val (z1, g) = g |> G.add_vertex (mkZ zero_angle);
  val (z2, g) = g |> G.add_vertex (mkZ zero_angle);
  val (_,  g) = g |> G.add_edge undir_edge z1 x1;
  val (_,  g) = g |> G.add_edge undir_edge x1 x2;
  val (_,  g) = g |> G.add_edge undir_edge x1 x2;
  val (_,  g) = g |> G.add_edge undir_edge x2 z2;
  val _ = G.print g;
  val verts = V.NSet.single x1;
  val rseq = RulesetRewriter.applicable_rules ruleset
      (RulesetRewriter.rule_matches_within verts) 
      (R.NSet.single (R.mk "isometry_red")) g;
  val _ = Seq.list_of rseq;
  in writeln "success" end) ();


  val Ba = B.mk "Ba"
  
  val Va = V.mk "Va"
  val Vb = V.mk "Vb"
  val Vc = V.mk "Vc"
  val Vd = V.mk "Vd"
  val Vf = V.mk "Vf"
  
  val Vx = V.mk "Vx"
  val Vy = V.mk "Vy"

(* lhs *)
  
  
  val lhs = G.empty
    |> G.add_named_vertex Va bvert
    |> G.add_named_vertex Vc (mkZ zero_angle)
    |> G.add_named_bbox Ba
    |> G.doadd_to_bbox Ba (V.NSet.of_list [Va])
    |> G.doadd_edge dir_edge Vc Va
  
  val _ = Pretty.writeln (Pretty.str "interior node bbox rule")
  (*val _ = G.print lhs;*)
  (* rhs *)
  val rhs = G.empty
    |> G.add_named_vertex Va bvert
    |> G.add_named_vertex Vf (mkX zero_angle)
    |> G.add_named_vertex Vd (mkH)
    |> G.add_named_bbox Ba
    |> G.doadd_to_bbox Ba (V.NSet.of_list [Va,Vd])
    |> G.doadd_edge dir_edge Vf Vd
    |> G.doadd_edge dir_edge Vd Va
    
  (*val rhs = G.empty
    |> G.add_named_vertex Va bvert
    |> G.add_named_vertex Vf (mkX zero_angle)
    |> G.add_named_vertex Vd (mkH)
    |> G.add_named_bbox Ba
    |> G.doadd_to_bbox Ba (V.NSet.of_list [Va,Vd])
    |> G.doadd_edge dir_edge Vf Vd
    |> G.doadd_edge dir_edge Vd Va*)
  
  (*val _ = G.print rhs;*)
  val rule = Rule.mk (lhs,rhs);
  
  val _ = Pretty.writeln (Pretty.str "*** rule (before freshening):")
  val _ = Rule.print rule;
  
  (* tgt graph *)
  val tgt = G.empty
    |> G.add_named_vertex Va bvert
    |> G.add_named_vertex Vb (mkZ zero_angle)
    |> G.doadd_edge dir_edge Vb Va

  val _ = Testing.test "rule with interior node in bbox on RHS" (fn () => let
  val (r', m1) = list_of_rule_matches rule tgt;
  
  val _ = Pretty.writeln (Pretty.str "*** rule (after freshening):")
  val _ = Rule.print r';
  
  val _ = Pretty.writeln (Pretty.str "*** match state:")
  val match = hd m1
  val _ = RulesetRewriter.print_match match
  val rhs' = (MatchSearch.BGMatchState.replay_pat_bbox_ops match (Rule.get_rhs r'))
  
  (*exception die_exp of unit
  val _ = raise die_exp ()*)
  (*val (_,g) = RulesetRewriter.rewrite r' (hd m1);
  val _ = G.print g;*)

  in writeln "success" end) ();
  
  
  val _ = Testing.assert_no_failed_tests();
  val _ = "UNIT TESTS FOR ruleset rewriting PASSED!";
end





