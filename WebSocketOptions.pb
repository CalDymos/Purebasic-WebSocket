XIncludeFile "PBExt.pb"
XIncludeFile "Net.Pb"

DeclareModule WebSocketOptions ; 
  
  ;#Region Class interface
  ;- Class interface
  
  Interface IWebSocketOptions ; 
    Dispose()
    
    ; public methods
    Set_Header(Name.s, Value.s)
    Set_SubProtocol(SubProtocol.s)
    ; public Properties
    Get_Headers(List Headers.Net::sRequestHeader())
    Get_SubProtocols(List subProtocols.s())
    Set_Proxy(Uri.s, UserName.s, PassWord.s)
    Get_ProxyUri.i()
    Get_ProxyUserName.s()
    Get_ProxyPassWord.s()
    Set_AutoReconnect(Value.b)
    Get_AutoReconnect.b()
    Set_SendDelay(Value.l)
    Get_SendDelay()
    Set_ConnectionTimout(TimeOut.l)
  EndInterface
  
  ;#End Region
  
  ;#Region Structure of the class
  ;- Structure of the class
  ; must be public so that it can be inherited
  
  Structure sWebSocketOptions 
    *vTable     ; Pointer to the function table. Always in first place
    
    ; Daten
    List Headers.Net::sRequestHeader()
    List SubProtocols.s()
    Proxy.Net::sWebProxy
    AutoReconnect.b
    SendDelay.l
    ConnectionTimout.l
  EndStructure
  
  ;#End Region
  
  ;#Region Declaration public module methods
  ;- Declaration public module methods
  
  ; Construct
  Declare New()
  
  ; Helper function for inheritance. For inheritance we need access to the address of the vituelle table of the class.
  Declare GetVT()
  
  ;#End Region
EndDeclareModule

