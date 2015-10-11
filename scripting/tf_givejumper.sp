#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_VERSION          "0.0.1"
public Plugin myinfo = {
    name = "[TF2] Auto-give Rocket Jumper",
    author = "nosoop",
    description = "Rocket Jumpers for everyone!",
    version = PLUGIN_VERSION,
    url = "http://github.com/nosoop"
}

#define ROCKETJUMPER_DEFINDEX	237
#define ROCKETJUMPER_CLASSNAME	"tf_weapon_rocketlauncher"

bool g_ClientUsingJumperOverride[MAXPLAYERS+1];

public void OnPluginStart() {
	HookEvent("post_inventory_application", Event_PlayerInventoryApplication_Post, EventHookMode_Post);
	RegConsoleCmd("sm_togglejumper", AdminCmd_ToggleJumper, "Toggles auto-granting of Rocket Jumpers on a player.");
	
	LoadTranslations("core.phrases");
}

public Action AdminCmd_ToggleJumper(int client, int nArgs) {
	if (!CheckCommandAccess(client, "jumper", ADMFLAG_CHEATS)) {
		ReplyToCommand(client, "[SM] %t.", "No Access");
		return Plugin_Handled;
	}
	
	g_ClientUsingJumperOverride[client] = !g_ClientUsingJumperOverride[client];
	PrintToChat(client, "Jumper mode %s", g_ClientUsingJumperOverride[client] ? "enabled" : "disabled");
	
	return Plugin_Handled;
}

public void OnClientPutInServer(int client) {
	g_ClientUsingJumperOverride[client] = false;
}

public void Event_PlayerInventoryApplication_Post(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_ClientUsingJumperOverride[client]) {
		ReplacePrimaryWithJumper(client);
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