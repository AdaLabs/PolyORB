--  Buffer management

--  $Id: //droopi/main/src/droopi-buffers.ads#2 $

with System;
--  For bit-order information.

with Ada.Streams;   use Ada.Streams;

with Droopi.Opaque; use Droopi.Opaque;
--  General opaque data storage types.

with Droopi.Opaque.Chunk_Pools;
--  Chunked memory storage.

package Droopi.Buffers is

   pragma Elaborate_Body;

   -------------------------
   -- General definitions --
   -------------------------

   type Endianness_Type is (Little_Endian, Big_Endian);

   Host_Order : constant Endianness_Type;
   --  The byte order of this host.

   type Buffer_Type is limited private;

   type Buffer_Access is access Buffer_Type;
   --  A pointer to a dynamically allocated buffer.

   ------------------------
   -- General operations --
   ------------------------

   function Length (Buffer : access Buffer_Type) return Stream_Element_Count;
   pragma Inline (Length);
   --  Return the length of Buffer.

   function Endianness (Buffer : Buffer_Type) return Endianness_Type;
   --  Return the endianness of Buffer.

   procedure Release (Buffer : in out Buffer_Type);
   --  Signal that a buffer will not be used anymore.
   --  The associated storage will be deallocated.

   procedure Initialize_Buffer
     (Buffer     : access Buffer_Type;
      Size       : Stream_Element_Count;
      Data       : Opaque_Pointer;
      Endianness : Endianness_Type;
      Initial_CDR_Position : Stream_Element_Offset);
   --  Sets the contents of Buffer using data
   --  passed as a pointer Data and a size Size.
   --  Buffer must be a fresh, empty buffer.
   --  The first element of Data corresponds to
   --  the indicated Initial_CDR_Position.
   --  The byte-order of the data is Endianness.
   --  The lifespan of the data designated by Data
   --  must be no less than the lifespan of the
   --  resulting buffer.

   procedure Prepend
     (Prefix : in Buffer_Type;
      Buffer : access Buffer_Type);
   --  Prepend the contents of Prefix at the beginning of
   --  Buffer. The CDR position of the last element in Prefix
   --  must be just before the CDR position of the first
   --  element in Buffer. The endiannesses of both buffers
   --  must match.
   --  The lifespan of Prefix must be no less than the
   --  lifespan of Buffer.

   function Copy
     (Buffer : access Buffer_Type)
     return Buffer_Access;
   --  Make a copy of Buffer. The copy's data is allocated
   --  only from its internal storage pool. There is no
   --  constraint on the lifespan of the resulting buffer.
   --  It is the caller's responsibility to call Release
   --  on the returned Buffer_Access to free the associated
   --  resources. The initial and current CDR positions of the
   --  new buffers are set to the initial CDR position of the
   --  source.

   procedure Release
     (A_Buffer : in out Buffer_Access);
   --  Release the storage associated with the buffer
   --  designated by A_Buffer, and the dynamically
   --  allocated data structure used to manage it.
   --  On return, A_Buffer is set to null.

   ----------------------------------
   -- The Message view of a buffer --
   ----------------------------------

   --  A buffer is an octet stream that can be
   --  exchanged on a GIOP stream.

   --  procedure Send
   --  procedure Receive

   ----------------------------------------
   -- The Encapsulation view of a buffer --
   ----------------------------------------

   --  A buffer is a sequence of bytes that can be
   --  turned into an opaque Encapsulation object
   --  and back.

   subtype Encapsulation is Stream_Element_Array;

   function Encapsulate
     (Buffer   : access Buffer_Type)
     return Encapsulation;
   --  Create an Octet_Array corresponding to Buffer
   --  as an encapsulation.

   procedure Decapsulate
     (Octets : access Encapsulation;
      Buffer : access Buffer_Type);
   --  Initialize a buffer with an Octet_Array
   --  corresponding to an Encapsulation.
   --  Buffer must be a fresh, empty buffer.
   --  The lifespan of the actual Octets array
   --  shall be no less than that of Buffer.

   ------------------------------
   -- The CDR view of a buffer --
   ------------------------------

   --  A buffer has a current position index called the current
   --  CDR position. Marshalling data into the buffer and
   --  unmarshalling data from the buffer first advances the
   --  current buffer position according to the alignment
   --  constraints for the data type, then further advance it
   --  by the size of the data effectively marshalled or
   --  unmarshalled.

   --  For any type T, the following subprograms shall
   --  be generated:

   --     procedure Marshall_By_Copy
   --       (Buffer    : access Buffer_Type;
   --        Data      : in T);
   --     --  Marshall data of type T.
   --
   --     function Unmarshall_By_Copy
   --       (Buffer    : access Buffer_Type)
   --       return T;
   --     --  Unmarshall data of type T.

   --     procedure Marshall_By_Reference
   --       (Buffer    : access Buffer_Type;
   --        Data      : access T);
   --     --  Marshall data of type T by reference.
   --     --  The lifespan of Data shall be no less
   --     --  than the lifespan of Buffer.
   --
   --     function Unmarshall_By_Reference
   --       (Buffer    : access Buffer_Type)
   --       return T_Access;
   --     --  Unmarshall data of type T by reference.
   --     --  The returned pointer is valid until
   --     --  Buffer is released.

   --  The marshall-by-copy routines shall allocate
   --  memory from the buffer's chunk pool, store the
   --  data in CDR format with Buffer's endianness in
   --  that memory chunk, and insert the chunk at Buffer's
   --  current CDR position, with proper alignment.

   --  The marshall-by-reference routines shall be called
   --  only when the native representation of type T is
   --  fully compatible with the CDR representation for Buffer.
   --  It shall insert a reference to the object's data at
   --  the current CDR position.

   procedure Set_Initial_Position
     (Buffer   : access Buffer_Type;
      Position : Stream_Element_Offset);
   --  Sets the initial and current CDR positions
   --  of Buffer to Position. No data must have
   --  been inserted into Buffer yet.

   procedure Align
     (Buffer    : access Buffer_Type;
      Alignment : Alignment_Type);
   --  Aligns Buffer on specified Alignment.
   --  This subprogram must be called before data is
   --  inserted into or retrieved from Buffer.
   --  The effect of this operation is to advance the
   --  current CDR position to a multiple of Alignment.

   --  Inserting data into a buffer

   procedure Insert_Raw_Data
     (Buffer    : access Buffer_Type;
      Size      : Stream_Element_Count;
      Data      : Opaque_Pointer);
   --  Inserts data into Buffer by reference at the current
   --  CDR position. This procedure is used to implement
   --  marshalling by reference.

   procedure Allocate_And_Insert_Cooked_Data
     (Buffer    : access Buffer_Type;
      Size      : Stream_Element_Count;
      Data      : out Opaque_Pointer);
   --  Allocates Size bytes within Buffer's memory
   --  pool, and inserts this chunk of memory into
   --  Buffer at the current CDR position.
   --  A pointer to the allocated space is returned,
   --  so the caller can copy data into it.
   --  This procedure is used to implement marshalling
   --  by copy.

   --  Retrieving data from a buffer

   procedure Extract_Data
     (Buffer : access Buffer_Type;
      Data   : out Opaque_Pointer;
      Size   : Stream_Element_Count);
   --  Retrieve Size elements from Buffer.
   --  On return, Data contains an access to the retrieved
   --  Data, and the CDR current position is advanced by Size.


   function CDR_Position (Buffer : access Buffer_Type)
     return Stream_Element_Offset;
   --  return the current CDR position of the buffer
   --  in the marshalling stream.

   -------------------------
   -- Utility subprograms --
   -------------------------

   procedure Show (Buffer : in Buffer_Type);
   --  Display the contents of Buffer for debugging
   --  purpose.

