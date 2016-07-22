// This is an Unreal Script

class UIRecoveryTurnSystemListener extends UIScreenListener config(RecoveryTurnSystem);

event OnInit(UIScreen Screen)
{
	local Object ThisObj;
	local UITacticalHUD TacHUDScreen;
	local UIRecoveryTurnSystemDisplay QueueDisplay;

	TacHUDScreen = UITacticalHUD(Screen);
	ThisObj = self;

	QueueDisplay = TacHUDScreen.Spawn(class'UIRecoveryTurnSystemDisplay', TacHUDScreen);
	QueueDisplay.InitPanel('UIRecoveryTurnQueue');
	QueueDisplay.InitRecoveryQueue(TacHUDScreen);

	`XEVENTMGR.RegisterForEvent(ThisObj, 'RecoveryTurnSystemUpdate', OnQueueUpdate, ELD_OnStateSubmitted);
}

private function EventListenerReturn OnQueueUpdate(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	local XComGameState_RecoveryQueue RecoveryQueue;
	local UITacticalHUD TacHUDScreen;
	local UIRecoveryTurnSystemDisplay QueueDisplay;

	`log("Listening RQ");
	if(`SCREENSTACK.IsInStack(class'UITacticalHUD'))
	{
		`log("Updating RQ");
		TacHUDScreen = UITacticalHUD(`SCREENSTACK.GetScreen(class'UITacticalHUD'));
		QueueDisplay = UIRecoveryTurnSystemDisplay(TacHUDScreen.GetChild('UIRecoveryTurnQueue'));
		RecoveryQueue = XComGameState_RecoveryQueue(EventData);
		QueueDisplay.UpdateQueuedUnits(RecoveryQueue);
	}
	return ELR_NoInterrupt;
}

event OnRemoved(UIScreen Screen)
{
	local Object ThisObj;
	ThisObj = self;
	`XEVENTMGR.UnRegisterFromAllEvents(ThisObj);
}

defaultproperties
{
	ScreenClass = class'UITacticalHUD';
}