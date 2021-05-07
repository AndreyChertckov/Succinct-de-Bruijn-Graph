{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TypeApplications     #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.DNA.SetDeBruijnGraphs where

import           Data.Proxy
import           GHC.TypeLits

import           Data.DNA.Assembly
import           Data.Enum.FixedList
import           Data.RankSelect.Maps as RSMaps


-- $setup
-- >>> :set -XTypeApplications
-- >>> :set -XDataKinds
-- >>> import Data.Enum.Letter

newtype ColoredDeBruijnGraph n a = ColoredDeBruijnGraph {getMaps :: RSMaps.RankSelectMaps (Edge n a) Int}

instance (Show (Edge n a), Bounded a, Enum a, KnownNat (n + 1))
  => Show (ColoredDeBruijnGraph n a) where
  show = show . toMultiplicityLists

-- | Convert set of de Bruijn Graphs into list of edges and counts
toMultiplicityLists
  :: (Bounded a, Enum a, KnownNat (n + 1))
  => ColoredDeBruijnGraph n a
  -> [[(Edge n a, Int)]]
toMultiplicityLists = RSMaps.toListsBoundedEnum . getMaps


graphsFromReads
  :: (KnownNat n, KnownNat (n+1), Bounded a, Enum a)
  => [[ReadSegment]]
  -> ColoredDeBruijnGraph n a
graphsFromReads reads = ColoredDeBruijnGraph maps
  where
    maps = RSMaps.empty

-- | Convert two list of read segments into the colored de bruijn graph
--
-- >>> graphsFromTwoReads [unsafeLetters @"ACGT" "AAACCAACC"] [unsafeLetters @"ACGT" "AAACGAACC"] :: ColoredDeBruijnGraph 2 (Letter "ACGT")
-- [[("AAA",1),("AAC",2),("ACC",2),("CAA",1),("CCA",1)],[("AAA",1),("AAC",2),("ACC",1),("ACG",1),("CGA",1),("GAA",1)]]
graphsFromTwoReads
  :: forall n a. (KnownNat n, KnownNat (n+1), Bounded a, Enum a, Eq a)
  => [ReadSegment]
  -> [ReadSegment]
  -> ColoredDeBruijnGraph n a
graphsFromTwoReads first second = ColoredDeBruijnGraph $ RSMaps.fromListsEnumOfTwoWith (+) size fixedList
   where
      size = 4 ^ (n + 1)
      n = fromIntegral (natVal (Proxy :: Proxy n))
      fixedList = unsafeFixedList @2 [firstChunks, secondChunks]
      firstChunks = makeChunks first
      secondChunks = makeChunks second
      makeChunks segments = [ (chunk, 1)
                            | segment <- segments
                            , chunk <- map fromEnum (readChunks segment :: [Chunk (n + 1)])
                            ]

-- | Union of two de Bruijn graphs
--
-- >>> unionOfTwoGraphs (graphFromReads @2 [unsafeLetters @"ACGT" "AAACCAACC"]) (graphFromReads @2 [unsafeLetters @"ACGT" "AAACGAACC"])
-- [[("AAA",1),("AAC",2),("ACC",2),("CAA",1),("CCA",1)],[("AAA",1),("AAC",2),("ACC",1),("ACG",1),("CGA",1),("GAA",1)]]
-- >>> (commonPart . getMaps) (unionOfTwoGraphs (graphFromReads @2 [unsafeLetters @"ACGT" "AAACCAACC"]) (graphFromReads @2 [unsafeLetters @"ACGT" "AAACGAACC"]))
-- 11000100000000000000000000000000000000000000000000000000000000000
unionOfTwoGraphs
  :: (KnownNat n, KnownNat (n+1), Bounded a, Enum a)
  => DeBruijnGraph n a
  -> DeBruijnGraph n a
  -> ColoredDeBruijnGraph n a
unionOfTwoGraphs (DeBruijnGraph first) (DeBruijnGraph second) = ColoredDeBruijnGraph (RSMaps.unionOfTwoMaps first second)


addReadsToGraph
  :: [ReadSegment]
  -> ColoredDeBruijnGraph n a
  -> ColoredDeBruijnGraph n a
addReadsToGraph _ graph = graph
