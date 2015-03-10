#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <morecolors>
#include <lastrequest>
#include <foxserito_jail_warden>
#include <sdkhooks>

#define Commander_VERSION   "1.6.0"
#define TEAM_CTS 3
#define CS_TEAM_T 2

new Warden = -1;
new FreeDayTrigger = 0;
new FreeDayPlayer = -1;
new WardenName;
new floodcontrol = 0;
new String:Sound_of_fight[] = "foxworldportal/jail/ob.mp3";
new String:Title_Menu[] = "[Меню командира] [By FoxSerito] v1.6 :\n \n";
new FriendlyfireCvar;
new GhostGameCvar;

public Plugin:myinfo = 
{
	name = "Jail Warden (by FoxSerito)",
	author = "FoxSerito",
	description = "Jail Warden",
	version = Commander_VERSION,
	url = "vk.com/foxserito"
};

public OnPluginStart() 
{
	LoadTranslations("warden.phrases");
	RegConsoleCmd("sm_w", BecomeWarden);
	RegConsoleCmd("sm_c", BecomeWarden);
	RegConsoleCmd("sm_uw", ExitWarden);
	RegConsoleCmd("sm_unwarden", ExitWarden);
	RegConsoleCmd("sm_ghostgame", GhostGameStartCommand);
	//RegAdminCmd("sm_ghostgame", GhostGameStartCommand, ADMFLAG_GENERIC);
	RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC);
	HookEvent("round_start", roundStart);
	HookEvent("player_death", playerDeath); 
	AddCommandListener(HookPlayerChat, "say");
	CreateConVar("sm_warden_version", Commander_VERSION,  "The version of the SourceMod plugin JailBreak Warden, by ecca", FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_PLUGIN);
}

public OnMapStart() 
{
	PrecacheSound("items/nvg_off.wav", true);
	PrecacheSound("items/gift_drop.wav", true);
	PrecacheSound("foxworldportal/jail/ob.mp3", true);
	PrecacheModel("models/player/vad36mk9/stryker.mdl");
	PrecacheModel("models/player/vad36pvk/cop.mdl");
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

public Action:BecomeWarden(client, args) 
{
	if (Warden == -1)
	{
		if (GetClientTeam(client) == TEAM_CTS)
		{
			if (IsPlayerAlive(client))
			{
				CPrintToChatAll("{springgreen}[КМД] ~ {white}%t", "warden_new", client);
				Warden = client; // становится командиром
				WardenName = client;
				SetEntityModel(client, "models/player/vad36mk9/stryker.mdl");
				SetEntityHealth(client, 130);
				SetClientListeningFlags(client, VOICE_NORMAL);
			}
			else 
			{
				CPrintToChat(client, "{springgreen}[КМД] ~ {white}%t", "warden_playerdead");
			}
		}
		else 
		{
			CPrintToChat(client, "{springgreen}[КМД] ~ {white}%t", "warden_ctsonly");
		}
	}
	else 
	{
		CPrintToChat(client, "{springgreen}[КМД] ~ {white}%t", "warden_exist", Warden);
	}
	
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if(client == Warden) // основная проверка
		{
			if(GetClientTeam(client) == 3 && IsPlayerAlive(client)) //дополнительные проверки, на всякий случай
			{
				ShowMyPanel(client);
			}
		}
	}
	return Plugin_Handled;
}

public Action:ExitWarden(client, args) 
{
	if(client == Warden)
	{
		CPrintToChatAll("{springgreen}[КМД] ~ {white}%t", "warden_retire", client);
		Warden = -1; 
		SetEntityModel(client, "models/player/vad36pvk/cop.mdl");
		SetEntityHealth(client, 100);
	}
	else 
	{
		CPrintToChat(client, "{springgreen}[КМД] ~ {white}%t", "warden_notwarden");
	}
}

//------------------------------------------------
//------------------------------------------------
//--------------------- НАЧАЛО РАУНДА -------------
//------------------------------------------------

