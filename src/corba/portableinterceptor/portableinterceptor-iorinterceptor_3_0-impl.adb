------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--               PORTABLEINTERCEPTOR.IORINTERCEPTOR_3_0.IMPL                --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2004-2006, Free Software Foundation, Inc.          --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 51 Franklin Street, Fifth    --
-- Floor, Boston, MA 02111-1301, USA.                                       --
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

with PortableInterceptor.Interceptor;

package body PortableInterceptor.IORInterceptor_3_0.Impl is

   -----------------------------------
   -- Adapter_Manager_State_Changed --
   -----------------------------------

   procedure Adapter_Manager_State_Changed
     (Self  : access Object;
      Id    : AdapterManagerId;
      State : AdapterState)
   is
      pragma Unreferenced (Self);
      pragma Unreferenced (Id);
      pragma Unreferenced (State);
   begin
      null;
   end Adapter_Manager_State_Changed;

--   ---------------------------
--   -- Adapter_State_Changed --
--   ---------------------------
--
--   procedure Adapter_State_Changed
--     (Self      : access Object;
--      Templates : ObjectReferenceTemplate.Abstract_Value_Ref;
--      State     : AdapterState)
--   is
--      pragma Unreferenced (Self);
--      pragma Unreferenced (Templates);
--      pragma Unreferenced (State);
--   begin
--      null;
--   end Adapter_State_Changed;

   ----------------------------
   -- Components_Established --
   ----------------------------

   procedure Components_Established
     (Self : access Object;
      Info : PortableInterceptor.IORInfo.Local_Ref)
   is
      pragma Unreferenced (Self);
      pragma Unreferenced (Info);
   begin
      null;
   end Components_Established;

   ----------
   -- Is_A --
   ----------

   function Is_A
     (Self            : access Object;
      Logical_Type_Id : Standard.String)
      return Boolean
   is
      pragma Unreferenced (Self);
   begin
      return CORBA.Is_Equivalent
        (Logical_Type_Id,
         PortableInterceptor.IORInterceptor_3_0.Repository_Id)
        or else CORBA.Is_Equivalent
          (Logical_Type_Id,
           "IDL:omg.org/CORBA/Object:1.0")
        or else CORBA.Is_Equivalent
           (Logical_Type_Id,
         PortableInterceptor.IORInterceptor.Repository_Id)
        or else CORBA.Is_Equivalent
           (Logical_Type_Id,
         PortableInterceptor.Interceptor.Repository_Id);
   end Is_A;

end PortableInterceptor.IORInterceptor_3_0.Impl;
