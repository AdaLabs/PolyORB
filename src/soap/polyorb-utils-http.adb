------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                   P O L Y O R B . U T I L S . H T T P                    --
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

with Ada.Streams;

with Interfaces;

package body PolyORB.Utils.HTTP is

   --------------------
   -- Base 64 Encode --
   --------------------

   function Base64_Encode (Data : Stream_Element_Array)
     return String
   is
      use Ada.Streams;
      use type Stream_Element;

      function Shift_Left
        (Value  : in Stream_Element;
         Amount : in Natural)
        return Stream_Element;
      pragma Import (Intrinsic, Shift_Left);

      function Shift_Right
        (Value  : in Stream_Element;
         Amount : in Natural)
        return Stream_Element;
      pragma Import (Intrinsic, Shift_Right);

      Encoded_Length : constant Integer
        := 4 * ((Data'Length + 2) / 3);
      Max_Line_Length : constant Integer := 72;

      Result : String
        (1 .. Encoded_Length
         + (Encoded_Length + Max_Line_Length - 1) / Max_Line_Length - 1);

      Last   : Integer := Result'First - 1;

      State  : Positive range 1 .. 3 := 1;
      E, Prev_E : Stream_Element := 0;

      Base64 : constant array (Stream_Element range 0 .. 63) of Character
        := ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
            'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
            'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
            'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
            '+', '/');

   begin
      for C in Data'Range loop
         E := Data (C);

         Last := Last + 1;
         if Last > 1 and then Last mod Max_Line_Length = 1 then
            Result (Last) := ASCII.LF;
            Last := Last + 1;
         end if;

         case State is
            when 1 =>
               Result (Last) := Base64 (Shift_Right (E, 2) and 16#3F#);
               State := 2;

            when 2 =>
               Result (Last) := Base64 ((Shift_Left (Prev_E, 4) and 16#30#)
                                        or (Shift_Right (E, 4) and 16#F#));
               State := 3;

            when 3 =>
               Result (Last) := Base64 ((Shift_Left (Prev_E, 2) and 16#3C#)
                                        or (Shift_Right (E, 6) and 16#3#));
               Last := Last + 1;
               Result (Last) := Base64 (E and 16#3F#);
               State := 1;
         end case;

         Prev_E := E;
      end loop;

      case State is
         when 1 =>
            null;
         when 2 =>
            Last := Last + 1;
            Result (Last) := Base64 (Shift_Left (Prev_E, 4) and 16#30#);
         when 3 =>
            Last := Last + 1;
            Result (Last) := Base64 (Shift_Left (Prev_E, 2) and 16#3C#);
      end case;

      pragma Assert ((Result'Last - Last) < 3);
      Result (Last + 1 .. Result'Last) := (others => '=');
      return Result;
   end Base64_Encode;

   function Base64_Encode (Data : in String) return String
   is
      use Ada.Streams;

      Stream_Data : Stream_Element_Array
        (Stream_Element_Offset (Data'First)
         .. Stream_Element_Offset (Data'Last));
   begin
      for I in Data'Range loop
         Stream_Data (Stream_Element_Offset (I)) := Character'Pos (Data (I));
      end loop;
      return Base64_Encode (Stream_Data);
   end Base64_Encode;

   -------------------
   -- Base64_Decode --
   -------------------

   function Base64_Decode (B64_Data : in String)
                          return Stream_Element_Array
   is
      use Ada.Streams;
      use Interfaces;

      function Base64 (C : in Character)
        return Interfaces.Unsigned_32;
      pragma Inline (Base64);
      --  Returns the base64 stream element given a character

      Base64_Values : constant array (Character) of Interfaces.Unsigned_32
        := ('A' => 0, 'B' => 1, 'C' => 2, 'D' => 3, 'E' => 4, 'F' => 5,
            'G' => 6, 'H' => 7, 'I' => 8, 'J' => 9, 'K' => 10, 'L' => 11,
            'M' => 12, 'N' => 13, 'O' => 14, 'P' => 15, 'Q' => 16, 'R' => 17,
            'S' => 18, 'T' => 19, 'U' => 20, 'V' => 21, 'W' => 22, 'X' => 23,
            'Y' => 24, 'Z' => 25,

            'a' => 26, 'b' => 27, 'c' => 28, 'd' => 29, 'e' => 30, 'f' => 31,
            'g' => 32, 'h' => 33, 'i' => 34, 'j' => 35, 'k' => 36, 'l' => 37,
            'm' => 38, 'n' => 39, 'o' => 40, 'p' => 41, 'q' => 42, 'r' => 43,
            's' => 44, 't' => 45, 'u' => 46, 'v' => 47, 'w' => 48, 'x' => 49,
            'y' => 50, 'z' => 51,

            '0' => 52, '1' => 53, '2' => 54, '3' => 55, '4' => 56,
            '5' => 57, '6' => 58, '7' => 59, '8' => 60, '9' => 61,

            '+' => 62,
            '/' => 63,
            others => 16#ffffffff#);

      function Shift_Left (Value  : in Interfaces.Unsigned_32;
                           Amount : in Natural) return Interfaces.Unsigned_32;
      pragma Import (Intrinsic, Shift_Left);

      function Shift_Right (Value  : in Interfaces.Unsigned_32;
                            Amount : in Natural) return Interfaces.Unsigned_32;
      pragma Import (Intrinsic, Shift_Right);

      Result : Stream_Element_Array
        (Stream_Element_Offset range 1 .. B64_Data'Length);
      R      : Stream_Element_Offset := 1;

      Group  : Interfaces.Unsigned_32 := 0;
      J      : Integer := 18;

      Pad    : Stream_Element_Offset := 0;

      function Base64 (C : in Character)
        return Interfaces.Unsigned_32 is
      begin
         pragma Assert (Base64_Values (C) < 64);
         return Base64_Values (C);
      end Base64;

   begin
      for C in B64_Data'Range loop

         if B64_Data (C) = ASCII.LF or else B64_Data (C) = ASCII.CR then
            null;

         else
            case B64_Data (C) is
               when '=' =>
                  Pad := Pad + 1;

               when others =>
                  Group := Group or Shift_Left (Base64 (B64_Data (C)), J);
            end case;

            J := J - 6;

            if J < 0 then
               Result (R .. R + 2) :=
                 (Stream_Element (Shift_Right (Group and 16#FF0000#, 16)),
                  Stream_Element (Shift_Right (Group and 16#00FF00#, 8)),
                  Stream_Element (Group and 16#0000FF#));

               R := R + 3;

               Group := 0;
               J     := 18;
            end if;

         end if;
      end loop;

      return Result (1 .. R - 1 - Pad);
   end Base64_Decode;


end PolyORB.Utils.HTTP;
