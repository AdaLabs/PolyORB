------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                      P O L Y O R B . B U F F E R S                       --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2001-2003 Free Software Foundation, Inc.           --
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
--                PolyORB is maintained by ACT Europe.                      --
--                    (email: sales@act-europe.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

--  $Id$

with Ada.Unchecked_Deallocation;
--  For Iovec_Pools.Free.

with System.Address_To_Access_Conversions;

with PolyORB.Log;

package body PolyORB.Buffers is

   use Ada.Streams;
   use System.Storage_Elements;
   use PolyORB.Opaque;
   use PolyORB.Log;
   use Buffer_Chunk_Pools;
   use Iovec_Pools;

   package L is new PolyORB.Log.Facility_Log ("polyorb.buffers");
   procedure O (Message : in String; Level : Log_Level := Debug)
     renames L.Output;

   package L2 is new PolyORB.Log.Facility_Log ("polyorb.buffers_show");
   procedure O2 (Message : in String; Level : Log_Level := Debug)
     renames L2.Output;

   ------------------------
   -- General operations --
   ------------------------

   ------------
   -- Length --
   ------------

   function Length
     (Buffer : access Buffer_Type)
     return Stream_Element_Count is
   begin
      return Buffer.Length;
   end Length;

   --------------------
   -- Set_Endianness --
   --------------------

   procedure Set_Endianness
     (Buffer : access Buffer_Type;
      E      :        Endianness_Type) is
   begin
      pragma Assert
        (Buffer.CDR_Position = Buffer.Initial_CDR_Position);

      Buffer.Endianness := E;
   end Set_Endianness;

   ----------------
   -- Endianness --
   ----------------

   function Endianness
     (Buffer : Buffer_Type)
     return Endianness_Type is
   begin
      return Buffer.Endianness;
   end Endianness;

   ----------------------
   -- Release_Contents --
   ----------------------

   procedure Release_Contents
     (Buffer : in out Buffer_Type) is
   begin
      Release (Buffer.Contents);
      Buffer_Chunk_Pools.Release (Buffer.Storage'Access);
      Buffer.CDR_Position         := 0;
      Buffer.Initial_CDR_Position := 0;
      Buffer.Endianness           := Host_Order;
      Buffer.Length               := 0;
   end Release_Contents;

   -----------------------
   -- Initialize_Buffer --
   -----------------------

   procedure Initialize_Buffer
     (Buffer               : access Buffer_Type;
      Size                 :        Stream_Element_Count;
      Data                 :        Opaque_Pointer;
      Endianness           :        Endianness_Type;
      Initial_CDR_Position :        Stream_Element_Offset)
   is
      Data_Iovec : constant Iovec
        := (Iov_Base => Data,
            Iov_Len  => Storage_Offset (Size));

   begin
      pragma Assert (True
        and then Buffer.CDR_Position = 0
        and then Buffer.Initial_CDR_Position = 0);

      Buffer.Endianness           := Endianness;
      Buffer.CDR_Position         := Initial_CDR_Position;
      Buffer.Initial_CDR_Position := Initial_CDR_Position;

      Append
        (Iovec_Pool => Buffer.Contents,
         An_Iovec   => Data_Iovec);

      Buffer.Length := Size;
   end Initialize_Buffer;

   -------------
   -- Reserve --
   -------------

   function Reserve
     (Buffer : access Buffer_Type;
      Amount :        Stream_Element_Count)
     return Reservation
   is
      Copy_Address : Opaque_Pointer;
      Initial_Position : constant Stream_Element_Offset
        := Buffer.CDR_Position;
   begin
      Allocate_And_Insert_Cooked_Data
        (Buffer, Amount, Copy_Address);

      return Reservation'
        (Location     => Copy_Address,
         Endianness   => Buffer.Endianness,
         CDR_Position => Initial_Position,
         Length       => Amount);
   end Reserve;

   ---------------
   -- Copy_Data --
   ---------------

   procedure Copy_Data
     (From : in Buffer_Type;
      Into :    Reservation) is
   begin
      pragma Assert (True
        and then From.Endianness   = Into.Endianness
        and then From.Initial_CDR_Position = Into.CDR_Position
        and then From.Length       = Into.Length);

      Iovec_Pools.Dump (From.Contents, Into.Location);
   end Copy_Data;

   ----------
   -- Copy --
   ----------

   function Copy
     (Buffer : access Buffer_Type)
     return Buffer_Access
   is
      Into         : constant Buffer_Access := new Buffer_Type;
      Copy_Address : Opaque_Pointer;

   begin
      Into.Endianness := Buffer.Endianness;
      Set_Initial_Position (Into, Buffer.Initial_CDR_Position);

      Allocate_And_Insert_Cooked_Data
        (Into,
         Buffer.Length,
         Copy_Address);

      Iovec_Pools.Dump (Buffer.Contents, Copy_Address);

      Into.CDR_Position := Buffer.Initial_CDR_Position;
      return Into;
   end Copy;

   -------------
   -- Release --
   -------------

   procedure Release
     (A_Buffer : in out Buffer_Access)
   is
      procedure Free is new Ada.Unchecked_Deallocation
        (Buffer_Type, Buffer_Access);

   begin
      if A_Buffer /= null then
         Release_Contents (A_Buffer.all);
         Free (A_Buffer);
      end if;
   end Release;

   -----------------------------
   -- To_Stream_Element_Array --
   -----------------------------

   function To_Stream_Element_Array
     (Buffer   : access Buffer_Type)
     return Opaque.Zone_Access is
   begin
      pragma Assert (Buffer.Initial_CDR_Position = 0);
      return Iovec_Pools.Dump (Buffer.Contents);
   end To_Stream_Element_Array;

   function To_Stream_Element_Array
     (Buffer   : access Buffer_Type)
     return Stream_Element_Array
   is
      Contents : Zone_Access := To_Stream_Element_Array (Buffer);
      Result   : constant Stream_Element_Array := Contents.all;
   begin
      Free (Contents);
      return Result;
   end To_Stream_Element_Array;

   ----------
   -- Peek --
   ----------

   function Peek
     (Buffer   : access Buffer_Type;
      Position :        Ada.Streams.Stream_Element_Offset)
     return Ada.Streams.Stream_Element is
   begin
      return Iovec_Pools.Peek
        (Iovec_Pool => Buffer.Contents,
         Offset     => Position - Buffer.Initial_CDR_Position);
   end Peek;

   ------------------------------
   -- The CDR view of a buffer --
   ------------------------------

   --------------------------
   -- Set_Initial_Position --
   --------------------------

   procedure Set_Initial_Position
     (Buffer   : access Buffer_Type;
      Position :        Stream_Element_Offset) is
   begin
      pragma Assert
        (Buffer.Initial_CDR_Position = Buffer.CDR_Position);

      Buffer.Initial_CDR_Position := Position;
      Buffer.CDR_Position         := Position;
   end Set_Initial_Position;

   Null_Data : aliased Stream_Element_Array (1 .. Alignment_Type'Last - 1)
     := (1 .. Alignment_Type'Last - 1 => 0);
   --  Null data used for padding.

   Null_Data_Address : constant Opaque_Pointer
     := Null_Data (Null_Data'First)'Address;

   ---------------
   -- Pad_Align --
   ---------------

   procedure Pad_Align
     (Buffer    : access Buffer_Type;
      Alignment :        Alignment_Type)
   is
      Padding : constant Stream_Element_Count
         := (Alignment - Buffer.CDR_Position) mod Alignment;
      Padding_Space : Opaque_Pointer;
   begin
      if Padding = 0 then
         --  Buffer is already aligned.

         return;
      end if;

      pragma Debug
        (O ("Pad_Align: pos = "
            & Stream_Element_Offset'Image (Buffer.CDR_Position)));
      pragma Debug
        (O ("Aligning on" & Alignment_Type'Image (Alignment)));
      pragma Debug (O ("Padding by"
                       & Stream_Element_Count'Image (Padding)));

      Grow_Shrink (Buffer.Contents'Access, Padding, Padding_Space);
      --  Try to extend Buffer.Content's last Iovec
      --  to provide proper alignment.

      if Is_Null (Padding_Space) then
         --  Grow was unable to extend the last Iovec:
         --  insert a non-growable iovec corresponding
         --  to static null data.

         declare
            Padding_Iovec : constant Iovec
              := (Iov_Base => Null_Data_Address,
                  Iov_Len  => Storage_Offset (Padding));
         begin
            Append
              (Iovec_Pool => Buffer.Contents,
               An_Iovec   => Padding_Iovec);
         end;
      end if;

      Buffer.Length := Buffer.Length + Padding;
      Align_Position (Buffer, Alignment);
   end Pad_Align;

   --------------------
   -- Align_Position --
   --------------------

   procedure Align_Position
     (Buffer    : access Buffer_Type;
      Alignment :        Alignment_Type)
   is
      Padding : constant Stream_Element_Count
         := (Alignment - Buffer.CDR_Position) mod Alignment;
   begin
      if Padding = 0 then
         --  Buffer is already aligned.

         return;
      end if;

      pragma Debug
        (O ("Align_Position: pos = "
            & Stream_Element_Offset'Image (Buffer.CDR_Position)));
      pragma Debug
        (O ("Aligning on" & Alignment_Type'Image (Alignment)));
      pragma Debug
        (O ("Padding by" & Stream_Element_Count'Image (Padding)));

      pragma Assert
        (Buffer.CDR_Position + Padding
         <= Buffer.Initial_CDR_Position + Buffer.Length);

      Buffer.CDR_Position := Buffer.CDR_Position + Padding;
      --  Advance the CDR position to the new alignment.

      pragma Assert (Buffer.CDR_Position mod Alignment = 0);
      --  Post-condition: the buffer is aligned as requested.

      pragma Debug
        (O ("Align_Position: now at"
            & Stream_Element_Offset'Image (Buffer.CDR_Position)));

   end Align_Position;

   ---------------------
   -- Insert_Raw_Data --
   ---------------------

   procedure Insert_Raw_Data
     (Buffer    : access Buffer_Type;
      Size      :        Stream_Element_Count;
      Data      :        Opaque_Pointer)
   is
      Data_Iovec : constant Iovec
        := (Iov_Base => Data, Iov_Len  => Storage_Offset (Size));
   begin
      pragma Assert (Buffer.Endianness = Host_Order);

      Append
        (Iovec_Pool => Buffer.Contents,
         An_Iovec   => Data_Iovec);
      Buffer.CDR_Position := Buffer.CDR_Position + Size;
      Buffer.Length := Buffer.Length + Size;
   end Insert_Raw_Data;

   -------------------------------------
   -- Allocate_And_Insert_Cooked_Data --
   -------------------------------------

   procedure Allocate_And_Insert_Cooked_Data
     (Buffer    : access Buffer_Type;
      Size      :        Stream_Element_Count;
      Data      :    out Opaque_Pointer)
   is
      A_Data : Opaque_Pointer;

   begin
      Grow_Shrink (Buffer.Contents'Access, Size, A_Data);
      --  First try to grow an existing Iovec.

      if Is_Null (A_Data) then
         declare
            A_Chunk : Chunk_Access;
            Data_Iovec : Iovec;
         begin
            Allocate (Buffer.Storage'Access, A_Chunk, Size);
            pragma Assert (A_Chunk /= null and then A_Chunk.Size >= Size);
            Data_Iovec := (Iov_Base => Chunk_Storage (A_Chunk),
                           Iov_Len  => Storage_Offset (Size));

            A_Data := Chunk_Storage (A_Chunk);
            Metadata (A_Chunk).all := (Last_Used => Size);
            Append
              (Iovec_Pool => Buffer.Contents,
               An_Iovec   => Data_Iovec,
               A_Chunk    => A_Chunk);
            pragma Assert (not Is_Null (A_Data));
         end;
      end if;

      Data := A_Data;
      Buffer.CDR_Position := Buffer.CDR_Position + Size;
      Buffer.Length := Buffer.Length + Size;
   end Allocate_And_Insert_Cooked_Data;

   ----------------------
   -- Unuse_Allocation --
   ----------------------

   procedure Unuse_Allocation
     (Buffer    : access Buffer_Type;
      Size      :        Stream_Element_Count)
   is
      Data : Opaque_Pointer;

   begin
      if Size /= 0 then
         Grow_Shrink (Buffer.Contents'Access, -Size, Data);
         Buffer.CDR_Position := Buffer.CDR_Position - Size;
         Buffer.Length := Buffer.Length - Size;
      end if;
   end Unuse_Allocation;

   ------------------
   -- Extract_Data --
   ------------------

   procedure Extract_Data
     (Buffer      : access Buffer_Type;
      Data        :    out Opaque_Pointer;
      Size        :        Stream_Element_Count;
      Use_Current :        Boolean := True;
      At_Position :        Stream_Element_Offset := 0)
   is
      Start_Position : Stream_Element_Offset;

   begin
      if Use_Current then
         Start_Position := Buffer.CDR_Position;
      else
         Start_Position := At_Position;
      end if;

      Extract_Data
        (Buffer.Contents, Data,
         Start_Position - Buffer.Initial_CDR_Position, Size);

      if Use_Current then
         Buffer.CDR_Position := Buffer.CDR_Position + Size;
      end if;
   end Extract_Data;

   ------------------
   -- CDR_Position --
   ------------------

   function CDR_Position
     (Buffer : access Buffer_Type)
     return Stream_Element_Offset is
   begin
      return Buffer.CDR_Position;
   end CDR_Position;

   ----------------------
   -- Set_CDR_Position --
   ----------------------

   procedure Set_CDR_Position
     (Buffer   : access Buffer_Type;
      Position :        Stream_Element_Offset) is
   begin
      Buffer.CDR_Position := Position;
   end Set_CDR_Position;

   ------------
   -- Rewind --
   ------------

   procedure Rewind
     (Buffer : access Buffer_Type) is
   begin
      Buffer.CDR_Position := Buffer.Initial_CDR_Position;
   end Rewind;

   ---------------
   -- Remaining --
   ---------------

   function Remaining
     (Buffer : access Buffer_Type)
     return Stream_Element_Count is
   begin
      return Buffer.Initial_CDR_Position + Buffer.Length
        - Buffer.CDR_Position;
   end Remaining;

   ---------------------------------------
   -- The input/output view of a buffer --
   ---------------------------------------

   -----------------
   -- Send_Buffer --
   -----------------

   procedure Send_Buffer
     (Buffer : access Buffer_Type;
      Socket :        Sockets.Socket_Type;
      To     :        Sockets.Sock_Addr_Type := Sockets.No_Sock_Addr) is
   begin
      Iovec_Pools.Write_To_Socket
        (Socket, Buffer.Contents'Access, Buffer.Length, To);
   end Send_Buffer;

   --------------------
   -- Receive_Buffer --
   --------------------

   procedure Receive_Buffer
     (Buffer   : access Buffer_Type;
      Socket   :        Sockets.Socket_Type;
      Max      :        Stream_Element_Count;
      Received :    out Stream_Element_Count)
   is
      Data : Opaque_Pointer;
      Last : Stream_Element_Offset;
      Addr : PolyORB.Sockets.Sock_Addr_Type;
      Saved_CDR_Position : constant Stream_Element_Offset
        := Buffer.CDR_Position;

   begin
      pragma Debug (O ("Receive_buffer: max is" & Max'Img));

      Allocate_And_Insert_Cooked_Data (Buffer, Max, Data);
      declare
         Z_Addr : constant System.Address := Data;
         Z : Stream_Element_Array (0 .. Max - 1);
         for Z'Address use Z_Addr;
         pragma Import (Ada, Z);
      begin
         PolyORB.Sockets.Receive_Socket
           (Socket => Socket,
            Item   => Z,
            Last   => Last,
            From   => Addr);
      end;
      Received := Last + 1;
      Unuse_Allocation (Buffer, Max - Received);
      Buffer.CDR_Position := Saved_CDR_Position;
   end Receive_Buffer;

   -------------------------
   -- Utility subprograms --
   -------------------------

   procedure Show (Octets : Zone_Access);
   --  Display the contents of Octets for debugging purposes.

   ----------
   -- Show --
   ----------

   procedure Show (Octets : Zone_Access)
   is
      subtype Hexa_Line is String (1 .. 50);
      subtype Ascii_Line is String (1 .. 17);

      Hex : constant String      := "0123456789ABCDEF";
      Nil_Hexa : constant Hexa_Line := (others => ' ');
      Nil_Ascii : constant Ascii_Line := (others => ' ');

      Hexa : Hexa_Line := Nil_Hexa;
      Ascii : Ascii_Line := Nil_Ascii;
      Index_Hexa : Natural := 1;
      Index_Ascii : Natural := 1;
   begin
      for J in Octets'Range loop
         Hexa (Index_Hexa) := ' ';
         Hexa (Index_Hexa + 1) := Hex (Natural (Octets (J) / 16) + 1);
         Hexa (Index_Hexa + 2) := Hex (Natural (Octets (J) mod 16) + 1);

         Index_Hexa := Index_Hexa + 3;

         if Octets (J) < 32 or else Octets (J) > 127 then
            Ascii (Index_Ascii) := '.';
         else
            Ascii (Index_Ascii) := Character'Val (Natural (Octets (J)));
         end if;
         Index_Ascii := Index_Ascii + 1;

         if Index_Hexa = 25 then
            Hexa (Index_Hexa) := ' ';
            Hexa (Index_Hexa + 1) := ' ';
            Index_Hexa := Index_Hexa + 2;
            Ascii (Index_Ascii) := ' ';
            Index_Ascii := Index_Ascii + 1;
         end if;

         if Index_Hexa > Hexa'Length then
            pragma Debug (O2 (Hexa & "   " & Ascii));
            Index_Hexa := 1;
            Hexa := Nil_Hexa;
            Index_Ascii := 1;
            Ascii := Nil_Ascii;
         end if;
      end loop;

      if Index_Hexa /= 1 then
         pragma Debug (O2 (Hexa & "   " & Ascii));
         null;
      end if;
   end Show;

   procedure Show (Buffer : in Buffer_Type) is
   begin
      pragma Debug (O2 ("Dumping "
                       & Endianness_Type'Image (Buffer.Endianness)
                       & " buffer, CDR position is "
                       & Stream_Element_Offset'Image
                       (Buffer.CDR_Position) & " (length is" &
                       Buffer.Length'Img & ")"));
      if Buffer.Length = 0 then
         return;
      end if;
      declare
         Dumped : Zone_Access := Iovec_Pools.Dump (Buffer.Contents);
      begin
         Show (Dumped);
         Free (Dumped);
      end;
   end Show;

   -------------------------------------------
   -- Implementation of package Iovec_Pools --
   -------------------------------------------

   package body Iovec_Pools is

      procedure Free is new Ada.Unchecked_Deallocation
        (Iovec_Array, Iovec_Array_Access);

      -----------------
      -- Grow_Shrink --
      -----------------

      procedure Grow_Shrink
        (Iovec_Pool   : access Iovec_Pool_Type;
         Size         :        Stream_Element_Offset;
         Data         :    out Opaque_Pointer)
      is

         -------------------------
         -- First_Address_After --
         -------------------------

         function First_Address_After
           (An_Iovec : Iovec)
            return Opaque_Pointer;
         pragma Inline (First_Address_After);
         --  Return the address of the storage
         --  element immediately following the
         --  last element of An_Iovec.

         function First_Address_After
           (An_Iovec : Iovec)
           return Opaque_Pointer is
         begin
            return An_Iovec.Iov_Base + An_Iovec.Iov_Len;
         end First_Address_After;

         -------------
         -- Do_Grow --
         -------------

         procedure Do_Grow
           (Last_Iovec : in out Iovec;
            Last_Chunk :        Chunk_Access);
         pragma Inline (Do_Grow);

         procedure Do_Grow
           (Last_Iovec : in out Iovec;
            Last_Chunk :        Chunk_Access) is
         begin
            if Last_Chunk /= null then
               declare
                  Chunk_Metadata : constant Chunk_Metadata_Access
                    := Metadata (Last_Chunk);
               begin
                  if False
                    or else (Size > 0
                             and then Chunk_Metadata.Last_Used + Size
                               <= Last_Chunk.Size)
                    or else (Size < 0
                             and then Chunk_Metadata.Last_Used + Size >= 0
                             and then Last_Iovec.Iov_Len
                               + Storage_Offset (Size) >= 0)
                  then
                     Chunk_Metadata.Last_Used
                       := Chunk_Metadata.Last_Used + Size;
                     Data := First_Address_After (Last_Iovec);
                     Last_Iovec.Iov_Len := Last_Iovec.Iov_Len
                       + Storage_Offset (Size);
                  else
                     --  Cannot grow last chunk: leave Data unchanged.

                     pragma Debug
                       (O ("Cannot satisfy growth request of size"
                           & Stream_Element_Offset'Image (Size)));
                     null;
                  end if;
               end;
            end if;
         end Do_Grow;

      begin
         Data := System.Null_Address;

         if Iovec_Pool.Last = 0 then
            --  Empty Iovec pool.

            return;
         end if;

         if Iovec_Pool.Last <= Iovec_Pool.Prealloc_Array'Last then
            Do_Grow (Iovec_Pool.Prealloc_Array (Iovec_Pool.Last),
                     Iovec_Pool.Last_Chunk);
         else
            Do_Grow (Iovec_Pool.Dynamic_Array (Iovec_Pool.Last),
                     Iovec_Pool.Last_Chunk);
         end if;
      end Grow_Shrink;

      ----------------------------------------
      -- Utility Subprograms (declarations) --
      ----------------------------------------

      function Is_Dynamic
        (Iovec_Pool : Iovec_Pool_Type)
        return Boolean;
      pragma Inline (Is_Dynamic);
      --  True iff Iovec pool uses dynamically allocated
      --  storage for the Iovecs and descriptors.

      function Iovecs_Address
        (Iovec_Pool : Iovec_Pool_Type)
        return System.Address;
      pragma Inline (Iovecs_Address);
      --  Returns the address of the first element of
      --  Iovec_Pool's Iovec_Array.

      procedure Extend
        (Iovec_Pool : in out Iovec_Pool_Type;
         Require    :        Natural;
         Allocate   :        Natural);
      --  Check the number of available Iovecs in Iovec_Pool and
      --  possibly extend it.  If Iovec_Pool's length is at least
      --  Require, then does nothing, else make it Allocate Iovecs
      --  long.

      procedure Dump (Iovecs : Iovec_Array; Into : Opaque_Pointer);
      --  Dump the content of Iovecs into Into.

      function Dump (Iovecs : Iovec_Array) return Zone_Access;
      --  Dump the data designated by an Iovec_Array
      --  into an array of octets.

      ----------------------------------
      -- Utility Subprograms (bodies) --
      ----------------------------------

      ----------------
      -- Is_Dynamic --
      ----------------

      function Is_Dynamic
        (Iovec_Pool : Iovec_Pool_Type)
        return Boolean is
      begin
         return Iovec_Pool.Dynamic_Array /= null;
      end Is_Dynamic;

      --------------------
      -- Iovecs_Address --
      --------------------

      function Iovecs_Address
        (Iovec_Pool : Iovec_Pool_Type)
        return System.Address is
      begin
         if Is_Dynamic (Iovec_Pool) then
            return Iovec_Pool.Dynamic_Array (1)'Address;
         else
            return Iovec_Pool.Prealloc_Array (1)'Address;
         end if;
      end Iovecs_Address;

      ------------
      -- Extend --
      ------------

      procedure Extend
        (Iovec_Pool : in out Iovec_Pool_Type;
         Require    :        Natural;
         Allocate   :        Natural) is
      begin
         pragma Assert (Allocate >= Require);

         if Require > Iovec_Pool.Length then
            declare
               New_Array : constant Iovec_Array_Access
                 := new Iovec_Array (1 .. Allocate);

               Old_Array_Address : constant System.Address
                 := Iovecs_Address (Iovec_Pool);
               Old_Array : Iovec_Array (1 .. Iovec_Pool.Length);
               for Old_Array'Address use Old_Array_Address;
               pragma Import (Ada, Old_Array);
            begin
               New_Array (1 .. Iovec_Pool.Last) := Old_Array (Old_Array'Range);

               if Is_Dynamic (Iovec_Pool) then
                  Free (Iovec_Pool.Dynamic_Array);
               end if;

               Iovec_Pool.Dynamic_Array := New_Array;
               Iovec_Pool.Length := New_Array'Length;
            end;
         end if;
      end Extend;

      ----------
      -- Dump --
      ----------

      procedure Dump
        (Iovecs : Iovec_Array;
         Into   : Opaque_Pointer)
      is
         Offset : Storage_Offset := 0;
      begin
         for J in Iovecs'Range loop
            declare
               L : constant Stream_Element_Offset
                 := Stream_Element_Offset (Iovecs (J).Iov_Len);

               S_Addr : constant System.Address
                 := Iovecs (J).Iov_Base;
               S : Stream_Element_Array (0 .. L - 1);
               for S'Address use S_Addr;
               pragma Import (Ada, S);

               D_Addr : constant System.Address
                 := Into + Offset;
               D : Stream_Element_Array (0 .. L - 1);
               for D'Address use D_Addr;
               pragma Import (Ada, D);

            begin
               D := S;
               Offset := Offset + Storage_Offset (L);
            end;
         end loop;
      end Dump;

      function Dump
        (Iovecs : Iovec_Array)
        return Zone_Access
      is
         Result : Zone_Access;
         Length : Stream_Element_Count := 0;
      begin
         for J in Iovecs'Range loop
            Length := Length + Stream_Element_Count (Iovecs (J).Iov_Len);
         end loop;

         Result := new Stream_Element_Array (1 .. Length);
         Dump (Iovecs, Opaque_Pointer'(Result (Result'First)'Address));

         return Result;
      end Dump;

      -------------------------------------------
      -- Visible subprograms (implementations) --
      -------------------------------------------

      ------------------
      -- Prepend_Pool --
      ------------------

      procedure Prepend_Pool
        (Prefix     :        Iovec_Pool_Type;
         Iovec_Pool : in out Iovec_Pool_Type)
      is
         New_Last : constant Natural := Iovec_Pool.Last + Prefix.Last;

      begin
         Extend (Iovec_Pool, New_Last, New_Last + 1);
         --  An Iovec pool that has been prefixed
         --  will likely not be appended to anymore.

         declare
            Prefix_Iovecs_Address : constant System.Address
              := Iovecs_Address (Prefix);
            Prefix_Iovecs : Iovec_Array (1 .. Prefix.Length);
            for Prefix_Iovecs'Address use Prefix_Iovecs_Address;
            pragma Import (Ada, Prefix_Iovecs);

            Pool_Iovecs_Address : constant System.Address
              := Iovecs_Address (Iovec_Pool);
            Pool_Iovecs : Iovec_Array (1 .. Iovec_Pool.Length);
            for Pool_Iovecs'Address use Pool_Iovecs_Address;
            pragma Import (Ada, Pool_Iovecs);

         begin
            --  Append new Iovec.

            Pool_Iovecs (1 .. New_Last)
              := Prefix_Iovecs (Prefix_Iovecs'Range)
              & Pool_Iovecs (1 .. Iovec_Pool.Last);
            Iovec_Pool.Last := New_Last;
         end;
      end Prepend_Pool;

      ------------
      -- Append --
      ------------

      procedure Append
        (Iovec_Pool : in out Iovec_Pool_Type;
         An_Iovec   :        Iovec;
         A_Chunk    :        Buffer_Chunk_Pools.Chunk_Access := null)
      is
         New_Last : constant Natural := Iovec_Pool.Last + 1;
      begin
         Extend (Iovec_Pool, New_Last, 2 * Iovec_Pool.Length);

         --  Append new Iovec.

         Iovec_Pool.Last := New_Last;
         Iovec_Pool.Last_Chunk := A_Chunk;

         declare
            Pool_Iovecs_Address : constant System.Address
              := Iovecs_Address (Iovec_Pool);
            Pool_Iovecs : Iovec_Array (1 .. Iovec_Pool.Length);
            for Pool_Iovecs'Address use Pool_Iovecs_Address;
            pragma Import (Ada, Pool_Iovecs);
         begin
            Pool_Iovecs (Iovec_Pool.Last) := An_Iovec;
         end;
      end Append;

      ------------------
      -- Extract_Data --
      ------------------

      procedure Extract_Data
        (Iovec_Pool :     Iovec_Pool_Type;
         Data       : out Opaque_Pointer;
         Offset     :     Stream_Element_Offset;
         Size       :     Stream_Element_Count)
      is
         Vecs_Address : constant System.Address
           := Iovecs_Address (Iovec_Pool);
         Vecs : Iovec_Array (1 .. Iovec_Pool.Last);
         for Vecs'Address use Vecs_Address;
         pragma Import (Ada, Vecs);

         Offset_Remainder : Storage_Offset := Storage_Offset (Offset);
         Index            : Natural := Vecs'First;
      begin
         while Offset_Remainder >= Vecs (Index).Iov_Len loop
            Offset_Remainder := Offset_Remainder - Vecs (Index).Iov_Len;
            Index := Index + 1;
         end loop;

         pragma Assert (Offset_Remainder + Storage_Offset (Size)
           <= Vecs (Index).Iov_Len);

         Data := Vecs (Index).Iov_Base + Offset_Remainder;

      exception
         when others =>
            raise Read_Error;
      end Extract_Data;

      ----------
      -- Peek --
      ----------

      function Peek
        (Iovec_Pool : Iovec_Pool_Type;
         Offset     : Stream_Element_Offset)
        return Stream_Element
      is
         Vecs_Address : constant System.Address
           := Iovecs_Address (Iovec_Pool);
         Iovecs : Iovec_Array (1 .. Iovec_Pool.Last);
         for Iovecs'Address use Vecs_Address;
         pragma Import (Ada, Iovecs);
         Current_Offset : Stream_Element_Offset := 0;
      begin
         for J in Iovecs'Range loop
            declare
               L : constant Stream_Element_Offset
                 := Stream_Element_Offset (Iovecs (J).Iov_Len);
            begin
               if Offset < L + Current_Offset then
                  declare
                     S_Addr : constant System.Address
                       := Iovecs (J).Iov_Base;
                     S : Stream_Element_Array (0 .. L - 1);
                     for S'Address use S_Addr;
                     pragma Import (Ada, S);
                  begin
                     return S (Offset - Current_Offset);
                  end;
               end if;
               Current_Offset := Current_Offset + L;
            end;
         end loop;
         raise Read_Error;
      end Peek;

      -------------
      -- Release --
      -------------

      procedure Release
        (Iovec_Pool : in out Iovec_Pool_Type) is
      begin
         if Is_Dynamic (Iovec_Pool) then
            Free (Iovec_Pool.Dynamic_Array);
         end if;

         Iovec_Pool.Last := 0;
         Iovec_Pool.Length := Iovec_Pool.Prealloc_Array'Length;
      end Release;

      package SE_Access_Address_Conversions is
        new System.Address_To_Access_Conversions
        (Ada.Streams.Stream_Element);

      ---------------------
      -- Write_To_Socket --
      ---------------------

      procedure Write_To_Socket
        (S          :        PolyORB.Sockets.Socket_Type;
         Iovec_Pool : access Iovec_Pool_Type;
         Length     :        Stream_Element_Count;
         To         :        PolyORB.Sockets.Sock_Addr_Type)
      is
         use PolyORB.Sockets;

         Vecs_Address : constant System.Address
           := Iovecs_Address (Iovec_Pool.all);

         Vecs : Iovec_Array (1 .. Iovec_Pool.Last);
         for Vecs'Address use Vecs_Address;
         pragma Import (Ada, Vecs);

         --  WAG:3.16

         --  The code is organised around GNAT.Sockets' view of iovecs
         --  as Vector_Type below. These declarations are not present
         --  in GNAT.Sockets as of GNAT 3.16 so for now we declare them
         --  here. When 3.17 is released these declarations can be
         --  removed, and Send_Vector can be used below instead of
         --  Send_Socket.

         type Stream_Element_Access is access all Ada.Streams.Stream_Element;

         type Vector_Element is record
            Base   : Stream_Element_Access;
            Length : Ada.Streams.Stream_Element_Count;
         end record;

         type Vector_Type is array (Integer range <>) of Vector_Element;

         --  WAG:3.16

         S_Vecs : Vector_Type (Vecs'Range);
         for S_Vecs'Address use Vecs_Address;
         pragma Import (Ada, S_Vecs);

         Index : Natural := Vecs'First;

         Count : Stream_Element_Count;
         Remainder : Stream_Element_Count := Length;
         --  Number of Stream_Elements yet to be written.

         use SE_Access_Address_Conversions;

      begin
         while Remainder > 0 loop

            --  WAG:3.16
            --  For now we do scatter-gather ourselves for lack of
            --  a writev operation in GNAT.Sockets. Subsequent
            --  releases of GNAT will have Send_Vector: the whole
            --  block below can then be replaced with:

            --  Send_Vector (S, S_Vecs (Index .. Vecs'Last), Count);

            declare --  WAG:3.16
               Z_Addr : constant Opaque_Pointer := Vecs (Index).Iov_Base;
               Z : Stream_Element_Array
                 (0 .. Stream_Element_Offset (Vecs (Index).Iov_Len - 1));
               for Z'Address use Z_Addr;
               pragma Import (Ada, Z);
               Last : Stream_Element_Offset;
            begin

               Send_Socket (S, Z, Last, To);
               --  May raise Socket_Error.
               Count := Stream_Element_Count (Last) + 1;
            end;    --  WAG:3.16

            while Index <= S_Vecs'Last
              and then Count >= S_Vecs (Index).Length
            loop
               Remainder := Remainder - S_Vecs (Index).Length;
               Count := Count - S_Vecs (Index).Length;
               Index := Index + 1;
            end loop;

            if Count > 0 then
               S_Vecs (Index).Base   := Stream_Element_Access
                 (To_Pointer
                  (S_Vecs (Index).Base.all'Address
                   + Storage_Offset (Count)));
               S_Vecs (Index).Length := S_Vecs (Index).Length - Count;
            end if;

         end loop;
      end Write_To_Socket;

      ----------
      -- Dump --
      ----------

      procedure Dump
        (Iovec_Pool : Iovec_Pool_Type;
         Into       : Opaque_Pointer)
      is
         Vecs_Address : constant System.Address
           := Iovecs_Address (Iovec_Pool);
         Vecs : Iovec_Array (1 .. Iovec_Pool.Last);
         for Vecs'Address use Vecs_Address;
         pragma Import (Ada, Vecs);
      begin
         Dump (Vecs, Into);
      end Dump;

      function Dump
        (Iovec_Pool : in Iovec_Pool_Type)
        return Zone_Access is
      begin
         if Is_Dynamic (Iovec_Pool) then
            return Dump (Iovec_Pool.Dynamic_Array
                         (1 .. Iovec_Pool.Last));
         else
            return Dump (Iovec_Pool.Prealloc_Array
                         (1 .. Iovec_Pool.Last));
         end if;
      end Dump;

   end Iovec_Pools;

end PolyORB.Buffers;