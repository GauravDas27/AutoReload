class X2Ability_AutoReload extends X2Ability config(AutoReload);

`include(ExcludeHelpers.uci)

var const name ReloadTemplateName;
var const name AutoReloadTemplateName;
var const name RetroReloadTemplateName;

var const name AbilityActivatedEvent;
var const name RetroReloadTriggerEvent;

struct ExcludeData
{
	var name Effect;
	var array<name> Abilities;
	var array<name> Weapons;
	var array<name> Ammo;
	var bool PrimaryOnly;
	var array<EAbilityHostility> Hostility;
};

var config array<ETeam> AllowUnitTeams;
var config array<ExcludeData> Excludes;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(AutoReloadAbility());
	Templates.AddItem(RetroReloadAbility());

	return Templates;
}

static function X2AbilityTemplate ModReloadAbility(name TemplateName)
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate Template;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	Template = AbilityTemplateManager.FindAbilityTemplate(default.ReloadTemplateName);

	Template = new(None, string(TemplateName)) class'X2AbilityTemplate' (Template);
	Template.SetTemplateName(TemplateName);

	Template.AbilityShooterConditions.AddItem(new class'X2Condition_FreeReload');

	Template.AbilityTriggers.Length = 0;

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bShowActivation = true;
	Template.bShowPostActivation = false;
	Template.bSkipFireAction = true;
	Template.ActivationSpeech = '';
	Template.DefaultKeyBinding = class'UIUtilities_Input'.const.FXS_INPUT_NONE;

	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

static function X2AbilityTemplate AutoReloadAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_EventListener EventListener;

	Template = ModReloadAbility(default.AutoReloadTemplateName);

	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.EventID = default.AbilityActivatedEvent;
	EventListener.ListenerData.EventFn = AutoReload_AbilityActivatedListener;
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.Filter = eFilter_Unit;
	EventListener.ListenerData.Priority = 10000; // low priority to ensure other listeners run and modify the game state first
	Template.AbilityTriggers.AddItem(EventListener);

	Template.BuildNewGameStateFn = AutoReload_BuildGameState;

	return Template;
}

static function X2AbilityTemplate RetroReloadAbility()
{
	local X2AbilityTemplate Template;
	local X2AbilityTrigger_EventListener EventListener;

	Template = ModReloadAbility(default.RetroReloadTemplateName);

	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.EventID = default.AbilityActivatedEvent;
	EventListener.ListenerData.EventFn = RetroReload_AbilityActivatedListener;
	EventListener.ListenerData.Deferral = ELD_PreStateSubmitted;
	EventListener.ListenerData.Filter = eFilter_Unit;
	Template.AbilityTriggers.AddItem(EventListener);

	EventListener = new class'X2AbilityTrigger_EventListener';
	EventListener.ListenerData.EventID = default.RetroReloadTriggerEvent;
	EventListener.ListenerData.EventFn = RetroReload_TriggerListener;
	EventListener.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListener.ListenerData.Filter = eFilter_Unit;
	Template.AbilityTriggers.AddItem(EventListener);

	Template.BuildNewGameStateFn = RetroReload_BuildGameState;

	return Template;
}

static function XComGameState AutoReload_BuildGameState(XComGameStateContext Context)
{
	local XComGameStateHistory History;
	local XComGameState GameState;
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_Ability AbilityState;
	local XComGameState_Unit UnitState;
	local XComGameState_Item WeaponState;

	History = `XCOMHISTORY;
	GameState = History.CreateNewGameState(true, Context);
	AbilityContext = XComGameStateContext_Ability(Context);
	AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityContext.InputContext.AbilityRef.ObjectID));
	UnitState = XComGameState_Unit(GameState.CreateStateObject(class'XComGameState_Unit', AbilityContext.InputContext.SourceObject.ObjectID));
	WeaponState = XComGameState_Item(GameState.CreateStateObject(class'XComGameState_Item', AbilityState.SourceWeapon.ObjectID));

	AbilityState.GetMyTemplate().ApplyCost(AbilityContext, AbilityState, UnitState, WeaponState, GameState);

	WeaponState.Ammo = WeaponState.GetClipSize();
	GameState.AddStateObject(UnitState);
	GameState.AddStateObject(WeaponState);

	return GameState;
}

