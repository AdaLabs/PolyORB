--  with Ada.Exceptions;
with Ada.Streams; use Ada.Streams;

with Droopi.Any;
with Droopi.Any.NVList;

with Droopi.Binding_Data.Local;
with Droopi.Buffers;
with Droopi.Filters;
with Droopi.Filters.Interface;
with Droopi.Log;
pragma Elaborate_All (Droopi.Log);

with Droopi.Obj_Adapters;
with Droopi.Objects;
with Droopi.Opaque;
with Droopi.ORB;
with Droopi.ORB.Interface;
with Droopi.References;
with Droopi.Requests; use Droopi.Requests;

with Droopi.Representations.SRP; use Droopi.Representations.SRP;
with Droopi.Utils;
with Droopi.Utils.SRP; use Droopi.Utils.SRP;
with Droopi.Types;

package body Droopi.Protocols.SRP is

   use Droopi.Any;
   use Droopi.Components;
   use Droopi.Filters;
   use Droopi.Filters.Interface;
   use Droopi.Log;
   use Droopi.ORB;
   use Droopi.ORB.Interface;
   use Droopi.Types;

   package L is new Droopi.Log.Facility_Log ("droopi.protocols.srp");
   procedure O (Message : in String; Level : Log_Level := Debug)
     renames L.Output;

   Rep : constant Rep_SRP_Access := new Rep_SRP;


   procedure Create
     (Proto   : access SRP_Protocol;
      Session : out Filter_Access)
   is
   begin
      --  This should be factored in Droopi.Protocols.

      Session := new SRP_Session;

      SRP_Session (Session.all).Buffer_In := new Buffers.Buffer_Type;
      SRP_Session (Session.all).Buffer_Out := new Buffers.Buffer_Type;

   end Create;

   procedure Connect (S : access SRP_Session) is
   begin
      null;
   end Connect;

   procedure Invoke_Request (S : access SRP_Session; R :  Requests.Request)
   is
   begin
      null;
   end Invoke_Request;

   procedure Abort_Request (S : access SRP_Session; R :  Requests.Request)
   is
   begin
      null;
   end Abort_Request;

   procedure Request_Received (S : access SRP_Session);
   procedure Request_Received (S : access SRP_Session)
   is
      use Binding_Data.Local;
      use Droopi.Obj_Adapters;

      Info_SRP : Split_SRP;

      --  used to store the arg list needed by the method called
      Args   : Any.NVList.Ref;
      Result : Any.NamedValue;

--      Method : String_Ptr := new Types.String'(To_Droopi_String ("bidon"));
--       Oid    : Objects.Object_Id_Access :=
--         new Objects.Object_Id'(To_Oid ("01000000"));

      ORB      : constant ORB_Access := ORB_Access (S.Server);

      Request_String : String_Ptr;
      Req    : Request_Access;

      Target_Profile :
        Binding_Data.Profile_Access := new Local_Profile_Type;
      Target   : References.Ref;
   begin
      --  Get the entire request string
      Request_String := new Types.String'(Unmarshall (S.Buffer_In));

      --  Split the string in its different parts and store them in
      --  a Split_SRP record
      Info_SRP := Split (Request_String.all);

      --  Get the arg profile needed by the method called
      Args := Obj_Adapters.Get_Empty_Arg_List
        (Object_Adapter (ORB),
         Info_SRP.Oid.all,
         To_Standard_String (Info_SRP.Method.all));

      Unmarshall (Args, Info_SRP);

      --  Get Object_Id and Operation_Id
--      Unmarshall_Request_Message (S.Buffer_In,
--                                  Oid,
--                                  Method);

      --  Get the arguments' values from the buffer
