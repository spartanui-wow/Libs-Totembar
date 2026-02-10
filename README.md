# Lib's - Totembar

**Modern, flexible ability tracking bar for World of Warcraft - Track ANY spell from ANY class!**

## Overview

Lib's - Totembar is a revolutionary WoW addon that breaks the traditional "totem bar" limitations. Want to track your Shaman totems? ✅ Hunter traps? ✅ Priest feathers? ✅ **Any spell from any class?** ✅

Originally extracted from the SpartanUI TotemBar module, it's been completely modernized with professional-grade architecture, comprehensive settings, and unlimited flexibility.

## Supported Classes & Abilities

### Shaman

- **Earth Totems**: Earthbind, Stoneskin, Stoneclaw, Strength of Earth
- **Fire Totems**: Searing, Magma, Flametongue, Tranquil Air
- **Water Totems**: Healing Stream, Mana Spring, Poison Cleansing, Fire Resistance
- **Air Totems**: Sentry, Grounding, Windwall, Windfury

### Hunter

- **Traps**: Freezing Trap, Immolation Trap, Snake Trap, Explosive Trap

_More classes and abilities can be added upon request._

## 🚀 Key Features

### Universal Flexibility

- **Any Class, Any Spell**: Track abilities from any class with custom durations
- **Smart Detection**: Auto-detects Shaman totems and Hunter traps
- **Custom Additions**: Add any spell with `/totembar add <spellID> [duration] [category]`
- **Examples**: Bloodlust, Pet abilities, Utility spells, Defensive cooldowns

### Professional UI

- **Comprehensive Settings Panel**: 5 organized categories with live preview
- **Per-Spell Controls**: Enable/disable individual spells
- **Visual Customization**: Scale, spacing, backgrounds, timer display
- **Combat Filters**: Show/hide based on combat state
- **Position Locking**: Prevent accidental movement

### Advanced Technology

- **AceTimer-3.0**: Professional timer scheduling (no manual OnUpdate loops)
- **SpartanUI Logging**: Proper log levels (debug, info, warning, error, critical)
- **AceDB Profiles**: Robust settings with profile support
- **Event-Driven**: Efficient WoW API integration
- **No Print Spam**: All logging through proper channels

## Installation

1. Extract the addon to your `World of Warcraft/Interface/AddOns/` directory
2. Restart World of Warcraft or use `/reload`
3. The addon will automatically enable for supported classes

## 📖 Usage Guide

### Quick Start

1. **Open Settings**: `/totembar` or `/ltb`
2. **Enable Spells**: Go to "Spell Settings" and check desired abilities
3. **Customize Appearance**: Adjust scale, spacing, positioning in "Layout & Appearance"
4. **Add Custom Spells**: Use `/totembar add <spellID> [duration] [category]`

### Essential Commands

- `/totembar` - Open comprehensive settings panel
- `/totembar add 2825 40 Utility` - Add Bloodlust with 40s duration
- `/totembar add 121536 8 Mobility` - Add Angelic Feather with 8s duration
- `/totembar list` - View all spells with enabled/disabled status
- `/totembar toggle` - Quick enable/disable
- `/totembar test` - Show class-appropriate test buttons

### Smart Behavior

- **Shaman**: Auto-detects all 4 totem slots in real-time
- **Hunter**: Tracks trap placement via spell cast detection
- **Any Class**: Tracks custom spells via UNIT_SPELLCAST_SUCCEEDED
- **Flexible Display**: 1-10 buttons, auto-hide when empty, combat filters
- **Secure Actions**: Right-click to destroy totems (Shaman only)

## SpartanUI Integration

When SpartanUI is installed, Lib's - Totembar will use LibAT's logging system for debug output and enhanced integration. This is completely optional - the addon works fine without SpartanUI.

## Technical Details

### Architecture

- **Timer Engine**: Efficient timer tracking and cleanup system
- **Action Buttons**: Secure button framework with state management
- **Event System**: Handles WoW events for totem/trap detection
- **AceAddon Framework**: Uses Ace3 libraries for robust addon structure

### Events Monitored

- `PLAYER_TOTEM_UPDATE` (Shaman)
- `UNIT_SPELLCAST_SUCCEEDED` (Hunter traps)
- `PLAYER_ENTERING_WORLD`, `PLAYER_LOGIN` (Initialization)

### Database

Settings are stored in `LibsTotembarDB` using AceDB for profile management.

## Development

This addon is based on the advanced architecture from the SpartanUI TotemBar module design document. See `DesignDoc.md` for detailed technical specifications and future enhancement plans.

### Adding New Classes/Abilities

To add support for additional classes or abilities, update the `CLASS_SPELLS` table in `main.lua` and add appropriate event handlers.

## Support

For bug reports, feature requests, or general support, please visit the SpartanUI [Discord server](https://discord.gg/Qc9TRBv).

## License

This addon is released under the Mozilla Public License v2.0.

## Credits

- Original SpartanUI TotemBar module design and architecture
- FloTotemBar addon for reference implementation patterns
- SpartanUI development team for framework integration support
