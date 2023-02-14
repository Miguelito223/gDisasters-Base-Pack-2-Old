
if GetConVar( "gdisasters_dnc_enable"):GetInt() == 1 then

local dnc_length		= CreateConVar( "dnc_length", "3600", bit.bor( FCVAR_ARCHIVE, FCVAR_GAMEDLL ), "The duration of one day in seconds." );

local TIME_NOON			= 12;		-- 12:00pm
local TIME_MIDNIGHT		= 0;		-- 12:00am
local TIME_DAWN_START	= 4;		-- 4:00am
local TIME_DAWN_END		= 6.5;		-- 6:30am
local TIME_DUSK_START	= 17;		-- 5:00pm;
local TIME_DUSK_END		= 19.5;		-- 7:30pm;

local STYLE_LOW			= string.byte( 'a' );		-- style for night time
local STYLE_HIGH		= string.byte( 'm' );		-- style for day time

local NIGHT				= 0;
local DAWN				= 1;
local DAY				= 2;
local DUSK				= 3;

local SKYPAINT =
{
	[DAWN] =
	{
		TopColor		= Vector( 0.2, 0.5, 1 ),
		BottomColor		= Vector( 1, 0.71, 0 ),
		FadeBias		= 1,
		HDRScale		= 0.26,
		StarScale		= 0.66,
		StarFade		= 0.0,	-- Do not change!
		DuskScale		= 1,
		DuskIntensity	= 1,
		DuskColor		= Vector( 1, 0.2, 0 ),
		SunColor		= Vector( 0.2, 0.1, 0 ),
		SunSize			= 2,
	},
	[DAY] =
	{
		TopColor		= Vector( 0.2, 0.49, 1 ),
		BottomColor		= Vector( 0.01, 0.96, 1 ),
		FadeBias		= 1,
		HDRScale		= 0.26,
		StarScale		= 0.66,
		StarFade		= 1.5,	-- Do not change!
		DuskScale		= 1,
		DuskIntensity	= 1,
		DuskColor		= Vector( 1, 0.2, 0 ),
		SunColor		= Vector( 0.83, 0.45, 0.11 ),
		SunSize			= 0.34,
	},
	[DUSK] =
	{
		TopColor		= Vector( 0.09, 0.32, 0.32 ),
		BottomColor		= Vector( 1, 0.48, 0 ),
		FadeBias		= 1,
		HDRScale		= 0.36,
		StarScale		= 0.66,
		StarFade		= 0.0,	-- Do not change!
		DuskScale		= 1,
		DuskIntensity	= 5.31,
		DuskColor		= Vector( 1, 0.36, 0 ),
		SunColor		= Vector( 0.83, 0.45, 0.11 ),
		SunSize			= 0.34,
	},
	[NIGHT] =
	{
		TopColor		= Vector( 0.00, 0.00, 0.00 ),
		BottomColor		= Vector( 0.10, 0.05, 0.11 ),
		FadeBias		= 0.27,
		HDRScale		= 0.19,
		StarScale		= 0.66,
		StarFade		= 5.0,	-- Do not change!
		DuskScale		= 0,
		DuskIntensity	= 0,
		DuskColor		= Vector( 1, 0.36, 0 ),
		SunColor		= Vector( 0.83, 0.45, 0.11 ),
		SunSize			= 0.0,
	}
};

