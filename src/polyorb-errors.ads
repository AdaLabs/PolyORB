------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                       P O L Y O R B . E R R O R S                        --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--            Copyright (C) 2005 Free Software Foundation, Inc.             --
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
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

--  Errors management subsystem

with Ada.Unchecked_Deallocation;
with GNAT.Source_Info;

with PolyORB.Any;
with PolyORB.Smart_Pointers;
with PolyORB.Types;

package PolyORB.Errors is

   ------------------------
   -- Exceptions Members --
   ------------------------

   --  A PolyORB error is notionally equivalent to a CORBA exception.
   --  It is composed by
   --   - Exception Id,
   --   - Exception Member.

   type Exception_Members is abstract tagged null record;
   --  Base type for all PolyORB exception members. A member is a record
   --  attached to an exception that allows the programmer to pass
   --  arguments when an exception is raised. The default Member record is
   --  abstract and empty but all other records will inherit from it.

   type Exception_Members_Access is access all Exception_Members'Class;

   procedure Free is new Ada.Unchecked_Deallocation
     (Exception_Members'Class, Exception_Members_Access);

   -----------------------
   -- Completion_Status --
   -----------------------

   type Completion_Status is
     (Completed_Yes,
      Completed_No,
      Completed_Maybe);
   --  Characterize the completion state of the execution process when
   --  systeme exception has been raised.

   To_Completion_Status :
     constant array (PolyORB.Types.Unsigned_Long range 0 .. 2)
         of Completion_Status
     := (0 => Completed_Yes, 1 => Completed_No, 2 => Completed_Maybe);

   To_Unsigned_Long :
     constant array (Completion_Status) of PolyORB.Types.Unsigned_Long
     := (Completed_Yes => 0, Completed_No => 1, Completed_Maybe => 2);

   function From_Any
     (Item : PolyORB.Any.Any)
     return Completion_Status;

   function To_Any
     (Item : Completion_Status)
     return Any.Any;

   function TC_Completion_Status
     return PolyORB.Any.TypeCode.Object;
   --  The typecode for standard enumeration type completion_status.

   --  Null_Members

   type Null_Members is new Exception_Members with null record;

   function To_Any
     (Name   : Standard.String;
      Member : Null_Members)
     return PolyORB.Any.Any;

   Null_Member : constant Null_Members
     := Null_Members'(Exception_Members with null record);

   --  System_Exception_Members

   type System_Exception_Members is new Exception_Members with record
      Minor     : PolyORB.Types.Unsigned_Long;
      Completed : Completion_Status;
   end record;

   function System_Exception_TypeCode
     (Name : Standard.String)
     return PolyORB.Any.TypeCode.Object;
   --  Return the TypeCode corresponding to the indicated
   --  system exception name.

   function To_Any
     (Name   : Standard.String;
      Member : System_Exception_Members)
     return PolyORB.Any.Any;

   --  InvalidPolicy_Members

   type InvalidPolicy_Members is new Exception_Members with record
      Index : PolyORB.Types.Short;
   end record;

   --  ForwardRequest_Members

   type ForwardRequest_Members is new Exception_Members with record
      Forward_Reference : PolyORB.Smart_Pointers.Ref;
   end record;

   function To_Any
     (Item : ForwardRequest_Members)
      return PolyORB.Any.Any;

   function From_Any
     (Item : PolyORB.Any.Any)
      return ForwardRequest_Members;

   function TC_ForwardRequest return PolyORB.Any.TypeCode.Object;

   ----------------
   -- ORB Errors --
   ----------------

   type Error_Id is
     (
      No_Error,                 --  no error

      --  One to one mapping of CORBA System exceptions.

      Unknown_E,                  --  unknown exception
      Bad_Param_E,                --  an invalid parameter was passed
      No_Memory_E,                --  dynamic memory allocation failure
      Imp_Limit_E,                --  violated implementation limit
      Comm_Failure_E,             --  communication failure
      Inv_Objref_E,               --  invalid object reference
      No_Permission_E,            --  no permission for attempted op.
      Internal_E,                 --  ORB internal error
      Marshal_E,                  --  error marshalling param/result
      Initialize_E,               --  ORB initialization failure
      No_Implement_E,             --  operation impleme. unavailable
      Bad_TypeCode_E,             --  bad typecode
      Bad_Operation_E,            --  invalid operation
      No_Resources_E,             --  insufficient resources for req.
      No_Response_E,              --  response to request not available
      Persist_Store_E,            --  persistent storage failure
      Bad_Inv_Order_E,            --  routine invocations out of order
      Transient_E,                --  transient failure - reissue request
      Free_Mem_E,                 --  cannot free memory
      Inv_Ident_E,                --  invalid identifier syntax
      Inv_Flag_E,                 --  invalid flag was specified
      Intf_Repos_E,               --  error accessing intf. repository
      Bad_Context_E,              --  error processing context object
      Obj_Adapter_E,              --  failure detected by object adapter
      Data_Conversion_E,          --  data conversion error
      Object_Not_Exist_E,         --  non-existent object, delete ref.
      Transaction_Required_E,     --  transaction required
      Transaction_Rolledback_E,   --  transaction rolled back
      Invalid_Transaction_E,      --  invalid transaction
      Inv_Policy_E,               --  invalid policy
      Codeset_Incompatible_E,     --  incompatible code set
      Rebind_E,                   --  rebind needed
      Timeout_E,                  --  operation timed out
      Transaction_Unavailable_E,  --  no transaction
      Transaction_Mode_E,         --  invalid transaction mode
      Bad_Qos_E,                  --  bad quality of service

      --  Special case for processing PortableServer's and
      --  PortableInterceptor's ForwardRequest exception.

      ForwardRequest_E,

      --  One to one mapping of POA exceptions.

      AdapterAlreadyExists_E,
      AdapterNonExistent_E,
      InvalidPolicy_E,
      NoServant_E,
      ObjectAlreadyActive_E,
      ObjectNotActive_E,
      ServantAlreadyActive_E,
      ServantNotActive_E,
      WrongAdapter_E,
      WrongPolicy_E,

      --  One to one mapping of POA Manager exceptions.

      AdapterInactive_E,

      --  PolyORB internal errors.
      Invalid_Object_Id_E,

      --  Group exception
      NotAGroupObject_E
      );

   subtype ORB_System_Error       is Error_Id
     range Unknown_E .. Bad_Qos_E;
   subtype POA_Error              is Error_Id
     range AdapterAlreadyExists_E .. WrongPolicy_E;
   subtype POAManager_Error        is Error_Id
     range AdapterInactive_E .. AdapterInactive_E;
   subtype PolyORB_Internal_Error is Error_Id
     range Invalid_Object_Id_E .. Error_Id'Last;

   ----------------------
   -- Error management --
   ----------------------

   type Error_Container is record
      Kind   : Error_Id := No_Error;
      Member : Exception_Members_Access;
   end record;

   function Found (Error : Error_Container) return Boolean;
   --  True iff Error is not null.

   procedure Throw
     (Error  : in out Error_Container;
      Kind   : in     Error_Id;
      Member : in     Exception_Members'Class;
      Where  : in     String := GNAT.Source_Info.Source_Location);
   --  Generates an error whith Kind and Member information.

   procedure Catch (Error : in out Error_Container);
   --  Acknowledge Error and reset its content.

   function Is_Error (Error : in Error_Container) return Boolean;
   --  True iff Error is not No_Error;

   function Error_To_Any (Error : in Error_Container) return PolyORB.Any.Any;

   ------------------
   -- Exception Id --
   ------------------

   --  An exception Id has the following form:
   --  NameSpace:Root'Separator' .. Version

   PolyORB_Exc_NameSpace : constant String;
   --  PolyORB exceptions namespace.

   PolyORB_Exc_Root      : constant String;
   --  PolyORB exceptions root.

   PolyORB_Exc_Separator : constant String;
   --  PolyORB exceptions separator.

   PolyORB_Exc_Prefix    : constant String;
   --  Concantenation of PolyORB_Exc_NameSpace, PolyORB_Root and
   --  PolyORB_Separator.

   PolyORB_Exc_Version   : constant PolyORB.Types.String;
   --  PolyORB exceptions version.

private

   PolyORB_Exc_NameSpace : constant String := "INTERNAL:";
   PolyORB_Exc_Root      : constant String := "POLYORB";
   PolyORB_Exc_Separator : constant String := "/";
   PolyORB_Exc_Prefix    : constant String
     := PolyORB_Exc_NameSpace
     & PolyORB_Exc_Root
     & PolyORB_Exc_Separator;

   PolyORB_Exc_Version   : constant PolyORB.Types.String
     := PolyORB.Types.To_PolyORB_String (":1.0");

end PolyORB.Errors;
