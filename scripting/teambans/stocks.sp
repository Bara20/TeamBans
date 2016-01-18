stock void SwitchTeam(int client, int team)
{
	ChangeClientTeam(client, team);

	int clients[1];
	Handle bf;
	clients[0] = client;
	bf = StartMessage("VGUIMenu", clients, 1);

	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetString(bf, "name", "team");
		PbSetBool(bf, "show", true);
	}
	else
	{
		BfWriteString(bf, "team");
		BfWriteByte(bf, 1);
		BfWriteByte(bf, 0);
	}

	EndMessage();
}

stock void SafeCloseHandle(Handle & rHandle)
{
	if (rHandle != null)
	{
		CloseHandle(rHandle);
		rHandle = null;
	}
}

stock bool HasClientTeamBan(int client)
{
	if (g_iPlayer[client][clientBanned])
		return true;
	return false;
}

stock int GetClientBanTeam(int client)
{
	if(HasClientTeamBan(client))
		return g_iPlayer[client][banTeam];
	return 0;
}

stock bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
		return true;
	return false;
}

stock void ResetVars(int client, bool resetAuth = true)
{
	if(resetAuth)
	{
		g_iPlayer[client][clientID] = 0;
		g_iPlayer[client][clientAuth] = false;
	}
	
	g_iPlayer[client][clientReady] = false;
	g_iPlayer[client][clientBanned] = false;
	g_iPlayer[client][banID] = 0;
	g_iPlayer[client][banLength] = 0;
	g_iPlayer[client][banTimeleft] = 0;
	g_iPlayer[client][banTeam] = 0;
	Format(g_iPlayer[client][banReason], TEAMBANS_REASON_LENGTH, "");
	SafeCloseHandle(g_iPlayer[client][banCheck]);
}

stock void CheckAllClients()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			char sSteamID[32];
			GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));
			OnClientAuthorized(i, sSteamID);
		}
	}
}

stock void IsAndMoveClient(int client)
{
	if (HasClientTeamBan(client))
	{
		if(GetClientBanTeam(client) == GetClientTeam(client))
		{
			char sTeam[TEAMBANS_TEAMNAME_SIZE];
			
			TeamBans_GetTeamName(GetClientBanTeam(client), sTeam, sizeof(sTeam), client);
				
			if(g_iPlayer[client][banLength] > 0)
				CPrintToChat(client, "%T", "TeamBanned", client, g_sTag, g_iPlayer[client][banTimeleft], sTeam);
			else if(g_iPlayer[client][banLength] == 0)
				CPrintToChat(client, "%T", "TeamBannedPerma", client, g_sTag, sTeam);
			
			if(GetClientTeam(client) == TEAMBANS_CT && GetClientBanTeam(client) == TEAMBANS_CT)
				SwitchTeam(client, TEAMBANS_T);
			else if(GetClientTeam(client) == TEAMBANS_T && GetClientBanTeam(client) == TEAMBANS_T)
				SwitchTeam(client, TEAMBANS_CT);
		}
	}
}

stock bool IsAndMoveClient_JoinTeam(int client, int team)
{
	if (HasClientTeamBan(client))
	{
		if(GetClientBanTeam(client) == team)
		{
			char sTeam[TEAMBANS_TEAMNAME_SIZE];
			
			TeamBans_GetTeamName(GetClientBanTeam(client), sTeam, sizeof(sTeam), client);
				
			if(g_iPlayer[client][banLength] > 0)
				CPrintToChat(client, "%T", "TeamBanned", client, g_sTag, g_iPlayer[client][banTimeleft], sTeam);
			else if(g_iPlayer[client][banLength] == 0)
				CPrintToChat(client, "%T", "TeamBannedPerma", client, g_sTag, sTeam);
			
			if(GetClientTeam(client) == TEAMBANS_CT && GetClientBanTeam(client) == TEAMBANS_CT)
				SwitchTeam(client, TEAMBANS_T);
			else if(GetClientTeam(client) == TEAMBANS_T && GetClientBanTeam(client) == TEAMBANS_T)
				SwitchTeam(client, TEAMBANS_CT);
			
			return true;
		}
	}
	return false;
}

