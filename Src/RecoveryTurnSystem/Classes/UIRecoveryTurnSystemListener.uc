// This is an Unreal Script

class UIRecoveryTurnSystemListener extends UIScreenListener config(RecoveryTurnSystem);

var UITacticalHUD TacHUDScreen;
var UIRecoveryTurnSystemDisplay QueueDisplay;

event OnInit(UIScreen Screen)
{
	local Object ThisObj;

	TacHUDScreen = UITacticalHUD(Screen);
	ThisObj = self;

	QueueDisplay = TacHUDScreen.Spawn(class'UIRecoveryTurnSystemDisplay', TacHUDScreen);
	QueueDisplay.InitRecoveryQueue(TacHUDScreen);

	`XEVENTMGR.RegisterForEvent(ThisObj, 'RecoveryTurnSystemUpdate', OnQueueUpdate, ELD_OnStateSubmitted);
}

private function EventListenerReturn OnQueueUpdate(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	local XComGameState_RecoveryQueue RecoveryQueue;

	RecoveryQueue = XComGameState_RecoveryQueue(EventData);
	QueueDisplay.UpdateQueuedUnits(RecoveryQueue);
	return ELR_NoInterrupt;
}

defaultproperties
{
	ScreenClass = class'UITacticalHUD';
}