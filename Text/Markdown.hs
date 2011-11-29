{-# LANGUAGE OverloadedStrings #-}
module Text.Markdown
    ( MarkdownSettings
    , msXssProtect
    , def
    , markdown
    ) where

import Prelude hiding (sequence, takeWhile)
import Data.Default (Default (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Text.Blaze (Html, toHtml, preEscapedText)
import Data.Enumerator
    ( Iteratee, Enumeratee
    , ($$), (=$)
    , run_, enumList, consume
    , sequence
    )
import Data.Enumerator.List (fold)
import Data.Monoid (mappend, mempty, mconcat)
import Data.Functor.Identity (runIdentity)
import Data.Attoparsec.Enumerator (iterParser)
import Data.Attoparsec.Text
    (Parser, takeWhile, string, skip, char)
import Control.Applicative ((<$>), (<|>), optional)
import qualified Text.Blaze.Html5 as H
import Control.Monad (when)

data MarkdownSettings = MarkdownSettings
    { msXssProtect :: Bool
    }

instance Default MarkdownSettings where
    def = MarkdownSettings
        { msXssProtect = True
        }

markdown :: MarkdownSettings -> TL.Text -> Html
markdown ms tl =
    runIdentity $ run_ $ enumList 8 (TL.toChunks tl) $$ markdownIter ms

markdownIter :: Monad m
             => MarkdownSettings
             -> Iteratee Text m Html
markdownIter ms = markdownEnum ms =$ fold mappend mempty

markdownEnum :: Monad m
             => MarkdownSettings
             -> Enumeratee Text Html m a
markdownEnum = sequence . iterParser . parser

nonEmptyLines :: Parser [Text]
nonEmptyLines =
    go id
  where
    go :: ([Text] -> [Text]) -> Parser [Text]
    go front = do
        l <- takeWhile (/= '\n')
        optional $ skip (== '\n')
        if T.null l then return (front []) else go $ front . (l:)

parser :: MarkdownSettings -> Parser Html
parser ms =
    para
  where
    para = do
        ls <- nonEmptyLines
        when (null ls) $ fail "Missing lines"
        return $ H.p $ foldr1
            (\a b -> a `mappend` preEscapedText "\n" `mappend` b)
            (map toHtml ls)
