-- | Plutus Tx basic functions.
module PlutusTx.Base (fst, snd, curry, uncurry, ($), flip, until, (.), const, id) where

import PlutusTx.Bool

-- | Plutus Tx version of 'Data.Tuple.fst'
fst :: (a, b) -> a
fst (a, _) = a
{-# INLINABLE fst #-}

-- | Plutus Tx version of 'Data.Tuple.snd'
snd :: (a, b) -> b
snd (_, b) = b
{-# INLINABLE snd #-}

curry :: ((a, b) -> c) -> a -> b -> c
curry f a b = f (a, b)
{-# INLINABLE curry #-}

uncurry :: (a -> b -> c) -> (a, b) -> c
uncurry f (a, b) = f a b
{-# INLINABLE uncurry #-}

infixr 0 $
-- Normal $ is levity-polymorphic, which we can't handle.
-- | Plutus Tx version of 'Data.Function.($)'.
($) :: (a -> b) -> a -> b
f $ a = f a
{-# INLINABLE ($) #-}

-- | Plutus Tx version of 'Prelude.flip'.
flip                    :: (a -> b -> c) -> b -> a -> c
flip f x y              =  f y x
{-# INLINABLE flip #-}

-- | Plutus Tx version of 'Prelude.until'.
until                   :: (a -> Bool) -> (a -> a) -> a -> a
until p f = go
  where
    go x | p x          = x
         | otherwise    = go (f x)
{-# INLINABLE until #-}

infixr 9 .
-- | Plutus Tx version of 'Prelude.(.)'.
(.)    :: (b -> c) -> (a -> b) -> a -> c
(.) f g = \x -> f (g x)
{-# INLINABLE (.) #-}


-- | Plutus Tx version of 'Prelude.const'.
const :: a -> b -> a
const x _ =  x
{-# INLINABLE const #-}

-- | Plutus Tx version of 'Prelude.id'.
id :: a -> a
id x = x
{-# INLINABLE id #-}