--      Unmarshall_Args (S.Buffer_In, Args);


      --  Get the result profile for the method called and create an
      --  appropriate Any.NamedValue for the result
      Result := (Name     => To_Droopi_String ("Result"),
                 Argument =>  Obj_Adapters.Get_Empty_Result
                   (Object_Adapter (ORB), Info_SRP.Oid.all,
                    To_Standard_String (Info_SRP.Method.all)),
                 Arg_Modes => 0);

      --  Create a local profile for the request. Indeed, the request isnnow
      --  local
      Create_Local_Profile
        (Info_SRP.Oid.all, Local_Profile_Type (Target_Profile.all));
      References.Create_Reference ((1 => Target_Profile), Target);

      --  Create a Request
      Create_Request (Target    => Target,
                      Operation => To_Standard_String (Info_SRP.Method.all),
                      Arg_List  => Args,
                      Result    => Result,
                      Req       => Req);

      --  Emit the request
      Emit_No_Reply
        (Component_Access (ORB),
         Queue_Request'(Request   => Req,
                        Requestor => Component_Access (S),
                        Requesting_Task => null));
   end Request_Received;

   procedure Reply_Received (S : access SRP_Session);
   procedure Reply_Received (S : access SRP_Session)is
   begin
      raise Not_Implemented;
   end Reply_Received;

   procedure Send_Reply (S : access SRP_Session; R : Request)
   is
      use Buffers;
      use Droopi.Objects;
      use Representations.SRP;

      --  CRLF : constant String := ASCII.CR & ASCII.LF;
      SRP_Info : Split_SRP;
      B : Buffer_Access renames S.Buffer_Out;
   begin
      Release_Contents (B.all);
      Set_SRP_Method (To_Droopi_String ("Reply"), SRP_Info);
      Set_SRP_Oid (To_Oid ("00000000"), SRP_Info);
      Set_SRP_Arg (To_Droopi_String ("Data"),
                   To_Any (To_Droopi_String ("200 OK" & Image (R))),
                   SRP_Info);

      --  Data := Join (SRP_Info);

      --  ??? Before using this procedure, we must be able to
      --  [un]marshall Split_SRP [from] to Any
      --  Marshall_From_Any (Rep.all, B, Data);

      Marshall_From_Split_SRP (Rep.all, B, SRP_Info);

      Emit_No_Reply (Lower (S), Data_Out'(Out_Buf => B));
   end Send_Reply;

   procedure Handle_Connect_Indication (S : access SRP_Session) is
   begin
      pragma Debug (O ("Received new connection to SRP service..."));

      --  1. Send greetings to client.

      --  Send_String ("Hello, please type data." & ASCII.LF);

      --  2. Notify transport layer that more data is expected.

      Expect_Data (S, S.Buffer_In, 1024);
      --  Exact => False

      --  Note that there is no race condition here. One might
      --  expect the following unfortunate sequence of events:
      --    10. Greetings sent to client
      --    11. Client answers
      --    20. Expect_Data
      --  (in 11: transport gets unexpected data).
      --  This does not actually happen because the TE is not
      --  being monitored while Send_Greetings and Expect_Data
      --  are done; it becomes monitored again /after/ the
      --  Connect_Indication has been processed.
      --
      --  The same goes for the handling of a Data_Indication.

   end Handle_Connect_Indication;

   procedure Handle_Connect_Confirmation (S : access SRP_Session) is
   begin
      null;
      --  No setup is necessary for newly-created client connections.
   end Handle_Connect_Confirmation;

   --  type String_Array is array (Integer range <>) of String_Ptr;


   --  procedure Free (SA : in out String_Array);
   --  procedure Free (SA : in out String_Array) is
   --  begin
   --     for I in SA'Range loop
   --        Free (SA (I));
   --     end loop;
   --  end Free;

   procedure Handle_Data_Indication (S : access SRP_Session)
   is
   begin
      pragma Debug (O ("Received data on SRP service..."));
      pragma Debug (Buffers.Show (S.Buffer_In.all));

--       case S.Mess_Type_Received is
--          when Req =>
--             if S.Role = Server then
      Request_Received (S);
--             else
--                raise SRP_Error;
--             end if;
--          when Reply =>
--             if S.Role = Client then
--                Reply_Received (S);
--             else
--                raise SRP_Error;
--             end if;
--       end case;

      Buffers.Release_Contents (S.Buffer_In.all);
      --  Clean up

      Expect_Data (S, S.Buffer_In, 1024);
      --  ??? DUMMY size
   end Handle_Data_Indication;

--    procedure Handle_Data_Indication (S : access SRP_Session)
--    is
--       use Any.NVList;

--       use Binding_Data.Local;
--       use Objects;
--       use References;

--    begin
--       pragma Debug (O ("Received data on SRP service..."));
--       pragma Debug (Buffers.Show (S.Buffer_In.all));

--       declare
--          Argv : Split_SRP
--            := Split (Unmarshall_To_Any (Rep.all, S.Buffer_In));


--          Method     : constant String := Argv.Method.all;
--          Oid        : constant Object_Id := Argv.Oid.all;
--          Args_Array : constant Arg_Info_Ptr := Argv.Args;
--          Current    : Arg_Info_Ptr := Args_Array;

--          Req : Request_Access := null;
--          Args   : Any.NVList.Ref;
--          Args_Type_Reference : Any.NVList.Ref;
--          Result : Any.NamedValue;

--          Target_Profile :
--            Binding_Data.Profile_Access := new Local_Profile_Type;
--          Target   : References.Ref;
--          ORB      : constant ORB_Access := ORB_Access (S.Server);
--          Temp_Arg : Any.NamedValue;
--          List     : NV_Sequence_Access;

--       begin
--          Buffers.Release_Contents (S.Buffer_In.all);
--          --  Clear buffer

--         begin
--             pragma Debug (O ("Received request " & Method
--                              & " on object " & To_String (Oid)
--                              & " with args "));

--             --  Block used only for debugging
--             declare
--                procedure Print_Val (Current : Arg_Info_Ptr);
--                procedure Print_Val (Current : Arg_Info_Ptr) is
--                   Pointer : Arg_Info_Ptr := Current;
--                begin
--                   while Pointer /= null loop
--                      Put_Line
--                        (Pointer.Name.all & " = " & Pointer.Value.all);
--                      Pointer := Pointer.Next;
--                   end loop;
--                end Print_Val;
--             begin
--                pragma Debug (Print_Val (Current));
--                null;
--             end;


--             Current := Args_Array;

--             --  Stores the arguments in a NVList before creating the request
--             Any.NVList.Create (Args);
--             --  Create a new NVList where the arguments will be stored

--             Args_Type_Reference   := Obj_Adapters.Get_Empty_Arg_List
--               (Object_Adapter (ORB).all, Oid, Method);
--             --  Used only to get the types used by the method called

--             declare
--                use Droopi.Any;
--                Simple_Arg : Any.NamedValue;
--                Arg_Any : Any.Any;
--             begin
--                List := List_Of (
--                for I in 1 .. Get_Count (Args) loop
--                 Temp_Arg := NV_Sequence.Element_Of (List.all, Positive (I));

--                   case Kind () is
--                      when Tk_Null =>
--                         Set_Any_Value (Arg_Any,
--                                        Types.Octet (Current.Value));
--                      when Tk_Void =>

--                      when Tk_Short =>
--                         Set_Any_Value (Arg_Any,
--                                        Types.Short (Current.Value));
--                      when Tk_Long =>
--                         Set_Any_Value (Arg_Any,
--                                        Types.Long (Current.Value));
--                      when Tk_Ushort =>
--                         Set_Any_Value (Arg_Any,
--                                      Types.Unsigned_Short (Current.Value));
--                      when Tk_Ulong =>
--                         Set_Any_Value (Arg_Any,
--                                        Types.Unsigned_Long (Current.Value));
--                      when Tk_Float =>
--                         Set_Any_Value (Arg_Any,
--                                        Types.Float (Current.Value));
--                      when Tk_Double =>
--                         Set_Any_Value (Arg_Any,
--                                        Types.Double (Current.Value));
--                      when Tk_Boolean =>
--                         Set_Any_Value (Arg_Any,
--                                        Types.Boolean (Current.Value));
--  --                      when Tk_Char =>
--  --                      when Tk_Octet =>
--  --                      when Tk_Any =>
--  --                      when Tk_TypeCode =>
--  --                      when Tk_Principal =>
--  --                      when Tk_Objref =>
--  --                      when Tk_Struct =>
--  --                      when Tk_Union =>
--  --                      when Tk_Enum =>
--  --                      when Tk_String =>
--  --                      when Tk_Sequence =>
--  --                      when Tk_Array =>
--  --                      when Tk_Alias =>
--  --                      when Tk_Except =>
--  --                      when Tk_Longlong =>
--  --                      when Tk_Ulonglong =>
--  --                      when Tk_Longdouble =>
--  --                      when Tk_Widechar =>
--  --                      when Tk_Wstring =>
--  --                      when Tk_Fixed =>
--  --                      when Tk_Value =>
--  --                      when Tk_Valuebox =>
--  --                      when Tk_Native =>
--  --                      when Tk_Abstract_Interface =>
--                      when others =>
--                         null;
--                   end case;
--  --               while Current /= null loop
--  --                Arg_Any := To_Any (To_Droopi_String (Current.Value.all));

--                   Simple_Arg
--                     := (Name      => To_Droopi_String (Current.Name.all),
--                         Argument  => Arg_Any,
--                         Arg_Modes => Any.ARG_IN);
--                   Any.NVList.Add_Item (Args, Simple_Arg);
--                   Current := Current.Next;
--                end loop;
--             end;

--             Result :=
--               (Name     => To_Droopi_String ("Result"),
--                Argument => Obj_Adapters.Get_Empty_Result
--                (Object_Adapter (ORB).all, Oid, Method),
--                Arg_Modes => 0);

--             Create_Local_Profile
--               (Oid, Local_Profile_Type (Target_Profile.all));
--             Create_Reference ((1 => Target_Profile), Target);

--             Create_Request
--               (Target    => Target,
--                Operation => Method,
--                Arg_List  => Args,
--                Result    => Result,
--                Req       => Req);

--             Emit_No_Reply
--               (Component_Access (ORB),
--                Queue_Request'(Request   => Req,
--                               Requestor => Component_Access (S),
--                               Requesting_Task => null));

--          exception
--             when E : others =>
--                O ("Got exception: "
--                   & Ada.Exceptions.Exception_Information (E));
--  --         end;
--       end;

--       Expect_Data (S, S.Buffer_In, 1024);
--       --  XXX Not exact amount.

--       --  Prepare to receive next message.

--    end Handle_Data_Indication;

   -----------------------
   -- Handle_Disconnect --
   -----------------------

   procedure Handle_Disconnect (S : access SRP_Session) is
   begin
      pragma Debug (O ("Received disconnect."));

      --  Cleanup protocol.

      Buffers.Release (S.Buffer_In);

   end Handle_Disconnect;

   --------------------------------
   -- Unmarshall_Request_Message --
   --------------------------------

   procedure Unmarshall_Request_Message (Buffer : access Buffer_Type;
                                         Oid    : access Object_Id;
                                         Method : access Types.String)
--                                          Oid    : out Objects.Object_Id;
--                                          Method : out Types.String)
   is
      use Droopi.Objects;
   begin
      Method.all := Unmarshall (Buffer);

      declare
         Obj : Stream_Element_Array := Unmarshall (Buffer);
      begin
         Oid.all := Object_Id (Obj);
      end;
