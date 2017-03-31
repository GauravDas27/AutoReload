class X2Condition_FreeReload extends X2Condition;

event name CallAbilityMeetsCondition(XComGameState_Ability kAbility, XComGameState_BaseObject kTarget)
{
	local XComGameStateHistory History;
	local XComGameState_Ability Ability;
	local XComGameState_Unit Unit;
	local XComGameState_Item Weapon;

	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local X2WeaponUpgradeTemplate WeaponUpgrade;

	if (kAbility == None) return 'AA_AbilityUnavailable';

	History = `XCOMHISTORY;
	// retrieve copies here because we do not want changes from calling FreeReloadCostFn to affect the history
	Ability = XComGameState_Ability(History.GetGameStateForObjectID(kAbility.ObjectID, eReturnType_Copy));
	Unit = XComGameState_Unit(History.GetGameStateForObjectID(kAbility.OwnerStateObject.ObjectID, eReturnType_Copy));
	Weapon = XComGameState_Item(History.GetGameStateForObjectID(kAbility.SourceWeapon.ObjectID, eReturnType_Copy));

	if (Ability == None) return 'AA_AbilityUnavailable';
	if (Unit == None) return 'AA_NotAUnit';
	if (Weapon == None) return 'AA_WeaponIncompatible';

	WeaponUpgrades = Weapon.GetMyWeaponUpgradeTemplates();
	foreach WeaponUpgrades(WeaponUpgrade)
	{
		if (WeaponUpgrade.FreeReloadCostFn == None) continue;
		if (WeaponUpgrade.FreeReloadCostFn(WeaponUpgrade, Ability, Unit)) return 'AA_WeaponIncompatible';
	}

	return 'AA_Success';
}
