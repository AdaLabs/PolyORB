------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--      P O L Y O R B . M O M A _ P . P R O V I D E R . R O U T E R S       --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2003-2004 Free Software Foundation, Inc.           --
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

--  $Id$

with MOMA.Destinations;
with MOMA.Messages;
with PolyORB.MOMA_P.Provider.Topic_Datas;

with PolyORB.Any.NVList;
with PolyORB.Exceptions;
with PolyORB.Log;
with PolyORB.Requests;
with PolyORB.Types;

package body PolyORB.MOMA_P.Provider.Routers is

   use MOMA.Destinations;
   use MOMA.Messages;
   use PolyORB.MOMA_P.Provider.Topic_Datas;

   use PolyORB.Any;
   use PolyORB.Log;
   use PolyORB.Tasking.Rw_Locks;
   use PolyORB.Types;

   package L is new PolyORB.Log.Facility_Log ("moma.provider.routers");
   procedure O (Message : in Standard.String; Level : Log_Level := Debug)
     renames L.Output;

   --  Actual functions implemented by the servant.

   procedure Add_Router
     (Self    : in out Router;
      Router  :        MOMA.Destinations.Destination);
   --  Add a Router to the list of known routers.

   procedure Publish
     (Self             : access Router;
      Message          :        PolyORB.Any.Any;
      From_Router_Id   :        MOMA.Types.String := To_MOMA_String (""));

   --  Publish a Message on the topic given by the Message destination.
   --  From_Router_Id is the Id of the router the message is coming from, if
   --  it's received from a router and not from a client.

   procedure Register
     (Self       : access Router;
      Router_Ref :        PolyORB.References.Ref);
   --  Register a router with another one : this means they will exchange
   --  messages one with each other.

   procedure Route
     (Self      : access Router;
      Message   :        PolyORB.Any.Any;
      To_Router :        MOMA.Destinations.Destination);
   --  Route a Message to another router.

   procedure Store
     (Pool    : Ref;
      Message : PolyORB.Any.Any);
   --  Store a Message in a Pool.
   --  XXX Code from Moma.Provider.Message_Producer is duplicated.

   procedure Subscribe
     (Self     : access Router;
      Topic    :        MOMA.Destinations.Destination;
      Pool     :        MOMA.Destinations.Destination);
   --  Subscribe a Pool to a Topic.
   --  Topic's kind must be set to "Topic".
   --  Pool's kind must be set to "Pool".

   procedure Unsubscribe
     (Self   : access Router;
      Topic  :        MOMA.Destinations.Destination;
      Pool   :        MOMA.Destinations.Destination);
   --  Unsubscribe a Pool to a Topic (same parameters as Subscribe).
   --  NB : the current implementation needs a client to send the
   --  Unsubscription and Subscription requests for a same pool to the same
   --  router.

   --  Accessors to servant interface.

   function Get_Parameter_Profile
     (Method : String)
     return PolyORB.Any.NVList.Ref;
   --  Parameters part of the interface description.

   --  Private accessors to some internal data.

   function Get_Routers
     (Self : Router)
     return PolyORB.MOMA_P.Provider.Topic_Datas.Destination_List.List;
   --  Return a copy of the list Self.Routers.List.

   ----------------
   -- Add_Router --
   ----------------

   procedure Add_Router
     (Self    : in out Router;
      Router  :        MOMA.Destinations.Destination) is
   begin
      Lock_W (Self.Routers.L_Lock);
      Destination_List.Append (Self.Routers.List, Router);
      Unlock_W (Self.Routers.L_Lock);
      --  XXX It would be better to check first the router isn't already
      --  in the list.
   end Add_Router;

   ------------------------
   -- Create_Destination --
   ------------------------

   function Create_Destination
     (Self : Router)
     return MOMA.Destinations.Destination is
   begin
      return MOMA.Destinations.Create_Destination
        (Get_Id (Self),
         Get_Self_Ref (Self),
         MOMA.Types.Router);
   end Create_Destination;

   ------------
   -- Get_Id --
   ------------

   function Get_Id
     (Self : Router)
     return MOMA.Types.String is
   begin
      return Self.Id;
   end Get_Id;

   ---------------------------
   -- Get_Parameter_Profile --
   ---------------------------

   function Get_Parameter_Profile
     (Method : String)
     return PolyORB.Any.NVList.Ref
   is
      Result : PolyORB.Any.NVList.Ref;
   begin
      PolyORB.Any.NVList.Create (Result);
      pragma Debug (O ("Parameter profile for " & Method & " requested."));

      if       Method = "Publish"
      or else  Method = "Route" then
         PolyORB.Any.NVList.Add_Item
            (Result,
             (Name      => To_PolyORB_String ("Message"),
              Argument  => PolyORB.Any.Get_Empty_Any
                              (MOMA.Messages.TC_MOMA_Message),
              Arg_Modes => PolyORB.Any.ARG_IN));
         if Method = "Route" then
            PolyORB.Any.NVList.Add_Item
               (Result,
                (Name      => To_PolyORB_String ("From_Router_Id"),
                 Argument  => PolyORB.Any.Get_Empty_Any
                              (TypeCode.TC_String),
                 Arg_Modes => PolyORB.Any.ARG_IN));
         end if;

      elsif Method = "Register" then
         PolyORB.Any.NVList.Add_Item
            (Result,
             (Name      => To_PolyORB_String ("Router"),
              Argument  => PolyORB.Any.Get_Empty_Any
                              (MOMA.Destinations.TC_MOMA_Destination),
              Arg_Modes => PolyORB.Any.ARG_IN));

      elsif Method = "Subscribe"
      or else Method = "Unsubscribe" then
         PolyORB.Any.NVList.Add_Item
            (Result,
             (Name      => To_PolyORB_String ("Topic"),
              Argument  => PolyORB.Any.Get_Empty_Any
                              (MOMA.Destinations.TC_MOMA_Destination),
              Arg_Modes => PolyORB.Any.ARG_IN));
         PolyORB.Any.NVList.Add_Item
            (Result,
             (Name      => To_PolyORB_String ("Pool"),
              Argument  => PolyORB.Any.Get_Empty_Any
                              (MOMA.Destinations.TC_MOMA_Destination),
              Arg_Modes => PolyORB.Any.ARG_IN));

      else
         raise Program_Error;
      end if;

      return Result;
   end Get_Parameter_Profile;

   -----------------
   -- Get_Routers --
   -----------------

   function Get_Routers
     (Self : Router)
     return PolyORB.MOMA_P.Provider.Topic_Datas.Destination_List.List
   is
      Routers : Destination_List.List;
   begin
      Lock_R (Self.Routers.L_Lock);
      Routers := Destination_List.Duplicate (Self.Routers.List);
      Unlock_R (Self.Routers.L_Lock);
      return Routers;
   end Get_Routers;

   ------------------
   -- Get_Self_Ref --
   ------------------

   function Get_Self_Ref
     (Self : Router)
     return PolyORB.References.Ref is
   begin
      return Self.Self_Ref;
   end Get_Self_Ref;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self       : access Router;
      Router_Ref :        PolyORB.References.Ref) is
   begin
      PolyORB.MOMA_P.Provider.Topic_Datas.Ensure_Initialization (Self.Topics);

      if not (Self.Routers.L_Initialized) then
         PolyORB.Tasking.Rw_Locks.Create (Self.Routers.L_Lock);
         Self.Routers.L_Initialized := True;
      end if;

      if Router_Ref /= PolyORB.References.Nil_Ref then
         Register (Self, Router_Ref);
      end if;
   end Initialize;

   ------------
   -- Invoke --
   ------------

   procedure Invoke
     (Self : access Router;
      Req  :        PolyORB.Requests.Request_Access)
   is
      use PolyORB.Any.NVList.Internals;
      use PolyORB.Any.NVList.Internals.NV_Lists;
      use PolyORB.Exceptions;

      Args      : PolyORB.Any.NVList.Ref;
      It        : Iterator;
      Operation : constant String := To_Standard_String (Req.all.Operation);
      Error     : Error_Container;
   begin
      pragma Debug (O ("The router is executing the request:"
                    & PolyORB.Requests.Image (Req.all)));

      PolyORB.Any.NVList.Create (Args);

      Args := Get_Parameter_Profile (To_Standard_String (Req.all.Operation));
      PolyORB.Requests.Arguments (Req, Args, Error);

      if Found (Error) then
         raise PolyORB.Unknown;
         --  XXX We should do something more contructive

      end if;

      It := First (List_Of (Args).all);

      if Operation = "Publish" then

         --  Publish
         Publish (Self, Value (It).Argument);

      elsif Operation = "Register" then

         --  Register

         declare
         begin
            Req.Result.Argument := To_Any
              (Create_Destination (Self.all));
            Add_Router (Self.all, MOMA.Destinations.From_Any
                        (Value (It).Argument));
         end;

      elsif Operation = "Route" then

         --  Route

         declare
            Message, From_Router_Id : Element_Access;
         begin
            Message := Value (It);
            Next (It);
            From_Router_Id := Value (It);
            Publish
              (Self, Message.Argument, From_Any (From_Router_Id.Argument));
         end;

      elsif Operation = "Subscribe"
        or else  Operation = "Unsubscribe"
      then

         --  Subscribe / Unsubscribe

         declare
            Topic, Pool : Element_Access;
         begin
            Topic := Value (It);
            Next (It);
            Pool := Value (It);

            if Operation = "Subscribe" then
               Subscribe
                 (Self,
                  MOMA.Destinations.From_Any (Topic.Argument),
                  MOMA.Destinations.From_Any (Pool.Argument));
            else
               Unsubscribe
                 (Self,
                  MOMA.Destinations.From_Any (Topic.Argument),
                  MOMA.Destinations.From_Any (Pool.Argument));
            end if;
         end;

      end if;
   end Invoke;

   -------------
   -- Publish --
   -------------

   procedure Publish
     (Self             : access Router;
      Message          :        PolyORB.Any.Any;
      From_Router_Id   :        MOMA.Types.String := To_MOMA_String (""))
   is
      Subscribers : Destination_List.List;
      I           : Destination_List.Iterator;
      Topic_Id    : MOMA.Types.String;
      Destination : MOMA.Destinations.Destination;
      Routers     : Destination_List.List;
      J           : Destination_List.Iterator;
   begin
      --  Check the destination is really a topic.

      Destination := Get_Destination (MOMA.Messages.From_Any (Message));
      if Get_Kind (Destination) /= MOMA.Types.Topic then
         raise Program_Error;
      end if;
      Topic_Id := Get_Name (Destination);

      --  Relay Message to other routers.

      Routers := Get_Routers (Self.all);
      J := Destination_List.First (Routers);
      while not (Destination_List.Last (J)) loop
         if MOMA.Destinations.Get_Name (Destination_List.Value (J).all) /=
               From_Router_Id
         then
            Route (Self, Message, Destination_List.Value (J).all);
         end if;
         Destination_List.Next (J);
      end loop;
      Destination_List.Deallocate (Routers);

      --  Store Message into known pools subscribed to this topic.

      Subscribers := Get_Subscribers (Self.Topics, Topic_Id);
      I := Destination_List.First (Subscribers);
      while not (Destination_List.Last (I)) loop
         Store (Get_Ref (Destination_List.Value (I).all), Message);
         Destination_List.Next (I);
      end loop;
      Destination_List.Deallocate (Subscribers);
   end Publish;

   --------------
   -- Register --
   --------------

   procedure Register
     (Self       : access Router;
      Router_Ref :        PolyORB.References.Ref)
   is
      Request     : PolyORB.Requests.Request_Access;
      Arg_List    : PolyORB.Any.NVList.Ref;
      Result      : PolyORB.Any.NamedValue;
      Destination : constant MOMA.Destinations.Destination
        := Create_Destination (Self.all);
   begin
      PolyORB.Any.NVList.Create (Arg_List);

      PolyORB.Any.NVList.Add_Item
        (Arg_List,
         To_PolyORB_String ("Router"),
         To_Any (Destination),
         PolyORB.Any.ARG_IN);

      Result
        := (Name      => To_PolyORB_String ("Result"),
            Argument  => PolyORB.Any.Get_Empty_Any
            (MOMA.Destinations.TC_MOMA_Destination),
            Arg_Modes => 0);

      PolyORB.Requests.Create_Request
        (Target    => Router_Ref,
         Operation => "Register",
         Arg_List  => Arg_List,
         Result    => Result,
         Req       => Request);

      PolyORB.Requests.Invoke (Request);
      PolyORB.Requests.Destroy_Request (Request);

      Add_Router (Self.all,
                  MOMA.Destinations.From_Any (Result.Argument));
   end Register;

   -----------
   -- Route --
   -----------

   procedure Route
     (Self      : access Router;
      Message   :        PolyORB.Any.Any;
      To_Router :        MOMA.Destinations.Destination)
   is
      Request     : PolyORB.Requests.Request_Access;
      Arg_List    : PolyORB.Any.NVList.Ref;
      Result      : PolyORB.Any.NamedValue;
   begin
      PolyORB.Any.NVList.Create (Arg_List);

      PolyORB.Any.NVList.Add_Item
        (Arg_List,
         To_PolyORB_String ("Message"),
         Message,
         PolyORB.Any.ARG_IN);

      PolyORB.Any.NVList.Add_Item
        (Arg_List,
         To_PolyORB_String ("From_Router_Id"),
         To_Any (Get_Id (Self.all)),
         PolyORB.Any.ARG_IN);

      Result
        := (Name      => To_PolyORB_String ("Result"),
            Argument  => PolyORB.Any.Get_Empty_Any (PolyORB.Any.TC_Void),
            Arg_Modes => 0);

      PolyORB.Requests.Create_Request
        (Target    => Get_Ref (To_Router),
         Operation => "Route",
         Arg_List  => Arg_List,
         Result    => Result,
         Req       => Request);

      PolyORB.Requests.Invoke (Request);
      PolyORB.Requests.Destroy_Request (Request);
   end Route;

   ------------
   -- Set_Id --
   ------------

   procedure Set_Id
     (Self  : in out Router;
      Id    :        MOMA.Types.String) is
   begin
      Self.Id := Id;
   end Set_Id;

   -------------------
   --  Set_Self_Ref --
   -------------------

   procedure Set_Self_Ref
     (Self  : in out Router;
      Ref   :        PolyORB.References.Ref) is
   begin
      Self.Self_Ref := Ref;
   end Set_Self_Ref;

   -----------
   -- Store --
   -----------

   procedure Store
     (Pool    : Ref;
      Message : PolyORB.Any.Any)
   is
      Request     : PolyORB.Requests.Request_Access;
      Arg_List    : PolyORB.Any.NVList.Ref;
      Result      : PolyORB.Any.NamedValue;
   begin
      PolyORB.Any.NVList.Create (Arg_List);

      PolyORB.Any.NVList.Add_Item
        (Arg_List,
         To_PolyORB_String ("Message"),
         Message,
         PolyORB.Any.ARG_IN);

      Result
        := (Name      => To_PolyORB_String ("Result"),
            Argument  => PolyORB.Any.Get_Empty_Any (PolyORB.Any.TC_Void),
            Arg_Modes => 0);

      PolyORB.Requests.Create_Request
        (Target    => Pool,
         Operation => "Publish",
         Arg_List  => Arg_List,
         Result    => Result,
         Req       => Request);
      PolyORB.Requests.Invoke (Request);
      PolyORB.Requests.Destroy_Request (Request);
   end Store;

   ---------------
   -- Subscribe --
   ---------------

   procedure Subscribe
     (Self  : access Router;
      Topic :        MOMA.Destinations.Destination;
      Pool  :        MOMA.Destinations.Destination) is
   begin
      if Get_Kind (Topic) /= MOMA.Types.Topic
        or else Get_Kind (Pool) /= MOMA.Types.Pool
      then
         raise Program_Error;
      end if;

      PolyORB.MOMA_P.Provider.Topic_Datas.Add_Subscriber
        (Self.Topics,
         Get_Name (Topic),
         Pool);
   end Subscribe;

   -----------------
   -- Unsubscribe --
   -----------------

   procedure Unsubscribe
     (Self   : access Router;
      Topic  :        MOMA.Destinations.Destination;
      Pool   :        MOMA.Destinations.Destination) is
   begin
      if Get_Kind (Topic) /= MOMA.Types.Topic
        or else Get_Kind (Pool) /= MOMA.Types.Pool
      then
         raise Program_Error;
      end if;

      PolyORB.MOMA_P.Provider.Topic_Datas.Remove_Subscriber
        (Self.Topics,
         Get_Name (Topic),
         Pool);
   end Unsubscribe;

end PolyORB.MOMA_P.Provider.Routers;
