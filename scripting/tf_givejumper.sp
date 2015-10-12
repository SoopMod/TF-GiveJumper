#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>
#include <sdkhooks>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_VERSION          "0.1.0"
public Plugin myinfo = {
    name = "[TF2] Auto-give Rocket Jumper",
    author = "nosoop",
    description = "Rocket Jumpers for everyone!",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

#define ROCKETJUMPER_DEFINDEX	237
#define ROCKETJUMPER_CLASSNAME	"tf_weapon_rocketlauncher"

// Determines whether or not Rocket Jumpers are enabled.
// This cannot be changed while the map is running, because it's a pain to hook / unhook everything.
Handle g_hConVarJumperEnabled = null;
bool g_bJumperEnabled = false;

bool g_ClientUsingJumperOverride[MAXPLAYERS+1];
float g_ClientLastResupplyTime[MAXPLAYERS+1];

public void OnPluginStart() {
	g_hConVarJumperEnabled = CreateConVar("sm_grantjumper_enabled", "0", "Determine whether granting of Rocket Jumpers can be used.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_DONTRECORD, true, 0.0, true, 1.0);

	HookEvent("post_inventory_application", Event_PlayerInventoryApplication_Post, EventHookMode_Post);
	RegConsoleCmd("sm_togglejumper", AdminCmd_ToggleJumper, "Toggles auto-granting of Rocket Jumpers on a player.");
	
	for (int i = MaxClients; i > 0; --i) {
		OnClientPutInServer(i);
	}
	
	LoadTranslations("core.phrases");
}

public void OnConfigsExecuted() {
	g_bJumperEnabled = GetConVarBool(g_hConVarJumperEnabled);
	
	if (g_bJumperEnabled) {
		LogMessage("Automatic granting of Rocket Jumpers enabled.");
		DisableResuppliesOnNextFrameIfDesirable();
	}
}

/**
 * Disable the resupplies once the server's running.  Or something.
 * Probably a really dumb hack, but fuck if I know how the resupplies are enabled.
 *
 * (TODO test DispatchKeyValue(entity, "StartDisabled", "1"))
 */
public void TF2_OnWaitingForPlayersStart() { DisableResuppliesOnNextFrameIfDesirable(); }
public void TF2_OnWaitingForPlayersEnd() { DisableResuppliesOnNextFrameIfDesirable(); }

void DisableResuppliesOnNextFrameIfDesirable() {
	if (g_bJumperEnabled) {
		RequestFrame(RequestFrameCallback_DisableResupply);
	}
}

public void RequestFrameCallback_DisableResupply(any data) {
	SetRegeneratorState(false);
}

void SetRegeneratorState(bool bEnabled) {
	int regeneratorFuncs = -1;
	while ((regeneratorFuncs = FindEntityByClassname(regeneratorFuncs, "func_regenerate")) != -1) {
		AcceptEntityInput(regeneratorFuncs, bEnabled ? "Enable" : "Disable");
	}
}

public Action AdminCmd_ToggleJumper(int client, int nArgs) {
	if (!g_bJumperEnabled) {
		return Plugin_Handled;
	} else if (!CheckCommandAccess(client, "jumper", ADMFLAG_CHEATS)) {
		ReplyToCommand(client, "[SM] %t.", "No Access");
		return Plugin_Handled;
	}
	
	g_ClientUsingJumperOverride[client] = !g_ClientUsingJumperOverride[client];
	PrintToChat(client, "Jumper mode %s", g_ClientUsingJumperOverride[client] ? "enabled" : "disabled");
	
	if (g_ClientUsingJumperOverride[client]) {
		ReplacePrimaryWithJumper(client);
	}
	
	return Plugin_Handled;
}

public void OnClientPutInServer(int client) {
	g_ClientUsingJumperOverride[client] = false;
	
	if (g_bJumperEnabled && IsClientInGame(client)) {
		SDKHook(client, SDKHook_Touch, SDKHookCB_OnResupplyTouch);
	}
}

/**
 * Replace resupply handling with own implementation.
 */
public void SDKHookCB_OnResupplyTouch(int client, int other) {
	// How slow is GetEntityClassname?  Maybe store a list of func_regenerate entities instead
	char entityName[64];
	GetEntityClassname(other, entityName, sizeof(entityName));
	if (StrEqual(entityName, "func_regenerate") && GetGameTime() > g_ClientLastResupplyTime[client] + 5.0) {
		if (!g_ClientUsingJumperOverride[client]) {
			TF2_RegeneratePlayer(client);
		} else {
			// TODO iterate over weapons and refill clips that way
			int hActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			GivePlayerAmmo(client, 99, GetEntProp(hActiveWeapon, Prop_Data, "m_iPrimaryAmmoType"), true);
			
			// Refill clip for Rocket Jumper.  Hopefully.
			SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Data, "m_iClip1", 4);
		}
		g_ClientLastResupplyTime[client] = GetGameTime();
	}
}

public void Event_PlayerInventoryApplication_Post(Event event, const char[] name, bool dontBroadcast) {
	if (g_bJumperEnabled) {
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (g_ClientUsingJumperOverride[client]) {
			ReplacePrimaryWithJumper(client);
		}
	}
}

void ReplacePrimaryWithJumper(int client) {
	TF2_RemoveWeaponSlot(client, 0);

	Handle hRocketJumper = TF2Items_CreateItem(OVERRIDE_ALL | PRESERVE_ATTRIBUTES);
	TF2Items_SetItemIndex(hRocketJumper, ROCKETJUMPER_DEFINDEX);
	TF2Items_SetClassname(hRocketJumper, ROCKETJUMPER_CLASSNAME);
	TF2Items_SetQuality(hRocketJumper, 0);
	TF2Items_SetLevel(hRocketJumper, 1);
	TF2Items_SetNumAttributes(hRocketJumper, 1);
	TF2Items_SetAttribute(hRocketJumper, 0, 1, 0.0); // 100% damage penalty
	
	int jumper = TF2Items_GiveNamedItem(client, hRocketJumper);
	
	// Force the weapon as active (though there should be a better way to determine if primary is equipped)
	if (IsValidEntity(jumper)) {
		EquipPlayerWeapon(client, jumper);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", jumper);
	}
	
	CloseHandle(hRocketJumper);
}