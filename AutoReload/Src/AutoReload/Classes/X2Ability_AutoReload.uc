class X2Ability_AutoReload extends X2Ability;

var const name ReloadTemplateName;
var const name AutoReloadTemplateName;
var const name RetroReloadTemplateName;

var const name AbilityActivatedEvent;
var const name RetroReloadTriggerEvent;

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

	Template.AbilityTriggers.Length = 0;

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bShowActivation = true;
	Template.bSkipFireAction = true;
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
	`log("AutoReload: AR BuildGameState");
	return `XCOMHISTORY.CreateNewGameState(true, Context);
}

static function XComGameState RetroReload_BuildGameState(XComGameStateContext Context)
{
	`log("AutoReload: RR BuildGameState");
	return `XCOMHISTORY.CreateNewGameState(true, Context);
}

static function EventListenerReturn AutoReload_AbilityActivatedListener(Object EventData, Object EventSource, XComGameState GameState, name EventID)
{
	local XComGameState_Unit Unit;
	local XComGameState_Ability Ability;
	local XComGameStateContext_Ability Context;

	local XComGameState_Ability ReloadAbility;
	local XComGameState_Item ReloadWeapon;

	Unit = XComGameState_Unit(EventSource);
	Ability = XComGameState_Ability(EventData);
	if (!IsEventValid(Unit, Ability, GameState)) return ELR_NoInterrupt;

	Context = XComGameStateContext_Ability(GameState.GetContext());
	if (Context.InterruptionStatus != eInterruptionStatus_Interrupt) return ELR_NoInterrupt; // AutoReload only handles interrupts
	if (Context.ResultContext.InterruptionStep != 0) return ELR_NoInterrupt; // check AutoReload for the first interrupt only

	// we should not AutoReload if a free action (hair trigger) procs
	// it is not possible to determine free action proc in an interrupt
	// we simply skip the event; RetroReload will trigger post interrupt
	if (!Unit.bGotFreeFireAction && IsFreeFireActionPossible(Ability)) return ELR_NoInterrupt;

	// fetch latest state objects from history; changes by listeners which modify state objects but do not add them to history will get ignored
	Unit = XComGameState_Unit(GetStateObject(Unit.ObjectID, eReturnType_Copy));
	Ability = XComGameState_Ability(GetStateObject(Ability.ObjectID, eReturnType_Copy));
	if (!IsUnitAllowed(Unit)) return ELR_NoInterrupt;
	if (!IsAbilityAllowed(Ability)) return ELR_NoInterrupt;

	ReloadAbility = GetAbility(Unit, default.AutoReloadTemplateName, eReturnType_Copy);
	if (ReloadAbility == None) return ELR_NoInterrupt; // unit cannot AutoReload
	ReloadWeapon = XComGameState_Item(GetStateObject(ReloadAbility.SourceWeapon.ObjectID, eReturnType_Copy));
	if (IsFreeReloadPresent(ReloadWeapon, ReloadAbility, Unit)) return ELR_NoInterrupt;

	`log("AutoReload: AR Listener: " $ Context.InputContext.AbilityTemplateName);
	return ELR_NoInterrupt;
}

static function EventListenerReturn RetroReload_AbilityActivatedListener(Object EventData, Object EventSource, XComGameState GameState, name EventID)
{
	local XComGameState_Unit Unit;
	local XComGameState_Ability Ability;
	local XComGameStateContext_Ability Context;

	local XComGameState_Ability ReloadAbility;
	local XComGameState_Item ReloadWeapon;

	Unit = XComGameState_Unit(EventSource);
	Ability = XComGameState_Ability(EventData);
	if (!IsEventValid(Unit, Ability, GameState)) return ELR_NoInterrupt;

	Context = XComGameStateContext_Ability(GameState.GetContext());
	if (Context.InterruptionStatus == eInterruptionStatus_Interrupt) return ELR_NoInterrupt; // RetroReload only handles non-interrupts

	// fetch unit state after ability corresponding to this event is applied
	Unit = XComGameState_Unit(GameState.GetGameStateForObjectID(Unit.ObjectID));
	if (Unit != None && Unit.NumAllActionPoints() > 0) return ELR_NoInterrupt;

	// fetch latest state objects from history; this is the state before ability corresponding to this event was activated
	Unit = XComGameState_Unit(GetStateObject(Unit.ObjectID, eReturnType_Copy));
	Ability = XComGameState_Ability(GetStateObject(Ability.ObjectID, eReturnType_Copy));
	if (!IsUnitAllowed(Unit)) return ELR_NoInterrupt;
	if (!IsAbilityAllowed(Ability)) return ELR_NoInterrupt;

	ReloadAbility = GetAbility(Unit, default.RetroReloadTemplateName, eReturnType_Copy);
	if (ReloadAbility == None) return ELR_NoInterrupt; // unit cannot RetroReload
	ReloadWeapon = XComGameState_Item(GetStateObject(ReloadAbility.SourceWeapon.ObjectID, eReturnType_Copy));
	if (IsFreeReloadPresent(ReloadWeapon, ReloadAbility, Unit)) return ELR_NoInterrupt;

	`log("AutoReload: RR Listener: " $ Context.InputContext.AbilityTemplateName);
	return ELR_NoInterrupt;
}

static function EventListenerReturn RetroReload_TriggerListener(Object EventData, Object EventSource, XComGameState GameState, name EventID)
{
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

	Weapon = Ability.GetSourceWeapon();
	if (Weapon == None) return false; // ability does not require a weapon

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
	if (Unit.GetTeam() != eTeam_XCom) return false; // unit team not allowed
	return true;
}

static function bool IsAbilityAllowed(XComGameState_Ability Ability)
{
	if (Ability == None) return false; // no ability
	if (Ability.GetMyTemplateName() == default.AutoReloadTemplateName) return false; // prevent AutoReload infinite loops
	if (Ability.GetMyTemplateName() == default.RetroReloadTemplateName) return false; // prevent RetroReload infinite loops
	return true;
}

static function bool IsFreeReloadPresent(XComGameState_Item Weapon, XComGameState_Ability Ability, XComGameState_Unit Unit)
{
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local X2WeaponUpgradeTemplate WeaponUpgrade;

	if (Weapon == None) return false; // no weapon

	WeaponUpgrades = Weapon.GetMyWeaponUpgradeTemplates();
	foreach WeaponUpgrades(WeaponUpgrade)
	{
		if (WeaponUpgrade.FreeReloadCostFn == None) continue;
		if (WeaponUpgrade.FreeReloadCostFn(WeaponUpgrade, Ability, Unit)) return true;
	}

	return false;
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

defaultproperties
{
	ReloadTemplateName = "Reload"
	AutoReloadTemplateName = "AutoReload"
	RetroReloadTemplateName = "RetroReload"

	AbilityActivatedEvent = "AbilityActivated"
	RetroReloadTriggerEvent = "RetroReloadTrigger"
}
