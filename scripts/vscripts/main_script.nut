Msg( "-----------------------------------\n" );
Msg( "  Mob Rushers Initialized\n"    );
Msg( "-----------------------------------\n" );

// CONSTANTS
const PREFIXMSG				= "<[[Mob Rushers]]>";
const INFALERTMSG			= "The Infected has been alerted! Try to survive, good luck!";
const GREEN_CLR 			= "\x03";
const ORANGE_CLR 			= "\x04";
const SPACER_MSG 			= " ";

const DIFF_EASY				= 0;
const DIFF_NORMAL			= 1;
const DIFF_HARD				= 2;
const DIFF_IMPOSSIBLE		= 3;

const MINIHORDE_COOLDOWN	= 30.0;

::lastMiniHordeTime <- 0.0;


foreach ( sound in ::WarnSound )
{
	if ( !IsSoundPrecached( sound ) )
		PrecacheSound( sound );
}

function IsScriptAllowedForGameMode()
{
	local gameMode = Director.GetGameMode();
	printl( "[Mob Rushers] Detected game mode: '" + gameMode + "'" );

	// Check if gameMode is in the disabled list
	if ( ::Settings.DisableOnGamemodes.find( gameMode ) != null )
	{
		printl( "[Mob Rushers] Running in " + gameMode + ", NOT RUNNING!" );
		return true;
	}

	printl( "[Mob Rushers] Script running for game mode: " + gameMode );
	return true;
}

