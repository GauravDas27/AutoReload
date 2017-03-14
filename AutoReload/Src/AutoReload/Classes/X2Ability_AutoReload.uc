class X2Ability_AutoReload extends X2Ability;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(AutoReloadAbility());

	return Templates;
}

static function X2AbilityTemplate AutoReloadAbility()
{
	local X2AbilityTemplateManager AbilityTemplateMan;
	local X2AbilityTemplate ReloadTemplate;
	local X2AbilityTemplate Template;

	AbilityTemplateMan = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	ReloadTemplate = AbilityTemplateMan.FindAbilityTemplate('Reload');

	Template = new(None, "AutoReload") class'X2AbilityTemplate' (ReloadTemplate);
	Template.SetTemplateName('AutoReload');

	Template.DefaultKeyBinding = class'UIUtilities_Input'.const.FXS_INPUT_NONE;
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
