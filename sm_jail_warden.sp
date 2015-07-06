#pragma semicolon 1 
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <warden>
#include <morecolors>
#include <sdkhooks>
//#include <lastrequest>
#include <basecomm>

// --------------------
//thanks for the basis code https://github.com/ecca
//спасибо за базовый код https://github.com/ecca
// --------------------

#define PLUGIN_VERSION   "2.5"

new Warden = -1;
new Handle:g_fward_onBecome = INVALID_HANDLE;
new Handle:g_fward_onRemove = INVALID_HANDLE;

new Handle:WardenModel;
new String:WardenModelPath[PLATFORM_MAX_PATH] = "models/player/ct_gign.mdl";

new Handle:GlowLight;
new String:GlowLightPath[PLATFORM_MAX_PATH] = "sprites/animglow01.vmt";

new Handle:GlowLightColor;
new String:GlowLightColorPick[] = "0 255 0";

new Handle:GlowLightSize;
new String:GlowLightSizePick[] = "0.6";

new LR_cancel_count = 2; // сколько раз может отменять LR командир
new hg_count = 25;

new floodcontrol = 0;
new mute_comandspam_control = 0;

new FreeDayTrigger = 0;
new FreeDayPlayer = -1;
new CT_Vote_cmd;
new String:m_ModelName_before_ward[PLATFORM_MAX_PATH];
new Handle:h_Menu, Handle:h_Timer;
new kick_vots[MAXPLAYERS + 1], timer_sec, all_votes; 
new HP_bw = -1;
new g_offsCollisionGroup;
new switch_noblock = 0;

public Plugin:myinfo = {
	name = "Jail Warden (by FoxSerito)",
	author = "FoxSerito",
	description = "Warden menu for jail mod server",
	version = PLUGIN_VERSION,
	url = "vk.com/foxserito"
};

