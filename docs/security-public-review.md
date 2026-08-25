# Security and Public-File Review

Review date: 2026-08-24

Scope: files returned by `git ls-files`. Local ignored files, untracked package experiments, `.env.ps1`, `.wizard-metrics/`, and `node_modules/` were excluded from public-file findings.

## Findings

| File or scope | Concern | Confidence | Recommended owner decision |
| --- | --- | --- | --- |
| Tracked text files | Pattern scan found no private key, active bearer token, hard-coded client secret, password, or connection string. Matches were variables, mocks, GitHub secret references, and security guidance. | High | Retain; enable GitHub secret scanning and review staged diffs before every push. |
| `requirements/02 Getting Started Interactive Decision Template.pdf` | Metadata names an author; extracted text includes a public VA feedback address and Department of Veterans Affairs/Board of Veterans' Appeals material. No confidentiality or reuse license was found. | High for content; low for redistribution rights | Owner or counsel must confirm public redistribution rights and business necessity before release. Remove or replace with an owner-approved synthetic/openly licensed fixture if rights are unclear. |
| `requirements/Example Decision and Remand 07.05.pdf` | Metadata contains an author identifier. Extracted text appears to use placeholder veteran names and VA/representative content. No confidentiality or reuse license was found. | Medium-high | Owner or counsel must confirm that names are synthetic and public redistribution is permitted. Remove or replace if provenance cannot be documented. |
| Contoso scenario files | `contoso-dev.crm.dynamics.com` and Contoso identities are synthetic examples, not credentials. | High | Retain with the synthetic-sample label; never use as a coworker's default solution identity. |
| Public GitHub URLs and ASCII asset | `bradlaw76` appears in repository URLs and a decorative terminal prompt. | High | Owner should confirm the personal account attribution is intended for public release. |
| Repository root | No license file or recorded redistribution grant exists. | High | Explicit owner decision required. Do not infer or add a license automatically. |
| Dependency automation | No Dependabot or Renovate configuration was found. Tracked package manifests were not found. PowerShell modules and GitHub Actions are the current dependency surfaces. | High | Enable reviewed Dependabot coverage for GitHub Actions where organization policy permits; continue pinning PowerShell module versions in CI. |

## Method

- Enumerated tracked files with `git ls-files`.
- Scanned tracked text with `git grep` for private-key markers, bearer/client-secret/password/connection-string terms, email domains, local user paths, owner names, and sample environment URLs.
- Enumerated tracked document, archive, certificate, environment, and package-manifest extensions.
- Extracted PDF metadata and text to the operating-system temporary directory with installed PyMuPDF because `pdftotext` was unavailable.
- Searched extracted text for names, email addresses, organizations, confidentiality markers, and copyright/license language. The extracted bodies were not added to the repository.

## Limitations

This is a pattern and content review, not a legal determination or a full secret-scanning engine. PDF provenance and redistribution rights cannot be established from file content alone. Live GitHub secret scanning, dependency alerts, repository visibility, branch protection, and organization policy were not inspected.