local DNC =
{
	m_InitEntities = false,
	m_Time = 0,
	m_LastPeriod = NIGHT,
	m_LastStyle = '.',
	m_Cloudy = false,
	m_Paused = false,

	-- to easily hook functions within our own object instance
	Hook = function( self, name )

		local func = self[name];
		local function Wrapper( ... )
			func( self, ... );
		end

		hook.Add( name, string.format( "DNC.%s", tostring( self ), name ), Wrapper );

	end,

	Initialize = function( self )

		self:Hook( "Think" );

	end,

	InitEntities = function( self )

		self.m_LightEnvironment = ents.FindByClass( "light_environment" )[1];
		self.m_EnvSun = ents.FindByClass( "env_sun" )[1];
		self.m_EnvSkyPaint = ents.FindByClass( "env_skypaint" )[1];
		self.m_RelayDawn = ents.FindByName( "dawn" )[1];
		self.m_RelayDusk = ents.FindByName( "dusk" )[1];
		self.m_RelayCloudy = ents.FindByName( "cloudy" )[1];

		-- put the sun on the horizon initially
		if( IsValid( self.m_EnvSun ) ) then
			self.m_EnvSun:SetKeyValue( "sun_dir", "1 0 0" );
		end

		-- HACK: Fixes prop lighting since the first pattern change fails to update it.
		if( IsValid( self.m_LightEnvironment ) ) then
			self.m_LightEnvironment:Fire( "FadeToPattern", 'a' );
		end

		self.m_InitEntities = true;

	end,

	Think = function( self )

		if( not self.m_InitEntities ) then self:InitEntities(); end

		if( not self.m_Paused ) then
			self.m_Time = self.m_Time + ( 24 / dnc_length:GetInt() ) * FrameTime();
			if( self.m_Time > 24 ) then
				self.m_Time = 0;
			end
		end

		-- since our dawn/dusk periods last several hours find the mid point of them
		local dawnMidPoint = ( TIME_DAWN_END + TIME_DAWN_START ) / 2;
		local duskMidPoint = ( TIME_DUSK_END + TIME_DUSK_START ) / 2;

		-- dawn/dusk/night events
		if( self.m_Time >= TIME_DUSK_END ) then
			if( self.m_LastPeriod ~= NIGHT ) then
				self.m_EnvSun:Fire( "TurnOff", "", 0 );
				
				self.m_LastPeriod = NIGHT;
			end

		elseif( self.m_Time >= duskMidPoint ) then
			if( self.m_LastPeriod ~= DUSK ) then
				if( IsValid( self.m_RelayDusk ) ) then
					self.m_RelayDusk:Fire( "Trigger", "" );
				end

				self.m_Cloudy = math.random() > 0.5;

				-- at dawn select if we should display clouds for night or not (50% chance)
				if( IsValid( self.m_EnvSkyPaint ) ) then
					if( self.m_Cloudy ) then
						self.m_EnvSkyPaint:SetStarTexture( "skybox/clouds" );
					else
						self.m_EnvSkyPaint:SetStarTexture( "skybox/starfield" );
					end
				end

				self.m_LastPeriod = DUSK;
			end

		elseif( self.m_Time >= dawnMidPoint ) then
			if( self.m_LastPeriod ~= DAWN ) then
				if( IsValid( self.m_RelayDawn ) ) then
					self.m_RelayDawn:Fire( "Trigger", "" );
				end

				self.m_Cloudy = math.random() > 0.5;

				-- at dawn select if we should display clouds for day or not (50% chance)
				if( IsValid( self.m_EnvSkyPaint ) ) then
					if( self.m_Cloudy ) then
						self.m_EnvSkyPaint:SetStarTexture( "skybox/clouds" );
						SKYPAINT[DAY].StarFade = 1.5;
					else
						SKYPAINT[DAY].StarFade = 0;
					end
				end

				self.m_LastPeriod = DAWN;
			end

		elseif( self.m_Time >= TIME_DAWN_START ) then
			if( self.m_LastPeriod ~= DAY ) then
				self.m_EnvSun:Fire( "TurnOn", "", 0 );

				self.m_LastPeriod = DAY;
			end

		end

		-- light_environment
		if( IsValid( self.m_LightEnvironment ) ) then
			local frac = 0;

			if( self.m_Time >= dawnMidPoint and self.m_Time < TIME_NOON ) then
				frac = math.EaseInOut( ( self.m_Time - dawnMidPoint ) / ( TIME_NOON - dawnMidPoint ), 0, 1 );
			elseif( self.m_Time >= TIME_NOON and self.m_Time < duskMidPoint ) then
				frac = 1 - math.EaseInOut( ( self.m_Time - TIME_NOON ) / ( duskMidPoint - TIME_NOON ), 1, 0 );
			end

			local style = string.char( math.floor( Lerp( frac, STYLE_LOW, STYLE_HIGH ) + 0.5 ) );

			if( self.m_LastStyle ~= style ) then
				self.m_LightEnvironment:Fire( "FadeToPattern", style );
				self.m_LastStyle = style;
			end
		end

		-- env_sun
		if( IsValid( self.m_EnvSun ) ) then
			if( self.m_Time >= TIME_DAWN_START and self.m_Time <= TIME_DUSK_END ) then
				local frac = 1 - ( ( self.m_Time - TIME_DAWN_START ) / ( TIME_DUSK_END - TIME_DAWN_START ) );
				local angle = Angle( -180 * frac, 15, 0 );

				self.m_EnvSun:SetKeyValue( "sun_dir", tostring( angle:Forward() ) );
			end
		end

		-- env_skypaint
		if( IsValid( self.m_EnvSkyPaint ) ) then
			-- env_skypaint doesn't update fast enough.
			if( IsValid( self.m_EnvSun ) ) then
				self.m_EnvSkyPaint:SetSunNormal( self.m_EnvSun:GetInternalVariable( "m_vDirection" ) );
			end

			local cur = NIGHT;
			local next = NIGHT;
			local frac = 0;

			if( self.m_Time >= TIME_DAWN_START and self.m_Time < dawnMidPoint ) then
				cur = NIGHT;
				next = DAWN;
				frac = math.EaseInOut( ( self.m_Time - TIME_DAWN_START ) / ( dawnMidPoint - TIME_DAWN_START ), 0.5, 0.5 );
			elseif( self.m_Time >= dawnMidPoint and self.m_Time < TIME_DAWN_END ) then
				cur = DAWN;
				next = DAY;
				frac = math.EaseInOut( ( self.m_Time - dawnMidPoint ) / ( TIME_DAWN_END - dawnMidPoint ), 0.5, 0.5 );
			elseif( self.m_Time >= TIME_DUSK_START and self.m_Time < duskMidPoint ) then
				cur = DAY;
				next = DUSK;
				frac = math.EaseInOut( ( self.m_Time - TIME_DUSK_START ) / ( duskMidPoint - TIME_DUSK_START ), 0.5, 0.5 );
			elseif( self.m_Time >= duskMidPoint and self.m_Time < TIME_DUSK_END ) then
				cur = DUSK;
				next = NIGHT;
				frac = math.EaseInOut( ( self.m_Time - duskMidPoint ) / ( TIME_DUSK_END - duskMidPoint ), 0.5, 0.5 );
			elseif( self.m_Time >= TIME_DAWN_END and self.m_Time <= TIME_DUSK_END ) then
				cur = DAY;
				next = DAY;
			end

			self.m_EnvSkyPaint:SetTopColor( LerpVector( frac, SKYPAINT[cur].TopColor, SKYPAINT[next].TopColor ) );
			self.m_EnvSkyPaint:SetBottomColor( LerpVector( frac, SKYPAINT[cur].BottomColor, SKYPAINT[next].BottomColor ) );
			self.m_EnvSkyPaint:SetSunColor( LerpVector( frac, SKYPAINT[cur].SunColor, SKYPAINT[next].SunColor ) );
			self.m_EnvSkyPaint:SetDuskColor( LerpVector( frac, SKYPAINT[cur].DuskColor, SKYPAINT[next].DuskColor ) );
			self.m_EnvSkyPaint:SetFadeBias( Lerp( frac, SKYPAINT[cur].FadeBias, SKYPAINT[next].FadeBias ) );
			self.m_EnvSkyPaint:SetHDRScale( Lerp( frac, SKYPAINT[cur].HDRScale, SKYPAINT[next].HDRScale ) );
			self.m_EnvSkyPaint:SetDuskScale( Lerp( frac, SKYPAINT[cur].DuskScale, SKYPAINT[next].DuskScale ) );
			self.m_EnvSkyPaint:SetDuskIntensity( Lerp( frac, SKYPAINT[cur].DuskIntensity, SKYPAINT[next].DuskIntensity ) );
			self.m_EnvSkyPaint:SetSunSize( Lerp( frac, SKYPAINT[cur].SunSize, SKYPAINT[next].SunSize ) );
			self.m_EnvSkyPaint:SetStarFade( Lerp( frac, SKYPAINT[cur].StarFade, SKYPAINT[next].StarFade ) );
			self.m_EnvSkyPaint:SetStarScale( Lerp( frac, SKYPAINT[cur].StarScale, SKYPAINT[next].StarScale ) );
		end

	end,

	TogglePause = function( self )

		self.m_Paused = not self.m_Paused;

	end,

	SetTime = function( self, time )

		self.m_Time = math.Clamp( time, 0, 24 );

		-- FIXME: we're bypassing the sun code
		if( IsValid( self.m_EnvSun ) ) then
			self.m_EnvSun:SetKeyValue( "sun_dir", "1 0 0" );
		end

		-- FIXME: we're bypassing the dusk/dawn events
		if( IsValid( self.m_EnvSkyPaint ) ) then
			self.m_EnvSkyPaint:SetStarTexture( "skybox/starfield" );
			SKYPAINT[DAY].StarFade = 0;
		end

	end,

	GetTime = function( self )

		return self.m_Time;

	end,
};

DNC:Initialize();

concommand.Add( "dnc_pause", function( pl, cmd, args )

	if( not pl:IsSuperAdmin() ) then return; end
	
	DNC:TogglePause();

	pl:PrintMessage( HUD_PRINTCONSOLE, "DNC is " .. ( DNC.m_Paused and "paused" or "no longer paused" ) );

end );

concommand.Add( "dnc_settime", function( pl, cmd, args )

	if( not pl:IsSuperAdmin() ) then return; end

	DNC:SetTime( tonumber( args[1] or "0" ) );

end );

concommand.Add( "dnc_gettime", function( pl, cmd, args )

	local time = DNC:GetTime();
	local hours = math.floor( time );
	local minutes = ( time - hours ) * 60;

	pl:PrintMessage( HUD_PRINTCONSOLE, string.format( "The current time is %s", string.format( "%02i:%02i", hours, minutes ) ) );

end );

end