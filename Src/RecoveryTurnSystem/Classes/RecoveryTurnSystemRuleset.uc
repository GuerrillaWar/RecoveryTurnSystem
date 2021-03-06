//-----------------------------------------------------------
//
//-----------------------------------------------------------
class RecoveryTurnSystemRuleset extends X2TacticalGameRuleset config(RecoveryTurnSystem);

var() bool bSkipRemainingTurnActivity; // we need our own because the base class protected it
var() ETeam LastActiveTeam;

var const config array<name> EffectsTickOnUnitTurn;

function OnNewGameState(XComGameState NewGameState)
{
	local XComGameStateContext_TacticalGameRule TacticalContext;

	super.OnNewGameState(NewGameState);

	TacticalContext = XComGameStateContext_TacticalGameRule( NewGameState.GetContext() );

	if (IsInState( 'TurnPhase_UnitActions' ) && (TacticalContext != none) && (TacticalContext.GameRuleType == eGameRule_SkipTurn))
	{
		bSkipRemainingTurnActivity = true;
	}
}

simulated state CreateTacticalGame
{
	simulated function SetupUnits()
	{
		local XComGameState StartState;
		local int StartStateIndex;

		StartState = CachedHistory.GetStartState();
		if (StartState == none)
		{
			StartStateIndex = CachedHistory.FindStartStateIndex();
		
			StartState = CachedHistory.GetGameStateFromHistory(StartStateIndex);

			`assert(StartState != none);

		}

		// only spawn AIs in SinglePlayer...
		if (`XENGINE.IsSinglePlayerGame())
			StartStateSpawnAliens(StartState);

		// Spawn additional units ( such as cosmetic units like the Gremlin )
		StartStateSpawnCosmeticUnits(StartState);

		//Add new game oject states to the start state.
		//*************************************************************************	
		StartStateCreateXpManager(StartState);
		StartStateInitializeUnitAbilities(StartState);      //Examine each unit's start state, and add ability state objects as needed
		StartStateInitializeSquads(StartState);
		StartStateRecoveryQueue(StartState);
		//*************************************************************************
	}
}

