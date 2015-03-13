#pragma semicolon 1 
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <warden>
#include <morecolors>
#include <foxserito_jail_warden>
#include <sdkhooks>

// --------------------
//thanks for the basis code https://github.com/ecca
// --------------------

#define TEAM_CTS 3
#define CS_TEAM_T 2
#define PLUGIN_VERSION   "3.0.1"

new Warden = -1;
new Handle:g_cVar_mnotes = INVALID_HANDLE;
new Handle:g_fward_onBecome = INVALID_HANDLE;
new Handle:g_fward_onRemove = INVALID_HANDLE;


new String:Title_Menu[] = "[Меню командира] [By FoxSerito] v2.0 beta:\n \n";

new String:Sound_of_fight[] = "foxworldportal/jail/ob.mp3";
new floodcontrol = 0;
new FriendlyfireCvar;
new GhostGameCvar;
new FreeDayTrigger = 0;
new FreeDayPlayer = -1;

new Handle:h_Menu, Handle:h_Timer; 
new kick_vots[MAXPLAYERS + 1], timer_sec, all_votes; 

public Plugin:myinfo = {
	name = "Jailbreak Warden",
	author = "ecca",
	description = "Jailbreak Warden script",
	version = PLUGIN_VERSION,
	url = "ffac.eu"
};