function StartInfectedChaseThink()
{
	if ( !Director.HasAnySurvivorLeftSafeArea() ) return;	// Do not run if we haven't leave the saferoom yet.

	local randSurvivor 			= GetRandomSurvivor();
	local maxSpawnLimit 		= ::Settings.MaxSpawnedCommonInf;
	local countScriptedSpawn 	= ::spawnedInfected.len(); 				// Count our spawned infected.
	local spawnChance 			= 0;									// Spawn chance for our rushing infected to spawn in.
	local iCount 				= 0;									// Our inital Spawn Count amount.

	if ( randSurvivor == null ) return;

	// Allow wanders to rush towards the survivors.
	if ( ::Settings.ShouldAllRush )
	{
		if ( randSurvivor != null )
		{
			CommandInfectedToAttackSurvivors( randSurvivor );
		}
	}

	CleanSpawnedInfectedList(); // Clean up the list before we do more crap.

	// Get spawn chance based on difficulty
	switch ( GetDifficulty() )
	{
		case DIFF_EASY:
			iCount = RandomInt( ::Settings.SpawnCountMin_Easy, ::Settings.SpawnCountMax_Easy );
			spawnChance = ::Settings.SpawnChance_Easy;
		break;

		case DIFF_NORMAL:
			iCount = RandomInt( ::Settings.SpawnCountMin_Norm, ::Settings.SpawnCountMax_Norm );
			spawnChance = ::Settings.SpawnChance_Norm;
		break;

		case DIFF_HARD:
			iCount = RandomInt( ::Settings.SpawnCountMin_Adv, ::Settings.SpawnCountMax_Adv );
			spawnChance = ::Settings.SpawnChance_Adv;
		break;

		case DIFF_IMPOSSIBLE:
			iCount = RandomInt( ::Settings.SpawnCountMin_Exp, ::Settings.SpawnCountMax_Exp );
			spawnChance = ::Settings.SpawnChance_Exp;
		break;
	}

	// For testing ONLY!!!!
	if ( Director.GetGameMode() == "survival" )
		spawnChance = 50; // 50% of normal chance

	// Finale logic: Lower the iCount and spawnChance
	// so we do not softlock the finale.
	if ( Director.IsFinale() )
	{
		// Halve spawn count and reduce chance during finale
		//iCount = ceil( iCount * 0.65 );
		//spawnChance = spawnChance * 0.65;
		iCount = 1
		spawnChance = 5;
		if ( ::Settings.DebugMode )
			printl( "[Mob Rushers] Finale active—spawn count halved to " + iCount + ", chance reduced to " + spawnChance + "%" );
	}

	local roll = RandomInt( 0, 100 );

	printl( "=====================================================");
	printl( format( "Difficulty: %d, Spawn Count: %d, Chance: %d, Roll: %d", GetDifficulty(), iCount, spawnChance, roll ) );
	printl( format( "Scripted Spawned: %d, Total CI: %d", countScriptedSpawn, GetCICount() ) );
	printl( "=====================================================");

	if ( roll >= spawnChance || countScriptedSpawn >= maxSpawnLimit )
	{
		if ( ::Settings.DebugMode && roll >= spawnChance )
			printl( "[Mob Rushers] Spawn skipped: roll (" + roll + ") >= chance (" + spawnChance + ")" );
		return;
	}

	// Mini-Horde Chance with Cooldown
	local isMiniHorde = false;
	local availableSlots = maxSpawnLimit - countScriptedSpawn;
	local currentTime = Time();
	if ( RandomInt( 0, 100 ) < ::Settings.MiniHordeChance && ( currentTime - ::lastMiniHordeTime >= MINIHORDE_COOLDOWN ) )
	{
		if ( Director.IsFinale() ) return;

		local potentialCount = RandomInt( 10, 15 );
		if ( potentialCount >= 10 && potentialCount <= availableSlots )
		{
			isMiniHorde = true;	// We're a mini horde, so we can display our GI message
			iCount = potentialCount;
			::lastMiniHordeTime = currentTime;
			if ( ::Settings.DebugMode )
				printl( "[Mob Rushers] Mini-horde triggered! Spawn count set to " + iCount );
		}
		else if ( ::Settings.DebugMode )
		{
			printl( "[Mob Rushers] Mini-horde skipped: insufficient slots (" + availableSlots + ") or too small (" + potentialCount + ")" );
		}
	}
	else if ( ::Settings.DebugMode && ( currentTime - ::lastMiniHordeTime < MINIHORDE_COOLDOWN ) )
	{
		printl( "[Mob Rushers] Mini-horde on cooldown: " + format( "%.1f", MINIHORDE_COOLDOWN - ( currentTime - ::lastMiniHordeTime ) ) + " seconds remaining" );
	}

	// Spawn our Rushing infected
	local isSameArea;
	local spawnPos = null;
	local spawnedCount = 0;
	local lastSpawnPos = spawnPos; // Cache last position for same-area spawns
	for ( local i = 0; i < iCount && countScriptedSpawn < maxSpawnLimit; i++ )
	{
		if ( isMiniHorde )
			isSameArea = true;
		else
			isSameArea = RandomInt( 0, 100 ) < 75;

		// Determine spawn position
		if ( i == 0 || !isSameArea )
		{
			spawnPos = FindValidSpawnLocation( randSurvivor, !isSameArea );
			if ( !spawnPos )
			{
				if ( ::Settings.DebugMode )
					printl( "[Mob Rushers] Failed to find spawn location on attempt " + i );
				if ( i == 0 ) return; // Critical failure on first try

				break; // Fallback failed, stop spawning
			}
			lastSpawnPos = spawnPos;
		}
		else
		{
			spawnPos = lastSpawnPos; // Reuse position for same-area horde
		}

		/*
			if AllowNearSpawning is enabled, we will try
			to find a new position that is not close to survivors.
			If disabled, don't try to refind an area.
		*/
/* 		if ( !::Settings.AllowNearSpawning )
		{
			local survivorPos = randSurvivor.GetOrigin();
			local distance = ( spawnPos - survivorPos ).Length();
			if ( distance < 500 )
			{
				if ( ::Settings.DebugMode )
					printl( "[Mob Rushers] Spawn too close (" + distance + " units), retrying..." );

				spawnPos = FindValidSpawnLocation( randSurvivor, !isSameArea );
				if ( !spawnPos ) continue; // Skip this iteration if retry fails
			}
		}
 */
		// Spawn the infected
		local infEnt = SpawnEntityFromTable( "infected", { origin = spawnPos, targetname = "task_zombie_ci" } );
		if ( infEnt && infEnt.IsValid() )
		{
			NetProps.SetPropInt( infEnt, "m_mobRush", 1 );
			::spawnedInfected.append( infEnt );
			spawnedCount++;
			countScriptedSpawn++;

			if ( ::Settings.DebugMode )
				printl( "[Mob Rushers] Spawned infected at " + spawnPos );
		}
	}

	// Play sound and hint if enough infected spawned
	if ( isMiniHorde && spawnedCount > 10 )
	{
		DisplayInstructorHint( HintMinihordeAlert );
		local randomIndex = RandomInt(0, ::WarnSound.len() - 1 );
		local randomSound = ::WarnSound[ randomIndex ];
		EmitAmbientSoundOn( randomSound, 0.75, 0, 100, Entities.First() );
	}


	// Post-spawn feedback
	if ( spawnedCount > 0 && ::Settings.DebugMode )
	{
		local INFALERTMSG = isSameArea ? "Same area spawn" : "New random location";
		printl( "[Mob Rushers] " + INFALERTMSG + ": Spawned " + spawnedCount + " infected" );
	}
}

function GetCICount()
{
	local infected = null;
	local count = 0

	while ( infected = Entities.FindByClassname( infected, "infected" ) )
	{
		count++
	}

	return count
}

// dumb hack way to mimick GetInt from TF2's VScript
function GetConVarInt( CVarName )
{
	local floatValue = Convars.GetFloat( CVarName )
	local lower = floor( floatValue )
	local upper = lower + 1

	if ( floatValue - lower < upper - floatValue )
	{
		return lower
	}
	else
	{
		return upper
	}
}

function UpdateSurvivorLists()
{
	// Clear current lists
	::humanSurvivors.clear();
	::botSurvivors.clear();

	for ( local player; player = Entities.FindByClassname( player, "player" ); )
		if ( player.IsSurvivor() )
			if ( !player.IsDead() )
				if ( IsPlayerABot( player ) ) // Human players
					::humanSurvivors.append( player );
				else // Bot survivors
					::botSurvivors.append( player );

	if ( ::Settings.DebugMode )
	{
		printl( "Updated human survivors count: " + ::humanSurvivors.len() );
		printl( "Updated bot survivors count: " + ::botSurvivors.len() );
	}
}

