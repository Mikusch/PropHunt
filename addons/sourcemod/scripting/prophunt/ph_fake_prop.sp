static char classname[] = "ph_fake_prop";

static CEntityFactory EntityFactory;

methodmap CFakeProp < CBaseCombatCharacter
{
	public CFakeProp(int entindex)
	{
		return view_as<CFakeProp>(entindex);
	}

	public static void Initialize()
	{
		EntityFactory = new CEntityFactory(classname);
		EntityFactory.DeriveFromClass("base_boss");
		EntityFactory.Install();
	}
	
	public static CFakeProp CreateFromPlayer(PHPlayer player, SDKHookCB callback)
	{
		float origin[3], angles[3];
		player.GetAbsOrigin(origin);
		player.GetAbsAngles(angles);
		
		char model[PLATFORM_MAX_PATH];
		player.GetPropString(Prop_Send, "m_iszCustomModel", model, sizeof(model));
		
		PropConfig config;
		if (GetConfigByModel(model, config))
		{
			AddVectors(origin, config.offset, origin);
			AddVectors(angles, config.rotation, angles);
		}

		CFakeProp prop = CFakeProp(CreateEntityByName(classname));
		if (prop.IsValid())
		{
			prop.KeyValueVector("origin", origin);
			prop.KeyValueVector("angles", angles);
			prop.KeyValueInt("body", player.GetProp(Prop_Send, "m_nBody"));
			prop.KeyValueInt("skin", player.GetEffectiveSkin());
			prop.KeyValueInt("teamnum", GetClientTeam(player));
			prop.KeyValueInt("sequence", player.GetProp(Prop_Send, "m_nSequence"));
			prop.KeyValueInt("solid", SOLID_VPHYSICS);
			prop.KeyValueInt("disableshadows", 1);
			prop.KeyValueFloat("playbackrate",  player.GetPropFloat(Prop_Send, "m_flPlaybackRate"));
			prop.KeyValueFloat("cycle",  player.GetPropFloat(Prop_Send, "m_flCycle"));
			prop.KeyValueFloat("modelscale", player.GetPropFloat(Prop_Send, "m_flModelScale"));
			prop.SetPropEnt(Prop_Send, "m_hOwnerEntity", player);
			prop.SetProp(Prop_Data, "m_bloodColor", DONT_BLEED);
			prop.SetProp(Prop_Data, "m_takedamage", DAMAGE_EVENTS_ONLY);
			prop.SetProp(Prop_Data, "m_iMaxHealth", player.GetMaxHealth());
			prop.SetProp(Prop_Data, "m_iHealth", player.GetMaxHealth());
			prop.AddFlag(FL_NOTARGET);
			prop.SetModel(model);
			
			PSM_SDKHook(prop.index, SDKHook_OnTakeDamageAlivePost, callback);
		}
		
		return prop;
	}
}