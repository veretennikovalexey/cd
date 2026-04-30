# CLAUDE.md — Chess Debut Trainer

This file gives Claude the context needed to work on this project effectively.

## What this project is

A **single-page chess opening (debut) trainer** that runs entirely in the browser. The user (a Russian-speaking chess enthusiast named Alex) uses it to practice and review chess openings. The UI is in Russian; code comments are in Russian.

The whole app is a **single static HTML file** (`index.html`) — no build step, no bundler, no server-side code. It can be opened directly via `file://` or served from any static HTTP server.

## Tech stack

- **Vanilla JavaScript** — no framework, no TypeScript, no bundler.
- **jQuery 3.7.1** (CDN) — only because chessboard.js requires it.
- **chess.js 0.10.3** (CDN) — game logic, legal move validation, FEN/PGN parsing.
- **chessboard.js 1.0.0** (CDN, by Chris Oakman) — board rendering and drag-and-drop.
- **Stockfish (asm.js build)** — bundled locally at `engine/stockfish.asm.js` (~957 KB), runs in a Web Worker, communicates over UCI. No internet required for the engine.
- **localStorage** — persists the current game (moves array) and current debut name across reloads.

The CDN scripts are referenced inline in `index.html`; everything else (engine, piece images, icons) is local.

## File layout

```
index.html              # The whole app (HTML + CSS + JS, ~1200 lines)
sd.json                 # User's saved debuts library: { "debuts": [{name, pgn}, ...] }
engine/
  stockfish.asm.js      # Stockfish chess engine, asm.js build, runs in Web Worker
img/
  chesspieces/wikipedia/{wK,wQ,...,bK,bQ,...}.png   # Piece sprites
  icons/{home,flip,undo,redo,clear,save,load,start,step-back,step-fwd,end}.png
run.cmd                 # Windows: starts `python -m http.server 8000` and opens browser
pp.cmd                  # Windows: git pull/add/commit -m alex/push convenience script
.git/                   # Git repo (remote: origin/main)
```

There is no `package.json`, no `node_modules`, no build artifacts. Editing `index.html` directly is the workflow.

## Running it

The user runs `run.cmd` on Windows, which starts a local Python HTTP server on port 8000 and opens `http://localhost:8000/index.html` in the default browser. A local server is needed (rather than `file://`) because:
- The Web Worker for Stockfish is loaded from a relative path and `file://` Worker policies vary by browser.
- `fetch('sd.json')` is blocked in Chrome/Edge under `file://`.
- The app has a fallback file-picker for `sd.json` when fetch fails, but the engine still needs the server to start reliably.

To deploy/sync, the user runs `pp.cmd` which does a `git pull && git add . && git commit -m alex && git push origin main`. Author identity is hardcoded in `pp.cmd` to `veretennikovalexey / raidex@yandex.ru`.

## Application architecture

Everything lives inside one `<script>` block at the bottom of `index.html`. Logical sections (in order):