public OnPluginStart() 
{
	// Initialize our phrases
	LoadTranslations("warden.phrases");
	
	// Register our public commands
	RegConsoleCmd("sm_uw", ExitWarden);
	RegConsoleCmd("sm_unwarden", ExitWarden);
	RegConsoleCmd("sm_uc", ExitWarden);
	RegConsoleCmd("sm_uncommander", ExitWarden);
	RegConsoleCmd("sm_w", openmenu);
	RegConsoleCmd("sm_c", openmenu);
	// Register our admin commands
	RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_rc", RemoveWarden, ADMFLAG_GENERIC);
	
	// Hooking the events
	//HookEvent("round_start", roundStart); // For the round start
	HookEvent("round_start", round_start, EventHookMode_PostNoCopy); 
	HookEvent("player_death", playerDeath); // To check when our warden dies :)
	
	// For our warden to look some extra cool
	AddCommandListener(HookPlayerChat, "say");
	
	// May not touch this line
	CreateConVar("sm_warden_version", PLUGIN_VERSION,  "The version of the SourceMod plugin JailBreak Warden, by ecca", FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cVar_mnotes = CreateConVar("sm_warden_better_notifications", "0", "0 - disabled, 1 - Will use hint and center text", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	g_fward_onBecome = CreateGlobalForward("warden_OnWardenCreated", ET_Ignore, Param_Cell);
	g_fward_onRemove = CreateGlobalForward("warden_OnWardenRemoved", ET_Ignore, Param_Cell);
}

public OnMapStart() 
{
	PrecacheSound("items/nvg_off.wav", true);
	PrecacheSound("items/gift_drop.wav", true);
	PrecacheSound("foxworldportal/jail/ob.mp3", true);
	PrecacheModel("models/player/vad36mk9/stryker.mdl");
	PrecacheModel("models/player/vad36pvk/cop.mdl");
}


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("warden_exist", Native_ExistWarden);
	CreateNative("warden_iswarden", Native_IsWarden);
	CreateNative("warden_set", Native_SetWarden);
	CreateNative("warden_remove", Native_RemoveWarden);

	RegPluginLibrary("warden");
	
	return APLRes_Success;
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
}

public Action:GhostGameStartCommand(client, args) 
{ 
	ShowGhostGameMenu(client);
	return Plugin_Handled; 
} 

public Action:openmenu(client, args) 
{
	if(IsPlayerAlive(client) && warden_iswarden(client))
	{
		ShowMyPanel(client);
	}
	else // The warden already exist so there is no point setting a new one
	{
		PrintToChat(client, "Вы не КМД");
	}
}


public Action:BecomeWarden(client, args) 
{
	if (Warden == -1) // There is no warden , so lets proceed
	{
		if (GetClientTeam(client) == 3) // The requested player is on the Counter-Terrorist side
		{
			if (IsPlayerAlive(client)) // A dead warden would be worthless >_<
			{
				SetTheWarden(client);
			}
			else // Grr he is not alive -.-
			{
				PrintToChat(client, "Warden ~ %t", "warden_playerdead");
			}
		}
		else // Would be wierd if an terrorist would run the prison wouldn't it :p
		{
			PrintToChat(client, "Warden ~ %t", "warden_ctsonly");
		}
	}
	else // The warden already exist so there is no point setting a new one
	{
		PrintToChat(client, "Warden ~ %t", "warden_exist", Warden);
	}
}

public Action:ExitWarden(client, args) 
{
	if(client == Warden) // The client is actually the current warden so lets proceed
	{
		PrintToChatAll("Warden ~ %t", "warden_retire", client);
		if(GetConVarBool(g_cVar_mnotes))
		{
			PrintCenterTextAll("Warden ~ %t", "warden_retire", client);
			PrintHintTextToAll("Warden ~ %t", "warden_retire", client);
		}
		Warden = -1; // Open for a new warden
		SetEntityRenderColor(client, 255, 255, 255, 255); // Lets remove the awesome color
	}
	else // Fake dude!
	{
		PrintToChat(client, "Warden ~ %t", "warden_notwarden");
	}
}

public round_start(Handle:event, const String:name[], bool:silent) 
{ 
	Warden = -1; // Lets remove the current warden if he exist
	// Если вдруг начался новый раунд, но наш таймер + меню активны, останавливаем их. 
	// Например, раунд быстро закончился, или был рестарт. 
	FreeDayTrigger = 0;
	FreeDayPlayer = -1;
	FriendlyfireCvar = 0;
	GhostGameCvar = 0;
	
	ServerCommand("mp_friendlyfire 0");
	ServerCommand("vip_friendlyfire 0");
	ServerCommand("sm plugins load shop_trails");
	ServerCommand("mp_flashlight 1");
	ServerCommand("sm_hosties_lr 1"); //разрешить писать LR
	ServerCommand("sm_hosties_rebel_color 1"); //// Включить окраску бунтующих Т
	ServerCommand("sm_hosties_announce_rebel 1"); // Включить оповещение в чате когда Т считаются сбежавшами.
	ServerCommand("mp_playerid 0"); //видны ники	
	ServerCommand("sm_hosties_freekill_sound_mode 1"); //звук фрикила
	ServerCommand("hgrsource_hook_enable 1"); //врубаем паутинку админам
	ServerCommand("mp_forcecamera 0"); //наблюдать за другой командой

	if (h_Timer != INVALID_HANDLE) 
	{ 
		KillTimer(h_Timer); 
		h_Timer = INVALID_HANDLE; 
	}

	if (h_Menu != INVALID_HANDLE) CloseHandle(h_Menu); 
	h_Menu = CreateMenu(Select_Func); 
	SetMenuTitle(h_Menu, "Кто будет командовать?\n \n"); 
	SetMenuExitButton(h_Menu, false); 
	decl String:StR_Id[15], String:StR_Name[MAX_NAME_LENGTH]; 
	new players = 0; 
	for (new i = 1; i <= MaxClients; i++) 
	{ 
		// очищаем кол-во голосов за кик игрока (i = его индекс) 
		kick_vots[i] = 0; 

		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_CTS && GetClientName(i, StR_Name, MAX_NAME_LENGTH)) 
		{ 
			// получаем userid игрока и делаем его строкой, чтобы добавить в меню 
			IntToString(GetClientUserId(i), StR_Id, sizeof(StR_Id)); 
			AddMenuItem(h_Menu, StR_Id, StR_Name); 
			players++; 
		} 
	} 

	// если игроков на сервере > 0 
	if (players > 0) 
	{ 
		// показываем игрокам созданное меню и запускаем таймер 
		for (new i = 1; i <= MaxClients; i++) 
		{ 
			if (IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && !IsFakeClient(i)) DisplayMenu(h_Menu, i, 10); 
		} 
		all_votes = 0;  // сколько всего было голосов 
		timer_sec = 15; // время голосования в сек. 
		h_Timer = CreateTimer(1.0, Timer_Func, _, TIMER_REPEAT); 
	} 
	else 
	{ 
		// если нет игроков, удаляем созданное меню 
		CloseHandle(h_Menu); 
		h_Menu = INVALID_HANDLE; 
	} 
} 

