-----------------------------------------------------------------------
-----------------------------------------------------------------------
----                                                               ----
----                         AdaBroker                             ----
----                                                               ----
----                 package Corba.Exceptions                      ----
----                                                               ----
----                                                               ----
----   Copyright (C) 1999 ENST                                     ----
----                                                               ----
----   This file is part of the AdaBroker library                  ----
----                                                               ----
----   The AdaBroker library is free software; you can             ----
----   redistribute it and/or modify it under the terms of the     ----
----   GNU Library General Public License as published by the      ----
----   Free Software Foundation; either version 2 of the License,  ----
----   or (at your option) any later version.                      ----
----                                                               ----
----   This library is distributed in the hope that it will be     ----
----   useful, but WITHOUT ANY WARRANTY; without even the implied  ----
----   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR     ----
----   PURPOSE.  See the GNU Library General Public License for    ----
----   more details.                                               ----
----                                                               ----
----   You should have received a copy of the GNU Library General  ----
----   Public License along with this library; if not, write to    ----
----   the Free Software Foundation, Inc., 59 Temple Place -       ----
----   Suite 330, Boston, MA 02111-1307, USA                       ----
----                                                               ----
----                                                               ----
----                                                               ----
----   Description                                                 ----
----   -----------                                                 ----
----                                                               ----
----     This package is a sub package of package corba dealing    ----
----   with Corba exceptions.                                      ----
----     It provides two main functions : Raise_corba_Exception    ----
----   and Get_Members. These functions allows the programmer to   ----
----   associate to each exception a "memmber" structure with      ----
----   all kinds of datas he needs.                                ----
----                                                               ----
----                                                               ----
----   authors : Sebastien Ponce, Fabien Azavant                   ----
----   date    : 02/28/99                                          ----
----                                                               ----
-----------------------------------------------------------------------
-----------------------------------------------------------------------


with Ada.Unchecked_Conversion ;
with Interfaces.C ;
with System ;

