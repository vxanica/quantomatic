signature RGB_UNIFIABLE_DATA =    
sig
  datatype node = Red | Green | Blue;
  include UNIFIABLE_DATA
  sharing type data = node;
end;

structure RGB_VertexData
: RGB_UNIFIABLE_DATA
= struct
  datatype node = Red | Green | Blue;
  type data = node;
  
  fun as_int Red = 0
    | as_int Green = 1
    | as_int Blue = 2
  
  fun data_ord (d1,d2) = int_ord (as_int d1, as_int d2)
  fun data_eq (n1, n2) = case data_ord (n1, n2) of EQUAL => true | _ => false;
  fun pretty_data Red   = Pretty.str "Red"
    | pretty_data Green = Pretty.str "Green"
    | pretty_data Blue  = Pretty.str "Blue";
  val print_data = Pretty.writeln o pretty_data;
    
  fun match_data pair m = if data_eq pair then SOME m else NONE
  fun unify_data _ _ = SOME ();
    
  type subst = unit;
  val empty_subst = ();
  fun compose_subst _ = ();
  fun subst_in_data _ d = d;  
  
  fun pretty_subst _ = Pretty.str "";
  val print_subst = Pretty.writeln o pretty_subst;
  
  val default_data = Red;
  
  structure Sharing = struct type data = data; type subst = subst; end;
end;


(*  *)
structure RGB_VertexComponentData_Param
: ELEMENT_COMPONENT_DATA_PARAM where type data = RGB_VertexData.data
= struct 
  type data = RGB_VertexData.data;
  exception unknown_type_exp of string;

  fun type_of RGB_VertexData.Red = "Red"
    | type_of RGB_VertexData.Green = "Green"
    | type_of RGB_VertexData.Blue = "Blue";

  fun cdata_of _ = ComponentData.Unit;

  fun default_data "Red" = RGB_VertexData.Red
    | default_data "Green" = RGB_VertexData.Green
    | default_data "Blue" = RGB_VertexData.Blue
    | default_data n = raise unknown_type_exp n;

  fun update _ = I;
end;