public OnPluginStart() 
{
	AutoExecConfig();
	LoadTranslations("warden.phrases");

	RegConsoleCmd("sm_uw", ExitWarden);
	RegConsoleCmd("sm_unwarden", ExitWarden);
	RegConsoleCmd("sm_uc", ExitWarden);
	RegConsoleCmd("sm_uncommander", ExitWarden);
	RegConsoleCmd("sm_w", openmenu);
	RegConsoleCmd("sm_c", openmenu);
	RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_rc", RemoveWarden, ADMFLAG_GENERIC);

	//HookEvent("round_end",round_end,EventHookMode_Pre);
	HookEvent("round_start", round_start, EventHookMode_PostNoCopy); 

	HookEvent("player_death", playerDeath);

	RegConsoleCmd("say", say);
	RegConsoleCmd("say_team", say);

	g_offsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
	if (g_offsCollisionGroup == -1)
	{
		SetFailState("[NoBlock] Failed to get offset for CBaseEntity::m_CollisionGroup.");
	}

	CreateConVar("sm_warden_version", PLUGIN_VERSION,  "The version of the SourceMod plugin Jail Warden, by FoxSerito", FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_fward_onBecome = CreateGlobalForward("warden_OnWardenCreated", ET_Ignore, Param_Cell);
	g_fward_onRemove = CreateGlobalForward("warden_OnWardenRemoved", ET_Ignore, Param_Cell);
	WardenModel = CreateConVar("warden_model", WardenModelPath, "Модель командира");
	GlowLight = CreateConVar("GlowLight_Texture", GlowLightPath, "Текстура направляющего света");
	GlowLightColor = CreateConVar("GlowLight_Color", GlowLightColorPick, "Цвет направляющего света (R G B)");
	GlowLightSize = CreateConVar("GlowLight_Size", GlowLightSizePick, "Размер направляющего света");
}

public OnConfigsExecuted()
{
	GetConVarString(WardenModel, WardenModelPath, sizeof(WardenModelPath));
	GetConVarString(GlowLight, GlowLightPath, sizeof(GlowLightPath));
	GetConVarString(GlowLightColor, GlowLightColorPick, sizeof(GlowLightColorPick));
	GetConVarString(GlowLightSize, GlowLightSizePick, sizeof(GlowLightSizePick));
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

public OnMapStart()
{
	AddFileToDownloadsTable("sound/foxworldportal/jail/mkd_fight.mp3");
	PrecacheSound("foxworldportal/jail/mkd_fight.mp3");
}

public Action:openmenu(client, args) 
{

	if(IsPlayerAlive(client) && warden_iswarden(client))
	{
		ShowMyPanel(client);
	}
	else // если командир уже назначен просто открываем ему меню
	{
		BecomeWarden(client, args);
	}
	return Plugin_Handled;
}

public Action:BecomeWarden(client, args) 
{
	if (Warden == -1) // если нет кмд
	{
		
		if (GetClientTeam(client) == 3) // если игрок КТ
		{
			if (IsPlayerAlive(client) && CT_Vote_cmd == 0) // если игрок жив и голосование не идет
			{
				SetTheWarden(client); //игрок становится КМД
				ShowMyPanel(client); //и показываем ему сразу меню
			}
			else if(CT_Vote_cmd > 0) // если голосование еще идет
			{
				CPrintToChat(client,"[КМД] ~ Вы неможете сейчас стать командиром, идет голосование!");
			}
			//else if( ) //если у когонибудь ЛР
			//{
			//	CPrintToChat(client,"[КМД] ~ Вы неможете сейчас стать командиром, идет ЛР!");
			//}
			else // или другая причина
			{
				//CPrintToChat(client, "[КМД] %t", "warden_playerdead");
				CPrintToChat(client,"[КМД] ~ Вы неможете сейчас стать командиром!");
			}
		}
		else // только КТ могут стать командиром
		{
			CPrintToChat(client,"[КМД] ~  %t", "warden_ctsonly");
		}
	}
	else // командир уже назначен
	{
		CPrintToChat(client,"[КМД] ~  %t", "warden_exist", Warden);
	}
}

public Action:ExitWarden(client, args) 
{
	if(client == Warden) // убеждаемся в игроке что он командир
	{
		CPrintToChatAll("[КМД] %t", "warden_retire", client);
		if (GetClientMenu(client))
		{
			CancelClientMenu(client);
		}
		Warden = -1; // даем возможность другим стать командиром
		//SetEntityRenderColor(client, 255, 255, 255, 255);
	}
	else 
	{
		CPrintToChat(client, "[КМД] %t", "warden_notwarden");
	}
}

public round_start(Handle:event, const String:name[], bool:silent) 
{ 
	new T_players = GetTeamClientCount(CS_TEAM_T);
	new CT_players = GetTeamClientCount(CS_TEAM_CT);

	Warden = -1; // в начале раунда открываем вакансию командира
	FreeDayTrigger = 0;
	FreeDayPlayer = -1;
	LR_cancel_count = 2;
	hg_count = 25;

	BlockClientAll();
	switch_noblock = 0;

	if (h_Timer != INVALID_HANDLE) 
	{ 
		KillTimer(h_Timer); 
		h_Timer = INVALID_HANDLE; 
	}

	ServerCommand("mp_friendlyfire 0");

	if (h_Menu != INVALID_HANDLE) CloseHandle(h_Menu); 
	h_Menu = CreateMenu(Select_Func); 
	SetMenuTitle(h_Menu, "Кто будет командовать?\n \n"); 
	SetMenuExitButton(h_Menu, false); 
	decl String:StR_Id[15], String:StR_Name[MAX_NAME_LENGTH]; 

	//new Float:gravity = GetEntPropFloat(ent, Prop_Data, "m_flGravity"); 
	// SetEntityGravity(client, 1.0);
	
	for (new p = 1; p <= MaxClients; p++) 
	{ 
		kick_vots[p] = 0;
		
		if (IsClientInGame(p) && GetClientTeam(p) == CS_TEAM_CT && GetClientName(p, StR_Name, MAX_NAME_LENGTH)) 
		{ 
			// получаем userid игрока и делаем его строкой, чтобы добавить в меню 
			IntToString(GetClientUserId(p), StR_Id, sizeof(StR_Id)); 
			AddMenuItem(h_Menu, StR_Id, StR_Name); 
		}	
	} 

	// если террористов на сервере > 2 (потомучто sm_hosties_lr_ts_max 2, чтобы не мешать писать ЛР)
	if (T_players > 2 && CT_players > 0) 
	{ 
		// показываем игрокам созданное меню и запускаем таймер 
		for (new i = 1; i <= MaxClients; i++) 
		{ 
			if (IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_T && !IsFakeClient(i)) DisplayMenu(h_Menu, i, 10); 
		} 
		all_votes = 0;  // сколько всего было голосов 
		timer_sec = 12; // время голосования в сек. 
		CT_Vote_cmd = 1; // переменная для обозначения что голосвание еще идет
		h_Timer = CreateTimer(1.0, Timer_Func, _, TIMER_REPEAT); 
	} 
	else 
	{
		// если террористов меньше 2, удаляем созданное меню и разрешаем писать команды !w/!c
		CloseHandle(h_Menu); 
		h_Menu = INVALID_HANDLE;
		CPrintToChatAll("Мало игроков для голосования, возьмите кмд командой !w или !c");  
		CT_Vote_cmd = 0;
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
		CPrintToChatAll("| %N выбрал игрока %N |", client, target); 
	} 
	else 
		CPrintToChat(client,"[КМД] ~ Игрок не найден"); 
} 

public Action:Timer_Func(Handle:timer_f) 
{ 
	if (--timer_sec > 0) 
	{ 
		PrintHintTextToAll("До завершения голосования:\n \n%d сек", timer_sec); 
		return Plugin_Continue; 
	} 

	// Время истекло, голосование окончено 
	h_Timer = INVALID_HANDLE; 
	if (h_Menu != INVALID_HANDLE) 
	{ 
		CloseHandle(h_Menu); 
		h_Menu = INVALID_HANDLE; 
	} 
 
	if (all_votes < 1)
	{
		new last_cmd[65];
		new ct_count = 0;
		for(new z = 1; z <= GetMaxClients(); z++)
		{
			if(IsClientInGame(z) && !IsFakeClient(z) && GetClientTeam(z) == CS_TEAM_CT && IsPlayerAlive(z))
			{
				last_cmd[z] = z;
				ct_count++;
			}
		}
		new random_cmd = last_cmd[GetRandomInt(1,ct_count)];
		CT_Vote_cmd = 0;
		if(IsClientInGame(random_cmd) && !IsFakeClient(random_cmd) && GetClientTeam(random_cmd) == CS_TEAM_CT && IsPlayerAlive(random_cmd)) //проверка проверка проверка :D
		{
			SetTheWarden(random_cmd);
			ShowMyPanel(random_cmd);
		}
		else if(ct_count == 0)
		{
			CPrintToChatAll("[КМД] Голосование провалилось :( Нету живых КТ");
			CT_Vote_cmd = 0;
			return Plugin_Stop;
		}

		CPrintToChatAll("[КМД] Голосов нет, случайным командиром становится %N", random_cmd);
		// 
	}
	else
	{
		CT_Vote_cmd = 0;
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
	if (target > 0 && IsClientInGame(target) && !IsFakeClient(target) && GetClientTeam(target) == CS_TEAM_CT && IsPlayerAlive(target)) //проверка проверка проверка :D
	{ 
		for(new i = 1; i <= GetMaxClients(); i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i))
			{
				ClientCommand(i, "play ui/achievement_earned.wav");
			}
		}
		CPrintToChatAll("╔═══\n║ Голосование на командира завершено!\n║ За игрока %N проголосовало %d чел.\n╚═══\n", target, all_votes);
		
		SetTheWarden(target);
		ShowMyPanel(target);
	} 
	else 
		CPrintToChatAll("Игрок за КТ не найден, введите !w или !c чтобы стать командиром."); 

	return Plugin_Stop; 
}

public Action:playerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid")); 
	
	if(client == Warden)
	{
		CPrintToChatAll("[КМД] %t", "warden_dead", client);
		SetEntityRenderColor(client, 255, 255, 255, 255);
		if (GetClientMenu(client))
		{
			CancelClientMenu(client);
		}
		Warden = -1;
	}
}