package body Corba.Exceptions is

   type ID_Num is mod 65000 ;
   ID_Number : ID_Num := 0;
   -- Number of exceptions raised until now
   -- used to build an identifier for each exception


   type Cell ;
   type Cell_Ptr is access all Cell ;
   type Cell (N : Positive) is
      record
         Value : Idl_Exception_Members_Ptr ;
         ID : Standard.String (1..N) ;
         Next : Cell_Ptr ;
      end record ;
   -- Definition of type list of Idl_Exception_Members in order to store
   -- the different member object waiting for their associated exception
   -- to be catched.
   -- Actually, this list works as a stack since the last exception raised
   -- may be the first catched.
   -- Each member is associated to a string which references it and allows
   -- the procedure Get_Members to find it again since the corresponding
   -- exception will be raised with the same string as message.
   -- Actually, the string is the image of ID_Number that is incremented
   -- each time an exception is raised.

   Member_List : Cell_Ptr := null ;
   -- list of members


   -- Free : free the memory
   -------------------------
   procedure Free is new Ada.Unchecked_Deallocation(Cell, Cell_Ptr) ;


   -- Put : add a member to the list
   ---------------------------------
   procedure Put (V : in Idl_Exception_Members'Class ;
                  ID_V : in Standard.String) is
      Temp : Cell_Ptr ;
   begin
      -- makes a new cell ...
      Temp := new Cell'(N => ID_V'Length,
                        Value => new Idl_Exception_Members'Class'(V),
                        ID => ID_V,
                        Next => Member_List) ;
      -- ... and add it in front of the list
      Member_List := Temp ;
   end ;


   -- Get : get a member from the list
   ------------------------------------
   function Get (From : in Ada.Exceptions.Exception_Occurrence)
                 return Idl_Exception_Members'Class is
      Temp, Old_Temp : Cell_Ptr ;
      -- pointers on the cell which is beeing process and on the previous cell
      ID : Standard.String := Ada.Exceptions.Exception_Message (From) ;
      -- reference of the searched member
   begin
      Old_Temp := null ;
      Temp := Member_List ;
      loop
         if Temp.all.ID = ID
         then
            declare
               -- we found the member associated to From
               Member : Idl_Exception_Members'Class := Temp.all.Value.all ;
            begin
               -- we can suppress the correponding cell
               if Old_Temp = null
               then
                  -- temp was the first cell
                  Member_List := Temp.all.Next ;
               else
                  -- temp was not the first cell
                  Old_Temp.all.Next := Temp.all.Next ;
               end if ;
               -- and free the memory
               Free (Ex_Body_Ptr (Temp.all.Value)) ;
               Free (Temp) ;
               -- at last, return the result
               return Member ;
            end ;
         else
            -- if the end of list is reached
            if Temp.all.Next = null
            then
               -- raise an Ada Exception AdaBroker_Fatal_Error
               Ada.Exceptions.Raise_Exception (AdaBroker_Fatal_Error'Identity,
                                               "Corba.exceptions.Get (Standard.String)"
                                               & Corba.CRLF
                                               & "Member associated to exception "
                                               & Ada.Exceptions.Exception_Name (From)
                                               & " not found.") ;
            else
               -- else go to the next element of the list
               Old_Temp := Temp ;
               Temp := Temp.all.Next ;
            end if ;
         end if ;
      end loop ;
   end ;


   -- Get_Members
   --------------
   procedure Get_Members (From : in Ada.Exceptions.Exception_Occurrence;
                          To : out Idl_Exception_Members'Class) is
   begin
      To := Get (From) ;
   end ;


   -- Raise_Corba_exception
   ------------------------
   procedure Raise_Corba_Exception(Excp : in Ada.Exceptions.Exception_Id ;
                                   Excp_Memb: in Idl_Exception_Members'Class) is
      ID : Standard.String := ID_Num'Image(ID_Number) ;
   begin
      -- stores the member object
      Put (Excp_Memb,ID) ;
      -- raises the Ada exception with the ID String as message
      Ada.Exceptions.Raise_Exception (Excp,ID) ;
   end ;


   -- Completion_Status_To_C_Int
   -----------------------------
   function Completion_Status_To_C_Int (Status : in Corba.Completion_Status)
                                        return Interfaces.C.Int is
   begin
      case Status is
         when Corba.Completed_Yes =>
            return Interfaces.C.Int (0) ;
         when Corba.Completed_No =>
            return Interfaces.C.Int (1) ;
         when Corba.Completed_Maybe =>
            return Interfaces.C.Int (2) ;
      end case ;
   end;


   -- C_Int_To_Completion_Status
   -----------------------------
   function C_Int_To_Completion_Status (N : in Interfaces.C.Int)
                                        return Corba.Completion_Status is
   begin
      case N is
         when 1 =>
            return Corba.Completed_Yes ;
         when 2 =>
            return Corba.Completed_No ;
         when 3 =>
            return Corba.Completed_Maybe ;
         when others =>
            Ada.Exceptions.Raise_Exception (Corba.AdaBroker_Fatal_Error'Identity,
                                            "Expected Completion_Status in C_Int_To_Completion_Status" & Corba.CRLF &
                                            "Int out of range" & Corba.CRLF &
                                            "(see corba_exceptions.adb L210)");
      end case ;
   end ;


   -- Ada_To_C_Unsigned_Long
   -------------------------
   function Ada_To_C_Unsigned_Long is
     new Ada.Unchecked_Conversion (Corba.Unsigned_Long,
                                   Interfaces.C.Unsigned_Long) ;
   -- needed to change ada type Corba.Unsigned_Long
   -- into C type Interfaces.C.Unsigned_Long


   -- C_Omni_Call_Transient_Exeption_Handler
   -----------------------------------------
   function C_Omni_Call_Transient_Exeption_Handler
     (Obj : in System.Address ;
      Retries : in Interfaces.C.Unsigned_Long ;
      Minor : in Interfaces.C.Unsigned_Long ;
      Status : in Interfaces.C.Int)
      return Sys_Dep.C_Boolean ;
   pragma Import (CPP,
                  C_Omni_Call_Transient_Exeption_Handler,
                  "_omni_callTransientExceptionHandler__FP10omniObjectUlUlQ25CORBA16CompletionStatus") ;


   -- Omni_Call_Transient_Exception_Handler
   ----------------------------------------
   function Omni_Call_Transient_Exception_Handler
     (Obj : in Omniobject.Object'Class ;
      Retries : in Corba.Unsigned_Long ;
      Minor : in Corba.Unsigned_Long ;
      Status : in Corba.Completion_Status)
      return Corba.Boolean is
      C_Obj : System.Address ;
      C_Retries : Interfaces.C.Unsigned_Long ;
      C_Minor : Interfaces.C.Unsigned_Long ;
      C_Status : Interfaces.C.Int ;
      C_Result : Sys_Dep.C_Boolean ;
   begin
      -- transforms the arguments in a C type ...
      C_Obj := Obj'Address ;
      C_Retries := Ada_To_C_Unsigned_Long (Retries) ;
      C_Minor := Ada_To_C_Unsigned_Long (Minor) ;
      C_Status := Completion_Status_To_C_Int (Status) ;
      -- ... calls the C function ...
      C_Result := C_Omni_Call_Transient_Exeption_Handler (C_Obj,
                                                          C_Retries,
                                                          C_Minor,
                                                          C_Status) ;
      -- ... and transforms the result into an Ada type
      return Sys_Dep.Boolean_C_To_Ada (C_Result) ;
   end ;


   -- C_Omni_Comm_Failure_Exception_Handler
   ----------------------------------------
   function C_Omni_Comm_Failure_Exception_Handler
     (Obj : in System.Address ;
      Retries : in Interfaces.C.Unsigned_Long ;
      Minor : in Interfaces.C.Unsigned_Long ;
      Status : in Interfaces.C.Int)
      return Sys_Dep.C_Boolean ;
   pragma Import (CPP,
                  C_Omni_Comm_Failure_Exception_Handler,
                  "_omni_callCommFailureExceptionHandler__FP10omniObjectUlUlQ25CORBA16CompletionStatus") ;


   -- Omni_Comm_Failure_Exception_Handler
   --------------------------------------
   function Omni_Comm_Failure_Exception_Handler
     (Obj : in Omniobject.Object'Class ;
      Retries : in Corba.Unsigned_Long ;
      Minor : in Corba.Unsigned_Long ;
      Status : in Corba.Completion_Status)
      return Corba.Boolean is
      C_Obj : System.Address ;
      C_Retries : Interfaces.C.Unsigned_Long ;
      C_Minor : Interfaces.C.Unsigned_Long ;
      C_Status : Interfaces.C.Int ;
      C_Result : Sys_Dep.C_Boolean ;
   begin
      -- transforms the arguments in a C type ...
      C_Obj := Obj'Address ;
      C_Retries := Ada_To_C_Unsigned_Long (Retries) ;
      C_Minor := Ada_To_C_Unsigned_Long (Minor) ;
      C_Status := Completion_Status_To_C_Int (Status) ;
      -- ... and calls the C function
      C_Result := C_Omni_Comm_Failure_Exception_Handler (C_Obj,
                                                         C_Retries,
                                                         C_Minor,
                                                         C_Status) ;
      -- ... and transforms the result into an Ada type
      return Sys_Dep.Boolean_C_To_Ada (C_Result) ;
   end ;


   -- C_Omni_System_Exception_Handler
   ----------------------------------
   function C_Omni_System_Exception_Handler
     (Obj : in System.Address ;
      Retries : in Interfaces.C.Unsigned_Long ;
      Minor : in Interfaces.C.Unsigned_Long ;
      Status : in Interfaces.C.Int)
      return Sys_Dep.C_Boolean ;
   pragma Import (CPP,
                  C_Omni_System_Exception_Handler,
                  "_omni_callSystemExceptionHandler__FP10omniObjectUlUlQ25CORBA16CompletionStatus") ;


   -- Omni_System_Exception_Handler
   --------------------------------
   function Omni_System_Exception_Handler
     (Obj : in Omniobject.Object'Class ;
      Retries : in Corba.Unsigned_Long ;
      Minor : in Corba.Unsigned_Long ;
      Status : in Corba.Completion_Status)
      return Corba.Boolean is
      C_Obj : System.Address ;
      C_Retries : Interfaces.C.Unsigned_Long ;
      C_Minor : Interfaces.C.Unsigned_Long ;
      C_Status : Interfaces.C.Int ;
      C_Result : Sys_Dep.C_Boolean ;
   begin
      -- transforms the arguments in a C type ...
      C_Obj := Obj'Address ;
      C_Retries := Ada_To_C_Unsigned_Long (Retries) ;
      C_Minor := Ada_To_C_Unsigned_Long (Minor) ;
      C_Status := Completion_Status_To_C_Int (Status) ;
      -- ... and calls the C function
      C_Result := C_Omni_System_Exception_Handler (C_Obj,
                                                   C_Retries,
                                                   C_Minor,
                                                   C_Status) ;
      -- ... and transforms the result into an Ada type
      return Sys_Dep.Boolean_C_To_Ada (C_Result) ;
   end ;


   -- C_Omni_Object_Not_Exist_Exception_Handler
   --------------------------------------------
   function C_Omni_Object_Not_Exist_Exception_Handler
     (Obj : in System.Address ;
      Retries : in Interfaces.C.Unsigned_Long ;
      Minor : in Interfaces.C.Unsigned_Long ;
      Status : in Interfaces.C.Int)
      return Sys_Dep.C_Boolean ;
   pragma Import (CPP,
                  C_Omni_Object_Not_Exist_Exception_Handler,
                  "_omni_callObjectNotExistExceptionHandler__FP10omniObjectUlUlQ25CORBA16CompletionStatus") ;


   -- Omni_Object_Not_Exist_Exception_Handler
   ------------------------------------------
   function Omni_Object_Not_Exist_Exception_Handler
     (Obj : in Omniobject.Object'Class ;
      Retries : in Corba.Unsigned_Long ;
      Minor : in Corba.Unsigned_Long ;
      Status : in Corba.Completion_Status)
      return Corba.Boolean is
      C_Obj : System.Address ;
      C_Retries : Interfaces.C.Unsigned_Long ;
      C_Minor : Interfaces.C.Unsigned_Long ;
      C_Status : Interfaces.C.Int ;
      C_Result : Sys_Dep.C_Boolean ;
   begin
      -- transforms the arguments in a C type ...
      C_Obj := Obj'Address ;
      C_Retries := Ada_To_C_Unsigned_Long (Retries) ;
      C_Minor := Ada_To_C_Unsigned_Long (Minor) ;
      C_Status := Completion_Status_To_C_Int (Status) ;
      -- ... and calls the C function
      C_Result := C_Omni_Object_Not_Exist_Exception_Handler (C_Obj,
                                                             C_Retries,
                                                             C_Minor,
                                                             C_Status) ;
      -- ... and transforms the result into an Ada type
      return Sys_Dep.Boolean_C_To_Ada (C_Result) ;
   end ;

end Corba.Exceptions ;





