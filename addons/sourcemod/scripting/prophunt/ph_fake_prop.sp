methodmap CFakeProp
{
	public CFakeProp(int entity)
	{
		return view_as<CFakeProp>(entity);
	}

	property int index
	{
		public get()
		{
			return view_as<int>(this);
		}
	}

	public bool IsValid()
	{
		return IsValidEntity(this.index);
	}

	public static CFakeProp CreateFromPlayer(PHPlayer player)
	{
		float origin[3], angles[3];
		GetClientAbsOrigin(player.entindex, origin);
		GetEntPropVector(player.entindex, Prop_Data, "m_angRotation", angles);

		char model[PLATFORM_MAX_PATH];
		player.GetEffectiveModelName(model, sizeof(model));

		PropConfig config;
		if (GetConfigByModel(model, config))
		{
			AddVectors(origin, config.offset, origin);

			if (GetVectorLength(config.rotation, true) != 0.0)
				angles = config.rotation;
		}

		CFakeProp prop = CFakeProp(CreateEntityByName("base_boss"));
		if (prop.IsValid())
		{
			int entity = prop.index;

			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValueVector(entity, "angles", angles);
			DispatchKeyValueInt(entity, "body", GetEntProp(player.entindex, Prop_Send, "m_nBody"));
			DispatchKeyValueInt(entity, "skin", player.GetEffectiveSkin());
			DispatchKeyValueInt(entity, "teamnum", GetClientTeam(player.entindex));
			DispatchKeyValueInt(entity, "solid", HasPhysicsModel(model) ? SOLID_VPHYSICS : SOLID_BBOX);
			DispatchKeyValueInt(entity, "disableshadows", 1);
			DispatchKeyValueFloat(entity, "playbackrate", GetEntPropFloat(player.entindex, Prop_Send, "m_flPlaybackRate"));
			DispatchKeyValueFloat(entity, "cycle", GetEntPropFloat(player.entindex, Prop_Send, "m_flCycle"));
			DispatchKeyValueFloat(entity, "modelscale", GetEntPropFloat(player.entindex, Prop_Send, "m_flModelScale"));
			SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", player.entindex);
			SetEntProp(entity, Prop_Data, "m_bloodColor", DONT_BLEED);
			SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_EVENTS_ONLY);
			SetEntProp(entity, Prop_Data, "m_iMaxHealth", player.GetMaxHealth());
			SetEntProp(entity, Prop_Data, "m_iHealth", player.GetMaxHealth());
			SetEntityFlags(entity, GetEntityFlags(entity) | FL_NOTARGET);
			SetEntityModel(entity, model);
			SetEntProp(entity, Prop_Send, "m_nSequence", GetEntProp(player.entindex, Prop_Send, "m_nSequence"));	// must be AFTER SetModel!

			PSM_SDKHook(entity, SDKHook_SetTransmit, FakeProp_SetTransmit);
		}

		return prop;
	}
}