public Select_Func(Handle:menu, MenuAction:action, client, item) 
{ 
	if (action != MenuAction_Select) 
		return; 

	decl String:StR_Id[15]; 
	if (!GetMenuItem(menu, item, StR_Id, sizeof(StR_Id))) 
		return; 

	new target = GetClientOfUserId(StringToInt(StR_Id)); 
	if (target > 0) 
	{ 
		all_votes++; 
		kick_vots[target]++; 
		CPrintToChatAll("{greenyellow}| {lime}%N {greenyellow}выбрал игрока {lime}%N {greenyellow}|", client, target); 
	} 
	else 
		PrintToChat(client, "Игрок не найден"); 
} 

public Action:Timer_Func(Handle:timer_f) 
{ 
	if (--timer_sec > 0) 
	{ 
		PrintHintTextToAll("До завершения голосования:\n< %d сек >", timer_sec); 
		return Plugin_Continue; 
	} 

	// Время истекло, голосование окончено 
	h_Timer = INVALID_HANDLE; 
	if (h_Menu != INVALID_HANDLE) 
	{ 
		CloseHandle(h_Menu); 
		h_Menu = INVALID_HANDLE; 
	} 

	PrintHintTextToAll("Голосование завершено (%d голосов)", all_votes); 
	if (all_votes < 1)
	{
		return Plugin_Stop; 
	}

	// Находим игрока, за которого больше всего проголосовали 
	new vots = 0, target = 0; 
	for (new i = 1; i <= MaxClients; i++) 
	{ 
		if (kick_vots[i] > vots) 
		{ 
			vots = kick_vots[i]; 
			target = i; 
		} 
	} 
	if (target > 0 && IsClientInGame(target)) 
	{ 
		CPrintToChatAll("<<<< {unique}Игрок {haunted}%N {unique}выбран командиром >>>>", target);
		SetTheWarden(target);
		ShowMyPanel(target);
	} 
	else 
		PrintToChatAll("Игрок не найден"); 

	return Plugin_Stop; 
}

public Action:playerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid")); // Get the dead clients id
	
	if(client == Warden) // Aww damn , he is the warden
	{
		PrintToChatAll("Warden ~ %t", "warden_dead", client);
		if(GetConVarBool(g_cVar_mnotes))
		{
			PrintCenterTextAll("Warden ~ %t", "warden_dead", client);
			PrintHintTextToAll("Warden ~ %t", "warden_dead", client);
		}
		SetEntityRenderColor(client, 255, 255, 255, 255); // Lets give him the standard color back
		Warden = -1; // Lets open for a new warden
	}
}

public OnClientDisconnect(client)
{
	if(client == Warden) // The warden disconnected, action!
	{
		PrintToChatAll("Warden ~ %t", "warden_disconnected");
		if(GetConVarBool(g_cVar_mnotes))
		{
			PrintCenterTextAll("Warden ~ %t", "warden_disconnected", client);
			PrintHintTextToAll("Warden ~ %t", "warden_disconnected", client);
		}
		Warden = -1; // Lets open for a new warden
	}
}

public Action:RemoveWarden(client, args)
{
	if(Warden != -1) // Is there an warden at the moment ?
	{
		RemoveTheWarden(client);
	}
	else
	{
		PrintToChatAll("Warden ~ %t", "warden_noexist");
	}

	return Plugin_Handled; // Prevent sourcemod from typing "unknown command" in console
}

