#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <hamsandwich>
#include <sqlx>
#include <jailbreak>

// #define DEBUG_MODE
#define TASK_GIVE_BONUS	 	3289327

#define get_system_points(%1)	 amxx4u_get_points(%1)
#define set_system_points(%1,%2) amxx4u_set_points(%1, %2)

static const NAME[]			= "Skill System";
static const VERSION[]		= "1.0";
static const AUTHOR[]		= "dredek";
static const URL_AUTHOR[]	= "https://amxx4u.pl/";

static const menu_title[]  	= "\d© AMXX4u.pl | SKILLS^n\r[SKILL]\w";
static const menu_prefix[] 	= "\d×\w";

static const SKILL_CONFIG[] = "/addons_configs/amxx4u/skill/system.cfg";

static const menu_commands[][] =
{
	"/skill",
	"/skille",
	"/skills",
	"/umiejetnosci",
	"/u",
	"skill",
	"skille",
	"skills",
	"umiejetnosci",
	"u"
};

enum _:PLAYER_SKILL
{
	SLABY_PUNKT,
	SPRYT,
	WYTRZYMALOSC,
	KEVLAR,
	ADIDASY
};

enum _:CVARS
{
	SQL_HOST[MAX_IP_PORT],
	SQL_USER[MAX_NAME],
	SQL_PASS[MAX_NAME],
	SQL_DATA[MAX_NAME],

	MAX_SLABY_PUNKT,
	MAX_SPRYT,
	MAX_WYTRZYMALOSC,
	MAX_KEVLAR,
	MAX_ADIDASY,

	COST_SLABY_PUNKT,
	COST_SPRYT,
	COST_WYTRZYMALOSC,
	COST_KEVLAR,
	COST_ADIDASY
};

enum _:PLAYER_INFO (+= 1)
{
	PLAYER_NAME[MAX_NAME],
	PLAYER_AUTH[MAX_AUTHID]
}

new Handle:sql;
new Handle:connection;
new bool:sql_connected;
new data_loaded;

new player_data[MAX_PLAYERS + 1][PLAYER_INFO];

new player_skill[MAX_PLAYERS + 1][PLAYER_SKILL];
new skills_cvars[CVARS];

public plugin_init()
{
	register_plugin(NAME, VERSION, AUTHOR, URL_AUTHOR);

	register_commands(menu_commands, sizeof(menu_commands), "main_menu", ADMIN_USER);

	_register_cvars();

	RegisterHam(Ham_TakeDamage, "player", "take_damage", 0);
	RegisterHam(Ham_Spawn, "player", "respawn_player", 1);
}

public plugin_cfg()
{
	new file_path[MAX_PATH];
	get_configsdir(file_path, charsmax(file_path));
	add(file_path, charsmax(file_path), SKILL_CONFIG);

	#if defined DEBUG_MODE
		log_amx("Config path: %s", file_path);
	#endif

	if(!file_exists(file_path))
		set_fail_state(fmt("Nie znaleziono pliku %s (full path: %s)", SKILL_CONFIG, file_path));

	server_cmd("exec %s", file_path);
	_register_sql();
}

public client_putinserver(index)
{
	if(is_user_hltv(index))
		return;

	get_user_name(index, player_data[index][PLAYER_NAME], charsmax(player_data[][PLAYER_NAME]));
	mysql_escape_string(player_data[index][PLAYER_NAME], player_data[index][PLAYER_NAME], charsmax(player_data[][PLAYER_NAME]));

	get_user_authid(index, player_data[index][PLAYER_AUTH], charsmax(player_data[][PLAYER_AUTH]));

	set_task(1.0, "load_data", index);
}

public client_disconnected(index)
{
	if(is_user_hltv(index))
		return;

	save_data(index, 0);
}