public OnClientDisconnect(client)
{
	if(client == Warden)
	{
		CPrintToChatAll("[КМД] %t", "warden_disconnected");
		if (GetClientMenu(client))
		{
			CancelClientMenu(client);
		}
		Warden = -1;
	}
}

public Action:RemoveWarden(client, args)
{
	if(Warden != -1)
	{
		RemoveTheWarden(client);
	}
	else
	{
		CPrintToChatAll("[КМД] %t", "warden_noexist");
	}

	return Plugin_Handled;
}

public Action:say(client, args) 
{
	if (Warden == client)
	{
		decl String:to_chat[255];
		decl String:msg[255];
		GetCmdArgString(msg, sizeof(msg));
		StripQuotes(msg);
		Format(to_chat, sizeof(to_chat), "%t","warden_chat", client, msg);
		if(msg[0] == '/' || msg[0] == '@' || IsChatTrigger())
		{
			return Plugin_Handled;
		}
		else CPrintToChatAll(to_chat);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}


public SetTheWarden(client)
{
	if(IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == CS_TEAM_CT && IsPlayerAlive(client))
	{
		GetEntPropString(client, Prop_Data, "m_ModelName", m_ModelName_before_ward, sizeof(m_ModelName_before_ward));

		CPrintToChatAll("[КМД] %t", "warden_new", client);
		Warden = client;
		
		HP_bw = GetClientHealth(client); // запоминаем сколько было HP до того как стать командиром
		if (GetClientHealth(client) > 90) //если жизней больше 90 
		{
			SetEntProp(client, Prop_Data, "m_iHealth", 130); //устанавливаем 130 HP
		}
		// SetClientListeningFlags(client, VOICE_NORMAL);
		SetEntityModel(client, WardenModelPath);
		Forward_OnWardenCreation(client);
	}
}

public RemoveTheWarden(client)
{
	CPrintToChatAll("[КМД] %t", "warden_removed", client, Warden);
	SetEntityRenderColor(Warden, 255, 255, 255, 255);
	SetEntityModel(client, m_ModelName_before_ward); //возвращаем модельку которая была раньше

	if (GetClientHealth(client) >= 90) //если у командира больше или равно 90 HP
	{	
		if (HP_bw > 100) //если перед тем как стать командиром у него было больше 100
		{
			SetEntProp(client, Prop_Data, "m_iHealth", HP_bw); // возвращаем жизни которые раньше были до того как стал командиром
		}
		else if (HP_bw >= 90 && HP_bw < 100) // если жизней от 90 до 100
		{
			SetEntProp(client, Prop_Data, "m_iHealth", 100); // хилимся живееем!!!! :D
		}
	}

	if (GetClientMenu(client))
	{
		CancelClientMenu(client);
	}
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
	SetPanelTitle(maincmd, "Меню командира\n \n"); 
	DrawPanelItem(maincmd, "[◄|►] Открыть все двери");
	DrawPanelItem(maincmd, "Направляющий свет");
	DrawPanelItem(maincmd, "Снять ФД/станд. цвет");	
	DrawPanelItem(maincmd, "Дать мирный фридей (1чел)");
	DrawPanelItem(maincmd, "Драка заключенных Вкл./Выкл.");
	DrawPanelItem(maincmd, "NoBlock Вкл./Выкл.");
	DrawPanelItem(maincmd, "Выкл микро заключенным на 15 сек");
	DrawPanelItem(maincmd, "Еще >>");
	DrawPanelText(maincmd, "\n \n");
	DrawPanelItem(maincmd, "[-] Покинуть пост");
	DrawPanelItem(maincmd, "[X] Выйти из меню");
	SendPanelToClient(maincmd, client, Select_Panel, 0);
	CloseHandle(maincmd);
}



public Select_Panel(Handle:maincmd, MenuAction:action, client, option)  
{ 
	if (action == MenuAction_Select) 
	{ 
		if(IsPlayerAlive(client) && warden_iswarden(client))
		{
			switch(option)
			{
				case 1:
				{
					if (floodcontrol == 1)
					{
						CPrintToChat(client,"[КМД] ~ Не используйте меню так часто!");
						ShowMyPanel(client);
					}
					else
					{
						floodcontrol = 1;
						CPrintToChatAll("[КМД] ~ Командир Открыл Джайлы и другие обьекты");
						OpenAllDoors();
						ShowMyPanel(client);
						CreateTimer(5.0, FLOOD_D_timer);
					}
				}
				case 2:
				{
					CreateGlowLight(client);
					ShowMyPanel(client);
				}
				case 3:
				{
					ColorChangeDef(client);
					ShowMyPanel(client);
				}
				case 4:
				{
					// фридей
					FreeDay(client);
					ShowMyPanel(client);
				}
				case 5:
				{
					if (GetConVarInt(FindConVar("mp_friendlyfire")) == 1) 
					{
						floodcontrol = 1;
						ServerCommand("mp_friendlyfire 0");
						PrintHintTextToAll("[КМД] ~ Командир запретил заключенным драться!"); 
						CPrintToChatAll("[КМД] ~ Командир запретил заключенным драться!");
						CreateTimer(5.0, FLOOD_D_timer);
						for(new i = 1; i <= GetMaxClients(); i++)
						{
							if(IsClientInGame(i) && !IsFakeClient(i))
							{
								ClientCommand(i, "play buttons/weapon_cant_buy.wav");
							}
						}

					}
					else if (floodcontrol == 1)
					{
						CPrintToChat(client,"[КМД] ~ Не используйте меню так часто!");
					}
					else
					{
						floodcontrol = 1;
						ServerCommand("mp_friendlyfire 1");
						PrintHintTextToAll("[КМД] ~ Командир разрешил заключенным драться!");
						CPrintToChatAll("[КМД] ~ Командир разрешил заключенным драться!");
						CreateTimer(5.0, FLOOD_D_timer);
						for(new i = 1; i <= GetMaxClients(); i++)
						{
							if(IsClientInGame(i) && !IsFakeClient(i))
							{
								ClientCommand(i, "play foxworldportal/jail/mkd_fight.mp3");
							}
						}
					}
					ShowMyPanel(client);
				}
				case 6:
				{
					if (switch_noblock == 1) 
					{
						floodcontrol = 1;
						BlockClientAll();
						switch_noblock = 0;
						CPrintToChatAll("[КМД] ~ Командир выключил noblock!");
						PrintHintTextToAll("[КМД] ~ noblock выключен -");
						for(new i = 1; i <= GetMaxClients(); i++)
						{
							if(IsClientInGame(i) && !IsFakeClient(i))
							{
								ClientCommand(i, "play buttons/weapon_cant_buy.wav");
							}
						} 
						CreateTimer(5.0, FLOOD_D_timer);
					}
					else if (floodcontrol == 1)
					{
						CPrintToChat(client,"[КМД] ~ Не используйте меню так часто!");
					}
					else
					{
						floodcontrol = 1;
						UnblockClientAll();
						switch_noblock = 1;
						CPrintToChatAll("[КМД] ~ Командир включил noblock!");
						PrintHintTextToAll("[КМД] ~ noblock включен +");
						for(new i = 1; i <= GetMaxClients(); i++)
						{
							if(IsClientInGame(i) && !IsFakeClient(i))
							{
								ClientCommand(i, "play physics/metal/chain_impact_soft2.wav");
							}
						} 
						CreateTimer(5.0, FLOOD_D_timer);
					}
					ShowMyPanel(client);
				}
				case 7:
				{
					if (mute_comandspam_control == 1)
					{
						CPrintToChat(client,"[КМД] ~ Повторно выдать мут можно только через 30 сек!");
						ShowMyPanel(client);
					}
					else
					{
						mute_comandspam_control = 1;
						ShowMyPanel(client);
						Mute_alive_T(); // устанавливаем все Т мут
						CreateTimer(15.0, Timer_UnMute_alive_T, client, TIMER_FLAG_NO_MAPCHANGE); // через 15 секунда автоматически снимаем мут с Т
						CreateTimer(30.0, mute_comandspam_timer);
					}
				}
				case 8:
				{
					MenuPlus(client);
				}
				case 9:
				{
					CPrintToChatAll("[КМД] ~ Командир покинул пост, возьмите командование!");
					SetEntityModel(client, m_ModelName_before_ward); //возвращаем модельку которая была раньше
					Warden = -1;
				}
			}
		}
		else // The warden already exist so there is no point setting a new one
		{
			CPrintToChat(client, "[КМД] ~ Вы не КМД");
		}
	} 
}

Mute_alive_T()
{
	new MutedT_count;
	MutedT_count = 0;
	for(new i = 1; i <= MaxClients; i++)
	{
		if ( IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T && !IsFakeClient(i) && !BaseComm_IsClientMuted(i) && !(GetUserFlagBits(i) & ADMFLAG_GENERIC) )
		{
			BaseComm_SetClientMute(i, true);
			MutedT_count++;
		}
	}
	if (MutedT_count == 0) CPrintToChatAll("[КМД] ~ Заключенных нет, некому отключать микрофон.");
	else CPrintToChatAll("[КМД] ~ Командир отключил заключенным микрофон на 15 сек (%i человек)",MutedT_count);
}	

public Action:Timer_UnMute_alive_T(Handle:fox_m_timer, any:client)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T && !IsFakeClient(i) && BaseComm_IsClientMuted(i) ) // if player is in game and alive
		{
			BaseComm_SetClientMute(i, false);
		}
	}
	CPrintToChatAll("[КМД] ~ Время вышло, заключенные снова могут говорить!");
}

