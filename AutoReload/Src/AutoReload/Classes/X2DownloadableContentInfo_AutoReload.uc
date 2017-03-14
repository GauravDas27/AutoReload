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
	local X2ItemTemplateManager ItpMan;
	local X2DataTemplate DataTp;
	local X2WeaponTemplate WeaponTp;

	ItpMan = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach ItpMan.IterateTemplates(DataTp, None)
	{
		WeaponTp = X2WeaponTemplate(DataTp);
		if (WeaponTp == None || WeaponTp.InventorySlot != eInvSlot_PrimaryWeapon || WeaponTp.Abilities.Find('Reload') == INDEX_NONE)
		{
			continue;
		}
		WeaponTp.Abilities.AddItem('AutoReload');
	}
}
