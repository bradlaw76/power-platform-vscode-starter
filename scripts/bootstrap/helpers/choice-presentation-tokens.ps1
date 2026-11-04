<#
=============================================================================
COMPONENT:    Choice Presentation Tokens
FILE:         scripts/bootstrap/helpers/choice-presentation-tokens.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  PowerShell 7
OVERVIEW:     Original wizard palette and redundant inline label symbols.
ARCHITECTURE: Pure presentation data; Unicode constructed from codepoints.
TEST CASES:   Exact palette, rendered labels, and unchanged semantic values.
NON-NEGOTIABLES: Presentation never changes option identity or stored values.
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

function Get-WizardChoiceDisplayLabel {
    param([object]$Option)
    $icon = $Option.PSObject.Properties['Icon']
    if ($null -eq $icon -or $icon.Value -eq 'none') { return [string]$Option.Label }
    if (-not $script:ChoiceIcons.Contains($icon.Value)) { throw "Unknown Choice icon '$($icon.Value)'." }
    return "$($script:ChoiceIcons[$icon.Value]) $($Option.Label)"
}

function Get-WizardChoiceColor {
    param([object]$Option)
    $token = $Option.PSObject.Properties['ColorToken']
    if ($null -eq $token) { return $null }
    if (-not $script:ChoicePalette.Contains($token.Value)) { throw "Unknown Choice color '$($token.Value)'." }
    return $script:ChoicePalette[$token.Value]
}
