signature RULESET_REWRITER_SHARING =
sig
  structure Ruleset : RULESET_SHARING
  type match
end;

signature RULESET_REWRITER =
sig
  structure Log : LOG

  structure Ruleset : RULESET
  structure Rule : RULE 
  sharing Ruleset.Rule.Sharing = Rule.Sharing
  type match

  structure Sharing : RULESET_REWRITER_SHARING
  sharing Sharing.Ruleset = Ruleset.Sharing;
  sharing type Sharing.match = match;

  (* matching *)
  val apply : Ruleset.T -> Rule.Graph.T 
        -> ((R.name * Rule.T) (* name, rule, rewritten graph *) 
            * Rule.Graph.T) Seq.seq 
  val apply_in : Ruleset.T -> Rule.Graph.T -> V.NSet.T  
        -> ((R.name * Rule.T) * Rule.Graph.T) Seq.seq;

  (* get just first rewrite *)
  val apply_first : Ruleset.T -> Rule.Graph.T 
        -> ((R.name * Rule.T) (* name, rule, rewritten graph *) 
            * Rule.Graph.T) option 
  val apply_first_in : Ruleset.T -> Rule.Graph.T -> V.NSet.T  
        -> ((R.name * Rule.T) * Rule.Graph.T) option;

  (* low-level *)
  val applicable_rules : Ruleset.T (* background ruleset *)
      -> (Rule.T -> Rule.Graph.T -> Rule.T * match Seq.seq) (* matcher *)
      -> R.NSet.T (* subset of rules to use *) 
      -> Rule.Graph.T (* graph to look for matches of rules in *)
      -> ((R.name * Rule.T) (* name, rule, rewritten graph *) 
            * Rule.Graph.T) Seq.seq 
 
  (* to see what a rule looks like once data is matched and bang-boxes 
     expanded. *)
  val instantiate_rule : match -> Rule.T -> Rule.T; 

  (* check how a single rule matches (rule is renamed) *)
  val rule_matches : Rule.T -> Rule.Graph.T -> (Rule.T * match Seq.seq)
  
  (* funny order is because we create a rule-matcher and use it in applicable_rules (rule is renamed) *)
  val rule_matches_within : V.NSet.T -> Rule.T -> Rule.Graph.T  
      -> (Rule.T * match Seq.seq)

  (* a couple of helpful fns because match is opaque *)
  val print_match : match -> unit
  val pretty_match : match -> Pretty.T
end;

(* *)
functor RulesetRewriter(
  structure Ruleset : RULESET
  structure MatchSearch : BG_MATCH_SEARCH
  sharing MatchSearch.Sharing.G = Ruleset.Rule.Sharing.Graph
  structure GraphSubst : GRAPH_SUBST
  sharing type GraphSubst.graph = Ruleset.Rule.Graph.T
  sharing type GraphSubst.match = MatchSearch.MatchState.T
) : RULESET_REWRITER =
struct
  structure Log : LOG = Log(val init_level = 0)

  structure MatchState = MatchSearch.BGMatchState;
  structure Ruleset = Ruleset;
  structure Rule = Ruleset.Rule;
  type match = MatchState.T
  (* *)
  structure MatchSearch = MatchSearch;
  structure GraphSubst = GraphSubst;

  structure G = Rule.Graph;

  fun log_p pretty_f lvl name =
    Log.logf lvl (fn g => Pretty.string_of
        (Pretty.chunks [Pretty.str (name^":"),(pretty_f g)]))

  val log_graph = log_p G.pretty
  val log_rule = log_p Rule.pretty

  fun rule_matches r g =
      let
        (* Vertices and variables must be renamed away from
         * those in g, otherwise the rewriting will fail
         * (a quirk of the implementations of LinRatExpr and
         * V.CRnm) *)
        val _ = Log.log 3 "RulesetRewriter.rule_matches"
        val g_norm = G.normalise g
        val rnms = (X.Rnm.mk_from_avoids (G.get_xnames g_norm),
                    V.Rnm.mk_from_avoids (G.get_vnames g_norm),
                    E.Rnm.empty, B.Rnm.empty)
        val (_,r) = Rule.rename rnms r;
        val lhs = G.normalise (Rule.get_lhs r);
        val rhs = G.normalise (Rule.get_rhs r);
        val avoid = G.get_vnames rhs;
        val track = G.get_vnames rhs;
      in (r,MatchSearch.match_normalised_avoiding_tracking (avoid,track) lhs g_norm) end;

  fun rule_matches_within vset r g  = 
      let 
        (* (Boundary) vertices and variables must be renamed
         * away from those in g, otherwise the rewriting will
         * fail (a quirk of the implementations of LinRatExpr
         * and V.CRnm) *)
        val _ = Log.log 3 "RulesetRewriter.rule_matches_within"
        val g_norm = G.normalise g
        val rnms = (X.Rnm.mk_from_avoids (G.get_xnames g_norm),
                    V.Rnm.mk_from_avoids (G.get_vnames g_norm),
                    E.Rnm.empty, B.Rnm.empty)
        val (_,r) = Rule.rename rnms r;
        val lhs = G.normalise (Rule.get_lhs r);
        val rhs = G.normalise (Rule.get_rhs r);
        val avoid = G.get_vnames rhs;
        val track = G.get_vnames rhs;
      in (r,
          MatchSearch.match_subgraph_normalised_avoiding_tracking
            (avoid,track) lhs g vset) end;
  
  (* instantiate rule with a match *)
  fun instantiate_rule m r = 
      Rule.mk (MatchState.get_pat m, 
               MatchState.replay_pat_bbox_ops m (Rule.get_rhs r));
  
  (* apply rules to whole graph *)
  (* IMPROVE: provide a single name-space for all rules, and thus avoid 
     multiple renamings. *)
  fun applicable_rules rset matcher rnset g = let
    val _ = log_graph 4 "RulesetRewriter.applicable_rules: graph" g
  in
    R.NSet.fold
    (fn n =>
        let
          val rule = (Ruleset.get_rule rset n)
          val rulename = R.string_of_name n
          val _ = log_rule 2 ("Trying rule "^rulename) rule
          val (r,matches) = matcher rule g
          val _ = log_rule 3 "Rule instantiated as" r
          val rw = GraphSubst.rewrite g (Rule.get_lhs r)
          fun apply_rw m = let
            val _ = Log.log 1 ("Applying rule "^rulename)
            val ((lhs,rhs),g) = rw m (Rule.get_rhs r)
            val rule = Rule.mk (G.minimise lhs,G.minimise rhs)
          in
            ((n,rule),(G.minimise g))
          end
        in
          Seq.append (Seq.map apply_rw matches)
        end)
     rnset
     Seq.empty
  end;
  
  fun apply rset g = 
      applicable_rules rset rule_matches 
       (Ruleset.get_active rset) g;

  fun apply_in rset g vset = 
      applicable_rules rset (rule_matches_within vset) 
        (Ruleset.get_active rset) g;
  
  (* apply just first rule that can be applied *)
  fun apply_first rset g =
      case Seq.pull (apply rset g)
       of NONE => NONE
        | SOME (h,_) => SOME h;

  fun apply_first_in rset vset g = 
      case Seq.pull (apply_in rset vset g) 
       of NONE => NONE
        | SOME (h,_) => SOME h;

  val print_match = MatchState.print
  val pretty_match = MatchState.pretty

  structure Sharing : RULESET_REWRITER_SHARING
  = struct
    structure Ruleset = Ruleset.Sharing;
    type match = MatchState.T;
  end


end; (* *)
