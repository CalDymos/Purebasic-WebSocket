;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* Module     : TextEncoding.pbi - Represents methods for encoding strings
;* Created    : 14.03.2021
;* Author     : Cal Dymos
;* Contacts   : {Contact}
;* Copyright  : Byte Ranger Software
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

DeclareModule TextEncoding
   
  ;- --------------------------------------------------------------------------
  ;-   Declaration Public Methods
  ;- --------------------------------------------------------------------------
    
  Declare.s ToAscii (*UnicodeStr, srcType.l = #PB_Unicode)
  Declare.s ToUnicode (*AsciiStr)
  Declare.s ASCIIArray_ToString(Array asciiArray.a(1), srcType.l = #PB_Ascii)
  Declare String_ToASCIIArray(srcString.s, Array DstAsciiArray.a(1), DstType.l = #PB_Unicode)
  
EndDeclareModule

Module TextEncoding
  
  ;- --------------------------------------------------------------------------
  ;-   Public Methods
  ;- --------------------------------------------------------------------------  
  
  ;<comment>
  ;  <summary>convert unicode / UTF8 String to AScii string, using PB String data type</summary>
  ;  <param><b>*UnicodeStr</b>: a pointer to PB unicode string, or any memory containing unicode string</param>
  ;  <param><i>Optional </i><b>srcType</b>: Format of the input string (UTF8 or Unicode)</param>
  ;  <return>returns a Unicode string with ascii bytes order inside, equal to array of 1-byte chars</return>
  ;  <example>ascii.s = TextEncoding::ToAscii(@Text)</example>
  ;</comment>
  Procedure.s ToAscii (*UnicodeStr, srcType.l = #PB_Unicode)
    Protected UnicodeStr.s = PeekS(*UnicodeStr, #PB_Default, srcType)
    Protected AsciiStrLen = 1 + Len(UnicodeStr) / SizeOf(Character)
    Protected AsciiStr.s = Space(AsciiStrLen)
    PokeS(@AsciiStr, UnicodeStr, #PB_Default, #PB_Ascii)
    ProcedureReturn AsciiStr
  EndProcedure
  
  ;<comment>
  ;  <summary>convert unicode / UTF8 String to AScii string, using PB String data type</summary>
  ;  <param><b>*AsciiStr</b>: pointer to a string returned by 'ToAscii()', or any ASCII string memory buffer</param>
  ;  <return>returns a Unicode string</return>
  ;  <example>Text.s = TextEncoding::ToUnicode(*asciiStr)</example>
  ;</comment>
  Procedure.s ToUnicode (*AsciiStr)
    ProcedureReturn PeekS(*AsciiStr, #PB_Default, #PB_Ascii)
  EndProcedure
  
  ;<comment>
  ;  <summary>Get a Unicode String from an ASCII Array</summary>
  ;  <param><b>asciiArray</b>: </param>
  ;  <param><i>Optional </i><b>srcType</b>: Format of the input array</param>
  ;  <return>returns an Unicode String</return>
  ;  <example>Text.s = TextEncoding::ASCIIArray_ToString(ascii())</example>
  ;</comment>
  Procedure.s ASCIIArray_ToString(Array asciiArray.a(1), srcType.l = #PB_Ascii)
    
    If ArraySize(asciiArray()) <> -1
      ProcedureReturn ToUnicode(@asciiArray(), srcType)  
    EndIf
    
  EndProcedure

  ;<comment>
  ;  <summary>Get an ASCII Array from a String</summary>
  ;  <param><b>srcString</b>: </param>
  ;  <param><b>DstAsciiArray</b>: contains the destination array</param>
  ;  <param><i>Optional </i><b>DstType</b>: Format of the destination String encoding</param>
  ;  <return>no Return Value</return>
  ;  <example>TextEncoding::String_ToASCIIArray(Text, ascii())</example>
  ;</comment>
  Procedure String_ToASCIIArray(srcString.s, Array DstAsciiArray.a(1), DstType.l = #PB_Unicode)
    Protected *Src
    Protected ArraySize.l
    Protected Size.l
    
    If srcString
      FreeArray(DstAsciiArray())
      If DstType = #PB_Unicode Or DstType = #PB_Unicode | #PB_String_NoZero
        size = Len(srcString) * SizeOf(Unicode)
        *src = @srcString
      ElseIf DstType = #PB_Ascii Or DstType = #PB_Ascii | #PB_String_NoZero
        size = Len(srcString)
        *src = Ascii(srcString)
      ElseIf DstType = #PB_UTF8 Or DstType = #PB_UTF8 | #PB_String_NoZero
        size = StringByteLength(srcString, #PB_UTF8)
        *src = UTF8(srcString)
      EndIf
      
      If DstType & #PB_String_NoZero
        ArraySize = size - 1
      Else
        ArraySize = size
      EndIf
      Dim DstAsciiArray(ArraySize)
      CopyMemory(*src, @DstAsciiArray(), size)
      
      If (DstType = #PB_Ascii Or DstType = #PB_Ascii | #PB_String_NoZero) Or (DstType = #PB_UTF8 Or DstType = #PB_UTF8 | #PB_String_NoZero)
        FreeMemory(*src)
      EndIf
    EndIf
  EndProcedure
  
EndModule