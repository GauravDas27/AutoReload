class X2Ability_AutoReload extends X2Ability;

var const name ReloadTemplateName;
var const name AutoReloadTemplateName;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(AutoReloadAbility());

	return Templates;
}

static function X2AbilityTemplate AutoReloadAbility()
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate ReloadTemplate;
	local X2AbilityTemplate Template;

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	ReloadTemplate = AbilityTemplateManager.FindAbilityTemplate(default.ReloadTemplateName);

	Template = new(None, string(default.AutoReloadTemplateName)) class'X2AbilityTemplate' (ReloadTemplate);
	Template.SetTemplateName(default.AutoReloadTemplateName);

	Template.DefaultKeyBinding = class'UIUtilities_Input'.const.FXS_INPUT_NONE;
	Template.AbilityCosts.Length = 0;
	Template.AbilityTriggers.Length = 0;

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bShowActivation = true;
	Template.bSkipFireAction = true;

	Template.BuildNewGameStateFn = AutoReloadAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	return Template;
}

static function XComGameState AutoReloadAbility_BuildGameState(XComGameStateContext Context)
{
	`log("AutoReload: BuildGameState");
	return `XCOMHISTORY.CreateNewGameState(true, Context);
}

defaultproperties
{
	ReloadTemplateName = "Reload"
	AutoReloadTemplateName = "AutoReload"
}
