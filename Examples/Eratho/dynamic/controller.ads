--  User Defined Libraries
with Common; use Common;

package Controller is

   pragma Remote_Call_Interface;
   type Prime_Pool_Access is access all Prime_Pool_Type'Class;


   Last_Pool_Index : constant := 3;
   type Pool_Index is range 0 .. Last_Pool_Index;

   procedure Register
     (Pool  : in  Prime_Pool_Access;
      Index : out Pool_Index);

   function  Next
     (Index : Pool_Index)
      return Prime_Pool_Access;

   function First
      return Prime_Pool_Access;

end Controller;
