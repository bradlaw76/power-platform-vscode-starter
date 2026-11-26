<#
=============================================================================
COMPONENT:    Choice Presentation Tokens
FILE:         scripts/bootstrap/helpers/choice-presentation-tokens.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7
OVERVIEW:     Shared stage-35 tokens for rendering and semantic verification.
ARCHITECTURE: Pure data; Unicode constructed from codepoints.
TEST CASES:   Existing pastel colors and inline icons remain unchanged.
NON-NEGOTIABLES: Tokens change presentation, never option identity.
=============================================================================
#>
$script:ChoicePalette = [ordered]@{
    'pastel-apricot' = '#FFD1A3'
    'pastel-blue' = '#B9DDF5'
    'pastel-gray' = '#D9E1E8'
    'pastel-lavender' = '#D8C4F1'
    'pastel-mint' = '#C8E6C9'
    'pastel-peach' = '#FAD7A0'
    'pastel-rose' = '#F5BEC8'
    'pastel-yellow' = '#F7E7A9'
}
$script:ChoiceIcons = [ordered]@{
    'none' = ''
    'circle-filled' = [string][char]0x25CF
    'diamond-filled' = [string][char]0x25C6
    'diamond-outline' = [string][char]0x25C7
    'info' = [string][char]0x2139
    'square-filled' = [string][char]0x25A0
    'triangle-filled' = [string][char]0x25B2
    'triangle-outline' = [string][char]0x25B3
    'warning' = [string][char]0x26A0
}
