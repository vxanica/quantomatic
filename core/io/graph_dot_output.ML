signature OUTPUT_DOT = OUTPUT where type T = string;

functor OutputSStrNameDot(N: SSTR_NAME) : OUTPUT_DOT
= struct
  type T = string;
  type data = N.name;
  fun output s = N.string_of_name s;
end;

signature DOT_STYLE =
sig
  type vdata;
  val style_for_ivertex_data : vdata -> string
end

functor OutputGraphDot(
  structure Graph : BANG_GRAPH
  structure DotStyle : DOT_STYLE
  sharing type DotStyle.vdata = Graph.OVData.IData.data
) : OUTPUT_DOT =
struct
  structure Graph = Graph;
  type T = string;
  type data = Graph.T;
  fun node_block graph = let
    val boxtab = Graph.get_bbox_table graph
    fun sty nm = case Graph.get_vertex graph nm
                   of (Graph.OVData.NVert data, _) => " " ^ (DotStyle.style_for_ivertex_data data)
                    | (Graph.OVData.WVert, _) => " [style=filled,fillcolor=gray,shape=box,width=0,height=0,fontcolor=white]"
    fun f nm list = (V.pretty_name nm)::
                    (Pretty.str (sty nm))::
                    (Pretty.str ";\n")::
                    list
    fun box_f (box,vset) list = 
      (Pretty.str "subgraph cluster_")::
      (B.pretty_name box)::
      (Pretty.str " {\n")::
      (V.NSet.fold_rev f vset
      (Pretty.str "}\n"::list))
  in B.NTab.fold box_f boxtab (V.NSet.fold_rev f (Graph.get_unbboxed graph) [])
  end;
  
  fun edge_block graph = let
    fun f nm list = let
      val (_, (s,t)) = Graph.get_edge graph nm
    in (V.pretty_name s)::
       (Pretty.str " -> ")::
       (V.pretty_name t)::
       (Pretty.str " [label=")::
       (E.pretty_name nm)::
       (Pretty.str "];\n")::list
    end
  in E.NSet.fold_rev f (Graph.get_enames graph) []
  end;
  
  fun output graph = Pretty.string_of (Pretty.block (
    [Pretty.str "digraph G {\n"] @
    node_block graph @
    edge_block graph @
    [Pretty.str "}\n"]
  ));
end
