------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                M O M A . P R O V I D E R . R O U T E R S                 --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--             Copyright (C) 1999-2002 Free Software Fundation              --
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

--  A servant used for routing topic messages.

--  $Id$

with MOMA.Destinations;
with MOMA.Provider.Topic_Datas;

with PolyORB.Any;
with PolyORB.Any.NVList;
with PolyORB.Minimal_Servant;
with PolyORB.Obj_Adapters.Simple;
with PolyORB.References;
with PolyORB.Requests;

package MOMA.Provider.Routers is

   use PolyORB.References;

   type Router is new PolyORB.Minimal_Servant.Servant with private;
   --  Topics : the list of all topics, with their subscribers.

   type Router_Acc is access Router;

   procedure Initialize (Self : access Router);
   --  Initialize a Router.

   procedure Invoke
     (Self : access Router;
      Req  : PolyORB.Requests.Request_Access);
   --  Router servant skeleton.

   function If_Desc
     return PolyORB.Obj_Adapters.Simple.Interface_Description;
   pragma Inline (If_Desc);
   --  Interface description for SOA object adapter.

private

   type Router is new PolyORB.Minimal_Servant.Servant with record
      Topics   : MOMA.Provider.Topic_Datas.Topic_Data;
   end record;

   procedure Publish (Self       : access Router;
                      Message    : PolyORB.Any.Any);
   --  Publish a Message on the topic given by the Message destination.

   procedure Store (Pool      : Ref;
                    Message   : PolyORB.Any.Any);
   --  Store a Message in a Pool.
   --  XXX Code from Moma.Provider.Message_Producer is duplicated.

   procedure Subscribe (Self     : access Router;
                        Topic    : MOMA.Destinations.Destination;
                        Pool     : MOMA.Destinations.Destination);
   --  Subscribe a Pool to a Topic.
   --  Topic's kind must be set to "Topic".
   --  Pool's kind must be set to "Pool".

   function Get_Parameter_Profile (Method : String)
     return PolyORB.Any.NVList.Ref;
   --  Parameters part of the interface description.

   function Get_Result_Profile (Method : String)
     return PolyORB.Any.Any;
   --  Result part of the interface description.

end MOMA.Provider.Routers;
