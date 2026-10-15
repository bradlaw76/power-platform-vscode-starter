# FAST Official-Source Assessment

**Verified:** 2026-10-15  
**Scope:** FAST-001 research only

## Material finding

Both Microsoft repositories backing FAST are archived:

- [`microsoft/industry-solutions`](https://github.com/microsoft/industry-solutions)
  supplies the Jekyll documentation site.
- [`microsoft/industry-apps`](https://github.com/microsoft/industry-apps)
  supplies module source and GitHub Releases.

Both repositories state that the modules are reference implementations, are not
production-ready, are not covered by a Microsoft support agreement, and carry
no obligation for updates or maintenance. Recommendations must therefore
surface archive state, last verification, and support risk.

## Discovery roots

The rendered [FAST documentation](https://microsoft.github.io/industry-solutions/)
is generated from Jekyll collections defined in the documentation repository.
Relevant collections include modules, app releases, articles, use cases,
personas, agents, portals, portal releases, and tables.

The rendered module/use-case list pages do not provide reliable complete machine
enumeration. The provider should enumerate repository collections and parse
front matter, then use rendered pages for narrative evidence.

Primary roots:

- [Getting Started Guide](https://microsoft.github.io/industry-solutions/articles/getting-started-guide/)
- [Modules](https://microsoft.github.io/industry-solutions/modules/)
- [Use Cases](https://microsoft.github.io/industry-solutions/use-cases/)
- [Core](https://microsoft.github.io/industry-solutions/modules/core/)
- [Documentation home](https://microsoft.github.io/industry-solutions/)
- [`industry-solutions` repository API](https://api.github.com/repos/microsoft/industry-solutions)
- [`industry-apps` repository API](https://api.github.com/repos/microsoft/industry-apps)

## Snapshot observations

The current sources disagree, which is an important catalog requirement rather
than a count to hardcode:

| Source | Observation |
| --- | --- |
| `industry-apps` category directories | 30 module directories across eight categories |
| Generated module statistics report | Reports 27 modules; excludes three government directories and identifies two zero-entity placeholders |
| Documentation `_modules` collection | 21 published module pages plus a template |
| GitHub Releases API | 22 module prefixes with packaged ZIP releases across 70 releases; 70 managed and 70 unmanaged ZIP assets |
| Documentation `_use_cases` collection | Six published use cases plus a template |
| Documentation `_personas` collection | Three entries observed |
| Documentation `_agents` collection | One entry observed |
| Documentation `_portals` collection | One published entry plus a template |

These values describe the 2026-10-15 assessment only. The implementation must
discover and reconcile current breadth dynamically.

## Structured metadata

Useful sources include:

- Jekyll front matter in `_modules`, `_use_cases`, `_personas`, `_agents`, and
  `_portals`;
- generated `.stats/module_stats.csv`, `.stats/module_stats.json`, and
  `.stats/module_stats_report.md` in `industry-apps`;
- module source directories and project/build files;
- GitHub Releases, tags, and release assets;
- rendered narrative pages and linked diagrams.

Front matter provides documented dependency and relationship data. Generated
statistics provide structural counts. Releases provide package availability.
No single source is sufficient by itself.

## Core assessment

The Getting Started Guide requires Core before specialty modules. Checked
module front matter also declares Core as a required module, while Core declares
no required modules.

The earlier assessment missed release tags containing encoded module/version
paths. The Core page links to `core/v1.2.1.0`, and the corresponding GitHub
release contains both managed and unmanaged ZIP assets. The managed asset was
downloaded, its ZIP integrity passed, and its SHA-256 exactly matched the digest
published by the GitHub Releases API.

Architecture consequence:

- Core `1.2.1.0` is package-verified evidence, not a permanent version
  requirement.
- The inspected managed package exposes exact solution, publisher, table,
  attribute, relationship, component, and declared dependency metadata.
- Four declared missing dependencies still require target-environment
  resolution, so package availability does not establish environment
  compatibility.
- Documentation version claims must be cross-checked against actual releases.

See
[`evidence/core-v1.2.1.0-package-summary.md`](evidence/core-v1.2.1.0-package-summary.md)
and its machine-readable companion for the complete extraction.

## Access and crawl findings

- No usable `sitemap.xml` was found.
- GitHub source collections are more reliable than rendered list-page scraping.
- Releases and tree APIs require explicit pagination/completeness checks.
- GitHub access through the current authenticated MCP path returned an
  organization SAML enforcement error for Microsoft repositories; public REST
  and raw content remained accessible. Runtime design must not depend on one
  authenticated tool path.
- Candidate promotion must record rate limits, pagination, source errors, and
  coverage exceptions.

## Unverified gaps

1. Data-model directories referenced by documentation configuration were not
   found at the attempted repository paths.
2. Persona breadth was not independently reconciled against a second source.
3. A packaged Member Organizations release lacks a corresponding observed
   module documentation page.
4. Continued GitHub Pages rebuild behavior after repository archival is
   unverified.
5. ERD and diagram bodies were not exhaustively verified.
6. Government and tooling directories require deeper classification.
7. Core versions other than the inspected release and actual target-environment
   compatibility remain unverified.

These gaps must remain explicit in snapshots and decisions. They are not
evidence of absence.
