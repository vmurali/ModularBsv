import DataTypes

prettyPrint (bn, Binding ba bz bexpr) =
  "wire " ++ bn ++ "[" ++ ba ++ "-1:0][" ++ bz ++ "-1:0]\nassign " ++ bn ++ " = " prettyPrint bexpr
