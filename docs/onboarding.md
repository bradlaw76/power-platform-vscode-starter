# Onboarding Guide

Use this document when setting up this repo for the first time in VS Code.

---

## Step 1: Accept extension recommendations

When VS Code opens this folder you will see a notification:
> "Do you want to install the recommended extensions for this repository?"

Click **Install All**. If you missed it, open the Extensions panel (Ctrl+Shift+X),
search `@recommended`, and install each one.

Required extensions installed by this repo:
- GitHub Copilot — AI assistant
- Power Platform Tools — Maker/CLI integration
- PowerShell — terminal language support
- JSON — schema validation for payloads
- Markdown lint — documentation quality
- YAML — process definition files

---

## Step 2: Open an integrated terminal

- Press **Ctrl+`** (backtick) or go to **Terminal → New Terminal**.
- Confirm the shell is PowerShell 7:
  ```powershell
  $PSVersionTable.PSVersion
  ```
  Major version must be 7 or higher.

---

## Step 3: Run the prerequisite check

```powershell
pwsh ./scripts/bootstrap/00-prereq-check.ps1
```

All tools should show PASS. Install any that show FAIL before continuing.

---

## Step 4: Sign in and configure

```powershell
pwsh ./scripts/bootstrap/10-auth-connect.ps1
```

The script will ask you for:
- Your Dataverse environment URL
- Your Azure tenant (optional — leave blank for default)
- Your publisher name and prefix
- Your solution name

It saves your session to `.env.ps1` (local only, never committed).

**Flags:**
```powershell
# No browser available (remote machine or headless)
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -UseDeviceCode

# Service principal / CI
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -ServicePrincipal
```

---

## Step 5: Build in order

Run each script in sequence. Each one tells you the next step on completion.

```powershell
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
```

All scripts are idempotent — safe to rerun at any time.

---

## Step 6: Verify in the Maker portal

Open https://make.powerapps.com, select your environment, and confirm:
- Tables appear under **Dataverse → Tables**
- Forms and views appear on each table
- Tables appear inside the target solution

---

## Common issues

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| 401 on every API call | Token URL mismatch | Re-run `10-auth-connect.ps1` — ensure URL has no trailing slash |
| Token works then stops mid-run | Token expired (60–90 min) | Re-run `10-auth-connect.ps1` to refresh |
| PAC errors after `az login` | Two separate auth mechanisms | Run both `az login` AND `pac auth create` |
| Login opens wrong tenant | Multiple tenants on account | Pass `-tenantId` or re-run auth with specific tenant |
| `pac` not found | CLI not installed | `winget install Microsoft.PowerPlatformCLI` |
| Solution not found error | Solution unique name wrong or missing | Create solution in Maker portal first, then re-run `50-add-to-solution.ps1` |
