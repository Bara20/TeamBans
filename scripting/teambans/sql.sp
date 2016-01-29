stock void SQL_OnPluginStart()
{
	if (!SQL_CheckConfig("teambans"))
	{
		TB_LogFile(ERROR, "(SQL_OnPluginStart) Database failure: Couldn't find Database entry \"teambans\"");
		
		SetFailState("(SQL_OnPluginStart) Database failure: Couldn't find Database entry \"teambans\"");
		return;
	}
	
	Database.Connect(SQL_OnConnect, "teambans");
}

public void SQL_OnConnect(Database db, const char[] error, any data)
{
	if(db == null || strlen(error) > 0)
	{
		TB_LogFile(ERROR, "(SQL_OnConnect) Connection to database failed!: %s", error);
		
		SetFailState("(SQL_OnConnect) Connection to database failed!: %s", error);
		return;
	}
	
	DBDriver iDriver = db.Driver;
		
	char sDriver[16];
	iDriver.GetIdentifier(sDriver, sizeof(sDriver));
	
	if (!StrEqual(sDriver, "mysql", false))
	{
		TB_LogFile(ERROR, "(SQL_OnConnect) Only mysql support!");
		
		SetFailState("(SQL_OnConnect) Only mysql support!");
		return;
	}

	g_dDB = db;

	SQL_CheckTables();

	g_dDB.SetCharset("utf8");
	
	CheckAllClients();
}

public void SQL_OnClientAuthorized(Database db, DBResultSet results, const char[] error, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(!client || g_iPlayer[client][clientID] != client)
		return;
	
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR, "[TeamBans] (SQL_OnClientAuthorized) Query failed: %s", error);
		
		return;
	}
	else
	{
		if(results.HasResults)
		{
			char sCommunityID[64];
			
			if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
				return;
			
			while(results.FetchRow())
			{
				if(IsDebug() && GetLogLevel() >= view_as<int>(DEBUG))
					TB_LogFile(DEBUG, "[TeamBans] (SQL_OnClientAuthorized) %N - %s", client, sCommunityID);
				
				g_iPlayer[client][banLength] = results.FetchInt(0);
				g_iPlayer[client][banTimeleft] = results.FetchInt(1);
				int active = results.FetchInt(2);
				results.FetchString(3, g_iPlayer[client][banReason], TEAMBANS_REASON_LENGTH);
				g_iPlayer[client][banID] = results.FetchInt(4);
				g_iPlayer[client][banTeam] = results.FetchInt(5);
				g_iPlayer[client][banDate] = results.FetchInt(6);
				
				if(active == 1)
				{
					if(g_iPlayer[client][banTeam] == TEAMBANS_SERVER)
					{
						int iDate = GetTime();
						int uDate = g_iPlayer[client][banDate] + (g_iPlayer[client][banLength] * 60);
						
						if(uDate > iDate)
						{
							float fTimeleft = float((uDate - iDate) / 60);
							int iTimeleft = RoundToCeil(fTimeleft);
							
							UpdateServerTimeleft(client, iTimeleft);
							ResetVars(client);
							KickClient(client, "%T", "BanReason", client);
						}
						else
							DelTeamBan(0, client);
						
						return;
					}
						
					g_iPlayer[client][clientBanned] = true;
					
					if (g_iPlayer[client][banLength] == 0)
					{
						g_iPlayer[client][banLength] = 0;
						g_iPlayer[client][banTimeleft] = 0;
						g_iPlayer[client][clientReady] = true;
					}
					else if (g_iPlayer[client][banLength] > 0 && g_iPlayer[client][banTimeleft] > 0)
					{
						SafeCloseHandle(g_iPlayer[client][banCheck]);
	
						if (g_iPlayer[client][banCheck] == null)
							g_iPlayer[client][banCheck]  = CreateTimer(60.0, Timer_BanCheck, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
						g_iPlayer[client][clientReady] = true;
					}
				}
				
				CreateTimer(5.0, Timer_SQLConnect, GetClientUserId(client));
				
				if(IsDebug() && GetLogLevel() >= view_as<int>(DEBUG))
					TB_LogFile(DEBUG, "clientIndex: %d - banLength: %d - banTimeleft: %d - banActive: %d - banReason: %s - banID: %d - banTeam: %d", client, g_iPlayer[client][banLength], g_iPlayer[client][banTimeleft], g_iPlayer[client][clientBanned], g_iPlayer[client][banReason], g_iPlayer[client][banID], g_iPlayer[client][banTeam]);
			}
			g_iPlayer[client][clientReady] = true;
		}
	}
}

