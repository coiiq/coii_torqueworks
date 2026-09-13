# TorqueWorks

### Vehicle tuning, workshop billing & dyno testing for FiveM

**v0.1.0 · Beta · ESX / QBCore / Qbox**

Build a workshop around more than an upgrade menu. TorqueWorks lets mechanics put together a vehicle build, send a clear estimate to the customer, and install the selected parts when the customer accepts and pays.

<!-- MEDIA: Replace every REPLACE_ marker before publishing. Use repository-relative image paths or public HTTPS image URLs. -->
![TorqueWorks — workshop overview](https://i.imgur.com/CS0E2sh.png)

[Watch the showcase](https://streamable.com/fd3mr2) · [Discord] @coii

## Features

- **Vehicle builds:** engines, turbochargers, ECU hardware and maps, fuel pumps, flywheels, transmissions, nitrous, brakes, suspension, differentials, and tires.
- **Customer estimates:** selected parts, required materials, labor, total price, and estimated vehicle class changes in one quote.
- **Cash or bank:** customers choose their payment method; mechanics can also quote their own vehicles.
- **Immediate installation:** accepting a valid quote installs the complete build, consumes the required materials, and closes the mechanic menu.
- **Multiple workshops:** separate names, job and grade access, tuning locations, and dyno bays.
- **Player-owned vehicles:** ownership checks use configurable framework database mappings.
- **Dyno testing:** power, torque, boost, and RPM charts with saved pull history.
- **Vehicle settings:** custom ECU calibration, tire pressure, and drivetrain adjustments.
- **In-car MMI:** a placeable dashboard display with vehicle telemetry and controls.
- **Presentation:** configurable category colors, carbon-style cards, floating build previews in configured zones, and bundled engine audio.
- **Persistence and audit:** saved builds, completed receipts, and optional Discord logs for quotes and payment events.

Dyno figures and vehicle class changes are game-derived estimates, not real-world measurements.

## Preview

![Mechanic menu and part selection](https://i.imgur.com/bxZaaPB.jpeg)

![Customer build estimate](https://i.imgur.com/b2vu0SX.jpeg)

![Dyno results and history](https://i.imgur.com/1zpvlez.png)

[![Watch the TorqueWorks showcase](https://i.imgur.com/1nsLEQE.png)(https://streamable.com/fd3mr2)

## Requirements

- A FiveM server with OneSync enabled.
- One supported framework: **ESX**, **QBCore**, or **Qbox**.
- `ox_lib`, `oxmysql`, and `baseevents`.
- A configured MySQL/MariaDB connection for `oxmysql`.
- An inventory containing the required TorqueWorks items. Qbox uses `ox_inventory`; ESX and QBCore can use their framework inventory or `ox_inventory`.

## Installation

### 1. Add the resource

Download the release and extract it into your server's resources directory. Name the resource folder exactly:

```text
coii_torqueworks
```

### 2. Register the inventory items

For **ox_inventory**:

1. Open [`items/ox_inventory.lua`](items/ox_inventory.lua).
2. Copy the entries **inside** its returned table into `ox_inventory/data/items.lua`. Do not paste a second `return` table or replace your existing items.
3. Copy the PNG files from [`items/images/`](items/images/) into `ox_inventory/web/images/`.

For another supported inventory, register equivalent entries using its item format. The supplied definitions cover the MMI tablet, turbo parts, hose clamps, motor oil, screws, and nitrous bottle. Requirements can be changed in [`shared/config/installation.lua`](shared/config/installation.lua); every configured item must exist in your inventory.

### 3. Configure your server

In [`shared/config.lua`](shared/config.lua):

- Leave `Config.Framework = 'auto'`, or select `esx`, `qbcore`, or `qbox` explicitly.
- Check the vehicle ownership table and column mappings against your garage system.
- Customize the notification, progress, and TextUI adapters if needed.

In [`shared/config/workshops.lua`](shared/config/workshops.lua), set each workshop's name, allowed jobs and minimum grades, tuning coordinates, and dyno position. Move the example locations to match your map.

Set part prices and labor costs, then review the inventory materials and theme in the configuration files listed below.

### 4. Set the start order

Add the resource after its dependencies in `server.cfg`. For example, on an ESX server using ox_inventory:

```cfg
ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure baseevents
ensure coii_torqueworks
```

Use `qb-core` or `qbx_core` in place of `es_extended` for your framework, and follow that framework's inventory start order. Keep TorqueWorks after the framework and inventory. Do not start multiple frameworks from this example.

### 5. Database setup

Missing TorqueWorks tables are created automatically when the resource starts. A manual schema is also included at [`sql/coii_torqueworks.sql`](sql/coii_torqueworks.sql). The automatic setup creates TorqueWorks tables; your framework's vehicle ownership table must already exist.

### 6. Verify the workshop

Join with a configured mechanic job, drive a player-owned vehicle to the tuning location, and open the terminal. Select parts, send a quote, and accept it with cash or bank. Confirm the build persists after leaving and re-entering the vehicle.

Optional administrator access:

```cfg
add_ace group.admin coii_torqueworks.mechanic allow
```

## How it works

1. The mechanic opens the terminal in a configured workshop.
2. Parts are collected with **Add to quote**.
3. The mechanic sends the estimate to a nearby customer, or selects **My vehicle**.
4. The customer reviews the estimate and rejects it or pays using cash or bank.
5. The server validates the vehicle, workshop access, build, payment, and materials, then applies the complete build and saves the receipt.

Failed saves attempt to return the payment and consumed materials. Older paid work orders retain a **Complete order** recovery action so they can finish without a second payment.

## Configuration reference

| File | Settings |
| --- | --- |
| `shared/config.lua` | Framework, ownership mappings, notification/progress/TextUI adapters |
| `shared/config/workshops.lua` | Workshop names, jobs, grades, locations, dyno bays |
| `shared/config/integrations.lua` | Administrator access, billing, labor, quote limits, payment methods |
| `shared/config/parts.lua` | Available parts and their properties |
| `shared/config/tuning.lua` | Prices, compatibility, factory builds, ECU maps, tires, transmissions |
| `shared/config/installation.lua` | Required inventory materials and administrator bypass |
| `shared/config/theme.lua` | UI colors, category accents, effects |
| `shared/config/ui.lua` | MMI, vehicle classes, floating build-card zones |
| `shared/config/core.lua` | Runtime intervals, brakes, nitrous |
| `shared/config/sounds.lua` | Turbo audio behavior |
| `shared/config/dyno.lua` | Dyno model, alignment, pull settings, calibration |
| `shared/config/legacy.lua` | Older saved-build format mappings |
| `server/config/logging.lua` | Server-only Discord audit settings |

## Discord logs

Set the webhook in your private `server.cfg` before starting TorqueWorks:

```cfg
set torqueworks_discord_webhook "YOUR_DISCORD_WEBHOOK_URL"
```

Use `set`, not `setr`, so the webhook stays server-side. Do not commit it to GitHub. You can alternatively create the Git-ignored `server/config/logging.local.lua` containing:

```lua
Config.DiscordLogs.webhook = 'YOUR_DISCORD_WEBHOOK_URL'
```

The server convar takes precedence. Log event toggles and embed colors are in `server/config/logging.lua`.

## Updating

Back up your resource configuration and database before updating. Replace the resource files, merge your settings into the new config files, and read the release notes before restarting. Preserve the engine-audio and dyno registrations in `fxmanifest.lua`.

The startup banner includes the installed version and checks GitHub for a newer release.

## Troubleshooting

- **The terminal does not open:** check the workshop coordinates, job/grade, vehicle ownership record, and garage table mappings. Open it while driving a supported vehicle.
- **An item is missing:** confirm the item ID in `shared/config/installation.lua` exists in your inventory and that the mechanic has the required quantity.
- **Item icons do not appear:** check the copied PNG filenames and your inventory's image directory.
- **The dyno cannot start:** drive onto the configured bay and check the workshop's dyno position and access settings.
- **Nitro does nothing:** the vehicle needs an installed nitrous system. The default binding is Left Alt; bindings can be changed in FiveM settings.
- **A conflict appears after installation:** check other resources that modify handling, transmissions, boost, or nitrous on the same vehicle.
