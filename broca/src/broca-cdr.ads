------------------------------------------------------------------------------
--                                                                          --
--                          ADABROKER COMPONENTS                            --
--                                                                          --
--                            B R O C A . C D R                             --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--          Copyright (C) 1999-2001 ENST Paris University, France.          --
--                                                                          --
-- AdaBroker is free software; you  can  redistribute  it and/or modify it  --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. AdaBroker  is distributed  in the hope that it will be  useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with AdaBroker; see file COPYING. If  --
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
--             AdaBroker is maintained by ENST Paris University.            --
--                     (email: broker@inf.enst.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

with CORBA;
with CORBA.AbstractBase;
with CORBA.Object;

with Broca.Buffers; use Broca.Buffers;
with Broca.Opaque;  use Broca.Opaque;

package Broca.CDR is

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Octet);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Octet);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Octet;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Char);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Char);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Char;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Wchar);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Wchar);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Wchar;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Boolean);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Boolean);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Boolean;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Unsigned_Short);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Unsigned_Short);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Unsigned_Short;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Unsigned_Long);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Unsigned_Long);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Unsigned_Long;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Unsigned_Long_Long);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Unsigned_Long_Long);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Unsigned_Long_Long;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Short);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Short);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Short;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Long);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Long);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Long;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Long_Long);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Long_Long);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Long_Long;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Float);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Float);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Float;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Double);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Double);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Double;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Long_Double);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Long_Double);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Long_Double;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access Standard.String);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in Standard.String);

   function Unmarshall (Buffer : access Buffer_Type)
     return Standard.String;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.String);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.String);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.String;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Wide_String);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Wide_String);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Wide_String;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Identifier);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Identifier);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Identifier;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.ScopedName);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.ScopedName);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.ScopedName;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.RepositoryId);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.RepositoryId);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.RepositoryId;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.ValueModifier);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.ValueModifier);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.ValueModifier;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Visibility);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Visibility);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Visibility;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Any);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Any);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.Any;

   --  The next three marshall or unmarshall the value of the any and
   --  not the any type itself.

   procedure Marshall_From_Any
     (Buffer : access Buffer_Type;
      Data   : access CORBA.Any);
   procedure Marshall_From_Any
     (Buffer : access Buffer_Type;
      Data   : in CORBA.Any);

   --  This procedure unmarshalls an Any in Result.
   --  If Result already has a value, then its memory location
   --  will be reused. Otherwise, a new location will be created
   procedure Unmarshall_To_Any (Buffer : access Buffer_Type;
                                Result : in out CORBA.Any);

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.TypeCode.Object);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.TypeCode.Object);

   function Unmarshall (Buffer : access Buffer_Type)
     return CORBA.TypeCode.Object;

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access CORBA.NamedValue);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.NamedValue);

   procedure Unmarshall (Buffer : access Buffer_Type;
                         NV : in out CORBA.NamedValue);

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : access Encapsulation);
   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in Encapsulation);

   function Unmarshall (Buffer : access Buffer_Type)
     return Encapsulation;

   procedure Start_Encapsulation
     (Buffer : access Buffer_Type);
   --  Prepare Buffer to receive marshalled data
   --  that will be turned into an Encapsulation.

   --  Marshalling and unmashalling of object references
   --  (but not valuetypes)

   procedure Marshall
     (Buffer : access Buffer_Type;
      Data   : in CORBA.AbstractBase.Ref'Class);

   procedure Unmarshall
     (Buffer : access Buffer_Type;
      Data : in out CORBA.AbstractBase.Ref'Class);

   function Unmarshall
     (Buffer : access Buffer_Type)
      return CORBA.Object.Ref;

   --  Marshalling and unmarshalling of system exceptions

   procedure Marshall
     (Buffer : access Buffer_Type;
      Excpt  : in CORBA.Exception_Occurrence);

   procedure Unmarshall_And_Raise
     (Buffer : access Buffer_Type);
   pragma No_Return (Unmarshall_And_Raise);

   --  a special subpackage for marshalling/unmarshalling of fixed type

   generic
      type F is delta <> digits <>;
   package Fixed_Point is

      procedure Marshall
        (Buffer : access Buffer_Type;
         Data   : access F);
      procedure Marshall
        (Buffer : access Buffer_Type;
         Data   : in F);

      function Unmarshall (Buffer : access Buffer_Type)
        return F;

      function Fixed_To_Octets (Data : in F)
        return Octet_Array;

      function Octets_To_Fixed (Octets : Octet_Array)
        return F;

   end Fixed_Point;

end Broca.CDR;
