------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--    P O L Y O R B . P O A _ M A N A G E R . B A S I C _ M A N A G E R     --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                Copyright (C) 2001 Free Software Fundation                --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--              PolyORB is maintained by ENST Paris University.             --
--                                                                          --
------------------------------------------------------------------------------

--  $Id$

with PolyORB.Log;
with PolyORB.POA;

package body PolyORB.POA_Manager.Basic_Manager is

   use PolyORB.Locks;
   use PolyORB.Log;
   use Requests_Queue_P;

   package L is new PolyORB.Log.Facility_Log
     ("polyorb.poa_manager.basic_manager");
   procedure O (Message : in Standard.String; Level : Log_Level := Debug)
     renames L.Output;

   procedure Do_Wait_For_Completion (Self : access Basic_POA_Manager);
   --  Wait for completion

   procedure Do_Etherealize_Objects (Self : access Basic_POA_Manager);
   --  Etherealize the objects of the associated POAs
   --  (in case a Servant Manager is used with a RETAIN policy)

   procedure Destroy_If_Unused (Self : access Basic_POA_Manager);
   --  Destroy the POAManager if it is no longer used by any POA,
   --  and the POAManager has been created only for

   --------------
   -- Activate --
   --------------

   procedure Activate
     (Self : access Basic_POA_Manager)
   is
   begin
      pragma Debug (O ("Activate POAManager"));
      Lock_W (Self.State_Lock);
      if Self.Current_State = INACTIVE then
         Unlock_W (Self.State_Lock);
         raise PolyORB.POA.Adapter_Inactive;
      else
         Self.Current_State := ACTIVE;
      end if;
      Unlock_W (Self.State_Lock);
   end Activate;

   -------------------
   -- Hold_Requests --
   -------------------

   procedure Hold_Requests
     (Self                : access Basic_POA_Manager;
      Wait_For_Completion :        Boolean)
   is
   begin
      pragma Debug (O ("Hold requests, Wait_For_Completion is "
                       & Wait_For_Completion'Img));
      Lock_W (Self.State_Lock);
      if Self.Current_State = INACTIVE then
         Unlock_W (Self.State_Lock);
         raise PolyORB.POA.Adapter_Inactive;
      else
         Self.Current_State := HOLDING;
         null;
      end if;
      Unlock_W (Self.State_Lock);

      if Wait_For_Completion then
         Do_Wait_For_Completion (Self);
      end if;
   end Hold_Requests;

   ----------------------
   -- Discard_Requests --
   ----------------------

   procedure Discard_Requests
     (Self                : access Basic_POA_Manager;
      Wait_For_Completion :        Boolean)
   is
   begin
      pragma Debug (O ("Discard requests, Wait_For_Completion is "
                       & Wait_For_Completion'Img));
      Lock_W (Self.State_Lock);
      if Self.Current_State = INACTIVE then
         Unlock_W (Self.State_Lock);
         raise PolyORB.POA.Adapter_Inactive;
      else
         Self.Current_State := DISCARDING;
         null;
      end if;
      Unlock_W (Self.State_Lock);

      if Wait_For_Completion then
         Do_Wait_For_Completion (Self);
      end if;
   end Discard_Requests;

   ----------------
   -- Deactivate --
   ----------------

   procedure Deactivate
     (Self                : access Basic_POA_Manager;
      Etherealize_Objects :        Boolean;
      Wait_For_Completion :        Boolean)
   is
   begin
      pragma Debug (O ("Hold requests, Wait_For_Completion is "
                       & Wait_For_Completion'Img
                       & ", Etherealize_Objects is "
                       & Etherealize_Objects'Img));
      Lock_W (Self.State_Lock);
      if Self.Current_State = INACTIVE then
         Unlock_W (Self.State_Lock);
         raise PolyORB.POA.Adapter_Inactive;
      else
         Self.Current_State := INACTIVE;
      end if;
      Unlock_W (Self.State_Lock);

      if Etherealize_Objects then
         Do_Etherealize_Objects (Self);
      end if;
      if Wait_For_Completion then
         Do_Wait_For_Completion (Self);
      end if;
   end Deactivate;

   ---------------
   -- Get_State --
   ---------------

   function Get_State (Self : Basic_POA_Manager)
                      return State
   is
   begin
      pragma Debug (O ("POAManager state is "
                       & Self.Current_State'Img));
      return Self.Current_State;
   end Get_State;

   ------------
   -- Create --
   ------------

   procedure Create (M : access Basic_POA_Manager)
   is
      use PolyORB.POA_Types.POA_Sequences;
   begin
      pragma Debug (O ("Create a new Basic_POA_Manager"));
      Create (M.State_Lock);
      Create (M.Count_Lock);
      Create (M.POAs_Lock);
      Create (M.Queue_Lock);

      Lock_W (M.POAs_Lock);
      M.Managed_POAs := new POAList;
      Unlock_W (M.POAs_Lock);

      Lock_W (M.State_Lock);
      M.Current_State := HOLDING;
      Unlock_W (M.State_Lock);

      Lock_W (M.Queue_Lock);
      Create (M.Holded_Requests, Queue_Size);
      Unlock_W (M.Queue_Lock);
   end Create;

   ------------------
   -- Register_POA --
   ------------------

   procedure Register_POA
     (Self : access Basic_POA_Manager;
      OA   : Obj_Adapter_Access)
   is
      use PolyORB.POA_Types.POA_Sequences;
   begin
      pragma Debug (O ("Register a new POA"));
      Lock_W (Self.POAs_Lock);
      for I in 1 .. Length (Sequence (Self.Managed_POAs.all)) loop
         if Element_Of (Sequence (Self.Managed_POAs.all), I) = null then
            Replace_Element (Sequence (Self.Managed_POAs.all), I, OA);
            Unlock_W (Self.POAs_Lock);
            Inc_Usage_Counter (Self);
            return;
         end if;
      end loop;
      Append (Sequence (Self.Managed_POAs.all), OA);
      Unlock_W (Self.POAs_Lock);
      Inc_Usage_Counter (Self);
   end Register_POA;

   ----------------
   -- Remove_POA --
   ----------------

   procedure Remove_POA
     (Self : access Basic_POA_Manager;
      OA   : Obj_Adapter_Access)
   is
      use PolyORB.POA_Types.POA_Sequences;
      A_Child : Obj_Adapter_Access;
   begin
      pragma Debug (O ("Remove a POA"));
      Lock_W (Self.POAs_Lock);
      for I in 1 .. Length (Sequence (Self.Managed_POAs.all)) loop
         A_Child := Element_Of (Sequence (Self.Managed_POAs.all), I);
         if A_Child = OA then
            Replace_Element (Sequence (Self.Managed_POAs.all), I, null);
            Unlock_W (Self.POAs_Lock);
            Dec_Usage_Counter (Self);
            Destroy_If_Unused (Self);
            return;
         end if;
      end loop;
      Unlock_W (Self.POAs_Lock);

      raise Invalid_Obj_Adapter;
   end Remove_POA;

   ----------------------
   -- Get_Hold_Servant --
   ----------------------

   function Get_Hold_Servant
     (Self : access Basic_POA_Manager;
      OA   :        Obj_Adapter_Access)
     return Hold_Servant_Base_Access
   is
      S         : Hold_Servant_Access;
      New_Entry : Queue_Element_Access;
   begin
      pragma Debug (O ("Get a Hold_Servant"));
      Lock_W (Self.Queue_Lock);

      if Get_Count (Self.Holded_Requests) >=
        Get_Max_Count (Self.Holded_Requests)
      then
         Unlock_W (Self.Queue_Lock);
         raise PolyORB.POA.Transient;
      end if;

      New_Entry     := new Queue_Element;
      New_Entry.OA  := OA;
      Add (Self.Holded_Requests, New_Entry);

      S             := new Hold_Servant;
      S.Queue_Entry := New_Entry;
      Unlock_W (Self.Queue_Lock);

      return Hold_Servant_Base_Access (S);
   end Get_Hold_Servant;

   -----------------------
   -- Inc_Usage_Counter --
   -----------------------

   procedure Inc_Usage_Counter
     (Self : access Basic_POA_Manager)
   is
   begin
      Lock_W (Self.Count_Lock);
      Self.Usage_Count := Self.Usage_Count + 1;
      Unlock_W (Self.Count_Lock);
      pragma Debug (O ("Increase usage to "
                       & Self.Usage_Count'Img));
   end Inc_Usage_Counter;

   -----------------------
   -- Dec_Usage_Counter --
   -----------------------

   procedure Dec_Usage_Counter
     (Self : access Basic_POA_Manager)
   is
   begin
      Lock_W (Self.Count_Lock);
      Self.Usage_Count := Self.Usage_Count - 1;
      Unlock_W (Self.Count_Lock);
      pragma Debug (O ("Decrease usage to "
                       & Self.Usage_Count'Img));
   end Dec_Usage_Counter;

   ----------------------------
   -- Do_Wait_For_Completion --
   ----------------------------

   procedure Do_Wait_For_Completion
     (Self : access Basic_POA_Manager)
   is
   begin
      pragma Warnings (Off);
      pragma Unreferenced (Self);
      pragma Warnings (On);
      --  ??? What's this thing about the threads ? Ignored for now.
      --  ??? Iterates through the POAs to wait for completion
      null;
   end Do_Wait_For_Completion;

   ----------------------------
   -- Do_Etherealize_Objects --
   ----------------------------

   procedure Do_Etherealize_Objects
     (Self : access Basic_POA_Manager)
   is
   begin
      pragma Warnings (Off);
      pragma Unreferenced (Self);
      pragma Warnings (On);
      null;
      --  ??? To be implemented
   end Do_Etherealize_Objects;

   -----------------------
   -- Destroy_If_Unused --
   -----------------------

   procedure Destroy_If_Unused
     (Self : access Basic_POA_Manager)
   is
      BPM : Basic_POA_Manager_Access
        := Basic_POA_Manager_Access (Self);
   begin
      Lock_R (Self.Count_Lock);
      if Self.Usage_Count = 0 then
         pragma Debug (O ("POAManager is no longer used, destroying it"));
         Unlock_R (Self.Count_Lock);
         Destroy (Self.State_Lock);
         Destroy (Self.Count_Lock);
         Destroy (Self.POAs_Lock);
         Destroy (Self.Queue_Lock);
         Destroy (Self.Holded_Requests);
         Free (BPM);
      else
         Unlock_R (Self.Count_Lock);
      end if;
   end Destroy_If_Unused;

   ------------
   -- Create --
   ------------

   procedure Create
     (HS  : in out Hold_Servant;
      QEA : in     Queue_Element_Access)
   is
   begin
      HS.Queue_Entry := QEA;
   end Create;

   ----------
   -- Left --
   ----------

   function "="
     (Left, Right : Hold_Servant)
     return Boolean
   is
   begin
      return Left.Queue_Entry = Right.Queue_Entry;
   end "=";

   --------------------
   -- Handle_Message --
   --------------------

   function Handle_Message
     (Obj : access Hold_Servant;
      Msg :        PolyORB.Components.Message'Class)
     return PolyORB.Components.Message'Class
   is
      S            : Hold_Servant_Access;
      Null_Message : PolyORB.Components.Null_Message;
   begin
      pragma Debug (O ("Hold Servant queues message"));

      S := Hold_Servant_Access (Obj);

      pragma Warnings (Off);
      pragma Unreferenced (Msg);
      pragma Warnings (On);
      --      Obj.Queue_Entry.Msg := Msg;
      --  ??? How do we queue the messages?

      Free (S);

      return Null_Message;
   end Handle_Message;

end PolyORB.POA_Manager.Basic_Manager;
