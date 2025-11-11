# Evidence Card UID Scheme

## Overview

The UID (Unique Identifier) scheme is a compact, hierarchical system for identifying and organizing Evidence Cards in the CourtRoom Masterpiece system.

Each UID encodes:
- **Claim number** (which civil rights violation)
- **Element number** (which legal element of that claim)
- **Defendant number** (which defendant's actions)
- **Evidence variant letter** (optional, for chronological evidence sequencing)

## Format

```
[Claim][Element][Defendant][Letter]
```

- **3-digit UIDs**: `[C][E][D]`
- **4-digit UIDs**: `[C][E][S][D]` (S = sub-element)
- **Letter suffix**: A, B, C... for chronological evidence variants

## Examples

| UID   | Claim | Element | Sub-Element | Defendant | Evidence | Meaning |
|-------|-------|---------|-------------|-----------|----------|---------|
| 111   | 1     | 1       | -           | 1         | -        | First claim, first element, first defendant |
| 112   | 1     | 1       | -           | 2         | -        | Same claim/element, second defendant |
| 245B  | 2     | 4       | -           | 5         | B        | Second claim, fourth element, fifth defendant, second evidence variant |
| 1234A | 1     | 2       | 3           | 4         | A        | First claim, second element, sub-element 3, fourth defendant, first evidence |

## Claims

| Number | Claim Description |
|--------|-------------------|
| 1      | Unlawful Detention |
| 2      | Excessive Force |
| 3      | False Arrest |
| 4      | Malicious Prosecution |
| 5      | Retaliation |
| ... | (expand as needed) |

## Elements (Example for Claim 1: Unlawful Detention)

| Number | Element Description |
|--------|---------------------|
| 1      | Under color of law |
| 2      | Intentional restraint |
| 3      | Without consent |
| 4      | Without lawful authority |
| 5      | Without probable cause |
| ... | (add more per claim) |

## Defendants

| Number | Defendant Name |
|--------|----------------|
| 1      | Dana Gunnarson |
| 2      | Catlin Blyth |
| 3      | John Doe Officer |
| ... | (expand as needed) |

## Evidence Variants (Letter Suffix)

When multiple pieces of evidence support the **same claim/element/defendant combination**, append a letter:

- **111A**: First piece of evidence for Claim 1, Element 1, Defendant 1
- **111B**: Second piece of evidence for same
- **111C**: Third piece of evidence

### Important Distinction

- **UID without letter**: The **event** that satisfied the element
- **UID with letter**: The **evidence** that proves that event

Example:
- **245** → "On 2024-05-15, Defendant 5 used pepper spray without warning (Event)"
- **245A** → "Body camera footage timestamp 14:32:15 (Evidence)"
- **245B** → "Witness statement from bystander (Evidence)"

## Directory Structure

Evidence Cards are stored hierarchically:

```
shared_bus/evidence_cards/
├── claim_1/
│   ├── element_1/
│   │   ├── defendant_1/
│   │   │   ├── 111.json
│   │   │   ├── 111A.json
│   │   │   └── 111B.json
│   │   └── defendant_2/
│   │       └── 112.json
│   └── element_2/
│       └── ...
├── claim_2/
│   └── ...
└── index.json (master index mapping UID → file path)
```

## Parsing Rules

1. **Detect UID**: Scan for pattern `^\[(\d{3,4})([A-Z]?)\]`
2. **Extract digits**:
   - 3 digits: `[Claim][Element][Defendant]`
   - 4 digits: `[Claim][Element][SubElement][Defendant]`
3. **Extract letter** (if present): Evidence variant A-Z
4. **Validate**: All numbers must be 1-9 (no zeros)

## Integration with Gemini

When Gemini produces multiple Evidence Cards in one response:
1. Each card starts with its UID: `[XXX]` or `[XXXX]`
2. The system splits the response at UID boundaries
3. Each card is saved as `{UID}.json` in the appropriate directory
4. The master `index.json` is updated with the mapping

## Searchability

### By Meta Tags
Reflection logs include a `meta_tags` column (pipe-separated: `tag1|tag2|tag3`) for quick memory search.

### By UID Components
- Find all evidence for **Claim 2**: search `claim_2/` directory
- Find all evidence for **Defendant 1**: search pattern `1.json` across all paths
- Find all **Element 3** items: search `element_3/` directories

### By Chronological Order
Evidence variants (A, B, C...) represent chronological sequence when multiple pieces of evidence were collected for the same event.

## Future Extensions

- **5-digit UIDs**: Add another dimension (e.g., witness number)
- **Revision suffixes**: `111A_v2.json` for updated analysis
- **Cross-references**: JSON field linking related UIDs
- **Date-based auto-lettering**: Automatically assign A/B/C based on evidence timestamp

## Usage in UI

The main UI (`index.html`) displays evidence cards in pop-ups:
- **Claim selector**: Choose claim number
- **Element selector**: Choose element within that claim
- **Defendant filter**: Show only selected defendant
- **Card detail**: Click UID to open full Evidence Card JSON

## Reflection Integration

Every ~10 model actions, the system performs a reflection and logs:
- **Meta tags**: for finding similar situations
- **Hot rows**: reflection entries are marked for priority review
- **UID linkage**: reflections can reference specific Evidence Cards by UID

This allows the model to learn from past evidence analysis and improve future card generation.
