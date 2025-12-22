//; =============================================================================
//;                           BAR STYLES MODULE
//;              Constants for Bar Style Character Data
//; =============================================================================
//;
//; Bar style character data is injected at build time by the web app.
//; This file only defines the size constants needed for reserving space.
//;
//; =============================================================================

#importonce

//; Size per style:
//; - Water reflection: 30 chars (10 main + 10 ref1 + 10 ref2) = 240 bytes
//; - Mirror: 20 chars (10 main + 10 mirror) = 160 bytes
.const BAR_STYLE_SIZE_WATER = 240
.const BAR_STYLE_SIZE_MIRROR = 160
