<#
=============================================================================
COMPONENT:    FAST Package Indexing Tests
FILE:         scripts/ci/test-fast-package-indexing.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$evidenceRoot = Join-Path $repoRoot 'specs/fast-solution-accelerator-discovery/evidence/pkg'
$schemaPath = Join-Path $repoRoot 'schemas/accelerators/package-metadata.schema.json'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "fast-package-$([guid]::NewGuid().ToString('N'))"

. (Join-Path $repoRoot 'scripts/accelerators/accelerator-catalog.ps1')
. (Join-Path $repoRoot 'scripts/accelerators/fast-provider.ps1')

try {
    $expected = [ordered]@{
        'core.json' = @{ tables = 38; attributes = 1008; relationships = 323; dependencies = 4 }
        'investigations.json' = @{ tables = 28; attributes = 908; relationships = 292; dependencies = 96 }
        'training-certification.json' = @{ tables = 21; attributes = 815; relationships = 225; dependencies = 96 }
    }
    foreach ($name in $expected.Keys) {
        $path = Join-Path $evidenceRoot $name
        $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop)) {
            throw "Package index does not match its schema: $name"
        }
        $package = $json | ConvertFrom-Json
        $counts = $expected[$name]
        if (@($package.tables).Count -ne $counts.tables -or
            @($package.tables.attributes).Count -ne $counts.attributes -or
            @($package.relationships).Count -ne $counts.relationships -or
            @($package.declaredDependencies).Count -ne $counts.dependencies) {
            throw "Package index coverage changed unexpectedly: $name"
        }
    }

    $contentRoot = Join-Path $tempRoot 'content'
    New-Item -ItemType Directory -Path $contentRoot -Force | Out-Null
    $solutionXml = @'
<ImportExportXml>
  <SolutionManifest>
    <UniqueName>fixture_solution</UniqueName>
    <LocalizedNames><LocalizedName description="Fixture Solution" /></LocalizedNames>
    <Version>1.0.0.0</Version>
    <Managed>1</Managed>
    <SolutionPackageVersion>9.2</SolutionPackageVersion>
    <publisher>
      <UniqueName>fixture</UniqueName>
      <LocalizedNames><LocalizedName description="Fixture" /></LocalizedNames>
      <Descriptions><Description description="Fixture publisher" /></Descriptions>
      <CustomizationPrefix>fixture</CustomizationPrefix>
      <CustomizationOptionValuePrefix>12345</CustomizationOptionValuePrefix>
    </publisher>
    <RootComponents>
      <RootComponent type="1" schemaName="fixture_table" behavior="0" />
    </RootComponents>
    <MissingDependencies />
  </SolutionManifest>
</ImportExportXml>
'@
    $customizationsXml = @'
<ImportExportXml>
  <Entities>
    <Entity>
      <Name LocalizedName="Fixture Table">fixture_table</Name>
      <EntityInfo>
        <entity Name="fixture_table">
          <attributes>
            <attribute PhysicalName="fixture_name">
              <Name>fixture_name</Name>
              <Type>nvarchar</Type>
              <RequiredLevel>required</RequiredLevel>
              <IsCustomField>1</IsCustomField>
              <IntroducedVersion>1.0.0.0</IntroducedVersion>
            </attribute>
          </attributes>
        </entity>
      </EntityInfo>
      <FormXml />
      <SavedQueries />
    </Entity>
  </Entities>
  <EntityRelationships />
  <optionsets />
</ImportExportXml>
'@
    Set-Content -LiteralPath (Join-Path $contentRoot 'solution.xml') -Value $solutionXml -Encoding utf8NoBOM
    Set-Content -LiteralPath (Join-Path $contentRoot 'customizations.xml') -Value $customizationsXml -Encoding utf8NoBOM
    $zipPath = Join-Path $tempRoot 'fixture-managed.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($contentRoot, $zipPath)
    $fixture = Get-FastSolutionPackageMetadata -ZipPath $zipPath -ModuleId fixture
    if ($fixture.solution.uniqueName -ne 'fixture_solution' -or
        @($fixture.tables).Count -ne 1 -or
        @($fixture.tables.attributes).Count -ne 1 -or
        $fixture.sha256 -ne (Get-AcceleratorFileSha256 -Path $zipPath)) {
        throw 'Synthetic solution ZIP metadata was not indexed correctly.'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'FAST package indexing tests passed.' -ForegroundColor Green