private

   ------------------------------------------
   -- Determination of the host byte order --
   ------------------------------------------

   use System;

   Default_Bit_Order_To_Endianness :
     constant array (Bit_Order) of Endianness_Type
     := (High_Order_First => Big_Endian,
         Low_Order_First  => Little_Endian);

   Host_Order : constant Endianness_Type :=
     Default_Bit_Order_To_Endianness (Default_Bit_Order);

   --------------
   -- A Buffer --
   --------------

   type Iovec is record
      Iov_Base : Opaque_Pointer;
      Iov_Len  : Stream_Element_Count;
   end record;
   --  This is modeled after the POSIX iovec, but is not equivalent
   --  (because we cannot depend on being able to manipulate System.Address).

   type Buffer_Chunk_Metadata is record
      --  An Iovec pool manipulates chunks of memory allocated
      --  from a Chunk_Pool. This records holds the metadata
      --  associated by the Iovec pool and the Buffer (below)
      --  with each allocated chunk.

      Last_Used : Stream_Element_Offset := 0;
      --  The index within the chunk of the last
      --  used element.
   end record;

   Null_Buffer_Chunk_Metadata : constant Buffer_Chunk_Metadata
     := (Last_Used => 0);

   package Buffer_Chunk_Pools is
      new Chunk_Pools
     (Chunk_Metadata => Buffer_Chunk_Metadata,
      Null_Metadata  => Null_Buffer_Chunk_Metadata);

   subtype Chunk_Metadata_Access is
     Buffer_Chunk_Pools.Metadata_Access;

   package Iovec_Pools is

      --  An Iovec_Pool stores a sequence of Iovecs with
      --  corresponding descriptors. An array of pre-allocated
      --  storage is used if the pool contains no more than
      --  Prealloc_Size items, else a dynamically-allocated
      --  array is used.

      Write_Error : exception;
      Read_Error  : exception;

      type Iovec_Pool_Type is private;

      procedure Grow
        (Iovec_Pool   : access Iovec_Pool_Type;
         Size         : Stream_Element_Count;
         Data         : out Opaque_Pointer);
      --  Augment the length of the last Iovec in
      --  Iovec_Pool by Size elements, if possible.
      --  On success, a pointer to the reserved
      --  space is returned in Data. On failure, a null
      --  pointer is returned.

      procedure Prepend_Pool
        (Prefix     : Iovec_Pool_Type;
         Iovec_Pool : in out Iovec_Pool_Type);
      --  Prepends the contents of Prefix in Iovec_Pool.
      --  Prefix is unchanged.

      procedure Append
        (Iovec_Pool : in out Iovec_Pool_Type;
         An_Iovec   : Iovec;
         A_Chunk    : Buffer_Chunk_Pools.Chunk_Access := null);
      --  Append An_Iovec at the end of Iovec_Pool.
      --  If A_Chunk is not null, then the Iovec points to
      --  data within the designated chunk, and can be
      --  extended towards the end of the chunk if necessary.

      procedure Extract_Data
        (Iovec_Pool : Iovec_Pool_Type;
         Data       : out Opaque_Pointer;
         Offset     : Stream_Element_Offset;
         Size       : Stream_Element_Count);
      --  Retrieve exactly Size octets of data from
      --  Iovec_Pool starting at Offset.
      --  The data must be stored contiguously.
      --  If there are not Size octest of data
      --  contiguously stored in Iovec_Pool at Offset,
      --  then exception Read_Error is raised.

      procedure Release
        (Iovec_Pool : in out Iovec_Pool_Type);
      --  Signals that Iovec_Pool will not be used anymore.
      --  The associated Iovec array storage is returned to
      --  the system.

      ---------------------------------------
      -- Low-level interfaces to the octet --
      -- stream of an Iovec_Pool.          --
      ---------------------------------------

      procedure Dump
        (Iovec_Pool : Iovec_Pool_Type;
         Into       : Opaque_Pointer);
      --  Dump the content of an Iovec_Pool into Into.

      function Dump
        (Iovec_Pool : Iovec_Pool_Type)
        return Opaque_Pointer;
      --  Dump the contents of Iovec_Pool into an array of octets. The result
      --  must be deallocated when not used anymore.

      --  procedure Write_To_FD
      --    (FD : Interfaces.C.int;
      --     Iovec_Pool : access Iovec_Pool_Type);
      --  Write the contents of Iovec_Pool to
      --  the system file descriptor Fd. On
      --  error, Write_Error is raised.

   private

      type Iovec_Array is array (Positive range <>) of aliased Iovec;
      type Iovec_Array_Access is access all Iovec_Array;

      Prealloc_Size : constant := 16;
      --  The number of slots in the preallocated iovec array.

      type Iovec_Pool_Type is record

         Prealloc_Array : aliased Iovec_Array (1 .. Prealloc_Size);
         Dynamic_Array  : Iovec_Array_Access := null;
         --  The pre-allocated and dynamically allocated
         --  Iovec_Arrays.

         Length : Natural := Prealloc_Size;
         --  The length of the arrays currently in use.

         Last : Natural := 0;
         --  The number of the last allocated Iovec in the pool.
         --  If Last <= Prealloc_Array'Last then the pool's
         --  Iovecs are stored in Prealloc_Array, else they
         --  are stored in Dynamic_Array.

         Last_Chunk : Buffer_Chunk_Pools.Chunk_Access := null;
         --  If the last Iovec is pointing into user data,
         --  then we cannot assume that addresses beyond the
         --  end of the Iovec's buffer is valid: this
         --  Iovec cannot be grown. In this case,
         --  Last_Chunk is set to null.

         --  If the last Iovec is pointing into a memory
         --  chunk from a Buffer's chunk pool, then we can
         --  grow the Iovec if its last element is also the
         --  last allocated element of the chunk. In this
         --  second case, Last_Chunk is set to an access
         --  that designates the storage chunk.
      end record;

   end Iovec_Pools;

   type Buffer_Type is record
      Endianness : Endianness_Type := Host_Order;
      --  The byte order of the data stored in the
      --  buffer.

      CDR_Position : Stream_Element_Offset := 0;
      --  The current position within the stream for
      --  marshalling and unmarshalling.

      Initial_CDR_Position : Stream_Element_Offset := 0;
      --  The position within the stream of the first
      --  element of Buffer.

      Contents     : aliased Iovec_Pools.Iovec_Pool_Type;
      --  The marshalled data as a pool of Iovecs.

      Storage      : aliased Buffer_Chunk_Pools.Pool_Type;
      --  A set of memory chunks used to store data
      --  marshalled by copy.

      Length       : Stream_Element_Count := 0;
      --  Length of stored data.
   end record;

end Droopi.Buffers;
