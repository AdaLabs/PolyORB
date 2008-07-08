------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                       R T C O R B A . H E L P E R                        --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--         Copyright (C) 2004-2007, Free Software Foundation, Inc.          --
--                                                                          --
-- This specification is derived from the CORBA Specification, and adapted  --
-- for use with PolyORB. The copyright notice above, and the license        --
-- provisions that follow apply solely to the contents neither explicitely  --
-- nor implicitely specified by the CORBA Specification defined by the OMG. --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 51 Franklin Street, Fifth    --
-- Floor, Boston, MA 02111-1301, USA.                                       --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

-------------------------------------------------
--  This file has been generated automatically
--  by IDLAC version 2.3.0w.
--
--  Do NOT hand-modify this file, as your
--  changes will be lost when you re-run the
--  IDL to Ada compiler.
-------------------------------------------------
pragma Style_Checks ("NM32766");

with CORBA.Object;
with PolyORB.Any;
with CORBA;
pragma Elaborate_All (CORBA);

package RTCORBA.Helper is

   TC_NativePriority : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.NativePriority;

   function From_Any (C : PolyORB.Any.Any_Container'Class) return RTCORBA.NativePriority;

   function To_Any
     (Item : RTCORBA.NativePriority) return CORBA.Any;

   TC_Priority : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.Priority;

   function From_Any (C : PolyORB.Any.Any_Container'Class) return RTCORBA.Priority;

   function To_Any
     (Item : RTCORBA.Priority) return CORBA.Any;

   TC_ThreadpoolId : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.ThreadpoolId;

   function From_Any (C : PolyORB.Any.Any_Container'Class) return RTCORBA.ThreadpoolId;

   function To_Any
     (Item : RTCORBA.ThreadpoolId) return CORBA.Any;
   function Wrap (X : access RTCORBA.ThreadpoolLane) return PolyORB.Any.Content'Class;

   TC_ThreadpoolLane : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.ThreadpoolLane;

   function To_Any
     (Item : RTCORBA.ThreadpoolLane) return CORBA.Any;

   TC_IDL_SEQUENCE_RTCORBA_ThreadpoolLane : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.IDL_SEQUENCE_RTCORBA_ThreadpoolLane.Sequence;

   function To_Any
     (Item : RTCORBA.IDL_SEQUENCE_RTCORBA_ThreadpoolLane.Sequence) return CORBA.Any;

   function Wrap (X : access RTCORBA.IDL_SEQUENCE_RTCORBA_ThreadpoolLane.Sequence) return PolyORB.Any.Content'Class;

   TC_ThreadpoolLanes : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.ThreadpoolLanes;

   function To_Any
     (Item : RTCORBA.ThreadpoolLanes) return CORBA.Any;
   function Wrap (X : access RTCORBA.PriorityModel) return PolyORB.Any.Content'Class;

   TC_PriorityModel : CORBA.TypeCode.Object;

   function From_Any (C : PolyORB.Any.Any_Container'Class) return RTCORBA.PriorityModel;

   function From_Any (Item : CORBA.Any) return RTCORBA.PriorityModel;

   function To_Any
     (Item : RTCORBA.PriorityModel) return CORBA.Any;

   function Unchecked_To_Ref
     (The_Ref : CORBA.Object.Ref'Class) return RTCORBA.ProtocolProperties_Forward.Ref;

   function To_Ref
     (The_Ref : CORBA.Object.Ref'Class) return RTCORBA.ProtocolProperties_Forward.Ref;

   TC_ProtocolProperties : CORBA.TypeCode.Object;
   function Wrap (X : access RTCORBA.Protocol) return PolyORB.Any.Content'Class;

   TC_Protocol : CORBA.TypeCode.Object;

   TC_IDL_SEQUENCE_RTCORBA_Protocol : CORBA.TypeCode.Object;

   TC_ProtocolList : CORBA.TypeCode.Object;
   function Wrap (X : access RTCORBA.PriorityBand) return PolyORB.Any.Content'Class;

   TC_PriorityBand : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.PriorityBand;

   function To_Any
     (Item : RTCORBA.PriorityBand) return CORBA.Any;

   TC_IDL_SEQUENCE_RTCORBA_PriorityBand : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.IDL_SEQUENCE_RTCORBA_PriorityBand.Sequence;

   function To_Any
     (Item : RTCORBA.IDL_SEQUENCE_RTCORBA_PriorityBand.Sequence) return CORBA.Any;

   function Wrap (X : access RTCORBA.IDL_SEQUENCE_RTCORBA_PriorityBand.Sequence) return PolyORB.Any.Content'Class;

   TC_PriorityBands : CORBA.TypeCode.Object;

   function From_Any (Item : CORBA.Any) return RTCORBA.PriorityBands;

   function To_Any
     (Item : RTCORBA.PriorityBands) return CORBA.Any;

end RTCORBA.Helper;
