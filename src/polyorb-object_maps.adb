------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--              P O L Y O R B . O B J E C T _ M A P S . S E Q               --
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

package body PolyORB.Object_Maps is

   use Map_Entry_Seqs;
   use PolyORB.POA_Types;

   -------------
   -- Is_Null --
   -------------

   function Is_Null
     (Item : in Object_Map_Entry_Access)
     return Boolean;

   function Is_Null
     (Item : in Object_Map_Entry_Access)
     return Boolean
   is
   begin
      return (Item = null);
   end Is_Null;

   ---------
   -- Add --
   ---------

   function Add
     (O_Map : access Object_Map;
      Obj   : in     Object_Map_Entry_Access)
     return Integer
   is
      Elts  : constant Element_Array := To_Element_Array (O_Map.Map);
   begin
      for I in Elts'Range loop
         if Is_Null (Elts (I)) then
            Replace_Element (O_Map.Map, 1 + I - Elts'First, Obj);
            return I;
         end if;
      end loop;

      Append (O_Map.Map, Obj);
      return Elts'Last + 1;
   end Add;

   -------------------
   -- Is_Servant_In --
   -------------------

   function Is_Servant_In
     (O_Map : in Object_Map;
      Item  : in PolyORB.Servants.Servant_Access)
     return Boolean
   is
   begin
      return not Is_Null (Get_By_Servant (O_Map, Item));
   end Is_Servant_In;

   ---------------------
   -- Is_Object_Id_In --
   ---------------------

   function Is_Object_Id_In
     (O_Map : in Object_Map;
      Item  : in PolyORB.POA_Types.Unmarshalled_Oid)
     return Boolean
   is
   begin
      return not Is_Null (Get_By_Id (O_Map, Item));
   end Is_Object_Id_In;

   ---------------
   -- Get_By_Id --
   ---------------

   function Get_By_Id
     (O_Map : in Object_Map;
      Item  : in PolyORB.POA_Types.Unmarshalled_Oid)
     return Object_Map_Entry_Access
   is
      Elts  : constant Element_Array := To_Element_Array (O_Map.Map);
   begin
      for I in Elts'Range loop
         if not Is_Null (Elts (I))
           and then Elts (I).Oid.all = Item
         then
            return Elts (I);
         end if;
      end loop;
      return null;
   end Get_By_Id;

   --------------------
   -- Get_By_Servant --
   --------------------

   function Get_By_Servant
     (O_Map  : in Object_Map;
      Item   : in PolyORB.Servants.Servant_Access)
     return Object_Map_Entry_Access
   is
      use type PolyORB.Servants.Servant_Access;
      Elts  : constant Element_Array := To_Element_Array (O_Map.Map);
   begin
      for I in Elts'Range loop
         if not Is_Null (Elts (I))
           and then Elts (I).Servant = Item
         then
            return Elts (I);
         end if;
      end loop;
      return null;
   end Get_By_Servant;

   ------------
   -- Remove --
   ------------

   function Remove_By_Id
     (O_Map : access Object_Map;
      Item  : in     PolyORB.POA_Types.Unmarshalled_Oid)
     return Object_Map_Entry_Access
   is
      Elts  : constant Element_Array := To_Element_Array (O_Map.Map);
   begin
      for J in Elts'Range loop
         if not Is_Null (Elts (J))
           and then Elts (J).Oid.all = Item
         then
            declare
               Old_Entry : constant Object_Map_Entry_Access
                 := Element_Of (O_Map.Map, J);
            begin
               Replace_Element (O_Map.Map, J, null);
               return Old_Entry;
            end;
         end if;
      end loop;
      return null;
   end Remove_By_Id;

end PolyORB.Object_Maps;
