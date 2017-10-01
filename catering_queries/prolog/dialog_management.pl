/** <module> dialog_management

  Copyright (C) 2017 Sascha Jongebloed
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
      * Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.
      * Neither the name of the <organization> nor the
        names of its contributors may be used to endorse or promote products
        derived from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@author Sascha Jongebloed 
@license BSD
*/

% defining functions
:- module(dialog_management,
    [
      assert_dialog_element/1,
      create_dialog_element/2,
      extract_guest_id/2,
      extract_query_element/2,
      assert_query_properties/2,
      create_query_of_type/3,
      extract_only_type/3,
      extract_only_type_help/4,
      run_the_rules/0,
      test_dialog_element/0,
      modified_to_current/0,
      modified_to_current_class/0,
      modified_to_current_properties/0,
      get_unmodified_property_name/2,
      get_unmodified_class_name/2,
      get_modified_property/1,
      get_modified_class/1,
      add_hack/0,
      subtract_hack/0
    ]).

:- rdf_meta get_modified_property(?),
			get_unmodified_property_name(?,r),
      get_unmodified_class_name(?,r),
			modified_to_current.

%% assert_dialog_element(+JSONString)
%
% Asserts a dialog intention object into the knowledge base
% and aligns it by running the swrl rule
%
% @JSONString JSONString containing dialog intention 
%
assert_dialog_element(JSONString) :-
    create_dialog_element(JSONString,_),
    run_the_rules,
    ignore(modified_to_current),
    ignore(add_hack),
    ignore(subtract_hack). %# if there are modified properties, 

%% create_dialog_element(+JSONString,-DialogElement)
%
% Parses the JSONString containing the dialog intention to 
% create the representation in the knowledge base
%
% @JSONString JSONString containing dialog intention 
% @DialogElement Representaiton of the dialog intention
%
create_dialog_element(JSONString,DialogElement) :-
    atom(JSONString),
    rdf_instance_from_class(knowrob:'DialogElement', DialogElement),
    extract_guest_id(JSONString,GuestID),
    rdf_assert(DialogElement,knowrob:'guestId',literal(type(xsd:string,GuestID))),
    extract_query_element(JSONString,Query),
    rdf_assert(DialogElement,knowrob:'dialogQuery',Query).

%% extract_guest_id(+JSONString,-GuestID)
%
% Extracts guest ID from the json string
%
% @JSONString JSONString containing dialog intention 
% @GuestID Guest ID from the json string
%
extract_guest_id(JSONString,GuestID) :-
	atomic_list_concat([RelevantGuestString|_], ',', JSONString),
	atom_concat('{guestId:', GuestID, RelevantGuestString).

%% extract_query_element(+JSONString,-QueryInstance)
%
% Extracts the dialog intention representation
%
% @JSONString JSONString containing dialog intention 
% @QueryInstance Instance of the dialog intention
%
extract_query_element(JSONString,QueryInstance) :-
	atomic_list_concat([_|[SecondHalf|_]], ',query:{', JSONString),
	sub_atom(SecondHalf, 0, _, 2, QueryString), % remove unneeded '}}'
	atomic_list_concat(QueryElements, ',', QueryString),
  create_query_of_type(QueryElements,CleanedQueryElements,QueryInstance),
	assert_query_properties(CleanedQueryElements,QueryInstance).

%% create_query_of_type(+QueryElements,-CleanedQueryElements,-QueryInstance) 
%
% Creates a instants of the dialogQuery object denoted by the QueryElements Stirngs 
% (strings of the form key:value)
%
% @QueryElements JSONString containing dialog intention 
% @CleanedQueryElements Instance of the dialog intention
% @QueryInstance An instance of the query
%
create_query_of_type(QueryElements,CleanedQueryElements,QueryInstance) :-
    extract_only_type(QueryElements,Type,CleanedQueryElements),
    get_class_name(Type,ClassName),
    atom_concat('http://knowrob.org/kb/knowrob.owl#', ClassName, FullClassName),
    rdf_instance_from_class(FullClassName,QueryInstance).

%% extract_only_type(+QueryElements,-Type,-CleanedQueryElements)
%
% extracts only the type string of the key-value-string
%
% @QueryElements key-value-Strings containing the infos of the query
% @Type Type of the dialog query
% @CleanedQueryElements Rest of the strings without the type:Type-Value string
%
extract_only_type(QueryElements,Type,CleanedQueryElements) :-
  extract_only_type_help(QueryElements,[],Type,CleanedQueryElements).

