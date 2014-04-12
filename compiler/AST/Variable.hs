
module AST.Variable where

import Data.Binary
import Control.Applicative ((<$>), (<*>))
import Text.PrettyPrint as P
import SourceSyntax.PrettyPrint

import qualified Data.List as List
import qualified Text.PrettyPrint as P
import SourceSyntax.PrettyPrint

newtype Raw = Raw String
    deriving (Eq,Ord,Show)

data Home
    = Local
    | Module !String
    deriving (Eq,Ord,Show)

data Canonical = Canonical
    { home :: !Home
    , name :: !String
    } deriving (Eq,Ord,Show)

local :: String -> Canonical
local x = Canonical Local x

class ToString a where
  toString :: a -> String

instance ToString Raw where
  toString (Raw x) = x

instance ToString Canonical where
  toString (Canonical home name) =
    case home of
      Local -> name
      Module path -> path ++ "." ++ name

-- | A listing of values. Something like (a,b,c) or (..) or (a,b,..)
data Listing a = Listing
    { _explicits :: [a]
    , _open :: Bool
    }

openListing :: Listing a
openListing = Listing [] True

-- | A value that can be imported or exported
data Value
    = Value !String
    | Alias !String
    | ADT !String !(Listing String)


instance Pretty Raw where
    pretty (Raw var) = variable var

instance Pretty Canonical where
    pretty (Canonical home name) =
        P.text (home' ++ name)
        where
          home' = case home of
                    Local -> ""
                    Module name -> name ++ "."

instance Pretty a => Pretty (Listing a) where
  pretty (Listing explicits open) =
      P.parens (commaCat (map pretty explicits ++ dots))
      where
        dots = [if open then P.text ".." else P.empty]

instance Pretty Value where
  pretty portable =
    case portable of
      Value name -> P.text name
      Alias name -> P.text name
      ADT name ctors ->
          P.text name <> pretty (ctors { _explicits = map P.text (_explicits ctors) })

instance Binary Canonical where
    put (Canonical home name) =
        case home of
          Local -> putWord8 0 >> put name
          Module path -> putWord8 1 >> put path >> put name

    get = do tag <- getWord8
             case tag of
               0 -> Canonical Local <$> get
               1 -> Canonical . Module <$> get <*> get
               _ -> error "Unexpected tag when deserializing canonical variable"

instance Binary Value where
    put portable =
        let put' n info = putWord8 n >> put info in
        case portable of
          Value name -> put' 0 name
          ADT name ctors ->
              do put' 1 name
                 put ctors

    get = do tag <- getWord8
             case tag of
               0 -> Value <$> get
               1 -> ADT <$> get <*> get
               _ -> error "Error reading valid import/export information from serialized string"

instance (Binary a) => Binary (Listing a) where
    put (Listing explicits open) =
        do put explicits
           put open

    get = Listing <$> get <*> get