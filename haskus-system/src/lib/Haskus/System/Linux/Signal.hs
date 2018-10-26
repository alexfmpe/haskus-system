{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TypeApplications #-}

-- | Linux signals
module Haskus.System.Linux.Signal
   ( SignalSet(..)
   , ChangeSignals(..)
   , sysPause
   , sysAlarm
   , sysSendSignal
   , sysSendSignalGroup
   , sysSendSignalAll
   , sysCheckProcess
   , sysChangeSignalMask
   )
where

import Haskus.System.Linux.ErrorCode
import Haskus.System.Linux.Syscalls
import Haskus.System.Linux.Process
import Haskus.Format.Binary.Vector (Vector)
import Haskus.Format.Binary.Word
import Haskus.Format.Binary.Ptr
import Haskus.Format.Binary.Storable
import Haskus.Utils.Flow
import Haskus.Utils.Memory

-- | Signal set
newtype SignalSet = SignalSet (Vector 16 Word64) deriving (Storable)

-- | Pause
sysPause :: MonadIO m => Flow m '[(),ErrorCode]
sysPause = liftIO (syscall_pause) ||> toErrorCodeVoid

-- | Alarm
sysAlarm :: MonadIO m => Word-> Flow m '[Word,ErrorCode]
sysAlarm seconds = liftIO (syscall_alarm seconds)
   ||> toErrorCodePure fromIntegral

-- | Kill syscall
sysSendSignal :: MonadIO m => ProcessID -> Int -> Flow m '[(),ErrorCode]
sysSendSignal (ProcessID pid) sig =
   liftIO (syscall_kill (fromIntegral pid) sig)
      ||> toErrorCodeVoid

-- | Send a signal to every process in the process group of the calling process
sysSendSignalGroup :: MonadIO m => Int -> Flow m '[(),ErrorCode]
sysSendSignalGroup sig =
   liftIO (syscall_kill 0 sig)
      ||> toErrorCodeVoid

-- | Send a signal to every process for which the calling process has permission to send signals, except for process 1 (init)
sysSendSignalAll :: MonadIO m => Int -> Flow m '[(),ErrorCode]
sysSendSignalAll sig =
   liftIO (syscall_kill (-1) sig)
      ||> toErrorCodeVoid

-- | Check if a given process or process group exists
--
-- Send signal "0" the given process
sysCheckProcess :: MonadIO m => ProcessID -> Flow m '[Bool,ErrorCode]
sysCheckProcess pid = sysSendSignal pid 0
   >.-.> const True
   >%~$> \case
      ESRCH -> flowSet False
      e     -> flowSet e

-- | Signal actions
data ChangeSignals
   = BlockSignals    -- ^ Block signals in the set
   | UnblockSignals  -- ^ Unblock signals in the set
   | SetSignals      -- ^ Set blocked signals to the set
   deriving (Show,Eq,Enum)

-- | Change signal mask
sysChangeSignalMask :: MonadInIO m => ChangeSignals -> Maybe SignalSet -> Flow m '[SignalSet,ErrorCode]
sysChangeSignalMask act set =
   withMaybeOrNull set $ \x ->
      alloca $ \(ret :: Ptr SignalSet) ->
         liftIO (syscall_rt_sigprocmask (fromEnum act) (castPtr x) (castPtr ret))
            ||>   toErrorCode
            >.~.> (const $ peek ret)
