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
	
	public static CFakeProp CreateFromPlayer(PHPlayer player, SDKHookCB callback = INVALID_FUNCTION)
	{
		float origin[3], angles[3];
		player.GetAbsOrigin(origin);
		player.GetAbsAngles(angles);
		
		char model[PLATFORM_MAX_PATH];
		player.GetEffectiveModelName(model, sizeof(model));
		
		PropConfig config;
		if (GetConfigByModel(model, config))
		{
			AddVectors(origin, config.offset, origin);

			if (GetVectorLength(config.rotation, true) != 0.0)
				angles = config.rotation;
		}

		CFakeProp prop = CFakeProp(CreateEntityByName(classname));
		if (prop.IsValid())
		{
			prop.KeyValueVector("origin", origin);
			prop.KeyValueVector("angles", angles);
			prop.KeyValueInt("body", player.GetProp(Prop_Send, "m_nBody"));
			prop.KeyValueInt("skin", player.GetEffectiveSkin());
			prop.KeyValueInt("teamnum", GetClientTeam(player));
			prop.KeyValueInt("solid", HasPhysicsModel(model) ? SOLID_VPHYSICS : SOLID_BBOX);
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
			prop.SetProp(Prop_Send, "m_nSequence", player.GetProp(Prop_Send, "m_nSequence"));	// must be AFTER SetModel!

			PSM_SDKHook(prop.index, SDKHook_SetTransmit, FakeProp_SetTransmit);

			if (callback != INVALID_FUNCTION)
				PSM_SDKHook(prop.index, SDKHook_OnTakeDamageAlivePost, callback);
		}

		return prop;
	}
}
