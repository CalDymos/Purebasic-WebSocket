;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* Module     : Net.pbi - Provides structures, enumerations, and methods for easier programming 
;*                        For many protocols currently used in networks.
;* Created    : 10.10.2023
;* Author     : Cal Dymos
;* Contacts   : {Contact}
;* Copyright  : Byte Ranger Software
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *


DeclareModule Net
   
  ;- --------------------------------------------------------------------------
  ;-   Public Enums
  ;- --------------------------------------------------------------------------  
  
  ;Represents known WebSocket codes For locking operations As defined in Section 11.7 of the WebSocket protocol specification.
  Enumeration WebSocketCloseStatus
    #WebSocketCloseStatus_Empty = 1005 ;No error specified.
    #WebSocketCloseStatus_EndpointUnavailable = 1001 ;Indicates an endpoint is being removed. Either the server Or client will become unavailable.
    #WebSocketCloseStatus_InternalServerError = 1011 ;The connection will be closed by the server because of an error on the server.
    #WebSocketCloseStatus_InvalidMessageType = 1003  ;The client Or server is terminating the connection because it cannot accept the Data type it received.
    #WebSocketCloseStatus_InvalidPayloadData = 1007  ;The client Or server is terminating the connection because it has received Data inconsistent With the message type.
    #WebSocketCloseStatus_MandatoryExtension = 1010  ;The client is terminating the connection because it expected the server To negotiate an extension.
    #WebSocketCloseStatus_MessageTooBig = 1009       ;The client Or server is terminating the connection because it has received a message that is too big For it To process.
    #WebSocketCloseStatus_NormalClosure = 1000       ;The connection has closed after the request was fulfilled.
    #WebSocketCloseStatus_PolicyViolation = 1008     ;The connection will be closed because an endpoint has received a message that violates its policy.
    #WebSocketCloseStatus_ProtocolError =	1002       ;The client Or server is terminating the connection because of a protocol error.
    
  EndEnumeration
  
  ; State codes for WebSocket connection.
  Enumeration WebSocketState
    #WebSocketState_None = 0
    #WebSocketState_Connecting = 1
    #WebSocketState_Open = 2
    #WebSocketState_CloseSent = 3
    #WebSocketState_CloseReceived = 4
    #WebSocketState_Closed = 5
    #WebSocketState_Aborted = 6
  EndEnumeration
  
  ; Specifies the type of the Websocket message
  Enumeration WebSocketMessageType
    #WebSocketMessageType_Text
    #WebSocketMessageType_Binary
    #WebSocketMessageType_Close
    #WebSocketMessageType_Unknown
    #WebSocketMessageType_Invalid
    #WebSocketMessageType_Ping
    #WebSocketMessageType_Pong
  EndEnumeration
  
  ;- --------------------------------------------------------------------------
  ;-   Public Structure
  ;- --------------------------------------------------------------------------  
    
  Structure sUri
    OriginalString.s
    Scheme.s
    AbsolutePath.s
    AbsoluteUri.s
    Host.s
    Port.l
    Query.s
    UserInfo.s
  EndStructure
  
  Structure sWebProxy
    uri.sUri
    Username.s
    Password.s
  EndStructure
  
  Structure sRequestHeader
    headerName.s
    headerValue.s
  EndStructure
  
  Structure sWebSocketReceiveResult
    Count.i
    EndOfMessage.b
    MessageType.l ; .WebSocketMessageType
  EndStructure
  
  ;- --------------------------------------------------------------------------
  ;-   Declaration Public Methods
  ;- --------------------------------------------------------------------------
    
  Declare SetUri(UriString.s, *Uri.sUri)
EndDeclareModule

Module Net
  
  ;- --------------------------------------------------------------------------
  ;-   Public Methods
  ;- --------------------------------------------------------------------------  
  
  ;<comment>
  ;  <summary>Represents the structure of a URI (Uniform Resource Identifier) <br>to get easy access to the parts of the URI.</summary>
  ;  <param><b>UriString</b>: Uri String</param>
  ;  <param><b>*Uri</b>: Pointer auf eine 'sUri' Structure.</param>
  ;  <return>no return value</return>
  ;  <example>Net::SetUri("http://admin:1234@www.testserver.com:7780", @Uri)</example>
  ;</comment>
  Procedure SetUri(UriString.s, *Uri.sUri)
    With *Uri
      \OriginalString = uriString
      \AbsoluteUri = URLEncoder(uriString)
      \Port = Val(GetURLPart(uriString, #PB_URL_Port))
      If \Port = 0 : \Port = 80 : EndIf
      \Scheme = GetURLPart(uriString, #PB_URL_Protocol)
      \AbsolutePath = GetURLPart(uriString, #PB_URL_Path)  
      \Host = GetURLPart(uriString, #PB_URL_Site)
      \Query = GetURLPart(uriString, #PB_URL_Parameters)
      \UserInfo = GetURLPart(uriString, #PB_URL_User) 
      If \UserInfo <> "" : \UserInfo + ":" + GetURLPart(uriString, #PB_URL_Password) : EndIf
      If \UserInfo = ":" : \UserInfo = "" : EndIf
    EndWith
  EndProcedure
EndModule
