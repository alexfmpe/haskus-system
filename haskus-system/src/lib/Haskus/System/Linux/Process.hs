{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

-- | Process management
module Haskus.System.Linux.Process
   ( ProcessID(..)
   , ThreadID(..)
   , UserID(..)
   , GroupID(..)
   , SessionID(..)
   , sysExit
   , sysGetCPU
   , sysGetProcessID
   , sysGetParentProcessID
   , sysGetRealUserID
   , sysGetEffectiveUserID
   , sysSetEffectiveUserID
   , sysGetRealGroupID
   , sysGetEffectiveGroupID
   , sysSetEffectiveGroupID
   , sysGetThreadID
   , sysFork
   , sysVFork
   , sysSchedulerYield
   )
where

import Haskus.Format.Binary.Ptr (Ptr, nullPtr)
import Haskus.Format.Binary.Word
import Haskus.Format.Binary.Storable
import Haskus.System.Linux.Syscalls
import Haskus.System.Linux.ErrorCode
import Haskus.Utils.Flow

-- | Process ID
newtype ProcessID = ProcessID Word32 deriving (Show,Eq,Ord,Storable)

-- | Thread ID
newtype ThreadID = ThreadID Word32 deriving (Show,Eq,Ord,Storable)

-- | User ID
newtype UserID = UserID Word32 deriving (Show,Eq,Ord,Storable)

-- | Group ID
newtype GroupID = GroupID Word32 deriving (Show,Eq,Ord,Storable)

-- | Session ID
newtype SessionID = SessionID Word32 deriving (Show,Eq,Ord,Storable)

-- | Exit the current process with the given return value
-- This syscall does not return.
sysExit :: Int64 -> IO ()
sysExit n = void (syscall_exit n)

-- | Get CPU and NUMA node executing the current process
sysGetCPU :: MonadInIO m => Flow m '[(Word,Word),ErrorCode]
sysGetCPU =
   alloca $ \cpu ->
      alloca $ \node ->
         liftIO (syscall_getcpu (cpu :: Ptr Word) (node :: Ptr Word) nullPtr)
            ||>   toErrorCode
            >.~.> (const ((,) <$> peek cpu <*> peek node))

-- | Return process ID
sysGetProcessID :: IO ProcessID
sysGetProcessID = ProcessID . fromIntegral <$> syscall_getpid

-- | Return thread ID
sysGetThreadID :: IO ThreadID
sysGetThreadID = ThreadID . fromIntegral <$> syscall_gettid

-- | Return parent process ID
sysGetParentProcessID :: IO ProcessID
sysGetParentProcessID = ProcessID . fromIntegral <$> syscall_getppid

-- | Get real user ID of the calling process
sysGetRealUserID :: IO UserID
sysGetRealUserID = UserID . fromIntegral <$> syscall_getuid

-- | Get effective user ID of the calling process
sysGetEffectiveUserID :: IO UserID
sysGetEffectiveUserID = UserID . fromIntegral <$> syscall_geteuid

-- | Set effective user ID of the calling process
sysSetEffectiveUserID :: MonadIO m => UserID -> Flow m '[(),ErrorCode]
sysSetEffectiveUserID (UserID uid) = liftIO (syscall_setuid uid)
   ||> toErrorCodeVoid

-- | Get real group ID of the calling process
sysGetRealGroupID :: IO GroupID
sysGetRealGroupID = GroupID . fromIntegral <$> syscall_getgid

-- | Get effective group ID of the calling process
sysGetEffectiveGroupID :: IO GroupID
sysGetEffectiveGroupID = GroupID . fromIntegral <$> syscall_getegid

-- | Set effective group ID of the calling process
sysSetEffectiveGroupID :: MonadIO m => GroupID -> Flow m '[(),ErrorCode]
sysSetEffectiveGroupID (GroupID gid) = liftIO (syscall_setgid gid)
   ||> toErrorCodeVoid

-- | Create a child process
sysFork :: MonadIO m => Flow m '[ProcessID,ErrorCode]
sysFork = liftIO (syscall_fork)
   ||> toErrorCodePure (ProcessID . fromIntegral)

-- | Create a child process and block parent
sysVFork :: MonadIO m => Flow m '[ProcessID,ErrorCode]
sysVFork = liftIO (syscall_vfork)
   ||> toErrorCodePure (ProcessID . fromIntegral)

-- | Yield the processor
sysSchedulerYield :: MonadIO m => Flow m '[(),ErrorCode]
sysSchedulerYield = liftIO (syscall_sched_yield) ||> toErrorCodeVoid

