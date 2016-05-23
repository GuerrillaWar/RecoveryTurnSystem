class XComGameState_RecoveryQueue extends XComGameState_BaseObject config(RecoveryTurnSystem);

struct RecoveringUnit
{
	var StateObjectReference UnitRef;
	var int RecoveryTime;
};

var() array<RecoveringUnit> Queue;
var() RecoveringUnit CurrentUnit;
var() array<StateObjectReference> CurrentFollowers;
var() int TurnTimeRemaining;
var const config int RecoveryCeiling;
var const config int RecoveryMaxClamp;
var const config int RecoveryMinClamp;
var const config int RecoveryWait;
var const config int TurnLength;
var const config int RecoveryBaseShuffle;
var() int TurnCycler;
var() bool TurnCycleEnd;

function InitTurnTime ()
{
	TurnTimeRemaining = RecoveryBaseShuffle + TurnLength;
}

function AddUnitToQueue(XComGameState_Unit UnitState, optional bool addedMidMission = false)
{
	local RecoveringUnit QueueEntry;

	if (!addedMidMission)
	{
		QueueEntry.RecoveryTime = Rand(RecoveryBaseShuffle) + Clamp(
			RecoveryCeiling - Round(UnitState.GetCurrentStat(eStat_Mobility)),
			RecoveryMinClamp, RecoveryMaxClamp
		);
	}
	else
	{	
		QueueEntry.RecoveryTime = Clamp(
			RecoveryCeiling - Round(UnitState.GetCurrentStat(eStat_Mobility)),
			RecoveryMinClamp, RecoveryMaxClamp
		);
	}
	QueueEntry.UnitRef = UnitState.GetReference();

	Queue.AddItem(QueueEntry);
}

function array<int> GetRecoveryCostArrayForUnitState(XComGameState_Unit UnitState)
{
	local int DefaultRecovery;
	local array<int> CostArray;

	DefaultRecovery = Clamp(
		RecoveryCeiling - Round(UnitState.GetCurrentStat(eStat_Mobility)),
		RecoveryMinClamp, RecoveryMaxClamp
	);

	CostArray.AddItem(DefaultRecovery);
	CostArray.AddItem(Round(DefaultRecovery / 2));
	CostArray.AddItem(RecoveryWait);



	return CostArray;
}

function int GetRecoveryCostForUnitState(XComGameState_Unit UnitState)
{
	local int RecoveryCost, DefaultRecovery, RemainingPoints;

	DefaultRecovery = Clamp(
		RecoveryCeiling - Round(UnitState.GetCurrentStat(eStat_Mobility)),
		RecoveryMinClamp, RecoveryMaxClamp
	);

	RemainingPoints = UnitState.NumActionPoints();

	if(RemainingPoints < 1)       // full move, apply full recovery cost
	{
		RecoveryCost = DefaultRecovery;
	}
	else if(RemainingPoints == 1)  // half move, apply half recovery cost
	{
		RecoveryCost = Round(DefaultRecovery / 2);
	}
	else                           // no move, apply wait time only
	{
		RecoveryCost = RecoveryWait;
	}

	return RecoveryCost;
}

function ReturnFollowerUnitToQueue(XComGameState_Unit UnitState)
{
	local RecoveringUnit Entry;
	local StateObjectReference UnitRef;
	local int FollowerIndex, ix, QueueIndex, RecoveryCost;

	RecoveryCost = GetRecoveryCostForUnitState(UnitState);

	foreach CurrentFollowers(UnitRef, ix)
	{
		if (UnitRef.ObjectID == UnitState.ObjectID)
		{
			FollowerIndex = ix;
			break;
		}
	}

	CurrentFollowers.Remove(FollowerIndex, 1);

	foreach Queue(Entry, ix)
	{
		if (Entry.UnitRef.ObjectID == UnitState.ObjectID)
		{
			QueueIndex = ix;
			break;
		}
	}

	Queue[QueueIndex].RecoveryTime += RecoveryCost; // Stacking the cost rather than resetting.
}

