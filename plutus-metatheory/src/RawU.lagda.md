
This module provides the interface between the Haskell code and the Agda code.
It replicates the Haskell representation of Raw. In particular, for term constants,
we need the following extension to be able to replicate the Haskell representation
of Universes.

```
{-# OPTIONS --type-in-type #-}

module RawU where
```

## Imports

```
open import Function using (_∘_)
open import Data.Nat using (ℕ)
open import Data.Bool using (true;false)
open import Data.Integer using (ℤ)
open import Data.String using (String)
open import Data.Bool using (Bool;_∧_)
open import Relation.Binary using (DecidableEquality)
open import Relation.Binary.PropositionalEquality using (_≡_;refl;sym;cong;cong₂)
open import Relation.Nullary using (does;yes;no;¬_)
open import Data.Unit using (⊤;tt)
open import Data.Product using (Σ;proj₁;proj₂) renaming (_,_ to _,,_)

open import Utils using (ByteString;DATA;List;[];_∷_;_×_;_,_;eqDATA)
open import Utils.Decidable using (dcong;dcong₂)
open import Builtin using (Builtin;equals)
open Builtin.Builtin

open import Builtin.Signature using (_⊢♯;con) 
import Builtin.Constant.Type ℕ (_⊢♯) as T
open import Builtin.Constant.AtomicType using (decAtomicTyCon)

{-# FOREIGN GHC {-# LANGUAGE GADTs #-} #-}
{-# FOREIGN GHC import PlutusCore #-}
{-# FOREIGN GHC import Raw #-}
```

## A (Haskell) Universe for types

The following tags use type-in-type, and map more directly to the Haskell representation
of the default universe.

Tags are indexed by the real type they represent.
The `Esc` datatype is used in the Haskell implementation to "escape" any kind into Type.
For constants, we only care about kind *, but we need it to match the Haskell implementation.
```
data Esc (a : Set) : Set where
{-# INJECTIVE Esc #-}
{-# COMPILE GHC Esc = data Esc () #-}

data Tag : Set → Set where
  integer    : Tag (Esc ℤ)
  bytestring : Tag (Esc ByteString)
  string     : Tag (Esc String)
  bool       : Tag (Esc Bool)
  unit       : Tag (Esc ⊤)
  pdata      : Tag (Esc DATA)
  pair       : ∀{A B} → Tag (Esc A) → Tag (Esc B) → Tag (Esc (A × B))
  list       : ∀{A} → Tag (Esc A) → Tag (Esc (List A))

{-# FOREIGN GHC type Tag = DefaultUni #-}
{-# FOREIGN GHC pattern TagInt        = DefaultUniInteger  #-}
{-# FOREIGN GHC pattern TagBS         = DefaultUniByteString #-}
{-# FOREIGN GHC pattern TagStr        = DefaultUniString #-}
{-# FOREIGN GHC pattern TagBool       = DefaultUniBool #-}
{-# FOREIGN GHC pattern TagUnit       = DefaultUniUnit #-}
{-# FOREIGN GHC pattern TagData       = DefaultUniData #-}
{-# FOREIGN GHC pattern TagPair ta tb = DefaultUniPair ta tb #-}
{-# FOREIGN GHC pattern TagList ta    = DefaultUniList ta #-}
{-# COMPILE GHC Tag = data Tag (TagInt | TagBS | TagStr | TagBool | TagUnit | TagData | TagPair | TagList) #-}
```

## Term constants

Term constants are pairs of a tag and the corresponding type. 

