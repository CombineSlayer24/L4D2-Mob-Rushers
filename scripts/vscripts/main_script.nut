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
	printl( "Detected game mode: '" + gameMode + "'" );

	// Check if gameMode is in the disabled list
	if ( ::Settings.DisableOnGamemodes.find( gameMode ) != null )
	{
		printl( "Running in " + gameMode + ", NOT RUNNING!" );
		return true;
	}

	printl( "Script running for game mode: " + gameMode );
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
		spawnChance = 60; // 60% of normal chance

	// Finale logic: Lower the iCount and spawnChance
	// so we do not softlock the finale.
	if ( Director.IsFinale() )
	{
		// Halve spawn count and reduce chance during finale
		//iCount = ceil( iCount * 0.65 );
		//spawnChance = spawnChance * 0.65;
		iCount = 1
		spawnChance = 5;
		DebugMsg( "Finale active—spawn count halved to " + iCount + ", chance reduced to " + spawnChance + "%" );
	}

	// Funny name, if RTD lands above our Chance, spawn it!
	local rollTheDice = RandomInt( 0, 100 );

	printl( "=====================================================" );
	printl( format( "Difficulty: %d, Spawn Count: %d, Chance: %d, rollTheDice: %d", GetDifficulty(), iCount, spawnChance, rollTheDice ) );
	printl( format( "Scripted Spawned: %d, Total CI: %d", countScriptedSpawn, GetCICount() ) );
	printl( "=====================================================" );

	// Our rollTheDice chances for spawning happens here!
	if ( rollTheDice >= spawnChance || countScriptedSpawn >= maxSpawnLimit )
	{
		if ( rollTheDice >= spawnChance )
			DebugMsg( "Spawn skipped: rollTheDice (" + rollTheDice + ") >= chance (" + spawnChance + ")" );
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
			DebugMsg( "Mini-horde triggered! Spawn count set to " + iCount );
		}
		else
		{
			DebugMsg( "Mini-horde skipped: insufficient slots (" + availableSlots + ") or too small (" + potentialCount + ")" );
		}
	}
	else if ( currentTime - ::lastMiniHordeTime < MINIHORDE_COOLDOWN )
	{
		DebugMsg( "Mini-horde on cooldown: " + format( "%.1f", MINIHORDE_COOLDOWN - ( currentTime - ::lastMiniHordeTime ) ) + " seconds remaining" );
	}

	// Spawn our Rushing infected
	local spawnPos = null;
	local lastSpawnPosTable = { pos = null };
	local spawnedCount = 0;

	for ( local i = 0; i < iCount && countScriptedSpawn < maxSpawnLimit; i++ )
	{
		local spawnSameArea = isMiniHorde || ( i > 0 && RandomInt( 0, 100 ) < 75 );
		spawnPos = FindValidSpawnLocation( randSurvivor, spawnSameArea, lastSpawnPosTable );

		if ( !spawnPos )
		{
			DebugMsg( "Failed to find spawn location on attempt " + i );
			if ( i == 0 ) return;
			break;
		}

		local infEnt = SpawnEntityFromTable( "infected", { origin = spawnPos, targetname = "task_zombie_ci" } );
		if ( infEnt && infEnt.IsValid() )
		{
			NetProps.SetPropInt( infEnt, "m_mobRush", 1 );
			local gender = NetProps.GetPropInt( infEnt, "m_Gender" )
			// Do not modify health on Uncommon Infected
			if ( !gender == 11 || !gender == 12 || !gender == 13
				|| !gender == 14
				|| !gender == 15
				|| !gender == 16
				|| !gender == 17 )
			{
				NetProps.SetPropInt( infEnt, "m_iMaxHealth", 30 )
				NetProps.SetPropInt( infEnt, "m_iHealth", 30 )
			}
			::spawnedInfected.append( infEnt );
			spawnedCount++;
			countScriptedSpawn++;

			DebugMsg( "Spawned infected at " + spawnPos );
		}
	}

	if ( isMiniHorde && spawnedCount > 10 )
	{
		DisplayInstructorHint( HintMinihordeAlert );
		local randomIndex = RandomInt( 0, ::WarnSound.len() - 1 );
		local randomSound = ::WarnSound[ randomIndex ];
		EmitAmbientSoundOn( randomSound, 0.75, 0, 100, Entities.First() );
	}

	if ( spawnedCount > 0 )
	{
		local debugMsg = ( lastSpawnPosTable.pos && spawnPos == lastSpawnPosTable.pos + Vector( 0, 0, 10 ) ) ? "Same area spawn" : "New random location";
		DebugMsg( "" + debugMsg + ": Spawned " + spawnedCount + " infected" );
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

	DebugMsg( "Updated human survivors count: " + ::humanSurvivors.len() );
	DebugMsg( "Updated bot survivors count: " + ::botSurvivors.len() );
}

