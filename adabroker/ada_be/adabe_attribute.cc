#include <adabe.h>


adabe_attribute::adabe_attribute(idl_bool ro, AST_Type *ft, UTL_ScopedName *n, UTL_StrList *p)
  : AST_Attribute(ro,ft,n,p),
    AST_Field(AST_Decl::NT_attr,ft,n,p),
    AST_Decl(AST_Decl::NT_attr,n,p),
    adabe_name()
{  
}

void
adabe_attribute::produce_ads(dep_list with, string &body, string &previous)
{
  compute_ada_names();
  body += "   function get_" + get_ada_local_name() +"(Self : in Ref) return "; 
  AST_Decl *d = field_type();
  string name = adabe_name::narrow_from_decl(d)->dump_name(with, body, previous);
  body += name + ";\n";
  if (!pd_readonly)
    {
      body += "   procedure set_" + get_ada_local_name();
      body += "(Self : in Ref, To : in ";
      body += name;
      body += ");\n";
    }
}

void
adabe_operation::produce_adb(dep_list with, string &body, string &previous)
{
  body += "   function get_" + get_ada_local_name() +"(Self : in Ref) return "; 
  AST_Decl *d = field_type();  
  string name = adabe_name::narrow_from_decl(d)->dump_name(with, body, previous);
  body += name + ";\n";  
  name_of_the_package = adabe_name::narrow_from_decl(ScopeAsDecl(defined_in()))->get_ada_full_name();
  body += "   Opcd : " + name_of_the_package + ".Proxies.Get_" + get_ada_local_name() + "_Proxy ;\n";
  body += "   Result : " + name +";\n";
  body += "   begin \n";
  body += "      Assert_Ref_Not_Nil(Self);";
  body += "      Opcd := " + name_of_the_package + ".Proxies.Create();\n";
  body += "      OmniProxyCallWrapper.Invoke(Self, Opcd) ;\n";
  body += "      Result := " + name_of_the_package + ".Proxies.Get_Result(Opcd) ;\n";
  body += "      " + name_of_the_package + ".Proxies.Free(Opcd) ;\n";
  body += "      return Result ;";
  body += "   end;";
  if (!pd_readonly)
    {
      body += "   procedure set_" + get_ada_local_name() +"(Self : in Ref, To : in ";
      body += name + ") is \n";
      body += "   Opcd : " + name_of_the_package + ".Proxies." + get_ada_local_name() + "_Proxy ;\n";
      body += "   begin \n";
      body += "      Assert_Ref_Not_Nil(Self);";
      body += "      Opcd := " + name_of_the_package + ".Proxies.Create(To);";
      body += "      OmniProxyCallWrapper.Invoke(Self, Opcd) ;\n";
      body += "      " + name_of_the_package + ".Proxies.Free(Opcd) ;\n";
      body += "      return ;";
      body += "   end;";    
    }
}

void
adabe_attribute::produce_impl_ads(dep_list with, string &body, string &previous)
{
  body += "   function get_" + get_ada_local_name() +"(Self : access Object) return " 
  AST_Decl *d = field_type();
  string name = adabe_name::narrow_from_decl(d)->dump_name(with, body, previous);
  body += name + ";\n";
  if (!pd_readonly)
    {
      body += "   procedure set_" + name +"(Self : access Object, To : in ";
      body += name;
      body += ");\n";
    }
}

void
adabe_attribute::produce_impl_adb(dep_list with, string &body, string &previous)
{
  body += "   function get_" + get_ada_local_name() +"(Self : access Object) return ";
  AST_Decl *d = field_type();
  string name = adabe_name::narrow_from_decl(d)->dump_name(with, body, previous);
  body += name + ";\n";
  body += "   begin\n\n";
  body += "   end; \n"; 
  if (!pd_readonly)
    {
      body += "   procedure set_" + name +"(Self : access Object, To : in ";
      body += name;
      body += ") is\n";
      body += "   begin\n\n";
      body += "   end; \n"; 
    } 
}

void
adabe_attribute::produce_proxies_ads(dep_list with, string &body, string &private_definition)
{  
  AST_Decl *d = field_type();
  string name = adabe_name::narrow_from_decl(d)->dump_name(with, body, previous);
  body += "   type get_" + get_ada_local_name() +"_Proxy is new OmniProxyCallDesc.Object with private;\n";
  body += "   function Create() return get_" + get_ada_local_name() +"_Proxy ;\n";
  body += "   procedure Free(Self : in out get_" + get_ada_local_name() + "_Proxy);\n";
  body += "   function Aligned_Size(Self : in get_" + get_ada_local_name() + "_Proxy ; Size_In : in Corba.Unsigned_Long)";
  body += " return Corba.Unsigned_Long ;\n";
  body += "   procedure Marshal_Arguments(Self : in get_" + get_ada_local_name() + "_Proxy ; Giop_Client : in out Giop_C.Object);\n";
  body += "   procedure Unmarshal_Returned_Values(Self : in out get_" + get_ada_local_name() + "_Proxy ; Giop_Client : in Giop_C.Object);\n";
  body += "   function Get_Result (Self : in get_" + get_ada_local_name() + "_Proxy ) return ";
  body += name + "; \n";

  private_definition += "   type get_" + get_ada_local_name() + "_Proxy is new OmniProxyCallDesc.Object with record \n";
  private_definition += "      Result : " + name + "_Ptr := null;\n";
  private_definition += "   end record ;\n";
  
  if (!pd_readonly)
    {
      body += "   type set_" + get_ada_local_name() +"_Proxy is new OmniProxyCallDesc.Object with private ;\n";
      body += "   function Create(Arg : in " + name + ") return set_" + get_ada_local_name() +"_Proxy ;\n";
      body += "   procedure Free(Self : in out get_" + get_ada_local_name() + "_Proxy);\n";
      body += "   function Aligned_Size(Self : in get_" + get_ada_local_name() + "_Proxy ; Size_In : in Corba.Unsigned_Long)";
      body += " return Corba.Unsigned_Long ;\n";
      body += "   procedure Marshal_Arguments(Self : in get_" + get_ada_local_name() + "_Proxy ; Giop_Client : in out Giop_C.Object);\n";
      body += "   procedure Unmarshal_Returned_Values(Self : in out get_" + get_ada_local_name() + "_Proxy ; Giop_Client : in Giop_C.Object);\n";
      private_definition += "   type set_" + get_ada_local_name() + "_Proxy is new OmniProxyCallDesc.Object with record \n";
      private_definition += "      Arg : " + name + "_Ptr := null;\n";
      private_definition += "end record ;\n";
    }  
}

void
adabe_attribute::produce_proxies_adb(dep_list with, string &body, string &private_definition)
{
}

void
adabe_attribute::produce_skeleton_adb(dep_list with, string &body, string &private_definition)
{
}

IMPL_NARROW_METHODS1(adabe_attribute, AST_Attribute)
IMPL_NARROW_FROM_DECL(adabe_attribute)
IMPL_NARROW_FROM_SCOPE(adabe_attribute)
















