------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--        P O L Y O R B . M I N I M A L _ S E R V A N T . T O O L S         --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2002-2005 Free Software Foundation, Inc.           --
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
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

with PolyORB.Obj_Adapters;
with PolyORB.Objects;
with PolyORB.ORB;
with PolyORB.Servants;
with PolyORB.Setup;
with PolyORB.Types;

package body PolyORB.Minimal_Servant.Tools is

   use PolyORB.Minimal_Servant;
   use PolyORB.Objects;
   use PolyORB.Servants;
   use PolyORB.Setup;

   ----------------------
   -- Initiate_Servant --
   ----------------------

   procedure Initiate_Servant
     (Obj     : access PolyORB.Minimal_Servant.Servant'Class;
      Type_Id : in     PolyORB.Types.String;
      Ref     :    out PolyORB.References.Ref;
      Error   : in out PolyORB.Errors.Error_Container)
   is
      use PolyORB.Errors;

      Servant : constant PolyORB.Servants.Servant_Access
        := To_PolyORB_Servant (Obj);

      Obj_Adapter : constant PolyORB.Obj_Adapters.Obj_Adapter_Access
        := PolyORB.ORB.Object_Adapter (The_ORB);

      Servant_Id : Object_Id_Access;

   begin
      PolyORB.Obj_Adapters.Export
        (Obj_Adapter,
         Servant,
         null,
         Servant_Id,
         Error);

      if Found (Error) then
         return;
      end if;

      --  Register object

      PolyORB.ORB.Create_Reference
        (The_ORB,
         Servant_Id,
         PolyORB.Types.To_Standard_String (Type_Id),
         Ref);

      Free (Servant_Id);
   end Initiate_Servant;

   ----------------
   -- Run_Server --
   ----------------

   procedure Run_Server is
   begin
      PolyORB.ORB.Run (PolyORB.Setup.The_ORB, May_Poll => True);
   end Run_Server;

end PolyORB.Minimal_Servant.Tools;
