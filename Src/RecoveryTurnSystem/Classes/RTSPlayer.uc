// This is an Unreal Script

class RTSPLayer extends XGPlayer;

simulated function bool EndTurn(EPlayerEndTurnType eEndTurnType)
{
	local X2TacticalGameRuleset TacticalRules;
	local XComGameStateContext_TacticalGameRule EndTurnContext;
	if (m_eTeam == eTeam_Alien)
	{
		`LogAIActions("Calling XGPlayer::EndTurn()");
	}

	`LogAI("XGPlayer::EndTurn::"$GetStateName() @m_eTeam@ eEndTurnType);

	// deselect the current unit immediately, to prevent players exploiting a one frame window
	// where they would still be able to activate abilities
	XComTacticalController(GetALocalPlayerController()).Visualizer_ReleaseControl();
	ReturnRecoveringUnitToQueue();

	TacticalRules = `TACTICALRULES;
	if( (eEndTurnType == ePlayerEndTurnType_PlayerInput && (TacticalRules.GetLocalClientPlayerObjectID() == TacticalRules.GetCachedUnitActionPlayerRef().ObjectID || `CHEATMGR != none && `CHEATMGR.bAllowSelectAll)) ||
		eEndTurnType == ePlayerEndTurnType_AI )
	{
		EndTurnContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());
		EndTurnContext.GameRuleType = eGameRule_SkipTurn;
		EndTurnContext.PlayerRef = TacticalRules.GetCachedUnitActionPlayerRef();
		EndTurnContext.SetSendGameState(true);

		`XCOMGAME.GameRuleset.SubmitGameStateContext(EndTurnContext);
		EndTurnContext.SetSendGameState(false);
	}

	return false;
}

simulated function ReturnRecoveringUnitToQueue()
{
	local XComGameState_RecoveryQueue RecoveryQueue;
	local XComGameState_Unit UnitState;
	local XComGameState NewGameState;
	local StateObjectReference UnitRef;

	RecoveryQueue = XComGameState_RecoveryQueue(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_RecoveryQueue'));
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("ReturnUnitToRecoveryQueue");
	RecoveryQueue = XComGameState_RecoveryQueue(NewGameState.CreateStateObject(class'XComGameState_RecoveryQueue', RecoveryQueue.ObjectID));
	UnitRef = RecoveryQueue.GetCurrentUnitReference();

	if (UnitRef.ObjectID != 0)
	{
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		RecoveryQueue.ReturnUnitToQueue(UnitState);
	}

	NewGameState.AddStateObject(RecoveryQueue);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}