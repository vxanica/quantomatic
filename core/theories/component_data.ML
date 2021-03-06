(* *)
signature COMPONENT_DATA = 
sig
  datatype T = Unit
             | String of string
             | LinratAngleExpr of LinratAngleExpr.T;
  exception bad_format_exp of string;

  val xml_of : T -> XML.tree list
  val of_xml_unit : XML.tree list -> T
  val of_xml_string : XML.tree list -> T
  val of_xml_linrat : XML.tree list -> T

  val string_of : T -> string
  val of_string_unit : string -> T
  val of_string_string : string -> T
  val of_string_linrat : string -> T

  val pretty : T -> Pretty.T
end;

structure ComponentData : COMPONENT_DATA = 
struct
  datatype T = Unit
             | String of string
             | LinratAngleExpr of LinratAngleExpr.T;
  exception bad_format_exp of string;

  fun xml_of Unit = []
    | xml_of (String s) = [OutputStringXML.output s]
    | xml_of (LinratAngleExpr e) = [OutputLinratXML.output e];

  fun of_xml_unit _ = Unit
  fun of_xml_string [n] = (String (InputStringXML.input n) handle XML_Parse_Utils.bad_input_exp(s,_) => raise bad_format_exp s)
    | of_xml_string _ = raise bad_format_exp "Single XML Node expected"
  fun of_xml_linrat [n] = (LinratAngleExpr (InputLinratXML.input n) handle XML_Parse_Utils.bad_input_exp(s,_) => raise bad_format_exp s)
    | of_xml_linrat _ = raise bad_format_exp "Single XML node expected"

  fun string_of Unit = ""
    | string_of (String s) = s
    | string_of (LinratAngleExpr e) = Pretty.string_of (LinratAngleExpr.pretty e)

  fun of_string_unit _ = Unit
  fun of_string_string s = (String s)
  fun of_string_linrat e = (LinratAngleExpr (LinratAngleExpr.parse e))
      handle LinratAngleExpr.parse_exp => raise bad_format_exp ("\"" ^ e ^ "\" is not a valid linear rational expression")

  fun pretty Unit = Pretty.str ""
    | pretty (String s) = Pretty.quote (Pretty.str s)
    | pretty (LinratAngleExpr e) = LinratAngleExpr.pretty e
end;

(* TODO: Explain in more detail what this does. *)
(* Some kind of wrapper for data to put it into a single bigger globally 
   defined type, used to then talk to the GUI. *)
signature ELEMENT_COMPONENT_DATA_PARAM =
sig
  (* type of data, e.g. vertex data *)
  type data
  exception unknown_type_exp of string;

  (* get the type-string for the data, this tells the GUI how to handle it *)
  (* this avoids having to format the data *)
  val type_of : data -> string;
  (* Gets the Component Data value for this bit of data *)
  val cdata_of : data -> ComponentData.T;

  (* the default data *)
  val default_data : string -> data;

  val update : (ComponentData.T -> ComponentData.T) -> (data -> data);
end;

(* Basic implementation for things with no data *)
structure NoData_Param 
: ELEMENT_COMPONENT_DATA_PARAM where type data = unit 
= struct
  type data = unit
  exception unknown_type_exp of string;

  fun type_of () = "unit";

  fun cdata_of () = ComponentData.Unit;

  fun default_data "unit" = ()
    | default_data n = raise unknown_type_exp n;

  fun update _ = I;
end;

(* Adds OGraph semantics to a ELEMENT_COMPONENT_DATA_PARAM *)
functor OVertexComponentData_Param(
  structure VertexDataParam : ELEMENT_COMPONENT_DATA_PARAM
  structure OVData : OVERTEX_DATA
  sharing type OVData.IData.data = VertexDataParam.data
)
: ELEMENT_COMPONENT_DATA_PARAM
= struct 
  type data = OVData.data;
  exception unknown_type_exp = VertexDataParam.unknown_type_exp

  fun type_of (OVData.WVert) = "edge-point"
    | type_of (OVData.NVert d) = VertexDataParam.type_of d;

  fun cdata_of (OVData.WVert) = ComponentData.Unit
    | cdata_of (OVData.NVert d) = VertexDataParam.cdata_of d;

  fun default_data "edge-point" = OVData.WVert
    | default_data n = OVData.NVert (VertexDataParam.default_data n);

  fun update _ OVData.WVert = OVData.WVert
    | update upd (OVData.NVert d) = (OVData.NVert (VertexDataParam.update upd d));
end;

signature ELEMENT_COMPONENT_DATA =
sig
  include ELEMENT_COMPONENT_DATA_PARAM;

  val type_and_cdata_of : data -> (string * ComponentData.T);

  val type_and_xml_of : data -> string * (XML.tree list);
  val of_type_and_xml : (string * (XML.tree list)) -> data;
  val update_from_xml : (XML.tree list) -> (data -> data);

  val type_and_string_of : data -> string * string;
  val of_type_and_string : (string * string) -> data;
  val update_from_string : string -> (data -> data);
end;

functor ElementComponentData(Param : ELEMENT_COMPONENT_DATA_PARAM) : ELEMENT_COMPONENT_DATA =
struct
  open Param;
  local open ComponentData in

  fun type_and_cdata_of d = (type_of d,cdata_of d);

  fun type_and_xml_of d =
    let
      val (t,cd) = type_and_cdata_of d
      fun to_xml Unit = []
        | to_xml (String s) = [OutputStringXML.output s]
        | to_xml (LinratAngleExpr e) = [OutputLinratXML.output e]
    in
      (t,to_xml cd)
    end;

  fun update_from_xml xml =
    let
      fun xml_updater _ Unit = Unit
        | xml_updater [xml] (String _) = ((String (InputStringXML.input xml))
              handle XML_Parse_Utils.bad_input_exp (msg,_) => raise bad_format_exp msg)
        | xml_updater _            (String _) = raise bad_format_exp "String XML element expected"
        | xml_updater [xml] (LinratAngleExpr _) = ((LinratAngleExpr (InputLinratXML.input xml)) 
              handle XML_Parse_Utils.bad_input_exp (msg,_) => raise bad_format_exp msg)
        | xml_updater _     (LinratAngleExpr _) = raise bad_format_exp "Single XML element expected"
    in
      update (xml_updater xml)
    end;

  fun of_type_and_xml (t,xml) =
      update_from_xml xml (default_data t)

  fun type_and_string_of d =
    let
      val (t,cd) = type_and_cdata_of d
      fun to_string Unit = ""
        | to_string (String s) = s
        | to_string (LinratAngleExpr e) = Pretty.string_of (LinratAngleExpr.pretty e)
    in
      (t,to_string cd)
    end;

  fun update_from_string str =
    let
      fun string_updater _   Unit = Unit
        | string_updater str (String _) = (String str)
        | string_updater str (LinratAngleExpr _) = (LinratAngleExpr (LinratAngleExpr.parse str))
              handle LinratAngleExpr.parse_exp => raise bad_format_exp ("\"" ^ str ^ "\" is not a valid linear rational expression")
    in
      update (string_updater str)
    end;

  fun of_type_and_string (t,str) =
      update_from_string str (default_data t)

  end; (* local open *)
end;

structure EmptyElementComponentData = ElementComponentData(NoData_Param);


(* vi:sts=2:ts=2:sw=2:et
*)
