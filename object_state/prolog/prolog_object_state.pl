/** <module> prolog_object_state

@author Lukas Samel, Michael Speer, Sascha Jongebloed 
@license BSD
*/

% defining functions
:- module(prolog_object_state,
    [
      close_object_state/1,
      connect_frames1/1,
      connect_frames2/1,
      connect_frames3/2,
      connect_frames4/1,
      connect_frames5/2,
      connect_frames/3,
      create_fluent_pose/2,
      create_object_state/9,
      create_object_state_with_close/9,
      create_object_name/2,
      create_temporal_name/2,
      disconnect_frames/2,
      dummy_perception2/1,
      dummy_perception/1,
      dummy_perception_with_close/1,
      dummy_close/1,
      dummy_perception_with_close2/1,
      isConnected/2,
      get_fluent_pose/3,
      get_object_infos/5,
      get_object_infos/6,
      get_object_infos/8,
      get_tf_infos/4,
      holds_suturo/2,
      seen_since/3
    ]).

:- dynamic
        isConnected/2.

:- rdf_meta create_object_state(r,r,r,r,r,r,r,r,?),
      close_object_state(r,r,r,r,r,r,r,r,?),
      create_object_state_with_close(r,r,r,r,r,r,r,r,?),
      create_object_name(r,?),
      create_temporal_name(r,?),
      get_object_infos(r,?,?,?,?),
      get_object_infos(r,?,?,?,?,?),
      get_object_infos(r,?,?,?,?,?,?,?),
      connect_frames(r,r,r),
      disconnect_frames(r,r),
      seen_since(r,r,r),
      holds_suturo(r,?),
      print_shit(r),
      dummy_perception(?).

%importing external libraries
:- use_module(library('semweb/rdf_db')).
:- use_module(library('semweb/rdfs')).
:- use_module(library('owl')).
:- use_module(library('owl_parser')).
:- use_module(library('knowrob_coordinates')).
:- use_module(library('knowrob_temporal')).
:- use_module(library('knowrob_objects')).
:- use_module(library('rdfs_computable')).
:- use_module(library('knowrob_owl')).

%registering namespace
:- rdf_db:rdf_register_ns(knowrob,  'http://knowrob.org/kb/knowrob.owl#',  [keep(true)]).
:- rdf_db:rdf_register_ns(srdl2, 'http://knowrob.org/kb/srdl2.owl#', [keep(true)]).
:- rdf_db:rdf_register_ns(srdl2comp, 'http://knowrob.org/kb/srdl2-comp.owl#', [keep(true)]).
:- rdf_db:rdf_register_ns(srdl2cap, 'http://knowrob.org/kb/srdl2-cap.owl#', [keep(true)]).
:- rdf_db:rdf_register_ns(map_obj, 'http://knowrob.org/kb/ccrl2_map_objects.owl#', [keep(true)]).
:- rdf_db:rdf_register_ns(map_obj, 'http://knowrob.org/kb/ccrl2_map_objects.owl#', [keep(true)]).
:- rdf_db:rdf_register_ns(suturo_obj, 'package://object_state/owl/suturo_object.owl#', [keep(true)]).
:- owl_parse('package://knowrob_common/owl/knowrob.owl').
:- owl_parse('package://knowrob_map_data/owl/ccrl2_semantic_map.owl').
 
