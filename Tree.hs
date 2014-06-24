module Tree where

import Control.Monad
import Control.Applicative
import Utils

----- TREE -----
data Tree a = Node a [Tree a]

leaf x = Node x []

onNodeValue f (Node value children) = Node (f value) children
setNodeValue x = onNodeValue (\_ -> x)

setChildren children (Node value _) = Node value children
addChild newChild (Node value children) = Node value (newChild : children)

foldTree :: (sub -> a) -> (a -> [a] -> a) -> Tree sub -> a
foldTree f combine (Node value args) = combine (f value) (map (foldTree f combine) args)


----- ZIPPER -----

-- TODO: Maybe extract list zipper
data TreeFocus a = TreeFocus (Maybe (TreeFocus a)) [Tree a] (Tree a) [Tree a]

zipTree tree = TreeFocus Nothing [] tree []

focusedTree (TreeFocus _ _ focus _) = focus


------ movement -----

goDown :: TreeFocus a -> Maybe (TreeFocus a)
goDown zipper = case focusedTree zipper of
  Node _ [] -> Nothing
  Node _ (firstChild : otherChildren) -> Just (TreeFocus (Just zipper) [] firstChild otherChildren)

goUp :: TreeFocus a -> Maybe (TreeFocus a)
goUp actZipper = case actZipper of
  TreeFocus maybePrevZipper leftNeighbors focusedTree rightNeighbors
    -> let updateChildren (Node value _)
             = Node value (reverse leftNeighbors ++ [focusedTree] ++ rightNeighbors)
       in modifyFocus updateChildren <$> maybePrevZipper

goRight :: TreeFocus a -> Maybe (TreeFocus a)
goRight (TreeFocus prevZipper leftNeighbors curFocus rightNeighbors) = case rightNeighbors of
  [] -> Nothing
  (newFocus : restRightNeighbors)
    -> Just <| TreeFocus prevZipper (curFocus : leftNeighbors) newFocus restRightNeighbors

goLeft :: TreeFocus a -> Maybe (TreeFocus a)
goLeft (TreeFocus prevFocus leftNeighbors curFocus rightNeighbors) = case leftNeighbors of
  [] -> Nothing
  (newFocus : restLeftNeighbors)
    -> Just <| TreeFocus prevFocus restLeftNeighbors newFocus (curFocus:rightNeighbors)


----- modification -----

modifyFocus f (TreeFocus parent leftNeighbors focus rightNeighbors)
  = TreeFocus parent leftNeighbors (f focus) rightNeighbors

setFocus x = modifyFocus (\_ -> x)

deleteFocused (TreeFocus maybeParent leftNeighbors focus rightNeighbors)
  = case leftNeighbors of
      (newFocus : leftRestNeighbors)
         -> Just (TreeFocus maybeParent leftRestNeighbors newFocus rightNeighbors)
      [] -> case rightNeighbors of
        (newFocus : rightRestNeighbors)
           -> Just (TreeFocus maybeParent leftNeighbors newFocus rightRestNeighbors)
        [] -> modifyFocus (setChildren []) <$> maybeParent

moveRight (TreeFocus parent leftNeighbors focus rightNeighbors)
  = case rightNeighbors of
      [] -> Nothing
      (rightNeighbor : restRightNeighbors)
        -> Just (TreeFocus parent (rightNeighbor : leftNeighbors) focus restRightNeighbors)

moveLeft (TreeFocus parent leftNeighbors focus rightNeighbors)
  = case leftNeighbors of
      [] -> Nothing
      (leftNeighbor : restLeftNeighbors)
        -> Just (TreeFocus parent restLeftNeighbors focus (leftNeighbor : rightNeighbors))


----- folding -----

foldNeighbors :: (sub -> a) -> (a -> [a] -> a) -> [Tree sub] -> a -> [Tree sub] -> [a]
foldNeighbors f combine leftNeighbors self rightNeighbors
  = reverse (map (foldTree f combine) leftNeighbors)
    ++ [self]
    ++ map (foldTree f combine) rightNeighbors

buildUp :: (sub -> a) -> (a -> [a] -> a) -> [a] -> Maybe (TreeFocus sub) -> [a]
buildUp f combine subs maybeFocus = case maybeFocus of
  Nothing -> subs
  Just (TreeFocus maybePrevFocus leftNeighbors (Node value _) rightNeighbors)
    -> let childrenResults = foldNeighbors f combine leftNeighbors focusedResult rightNeighbors
           focusedResult = combine (f value) subs
       in maybePrevFocus |> buildUp f combine childrenResults

foldZipper :: (Tree sub -> a) -> (sub -> a) -> (a -> [a] -> a) -> TreeFocus sub -> [a]
foldZipper f g combine (TreeFocus maybePrevFocus leftNeighbors focus rightNeighbors)
  = maybePrevFocus |> buildUp g combine (foldNeighbors g combine leftNeighbors (f focus) rightNeighbors)