static function XComGameState RetroReload_BuildGameState(XComGameStateContext Context)
{
	return `XCOMHISTORY.CreateNewGameState(true, Context);
}

static function RetroReload_ModifyGameState(XComGameState GameState, XComGameStateContext_Ability AbilityContext)
{
	local XComGameState_Ability AbilityState;
	local XComGameState_Unit UnitState;
	local XComGameState_Item WeaponState;

	local XComGameState_Unit NewUnitState;
	local XComGameState_Item NewWeaponState;

	AbilityState = XComGameState_Ability(GetStateObject(AbilityContext.InputContext.AbilityRef.ObjectID));
	UnitState = XComGameState_Unit(GetStateObject(AbilityContext.InputContext.SourceObject.ObjectID, eReturnType_Copy));
	WeaponState = XComGameState_Item(GetStateObject(AbilityState.SourceWeapon.ObjectID, eReturnType_Copy));

	NewUnitState = XComGameState_Unit(GameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
	NewWeaponState = XComGameState_Item(GameState.CreateStateObject(class'XComGameState_Item', WeaponState.ObjectID));

	// unit does not have any action points but other AbilityCosts can still modify the state
	ApplyCost(AbilityContext, AbilityState, NewUnitState, NewWeaponState, GameState);
	PostApplyCost(AbilityContext, AbilityState, NewUnitState, NewWeaponState, GameState);

	NewWeaponState.Ammo = NewWeaponState.GetClipSize() + NewWeaponState.Ammo - WeaponState.Ammo;
	NewWeaponState.Ammo = Clamp(0, NewWeaponState.Ammo, NewWeaponState.GetClipSize());
	GameState.AddStateObject(NewUnitState);
	GameState.AddStateObject(NewWeaponState);

	// send a event to trigger RetroReload and ensure that its visualization is displayed
	`XEVENTMGR.TriggerEvent(default.RetroReloadTriggerEvent, AbilityContext, UnitState, GameState);
}

static function EventListenerReturn AutoReload_AbilityActivatedListener(Object EventData, Object EventSource, XComGameState GameState, name EventID)
{
	local XComGameState_Unit Unit;
	local XComGameState_Ability Ability;
	local XComGameStateContext_Ability Context;

	local XComGameState_Ability ReloadAbility;
	local XComGameState_Item ReloadWeapon;
	local XComGameStateContext_Ability ReloadContext;
	local X2AbilityTemplate ReloadTemplate;

	Unit = XComGameState_Unit(EventSource);
	Ability = XComGameState_Ability(EventData);
	if (!IsEventValid(Unit, Ability, GameState)) return ELR_NoInterrupt;

	Context = XComGameStateContext_Ability(GameState.GetContext());
	if (Context.InterruptionStatus != eInterruptionStatus_Interrupt) return ELR_NoInterrupt; // AutoReload only handles interrupts
	if (Context.ResultContext.InterruptionStep != 0) return ELR_NoInterrupt; // check AutoReload for the first interrupt only

	// fetch latest state objects from history; changes by listeners which modify state objects but do not add them to history will get ignored
	Unit = XComGameState_Unit(GetStateObject(Unit.ObjectID, eReturnType_Copy));
	Ability = XComGameState_Ability(GetStateObject(Ability.ObjectID, eReturnType_Copy));

	if (!IsUnitAllowed(Unit)) return ELR_NoInterrupt;
	if (!IsAbilityAllowed(Ability)) return ELR_NoInterrupt;
	if (!IsAllowedInConfig(Unit, Ability)) return ELR_NoInterrupt;
	if (!Ability.GetMyTemplate().WillEndTurn(Ability, Unit)) return ELR_NoInterrupt;
	if (!Unit.bGotFreeFireAction && IsFreeFireActionPossible(Ability)) return ELR_NoInterrupt;

	ReloadAbility = GetAbility(Unit, default.AutoReloadTemplateName, eReturnType_Copy);
	ReloadWeapon = XComGameState_Item(GetStateObject(ReloadAbility.SourceWeapon.ObjectID, eReturnType_Copy));
	if (ReloadWeapon == None) return ELR_NoInterrupt; // no weapon to AutoReload

	ReloadContext = class'XComGameStateContext_Ability'.static.BuildContextFromAbility(ReloadAbility, Unit.ObjectID);
	ReloadContext.bSkipValidation = true; // validation done manually
	ReloadTemplate = ReloadAbility.GetMyTemplate();

	// validation for X2AbilityTemplate.CanAfford
	if (!CanAfford(ReloadContext, ReloadAbility, Unit)) return ELR_NoInterrupt; // unit cannot AutoReload
	ApplyCost(ReloadContext, ReloadAbility, Unit, ReloadWeapon, GetStateCopy()); // all variables are copies so history will not be affected
	if (!CanAfford(Context, Ability, Unit)) return ELR_NoInterrupt; // not enough action points to trigger AutoReload before ability

	// validation for XComGameState_Ability.CanActivateAbility ignoring costs
	if (ReloadAbility.CanActivateAbility(Unit, , true) != 'AA_Success') return ELR_NoInterrupt;

	// validation for X2AbilityTemplate.CheckTargetConditions
	if (ReloadTemplate.CheckTargetConditions(ReloadAbility, Unit, Unit) != 'AA_Success') return ELR_NoInterrupt;

	`log("AutoReload: AR Triggering: " $ Context.InputContext.AbilityTemplateName);
	`XCOMGAME.GameRuleset.SubmitGameStateContext(ReloadContext);
	return ELR_NoInterrupt;
}

