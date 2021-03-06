(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *)
(*  Representation Graphs with  Bang-Boxes *)
(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *)
(* FIXME: make merge_by_vertices respect !-boxes. ? need general notion of
   data merging? *)

(* Quantomatic's implementation of pattern graphs (a.k.a. !-graphs) deviates
 * from the theoretical version in several ways.  The !-vertices are stored
 * separately to other vertex types, in their own namespace (B, rather than V).
 * The edges from !-vertices to non-!-vertices (ie: the contents of the !-box)
 * are stored implicitly as a binary relation.  Similarly, the edges between
 * !-vertices are stored as a partial order.  This is possible because there is
 * at most one edge between a !-vertex and any other vertex, and the !-vertex
 * must be the source of the edge.
 *)

(* Basic Bang Graphs: data and also basic functions *)
signature BASIC_BANG_GRAPH =
sig
include BASIC_OGRAPH;

exception bbox_not_open_exp of (V.name * V.name) * B.name * T;
exception bbox_already_exists_exp of B.name * T;
exception bbox_bad_parent_exp of B.name * B.name * T;
exception no_such_bbox_exp of string * B.name * T;

val get_bboxes : T -> B.NSet.T
(* Does not contain empty !-boxes (or unboxed vertices) *)
val get_bbox_rel : T -> BVBRel.T
(* Return the "parent" relation for nested bang-boxes *)
val get_bbox_parent_rel : T -> BMap.T
(* Does not contain empty !-boxes *)
val get_bbox_table : T -> V.NSet.T B.NTab.T
(* Does not contain unboxed vertices *)
val get_vertex_bbox_table : T -> B.NSet.T V.NTab.T
(* all vertices that are in at least one !-box *)
val get_bboxed : T -> V.NSet.T
(* all vertices that are in at no !-boxes *)
val get_unbboxed : T -> V.NSet.T
val get_empty_bboxes : T -> B.NSet.T

val add_bbox_named_like : B.name -> T -> (B.name * T)
(* delete a bbox and orphan its children *)
(* does not delete the contained vertices *)
(* identity if name does not exist *)
val delete_bbox : B.name -> T -> T

(* throws bbox_already_exists_exp on name clash *)
(* identity if original name does not exist *)
val rename_bbox : B.name -> B.name -> T -> T

(* no_such_bbox_exp if !-box does not exist *)
val add_to_bbox : B.name -> V.NSet.T -> T -> (V.NSet.T * T)
(* no_such_bbox_exp if !-box does not exist *)
(* does not raise if verts are not in !-box *)
val remove_from_bbox : B.name -> V.NSet.T -> T -> (V.NSet.T * T)

(* Set parent of the given bbox
 *
 * Arg 1: child bbox
 * Arg 2: parent bbox
 * Arg 3: graph
 *)
(* bbox_bad_parent_exp if fst is not a subset of snd *)
val set_bbox_parent : B.name -> B.name -> T -> T

(* make the given bbox an orphan *)
val clear_bbox_parent : B.name -> T -> T

(* returns true if bbox has parent *)
val bbox_has_parent : T -> B.name -> bool


(* must make sure the bbox_rel dom is a subset of bboxes *)
val update_bboxes : (B.NSet.T -> B.NSet.T) -> T -> T
val update_bbox_rel : (BVBRel.T -> BVBRel.T) -> T -> T
val update_bbox_parent_rel : (BMap.T -> BMap.T) -> T -> T

end;



(* bang-box graphs with all the extra functions defined in terms of the
   basic ones *)
signature BANG_GRAPH =
sig
include OGRAPH;

(* *** COPIED FROM BASIC_BANG_GRAPH ... would be better to have union version
   of include *** *)

exception bbox_not_open_exp of (V.name * V.name) * B.name * T;
exception bbox_already_exists_exp of B.name * T;
exception no_such_bbox_exp of string * B.name * T;
exception bbox_bad_parent_exp of B.name * B.name * T;

val get_bboxes : T -> B.NSet.T
(* Does not contain empty !-boxes (or unboxed vertices) *)
val get_bbox_rel : T -> BVBRel.T
(* Return the "parent" relation for nested bang-boxes *)
val get_bbox_parent_rel : T -> BMap.T
(* Does not contain empty !-boxes *)
val get_bbox_table : T -> V.NSet.T B.NTab.T
(* Does not contain unboxed vertices *)
val get_vertex_bbox_table : T -> B.NSet.T V.NTab.T
(* all vertices that are in at least one !-box *)
val get_bboxed : T -> V.NSet.T
(* all vertices that are in at no !-boxes *)
val get_unbboxed : T -> V.NSet.T
val get_empty_bboxes : T -> B.NSet.T

val add_bbox_named_like : B.name -> T -> (B.name * T)
(* does not delete the contained vertices *)
(* identity if name does not exist *)
val delete_bbox : B.name -> T -> T

