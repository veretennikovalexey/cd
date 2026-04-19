# Chess Debut Trainer — Project Memory

## What is this project

A fully static single-page chess opening recorder.
No server, no Python, no database — opens directly in the browser.

---

## File structure

```
cd/
├── index.html                  ← everything: HTML + CSS + JS in one file
├── memory.md                   ← this file
└── img/
    └── chesspieces/
        └── wikipedia/
            ├── wP.png  wR.png  wN.png  wB.png  wQ.png  wK.png
            └── bP.png  bR.png  bN.png  bB.png  bQ.png  bK.png
```

---

## Libraries (CDN, no local files)

| Library | Version | Purpose |
|---|---|---|
| jQuery | 3.7.1 | required by chessboard.js |
| chess.js | 0.10.3 | move validation, SAN/FEN |
| chessboard.js | 1.0.0 | board rendering, drag&drop |

---

## Storage — localStorage

Key: `'chess_debut_moves'`

Format — JSON array of move objects:
```json
[
  {
    "move_number": 1,
    "color": "white",
    "move_san": "e4",
    "move_uci": "e2e4",
    "fen_before": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "fen_after":  "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
  }
]
```

localStorage helpers:
- `loadMoves()` — read array from storage
- `saveMoves(arr)` — write array to storage
- `appendMove(obj)` — push one move and persist
- `deleteMovesFrom(index)` — slice to index and persist
- `clearAllMoves()` — remove key entirely

---

## JS state variables

```js
let board       = null;   // chessboard.js instance
let game        = null;   // chess.js instance
let savedMoves  = [];     // in-memory mirror of localStorage
let currentIdx  = -1;     // index into savedMoves (-1 = start position)
let isReviewing = false;  // true = browsing history, drag&drop blocked
```

---

## UI — buttons and keyboard

| Button | Keyboard | Action |
|---|---|---|
| ↺ Повернуть | — | flip board |
| ← Отменить | — | recording mode: delete last move; review mode: step back |
| → Повторить | — | step forward in review mode |
| ✕ Очистить | — | clear all moves from localStorage |
| ⏮ | — | go to start position |
| ◀ | ← Arrow | step back one move (never deletes) |
| ▶ | → Arrow | step forward one move |
| ⏭ | — | go to last saved move |

Clicking any move in the history panel jumps to that position.

### stepBack / stepForward vs undoMove

- `stepBack` / `stepForward` — pure navigation, **never delete** moves from storage
- `undoMove` (← Отменить) — in recording mode **permanently deletes** the last move

---

## pieceTheme path

```js
pieceTheme: 'img/chesspieces/wikipedia/{piece}.png'
```

Relative path — works when opened as `file://` locally or hosted on GitHub Pages.

---

## How to open

Double-click `index.html` in the browser. No server needed.

## How to publish on GitHub Pages

Push the folder to a GitHub repo, enable Pages from the repo settings — done.

---

## History

1. Initially built as Flask + SQLite app (app.py, database.py, templates/)
2. Converted to fully static site for GitHub Pages — all Python files deleted
3. Chess piece PNGs downloaded from chessboardjs.com into `img/chesspieces/wikipedia/`
4. Added ◀ / ▶ step navigation buttons and ArrowLeft / ArrowRight keyboard shortcuts