function ReturnUnitToQueue(XComGameState_Unit UnitState)
{
	local RecoveringUnit QueueEntry, BlankRecovery;
	local int RecoveryCost;

	RecoveryCost = GetRecoveryCostForUnitState(UnitState);
	`log("Returning Unit to Queue with Recovery: " @RecoveryCost);

	CurrentUnit = BlankRecovery;
	QueueEntry.RecoveryTime = RecoveryCost;
	QueueEntry.UnitRef = UnitState.GetReference();

	Queue.AddItem(QueueEntry);
}

function StateObjectReference GetCurrentUnitReference()
{
	return CurrentUnit.UnitRef;
}

function AddFollower(XComGameState_Unit Follower)
{
	CurrentFollowers.AddItem(Follower.GetReference());
}

function array<StateObjectReference> GetCurrentFollowerReferences()
{
	return CurrentFollowers;
}

function bool TurnEnded()
{
	local RecoveringUnit Entry;
	local int MinRecoveryTimeLeft, ix;

	MinRecoveryTimeLeft = 100000;

	foreach Queue(Entry, ix)
	{
		if (Entry.RecoveryTime < MinRecoveryTimeLeft)
		{
			MinRecoveryTimeLeft = Entry.RecoveryTime;
		}
	}

	if (TurnTimeRemaining <= MinRecoveryTimeLeft)
	{
		foreach Queue(Entry, ix)
		{
			Queue[ix].RecoveryTime = Entry.RecoveryTime - TurnTimeRemaining;
		}
		TurnTimeRemaining = TurnLength;
		return true;
	}
	else
	{
		return false;
	}
}

function int GetRecoveryTimeForUnitRef(StateObjectReference UnitRef)
{
	local RecoveringUnit Entry;
	foreach Queue(Entry)
	{
		if (Entry.UnitRef.ObjectID == UnitRef.ObjectID)
		{
			return Entry.RecoveryTime;
		}
	}

	if (CurrentUnit.UnitRef.ObjectID == UnitRef.ObjectID)
	{
		return -1;
	}
	else
	{
		return 1000;
	}
}

function int GetQueueIndexForUnitRef(StateObjectReference UnitRef)
{
	local RecoveringUnit Entry;
	local int ix;

	foreach Queue(Entry, ix)
	{
		if (Entry.UnitRef.ObjectID == UnitRef.ObjectID)
		{
			return ix;
		}
	}

	if (CurrentUnit.UnitRef.ObjectID == UnitRef.ObjectID)
	{
		return -1;
	}
	else
	{
		return 1000;
	}
}


function bool CheckUnitInQueue(StateObjectReference UnitRef)
{
	local RecoveringUnit Entry;
	foreach Queue(Entry)
	{
		if (Entry.UnitRef.ObjectID == UnitRef.ObjectID)
		{
			return true;
		}
	}

	if (CurrentUnit.UnitRef.ObjectID == UnitRef.ObjectID)
	{
		return true;
	}
	else
	{
		return false;
	}
}

function StateObjectReference PopNextUnitReference()
{
	local RecoveringUnit Entry;
	local RecoveringUnit FoundEntry;
	local int ix;

	while (FoundEntry.UnitRef.ObjectID == 0)
	{
		foreach Queue(Entry, ix)
		{
			if (Entry.RecoveryTime <= 0)
			{
				Queue.RemoveItem(Entry);
				FoundEntry = Entry;
				break;
			}
			else
			{
				Queue[ix].RecoveryTime = Entry.RecoveryTime - 1;
			}
		}
		TurnTimeRemaining = TurnTimeRemaining - 1;
	}
	CurrentUnit = FoundEntry;

	return FoundEntry.UnitRef;
}

defaultproperties
{
	TurnCycler = -1
}