------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--            P O L Y O R B . R E F E R E N C E S . C O R B A L O C         --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2003 Free Software Foundation, Inc.             --
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

with Ada.Strings;
with Ada.Strings.Unbounded;


with PolyORB.Binding_Data;
with PolyORB.Initialization;
pragma Elaborate_All (PolyORB.Initialization); --  WAG:3.15
with PolyORB.Log;
with PolyORB.Types;
with PolyORB.Utils.Strings;

package body PolyORB.References.Corbaloc is

   use Ada.Strings.Unbounded;

   use PolyORB.Binding_Data;
   use PolyORB.Log;
   use PolyORB.Utils.Strings;

   package L is new PolyORB.Log.Facility_Log ("polyorb.references.corbaloc");
   procedure O (Message : in String; Level : Log_Level := Debug)
     renames L.Output;

   type Profile_Record is record
      Tag                    : PolyORB.Binding_Data.Profile_Tag;
      Proto_Ident            : Types.String;
      Profile_To_String_Body : Profile_To_String_Body_Type;
      String_To_Profile_Body : String_To_Profile_Body_Type;
   end record;

   package Profile_Record_Seq is
      new PolyORB.Sequences.Unbounded (Profile_Record);

   use Profile_Record_Seq;

   Callbacks : Profile_Record_Seq.Sequence;

   Null_String : constant Types.String
     := Types.String (Null_Unbounded_String);

   type Tag_Array is array (Natural range <>) of Profile_Tag;

   procedure Get_Corbaloc_List
     (Corbaloc      :        Corbaloc_Type;
      Corbaloc_List :    out String_Array;
      Tag_List      :    out Tag_Array;
      N             :    out Natural);

   procedure Get_Corbaloc_List
     (Corbaloc      :        Corbaloc_Type;
      Corbaloc_List :    out String_Array;
      Tag_List      :    out Tag_Array;
      N             :    out Natural)
   is
      use PolyORB.Types;

      Profs    : constant Profile_Array
        := Profiles_Of (Corbaloc);
      Str : Types.String;
   begin
      N := 0;
      for J in Profs'Range loop
         Str := Profile_To_String (Profs (J));
         if Length (Str) /= 0 then
            N := N + 1;
            Corbaloc_List (N) := Str;
            Tag_List (N) := Get_Profile_Tag (Profs (J).all);
         end if;
      end loop;
      pragma Debug (O ("Profile found :" & N'Img));
   end Get_Corbaloc_List;

   -----------------------
   -- Profile_To_String --
   -----------------------

   function Profile_To_String
     (P : Binding_Data.Profile_Access)
     return Types.String
   is
      use PolyORB.Types;
   begin
      pragma Assert (P /= null);
      pragma Debug (O ("Profile to string with tag:"
                       & Get_Profile_Tag (P.all)'Img));

      for J in 1 .. Length (Callbacks) loop
         declare
            T : constant Profile_Tag
              := Get_Profile_Tag (P.all);

            Info : constant Profile_Record
              := Element_Of (Callbacks, J);
         begin
            if T = Info.Tag then
               declare
                  Str : constant Types.String
                    := Info.Profile_To_String_Body (P);
               begin
                  if Length (Str) /= 0 then
                     pragma Debug (O ("Profile ok"));
                     return Str;
                  else
                     pragma Debug (O ("Profile not ok"));
                     return Null_String;
                  end if;
               end;
            end if;
         end;
      end loop;
      pragma Debug (O ("Profile not ok"));
      return Null_String;
   end Profile_To_String;

   -----------------------
   -- String_To_Profile --
   -----------------------

   function String_To_Profile
     (Str : Types.String)
     return Binding_Data.Profile_Access
   is
      use PolyORB.Types;
   begin
      pragma Debug (O (To_Standard_String (Str)));
      for J in 1 .. Length (Callbacks) loop
         declare
            Ident : Types.String
              renames Element_Of (Callbacks, J).Proto_Ident;
         begin
            if Length (Str) > Length (Ident)
              and then To_String (Str) (1 .. Length (Ident)) = Ident then
               pragma Debug
                 (O ("Try to unmarshall profile with profile factory tag "
                     & Element_Of (Callbacks, J).Tag'Img));
               return Element_Of (Callbacks, J).String_To_Profile_Body (Str);
            end if;
         end;
      end loop;
      pragma Debug (O ("Profile not found for : "
                       & To_Standard_String (Str)));
      return null;
   end String_To_Profile;

   ----------------------------------------
   -- Object_To_String_With_Best_Profile --
   ----------------------------------------

   function Object_To_String_With_Best_Profile
     (Corbaloc : Corbaloc_Type)
     return Types.String
   is
   begin
      pragma Debug (O ("Create corbaloc with best profile: Enter"));

      if Is_Nil (Corbaloc) then
         pragma Debug (O ("Corbaloc Empty"));
         return Corbaloc_Prefix;
      else
         declare
            use PolyORB.Types;

            N : Natural;
            TL : Tag_Array (1 .. Length (Callbacks));
            SL : String_Array (1 .. Length (Callbacks));
            Profs    : constant Profile_Array
              := Profiles_Of (Corbaloc);
            Best_Preference : Profile_Preference := Profile_Preference'First;
            Best_Profile_Index : Integer := 0;
            Str : Types.String := Corbaloc_Prefix;
         begin
            Get_Corbaloc_List (Corbaloc, SL, TL, N);
            for J in Profs'Range loop
               declare
                  P : constant Profile_Preference
                    := Get_Profile_Preference (Profs (J).all);
               begin
                  if P > Best_Preference then
                     for K in TL'Range loop
                        if TL (K) = Get_Profile_Tag (Profs (J).all) then
                           Best_Preference := P;
                           Best_Profile_Index := K;
                        end if;
                     end loop;
                  end if;
               end;
            end loop;
            if Best_Profile_Index = 0 then
               return Corbaloc_Prefix;
            end if;
            Str := SL (Best_Profile_Index);
            pragma Debug (O ("Create corbaloc with best profile: Leave"));
            return Corbaloc_Prefix & Str;
         end;
      end if;
   end Object_To_String_With_Best_Profile;

   ----------------------
   -- Object_To_String --
   ----------------------

   function Object_To_String
     (Corbaloc : Corbaloc_Type;
      Profile  : PolyORB.Binding_Data.Profile_Tag)
     return Types.String
   is
      use PolyORB.Types;

      Profs    : constant Profile_Array
        := Profiles_Of (Corbaloc);
      Str : Types.String;
   begin
      for J in Profs'Range loop
         if Get_Profile_Tag (Profs (J).all) = Profile then
            Str := Profile_To_String (Profs (J));
            if Length (Str) /= 0 then
               return Str;
            end if;
         end if;
      end loop;
      return Corbaloc_Prefix;
   end Object_To_String;

   -----------------------
   -- Object_To_Strings --
   -----------------------

   function Object_To_Strings
     (Corbaloc : Corbaloc_Type)
     return String_Array
   is
      N : Natural;
      TL : Tag_Array (1 .. Length (Callbacks));
      SL : String_Array (1 .. Length (Callbacks));
   begin
      Get_Corbaloc_List (Corbaloc, SL, TL, N);
      return SL (1 .. N);
   end Object_To_Strings;

   ----------------------
   -- String_To_Object --
   ----------------------

   function String_To_Object
     (Str : Types.String)
     return Corbaloc_Type
   is
      use PolyORB.Types;
      use Profile_Seqs;

      Result : Corbaloc_Type;
      Len    : constant Integer := Length (Corbaloc_Prefix);
      Pro    : Profile_Access;
   begin
      pragma Debug (O ("Try to decode Corbaloc: enter "));
      if Length (Str) > Len
        and then
        To_String (Str) (1 .. Len) = Corbaloc_Prefix then
         Pro := String_To_Profile
           (To_PolyORB_String
            (To_Standard_String (Str) (Len + 1 .. Length (Str))));
         if Pro /= null then
            Create_Reference
              ((1 => Pro),
               "",
               References.Ref (Result));
         end if;
      end if;
      pragma Debug (O ("Try to decode Corbaloc: leave "));
      return Result;
   end String_To_Object;

   --------------
   -- Register --
   --------------

   procedure Register
     (Tag                    : in PolyORB.Binding_Data.Profile_Tag;
      Proto_Ident            : in Types.String;
      Profile_To_String_Body : in Profile_To_String_Body_Type;
      String_To_Profile_Body : in String_To_Profile_Body_Type)
   is
      Elt : constant Profile_Record
        := (Tag,
            Proto_Ident,
            Profile_To_String_Body,
            String_To_Profile_Body);
   begin
      Append (Callbacks, Elt);
   end Register;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize;

   procedure Initialize is
   begin
      Register (Corbaloc_Prefix, String_To_Object'Access);
   end Initialize;

   use PolyORB.Initialization;
   use PolyORB.Initialization.String_Lists;

begin
   Register_Module
     (Module_Info'
      (Name      => +"references.corbaloc",
       Conflicts => Empty,
       Depends   => Empty,
       Provides  => Empty,
       Init      => Initialize'Access));
end PolyORB.References.Corbaloc;