(* throws bbox_already_exists_exp on name clash *)
(* identity if original name does not exist *)
val rename_bbox : B.name -> B.name -> T -> T

(* no_such_bbox_exp if !-box does not exist *)
(* The minimum open subgraph containing the
 * given vertices is added, to ensure the
 * !-box remains an open subgraph.
 *
 * Returns the actual vertices added (always
 * a superset of the vertex set given).
 *)
val add_to_bbox : B.name -> V.NSet.T -> T -> (V.NSet.T * T)
val doadd_to_bbox : B.name -> V.NSet.T -> T -> T
(* no_such_bbox_exp if !-box does not exist *)
(* does not raise if verts are not in !-box *)
(* Does not remove any vertices that are
 * necessary for the !-box to remain open
 *
 * Returns the actual vertices removed (always
 * a subset of the vertex set given).
 *)
val remove_from_bbox : B.name -> V.NSet.T -> T -> (V.NSet.T * T)
val doremove_from_bbox : B.name -> V.NSet.T -> T -> T

(* set parent of the first bbox to be the second bbox *)
(* snd will be the parent of the fst *)
val set_bbox_parent : B.name -> B.name -> T -> T

(* make the given bbox an orphan *)
val clear_bbox_parent : B.name -> T -> T

(* returns true if bbox has parent *)
val bbox_has_parent : T -> B.name -> bool

(* we don't copy updaters/setters for internal structures,
 * since using these can lead to an inconsistent state *)

(* *** END OF COPIED *** *)

exception merge_bbox_exp of string
(* thrown when using old API on a graph with overlapping !-boxes *)

(* If adding an edge between the two given vertices would extend
 * one or more !-boxes, return one such !-box, otherwise NONE
 *)
val tryget_bbox_extended_by_edge : V.name -> V.name -> T -> B.name option

val lookup_bbox_parent : T -> B.name -> B.name option

(* getters for bbox -> vert *)
val get_bbox_list : T -> B.name list
val has_bbox : T -> B.name -> bool
(* no_such_bbox_exp if bbox does not exist *)
val get_bbox_contents : T -> B.name -> V.NSet.T

(* getters for vert -> bbox *)
(* no_such_vname_exp if vertex does not exist *)
val get_bboxes_of : T -> V.name -> B.NSet.T
(* no_such_vname_exp if vertex does not exist *)
val is_bboxed : T -> V.name -> bool

(* bbox_already_exists_exp *)
val add_named_bbox : B.name -> T -> T
val add_bbox : T -> B.name * T
val doadd_bbox : T -> T

val try_rename1_bbox : B.name -> B.name -> T -> T option

val remove_from_all_bboxes : V.NSet.T -> T -> T

(* no_such_bbox_exp *)
val kill_bbox : B.name -> T -> T
(* no_such_bbox_exp *)
val drop_bbox : B.name -> T -> T
val merge_bboxes : B.NSet.T -> T -> B.name * T

(* copy a set of vertices, making copy having names fresh w.r.t.
   vrn and ern (edge and vertex renaming).
   copies edges to all vertices outside the selected set.
   assumes: (get_vnames g) <= get_avoids(vrn)
            (get_enames g) <= get_avoids(ern)
            (get_bboxes g) <= get_avoids(brn)
*)
val copy1_bbox : B.name (* bbox to copy *)
      -> ((V.renaming (* renaming for bbox copy/avoids *)
           * E.renaming
           * B.renaming)
          * T) (* graph containing bbox name *)
      -> (B.name (* new box name *)
          * ((V.renaming (* how vnames were copied *)
               * E.renaming (* ename copying *)
               * B.renaming) (* bbname copying *)
             * T)) (* new graph with bbox copied *)

val fresh_copy1_bbox : B.name (* bbox to copy *)
      -> T (* graph containing bbox name *)
      -> (B.name (* new box name *)
          * T) (* new graph with bbox copied *)

(* copy and drop *)
val expand1_bbox : B.name (* bbox to expand *)
      -> ((V.renaming (* renaming for bbox copy/avoids *)
           * E.renaming
           * B.renaming)
          * T) (* graph containing bbox name *)
      -> ((V.renaming (* how vnames were copied *)
               * E.renaming (* ename copying *)
               * B.renaming) (* bbname copying *)
             * T) (* new graph with bbox expanded *)

(* copy and drop *)
val fresh_expand1_bbox : B.name (* bbox to expand *)
      -> T (* graph containing bbox name *)
      -> T (* new graph with bbox expanded *)

(* renaming of bang-box names *)
structure BBoxCRnm : COMPOUND_RENAMING
where type obj = T and type renaming = B.Rnm.T

val rename_apart_incl_bboxes : T -> T ->
  (X.renaming * V.renaming * E.renaming * B.renaming) * T

end;