%% create_object_state(+Name, +Pose, +Type, +FrameID, +Width, +Height, +Depth, +Begin, -ObjInst) is probably det.
% Create the object representations in the knowledge base
% Argument 'Type' specifies perceptions classification of the object
% 
% @param Name describes the class of the object
% @param PoseAsList The pose of the object stored in a list of lists
% @param Type The type of the object (see ObjectDetection.msg)
% @param FrameID reference frame of object
% @param Width The width of the object
% @param Height The height of the object
% @param Depth The depth of the object
% @param Interval A list containing the start time and end time of a temporal
% @param ObjInst The created object instance (optional:to be returned)
create_object_state(Name, Pose, Type, FrameID, Width, Height, Depth, [Begin], ObjInst) :- 
    create_object_name(Name, FullName),
    (owl_has(ObjInst,rdf:type,FullName) -> true; rdf_instance_from_class(FullName, ObjInst)), 
    create_fluent(ObjInst, Fluent),
    rdf_assert(Fluent, knowrob:'typeOfObject', literal(type(xsd:integer, Type))),
    rdf_assert(Fluent, knowrob:'frameOfObject', literal(type(xsd:string, FrameID))),
    rdf_assert(Fluent, knowrob:'widthOfObject', literal(type(xsd:float, Width))),
    rdf_assert(Fluent, knowrob:'heightOfObject',literal(type(xsd:float, Height))),
    rdf_assert(Fluent, knowrob:'depthOfObject', literal(type(xsd:float, Depth))),
    create_fluent_pose(Fluent, Pose).


%% create_object_state_with_close(+Name, +Pose, +Type, +Frame, +Width, +Height, +Depth, (+)[Begin], -ObjInst)
% LSa, MSp
% Creates a fluent and closes the corresponding old TemporalPart.
create_object_state_with_close(Name, Pose, Type, Frame, Width, Height, Depth, [Begin], ObjInst) :-
    atom_concat('/', Name, ChildFrameID),
    not(isConnected(_ ,ChildFrameID)) ->
    ignore(close_object_state(Name)),
    create_object_state(Name, Pose, Type, Frame, Width, Height, Depth, [Begin], ObjInst);
    false.


%% create_fluent_pose(+Fluent, +Pose)
% MSp
% @param Fluent temporal part of object
% @param Pose list of lists [[3],[4]] position and orientation
create_fluent_pose(Fluent, [[PX, PY, PZ], [OX, OY, OZ, OW]]) :-
    rdf_assert(Fluent, knowrob:'xPosOfObject', literal(type(xsd:float, PX))),
    rdf_assert(Fluent, knowrob:'yPosOfObject', literal(type(xsd:float, PY))),
    rdf_assert(Fluent, knowrob:'zPosOfObject', literal(type(xsd:float, PZ))),
    rdf_assert(Fluent, knowrob:'xOriOfObject', literal(type(xsd:float, OX))),
    rdf_assert(Fluent, knowrob:'yOriOfObject', literal(type(xsd:float, OY))),
    rdf_assert(Fluent, knowrob:'zOriOfObject', literal(type(xsd:float, OZ))),
    rdf_assert(Fluent, knowrob:'wOriOfObject', literal(type(xsd:float, OW))).


%% close_object_state(+Name) is probably det.
% SJo
% Closes the interval of a holding fluent 
% @param Name describes the class of the object
close_object_state(Name) :- 
    create_object_name(Name, FullName),
    owl_has(Obj, rdf:type,FullName),    
    fluent_assert_end(Obj,P).
    

%% create_object_name(+Name,-FullName) is det.
% LSa
% Appends Name to the knowrob domain.
% @param Name content to be appended to the namespace
% @preturns FullName the concatenated string
create_object_name(Name, FullName) :-
    atom_concat('http://knowrob.org/kb/knowrob.owl#', Name, FullName).


%% create_temporal_name(+FullName, -FullTemporalName) is det.
%
% @param FullName full object name without temporal stamp  perception 
% @returns FullTemporalName the concatenated string including the temporal stamp
create_temporal_name(FullName, FullTemporalName) :-
    atom_concat(FullName,'@t_i', FullTemporalName).


%% get_object_infos(+Name, -FrameID, -Height, -Width, -Depth)
% 
get_object_infos(Name, FrameID, Height, Width, Depth) :-
    get_object_infos(Name, FrameID, _, _, _, Height, Width, Depth).


%% get_object_infos(+Name, -FrameID, -Timestamp, -Height, -Width, -Depth)
% 
get_object_infos(Name, FrameID, Timestamp, Height, Width, Depth) :-
    get_object_infos(Name, FrameID, _, Timestamp, _, Height, Width, Depth).


