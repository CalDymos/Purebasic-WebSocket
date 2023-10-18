;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* Module     : BitConverter - Converts base data types to an array of bytes, and an array of bytes to base data types.
;* Created    : 13.10.23
;* Author     : CalDymos
;* Contacts   : {Contact}
;* Copyright  : Byte Ranger Software
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

DeclareModule BitConverter
  ;- --------------------------------------------------------------------------
  ;-   Declaration Public Methods
  ;- --------------------------------------------------------------------------
    
  Declare.s ToString(Array value.a(1), startIndex=0, length=0) 
EndDeclareModule

Module BitConverter
  ;- --------------------------------------------------------------------------
  ;-   Public Methods
  ;- --------------------------------------------------------------------------  
   
  ;<comment>
  ;  <summary>Converts the numeric value of each element of a specified Array of bytes To its equivalent hexadecimal string representation.</summary>
  ;  <param><b>value</b>: An Array of bytes.</param>
  ;  <param><i>Optional</i> <b>startIndex</b>: The starting position within value.</param>
  ;  <param><i>Optional</i> <b>length</b>: The number of array elements in value to convert.</param>
  ;  <return>String of hexadecimal pairs, each value separated by hyphen. For example, "7F-2C-4A-00".</return>
  ;  <example>Str$ = BitConverter::ToString(value())</example>
  ;</comment>
  Procedure.s ToString(Array value.a(1), startIndex=0, length=0) 
    Protected hexchar.s
    Protected StringToHex.s
    Protected x
    Protected flag
    
    If ArraySize(value()) <> -1
      If startIndex > ArraySize(value()) Or startIndex < 0
        startIndex = 0 
      EndIf
      
      If (startIndex + length - 1) > ArraySize(value()) Or length <= 0
        length = ArraySize(value())
      Else
        length + startIndex - 1
      EndIf
      
      For x = startIndex To length
        If flag : StringToHex + "-" : EndIf
        hexchar = RSet(Hex(Value(x),#PB_Ascii),2, "0")
        StringToHex + hexchar
        flag = #True
      Next x 
      ProcedureReturn StringToHex
    EndIf
  EndProcedure
EndModule