public _register_sql()
{
	new error[128];
	new error_num;

	get_cvar_string("amxx4u_skills_host", skills_cvars[SQL_HOST], charsmax(skills_cvars[SQL_HOST]));
	get_cvar_string("amxx4u_skills_user", skills_cvars[SQL_USER], charsmax(skills_cvars[SQL_USER]));
	get_cvar_string("amxx4u_skills_pass", skills_cvars[SQL_PASS], charsmax(skills_cvars[SQL_PASS]));
	get_cvar_string("amxx4u_skills_data", skills_cvars[SQL_DATA], charsmax(skills_cvars[SQL_DATA]));

	sql         = SQL_MakeDbTuple(skills_cvars[SQL_HOST], skills_cvars[SQL_USER], skills_cvars[SQL_PASS], skills_cvars[SQL_DATA]);
	connection  = SQL_Connect(sql, error_num, error, charsmax(error));

	#if defined DEBUG_MODE
		log_amx("Database: %s %s %s %s", skills_cvars[SQL_HOST], skills_cvars[SQL_USER], skills_cvars[SQL_PASS], skills_cvars[SQL_DATA]);
	#endif

	if(error_num)
	{
		log_amx("MySQL ERROR: Query [%d] %s", error_num, error);
		sql = Empty_Handle;

		set_task(1.0, "_register_sql");
		return;
	}

	new query_data[MAX_DESC];
	formatex(query_data, charsmax(query_data), "\
		CREATE TABLE IF NOT EXISTS `amxx4u_skills` (\
		`id` INT(11) NOT NULL AUTO_INCREMENT,\
		`player_name` VARCHAR(64) NOT NULL,\
		`player_auth` VARCHAR(64) NOT NULL DEFAULT 0,\
		`skills_slabypunkt` INT(11) NOT NULL DEFAULT 0,\
		`skills_spryt` INT(11) NOT NULL DEFAULT 0,\
		`skills_wytrzymalosc` INT(11) NOT NULL DEFAULT 0,\
		`skills_kevlar` INT(11) NOT NULL DEFAULT 0,\
		`skills_adidasy` INT(11) NOT NULL DEFAULT 0,\
		PRIMARY KEY(`id`));");

	new Handle:query = SQL_PrepareQuery(connection, query_data);

	SQL_Execute(query);
	SQL_FreeHandle(query);

	sql_connected = true;
}

public save_data(index, end)
{
	if(!get_bit(index, data_loaded))
		return;

	new query_data[MAX_DESC];
	formatex(query_data, charsmax(query_data), "\
		UPDATE `amxx4u_skills` SET\
		`player_auth` = ^"%s^",\
		`skills_slabypunkt` = '%i',\
		`skills_spryt` = '%i',\
		`skills_wytrzymalosc` = '%i',\
		`skills_kevlar` = '%i',\
		`skills_adidasy` = '%i'\
		WHERE `player_name` = ^"%s^";",
		player_data[index][PLAYER_AUTH],
		player_skill[index][SLABY_PUNKT],
		player_skill[index][SPRYT],
		player_skill[index][WYTRZYMALOSC],
		player_skill[index][KEVLAR],
		player_skill[index][ADIDASY],
		player_data[index][PLAYER_NAME]);

	switch(end)
	{
		case 0: SQL_ThreadQuery(sql, "ignore_handle", query_data);
		case 1:
		{
			new error[128];
			new error_num;
			new Handle:query;

			query = SQL_PrepareQuery(connection, query_data);

			if(!SQL_Execute(query))
			{
				error_num = SQL_QueryError(query, error, charsmax(error));
				log_amx("MySQL ERROR: Non-threaded query failed. [%d] %s", error_num, error);
			}

			SQL_FreeHandle(query);
			SQL_FreeHandle(connection);
		}
	}

	if(end)
		rem_bit(index, data_loaded);
}

public load_data(index)
{
	if(!sql_connected)
	{
		set_task(1.0, "load_data", index);
		return;
	}

	new temp[1];
	temp[0] = index;

	SQL_ThreadQuery(sql, "load_data_handle", fmt("SELECT * FROM `amxx4u_skills` WHERE `player_name` = ^"%s^"", player_data[index][PLAYER_NAME]), temp, sizeof(temp));
}

