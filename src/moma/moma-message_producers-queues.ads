------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--        M O M A . M E S S A G E _ P R O D U C E R S . Q U E U E S         --
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

--  Derivation of Message_Producers for Queues.

--  $Id$

with MOMA.Messages;
with MOMA.Types;

with PolyORB.Annotations;
with PolyORB.Call_Back;
with PolyORB.References;
with PolyORB.Requests;

package MOMA.Message_Producers.Queues is

   type Queue is new Message_Producer with null record;

   type CBH_Note is new PolyORB.Annotations.Note with record
      Dest : PolyORB.References.Ref;
   end record;

   --  function Get_Queue return MOMA.Destinations.Queues.Queue;

   procedure Send (Self    : Queue;
                   Message : MOMA.Messages.Message'Class);
   --  Send message to Self.
   --  XXX should send asynchronous message !!!

   procedure Send (Self           : Queue;
                   Message        : MOMA.Messages.Message'Class;
                   Persistent     : Boolean;
                   Priority_Value : MOMA.Types.Priority;
                   TTL            : Time);
   --  Send message to Self, override default producer's values.
   --  XXX not implemented.

   procedure Response_Handler
     (Req : PolyORB.Requests.Request;
      CBH : access PolyORB.Call_Back.Call_Back_Handler);
   --  Call back handler attached to a MOM producer interacting with
   --  a ORB node.

end MOMA.Message_Producers.Queues;
