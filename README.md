# DragonTransfer Mini App

Telegram Mini App для покупки USDT (TRC20) за рубли через DragonTransfer Partner API. Работает и как обычный сайт в браузере — бот на первом этапе не обязателен.

API-ключ хранится только на сервере (`DRAGONTRANSFER_API_KEY`). Во фронтенд он не попадает.

## Стек

Rails 8, PostgreSQL, Faraday, vanilla JS + `telegram-web-app.js`.

## Архитектура

Контроллеры тонкие: сценарии живут в сервисных объектах (`BaseService`, метод `call`), как в `rate_me_telegram`. HTTP к Partner API изолирован в `DragonTransfer::Client`.

| Сервис | Назначение |
| --- | --- |
| `Precalcs::Create` | Расчёт USDT |
| `Rates::Fetch` | Текущий курс |
| `Orders::Create` | Создание заявки и сохранение `id` |
| `Orders::Show` / `Orders::SyncStatus` | Статус через `orders/find` |
| `Webhooks::DragonTransfer::Process` | Проверка `X-Api-Key` и обновление заявки |

## Запуск

Скопируйте переменные окружения и поднимите PostgreSQL вместе с приложением:

```bash
cp .env.example .env
# укажите DRAGONTRANSFER_API_KEY и при необходимости APP_HOST
docker compose up --build
```

Приложение: http://localhost:3000

Локально, если Rails уже установлен на хосте, достаточно базы из Compose:

```bash
docker compose up db -d
bin/setup
bin/rails server
```

`bin/setup` использует `DATABASE_URL` из `.env` (по умолчанию Postgres на порту **5433**).

## Тесты

RSpec в стиле сервисных спецификаций: `subject` / `let` / `context`, инъекция `instance_double` для Partner API.

```bash
docker compose exec web bin/rails db:prepare RAILS_ENV=test
docker compose exec web bundle exec rspec
```

## Переменные

| Переменная | Назначение |
| --- | --- |
| `DRAGONTRANSFER_BASE_URL` | Базовый URL Partner API |
| `DRAGONTRANSFER_API_KEY` | Секрет партнёра, заголовок `X-Api-Key` |
| `APP_HOST` | Публичный URL приложения для `verification_return_url` / `invoice_return_url` |
| `DATABASE_URL` | Подключение к PostgreSQL |

Webhook DragonTransfer: `POST /webhooks/dragon_transfer`. На стороне партнёра нужно указать `https://<ваш-хост>/webhooks/dragon_transfer`. Запрос должен приходить с тем же `X-Api-Key`. Для локальной проверки нужен публичный туннель (ngrok, Cloudflare Tunnel и т.п.) и `APP_HOST` с этим адресом.

Статус заявки обновляется webhook'ом; пока заявка не в `SUCCESS`/`ERROR`, Mini App дополнительно опрашивает `GET /api/orders/:id` (внутри — `orders/find`) каждые 20 секунд.

## Сценарий пользователя

1. Вводит сумму в RUB и видит расчёт USDT (`orders/precalc`).
2. Указывает ФИО, email, телефон и кошелёк TRC20.
3. Сервер создаёт заявку (`orders/create`) и сохраняет её `id`.
4. Клиент проходит KYC и оплату на страницах DragonTransfer, затем возвращается на `/orders/:id/...-return`.
5. На экране статуса видно текущее состояние операции.

## Telegram-бот (позже)

1. Создайте бота в [@BotFather](https://t.me/BotFather).
2. Укажите Web App URL на публичный адрес этого приложения (`APP_HOST`).
3. Откройте Mini App из бота — интерфейс подхватит тему Telegram и `initData`.

## Проверка API без UI

Расчёт:

```bash
curl -s -X POST http://localhost:3000/api/precalc \
  -H "Content-Type: application/json" \
  -d '{"amount":5000}'
```

Симуляция webhook:

```bash
curl -s -X POST http://localhost:3000/webhooks/dragon_transfer \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $DRAGONTRANSFER_API_KEY" \
  -d '{"id":"<uuid-заявки>","status":"PAYIN_SUCCESS","error_code":null}'
```