%% get_object_infos(+Name, -FrameID, -Type, -Timestamp, -Pose, -Height, -Width, -Depth)
% LSa, MSp
% @param Name name of the object
% @param FrameID reference frame of object pose
% @param Timestamp start time of most recent perception
% @param Type type of the object
% @param Pose list of [Position, Orientation] of object
% @param Height height of object
% @param Width width of object
% @param Depth depth of object
get_object_infos(Name, FrameID, Type, Timestamp, [Position, Orientation], Height, Width, Depth) :-
    owl_has(Obj,rdf:type,Name),
    holds_suturo(Obj, Fluent),
    owl_has(Fluent, knowrob:'frameOfObject', literal(type(xsd:string,FrameID))),
    owl_has(Fluent, knowrob:'heightOfObject', literal(type(xsd:float,Height))), 
    owl_has(Fluent, knowrob:'widthOfObject', literal(type(xsd:float,Width))),
    owl_has(Fluent, knowrob:'depthOfObject', literal(type(xsd:float,Depth))),
    owl_has(Fluent, knowrob:'typeOfObject', literal(type(xsd:integer,Type))),
    get_fluent_pose(Fluent, Position, Orientation),
    owl_has(Fluent,knowrob:'temporalExtend',I),
    owl_has(I, knowrob:'startTime', Timepoint),
    create_timepoint(Time, Timepoint),
    atom_number(Time, Timestamp),
    number(Timestamp).


%% seen_since(+Name, +FrameID, +TimeFloat) --> true/false
%  MSp
%  @param Name name of the object in database
%  @param FrameID reference frame of object
%  @param TimeFloat timestamp to be asserted
seen_since(Name, FrameID, TimeFloat) :-
    get_object_infos(Name, FrameID, _, Timestamp, _, _, _, _),
    TimeFloat < Timestamp;
    close_object_state(Name).


%% get_tf_infos(-Name, -FrameID, -Position, -Orientation)
% LSa
% A function to bundle the required information for the TF-broadcaster.
% @param Name 
% @param FrameID 
% @param Position position of object in frame
% @param Orientation orientation of object in frame
get_tf_infos(Name, FrameID, Position, Orientation) :-
    owl_has(Obj,rdf:type,FullName),
    create_object_name(Name, FullName),
    holds_suturo(Obj, Fluent),
    owl_has(Fluent, knowrob:'frameOfObject', literal(type(xsd:string,FrameID))),
    get_fluent_pose(Fluent, Position, Orientation).


%% get_fluent_pose(Fluent, [PX, PY, PZ],[OX, OY, OZ, OW])
% MSp
get_fluent_pose(Fluent, [PX, PY, PZ],[OX, OY, OZ, OW]) :-
    owl_has(Fluent, knowrob: 'xPosOfObject', literal(type(xsd: float, PX))),
    owl_has(Fluent, knowrob: 'yPosOfObject', literal(type(xsd: float, PY))),
    owl_has(Fluent, knowrob: 'zPosOfObject', literal(type(xsd: float, PZ))),
    owl_has(Fluent, knowrob: 'xOriOfObject', literal(type(xsd: float, OX))),
    owl_has(Fluent, knowrob: 'yOriOfObject', literal(type(xsd: float, OY))),
    owl_has(Fluent, knowrob: 'zOriOfObject', literal(type(xsd: float, OZ))),
    owl_has(Fluent, knowrob: 'wOriOfObject', literal(type(xsd: float, OW))).


%% holds_suturo(+ObjInst, -Fluent)
% Custom built holds, since the provided holds does not work.
holds_suturo(ObjInst, Fluent) :-
    owl_has(ObjInst,knowrob:'temporalParts',Fluent),
    owl_has(Fluent,knowrob:'temporalExtend',I),
    current_time(Now),
    interval_during([Now,Now],I).