public Action:HookPlayerChat(client, const String:command[], args)
{
	if(Warden == client && client != 0) // Check so the player typing is warden and also checking so the client isn't console!
	{
		new String:szText[256];
		GetCmdArg(1, szText, sizeof(szText));
		
		if(szText[0] == '/' || szText[0] == '@' || IsChatTrigger()) // Prevent unwanted text to be displayed.
		{
			return Plugin_Handled;
		}
		
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3) // Typing warden is alive and his team is Counter-Terrorist
		{
			CPrintToChatAll("{springgreen}[Командир] {blue}%N: {white}%s", client, szText);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public SetTheWarden(client)
{
	PrintToChatAll("Warden ~ %t", "warden_new", client);
	
	if(GetConVarBool(g_cVar_mnotes))
	{
		PrintCenterTextAll("Warden ~ %t", "warden_new", client);
		PrintHintTextToAll("Warden ~ %t", "warden_new", client);
	}
	Warden = client;
	SetEntityModel(client, "models/player/vad36mk9/stryker.mdl");
	SetEntityHealth(client, 130);
	SetClientListeningFlags(client, VOICE_NORMAL);
	
	Forward_OnWardenCreation(client);
}

public RemoveTheWarden(client)
{
	PrintToChatAll("Warden ~ %t", "warden_removed", client, Warden);
	if(GetConVarBool(g_cVar_mnotes))
	{
		PrintCenterTextAll("Warden ~ %t", "warden_removed", client);
		PrintHintTextToAll("Warden ~ %t", "warden_removed", client);
	}
	SetEntityRenderColor(Warden, 255, 255, 255, 255);
	Warden = -1;
	
	Forward_OnWardenRemoved(client);
}

public Native_ExistWarden(Handle:plugin, numParams)
{
	if(Warden != -1)
		return true;
	
	return false;
}

public Native_IsWarden(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if(!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if(client == Warden)
		return true;
	
	return false;
}

public Native_SetWarden(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if(Warden == -1)
	{
		SetTheWarden(client);
	}
}

public Native_RemoveWarden(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if(client == Warden)
	{
		RemoveTheWarden(client);
	}
}

public Forward_OnWardenCreation(client)
{
	Call_StartForward(g_fward_onBecome);
	Call_PushCell(client);
	Call_Finish();
}

public Forward_OnWardenRemoved(client)
{
	Call_StartForward(g_fward_onRemove);
	Call_PushCell(client);
	Call_Finish();
}

ShowMyPanel(client) 
{ 
	new Handle:maincmd = CreatePanel(); 
	SetPanelTitle(maincmd, Title_Menu); 
	DrawPanelItem(maincmd, "[◄|►] Открыть все двери");		//1
	DrawPanelItem(maincmd, "Дополнительно"); 					//2
	DrawPanelItem(maincmd, "Снять ФД/станд. цвет");			//3	
	DrawPanelItem(maincmd, "Дать мирный фридей (1чел)");		//4
	DrawPanelItem(maincmd, "Драка заключенных Вкл./Выкл.");	//5
	DrawPanelItem(maincmd, "Режим пряток (beta)");			//7
	DrawPanelText(maincmd, "130hp+Скин(пасив)");				//--
	DrawPanelText(maincmd, "\n \n");							//--
	DrawPanelItem(maincmd, "[-] Покинуть пост");				//8
	DrawPanelItem(maincmd, "[X] Выйти из меню");				//9
	SendPanelToClient(maincmd, client, Select_Panel, 0);
	CloseHandle(maincmd);
	ClientCommand(client, "playgamesound items/nvg_off.wav");
}


public Select_Panel(Handle:maincmd, MenuAction:action, client, option)  
{ 
	if (action == MenuAction_Select) 
	{ 
		if(IsPlayerAlive(client) && warden_iswarden(client))
		{
			if(option == 1)
			{
				if (floodcontrol == 1)
				{
					PrintToChat(client,"Не используйте меню так часто!");
					ShowMyPanel(client);
				}
				else
				{
					floodcontrol = 1;
					CPrintToChatAll("{springgreen}[КМД] ~ {white}Командир Открыл Джайлы и другие обьекты");
					PrintToServer("Коммандирка ~ Открыты все двери");
					OpenAllDoors();
					ShowMyPanel(client);
					CreateTimer(5.0, FLOOD_D_timer);
				}
			}
			else if(option == 2)
			{
				MenuPlus(client);
			}
			else if(option == 3)
			{
				ColorChangeDef(client);
				ShowMyPanel(client);
			}
			
			else if(option == 4)
			{
				// фридей
				FreeDay(client);
				ShowMyPanel(client);
			}
			
			else if(option == 5)
			{
				if (floodcontrol == 1)
				{
					PrintToChat(client,"Не используйте меню так часто!");
					ShowMyPanel(client);
				}
				else
				{
					floodcontrol = 1;
					CreateTimer(5.0, FLOOD_D_timer);
					friendlyfire();							// friendlyfire
					ShowMyPanel(client);
				}
			}
			else if(option == 6)
			{
				ShowGhostGameMenu(client);
			}
			else if(option == 7)
			{
				CPrintToChatAll("{springgreen}[КМД] ~ {white}Командир покинул пост, возьмите командование!");
				warden_remove(client);
			}
			else if (action == MenuAction_End)
			{
				CloseHandle(maincmd);
			}
		}
		else // The warden already exist so there is no point setting a new one
		{
			PrintToChat(client, "Вы не КМД");
		}
	} 
}

MenuPlus(client) 
{ 
	new Handle:MenuPlus_handle = CreatePanel(); 
	SetPanelTitle(MenuPlus_handle, "Дополнительное меню");	// заголовок
	DrawPanelItem(MenuPlus_handle, "Покрасить в синий");					// 1 пункт
	DrawPanelItem(MenuPlus_handle, "Покрасить в зеленый");				// 2 пункт
	DrawPanelItem(MenuPlus_handle, "Отменить все ЛР");					// 3 пункт
	DrawPanelText(MenuPlus_handle, "\n \n");								// пропуск строки
	DrawPanelItem(MenuPlus_handle, "<- Назад");							// пункт назад
	SendPanelToClient(MenuPlus_handle, client, Select_Panel_plus, 0);
	CloseHandle(MenuPlus_handle);
	ClientCommand(client, "playgamesound items/nvg_off.wav");
}

public Select_Panel_plus(Handle:MenuPlus_handle, MenuAction:action, client, option) 
{ 
	if(IsPlayerAlive(client) && warden_iswarden(client))
	{
		if(option == 1)
		{
			ColorChangeBlue(client);
			MenuPlus(client);
		}
		else if(option == 2)
		{
			ColorChangeGreen(client);
			MenuPlus(client);
		}
		else if(option == 3)
		{
			if (floodcontrol == 1)
			{
				PrintToChat(client,"Не используйте меню так часто!");
				MenuPlus(client);
			}
			else
			{
				floodcontrol = 1;
				CreateTimer(5.0, FLOOD_D_timer);
				ServerCommand("sm_stoplr"); //остановить лр
				MenuPlus(client);
			}
		}
		else if(option == 4) // пункт назад
		{
			ShowMyPanel(client);
		}
	}
	else // The warden already exist so there is no point setting a new one
	{
		PrintToChat(client, "Вы не КМД");
	}

}

public Action:FLOOD_D_timer(Handle:timer)
{
	floodcontrol = 0;
}

//-------------------------------------------------
// Перекрас
//-------------------------------------------------

ColorChangeBlue(client)
{
	new targetaim = GetClientAimTarget(client, true);

	if( targetaim == -1)
	{
		PrintToChat(client,"Наведите прицел на живого игрока!");
	}
	else
	{
		SetEntityRenderColor(targetaim, 0, 0, 255, 255);
		PrintToChat(client,"Вы перекрасили игрока в синий");
	}	
}

ColorChangeGreen(client)
{
	new targetaim = GetClientAimTarget(client, true);
	
	if( targetaim == -1)
	{
		PrintToChat(client,"Наведите прицел на живого игрока!");
	}
	else
	{
		SetEntityRenderColor(targetaim, 0, 255, 0, 255);
		PrintToChat(client,"Вы перекрасили игрока в зеленый");	
	}
}

ColorChangeDef(client)
{
	new targetaim = GetClientAimTarget(client, true);
	
	if( targetaim == -1)
	{
		PrintToChat(client,"Наведите прицел на живого игрока!");
	}
	else
	{
		SetEntityRenderColor(targetaim, 255, 255, 255, 255);
		if(targetaim == FreeDayPlayer) // снимем фридей
		{
			new String:freeday_restr[32];
			GetClientName(targetaim, freeday_restr, sizeof(freeday_restr));
			FreeDayTrigger = 0;
			FreeDayPlayer = -1;
			CPrintToChatAll("{springgreen}[КМД] ~ {white} Командир снял мирный фридей с %s", freeday_restr);
			PrintToServer("Коммандирка ~ снял мирный фридей");
		}
	}
}

friendlyfire()
{
	if(FriendlyfireCvar == 1)
	{
		PrintHintTextToAll("Командир запретил заключенным драться!");
		//SetConVarInt(FindConVar("mp_friendlyfire"), 0);
		ServerCommand("mp_friendlyfire 0");
		PrintToServer("Коммандирка ~   mp_friendlyfire 0");
		FriendlyfireCvar = 0;
		//
		decl String:buffer[150];
		for(new i = 1; i <= GetMaxClients(); i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				Format(buffer, sizeof(buffer), "play %s", "common/null");
				ClientCommand(i, buffer);
			}
		}
		//
	}
	else
	{
		PrintHintTextToAll("Командир разрешил заключенным драться!");
		ServerCommand("mp_friendlyfire 1");
		PrintToServer("Коммандирка ~   mp_friendlyfire 1");
		
		FriendlyfireCvar = 1;
		//
		decl String:buffer[150];
		for(new i = 1; i <= GetMaxClients(); i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				Format(buffer, sizeof(buffer), "play %s", Sound_of_fight);
				ClientCommand(i, buffer);
			}
		}
		//
	}
}

//---------------------------Ghost Game----------------------

ShowGhostGameMenu(client) 
{ 
	new Handle:GameMenu_GH = CreatePanel(); 
	SetPanelTitle(GameMenu_GH, "Игра Призрак [beta]:\n \n");
	DrawPanelItem(GameMenu_GH, "Старт/Стоп");
	DrawPanelItem(GameMenu_GH, "Выход\n \n");
	DrawPanelText(GameMenu_GH, "Игра Призрак ");	
	DrawPanelText(GameMenu_GH, "[By FoxSerito]");
	DrawPanelText(GameMenu_GH, "\n \n");
	DrawPanelItem(GameMenu_GH, "Известные ошибки (баги)");	
	SendPanelToClient(GameMenu_GH, client, Select_Panel_PM, 0); 
	CloseHandle(GameMenu_GH);
} 

public Select_Panel_PM(Handle:GameMenu_GH, MenuAction:action, client, option) 
{ 
	if(IsPlayerAlive(client) && warden_iswarden(client))
	{
		if(option == 1)
		{
			if (floodcontrol == 1)
			{
				PrintToChat(client,"Не используйте меню так часто!");
				ShowGhostGameMenu(client);
			}
			else
			{
				if (floodcontrol == 9999)
				{
					floodcontrol = 1;
					if (GhostGameCvar == 0)
					{
						GhostGameStart(); //запускаем
						
						PrintToChat(client,"[КМД] ~ Запущена игра Призрак!");
						PrintHintTextToAll("[КМД] ~ Запущена игра Призрак!");
						ShowGhostGameMenu(client);
						GhostGameCvar = 1;
					}
					else
					{
						GhostGameStop(); //останавливаем
						
						PrintToChat(client,"[КМД] ~ Игра Призрак остановлена!");
						PrintHintTextToAll("[КМД] ~ Игра Призрак остановлена!");
						ShowGhostGameMenu(client);
						GhostGameCvar = 0;
					}
					CreateTimer(5.0, FLOOD_D_timer);
				}
				else
				{
					PrintToChat(client, "Игра в разработке...");
				}
			}
		}
		if(option == 3)
		{
			PrintToChat(client," ");
			CPrintToChat(client,"{white}[КМД] ~ {greenyellow}Баги: перед началом игры КТ должен выбросить гранату, иначе будет видно");
			PrintToChat(client," ");
			ShowGhostGameMenu(client);
		}
		else if (action == MenuAction_End)
		{
			CloseHandle(GameMenu_GH);
		}
	}
	else // The warden already exist so there is no point setting a new one
	{
		PrintToChat(client, "Вы не КМД");
	}
}

// ---------------------------GAME START --------------------------------

GhostGameStart()
{
	ServerCommand("sm plugins unload shop_trails");
	ServerCommand("mp_flashlight 0"); //неробит
	ServerCommand("sm_hosties_lr 0"); //зпретить писать LR
	ServerCommand("sm_hosties_rebel_color 0"); // Выключить окраску бунтующих Т
	ServerCommand("sm_hosties_announce_rebel 0"); // Выключить оповещение в чате когда Т считаются сбежавшами.
	ServerCommand("mp_playerid 2"); //невидны ники в центре
	ServerCommand("sm_hosties_freekill_sound_mode -1"); //звук фрикила
	ServerCommand("hgrsource_hook_enable 0"); //вырубаем паутинку админам
	ServerCommand("sm_stoplr"); //остановить лр
	ServerCommand("mp_forcecamera 1"); //наблюдать за другой командой
	
	CPrintToChatAll("{springgreen}[КМД] ~ {white}Запущена игра Призрак[beta]!");
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (!IsFakeClient(i)) && IsPlayerAlive(i))
		{
			if(GetClientTeam(i) == TEAM_CTS)
			{
				StripAllWeapons(i);
				GivePlayerItem(i, "weapon_knife");
				//SetThirdPerson(i);
				SetEntityRenderMode(i, RENDER_TRANSCOLOR);
				SetEntityRenderColor(i, 255, 255, 255, 0);
				InvisWeapons(i);
				CreateTimer(1.0, Timer_FixGravity, _, TIMER_REPEAT);
				SetEntityGravity(i, 0.2);
			}
			else if(GetClientTeam(i) == CS_TEAM_T)
			{
				StripAllWeapons(i);
				GivePlayerItem(i, "weapon_ak47");
				GivePlayerItem(i, "weapon_knife");
			}
		}
	} 	
}