static function EventListenerReturn RetroReload_AbilityActivatedListener(Object EventData, Object EventSource, XComGameState GameState, name EventID)
{
	local XComGameState_Unit Unit;
	local XComGameState_Ability Ability;
	local XComGameStateContext_Ability Context;

	local XComGameState_Ability ReloadAbility;
	local XComGameState_Item ReloadWeapon;
	local XComGameStateContext_Ability ReloadContext;
	local X2AbilityTemplate ReloadTemplate;

	Unit = XComGameState_Unit(EventSource);
	Ability = XComGameState_Ability(EventData);
	if (!IsEventValid(Unit, Ability, GameState)) return ELR_NoInterrupt;

	Context = XComGameStateContext_Ability(GameState.GetContext());
	if (Context.InterruptionStatus == eInterruptionStatus_Interrupt) return ELR_NoInterrupt; // RetroReload only handles non-interrupts
	if (Context.InterruptionStatus == eInterruptionStatus_Resume) return ELR_NoInterrupt; // AutoReload was already checked for the preceding interrupt

	// fetch latest state objects from history; this is the state before ability corresponding to this event was activated
	Unit = XComGameState_Unit(GetStateObject(Unit.ObjectID, eReturnType_Copy));
	Ability = XComGameState_Ability(GetStateObject(Ability.ObjectID, eReturnType_Copy));

	if (!IsUnitAllowed(Unit)) return ELR_NoInterrupt;
	if (!IsAbilityAllowed(Ability)) return ELR_NoInterrupt;
	if (!IsAllowedInConfig(Unit, Ability)) return ELR_NoInterrupt;
	if (!Ability.GetMyTemplate().WillEndTurn(Ability, Unit)) return ELR_NoInterrupt;
	if (!Unit.bGotFreeFireAction && IsFreeFireActionPossible(Ability)) return ELR_NoInterrupt;

	ReloadAbility = GetAbility(Unit, default.RetroReloadTemplateName, eReturnType_Copy);
	ReloadWeapon = XComGameState_Item(GetStateObject(ReloadAbility.SourceWeapon.ObjectID, eReturnType_Copy));
	if (ReloadWeapon == None) return ELR_NoInterrupt; // no weapon to RetroReload

	ReloadContext = class'XComGameStateContext_Ability'.static.BuildContextFromAbility(ReloadAbility, Unit.ObjectID);
	ReloadContext.bSkipValidation = true; // validation done manually
	ReloadTemplate = ReloadAbility.GetMyTemplate();

	// validation alternative for X2AbilityTemplate.CanAfford
	if (!CanAfford(ReloadContext, ReloadAbility, Unit)) return ELR_NoInterrupt; // unit cannot RetroReload
	ApplyCost(ReloadContext, ReloadAbility, Unit, ReloadWeapon, GetStateCopy()); // all variables are copies so history will not be affected
	if (!CanAfford(Context, Ability, Unit)) return ELR_NoInterrupt; // not enough action points to trigger RetroReload before ability

	// validation for XComGameState_Ability.CanActivateAbility ignoring costs
	if (ReloadAbility.CanActivateAbility(Unit, , true) != 'AA_Success') return ELR_NoInterrupt;

	// validation for X2AbilityTemplate.CheckTargetConditions
	if (ReloadTemplate.CheckTargetConditions(ReloadAbility, Unit, Unit) != 'AA_Success') return ELR_NoInterrupt;

	`log("AutoReload: RR Triggering: " $ Context.InputContext.AbilityTemplateName);
	RetroReload_ModifyGameState(GameState, ReloadContext);
	return ELR_NoInterrupt;
}

static function EventListenerReturn RetroReload_TriggerListener(Object EventData, Object EventSource, XComGameState GameState, name EventID)
{
	local XComGameStateContext_Ability Context;

	Context = XComGameStateContext_Ability(EventData);
	if (Context == None) return ELR_NoInterrupt; // bad event
	if (Context.InputContext.AbilityTemplateName != default.RetroReloadTemplateName) return ELR_NoInterrupt; // bad event

	`XCOMGAME.GameRuleset.SubmitGameStateContext(Context);
	return ELR_NoInterrupt;
}

