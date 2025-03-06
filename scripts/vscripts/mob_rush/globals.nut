// GLOBALS
::humanSurvivors 	<- [];	// Get all alive human survivors
::botSurvivors 		<- [];	// Get all alive bot survivors
::spawnedInfected 	<- []; 	// Get all alive spawned infected with script

::WarnSound 		<-
[
	"music/mob/germl1b.wav"
	"music/mob/germm1b.wav"
	"music/mob/germs1a.wav"
	"music/mob/germs2a.wav"
	"music/mob/germs2b.wav"

	// New
	"music/mob/mallgerml1a.wav"
	"music/mob/mallgerml1b.wav"
	"music/mob/easygermm1a.wav"
	"music/mob/easygermm1b.wav"
	"music/mob/milltowngermm2a.wav"
	"music/mob/milltowngermx1c.wav"
	"music/mob/parishtmptgermx1c.wav"
	"music/mob/parishtmptgermx1d.wav"
	"music/mob/deadlightgerml2b.wav"
	"music/mob/deadlightgermm1b.wav"
]

::HintMinihordeAlert <-
{
	hint_name = "hint_minihorde_alert"
	hint_caption = "Incoming Mini-Horde!",
	hint_timeout = 8,
	hint_icon_onscreen = "icon_alert",
	hint_instance_type = 2,
	hint_color = "240 240 50"
}

::Settings			<-
{
	/*
		-- Possible TODO settings --
		- SameAreaSpawnChance		// todo
		- AllowFinaleTankAssistance	// Spawn alongside the Finale Tank
	*/

	// -------------
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
	//AllowNearSpawning 	= true 		// if true, the script will not attempt to refind spawn positions that were too close to the survivors
}

function FormatValue(val) {
	if (type(val) == "string") {
		return "\"" + val + "\"";
	}
	else if (type(val) == "array") {
		local s = "[";
		for (local i = 0; i < val.len(); i++) {
			s += FormatValue(val[i]);
			if (i < val.len() - 1) s += ", ";
		}
		s += "]";
		return s;
	}
	return val.tostring();
}

function SetupConfigSettings()
{
	local SettingsFileName = "mob_rushers/Settings.cfg";
	local function SerializeSettings() {
		// Helps make the CFG look neater. (Yes, WE NEED NEATNESS, DAMNIT)
		local orderedKeys = [
			"SpawnCountMin_Easy",
			"SpawnCountMax_Easy",
			"SpawnChance_Easy",
			"SpawnCountMin_Norm",
			"SpawnCountMax_Norm",
			"SpawnChance_Norm",
			"SpawnCountMin_Adv",
			"SpawnCountMax_Adv",
			"SpawnChance_Adv",
			"SpawnCountMin_Exp",
			"SpawnCountMax_Exp",
			"SpawnChance_Exp",
			"SpawnDistMin",
			"SpawnDistMax",
			"MaxSpawnedCommonInf",
			"ShouldAllRush",
			"DisableOnGamemodes",
			"MiniHordeChance",
			"DebugMode",
			//"AllowNearSpawning"
		];

		local sData = "{\n";
		foreach ( key in orderedKeys )
		{
			if ( key in ::Settings )
			{
				sData += format( "\t%-20s = %s\n", key, FormatValue( ::Settings[ key ] ) );
			}
		}
		sData += "}";
		StringToFile( SettingsFileName, sData );
	}

	// Load existing file if it exists
	local file = FileToString(SettingsFileName);
	if (file != null) {
		try {
			local loadedSettings = compilestring("return " + file)();
			if (typeof loadedSettings == "table") {
				local hasMissingKey = false;
				foreach (key, val in ::Settings) {
					if (key in loadedSettings) {
						::Settings[key] = loadedSettings[key];
					}
					else { hasMissingKey = true; }
				}
				if ( hasMissingKey )
				{
					printl( "[Mob Rushers] Config file missing keys, rewriting..." );
					SerializeSettings();
				}
			}
			else
			{
				printl( "[Mob Rushers] Config file invalid, regenerating..." );
				SerializeSettings();
			}
		}
		catch ( e )
		{
			printl( "[Mob Rushers] Error parsing config file (" + e + "), regenerating..." );
			SerializeSettings();
		}
	}
	else
	{
		printl( "[Mob Rushers] No config file found, creating new one..." );
		SerializeSettings();
	}
}

function DisplayInstructorHint( keyvalues, target = null, player = null )
{
	keyvalues.classname <- "env_instructor_hint";
	keyvalues.hint_auto_start <- 0;
	keyvalues.hint_allow_nodraw_target <- 1;

	if ( target && target.IsValid() )
	{
		keyvalues.hint_target <- target.GetName();
		keyvalues.hint_static <- 0;
		//keyvalues.hint_range <- 1500; // Use the range you have set in LootDroppedHint
	}
	else
	{
		// Static target for fallback
		if ( Entities.FindByName( null, "static_hint_target" ) == null )
			SpawnEntityFromTable( "info_target_instructor_hint", { targetname = "static_hint_target" } );

		keyvalues.hint_target <- "static_hint_target";
		keyvalues.hint_static <- 1;
		keyvalues.hint_range <- 0;
	}

	local hint = SpawnEntityFromTable( "env_instructor_hint", keyvalues );
	//printl( hint );

	if ( player )
	{
		DoEntFire( "!self", "ShowHint", "", 0, player, hint );
	}
	else
	{
		local player = null;
		while ( player = Entities.FindByClassname( player, "player" ) )
		{
			//printl( player );
			DoEntFire( "!self", "ShowHint", "", 0, player, hint );
		}
	}

	if ( keyvalues.hint_timeout && keyvalues.hint_timeout != 0 )
	{
		DoEntFire( "!self", "Kill", "", keyvalues.hint_timeout, null, hint );
	}

	return hint;
}