```
data TagCon : Set where
  tagCon : ∀{A} → Tag (Esc A) → A → TagCon

{-# FOREIGN GHC type TagCon = Some (ValueOf DefaultUni) #-}
{-# FOREIGN GHC pattern TagCon t x = Some (ValueOf t x) #-} 
{-# COMPILE GHC TagCon = data TagCon (TagCon) #-}

{-# TERMINATING #-}
decTagCon : (C C' : TagCon) → Bool
decTagCon (tagCon integer i) (tagCon integer i') = does (i Data.Integer.≟ i') 
decTagCon (tagCon bytestring b) (tagCon bytestring b') = equals b b'
decTagCon (tagCon string s) (tagCon string s') = does (s Data.String.≟ s')
decTagCon (tagCon bool b) (tagCon bool b') = does (b Data.Bool.≟ b')
decTagCon (tagCon unit ⊤) (tagCon unit ⊤) = true
decTagCon (tagCon pdata d) (tagCon pdata d') = eqDATA d d'
decTagCon (tagCon (pair t₁ t₂) (x₁ , x₂)) (tagCon (pair u₁ u₂) (y₁ , y₂)) = 
       decTagCon (tagCon t₁ x₁) (tagCon u₁ y₁) ∧ decTagCon (tagCon t₂ x₂) (tagCon u₂ y₂)
decTagCon (tagCon (list t) []) (tagCon (list t') []) = true -- TODO: check that the tags t and t' are equal
decTagCon (tagCon (list t) (x ∷ xs)) (tagCon (list t') (y ∷ ys)) = 
       decTagCon (tagCon t x) (tagCon t' y) ∧ decTagCon (tagCon (list t) xs) (tagCon (list t') ys)
decTagCon _ _ = false
```
## Raw syntax

This version is not intrinsically well-scoped. It's an easy to work
with rendering of the untyped plutus-core syntax.

```
data Untyped : Set where
  UVar : ℕ → Untyped
  ULambda : Untyped → Untyped
  UApp : Untyped → Untyped → Untyped
  UCon : TagCon → Untyped
  UError : Untyped
  UBuiltin : Builtin → Untyped
  UDelay : Untyped → Untyped
  UForce : Untyped → Untyped

{-# FOREIGN GHC import Untyped #-}
{-# COMPILE GHC Untyped = data UTerm (UVar | ULambda  | UApp | UCon | UError | UBuiltin | UDelay | UForce) #-}
```

##  Agda-Style universes

In the rest of the formalisation we use the following representation of type tags.

```
TyTag : Set
TyTag = 0 ⊢♯
```

The meaning of type tags is provided by the following function.

```
⟦_⟧tag : TyTag → Set
⟦ con T.integer ⟧tag = ℤ
⟦ con T.bytestring ⟧tag = ByteString
⟦ con T.string ⟧tag = String
⟦ con T.bool ⟧tag = Bool
⟦ con T.unit ⟧tag = ⊤
⟦ con T.pdata ⟧tag = DATA
⟦ con (T.pair p p') ⟧tag = ⟦ p ⟧tag × ⟦ p' ⟧tag
⟦ con (T.list p) ⟧tag = List ⟦ p ⟧tag
```

Equality of `TyTag`s is decidable

```
decTag : DecidableEquality TyTag
decTyCon : DecidableEquality (T.TyCon 0)
-- atomic
decTyCon (T.atomic A) (T.atomic A') = dcong T.atomic (λ {refl → refl}) (decAtomicTyCon A A')
decTyCon (T.atomic _) (T.list _)     = no λ()
decTyCon (T.atomic _) (T.pair _ _)   = no λ()
-- pair
decTyCon (T.pair A B) (T.pair A' B') = dcong₂ T.pair (λ {refl → refl ,, refl }) (decTag A A') (decTag B B')
decTyCon (T.pair _ _) (T.atomic _)   = no λ()
decTyCon (T.pair _ _) (T.list _)     = no λ()
-- list
decTyCon (T.list A) (T.list A') = dcong T.list (λ {refl → refl}) (decTag A A')
decTyCon (T.list _)   (T.atomic _)   = no λ()
decTyCon (T.list _)   (T.pair _ _)   = no λ()

decTag (con x) (con y) = dcong con (λ {refl → refl}) (decTyCon x y)
```

Again term constants are a pair of a tag, and its meaning, except
this time the meaning is given by the semantic function ⟦_⟧tag.

```
data TmCon : Set where 
  tmCon : (t : TyTag) → ⟦ t ⟧tag → TmCon
```

## Conversion between universe representations

We can convert between the two universe representations.
 * The universe à la Haskell, given by `Tag` and `TagCon`
 * The universe in Agda-style, given by `TyTag` abd `TmCon`.

### From Haskell-style to Agda-style