stock void CheckReasonsFile()
{
	if(g_kvReasons != null)
		delete g_kvReasons;
	
	g_kvReasons = new KeyValues("reasons");
	
	if(g_kvReasons.ImportFromFile(g_sReasonsPath))
	{
		char sSection[256];
		if(!g_kvReasons.GetSectionName(sSection, sizeof(sSection)))
		{
			TB_LogFile(ERROR, "[TeamBans] (CheckReasonsFile) Wrong format in reaons file!");
			SetFailState("[TeamBans] (CheckReasonsFile) Wrong format in reaons file!");
			return;
		}
		
		if(!StrEqual(sSection, "reasons", false))
		{
			TB_LogFile(ERROR, "[TeamBans] (CheckReasonsFile) 'reasons' section not found in file: %s", g_sReasonsPath);
			SetFailState("[TeamBans] (CheckReasonsFile) 'reasons' section not found in file: %s", g_sReasonsPath);
			return;
		}
		
		g_kvReasons.Rewind();
	}
	else
	{
		TB_LogFile(ERROR, "[TeamBans] (CheckReasonsFile) '%s' not found!", g_sReasonsPath);
		SetFailState("[TeamBans] (CheckReasonsFile) '%s' not found!", g_sReasonsPath);
		return;
	}
}

stock void CheckLengthFile()
{
	if(g_kvLength != null)
		delete g_kvLength;
	
	g_kvLength = new KeyValues("length");
	
	if(g_kvLength.ImportFromFile(g_sLengthPath))
	{
		char sSection[256];
		if(!g_kvLength.GetSectionName(sSection, sizeof(sSection)))
		{
			TB_LogFile(ERROR, "[TeamBans] (CheckLengthFile) Wrong format in reaons file!");
			SetFailState("[TeamBans] (CheckLengthFile) Wrong format in reaons file!");
			return;
		}
		
		if(!StrEqual(sSection, "length", false))
		{
			TB_LogFile(ERROR, "[TeamBans] (CheckLengthFile) 'length' section not found in file: %s", g_sLengthPath);
			SetFailState("[TeamBans] (CheckLengthFile) 'length' section not found in file: %s", g_sLengthPath);
			return;
		}
		
		g_kvLength.Rewind();
	}
	else
	{
		TB_LogFile(ERROR, "[TeamBans] (CheckLengthFile) '%s' not found!", g_sLengthPath);
		SetFailState("[TeamBans] (CheckLengthFile) '%s' not found!", g_sLengthPath);
		return;
	}
}

stock void SQL_CheckTables()
{
	char sQuery[] = "\
		CREATE TABLE IF NOT EXISTS `teambans` ( \
		  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,\
		  `playerid` varchar(64) NOT NULL, \
		  `playername` varchar(128) NOT NULL, \
		  `date` int(10) NOT NULL, \
		  `length` int(32) NOT NULL, \
		  `timeleft` int(32) NOT NULL, \
		  `team` int(2) NOT NULL, \
		  `active` tinyint(1) NOT NULL, \
		  `reason` varchar(128) NOT NULL, \
		  `adminid` varchar(64) NOT NULL , \
		  `adminname` varchar(128) NOT NULL, \
		  `uadminid` varchar(64) DEFAULT NULL, \
		  `uadminname` varchar(128) NOT NULL, \
		  PRIMARY KEY (`id`) \
		) ENGINE=InnoDB DEFAULT CHARSET=utf8;";
	
	if(IsDebug() && GetLogLevel() >= view_as<int>(DEBUG))
		TB_LogFile(DEBUG, "[TeamBans] (SQL_CheckTables) %s", sQuery);
	
	g_dDB.Query(SQLCallback_Create, sQuery, _, DBPrio_High);
}
