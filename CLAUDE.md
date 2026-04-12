# distill-anything

Personal Context Management system — continuously record life data (audio, photo, video, text), distill into actionable knowledge.

<!-- auto-harness:begin -->
## North-star targets

1. **Data reliability** — zero data loss rate (target: 100% upload success)
   Measure: automated script comparing client record count vs server received count

2. **Client stability** — long-running without crash (target: 24h+ no ANR/crash)
   Measure: `adb logcat` crash monitoring on Android emulator

3. **Conversion quality** — raw records to Obsidian notes information retention
   Measure: agent evaluation (structured scoring 1-10)

Secondary criterion: **Simplicity** — when two approaches yield similar results, prefer less code.

## Project conventions

- **Monorepo structure**: `client/` (Flutter) + `server/` (Python)
- **Package manager**: Flutter (pub), Python (uv)
- **Client language**: Dart (Flutter)
- **Server language**: Python
- **Code quality**: `flutter analyze`, `ruff check`, `mypy`
- **Testing**: `flutter test`, `pytest`
- **Build verification**: `flutter build apk`
- **Output format**: Obsidian-compatible Markdown (for knowledge base)
- **UX testing**: Android emulator + adb debugging
- **Privacy**: self-hosted, all data stays on user's own infrastructure

## Observation setup

### Script checks (automated)
- Data integrity — checksum verification after upload (client vs server)
- Flutter static analysis — `flutter analyze`
- Python lint — `ruff check src/` + `mypy src/`
- Flutter tests — `flutter test`
- Python tests — `pytest`
- Build success — `flutter build apk`

### Agent checks (periodic)
- Knowledge base conversion quality — evaluate raw record -> Obsidian markdown accuracy and structure
- API design review — RESTful consistency, extensibility, naming conventions

### Human checks (escalate)
- UX experience — verify interaction fluency via Android emulator + adb

## Active skills

- dev-loop — complete dev cycle: implement -> test -> verify -> review -> measure -> keep/discard
- north-star — quantifiable optimization targets with observation mechanisms
- long-horizon — autonomous decision-making framework with escalation ladder
- new-project — spec-driven development for greenfield projects
<!-- auto-harness:end -->
