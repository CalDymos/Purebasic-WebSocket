;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* Module     : Thread.pbi - Modul to control a Thread
;* Created    : 17.10.2023
;* Author     : Cal Dymos
;* Contacts   : {Contact}
;* Copyright  : Byte Ranger Software
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

CompilerIf Not #PB_Compiler_Thread
  CompilerError "Compiler-Option ThreadSafe is needed!"
CompilerEndIf

DeclareModule Thread
  
  ;- --------------------------------------------------------------------------
  ;-   Public Structure
  ;- --------------------------------------------------------------------------  
  
  Structure sThreadCtrl 
    ID.i
    Mutex.i
    UserID.i
    Signal.i
    Suspend.i
    Abort.i
    *AddData
  EndStructure

  ;- --------------------------------------------------------------------------
  ;-   Declaration Public Methods
  ;- --------------------------------------------------------------------------
  
  Declare Start(*Thread.sThreadCtrl, *Procedure, *AddData)
  Declare Abort(*Thread.sThreadCtrl, Wait=1000)
  Declare Suspend(*Thread.sThreadCtrl)
  Declare Resume(*Thread.sThreadCtrl)
  Declare GetState(*Thread.sThreadCtrl)
  Declare Finalize(*Thread.sThreadCtrl, Abort=#True, Wait=1000)
  
EndDeclareModule  

Module Thread
  
  EnableExplicit
  
  ;- --------------------------------------------------------------------------
  ;-   Private Structures and Vars
  ;- --------------------------------------------------------------------------
  Enumeration ThreadState
    #ThreadState_Running = 0
    #ThreadState_Suspended = 64
    #ThreadState_AbortRequested = 128
  EndEnumeration
    
  ;- --------------------------------------------------------------------------
  ;-   Public Methods
  ;- --------------------------------------------------------------------------  
  
  ;<comment>
  ;  <summary>Creates a new thread.</summary>
  ;  <param><b>*Thread</b>: Pointer to a 'sThreadCtrl' Structure, must always be created with AllocateStructure.</param>
  ;  <param><b>*Procedure</b>: The address of the procedure you want to use as new thread.</param>
  ;  <param><b>*AddData</b>: Pointer to an additional data structure.</param>
  ;  <return>The result is zero if the thread was successfully created or already exists.</return>
  ;  <example>Thread::Start(*Thread, @MyThreadProc(), *Data)</example>
  ;</comment>
  Procedure Start(*Thread.sThreadCtrl, *Procedure, *AddData)
    Define ThreadID
    
    If Not IsThread(*Thread\ID)
      *Thread\AddData = *AddData
      *Thread\ID      = CreateThread(*Procedure, *Thread)  
      *Thread\Mutex = CreateMutex()
    Else
      ThreadID = *Thread\ID
    EndIf
    
    ProcedureReturn ThreadID
  EndProcedure
    
  ;<comment>
  ;  <summary>Aborts an existing thread. If the thread is suspended, it will be resumed before with a signal.</summary>
  ;  <param><b>*Thread</b>: Pointer to a 'sThreadCtrl' Structure.</param>
  ;  <param><i>Optional</i> <b>Wait</b>: How long [ms] to wait for the thread to finish, before killing it</param>
  ;  <return>no return value</return>
  ;  <example>Thread::Abort(*Thread, 15000)</example>
  ;</comment>
  Procedure Abort(*Thread.sThreadCtrl, Wait.i=1000)
          
      If IsThread(*Thread\ID)
        
        LockMutex(*Thread\Mutex)
        
        *Thread\Abort = #True
        
        If *Thread\Suspend
          *Thread\Suspend = #False
          SignalSemaphore(*Thread\Signal)
        EndIf
        
        If WaitThread(*Thread\ID, Wait) = 0 : KillThread(*Thread\ID) : EndIf
        
        *Thread\ID      = #False
        *Thread\Suspend = #False
        *Thread\Abort   = #False
        
        If *Thread\Signal
          FreeSemaphore(*Thread\Signal)
          *Thread\Signal = #False
        EndIf
        
        UnlockMutex(*Thread\Mutex)
        
      EndIf   
    
  EndProcedure
  
  ;<comment>
  ;  <summary>Suspend the thread. For this a semaphore is created on which the thread can wait.</summary>
  ;  <param><b>*Thread</b>: Pointer to a 'sThreadCtrl' Structure.</param>
  ;  <return>no return value</return>
  ;  <example>Thread::Suspend(*Thread)</example>
  ;</comment>
  Procedure Suspend(*Thread.sThreadCtrl)
       
      If IsThread(*Thread\ID)
                
        LockMutex(*Thread\Mutex)
        
        If Not *Thread\Signal : *Thread\Signal = CreateSemaphore() : EndIf
        
        If Not *Thread\Suspend : *Thread\Suspend = #True : EndIf
        
        UnlockMutex(*Thread\Mutex)
              
    EndIf 
    
  EndProcedure
  
  ;<comment>
  ;  <summary>Resumes the thread if it was suspended. For this purpose a signal is triggered via semaphore.</summary>
  ;  <param><b>*Thread</b>: Pointer to a 'sThreadCtrl' Structure.</param>
  ;  <return>no return value</return>
  ;  <example>Thread::Resume(*Thread)</example>
  ;</comment>
  Procedure Resume(*Thread.sThreadCtrl)


      
      If IsThread(*Thread\ID)
                
        LockMutex(*Thread\Mutex)
        
        If *Thread\Suspend
          *Thread\Suspend = #False
          SignalSemaphore(*Thread\Signal)
        EndIf
        
        UnlockMutex(*Thread\Mutex)
        
    EndIf
    
  EndProcedure
  
  ;<comment>
  ;  <summary>Get status code of a thread</summary>
  ;  <param><b>*Thread</b>: Pointer to a 'sThreadCtrl' Structure.</param>
  ;  <return>Status code of the thread</return>
  ;  <example>ThreadState = Thread::GetState(*Thread)</example>
  ;</comment>
  Procedure GetState(*Thread.sThreadCtrl)
      
      If IsThread(*Thread\ID)
                
        LockMutex(*Thread\Mutex)
        
        If *Thread\Suspend
          ProcedureReturn #ThreadState_Suspended
        ElseIf Not *Thread\Suspend
          ProcedureReturn #ThreadState_Running
        ElseIf *Thread\Abort
          ProcedureReturn #ThreadState_AbortRequested
        EndIf
        
        UnlockMutex(*Thread\Mutex)
        
      EndIf
    
  EndProcedure  
  
  ;<comment>
  ;  <summary>Frees the memory for the thread. If this is still running, it is stopped first.</summary>
  ;  <param><b>*Thread</b>: Pointer to a 'sThreadCtrl' Structure.</param>
  ;  <param><i>Optional</i> <b>Abort</b>: Specifies whether the thread should be aborted before</param>
  ;  <param><i>Optional</i> <b>Wait</b>: How long [ms] to wait for the thread to finish, before killing it</param>
  ;  <return>returns true if successful, false otherwise</return>
  ;  <example>Thread::Finalize(*Thread, #True, 15000)</example>
  ;</comment>
  Procedure Finalize(*Thread.sThreadCtrl, Abort=#True, Wait=1000)
                  
      LockMutex(*Thread\Mutex)
      
      If IsThread(*Thread\ID)
        
        If Abort
          Abort(*Thread, Wait)
          UnlockMutex(*Thread\Mutex)
          FreeMutex(*Thread\Mutex)
          FreeStructure(*Thread)
          ProcedureReturn #True
        Else
          UnlockMutex(*Thread\Mutex)
          ProcedureReturn #False
        EndIf
        
      Else
        
        If *Thread\Signal
          FreeSemaphore(*Thread\Signal)
        EndIf
        UnlockMutex(*Thread\Mutex)
        FreeMutex(*Thread\Mutex)
        FreeStructure(*Thread)
        
        ProcedureReturn #True
      EndIf
    
  EndProcedure 
  
EndModule