simulated function StartStateRecoveryQueue(XComGameState StartState)
{
	local XComGameState_Unit UnitState;
	local bool PartOfTeam;
	local XComGameState_RecoveryQueue QueueState;		
		
	QueueState = XComGameState_RecoveryQueue(StartState.CreateStateObject(class'XComGameState_RecoveryQueue'));
	StartState.AddStateObject(QueueState);
	QueueState.InitTurnTime();

	foreach StartState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		PartOfTeam = UnitState.GetTeam() == eTeam_XCom || UnitState.GetTeam() == eTeam_Alien;

		if (!UnitState.GetMyTemplate().bIsCosmetic && PartOfTeam) {
			`log("Adding to queue: " @UnitState.ObjectID);
			QueueState.AddUnitToQueue(UnitState);
		}
	}
}

simulated state TurnPhase_UnitActions
{
	simulated function bool NextPlayer()
	{
		EndRecoveryUnitControl();

		if(HasTacticalGameEnded())
		{
			// if the tactical game has already completed, then we need to bail before
			// initializing the next player, as we do not want any more actions to be taken.
			return false;
		}
		UnitActionPlayerIndex = 0;

		return BeginPlayerTurn();
	}

	simulated function UpdateAbilityCooldowns(XComGameState NewPhaseState)
	{
		local XComGameState_Ability AbilityState, NewAbilityState;
		local XComGameState_Player  PlayerState, NewPlayerState;
		local XComGameState_Unit UnitState, NewUnitState;
		local bool TickCooldown;

		if (!bLoadingSavedGame)
		{
			foreach CachedHistory.IterateByClassType(class'XComGameState_Ability', AbilityState)
			{
				// some units tick their cooldowns per action instead of per turn, skip them.
				UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(AbilityState.OwnerStateObject.ObjectID));
				`assert(UnitState != none);
				TickCooldown = AbilityState.iCooldown > 0 && !UnitState.GetMyTemplate().bManualCooldownTick;

				if( TickCooldown || AbilityState.TurnsUntilAbilityExpires > 0 )
				{
					NewAbilityState = XComGameState_Ability(NewPhaseState.CreateStateObject(class'XComGameState_Ability', AbilityState.ObjectID));//Create a new state object on NewPhaseState for AbilityState
					NewPhaseState.AddStateObject(NewAbilityState);

					if( TickCooldown )
					{
						NewAbilityState.iCooldown--;
					}

					if( NewAbilityState.TurnsUntilAbilityExpires > 0 )
					{
						NewAbilityState.TurnsUntilAbilityExpires--;
						if( NewAbilityState.TurnsUntilAbilityExpires == 0 )
						{
							NewUnitState = XComGameState_Unit(NewPhaseState.CreateStateObject(class'XComGameState_Unit', NewAbilityState.OwnerStateObject.ObjectID));
							NewPhaseState.AddStateObject(NewUnitState);
							NewUnitState.Abilities.RemoveItem(NewAbilityState.GetReference());
						}
					}
				}
			}

			foreach CachedHistory.IterateByClassType(class'XComGameState_Player', PlayerState)
			{
				if (PlayerState.HasCooldownAbilities() || PlayerState.SquadCohesion > 0)
				{
					NewPlayerState = XComGameState_Player(NewPhaseState.CreateStateObject(class'XComGameState_Player', PlayerState.ObjectID));
					NewPlayerState.UpdateCooldownAbilities();
					if (PlayerState.SquadCohesion > 0)
						NewPlayerState.TurnsSinceCohesion++;
					NewPhaseState.AddStateObject(NewPlayerState);
				}
			}
		}
	}

	simulated function EndRecoveryUnitControl()
	{
		local XComGameStateContext_TacticalGameRule Context;
		local XComGameState_Player PlayerState;
		local X2EventManager EventManager;
		local XComGameState_ChallengeData ChallengeData;
		local XComGameState_TimerData TimerState;
		local XComGameState_RecoveryQueue RecoveryQueue;
		local XComGameState NewGameState;
		local StateObjectReference PlayerRef;
		local XComGameState_BattleData BattleData;
		local int PlayerIndex;

		BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
		EventManager = `XEVENTMGR;
		if( UnitActionPlayerIndex > -1 )
		{
			`log("Team Section");
			//Notify the player state's visualizer that they are no longer the unit action player
			PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(CachedUnitActionPlayerRef.ObjectID));
			`assert(PlayerState != none);
			XGPlayer(PlayerState.GetVisualizer()).OnUnitActionPhaseFinished_NextPlayer();

			//Don't process turn begin/end events if we are loading from a save
			if( !bLoadingSavedGame )
			{
				// build a gamestate to mark this end of this players turn
			}

			RecoveryQueue = XComGameState_RecoveryQueue(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_RecoveryQueue'));
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Roll Turn Timer");
			`log("Creating State Object Recovery Queue");
			RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
			NewGameState.AddStateObject(RecoveryQueue);

			if (RecoveryQueue.TurnEnded())
			{
				UpdateAbilityCooldowns(NewGameState);
				SubmitGameState(NewGameState);
				
				for(PlayerIndex = 0; PlayerIndex < BattleData.PlayerTurnOrder.Length; ++PlayerIndex)
				{
					PlayerRef = BattleData.PlayerTurnOrder[PlayerIndex];
					PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(PlayerRef.ObjectID));
					//Notify the player state's visualizer that they are now the unit action player
					`assert(PlayerState != none);
					`log("CYCLE TURN EVENTS FOR PLAYER" @ PlayerIndex);
					// fire all turn events because player turns are meaningless here


					// build a gamestate to mark this beginning of this players turn
					if (PlayerIndex != 0)
					{
						CachedUnitActionPlayerRef = PlayerRef;
						EventManager.TriggerEvent( 'PlayerTurnEnded', PlayerState, PlayerState );
						Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnEnd);
						Context.PlayerRef = PlayerRef;				
						SubmitGameStateContext(Context);
						NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Submit Ending State");
						RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
						RecoveryQueue.TurnCycler = PlayerIndex;
						RecoveryQueue.TurnCycleEnd = true;
						NewGameState.AddStateObject(RecoveryQueue);
						SubmitGameState(NewGameState);

						EventManager.TriggerEvent( 'PlayerTurnBegun', PlayerState, PlayerState );
						Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnBegin);
						Context.PlayerRef = PlayerRef;				
						SubmitGameStateContext(Context);
						NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Submit Beginning State");
						RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
						RecoveryQueue.TurnCycler = PlayerIndex;
						RecoveryQueue.TurnCycleEnd = false;
						NewGameState.AddStateObject(RecoveryQueue);
						SubmitGameState(NewGameState);
					}
				}	

				PlayerRef = BattleData.PlayerTurnOrder[0];
				CachedUnitActionPlayerRef = PlayerRef;
				PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(PlayerRef.ObjectID));
				EventManager.TriggerEvent( 'PlayerTurnEnded', PlayerState, PlayerState );
				Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnEnd);
				Context.PlayerRef = PlayerRef;				
				SubmitGameStateContext(Context);
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Submit Ending State");
				RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
				RecoveryQueue.TurnCycler = 0;
				RecoveryQueue.TurnCycleEnd = true;
				NewGameState.AddStateObject(RecoveryQueue);
				SubmitGameState(NewGameState);

				EventManager.TriggerEvent( 'PlayerTurnBegun', PlayerState, PlayerState );
				Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnBegin);
				Context.PlayerRef = PlayerRef;				
				SubmitGameStateContext(Context);
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Submit Beginning State");
				RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
				RecoveryQueue.TurnCycler = 0;
				RecoveryQueue.TurnCycleEnd = false;
				NewGameState.AddStateObject(RecoveryQueue);
				SubmitGameState(NewGameState);
			} 
			else
			{
				SubmitGameState(NewGameState);
			}


			ChallengeData = XComGameState_ChallengeData( CachedHistory.GetSingleGameStateObjectForClass( class'XComGameState_ChallengeData', true ) );
			if ((ChallengeData != none) && !UnitActionPlayerIsAI( ))
			{
				TimerState = XComGameState_TimerData( CachedHistory.GetSingleGameStateObjectForClass( class'XComGameState_TimerData' ) );
				TimerState.bStopTime = true;
			}
		} else {
			// start of mission, mark turn start here and fire turn start events
			`log("START OF MISSION EVENTING");
			RecoveryQueue = XComGameState_RecoveryQueue(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_RecoveryQueue'));
			for(PlayerIndex = 0; PlayerIndex < BattleData.PlayerTurnOrder.Length; ++PlayerIndex)
			{
				PlayerRef = BattleData.PlayerTurnOrder[PlayerIndex];
				CachedUnitActionPlayerRef = PlayerRef;
				PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(PlayerRef.ObjectID));
				//Notify the player state's visualizer that they are now the unit action player
				`assert(PlayerState != none);
				EventManager.TriggerEvent( 'PlayerTurnBegun', PlayerState, PlayerState );

				// build a gamestate to mark this beginning of this players turn (only for human)
				if (PlayerIndex != 0)
				{
					Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnBegin);
					Context.PlayerRef = PlayerRef;				
					SubmitGameStateContext(Context);
					NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Submit Beginning State");
					RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
					RecoveryQueue.TurnCycler = PlayerIndex;
					RecoveryQueue.TurnCycleEnd = false;
					NewGameState.AddStateObject(RecoveryQueue);
					SubmitGameState(NewGameState);
				}
			}

			PlayerRef = BattleData.PlayerTurnOrder[0];
			CachedUnitActionPlayerRef = PlayerRef;
			Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnBegin);
			Context.PlayerRef = PlayerRef;				
			SubmitGameStateContext(Context);
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Submit Beginning State");
			RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
			RecoveryQueue.TurnCycler = 0;
			RecoveryQueue.TurnCycleEnd = false;
			NewGameState.AddStateObject(RecoveryQueue);
			SubmitGameState(NewGameState);
		}
	}

	simulated function XComGameState_RecoveryQueue ScanForNewUnits(XComGameState NewGameState, XComGameState_RecoveryQueue QueueState)
	{
		local XComGameState_Unit UnitState;
		local bool PartOfTeam;
		
		foreach CachedHistory.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			PartOfTeam = UnitState.GetTeam() == eTeam_XCom || UnitState.GetTeam() == eTeam_Alien;

			if (!UnitState.GetMyTemplate().bIsCosmetic && PartOfTeam && !QueueState.CheckUnitInQueue(UnitState.GetReference()))
			{
				`log("Adding to queue: " @UnitState.ObjectID);
				QueueState.AddUnitToQueue(UnitState, true);
			}
		}
		return QueueState;
	}

	simulated function ReturnRecoveringUnitToQueue()
	{
		local XComGameState_RecoveryQueue RecoveryQueue;
		local XComGameState_Unit UnitState;
		local XComGameState NewGameState;
		local StateObjectReference UnitRef;
		local array<StateObjectReference> FollowerRefs;

		RecoveryQueue = XComGameState_RecoveryQueue(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_RecoveryQueue'));
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ReturnUnitToRecoveryQueue");
		RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
		UnitRef = RecoveryQueue.GetCurrentUnitReference();

		if (UnitRef.ObjectID != 0)
		{
			UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitRef.ObjectID));
			RecoveryQueue.ReturnUnitToQueue(UnitState);
		}

		FollowerRefs = RecoveryQueue.GetCurrentFollowerReferences();
		foreach FollowerRefs(UnitRef)
		{	
			UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitRef.ObjectID));
			RecoveryQueue.ReturnFollowerUnitToQueue(UnitState);
		}

		NewGameState.AddStateObject(RecoveryQueue);
		SubmitGameState(NewGameState);
	}

	simulated function bool BeginPlayerTurn()
	{
		local XComGameState_Player PlayerState;
		local XComGameState NewGameState;
		local XGPlayer PlayerStateVisualizer;
		local XComGameState_RecoveryQueue RecoveryQueue;
		local XComGameState_Unit UnitState, NewUnitState, FollowerState;
		local XComGameState_Effect Effect;
		local Object BlankObject;
		local StateObjectReference UnitRef, ControllingPlayer, FollowerRef, EffectRef;
		local X2EventManager EventManager;
		local int FollowerIx;

		EventManager = `XEVENTMGR;

		if( !bLoadingSavedGame )
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SetupUnitActionsForPlayerTurnBegin");


			RecoveryQueue = XComGameState_RecoveryQueue(CachedHistory.GetSingleGameStateObjectForClass(class'XComGameState_RecoveryQueue'));
			`log("Popping Recovery Queue");
			`log("Turn Timer:" @ RecoveryQueue.TurnTimeRemaining);
			RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
			RecoveryQueue = ScanForNewUnits(NewGameState, RecoveryQueue);
			NewGameState.AddStateObject(RecoveryQueue);
			UnitRef = RecoveryQueue.PopNextUnitReference();
			UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitRef.ObjectID));

			while (UnitState.IsDead()) // avoid visualising turn changes towards units that can't do anything
			{
				UnitRef = RecoveryQueue.PopNextUnitReference();
				UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(UnitRef.ObjectID));
			}

			ControllingPlayer = UnitState.ControllingPlayer;
			CachedUnitActionPlayerRef = ControllingPlayer;
			`log("Unit Reference Popped: " @UnitState.GetMyTemplateName());

			NewUnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));

			NewUnitState.SetupActionsForBeginTurn();
			if (NewUnitState.IsGroupLeader() && NewUnitState.GetGroupMembership() != none) {
				if ( XGUnit(NewUnitState.GetVisualizer()).GetAlertLevel(UnitState) != eAL_Red )
				{
					foreach NewUnitState.GetGroupMembership().m_arrMembers(FollowerRef, FollowerIx)
					{
						if (FollowerIx == 0) continue; // this is the leader so ignore
						FollowerState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(FollowerRef.ObjectID));
						FollowerState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', FollowerState.ObjectID));
						RecoveryQueue.AddFollower(FollowerState);
						FollowerState.SetupActionsForBeginTurn();
						NewGameState.AddStateObject(FollowerState);
					}
				}
			}
			// Add the updated unit state object to the new game state
			NewGameState.AddStateObject(NewUnitState);
			EventManager.TriggerEvent('RecoveryTurnSystemUpdate', RecoveryQueue);
			SubmitGameState(NewGameState);

			`log("Ticking Effects");
			foreach NewUnitState.AffectedByEffects(EffectRef)
			{
				Effect = XComGameState_Effect(CachedHistory.GetGameStateForObjectID(EffectRef.ObjectID));
				
				if (default.EffectsTickOnUnitTurn.Find(Effect.GetX2Effect().EffectName) != -1) {
					`log("Ticking Effect:" @ Effect.GetX2Effect().EffectName);
					Effect.OnPlayerTurnTicked(BlankObject, BlankObject, NewGameState, 'PlayerTurnBegun');
				}
			}



			// Moved this down here since SetupUnitActionsForPlayerTurnBegin needs to reset action points before 
			// OnUnitActionPhaseBegun_NextPlayer calls GatherUnitsToMove.
			PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(ControllingPlayer.ObjectID));
			//Notify the player state's visualizer that they are now the unit action player
			`assert(PlayerState != none);
			PlayerStateVisualizer = XGPlayer(PlayerState.GetVisualizer());
			PlayerStateVisualizer.OnUnitActionPhaseBegun_NextPlayer();  // This initializes the AI turn 

			CachedUnitActionPlayerRef = ControllingPlayer;
			
			if (UnitState.GetTeam() != LastActiveTeam)
			{
				if (UnitState.GetTeam() == eTeam_XCom)
				{
					`PRES.UIEndTurn(eTurnOverlay_Local);
				}		
				else
				{
					`PRES.UIEndTurn(eTurnOverlay_Alien);
				}
			}

			LastActiveTeam = UnitState.GetTeam();

			`XTACTICALSOUNDMGR.EvaluateTacticalMusicState();
			return true;
		}

		return false;
	}

	simulated function bool ActionsAvailable()
	{
		local XGPlayer ActivePlayer;
		local XComGameState_Unit UnitState;
		local XComGameState_Player PlayerState;
		local bool bActionsAvailable;

		// Turn was skipped, no more actions
		if (bSkipRemainingTurnActivity)
		{
			ReturnRecoveringUnitToQueue(); // return unit to queue, applying recovery cost
			bSkipRemainingTurnActivity = false;
			return false;
		}

		bActionsAvailable = false;

		ActivePlayer = XGPlayer(CachedHistory.GetVisualizer(CachedUnitActionPlayerRef.ObjectID));

		if (ActivePlayer.m_kPlayerController != none)
		{
			// Check current unit first, to ensure we aren't switching away from a unit that has actions (XComTacticalController::OnVisualizationIdle also switches units)
			UnitState = XComGameState_Unit(CachedHistory.GetGameStateForObjectID(ActivePlayer.m_kPlayerController.ControllingUnit.ObjectID));
			bActionsAvailable = UnitHasActionsAvailable(UnitState);
		}

		if (!bActionsAvailable)
		{
			foreach CachedHistory.IterateByClassType(class'XComGameState_Unit', UnitState)
			{
				bActionsAvailable = UnitHasActionsAvailable(UnitState);

				if (bActionsAvailable)
				{
					break; // once we find an action, no need to keep iterating
				}
			}
		}

		if( bActionsAvailable )
		{
			bWaitingForNewStates = true;	//If there are actions available, indicate that we are waiting for a decision on which one to take

			if( !UnitActionPlayerIsRemote() )
			{				
				PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(UnitState.ControllingPlayer.ObjectID));
				`assert(PlayerState != none);
				XGPlayer(PlayerState.GetVisualizer()).OnUnitActionPhase_ActionsAvailable(UnitState);
			}
		}

		if (!bActionsAvailable)
		{
			ReturnRecoveringUnitToQueue(); // return unit to queue, applying recovery cost
		}

		return bActionsAvailable;
	}

	simulated function EndPlayerTurn()
	{
		local XComGameStateContext_TacticalGameRule Context;
		local XComGameState_Player PlayerState;
		local X2EventManager EventManager;

		EventManager = `XEVENTMGR;
		`log("EndPlayerTurn: " @UnitActionPlayerIndex);
		if( UnitActionPlayerIndex > -1 )
		{
			//Notify the player state's visualizer that they are no longer the unit action player
			PlayerState = XComGameState_Player(CachedHistory.GetGameStateForObjectID(CachedUnitActionPlayerRef.ObjectID));
			`assert(PlayerState != none);
			XGPlayer(PlayerState.GetVisualizer()).OnUnitActionPhaseFinished_NextPlayer();

			//Don't process turn begin/end events if we are loading from a save
			if( !bLoadingSavedGame )
			{
				EventManager.TriggerEvent( 'PlayerTurnEnded', PlayerState, PlayerState );

				// build a gamestate to mark this end of this players turn
				Context = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_PlayerTurnEnd);
				Context.PlayerRef = CachedUnitActionPlayerRef;				
				SubmitGameStateContext(Context);
			}
		}
	}
}

static function CleanupTacticalMission(optional bool bSimCombat = false)
{
	local XComGameState NewGameState;
	local XComGameState_RecoveryQueue RecoveryQueue;

	`log("Cleanup Recovery Queue at Mission End");
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Remove RecoveryQueue");
	RecoveryQueue = XComGameState_RecoveryQueue(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_RecoveryQueue'));
	NewGameState.RemoveStateObject(RecoveryQueue.ObjectID);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	super.CleanupTacticalMission(bSimCombat);
}
