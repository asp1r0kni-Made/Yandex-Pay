"""
Сплит Банк — единый backend-файл (демо/учебный проект).

Технологии: FastAPI + SQLite (всё в одном файле, без внешней БД).
Функции:
  - регистрация по номеру телефона
  - подтверждение кода (в деморежиме код просто возвращается в ответе,
    т.к. бесплатного SMS-провайдера из коробки нет — подключите свой,
    см. функцию send_sms_code ниже)
  - вход по номеру + коду, выдача JWT-токена
  - выпуск виртуальной демо-карты (НЕ настоящий платёжный инструмент!
    для реального выпуска карт нужна банковская лицензия и партнёр-эквайер)
  - получение списка карт пользователя

Запуск:
    pip install -r requirements.txt
    uvicorn app:app --host 0.0.0.0 --port 8000

Это ОДИН файл — база данных splitbank.db создастся автоматически рядом.
"""

import os
import random
import sqlite3
import string
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Конфигурация
# ---------------------------------------------------------------------------

DB_PATH = os.environ.get("SPLITBANK_DB", "splitbank.db")
JWT_SECRET = os.environ.get("SPLITBANK_JWT_SECRET", "change-me-in-production")
JWT_ALGORITHM = "HS256"
TOKEN_TTL_HOURS = 24 * 30
CODE_TTL_MINUTES = 5

