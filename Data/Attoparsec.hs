-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Attoparsec
-- Copyright   :  Bryan O'Sullivan 2007-2010
-- License     :  BSD3
-- 
-- Maintainer  :  bos@serpentine.com
-- Stability   :  experimental
-- Portability :  unknown
--
-- Simple, efficient parser combinators for 'ByteString' strings,
-- loosely based on 'Text.ParserCombinators.Parsec'.
-- 
-----------------------------------------------------------------------------
module Data.Attoparsec
    (
    -- * Parser types
      I.Parser
    , Result(..)

    -- * Running parsers
    , parse
    , parseWith
    , parseTest
    , feed

    -- * Combinators
    , (I.<?>)
    , I.try
    , module Data.Attoparsec.Combinator

    -- * Parsing individual bytes
    , I.anyWord8
    , I.notWord8
    , I.word8
    , I.satisfy

    -- ** Byte classes
    , I.inClass
    , I.notInClass

    -- * Efficient string handling
    , I.string
    , I.skipWhile
    , I.stringTransform
    , I.takeTill
    , I.takeWhile
    , I.takeWhile1

    -- * State observation and manipulation functions
    , I.endOfInput
    , I.ensure
    ) where

import Data.Attoparsec.Combinator
import Prelude hiding (takeWhile)
import qualified Data.Attoparsec.Internal as I
import qualified Data.ByteString as B

data Result r = Fail !B.ByteString [String] String
              | Partial (B.ByteString -> Result r)
              | Done !B.ByteString r

instance Show r => Show (Result r) where
    show (Fail bs stk msg) = "Fail " ++ show bs ++ show stk ++ " " ++ show msg
    show (Partial _)        = "Partial _"
    show (Done bs r)        = "Done " ++ show bs ++ " " ++ show r

feed :: Result r -> B.ByteString -> Result r
feed f@(Fail _ _ _) _ = f
feed (Partial k) d    = k d
feed (Done bs r) d    = Done (B.append bs d) r

fmapR :: (a -> b) -> Result a -> Result b
fmapR _ (Fail st stk msg) = Fail st stk msg
fmapR f (Partial k)       = Partial (fmapR f . k)
fmapR f (Done bs r)       = Done bs (f r)

instance Functor Result where
    fmap = fmapR

parseTest :: (Show a) => I.Parser a -> B.ByteString -> IO ()
parseTest p s = print (parse p s)

translate :: I.Result a -> Result a
translate (I.Fail s0 a0 c0 stk msg) = Fail s0 stk msg
translate (I.Partial k)             = Partial (translate . k)
translate (I.Done s0 a0 c0 r)       = Done s0 r

parse :: I.Parser a -> B.ByteString -> Result a
parse m s = translate (I.parse m s)
{-# INLINE parse #-}

parseWith :: Monad m =>
             (m B.ByteString)
          -> I.Parser a
          -> B.ByteString
          -> m (Result a)
parseWith refill p s = step $ I.parse p s
  where step (I.Fail s0 a0 c0 stk msg) = return $! Fail s0 stk msg
        step (I.Partial k)       = (step . k) =<< refill
        step (I.Done s0 a0 c0 r)       = return $! Done s0 r