```
tag2TyTag : ∀{A} → Tag A → TyTag
tag2TyTag integer = con T.integer
tag2TyTag bytestring = con T.bytestring
tag2TyTag string = con T.string
tag2TyTag bool = con T.bool
tag2TyTag unit = con T.unit
tag2TyTag pdata = con T.pdata
tag2TyTag (pair t u) = con (T.pair (tag2TyTag t) (tag2TyTag u))
tag2TyTag (list t) = con (T.list (tag2TyTag t))

tagLemma : ∀{A}(t : Tag (Esc A)) →  A ≡ ⟦ tag2TyTag t ⟧tag
tagLemma integer = refl
tagLemma bytestring = refl
tagLemma string = refl
tagLemma bool = refl
tagLemma unit = refl
tagLemma pdata = refl
tagLemma (pair t u) = cong₂ _×_ (tagLemma t) (tagLemma u)
tagLemma (list t) = cong List (tagLemma t)

tagCon2TmCon : TagCon → TmCon
tagCon2TmCon (tagCon integer x) = tmCon (con T.integer) x
tagCon2TmCon (tagCon bytestring x) = tmCon (con T.bytestring) x
tagCon2TmCon (tagCon string x) = tmCon (con T.string) x
tagCon2TmCon (tagCon bool x) = tmCon (con T.bool) x
tagCon2TmCon (tagCon unit x) = tmCon (con T.unit) tt
tagCon2TmCon (tagCon pdata x) = tmCon (con T.pdata) x
tagCon2TmCon (tagCon (pair x y) (a , b)) rewrite tagLemma x | tagLemma y = tmCon (con (T.pair (tag2TyTag x) (tag2TyTag y))) (a , b)
tagCon2TmCon (tagCon (list x) xs) rewrite tagLemma x = tmCon (con (T.list (tag2TyTag x))) xs
```

### From Agda-style to Haskell-style

```
tyTag2Tag : TyTag → Σ Set (λ A → Tag (Esc A)) 
tyTag2Tag (con T.integer) = ℤ ,, integer
tyTag2Tag (con T.bytestring) = ByteString ,, bytestring
tyTag2Tag (con T.string) = String ,, string
tyTag2Tag (con T.bool) = Bool ,, bool
tyTag2Tag (con T.unit) = ⊤ ,, unit
tyTag2Tag (con T.pdata) = DATA ,, pdata
tyTag2Tag (con (T.pair t u)) with tyTag2Tag t | tyTag2Tag u 
... | A ,, a | B ,, b = A × B ,, pair a b
tyTag2Tag (con (T.list t)) with tyTag2Tag t 
... | A ,, a = (List A) ,, (list a)

tyTagLemma : (t : TyTag) → ⟦ t ⟧tag ≡ proj₁ (tyTag2Tag t)
tyTagLemma (con T.integer) = refl
tyTagLemma (con T.bytestring) = refl
tyTagLemma (con T.string) = refl
tyTagLemma (con T.bool) = refl
tyTagLemma (con T.unit) = refl
tyTagLemma (con T.pdata) = refl
tyTagLemma (con (T.pair t u)) = cong₂ _×_ (tyTagLemma t) (tyTagLemma u)
tyTagLemma (con (T.list t)) = cong List (tyTagLemma t)

tmCon2TagCon : TmCon → TagCon
tmCon2TagCon (tmCon (con T.integer) x) = tagCon integer x
tmCon2TagCon (tmCon (con T.bytestring) x) = tagCon bytestring x
tmCon2TagCon (tmCon (con T.string) x) = tagCon string x
tmCon2TagCon (tmCon (con T.bool) x) = tagCon bool x
tmCon2TagCon (tmCon (con T.unit) x) = tagCon unit tt
tmCon2TagCon (tmCon (con T.pdata) x) = tagCon pdata x
tmCon2TagCon (tmCon (con (T.pair t u)) (x , y)) rewrite tyTagLemma t | tyTagLemma u = 
    tagCon (pair (proj₂ (tyTag2Tag t)) (proj₂ (tyTag2Tag u))) (x , y)
tmCon2TagCon (tmCon (con (T.list t)) x) rewrite tyTagLemma t = tagCon (list (proj₂ (tyTag2Tag t))) x
``` 