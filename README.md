# L4D2-Mob-Rushers - [WIP]
You'll always be on your toes. Common Infected will spawn around Survivors and rush at them, breaking up their little breaks and rest.

# Bugs
- Common Infected can spawn in the view of Survivors.

# Configureable Settings
	SpawnCountMin_Easy 	= 1			// Minimum random amount of Common Infected to spawn
	SpawnCountMax_Easy 	= 5			// Maximum random amount of Common Infected to spawn
	SpawnChance_Easy 	= 5			// How frequent should we try to spawn? Low numbers = higher chances. High numbers = lower chances
	// -------------
	SpawnCountMin_Norm 	= 2
	SpawnCountMax_Norm 	= 6
	SpawnChance_Norm 	= 10
	// -------------
	SpawnCountMin_Adv 	= 3
	SpawnCountMax_Adv 	= 8
	SpawnChance_Adv 	= 20
	// -------------
	SpawnCountMin_Exp 	= 4
	SpawnCountMax_Exp 	= 8
	SpawnChance_Exp     = 15
	SpawnDistMin 		= 1250		// Minimum distance to spawn around the survivors
	SpawnDistMax 		= 2000		// MAximum distance to spawn around the survivors
	// -------------

	MaxSpawnedCommonInf = 30		// Maximum allowed ScriptSapwn Infected allowed
	ShouldAllRush 		= false		// Should Wandering infected be allowed to rush?
	DisableOnGamemodes 	= [ "survival", "scavenge", "mutation15" ]	// Gamemodes that the script should NOT be active in.
	MiniHordeChance     = 20, 		// % chance for a mini-horde
	DebugMode 			= false 	// Show some debug information on the host (Unless you're tinkering or modding this, why would you need this???)