// new pistolet = GetPlayerWeaponSlot(client, 1); 
// RemovePlayerItem(client, pistolet);  

// 0 - автомат 
// 1 - пистолет 
// 2 - нож 
// 3 - граната 
// 4 - бомба c4 

public Action:Timer_FixGravity(Handle:timer)
{
	if (GhostGameCvar == 0) {
		return Plugin_Stop;
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (!IsFakeClient(i)) && IsPlayerAlive(i))
		{
			if(GetClientTeam(i) == TEAM_CTS)
			{
				SetEntityGravity(i, 0.2);
			}
		}
	}
 	return Plugin_Continue;
}

public Action:OnWeaponCanUse(client, weapon)
{
    if( GetClientTeam(client) == TEAM_CTS && GhostGameCvar == 1)
	{
		decl String:wepClassname[32];
		GetEntityClassname(weapon, wepClassname, sizeof(wepClassname));
		if(StrContains(wepClassname, "knife")>=0)
		{
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", 99999.0);
		}

		//return Plugin_Handled;
	}
    return Plugin_Continue;
}

public Action:OnWeaponEquip(client, weapon)
{
    if( GetClientTeam(client) == TEAM_CTS && GhostGameCvar == 1)
	{
		return Plugin_Handled;
	}
    return Plugin_Continue;
}  


