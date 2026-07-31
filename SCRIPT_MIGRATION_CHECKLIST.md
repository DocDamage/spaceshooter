# Script Migration Checklist

| Area | Status | Phase 1 disposition |
|---|---|---|
| AudioCenter | Adapter | Safe silent compatibility facade |
| BattleServer | Adapter | Counters and battle signals restored |
| EnemySpawnerData | Adapter | One deterministic legacy wave |
| LevelServer | Adapter | Stage start/completion restored |
| LevelGUI | Adapter | HUD signal facade restored |
| Currency | Adapter | Currency rewards restored |
| GameServer | Adapter | Splash/menu/play/complete flow restored |
| Player ship | Reimplemented | Movement, firing, shield, health, XP, death |
| Enemy core | Reimplemented | Spawn, movement, firing, health, rewards |
| Player/enemy projectiles | Reimplemented | Godot 4 Area2D collision |
| Experience system | Reimplemented | Level-up behavior in player compatibility actor |
| Legacy optional equipment | Deferred | Not required by Phase 1 acceptance path |
| Legacy utility scripts | Preserved raw | Review or replace after migration gate |
| Legacy UI/theme scripts | Preserved raw | Sources incomplete; production UI replaces later |

## Donor script-by-script disposition

Legend: **Adapter** preserves the public Phase 1 interface; **Reimplemented** restores behavior in the active build; **Raw converted** is retained in `../legacy/godot-space-rpg-godot4-raw` and excluded from the required path because its dependencies are incomplete.

| Donor script | Disposition |
|---|---|
| `Autoload/BattleServer.gd` | Adapter |
| `Autoload/Currency.gd` | Adapter |
| `Autoload/EnemySpawnerData.gd` | Adapter |
| `Autoload/GameServer.gd` | Adapter |
| `Autoload/LevelGUI/LevelGUI.gd` | Adapter |
| `Autoload/LevelServer.gd` | Adapter |
| `GameDatabase/Item/Equipment/Equipment.gd` | Raw converted |
| `GameDatabase/Item/Equipment/Modules/Module.gd` | Raw converted |
| `GameDatabase/Item/Equipment/Satellites/Satellite.gd` | Raw converted |
| `GameDatabase/Item/Equipment/Shields/Shield.gd` | Reimplemented in player compatibility actor |
| `GameDatabase/Item/Equipment/Superpowers/Superpower.gd` | Raw converted |
| `GameDatabase/Item/Equipment/Weapons/Weapon.gd` | Reimplemented in player compatibility actor |
| `GameDatabase/Item/Item.gd` | Raw converted |
| `GameObject/DamagePopup/DamagePopup.gd` | Raw converted |
| `GameObject/DamagePopupTurret/DamagePopupTurret.gd` | Raw converted |
| `GameObject/EnemyCore/Core/EnemyCore.gd` | Reimplemented |
| `GameObject/EnemyCore/Droplet.gd` | Raw converted |
| `GameObject/EnemyCore/Explodang.gd` | Raw converted |
| `GameObject/EnemyCore/NonEnemyObject/LevelEndObject.gd` | Reimplemented in stage completion |
| `GameObject/EnemyCore/test-brisker-enemy.gd` | Raw converted |
| `GameObject/EnemyCore/test-counter-enemy.gd` | Raw converted |
| `GameObject/EnemyCore/test-moving-enemy.gd` | Raw converted |
| `GameObject/EnemyCore/test-weak-enemy.gd` | Reimplemented |
| `GameObject/EnemyProjectile/Core/EnemyProjectileCore.gd` | Reimplemented |
| `GameObject/EnemySpawner/EnemySpawner.gd` | Reimplemented |
| `GameObject/EnemyTurret/EnemyTurret.gd` | Reimplemented in enemy compatibility actor |
| `GameObject/Entity/Entity.gd` | Reimplemented in player/enemy actors |
| `GameObject/ExperienceSystem/ExperienceSystem.gd` | Reimplemented |
| `GameObject/InvincibleState/InvincibleState.gd` | Raw converted |
| `GameObject/LevelBulletBhv/LevelBulletBhv.gd` | Reimplemented in projectile actors |
| `GameObject/Pickups/Core/Pickups.gd` | Raw converted |
| `GameObject/Pickups/PickupsItem.gd` | Raw converted |
| `GameObject/Pickups/PickupsMainCurrency.gd` | Reimplemented as direct reward |
| `GameObject/PickupsCollector/PickupsCollector.gd` | Raw converted |
| `GameObject/PickupsTurret/PickupsTurret.gd` | Raw converted |
| `GameObject/PlayerEquipmentCore/PlayerEquipmentCore.gd` | Raw converted |
| `GameObject/PlayerModule/Core/PlayerModule.gd` | Raw converted |
| `GameObject/PlayerProjectile/Core/PlayerProjectile.gd` | Reimplemented |
| `GameObject/PlayerProjectile/Debris.gd` | Raw converted |
| `GameObject/PlayerProjectileTurret/PlayerProjectileTurret.gd` | Reimplemented in player compatibility actor |
| `GameObject/PlayerSatellite/Core/PlayerSatellite.gd` | Raw converted |
| `GameObject/PlayerShield/Core/PlayerShield.gd` | Reimplemented |
| `GameObject/PlayerShip/Core/PlayerShip.gd` | Reimplemented |
| `GameObject/PlayerShip/Core/PlayerShipTouchController.gd` | Raw converted; out of scope |
| `GameObject/PlayerSuperpower/Core/PlayerSuperpower.gd` | Raw converted; out of scope |
| `GameObject/PlayerSuperpower/test-player-superpower.gd` | Raw converted; out of scope |
| `GameObject/PlayerWeapon/Core/PlayerWeapon.gd` | Reimplemented |
| `GameObject/PlayerWeapon/PulseCannon.gd` | Reimplemented |
| `GlobalClass/ExtendedButton.gd` | Raw converted |
| `Lib/Instanceable/8DirectionBehavior/8DirectionBehavior.gd` | Reimplemented in player compatibility actor |
| `Lib/Instanceable/BgColorSetter/BgColorSetter.gd` | Raw converted |
| `Lib/Instanceable/BrightnessShader/BrightnessShader.gd` | Raw converted |
| `Lib/Instanceable/BulletBehavior/BulletBehavior.gd` | Reimplemented in projectile actors |
| `Lib/Instanceable/ShakeBehavior/ShakeBehavior.gd` | Raw converted |
| `Lib/Instanceable/SineBehavior2D/SineBehavior2D.gd` | Reimplemented in enemy movement |
| `Lib/Instanceable/SpriteCycling/SpriteCycling.gd` | Raw converted |
| `Lib/ScriptTemplate.gd` | Raw converted; non-runtime |
| `Lib/Singleton/AudioCenter/AudioCenter.gd` | Adapter |
| `Lib/Util/DateTime/DateTime.gd` | Raw converted |
| `Lib/Util/NumberSplit/NumberSplit.gd` | Raw converted |
| `Scenes/Levels/Core/Level.gd` | Reimplemented |
| `Scenes/SplashScreen/SplashScreen.gd` | Reimplemented |
| `Scenes/test_scene/test_scene.gd` | Raw converted; non-runtime |
