
BASE.Type	= "generic"

BASE.MinPlayers		=  1
BASE.MaxPlayers		= -1

BASE.DefaultRole	= -1
BASE.DieOnLose		= false

BASE.DefaultState	= false

BASE.Windup			= 6


-- Room Accessors
function BASE:GetPoints( group )
	return self.Room:GetPoints( group )
end
function BASE:GetPointCount( group )	
	return self.Room:GetPointCount( group ) 
end

function BASE:GetRandomPoints( num, group )	
	return self.Room:GetRandomPoints( num, group )
end
function BASE:GetRandomFilterBox( num, group, filter, mins, maxs )
	return self.Room:GetRandomFilterBox( num, group, filter, mins, maxs ) 
end

-- Gamemode Accessors
function BASE:Instruction( text, bgColor, fgColor )
	for _, ply in pairs( self:GetPlayers() ) do
		ply:SendPopup( text, bgColor, fgColor )
	end
end

-- Internal API
function BASE:SafeCall( func, ... )
	local succ, err = pcall( func, self, ... )

	if ( !succ ) then MsgN( err ) end
	return succ, err
end

function BASE:Setup()
	local players	= self:GetPlayers()
	local count		= #players

	if ( !self:IsPlayable( count ) ) then return false end
	
	if ( self.Room == "*" ) then
		self.Room = GAMEMODE.CurrRoom
	else
		self.Room = GAMEMODE:FindRoomFor( self.Room, count )
	end
	
	if ( !self.Room ) then return false end		
	
	if ( self.Room != GAMEMODE.CurrRoom ) then		
		local spawns, found = self:GetRandomPoints( count, "spawn" )
		if ( found <= 0 ) then 
			GAMEMODE:Warning( "No spawnpoints in func_wareroom: " .. tostring( self.Room ) )
			return false
		end
		
		if ( found < count ) then
			GAMEMODE:Warning( "func_wareroom provides less spawnpoints than MinPlayers" )
		end
		
		for index = 1, count do
			players[index]:SetPos( spawns[index % found +1] )
		end
	
		GAMEMODE.CurrRoom = self.Room
	end
	
	self.Phase 		= -1
	self.NextPhase	= CurTime() + self.Windup
	self.Trash		= {}
	
	if( !self:SafeCall( self.Initialize ) ) then return false end

	for _, ply in pairs( self:GetPlayers() ) do
		ply:SetRole( self.DefaultRole )
	
		ply:ResetState( self.InitialState )
		ply:RestoreDeath()
	end

	GAMEMODE:ReportWareTimes()
	GAMEMODE:SendStates( self.InitialState, true, self.HideStates )
	
	self.IsPlaying 	= true
	return true
end

function BASE:InternalThink()
	if ( !self.IsPlaying ) then return end
	
	if ( self.NextPhase < CurTime() and !self:ForceNextPhase() ) then 
		return
	end
	
	if ( self.Phase >= 0 and self.Think ) then
		self:SafeCall( self.Think, self.Phase )
	end
end

function BASE:InternalEnd()
	GAMEMODE:UpdatePlayerStates( true )
	
	for _, ply in pairs( self:GetPlayers() ) do
		if ( !ply:IsLocked() or self.HideStates ) then
			GAMEMODE:PlayerStateEffect( ply, ply:GetState() )
		end
	end	
	
	self:SafeCall( self.EndAction )
end

function BASE:Cleanup()
	for _, ply in pairs( self:GetPlayers() ) do
		ply:StripWeapons()
		ply:RestoreDeath()
	end
	
	for _, entry in pairs( self.Trash ) do
		if ( entry and IsValid( entry ) ) then
			entry:GetPos():Effect( "ware_disappear" )
			entry:Remove()
		end
	end
	
	-- TODO: Prop gibs, how to detect them?!
	for _, prop in pairs( ents.FindByClass( "prop_physics" ) ) do
		prop:Remove()
	end
end

-- External API
function BASE:GetPlayers()
	return player.GetAll()
end

function BASE:PlayerRatio( ratio, min, max )
	return math.Clamp( math.ceil( #self:GetPlayers() * ratio ), min, max )
end

function BASE:GetPhase()
	return self.Phase
end

function BASE:SetPhaseTime( sec )
	self.NextPhase = CurTime() + sec
end

function BASE:AddToTrash( entry )
	table.insert( self.Trash, entry )
end

function BASE:ForceNextPhase()
	if ( self.Phase > 1 ) then
		self:SafeCall( self.EndPhase, self.Phase )
	end
	
	local phases = self.Phases
	
	if ( !phases or !phases[ self.Phase +2 ] ) then
		self:InternalEnd()
		
		self.Phase		= nil
		self.IsPlaying 	= false
		
		return false
	else
		self.Phase 		= self.Phase +1
		
		self.NextPhase	= CurTime() + phases[ self.Phase +1 ]
		
		if ( self.Phase == 0 ) then
			self:SafeCall( self.StartAction )
		else
			self:SafeCall( self.StartPhase, self.Phase )
		end
	end
	
	GAMEMODE:ReportWarePhase()
	return true
end

function BASE:ForceEnd()
	if ( self.Phase > 1 ) then
		self:SafeCall( self.EndPhase, self.Phase )
	end

	self:InternalEnd()
	
	self.Phase 		= nil
	self.IsPlaying	= false
end

-- Internal utils
function BASE:GiveAll( weapon )
	for _, ply in pairs( self:GetPlayers() ) do 
		ply:Give( weapon )
	end
end

function BASE:ApplyAll( state, lock )
	for _, ply in pairs( self:GetPlayers() ) do
		ply:ApplyState( state, lock )
	end
end

-- Callbacks
function BASE:IsPlayable( count )
	return self.Initialize != nil
end


function BASE:StartAction()				end
function BASE:EndAction()				end

function BASE:StartPhase( phaseID )		end
function BASE:EndPhase( phaseID )		end