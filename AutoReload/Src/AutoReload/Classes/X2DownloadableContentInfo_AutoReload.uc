//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_AutoReload.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_AutoReload extends X2DownloadableContentInfo;

static event OnPostTemplatesCreated()
{
	local X2AbilityTemplateManager AbilityTemplateManager;
	local array<X2AbilityTemplate> AbilityTemplates;
	local X2AbilityTemplate AbilityTemplate;

	AbilityTemplateManager = class 'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityTemplateManager.FindAbilityTemplateAllDifficulties(class'X2Ability_AutoReload'.default.ReloadTemplateName, AbilityTemplates);
	foreach AbilityTemplates(AbilityTemplate)
	{
		AbilityTemplate.AdditionalAbilities.AddItem(class'X2Ability_AutoReload'.default.AutoReloadTemplateName);
		AbilityTemplate.AdditionalAbilities.AddItem(class'X2Ability_AutoReload'.default.RetroReloadTemplateName);
	}
}