%% connect_frames(+ParentFrameID, +ChildFrameID, +Pose)
% LSa
% A small function to connect two given frames.
connect_frames(ParentFrameID, ChildFrameID, Pose) :-
	atom_concat('/', Name, ChildFrameID),
  atom_concat('http://knowrob.org/kb/knowrob.owl#', Name, FullName),
  get_object_infos(FullName, _, Type, _, _, Height, Width, Depth),
  create_object_state_with_close(Name, Pose, Type, ParentFrameID, Width, Height, Depth, [Begin], ObjInst),
  assert(isConnected(ParentFrameID, ChildFrameID)).


%% disconnect_frames(+ParentFrameID, +ChildFrameID)
% LSa
% A simple function to disconnect two given frames.
disconnect_frames(ParentFrameID, ChildFrameID) :-
  retract(isConnected(ParentFrameID, ChildFrameID)).


%%
% Dummy object_state
dummy_perception(Name) :-
	 create_object_state(Name, [[5.0,4.0,3.0],[6.0,7.0,8.0,9.0]], 1.0, '/odom_combined', 20.0, 14.0, 9.0, Begin, ObjInst).


dummy_perception_with_close(Name) :-
	 create_object_state_with_close(Name, [[9.0,6.0,2.0],[9.0,1.0,5.0,7.0]], 1.0, '/odom_combined', 20.0, 14.0, 9.0, Begin, ObjInst).


dummy_perception_with_close2(Name) :-
	 create_object_state_with_close(Name, [[3.0,2.0,1.0],[7.0,7.0,7.0,7.0]], 1.0, '/odom_combined', 20.0, 14.0, 9.0, Begin, ObjInst).


dummy_close(Name) :-
	close_object_state(+Name).

% Dummy object_state
dummy_perception2(Egal) :-
   create_object_state_with_close('carrot1', [[5.0,4.0,3.0],[6.0,7.0,8.0,9.0]], 1.0, '/odom_combined', 20.0, 14.0, 9.0, Begin, ObjInst).

%% connect_frames1(+Name)
% LSa
% Test function for documentation. Should not be used elsewhere.
% DO NOT MODIFY - REFERENCED IN DOCUMENTARY.
connect_frames1(Name) :-
create_object_state(Name, [[5.0,4.0,3.0],[6.0,7.0,8.0,9.0]], 1.0, '/odom_combined', 20.0, 14.0, 9.0, Begin, ObjInst).

%% connect_frames2(+Name)
% LSa
% Test function for documentation. Should not be used elsewhere.
% DO NOT MODIFY - REFERENCED IN DOCUMENTARY.
connect_frames2(Name) :-
   create_object_state_with_close(Name, [[5.0,4.0,3.0],[6.0,7.0,8.0,9.0]], 1.0, '/odom_combined', 20.0, 14.0, 9.0, Begin, ObjInst).

%% connect_frames3(+ParentFrameID, +ChildFrameID)
% LSa
% Test function for documentation. Should not be used elsewhere.
% DO NOT MODIFY - REFERENCED IN DOCUMENTARY.
connect_frames3(ParentFrameID, ChildFrameID) :-
   disconnect_frames('/turtle1', '/carrot1').

%% connect_frames4(+Name)
% LSa
% Test function for documentation. Should not be used elsewhere.
% DO NOT MODIFY - REFERENCED IN DOCUMENTARY.
connect_frames4(Name) :-
   create_object_state_with_close(Name, [[8.0,7.0,7.0],[6.0,7.0,8.0,9.0]], 1.0, '/odom_combined', 20.0, 14.0, 9.0, Begin, ObjInst).

%% connect_frames5(+ParentFrameID, +ChildFrameID)
% LSa
% Test function for documentation. Should not be used elsewhere.
% DO NOT MODIFY - REFERENCED IN DOCUMENTARY.
connect_frames5(ParentFrameID, ChildFrameID) :-
   atom_concat('/', ParentFrameID, UsableParentFrameID),
   atom_concat('/', ChildFrameID, UsableChildFrameID),
   connect_frames(UsableParentFrameID, UsableChildFrameID, [[8.0,7.0,7.0],[6.0,7.0,8.0,9.0]]).
