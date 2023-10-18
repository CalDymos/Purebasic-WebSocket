;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* Module     : Guid.pi - Methods to handle GUID (Globally Unique Identifier) / UUID (Universally Unique Identifier)
;* Created    : {Date}
;* Author     : {User}
;* Contacts   : {Contact}
;* Copyright  : {CopyRight}
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

DeclareModule Guid
  ;- --------------------------------------------------------------------------
  ;-   Public Structure
  ;- --------------------------------------------------------------------------  
  
  ; Structure for a Guid / UUID
  Structure UUID
    Time_low.l
    Time_mid.w
    Time_hi_and_Version.w
    Clock_Seq_hi_and_res.a
    Clock_Seq_low.a
    Node.a[6]
  EndStructure
  
  ;- --------------------------------------------------------------------------
  ;-   Declaration Public Methods
  ;- --------------------------------------------------------------------------
  
  Declare.s ToString(*Guid.UUID, ToUpper=#False)
  Declare.i New(Array DstArray.a(1))
  Declare.i New_Ptr(*Guid.UUID)
EndDeclareModule

Module Guid
  
  ;<comment>
  ;  <summary>Returns a new GUID / UUID as Ascii Array</summary>
  ;  <param><b>DstArray</b>: destination Array </param>
  ;  <return>Returns a Pointer to the Array</return>
  ;  <example>Guid::New(@Guid())</example>
  ;</comment>
  Procedure.i New(Array DstArray.a(1)) 
    
    If ArraySize(Guid()) = -1
      Dim Guid(SizeOf(UUID) - 1)
    Else
      ReDim Guid(SizeOf(UUID) - 1)
    EndIf
    
    If UuidCreate_(@Guid()) = #RPC_S_OK
      ProcedureReturn @Guid()
    EndIf 
    
  EndProcedure
  
  ;<comment>
  ;  <summary>Returns a new GUID / UUID as UUID Structure</summary>
  ;  <param><b>*Guid</b>: Pointer to a UUID Structure</param>
  ;  <return>returns Pointer to the UUID Structure</return>
  ;  <example>Guid::New_Ptr(@Guid)</example>
  ;</comment>
  Procedure.i New_Ptr(*Guid.UUID)
    
    If Not *Guid
      ProcedureReturn #Null
    EndIf
        
    If UuidCreate_(*Guid) = #RPC_S_OK
      ProcedureReturn *Guid
    EndIf 
  EndProcedure
  
  ;<comment>
  ;  <summary>Returns a string representation of the value of Guid in registry format.</summary>
  ;  <param><b>*Guid</b>: Pointer to the UUID Structure</param>
  ;  <param><i>Optional </i><b>ToUpper</b>: Flag to set Output Uppercase</param>
  ;  <return>returns string with guid in registry format</return>
  ;  <example>RegGuid.s = Guid::ToString(@Guid)</example>
  ;</comment>
  Procedure.s ToString(*Guid.UUID, ToUpper=#False)
    Protected.s StringGuid
    Protected *RpcString
    
    If *Guid = #Null : ProcedureReturn "" : EndIf 
    
    If UuidToString_(*Guid, @*RpcString) = #RPC_S_OK
      If *stringUuid
        If ToUpper
          StringGuid = UCase(PeekS(*stringUuid, -1, #PB_Unicode))
        Else
          StringGuid = PeekS(*stringUuid, -1, #PB_Unicode)
        EndIf
        RpcStringFree_(@*RpcString)
        
      EndIf
    EndIf 
    
    ProcedureReturn StringGuid
  EndProcedure
  
EndModule
