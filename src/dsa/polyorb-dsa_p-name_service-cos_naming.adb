------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                  POLYORB.DSA_P.NAME_SERVICE.COS_NAMING                   --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--           Copyright (C) 2010, Free Software Foundation, Inc.             --
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

with PolyORB.Utils;
with PolyORB.Log;
with PolyORB.Services.Naming.NamingContext;
with PolyORB.Services.Naming.NamingContext.Client;
with PolyORB.Smart_Pointers;
with Ada.Exceptions;
with System.RPC;
with PolyORB.Tasking.Threads;
with PolyORB.Initialization;

package body PolyORB.DSA_P.Name_Service.COS_Naming is
   use PolyORB.Utils;
   use PolyORB.Log;
   use PolyORB.Smart_Pointers;

   package L is new PolyORB.Log.Facility_Log
     ("polyorb.dsa_p.name_service.cos_naming");
   procedure O (Message : String; Level : Log_Level := Debug)
     renames L.Output;
   function C (Level : Log_Level := Debug) return Boolean
               renames L.Enabled;

   package PSNNC renames PolyORB.Services.Naming.NamingContext;

   Time_Between_Requests : constant Duration := 1.0;
   Max_Requests          : constant Natural := 10;

   -------------------------
   -- Nameserver_Register --
   -------------------------

   procedure Nameserver_Register
     (Name_Ctx : access COS_Name_Context;
      Name : String;
      Kind : String;
      Obj  : PolyORB.References.Ref)
   is
      use Ada.Exceptions;
      Id      : constant PolyORB.Services.Naming.Name := To_Name (Name, Kind);
      Context : PSNNC.Ref;
      Reg_Obj : PolyORB.References.Ref;
   begin
      pragma Debug (C, O ("About to register " & Name & " on nameserver"));

      --  May raise an exception which we do not want to handle in the
      --  following block (failure to establish the naming context is a fatal
      --  error and must be propagated to the caller).

      PSNNC.Set (Context, Entity_Of (Smart_Pointers.Ref (Name_Ctx.Base_Ref)));

      begin
         Reg_Obj := PSNNC.Client.Resolve (Context, Id);
      exception
         when others =>

            --  Resolution attempt returned an authoritative "name not found"
            --  error: register unit now.

            PSNNC.Client.Bind
              (Self => Context,
               N    => Id,
               Obj  => Obj);
            return;
      end;

      --  Name is present in name server, check validity of the reference it
      --  resolves to.

      if Get_Reconnection_Policy (Name) = Reject_On_Restart
           or else Is_Reference_Valid (Reg_Obj)
      then
         --  Reference is valid: RCI unit is already declared by another
         --  partition.

         PolyORB.Initialization.Shutdown_World (Wait_For_Completion => False);
         raise Program_Error with Name & " (" & Kind & ") is already declared";

      else
         --  The reference is not valid anymore: we assume the original server
         --  has died, and rebind the name.

         PSNNC.Client.Rebind
           (Self => Context,
            N    => To_Name (Name, Kind),
            Obj  => Obj);
      end if;
   end Nameserver_Register;

   -----------------------
   -- Nameserver_Lookup --
   -----------------------

   function Nameserver_Lookup
     (Name_Ctx : access COS_Name_Context;
      Name     : String;
      Kind     : String;
      Initial  : Boolean := True) return PolyORB.References.Ref
   is

      LName : constant String := To_Lower (Name);

      Result  : PolyORB.References.Ref;
      Context : PSNNC.Ref;
      Retry_Count : Natural := 0;
   begin
      pragma Debug
        (C, O ("Nameserver_Lookup (" & Name & "." & Kind & "): enter"));

      --  Unit not known yet, we therefore know that it is remote, and we
      --  need to look it up with the naming service.
      PSNNC.Set (Context, Entity_Of (Smart_Pointers.Ref (Name_Ctx.Base_Ref)));
      loop
         begin
            Result := PSNNC.Client.Resolve
                        (Context, To_Name (LName, Kind));

            if not Is_Reference_Valid (Result) then
               PolyORB.References.Release (Result);
            end if;

         exception
               --  Catch all exceptions: we will retry resolution, and bail
               --  out after Max_Requests iterations.

            when E : others =>
               pragma Debug (C, O ("retry" & Retry_Count'Img & " got "
                 & Ada.Exceptions.Exception_Information (E)));
               PolyORB.References.Release (Result);
         end;

         exit when not (Initial and then Is_Nil (Smart_Pointers.Ref (Result)));
         --  Resolve succeeded, or just trying to refresh a stale ref:
         --  exit loop.

         if Retry_Count = Max_Requests then
            raise System.RPC.Communication_Error with
              "lookup of " & Kind & " " & Name & " failed";
         end if;
         Retry_Count := Retry_Count + 1;
         PolyORB.Tasking.Threads.Relative_Delay (Time_Between_Requests);
      end loop;

      pragma Debug
        (C, O ("Nameserver_Lookup (" & Name & "." & Kind & "): leave"));
      return Result;
   end Nameserver_Lookup;

   -------------
   -- To_Name --
   -------------

   function To_Name (Id, Kind : String) return PolyORB.Services.Naming.Name is
      use PolyORB.Services.Naming.SEQUENCE_NameComponent;
   begin
      return PolyORB.Services.Naming.Name
        (To_Sequence
         ((1 => (id   => PolyORB.Services.Naming.To_PolyORB_String (Id),
                 kind => PolyORB.Services.Naming.To_PolyORB_String (Kind)))));
   end To_Name;

end PolyORB.DSA_P.Name_Service.COS_Naming;
