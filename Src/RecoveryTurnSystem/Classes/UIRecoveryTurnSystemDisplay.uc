// This is an Unreal Script

class UIRecoveryTurnSystemDisplay extends UIPanel dependson(XComGameState_RecoveryQueue);

var UITacticalHUD TacHUDScreen;
var XComGameState_RecoveryQueue CurrentQueue;
var UIList Container;
var StateObjectReference BlankReference;
var array<StateObjectReference> UnitsInQueue;
var array<StateObjectReference> IconMapping;
var X2Camera_LookAtActor LookAtTargetCam;

function InitRecoveryQueue(UITacticalHUD TacHUDScreen)
{
	local Object ThisObj;
	
	Container = TacHUDScreen.Spawn(class'UIList', TacHUDScreen);
	Container.InitList('RecoveryQueueDisplayList',
					   0, 0, 100, 1000);
	AnchorBottomLeft();
	Container.AnchorBottomLeft();
	Container.SetPosition(0, -1000);
	Container.SetSize(100, 100);
	Container.OnChildMouseEventDelegate = OnChildMouseEventDelegate;
	`log("Anchored Display");
}

function UpdateQueuedUnits(XComGameState_RecoveryQueue Queue)
{
	local XComGameState_Unit Unit;
	local X2VisualizerInterface Visualizer;
	local XComGameState_Player XComPlayerState;
	local UIIcon Icon;
	local ETeam Team;
	local RecoveringUnit Entry;
	local int i, Size, RecoveryTime;
	local bool RenderedTurnIndicator;
	local X2Condition_UnitProperty PlayerFilter;
	local array<X2Condition> PlayerFilters;

	CurrentQueue = Queue;
	PlayerFilter = new class'X2Condition_UnitProperty';
	PlayerFilter.IsPlayerControlled = true;
	PlayerFilters.AddItem(PlayerFilter);

	XComPlayerState = XComGameState_Player(
		`XCOMHISTORY.GetGameStateForObjectID(XGBattle_SP(`BATTLE).GetHumanPlayer().ObjectID)
	);

	// DATA: -----------------------------------------------------------

	// if the currently selected ability requires the list of ability targets be restricted to only the ones that can be affected by the available action, 
	// use that list of targets instead
	UnitsInQueue.Remove(0, UnitsInQueue.Length);
	IconMapping.Remove(0, IconMapping.Length);
	foreach Queue.Queue(Entry)
	{
		UnitsInQueue.AddItem(Entry.UnitRef);
	}

	UnitsInQueue.Sort(SortUnits);
	`log("Rendering Queue, entries: " @UnitsInQueue.Length);
	// VISUALS: -----------------------------------------------------------
	// Now that the array is tidy, we can set the visuals from it.
	Container.ClearItems();
	Size = 25;

	for(i = 0; i < UnitsInQueue.Length; i++)
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitsInQueue[i].ObjectID));
		RecoveryTime = Queue.GetRecoveryTimeForUnitRef(UnitsInQueue[i]);
		if (Unit.IsDead()) continue;
		if (Unit.IsCivilian()) continue; // don't show civilians

		if (!RenderedTurnIndicator && (RecoveryTime <= Queue.TurnTimeRemaining))
		{
			Icon = UIIcon(
				Container.CreateItem(class'UIIcon')
			).InitIcon(, "img:///UILibrary_Common.TargetIcons.target_mission",
				   true, true, 48, eUIState_Warning);
			Icon.LoadIconBG("img:///UILibrary_Common.TargetIcons.target_mission_bg");
			Size += 48;
			RenderedTurnIndicator = true;
			IconMapping.AddItem(BlankReference);
		}

		if (Unit.GetTeam() != eTeam_XCom)
		{
			if (!class'X2TacticalVisibilityHelpers'.static.CanSquadSeeTarget(XComPlayerState.ObjectID, Unit.ObjectID))
			{
				continue;
			}
		}

		Visualizer = X2VisualizerInterface(Unit.GetVisualizer());
		Icon = UIIcon(
			Container.CreateItem(class'UIIcon')
		).InitIcon(, "img:///" $ Visualizer.GetMyHUDIcon(),
				   true, true, 48, Visualizer.GetMyHUDIconColor());
		Icon.LoadIconBG("img:///" $ Visualizer.GetMyHUDIcon() $ "_bg");
		Size += 48;
		IconMapping.AddItem(UnitsInQueue[i]);
	}
	// UIListItemString(Container.CreateItem()).InitListItem("Turn Time Left :" @ Queue.TurnTimeRemaining);
	if (!RenderedTurnIndicator)
	{
		Icon = UIIcon(
			Container.CreateItem(class'UIIcon')
		).InitIcon(, "img:///UILibrary_Common.TargetIcons.target_mission",
				true, true, 48, eUIState_Warning);
		Icon.LoadIconBG("img:///UILibrary_Common.TargetIcons.target_mission_bg");
		Size += 48;
		RenderedTurnIndicator = true;
		IconMapping.AddItem(BlankReference);
	}


	Container.SetSize(100, Size);
	Container.SetPosition(10, -150 - Size);
	Container.Show();
}

function FocusCamera()
{
	local Actor TargetActor;
	local int SelectionIx;
	SelectionIx = Container.SelectedIndex;	

	if(LookAtTargetCam != none)
	{		
		`CAMERASTACK.RemoveCamera(LookAtTargetCam);
		LookAtTargetCam = none;
	}

	if (SelectionIx == INDEX_NONE) return;
	if (IconMapping[SelectionIx].ObjectID == 0) return;
	
	TargetActor = `XCOMHISTORY.GetVisualizer(IconMapping[SelectionIx].ObjectID);
	`log("Looking at TargetActor " @ IconMapping[SelectionIx].ObjectID @ SelectionIx);
	LookAtTargetCam = new class'X2Camera_LookAtActor';
	LookAtTargetCam.ActorToFollow = TargetActor;
	`CAMERASTACK.AddCamera(LookAtTargetCam);
}


simulated function OnChildMouseEventDelegate(UIPanel Control, int cmd)
{
	switch(cmd)
	{
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_OUT:
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OUT:
		ClearCamera();
		break;
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER:
	case class'UIUtilities_Input'.const.FXS_L_MOUSE_DRAG_OVER:
		FocusCamera();
		break;
	}
}

simulated function ClearCamera()
{
	`log("Clearing Camera");

	if(LookAtTargetCam != none)
	{		
		`CAMERASTACK.RemoveCamera(LookAtTargetCam);
		LookAtTargetCam = none;
	}
}

function int SortUnits(StateObjectReference ObjectA, StateObjectReference ObjectB)
{
	local int RecoveryA, RecoveryB;

	RecoveryA = CurrentQueue.GetRecoveryTimeForUnitRef(ObjectA);
	RecoveryB = CurrentQueue.GetRecoveryTimeForUnitRef(ObjectB);

	if( RecoveryA < RecoveryB )
	{
		return -1;
	}

	return 0;
}
