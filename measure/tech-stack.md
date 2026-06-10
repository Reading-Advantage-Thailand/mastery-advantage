# Tech Stack - Mastery Advantage

## Repository Role

This is a specification, source-data, graph-generation, validation, and static
visualization repository. It does not currently contain a deployed application
runtime.

## Active Tooling

| Layer | Technology | Purpose |
|---|---|---|
| Graph generation | Node.js 22, CommonJS JavaScript | Deterministic source extraction and JSON generation |
| Source extraction | Poppler `pdftotext`, `pdfinfo` | Read and validate locally cached reference PDFs |
| Graph artifacts | JSON | Canonical nodes, edges, provenance, and metadata |
| Source mappings | CSV, Markdown, JSON | Human-readable and generated domain data |
| Visualization | Static HTML, D3, SVG | Graph exploration and marketing assets |
| Documentation | Markdown | Normative specification and implementation planning |
| Hosting | GitHub Pages | Static marketing-asset gallery |

## Planned Vocabulary-Graph Enrichment Tools

Tools may be added only after their license, reproducibility, versioning, and
artifact-size implications are documented:

- Corpus frequency provider such as `wordfreq`.
- WordNet-compatible lexical-semantic data and APIs.
- fastText or equivalent embedding model for sparse similarity candidates.
- ConceptNet or equivalent broad semantic-relatedness source.
- Test runner and schema validator appropriate for generator regression tests.

## Constraints

- Publisher PDFs remain a local, Git-ignored source cache.
- Tracked graph artifacts must be reproducible from documented inputs.
- Derived edges require source/model version, derivation method, confidence,
  and review status.
- The domain graph must conform to `SPECIFICATION.md`.
- Application-specific persistence and runtime adapters belong in consuming
  application repositories.
