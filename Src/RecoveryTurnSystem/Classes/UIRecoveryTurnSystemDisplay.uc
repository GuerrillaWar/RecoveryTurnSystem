// This is an Unreal Script

class UIRecoveryTurnSystemDisplay extends UIPanel dependson(XComGameState_RecoveryQueue) config(RecoveryTurnSystem);

var XComGameState_RecoveryQueue CurrentQueue;
var UIList Container;
var StateObjectReference BlankReference;
var array<StateObjectReference> UnitsInQueue;
var array<StateObjectReference> IconMapping;
var X2Camera_LookAtActor LookAtTargetCam;

var UIText NextUnitText, HoverUnitText;
var UIText WaitMarker, HalfMarker, FullMarker;
var int LastContainerOffset;

var const config bool DisplayHiddenEnemiesInQueue;

function InitRecoveryQueue(UITacticalHUD TacHUDScreen)
{
	Container = TacHUDScreen.Spawn(class'UIList', TacHUDScreen);
	Container.InitList('RecoveryQueueDisplayList',
					   0, 0, 100, 1000);
	AnchorBottomLeft();
	Container.AnchorBottomLeft();
	Container.SetPosition(0, -1000);
	Container.SetSize(100, 100);
	Container.OnChildMouseEventDelegate = OnChildMouseEventDelegate;

	HoverUnitText = TacHUDScreen.Spawn(class'UIText', TacHUDScreen);
	HoverUnitText.InitText(, , true);
	HoverUnitText.AnchorBottomLeft();
	HoverUnitText.SetPosition(68, 0);
	HoverUnitText.SetSize(700, 48);
	HoverUnitText.Hide();

	NextUnitText = TacHUDScreen.Spawn(class'UIText', TacHUDScreen);
	NextUnitText.InitText(, , true);
	NextUnitText.AnchorBottomLeft();
	NextUnitText.SetPosition(68, -150 - 48);
	NextUnitText.SetSize(700, 48);
	NextUnitText.Hide();

	WaitMarker = TacHUDScreen.Spawn(class'UIText', TacHUDScreen);
	WaitMarker.InitText(, , true);
	WaitMarker.SetCenteredText("-       -");
	WaitMarker.AnchorBottomLeft();
	WaitMarker.SetPosition(10, 0);
	WaitMarker.SetSize(48, 16);
	WaitMarker.Hide();

	HalfMarker = TacHUDScreen.Spawn(class'UIText', TacHUDScreen);
	HalfMarker.InitText(, , true);
	HalfMarker.SetCenteredText("--     --");
	HalfMarker.AnchorBottomLeft();
	HalfMarker.SetPosition(10, 0);
	HalfMarker.SetSize(48, 16);
	HalfMarker.Hide();

	FullMarker = TacHUDScreen.Spawn(class'UIText', TacHUDScreen);
	FullMarker.InitText(, , true);
	FullMarker.SetCenteredText("---  ---");
	FullMarker.AnchorBottomLeft();
	FullMarker.SetPosition(10, 0);
	FullMarker.SetSize(48, 16);
	FullMarker.Hide();

	`log("Anchored Display");
}

function UpdateQueuedUnits(XComGameState_RecoveryQueue Queue)
{
	local XComGameState_Unit Unit, CurrentUnit;
	local X2VisualizerInterface Visualizer;
	local XComGameState_Player XComPlayerState;
	local UIIcon Icon;
	local RecoveringUnit Entry;
	local int i, Size, RecoveryTime;
	local string NextUnitName;
	local bool RenderedTurnIndicator;
	local array<int> CurrentCostArray;

	CurrentQueue = Queue;



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
		if (Unit.GetTeam() != eTeam_XCom && Unit.GetTeam() != eTeam_Alien) continue; // don't show units off main teams

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
			if (!class'X2TacticalVisibilityHelpers'.static.CanSquadSeeTarget(XComPlayerState.ObjectID, Unit.ObjectID) && !DisplayHiddenEnemiesInQueue)
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
	
	LastContainerOffset = -150 - Size;
	NextUnitText.SetPosition(68, LastContainerOffset + ((IconMapping.Length - 1) * 48));



	// Recovery Preview Pips
	CurrentUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Queue.CurrentUnit.UnitRef.ObjectID));
	CurrentCostArray = Queue.GetRecoveryCostArrayForUnitState(CurrentUnit);

	for(i = 0; i < IconMapping.Length; i++)
	{
		if (IconMapping[i].ObjectID != 0)
		{
			RecoveryTime = Queue.GetRecoveryTimeForUnitRef(IconMapping[i]);
		}
		else
		{
			RecoveryTime = Queue.TurnTimeRemaining;
		}

		if (CurrentCostArray.Length > 0 && CurrentCostArray[0] > RecoveryTime)
		{
			if (CurrentCostArray.Length == 3) // full marker
			{
				FullMarker.SetPosition(10, LastContainerOffset + (i * 48) - 12);
				FullMarker.Show();
			}
			else if (CurrentCostArray.Length == 2)
			{
				HalfMarker.SetPosition(10, LastContainerOffset + (i * 48) - 12);
				HalfMarker.Show();
			}
			else
			{
				WaitMarker.SetPosition(10, LastContainerOffset + (i * 48) - 12);
				WaitMarker.Show();
			}
			CurrentCostArray.Remove(0, 1);
		}
	}

	if (IconMapping.Length > 0 && IconMapping[IconMapping.Length - 1].ObjectID != 0)
	{
		NextUnitName = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(IconMapping[IconMapping.Length - 1].ObjectID)).GetName(eNameType_Full);
		NextUnitText.SetText("Next:" @ NextUnitName);
		NextUnitText.Show();
	}
	else if (IconMapping[IconMapping.Length - 1].ObjectID == 0)
	{
		NextUnitText.SetText("Next Turn");
		NextUnitText.Show();
	}
	else
	{
		NextUnitText.Hide();
	}


	Container.SetSize(100, Size);
	Container.SetPosition(10, LastContainerOffset);
	Container.Show();
}

function FocusCamera()
{
	local Actor TargetActor;
	local string HoverUnitName;
	local int SelectionIx;
	SelectionIx = Container.SelectedIndex;

	if(LookAtTargetCam != none)
	{		
		`CAMERASTACK.RemoveCamera(LookAtTargetCam);
		LookAtTargetCam = none;
	}

	if (SelectionIx == INDEX_NONE) return;
	
	HoverUnitText.SetPosition(68, LastContainerOffset + (SelectionIx * 48));
	if (SelectionIx == IconMapping.Length - 1)
	{
		HoverUnitText.Hide();
	}
	else if (IconMapping[SelectionIx].ObjectID == 0)
	{
		HoverUnitText.SetText("Next Turn");
		HoverUnitText.Show();
	}
	else
	{
		HoverUnitName = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(IconMapping[SelectionIx].ObjectID)).GetName(eNameType_Full);
		HoverUnitText.SetText(HoverUnitName);
		HoverUnitText.Show();
	}

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
	HoverUnitText.Hide();
	if(LookAtTargetCam != none)
	{		
		`CAMERASTACK.RemoveCamera(LookAtTargetCam);
		LookAtTargetCam = none;
	}
}

function int SortUnits(StateObjectReference ObjectA, StateObjectReference ObjectB)
{
	local int RecoveryA, RecoveryB, IndexA, IndexB;

	RecoveryA = CurrentQueue.GetRecoveryTimeForUnitRef(ObjectA);
	RecoveryB = CurrentQueue.GetRecoveryTimeForUnitRef(ObjectB);
	IndexA = CurrentQueue.GetQueueIndexForUnitRef(ObjectA);
	IndexB = CurrentQueue.GetQueueIndexForUnitRef(ObjectB);

	if(RecoveryA == RecoveryB) // queue position takes over
	{
		if (IndexA < IndexB)
		{
			return -1;
		}

		return 0;
	}

	if( RecoveryA < RecoveryB )
	{
		return -1;
	}

	return 0;
}