MenuPlus(client) 
{ 
	new Handle:MenuPlus_handle = CreatePanel(); 
	SetPanelTitle(MenuPlus_handle, "Дополнительное меню:");	// заголовок
	DrawPanelText(MenuPlus_handle, "\n \n");
	DrawPanelItem(MenuPlus_handle, "Покрасить в синий");
	DrawPanelItem(MenuPlus_handle, "Покрасить в зеленый");
	DrawPanelItem(MenuPlus_handle, "Отменить все ЛР (2 раза)");
	DrawPanelItem(MenuPlus_handle, "Взять гранату (25 раз)");
	DrawPanelItem(MenuPlus_handle, "Игра призрак (В разработке)");
	DrawPanelText(MenuPlus_handle, "\n \n");
	DrawPanelItem(MenuPlus_handle, "<< Назад");
	SendPanelToClient(MenuPlus_handle, client, Select_Panel_plus, 0);
	CloseHandle(MenuPlus_handle);
	ClientCommand(client, "playgamesound items/nvg_off.wav");
}


public Select_Panel_plus(Handle:MenuPlus_handle, MenuAction:action, client, option) 
{ 
	if(IsPlayerAlive(client) && warden_iswarden(client))
	{
		switch(option)
		{
			case 1:
			{
				ColorChangeBlue(client);
				MenuPlus(client);
			}
			case 2:
			{
				ColorChangeGreen(client);
				MenuPlus(client);
			}
			case 3:
			{
				if (floodcontrol == 1)
				{
					CPrintToChat(client,"[КМД] ~ Не используйте меню так часто!");
				}
				else if (LR_cancel_count == 0)
				{
					CPrintToChat(client,"[КМД] ~ Вы больше неможете отменять LR!");
				}
				else
				{
					floodcontrol = 1;
					CreateTimer(5.0, FLOOD_D_timer);
					ServerCommand("sm_stoplr"); //остановить лр
					--LR_cancel_count;
				}
				MenuPlus(client);
			}
			case 4: 
			{
				if (hg_count == 0)
				{
					CPrintToChat(client,"[КМД] ~ У вас закончились гранаты!");
				}
				else
				{
					GivePlayerItem(client, "weapon_hegrenade");
					--hg_count;
					CPrintToChat(client,"[КМД] ~ У вас осталось %d гранат(а/ы)!",hg_count);
				}
				MenuPlus(client);
			}
			case 5:
			{
				CPrintToChat(client,"[КМД] ~ В разработке!");
				MenuPlus(client);
			}
			case 6:
			{
				ShowMyPanel(client);
			}
		}
		if (action == MenuAction_End)
		{
			CloseHandle(MenuPlus_handle);
		}
	}
	else // The warden already exist so there is no point setting a new one
	{
		CPrintToChat(client, "[КМД] ~ Вы не КМД");
	}
}

