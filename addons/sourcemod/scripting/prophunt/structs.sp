enum struct MapConfig
{
	ArrayList prop_whitelist;
	ArrayList prop_blacklist;
	bool hunter_setup_freeze;
	bool open_doors_after_setup;
	int setup_time;
	int round_time;
	char relay_name[64];
	
	void ReadFromKv(KeyValues kv)
	{
		this.hunter_setup_freeze = view_as<bool>(kv.GetNum("hunter_setup_freeze", ph_hunter_setup_freeze.BoolValue));
		this.open_doors_after_setup = view_as<bool>(kv.GetNum("open_doors_after_setup", ph_open_doors_after_setup.BoolValue));
		this.setup_time = kv.GetNum("setup_time", ph_setup_time.IntValue);
		this.round_time = kv.GetNum("round_time", ph_round_time.IntValue);
		
		// TODO: SM 1.11 says hello
		ph_relay_name.GetString(this.relay_name, 256);
		kv.GetString("relay_name", this.relay_name, 256, this.relay_name);
		
		// Prop whitelist (overrides blacklist)
		if (kv.JumpToKey("prop_whitelist"))
		{
			this.prop_whitelist = new ArrayList(PLATFORM_MAX_PATH);
			
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char model[PLATFORM_MAX_PATH];
					kv.GetString(NULL_STRING, model, sizeof(model));
					this.prop_whitelist.PushString(model);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
		kv.GoBack();
		
		// Prop blacklist
		if (kv.JumpToKey("prop_blacklist"))
		{
			this.prop_blacklist = new ArrayList(PLATFORM_MAX_PATH);
			
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char model[PLATFORM_MAX_PATH];
					kv.GetString(NULL_STRING, model, sizeof(model));
					this.prop_blacklist.PushString(model);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	bool HasWhitelist()
	{
		return (this.prop_whitelist && this.prop_whitelist.Length > 0);
	}
	
	bool IsWhitelisted(const char[] model)
	{
		return this.HasWhitelist() && (this.prop_whitelist.FindString(model) != -1);
	}
	
	bool IsBlacklisted(const char[] model)
	{
		return this.HasWhitelist() || (this.prop_blacklist && this.prop_blacklist.Length > 0 && this.prop_blacklist.FindString(model) != -1);
	}
}

MapConfig g_CurrentMapConfig;
