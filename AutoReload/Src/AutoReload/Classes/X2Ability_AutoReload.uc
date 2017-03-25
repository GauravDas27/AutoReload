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

static function EventListenerReturn AutoReload_AbilityActivatedListener(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	return ELR_NoInterrupt;
}

static function EventListenerReturn RetroReload_AbilityActivatedListener(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	return ELR_NoInterrupt;
}

static function EventListenerReturn RetroReload_TriggerListener(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	return ELR_NoInterrupt;
}

defaultproperties
{
	ReloadTemplateName = "Reload"
	AutoReloadTemplateName = "AutoReload"
	RetroReloadTemplateName = "RetroReload"

	AbilityActivatedEvent = "AbilityActivated"
	RetroReloadTriggerEvent = "RetroReloadTrigger"
}