// ---------------------------GAME STOP --------------------------------


GhostGameStop()
{
	ServerCommand("sm plugins load shop_trails");
	ServerCommand("mp_flashlight 1");
	ServerCommand("sm_hosties_lr 1");  //разрешить писать LR
	ServerCommand("sm_hosties_rebel_color 1"); //// Включить окраску бунтующих Т
	ServerCommand("sm_hosties_announce_rebel 1"); // Включить оповещение в чате когда Т считаются сбежавшами.
	ServerCommand("mp_playerid 0"); //ники видны в центре
	ServerCommand("sm_hosties_freekill_sound_mode 1"); //звук фрикила
	ServerCommand("hgrsource_hook_enable 1"); //врубаем паутинку админам
	ServerCommand("mp_forcecamera 0"); //наблюдать за другой командой
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (!IsFakeClient(i)) && IsPlayerAlive(i))
		{
			if(GetClientTeam(i) == TEAM_CTS)
			{
				StripAllWeapons(i);
				GivePlayerItem(i, "weapon_knife");	
			}
			else if(GetClientTeam(i) == CS_TEAM_T)
			{
				StripAllWeapons(i);
				GivePlayerItem(i, "weapon_knife");
			}
			SetEntityRenderMode(i, RENDER_TRANSCOLOR);
			SetEntityRenderColor(i, 255, 255, 255, 255);
			SetEntityGravity(i, 1.0);
		}
	}
}


