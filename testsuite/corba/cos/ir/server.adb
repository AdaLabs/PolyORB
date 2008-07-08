------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                               S E R V E R                                --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 1999-2004 Free Software Foundation, Inc.           --
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
--                PolyORB is maintained by ACT Europe.                      --
--                    (email: sales@act-europe.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

with Ada.Text_IO;

with CORBA.Object;
with CORBA.ORB;
with CORBA.Repository_Root.IRObject.Impl;
with CORBA.Repository_Root.Contained.Impl;
with CORBA.Repository_Root.Repository.Impl;
with CORBA.Repository_Root;

with PortableServer;

with PolyORB.CORBA_P.Server_Tools;

with PolyORB.Setup.No_Tasking_Server;
pragma Warnings (Off, PolyORB.Setup.No_Tasking_Server);

procedure Server is
   use CORBA.Repository_Root;
   use PolyORB.CORBA_P.Server_Tools;

begin

   CORBA.ORB.Initialize ("ORB");

   declare
      Ref : CORBA.Object.Ref;
      Repo : constant Repository.Impl.Object_Ptr := new Repository.Impl.Object;

   begin

      Repository.Impl.Init (Repo,
                            IRObject.Impl.Object_Ptr (Repo),
                            dk_Repository,
                            Contained.Impl.Contained_Seq.Null_Sequence);
      Initiate_Servant (PortableServer.Servant (Repo), Ref);

      Ada.Text_IO.Put_Line
        ("'" & CORBA.To_Standard_String (CORBA.Object.Object_To_String (Ref)) &
         "'");

      Initiate_Server;
   end;
end Server;
