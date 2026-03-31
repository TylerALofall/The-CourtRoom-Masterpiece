# MCP Local Architecture

**Status:** Foundation complete — tools live and callable, heartbeat/loop deferred.

---

## Overview

This document explains how the local MCP shell and PowerShell tool scripts fit
together and which parts are intentionally stubbed for a later phase.

The architecture is **PowerShell-first, local-first, no Python, no
browser-backed storage**. XML is the master format; CSV is a secondary
index/view.

---

## Directory Layout

```
The-CourtRoom-Masterpiece/
│
├── mcp_local/                   # MCP host / registry / dispatch
│   ├── Invoke-McpHost.ps1       # Entry point — thin router only
│   ├── tool_registry.json       # Manifest of all registered tools
│   ├── memory.json              # Session memory stub (future)
│   └── ollama-openapi.json      # OpenAPI shape reference
│
├── mcp_tools/                   # One script per tool (isolated)
│   ├── Get-ToolMenu.ps1         # get_tool_menu
│   ├── Get-DocumentList.ps1     # list_documents
│   ├── Search-Documents.ps1     # search_documents
│   ├── Resolve-Citation.ps1     # resolve_citation
│   ├── Get-DocumentPage.ps1     # get_document_page
│   ├── Get-XmlObject.ps1        # get_xml_object
│   └── New-BlockPlan.ps1        # create_block_plan
│
├── block_plans/                 # XML block plan artifacts (auto-created)
│   └── block_plans_index.csv    # CSV index for searchability
│
├── ECF_FILES/                   # Source documents (PDFs, JSON lists)
│
├── HubStation/                  # Existing PowerShell hub service
└── docs/                        # Architecture and spec documents
    └── MCP_LOCAL_ARCHITECTURE.md  ← you are here
```

---

## Design Principles

| Principle | Decision |
|-----------|----------|
| PowerShell only | All infrastructure scripts are `.ps1`. No Python. |
| Local-first | All data lives on disk. No browser-backed or cloud storage. |
| Tools isolated from host | Each tool is its own script. A crash in one tool cannot affect others. |
| Thin host / dispatcher | `Invoke-McpHost.ps1` only resolves the tool script and passes JSON through. No logic lives in the host. |
| XML master, CSV secondary | `get_xml_object` and `create_block_plan` produce XML. CSV rows index them for search. |
| snake_case everywhere | All field names, tool names, and schema keys use `snake_case`. |
| `document_no`, not `document_id` | Documents are identified by their ECF/docket number, not a generated id. |
| `filing_path` only where relevant | `filing_path` is for supporting attachments that need a local path. It does not appear on already-filed ECF documents. |
| Heartbeat/loop deferred | Loop orchestration, heartbeat timing, and auto-reprompt are **not** implemented here. See § Deferred section below. |

---

## Quick Start

### Discover available tools

```powershell
# From the repo root
pwsh -File mcp_local/Invoke-McpHost.ps1 -ListTools
```

### List documents for a case

```powershell
pwsh -File mcp_local/Invoke-McpHost.ps1 -Tool list_documents -InputJson '{"case_no":"839"}'
```

### Search documents

```powershell
pwsh -File mcp_local/Invoke-McpHost.ps1 -Tool search_documents -InputJson '{"query":"amended complaint","case_no":"839"}'
```

### Resolve a citation

```powershell
pwsh -File mcp_local/Invoke-McpHost.ps1 -Tool resolve_citation -InputJson '{"citation":"ecf[13]page[2]"}'
```

### Get a specific page

```powershell
pwsh -File mcp_local/Invoke-McpHost.ps1 -Tool get_document_page -InputJson '{"document_no":"13","page_no":2,"case_no":"839"}'
```

### Get the XML master record for a document

```powershell
pwsh -File mcp_local/Invoke-McpHost.ps1 -Tool get_xml_object -InputJson '{"document_no":"13","case_no":"839"}'
```

### Create a block plan

```powershell
$input = @{
    case_no      = "839"
    case_name    = "Lofall v. West Linn et al"
    block_title  = "Opposition_to_MTD"
    document_nos = @("34","35","36","37","38")
} | ConvertTo-Json

pwsh -File mcp_local/Invoke-McpHost.ps1 -Tool create_block_plan -InputJson $input
```

---

## Tool Contracts (snake_case)

All tools accept JSON via `-InputJson` and return JSON to stdout.
All responses include `ok: true/false`. On error, `error` contains the message.

### `get_tool_menu`

**Input:** `{}` (no required fields)

**Output:**
```json
{
  "ok": true,
  "tool_count": 7,
  "tools": [
    { "tool_name": "list_documents", "description": "...", "script": "Get-DocumentList.ps1", ... }
  ]
}
```

---

### `list_documents`

**Input:**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `case_no` | string | no | Filter by case number |
| `case_name` | string | no | Substring filter |
| `filing_source` | string | no | e.g. `ecf` |
| `page_no` | int | no | 1-based, default 1 |
| `page_size` | int | no | default 50 |

**Output fields per document:**
`document_no`, `case_no`, `case_name`, `authorship`, `total_pages`, `filing_source`, `file_name`

---

### `search_documents`