(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *)
(* A  Graph With Boundary *)
(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *)
functor BasicBangGraphFun(
        structure Param : OGRAPH_PARAM
        type data
        val empty_data : data
) : BASIC_BANG_GRAPH
= struct

  (* IDEA: would be handy to have a warning for type overloading; can be tricky to see! e.g. if OVertex = Param.Vertex ... *)

  (* to avoid using clobbered data and empty graph from the opened Basic Graph *)
  type data2 = data;

  (* we add bbox to Graph data, this is hidden *)
  datatype hdata =
           HData of
           { bboxes : B.NSet.T,
             bbox_rel : BVBRel.T,
             bbox_parent_rel : BMap.T,
             data : data
           };
  fun get_bboxes_of_hdata (HData rep) = #bboxes rep;
  fun get_bbox_rel_of_hdata (HData rep) = #bbox_rel rep;
  fun get_bbox_parent_rel_of_hdata (HData rep) = #bbox_parent_rel rep;
  fun get_data_of_hdata (HData rep) = #data rep;
  fun update_bboxes_of_hdata f (HData rep) =
      HData { data = #data rep,
              bbox_rel = #bbox_rel rep,
              bbox_parent_rel = #bbox_parent_rel rep,
              bboxes = f (#bboxes rep)
            };
  fun update_bbox_rel_of_hdata f (HData rep) =
      HData { data = #data rep,
              bbox_rel = f (#bbox_rel rep),
              bbox_parent_rel = #bbox_parent_rel rep,
              bboxes = #bboxes rep
            };
  fun update_bbox_parent_rel_of_hdata f (HData rep) =
      HData { data = #data rep,
              bbox_rel = #bbox_rel rep,
              bbox_parent_rel = f (#bbox_parent_rel rep),
              bboxes = #bboxes rep
            };
  fun update_data_of_hdata f (HData rep) =
      HData { data = f (#data rep),
              bbox_rel = #bbox_rel rep,
              bbox_parent_rel = #bbox_parent_rel rep,
              bboxes = #bboxes rep
            };
  val empty_hdata = HData { bboxes = B.NSet.empty,
                     bbox_rel = BVBRel.empty,
                     bbox_parent_rel = BMap.empty,
                     data = empty_data};

  (* make basic graph with this as internal data *)
  structure G : BASIC_OGRAPH = BasicOGraphFun(
    structure Param = Param
    type data = hdata
    val empty_data = empty_hdata
  );
  (* inherit functions from Graph *)
  open G;

  (* clobber sub-graph data stuff *)
  type data = data2;
  val get_data = get_data_of_hdata o G.get_data;
  val update_data = G.update_data o update_data_of_hdata;

  exception bbox_not_open_exp of (V.name * V.name) * B.name * T;
  exception bbox_already_exists_exp of B.name * T;
  exception no_such_bbox_exp of string * B.name * T;
  exception bbox_bad_parent_exp of B.name * B.name * T;

  (* for bbox part of added data *)
  val get_bboxes = get_bboxes_of_hdata o G.get_data;
  val get_bbox_rel = get_bbox_rel_of_hdata o G.get_data;
  val get_bbox_parent_rel = get_bbox_parent_rel_of_hdata o G.get_data;
  val get_bbox_table = BVBRel.get_domtab o get_bbox_rel
  val get_vertex_bbox_table = BVBRel.get_codtab o get_bbox_rel
  (* all vertices that are in at least one bbox *)
  val get_bboxed = V.NTab.get_nameset o get_vertex_bbox_table;
  fun get_unbboxed g =
    let
      val boxrel = get_bbox_rel g
      val verts = V.NTab.get_nameset (get_vertices g)
    in
      V.NSet.subtract verts (BVBRel.get_codset boxrel)
    end
  fun get_empty_bboxes g =
    let val boxrel = get_bbox_rel g in
      B.NSet.subtract (get_bboxes g) (BVBRel.get_domset boxrel)
    end

  val update_bboxes = G.update_data o update_bboxes_of_hdata;
  val update_bbox_rel = G.update_data o update_bbox_rel_of_hdata;
  val update_bbox_parent_rel = G.update_data o update_bbox_parent_rel_of_hdata;
  
  fun set_bbox_parent b bp g = let
    val has_bbox = B.NSet.contains o get_bboxes;
    fun get_bbox_contents g b =
      if has_bbox g b then
        (case B.NTab.lookup (get_bbox_table g) b of
              NONE    => V.NSet.empty
            | SOME vs => vs)
      else
        raise no_such_bbox_exp ("set_bbox_parent",b,g)
    val b_vs = get_bbox_contents g b
    val bp_vs = get_bbox_contents g bp
    val _ = if V.NSet.sub_set b_vs bp_vs then ()
            else raise bbox_bad_parent_exp (b,bp,g)
    (* FIXME: enforce anti-symmetry (no loops) *)
  in
    update_bbox_parent_rel (BMap.add_to_dom b bp) g
  end
  
  (* orphan the given !-box. If its parent has no children, remove from parent rel *)
  fun clear_bbox_parent b =
    update_bbox_parent_rel (BMap.surj_del_dom b)

  fun bbox_has_parent g b =
    case BMap.lookup_domf (get_bbox_parent_rel g) b
      of SOME _ => true | NONE => false

  fun add_bbox_named_like b g = let
    val (bn',bs') = B.NSet.add_new b (get_bboxes g)
  in
    (bn', g |> update_bboxes (fn _ => bs'))
  end

  fun delete_bbox bn g =
        g |> (case BMap.lookup_codf (get_bbox_parent_rel g) bn
              of SOME ch => B.NSet.fold clear_bbox_parent ch
               | NONE => I)
          |> clear_bbox_parent bn
          |> update_bboxes (B.NSet.delete bn)
          |> update_bbox_rel (BVBRel.del_dom bn)

  (* raises bbbox_already_exists_exp if bbox name already exists *)
  fun rename_bbox n1 n2 g =
      g |> update_bboxes (fn bxs =>
                             case B.NSet.try_rename1 n1 n2 bxs
                               of NONE => raise bbox_already_exists_exp (n2,g)
                                | SOME bxs2 => bxs2)
        |> update_bbox_rel (fn bxs =>
                             case BVBRel.try_rename1_dom n1 n2 bxs
                              of NONE => raise bug_exp "bbox in bbox_rel but not bboxes"
                               | SOME bxs2 => bxs2);

  (* use with caution *)
  structure OGHelpers = OGraphFun(G)

  (* modified graph functions *)
  fun add_edge_named_like en edd s t g = let
    val (sd,_) = get_vertex g s
    val (td,_) = get_vertex g t
    fun get_bboxes_of g v =
        case V.NTab.lookup (get_vertex_bbox_table g) v of
             NONE => B.NSet.empty
           | SOME bs => bs;
    val sbbs = get_bboxes_of g s
    val tbbs = get_bboxes_of g t
    val (e,g') = G.add_edge_named_like en edd s t g
    fun repair_wire wvs = let
      val wire_bbs = B.NSet.union_merge sbbs tbbs
    in
      update_bbox_rel (BVBRel.add_many wire_bbs wvs)
    end
  in
    case (sd,td)
      of (OVData.WVert,OVData.WVert) =>
            let val (_,_,wvs,_) = OGHelpers.get_wire_containing_edge g' e in
              (e,repair_wire (V.NSet.add s (V.NSet.add t wvs)) g')
            end
       | (OVData.NVert _,OVData.WVert) =>
            let val (_,_,wvs,_) = OGHelpers.get_wire_containing_edge g' e in
              (e,repair_wire (V.NSet.add t wvs) g')
            end
       | (OVData.WVert,OVData.NVert _) =>
            let val (_,_,wvs,_) = OGHelpers.get_wire_containing_edge g' e in
              (e,repair_wire (V.NSet.add s wvs) g')
            end
       | (OVData.NVert _,OVData.NVert _) => (e,g')
  end

  fun delete_vertex n g =
      g |> update_bbox_rel (BVBRel.del_cod n)
        |> G.delete_vertex n;

  fun rename_vname n1 n2 g =
      g |> G.rename_vname n1 n2
        (* the NONE case should never happen: all vertices already occur in
           graph, so G.rename_vname should have raised an exeption. *)
        |> update_bbox_rel (the o BVBRel.try_rename1_cod n1 n2);

  fun find_open_subgraph g vset = let
    fun add_if_wv v = if OGHelpers.is_wire_vertex g v then V.NSet.add v else I
    fun add_incoming_wire e = let
      val (s,_,wvs,_) = OGHelpers.get_wire_containing_edge g e
    in
      (add_if_wv s) o V.NSet.union_merge wvs
    end
    fun add_outgoing_wire e = let
      val (_,t,wvs,_) = OGHelpers.get_wire_containing_edge g e
    in
      (add_if_wv t) o V.NSet.union_merge wvs
    end
    fun absorb vn = let
      val (_,(ins,outs)) = get_vertex g vn
    in
       (E.NSet.fold add_incoming_wire ins)
       o (E.NSet.fold add_outgoing_wire outs)
    end
  in
    V.NSet.fold absorb vset vset
  end

  fun add_to_bbox b vs g =
    if not (B.NSet.contains (get_bboxes g) b) then
      raise no_such_bbox_exp ("add_to_bbox",b,g)
    else if not (V.NSet.sub_set vs ((V.NTab.get_nameset o get_vertices) g)) then
      raise no_such_vnames_exp ("doadd_to_bbox",vs,g)
    else
      let
        val to_add = find_open_subgraph g vs
      in
        (to_add, g |> update_bbox_rel (BVBRel.add_to_dom b to_add))
      end

  fun remove_from_bbox b vs g =
    if not (B.NSet.contains (get_bboxes g) b) then
      raise no_such_bbox_exp ("remove_from_bbox",b,g)
    else
      let
        val old_bvs = 
          (case B.NTab.lookup (get_bbox_table g) b of
                NONE    => V.NSet.empty
              | SOME vs => vs)
        val new_bvs = find_open_subgraph g (V.NSet.subtract old_bvs vs)
        val remove_bvs = V.NSet.subtract old_bvs new_bvs
      in
        (remove_bvs, g |> update_bbox_rel (BVBRel.del_from_dom b remove_bvs))
      end

  fun get_plugging g v1 v2 = let
    (* gah, stupid inheritance games *)
    fun get_bboxes_of g v =
        case V.NTab.lookup (get_vertex_bbox_table g) v of
             NONE => B.NSet.empty
           | SOME bs => bs;
  in
    if B.NSet.eq (get_bboxes_of g v1) (get_bboxes_of g v2)
    then G.get_plugging g v1 v2
    else NONE
  end;

  (* prettifying *)
  fun pretty g =
      Pretty.chunks
        [ Pretty.str "BangBoxGraph{",
          Pretty.block
            [Pretty.str "  ", (* indent *)
             Pretty.chunks
               ([Pretty.block
                         [Pretty.str "Bang-Boxes: ",
                          B.NSet.pretty (get_bboxes g)],
                       Pretty.block
                         [Pretty.str "BB relation: ",
                          BVBRel.pretty (get_bbox_rel g)],
                       Pretty.block
                         [Pretty.str "BB parents: ",
                          BMap.pretty (get_bbox_parent_rel g)]]
                @ [G.pretty g])],
          Pretty.str "}"
        ];

  val print = Pretty.writeln o pretty;

end (* Functor BasicBangGraphFun : ... -> BASIC_BANG_GRAPH *)


(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *)
(*  functor make a BANG_GRAPH *)
(* -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-==-=-=-=-=-=-=-=-=-=- *)
(* Given a BASIC_BANG_GRAPH, provide it with various tools *)
functor BangGraphTools(G : BASIC_BANG_GRAPH)
: BANG_GRAPH
= struct

  (* provide basic bang-graph functions and sub-structures  *)
  open G;

  (* provide open graph functions/tools *)
  structure OGraph = OGraphFun(G);
  open OGraph;

  exception merge_bbox_exp of string

  fun tryget_bbox_extended_by_edge s t g = let
    val (sd,_) = get_vertex g s
    val (td,_) = get_vertex g t
    fun get_bboxes_of g v =
        case V.NTab.lookup (get_vertex_bbox_table g) v of
             NONE => B.NSet.empty
           | SOME bs => bs;
    fun check_nv_wv n w = let
      val nbbs = get_bboxes_of g n
      val wbbs = get_bboxes_of g w
      fun one_bad_bbox () = let
          val bad_bbs = B.NSet.subtract nbbs wbbs
        in the (B.NSet.get_local_bot bad_bbs) end
    in
      if B.NSet.sub_set nbbs wbbs then NONE
      else SOME (one_bad_bbox())
    end
  in
    case (sd,td)
      of (OVData.WVert,OVData.WVert) =>
          let
            val sbbs = get_bboxes_of g s
            val tbbs = get_bboxes_of g t
            fun one_bad_bbox () = let
                val (l,_,r) = B.NSet.contrast sbbs tbbs
                val bad_bbs = B.NSet.union_merge l r
              in the (B.NSet.get_local_bot bad_bbs) end
          in
            if B.NSet.eq sbbs tbbs then NONE
            else SOME (one_bad_bbox())
          end
       | (OVData.NVert _,OVData.WVert) => check_nv_wv s t
       | (OVData.WVert,OVData.NVert _) => check_nv_wv t s
       | _ => NONE
  end

  val doadd_to_bbox = snd ooo add_to_bbox
  val doremove_from_bbox = snd ooo remove_from_bbox

  val lookup_bbox_parent = BMap.lookup_domf o get_bbox_parent_rel

  (* getters for bbox -> vert *)
  val get_bbox_list = B.NSet.list_of o get_bboxes;
  val has_bbox = B.NSet.contains o get_bboxes;
  fun get_bbox_contents g b =
    if has_bbox g b then
      (case B.NTab.lookup (get_bbox_table g) b of
            NONE    => V.NSet.empty
          | SOME vs => vs)
    else
      raise no_such_bbox_exp ("get_bbox_contents",b,g)

  (* getters for vert -> bbox *)
  (* lookup names of boxes that v is in *)
  fun get_bboxes_of g v =
      case V.NTab.lookup (get_vertex_bbox_table g) v of
           NONE => (if not (V.NTab.contains_name (get_vertices g) v) then
                      raise no_such_vname_exp ("get_bboxes_of", v, g)
                    else B.NSet.empty)
         | SOME bs => bs;
  fun is_bboxed g v =
    if V.NSet.contains (get_vnames g) v then
      V.NSet.contains (get_bboxed g) v
    else
      raise no_such_vname_exp ("is_bboxed", v, g)

  fun add_named_bbox b g = let
    val (b',g') = add_bbox_named_like b g
  in
    if B.name_eq (b,b') then g'
    else raise bbox_already_exists_exp (b,g)
  end
  val add_bbox = add_bbox_named_like B.default_name
  val doadd_bbox = snd o add_bbox

  fun try_rename1_bbox n1 n2 g =
      (SOME (rename_bbox n1 n2 g)) handle bbox_already_exists_exp _ => NONE;

  fun remove_from_all_bboxes vs g =
    B.NSet.fold (fn b => doremove_from_bbox b vs) (get_bboxes g) g

  fun kill_bbox bn g =
    if not (has_bbox g bn) then raise no_such_bbox_exp ("kill_bbox",bn,g)
    else
      let
        val g' =
          g |> (case BMap.lookup_codf (get_bbox_parent_rel g) bn
                  of SOME ch => B.NSet.fold kill_bbox ch
                   | NONE => I)
        val bbox_vs = get_bbox_contents g' bn
      in
        g' |> V.NSet.fold delete_vertex bbox_vs
           |> delete_bbox bn
      end;

  fun drop_bbox bn g =
    if not (has_bbox g bn) then
      raise no_such_bbox_exp ("drop_bbox",bn,g)
    else
      g |> delete_bbox bn;

  (* returns merged bbox-name and new merged graph *)
  fun merge_bboxes bnset g =
      (case B.NSet.pull_local_top bnset of
         NONE => raise merge_bbox_exp "given empty bbox name set"
       | SOME (bn,bnset2) =>
         (bn, B.NSet.fold
              (fn bn2 => fn g2 =>
                   g2 |> doadd_to_bbox bn (get_bbox_contents g2 bn2)
                      |> delete_bbox bn2)
              bnset2 g));

  
  (* copy a bbox and its children. If parent has been copied, inherit the copy
     as new parent, otherwise inherit the current parent. *)



  fun copy_bbox_children from_bbox to_bbox_opt (brn,g) =
    let
      val children = BMap.lookup_codf (get_bbox_parent_rel g) from_bbox
      fun copy_child c (brn,g) = let
        val (new_c_opt,brn') = B.Rnm.rename1 c brn
        val new_c = case new_c_opt of SOME x=>x | NONE =>
                    raise ERROR ("bad renamer passed to copy_bbox_children")
        val g' = g |> add_named_bbox new_c
                   |> (case to_bbox_opt
                         of SOME bb => set_bbox_parent new_c bb
                          | NONE => I)
      in copy_bbox_children c new_c_opt (brn',g')
      end
    in case children
         of SOME cs => B.NSet.fold copy_child cs (brn,g)
          | NONE => (brn,g)
    end
  
  (* copy bang box, given renaming info, or possibly with dictated renaming. *)

(*  fun copy1_bbox bn ((vrn,ern,brn),g) =
      let
        val bbox_vs = get_bbox_contents g bn;
        val ((vrn',ern'),g') = copy_subgraph bbox_vs ((vrn, ern),g);
        val (new_bn_opt,brn') = B.Rnm.rename1 bn brn;
        val bn' = (case new_bn_opt
                     of NONE => raise ERROR ("copy1_bbox was passed brn that " ^
                                "does not avoid !-box being renamed")
                      | SOME bn' => bn');
        val g'' = add_named_bbox bn' g'
        fun extend_bbs v gr =
          let
            val SOME v' = V.Rnm.lookup vrn' v
            val vs = V.NSet.single v'
            val bbs' = B.NSet.delete bn (get_bboxes_of g v)
            val bbs = B.NSet.add bn' bbs'
          in
            B.NSet.fold (fn b => doadd_to_bbox b vs) bbs gr*)

  fun copy_or_expand MK_BBOX bn ((vrn,ern,brn),g) =
    let
      val bbox_vs = get_bbox_contents g bn;
      val ((vrn',ern'),g') = copy_subgraph bbox_vs ((vrn, ern),g);
      val (g', new_bn_opt, brn') =
        if MK_BBOX then
          let val (new_bn_opt,brn') = B.Rnm.rename1 bn brn
          in case new_bn_opt
               of SOME bn' => (add_named_bbox bn' g', new_bn_opt, brn')
                | NONE => raise ERROR
                          ("copy_or_expand was passed brn that " ^
                           "does not avoid !-box being renamed")
          end
        else (g', NONE, brn)
      val (brn',g') = copy_bbox_children bn new_bn_opt (brn',g')
      fun map_bbox_name b = case B.Rnm.lookup brn' b of SOME b' => b' | NONE => b
      fun extend_bbs v gr =
        let
          (* find the vertex that this one was copied from *)
          val vnew = the (V.Rnm.lookup vrn' v)
          val bbs_to_extend = get_bboxes_of g v
           |> B.NSet.delete bn
           |> (case new_bn_opt of SOME bn' => B.NSet.add bn' | NONE => I)
           |> (fn bs => B.NSet.fold (fn b => B.NSet.add (map_bbox_name b)) bs B.NSet.empty)
        in
          B.NSet.fold (fn b => doadd_to_bbox b (V.NSet.single vnew)) bbs_to_extend gr
        end
      val g' = V.NSet.fold extend_bbs bbox_vs g'
    in
       (new_bn_opt, ((vrn',ern',brn'), g'))
    end;

  val copy1_bbox = (apfst the) oo (copy_or_expand true)
  val expand1_bbox = snd oo (copy_or_expand false)

  fun fresh_namers_for g =
    (V.Rnm.mk_from_avoids (get_vnames g),
     E.Rnm.mk_from_avoids (get_enames g),
     B.Rnm.mk_from_avoids (get_bboxes g))

  fun fresh_expand1_bbox bn g =
    let val (_, graph) = expand1_bbox bn (fresh_namers_for g, g)
    in graph end;

  fun fresh_copy1_bbox bn g =
    let val (bname, (_, graph)) = copy1_bbox bn (fresh_namers_for g, g)
    in (bname, graph) end;

  structure BBoxCRnm = CompoundRenamingFun(
  struct
    structure Nm = B
    type obj = T
    val try_rename1 = try_rename1_bbox;
    val get_nameset = get_bboxes
  end);

  (*  *)
  fun rename_incl_bboxes (xrn,vrn,ern,brn) g =
      let
        val (xrn2,g') = CRnmX.rename xrn g
        val (vrn2,g'') = VertexCRnm.rename vrn g'
        val (ern2,g''') = EdgeCRnm.rename ern g''
        val (brn2,g'''') = BBoxCRnm.rename brn g'''
      in ((xrn2,vrn2,ern2,brn2),g'''') end;

  fun rename_apart_incl_bboxes from g =
      let
        val bad_xs = get_xnames from
        val bad_vs = get_vnames from
        val bad_es = get_enames from
        val bad_bs = get_bboxes from
        val g_xs = get_xnames g
        val g_vs = get_vnames g
        val g_es = get_enames g
        val g_bs = get_bboxes g
        val xrn = X.Rnm.mk (X.NSet.subtract g_xs bad_xs)
                           (X.NSet.union_merge g_xs bad_xs)
                           X.NTab.empty
        val vrn = V.Rnm.mk (V.NSet.subtract g_vs bad_vs)
                           (V.NSet.union_merge g_vs bad_vs)
                           V.NTab.empty
        val ern = E.Rnm.mk (E.NSet.subtract g_es bad_es)
                           (E.NSet.union_merge g_es bad_es)
                           E.NTab.empty
        val brn = B.Rnm.mk (B.NSet.subtract g_bs bad_bs)
                           (B.NSet.union_merge g_bs bad_bs)
                           B.NTab.empty
      in rename_incl_bboxes (xrn,vrn,ern,brn) g end;

  (* override OGraph functions *)
  (* Merge g1 into g2.
     (Replaces basic merge_by_vertices to include bboxes)
     Assumes edge-names are disjoint. Assumes bbox names disjoint.
     Assumes all edge-points from g1 are in g2 already (and copied bboxes skip edge-points)
     When an edge-point in g1 overlaps a node vertex in g2, if the
     edge-point is in a bangbox, then the bang-box doesn't extend to the
     node vertex. *)
  (* FIXME: implement this correctly
  fun merge_by_vertices g1 g2 =
      g2 |> OGraph.merge_by_vertices g1
         |> B.NTab.fold
              (fn (bbn,vset) => ???)
              (get_bbox_table g1);
  *)

  (* Asserts that all the vertices in vs have exactly the
   * !-boxes vs *)
  fun check_bboxes g bs (w as (_,_,vs,_)) =
    V.NSet.fold (fn v => fn bs =>
      if B.NSet.eq bs (get_bboxes_of g v) then bs
      else raise wire_exp ("Inconsistent !-boxes",g,w)) vs bs
  fun check_wire_bboxes g (w as (s,t,wvs,_)) =
    if is_wire_vertex g s then
      (if is_wire_vertex g t then
         (check_bboxes g (get_bboxes_of g s) w; w)
       else
         let
           val bs = get_bboxes_of g s
           val _ = check_bboxes g bs w
           val _ = if B.NSet.sub_set (get_bboxes_of g t) bs
                   then () else raise wire_exp ("Inconsistent !-boxes",g,w)
         in w end)
    else if is_wire_vertex g t then
      let
        val bs = get_bboxes_of g t
        val _ = check_bboxes g bs w
        val _ = if B.NSet.sub_set (get_bboxes_of g s) bs
                then () else raise wire_exp ("Inconsistent !-boxes",g,w)
      in w end
    else
      case V.NSet.get_local_bot wvs of
           NONE => w
         | SOME wv =>
              let
                val bs = get_bboxes_of g wv
                val _ = check_bboxes g bs w
                val _ = if B.NSet.sub_set (get_bboxes_of g s) bs
                        then () else raise wire_exp ("Inconsistent !-boxes",g,w)
                val _ = if B.NSet.sub_set (get_bboxes_of g t) bs
                        then () else raise wire_exp ("Inconsistent !-boxes",g,w)
              in w end

  fun assert_wire_coherent g = (OGraph.assert_wire_coherent g)
                             o (check_wire_bboxes g)

  fun is_wire_minimal g (s,t,wvs,_) =
    (V.NSet.is_empty wvs)
    orelse
    (case V.NSet.tryget_singleton wvs of
          NONE => false
        | SOME wv =>
            let
              val wire_bs = get_bboxes_of g wv
              val s_bs = get_bboxes_of g s
              val t_bs = get_bboxes_of g t
              val end_bs = B.NSet.union_merge s_bs t_bs
            in
              not (B.NSet.eq wire_bs end_bs)
            end)
  (* is_wire_normalised is unchanged from OGraph *)

  fun minimise_wire' (wire as (s,t,wvs,es)) g =
    if is_wire_vertex g s orelse is_wire_vertex g t then
      (* any wire !-boxes will be on s or t *)
      OGraph.minimise_wire' wire g
    else if B.NSet.is_empty (get_bboxes g) then
      (* treat as OGraph *)
      OGraph.minimise_wire' wire g
    else
      case V.NSet.get_local_bot wvs of
           (* already minimal *)
           NONE => OGraph.minimise_wire' wire g
         | SOME wv =>
             let
               val bs = get_bboxes_of g wv
               val edge_sufficient = B.NSet.is_empty bs orelse
                    (B.NSet.eq bs (B.NSet.union_merge (get_bboxes_of g s)
                                                      (get_bboxes_of g t)))
             in
               if edge_sufficient
               then OGraph.minimise_wire' wire g
               else
                 let
                   val (dir_and_data,_) = get_edge g ((the o E.NSet.get_local_bot) es)
                   val g      = g |> delete_wire wire
                   val (wv,g) = g |> add_vertex OVData.WVert
                   val wvset  = V.NSet.single wv
                   val g      = g |> B.NSet.fold (fn b => doadd_to_bbox b wvset) bs
                   val (e1,g) = g |> add_edge dir_and_data s wv
                   val (e2,g) = g |> add_edge dir_and_data wv t
                   val eset   = E.NSet.of_list [e1,e2]
                 in
                   ((s,t,wvset,eset), g)
                 end
             end
  fun minimise_wire wire g = let
    val _ = assert_wire_coherent g wire
  in
    if is_wire_minimal g wire
    then (wire,g)
    else minimise_wire' wire g
  end
  val do_minimise_wire = snd oo minimise_wire

  fun normalise_wire' (wire as (s,t,wvs,es)) g =
    if is_wire_vertex g s orelse is_wire_vertex g t then
      (* any wire !-boxes will be on s or t *)
      OGraph.minimise_wire' wire g
    else
      (* add two extra wire verts on internal wires *)
      let
        val (dir_and_data,_) = get_edge g ((the o E.NSet.get_local_bot) es)
        val bs = case V.NSet.get_local_bot wvs of
                      NONE => B.NSet.union_merge (get_bboxes_of g s)
                                                 (get_bboxes_of g t)
                    | SOME wv => get_bboxes_of g wv
        val g      = g |> delete_wire wire
        val (b1,g) = g |> add_vertex OVData.WVert
        val (b2,g) = g |> add_vertex OVData.WVert
        val wvset  = V.NSet.of_list [b1,b2]
        val g      = g |> B.NSet.fold (fn b => doadd_to_bbox b wvset) bs
        val (e1,g) = g |> add_edge dir_and_data s b1
        val (e2,g) = g |> add_edge dir_and_data b1 b2
        val (e3,g) = g |> add_edge dir_and_data b2 t
        val eset   = E.NSet.of_list [e1,e2,e3]
      in
        ((s,t,wvset,eset), g)
      end
  fun normalise_wire wire g = let
    val _ = assert_wire_coherent g wire
  in
    if is_wire_normalised g wire
    then (wire,g)
    else normalise_wire' wire g
  end
  val do_normalise_wire = snd oo normalise_wire

  fun minimise g = g |> fold do_minimise_wire (get_wire_list g)
  fun normalise g = g |> fold do_normalise_wire (get_wire_list g)

  fun plug_and_minimise g v1 v2 = let
    val (e,g') = plug g v1 v2
  in
    minimise_wire (get_wire_containing_edge g' e) g'
  end
  val do_plug_and_minimise = snd ooo plug_and_minimise
  fun plug_and_normalise g v1 v2 = let
    val (e,g') = plug g v1 v2
  in
    normalise_wire (get_wire_containing_edge g' e) g'
  end
  val do_plug_and_normalise = snd ooo plug_and_normalise

end; (* BangGraphFun *)

(* vim:et:sts=2:sw=2
*)