public Action:FLOOD_D_timer(Handle:timer)
{
	floodcontrol = 0;
}

public Action:mute_comandspam_timer(Handle:timer)
{
	mute_comandspam_control = 0;
}
//-------------------------------------------------
// Перекрас
//-------------------------------------------------

ColorChangeBlue(client)
{
	new targetaim = GetClientAimTarget(client, true);
	if( targetaim == -1)
	{
		CPrintToChat(client,"[КМД] ~ Наведите прицел на живого игрока!");
	}
	else
	{
		SetEntityRenderColor(targetaim, 0, 0, 255, 255);
		CPrintToChat(client,"[КМД] ~ Вы перекрасили игрока %N в синий",targetaim);
		CPrintToChat(targetaim,"[КМД] ~ Вас перекрасили в СИНИЙ!");
		PrintHintText(targetaim,"[КМД] ~ Вас перекрасили в СИНИЙ!");
	}	
}

ColorChangeGreen(client)
{
	new targetaim = GetClientAimTarget(client, true);
	if( targetaim == -1)
	{
		CPrintToChat(client,"[КМД] ~ Наведите прицел на живого игрока!");
	}
	else
	{
		SetEntityRenderColor(targetaim, 0, 255, 0, 255);
		CPrintToChat(client,"[КМД] ~ Вы перекрасили игрока %N в зеленый",targetaim);
		CPrintToChat(targetaim,"[КМД] ~ Вас перекрасили в ЗЕЛЕНЫЙ!");
		PrintHintText(targetaim,"[КМД] ~ Вас перекрасили в ЗЕЛЕНЫЙ!");
	}
}

