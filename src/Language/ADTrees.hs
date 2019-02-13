module Language.ADTrees
    ( Player(..)
    , Event(..)
    , Semantics
    , FSemantics(..)
    , aggregate
    , cutsets
    , flatten
    , dot
    , probability
    , difficulty
    ) where

import Data.List (lookup)
import Data.Maybe (fromJust)
import Text.Printf (printf)

-- TODO: mention https://github.com/tomahawkins/fault-tree

type Name = String

data Player = A | D deriving (Show, Eq)

-- Semantics for a given faction
data FSemantics a = MkFSemantics
    { plus  :: a -> a -> a
    , zero  :: a
    , times :: a -> a -> a
    , one   :: a
    , minus :: a -> a
    }

-- Attack-defense semantics
type Semantics a = Player -> FSemantics a

data Event a 
    = Basic Player Name a
    | And   Player Name [Event a]
    | Or    Player Name [Event a]
    deriving (Show, Eq)

-- TODO: add minus
aggregate :: Semantics a -> Event a -> a
aggregate _ (Basic _ _ a)   = a
aggregate d (And   p _ es)  = foldr (times (d p) . aggregate d) (one $ d p) es
aggregate d (Or    p _ es)  = foldr (plus (d p) . aggregate d) (zero $ d p) es

-- TODO: check this makes sense
cutsets :: Event a -> [Event a]
cutsets (Basic p n a) = [Basic p n a]
cutsets (And p n es) = map (And p n) (mapM cutsets es) -- cartesian product
cutsets (Or _ _ es) = concatMap cutsets es

flatten :: Event a -> [Event a]
flatten e@Basic{}      = [e]
flatten e@(And _ _ es) = e : concatMap flatten es
flatten e@(Or _ _ es)  = e : concatMap flatten es

dot :: (Eq a) => (a -> String) -> Event a -> String
dot fs r = unlines
    [ "digraph {"
    , "\trankdir=BT"
    , "\tnode [style=\"bold,rounded\"]"
    , unlines $ map node (flatten r)
    , unlines $ map edge (flatten r)
    , "}"
    ]
    where
        ids = [ (e', "event_" ++ show i) | (e', i) <- zip (flatten r) [0 :: Int ..] ]
        eventId e = fromJust $ lookup e ids

        color A = "#ff0000"
        color D = "#00ff00"

        -- TODO: add player colors
        -- TODO: add attributes
        -- TODO: add or/and fanciness
        node e@(Basic p n a) = printf "\t%s [label=<%s <br/> <FONT POINT-SIZE=\"10\">%s</FONT>>,color=\"%s\",shape=box]" (eventId e) n (fs a) (color p)
        node e@(And p n _)   = printf "\t%s [label=<%s <br/> AND>,color=\"%s\",shape=box]" (eventId e) n (color p)
        node e@(Or p n _)    = printf "\t%s [label=<%s <br/> OR>,color=\"%s\",shape=box]" (eventId e) n (color p)

        edge Basic{} = ""
        edge e@(And _ _ es)  = unlines [ printf "\t%s -> %s" (eventId e') (eventId e) | e' <- es ]
        edge e@(Or _ _ es)   = unlines [ printf "\t%s -> %s" (eventId e') (eventId e) | e' <- es ]


------------------------
-- DEFAULT ATTRIBUTES --
------------------------

probability :: Semantics Rational
probability _ = MkFSemantics
    { plus  = (+)
    , zero  = 0
    , times = (*)
    , one   = 1
    , minus = (1 -)
    }

difficulty :: Semantics Rational
difficulty A = MkFSemantics
    { plus  = min
    , zero  = 1
    , times = max
    , one   = 0
    , minus = (1 -)
    }
difficulty D = MkFSemantics
    { plus  = max
    , zero  = 0
    , times = min
    , one   = 1
    , minus = (1 -)
    }

-- TODO: Cost
