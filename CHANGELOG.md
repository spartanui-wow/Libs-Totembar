# Changelog

All notable changes to Libs-Totembar will be documented in this file.

## [1.0.0] - 2025-01-07

### Added
- **Initial Release**: Modern, flexible ability tracking addon extracted from SpartanUI TotemBar
- **Universal Multi-Class Support**: 
  - **Shaman**: Complete totem tracking (16+ totems across Earth/Fire/Water/Air categories)
  - **Hunter**: Trap tracking with duration timers + pet abilities
  - **Priest**: Example spells like Angelic Feather
  - **Any Class**: Flexible system allows any spell to be added
  
- **Advanced Core Features**:
  - **AceTimer-3.0**: Professional timer management with precise scheduling
  - **SpartanUI Logger Integration**: Proper logging system with levels (debug, info, warning, error, critical)
  - **Comprehensive Settings Panel**: Full AceConfig interface with live updates
  - **Flexible Spell System**: Add any spell from any class with custom duration/category
  - **Dynamic Button Management**: Up to 10 configurable buttons
  - **Smart Positioning**: Drag-to-move with position locking option
  
- **Modern UI Features**:
  - **Settings Categories**: General, Layout & Appearance, Spell Settings, Filters & Display, Custom Spells
  - **Per-Spell Toggles**: Enable/disable individual spells with live preview
  - **Visual Customization**: Scale, spacing, backgrounds, timer text display
  - **Combat Filters**: Hide/show based on combat state
  - **Enhanced Tooltips**: Spell info, remaining time, category, custom spell indicators
  
- **Custom Spell Management**:
  - **Add Any Spell**: `/totembar add <spellID> [duration] [category]`
  - **Remove Custom Spells**: `/totembar remove <spellID>`
  - **Settings Integration**: Custom spells appear in options panel
  - **Examples Included**: Bloodlust, pet abilities, utility spells
  
- **Professional Commands**:
  - `/totembar` or `/ltb` - Open comprehensive settings panel
  - `/totembar add/remove <spellID>` - Manage custom spells
  - `/totembar list` - View all available spells with status
  - `/totembar toggle/reset/test/help` - Standard operations
  
- **Technical Architecture**:
  - **No Print Statements**: All logging through SpartanUI.Log() with proper levels
  - **AceTimer Integration**: Professional timer scheduling and management
  - **AceDB Profiles**: Robust settings storage with profile support
  - **Event-Driven**: Efficient WoW API event handling
  - **Modular Design**: Easy to extend with new classes and abilities

### Known Issues
- None at initial release

### Future Enhancements
- Additional class support (Death Knight, Paladin, etc.)
- Advanced configuration UI
- Animation system enhancements
- WeakAuras integration
- Profile sharing capabilities

---

## Version History Notes

This addon is based on the SpartanUI TotemBar module architecture, extracted and enhanced for standalone use. The design follows the comprehensive technical specifications outlined in the original DesignDoc.md.

### Migration from SpartanUI TotemBar
Users migrating from the SpartanUI TotemBar module should note:
- Settings are independent and will need to be reconfigured
- Functionality is equivalent with additional hunter support
- SpartanUI integration is optional but recommended for existing users