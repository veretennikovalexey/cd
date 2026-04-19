# План разработки: Chess Debut Trainer
**Локальный веб-сервер для изучения шахматного дебюта**

---

## Стек технологий

| Компонент | Решение |
|---|---|
| Backend | Python + Flask |
| Frontend | HTML + CSS + JavaScript |
| Шахматная логика | chess.js (JS-библиотека) |
| Анимация фигур | chessboard.js (готовый движок) |
| Хранение ходов | SQLite (через Flask + sqlite3) |
| Изображения фигур | Встроенный набор в chessboard.js (стиль Wikipedia / чёрно-белый классический) |

---

## Структура проекта

```
cd/
├── app.py                  # Flask-сервер, API-эндпоинты
├── database.py             # Работа с SQLite
├── chess_debut.db          # База данных с ходами (создаётся автоматически)
├── requirements.txt        # Flask, flask-cors
├── static/
│   ├── css/
│   │   └── style.css       # Стили страницы
│   ├── js/
│   │   ├── main.js         # Основная логика приложения
│   │   └── libs/
│   │       ├── chess.min.js        # Шахматная логика (валидация ходов)
│   │       ├── chessboard.min.js   # Рендер доски + анимация
│   │       └── chessboard.min.css  # Стили доски
│   └── img/
│       └── chesspieces/    # Спрайты фигур (подтягиваются из CDN chessboard.js)
└── templates/
    └── index.html          # Главная страница
```

---

## Шаг 1 — Настройка окружения

```bash
# Создать виртуальное окружение
python -m venv venv
venv\Scripts\activate          # Windows
source venv/bin/activate       # Linux/Mac

# Установить зависимости
pip install flask flask-cors

# Создать requirements.txt
pip freeze > requirements.txt
```

---

## Шаг 2 — База данных (database.py)

**Таблица `moves`:**

| Поле | Тип | Описание |
|---|---|---|
| id | INTEGER PRIMARY KEY | Автоинкремент |
| move_number | INTEGER | Номер хода (1, 2, 3...) |
| color | TEXT | 'white' или 'black' |
| move_san | TEXT | Ход в нотации SAN (e4, Nf3, O-O...) |
| move_uci | TEXT | Ход в UCI-нотации (e2e4, g1f3...) |
| fen_before | TEXT | Позиция ДО хода (FEN-строка) |
| fen_after | TEXT | Позиция ПОСЛЕ хода (FEN-строка) |
| created_at | TIMESTAMP | Время записи |

**Функции:**
- `init_db()` — создать таблицу если не существует
- `save_move(move_number, color, san, uci, fen_before, fen_after)` — сохранить ход
- `get_all_moves()` — получить все ходы в порядке id
- `delete_moves_from(move_index)` — удалить ходы начиная с индекса (для отмены)
- `clear_all_moves()` — очистить всю партию

---

## Шаг 3 — Flask Backend (app.py)

**API-эндпоинты:**

| Метод | URL | Действие |
|---|---|---|
| GET | `/` | Отдать index.html |
| GET | `/api/moves` | Получить все сохранённые ходы |
| POST | `/api/moves` | Сохранить новый ход |
| DELETE | `/api/moves/<int:from_id>` | Удалить ходы начиная с id (отмена) |
| DELETE | `/api/moves/all` | Очистить всю партию |

**Формат POST /api/moves (JSON):**
```json
{
  "move_number": 1,
  "color": "white",
  "move_san": "e4",
  "move_uci": "e2e4",
  "fen_before": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "fen_after":  "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
}
```

---

## Шаг 4 — Frontend (index.html + main.js)

### Макет страницы

```
+------------------------------------------+-------------------+
|  [↺ Повернуть] [← Отменить] [→ Повторить]                    |
|                                           |  История ходов    |
|     A  B  C  D  E  F  G  H               |  ─────────────    |
|  8 [  ][  ][  ][  ][  ][  ][  ][  ]  8  |  1. e4    e5      |
|  7 [  ][  ][  ][  ][  ][  ][  ][  ]  7  |  2. Nf3   Nc6     |
|  ...                                     |  3. ...           |
|  1 [  ][  ][  ][  ][  ][  ][  ][  ]  1  |  ─────────────    |
|     A  B  C  D  E  F  G  H               |  [⏮ Начало]       |
|                                           |  [⏭ Конец]        |
+------------------------------------------+-------------------+
```

### Используемые библиотеки (CDN)

