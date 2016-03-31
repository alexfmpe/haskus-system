{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FunctionalDependencies #-}

-- | Heterogeneous list utils
module ViperVM.Utils.HList
   ( Tail
   , Head
   , ReplaceAt
   , RemoveAt
   , Concat
   , Length
   , MapMaybe
   , Generate
   , IsMember
   , IsSubset
   , Indexes
   , MapTest
   , Zip
   , Filter
   , Nub
   , NubHead
   , IndexOf
   , MaybeIndexOf
   , TypeAt
   , HFoldr' (..)
   , HTuple' (..)
   , Single (..)
   )
where

import Data.HList.FakePrelude (ApplyAB(..))
import Data.HList.HList
import Data.Proxy
import GHC.TypeLits

-- | Tail of a list
type family Tail xs where
   Tail (x ': xs) = xs

-- | Head of a list
type family Head xs where
   Head (x ': xs) = x

-- | Concat two type lists
type family Concat xs ys where
   Concat '[] '[]      = '[]
   Concat '[] ys       = ys
   Concat (x ': xs) ys = x ': Concat xs ys

-- | Get list length
type family Length xs where
   Length '[]       = 0
   Length (x ': xs) = 1 + Length xs

-- | replace l[n] with l2 (folded)
type family ReplaceAt (n :: Nat) l l2 where
   ReplaceAt 0 (x ': xs) ys = Concat ys xs
   ReplaceAt n (x ': xs) ys = x ': ReplaceAt (n-1) xs ys

-- | Remove a type at index
type family RemoveAt (n :: Nat) l where
   RemoveAt 0 (x ': xs) = xs
   RemoveAt n (x ': xs) = x ': RemoveAt (n-1) xs

-- | Apply Maybe to all the elements of the list
type family MapMaybe l where
   MapMaybe '[]       = '[]
   MapMaybe (x ': xs) = Maybe x ': MapMaybe xs

-- | Generate a list of Nat [n..m-1]
type family Generate (n :: Nat) (m :: Nat) where
   Generate n n = '[]
   Generate n m = Proxy n ': Generate (n+1) m

-- | Check that a type is member of a type list
type family IsMember a l :: Bool where
   IsMember a (a ': l) = 'True
   IsMember a (b ': l) = IsMember a l

-- | Check that a list is a subset of another
type family IsSubset l1 l2 :: Bool where
   IsSubset l1 l1 = 'True
   IsSubset l1 l2 = IsSubsetEx l1 l2 l2

type family IsSubsetEx l1 l2 i :: Bool where
   IsSubsetEx '[] l2 i = 'True
   IsSubsetEx l1 '[] i = 'False
   IsSubsetEx (x ': xs) (x ': ys) i = IsSubsetEx xs i i
   IsSubsetEx (x ': xs) (y ': ys) i = IsSubsetEx (x ': xs) ys i

-- | Get list indexes
type family Indexes (l :: [*]) where
   Indexes l = Generate 0 (Length l)

-- | Map to 1 if type equality, 0 otherwise
type family MapTest a (l :: [*]) where
   MapTest a '[]       = '[]
   MapTest a (a ': xs) = Proxy 1 ': MapTest a xs
   MapTest a (x ': xs) = Proxy 0 ': MapTest a xs

-- | Zip two lists
type family Zip (l :: [*]) (l2 :: [*]) where
   Zip '[] xs              = '[]
   Zip xs '[]              = '[]
   Zip (x ': xs) (y ': ys) = (x,y) ': Zip xs ys

-- | Remove `a` in `l`
type family Filter a (l :: [*]) where
   Filter a '[]       = '[]
   Filter a (a ': xs) = Filter a xs
   Filter a (x ': xs) = x ': Filter a xs

-- | Keep only a single value of each type
type family Nub (l :: [*]) where
   Nub '[]       = '[]
   Nub (x ': xs) = x ': Nub (Filter x xs)

-- | Keep only a single value of the head type
type family NubHead (l :: [*]) where
   NubHead '[]       = '[]
   NubHead (x ': xs) = x ': Filter x xs

-- | Get the first index of a type
type family IndexOf a (l :: [*]) where
   IndexOf x (x ': xs) = 0
   IndexOf y (x ': xs) = 1 + IndexOf y xs

-- | Get the first index (starting from 1) of a type or 0 if none
type family MaybeIndexOf a (l :: [*]) where
   MaybeIndexOf x xs = MaybeIndexOf' 0 x xs

type family MaybeIndexOf' (n :: Nat) a (l :: [*]) where
   MaybeIndexOf' n x '[]       = 0
   MaybeIndexOf' n x (x ': xs) = 1 + n
   MaybeIndexOf' n x (y ': xs) = MaybeIndexOf' (n+1) x xs

-- | Indexed access into the list
type family TypeAt (n :: Nat) (l :: [*]) where
   TypeAt 0 (x ': xs) = x
   TypeAt n (x ': xs) = TypeAt (n-1) xs


-- | Like HFoldr but only use types, not values!
--
-- It allows us to foldr over the list of types in the union and for each type
-- to retrieve the alignment and the size (from Storable).
class HFoldr' f v (l :: [*]) r where
   hFoldr' :: f -> v -> HList l -> r

instance (v ~ v') => HFoldr' f v '[] v' where
   hFoldr'       _ v _   = v

instance (ApplyAB f (e, r) r', HFoldr' f v l r) => HFoldr' f v (e ': l) r' where
   -- compared to hFoldr, we pass undefined values instead of the values
   -- supposedly in the list (we don't have a real list associated to HList l)
   hFoldr' f v _ = applyAB f (undefined :: e, hFoldr' f v (undefined :: HList l) :: r)



-- * Conversion to and from tuples (original HList only supports up to 6
-- elements)

class HTuple' v t | v -> t, t -> v where
    -- | alternatively: @hUncurry (,,,)@
    hToTuple' :: HList v -> t
    hFromTuple' :: t -> HList v

-- | @Iso (HList v) (HList v') a b@
--hTuple x = iso hToTuple hFromTuple x
--
---- | @Iso' (HList v) a@
--hTuple' x = simple (hTuple x)

instance HTuple' '[] () where
    hToTuple' HNil = ()
    hFromTuple' () = HNil

data Single a = Single a deriving (Show,Eq)

instance HTuple' '[a] (Single a) where
    hToTuple' (a `HCons` HNil) = Single a
    hFromTuple' (Single a) = (a `HCons` HNil)

instance HTuple' '[a,b] (a,b) where
    hToTuple' (a `HCons` b `HCons` HNil) = (a,b)
    hFromTuple' (a,b) = (a `HCons` b `HCons` HNil)

instance HTuple' '[a,b,c] (a,b,c) where
    hToTuple' (a `HCons` b `HCons` c `HCons` HNil) = (a,b,c)
    hFromTuple' (a,b,c) = (a `HCons` b `HCons` c `HCons` HNil)

instance HTuple' '[a,b,c,d] (a,b,c,d) where
    hToTuple' (a `HCons` b `HCons` c `HCons` d `HCons` HNil) = (a,b,c,d)
    hFromTuple' (a,b,c,d) = (a `HCons` b `HCons` c `HCons` d `HCons` HNil)

instance HTuple' '[a,b,c,d,e] (a,b,c,d,e) where
    hToTuple' (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` HNil) = (a,b,c,d,e)
    hFromTuple' (a,b,c,d,e) = (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` HNil)

instance HTuple' '[a,b,c,d,e,f] (a,b,c,d,e,f) where
    hToTuple' (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` HNil) = (a,b,c,d,e,f)
    hFromTuple' (a,b,c,d,e,f) = (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` HNil)

instance HTuple' '[a,b,c,d,e,f,g] (a,b,c,d,e,f,g) where
    hToTuple' (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` HNil) = (a,b,c,d,e,f,g)
    hFromTuple' (a,b,c,d,e,f,g) = (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` HNil)

instance HTuple' '[a,b,c,d,e,f,g,h] (a,b,c,d,e,f,g,h) where
    hToTuple' (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` h `HCons` HNil) = (a,b,c,d,e,f,g,h)
    hFromTuple' (a,b,c,d,e,f,g,h) = (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` h `HCons` HNil)

instance HTuple' '[a,b,c,d,e,f,g,h,i] (a,b,c,d,e,f,g,h,i) where
    hToTuple' (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` h `HCons` i `HCons` HNil) = (a,b,c,d,e,f,g,h,i)
    hFromTuple' (a,b,c,d,e,f,g,h,i) = (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` h `HCons` i `HCons` HNil)

instance HTuple' '[a,b,c,d,e,f,g,h,i,j] (a,b,c,d,e,f,g,h,i,j) where
    hToTuple' (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` h `HCons` i `HCons` j `HCons` HNil) = (a,b,c,d,e,f,g,h,i,j)
    hFromTuple' (a,b,c,d,e,f,g,h,i,j) = (a `HCons` b `HCons` c `HCons` d `HCons` e `HCons` f `HCons` g `HCons` h `HCons` i `HCons` j `HCons` HNil)