extract_only_type_help([],TillNow,Type,CleanedQueryElements) :-
  write('Query has no type'),
  Type = 'DialogQuery',
  CleanedQueryElements = TillNow.

extract_only_type_help([QueryElement|Rest],TillNow,Type,CleanedQueryElements) :-
  atomic_list_concat([Property|[Value|_]],':',QueryElement),
  (Property = type ->
      (Type = Value,
        append(TillNow,Rest,CleanedQueryElements));
      (append([QueryElement],TillNow,TillNowNew),
        extract_only_type_help(Rest,TillNowNew,Type,CleanedQueryElements))
    ).

%% assert_query_properties(+QueryElements,+DialogQuery)
%
% Asserts the informations in the queryelements strings 
% to the instance of the DialogQuery
%
% @QueryElements key-value-Strings containing the infos of the query
% @DialogQuery Instance of the dialog query
%
assert_query_properties([],_).
assert_query_properties([QueryElement|Rest],DialogQuery) :-
	Ns = knowrob,
	atomic_list_concat([Property|[Value|_]],':',QueryElement),
	rdf_global_id(Ns:Property, PropertyName),
	rdf_assert_with_literal(DialogQuery,PropertyName,Value),
	assert_query_properties(Rest,DialogQuery).

%% rdf_assert_with_literal(S,P,Value)
%
% Helperfunction to assert S,P,Value triple with P a DatatypeProperty
%
% @S Subject
% @P Predicate
% @Value Value
%
rdf_assert_with_literal(S,P,Value) :-
  (atom_number(Value,ValueX)-> true ; ValueX = Value),
  rdf_has(P, rdf:type, owl:'DatatypeProperty'),
  (  rdf_phas(P, rdfs:range, Range)
  -> assert_temporal_part(S, P, literal(type(Range,ValueX)))
  ;  assert_temporal_part(S, P, literal(ValueX))
  ), !.

%% run_the_rules
%
% Runs the rules to interprete the Dialog Intention object
%
run_the_rules :-
    ignore((
      swrl:rdf_swrl_name(Descr3,'IncreaseCake'),
      rdf_has(Descr3, knowrob:swrlActionVariable, VarLiteral2),
      strip_literal_type(VarLiteral2, Var2),
      rdf_swrl_project(Descr3, [var(Var2,Act2)]),
      rdf_swrl_unload(Descr3))),
    ignore((
      swrl:rdf_swrl_name(Descr,'SetCakeWithCustomer'),
      rdf_has(Descr, knowrob:swrlActionVariable, VarLiteral),
      strip_literal_type(VarLiteral, Var),
      rdf_swrl_project(Descr, [var(Var,Act)]),
      rdf_swrl_unload(Descr))),
    ignore((
      swrl:rdf_swrl_name(Descr2,'SetLocation'),
      rdf_has(Descr2, knowrob:swrlActionVariable, VarLiteral1),
      strip_literal_type(VarLiteral1, Var1),
      rdf_swrl_project(Descr2, [var(Var1,Act1)]),
      rdf_swrl_unload(Descr2))),
    ignore((
      swrl:rdf_swrl_name(Descr4,'DecreaseCake'),
      rdf_has(Descr4, knowrob:swrlActionVariable, VarLiteral3),
      strip_literal_type(VarLiteral3, Var3),
      rdf_swrl_project(Descr4, [var(Var3,Act3)]),
      rdf_swrl_unload(Descr4))).

%% get_class_name(+Type, -ClassName)
% MSp
% converts first letter of Type into capital letter
get_class_name(Type, ClassName) :-
    not((var(Type), var(ClassName))),
    sub_atom(Type,0,1,_,C), char_code(C,I), 96<I, I<123
    -> J is I-32, char_code(D,J), sub_atom(Type,1,_,0,Sub), atom_concat(D,Sub,ClassName)
    ; ClassName = Type.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Functions to convert modified names to real names %%%%%%%%%%%%%%%%%%%%%%

modified_to_current :-
  ignore(modified_to_current_class),
  ignore(modified_to_current_properties).

modified_to_current_class :-
    forall(
      (
        get_unmodified_class_name(MClass,Class),
        rdf_has(S,rdf:type,MClass)),
      (
        rdf_assert(S,rdf:type,Class),
        rdf_retractall(S,rdf:type,MClass))
      ).