**Input:**
| Field | Type | Required |
|-------|------|----------|
| `query` | string | **yes** |
| `case_no` | string | no |
| `filing_source` | string | no |

**Output fields per result:**
`document_no`, `case_no`, `case_name`, `file_name`, `filing_source`, `score`, `snippet`

---

### `resolve_citation`

**Input:**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `citation` | string | **yes** | Format: `ecf[document_no]page[page_no]` |

**Output:**
`ok`, `citation`, `document_no`, `page_no`, `filing_source`, `case_no`, `file_name`

> `filing_path` is **not** returned here because ECF filings are already
> submitted. `filing_path` applies only to supporting attachments that need a
> local path for submission preparation.

---

### `get_document_page`

**Input:**
| Field | Type | Required |
|-------|------|----------|
| `document_no` | string | **yes** |
| `page_no` | int | **yes** |
| `case_no` | string | no |

**Output:**
`ok`, `document_no`, `case_no`, `case_name`, `page_no`, `total_pages`,
`filing_source`, `authorship`, `file_name`, `content_text`

> PDF text extraction is a stub. The tool returns the file path so the caller
> can open the PDF directly. Full extraction (iTextSharp or equivalent) is an
> extension point — no Python required.

---

### `get_xml_object`

**Input:**
| Field | Type | Required |
|-------|------|----------|
| `document_no` | string | **yes** |
| `case_no` | string | no |

**Output:**
`ok`, `document_no`, `case_no`, `xml_path`, `xml_content`

Lookup order:
1. Existing `.xml` sidecar in `ECF_FILES/`
2. Entry from `Case_<n>_0-Master_ECF_List.json`
3. Generated stub XML (written as sidecar for future reuse)

---

### `create_block_plan`

**Input:**
| Field | Type | Required |
|-------|------|----------|
| `case_no` | string | **yes** |
| `case_name` | string | no |
| `block_title` | string | **yes** |
| `document_nos` | array of strings | **yes** |

**Output:**
`ok`, `block_title`, `case_no`, `case_name`, `document_count`,
`block_plan_path`, `created_at_epoch`

XML artifact written to `block_plans/`. CSV index row appended to
`block_plans/block_plans_index.csv`.

---

## Isolation Model

Each tool script is a standalone `.ps1` file:

- It receives `$InputJson` as a parameter.
- It writes a single JSON object to stdout.
- It exits with code 0 on success, non-zero on fatal error.
- It has no dependency on any other tool script.
- `Invoke-McpHost.ps1` spawns each tool in a fresh `pwsh` child process so
  a crash or `$ErrorActionPreference = 'Stop'` trigger in one tool cannot
  affect the host or other tools.

---

## Extending with New Tools

1. Create `mcp_tools/My-NewTool.ps1` following the existing pattern:
   - Accept `-InputJson` parameter.
   - Parse with `ConvertFrom-Json`.
   - Validate required fields.
   - Write result with `Write-Result` helper.

2. Add an entry to `mcp_local/tool_registry.json`:
   ```json
   {
     "tool_name": "my_new_tool",
     "description": "What it does.",
     "script": "My-NewTool.ps1",
     "input": { "field_name": "string (required)" },
     "output": { "ok": "bool", "..." : "..." }
   }
   ```

3. Test:
   ```powershell
   pwsh -File mcp_local/Invoke-McpHost.ps1 -Tool my_new_tool -InputJson '{"field_name":"value"}'
   ```

---

## Deferred / Stubbed (Not in This PR)

| Feature | Status | Notes |
|---------|--------|-------|
| Heartbeat / autonomous loop | **Deferred** | Spec in `docs/MCP_ARRAY_FLOW_SPEC.md`. Not safe to implement before document tooling is solid. |
| Auto-reprompt on tool output | **Deferred** | Requires loop runner. Spec defined; implementation follows after this foundation. |
| PDF full-text extraction | **Stub** | `get_document_page` returns file path for PDF. Extend with iTextSharp or similar (no Python). |
| XML sidecar population for all files | **Partial** | `get_xml_object` writes stubs. Bulk population is a separate pass. |
| Reflection / long-term memory indexing | **Deferred** | `HubStation/Reflections.psm1` handles this; integrate after runner is live. |
| Archangels integration | **Deferred** | Runner/skeleton pattern from that repo feeds into the loop layer, not this tool layer. |

---

## Relationship to HubStation

`HubStation/HubStation.ps1` is a persistent local HTTP hub that bridges model
calls to local services. The MCP tool layer built here is **separate** and
**simpler**:

- HubStation = persistent hub with HTTP listener, TTS, Gemini integration.
- MCP tools = discrete, stateless, callable-by-name document tools.

When the loop/runner layer is added, it will call `Invoke-McpHost.ps1` which
dispatches to these tools — and HubStation can be one of the services the
runner bridges to.

---

## Citation Format Reference

```
ecf[<document_no>]page[<page_no>]
```

Examples:
- `ecf[13]page[2]` → ECF document 13, page 2
- `ecf[35-10]page[1]` → ECF document 35-10 (exhibit 10 of document 35), page 1

Alternative with explicit filing source:
```
[<filing_source>][<document_no>]page[<page_no>]
```