static function bool IsEventValid(XComGameState_Unit Unit, XComGameState_Ability Ability, XComGameState GameState)
{
	local XComGameStateContext_Ability Context;

	if (Unit == None) return false; // bad event
	if (Ability == None) return false; // bad event
	if (GameState == None) return false; // bad event

	Context = XComGameStateContext_Ability(GameState.GetContext());
	if (Context == None) return false; // bad event
	if (Ability.ObjectID != Context.InputContext.AbilityRef.ObjectID) return false; // bad event

	return true;
}

static function bool IsFreeFireActionPossible(XComGameState_Ability Ability)
{
	local XComGameState_Item Weapon;
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local X2WeaponUpgradeTemplate WeaponUpgrade;
	local bool FreeActionPossible;
	local X2AbilityTemplate Template;
	local X2AbilityCost AbilityCost;

	if (!Ability.AllowFreeFireWeaponUpgrade()) return false; // ability cannot trigger a free action

	Weapon = Ability.GetSourceWeapon();
	if (Weapon == None) return false; // ability does not have a weapon and cannot have free fire upgrade

	WeaponUpgrades = Weapon.GetMyWeaponUpgradeTemplates();
	foreach WeaponUpgrades(WeaponUpgrade)
	{
		if (WeaponUpgrade.FreeFireCostFn != None)
		{
			FreeActionPossible = true;
			break;
		}
	}
	if (!FreeActionPossible) return false; // weapon does not have an upgrade which can allow free action

	Template = Ability.GetMyTemplate();
	foreach Template.AbilityCosts(AbilityCost)
	{
		if (AbilityCost.IsA('X2AbilityCost_ActionPoints') || AbilityCost.IsA('X2AbilityCost_ReserveActionPoints'))
		{
			if (!AbilityCost.bFreeCost) return true; // ability action point cost can be negated by a free action
		}
	}

	return false; // ability cannot proc a free action
}

static function bool IsUnitAllowed(XComGameState_Unit Unit)
{
	if (Unit == None) return false; // no unit
	if (default.AllowUnitTeams.Find(Unit.GetTeam()) == INDEX_NONE) return false; // unit team not present in config
	return true;
}

static function bool IsAbilityAllowed(XComGameState_Ability Ability)
{
	local X2AbilityTemplate Template;

	if (Ability == None) return false; // no ability

	Template = Ability.GetMyTemplate();
	if (Template.DataName == default.AutoReloadTemplateName) return false; // prevent AutoReload infinite loops
	if (Template.DataName == default.RetroReloadTemplateName) return false; // prevent RetroReload infinite loops
	return true;
}

static function bool IsAllowedInConfig(XComGameState_Unit Unit, XComGameState_Ability Ability)
{
	local ExcludeData Exclude;
	local bool Present;

	local X2AbilityTemplate Template;
	local XComGameState_Item Weapon;
	local XComGameState_Item Ammo;
	local XComGameState_Item Primary;

	foreach default.Excludes(Exclude)
	{
		Template = Ability.GetMyTemplate();
		Weapon = Ability.GetSourceWeapon();
		Ammo = Ability.GetSourceAmmo();
		Primary = Unit.GetPrimaryWeapon();

		Present = `ExEffect(Exclude.Effect, Unit)
			&& `ExLookup(Template.DataName, Exclude.Abilities)
			&& `ExBaseObj(Weapon, Exclude.Weapons)
			&& `ExBaseObj(Ammo, Exclude.Ammo)
			&& `ExPrimary(Exclude.PrimaryOnly, Weapon, Primary)
			&& `ExLookup(Template.Hostility, Exclude.Hostility)
		;
		if (Present) return false;
	}
	return true;
}

static function bool CanAfford(XComGameStateContext_Ability Context, XComGameState_Ability Ability, XComGameState_Unit Unit)
{
	local X2AbilityTemplate Template;
	local X2AbilityCost AbilityCost;
	local X2AbilityCost_ActionPoints ActionPointCost;

	Template = Ability.GetMyTemplate();
	foreach Template.AbilityCosts(AbilityCost)
	{
		if (AbilityCost.CanAfford(Ability, Unit) != 'AA_Success') return false;

		ActionPointCost = X2AbilityCost_ActionPoints(AbilityCost);
		if (ActionPointCost == None) continue;

		if (ActionPointCost.bMoveCost || X2AbilityTarget_MovingMelee(Template.AbilityTargetStyle) != None)
		{
			if (!CanAffordMove(ActionPointCost, Context, Ability, Unit)) return false;
		}
	}
	return true;
}