--       declare
--          Obj : Stream_Element_Array := Unmarshall (Buffer);
--       begin
--          Oid    := Object_Id (Obj);
--       end;
--       Method := Unmarshall (Buffer);
   end Unmarshall_Request_Message;

   ---------------------
   -- Unmarshall_Args --
   ---------------------
   procedure Unmarshall_Args (Buffer : access Buffer_Type;
                              Args   : in out Any.NVList.Ref)
   is
      use Droopi.Any.NVList;
      use Internals;
      use Internals.NV_Sequence;

      Args_List : NV_Sequence_Access;
      Temp_Arg  : NamedValue;
   begin
      --  By modifing Args_list, we modify directly Args
      Args_List := List_Of (Args);
      for I in 1 .. Get_Count (Args) loop
         Temp_Arg := Element_Of (Args_List.all, Positive (I));
         --  Temp_Arg is an empty any, but its type is already set

         Unmarshall (Buffer, Temp_Arg);
         Replace_Element (Args_List.all, Positive (I), Temp_Arg);
      end loop;
   end Unmarshall_Args;

   ----------------
   -- Unmarshall --
   ----------------

   function To_SEA (S : Types.String) return Stream_Element_Array;
   function To_SEA (S : Types.String) return Stream_Element_Array
   is
      Temp_S : Standard.String := To_Standard_String (S);
      Value  : Stream_Element_Array (1 .. Temp_S'Length);
   begin
      for I in Value'Range loop
         Value (I) := Stream_Element
           (Character'Pos (Temp_S (Temp_S'First +
                                   Integer (I - Value'First))));
      end loop;
      return Value;
   end To_SEA;

   procedure Unmarshall (Args : in out Any.NVList.Ref; Info_SRP : Split_SRP)
   is
      use Droopi.Any.NVList;
      use Internals;
      use Internals.NV_Sequence;
      use Droopi.Opaque;
      use Droopi.Utils;

      Args_List   : NV_Sequence_Access;
      Current_Arg : Arg_Info_Ptr := Info_SRP.Args;
      Temp_Arg  : NamedValue;
      Temp_Buffer : aliased Buffer_Type;
   begin
      --  By modifing Args_list, we modify directly Args
      Args_List := List_Of (Args);

      for I in 1 .. Get_Count (Args) loop
         Temp_Arg := Element_Of (Args_List.all, Positive (I));

         declare
            Value : aliased Stream_Element_Array :=
              To_SEA (Current_Arg.all.Value.all & ASCII.nul);
            Z : constant Zone_Access
              := Zone_Access'(Value'Unchecked_Access);
         begin
            Initialize_Buffer (Buffer     => Temp_Buffer'Access,
                               Size       => Value'Length,
                               Data       => (Zone   => Z,
                                              Offset => Z'First),
                               Endianness => Little_Endian,
                               Initial_CDR_Position => 0);
            Show (Temp_Buffer);
            Unmarshall (Temp_Buffer'Access, Temp_Arg);
            Replace_Element (Args_List.all, Positive (I), Temp_Arg);
         end;
--          declare
--             Value : aliased Stream_Element_Array := To_Stream_Element_Array
--               (To_Standard_String (Current_Arg.all.Value.all));
--             Z : constant Zone_Access
--               := Zone_Access'(Value'Unchecked_Access);
--          begin
--             Initialize_Buffer (Buffer     => Temp_Buffer'Access,
--                                Size       => Value'Length,
--                                Data       => (Zone   => Z,
--                                               Offset => Z'First),
--                                Endianness => Little_Endian,
--                                Initial_CDR_Position => 0);
--             Show (Temp_Buffer);
--          end;

         --  ??? No verification if Current_Arg si null
         Current_Arg := Current_Arg.all.Next;
      end loop;
   end Unmarshall;

end Droopi.Protocols.SRP;
