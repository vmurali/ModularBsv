import ModuleParser
import Text.Parsec

main = do
  input <- getContents
  parseTest modulesParser input