1. **localStorage helpers** — `loadMoves`, `saveMoves`, `appendMove`, `deleteMovesFrom`, `clearAllMoves`, `saveDebutName`, `loadDebutName`, `applyDebutName`. Two keys: `chess_debut_moves` (JSON array) and `chess_debut_name` (string).
2. **State** — module-level vars: `board` (chessboard.js instance), `game` (chess.js instance), `savedMoves` (array), `currentIdx`, `isReviewing`, `currentDebutName`.
3. **Eval layer A — material + piece-square tables** — `PST_*` arrays, `PIECE_VAL`, `evaluatePosition()`. Returns `{ score, label, isMate }` from White's perspective. Index convention: `0 = a8 ... 63 = h1`; for Black pieces the PST index is mirrored via `idx ^ 56`.
4. **Eval bar rendering** — `renderEvalBar(score, label)`, `updateEvalBar()`. The bar is a vertical strip left of the board; its fill height is proportional to White's advantage, clamped to ±5 pawns. Flips when board orientation flips.
5. **Eval layer B — Stockfish** — `initEngine`, `handleEngineLine`, `parseInfoLine`, `requestEngineEval`, `sendNextSearch`. Layer A renders instantly on every move; if Stockfish is ready, layer B is also asked to evaluate and overwrites the bar with deeper analysis as `info` lines stream in. Mode indicator badge in the header shows `A` (loading or failed) or `B` (Stockfish active).
6. **Move list** — `renderMoveList` builds rows of `move-num | white-move | black-move`; clicking a move jumps to that position.
7. **Navigation** — `goToMove`, `goToStart`, `goToEnd`, `stepBack`, `stepForward`, plus `undoMove` / `redoMove`. `stepBack` / `stepForward` never delete moves; `undoMove` deletes the last move only when in recording mode (cursor at the end). Arrow keys ←/→ are bound to step-back / step-forward.
8. **chessboard.js callbacks** — `onDragStart`, `onDrop`, `onSnapEnd`. Drops are validated by chess.js; if illegal, returns `'snapback'`. Auto-promotes pawns to queen.
9. **PGN import/export** — `savePGN` (uses `chess.js .pgn()`), `loadPGN` (uses `.load_pgn()` then re-plays each move to rebuild `savedMoves`).
10. **Saved debuts modal** (`btn-home` / "домик" button) — `openDebutsList` tries `fetch('sd.json')`; on failure (e.g. file:// in Chrome) falls back to a manual file picker. `renderDebutList` shows names only; clicking loads via `loadDebutFromList` → `loadPGN`.

## Key conventions and gotchas

- **All UI strings and code comments are in Russian.** Keep that language when editing existing parts; new internal helpers can be in English if not user-facing.
- **Two evaluation layers run in parallel.** Layer A is instant and always available (used as a fallback and as the immediate first paint). Layer B (Stockfish) overwrites it once analysis arrives.
- **UCI score sign convention** — engine returns score from the side-to-move's perspective. `parseInfoLine` normalizes to White's perspective using `sideMul = (turnChar === 'w') ? 1 : -1`.
- **Stockfish search depth is one constant** — `ENGINE_DEPTH` (line ~592). Currently `14`. Sent to engine as `go depth N`. Increasing it makes evaluations stronger but slower; the asm.js build is significantly slower than native/WASM Stockfish, so don't push it too high.
- **Search cancellation** — when a new position arrives mid-search, code sends `stop` to the engine and queues the new FEN in `pendingFen`; the next search starts on `bestmove`.
- **Promotion is hardcoded to queen** in `onDrop` — there's no UI for under-promotion.
- **`localStorage` is the only persistence.** `clear` button wipes both keys after a `confirm()` prompt.
- **`sd.json` format** supports two move encodings per entry: `"pgn": "1. e4 e5 ..."` (preferred, easier to edit) or `"moves": ["e4", "e5", ...]` (SAN array). `loadDebutFromList` handles both.
- **Mobile breakpoint at 700px** — board area stacks vertically; board width becomes `calc(100% - 28px)` to leave room for the eval bar.

## Editing playbook

- **Tweaking engine settings (depth, time, threads, hash):** modify `ENGINE_DEPTH` and/or the `go ...` command in `sendNextSearch`. UCI options (e.g. `setoption name Hash value 256`) should be sent right after `uciok` in `handleEngineLine` before `isready`.
- **Adding a new toolbar button:** add to `<div class="controls">`, place an icon under `img/icons/`, wire up the listener inside `init()`.
- **Adding a new debut:** append to `sd.json`'s `debuts` array. Editor-friendly formatting is encouraged — the user reads/edits this file by hand.
- **Changing piece set:** drop new PNGs into `img/chesspieces/<theme>/` and update `pieceTheme` in the chessboard config.
- **Changing colors / theme:** the palette is dark blue (`#1a1a2e`, `#16213e`, `#0f3460`) with gold accent (`#e2b96f`); search and replace if rebranding.

## What this project is NOT

- Not a server-side app. No backend, no API, no database.
- Not a build-tooled project. Don't introduce webpack/vite/npm — keep it a single editable HTML file unless explicitly asked.
- Not a chess-playing app — Stockfish only evaluates positions; it does not propose or play moves against the user. The user enters both sides' moves themselves to study openings.

## User preferences (Alex)

- Prefers Russian responses with informal "ты" address.
- Prefers to discuss changes before they are made — when asked to "посмотреть" / "look at" something, do not edit yet; explain first, wait for the go-ahead.
- Works on Windows. Paths in scripts use Windows `cmd` conventions.
