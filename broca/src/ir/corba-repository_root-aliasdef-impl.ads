----------------------------------------------
--  This file has been generated automatically
--  by AdaBroker (http://adabroker.eu.org/)
----------------------------------------------

with CORBA.Repository_Root.IDLType;
with CORBA.Repository_Root.IDLType.Impl;
with CORBA.Repository_Root.IRObject.Impl;
with CORBA.Repository_Root.TypedefDef.Impl;
pragma Elaborate_All (CORBA.Repository_Root.TypedefDef.Impl);

package CORBA.Repository_Root.AliasDef.Impl is

   type Object is
     new CORBA.Repository_Root.TypedefDef.Impl.Object with private;

   type Object_Ptr is access all Object'Class;

   --  method used to initialize recursively the object fields.
   procedure Init (Self : access Object;
                   Real_Object :
                     CORBA.Repository_Root.IRObject.Impl.Object_Ptr;
                   Def_Kind : Corba.Repository_Root.DefinitionKind;
                   Id : CORBA.RepositoryId;
                   Name : CORBA.Identifier;
                   Version : CORBA.Repository_Root.VersionSpec;
                   Defined_In : CORBA.Repository_Root.Container_Forward.Ref;
                   Absolute_Name : CORBA.ScopedName;
                   Containing_Repository :
                     CORBA.Repository_Root.Repository_Forward.Ref;
                   IDL_Type : CORBA.TypeCode.Object;
                   IDLType_View : CORBA.Repository_Root.IDLType.Impl.Object_Ptr;
                   Original_Type_Def : CORBA.Repository_Root.IDLType.Ref);

   function get_original_type_def
     (Self : access Object)
     return CORBA.Repository_Root.IDLType.Ref;

   procedure set_original_type_def
     (Self : access Object;
      To : in CORBA.Repository_Root.IDLType.Ref);

private

   type Object is
     new CORBA.Repository_Root.TypedefDef.Impl.Object with record
        Original_Type_Def : CORBA.Repository_Root.IDLType.Ref;
   end record;

end CORBA.Repository_Root.AliasDef.Impl;