app = FastAPI(title="Сплит Банк API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# База данных
# ---------------------------------------------------------------------------


@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db():
    with get_db() as db:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                phone TEXT UNIQUE NOT NULL,
                full_name TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS auth_codes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                phone TEXT NOT NULL,
                code TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                used INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS cards (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id),
                card_number TEXT NOT NULL,
                expiry TEXT NOT NULL,
                cvv TEXT NOT NULL,
                label TEXT NOT NULL DEFAULT 'Цифровая карта',
                balance_kopeks INTEGER NOT NULL DEFAULT 0,
                frozen INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            )
            """
        )


init_db()

# ---------------------------------------------------------------------------
# Утилиты
# ---------------------------------------------------------------------------


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def gen_code() -> str:
    return "".join(random.choices(string.digits, k=4))


def send_sms_code(phone: str, code: str):
    """
    Заглушка отправки SMS. Подключите сюда своего провайдера
    (например, SMS Aero, SMSC.ru, Twilio и т.д.) — вызов их HTTP API.
    Пока что просто логируем в консоль.
    """
    print(f"[SMS-DEMO] Код для {phone}: {code}")


def create_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(hours=TOKEN_TTL_HOURS),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def get_current_user(authorization: str = Header(default="")) -> sqlite3.Row:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Нет токена авторизации")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Невалидный или истёкший токен")
    user_id = int(payload["sub"])
    with get_db() as db:
        row = db.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="Пользователь не найден")
    return row


def gen_card_number() -> str:
    # Демо-номер карты (не привязан к настоящей платёжной сети)
    return "22" + "".join(random.choices(string.digits, k=14))


def gen_cvv() -> str:
    return "".join(random.choices(string.digits, k=3))


def gen_expiry() -> str:
    dt = datetime.now() + timedelta(days=365 * 4)
    return dt.strftime("%m/%y")


# ---------------------------------------------------------------------------
# Схемы запросов/ответов
# ---------------------------------------------------------------------------


class RegisterRequest(BaseModel):
    phone: str = Field(..., examples=["+79990000000"])
    full_name: str | None = None


class VerifyCodeRequest(BaseModel):
    phone: str
    code: str


class RequestCodeRequest(BaseModel):
    phone: str


class IssueCardRequest(BaseModel):
    label: str | None = "Цифровая карта"


# ---------------------------------------------------------------------------
# Эндпоинты: регистрация и вход
# ---------------------------------------------------------------------------


@app.post("/auth/register")
def register(req: RegisterRequest):
    with get_db() as db:
        existing = db.execute(
            "SELECT id FROM users WHERE phone = ?", (req.phone,)
        ).fetchone()
        if existing is None:
            db.execute(
                "INSERT INTO users (phone, full_name, created_at) VALUES (?, ?, ?)",
                (req.phone, req.full_name, now_iso()),
            )

    code = gen_code()
    expires = (datetime.now(timezone.utc) + timedelta(minutes=CODE_TTL_MINUTES)).isoformat()
    with get_db() as db:
        db.execute(
            "INSERT INTO auth_codes (phone, code, expires_at, used) VALUES (?, ?, ?, 0)",
            (req.phone, code, expires),
        )
    send_sms_code(req.phone, code)

    return {
        "status": "code_sent",
        "message": "Код отправлен (в деморежиме см. поле debug_code)",
        # В проде это поле нужно убрать — оно только для локальной разработки!
        "debug_code": code,
    }


@app.post("/auth/request-code")
def request_code(req: RequestCodeRequest):
    with get_db() as db:
        user = db.execute(
            "SELECT id FROM users WHERE phone = ?", (req.phone,)
        ).fetchone()
    if user is None:
        raise HTTPException(status_code=404, detail="Пользователь не зарегистрирован")

    code = gen_code()
    expires = (datetime.now(timezone.utc) + timedelta(minutes=CODE_TTL_MINUTES)).isoformat()
    with get_db() as db:
        db.execute(
            "INSERT INTO auth_codes (phone, code, expires_at, used) VALUES (?, ?, ?, 0)",
            (req.phone, code, expires),
        )
    send_sms_code(req.phone, code)
    return {"status": "code_sent", "debug_code": code}


@app.post("/auth/verify")
def verify_code(req: VerifyCodeRequest):
    with get_db() as db:
        row = db.execute(
            """
            SELECT * FROM auth_codes
            WHERE phone = ? AND code = ? AND used = 0
            ORDER BY id DESC LIMIT 1
            """,
            (req.phone, req.code),
        ).fetchone()

        if row is None:
            raise HTTPException(status_code=400, detail="Неверный код")

        expires_at = datetime.fromisoformat(row["expires_at"])
        if datetime.now(timezone.utc) > expires_at:
            raise HTTPException(status_code=400, detail="Код истёк, запросите новый")

        db.execute("UPDATE auth_codes SET used = 1 WHERE id = ?", (row["id"],))

        user = db.execute(
            "SELECT * FROM users WHERE phone = ?", (req.phone,)
        ).fetchone()
        if user is None:
            raise HTTPException(status_code=404, detail="Пользователь не найден")

    token = create_token(user["id"])
    return {
        "status": "ok",
        "token": token,
        "user": {"id": user["id"], "phone": user["phone"], "full_name": user["full_name"]},
    }


@app.get("/me")
def me(user: sqlite3.Row = Depends(get_current_user)):
    return {"id": user["id"], "phone": user["phone"], "full_name": user["full_name"]}


# ---------------------------------------------------------------------------
# Эндпоинты: карты
# ---------------------------------------------------------------------------


@app.get("/cards")
def list_cards(user: sqlite3.Row = Depends(get_current_user)):
    with get_db() as db:
        rows = db.execute(
            "SELECT * FROM cards WHERE user_id = ? ORDER BY id DESC", (user["id"],)
        ).fetchall()
    return [
        {
            "id": r["id"],
            "label": r["label"],
            "card_number": r["card_number"],
            "masked_number": "•••• " + r["card_number"][-4:],
            "expiry": r["expiry"],
            "cvv": r["cvv"],
            "balance": r["balance_kopeks"] / 100,
            "frozen": bool(r["frozen"]),
        }
        for r in rows
    ]


@app.post("/cards/issue")
def issue_card(req: IssueCardRequest, user: sqlite3.Row = Depends(get_current_user)):
    card_number = gen_card_number()
    expiry = gen_expiry()
    cvv = gen_cvv()
    with get_db() as db:
        cur = db.execute(
            """
            INSERT INTO cards (user_id, card_number, expiry, cvv, label, balance_kopeks, created_at)
            VALUES (?, ?, ?, ?, ?, 0, ?)
            """,
            (user["id"], card_number, expiry, cvv, req.label or "Цифровая карта", now_iso()),
        )
        card_id = cur.lastrowid
    return {
        "id": card_id,
        "label": req.label or "Цифровая карта",
        "card_number": card_number,
        "expiry": expiry,
        "cvv": cvv,
        "balance": 0,
        "frozen": False,
    }


@app.post("/cards/{card_id}/freeze")
def freeze_card(card_id: int, user: sqlite3.Row = Depends(get_current_user)):
    with get_db() as db:
        row = db.execute(
            "SELECT * FROM cards WHERE id = ? AND user_id = ?", (card_id, user["id"])
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="Карта не найдена")
        new_state = 0 if row["frozen"] else 1
        db.execute("UPDATE cards SET frozen = ? WHERE id = ?", (new_state, card_id))
    return {"id": card_id, "frozen": bool(new_state)}


@app.get("/health")
def health():
    return {"status": "ok", "time": now_iso()}


# ---------------------------------------------------------------------------
# Точка входа для локального запуска: python app.py
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