public load_data_handle(fail_state, Handle:query, error[], error_num, temp_id[], data_size)
{
	if(fail_state)
	{
		log_amx("MySQL ERROR: %s [%d]", error, error_num);
		return;
	}

	new index = temp_id[0];

	if(SQL_NumRows(query))
	{
		player_skill[index][SLABY_PUNKT]  	= SQL_ReadResult(query, SQL_FieldNameToNum(query, "skills_slabypunkt"));
		player_skill[index][SPRYT]  		= SQL_ReadResult(query, SQL_FieldNameToNum(query, "skills_spryt"));
		player_skill[index][WYTRZYMALOSC]  	= SQL_ReadResult(query, SQL_FieldNameToNum(query, "skills_wytrzymalosc"));
		player_skill[index][KEVLAR]  		= SQL_ReadResult(query, SQL_FieldNameToNum(query, "skills_kevlar"));
		player_skill[index][ADIDASY]  		= SQL_ReadResult(query, SQL_FieldNameToNum(query, "skills_adidasy"));
	}
	else
		SQL_ThreadQuery(sql, "ignore_handle", fmt("INSERT IGNORE INTO `amxx4u_skills` (`player_name`) VALUES (^"%s^");", player_data[index][PLAYER_NAME]));

	set_bit(index, data_loaded);
}

public ignore_handle(fail_state, Handle:query, error[], error_num, data[], data_size)
{
	if(fail_state)
	{
		log_amx("MySQL ERROR: ignore_Handle %s (%d)", error, error_num);
		return;
	}

	return;
}

