with All_Types.Skel;
with CORBA;
--with CORBA.Object;

package all_types.Impl is
   --  My own implementation of echo object.
   --  This is simply used to define the operations.

   type Object is new All_Types.Skel.Object with private;

   type Object_Acc is access all Object;

private

   type Object is new All_Types.Skel.Object with null record;
--      Pd_Col : Color := Blue ;
--      Pd_Ex : Example := (Switch => 1, Counter => 23) ;
--   end record;

   function echoBoolean
     (Self : access Object;
      arg : in CORBA.Boolean)
      return CORBA.Boolean;

   function echoShort
     (Self : access Object;
      arg : in CORBA.Short)
      return CORBA.Short;

   function echoLong
     (Self : access Object;
      arg : in CORBA.Long)
      return CORBA.Long;

   function echoUShort
     (Self : access Object;
      arg : in CORBA.Unsigned_Short)
      return CORBA.Unsigned_Short;

   function echoULong
     (Self : access Object;
      arg : in CORBA.Unsigned_Long)
      return CORBA.Unsigned_Long;

   function echoFloat
     (Self : access Object;
      arg : in CORBA.Float)
      return CORBA.Float;

   function echoDouble
     (Self : access Object;
      arg : in CORBA.Double)
      return CORBA.Double;

   function echoChar
     (Self : access Object;
      arg : in CORBA.Char)
      return CORBA.Char;

   function echoOctet
     (Self : access Object;
      arg : in CORBA.Octet)
      return CORBA.Octet;

   function echoString
     (Self : access Object;
      arg : in CORBA.String)
      return CORBA.String;

   function echoRef
     (Self : access Object;
      arg : in Ref)
      return Ref;

   function echoColor
     (Self : access Object;
      arg  : in Color)
      return Color;

   function EchoArray
     (Self : access Object;
      Arg : in Simple_Array)
      return Simple_Array;

   procedure TestException
     (Self : access Object);

   function echoStruct
     (Self : access Object;
      arg  : in Simple_Struct)
      return Simple_Struct;

--   procedure simple_exception_test
--     (Self : access Object);
--
--   procedure complexe_exception_test
--     (Self : access Object);
--
--   function echo1
--     (Self : access Object;
--      arg : in example)
--      return example;
--
--   function echo2
--     (Self : access Object;
--      arg : in simple_struct)
--      return simple_struct;
--
--   function InverseStruct
--     (Self : access Object;
--      Arg : in Manu_Struct)
--      return Manu_Struct;
--
--
--   function echo3
--     (Self : access Object;
--      arg : in Color)
--      return Color;
--
--   function echo4
--     (Self : access Object;
--      arg : in U_string)
--      return U_string;
--
--   function echo6
--     (Self : access Object;
--      arg : in U_sequence)
--      return U_sequence;
--
--   function echo7
--     (Self : access Object;
--      arg : in B_sequence)
--      return B_sequence;
--
--   function Get_R_attribute
--     (Self : access Object)
--      return Color;
--
--   function Get_N_attribute
--     (Self : access Object)
--      return example;
--
--   procedure Set_N_attribute
--     (Self : access Object;
--      To   : in example);
--
--   function echo8
--     (Self : access Object;
--      arg : in line)
--      return line;
--
--   function echo9
--     (Self : access Object;
--      arg : in square)
--      return square;
--
--   function echo10
--     (Self : access Object;
--      arg : in cube)
--      return cube;
--
--   function echo11
--     (Self : access Object;
--      arg : in Ref)
--      return Ref;
--
--   function echo12
--     (Self : access Object;
--      arg : in CORBA.Object.Ref)
--      return CORBA.Object.Ref;
--
--   function get_myself
--     (Self : access Object)
--      return Ref;
--

end all_types.Impl;
