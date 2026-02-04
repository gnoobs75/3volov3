extends Node
## Stub: Co-op Invasion Mode - multiplayer peer placeholder.
## From Possible_Features: "Invite friends to invade biospheres with rival species"
## TODO: Implement ENetMultiplayerPeer, lobby, invasion deployment

var peer: MultiplayerPeer = null

func host_game(port: int = 9876) -> void:
	print("Co-op Stub: Would host on port %d (not implemented)" % port)

func join_game(address: String, port: int = 9876) -> void:
	print("Co-op Stub: Would join %s:%d (not implemented)" % [address, port])

func deploy_invasion(rival_genes: Array, drop_position: Vector2) -> void:
	print("Co-op Stub: Would deploy invasion at %s with %d genes (not implemented)" % [str(drop_position), rival_genes.size()])
