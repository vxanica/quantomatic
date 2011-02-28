signature XML_PARSE_UTILS = 
sig 
  include XML
  exception bad_input_exp of string;
  (* NOTE: Markup.T = string * Properties.T *)

  val test_tag : string -> tree -> bool (* elem has tag = string *)
  val assert_tag : string -> tree -> unit (* raises *)

  val is_text : tree -> bool
  val is_elem : tree -> bool

  val get_text : tree -> string (* raises if elem *)
  val get_elem : tree -> Markup.T * tree list (* raises if text *)
  val get_children : tree -> tree list (* raises if text *)
  val get_the_child : tree -> tree (* raises if not a unique child *)
  val get_the_child_text : tree -> string (* raises if the unique child is not text *)
  val get_attributes : tree -> Properties.T (* raises if text *)
  val get_tag : tree -> string (* raises if text *)

  val filter_elems : string -> tree list -> tree list
  val lookup_first_elem : string -> tree list -> tree option
  val lookup_the_elem : string -> tree list -> tree option (* SOME if exactly one *)
  val get_first_elem : string -> tree list -> tree (* raises if text or none *)
  val get_the_elem : string -> tree list -> tree (* raises if not exactly one *)
end;

structure XML_Parse_Utils 
: XML_PARSE_UTILS  
= struct

open XML;

exception bad_input_exp of string;
	  		     
val tolower = String.map Char.toLower
val toupper = String.map Char.toUpper

fun is_text (Text _) = true | is_text _ = false;
fun is_elem (Elem _) = true | is_elem _ = false;

fun get_elem (Text _) = raise bad_input_exp "Can't get elem of text"
  | get_elem (Elem x) = x;

fun get_text (Text s) = s
  | get_text (Elem ((tag,_),_)) = raise bad_input_exp ("Expected text but saw <"^ tag ^"> element.");

fun get_tag (Text _) = raise bad_input_exp "Can't get tag of text"
  | get_tag (Elem ((tag, attr),children)) = tag;

fun get_attributes (Text _) = raise bad_input_exp "Can't get attribute of text"
  | get_attributes (Elem ((elem, attr),children)) = attr;

fun get_children (Text _) = raise bad_input_exp "Can't get children of text"
  | get_children (Elem ((elem, attr),children)) = children;

fun get_the_child (Text _) = raise bad_input_exp "Can't get unique child of text"
  | get_the_child (Elem ((elem, attr),[child])) = child
  | get_the_child (Elem ((elem, attr),_)) = raise bad_input_exp "Doesn't have unqiue child";

val get_the_child_text = get_text o get_the_child;

fun test_tag tag xml = is_elem xml andalso (tolower tag = tolower (get_tag xml));

fun assert_tag tag xml = 
    if test_tag tag xml then () else raise bad_input_exp ("found "^(if is_text xml then "Text"  else "<"^(get_tag xml)^">")^" but expected <"^tag^">.");

(* get the first element in the list  which is of type "wanted"
   return the rest of the list in the second coord
   if none is found either return NONE or fail depending 
   on value of boolean param force
*)
fun filter_elems tag trees = List.filter (test_tag tag) trees 

fun lookup_first_elem tag trees = List.find (test_tag tag) trees 
fun get_first_elem tag trees = 
    case lookup_first_elem tag trees of SOME x => x
       | NONE => raise bad_input_exp ("Element with tag <"^tag^"> not found.");

fun lookup_the_elem tag trees = 
    case List.filter (test_tag tag) trees 
      of [x] => SOME x
       | _ => NONE;
fun get_the_elem tag trees = 
    case lookup_the_elem tag trees 
      of NONE => raise bad_input_exp ("Unqiue <"^tag^"> tag not found.")
       | SOME x => x;

end