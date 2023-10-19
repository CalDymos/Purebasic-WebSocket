CompilerIf Not #PB_Compiler_Thread
  CompilerError "Thread-Safe is not activated!"
CompilerEndIf

XIncludeFile "System\System.pbi"
XIncludeFile "WebSocketOptions.pbi"

DeclareModule WebSocket 
  
  ;{ Class interface
  ;- --------------------------------------------------------------------------
  ;- Class interface
  ;- --------------------------------------------------------------------------
  
  Interface IWebSocket 
    Dispose()
    
    ; public methods
    Connect()
    Disconnect()
    Send(message.s)
    SendArray(Array message.a(1))
    SendRawArray(Array RawData.a(1))
    
    ; public Properties
    Set_KeepAliveInterval(interval.l)
    Get_KeepAliveInterval.l()
    Get_State()
    Get_SendQueueLength()
    Get_InstanceName()
    AddHandler_OnData(*Procedure);
    AddHandler_OnMessage(*Procedure)
    AddHandler_OnStateChanged(*Procedure)
    AddHandler_OnOpened(*Procedure)
    AddHandler_OnClosed(*Procedure)
    AddHandler_OnError(*Procedure)
    AddHandler_OnSendFailed(*Procedure)
    AddHandler_OnFatality(*Procedure)
  EndInterface
  
  ;}
  
  ;{ Public Structures
  ;- --------------------------------------------------------------------------
  ;- Public Structures
  ;- --------------------------------------------------------------------------
  
  Structure sRequestMessage
    MessageType.l
    Array aData.a(0)
  EndStructure
  
  ; Helper Structure for GetLastError
  Structure sErr
    Description.s
    Number.l
  EndStructure
  
  ; Websocket MessageHeader
  Structure sMessageHeader
    Opcode.a ;.OpCodes
    FIN.a
    RSV1.a 
    RSV2.a
    RSV3.a
    PayloadLength.q
    Mask.l
  EndStructure
  
  ;}
  
  ;{ Class Structure
  ;- --------------------------------------------------------------------------
  ;- Class Structure
  ;- --------------------------------------------------------------------------
  ; must be public so that it can be inherited
  
  Structure sWebSocket 
    *vTable     ; Pointer to the function table. Always in first place
    Mutex.i     ; Is needed if the created object is used by different threads
    
    ; Event pointers
    *OnData
    *OnMessage
    *OnStateChanged
    *OnOpened
    *OnClosed
    *OnError
    *OnSendFailed
    *OnFatality
    
    ; private Data
    disposeCalled.b
    instanceName.s
    connectionID.i
    uri.Net::sUri
    state.l ;.WebSocketState
    keepAliveInterval.l
    timeOut.l
    *options.WebSocketOptions::IWebSocketOptions
    *listenerThread.Thread::sThreadCtrl
    listenerRunning.b
    *senderThread.Thread::sThreadCtrl
    senderRunning.b
    *monitorThread.Thread::sThreadCtrl
    monitorRunning.b
    autoReconnect.b
    reconnecting.b
    reconnectNeeded.b
    disconnectCalled.b
    closeStatus.l
    *reconnectThread.Thread::sThreadCtrl
    *sendQueueAddThread.Thread::sThreadCtrl
    LastMessageHeader.sMessageHeader
    
    List sendQueue.sRequestMessage() 
    lastError.sErr
  EndStructure
  
  ;}
  
  ;{ Declaration public module methods
  ;- --------------------------------------------------------------------------
  ;- Declaration public module methods
  ;- --------------------------------------------------------------------------
  
  ; Construct
  Declare New(uri.s, *options.WebSocketOptions::IWebSocketOptions, InstanceName.s = #Empty$)
  
  ; Helper function for inheritance. For inheritance we need access to the address of the vituelle table of the class.
  Declare GetVT()
  
  ;}
EndDeclareModule
Module WebSocket 
  EnableExplicit 
  
  ;{ Private Structures and Vars
  ;- --------------------------------------------------------------------------
  ;- Private Structures and Vars
  ;- --------------------------------------------------------------------------
  
  ; Helper structure for accessing the virtual table as an Array Of Pointers
  Structure udtArrayVT
    *Addr[0] 
  EndStructure
  
  Enumeration MessageOpcode
    #MessageOpcode_Continuation = 0
    #MessageOpcode_Text = 1
    #MessageOpcode_Binary = 2
    
    #MessageOpcode_Close = 8
    #MessageOpcode_Ping = 9
    #MessageOpcode_Pong = 10
  EndEnumeration   
  
  ;The maximum size in bytes of a message frame header that includes mask bytes.
  #MaxMessageHeaderLength = 14
  ;The maximum size of a control message payload.
  #MaxControlPayloadLength = 125
  ;Length of the mask XOr'd with the payload data.
  #MaskLength = 4
  
  ; Pointer for virutal table
  Global *vtWebSocket.udtArrayVT 
  
  ;} 
  
  ;{ Declaration public Interface methods
  ;- --------------------------------------------------------------------------
  ;- Declaration public Interface methods
  ;- --------------------------------------------------------------------------
  
  Declare Dispose(*This)
  Declare Disconnect(*This)
  
  ;}
  
  ;{ Declaration private methods
  ;- --------------------------------------------------------------------------
  ;- Declaration private methods
  ;- --------------------------------------------------------------------------
  
  Declare _Connect_Thread(*Thread.Thread::sThreadCtrl)
  Declare _StartListener(*This.sWebSocket)
  Declare _StartListener_Thread(*This.sWebSocket)
  Declare _StartMonitor(*This.sWebSocket)
  Declare _StartMonitor_Thread(*This.sWebSocket)
  Declare _StartSender(*This.sWebSocket)
  Declare _StartSender_Thread(*This.sWebSocket)
  Declare _DoReconnect(*This.sWebSocket)
  Declare _DoReconnect_Thread(*This.sWebSocket)
  Declare _Send(*This.sWebSocket, Array buffer.a(1), messageType.l, messageFlags.l)
  Declare _SendFrame(*This.sWebSocket, *payloadBuffer, *header.sMessageHeader)
  Declare _sendQueueAdd_Thread(*Thread.Thread::sThreadCtrl)
  Declare _SendKeepAlive(*This.sWebSocket)
  Declare _Handshake(*This.sWebSocket)
  Declare _ApplyMasking(Mask.l, *Buffer)
  Declare _Receive(*This.sWebSocket, Array buffer.a(1), *res.Net::sWebSocketReceiveResult)
  Declare _Abort(*This.sWebSocket)
  Declare _Close(*This.sWebSocket, closeStatus.w, statusDescription.s)
  Declare _GetLastError(*Err.sErr) 
  
  
  ;}
  
  ;{ Declaration Events
  ;- --------------------------------------------------------------------------
  ;- Declaration Events
  ;- --------------------------------------------------------------------------
  
  ; Delegates for Events
  Prototype Proto_OnError(*sender, errNum.l)
  Prototype Proto_OnClosed(*sender, WebSocketCloseStatus.l)
  Prototype Proto_OnOpened(*sender)
  Prototype Proto_OnStateChanged(*sender, New_WebSocketState.l, Prev_WebSocketState.l)
  Prototype Proto_OnMessage(*sender, message.s)
  Prototype Proto_OnData(*sender, Array ByteData.a(1))
  Prototype Proto_OnFatality(*sender, reason.s)
  Prototype Proto_OnSendFailed(*sender, Array ByteData.a(1), errNum.l)
  
  Global OnError.Proto_OnError
  Global OnClosed.Proto_OnClosed
  Global OnOpened.Proto_OnOpened
  Global OnStateChanged.Proto_OnStateChanged
  Global OnMessage.Proto_OnMessage
  Global OnData.Proto_OnData
  Global OnFatality.Proto_OnFatality
  Global OnSendFailed.Proto_OnSendFailed
  
  ;}
  
  ;{ Macros
  ;- --------------------------------------------------------------------------
  ;- Macros
  ;- --------------------------------------------------------------------------
  
  Macro dbg(txt)
    Debug "Websocket: " + FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss",Date()) + " > " + txt
  EndMacro
  ;}
  
  ;{ Construct and Destruct
  ;- --------------------------------------------------------------------------
  ;- Construct and destruct
  ;- --------------------------------------------------------------------------
  
  ;Construct
  Procedure New(uri.s, *options.WebSocketOptions::IWebSocketOptions, InstanceName.s = #Empty$)
    Protected *Object.sWebSocket                                      
    
    *Object = AllocateStructure(sWebSocket)                           
    
    If *Object
      With *Object
        \vTable = *vtWebSocket     ; Set pointer to the function table (methods). 
        
        \Mutex = CreateMutex()  ; create Mutex to protect the data of the object, when used in multiple threads
        
        Net::SetUri(uri, @\Uri)
        
        \options = *options
        \instanceName = InstanceName
        \TimeOut = \options\Get_ConnectionTimout()
        
        \AutoReconnect = \options\Get_AutoReconnect()
        
        _StartMonitor(*Object)
      EndWith
    EndIf
    ProcedureReturn *Object
  EndProcedure
  
  ; Destruct
  Procedure Dispose(*This.sWebSocket)
    If *This
      With *This
        \disposeCalled = #True ; Request threads to be quit
        Disconnect(*This)
        Thread::Finalize(\sendQueueAddThread)
        Thread::Finalize(\senderThread)
        Thread::Finalize(\monitorThread)
        Thread::Finalize(\listenerThread)
        Thread::Finalize(\reconnectThread)
        FreeMutex(*This\Mutex) ; Release Mutex
        FreeStructure(*This)      ; Release Memory
      EndWith
    EndIf
  EndProcedure
  
  ;}
  
  ;{ Properties
  ;- --------------------------------------------------------------------------
  ;- Properties 
  ;- --------------------------------------------------------------------------
  
  Procedure.l Get_State(*This.sWebSocket)
    ProcedureReturn *This\state
  EndProcedure
  
  Procedure Set_KeepAliveInterval(*This.sWebSocket, interval.l)
    With *This
      LockMutex(\Mutex)
      \KeepAliveInterval = interval
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  Procedure.l Get_KeepAliveInterval(*This.sWebSocket)
    ProcedureReturn *this\KeepAliveInterval
  EndProcedure
  
  Procedure.l Get_SendQueueLength(*This.sWebSocket)
    ProcedureReturn ListSize(*this\sendQueue())
  EndProcedure
  
  Procedure.s Get_InstanceName(*This.sWebSocket)
    ProcedureReturn *this\instanceName
  EndProcedure
  
  ;}
  
  ;{ Event Handler Methods
  ;- --------------------------------------------------------------------------
  ;- Event Handler Methods
  ;- --------------------------------------------------------------------------
  
  Procedure AddHandler_OnData(*This.sWebSocket, *Procedure)
    With *This
      \OnData = *Procedure
    EndWith
  EndProcedure
  Procedure AddHandler_OnMessage(*This.sWebSocket, *Procedure)
    With *This
      \OnMessage = *Procedure
    EndWith
  EndProcedure
  Procedure AddHandler_OnStateChanged(*This.sWebSocket, *Procedure)
    With *This
      \OnStateChanged = *Procedure
    EndWith
  EndProcedure
  Procedure AddHandler_OnOpened(*This.sWebSocket, *Procedure)
    With *This
      \OnOpened = *Procedure
    EndWith
  EndProcedure
  Procedure AddHandler_OnClosed(*This.sWebSocket, *Procedure)
    With *This
      \OnClosed = *Procedure
    EndWith
  EndProcedure
  Procedure AddHandler_OnError(*This.sWebSocket, *Procedure)
    With *This
      \OnError = *Procedure
    EndWith
  EndProcedure
  Procedure AddHandler_OnSendFailed(*This.sWebSocket, *Procedure)
    With *This
      \OnSendFailed = *Procedure
    EndWith
  EndProcedure
  Procedure AddHandler_OnFatality(*This.sWebSocket, *Procedure)
    With *This
      \OnFatality = *Procedure
    EndWith
  EndProcedure
  
  ;}
  
  ;{ Public methods
  ;- --------------------------------------------------------------------------
  ;- Public methods
  ;- --------------------------------------------------------------------------
  
  Procedure Disconnect(*This.sWebSocket)
    With *This
      dbg("Disconnect called, closing websocket.")
      LockMutex(\Mutex)
      \disconnectCalled = #True
      UnlockMutex(\Mutex)
      _Close(*This, Net::#WebSocketCloseStatus_NormalClosure, "NORMAL SHUTDOWN")
    EndWith
  EndProcedure
  
  ;<comment>
  ;  <summary>Establishes the connection to the server <b>! CALL ONLY VIA THE INTERFACE !</b></summary>
  ;  <param><i>*This: Pointer to instance of the class, not needed when calling via the interface</i></param>
  ;  <return>no return Value</return>
  ;  <example>*ws\connect()</example>
  ;</comment>
  Procedure Connect(*This.sWebSocket)
    Define *thread.Thread::sThreadCtrl
    Protected err.sErr
    Protected msec
    
    With *This
      dbg("Connect called.")
      LockMutex(\Mutex)
      \disconnectCalled = #False
      UnlockMutex(\Mutex)

      *thread = Thread::New()
      Thread::Start(*thread, @_Connect_Thread(), *This)
      Thread::Wait(*thread, \timeOut)
      
      dbg("Starting Listener and Sender.")  
      _StartListener(*This)
      _StartSender(*This)
      
      msec = 0
      While \State <> Net::#WebSocketState_Open And msec < \TimeOut
        msec + 1
        Delay(1)
      Wend
      
      If \state <> Net::#WebSocketState_Open
        If \OnError
          _GetLastError(err)
          dbg("Connect failed:" + err\Description)
          LockMutex(\Mutex)
          OnError = \OnError
          UnlockMutex(\Mutex)
          OnError(*This, err\Number)
        EndIf
      EndIf
      
      dbg("Connect result: " + Bool(\State = Net::#WebSocketState_Open) + ", State " + \state)
      
      Thread::Finalize(*thread)
      ProcedureReturn Bool(\State = Net::#WebSocketState_Open)
    EndWith
  EndProcedure
  
  Structure _sSendParam
    *this.sWebSocket
    msg.sRequestMessage
  EndStructure
  
  ;<comment>
  ;  <summary>Sends a text message to the server <b>! CALL ONLY VIA THE INTERFACE !</b></summary>
  ;  <param><i>*This: Pointer to instance of the class, not needed when calling via the interface</i></param>
  ;  <param><b>message</b>: text Message to be send</param>
  ;  <return>no return Value</return>
  ;  <example>*ws\send("Eine Nachricht")</example>
  ;</comment>
  Procedure Send(*This.sWebSocket, message.s)
    Define *Param._sSendParam
    Define *thread.Thread::sThreadCtrl
    
    *Param = AllocateStructure(_sSendParam)
    *Param\this = *This
    TextEncoding::String_ToASCIIArray(message, *Param\msg\aData(), #PB_UTF8|#PB_String_NoZero)
    *Param\msg\MessageType = Net::#WebSocketMessageType_Text
    
    With *This  
      *thread = Thread::New()
      Thread::Start(*thread, @_sendQueueAdd_Thread(),*Param)
      LockMutex(\Mutex)
      ;Abort And Free Thread if it is still running
      Thread::Finalize(\sendQueueAddThread, #True, 1)
      \sendQueueAddThread = *thread
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  Procedure SendArray(*This.sWebSocket, Array message.a(1))
    Send(*this, TextEncoding::ASCIIArray_ToString(message(), #PB_UTF8))
  EndProcedure
  
  Procedure SendRawArray(*This.sWebSocket, Array RawData.a(1))
  EndProcedure
  
  
  ;}
  
  ;{ Private Methods
  ;- --------------------------------------------------------------------------
  ;- Private Methods
  ;- --------------------------------------------------------------------------
  
  Procedure _Connect_Thread(*Thread.Thread::sThreadCtrl)
    Define *this.sWebSocket = *Thread\Param ; Get Pointer to WebSocket Instance
    Protected *ProxyUri.Net::sUri
    Protected ConnectionID
    
    With *This      
      LockMutex(\Mutex)
      \State = Net::#WebSocketState_Connecting
      UnlockMutex(\Mutex)
      
      If \Uri\Scheme = "wss" ; If we connect with encryption (https)
        *ProxyUri = \options\Get_ProxyUri()
        If *ProxyUri\OriginalString 
          ConnectionID = OpenNetworkConnection(*ProxyUri\Host, *ProxyUri\Port, #PB_Network_TCP, \TimeOut)
          LockMutex(\Mutex)
          \connectionID = ConnectionID
          UnlockMutex(\Mutex)
        Else
          dbg("We need an SSL-Proxy like stunnel for encryption. Configure a proxy")
        EndIf
      ElseIf \Uri\Scheme = "ws"
        ConnectionID = OpenNetworkConnection(\Uri\Host, \Uri\Port, #PB_Network_TCP, \TimeOut)
        LockMutex(\Mutex)
        \connectionID = ConnectionID
        UnlockMutex(\Mutex)
      EndIf
      
      If \ConnectionID 
        If _Handshake(*This)
          dbg("Connection and Handshake ok")
          LockMutex(\Mutex)
          \State = Net::#WebSocketState_Open
          UnlockMutex(\Mutex)
          ProcedureReturn
        Else
          dbg("Handshake-Error")
          _Abort(*This)
          ProcedureReturn
        EndIf
      Else
        dbg("Couldn't connect")
        _Abort(*This)
        ProcedureReturn
      EndIf
    EndWith
  EndProcedure
  
  Procedure _sendQueueAdd_Thread(*Thread.Thread::sThreadCtrl)
    Protected *Param._sSendParam = *thread\Param
    With *Param\this
      dbg("Adding item To send queue:")
      
      LockMutex(\Mutex)
      FirstElement(\sendQueue())
      InsertElement(\sendQueue())
      \sendQueue() = *Param\msg
      UnlockMutex(\Mutex)
    EndWith
    
    LockMutex(*thread\Mutex)
    FreeStructure(*Param)
    *thread\Param = 0
    UnlockMutex(*thread\Mutex)
    
  EndProcedure
  
  Procedure _SendFrame(*This.sWebSocket, *payloadBuffer, *header.sMessageHeader)
    Protected Headerlength
    Protected *FrameBuffer
    Protected result
    Protected pos
    Protected Dim Mask.a(#MaskLength - 1)
    
    With *This
      dbg("Payload data length to send: " + Str(*header\payloadLength))
      
      ; The framebuffer, we fill it with the send data
      If *header\payloadLength <= 125
        Headerlength = 6
      ElseIf *header\payloadLength >= 126 And *header\payloadLength <= 65535
        Headerlength = 8
      Else
        Headerlength = #MaxMessageHeaderLength
      EndIf
      
      dbg("Headerlength to send: " + Str(Headerlength))
      
      
      *FrameBuffer = AllocateMemory(Headerlength + *header\payloadLength)
      
      If Not *header\Mask
        ; We generate 4 random masking bytes
        Mask(0) = Random(255,0)
        Mask(1) = Random(255,0) 
        Mask(2) = Random(255,0) 
        Mask(3) = Random(255,0) 
      Else
        PokeL(@Mask(), *header\Mask)
      EndIf
      
      pos = 0 ; The byteposotion in the framebuffer
      
      ; First Byte: FIN(1=finished with this Frame),RSV(0),RSV(0),RSV(0),OPCODE(4 byte)=0001(text) 
      PokeA(*FrameBuffer, (*Header\FIN << 7 ) | (*Header\RSV1 << 6) | (*Header\RSV2 << 5) | (*Header\RSV3 << 4) | *header\opCode) : pos + 1 ; = 129 text / = 130 binary
      
      ; Second Byte: Masking(1),length(to 125bytes, else we have to extend)
      If *header\payloadLength <= 125                                             ; Length fits in first byte
        PokeA(*Framebuffer + pos, *header\payloadLength + 128)    : pos + 1       ; + 128 for Masking
      ElseIf *header\payloadLength >= 126 And *header\payloadLength <= 65535      ; We have to extend length to third byte
        PokeA(*Framebuffer + pos, 126 + 128)          : pos + 1                   ; 126 for 2 extra length bytes and + 128 for Masking
        PokeA(*FrameBuffer + pos, (*header\payloadLength >> 8))   : pos + 1       ; First Byte
        PokeA(*FrameBuffer + pos, *header\payloadLength)          : pos + 1       ; Second Byte
      Else                                                                        ; It's bigger than 65535, we also use 8 extra bytes
        PokeA(*Framebuffer + pos, 127 + 128)          : pos + 1                   ; 127 for 8 extra length bytes and + 128 for Masking
        PokeA(*Framebuffer + pos, 0)                  : pos + 1                   ; 8 Bytes for payload lenght. We don't support giant packages for now, so first bytes are zero :P
        PokeA(*Framebuffer + pos, 0)                  : pos + 1
        PokeA(*Framebuffer + pos, 0)                  : pos + 1
        PokeA(*Framebuffer + pos, 0)                  : pos + 1
        PokeA(*Framebuffer + pos, *header\payloadLength >> 24)    : pos + 1
        PokeA(*Framebuffer + pos, *header\payloadLength >> 16)    : pos + 1
        PokeA(*Framebuffer + pos, *header\payloadLength >> 8)     : pos + 1
        PokeA(*Framebuffer + pos, *header\payloadLength)          : pos + 1       ; = 10 Byte
      EndIf
      ; Write Masking Bytes
      PokeA(*FrameBuffer + pos, Mask(0))              : pos + 1
      PokeA(*FrameBuffer + pos, Mask(1))              : pos + 1
      PokeA(*FrameBuffer + pos, Mask(2))              : pos + 1
      PokeA(*FrameBuffer + pos, Mask(3))              : pos + 1
      
      _ApplyMasking(PeekL(@Mask()), *payloadBuffer)
      
      CopyMemory(*payloadBuffer, *FrameBuffer + pos, *header\payloadLength)
      
      If SendNetworkData(\connectionID, *FrameBuffer, Headerlength + *header\payloadLength) = Headerlength + *header\payloadLength
        dbg("sent frame size in byte: " + Str(Headerlength + *header\payloadLength))
        result = #True
      Else
        result = #False
      EndIf
      FreeMemory(*FrameBuffer)
      ProcedureReturn result
    EndWith
  EndProcedure
  
  ;<comment>
  ;  <summary><i>Private methode</i> - Sends data over the WebSocket connection.</summary>
  ;  <param><b>*This</b>: Pointer to the websocket instance</param>
  ;  <param><b>buffer</b>: The buffer to be sent over the connection.</param>
  ;  <param><b>messageType</b>: A 'WebSocketMessageType' enumeration value that specifies the message type.</param>
  ;  <param><b>messageFlags</b>: Flags for controlling how the WebSocket should send a message. </param>
  ;  <return>no return value</return>
  ;  <example>_Send(*This, buffer(), messageType, messageFlags)</example>
  ;</comment>
  Procedure _Send(*This.sWebSocket, Array buffer.a(1), messageType.l, messageFlags.l)
    Define header.sMessageHeader
    Protected *PayloadBuffer
    
    With *This
      If messageType = Net::#WebSocketMessageType_Text
        header\FIN = #True
        header\Opcode = #MessageOpcode_Text
        header\PayloadLength = ArraySize(buffer()) + 1
      ElseIf messageType = Net::#WebSocketMessageType_binary
        header\FIN = #True
        header\Opcode = #MessageOpcode_Binary
        header\PayloadLength = ArraySize(buffer()) + 1
      ElseIf messageType = Net::#WebSocketMessageType_Ping ; Send Ping with Payload Data
        header\FIN = #True
        header\Opcode = #MessageOpcode_Ping
        header\PayloadLength = ArraySize(buffer()) + 1
        If header\PayloadLength > #MaxControlPayloadLength ; max Payload of 125 allowed
          header\PayloadLength = #MaxControlPayloadLength
        EndIf
      EndIf
      If header\PayloadLength 
        *PayloadBuffer = AllocateMemory(header\PayloadLength)
      EndIf
      
      If *PayloadBuffer
        CopyMemory(@buffer(), *PayloadBuffer, header\PayloadLength)
      EndIf
      
      _SendFrame(*This.sWebSocket, *PayloadBuffer, @header)
      
      If *PayloadBuffer
        FreeMemory(*PayloadBuffer)  
      EndIf
    EndWith
  EndProcedure
  
  ;<comment>
  ;  <summary><i>Private methode</i> - Sends data over the WebSocket connection.</summary>
  ;  <param><b>*This</b>: Pointer to the websocket instance</param>
  ;  <param><b>buffer</b>: The buffer to be sent over the connection.</param>
  ;  <param><b>messageType</b>: A 'WebSocketMessageType' enumeration value that specifies the message type.</param>
  ;  <param><b>messageFlags</b>: Flags for controlling how the WebSocket should send a message. </param>
  ;  <return>no return value</return>
  ;  <example>_Send(*This, buffer(), messageType, messageFlags)</example>
  ;</comment>
  Procedure _SendKeepAlive(*This.sWebSocket)
    Dim Empty.a(0) : FreeArray(Empty())
    _Send(*This, Empty(), Net::#WebSocketMessageType_Pong, #True)
  EndProcedure
  
  
  ;<comment>
  ;  <summary><i>Private methode</i> - Aborts the WebSocket connection and close network connection.</summary>
  ;  <param><b>*This</b>: Pointer to the websocket instance</param>
  ;  <return>no return value</return>
  ;  <example>_Abort(*This)</example>
  ;</comment>
  Procedure _Abort(*This.sWebSocket)
    With *This
      dbg("Abort Websocket connection")
      \State = Net::#WebSocketState_Aborted
      If \ConnectionID : CloseNetworkConnection(\ConnectionID) : EndIf
      LockMutex(\Mutex)
      \connectionID = 0
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  ;<comment>
  ;  <summary><i>Private methode</i> - Sends data over the WebSocket connection.</summary>
  ;  <param><b>*This</b>: Pointer to the websocket instance</param>
  ;  <param><b>buffer</b>: The buffer to be sent over the connection.</param>
  ;  <param><b>messageType</b>: A 'WebSocketMessageType' enumeration value that specifies the message type.</param>
  ;  <param><b>messageFlags</b>: Flags for controlling how the WebSocket should send a message. </param>
  ;  <return>no return value</return>
  ;  <example>_Close(*This, buffer(), messageType, messageFlags)</example>
  ;</comment>
  Procedure _Close(*This.sWebSocket, closeStatus.w, statusDescription.s)
    Define header.sMessageHeader
    Protected *PayloadBuffer
    With *This
      dbg("Close Websocket connection")
      header\FIN = #True
      header\Opcode = #MessageOpcode_Close
      header\PayloadLength = SizeOf(closeStatus) + StringByteLength(statusDescription, #PB_UTF8)
      *PayloadBuffer = AllocateMemory(header\PayloadLength)
      PokeU(*PayloadBuffer, ((closeStatus & $FF00) >> 8) | ((closeStatus & $FF) << 8))
      PokeS(*PayloadBuffer + SizeOf(closeStatus), statusDescription, -1, #PB_UTF8|#PB_String_NoZero)      
      _SendFrame(*This.sWebSocket, *PayloadBuffer, @header)
      CloseNetworkConnection(\ConnectionID)
      LockMutex(\Mutex)
      \State = Net::#WebSocketState_Closed     
      UnlockMutex(\Mutex)
      FreeMemory(*PayloadBuffer)
    EndWith
  EndProcedure
  
  Procedure _StartMonitor(*This.sWebSocket)
    Define *thread.Thread::sThreadCtrl
    
    With *this
      dbg("Starting monitor.")
      *thread = Thread::New()
      ; Abort And Free Thread if it is still running
      Thread::Finalize(\monitorThread, #True, 10)
      Thread::Start(*thread, @_StartMonitor_Thread(), *This)
      LockMutex(\Mutex)
      \monitorThread = *thread
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  Procedure _StartMonitor_Thread(*Thread.Thread::sThreadCtrl)
    Define *This.sWebSocket = *Thread\Param
    Protected  lastState
    
    With *this
      dbg("Entering monitor loop.")
      LockMutex(\Mutex)
      \MonitorRunning = #True
      \reconnectNeeded = #False
      UnlockMutex(\Mutex)
      
      lastState = \state
      While (Not \disposeCalled And Not *Thread\Abort)
        If lastState = \State
          Delay(200)
          Continue
        EndIf
        
        If \Reconnecting
          
          ; When the reconnection is made, we must not trigger a status change too quickly.
          Delay(4000)
          If \Reconnecting
            Delay(3000)
            If Not \Reconnecting  
              ProcedureReturn  
            EndIf
          Else
            ProcedureReturn 
          EndIf
        EndIf
        
        ;don't fire if we just came off of an abort (reconnect)
        If (lastState = Net::#WebSocketState_Aborted) And (\State = Net::#WebSocketState_Connecting Or \State = Net::#WebSocketState_Open)
          Break
        EndIf
        
        If \AutoReconnect And \reconnectNeeded And \State = Net::#WebSocketState_Aborted
          Break
        EndIf
        
        ; check again since This can change before the first check
        If laststate = \State
          Delay(200)
          Continue
        EndIf
        
        If (\AutoReconnect And (\State = Net::#WebSocketState_Closed Or \State = Net::#WebSocketState_Aborted))
          
          Break;
        EndIf
        
        dbg("State changed from " + Str(lastState) + " To " + \State);
        
        If \OnStateChanged  
          LockMutex(\Mutex)
          OnStateChanged = \OnStateChanged
          UnlockMutex(\Mutex)
          OnStateChanged(*This, \State, lastState)
        EndIf
        
        If \State = Net::#WebSocketState_Open
          If \OnOpened 
            LockMutex(\Mutex)
            OnOpened = \OnOpened
            UnlockMutex(\Mutex)
            OnOpened(*This)
          EndIf
        EndIf
        
        If (\State = Net::#WebSocketState_Closed Or \State = Net::#WebSocketState_Aborted) And Not \Reconnecting
          If lastState = Net::#WebSocketState_Open And Not \disconnectCalled And \AutoReconnect
            dbg("Reconnect needed.")
            ; Exit the loop and start async reconnect
            LockMutex(\Mutex)
            \reconnectNeeded = #True
            UnlockMutex(\Mutex)
            Break
          EndIf
          If \OnClosed 
            LockMutex(\Mutex)
            OnClosed = \OnClosed
            UnlockMutex(\Mutex)
            If \CloseStatus
              OnClosed(*This, \CloseStatus)
            Else
              OnClosed(*This, Net::#WebSocketCloseStatus_Empty)
            EndIf
          EndIf
          If  \CloseStatus And \CloseStatus <> Net::#WebSocketCloseStatus_NormalClosure
            If \OnError
              LockMutex(\Mutex)
              OnError = \OnError
              UnlockMutex(\Mutex)
              OnError(*This, \CloseStatus)
            EndIf
          EndIf
        EndIf
        lastState = \State
      Wend
      LockMutex(\Mutex)
      \MonitorRunning = #False
      UnlockMutex(\Mutex)
      dbg("Exiting monitor")
      If (\AutoReconnect And \reconnectNeeded And Not \reconnecting And Not \disconnectCalled And Not *Thread\Abort)
        
        _DoReconnect(*This);
      EndIf
    EndWith
  EndProcedure
  
  Procedure _DoReconnect(*This.sWebSocket)
    Define *thread.Thread::sThreadCtrl
    With *This
      dbg("Entered reconnect.")
      *thread = Thread::New()
      Thread::Finalize(\reconnectThread, #True, 10)
      Thread::Start(*thread, @_DoReconnect_Thread(), *This)
      LockMutex(\Mutex)
      \reconnectThread = *thread
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  Procedure _DoReconnect_Thread(*thread.Thread::sThreadCtrl)
    Define *This.sWebSocket = *thread\Param
    Protected msec.l
    Protected connected.b
    Define *ConnectThread.Thread::sThreadCtrl
    
    With *This
      LockMutex(\Mutex)
      \Reconnecting = #True
      UnlockMutex(\Mutex)
      
      msec = 0
      While (Not Thread::GetState(\monitorThread) Or Not Thread::GetState(\listenerThread) Or Not Thread::GetState(\senderThread)) And msec < 15000       
        msec + 1
        Delay(1)
      Wend
      
      If (Not Thread::GetState(\monitorThread) Or Not Thread::GetState(\listenerThread) Or Not Thread::GetState(\senderThread))
        dbg("Reconnect fatality, tasks failed to stop before the timeout.")
        ; exit everything As dead...
        If \OnFatality 
          LockMutex(\Mutex)
          OnFatality = \OnFatality
          UnlockMutex(\Mutex)
          OnFatality(*This, "Fatal network error. Network services fail to shut down.")
        EndIf
        LockMutex(\Mutex)
        \reconnecting = #False
        \disconnectCalled = #True
        UnlockMutex(\Mutex)
        ProcedureReturn          
      EndIf
      
      dbg("closing of current websocket.")
      _Abort(*This)
      
      If \OnStateChanged
        LockMutex(\Mutex)
        OnStateChanged = \OnStateChanged
        UnlockMutex(\Mutex)
        OnStateChanged(*This, Net::#WebSocketState_Connecting, Net::#WebSocketState_Aborted)
      EndIf
      
      connected = #False
      *ConnectThread = Thread::New()
      While (Not \disconnectCalled And Not \disposeCalled And Not connected And Not *ConnectThread\Abort)
        dbg("Creating new websocket.")
        
        If (Not \MonitorRunning)
          
          dbg("Starting monitor.")
          _StartMonitor(*This)
        EndIf
   
        dbg("Attempting connect.")
        msec = 0
        Thread::Start(*ConnectThread, @_Connect_Thread(), *This)
        Thread::Wait(*ConnectThread, \timeOut)
        
        If Not IsThread(*ConnectThread\ID) And \State = Net::#WebSocketState_Open 
          connected = #True 
        EndIf 
        dbg("Connect result: " + Str(connected))                               
        
        If Not connected
          dbg("Reconnection failed")
          _Abort(*This)
          ; exit everything As dead...
          If \OnFatality 
            LockMutex(\Mutex)
            OnFatality = \OnFatality
            UnlockMutex(\Mutex)
            OnFatality(*This, "Fatal network error. reconnect failed.")
          EndIf
          LockMutex(\Mutex)
          \reconnectNeeded = #False
          \reconnecting = #False
          \disconnectCalled = #True
          UnlockMutex(\Mutex)
          ProcedureReturn 
        Else
          dbg("Reconnect success, restarting Monitor, Listener and Sender")
          LockMutex(\Mutex)
          \reconnectNeeded = #False
          \reconnecting = #False
          UnlockMutex(\Mutex)
          If Not \monitorRunning
            _StartMonitor(*This)
          EndIf
          
          If Not \listenerRunning
            _StartListener(*This)
          EndIf
          
          If Not \senderRunning
            _StartSender(*This)
          EndIf
          
        EndIf
      Wend
    EndWith
  EndProcedure
  
  
  Procedure _StartListener(*This.sWebSocket)
    Define *thread.Thread::sThreadCtrl
    With *This
      dbg("Starting listener.")
      *thread = Thread::New()
      Thread::Finalize(\listenerThread, #True, 10)
      Thread::Start(*thread, @_StartListener_Thread(), *This)
      LockMutex(\Mutex)
      \listenerThread = *thread
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  
  Procedure _StartListener_Thread(*thread.Thread::sThreadCtrl)
    Define *This.sWebSocket = *thread\Param
    Protected message.s
    Protected Dim binary.a(0) : FreeArray(binary())
    Protected Dim buffer.a(0) : FreeArray(buffer())
    Protected res.Net::sWebSocketReceiveResult
    Protected Dim exactDataBuffer.a(0) : FreeArray(exactDataBuffer())
    Protected Dim binaryData.a(0) : FreeArray(binaryData())
    
    With *this
      dbg("Entering listener loop.")
      LockMutex(\Mutex)
      \listenerRunning = #True
      UnlockMutex(\Mutex)
      While (\State = Net::#WebSocketState_Open And Not \disposeCalled And Not \reconnecting And Not *thread\Abort)
        message = #Empty$
        
        ReadNWData:
        
        FreeArray(buffer())
        ResetStructure(@res, Net::sWebSocketReceiveResult)
        
        If Not _Receive(*this, buffer(), @res)
          LockMutex(\Mutex)
          \reconnectNeeded = #True
          UnlockMutex(\Mutex)
          _Abort(*This)
          Break
        EndIf
        
        If Not res\Count  
          Goto ReadNWData 
        EndIf
        
        If res\MessageType = Net::#WebSocketMessageType_Close
          dbg("Server requested close")
          _close(*This, Net::#WebSocketCloseStatus_NormalClosure, "SERVER REQUESTED CLOSE")
          ProcedureReturn 
        EndIf
        
        ; handle Text data
        If res\MessageType = Net::#WebSocketMessageType_Text
          If Not res\EndOfMessage
            message + TextEncoding::ASCIIArray_ToString(buffer(), #PB_UTF8)
            Goto ReadNWData
          EndIf
          message + TextEncoding::ASCIIArray_ToString(buffer(), #PB_UTF8)
          
          ; support ping/pong if initiated by the server (see RFC 6455)
          If message = "ping"
            Send(*this, "pong")
          Else
            dbg("Message fully received:")
            If \OnMessage
              LockMutex(\Mutex)
              OnMessage = \OnMessage
              UnlockMutex(\Mutex)
              OnMessage(*This, message)
            EndIf
          EndIf
        Else
          Dim exactDataBuffer(res\Count - 1)
          CopyArray(buffer(), exactDataBuffer())
          
          If Not res\EndOfMessage
            System::ASCIIArray_AddRange(binary(), exactDataBuffer())
            Goto ReadNWData
          EndIf
          
          System::ASCIIArray_AddRange(binary(), exactDataBuffer())
          ;dbg(ArraySize(exactDataBuffer()))
          Dim binaryData(ArraySize(binary()))
          CopyArray(binary(), binaryData())
          
          dbg("Binary fully received: " + BitConverter::ToString(binaryData()))
          If \OnData
            LockMutex(\Mutex)
            OnData = \OnData
            UnlockMutex(\Mutex)
            OnData(*This, binaryData())
          EndIf
          
          FreeArray(Buffer())
        EndIf
      Wend
      LockMutex(\Mutex)
      \ListenerRunning = #False
      UnlockMutex(\Mutex)
      dbg("Listener exiting")
      ;dbg(\State + " | " + \disposeCalled + " | " + \reconnecting)
    EndWith
  EndProcedure
  
  Procedure _ApplyMasking(Mask.l, *Buffer)
    Define i.i
    For i = 0 To MemorySize(*Buffer) - 1
      PokeA(*Buffer + i, PeekA(*Buffer + i) ! PeekA(@Mask + (i % 4)))
    Next
  EndProcedure
  
  Procedure _ParseMessageHeaderFromFrameBuffer(*This.sWebSocket, *FrameBuffer, FrameBufferSize, *resultheader.sMessageHeader)
    Protected Offset.i
    Protected i
    Protected masked.a
    Protected Dim Mask.a(3)
    Protected *receiveBuffer = *FrameBuffer
    Protected header.sMessageHeader
    
    With *this
      
      If *resultheader: ResetStructure(*resultheader, sMessageHeader): EndIf
      If (FrameBufferSize - Offset) >= 2
        header\Fin = Bool((PeekA(*receiveBuffer) & %10000000) <> 0)
        header\Opcode = PeekA(*receiveBuffer) & $F
        header\RSV1 = Bool((PeekA(*receiveBuffer) & %01000000) <> 0)
        header\RSV1 = Bool((PeekA(*receiveBuffer) & %00100000) <> 0)
        header\RSV1 = Bool((PeekA(*receiveBuffer) & %00010000) <> 0)
        masked = Bool((PeekA(*receiveBuffer + 1) & %10000000) <> 0)
        header\PayloadLength = PeekA(*receiveBuffer + 1) & %01111111
        
        Offset + 2
        *receiveBuffer + Offset
        
        ; Read the remainder of the payload length, if necessary
        If header\PayloadLength = 126 ; 16 bits
          If (FrameBufferSize - Offset) >= 2 
            header\PayloadLength = (PeekA(*receiveBuffer) << 8) | PeekA(*receiveBuffer);
            Offset + 2
            *receiveBuffer + Offset
          Else
            dbg("Expected to have two bytes for the payload length.")
            ProcedureReturn -1
          EndIf
          
        ElseIf header\PayloadLength = 127 ; 64 bits
          If FrameBufferSize >= 8
            
            header\PayloadLength = 0
            For i = 0 To 7
              header\PayloadLength = (header\PayloadLength << 8) | PeekA(*receiveBuffer + i);
            Next
            Offset + 8
            *receiveBuffer + Offset
          Else
            dbg("Expected to have eight bytes for the payload length.")
            ProcedureReturn -2
          EndIf
          
        EndIf
        
        If header\PayloadLength < 0 
          ProcedureReturn -3
        EndIf
        
        If masked
          Mask(0) = PeekA(*receiveBuffer)
          Mask(1) = PeekA(*receiveBuffer + 1) 
          Mask(2) = PeekA(*receiveBuffer + 2) 
          Mask(3) = PeekA(*receiveBuffer + 3)
          header\Mask = PeekL(@MasK())
          
          OffSet + 4
          *receiveBuffer + Offset
        EndIf
        
        *resultheader\FIN = header\FIN
        *resultheader\Mask = header\Mask
        *resultheader\RSV1 = header\RSV1
        *resultheader\RSV2 = header\RSV2
        *resultheader\RSV3 = header\RSV3
        *resultheader\Opcode = header\Opcode
        *resultheader\PayloadLength = header\PayloadLength
        ProcedureReturn Offset
      Else
        dbg("Expected To at least have the first two bytes of the header.")
      EndIf
    EndWith
  EndProcedure
  
  ;<comment>
  ;  <summary>Empfängt Daten aus einem verbundenen Socket</summary>
  ;  <param>*This: Pointer auf die Instanz der Klasse WebSocket</param>
  ;  <param>*Message: Der Puffer für die empfangenen Daten.</param>
  ;  <param>*res: Pointer auf eine sWebSocketReceiveResult Strukture</param>
  ;  <example>_Receive(*This, *buffer, @WebSocketReceiveResult)</example>
  ;</comment>
  Procedure _Receive(*This.sWebSocket, Array buffer.a(1), *res.Net::sWebSocketReceiveResult)
    Protected BufOffset.l
    Protected headerErrorCode.l
    Protected masking.b
    Protected ReceivedBytes.l
    Protected BufferIncrease.l = 4096
    Protected BufferSize.l = 0
    Protected *FrameBuffer = AllocateMemory(BufferIncrease)
    Protected *PayloadBuffer
    Protected count.i
    Define header.sMessageHeader
    
    With *this      
      count = 0
      Repeat
        BufferSize + BufferIncrease
        *FrameBuffer = ReAllocateMemory(*FrameBuffer, BufferSize)
        ReceivedBytes = ReceiveNetworkData(\ConnectionID, *FrameBuffer + count * BufferIncrease, BufferIncrease)
        ;InData.s = InData.s + PeekS(*FrameBuffer, ReceivedBytes, #PB_UTF8)
        count + 1
        ;dbg("Received Bytes: " + Str(ReceivedBytes))
      Until ReceivedBytes < BufferIncrease
      
      If ReceivedBytes = -1
        LockMutex(\Mutex)
        \state = Net::#WebSocketState_Aborted
        \closeStatus = Net::#WebSocketCloseStatus_InternalServerError
        *res\MessageType = Net::#WebSocketMessageType_Invalid
        *res\Count = 0
        UnlockMutex(\Mutex)
        ProcedureReturn #False
      EndIf
      
      BufferSize - BufferIncrease + ReceivedBytes
      
      ;dbg("Received Total Bytes: " + Str(BufferSize))
      
      *FrameBuffer = ReAllocateMemory(*FrameBuffer, BufferSize)
      
      headerErrorCode =  _ParseMessageHeaderFromFrameBuffer(*This.sWebSocket, *FrameBuffer, BufferSize, @header.sMessageHeader)
      If headerErrorCode <> 0
        BufOffset = headerErrorCode
        
        ; FIN
        If Not Header\FIN
          *res\EndOfMessage = #False
        Else
          *res\EndOfMessage = #True
        EndIf
        
        ; Opcodes
        If Header\Opcode = #MessageOpcode_Text
          dbg("Text frame")
          *res\MessageType = Net::#WebSocketMessageType_Text
        ElseIf Header\Opcode = #MessageOpcode_Binary
          dbg("Binary frame")
          *res\MessageType = Net::#WebSocketMessageType_binary
        ElseIf Header\Opcode = #MessageOpcode_Close
          dbg("Closing frame")
          *res\MessageType = Net::#WebSocketMessageType_Close
        ElseIf header\Opcode = #MessageOpcode_Ping 
          dbg("Received Ping")
          ; Answer with a Pong
          *PayloadBuffer = AllocateMemory(header\PayloadLength)
          CopyMemory(*FrameBuffer + BufOffset, *PayloadBuffer, header\PayloadLength)         
          header\Opcode = #MessageOpcode_Pong ; change Opcode to Pong
          _SendFrame(*This, *PayloadBuffer, header) ; and return Message
          FreeMemory(*PayloadBuffer)
          
          Dim buffer(header\PayloadLength - 1)
          CopyMemory(*FrameBuffer + BufOffset, @buffer(), header\PayloadLength)
          *res\Count = header\PayloadLength
          FreeMemory(*FrameBuffer)
          ProcedureReturn #True
        Else
          dbg("Opcode unknown:" +Str(header\Opcode))
          *res\MessageType = Net::#WebSocketMessageType_Unknown
          Dim buffer(header\PayloadLength - 1)
          CopyMemory(*FrameBuffer + BufOffset, @buffer(), header\PayloadLength)
          *res\Count = header\PayloadLength
          FreeMemory(*FrameBuffer)
          ProcedureReturn #False
        EndIf
        
        dbg("Mask: " + Str(header\Mask))
        
        dbg("PayloadLength: " + Str(header\PayloadLength))
        
        *PayloadBuffer = AllocateMemory(header\PayloadLength)
        CopyMemory(*FrameBuffer + BufOffset, *PayloadBuffer, header\PayloadLength)
        
        If header\Mask
          *res\MessageType = Net::#WebSocketMessageType_invalid ; all messages from the server to the client MUST NOT be masked !
          
          _ApplyMasking(header\Mask, *PayloadBuffer)
        
        EndIf
        
        Dim buffer(header\PayloadLength - 1)
        CopyMemory(*PayloadBuffer, @buffer(), header\PayloadLength)
        *res\Count = header\PayloadLength
        FreeMemory(*FrameBuffer)
        FreeMemory(*PayloadBuffer)
        ProcedureReturn #True
      Else
        LockMutex(\Mutex)
        *res\MessageType = Net::#WebSocketMessageType_Invalid
        UnlockMutex(\Mutex)
        FreeMemory(*FrameBuffer)
        ProcedureReturn  #False
      EndIf
    EndWith
  EndProcedure
  
  Procedure _StartSender(*This.sWebSocket)
    Define *thread.Thread::sThreadCtrl
    With *This
      dbg("Starting Sender.")
      *thread = Thread::New()
      Thread::Finalize(\senderThread, #True, 10)
      Thread::Start(*thread, @_StartSender_Thread(), *This)
      LockMutex(\Mutex)
      \senderThread = *thread
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  Procedure _StartSender_Thread(*thread.Thread::sThreadCtrl)
    Define *This.sWebSocket = *thread\Param
    Protected *QueueItem.sRequestMessage
    Protected msg.sRequestMessage, *msg.sRequestMessage
    Protected Dim buffer.a(0) : FreeArray(buffer())
    Protected  msgType.l
    
    With *this
      dbg("Entering sender loop.");
      LockMutex(\Mutex)
      \SenderRunning = #True
      UnlockMutex(\Mutex)
      While (Not \disposeCalled And Not \reconnecting And Not *thread\Abort)
        If (\State = Net::#WebSocketState_Open And Not \Reconnecting)
          
          LockMutex(\Mutex)
          *QueueItem = LastElement(\sendQueue());
          If *QueueItem 
            CopyStructure(*QueueItem, @msg, sRequestMessage)
            DeleteElement(\sendQueue())
            *msg = @msg
          Else
            *msg = #Null
          EndIf
                   
          UnlockMutex(\Mutex)
          
          If *msg
            Dim buffer(ArraySize(*msg\aData()))
            CopyArray(*msg\aData(), buffer())                            
            
            dbg("Sending message:");
            msgType = *msg\MessageType 
            If msgType <> Net::#WebSocketMessageType_Text : msgType = Net::#WebSocketMessageType_Binary: EndIf
            If Not _Send(*this, buffer(), msgType, #True)
              
              If \OnSendFailed
                LockMutex(\Mutex)
                OnSendFailed = \OnSendFailed
                UnlockMutex(\Mutex)
                OnSendFailed(*This, buffer(), *This\LastError)
              EndIf
              LockMutex(\Mutex)
              \reconnectNeeded = #True;
              UnlockMutex(\Mutex)
              _Abort(*This)           
              Break                   
            EndIf
          EndIf
        EndIf
        
        ; limit To N ms per iteration
        Delay(\options\Get_SendDelay());
      Wend
      LockMutex(\Mutex)
      \senderRunning = #False
      UnlockMutex(\Mutex)
    EndWith
  EndProcedure
  
  Procedure _Handshake(*This.sWebSocket)
    Protected NewList Headers.Net::sRequestHeader()
    Protected NewList SubProtocols.s()
    Protected Request.s
    Protected AddStr.s
    Protected Size.i
    Protected Answer.s
    Protected *Buffer
    
    With *This
      Request = "GET /" + \Uri\AbsolutePath + " HTTP/1.1"+ #CRLF$ +
                "Connection: Upgrade,Keep-Alive" + #CRLF$ +          
                "Upgrade: websocket" + #CRLF$ +          
                "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" + #CRLF$ +
                "Sec-WebSocket-Version: 13" + #CRLF$
      
      \options\Get_Headers(Headers())
      \options\Get_SubProtocols(SubProtocols())
      
      ForEach Headers()
        Request + Headers()\headerName + ": " + Headers()\headerValue + #CRLF$
      Next
      
      If ListSize(SubProtocols()) <> 0
        Request + "Sec-WebSocket-Protocol: "
        ForEach SubProtocols()
          Request + SubProtocols() + AddStr
          AddStr = "," 
        Next
        Request + #CRLF$
      EndIf
      
      Request + "Host: " + \Uri\Host + #CRLF$ + #CRLF$
      
      SendNetworkString(\ConnectionID, Request, #PB_UTF8)
      *Buffer = AllocateMemory(65536)
      
      ; We wait for answer
      Repeat
        Size = ReceiveNetworkData(\ConnectionID, *Buffer, 65536)
        Answer = Answer + PeekS(*Buffer, Size, #PB_UTF8)
        If FindString(Answer, #CRLF$ + #CRLF$)
          Break
        EndIf
      Until Size <> 65536
      
      Answer.s = UCase(Answer.s)
      
      ; Check answer
      If Not FindString(Answer.s, "HTTP/1.1 101") 
        ProcedureReturn #False
      ElseIf Not FindString(Answer, "CONNECTION: UPGRADE") 
        ProcedureReturn #False
      ElseIf Not FindString(Answer, "UPGRADE: WEBSOCKET")
        ProcedureReturn #False
      ElseIf Not FindString(Answer, "SEC-WEBSOCKET-ACCEPT: S3PPLMBITXAQ9KYGZZHZRBK+XOO=")
        ProcedureReturn #False
      Else
        ProcedureReturn #True
      EndIf
    EndWith
  EndProcedure
  
  Procedure _GetLastError(*Err.sErr) 
    Protected Error,*MemoryID,e$,Length
    Error = GetLastError_() 
    If *Err And Error
      *Err\Number = Error
      *MemoryID = AllocateMemory(255) 
      If *MemoryID
        Length = FormatMessage_ (#FORMAT_MESSAGE_FROM_SYSTEM, #Null, Error, 0, *MemoryID, 255, #Null) 
        If Length > 1 ; Some error messages are "" + Chr (13) + Chr (10)... stoopid M$... :( 
          e$ = PeekS(*MemoryID, Length - 2) 
        Else 
          e$ = "Unknown error!" 
        EndIf 
        FreeMemory(*MemoryID)
        *Err\Description = e$
        ProcedureReturn 0
      Else
        ProcedureReturn Error
      EndIf
    Else 
      ProcedureReturn -1 
    EndIf 
  EndProcedure 
  
  ;}
  
  ;{ Handling Virtual Table
  ;- --------------------------------------------------------------------------
  ;-   Handling Virtual Table
  ;- --------------------------------------------------------------------------  
  
  Procedure InitVT()
    *vtWebSocket = AllocateMemory(SizeOf(iWebSocket))
    
    If *vtWebSocket
      With *vtWebSocket
        \addr[OffsetOf(iWebSocket\Dispose()) / SizeOf(integer)] = @Dispose()
        \addr[OffsetOf(iWebSocket\Connect()) / SizeOf(integer)] = @Connect()
        \addr[OffsetOf(iWebSocket\Disconnect()) / SizeOf(integer)] = @Disconnect()       
        \addr[OffsetOf(iWebSocket\Send()) / SizeOf(integer)] = @Send()
        \addr[OffsetOf(iWebSocket\SendArray()) / SizeOf(integer)] = @SendArray()
        \addr[OffsetOf(iWebSocket\Set_KeepAliveInterval()) / SizeOf(integer)] = @Set_KeepAliveInterval()
        \addr[OffsetOf(iWebSocket\Get_KeepAliveInterval()) / SizeOf(integer)] = @Get_KeepAliveInterval()
        \addr[OffsetOf(iWebSocket\Get_State()) / SizeOf(integer)] = @Get_State()
        \addr[OffsetOf(iWebSocket\Get_SendQueueLength()) / SizeOf(integer)] = @Get_SendQueueLength()
        \addr[OffsetOf(iWebSocket\Get_InstanceName()) / SizeOf(integer)] = @Get_InstanceName()
        \addr[OffsetOf(iWebSocket\AddHandler_OnData()) / SizeOf(integer)] = @AddHandler_OnData()
        \addr[OffsetOf(iWebSocket\AddHandler_OnMessage()) / SizeOf(integer)] = @AddHandler_OnMessage()
        \addr[OffsetOf(iWebSocket\AddHandler_OnStateChanged()) / SizeOf(integer)] = @AddHandler_OnStateChanged()
        \addr[OffsetOf(iWebSocket\AddHandler_OnOpened()) / SizeOf(integer)] = @AddHandler_OnOpened()
        \addr[OffsetOf(iWebSocket\AddHandler_OnClosed()) / SizeOf(integer)] = @AddHandler_OnClosed()
        \addr[OffsetOf(iWebSocket\AddHandler_OnError()) / SizeOf(integer)] = @AddHandler_OnError()
        \addr[OffsetOf(iWebSocket\AddHandler_OnSendFailed()) / SizeOf(integer)] = @AddHandler_OnSendFailed()
        \addr[OffsetOf(iWebSocket\AddHandler_OnFatality()) / SizeOf(integer)] = @AddHandler_OnFatality()
      EndWith  
    Else
      End #ERROR_NOT_ENOUGH_MEMORY;
    EndIf
  EndProcedure : InitVT() ; initialize virtual table
  
  ; Property to Get Address of vTable (for inheritance)
  Procedure GetVT()
    ProcedureReturn *vtWebSocket
  EndProcedure
  
  ;}
  
EndModule