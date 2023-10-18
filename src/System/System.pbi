;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* Module     : System.pbi - Contains basic methods, structures and macros that simplify programming
;* Created    : 10.09.2020
;* Author     : Cal Dymos
;* Contacts   : {Contact}
;* Copyright  : Byte Ranger Software
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

DeclareModule System
  
  ;- --------------------------------------------------------------------------
  ;-   Public Structure
  ;- --------------------------------------------------------------------------  
  
  ; Structure for a ascii array
  Structure aASCII
    a.a[0]
  EndStructure
  
  ; Structure for a char array
  Structure aCHAR
    c.c[0]
  EndStructure
  
  ; Structure for a byte array
  Structure aBYTE
    b.b[0]
  EndStructure
    
  ;- --------------------------------------------------------------------------
  ;-   Declaration Public Methods
  ;- --------------------------------------------------------------------------
  
  Declare ASCIIArray_AddRange(Array DstArray.a(1), Array SrcArray.a(1))
  Declare.q ToUINT(source.l)
  Declare.a IsBitSet ( Value.a, Bit.a )
  Declare.a GetBit ( Value.a, Bit.a )
  Declare.a SetBit ( *Value.Ascii, Bit.a )
  Declare.a ClrBit ( *Value.Ascii, Bit.a )
  Declare.a TglBit ( *Value.Ascii, Bit.a )
  Declare.i AllocateString(Text.s)
  Declare.s FreeString(*Mem.String)
EndDeclareModule

Module System
  
  ;- --------------------------------------------------------------------------
  ;-   Public Methods
  ;- --------------------------------------------------------------------------  
  
  ;<comment>
  ;  <summary>Checks if bit is set</summary>
  ;  <param><b>Value</b>: Byte whose bits are to be checked</param>
  ;  <param><b>Bit</b>: Bit that should be checked (1 To 8).</param>
  ;  <return>Returns True if the bit is set, otherwise False</return>
  ;  <example>result = System::IsBitSet(Byte, 1)</example>
  ;</comment>
  Procedure.a IsBitSet (Value.a, Bit.a)
    ProcedureReturn Bool((Value & ( 1 << (Bit - 1) ) ) <> 0)
  EndProcedure
  
  ;<comment>
  ;  <summary>Determine decimal value of the set bit</summary>
  ;  <param><b>Value</b>: Byte in which the decimal value of the bit is to be determined.</param>
  ;  <param><b>Bit</b>: The bit to be determined (1 To 8).</param>
  ;  <return>Returns the decimal value of the set bit, otherwise zero</return>
  ;  <example>result = System::GetBit(Byte, 1)</example>
  ;</comment>
  Procedure.a GetBit (Value.a, Bit.a)
    ProcedureReturn  Value & ( 1 << (Bit - 1) ) 
  EndProcedure
  
  ;<comment>
  ;  <summary>Sets a bit in a byte</summary>
  ;  <param><b>*Value</b>: Pointer to the byte in which the bit is to be set</param>
  ;  <param><b>Bit</b>: Bit that should be set (1 To 8).</param>
  ;  <return>Returns the new value of the Byte</return>
  ;  <example>result = System::SetBit(@Byte, 3)</example>
  ;</comment>
  Procedure.a SetBit (*Value.Ascii, Bit.a)
    *Value\a = *Value\a | ( 1 << (Bit - 1) ) 
    ProcedureReturn *Value\a
  EndProcedure
  
  ;<comment>
  ;  <summary>Clears a set bit in a byte</summary>
  ;  <param><b>*Value</b>: Pointer to the byte whose bit are to be cleared</param>
  ;  <param><b>Bit</b>: Bit that should be cleared (1 To 8).</param>
  ;  <return>Returns the new value of the Byte</return>
  ;  <example>result = System::ClrBit(@Byte, 1)</example>
  ;</comment>
  Procedure.a ClrBit (*Value.Ascii, Bit.a)
    *Value\a = *Value\a &~ ( 1 << (Bit - 1) ) 
    ProcedureReturn *Value\a
  EndProcedure
  
  ;<comment>
  ;  <summary>Toggles a Bit in a byte</summary>
  ;  <param><b>*Value</b>: Pointer to the byte whose bit are to be toggled</param>
  ;  <param><b>Bit</b>: Bit that should be toggled(1 To 8).</param>
  ;  <return>Returns the new value of the Byte</return>
  ;  <example>result = System::TglBit(@Byte, 1)</example>
  ;</comment>
  Procedure.a TglBit (*Value.Ascii, Bit.a)
    *Value\a =  *Value\a ! ( 1 << (Bit - 1) ) 
    ProcedureReturn *Value\a
  EndProcedure
   
  ;<comment>
  ;  <summary>Adds the elements of the specified Ascii array to the end of the destination array.</summary>
  ;  <param><b>DstArray</b>: destination array.</param>
  ;  <param><b>SrcArray</b>: source array.</param>
  ;  <return>no return value</return>
  ;  <example>System::ASCIIArray_AddRange(buffer.a(), byteArray.a())</example>
  ;</comment>
  Procedure ASCIIArray_AddRange(Array DstArray.a(1), Array SrcArray.a(1))
    Define DstSize.l = ArraySize(DstArray()) + 1
    Define SrcSize.l = ArraySize(SrcArray()) + 1
    If SrcSize <> 0
      If DstSize = 0
        Dim DstArray(DstSize + SrcSize - 1) 
      Else
        ReDim DstArray(DstSize + SrcSize - 1) 
      EndIf
      CopyMemory(@SrcArray(), @DstArray() + DstSize, SrcSize)
    EndIf
  EndProcedure
  
  ;<comment>
  ;  <summary>Converts a specified value to a 32-bit unsigned integer.</summary>
  ;  <param><b>Int32</b>: Long value (Int32) to be converted </param>
  ;  <return>returns the unsigned Integer (32bit) value as a quad (64bit)</return>
  ;  <example>result.q = System::ToUINT(-214748304)</example>
  ;</comment>
  Procedure.q ToUINT(Int32.l)
    If PeekL(@source) < 0
      ; Reads 4 bytes from the memory address,
      ; (Uint minimum = 0, Uint maximum = 4294967295).
      ProcedureReturn PeekL(@source) + $100000000
    Else
      ProcedureReturn PeekL(@source)
    EndIf
  EndProcedure
  
  ;<comment>
  ;  <summary>copies a string into a structured memory area of type string</summary>
  ;  <param><b>Text</b>: Source string</param>
  ;  <return>Returns a pointer to the structured memory area</return>
  ;  <example>*result.STRING = System::AllocateString("This is a Text")</example>
  ;</comment>
  Procedure AllocateString(Text.s)
    Protected *mem.String
    *mem = AllocateStructure(String)
    If *mem
      *mem\s = Text
    EndIf
    ProcedureReturn *mem
  EndProcedure
  
  ;<comment>
  ;  <summary>Frees the memory that was allocated by the 'AllocateString' method.</summary>
  ;  <param><b>*Mem</b>: Pointer to the memory area containing the string structure</param>
  ;  <return>Returns the string</return>
  ;  <example>result.s = System::FreeString(*str)</example>
  ;</comment>
  Procedure.s FreeString(*Mem.String)
    Protected Text.s
    If *Mem
      text = *Mem\s
      FreeStructure(*Mem)
    EndIf
    ProcedureReturn text
  EndProcedure
  
EndModule