public main_menu(id)
{
	new points = get_system_points(id);

	new menu = menu_create(fmt("%s Skill System\d |\w Punktow:\y %i\d", menu_title, points), "menu_handle");
	new callback = menu_makecallback("menu_callback");

	new suma_trafien = (skills_cvars[MAX_SLABY_PUNKT] * 2 - player_skill[id][SLABY_PUNKT]);
	new suma_unik 	 = (skills_cvars[MAX_SPRYT] * 2 - player_skill[id][SPRYT]);

	menu_additem(menu, fmt("%s Slaby punkt\y [%i/%i]\d |\w Koszt:\y %i punktow^n\
		^t^t\r[1/%i Szans na traf. krytyczne]",
		menu_prefix, player_skill[id][SLABY_PUNKT], skills_cvars[MAX_SLABY_PUNKT], skills_cvars[COST_SLABY_PUNKT], suma_trafien), .callback = callback);

	menu_additem(menu, fmt("%s Spryt\y [%i/%i]\d |\w Koszt:\y %i punktow^n\
		^t^t\r[1/%i Szans unik traf.]",
		menu_prefix, player_skill[id][SPRYT], skills_cvars[MAX_SPRYT], skills_cvars[COST_SPRYT], suma_unik), .callback = callback);

	menu_additem(menu, fmt("%s Wytrzymalosc\y [%i/%i]\d |\w Koszt:\y %i punktow^n\
		^t^t\r[%i Dodatkowego zdrowia]",
		menu_prefix, player_skill[id][WYTRZYMALOSC], skills_cvars[MAX_WYTRZYMALOSC], skills_cvars[COST_WYTRZYMALOSC], player_skill[id][WYTRZYMALOSC]), .callback = callback);

	menu_additem(menu, fmt("%s Kevlar\y [%i/%i]\d |\w Koszt:\y %i punktow^n\
		^t^t\r[%i Dodatkowych pkt kamizelki]",
		menu_prefix, player_skill[id][KEVLAR], skills_cvars[MAX_KEVLAR], skills_cvars[COST_KEVLAR], player_skill[id][KEVLAR]), .callback = callback);

	menu_additem(menu, fmt("%s Adidasy\y [%i/%i]\d |\w Koszt:\y %i punktow^n\
		^t^t\r[%i Dodatkowej predkosci]",
		menu_prefix, player_skill[id][ADIDASY], skills_cvars[MAX_ADIDASY], skills_cvars[COST_ADIDASY], player_skill[id][ADIDASY]), .callback = callback);

	menu_addblank(menu, .slot = 0);
	menu_additem(menu, "\yZresetuj\w umiejetnosci");

	menu_setprop(menu, MPROP_BACKNAME, fmt("%s Wroc", menu_prefix));
	menu_setprop(menu, MPROP_NEXTNAME, fmt("%s Dalej", menu_prefix));
	menu_setprop(menu, MPROP_EXITNAME, fmt("%s Wyjdz", menu_prefix));

	menu_setprop(menu, MPROP_PERPAGE, 3);
	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public menu_callback(id, menu, item)
{
	new points = get_system_points(id);

	switch(item)
	{
		case 0:
		{
			if(player_skill[id][SLABY_PUNKT] >= skills_cvars[MAX_SLABY_PUNKT] || points < skills_cvars[COST_SLABY_PUNKT])
				return ITEM_DISABLED;
		}
		case 1:
		{
			if(player_skill[id][SPRYT] >= skills_cvars[MAX_SPRYT] || points < skills_cvars[COST_SLABY_PUNKT])
				return ITEM_DISABLED;
		}
		case 2:
		{
			if(player_skill[id][WYTRZYMALOSC] >= skills_cvars[MAX_WYTRZYMALOSC] || points < skills_cvars[COST_SLABY_PUNKT])
				return ITEM_DISABLED;
		}
		case 3:
		{
			if(player_skill[id][KEVLAR] >= skills_cvars[MAX_KEVLAR] || points < skills_cvars[COST_SLABY_PUNKT])
				return ITEM_DISABLED;
		}
		case 4:
		{
			if(player_skill[id][ADIDASY] >= skills_cvars[MAX_ADIDASY] || points < skills_cvars[COST_SLABY_PUNKT])
				return ITEM_DISABLED;
		}
	}

	return ITEM_ENABLED;
}

public menu_handle(id, menu, item)
{
	if(item == MENU_EXIT)
		return PLUGIN_HANDLED;

	menu_destroy(menu);

	switch(item)
	{
		case 0:
		{
			player_skill[id][SLABY_PUNKT] += 1;
			set_system_points(id, get_system_points(id) - skills_cvars[COST_SLABY_PUNKT]);


		}
		case 1:
		{
			player_skill[id][SPRYT] += 1;
			set_system_points(id, get_system_points(id) - skills_cvars[COST_SPRYT]);
		}
		case 2:
		{
			player_skill[id][WYTRZYMALOSC] += 1;
			set_system_points(id, get_system_points(id) - skills_cvars[COST_WYTRZYMALOSC]);
		}
		case 3:
		{
			player_skill[id][KEVLAR] += 1;
			set_system_points(id, get_system_points(id) - skills_cvars[COST_KEVLAR]);
		}
		case 4:
		{
			player_skill[id][ADIDASY] += 1;
			set_system_points(id, get_system_points(id) - skills_cvars[COST_ADIDASY]);
		}
		case 5:
		{
			player_skill[id][SLABY_PUNKT] 	= 0;
			player_skill[id][SPRYT] 		= 0;
			player_skill[id][WYTRZYMALOSC] 	= 0;
			player_skill[id][KEVLAR] 		= 0;
			player_skill[id][ADIDASY] 		= 0;
		}
	}

	save_data(id, 0);
	return PLUGIN_HANDLED;
}

public take_damage(this, idinflictor, idattacker, Float:damage, damagebits)
{
	if(!is_user_alive(this) || !is_user_connected(this) || !is_user_connected(idattacker) || get_user_team(this) == get_user_team(idattacker))
		return HAM_IGNORED;

	if(player_skill[idattacker][SLABY_PUNKT] > 0)
	{
		if(random_num(1, (skills_cvars[MAX_SLABY_PUNKT] * 2) - (player_skill[idattacker][SLABY_PUNKT])) == 1)
		{
			damage *= 1.5;
			set_hudmessage(255, 0, 0, -1.0, 0.7, 2, 6.0, 3.0,  0.1, 1.5);
			show_hudmessage(idattacker, "TRAFIENIE KRYTYCZNE!");
		}
	}

	if(player_skill[this][SPRYT] > 0)
	{
		if(random_num(1, (skills_cvars[MAX_SPRYT] * 2) - (player_skill[this][SPRYT])) == 1)
		{
			damage = 0.0;
			set_hudmessage(255, 0, 0, -1.0, 0.7, 2, 6.0, 3.0,  0.1, 1.5);
			show_hudmessage(this, "UNIK!");
		}
	}

	SetHamParamFloat(4, damage);
	return HAM_IGNORED;
}

public respawn_player(id)
{ 
	remove_task(id + TASK_GIVE_BONUS);
	set_task(3.0, "give_skill_bonus", id + TASK_GIVE_BONUS);	
}

public give_skill_bonus(id)
{
	id -= TASK_GIVE_BONUS;

	if(!is_user_alive(id))
		return HAM_IGNORED;

	if(player_skill[id][WYTRZYMALOSC] > 0) 
		set_user_health(id, get_user_health(id) + player_skill[id][WYTRZYMALOSC]);

	if(player_skill[id][KEVLAR] > 0) 
		set_user_armor(id, get_user_armor(id) + player_skill[id][KEVLAR]);

	if(player_skill[id][ADIDASY] > 0) 
		jail_set_user_speed(id, 250.0 + player_skill[id][ADIDASY]);

	return HAM_IGNORED;
}

_register_cvars()
{
	bind_pcvar_string(create_cvar("amxx4u_skills_host", "localhost",  FCVAR_SPONLY | FCVAR_PROTECTED), skills_cvars[SQL_HOST], charsmax(skills_cvars[SQL_HOST]));
	bind_pcvar_string(create_cvar("amxx4u_skills_user", "user",       FCVAR_SPONLY | FCVAR_PROTECTED), skills_cvars[SQL_USER], charsmax(skills_cvars[SQL_USER]));
	bind_pcvar_string(create_cvar("amxx4u_skills_pass", "pass",       FCVAR_SPONLY | FCVAR_PROTECTED), skills_cvars[SQL_PASS], charsmax(skills_cvars[SQL_PASS]));
	bind_pcvar_string(create_cvar("amxx4u_skills_data", "data",  	  FCVAR_SPONLY | FCVAR_PROTECTED), skills_cvars[SQL_DATA], charsmax(skills_cvars[SQL_DATA]));

	bind_pcvar_num(create_cvar("jb_max_slabypunkt", "10",
		.description = "Maksymalne ulepszenie umiejetnosci Slaby Punkt"), skills_cvars[MAX_SLABY_PUNKT]);

	bind_pcvar_num(create_cvar("jb_max_spryt", "10",
		.description = "Maksymalne ulepszenie umiejetnosci Spryt"), skills_cvars[MAX_SPRYT]);
	
	bind_pcvar_num(create_cvar("jb_max_wytrzymalosc", "10",
		.description = "Maksymalne ulepszenie umiejetnosci Wytrzymalosc"), skills_cvars[MAX_WYTRZYMALOSC]);

	bind_pcvar_num(create_cvar("jb_max_kevlar", "10",
		.description = "Maksymalne ulepszenie umiejetnosci Kevlar"), skills_cvars[MAX_KEVLAR]);

	bind_pcvar_num(create_cvar("jb_max_adidasy", "10",
		.description = "Maksymalne ulepszenie umiejetnosci Adidasy"), skills_cvars[MAX_ADIDASY]);

	bind_pcvar_num(create_cvar("jb_cost_slabypunkt", "2",
		.description = "Koszt ulepszenia umiejetnosci Slaby Punkt"), skills_cvars[COST_SLABY_PUNKT]);

	bind_pcvar_num(create_cvar("jb_cost_spryt", "2",
		.description = "Koszt ulepszenia umiejetnosci Spryt"), skills_cvars[COST_SPRYT]);
	
	bind_pcvar_num(create_cvar("jb_cost_wytrzymalosc", "2",
		.description = "Koszt ulepszenia umiejetnosci Wytrzymalosc"), skills_cvars[COST_WYTRZYMALOSC]);

	bind_pcvar_num(create_cvar("jb_cost_kevlar", "2",
		.description = "Koszt ulepszenia umiejetnosci Kevlar"), skills_cvars[COST_KEVLAR]);

	bind_pcvar_num(create_cvar("jb_cost_adidasy", "2",
		.description = "Koszt ulepszenia umiejetnosci Adidasy"), skills_cvars[COST_ADIDASY]);

	create_cvar("amxx4u_pl", VERSION, FCVAR_SERVER);
}