```html
<!-- chess.js — валидация ходов, генерация SAN -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/chess.js/0.10.3/chess.min.js"></script>

<!-- chessboard.js — визуализация + анимация drag&drop -->
<link  rel="stylesheet" href="https://unpkg.com/@chrisoakman/chessboardjs@1.0.0/dist/chessboard-1.0.0.min.css">
<script src="https://unpkg.com/@chrisoakman/chessboardjs@1.0.0/dist/chessboard-1.0.0.min.js"></script>

<!-- jQuery (нужен для chessboard.js) -->
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
```

---

## Шаг 5 — Логика JavaScript (main.js)

### Переменные состояния

```javascript
let board       = null;   // экземпляр chessboard.js
let game        = null;   // экземпляр chess.js
let savedMoves  = [];     // массив ходов из БД
let currentIdx  = -1;     // текущая позиция в истории (-1 = начало)
let isReviewing = false;  // режим просмотра (не запись)
```

### Инициализация при загрузке страницы

1. Создать `game = new Chess()` — начальная позиция
2. Создать `board = Chessboard('board', config)` с параметрами:
   - `draggable: true`
   - `onDragStart` — проверить что ход разрешён (не режим просмотра)
   - `onDrop` — применить ход через chess.js, сохранить в БД
   - `onSnapEnd` — синхронизировать позицию доски
3. Загрузить ходы с `/api/moves`
4. Отрисовать таблицу ходов справа

### Функции кнопок

| Кнопка | Функция | Поведение |
|---|---|---|
| ↺ Повернуть | `flipBoard()` | `board.flip()` |
| ← Отменить ход | `undoMove()` | Если не в режиме просмотра: удалить последний ход из БД и отменить в game; Если в режиме просмотра: `currentIdx--`, загрузить FEN |
| → Повторить ход | `redoMove()` | Только в режиме просмотра: `currentIdx++`, применить следующий сохранённый ход |
| ⏮ В начало | `goToStart()` | Загрузить начальную позицию FEN, `currentIdx = -1`, `isReviewing = true` |
| ⏭ В конец | `goToEnd()` | Загрузить последний FEN из savedMoves, `currentIdx = savedMoves.length - 1`, `isReviewing = false` |

### Режимы работы

**Режим записи** (`isReviewing = false`, `currentIdx === savedMoves.length - 1`):
- Пользователь делает ходы drag&drop
- Каждый ход сохраняется в БД
- Таблица ходов обновляется

**Режим просмотра** (`isReviewing = true` или `currentIdx < savedMoves.length - 1`):
- Drag&drop заблокирован
- Кнопки ← / → перемещают по сохранённым ходам
- Позиция берётся из поля `fen_before` / `fen_after` сохранённых ходов

---

## Шаг 6 — Таблица ходов (правая панель)

- Отображать ходы парами: `1. e4 e5`, `2. Nf3 Nc6`
- Текущий активный ход подсвечивать (CSS-класс `.active-move`)
- Клик по ходу в таблице = перейти к этой позиции
- Прокрутка таблицы автоматически следует за последним ходом

```html
<div id="move-list">
  <div class="move-row active" data-idx="1">
    <span class="move-num">1.</span>
    <span class="move white" data-idx="0">e4</span>
    <span class="move black" data-idx="1">e5</span>
  </div>
  ...
</div>
```

---

## Шаг 7 — Разметка доски (координаты)

chessboard.js автоматически рисует координаты A-H и 1-8 при настройке:
```javascript
const config = {
  showNotation: true,   // включить координаты
  ...
}
```

При повороте доски координаты переворачиваются автоматически.

---

## Шаг 8 — Запуск

```bash
# Активировать venv, затем:
python app.py

# Открыть в браузере:
# http://localhost:5000
```

---

## Шаг 9 — Финальная проверка (чеклист)

- [ ] Доска рендерится на localhost:5000
- [ ] Фигуры отображаются корректно
- [ ] Координаты A-H и 1-8 видны
- [ ] Ход белых при старте
- [ ] Drag&drop работает (только легальные ходы через chess.js)
- [ ] Ходы сохраняются в SQLite после каждого хода
- [ ] История ходов отображается справа (парами)
- [ ] Кнопка ↺ Повернуть работает
- [ ] Кнопка ← Отменить работает (и удаляет из БД)
- [ ] Кнопка → Повторить работает в режиме просмотра
- [ ] Кнопка ⏮ Начало — начальная позиция
- [ ] Кнопка ⏭ Конец — последний сохранённый ход
- [ ] При перезапуске сервера: начальная позиция + загрузка сохранённых ходов из БД
- [ ] Клик по ходу в таблице переходит к позиции

---

## Возможные расширения (по желанию)

- Экспорт партии в PGN-файл
- Подсветка легальных ходов при выборе фигуры
- Звук при ходе / взятии
- Отображение имени дебюта (из ECO-кодов)
- Таймер