public Action:roundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	Warden = -1;
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

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (!IsFakeClient(i)) && IsPlayerAlive(i))
		{
			SetEntityRenderMode(i, RENDER_TRANSCOLOR);
			SetEntityRenderColor(i, 255, 255, 255, 255);
			SetEntityGravity(i, 1.0);
			GivePlayerItem(i, "weapon_knife");
			CancelClientMenu(i, Handle:MenuPlus_handle);
			CancelClientMenu(i, Handle:maincmd);
			CancelClientMenu(i, Handle:GameMenu_GH);
		}
	}
	
}
//------------------------------------------------
//------------------------------------------------
//------------------------------------------------
//------------------------------------------------


public Action:playerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid")); 
	
	if(client == FreeDayTrigger)
	{
		FreeDayTrigger = 0;
		FreeDayPlayer = -1;
	}
	if(client == Warden)
	{
		CPrintToChatAll("{springgreen}[КМД] ~ {white}%t", "warden_dead", client);
		Warden = -1; 
		WardenName = -1;
		//CancelAllMenus();
		CancelClientMenu(client, Handle:MenuPlus_handle);
		CancelClientMenu(client, Handle:maincmd);
		CancelClientMenu(client, Handle:GameMenu_GH);
	}
}

public OnClientDisconnect(client)
{
	if(client == Warden) // The warden disconnected, action!
	{
		CPrintToChatAll("{springgreen}[КМД] ~ {white}%t", "warden_disconnected");
		Warden = -1;
		WardenName = -1;
	}
	
	if ( IsClientInGame(client) ) 
    { 
		SDKUnhook(client, SDKHook_WeaponEquip, OnWeaponEquip);
		SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    } 
}

public Action:RemoveWarden(client, args)
{
	if(Warden != -1)
	{
		CPrintToChatAll("{springgreen}[КМД] ~ {white}%t", "warden_removed", client, Warden);
		SetEntityModel(WardenName, "models/player/vad36pvk/cop.mdl");
		SetEntityHealth(WardenName, 100);
		Warden = -1; 
		WardenName = -1;
		CancelAllMenus();
	}
	else
	{
		CPrintToChat(client,"{springgreen}[КМД] ~ {white}%t", "warden_noexist");
	}

	return Plugin_Handled; 
}

public Action:HookPlayerChat(client, const String:command[], args)
{
	if(Warden == client && client != 0)
	{
		new String:szText[256];
		GetCmdArg(1, szText, sizeof(szText));
		
		if(szText[0] == '/' || szText[0] == '@' || IsChatTrigger()) // Prevent unwanted text to be displayed.
		{
			return Plugin_Handled;
		}
		
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == TEAM_CTS) 
		{
			CPrintToChatAll("{springgreen}[Командир] {blue}%N: {white}%s", client, szText);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
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
		if(IsPlayerAlive(client) && client==Warden)
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
				SetEntityModel(WardenName, "models/player/vad36pvk/cop.mdl");
				SetEntityHealth(WardenName, 100);
				Warden = -1; 
				WardenName = -1;
			}
			else if (action == MenuAction_End)
			{
				CloseHandle(maincmd);
			}
		}
	} 
}

// ----------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------
// дополнительное меню
// ----------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------

MenuPlus(client) 
{ 
	new Handle:MenuPlus_handle = CreatePanel(); 
	SetPanelTitle(MenuPlus_handle, "Дополнительное меню");	// заголовок
	DrawPanelItem(MenuPlus_handle, "Покрасить в синий");					// 1 пункт
	DrawPanelItem(MenuPlus_handle, "Покрасить в зеленый");				// 2 пункт
	DrawPanelItem(MenuPlus_handle, "Отменить все ЛР");					// 3 пункт
	DrawPanelText(MenuPlus_handle, "\n \n");								// пропуск строки
	DrawPanelItem(MenuPlus_handle, "<- Назад");							// пункт назад
	SendPanelToClient(MenuPlus_handle, client, Select_Panel, 0);
	CloseHandle(MenuPlus_handle);
	ClientCommand(client, "playgamesound items/nvg_off.wav");
}

public Select_MenuPlus(Handle:MenuPlus_handle, MenuAction:action, client, option) 
{ 
	if(IsPlayerAlive(client) && client == Warden)
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
}



// if (floodcontrol == 1)
// {
// PrintToChat(client,"Не используйте меню так часто!");
// }
// else
// {
// 	floodcontrol = 1;
// 	CreateTimer(5.0, FLOOD_D_timer);
// }





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
	if(IsPlayerAlive(client) && client == Warden)
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