ColorChangeDef(client)
{
	new targetaim = GetClientAimTarget(client, true);
	if( targetaim == -1)
	{
		CPrintToChat(client,"[КМД] ~ Наведите прицел на живого игрока!");
	}
	else if(targetaim == FreeDayPlayer) // снимем фридей
	{
		SetEntityRenderColor(targetaim, 255, 255, 255, 255);
		FreeDayTrigger = 0;
		FreeDayPlayer = -1;
		CPrintToChatAll("[КМД] ~  Командир снял мирный фридей с %N", targetaim);
		CPrintToChat(targetaim,"[КМД] ~ С вас снят мирный фридей!");
		PrintHintText(targetaim,"[КМД] ~ С вас снят мирный фридей");
	}
	else
	{
		SetEntityRenderColor(targetaim, 255, 255, 255, 255);
		PrintHintText(targetaim,"[КМД] ~ Ваш цвет был сброшен");
		CPrintToChat(targetaim,"[КМД] ~ Ваш цвет был сброшен");
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
		CPrintToChat(client,"[КМД] ~ Наведите прицел на живого игрока!");
	}
	else
	{
		if (client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			if(targetaim == FreeDayPlayer) //если цель уже с фридеем
			{
				CPrintToChat(client,"[КМД] ~ У заключенного %s уже есть мирный фридей!", FreeDayPlayer);
			}
			else //если же нет
			{
				if(FreeDayTrigger < 1) //проверяем есть ли место под фридей
				{
					FreeDayPlayer = targetaim; //даем фридей
					FreeDayTrigger = 1; 
					SetEntityRenderColor(targetaim, 0, 0, 0, 255);
					CPrintToChatAll("[КМД] ~ Командир выдал  мирный фридей игроку %N", targetaim);
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
					CPrintToChat(client,"[КМД] ~ Уже есть заключенный которому выдан мирный фридей!");
				}
			}
		}
	}
}