public void SQL_ReCheckTeamBans(Database db, DBResultSet results, const char[] error, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(!client || g_iPlayer[client][clientID] != client)
		return;
	
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR, "[TeamBans] (SQL_ReCheckTeamBans) Query failed: %s", error);
		return;
	}
	else
	{
		if(results.HasResults)
		{
			char sCommunityID[64];
			
			if(!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
				return;
			
			while(results.FetchRow())
			{
				if(IsDebug() && GetLogLevel() >= view_as<int>(DEBUG))
					TB_LogFile(DEBUG, "[TeamBans] (SQL_ReCheckTeamBans) %N - %s", client, sCommunityID);
				
				g_iPlayer[client][banLength] = results.FetchInt(0);
				g_iPlayer[client][banTimeleft] = results.FetchInt(1);
				int active = results.FetchInt(2);
				results.FetchString(3, g_iPlayer[client][banReason], TEAMBANS_REASON_LENGTH);
				g_iPlayer[client][banID] = results.FetchInt(4);
				g_iPlayer[client][banTeam] = results.FetchInt(5);
				
				if(active == 1)
				{
					g_iPlayer[client][clientBanned] = true;
					
					if (g_iPlayer[client][banLength] == 0)
					{
						g_iPlayer[client][banLength] = 0;
						g_iPlayer[client][banTimeleft] = 0;
						g_iPlayer[client][clientReady] = true;
					}
					else if (g_iPlayer[client][banLength] > 0 && g_iPlayer[client][banTimeleft] > 0)
					{
						SafeCloseHandle(g_iPlayer[client][banCheck]);
	
						if (g_iPlayer[client][banCheck] == null)
							g_iPlayer[client][banCheck]  = CreateTimer(60.0, Timer_BanCheck, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
						g_iPlayer[client][clientReady] = true;
					}
				}
				
				CreateTimer(5.0, Timer_SQLConnect, GetClientUserId(client));
			}
			g_iPlayer[client][clientReady] = true;
		}
	}
}

public void SQL_CheckOfflineBans(Database db, DBResultSet results, const char[] error, any pack)
{
	ResetPack(pack);
	
	int aid = ReadPackCell(pack);
	int admin;
	if(aid != 0 && IsClientValid(GetClientOfUserId(aid)))
		admin = GetClientOfUserId(aid);
	char target[18];
	ReadPackString(pack, target, sizeof(target));
	int team = ReadPackCell(pack);
	int length = ReadPackCell(pack);
	char reason[128];
	ReadPackString(pack, reason, sizeof(reason));
	
	if(db == null || strlen(error) > 0)
	{
		if(GetLogLevel() >= view_as<int>(ERROR))
			TB_LogFile(ERROR, "[TeamBans] (SQL_CheckOfflineBans) Query failed: %s", error);
		return;
	}
	else
	{
		char sCommunityID[64];
		
		if(admin > 0)
		{
			if(!GetClientAuthId(admin, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
				return;
		}
		else
			Format(sCommunityID, sizeof(sCommunityID), "0");
		
		if(results.HasResults)
		{
			while(results.FetchRow())
			{
				if(IsDebug() && GetLogLevel() >= view_as<int>(DEBUG))
					TB_LogFile(DEBUG, "[TeamBans] (SQL_CheckOfflineBans) %N - %s - %s", target, sCommunityID, target);
				
				int bActive = results.FetchInt(0);
				int bTeam = results.FetchInt(1);
				
				if(bActive && bTeam == team)
				{
					char sTeam[TEAMBANS_TEAMNAME_SIZE];
					TeamBans_GetTeamNameByNumber(team, sTeam, sizeof(sTeam));
					char sBuffer[32];
					Format(sBuffer, sizeof(sBuffer), "IsAlready%sBanned", sTeam);
					if(admin > 0 && IsClientValid(admin))
						CPrintToChat(admin, "%T", sBuffer, admin, g_sTag);
					return;
				}
				else if (bActive && (bTeam > TEAMBANS_SERVER && bTeam != team))
				{
					team = TEAMBANS_SERVER;
					SetOfflineBan(admin, sCommunityID, target, team, length, length, reason);
					return;
				}
				else
				{
					SetOfflineBan(admin, sCommunityID, target, team, length, length, reason);
					return;
				}
			}
		}
		SetOfflineBan(admin, sCommunityID, target, team, length, length, reason);
		return;
	}
}

stock void SetOfflineBan(int admin, const char[] adminid, const char[] target, int team, int length, int timeleft, const char[] reason)
{
	char sEAdmin[MAX_NAME_LENGTH], sAdmin[MAX_NAME_LENGTH];
	
	if(admin > 0 && IsClientValid(admin))
		GetClientName(admin, sEAdmin, sizeof(sEAdmin));
	
	g_dDB.Escape(sEAdmin, sAdmin, sizeof(sAdmin));
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "INSERT INTO `teambans` (`playerid`, `playername`, `date`, `length`, `timeleft`, `team`, `active`, `reason`, `adminid`, `adminname`) VALUES ('%s', 'Offline Ban', UNIX_TIMESTAMP(), '%d', '%d', '%d', '1', '%s', '%s', '%s');", target, length, timeleft, team, reason, adminid, sAdmin);
	
	if(IsDebug() && GetLogLevel() >= view_as<int>(DEBUG))
		TB_LogFile(DEBUG, "[TeamBans] (SQL_CheckOfflineBans) %s", sQuery);
	
	Action aResult = Plugin_Continue;
	Call_StartForward(g_iForwards[hOnPreOBan]);
	Call_PushCell(admin);
	Call_PushString(target);
	Call_PushCell(team);
	Call_PushCell(length);
	Call_PushCell(timeleft);
	Call_PushString(reason);
	Call_Finish(aResult);

	if(aResult > Plugin_Changed)
		return;
	
	g_dDB.Query(SQLCallback_OBan, sQuery, _, DBPrio_High);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i))
		{
			char sTeam[TEAMBANS_TEAMNAME_SIZE];
			TeamBans_GetTeamNameByNumber(team, sTeam, sizeof(sTeam), i);
			
			if(team > TEAMBANS_SERVER)
			{
				if(length > 0)
					CShowActivityEx(admin, g_sTag, "%T", "OnTeamOBan", i, target, sTeam, length, reason);
				else if(length == 0)
					CShowActivityEx(admin, g_sTag, "%T", "OnTeamOBanPerma", i, target, sTeam, reason);
			}
			else if(team == TEAMBANS_SERVER)
			{
				if(length > 0)
					CShowActivityEx(admin, g_sTag, "%T", "OnServerOBan", i, target, sTeam, length, reason);
				else if(length == 0)
					CShowActivityEx(admin, g_sTag, "%T", "OnServerOBanPerma", i, target, sTeam, reason);
			}
		}
	}
	
	Call_StartForward(g_iForwards[hOnPostOBan]);
	Call_PushCell(admin);
	Call_PushString(target);
	Call_PushCell(team);
	Call_PushCell(length);
	Call_PushCell(timeleft);
	Call_PushString(reason);
	Call_Finish();
}