function GetRandomSurvivor()
{
	// Update the lists before selecting a survivor
	UpdateSurvivorLists();

	// Prioritize human survivors
	if ( ::humanSurvivors.len() > 0 )
	{
		DebugMsg( "IS HUMAN PLAYER SURVIVOR" );
		return ::humanSurvivors[ RandomInt( 0, ::humanSurvivors.len() - 1 ) ];
	}
	// Fall back to bot survivors if no humans are alive
	else if ( ::botSurvivors.len() > 0 )
	{
		DebugMsg( "IS BOT PLAYER SURVIVOR" );
		return ::botSurvivors[ RandomInt( 0, ::botSurvivors.len() - 1 ) ];
	}
	else
	{
		DebugMsg( "NO SURVIVOR FOUND!" );
		return null; // No alive survivors found
	}
}

// NEW NEW NEW NEW
/* function GetRandomSurvivor()
{
	local survivors = { humans = [], bots = [] };
	local ent = null;

	// Collect all alive survivors
	while ( ent = Entities.FindByClassname( ent, "player" ) )
	{
		if ( ent.IsValid() && ent.IsSurvivor() && !ent.IsDead() )
		{
			if ( IsPlayerABot( ent ) )
				survivors.bots.append( ent );
			else
				survivors.humans.append( ent );
		}
	}

	DebugMsg( "Found " + survivors.humans.len() + " human survivors, " + survivors.bots.len() + " bot survivors" );

	// Prioritize human survivors
	if ( survivors.humans.len() > 0 )
	{
		DebugMsg( "Selecting random human survivor" );
		return survivors.humans[ RandomInt( 0, survivors.humans.len() - 1 ) ];
	}
	// Fall back to bot survivors
	else if ( survivors.bots.len() > 0 )
	{
		DebugMsg( "Selecting random bot survivor" );
		return survivors.bots[ RandomInt( 0, survivors.bots.len() - 1 ) ];
	}
	else
	{
		DebugMsg( "No survivors found!" );
		return null;
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

function FindValidSpawnLocation( survivor, spawnSameArea = false, lastSpawnPosTable = null )
{
	if ( !survivor || !survivor.IsValid() )
	{
		DebugMsg( "Invalid survivor for spawn location search" );
		return null;
	}

	local playerPos = survivor.GetOrigin();
	local maxDist = ::Settings.SpawnDistMax.tofloat();
	local minDist = ::Settings.SpawnDistMin.tofloat();
	local attempts = 50;

	DebugMsg( "Finding spawn for survivor at " + playerPos + ", range: " + minDist + "–" + maxDist );

	// Collect all alive survivors for visibility check
	local survs = [];
	local ent = null;
	while ( ent = Entities.FindByClassname( ent, "player" ) )
	{
		if ( ent.IsValid() && ent.IsSurvivor() && !ent.IsDead() )
			survs.append( ent );
	}

    if ( spawnSameArea && lastSpawnPosTable != null && "pos" in lastSpawnPosTable && lastSpawnPosTable.pos != null )
    {
        local dist = CalculateDistance( lastSpawnPosTable.pos, playerPos );
        DebugMsg( "Reusing same area spawn at " + lastSpawnPosTable.pos + " (dist: " + dist + ")" );
        return lastSpawnPosTable.pos + Vector( 0, 0, 10 );
    }

	for ( local i = 0; i < attempts; i++ )
	{
		local _pos = survivor.TryGetPathableLocationWithin( maxDist );
		if ( !_pos )
		{
			DebugMsg( "Attempt " + i + ": No pathable location found" );
			continue;
		}

/* 		local dist = CalculateDistance( _pos, playerPos );
		if ( dist > maxDist || dist < minDist )
		{
			DebugMsg( "Attempt " + i + ": Position " + _pos + " out of range (" + dist + ")" );
			continue;
		} */

		local canSee = false;
		foreach ( surv in survs )
		{
			if ( !surv.IsValid() || surv.IsDead() )
				continue;

			local survivorEyeAng = GetEyeAngles( surv );
			if ( !survivorEyeAng )
			{
				DebugMsg( "Survivor " + surv + " has no eye angles" );
				continue;
			}

			local posLeft = _pos + survivorEyeAng.Left().Scale( 64 );
			local posRight = _pos + survivorEyeAng.Left().Scale( -64 );

			local traceResults = [
				CanTraceToLocation( surv, _pos ),
				CanTraceToLocation( surv, _pos + Vector( 0, 0, 128 ) ),
				CanTraceToLocation( surv, posLeft ),
				CanTraceToLocation( surv, posRight )
			];

			if ( traceResults[ 0 ] || traceResults[ 1 ] || traceResults[ 2 ] || traceResults[ 3 ] )
			{
				canSee = true;
				DebugMsg( "Attempt " + i + ": Survivor " + surv + " can see " + _pos + " (traces: " + traceResults + ")" );
				break;
			}

/* 			local survDist = CalculateDistance( _pos, surv.GetOrigin() );
			if ( survDist < minDist )
			{
				canSee = true;
				DebugMsg( "Attempt " + i + ": Survivor " + surv + " too close to " + _pos + " (" + survDist + ")" );
				break;
			} */
		}

		if ( !canSee )
		{
			if ( lastSpawnPosTable != null )
				lastSpawnPosTable.pos <- _pos;

			DebugMsg( "Found valid spawn at " + _pos + " after " + ( i + 1 ) + " attempts" );
			if ( ::Settings.DebugMode )
				DebugDrawLine( playerPos, _pos, 0, 255, 0, true, 5.0 );
			return _pos + Vector( 0, 0, 10 );
		}
	}

	DebugMsg( "No valid spawn location found after " + attempts + " attempts" );
	return null;
}

