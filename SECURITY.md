# Security Policy

## Supported versions

Security fixes are applied to the default branch. Release or tag support is not yet defined; repository owners must publish a support window before treating a tagged version as maintained.

## Report a vulnerability

Do not open a public issue for a suspected vulnerability, credential, tenant identifier, customer record, or other sensitive information. Use GitHub private vulnerability reporting when enabled for this repository. If it is unavailable, contact the repository owner through an approved private Microsoft or GitHub channel and include only the minimum reproduction details needed.

Expect an acknowledgement target of five business days. Do not test against production or any Dataverse environment you do not own or have explicit authorization to assess.

## Secrets and environment safety

- Store local Dataverse values only in ignored `.env.ps1` or process environment variables.
- Never commit access tokens, client secrets, exported customer data, raw solution exports, or `.wizard-metrics/` telemetry.
- Use a dedicated non-production environment and scenario-specific unmanaged solution.
- Review `git diff --cached` and run secret scanning before every push.
- Integration workflow cleanup is permitted only for an explicitly approved disposable environment.

## Dependencies and updates

PowerShell modules and CI actions must be pinned or reviewed when updated. Enable GitHub dependency and secret scanning where the repository license and organization policy permit it. Validate updates with the complete credential-free suite and the manually approved disposable-environment integration workflow.
