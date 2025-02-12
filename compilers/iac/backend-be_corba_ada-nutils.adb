------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--          B A C K E N D . B E _ C O R B A _ A D A . N U T I L S           --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2005-2025, Free Software Foundation, Inc.          --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.                                               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
--                  PolyORB is maintained by AdaCore                        --
--                     (email: sales@adacore.com)                           --
--                                                                          --
------------------------------------------------------------------------------

with GNAT.Table;
with GNAT.Case_Util;

with Flags;        use Flags;
with Namet;        use Namet;
with Output;       use Output;
with Source_Input; use Source_Input;
with Utils;        use Utils;
with Values;       use Values;

with Frontend.Nutils;

with Backend.BE_CORBA_Ada.IDL_To_Ada; use Backend.BE_CORBA_Ada.IDL_To_Ada;
with Platform;

package body Backend.BE_CORBA_Ada.Nutils is

   package FEN renames Frontend.Nodes;
   package FEU renames Frontend.Nutils;
   package BEN renames Backend.BE_CORBA_Ada.Nodes;

   type Entity_Stack_Entry is record
      Current_Package : Node_Id;
      Current_Entity  : Node_Id;
   end record;

   Forwarded_Entities : List_Id := No_List;
   --  This list contains the forwarded entities

   Ada_Keyword_Prefix : constant String := "%ada_kw%";
   --  Prefix used to "mark" ada keywords

   No_Depth : constant Int := -1;
   package Entity_Stack is
      new GNAT.Table (Entity_Stack_Entry, Int, No_Depth + 1, 10, 10);

   use Entity_Stack;

   --  The following strings are included in internally generated identifiers
   --  to create names that are guaranteed never to clash with any legal
   --  IDL identifier.

   Latin_1_Unique_String : constant String :=
                             (1 => Character'Val (16#DC#));
   Latin_1_Unique_Suffix : aliased constant String :=
                             "_" & Latin_1_Unique_String;
   Latin_1_Unique_Infix  : aliased constant String :=
                             Latin_1_Unique_Suffix & "_";

   UTF_8_Unique_String : constant String :=
                           (Character'Val (16#C3#), Character'Val (16#9C#));
   UTF_8_Unique_Suffix : aliased constant String :=
                           "_" & UTF_8_Unique_String;
   UTF_8_Unique_Infix  : aliased constant String :=
                           UTF_8_Unique_Suffix & "_";

   --  The following are returned by the Unique_Suffix and Unique_Infix
   --  functions. We initialize them to the default Latin_1 values, and if
   --  -gnatW8 is given on the command line, they get set to the UTF_8 values.

   The_Unique_Suffix : access constant String := Latin_1_Unique_Suffix'Access;
   The_Unique_Infix  : access constant String := Latin_1_Unique_Infix'Access;

   --  argument for pragma Wide_Character_Encoding
   Encoding_Name  : Name_Id;  --  Brackets or UTF8
   Use_UTF8       : Boolean := False;

   procedure New_Operator (Op : Operator_Type; I : String := "");

   function Internal_Name (P : Node_Id; L : GLists) return Name_Id;
   pragma Inline (Internal_Name);
   --  Return an unique internal name useful for the binding between P and L

   ------------------------
   -- Add_Prefix_To_Name --
   ------------------------

   function Add_Prefix_To_Name
     (Prefix : String;
      Name   : Name_Id) return Name_Id
   is
   begin
      Set_Str_To_Name_Buffer (Prefix);
      Get_Name_String_And_Append (Name);
      return Name_Find;
   end Add_Prefix_To_Name;

   ------------------------
   -- Add_Suffix_To_Name --
   ------------------------

   function Add_Suffix_To_Name
     (Suffix : String;
      Name   : Name_Id) return Name_Id
   is
   begin
      Get_Name_String (Name);
      Add_Str_To_Name_Buffer (Suffix);
      return Name_Find;
   end Add_Suffix_To_Name;

   -----------------------------
   -- Remove_Suffix_From_Name --
   -----------------------------

   function Remove_Suffix_From_Name
     (Suffix : String;
      Name   : Name_Id) return Name_Id
   is
      Length   : Natural;
      Temp_Str : String (1 .. Suffix'Length);
   begin
      Set_Str_To_Name_Buffer (Suffix);
      Length := Name_Len;
      Get_Name_String (Name);

      if Name_Len > Length then
         Temp_Str := Name_Buffer (Name_Len - Length + 1 .. Name_Len);

         if Suffix = Temp_Str then
            Set_Str_To_Name_Buffer (Name_Buffer (1 .. Name_Len - Length));
            return Name_Find;
         end if;
      end if;

      return Name;
   end Remove_Suffix_From_Name;

   ----------------------
   -- Add_With_Package --
   ----------------------

   procedure Add_With_Package (E : Node_Id; Unreferenced : Boolean := False) is

      function Get_String_Name (The_String : String) return Name_Id;
      --  Return the Name_Id associated to The_String

      function To_Library_Unit (E : Node_Id) return Node_Id;
      --  Return the library unit which E belongs to in order to with
      --  it. As a special rule, package Standard returns No_Node.

      ---------------------
      -- Get_String_Name --
      ---------------------

      function Get_String_Name (The_String : String) return Name_Id is
         pragma Assert (The_String'Length > 0);

         Result : Name_Id;
      begin
         Set_Str_To_Name_Buffer (The_String);
         Result := Name_Find;
         return Result;
      end Get_String_Name;

      ---------------------
      -- To_Library_Unit --
      ---------------------

      function To_Library_Unit (E : Node_Id) return Node_Id is
         U : Node_Id;
      begin
         pragma Assert (Kind (E) = K_Defining_Identifier or else
                        Kind (E) = K_Selected_Component);

         U := Get_Declaration_Node (E);

         --  This node is not properly built as the corresponding node
         --  is not set.

         if No (U) then
            if Output_Tree_Warnings then
               Write_Str  ("WARNING: node ");
               Write_Name (Name (E));
               Write_Line (" has a null corresponding node");
            end if;

            return E;
         end if;

         if BEN.Kind (U) = K_Package_Declaration then
            U := Package_Specification (U);
         end if;

         pragma Assert (Kind (U) = K_Package_Specification
                        or else Kind (U) = K_Package_Instantiation);

         --  This is a nested package and we do not need to add a with for this
         --  unit but for one of its parents. If the kind of the parent unit
         --  name is a K_Package_Instantiation, we consider it as a nested
         --  package.

         if Kind (U) = K_Package_Instantiation
           or else Is_Nested_Package (U)
         then
            U := Get_Parent_Unit_Name (E);

            --  This is a special case to handle package Standard

            if No (U) then
               return No_Node;
            end if;

            return To_Library_Unit (U);
         end if;

         return E;
      end To_Library_Unit;

      P                : constant Node_Id := To_Library_Unit (E);
      W                : Node_Id;
      N                : Name_Id;
      B                : Byte;
      D                : Node_Id;
      I                : Node_Id;
      Helper_Name      : Name_Id;
      Skel_Name        : Name_Id;
      Impl_Name        : Name_Id;
      CDR_Name         : Name_Id;
      Aligned_Name     : Name_Id;
      Buffers_Name     : Name_Id;
      H_Internals_Name : Name_Id;
      IR_Info_Name     : Name_Id;

      Force_Elaboration : Boolean := False;
      --  Set to true to force the addition of elaboration pragma for
      --  the withed package.

   begin
      if No (P) then
         return;
      end if;

      Helper_Name      := Get_String_Name ("Helper");
      Skel_Name        := Get_String_Name ("Skel");
      Impl_Name        := Get_String_Name ("Impl");
      CDR_Name         := Get_String_Name ("CDR");
      Aligned_Name     := Get_String_Name ("Aligned");
      Buffers_Name     := Get_String_Name ("Buffers");
      H_Internals_Name := Get_String_Name ("Internals");
      IR_Info_Name     := Get_String_Name ("IR_Info");

      --  Build a string "<current_entity>%[s,b] <withed_entity>" that
      --  is the current entity name, a character 's' (resp 'b') to
      --  indicate whether we consider the spec (resp. body) of the
      --  current entity and the withed entity name.

      D := FE_Node (P);

      if Present (D) then
         if Get_Name (P) /= Helper_Name
           and then Get_Name (P) /= Skel_Name
           and then Get_Name (P) /= Impl_Name
           and then Get_Name (P) /= CDR_Name
           and then Get_Name (P) /= Aligned_Name
           and then Get_Name (P) /= Buffers_Name
           and then Get_Name (P) /= H_Internals_Name
           and then Get_Name (P) /= IR_Info_Name
         then
            --  This is a local entity and there is no need for a with
            --  clause.

            if Is_N_Parent_Of_M (D, FE_Node (Current_Entity)) then
               return;
            end if;
         end if;
      end if;

      if Get_Declaration_Node (P) = Package_Declaration (Current_Package) then
         --  This means a package "with"es itself, so exit

         return;
      end if;

      --  Routine that checks whether the package P has already been
      --  added to the withed packages of the current package. When we
      --  add a 'with' clause to a package specification, we check
      --  only if this clause has been added to the current
      --  spec. However, when we add a 'with' clause to a package
      --  body, we check that the clause has been added in both the
      --  spec and the body.

      --  IMPORTANT: Provided that all specs are generated before all
      --  bodies, this behaviour is automatically applied. We just
      --  need to encode the package name *without* precising whether
      --  it is a spec or a body.

      --  Encoding the withed package and the current entity

      N := Fully_Qualified_Name (P);

      if Is_Nested_Package
        (Package_Specification (Package_Declaration (Current_Package)))
      then
         --  The package is a nested within another package; use its parent's
         --  name.

         I := Get_Parent_Unit_Name
           (Defining_Identifier (Package_Declaration (Current_Package)));

         if Fully_Qualified_Name (I) = N then
            --  If true, this means a package "with"es itself, so exit

            return;
         end if;

      else
         --  else, use its own name

         I := Defining_Identifier (Package_Declaration (Current_Package));
      end if;

      Get_Name_String (Fully_Qualified_Name (I));
      Add_Char_To_Name_Buffer (' ');
      Get_Name_String_And_Append (N);
      N := To_Lower (Name_Find);

      --  Get the byte associated to the name in the hash table and
      --  check whether it is already set to 1 which means that the
      --  withed entity is already in the withed package list.

      B := Get_Name_Table_Byte (N);

      if B /= 0 then
         return;
      end if;

      Set_Name_Table_Byte (N, 1);

      if Output_Unit_Withing then
         Write_Name (N);
         Write_Eol;
      end if;

      if Get_Name (P) = Get_String_Name ("Internals")           or else
        Get_Name (P) = Get_String_Name ("CORBA")                or else
        Get_Name (P) = Get_String_Name ("Forward")              or else
        Get_Name (P) = Get_String_Name ("Bounded_Strings")      or else
        Get_Name (P) = Get_String_Name ("Bounded_Wide_Strings") or else
        Get_Name (P) = Get_String_Name ("Fixed_Point")          or else
        Get_Name (P) = Get_String_Name ("CORBA_Helper")
      then
         --  Ada static elaboration rules require the addition of
         --  "pragma Elaborate_All" to these package.

         Force_Elaboration := True;
      end if;

      --  Add entity to the withed packages list

      W := New_Node (K_Withed_Package);
      Set_Defining_Identifier (W, P);
      Set_Elaborated (W, Force_Elaboration);
      if Unreferenced then
         Set_Unreferenced (W, V => True);
      end if;

      Append_To (Context_Clause (Current_Package), W);
   end Add_With_Package;

   ---------------
   -- Append_To --
   ---------------

   procedure Append_To (L : List_Id; E : Node_Id) is
      Last : Node_Id;

   begin
      Last := Last_Node (L);

      if No (Last) then
         Set_First_Node (L, E);
      else
         Set_Next_Node (Last, E);
      end if;

      Last := E;

      while Present (Next_Node (Last)) loop
         Last := Next_Node (Last);
      end loop;

      Set_Last_Node (L, Last);
   end Append_To;

   ----------------
   -- Prepend_To --
   ----------------

   procedure Prepend_To (L : List_Id; E : Node_Id) is
   begin
      pragma Assert (No (Next_Node (E)));
      Set_Next_Node (E, First_Node (L));
      Set_First_Node (L, E);
      if No (Last_Node (L)) then
         Set_Last_Node (L, E);
      end if;
   end Prepend_To;

   -------------
   -- Convert --
   -------------

   function Convert (K : FEN.Node_Kind) return RE_Id is
   begin
      case K is
         when FEN.K_Float               => return RE_Float;
         when FEN.K_Double              => return RE_Double;
         when FEN.K_Long_Double         => return RE_Long_Double;
         when FEN.K_Short               => return RE_Short;
         when FEN.K_Long                => return RE_Long;
         when FEN.K_Long_Long           => return RE_Long_Long;
         when FEN.K_Unsigned_Short      => return RE_Unsigned_Short;
         when FEN.K_Unsigned_Long       => return RE_Unsigned_Long;
         when FEN.K_Unsigned_Long_Long  => return RE_Unsigned_Long_Long;
         when FEN.K_Char                => return RE_Char;
         when FEN.K_Wide_Char           => return RE_WChar;
         when FEN.K_String              => return RE_String_0;
         when FEN.K_Wide_String         => return RE_Wide_String;
         when FEN.K_Boolean             => return RE_Boolean;
         when FEN.K_Octet               => return RE_Octet;
         when FEN.K_Object              => return RE_Ref_2;
         when FEN.K_Any                 => return RE_Any;
         when others                    =>
            raise Program_Error;
      end case;
   end Convert;

   ------------------------
   -- Copy_Expanded_Name --
   ------------------------

   function Copy_Expanded_Name
     (N      : Node_Id;
      Withed : Boolean := True) return Node_Id
   is
      D : Node_Id;
      P : Node_Id := Get_Parent_Unit_Name (N);
   begin
      D := Copy_Node (N);

      if Kind (N) = K_Defining_Identifier then
         P := Get_Parent_Unit_Name (N);
      elsif Kind (N) = K_Attribute_Reference then
         P := Get_Parent_Unit_Name (Prefix (N));
      elsif Kind (N) = K_Selected_Component then
         P := Prefix (N);
      end if;

      if Present (P) then
         P := Copy_Expanded_Name (P, False);

         if Withed then
            Add_With_Package (P);
         end if;
      end if;

      return D;
   end Copy_Expanded_Name;

   ---------------
   -- Copy_Node --
   ---------------

   function Copy_Node (N : Node_Id) return Node_Id is
      C : Node_Id;
   begin
      case Kind (N) is
         when K_Identifier =>
            C := New_Node (K_Identifier);
            Set_Name (C, Name (N));
            Set_FE_Node (C, FE_Node (N));

         when K_Defining_Identifier =>
            C := New_Node (K_Defining_Identifier);
            Set_Name (C, Name (N));
            Set_Declaration_Node (C, Declaration_Node (N));
            Set_FE_Node (C, FE_Node (N));

         when K_Attribute_Reference =>
            C := New_Node (K_Attribute_Reference);
            Set_Name (C, Name (N));
            Set_Prefix (C, Copy_Node (Prefix (N)));
            Set_FE_Node (C, FE_Node (N));

         when K_Selected_Component =>
            C := New_Node (K_Selected_Component);
            Set_Selector_Name (C, Copy_Node (Selector_Name (N)));
            Set_Prefix (C, Copy_Node (Prefix (N)));
            Set_FE_Node (C, FE_Node (N));

         when K_Literal =>
            C := New_Node (K_Literal);
            Set_Value (C, Value (N));
            Set_FE_Node (C, FE_Node (N));

         when others =>
            raise Program_Error;
      end case;

      return C;
   end Copy_Node;

   -------------------
   -- Unique_Suffix --
   -------------------

   function Unique_Suffix return String is
   begin
      return The_Unique_Suffix.all;
   end Unique_Suffix;

   ------------------
   -- Unique_Infix --
   ------------------

   function Unique_Infix return String is
   begin
      return The_Unique_Infix.all;
   end Unique_Infix;

   --------------------------
   -- Get_Declaration_Node --
   --------------------------

   function Get_Declaration_Node (N : Node_Id) return Node_Id is
   begin
      case Kind (N) is
         when K_Defining_Identifier | K_Identifier =>
            return Declaration_Node (N);

         when K_Selected_Component =>
            if Kind (Selector_Name (N)) = K_Defining_Identifier or else
              Kind (Selector_Name (N)) = K_Identifier
            then
               return Declaration_Node (Selector_Name (N));
            else
               raise Program_Error;
            end if;

         when others =>
            raise Program_Error;
      end case;
   end Get_Declaration_Node;

   -------------------------
   -- Get_Base_Identifier --
   -------------------------

   function Get_Base_Identifier (N : Node_Id) return Node_Id is
   begin
      case Kind (N) is
         when K_Defining_Identifier | K_Identifier =>
            return N;

         when K_Selected_Component =>
            if Kind (Selector_Name (N)) = K_Defining_Identifier or else
               Kind (Selector_Name (N)) = K_Identifier
            then
               return Selector_Name (N);
            else
               raise Program_Error;
            end if;

         when others =>
            return Get_Base_Identifier (Defining_Identifier (N));
      end case;
   end Get_Base_Identifier;

   --------------
   -- Get_Name --
   --------------

   function Get_Name (N : Node_Id) return Name_Id is
   begin
      case Kind (N) is
         when K_Defining_Identifier | K_Identifier =>
            return Name (N);

         when K_Selected_Component =>
            if Kind (Selector_Name (N)) = K_Defining_Identifier or else
              Kind (Selector_Name (N)) = K_Identifier
            then
               return Name (Selector_Name (N));
            else
               raise Program_Error;
            end if;

         when others =>
            raise Program_Error;
      end case;
   end Get_Name;

   ---------------
   -- Get_Value --
   ---------------

   function Get_Value (N : Node_Id) return Value_Id is
   begin
      case Kind (N) is
         when K_Literal =>
            return Value (N);

         when K_Selected_Component =>
            if Kind (Selector_Name (N)) = K_Literal then
               return Value (Selector_Name (N));
            else
               raise Program_Error;
            end if;

         when others =>
            raise Program_Error;
      end case;
   end Get_Value;

   --------------------------
   -- Get_Parent_Unit_Name --
   --------------------------

   function Get_Parent_Unit_Name (N : Node_Id) return Node_Id is
   begin
      case Kind (N) is
         when K_Selected_Component =>
            return Prefix (N);

         when others =>
            return No_Node;
      end case;
   end Get_Parent_Unit_Name;

   --------------------
   -- Current_Entity --
   --------------------

   function Current_Entity return Node_Id is
   begin
      if Last = No_Depth then
         return No_Node;
      else
         return Table (Last).Current_Entity;
      end if;
   end Current_Entity;

   ---------------------
   -- Current_Package --
   ---------------------

   function Current_Package return Node_Id is
   begin
      if Last = No_Depth then
         return No_Node;
      else
         return Table (Last).Current_Package;
      end if;
   end Current_Package;

   -----------------------
   -- Expand_Designator --
   -----------------------

   function Expand_Designator
     (N               : Node_Id;
      Add_With_Clause : Boolean := True)
     return Node_Id
   is
      use Frontend.Nodes;

      P  : Node_Id;
      D  : Node_Id := No_Node;
      X  : Node_Id := N;
      FE : Node_Id;

   begin
      case BEN.Kind (N) is
         when K_Full_Type_Declaration
           | K_Subprogram_Specification
           | K_Object_Declaration
           | K_Exception_Declaration
           | K_Package_Instantiation =>
            P  := Parent (X);
            FE := FE_Node (X);

         when K_Package_Specification =>
            X  := Package_Declaration (N);
            P  := Parent (X);
            FE := FE_Node (IDL_Unit (X));

         when K_Package_Declaration =>
            P  := Parent (N);
            FE := FE_Node (IDL_Unit (X));

         when K_Selected_Component =>
            --  If N is already expanded, just add the necessary with clause
            --  and return a copy of N.

            return Copy_Expanded_Name (N, Add_With_Clause);

         when others =>
            raise Program_Error;
      end case;

      D := Get_Base_Identifier (Defining_Identifier (X));

      if Present (FE) then
         Set_FE_Node (D, FE);

         --  Handle the case of CORBA particular entities

         if FEN.Kind (FE) = K_Identifier
           and then Present (Scope_Entity (FE))
           and then FEN.Kind (Scope_Entity (FE)) = K_Module
           and then FEN.IDL_Name (Identifier (Scope_Entity (FE))) = CORBA_Name
         then
            D := Make_Selected_Component (RU (RU_CORBA), D);
         end if;
      end if;

      if No (P) then
         return D;
      end if;

      D := Make_Selected_Component
        (Expand_Designator (P, False), Get_Base_Identifier (D));
      P := Get_Parent_Unit_Name (D);

      --  Adding the with clause

      if Add_With_Clause and then Present (P) then
         Add_With_Package (P);
      end if;

      return D;
   end Expand_Designator;

   --------------------------
   -- Fully_Qualified_Name --
   --------------------------

   function Fully_Qualified_Name (N : Node_Id) return Name_Id is
      Parent_Node : Node_Id := No_Node;
      Parent_Name : Name_Id := No_Name;

   begin
      case Kind (N) is
         when K_Defining_Identifier =>
            Parent_Node := Get_Parent_Unit_Name (N);

            if Present (Parent_Node) then
               Parent_Name := Fully_Qualified_Name (Parent_Node);
            end if;

            Name_Len := 0;

            if Present (Parent_Node) then
               Get_Name_String (Parent_Name);
               Add_Char_To_Name_Buffer ('.');
            end if;

            Get_Name_String_And_Append (Name (N));
            return Name_Find;

         when K_Attribute_Reference =>
            Get_Name_String (Fully_Qualified_Name (Prefix (N)));
            Add_Char_To_Name_Buffer (''');
            Get_Name_String_And_Append (Name (N));
            return Name_Find;

         when K_Selected_Component =>
            Get_Name_String (Fully_Qualified_Name (Prefix (N)));
            Add_Char_To_Name_Buffer ('.');

            case Kind (Selector_Name (N)) is
               when K_Identifier | K_Defining_Identifier =>
                  Get_Name_String_And_Append (Name (Selector_Name (N)));
               when K_Literal =>
                  declare
                     V : constant Value_Id := Value (Selector_Name (N));
                  begin
                     case Value (V).K is
                        when FEN.K_Char .. FEN.K_Wide_Char =>
                           Add_Str_To_Name_Buffer
                             (Quoted (Image_Ada (V), '''));

                        when FEN.K_String .. FEN.K_Wide_String =>
                           Add_Str_To_Name_Buffer
                             (Quoted (Image_Ada (V), '"'));

                        when FEN.K_Enumerator =>
                           Add_Str_To_Name_Buffer (Image_Ada (V));

                        when others =>
                           raise Program_Error;
                     end case;
                  end;

               when others =>
                  raise Program_Error;
            end case;

            return Name_Find;

         when others =>
            raise Program_Error;
      end case;
   end Fully_Qualified_Name;

   -----------
   -- Image --
   -----------

   function Image (T : Token_Type) return String is
      S : String := Token_Type'Image (T);
   begin
      To_Lower (S);
      return S (5 .. S'Last);
   end Image;

   -----------
   -- Image --
   -----------

   function Image (Op : Operator_Type) return String is
      S : String := Operator_Type'Image (Op);
   begin
      To_Lower (S);

      for I in S'First .. S'Last loop
         if S (I) = '_' then
            S (I) := ' ';
         end if;
      end loop;

      return S (4 .. S'Last);
   end Image;

   -------------------
   -- Is_Class_Wide --
   -------------------

   function Is_Class_Wide (E : Node_Id) return Boolean is
      Orig_Type        : constant Node_Id := FEU.Get_Original_Type_Specifier
        (FEN.Type_Spec (E));
      Parent_Interface : Node_Id;

      use FEN;
   begin
      case FEN.Kind (E) is
         when K_Parameter_Declaration =>
            Parent_Interface := Scope_Entity
              (Identifier
               (Scope_Entity
                (Identifier
                 (Declarator
                  (E)))));

         when K_Operation_Declaration =>
            Parent_Interface := Scope_Entity (Identifier (E));

         when others =>
            raise Program_Error;
      end case;

      return FEN.Kind (Orig_Type) = FEN.K_Interface_Declaration
        and then Orig_Type = Parent_Interface;
   end Is_Class_Wide;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
   begin

      if Initialized then
         return;
      else
         Initialized := True;
      end if;

      --  Keywords.

      for J in Keyword_Type loop
         New_Token (J);
      end loop;

      --  Graphic Characters

      New_Token (Tok_Double_Asterisk, "**");
      New_Token (Tok_Ampersand, "&");
      New_Token (Tok_Minus, "-");
      New_Token (Tok_Plus, "+");
      New_Token (Tok_Asterisk, "*");
      New_Token (Tok_Slash, "/");
      New_Token (Tok_Dot, ".");
      New_Token (Tok_Apostrophe, "'");
      New_Token (Tok_Left_Paren, "(");
      New_Token (Tok_Right_Paren, ")");
      New_Token (Tok_Comma, ",");
      New_Token (Tok_Less, "<");
      New_Token (Tok_Equal, "=");
      New_Token (Tok_Greater, ">");
      New_Token (Tok_Not_Equal, "/=");
      New_Token (Tok_Greater_Equal, ">=");
      New_Token (Tok_Less_Equal, "<=");
      New_Token (Tok_Box, "<>");
      New_Token (Tok_Colon_Equal, ":=");
      New_Token (Tok_Colon, ":");
      New_Token (Tok_Greater_Greater, ">>");
      New_Token (Tok_Less_Less, "<<");
      New_Token (Tok_Semicolon, ";");
      New_Token (Tok_Arrow, "=>");
      New_Token (Tok_Vertical_Bar, "|");
      New_Token (Tok_Dot_Dot, "..");
      New_Token (Tok_Minus_Minus, "--");

      --  Keyword Operators

      for Op in Op_And .. Op_Or_Else loop
         New_Operator (Op);
      end loop;

      --  Other operators

      New_Operator (Op_And_Symbol, "&");
      New_Operator (Op_Double_Asterisk, "**");
      New_Operator (Op_Minus, "-");
      New_Operator (Op_Plus, "+");
      New_Operator (Op_Asterisk, "*");
      New_Operator (Op_Slash, "/");
      New_Operator (Op_Less, "<");
      New_Operator (Op_Equal, "=");
      New_Operator (Op_Greater, ">");
      New_Operator (Op_Not_Equal, "/=");
      New_Operator (Op_Greater_Equal, ">=");
      New_Operator (Op_Less_Equal, "<=");
      New_Operator (Op_Box, "<>");
      New_Operator (Op_Colon_Equal, ":=");
      New_Operator (Op_Colon, "--");
      New_Operator (Op_Greater_Greater, ">>");
      New_Operator (Op_Less_Less, "<<");
      New_Operator (Op_Semicolon, ";");
      New_Operator (Op_Arrow, "=>");
      New_Operator (Op_Vertical_Bar, "|");

      --  Attributes

      for A in Attribute_Id loop
         Set_Str_To_Name_Buffer (Attribute_Id'Image (A));
         Set_Str_To_Name_Buffer (Name_Buffer (3 .. Name_Len));
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         AN (A) := Name_Find;
      end loop;

      --  Components

      for C in Component_Id loop
         Set_Str_To_Name_Buffer (Component_Id'Image (C));
         Set_Str_To_Name_Buffer (Name_Buffer (3 .. Name_Len));
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         CN (C) := Name_Find;
      end loop;

      --  Parameters

      for P in Parameter_Id loop
         Set_Str_To_Name_Buffer (Parameter_Id'Image (P));
         Set_Str_To_Name_Buffer (Name_Buffer (3 .. Name_Len));
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         PN (P) := Name_Find;
      end loop;

      --  Subprograms

      for S in Subprogram_Id loop
         case S is
            when S_Minus =>
               Set_Str_To_Name_Buffer (Quoted ("-"));

            when others =>
               Set_Str_To_Name_Buffer (Subprogram_Id'Image (S));
               Set_Str_To_Name_Buffer (Name_Buffer (3 .. Name_Len));
               GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         end case;

         SN (S) := Name_Find;
      end loop;

      --  Types

      for T in Type_Id loop
         Set_Str_To_Name_Buffer (Type_Id'Image (T));
         Set_Str_To_Name_Buffer (Name_Buffer (3 .. Name_Len));
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         TN (T) := Name_Find;
      end loop;

      --  Variables

      for V in Variable_Id loop
         Set_Str_To_Name_Buffer (Variable_Id'Image (V));
         Set_Str_To_Name_Buffer (Name_Buffer (3 .. Name_Len));
         Add_Str_To_Name_Buffer (Unique_Suffix);
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         VN (V) := Name_Find;
      end loop;

      --  Pragmas

      for G in Pragma_Id loop
         Set_Str_To_Name_Buffer (Pragma_Id'Image (G));
         Set_Str_To_Name_Buffer (Name_Buffer (8 .. Name_Len));
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         GN (G) := Name_Find;
      end loop;

      --  Exceptions

      for E in Error_Id loop
         Set_Str_To_Name_Buffer (Error_Id'Image (E));
         Set_Str_To_Name_Buffer (Name_Buffer (3 .. Name_Len));
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         EN (E) := Name_Find;
      end loop;

      --  Conventions

      for C in Convention_Id loop
         Set_Str_To_Name_Buffer (Convention_Id'Image (C));
         Set_Str_To_Name_Buffer (Name_Buffer (12 .. Name_Len));
         GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
         XN (C) := Name_Find;
      end loop;

      --  Initialize the CORBA module entities names

      Set_Str_To_Name_Buffer ("CORBA");
      CORBA_Name := Name_Find;

      Set_Str_To_Name_Buffer ("Repository_Root");
      Repository_Root_Name := Name_Find;

      Set_Str_To_Name_Buffer ("IDL_Sequences");
      IDL_Sequences_Name := Name_Find;

      Set_Str_To_Name_Buffer ("DomainManager");
      DomainManager_Name := Name_Find;

      if Use_UTF8 then
         Set_Str_To_Name_Buffer ("UTF8");
      else
         Set_Str_To_Name_Buffer ("Brackets");
      end if;

      Encoding_Name := Name_Find;
   end Initialize;

   --------------
   -- Is_Empty --
   --------------

   function Is_Empty (L : List_Id) return Boolean is
   begin
      return L = No_List or else No (First_Node (L));
   end Is_Empty;

   ------------
   -- Length --
   ------------

   function Length (L : List_Id) return Natural is
      N : Node_Id;
      C : Natural := 0;
   begin
      if not Is_Empty (L) then
         N := First_Node (L);

         while Present (N) loop
            C := C + 1;
            N := Next_Node (N);
         end loop;
      end if;

      return C;
   end Length;

   ---------------------------------
   -- Make_Access_Type_Definition --
   ---------------------------------

   function Make_Access_Type_Definition
     (Subtype_Indication : Node_Id;
      Is_All             : Boolean := False;
      Is_Constant        : Boolean := False;
      Is_Not_Null        : Boolean := False)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Access_Type_Definition);
      Set_Subtype_Indication (N, Subtype_Indication);
      Set_Is_All (N, Is_All);
      Set_Is_Constant (N, Is_Constant);
      Set_Is_Not_Null (N, Is_Not_Null);
      return N;
   end Make_Access_Type_Definition;

   ----------------------
   -- Make_Ada_Comment --
   ----------------------

   function Make_Ada_Comment
     (N                 : Name_Id;
      Has_Header_Spaces : Boolean := True)
     return Node_Id
   is
      C : Node_Id;
   begin
      C := New_Node (K_Ada_Comment);
      Set_Message (C, N);
      Set_Has_Header_Spaces (C, Has_Header_Spaces);
      return C;
   end Make_Ada_Comment;

   --------------------------
   -- Make_Array_Aggregate --
   --------------------------

   function Make_Array_Aggregate (Elements : List_Id) return Node_Id is
      N : Node_Id;
   begin
      pragma Assert (not Is_Empty (Elements));

      N := New_Node (K_Array_Aggregate);
      Set_Elements (N, Elements);
      return N;
   end Make_Array_Aggregate;

   --------------------------------
   -- Make_Array_Type_Definition --
   --------------------------------

   function Make_Array_Type_Definition
     (Range_Constraints     : List_Id;
      Component_Definition  : Node_Id;
      Index_Definition      : Node_Id := No_Node;
      Index_Def_Constrained : Boolean := False)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Array_Type_Definition);
      Set_Range_Constraints (N, Range_Constraints);
      Set_Component_Definition (N, Component_Definition);
      Set_Index_Definition (N, Index_Definition);
      Set_Index_Def_Constrained (N, Index_Def_Constrained);
      return N;
   end Make_Array_Type_Definition;

   ---------------------------------
   -- Make_String_Type_Definition --
   ---------------------------------

   function Make_String_Type_Definition
     (Defining_Identifier : Node_Id;
      Range_Constraint    : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (BEN.K_String_Type_Definition);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Range_Constraint (N, Range_Constraint);
      return N;
   end Make_String_Type_Definition;

   -------------------------------
   -- Make_Assignment_Statement --
   -------------------------------

   function Make_Assignment_Statement
     (Variable_Identifier : Node_Id;
      Expression          : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Assignment_Statement);
      Set_Defining_Identifier (N, Variable_Identifier);
      Set_Expression (N, Expression);
      return N;
   end Make_Assignment_Statement;

   --------------------------------------
   -- Make_Attribute_Definition_Clause --
   --------------------------------------

   function Make_Attribute_Definition_Clause
     (Local_Name : Name_Id;
      Attribute  : Attribute_Id;
      Expression : Node_Id)
      return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Attribute_Definition_Clause);
      Set_Local_Name (N, Local_Name);
      Set_Attribute_Designator (N, AN (Attribute));
      Set_Expression (N, Expression);
      return N;
   end Make_Attribute_Definition_Clause;

   ------------------------------
   -- Make_Attribute_Reference --
   ------------------------------

   function Make_Attribute_Reference
     (Prefix    : Node_Id;
      Attribute : Attribute_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Attribute_Reference);
      Set_Prefix (N, Prefix);
      Set_Name (N, AN (Attribute));
      return N;
   end Make_Attribute_Reference;

   --------------------------
   -- Make_Block_Statement --
   --------------------------

   function Make_Block_Statement
     (Statement_Identifier : Node_Id := No_Node;
      Declarative_Part     : List_Id;
      Statements           : List_Id;
      Exception_Handler    : List_Id := No_List)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Block_Statement);
      Set_Defining_Identifier (N, Statement_Identifier);

      if Present (Statement_Identifier) then
         Set_Declaration_Node (Statement_Identifier, N);
      end if;

      Set_Declarative_Part (N, Declarative_Part);
      Set_Statements (N, Statements);

      if not Is_Empty (Exception_Handler) then
         Set_Exception_Handler (N, Exception_Handler);
      end if;

      return N;
   end Make_Block_Statement;

   -------------------------
   -- Make_Case_Statement --
   -------------------------

   function Make_Case_Statement
     (Expression                  : Node_Id;
      Case_Statement_Alternatives : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Case_Statement);
      Set_Expression (N, Expression);
      Set_Case_Statement_Alternatives (N, Case_Statement_Alternatives);
      return N;
   end Make_Case_Statement;

   -------------------------------------
   -- Make_Case_Statement_Alternative --
   -------------------------------------

   function Make_Case_Statement_Alternative
     (Discret_Choice_List : List_Id;
      Statements          : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Case_Statement_Alternative);
      Set_Discret_Choice_List (N, Discret_Choice_List);
      Set_Statements (N, Statements);
      return N;
   end Make_Case_Statement_Alternative;

   --------------------------------
   -- Make_Component_Association --
   --------------------------------

   function Make_Component_Association
     (Selector_Name : Node_Id;
      Expression    : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Component_Association);
      Set_Defining_Identifier (N, Selector_Name);
      Set_Expression (N, Expression);
      return N;
   end Make_Component_Association;

   --------------------------------
   -- Make_Component_Declaration --
   --------------------------------

   function Make_Component_Declaration
     (Defining_Identifier : Node_Id;
      Subtype_Indication  : Node_Id;
      Expression          : Node_Id := No_Node;
      Aliased_Present     : Boolean := False)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Component_Declaration);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Subtype_Indication (N, Subtype_Indication);
      Set_Expression (N, Expression);
      Set_Aliased_Present (N, Aliased_Present);
      return N;
   end Make_Component_Declaration;

   ----------------------------------
   -- Make_Decimal_Type_Definition --
   ----------------------------------

   function Make_Decimal_Type_Definition
     (Definition : Node_Id)
     return Node_Id is
      N   : Node_Id;
      V   : Value_Id;
      Exp : Node_Id;
   begin
      N := New_Node (K_Decimal_Type_Definition);

      V := New_Floating_Point_Value
        (Long_Double (1.0 / (10 ** (Integer (FEN.N_Scale (Definition))))));

      Exp := Make_Literal (V);
      Set_Scale (N, Exp);

      V := New_Integer_Value
        (Unsigned_Long_Long (FEN.N_Total (Definition)),
         1,
         10);
      Set_Total (N, V);
      return N;
   end Make_Decimal_Type_Definition;

   ---------------------
   -- Make_Identifier --
   ---------------------

   function Make_Identifier (Name : Name_Id) return Node_Id is
      N : Node_Id;
   begin
      N := New_Node (K_Identifier);
      Set_Name (N, To_Ada_Name (Name));
      return N;
   end Make_Identifier;

   ------------------------------
   -- Make_Defining_Identifier --
   ------------------------------

   function Make_Defining_Identifier (Name : Name_Id) return Node_Id is
      N : Node_Id;
   begin
      N := New_Node (K_Defining_Identifier);
      Set_Name (N, To_Ada_Name (Name));
      return N;
   end Make_Defining_Identifier;

   ----------------------------------
   -- Make_Derived_Type_Definition --
   ----------------------------------

   function Make_Derived_Type_Definition
     (Subtype_Indication    : Node_Id;
      Record_Extension_Part : Node_Id := No_Node;
      Is_Abstract_Type      : Boolean := False;
      Is_Private_Extension  : Boolean := False;
      Is_Subtype            : Boolean := False;
      Opt_Range             : Node_Id := No_Node)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Derived_Type_Definition);
      Set_Is_Abstract_Type (N, Is_Abstract_Type);
      Set_Is_Private_Extension (N, Is_Private_Extension);
      Set_Subtype_Indication (N, Subtype_Indication);
      Set_Record_Extension_Part (N, Record_Extension_Part);
      Set_Is_Subtype (N, Is_Subtype);
      Set_Range_Opt (N, Opt_Range);
      return N;
   end Make_Derived_Type_Definition;

   ------------------------------
   -- Make_Element_Association --
   ------------------------------

   function Make_Element_Association
     (Index      : Node_Id;
      Expression : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Element_Association);
      Set_Index (N, Index);
      Set_Expression (N, Expression);
      return N;
   end Make_Element_Association;

   --------------------------
   -- Make_Elsif_Statement --
   --------------------------

   function Make_Elsif_Statement
     (Condition       : Node_Id;
      Then_Statements : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Elsif_Statement);
      Set_Condition (N, Condition);
      Set_Then_Statements (N, Then_Statements);
      return N;
   end Make_Elsif_Statement;

   --------------------------------------
   -- Make_Enumeration_Type_Definition --
   --------------------------------------

   function Make_Enumeration_Type_Definition
     (Enumeration_Literals : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Enumeration_Type_Definition);
      Set_Enumeration_Literals (N, Enumeration_Literals);
      return N;
   end Make_Enumeration_Type_Definition;

   --------------------------------
   -- Make_Exception_Declaration --
   --------------------------------

   function Make_Exception_Declaration
     (Defining_Identifier : Node_Id;
      Renamed_Exception   : Node_Id := No_Node;
      Parent              : Node_Id := Current_Package)
     return Node_Id
   is
      N : Node_Id;
   begin
      pragma Assert (Kind (Defining_Identifier) = K_Defining_Identifier);

      N := New_Node           (K_Exception_Declaration);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Renamed_Entity      (N, Renamed_Exception);
      Set_Declaration_Node    (Defining_Identifier, N);
      Set_Parent              (N, Parent);
      return N;
   end Make_Exception_Declaration;

   -------------------------------
   -- Make_Explicit_Dereference --
   -------------------------------

   function Make_Explicit_Dereference (Prefix : Node_Id) return Node_Id is
      N : Node_Id;
   begin
      N := New_Node (K_Explicit_Dereference);
      Set_Prefix (N, Prefix);
      return N;
   end Make_Explicit_Dereference;

   ---------------------
   -- Make_Expression --
   ---------------------

   function Make_Expression
     (Left_Expr  : Node_Id;
      Operator   : Operator_Type := Op_None;
      Right_Expr : Node_Id := No_Node)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Expression);
      Set_Left_Expr (N, Left_Expr);
      Set_Operator (N, Operator_Type'Pos (Operator));
      Set_Right_Expr (N, Right_Expr);
      return N;
   end Make_Expression;

   ------------------------
   -- Make_For_Statement --
   ------------------------

   function Make_For_Statement
     (Defining_Identifier : Node_Id;
      Range_Constraint    : Node_Id;
      Statements          : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_For_Statement);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Range_Constraint (N, Range_Constraint);
      Set_Statements (N, Statements);
      return N;
   end Make_For_Statement;

   --------------------------------
   -- Make_Full_Type_Declaration --
   --------------------------------

   function Make_Full_Type_Declaration
     (Defining_Identifier : Node_Id;
      Type_Definition     : Node_Id;
      Discriminant_Spec   : List_Id := No_List;
      Parent              : Node_Id := Current_Package;
      Is_Subtype          : Boolean := False)
     return Node_Id
   is
      N : Node_Id;
   begin
      pragma Assert (Kind (Defining_Identifier) = K_Defining_Identifier);

      N := New_Node (K_Full_Type_Declaration);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Declaration_Node (Defining_Identifier, N);
      Set_Type_Definition (N, Type_Definition);
      Set_Discriminant_Spec (N, Discriminant_Spec);
      Set_Parent (N, Parent);
      Set_Is_Subtype (N, Is_Subtype);
      return N;
   end Make_Full_Type_Declaration;

   -----------------------
   -- Make_If_Statement --
   -----------------------

   function Make_If_Statement
     (Condition        : Node_Id;
      Then_Statements  : List_Id;
      Elsif_Statements : List_Id := No_List;
      Else_Statements  : List_Id := No_List)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_If_Statement);
      Set_Condition (N, Condition);
      Set_Then_Statements (N, Then_Statements);
      Set_Elsif_Statements (N, Elsif_Statements);
      Set_Else_Statements (N, Else_Statements);
      return N;
   end Make_If_Statement;

   ----------------------------
   -- Make_Indexed_Component --
   ----------------------------

   function Make_Indexed_Component
     (Prefix      : Node_Id;
      Expressions : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Indexed_Component);
      Set_Prefix (N, Prefix);
      Set_Expressions (N, Expressions);
      return N;
   end Make_Indexed_Component;

   ----------------------------------
   -- Make_Instantiated_Subprogram --
   ----------------------------------

   function Make_Instantiated_Subprogram
     (Defining_Identifier : Node_Id;
      Parameter_List      : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Instantiated_Subprogram);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Parameter_List (N, Parameter_List);
      return N;
   end Make_Instantiated_Subprogram;

   --------------
   -- New_List --
   --------------

   function New_List
     (N1 : Node_Id := No_Node;
      N2 : Node_Id := No_Node;
      N3 : Node_Id := No_Node;
      N4 : Node_Id := No_Node;
      N5 : Node_Id := No_Node) return List_Id
   is
      N : Node_Id;
      L : List_Id;
   begin
      Entries.Increment_Last;
      N := Entries.Last;
      Entries.Table (N) := Default_Node;
      Set_Kind (N, K_List_Id);

      L := List_Id (N);

      if Present (N1) then
         Append_To (L, N1);
      end if;

      if Present (N2) then
         Append_To (L, N2);
      end if;

      if Present (N3) then
         Append_To (L, N3);
      end if;

      if Present (N4) then
         Append_To (L, N4);
      end if;

      if Present (N5) then
         Append_To (L, N5);
      end if;

      return L;
   end New_List;

   ------------------
   -- Make_Literal --
   ------------------

   function Make_Literal (Value  : Value_Id) return Node_Id is
      pragma Assert (Value /= No_Value);

      N : constant Node_Id := New_Node (K_Literal);

   begin
      Set_Value (N, Value);
      return N;
   end Make_Literal;

   ------------------------------
   -- Make_Literal_With_Parent --
   ------------------------------

   function Make_Literal_With_Parent
     (Value  : Value_Id; Parent : Node_Id) return Node_Id
   is
      N : Node_Id := New_Node (K_Literal);

   begin
      Set_Value (N, Value);

      if Present (Parent) and then Value /= No_Value then
         N := Make_Selected_Component (Parent, N);
      end if;

      return N;
   end Make_Literal_With_Parent;

   -------------------------
   -- Make_Null_Statement --
   -------------------------

   function Make_Null_Statement
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Null_Statement);
      return N;
   end Make_Null_Statement;

   -----------------------------
   -- Make_Object_Declaration --
   -----------------------------

   function Make_Object_Declaration
     (Defining_Identifier : Node_Id;
      Constant_Present    : Boolean := False;
      Object_Definition   : Node_Id;
      Expression          : Node_Id := No_Node;
      Parent              : Node_Id := Current_Package;
      Renamed_Object      : Node_Id := No_Node;
      Aliased_Present     : Boolean := False)
     return Node_Id
   is
      N : Node_Id;
   begin
      pragma Assert (Kind (Defining_Identifier) = K_Defining_Identifier);

      N := New_Node           (K_Object_Declaration);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Declaration_Node  (Defining_Identifier, N);
      Set_Constant_Present    (N, Constant_Present);
      Set_Aliased_Present     (N, Aliased_Present);
      Set_Object_Definition   (N, Object_Definition);
      Set_Expression          (N, Expression);
      Set_Renamed_Entity      (N, Renamed_Object);
      Set_Parent (N, Parent);
      return N;
   end Make_Object_Declaration;

   -------------------------------
   -- Make_Object_Instantiation --
   -------------------------------

   function Make_Object_Instantiation
     (Qualified_Expression : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Object_Instantiation);
      Set_Qualified_Expression (N, Qualified_Expression);
      return N;
   end Make_Object_Instantiation;

   ------------------------------
   -- Make_Package_Declaration --
   ------------------------------

   function Make_Package_Declaration
     (Identifier : Node_Id; Include_Source : Boolean := False) return Node_Id
   is
      Pkg         : Node_Id;
      Unit        : Node_Id;

      function Make_Anon_Allocator_Warning_Pragma return Node_Id;
      --  Returns a pragma to disable warnings about anonymous allocators. This
      --  is necessary because we make liberal use of these. See for example
      --  the To_Any function that is generated for a struct, which passes an
      --  allocator to an access parameter. We should really switch to using
      --  named access types.

      function Make_Unnecesary_With_Of_Ancestor_Warning_Pragma return Node_Id;
      --  Returns a pragma to disable warnings about unnecessary with of
      --  ancestor package.

      function Make_Style_Check_Pragma return Node_Id;
      --  Returns a node for a pragma deactivating style checks

      function Make_Character_Encoding_Pragma return Node_Id;
      --  Returns a node for an encoding specification pragma

      -----------------------------
      -- Make_Style_Check_Pragma --
      -----------------------------

      function Make_Style_Check_Pragma return Node_Id is
      begin
         --  Note: just using Style_Checks (Off) wouldn't turn off line length
         --  checks, so we need to define the maximum line length explicitly.
         --  We set it to the maximum value supported by GNAT: 32766.

         Set_Str_To_Name_Buffer ("NM32766");

         return Make_Pragma
                  (Pragma_Style_Checks,
                   New_List
                     (Make_Literal
                        (New_String_Value (Name_Find, Wide => False))));
      end Make_Style_Check_Pragma;

      ----------------------------------------
      -- Make_Anon_Allocator_Warning_Pragma --
      ----------------------------------------

      function Make_Anon_Allocator_Warning_Pragma return Node_Id is
      begin
         Set_Str_To_Name_Buffer ("use of an anonymous access type allocator");

         return Make_Pragma
                  (Pragma_Warnings,
                   New_List
                     (RE (RE_Off),
                      Make_Literal
                        (New_String_Value (Name_Find, Wide => False))));
      end Make_Anon_Allocator_Warning_Pragma;

      -----------------------------------------------------
      -- Make_Unnecesary_With_Of_Ancestor_Warning_Pragma --
      -----------------------------------------------------

      function Make_Unnecesary_With_Of_Ancestor_Warning_Pragma
        return Node_Id is
      begin
         Set_Str_To_Name_Buffer ("unnecessary with of ancestor");

         return Make_Pragma
                  (Pragma_Warnings,
                   New_List
                     (RE (RE_Off),
                      Make_Literal
                        (New_String_Value (Name_Find, Wide => False))));
      end Make_Unnecesary_With_Of_Ancestor_Warning_Pragma;

      ------------------------------------
      -- Make_Character_Encoding_Pragma --
      ------------------------------------

      function Make_Character_Encoding_Pragma return Node_Id is
      begin
         return Make_Pragma
                  (Pragma_Wide_Character_Encoding,
                   New_List (Make_Identifier (Encoding_Name)));
      end Make_Character_Encoding_Pragma;

   --  Start of processing for Make_Package_Declaration

   begin
      Unit := New_Node (K_Package_Declaration);
      Set_Defining_Identifier (Unit, Identifier);

      if Kind (Identifier) = K_Defining_Identifier then
         Set_Declaration_Node (Identifier, Unit);

      elsif Kind (Identifier) = K_Selected_Component then
         Set_Declaration_Node (Selector_Name (Identifier), Unit);

      else
         raise Program_Error;
      end if;

      if Present (Current_Entity)
        and then FEN."/="
        (FEN.Kind
         (FEN.Corresponding_Entity
          (FE_Node
           (Current_Entity))),
         FEN.K_Specification)
      then
         Set_Parent (Unit, Stubs_Package (Current_Entity));
      end if;

      --  Building the specification part of the package

      Pkg := New_Node (K_Package_Specification);
      Set_Context_Clause (Pkg, New_List);

      --  Disabling style checks. We put the pragma before the header
      --  comment because some lines in the header may be very long.

      Append_To (Context_Clause (Pkg), Make_Style_Check_Pragma);
      Append_To (Context_Clause (Pkg), Make_Character_Encoding_Pragma);
      Append_To (Context_Clause (Pkg), Make_Anon_Allocator_Warning_Pragma);

      --  Adding a comment header

      Make_Comment_Header (Context_Clause (Pkg), Identifier, Include_Source);

      Set_Visible_Part (Pkg, New_List);
      Set_Nested_Packages (Pkg, New_List);
      Set_Private_Part (Pkg, New_List);
      Set_Package_Declaration (Pkg, Unit);
      Set_Package_Specification (Unit, Pkg);

      --  Building the implementation part of the package

      Pkg := New_Node (K_Package_Body);
      Set_Context_Clause (Pkg, New_List);

      --  Disabling style checks. We put the pragma before the header
      --  comment because some lines in the header may be very long.

      Append_To (Context_Clause (Pkg), Make_Style_Check_Pragma);
      Append_To (Context_Clause (Pkg), Make_Anon_Allocator_Warning_Pragma);
      Append_To
        (Context_Clause (Pkg),
         Make_Unnecesary_With_Of_Ancestor_Warning_Pragma);

      --  Adding a comment header. We only want to include source in the spec.

      Make_Comment_Header
        (Context_Clause (Pkg), Identifier, Include_Source => False);

      Set_Statements (Pkg, New_List);
      Set_Package_Declaration (Pkg, Unit);
      Set_Package_Body (Unit, Pkg);

      return Unit;
   end Make_Package_Declaration;

   --------------------------------
   -- Make_Package_Instantiation --
   --------------------------------

   function Make_Package_Instantiation
     (Defining_Identifier : Node_Id;
      Generic_Package     : Node_Id;
      Parameter_List      : List_Id := No_List;
      Parent              : Node_Id := Current_Package) return Node_Id
   is
      N : Node_Id;
   begin
      pragma Assert (Kind (Defining_Identifier) = K_Defining_Identifier);

      N := New_Node (K_Package_Instantiation);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Declaration_Node (Defining_Identifier, N);
      Set_Generic_Package (N, Generic_Package);
      Set_Parameter_List (N, Parameter_List);
      Set_Parent         (N, Parent);
      return N;
   end Make_Package_Instantiation;

   --------------------------------
   -- Make_Parameter_Association --
   --------------------------------

   function Make_Parameter_Association
     (Selector_Name    : Node_Id;
      Actual_Parameter : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Parameter_Association);
      Set_Selector_Name (N, Selector_Name);
      Set_Actual_Parameter (N, Actual_Parameter);
      return N;
   end Make_Parameter_Association;

   ----------------------------------
   -- Make_Parameter_Specification --
   ----------------------------------

   function Make_Parameter_Specification
     (Defining_Identifier : Node_Id;
      Subtype_Mark        : Node_Id;
      Parameter_Mode      : Mode_Id := Mode_In;
      Expression          : Node_Id := No_Node)
     return Node_Id
   is
      P : Node_Id;

   begin
      P := New_Node (K_Parameter_Specification);
      Set_Defining_Identifier (P, Defining_Identifier);
      Set_Parameter_Type (P, Subtype_Mark);
      Set_Parameter_Mode (P, Parameter_Mode);
      Set_Expression (P, Expression);
      return P;
   end Make_Parameter_Specification;

   -----------------
   -- Make_Pragma --
   -----------------

   function Make_Pragma
     (The_Pragma    : Pragma_Id;
      Argument_List : List_Id := No_List) return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Pragma);
      Set_Defining_Identifier (N, Make_Defining_Identifier (GN (The_Pragma)));
      Set_Argument_List (N, Argument_List);
      return N;
   end Make_Pragma;

   -------------------------------
   -- Make_Qualified_Expression --
   -------------------------------

   function Make_Qualified_Expression
     (Subtype_Mark : Node_Id;
      Operand      : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Qualified_Expression);
      Set_Subtype_Mark (N, Subtype_Mark);
      Set_Operand (N, Operand);
      return N;
   end Make_Qualified_Expression;

   --------------------------
   -- Make_Raise_Statement --
   --------------------------

   function Make_Raise_Statement
     (Raised_Error  : Node_Id := No_Node)
     return Node_Id is
      N : Node_Id;
   begin
      N := New_Node (K_Raise_Statement);
      Set_Raised_Error (N, Raised_Error);
      return N;
   end Make_Raise_Statement;

   ----------------
   -- Make_Slice --
   ----------------

   function Make_Slice
     (Prefix         : Node_Id;
      Discrete_Range : Node_Id) return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Slice);
      Set_Prefix         (N, Prefix);
      Set_Discrete_Range (N, Discrete_Range);
      return N;
   end Make_Slice;

   ----------------
   -- Make_Range --
   ----------------

   function Make_Range
     (Low_Bound  : Node_Id;
      High_Bound : Node_Id) return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Range);
      Set_Low_Bound  (N, Low_Bound);
      Set_High_Bound (N, High_Bound);
      return N;
   end Make_Range;

   ---------------------------
   -- Make_Range_Constraint --
   ---------------------------

   function Make_Range_Constraint
     (First : Node_Id; Last  : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Range_Constraint);
      Set_First (N, First);
      Set_Last (N, Last);
      return N;
   end Make_Range_Constraint;

   ---------------------------
   -- Make_Record_Aggregate --
   ---------------------------

   function Make_Record_Aggregate
     (L             : List_Id;
      Ancestor_Part : Node_Id := No_Node)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Record_Aggregate);
      Set_Component_Association_List (N, L);
      Set_Ancestor_Part (N, Ancestor_Part);
      return N;
   end Make_Record_Aggregate;

   ----------------------------
   -- Make_Record_Definition --
   ----------------------------

   function Make_Record_Definition
     (Component_List : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Record_Definition);
      Set_Component_List (N, Component_List);
      return N;
   end Make_Record_Definition;

   ---------------------------------
   -- Make_Record_Type_Definition --
   ---------------------------------

   function Make_Record_Type_Definition
     (Record_Definition : Node_Id;
      Is_Abstract_Type  : Boolean := False;
      Is_Tagged_Type    : Boolean := False;
      Is_Limited_Type   : Boolean := False)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Record_Type_Definition);
      Set_Is_Abstract_Type (N, Is_Abstract_Type);
      Set_Is_Tagged_Type (N, Is_Tagged_Type);
      Set_Is_Limited_Type (N, Is_Limited_Type);
      Set_Record_Definition (N, Record_Definition);
      return N;
   end Make_Record_Type_Definition;

   ---------------------------
   -- Make_Return_Statement --
   ---------------------------

   function Make_Return_Statement (Expression : Node_Id) return Node_Id is
      N : Node_Id;
   begin
      N := New_Node (K_Return_Statement);
      Set_Expression (N, Expression);
      return N;
   end Make_Return_Statement;

   -----------------------------
   -- Make_Selected_Component --
   -----------------------------

   function Make_Selected_Component
     (Prefix        : Node_Id;
      Selector_Name : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      pragma Assert (Present (Selector_Name));
      pragma Assert (Kind (Selector_Name) /= K_Selected_Component);

      if Present (Prefix) then
         pragma Assert (Kind (Prefix) /= K_Package_Declaration      and then
                        Kind (Prefix) /= K_Package_Specification    and then
                        Kind (Prefix) /= K_Package_Body             and then
                        Kind (Prefix) /= K_Subprogram_Specification and then
                        Kind (Prefix) /= K_Subprogram_Body          and then
                        Kind (Prefix) /= K_Full_Type_Declaration);

         N := New_Node (K_Selected_Component);
         Set_Prefix (N, Prefix);
         Set_FE_Node (N, FE_Node (Selector_Name));
         Set_Selector_Name (N, Selector_Name);
         return N;
      else
         return Selector_Name;
      end if;
   end Make_Selected_Component;

   -----------------------------
   -- Make_Selected_Component --
   -----------------------------

   function Make_Selected_Component
     (Prefix        : Name_Id;
      Selector_Name : Name_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      pragma Assert (Selector_Name /= No_Name);

      if Prefix /= No_Name then
         N := New_Node (K_Selected_Component);
         Set_Prefix (N, Make_Identifier (Prefix));
         Set_Selector_Name (N, Make_Identifier (Selector_Name));
         return N;
      else
         return Make_Identifier (Selector_Name);
      end if;
   end Make_Selected_Component;

   --------------------------
   -- Make_Subprogram_Call --
   --------------------------

   function Make_Subprogram_Call
     (Defining_Identifier : Node_Id;
      Actual_Parameter_Part : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Subprogram_Call);
      Set_Defining_Identifier (N, Defining_Identifier);
      Set_Actual_Parameter_Part (N, Actual_Parameter_Part);
      return N;
   end Make_Subprogram_Call;

   --------------------------
   -- Make_Subprogram_Body --
   --------------------------

   function Make_Subprogram_Body
     (Specification : Node_Id;
      Declarations  : List_Id;
      Statements    : List_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Subprogram_Body);
      Set_Specification (N, Specification);
      Set_Declarations (N, Declarations);
      Set_Statements (N, Statements);
      return N;
   end Make_Subprogram_Body;

   -----------------------------------
   -- Make_Subprogram_Specification --
   -----------------------------------

   function Make_Subprogram_Specification
     (Defining_Identifier     : Node_Id;
      Parameter_Profile       : List_Id;
      Return_Type             : Node_Id := No_Node;
      Parent                  : Node_Id := Current_Package;
      Renamed_Subprogram      : Node_Id := No_Node;
      Instantiated_Subprogram : Node_Id := No_Node)
     return Node_Id
   is
      N : Node_Id;
   begin
      pragma Assert (Kind (Defining_Identifier) = K_Defining_Identifier);

      N := New_Node               (K_Subprogram_Specification);
      Set_Defining_Identifier     (N, Defining_Identifier);
      Set_Parameter_Profile       (N, Parameter_Profile);
      Set_Return_Type             (N, Return_Type);
      Set_Parent                  (N, Parent);
      Set_Renamed_Entity          (N, Renamed_Subprogram);
      Set_Instantiated_Subprogram (N, Instantiated_Subprogram);
      return N;
   end Make_Subprogram_Specification;

   --------------------------
   -- Make_Type_Conversion --
   --------------------------

   function Make_Type_Conversion
     (Subtype_Mark : Node_Id;
      Expression   : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Type_Conversion);
      Set_Subtype_Mark (N, Subtype_Mark);
      Set_Expression (N, Expression);
      return N;
   end Make_Type_Conversion;

   --------------------
   -- Make_Used_Type --
   --------------------

   function Make_Used_Type
     (The_Used_Type : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Used_Type);

      Set_The_Used_Entity (N, The_Used_Type);
      return N;
   end Make_Used_Type;

   -----------------------
   -- Make_Used_Package --
   -----------------------

   function Make_Used_Package
     (The_Used_Package : Node_Id)
     return Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Used_Package);
      Set_The_Used_Entity (N, The_Used_Package);
      return N;
   end Make_Used_Package;

   -----------------------
   -- Make_Variant_Part --
   -----------------------

   function Make_Variant_Part
     (Discriminant        : Node_Id;
      Variant_List        : List_Id)
     return                Node_Id
   is
      N : Node_Id;
   begin
      N := New_Node (K_Variant_Part);
      Set_Variants (N, Variant_List);
      Set_Discriminant (N, Discriminant);
      return N;
   end Make_Variant_Part;

   -------------------------
   -- Make_Comment_Header --
   -------------------------

   procedure Make_Comment_Header
     (Package_Header     : List_Id;
      Package_Identifier : Node_Id;
      Include_Source : Boolean)
   is
      Separator    : Name_Id;
      --  A line of hyphens

      Pkg_Name_Str : constant String := "Impl";
      Internal_Str : constant String := "Internals";
      Editable     : Boolean;
      Internal     : Boolean;

      procedure Comment
        (Message : Name_Id; Has_Header_Spaces : Boolean := True);
      procedure Comment
        (Message : String; Has_Header_Spaces : Boolean := True);
      --  Append an Ada_Comment node to Package_Header

      procedure Comment_Source_File (Source : Source_File);
      --  Append the entire Source (an IDL source file), commented out, to the
      --  Package_Header

      -------------
      -- Comment --
      -------------

      procedure Comment
        (Message : Name_Id; Has_Header_Spaces : Boolean := True)
      is
      begin
         Append_To
           (Package_Header, Make_Ada_Comment (Message, Has_Header_Spaces));
      end Comment;

      procedure Comment
        (Message : String; Has_Header_Spaces : Boolean := True)
      is
      begin
         Set_Str_To_Name_Buffer (Message);
         Comment (Name_Find, Has_Header_Spaces);
      end Comment;

      -------------------------
      -- Comment_Source_File --
      -------------------------

      procedure Comment_Source_File (Source : Source_File) is
         Max_Num_Lines : constant Natural := 10_000;
         --  Avoid generating enormous comments, by limiting the number of
         --  lines to this

         Num_Lines : Natural := 0;
         --  Number of comment lines so far

         procedure Append_Comment (Line : String);
         --  Add a comment line, and keep track of Num_Lines

         procedure Append_Comment (Line : String) is
         begin
            Num_Lines := Num_Lines + 1;
            if Num_Lines > Max_Num_Lines then
               return;
            end if;

            Comment (Line);
         end Append_Comment;

      begin
         case Source.Kind is
            when Preprocessed_Source =>
               null; -- skip it

            when True_Source =>
               Comment ("");
               Comment ("Source: " & Get_Name_String (Source.Name));
               Comment ("");

               Iterate_Lines (Source, Append_Comment'Access);

               if Num_Lines > Max_Num_Lines then
                  Comment
                    ("..." & Natural (Num_Lines - Max_Num_Lines)'Img &
                     " lines elided");
               end if;

               Comment
                 ("End source: " & Get_Name_String (Source.Name) &
                  " --" & Num_Lines'Img & " lines");
         end case;
      end Comment_Source_File;

   begin
      --  Determine whether this package is intended to be edited by the user

      Editable :=
        (Pkg_Name_Str = Get_Name_String (Get_Name (Package_Identifier)));

      --  Check whether the package is internal to PolyORB

      Internal :=
        (Internal_Str = Get_Name_String (Get_Name (Package_Identifier)));

      --  Prepare separator line for comment box

      Set_Str_To_Name_Buffer
        ("-------------------------------------------------");
      Separator := Name_Find;

      --  Append the comment header lines to the package header

      Comment ("");
      Comment (Separator, Has_Header_Spaces => False);
      Comment ("This file has been generated automatically from");
      Comment (Main_Source);
      Comment ("by IAC (IDL to Ada Compiler) " & Platform.Version & ".");

      if not Editable then
         Comment (Separator, Has_Header_Spaces => False);
         Comment ("NOTE: If you modify this file by hand, your");
         Comment ("changes will be lost when you re-run the");
         Comment ("IDL to Ada compiler.");
         Comment (Separator, Has_Header_Spaces => False);
      end if;

      if Internal then
         Comment (Separator, Has_Header_Spaces => False);
         Comment ("This package is not part of the standard IDL-to-Ada");
         Comment ("mapping. It provides supporting routines used");
         Comment ("internally by PolyORB.");
      end if;

      if Include_Source then
         --  Loop through all the source files, and add them as comments

         Iterate_Source_Files (Comment_Source_File'Access);

         Comment ("");
         Comment (Separator, Has_Header_Spaces => False);
      end if;

      Comment ("");
   end Make_Comment_Header;

   -----------------
   -- Next_N_Node --
   -----------------

   function Next_N_Node (N : Node_Id; Num : Natural) return Node_Id is
      Result : Node_Id := N;
   begin
      for I in 1 .. Num loop
         Result := Next_Node (Result);
      end loop;

      return Result;
   end Next_N_Node;

   --------------
   -- New_Node --
   --------------

   function New_Node
     (Kind : Node_Kind;
      From : Node_Id := No_Node)
     return Node_Id
   is
      N : Node_Id;
   begin
      Entries.Increment_Last;
      N := Entries.Last;
      Entries.Table (N) := Default_Node;
      Set_Kind (N, Kind);

      if Present (From) then
         Bind_FE_To_BE (From, N, B_Stub);
         Set_Loc  (N, FEN.Loc (From));
      else
         Set_Loc  (N, Current_Loc);
      end if;

      return N;
   end New_Node;

   ---------------
   -- New_Token --
   ---------------

   procedure New_Token
     (T : Token_Type;
      I : String := "") is
   begin
      if T in Keyword_Type then
         Set_Str_To_Name_Buffer (Image (T));
      else
         Set_Str_To_Name_Buffer (I);
      end if;

      Token_Image (T) := Name_Find;

      --  Mark Ada keywords

      if T in Keyword_Type then
         --  We don't "mark" the keyword name but instead a custom
         --  string ("%ada_kw%<keyword>" to avoid clashing with other
         --  marked names.

         Set_Str_To_Name_Buffer (Ada_Keyword_Prefix);
         Get_Name_String_And_Append (Token_Image (T));
         Set_Name_Table_Byte (Name_Find, Byte (Token_Type'Pos (T) + 1));
      end if;
   end New_Token;

   ------------------
   -- New_Operator --
   ------------------

   procedure New_Operator
     (Op : Operator_Type;
      I : String := "") is
   begin
      if Op in Keyword_Operator then
         Set_Str_To_Name_Buffer (Image (Op));
      else
         Set_Str_To_Name_Buffer (I);
      end if;

      Operator_Image (Operator_Type'Pos (Op)) := Name_Find;
   end New_Operator;

   ----------------
   -- Pop_Entity --
   ----------------

   procedure Pop_Entity is
   begin
      if Last > No_Depth then
         Decrement_Last;
      end if;
   end Pop_Entity;

   -----------------
   -- Push_Entity --
   -----------------

   procedure Push_Entity (E : Node_Id) is
   begin
      Increment_Last;
      Table (Last).Current_Entity := E;
   end Push_Entity;

   ---------------------------
   -- Remove_Node_From_List --
   ---------------------------

   procedure Remove_Node_From_List (E : Node_Id; L : List_Id) is
      C : Node_Id;

   begin
      C := First_Node (L);

      if C = E then
         Set_First_Node (L, Next_Node (E));

         if Last_Node (L) = E then
            Set_Last_Node (L, No_Node);
         end if;
      else
         while Present (C) loop
            if Next_Node (C) = E then
               Set_Next_Node (C, Next_Node (E));

               if Last_Node (L) = E then
                  Set_Last_Node (L, C);
               end if;

               exit;
            end if;
            C := Next_Node (C);
         end loop;
      end if;
   end Remove_Node_From_List;

   -------------------
   -- Set_Forwarded --
   -------------------

   procedure Set_Forwarded (E : Node_Id) is
      N : Node_Id;
   begin
      --  We cannot directly append the node E to the List of
      --  forwarded entities because this node may have to be appended
      --  to other lists.

      N := New_Node (K_Node_Id);
      Set_FE_Node (N, E);

      if Is_Empty (Forwarded_Entities) then
         Forwarded_Entities := New_List;
      end if;

      Append_To (Forwarded_Entities, N);
   end Set_Forwarded;

   ------------------
   -- Is_Forwarded --
   ------------------

   function Is_Forwarded (E : Node_Id) return Boolean is
      Result : Boolean := False;
      N      : Node_Id;
   begin
      if Is_Empty (Forwarded_Entities) then
         Forwarded_Entities := New_List;
      end if;

      N := First_Node (Forwarded_Entities);

      while Present (N) loop
         if FE_Node (N) = E then
            Result := True;
         end if;

         N := Next_Node (N);
      end loop;

      return Result;
   end Is_Forwarded;

   ------------------
   -- Set_CDR_Body --
   ------------------

   procedure Set_CDR_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (CDR_Package (N));
   end Set_CDR_Body;

   ------------------
   -- Set_CDR_Spec --
   ------------------

   procedure Set_CDR_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (CDR_Package (N));
   end Set_CDR_Spec;

   ----------------------
   -- Set_Aligned_Spec --
   ----------------------

   procedure Set_Aligned_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Aligned_Package (N));
   end Set_Aligned_Spec;

   ----------------------
   -- Set_Buffers_Body --
   ----------------------

   procedure Set_Buffers_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (Buffers_Package (N));
   end Set_Buffers_Body;

   ----------------------
   -- Set_Buffers_Spec --
   ----------------------

   procedure Set_Buffers_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Buffers_Package (N));
   end Set_Buffers_Spec;

   ---------------------
   -- Set_Helper_Body --
   ---------------------

   procedure Set_Helper_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (Helper_Package (N));
   end Set_Helper_Body;

   ---------------------
   -- Set_Helper_Spec --
   ---------------------

   procedure Set_Helper_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Helper_Package (N));
   end Set_Helper_Spec;

   ------------------------
   -- Set_Internals_Body --
   ------------------------

   procedure Set_Internals_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (Internals_Package (N));
   end Set_Internals_Body;

   ------------------------
   -- Set_Internals_Spec --
   ------------------------

   procedure Set_Internals_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Internals_Package (N));
   end Set_Internals_Spec;

   -------------------
   -- Set_Impl_Body --
   -------------------

   procedure Set_Impl_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (Implementation_Package (N));
   end Set_Impl_Body;

   -------------------
   -- Set_Impl_Spec --
   -------------------

   procedure Set_Impl_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Implementation_Package (N));
   end Set_Impl_Spec;

   ----------------------
   -- Set_IR_Info_Body --
   ----------------------

   procedure Set_IR_Info_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (Ir_Info_Package (N));
   end Set_IR_Info_Body;

   ----------------------
   -- Set_IR_Info_Spec --
   ----------------------

   procedure Set_IR_Info_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Ir_Info_Package (N));
   end Set_IR_Info_Spec;

   -------------------
   -- Set_Main_Body --
   -------------------

   procedure Set_Main_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (Stubs_Package (N));
   end Set_Main_Body;

   -------------------
   -- Set_Main_Spec --
   -------------------

   procedure Set_Main_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Stubs_Package (N));
   end Set_Main_Spec;

   -----------------------
   -- Set_Skeleton_Body --
   -----------------------

   procedure Set_Skeleton_Body (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Body (Skeleton_Package (N));
   end Set_Skeleton_Body;

   -----------------------
   -- Set_Skeleton_Spec --
   -----------------------

   procedure Set_Skeleton_Spec (N : Node_Id := Current_Entity) is
   begin
      Table (Last).Current_Package :=
        Package_Specification (Skeleton_Package (N));
   end Set_Skeleton_Spec;

   -----------------
   -- To_Ada_Name --
   -----------------

   function To_Ada_Name
     (N                 : Name_Id;
      Is_Operation_Name : Boolean := False) return Name_Id
   is
      First      : Natural := 1;
      Name       : Name_Id;
      Low_Name   : Name_Id;
      Mixed_Name : Name_Id;
      Is_Keyword : Boolean;
   begin
      Get_Name_String (N);

      --  Remove leading underscores

      while First <= Name_Len and then Name_Buffer (First) = '_' loop
         First := First + 1;
      end loop;

      --  Escape doubled underscores

      for I in First .. Name_Len loop
         if Name_Buffer (I) = '_'
           and then I < Name_Len
           and then Name_Buffer (I + 1) = '_'
         then
            Name_Buffer (I + 1) := 'U';
         end if;
      end loop;

      --  Escape trailing underscores

      if Name_Buffer (Name_Len) = '_' then
         Add_Char_To_Name_Buffer ('U');
      end if;

      --  Get name in original case

      Name := Name_Find;

      --  Get name in lowercase

      Low_Name := To_Lower (Name);

      --  Get name in GNAT mixed case, for comparison with SN entries

      GNAT.Case_Util.To_Mixed (Name_Buffer (1 .. Name_Len));
      Mixed_Name := Name_Find;

      --  If the identifier collides with an Ada reserved word or (for object
      --  operations) with a primitive operation of Ada.Finalization.
      --  Controlled, insert "IDL_" string before the identifier.

      Set_Str_To_Name_Buffer (Ada_Keyword_Prefix);
      Get_Name_String_And_Append (Low_Name);
      Is_Keyword := Get_Name_Table_Byte (Name_Find) > 0;

      if Is_Keyword
           or else
          (Is_Operation_Name and then
               (Mixed_Name = SN (S_Initialize)
                  or else
                Mixed_Name = SN (S_Adjust)
                  or else
                Mixed_Name = SN (S_Finalize)))
      then
         Set_Str_To_Name_Buffer ("IDL_");
         Get_Name_String_And_Append (Name);
         Name := Name_Find;
      end if;

      return Name;
   end To_Ada_Name;

   ------------------
   -- To_Spec_Name --
   ------------------

   function To_Spec_Name (N : Name_Id) return Name_Id is
   begin
      Get_Name_String (N);
      To_Lower (Name_Buffer (1 .. Name_Len));

      if Name_Len > 2
        and then Name_Buffer (Name_Len - 1) = '%'
      then
         Name_Buffer (Name_Len) := 's';
      else
         Add_Str_To_Name_Buffer ("%s");
      end if;

      return Name_Find;
   end To_Spec_Name;

   -------------------
   -- Internal_Name --
   -------------------

   function Internal_Name (P : Node_Id; L : GLists) return Name_Id is
      pragma Assert (Kind (P) = K_Package_Declaration);
   begin
      --  The internal name is "<Full.Name.Of.P>%<Image_Of_L>"

      Get_Name_String (Fully_Qualified_Name (Defining_Identifier (P)));
      Add_Char_To_Name_Buffer ('%');
      Add_Str_To_Name_Buffer (GLists'Image (L));
      return Name_Find;
   end Internal_Name;

   ----------------------
   -- Initialize_GList --
   ----------------------

   procedure Initialize_GList (P : Node_Id; L : GLists) is
      pragma Assert (Kind (P) = K_Package_Declaration);

      The_List     : constant List_Id := New_List;
      Binding_Name : constant Name_Id := Internal_Name (P, L);
   begin
      if Get_Name_Table_Info (Binding_Name) = 0 then
         Set_Name_Table_Info (Binding_Name, Nat (The_List));
      end if;
   end Initialize_GList;

   ---------------
   -- Get_GList --
   ---------------

   function Get_GList (P : Node_Id; L : GLists) return List_Id is
      pragma Assert (Kind (P) = K_Package_Declaration);

      The_List     : List_Id;
      Binding_Name : constant Name_Id := Internal_Name (P, L);
   begin
      The_List := List_Id (Get_Name_Table_Info (Binding_Name));

      if The_List = No_List then
         The_List := New_List;
         Set_Name_Table_Info (Binding_Name, Nat (The_List));
      end if;

      return The_List;
   end Get_GList;

   ------------------------
   -- Set_UTF_8_Encoding --
   ------------------------

   procedure Set_UTF_8_Encoding is
   begin
      The_Unique_Suffix := UTF_8_Unique_Suffix'Access;
      The_Unique_Infix  := UTF_8_Unique_Infix'Access;
      Use_UTF8          := True;
   end Set_UTF_8_Encoding;

end Backend.BE_CORBA_Ada.Nutils;