modified_to_current_properties :-
    forall(
    (
      get_modified_property(MProp),
      get_unmodified_property_name(MProp,Prop),
      rdf_has(S,MProp,O)
    ),
    (
      (rdf_has(S,Prop,O) -> 
        rdf_retractall(S,Prop,O);
        true),
      rdf_assert(S,Prop,O)
    )),

    forall(
    (
      get_modified_property(MProp)
    ),
    (
      rdf_retractall(S,MProp,O)
    )),
    
    forall(
    (
      get_modified_property(MProp2),
      get_unmodified_property_name(MProp2,Prop2),
      rdf_has(SOld,knowrob:'temporalProperty',MProp2)
    ),
    (
      rdf_retractall(SOld,knowrob:'temporalProperty',MProp2),
      rdf_assert(SOld,knowrob:'temporalProperty',Prop2)
    )).
    %forall(
    %(
    %  rdf_has(SOld,swrl:'propertyPredicate',MProp)
    %),
    %(
    %  rdf_retractall(SOld,swrl:'propertyPredicate',MProp),
    %  rdf_assert(SOld,swrl:'propertyPredicate',Prop)
    %)).

get_unmodified_property_name(MProp,Prop) :-
	sub_string(MProp,0,_,9,PropString),
	name(Prop,PropString).

get_modified_property(P) :-
	rdf_equal(P,knowrob:'orderedAmount_modified').

get_modified_property(P) :-
  rdf_equal(P,knowrob:'guestId_modified').

get_modified_property(P) :-
  rdf_equal(P,knowrob:'guestName_modified').

get_modified_property(P) :-
  rdf_equal(P,knowrob:'visit_modified').

get_modified_property(P) :-
  rdf_equal(P,knowrob:'hasOrder_modified').

get_modified_property(P) :-
  rdf_equal(P,knowrob:'itemName_modified').

get_modified_property(P) :-
  rdf_equal(P,knowrob:'deliveredAmount_modified').

get_modified_property(P) :-
  rdf_equal(P,knowrob:'locatedAt_modified').

get_modified_class(ClassName) :-
  rdf_equal(ClassName,knowrob:'Customer_modified').


get_modified_class(ClassName) :-
  rdf_equal(ClassName,knowrob:'Visit_modified').

get_modified_class(ClassName) :-
  rdf_equal(ClassName,knowrob:'Order_modified').

get_unmodified_class_name(MClass,Class) :-
  (rdf_equal(MClass,knowrob:'Customer_modified') ->
    rdf_equal(Class,knowrob:'Customer');false);
  (rdf_equal(MClass,knowrob:'Visit_modified') ->
    rdf_equal(Class,knowrob:'Visit');false);
  (rdf_equal(MClass,knowrob:'Order_modified') ->
    rdf_equal(Class,knowrob:'Order');false);
  (rdf_equal(MClass,knowrob:'CheckedDialogElement_modified') ->
    rdf_equal(Class,knowrob:'CheckedDialogElement');false).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Hacks for add and subtract rules in swrl %%%%%%%%%%%%%%%%%%%%%

add_hack :-
  forall((
  rdf_has(S,knowrob:'orderedAmount',literal(type(xsd:integer,Amount))),
  rdf_has(S,knowrob:'orderedAmount_add',literal(type(xsd:integer,Add)))),
  (NewAmount is Amount + Add,
  rdf_retractall(S,knowrob:'orderedAmount',literal(type(xsd:integer,Amount))),
  rdf_retractall(S,knowrob:'orderedAmount_add',literal(type(xsd:integer,Add))),
  rdf_assert(S,knowrob:'orderedAmount',literal(type(xsd:integer,NewAmount))))).

subtract_hack :- 
  forall((
  rdf_has(S,knowrob:'orderedAmount',literal(type(xsd:integer,Amount))),
  rdf_has(S,knowrob:'orderedAmount_subtract',literal(type(xsd:integer,Sub)))),
  (NewAmount is Amount - Sub,
  rdf_retractall(S,knowrob:'orderedAmount',literal(type(xsd:integer,Amount))),
  rdf_retractall(S,knowrob:'orderedAmount_subtract',literal(type(xsd:integer,Add))),
  rdf_assert(S,knowrob:'orderedAmount',literal(type(xsd:integer,NewAmount))))).

	
%%%%%%%%%%%%%%%%

test_dialog_element :-
  assert_dialog_element('{guestId:1,query:{type:setCake,amount:1,guestName:arthur}}').