Module WebSocketOptions 
  EnableExplicit
  
  ;#Region virtual Table Helpers
  
    ; Helper structure for accessing the virtual table as an Array Of Pointers
  Structure udtArrayVT
    *Addr[0] 
  EndStructure
  
  ; Pointer for virutal table
  Global *vtWebSocketOptions.udtArrayVT 
  
  ;#End Region 
  
  ;#Region Declaration public Interface methods
  ;- Declaration public Interface methods
  Declare Dispose(*This)
  ;#End Region
  
  ;#Region Declaration private methods
   ;- Declaration private methods
  
  ;#End Region
    
  ;#Region Construct and Destruct
  ;- construct and destruct
  
  ;Construct
  Procedure New() ;
    Protected *Object.sWebSocketOptions 
    *Object = AllocateStructure(sWebSocketOptions) ; 
                                        
    If *Object
      *Object\vTable = *vtWebSocketOptions     ; Set pointer to the function table (methods). 
      
    EndIf
    ProcedureReturn *Object
  EndProcedure
  
  Procedure Dispose(*This.sWebSocketOptions)
    If *This
      FreeStructure(*This); Release Memory
    EndIf
  EndProcedure
  
  ;#End Region
  
  ;#Region Properties
  ;- Properties 
  
  Procedure Set_Header(*This.sWebSocketOptions, Name.s, Value.s)
    With *This
      ForEach \Headers()
        If \Headers()\headerName = Name
          \Headers()\headerValue = Value
          ProcedureReturn 
        EndIf
      Next
      AddElement(\Headers())
      \Headers()\headerName = Name
      \Headers()\headerValue = Value
    EndWith
  EndProcedure
  
  Procedure Get_Headers(*This.sWebSocketOptions, List Headers.Net::sRequestHeader())
    With *This
      Headers() = \Headers()
    EndWith    
  EndProcedure
  
  Procedure Set_SubProtocol(*This.sWebSocketOptions, SubProtocol.s)
    With *this
      ForEach \SubProtocols()
        If \SubProtocols() = SubProtocol
          ProcedureReturn 
        EndIf
      Next
      AddElement(\SubProtocols())
      \SubProtocols() = SubProtocol
    EndWith    
  EndProcedure
  
  Procedure Get_SubProtocols(*This.sWebSocketOptions, List Protocols.s())
    With *this
      Protocols() = \SubProtocols()
    EndWith
  EndProcedure
  
  Procedure Set_Proxy(*This.sWebSocketOptions, Uri.s, UserName.s, PassWord.s)
    With *this
      Net::SetUri(Uri, @\Proxy\uri)     
      \Proxy\Username = UserName
      \Proxy\Password = PassWord
    EndWith
  EndProcedure
  
  Procedure.i Get_ProxyUri(*This.sWebSocketOptions)
    ProcedureReturn @*this\Proxy\uri
  EndProcedure
  
  Procedure.s Get_ProxyUserName(*This.sWebSocketOptions)
    ProcedureReturn *this\Proxy\Username
  EndProcedure
  
  Procedure.s Get_ProxyPassWord(*This.sWebSocketOptions)
    ProcedureReturn *this\Proxy\Password
  EndProcedure
  
  Procedure Set_AutoReconnect(*This.sWebSocketOptions, Value.b)
    *This\AutoReconnect = value
  EndProcedure
  
  Procedure.b Get_AutoReconnect(*This.sWebSocketOptions)
    ProcedureReturn  *This\AutoReconnect
  EndProcedure
  
  Procedure Set_SendDelay(*This.sWebSocketOptions, Value.l)
    *This\SendDelay = Value
  EndProcedure
  
  Procedure.l Get_SendDelay(*This.sWebSocketOptions)
    ProcedureReturn *This\SendDelay
  EndProcedure
  
  Procedure Set_ConnectionTimout(*This.sWebSocketOptions, TimeOut.l)
    With *This
      \ConnectionTimout = TimeOut
    EndWith
  EndProcedure
    
  ;#End Region
  
  ;#Region Definition public methods
  ;- definition public methods
    
  ;#End Region
  
  ;#Region Definition Private Methods
  ;- Definition Private Methods
  
  ;#End Region
  
  ;#Region Virtual Table
  ;- Handling virtual table
    
  Procedure InitVT()
    *vtWebSocketOptions = AllocateMemory(SizeOf(iWebSocketOptions))
    
    If *vtWebSocketOptions
      With *vtWebSocketOptions
        \addr[OffsetOf(iWebSocketOptions\Dispose()) / SizeOf(integer)] = @Dispose() 
        \addr[OffsetOf(iWebSocketOptions\Set_Header()) / SizeOf(integer)] = @Set_Header() 
        \addr[OffsetOf(iWebSocketOptions\Set_SubProtocol()) / SizeOf(integer)] = @Set_SubProtocol() 
        \addr[OffsetOf(iWebSocketOptions\Get_Headers()) / SizeOf(integer)] = @Get_Headers()     
        \addr[OffsetOf(iWebSocketOptions\Get_SubProtocols()) / SizeOf(integer)] = @Get_SubProtocols()
        \addr[OffsetOf(iWebSocketOptions\Set_Proxy()) / SizeOf(integer)] = @Set_Proxy()
        \addr[OffsetOf(iWebSocketOptions\Get_ProxyUri()) / SizeOf(integer)] = @Get_ProxyUri()
        \addr[OffsetOf(iWebSocketOptions\Get_ProxyUserName()) / SizeOf(integer)] = @Get_ProxyUserName() 
        \addr[OffsetOf(iWebSocketOptions\Get_ProxyPassWord()) / SizeOf(integer)] = @Get_ProxyPassWord() 
        \addr[OffsetOf(iWebSocketOptions\Set_AutoReconnect()) / SizeOf(integer)] = @Set_AutoReconnect() 
        \addr[OffsetOf(iWebSocketOptions\Get_AutoReconnect()) / SizeOf(integer)] = @Get_AutoReconnect() 
        \addr[OffsetOf(iWebSocketOptions\Set_SendDelay()) / SizeOf(integer)] = @Set_SendDelay()
        \addr[OffsetOf(iWebSocketOptions\Get_SendDelay()) / SizeOf(integer)] = @Get_SendDelay()
      EndWith  
    Else
      ; TODO: Out Of Memory!
      End 
    EndIf
  EndProcedure : InitVT() ; initialize virtual table
  
  ; Property to Get Address of vTable (for inheritance)
  Procedure GetVT()
    ProcedureReturn *vtWebSocketOptions
  EndProcedure
  
  ;#End Region
EndModule