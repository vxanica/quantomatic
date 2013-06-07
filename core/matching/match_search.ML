(* The matching interface *)
(* see docs/matching_algo for details *)
signature MATCH_SEARCH_SHARING =
sig
  structure G : OGRAPH_SHARING
  structure MatchState : OGRAPH_MATCH_STATE_SHARING
  sharing G = MatchState.G
end

signature MATCH_SEARCH =
sig
  structure Log : LOG;

  structure MatchState : OGRAPH_MATCH_STATE
  structure G : OGRAPH
  structure Sharing : MATCH_SEARCH_SHARING
    sharing Sharing.G = G.SharingOGraph
    sharing Sharing.MatchState = MatchState.Sharing
  
  val match : G.T           (* pattern graph *)
    -> G.T                  (* target graph *)
    -> MatchState.T Seq.seq (* (lazy) list of matches *)
  
  val match_subgraph : G.T  (* pattern graph *)
    -> G.T                  (* target graph *)
    -> V.NSet.T             (* target subgraph verts *)
    -> MatchState.T Seq.seq (* (lazy) list of matches *)
  
  (* these versions are for efficiency if you can guarantee
   * that the graphs are already normalised
   *)
  val match_normalised : G.T (* pattern graph (normalised) *)
    -> G.T                   (* target graph (normalised) *)
    -> MatchState.T Seq.seq  (* (lazy) list of matches *)
  
  val match_subgraph_normalised : G.T (* pattern graph (normalised) *)
    -> G.T                            (* target graph (normalised) *)
    -> V.NSet.T                       (* target subgraph verts *)
    -> MatchState.T Seq.seq           (* (lazy) list of matches *)
end

signature BG_MATCH_SEARCH =
sig
  structure Log : LOG;

  structure G : BANG_GRAPH;
  structure MatchState : BANG_GRAPH_MATCH_STATE;
  structure BBoxOperator : BBOX_OPERATOR;
  structure Sharing : MATCH_SEARCH_SHARING
    sharing Sharing.G = G.SharingOGraph
    sharing Sharing.MatchState = MatchState.Sharing
    sharing G.SharingOGraph = BBoxOperator.G.SharingOGraph
    sharing MatchState.BBoxOperator.Sharing = BBoxOperator.Sharing
  
  (* Searches for matches *)
  val match
     : BBoxOperator.T       (* pattern graph + operator *)
    -> G.T                  (* target graph *)
    -> MatchState.T Seq.seq (* (lazy) list of matches *)
  
  (* Searches for matches *)
  val match_subgraph
     : BBoxOperator.T       (* pattern graph + operator *)
    -> G.T                  (* target graph *)
    -> V.NSet.T             (* target subgraph verts *)
    -> MatchState.T Seq.seq (* (lazy) list of matches *)
  
  (* Searches for matches *)
  val match_normalised
     : BBoxOperator.T       (* pattern graph + operator *)
    -> G.T                  (* target graph (normalised) *)
    -> MatchState.T Seq.seq (* (lazy) list of matches *)
  
  (* Searches for matches *)
  val match_subgraph_normalised
     : BBoxOperator.T       (* pattern graph + operator *)
    -> G.T                  (* target graph (normalised) *)
    -> V.NSet.T             (* target subgraph verts *)
    -> MatchState.T Seq.seq (* (lazy) list of matches *)
end
