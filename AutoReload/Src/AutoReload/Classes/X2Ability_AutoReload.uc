class X2Ability_AutoReload extends X2Ability;

var const name ReloadTemplateName;
var const name AutoReloadTemplateName;
var const name RetroReloadTemplateName;

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

	Template = ModReloadAbility(default.AutoReloadTemplateName);

	Template.BuildNewGameStateFn = AutoReload_BuildGameState;

	return Template;
}

static function X2AbilityTemplate RetroReloadAbility()
{
	local X2AbilityTemplate Template;

	Template = ModReloadAbility(default.RetroReloadTemplateName);

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

defaultproperties
{
	ReloadTemplateName = "Reload"
	AutoReloadTemplateName = "AutoReload"
	RetroReloadTemplateName = "RetroReload"
}
