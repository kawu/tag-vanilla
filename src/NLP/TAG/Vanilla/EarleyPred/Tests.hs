{-# LANGUAGE OverloadedStrings #-}


-- | Note: tests here are the same as the tests of the ordinary
-- `Earley` module.


module NLP.TAG.Vanilla.EarleyPred.Tests where


import           Control.Applicative ((<$>), (<*>))
import           Control.Monad (void, forM_)
import qualified Control.Monad.State.Strict as E

import qualified Data.IntMap as I
import qualified Data.Set as S
import           Data.List (sortBy)
import           Data.Ord (comparing)
import qualified Pipes as P
import qualified Pipes.Prelude as P

import           Test.Tasty (TestTree, testGroup) -- , localOptions)
import           Test.HUnit (Assertion, (@?=))
import           Test.Tasty.HUnit (testCase)

import           NLP.TAG.Vanilla.Tree (Tree (..), AuxTree (..))
import           NLP.TAG.Vanilla.EarleyPred (earley, recognize')
import           NLP.TAG.Vanilla.Rule (compile, Rule)


---------------------------------------------------------------------
-- Prerequisites
---------------------------------------------------------------------


type Tr = Tree String String
type AuxTr = AuxTree String String
type Rl = Rule String String


---------------------------------------------------------------------
-- Grammar1
---------------------------------------------------------------------


tom :: Tr
tom = INode "NP"
    [ INode "N"
        [FNode "Tom"]
    ]


sleeps :: Tr
sleeps = INode "S"
    [ INode "NP" []
    , INode "VP"
        [INode "V" [FNode "sleeps"]]
    ]


caught :: Tr
caught = INode "S"
    [ INode "NP" []
    , INode "VP"
        [ INode "V" [FNode "caught"]
        , INode "NP" [] ]
    ]


almost :: AuxTr
almost = AuxTree (INode "V"
    [ INode "Ad" [FNode "almost"]
    , INode "V" []
    ]) [1]


a :: Tr
a = INode "D" [FNode "a"]


mouse :: Tr
mouse = INode "NP"
    [ INode "D" []
    , INode "N"
        [FNode "mouse"]
    ]


mkGram1 :: IO (S.Set Rl)
mkGram1 = compile $
    (map Left [tom, sleeps, caught, a, mouse]) ++
    (map Right [almost])


testGram :: String -> [String] -> IO ()
testGram start sent = do
    gram <- mkGram1
    void $ earley gram (S.singleton start) sent
    -- forM_ rs $ \r -> printRule r >> putStrLn ""
    -- return ()


---------------------------------------------------------------------
-- Grammar2
---------------------------------------------------------------------


alpha :: Tr
alpha = INode "S"
    [ FNode "p"
    , INode "X"
        [FNode "e"]
    , FNode "q" ]


beta1 :: AuxTr
beta1 = AuxTree (INode "X"
    [ FNode "a"
    , INode "X"
        [ INode "X" []
        , FNode "a" ] ]
    ) [1,0]


beta2 :: AuxTr
beta2 = AuxTree (INode "X"
    [ FNode "b"
    , INode "X"
        [ INode "X" []
        , FNode "b" ] ]
    ) [1,0]


mkGram2 :: IO (S.Set Rl)
mkGram2 = compile $
    (map Left [alpha]) ++
    (map Right [beta1, beta2])


---------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------


tests :: TestTree
tests = testGroup "NLP.TAG.Vanilla.EarleyPred"
    [ testCase "Tom sleeps" testTom1
    , testCase "Tom caught a mouse" testTom2
    , testCase "Copy language" testCopy ]


testTom1 :: Assertion
testTom1 = do
    gram <- mkGram1
    recognize' gram "S" ["Tom", "sleeps"]    @@?= True
    recognize' gram "S" ["Tom"]              @@?= False
    recognize' gram "NP" ["Tom"]             @@?= True


testTom2 :: Assertion
testTom2 = do
    gram <- mkGram1
    recognize' gram "S" ["Tom", "almost", "caught", "a", "mouse"] @@?= True
    recognize' gram "S" ["Tom", "caught", "almost", "a", "mouse"] @@?= False
    recognize' gram "S" ["Tom", "caught", "a", "mouse"] @@?= True
    recognize' gram "S" ["Tom", "caught", "Tom"] @@?= True
    recognize' gram "S" ["Tom", "caught", "a", "Tom"] @@?= False
    recognize' gram "S" ["Tom", "caught"] @@?= False
    recognize' gram "S" ["caught", "a", "mouse"] @@?= False


-- | What we test is not really a copy language but rather a
-- language in which there is always the same number of `a`s and
-- `b`s on the left and on the right of the empty `e` symbol.
-- To model the real copy language with a TAG we would need to
-- use either adjunction constraints or feature structures.
testCopy :: Assertion
testCopy = do
    gram <- mkGram2
    recognize' gram "S"
        (words "p a b e a b q")
        @@?= True
    recognize' gram "S"
        (words "p a b e a a q")
        @@?= False
    recognize' gram "S"
        (words "p a b a b a b a b e a b a b a b a b q")
        @@?= True
    recognize' gram "S"
        (words "p a b a b a b a b e a b a b a b a   q")
        @@?= False


---------------------------------------------------------------------
-- Utils
---------------------------------------------------------------------


(@@?=) :: (Show a, Eq a) => IO a -> a -> Assertion
mx @@?= y = do
    x <- mx
    x @?= y
