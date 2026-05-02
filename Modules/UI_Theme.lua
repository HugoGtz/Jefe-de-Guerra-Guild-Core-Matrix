local addonName, ns = ...
ns.Theme = ns.Theme or {}

-- Single source of truth for all shared visual tokens.
-- Only tokens that appear in 2 or more UI_*.lua files live here.
-- File-specific layout constants (heights, widths, padding) stay local to each file.

ns.Theme = {
    -- ── Textures ──────────────────────────────────────────────────────────────
    TEX_WHITE  = "Interface\\Buttons\\WHITE8X8",
    TEX_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",

    -- ── Frame backgrounds ─────────────────────────────────────────────────────
    BG_MAIN  = { 0.05, 0.05, 0.07, 0.97 },  -- MainFrame backdrop
    BG_PANEL = { 0.06, 0.06, 0.08, 0.96 },  -- inner panel backdrops (SelfBar, etc.)
    BG_STRIP = { 0.08, 0.06, 0.06, 1.0  },  -- TabStrip background

    -- ── Borders ───────────────────────────────────────────────────────────────
    BORDER_MAIN = { 0.42, 0.12, 0.12, 0.85 },  -- main brand border (MainFrame, TabStrip, SelfBar, groupBox)
    BORDER_CARD = { 0.22, 0.20, 0.26, 1.0  },  -- card/row borders (CoreList)

    -- ── Brand colors ──────────────────────────────────────────────────────────
    BRAND_RED  = { 0.65, 0.10, 0.10, 1.0  },  -- TitleBar background
    BRAND_GOLD = { 1.00, 0.82, 0.15, 1.0  },  -- active tab accent bar / card count text

    -- ── Button states ─────────────────────────────────────────────────────────
    BTN_OFF    = { 0.13, 0.13, 0.17, 1.0 },
    BTN_ON     = { 0.22, 0.58, 0.82, 1.0 },
    BTN_HOVER  = { 0.18, 0.18, 0.24, 1.0 },
    BTN_TEXT   = { 0.95, 0.95, 0.98, 1.0 },
    BTN_LFG_ON = { 0.12, 0.48, 0.18, 1.0 },  -- LFG mode active (green)
    BTN_LFM_ON = { 0.48, 0.38, 0.06, 1.0 },  -- LFM mode active (gold-brown)

    -- ── Row / list ────────────────────────────────────────────────────────────
    ROW_HOVER  = { 1.0, 1.0, 1.0, 0.08 },  -- mouse-hover highlight
    ROW_STRIPE = { 1.0, 1.0, 1.0, 0.03 },  -- zebra stripe tint

    -- ── Separators ────────────────────────────────────────────────────────────
    SEP = { 0.22, 0.22, 0.28, 0.60 },

    -- ── Fonts ─────────────────────────────────────────────────────────────────
    FONT_ROW    = "GameFontHighlight",
    FONT_SMALL  = "GameFontDisableSmall",
    FONT_NORMAL = "GameFontNormal",
}