//-------------------------------------------------
//  Фридей
//-------------------------------------------------

FreeDay(client)
{
	new targetaim = GetClientAimTarget(client, true);
	if( targetaim == -1)
	{ 
		PrintToChat(client,"Наведите прицел на живого игрока!");
	}
	else
	{
		if (client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			new String:name_t_freeday[32];
			GetClientName(targetaim, name_t_freeday, sizeof(name_t_freeday));
			if(targetaim == FreeDayPlayer) //если цель уже с фридеем
			{
				PrintToChat(client,"[КМД] ~ У заключенного %s уже есть мирный фридей!", FreeDayPlayer);
				PrintToServer("[КМД] ~ У заключенного %s уже есть мирный фридей!", FreeDayPlayer);
			}
			else //если же нет
			{
				if(FreeDayTrigger < 1) //проверяем есть ли место под фридей
				{
					FreeDayPlayer = targetaim; //даем фридей
					FreeDayTrigger = 1; 
					SetEntityRenderColor(targetaim, 255, 255, 0, 200);
					CPrintToChatAll("{springgreen}[КМД] ~ {white}Командир выдал  мирный фридей игроку %s", name_t_freeday);
					PrintToServer("Командир выдал мирный фридей игроку %s", name_t_freeday);
					decl String:buffer[150];
					for(new i = 1; i <= GetMaxClients(); i++)
					{
						if(IsClientInGame(i) && !IsFakeClient(i))
						{
							Format(buffer, sizeof(buffer), "play %s", "items/gift_drop.wav");
							ClientCommand(i, buffer);
						}
					}
				}
				else
				{
					PrintToChat(client,"[КМД] ~ Уже есть заключенный которому дан мирный фридей!");
				}
			}
		}
	}
}
//-------------------------------------------------
//    Code from Open All Doors plugin by SemJef
//-------------------------------------------------

OpenAllDoors()
{
	decl String:class[32]; new ent = GetMaxEntities();
	while (ent > MaxClients)
	{
		if (IsValidEntity(ent) 
			&& GetEntityClassname(ent, class, 32) 
			&& (StrContains(class, "_door") > 0 || strcmp(class, "func_movelinear") == 0))
		{
			AcceptEntityInput(ent, "Unlock");
			AcceptEntityInput(ent, "Open");
		}
		ent--;
	}
}


//-------------------------------------------------
//  End Code from Jail OpenAllDoors plugin by SemJef
//-------------------------------------------------