function GetRandomSurvivor()
{
	// Update the lists before selecting a survivor
	UpdateSurvivorLists();

	// Prioritize human survivors
	if ( ::humanSurvivors.len() > 0 )
	{
		if ( ::Settings.DebugMode )
			printl( "IS HUMAN PLAYER SURVIVOR" );

		return ::humanSurvivors[ RandomInt( 0, ::humanSurvivors.len() - 1 ) ];
	}
	// Fall back to bot survivors if no humans are alive
	else if ( ::botSurvivors.len() > 0 )
	{
		if ( ::Settings.DebugMode )
			printl( "IS BOT PLAYER SURVIVOR" );
		return ::botSurvivors[ RandomInt( 0, ::botSurvivors.len() - 1 ) ];
	}
	else
	{
		if ( ::Settings.DebugMode )
			printl( "NO SURVIVOR FOUND!" );
		return null; // No alive survivors found
	}
}

/* // OLD OLD OLD OLD
function GetRandomSurvivor()
{
	local survivors = [];
	for ( local player; player = Entities.FindByClassname( player, "player" ); )
	{
		if ( player.IsSurvivor() && !player.IsDead() )
		{
			survivors.append( player );
		}
	}

	if ( survivors.len() > 0 )
	{
		return survivors[ RandomInt( 0, survivors.len() - 1 ) ];
	}
	else
	{
		return null; // No Survivors found! This should NEVER Happen, unless all die, but regardless.
	}
} */

function IsPlayerABot( player )
{
	return NetProps.GetPropInt( player, "m_humanSpectatorUserID" ) == -1;
}

function CleanSpawnedInfectedList()
{
	local i = 0;
	while ( i < ::spawnedInfected.len() )
	{
		if ( !::spawnedInfected[ i ] || !::spawnedInfected[ i ].IsValid() )
		{
			::spawnedInfected.remove( i );
		}
		else
		{
			i++;
		}
	}
}

function FindValidSpawnLocation( survivorPos, randomNavArea = false )
{
	local SpawnRadius = RandomInt( ::Settings.SpawnDistMin, ::Settings.SpawnDistMax );
	local SurvPos = survivorPos.GetOrigin();
	local allNavAreas = {};

	NavMesh.GetNavAreasInRadius( SurvPos, SpawnRadius, allNavAreas );

	// Find nonvisble areas and areas that we should spawn in.
	local nonVisibleAreas = [];
	foreach ( navArea in allNavAreas )
	{
		if ( !navArea.HasSpawnAttributes( 65536 ) && !navArea.IsDamaging() && !navArea.IsBlocked( 3, false ) && !navArea.IsPotentiallyVisibleToTeam( 2 ) )
		{
			nonVisibleAreas.push( navArea );
		}
	}

	local result = null;
	if ( nonVisibleAreas.len() > 0 )
	{
		local chosenArea = randomNavArea ? nonVisibleAreas[ RandomInt( 0, nonVisibleAreas.len() - 1 ) ] : nonVisibleAreas[ 0 ];
		if ( ::Settings.DebugMode )
		{
			printl( "[Mob Rushers] Found hidden spawn location! Areas checked: " + allNavAreas.len() + ", Non-visible to survivors: " + nonVisibleAreas.len() );
			chosenArea.DebugDrawFilled( 20, 175, 20, 128, 5.0, true );
		}
		local basePos = chosenArea.FindRandomSpot();
		result = Vector( basePos.x, basePos.y, basePos.z + 10 );
	}
	else if ( ::Settings.DebugMode )
	{
		printl ( "[Mob Rushers] No hidden spawn location found. Total areas: " + allNavAreas.len() );
	}

	allNavAreas = {};
	nonVisibleAreas = [];
	return result;

}

function CommandInfectedToAttackSurvivors( targetSurvivor )
{
	if ( targetSurvivor != null )
	{
		for ( local infected; infected = Entities.FindByClassname( infected, "infected" ); )
		{
			if ( infected.IsValid() )
			{
				if ( NetProps.GetPropInt( infected, "m_mobRush" ) == 0 )
					NetProps.SetPropInt( infected, "m_mobRush", 1 );
			}
		}
	}
}

function OnGameEvent_round_start_post_nav( params )
{
	SetupConfigSettings()

	if ( IsScriptAllowedForGameMode() )
	{
		g_MapScript.ScriptedMode_AddUpdate( StartInfectedChaseThink );
	}
}

// Alert the survivors of the incoming rushing infected.
function OnGameEvent_player_left_safe_area( params )
{
	if ( IsScriptAllowedForGameMode() )
	{
		ClientPrint( null, 3, format( GREEN_CLR + PREFIXMSG + ORANGE_CLR + SPACER_MSG + INFALERTMSG ) );
		local randomIndex = RandomInt( 0, ::WarnSound.len() - 1 );
		local randomSound = ::WarnSound[ randomIndex ];
		EmitAmbientSoundOn( randomSound, 1.0, 0, 100, Entities.First() );
	}
}

__CollectEventCallbacks( this, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener );