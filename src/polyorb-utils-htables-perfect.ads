------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--        P O L Y O R B . U T I L S . H T A B L E S . P E R F E C T         --
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

--  This package provides dynamic perfect hash tables; it implements
--  the Dietzfelbinger algorithm as described in "Dynamic Perfect
--  Hashing: Upper and Lower Bounds", Dietzfelbinger et al.  in SIAM
--  Journal on Computing, 1994, pp 738-761.

--  This algorithm provides dynamic perfect hash table with
--  - O (1) worst-case time for lookups and deletions,
--  - O (1) amortized expected time for insertions.

--  $Id$

with PolyORB.Utils.Dynamic_Tables;
with PolyORB.Utils.Strings;

generic
   type Item is private;

package PolyORB.Utils.HTables.Perfect is
   pragma Preelaborate;

   use type PolyORB.Utils.Strings.String_Ptr;
   subtype String_Access is PolyORB.Utils.Strings.String_Ptr;

   No_Key : exception renames PolyORB.Utils.HTables.No_Key;

   type Item_Access is access all Item;

   type Table is private;
   type Table_Access is access all Table;

   type Table_Instance is record
      T : Table_Access;
   end record;

   Default_Prime : constant := 1777771;
   Default_Max   : constant := 10;

   procedure Initialize
     (T      : out Table_Instance;
      Prime  : Natural := Default_Prime;
      Max    : Natural := Default_Max);
   --  Initialize the hash table.
   --  'Prime' is a prime number used by hash functions.
   --  'Max' is the max number of elements to store.

   procedure Finalize
     (T : in out Table_Instance);
   --  Finalize the hash table.

   function Lookup
     (T           : Table_Instance;
      Key         : String;
      Error_Value : Item)
      return Item;
   --  Find 'Key' in hash table and return its associated Item.
   --  When 'Key' does not exist, the function returns 'Error_Value'.

   function Lookup
     (T     : Table_Instance;
      Key   : String)
      return Item;
   --  Find 'Key' in hash table and return its associated Item.
   --  When 'Key' does not exist, the function raise 'No_Key' exception.

   procedure Insert
     (T     : Table_Instance;
      Key   : String;
      Value : Item);
   --  Insert (Key, Value) in hash table.
   --  'Key' is the string to hash and 'Value' its associated Item.
   --  If 'Key' already exists, nothing is done.

   --  Note : this procedure reorganizes, if necessary, the table or
   --  the sub_tables, leading to amortized O (1) complexity only.

   procedure Delete
     (T   : Table_Instance;
      Key : String);
   --  Delete key in hash table. In case of a non-existing Key, Delete
   --  ignores deletion. Key is the string to hash. This procedure only put
   --  the flag Used to False. Deallocations appears only after reorganisation
   --  of the table or a sub-table (procedure Insert)

private
   --  A Hash table is the agregation of an Hash_Table index table
   --  (non-generic) and and an array of item (generic) which contains
   --  the values stored.  The Hash_Table type is an index table that
   --  contains the actual position of an Item in the array of item.

   --  As described in the Dietzfelbinger algorithm, the Hash Table is
   --  divided into several tables, each of which contains several
   --  items.

   --  The Hash_Table index uses different structures to map an
   --  element to its associated item.

   --  'Element' type.

   type Element is record
      Key        : String_Access;  --  Key of the element to hash.
      Used       : Boolean;        --  Is the slot really used ?
      ST_Index   : Natural;        --  Index in the Sub Table.
      ST_Offset  : Natural;        --  Offset in the Sub Table.
      Item_Index : Natural;        --  Index of the element.
   end record;

   Empty : constant Element := Element'(null, False, 0, 0, 0);

   package Dynamic_Element_Array is new
     PolyORB.Utils.Dynamic_Tables (Element, Natural, 0, 10, 50);
   use Dynamic_Element_Array;

   subtype Element_Array is Dynamic_Element_Array.Instance;

   --  'Subtable' type.

   type Subtable is record
      First  : Natural;  --  'First subtable index.
      Last   : Natural;  --  'Last subtable index.
      Count  : Natural;  --  Number of elements used.
      High   : Natural;  --  Highest count value before reorganization.
      Max    : Natural;  --  Subtable maximum size.
      K      : Natural;  --  K-parameter of the subtable.
   end record;

   package Dynamic_Subtable_Array is new
     PolyORB.Utils.Dynamic_Tables (Subtable, Natural, 0, 10, 50);
   use Dynamic_Subtable_Array;

   subtype Subtable_Array is Dynamic_Subtable_Array.Instance;

   --  'Table_Info' type.

   type Table_Info is record
      Prime        : Natural;  --  Used by the algorithm, user defined.
      Count        : Natural;  --  Number of Key stored in the table.
      High         : Natural;  --  When Count = High, the table is resized.
      N_Subtables  : Natural;  --  Number of subtables.
      K            : Natural;  --  K-parameter of the subtable.
   end record;

   --  The Hash table index.

   type Hash_Table is record
      Info      : Table_Info;      --  Table information.
      Elements  : Element_Array;   --  Placeholder for elements.
      Subtables : Subtable_Array;  --  Sub tables information.
   end record;
   --  Each structure of the array contains the parameters for the sub-table
   --  hash function except the prime number stored in Info.Prime. In addition
   --  it contains the limit of each sub-table in the table Elements.
   --  We can note that :
   --          ..< Subtables.all (i).First   < Subtables.all (i).Last   <
   --              Subtables.all (i+1).First < Subtables.all (i+1).Last <..

   --  Item_Array

   package Dynamic_Item_Array is new
     PolyORB.Utils.Dynamic_Tables (Item_Access, Natural, 0, 10, 50);
   use Dynamic_Item_Array;

   subtype Item_Array is Dynamic_Item_Array.Instance;

   --  'Table' type.

   type Table is record
      HTable : Hash_Table;
      Items  : Item_Array;
   end record;
   --  Table is the agregation of an Hash_Table (non-generic) and
   --  and an array (generic) which contains the Values associated
   --  with the Keys. We can note that HTable.Elements.all and Items.all
   --  have the same size. Indeed if a Key is stored in HTable.Elements(i)
   --  then his value is stored in Items(HTable.Elements(i).Item_Index)

end PolyORB.Utils.HTables.Perfect;
