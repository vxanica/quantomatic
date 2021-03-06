(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *
 *  Computing substitutions of graphs: replacing a matched graph with a
 *  new graph that shares the same interface.
 *
 *  This implements double-pushout rewriting.
 * -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- *)
signature GRAPH_SUBST_SHARING =
sig
  type graph
  type match
end;

signature GRAPH_SUBST
= sig
  structure Log : LOG

  type graph
  type match
  
  structure Sharing : GRAPH_SUBST_SHARING
  sharing type graph = Sharing.graph;
  sharing type match = Sharing.match;
  
  (* rewriting pattern graph *)
  val do_rewrite : match (* match of lhs (not inst) *)
                -> graph (* replace with this rhs (not inst yet, but with
                            same boundary names as match pattern) *)
                -> graph (* new, rewritten graph *)

  val rewrite : match (* match of lhs *)
             -> graph (* replace with this rhs (not inst yet, but with
                         same boundary names as match pattern) *)
             -> (graph*graph) (* new lhs->rhs, as it is named/expanded in result graph *)
                * graph (* new, rewritten graph *)

end;


(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *) 
functor OGraphSubst(MatchState : OGRAPH_MATCH_STATE)
= struct
  structure Log : LOG = Log(val init_level = 0)

  type match = MatchState.T;
  type graph = MatchState.G.T;
  
  structure G = MatchState.G;
  
  structure Sharing = struct
    type match = match;
    type graph = graph;
  end;

  fun log_p pretty_f lvl name =
    Log.logf lvl (fn g => Pretty.string_of
        (Pretty.chunks [Pretty.str (name^":"),(pretty_f g)]))

  val log_graph = log_p G.pretty
  val log_vrnm = log_p V.Rnm.pretty
  val log_ernm = log_p E.Rnm.pretty

  (* implicit rhs; efficiency:
     allows lhs computation to be performed just once, then many rhs'
     to be given.
  *)
  fun rewrite m =
    let
      val g = MatchState.get_full_tgt m
      val pat = MatchState.get_pat m
      val subst_data = G.apply_data_subst (MatchState.get_match_subst m)
      val shared_boundary = G.get_boundary pat;
      val vmap = MatchState.get_vmap m
      val vmapf = VInjEndo.domf vmap
      val matched = VInjEndo.get_codset vmap;
          (* remove the matched part *)
      val interior = V.NSet.fold (V.NSet.delete o vmapf)
                                 shared_boundary
                                 matched
      val interior_edges = EInjEndo.get_codset (MatchState.get_emap m);
      (* h is g with LHS cut out; note that we need to delete edges explicitly,
         in case of bare wire matches *)
      val h = g |> E.NSet.fold G.delete_edge interior_edges
                |> V.NSet.fold G.delete_vertex interior
                   (* apply the data substitution to what remains *)
                |> subst_data;
      val _ = log_graph 4 "OGraphSubst.rewrite: pattern graph" pat
      val _ = log_graph 3 "OGraphSubst.rewrite: G" g
      val _ = log_graph 3 "OGraphSubst.rewrite: G-pat" h

      (* Rename the RHS verts for merging.
       *
       * The aim is to have the boundary verts match where the
       * LHS was cut out of g, and make all the other verts have
       * names distinct from any verts in h.  Then
       * G.merge_by_vertices will do the right thing.
       *
       * We actually make it avoid anything in g, so clients can
       * tell what was replaced.
       *
       * It also does the data substitution.
       *)
      val g_pat_verts = V.NSet.union_merge (G.get_vnames g) (G.get_vnames pat);
      val e_rnm = E.Rnm.mk_from_avoids (G.get_enames g);
      (* first v rename makes all names except boundary verts fresh *)
      (* this avoid clashes when doing the second rename *)
      val v_rnm1 = V.Rnm.mk shared_boundary g_pat_verts V.NTab.empty;
      (* second v rename sets the boundary verts to match the
       * corresponding verts in h. *)
      val v_rnm2 = V.Rnm.mk V.NSet.empty
                            g_pat_verts
                            (VInjEndo.get_domtab vmap);
      val _ = log_vrnm 4 "OGraphSubst.rewrite: v_rnm1" v_rnm1
      val _ = log_vrnm 4 "OGraphSubst.rewrite: v_rnm2" v_rnm2
      val _ = log_ernm 4 "OGraphSubst.rewrite: e_rnm" e_rnm

      val prepare = snd o G.VertexCRnm.rename v_rnm2
                  o snd o G.VertexCRnm.rename v_rnm1
                  o snd o G.EdgeCRnm.rename e_rnm
                  o subst_data

      in (fn rhs =>
          let
            val _ = log_graph 4 "OGraphSubst.rewrite: RHS" rhs
            val rhs' = prepare rhs
            val _ = log_graph 4 "OGraphSubst.rewrite: RHS (prepared)" rhs'
            val pat' = prepare pat
            val _ = log_graph 4 "OGraphSubst.rewrite: LHS (prepared)" pat'
          in
            ((pat',rhs'), G.merge_by_vertices rhs' h)
          end)
      end;

  val do_rewrite = snd oo rewrite;

end;


(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *) 
functor BangGraphSubst(MatchState : BANG_GRAPH_MATCH_STATE)
= struct
  type match = MatchState.T;
  type graph = MatchState.G.T;
  
  structure Sharing = struct
    type match = match;
    type graph = graph;
  end;

  structure OGS = OGraphSubst(MatchState);

  structure Log = OGS.Log;

  fun rewrite m rhs = OGS.rewrite m (MatchState.replay_pat_bbox_ops m rhs)

  val do_rewrite = snd oo rewrite;

end;

