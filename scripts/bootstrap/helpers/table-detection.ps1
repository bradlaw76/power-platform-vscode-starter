<#
.SYNOPSIS
    Helper module: detects standard Dataverse tables and separates them from custom ones.
    Used by scripts to avoid creating tables that already exist as out-of-box entities.

.DESCRIPTION
    Provides functions to classify tables as either standard (out-of-box) or custom (to be created).
    This allows the build process to skip standard tables and only create custom ones.

.EXAMPLE
    . ./scripts/bootstrap/helpers/table-detection.ps1
    $customTables = Get-CustomTablesToCreate -TableNames "Contact,Case,Inspection,cct_ticket"
    # Returns: @("Inspection", "cct_ticket")
#>

# Standard Dataverse tables that should NOT be created — they already exist
$StandardTableLogicalNames = @(
    # CRM Sales (always available)
    "contact", "account", "opportunity", "lead", "competitor", "invoice", "order", "quote",
    
    # Customer Service
    "incident", "knowledgearticle", "entitlement", "sla",
    
    # Field Service
    "msdyn_workorder", "msdyn_serviceappointment", "msdyn_customerasset",
    
    # Activities (comprehensive)
    "task", "activitypointer", "email", "phonecall", "appointment", "fax", "letter", "socialactivity",
    
    # Products & Pricing
    "product", "pricelevel", "productpricelevel", "uom", "uomschedule",
    "productassociation", "productsubstitute", "productfamily",
    
    # Marketing & Campaigns
    "campaign", "campaignresponse", "list", "marketinglist",
    
    # Organization & Admin
    "systemuser", "team", "businessunit", "organization", "queue", "role", "territory",
    
    # Relationships & Connections
    "connection", "connectionrole", "relationship",
    
    # Notes, Attachments, Documents
    "annotation", "activitymimeattachment", "attachment", "note", "feedback",
    
    # Project Operations
    "msdyn_project", "msdyn_projecttask", "msdyn_resource", "msdyn_resourcebooking",
    
    # Common system tables
    "transactioncurrency", "languagelocale", "organization", "principal", "userquery",
    "savedquery", "userform", "mailbox", "mailboxstatistics", "documenttemplate",
    "plugintypestatistic", "plugintype", "pluginassembly", "webresource",
    "reportcategory", "report", "reportvisibility", "sdkmessageprocessingstep",
    "sdkmessage", "sdkmessagefilter", "sdkmessagepair", "organizationdatasyncsubscription",
    "recommendeddocument", "sitemap", "subject", "subscriptiontrackingdeletedobject",
    "subscription", "traceregarding", "trace", "tracelog"
)


function Test-IsStandardTable {
    <#
    .SYNOPSIS
        Tests if a table logical name is a standard out-of-box Dataverse table.
    .PARAMETER LogicalName
        The logical name of the table (e.g., "contact", "incident", "cct_inspection").
    #>
    param([string]$LogicalName)
    
    $lower = $LogicalName.ToLower()
    return $StandardTableLogicalNames -contains $lower
}

function Resolve-TableLogicalName {
    <#
    .SYNOPSIS
        Converts a display name or shorthand to logical name.
    .EXAMPLE
        Resolve-TableLogicalName "Contact"  → "contact"
        Resolve-TableLogicalName "CustomInspection" -Prefix "cct"  → "cct_custominspection"
    #>
    param(
        [string]$DisplayName,
        [string]$Prefix = ""
    )
    
    $lower = $DisplayName.ToLower()
    
    # If it's already a logical name (contains underscore or matches a standard table), return as-is
    if ($lower.Contains("_")) { return $lower }
    if (Test-IsStandardTable $lower) { return $lower }
    
    # Otherwise, format as custom: <prefix>_<name>
    if ($Prefix) {
        return "$($Prefix.ToLower())_$($lower -replace ' ', '')"
    }
    
    return $lower
}

function Classify-Tables {
    <#
    .SYNOPSIS
        Classifies a list of table names into standard (skip) and custom (create).
    .PARAMETER TableNames
        Comma-separated list of table names or logical names.
    .PARAMETER PublisherPrefix
        Prefix for custom tables (e.g., "cct").
    .EXAMPLE
        $result = Classify-Tables -TableNames "Contact,Case,Inspection,cct_ticket" -PublisherPrefix "cct"
        # Returns: @{ Standard=@("contact","incident"); Custom=@("cct_inspection","cct_ticket") }
    #>
    param(
        [string]$TableNames,
        [string]$PublisherPrefix = ""
    )
    
    $tables = @($TableNames -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $standard = @()
    $custom = @()
    
    foreach ($table in $tables) {
        $logical = Resolve-TableLogicalName -DisplayName $table -Prefix $PublisherPrefix
        
        if (Test-IsStandardTable $logical) {
            $standard += $logical
        } else {
            $custom += $logical
        }
    }
    
    return @{
        Standard = $standard
        Custom   = $custom
    }
}

function Format-TableClassification {
    <#
    .SYNOPSIS
        Formats classification results for console output.
    .PARAMETER Classification
        Object returned by Classify-Tables.
    #>
    param($Classification)
    
    $output = @()
    $output += ""
    $output += "=== Table Classification ==="
    
    if ($Classification.Standard.Count -gt 0) {
        $output += ""
        $output += "Standard (out-of-box) — will SKIP creation:"
        foreach ($t in $Classification.Standard) {
            $output += "  ✓ $t"
        }
    }
    
    if ($Classification.Custom.Count -gt 0) {
        $output += ""
        $output += "Custom — will CREATE in solution:"
        foreach ($t in $Classification.Custom) {
            $output += "  ⊕ $t"
        }
    }
    
    if ($Classification.Standard.Count -eq 0 -and $Classification.Custom.Count -eq 0) {
        $output += "  (No tables to process)"
    }
    
    $output += ""
    return $output -join "`n"
}
