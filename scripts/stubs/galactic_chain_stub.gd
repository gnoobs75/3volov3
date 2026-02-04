extends Node
## Stub: Galactic Chain - procedural biosphere linking with migration.
## From Possible_Features: "Link biospheres into procedural planets/systems"
## TODO: Implement full chain generation, migration gates, species transfer

func generate_chain(size: int) -> Array:
	# Placeholder: return array of biosphere dicts
	var chain: Array = []
	for i in range(size):
		chain.append({
			"id": "biosphere_%d" % i,
			"type": ["ocean", "land", "atmosphere"][i % 3],
			"env_match": randf_range(0.3, 1.0)
		})
	print("GalacticChain: Generated chain of %d biospheres (stub)" % size)
	return chain

func calc_migration_success(species_genes: Array, target_env_match: float) -> float:
	var score: float = 0.0
	for gene_id in species_genes:
		var gene: Dictionary = BiologyLoader.get_gene(gene_id)
		var impact: Dictionary = gene.get("trait_impact", {})
		for key in impact:
			score += abs(impact[key])
	return clampf(score * target_env_match, 0.0, 1.0)