// X2AbilityCost_ActionPoints.CanAfford does not take movement distance into account so we use this function
static function bool CanAffordMove(X2AbilityCost_ActionPoints Cost, XComGameStateContext_Ability Context, XComGameState_Ability Ability, XComGameState_Unit Unit)
{
	local int i;
	local int ActionPointsAllowed;
	local int ActionPointCost;
	local PathingInputData MovementPath;

	ActionPointsAllowed = 0;
	for (i = Cost.AllowedTypes.Length - 1; i >= 0; i--)
	{
		ActionPointsAllowed += Unit.NumActionPoints(Cost.AllowedTypes[i]);
	}

	if (Cost.ConsumeAllPoints(Ability, Unit))
	{
		ActionPointCost = Cost.GetPointCost(Ability, Unit); // X2AbilityCost_ActionPoints always returns 1 for moves
	}
	else
	{
		ActionPointCost = 1; // move always costs atleast one action point
	}

	MovementPath = Context.InputContext.MovementPaths[Context.GetMovePathIndex(Unit.ObjectID)];
	ActionPointCost += MovementPath.CostIncreases.Length; // each cost increase element requires an action point
	return ActionPointCost <= ActionPointsAllowed;
}

// X2AbilityTemplate.ApplyCost does a lot of esoteric stuff so we use this function to purely apply AbilityCosts; use only for RetroReload
static function ApplyCost(XComGameStateContext_Ability Context, XComGameState_Ability Ability, XComGameState_Unit Unit, XComGameState_Item Weapon, XComGameState GameState)
{
	local X2AbilityTemplate Template;
	local X2AbilityCost AbilityCost;

	Template = Ability.GetMyTemplate();
	foreach Template.AbilityCosts(AbilityCost)
	{
		AbilityCost.ApplyCost(Context, Ability, Unit, Weapon, GameState);
	}
}

// call after ApplyCost; does stuff you expect X2AbilityTemplate.ApplyCost after processing AbilityCosts; use only for RetroReload
static function PostApplyCost(XComGameStateContext_Ability Context, XComGameState_Ability Ability, XComGameState_Unit Unit, XComGameState_Item Weapon, XComGameState GameState)
{
	local X2AbilityTemplate Template;
	local XComGameState_Unit PrevUnit;
	local StateObjectReference EffectRef;
	local XComGameState_Effect EffectState;
	local X2Effect_Persistent Effect;

	Template = Ability.GetMyTemplate();

	if (Template.AbilityCooldown != None)
	{
		Template.AbilityCooldown.ApplyCooldown(Ability, Unit, Weapon, GameState);
	}
	
	PrevUnit = XComGameState_Unit(GetStateObject(Unit.ObjectID));
	foreach Unit.AffectedByEffects(EffectRef)
	{
		EffectState = XComGameState_Effect(GetStateObject(EffectRef.ObjectID));
		if (EffectState == None) continue;
		Effect = EffectState.GetX2Effect();
		if (Effect.PostAbilityCostPaid(EffectState, Context, Ability, Unit, Weapon, GameState, PrevUnit.ActionPoints, PrevUnit.ReserveActionPoints))
		{
			break;
		}
	}
}

// helper to retrieve a unit's ability state
static function XComGameState_Ability GetAbility(XComGameState_Unit Unit, name AbilityTemplateName, optional EGameStateReturnType ReturnType=eReturnType_Reference)
{
	return XComGameState_Ability(GetStateObject(Unit.FindAbility(AbilityTemplateName).ObjectID, ReturnType));
}

// helper to retrieve the latest state object from history
static function XComGameState_BaseObject GetStateObject(int ObjectID, optional EGameStateReturnType ReturnType=eReturnType_Reference, optional XComGameState_BaseObject DefaultObject = None)
{
	local XComGameState_BaseObject StateObject;

	StateObject = ObjectID == 0 ? None : `XCOMHISTORY.GetGameStateForObjectID(ObjectID, ReturnType);
	return StateObject == None ? DefaultObject : StateObject;
}

// helper to retrieve a copy of a XComGameState which can be modified without affecting the history
static function XComGameState GetStateCopy()
{
	return `XCOMHISTORY.GetGameStateFromHistory(, eReturnType_Copy);
}

defaultproperties
{
	ReloadTemplateName = "Reload"
	AutoReloadTemplateName = "AutoReload"
	RetroReloadTemplateName = "RetroReload"

	AbilityActivatedEvent = "AbilityActivated"
	RetroReloadTriggerEvent = "RetroReloadTrigger"
}
