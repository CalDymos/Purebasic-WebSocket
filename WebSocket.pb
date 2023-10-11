XIncludeFile "PBExt.pb"
XIncludeFile "Net.Pb"
XIncludeFile "WebSocketOptions.pb"

DeclareModule WebSocket 
  
  ;#Region Class interface
  ;- Class interface
  
  Interface IWebSocket 
    Dispose()
    
    ; public methods
    Connect()
    Disconnect()
    Send(message.s)
    SendArray(Array message.a(1))
    ; public Properties
    Set_KeepAliveInterval(interval.l)
    Get_KeepAliveInterval.l()
    Get_State()
    Get_SendQueueLength()
    Get_InstanceName()
    AddHandler_OnData();
    AddHandler_OnMessage()
    AddHandler_OnStateChanged()
    AddHandler_OnOpened()
    AddHandler_OnClosed()
    AddHandler_OnError()
    AddHandler_OnSendFailed()
    AddHandler_OnFatality()
  EndInterface
  
  ;#End Region
  
  ;#Region Helper Structures
  ;- Helper Structures
  
  Structure sRequestMessage
    MessageType.l
    Array aData.a(0)
  EndStructure
  
  Structure sErr
    Description.s
    Number.l
  EndStructure
  
  ;#End Region
  
  ;#Region Structure of the class
  ;- Structure of the class
  ; must be public so that it can be inherited
  
  Structure sWebSocket 
    *vTable     ; Pointer to the function table. Always in first place
    
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
    state.l
    keepAliveInterval.l
    timeOut.l
    *options.WebSocketOptions::IWebSocketOptions
    listenerTaskId.i
    listenerRunning.b
    senderTaskId.i
    senderRunning.b
    MonitorTaskId.i
    monitorRunning.b
    autoReconnect.b
    reconnecting.b
    reconnectNeeded.b
    disconnectCalled.b
    closeStatus.l
    reconnectTaskId.i
    sendTaskId.i
    
    List sendQueue.sRequestMessage() 
    lastError.sErr
  EndStructure
  
  ;#End Region
  
  ;#Region Declaration public module methods
  ;- Declaration public module methods
  
  ; Construct
  Declare New(uri.s, *options.WebSocketOptions::IWebSocketOptions, InstanceName.s = #Empty$)
  
  ; Helper function for inheritance. For inheritance we need access to the address of the vituelle table of the class.
  Declare GetVT()
  
  ;#End Region
EndDeclareModule

Module WebSocket 
  EnableExplicit 
  
  ;#Region virtual Table Helpers
  
  ; Helper structure for accessing the virtual table as an Array Of Pointers
  Structure udtArrayVT
    *Addr[0] 
  EndStructure
  
  ; Pointer for virutal table
  Global *vtWebSocket.udtArrayVT 
  
  ;#End Region 
  
  ;#Region Declaration public Interface methods
  ;- Declaration public Interface methods
  Declare Dispose(*This)
  Declare Disconnect(*This)
  ;#End Region
  
  ;#Region Declaration private methods
  ;- Declaration private methods
  
  Declare _Connect_Task(*This.sWebSocket)
  Declare _StartListener(*This.sWebSocket)
  Declare _StartListener_Task(*This.sWebSocket)
  Declare _StartMonitor(*This.sWebSocket)
  Declare _StartMonitor_Task(*This.sWebSocket)
  Declare _StartSender(*This.sWebSocket)
  Declare _StartSender_Task(*This.sWebSocket)
  Declare _DoReconnect(*This.sWebSocket)
  Declare _DoReconnect_Task(*This.sWebSocket)
  Declare _Send_Task(*Param)
  Declare _Handshake(*This.sWebSocket)
  Declare _ApplyMasking(Array Mask.a(1), *Buffer)
  Declare _SendFrame(*This.sWebSocket, Array buffer.a(1), messageType.l, messageFlags.l)
  Declare _Receive(*This.sWebSocket, Array buffer.a(1), *res.Net::sWebSocketReceiveResult)
  Declare _Abort(*This.sWebSocket)
  Declare _Close(*This.sWebSocket, closeStatus.l, statusDescription.s)
  Declare _WaitForTaskEnd(TaskId)
  Declare _GetLastError(*Err.sErr) 
  
  
  ;#End Region
  
  ;#Region Declaration delegates for Events
  ;- Declaration delegates for Events
  
  Prototype Proto_OnError(*sender, errNum.l)
  Prototype Proto_OnClosed(*sender, WebSocketCloseStatus.l)
  Prototype Proto_OnOpened(*sender)
  Prototype Proto_OnStateChanged(*sender, New_WebSocketState.l, Prev_WebSocketState.l)
  Prototype Proto_OnMessage(*sender, message.s)
  Prototype Proto_OnData(*sender, Array ByteData.a(1))
  Prototype Proto_OnFatality(*sender, reason.s)
  Prototype Proto_OnSendFailed(*sender, Array ByteData.a(1), errNum.l)
  
  ;#End Region
  
  ;#Region Declaration Events
  ;- Declaration Events
  
  Global OnError.Proto_OnError
  Global OnClosed.Proto_OnClosed
  Global OnOpened.Proto_OnOpened
  Global OnStateChanged.Proto_OnStateChanged
  Global OnMessage.Proto_OnMessage
  Global OnData.Proto_OnData
  Global OnFatality.Proto_OnFatality
  Global OnSendFailed.Proto_OnSendFailed
  
  ;#End Region
  
  Macro dbg(txt)
    Debug "Websocket: " + FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss",Date()) + " > " + txt
  EndMacro
  
  ;#Region Construct and Destruct
  ;- construct and destruct
  
  ;Construct
  Procedure New(uri.s, *options.WebSocketOptions::IWebSocketOptions, InstanceName.s = #Empty$)
    Protected *Object.sWebSocket                                      
    
    *Object = AllocateStructure(sWebSocket)                           
    
    If *Object
      With *Object
        \vTable = *vtWebSocket     ; Set pointer to the function table (methods). 
        
        Net::SetUri(uri, @\Uri)
        
        \options = *options
        \instanceName = InstanceName
        \TimeOut = 15000 ; Set Connection Timout to default value 15000
        
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
        _WaitForTaskEnd(\sendTaskId)
        _WaitForTaskEnd(\senderTaskId)
        _WaitForTaskEnd(\MonitorTaskId)
        _WaitForTaskEnd(\listenerTaskId)
        _WaitForTaskEnd(\reconnectTaskId)
        FreeStructure(*This); Release Memory
      EndWith
    EndIf
  EndProcedure
  
  ;#End Region
  
  ;#Region Properties
  ;- Properties 
  
  Procedure.l Get_State(*This.sWebSocket)
    ProcedureReturn *This\state
  EndProcedure
  
  Procedure Set_KeepAliveInterval(*This.sWebSocket, interval.l)
    *This\KeepAliveInterval = interval
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
  
  ;#End Region
  
  ;#Region Add Event Handler Methods
  ;- Add Event Handler Methods
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
  
  ;#End Region
  
  ;#Region Definition public methods
  ;- definition public methods
  
  Procedure Disconnect(*This.sWebSocket)
    ;TODO:
  EndProcedure
  
  Procedure Connect(*This.sWebSocket)
    Define threadID.i
    Define msec.l
    threadID = CreateThread(@_Connect_Task(), *This)
    With *This
      
      dbg("Starting tasks.")  
      _StartListener(*This)
      _StartSender(*This)
      
      While IsThread(threadID) And \State <> Net::#WebSocketState_Open And msec < \TimeOut
        msec + 1
        Delay(1)
      Wend
      
      ProcedureReturn \State
    EndWith
  EndProcedure
  
  Structure _sSendParam
    *this.sWebSocket
    message.s
  EndStructure
  
  Procedure SendArray(*This.sWebSocket, Array message.a(1))
    ;TODO
  EndProcedure
  
  Procedure Send(*This.sWebSocket, message.s)
    Protected *Param._sSendParam
    
    *Param = AllocateStructure(_sSendParam)
    *Param\message = message
    *Param\this = *This
    
    With *This
      dbg("Adding item to send queue")
      
      *this\SendTaskID = CreateThread(@_Send_Task(),*Param)
    EndWith
  EndProcedure
  
  ;#End Region
    
  ;#Region Definition Private Methods
  ;- Definition Private Methods
  
  Procedure _Connect_Task(*This.sWebSocket)
    Define *ProxyUri.Net::sUri
    With *This      
      ;InitNetwork()
      If \Uri\Scheme = "wss" ; If we connect with encryption (https)
        *ProxyUri = \options\Get_ProxyUri()
        If *ProxyUri\OriginalString 
          \ConnectionID = OpenNetworkConnection(*ProxyUri\Host, *ProxyUri\Port, #PB_Network_TCP, \TimeOut)
        Else
          dbg("We need an SSL-Proxy like stunnel for encryption. Configure a proxy")
        EndIf
      ElseIf \Uri\Scheme = "ws"
        \ConnectionID = OpenNetworkConnection(\Uri\Host, \Uri\Port, #PB_Network_TCP, \TimeOut)
      EndIf
      
      If \ConnectionID 
        \State = Net::#WebSocketState_Connecting
        
        If _Handshake(*This)
          dbg("Connection and Handshake ok")
          \State = Net::#WebSocketState_Open
          ProcedureReturn
        Else
          dbg("Handshake-Error")
          CloseNetworkConnection(\ConnectionID)
          \ConnectionID = 0
          \State = Net::#WebSocketState_Aborted
          ProcedureReturn
        EndIf
      Else
        dbg("Couldn't connect")
        \State = Net::#WebSocketState_Aborted
        ProcedureReturn
      EndIf
    EndWith
  EndProcedure
  
  Procedure _Send_Task(*Param._sSendParam)
    Protected msg.sRequestMessage
    With *Param\this
      ;TODO
    EndWith
  EndProcedure
  
  Procedure _SendFrame(*This.sWebSocket, Array buffer.a(1), messageType.l, messageFlags.l)
    ;TODO:
  EndProcedure
   
  Procedure _Abort(*This.sWebSocket)
    With *This
      dbg("Abort Websocket connection")
      CloseNetworkConnection(\ConnectionID)
      \State = Net::#WebSocketState_Aborted
    EndWith
  EndProcedure
  
  Procedure _Close(*This.sWebSocket, closeStatus.l, statusDescription.s)
    With *This
      dbg("Close Websocket connection")
      ;TODO: Sending The Close frame
      CloseNetworkConnection(\ConnectionID)
      \State = Net::#WebSocketState_Closed     
    EndWith
  EndProcedure
  
  Procedure _StartMonitor(*This.sWebSocket)
    With *this
      dbg("Starting monitor.")
      \MonitorTaskId = CreateThread(@_StartMonitor_Task(), *This)
    EndWith
  EndProcedure
  
  Procedure _StartMonitor_Task(*This.sWebSocket)
    Protected  lastState
    With *this
      \MonitorRunning = #True
      \reconnectNeeded = #False
      While (Not \disposeCalled)
        If lastState = \State
          Delay(200)
          Continue
        EndIf
        
        If \Reconnecting
          
          ; When the reconnection is made, we must not trigger a status change too quickly.
          Delay(4000)
          If \Reconnecting
            Delay(3000)
            If Not \Reconnecting : ProcedureReturn : EndIf
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
          OnStateChanged = \OnStateChanged 
          OnStateChanged(*This, \State, lastState)
        EndIf
        
        If \State = Net::#WebSocketState_Open
          If \OnOpened 
            OnOpened = \OnOpened
            OnOpened(*This)
          EndIf
        EndIf
        
        If (\State = Net::#WebSocketState_Closed Or \State = Net::#WebSocketState_Aborted) And Not \Reconnecting
          If lastState = Net::#WebSocketState_Open And Not \disconnectCalled And \AutoReconnect
            dbg("Reconnect needed.")
            ; Exit the loop and start async reconnect
            \reconnectNeeded = #True
            Break
          EndIf
          If \OnClosed 
            OnClosed = \OnClosed
            If \CloseStatus
              OnClosed(*This, \CloseStatus)
            Else
              OnClosed(*This, Net::#WebSocketCloseStatus_Empty)
            EndIf
          EndIf
          If  \CloseStatus And \CloseStatus <> Net::#WebSocketCloseStatus_NormalClosure
            If \OnError
              OnError = \OnError
              OnError(*This, \CloseStatus)
            EndIf
          EndIf
        EndIf
        lastState = \State
      Wend
      \MonitorRunning = #False
      dbg("Exiting monitor")
      If (\AutoReconnect And \reconnectNeeded And Not \reconnecting And Not \disconnectCalled)
        
        _DoReconnect(*This);
      EndIf
    EndWith
  EndProcedure
  
  Procedure _DoReconnect(*This.sWebSocket)
    With *This
      dbg("Entered reconnect.")
      \ReconnectTaskId = CreateThread(@_DoReconnect_Task(), *This)
    EndWith
  EndProcedure
  
  Procedure _DoReconnect_Task(*This.sWebSocket)
    Define msec.l
    Define connected.b
    Define threadID.i
    
    With *This
      \Reconnecting = #True
      msec = 0
      While (IsThread(\MonitorTaskId) Or IsThread(\ListenerTaskId) Or IsThread(\SenderTaskId)) And msec < 15000       
        msec + 1
        Delay(1)
      Wend
      
      If (IsThread(\MonitorTaskId) Or IsThread(\ListenerTaskId) Or IsThread(\SenderTaskId))
        dbg("Reconnect fatality, tasks failed to stop before the timeout.")
        ; exit everything As dead...
        If \OnFatality 
          OnFatality = \OnFatality
          OnFatality(*This, "Fatal network error. Network services fail to shut down.")
        EndIf
        \reconnecting = #False
        \disconnectCalled = #True
        ProcedureReturn          
      EndIf
      
      dbg("closing of current websocket.")
      CloseNetworkConnection(\ConnectionID)
      \ConnectionID = 0
      \State = Net::#WebSocketState_Aborted
      
      If \OnStateChanged
        OnStateChanged = \OnStateChanged
        OnStateChanged(*This, Net::#WebSocketState_Connecting, Net::#WebSocketState_Aborted)
      EndIf
      
      connected = #False
      While (Not \disconnectCalled And Not \disposeCalled And Not connected)
        dbg("Creating new websocket.")
        
        If (Not \MonitorRunning)
          
          dbg("Starting monitor.")
          _StartMonitor(*This)                  
        EndIf
        
        dbg("Attempting connect.")
        msec = 0
        threadID = CreateThread(@_Connect_Task(), *This)
        While IsThread(threadID) And \State <> Net::#WebSocketState_Open And msec < \TimeOut
          msec + 1
          Delay(1)
        Wend
        If Not IsThread(ThreadId) And \State = Net::#WebSocketState_Open 
          connected = #True 
        EndIf 
        dbg("Connect result: " + Str(connected))                               
        If Not connected
          dbg("Reconnection failed")
          CloseNetworkConnection(\ConnectionID)
          \ConnectionID = 0
          \State = Net::#WebSocketState_Aborted
          ; exit everything As dead...
          If \OnFatality 
            OnFatality = \OnFatality
            OnFatality(*This, "Fatal network error. reconnect failed.")
          EndIf
          \reconnectNeeded = #False
          \reconnecting = #False
          \disconnectCalled = #True
          ProcedureReturn 
        EndIf
      Wend
    EndWith
  EndProcedure
  
   
  Procedure _StartListener(*This.sWebSocket)
    With *This
      dbg("Starting listener.")
      \ListenerTaskId = CreateThread(@_StartListener_Task(), *This)
    EndWith
  EndProcedure
  
  Procedure _StartListener_Task(*This.sWebSocket)
    Define message.s
    Dim binary.a(0)
    Dim buffer.a(0)
    Define res.Net::sWebSocketReceiveResult
    Dim exactDataBuffer.a(0)
    Dim binaryData.a(0)
    
    With *this
      dbg("Entering listener loop.")
      \listenerRunning = #True
      While (\State = Net::#WebSocketState_Open And Not \disposeCalled And Not \reconnecting)
        message = #Empty$
        FreeArray(binary())
        ReadNWData:
        
        FreeArray(buffer())
        ResetStructure(@res, Net::sWebSocketReceiveResult)
        
        If Not _Receive(*this, buffer(), @res)
          \reconnectNeeded = #True
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
            message + PBExt::ASCIIArray_ToString(buffer(), #PB_UTF8)
            Goto ReadNWData
          EndIf
          message + PBExt::ASCIIArray_ToString(buffer(), #PB_UTF8)
          
          ; support ping/pong if initiated by the server (see RFC 6455)
          If message = "ping"
            Send(*this, "pong")
          Else
            dbg("Message fully received:")
            If \OnMessage
              OnMessage = \OnMessage
              OnMessage(*This, message)
            EndIf
          EndIf
        Else
          ReDim exactDataBuffer(res\Count)
          CopyArray(buffer(), exactDataBuffer())
          
          If Not res\EndOfMessage
            PBExt::ASCIIArray_AddRange(binary(), exactDataBuffer())
            Goto ReadNWData
          EndIf
          
          PBExt::ASCIIArray_AddRange(binary(), exactDataBuffer())
          CopyArray(binary(), binaryData())
          
          dbg("Binary fully received:")
          If \OnData
            OnData = \OnData
            OnData(*This, binaryData())
          EndIf
          
          FreeArray(Buffer())
        EndIf
      Wend
      
      \ListenerRunning = #False
      dbg("Listener exiting")
    EndWith
  EndProcedure
  
  Procedure _ApplyMasking(Array Mask.a(1), *Buffer)
    Define i.i
    For i = 0 To MemorySize(*Buffer) - 1
      PokeA(*Buffer + i, PeekA(*Buffer + i) ! Mask(i % 4))
    Next
  EndProcedure
  
  ;<comment>
  ;  <summary>Empfängt Daten aus einem verbundenen Socket</summary>
  ;  <param>*This: Pointer auf die Instanz der Klasse WebSocket</param>
  ;  <param>*Message: Der Puffer für die empfangenen Daten.</param>
  ;  <param>*res: Pointer auf eine sWebSocketReceiveResult Strukture</param>
  ;  <example>_Receive(*This, *buffer, @WebSocketReceiveResult)</example>
  ;</comment>
  Procedure _Receive(*This.sWebSocket, Array buffer.a(1), *res.Net::sWebSocketReceiveResult)
    Define fragmentation.b
    Define frame_size.l
    Define pos.l
    Define masking.b
    Define ReceivedBytes.l
    Define BufferIncrease.l = 4096
    Define BufferSize.l = 0
    Define *FrameBuffer = AllocateMemory(BufferIncrease)
    
    With *this
      
      Repeat
        BufferSize + BufferIncrease
        *FrameBuffer = ReAllocateMemory(*FrameBuffer, BufferSize)
        ReceivedBytes = ReceiveNetworkData(\ConnectionID, *FrameBuffer, BufferIncrease)
        ;InData.s = InData.s + PeekS(*FrameBuffer, ReceivedBytes, #PB_UTF8)
      Until ReceivedBytes < BufferIncrease
      
      BufferSize - ReceivedBytes
      dbg("Received Bytes: " + Str(BufferSize))
      
      *FrameBuffer = ReAllocateMemory(*FrameBuffer, BufferSize)
      
      ;     ; debug: output any single byte
      ;     If #PB_Compiler_Debugger
      ;       For x = 0 To Size - 1 Step 1
      ;         dbg_bytes.s + Str(PeekA(*FrameBuffer + x)) + " | "
      ;       Next
      ;       dbg(dbg_bytes)
      ;     EndIf
      
      ; Getting informations about package
      If PeekA(*FrameBuffer) & %10000000 > #False ; FIN <> 1
                                                  ;dbg("Frame not fragmented")
        fragmentation = #False
      Else ; FIN = 0
        dbg("Frame fragmented! This not supported for now!")
        fragmentation = #True
        *res\EndOfMessage = #False
      EndIf
      
      ; Check for Opcodes
      If PeekA(*FrameBuffer) = %10000001 ; Textframe
        dbg("Text frame")
        *res\MessageType = Net::#WebSocketMessageType_Text
        *res\EndOfMessage = #True
      ElseIf PeekA(*FrameBuffer) = %10000010 ; Binary Frame
        dbg("Binary frame")
        *res\MessageType = Net::#WebSocketMessageType_binary
        *res\EndOfMessage = #True
      ElseIf PeekA(*FrameBuffer) = %10001000 ; Closing Frame
        dbg("Closing frame")
        *res\MessageType = Net::#WebSocketMessageType_Close
        *res\EndOfMessage = #True
      ElseIf PeekA(*FrameBuffer) = %10001001 ; Ping
        dbg("Received Ping")
        *res\MessageType = Net::#WebSocketMessageType_ping
        *res\EndOfMessage = #True
        ReDim buffer(BufferSize)
        CopyMemory(*FrameBuffer, @buffer(), BufferSize)
        *res\Count = BufferSize
        FreeMemory(*FrameBuffer)
        ProcedureReturn #True
      Else
        dbg("Opcode unknown")
        *res\MessageType = Net::#WebSocketMessageType_unknown
        ReDim buffer(BufferSize)
        CopyMemory(*FrameBuffer, @buffer(), BufferSize)
        *res\Count = BufferSize
        FreeMemory(*FrameBuffer)
        ProcedureReturn #False
      EndIf
      
      ; Check masking
      If PeekA(*FrameBuffer + 1) & %10000000 = 128 : masking = #True : Else : masking = #False : EndIf
      
      dbg("Masking: " + Str(masking))
      
      pos = 1
      
      ; check size
      If PeekA(*FrameBuffer + 1) & %01111111 <= 125 ; size is in this byte
        frame_size = PeekA(*FrameBuffer + pos) & %01111111 : pos + 1
      ElseIf PeekA(*FrameBuffer + 1) & %01111111 >= 126 ; Size is in 2 extra bytes
        frame_size = PeekA(*FrameBuffer + 2) << 8 + PeekA(*FrameBuffer + 3) : pos + 2
      EndIf
      dbg("FrameSize: " + Str(frame_size))
      
      If masking = #True
        *res\MessageType = Net::#WebSocketMessageType_invalid ; all messages from the server to the client MUST NOT be masked !
        
        Dim Mask.a(3)
        Mask(0) = PeekA(*FrameBuffer + pos) : pos + 1
        Mask(1) = PeekA(*FrameBuffer + pos) : pos + 1
        Mask(2) = PeekA(*FrameBuffer + pos) : pos + 1
        Mask(3) = PeekA(*FrameBuffer + pos) : pos + 1
        
        ReDim buffer(frame_size)
        
        CopyMemory(*FrameBuffer + pos, @buffer(), frame_size)
        *res\Count = frame_size
        
        _ApplyMasking(Mask(), @buffer())
        
        FreeArray(Mask())
        
      Else
        ReDim buffer(frame_size+1)
        CopyMemory(*FrameBuffer + pos, @buffer(), frame_size)
        *res\Count = frame_size
      EndIf
      
      FreeMemory(*FrameBuffer)
      ProcedureReturn #True
    EndWith
  EndProcedure
  
  
  Procedure _StartSender(*This.sWebSocket)
    With *This
      dbg("Starting Sender.")
      \SenderTaskId = CreateThread(@_StartSender_Task(), *This)
    EndWith
  EndProcedure
  
  Procedure _StartSender_Task(*This.sWebSocket)
    Define *msg.sRequestMessage
    Dim buffer.a(0)
    Define msgType.l
    
    With *this
      \SenderRunning = #True
      While (Not \disposeCalled And Not \reconnecting)
        If (\State = Net::#WebSocketState_Open And Not \Reconnecting)
          
          *msg = LastElement(\sendQueue());
          ReDim buffer(ArraySize(*msg\aData()))
          CopyArray(*msg\aData(), buffer())                            
          
          dbg("Sending message:");
          msgType = *msg\MessageType 
          If msgType <> Net::#WebSocketMessageType_Text : msgType = Net::#WebSocketMessageType_Binary: EndIf
          If Not _SendFrame(*this, buffer(), msgType, #True)
            
            If \OnSendFailed
              OnSendFailed = \OnSendFailed
              OnSendFailed(*This, buffer(), *This\LastError)
            EndIf
            \reconnectNeeded = #True;
            _Abort(*This)           ;
            Break                   ;
          EndIf
        EndIf
        
        ; limit To N ms per iteration
        Delay(\options\Get_SendDelay());
      Wend
      \senderRunning = #False
    EndWith
  EndProcedure
  
  Procedure _Handshake(*This.sWebSocket)
    NewList Headers.Net::sRequestHeader()
    NewList SubProtocols.s()
    Define Request.s
    Define AddStr.s
    Define Size.i
    Define Answer.s
    Define *Buffer
    
    With *This
      Request = "GET /" + \Uri\AbsolutePath + " HTTP/1.1"+ #CRLF$ +
                "Host: " + \Uri\Host + #CRLF$ +
                "Upgrade: websocket" + #CRLF$ +
                "Connection: Upgrade" + #CRLF$ +
                "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" + #CRLF$ +
                "Sec-WebSocket-Version: 13" + #CRLF$ + #CRLF$
      
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
      EndIf
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
  
  Procedure _WaitForTaskEnd(TaskId)
    Protected wait.l
    
    While IsThread(TaskId) And wait < 1000
      Delay(1)
      wait + 1
    Wend
    If IsThread(TaskId) : KillThread(TaskID): EndIf
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
  
  ;#End Region
  
  ;#Region Virtual Table
  ;- Handling virtual table
    
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
      ; TODO: Out Of Memory!
      End 
    EndIf
  EndProcedure : InitVT() ; initialize virtual table
  
  ; Property to Get Address of vTable (for inheritance)
  Procedure GetVT()
    ProcedureReturn *vtWebSocket
  EndProcedure
  
  ;#End Region
  
EndModule