-- You put the next functions in the where statement.

--OK my implementation is perhaps not as small as I thought, but I think it's the lattice is the 
--good abstraction layer.
--
--I 've done some modifications without to typecheck my code, so I think we could do the integration of this piece of code sunday, together.


conflict x = joins1 . Set.elems $ dependenciesAll x

 
basicConflict ((m1, h1),(m2, h2)) | m1 == "fp" , m2 == "fp" = conflictFp Map.! (h1,h2)  
			 	  | m1 == m2 = (conflictOfEachPairInsideModule m1) Map.! (("this",h1),("this",h2))
				  | otherwise  = CF 

buildDependenciesFunction ((m1, h1),(m2, h2))       | m1 == "fp" , m2 == "fp" = Set.singleton ((m1,h1),(m2,h2))   
					   | m1 == m2 = Set.singleton ((m1,h1),(m2,h2))
					   | m1 == "fp" = let listFps2 = toActualFp m2 $ fpOfEachMethodInternally Map.! (m2,h2) in Set.fromList . map (\p -> ((m1,h1),p)) $ listFps2
					   | m2 == "fp" = let listFps1 = toActualFp m1 $ fpOfEachMethodInternally Map.! (m1,h1) in Set.fromList . map (\p->  (p,(m2,h2))) $ listFps1
					   | otherwise  = let listFps1 = toActualFp m1 $ fpOfEachMethodInternally Map.! (m1,h1)
					 	 	      listFps2 = toActualFp m2 $ fpOfEachMethodInternally Map.! (m2,h2)	
							      in Set.fromList $ (\xs ys -> [(x,y) | x <- xs, y <- ys]) listFps1 listFps2  

dependenciesExpand :: Set.Set ((String,String),(String,String)) -> Set.Set ((String, String),(String,String))
dependenciesExpand x = Set.union (buildDependenciesFunction =<< x) x

dependenciesAll :: ((String,String),(String,String)) -> Set.Set ((String,String),(String,String))
dependenciesAll x = lfpFrom (Set.singleton x) dependenciesExpand 




