/*  [Store] Pets
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>
#include <store>
#include <smjansson>
#include <sdkhooks>
#include <smartdm>

new g_offsCollisionGroup;
new g_LeaderOffset;

enum Numeros
{
	String:Name[STORE_MAX_NAME_LENGTH],
	String:model[PLATFORM_MAX_PATH]
}

new g_list[1024][Numeros];
new g_listCount;


new Handle:g_listNameIndex = INVALID_HANDLE;

new pet_owner[2048];

new bool:g_HavePet[MAXPLAYERS+1] = {false, ...};



public Plugin:myinfo =
{
	name        = "[Store] Pets",
	author      = "Franc1sco steam: franug",
	description = "Pets component for [Store]",
	version     = "1.0.0",
	url         = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("store.phrases");
	
	g_offsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
	g_LeaderOffset = FindSendPropOffs("CHostage", "m_leader");
	
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Post);
	
	HookEvent("hostage_follows", Event_Hostage_Follows,EventHookMode_Pre);
	HookEvent("hostage_stops_following", Event_Hostage_Follows,EventHookMode_Pre);
	HookEvent("round_start", OnRoundStart);
	
	HookEvent("player_death", PlayerDeath);

	Store_RegisterItemType("pets", OnEquip, LoadItem);

}

public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!g_HavePet[client])
		return;
		
	for(new i=0;i<2048;++i)
		if(pet_owner[i] == client)
			if(IsValidEdict(i))
				AcceptEntityInput(i, "Kill");
}

public OnClientDisconnect(client)
{
	if(!g_HavePet[client])
		return;
		
	for(new i=0;i<2048;++i)
		if(pet_owner[i] == client)
			if(IsValidEdict(i))
				AcceptEntityInput(i, "Kill");
}

public OnMapStart()
{
	for (new skin = 0; skin < g_listCount; skin++)
	{
		if (strcmp(g_list[skin][model], "") != 0 && (FileExists(g_list[skin][model]) || FileExists(g_list[skin][model], true)))
		{
			PrecacheModel(g_list[skin][model]);
			Downloader_AddFileToDownloadsTable(g_list[skin][model]);
		}
	}
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	for(new i=0;i<2048;++i)
		pet_owner[i] = -1; // clean cache

}

public Action:Event_Hostage_Follows(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetEventInt(event, "hostage");
	
	if(pet_owner[entity] <= 0 || !IsClientInGame(pet_owner[entity]) || !IsPlayerAlive(pet_owner[entity]))
		return Plugin_Continue;
	
	SetEntDataEnt2(entity, g_LeaderOffset, pet_owner[entity]);
	return Plugin_Changed;

}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(g_HavePet[client])
	{
		for(new i=0;i<2048;++i)
			if(pet_owner[i] == client)
				if(IsValidEdict(i))
					AcceptEntityInput(i, "Kill");
	}
	g_HavePet[client] = false;
	
	if(!client || !IsClientInGame(client) || GetClientTeam(client) <= 1 || IsFakeClient(client))
		return Plugin_Continue;
	

	CreateTimer(1.0, GiveItem, GetClientSerial(client));

	return Plugin_Continue;
}

public Action:GiveItem(Handle:timer, any:serial)
{
	new client = GetClientFromSerial(serial);
	if (client == 0)
		return Plugin_Handled;

	if (!IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Handled;

	Store_GetEquippedItemsByType(Store_GetClientAccountID(client), "pets", Store_GetClientLoadout(client), OnGetPlayerItem, GetClientSerial(client));
	return Plugin_Handled;
}


public OnGetPlayerItem(ids[], count, any:serial) 
{
	new client = GetClientFromSerial(serial);
	if (client == 0)
		return;
		

	
	for (new index = 0; index < count; index++)
	{
		decl String:name[STORE_MAX_NAME_LENGTH];
		Store_GetItemName(ids[index], name, sizeof(name));
		
		new obtenido = -1;
		if (!GetTrieValue(g_listNameIndex, name, obtenido))
		{
			continue;
		}
		
		new Float:origin[3];
		GetClientEyePosition(client, origin);
		new entity = CreateEntityByName("hostage_entity");

		DispatchKeyValueVector(entity, "Origin", origin);
		DispatchSpawn(entity);
		SetEntityModel(entity, g_list[obtenido][model]);
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);
		SetEntData(entity, g_offsCollisionGroup, 2, 4, true);
		SetEntDataEnt2(entity, g_LeaderOffset, client);
		SetEntProp(entity, Prop_Send, "m_isRescued", 0);
		pet_owner[entity] = client;
		
		g_HavePet[client] = true;
		
		break;
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("pets", OnEquip, LoadItem);
	}	
}

public Store_OnReloadItems() 
{
	if (g_listNameIndex != INVALID_HANDLE)
		CloseHandle(g_listNameIndex);
		
	g_listNameIndex = CreateTrie();
	g_listCount = 0;
}

public LoadItem(const String:itemName[], const String:attrs[])
{
	strcopy(g_list[g_listCount][Name], STORE_MAX_NAME_LENGTH, itemName);
		
	SetTrieValue(g_listNameIndex, g_list[g_listCount][Name], g_listCount);
	
	new Handle:json = json_load(attrs);



	json_object_get_string(json, "model", g_list[g_listCount][model], PLATFORM_MAX_PATH);

	CloseHandle(json);
	
	if (strcmp(g_list[g_listCount][model], "") != 0 && (FileExists(g_list[g_listCount][model]) || FileExists(g_list[g_listCount][model], true)))
	{
		PrecacheModel(g_list[g_listCount][model]);
		Downloader_AddFileToDownloadsTable(g_list[g_listCount][model]);
	}

	
	g_listCount++;
}

public Store_ItemUseAction:OnEquip(client, itemId, bool:equipped)
{
	if (!IsClientInGame(client))
	{
		return Store_DoNothing;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "%s%t", STORE_PREFIX, "Must be alive to use");
		return Store_DoNothing;
	}
	
	decl String:name[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(itemId, name, sizeof(name));
	
	decl String:loadoutSlot[STORE_MAX_LOADOUTSLOT_LENGTH];
	Store_GetItemLoadoutSlot(itemId, loadoutSlot, sizeof(loadoutSlot));
	
	if (equipped)
	{

		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Unequipped item", displayName);
		
		if(g_HavePet[client])
		{
			for(new i=0;i<2048;++i)
				if(pet_owner[i] == client)
					if(IsValidEdict(i))
						AcceptEntityInput(i, "Kill");
		}
		g_HavePet[client] = false;

		return Store_UnequipItem;
	}
	else
	{		
		new obtenido = -1;
		if (!GetTrieValue(g_listNameIndex, name, obtenido))
		{
			PrintToChat(client, "%s%t", STORE_PREFIX, "No item attributes");
			return Store_DoNothing;
		}
		
		if(g_HavePet[client])
		{
			for(new i=0;i<2048;++i)
				if(pet_owner[i] == client)
					if(IsValidEdict(i))
						AcceptEntityInput(i, "Kill");
		}
		g_HavePet[client] = false;
		
		new Float:origin[3];
		GetClientEyePosition(client, origin);
		new entity = CreateEntityByName("hostage_entity");

		DispatchKeyValueVector(entity, "Origin", origin);
		DispatchSpawn(entity);
		SetEntityModel(entity, g_list[obtenido][model]);
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);
		SetEntData(entity, g_offsCollisionGroup, 2, 4, true);
		SetEntDataEnt2(entity, g_LeaderOffset, client);
		SetEntProp(entity, Prop_Send, "m_isRescued", 0);
		pet_owner[entity] = client;
		
		g_HavePet[client] = true;

		decl String:displayName[STORE_MAX_DISPLAY_NAME_LENGTH];
		Store_GetItemDisplayName(itemId, displayName, sizeof(displayName));
		
		PrintToChat(client, "%s%t", STORE_PREFIX, "Equipped item", displayName);

		return Store_EquipItem;
	}
}