------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                           I R _ S E R V E R P                            --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2002 Free Software Foundation, Inc.             --
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

with Server;
with Do_Nothing;
pragma Warnings (Off, Server);

with PolyORB.If_Descriptors;
with PolyORB.If_Descriptors.CORBA_IR;
with PolyORB.POA_Config.Proxies;
pragma Warnings (Off, PolyORB.POA_Config.Proxies);

with PolyORB.ORB;
with PolyORB.Setup;
with PolyORB.Initialization;

pragma Warnings (Off);
with PolyORB.Setup.Thread_Pool_Server;
with PolyORB.POA_Config.RACWs;
pragma Warnings (On);

procedure Ir_Serverp is
begin
   Do_Nothing;
   PolyORB.Initialization.Initialize_World;
   PolyORB.If_Descriptors.Default_If_Descriptor
     := new PolyORB.If_Descriptors.CORBA_IR.IR_If_Descriptor;
   PolyORB.ORB.Run (PolyORB.Setup.The_ORB, May_Poll => True);
end Ir_Serverp;