//-------------------------------------------------
// НАПРАВЛЯЮЩИЙ СВЕТ
//-------------------------------------------------

CreateGlowLight(client)
{ 
	decl Float:aim_Position[3]; 
	GetLookPosition_f(client, aim_Position);
	new weapon_ent = CreateEntityByName("env_sprite"); 
	if (weapon_ent < 1) 
	{ 
		LogError("Ошибка при создании env_sprite"); 
		return; 
	}
	DispatchKeyValueVector(weapon_ent, "origin", aim_Position); 
	DispatchKeyValue(weapon_ent,"model",GlowLightPath); 
	DispatchKeyValue(weapon_ent,"rendermode","9"); 
	DispatchKeyValue(weapon_ent,"spawnflags","1"); 
	DispatchKeyValue(weapon_ent,"rendercolor", GlowLightColorPick);
	DispatchKeyValue(weapon_ent,"scale", GlowLightSizePick); 
	DispatchKeyValue(weapon_ent, "OnUser1", "!self,Kill,0,15,-1"); // 15 = через сколько сек удалять
	DispatchSpawn(weapon_ent); 
	AcceptEntityInput(weapon_ent, "FireUser1");
}

GetLookPosition_f(client, Float:aim_Position[3]) 
{ 
	decl Float:EyePosition[3], Float:EyeAngles[3], Handle:h_trace; 
	GetClientEyePosition(client, EyePosition); 
	GetClientEyeAngles(client, EyeAngles); 
	h_trace = TR_TraceRayFilterEx(EyePosition, EyeAngles, MASK_SOLID, RayType_Infinite, GetLookPos_Filter_F, client); 
	TR_GetEndPosition(aim_Position, h_trace); 
	CloseHandle(h_trace); 
} 

public bool:GetLookPos_Filter_F(ent, mask, any:client) 
{ 
	return client != ent; 
}
//-------------------------------------------------


//-------------------------------------------------
//    NoBlock
//-------------------------------------------------

BlockEntity(client)
{
	SetEntData(client, g_offsCollisionGroup, 5, 4, true);
}

UnblockEntity(client)
{
	SetEntData(client, g_offsCollisionGroup, 2, 4, true);
}

BlockClientAll()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if ( IsClientInGame(i) && IsPlayerAlive(i) )
		{
			BlockEntity(i);
		}
	}
}

UnblockClientAll()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if ( IsClientInGame(i) && IsPlayerAlive(i) )
		{
			UnblockEntity(i);
		}
	}
}
//-------------------------------------------------


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