function DebugMsg( text )
{
    if ( ::Settings.DebugMode )
		printl( "[Mob Rushers] " + text );
}

// Credit to VSLib for these
function GetEyeAngles( entity )
{
	if ( !entity || !entity.IsValid() )
	{
		DebugMsg( "Warning: Invalid entity in GetEyeAngles" );
		return null;
	}

	if ( !("EyeAngles" in entity) )
	{
		DebugMsg( "Warning: Entity does not have EyeAngles method" );
		return null;
	}

	return entity.EyeAngles();
}

function GetEyePosition( entity )
{
	if ( !entity || !entity.IsValid() )
	{
		DebugMsg( "Warning: Invalid entity in GetEyePosition" );
		return null;
	}

	if ( !("EyePosition" in entity) )
	{
		DebugMsg( "Warning: Entity does not have EyePosition method, falling back to GetOrigin" );
		return entity.GetOrigin();
	}

	return entity.EyePosition();
}

function CanTraceToLocation( player, finishPos, traceMask = 131083 )
{
	if ( !player || !player.IsValid() )
		return false;

	local begin = GetEyePosition( player );
	if ( !begin )
		return false; // Fallback if eye position can’t be determined

	local m_trace = { start = begin, end = finishPos, ignore = player, mask = traceMask };
	TraceLine( m_trace );

	return AreVectorsEqual( m_trace.pos, finishPos );
}

function CalculateDistance( vec1, vec2 )
{
	if ( !vec1 || !vec2 )
		return -1.0;
	return ( vec2 - vec1 ).Length();
}

function AreVectorsEqual( vec1, vec2 )
{
	return vec1.x == vec2.x && vec1.y == vec2.y && vec1.z == vec2.z;
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