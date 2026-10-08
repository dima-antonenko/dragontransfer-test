# Архитектура

Telegram Mini App (и тот же UI в браузере) покупает USDT TRC20 за рубли.
Rails — прокси и хранилище заявок. Курс, KYC и оплата живут у DragonTransfer.

## Слои

```
HTTP → Controllers (home | orders | api | webhooks)
         → Services (#call)
              → Order
              → DragonTransfer::Client → Partner API
         ↓
    JSON (Api::*)  /  ERB + miniapp.js (HTML)
```

- Контроллер вызывает один сценарий и отдаёт результат.
- Сценарий не знает про `request` и формат HTTP-ответа.
- `DragonTransfer::Client` не знает про `Order`. Он принимает параметры и возвращает payload партнёра либо бросает `DragonTransfer::Error`.

## Граница с партнёром

Базовый URL и ключ: `DragonTransfer.config` из `DRAGONTRANSFER_BASE_URL` и `DRAGONTRANSFER_API_KEY`.
По умолчанию стенд `https://test.dragontransfer.online`.

| Метод клиента | Путь партнёра | Кто вызывает |
|---------------|---------------|--------------|
| `precalc` | `POST /api/partners/orders/precalc` | `Precalcs::Create` |
| `rate` | `POST /api/partners/orders/rate` | `Rates::Fetch` |
| `create` | `POST /api/partners/orders/create` | `Orders::Create` |
| `find` | `POST /api/partners/orders/find` | `Orders::SyncStatus` |

Заголовок исходящих запросов: `X-Api-Key`. Таймаут 20 с, open timeout 5 с.
Успех партнёра: HTTP success и `body["success"]`. Иначе `DragonTransfer::Error`
с `code`, `http_status`, `request_id`, `details`. Сетевой сбой — `code: network_error`, HTTP 502.

## Домен: Order

Локальная заявка и заявка партнёра — разные сущности, связанные полем `external_id`.

| Поле | Смысл |
|------|--------|
| `id` | integer PK. Им пользуются UI, return URL и `GET /api/orders/:id` |
| `external_id` | UUID партнёра. Уникален, если не `NULL`. По нему ищется webhook и `orders/find` |
| `status` | см. шкалу ниже, default `NEW` |
| `payin_*` | сколько платит пользователь, валюта RUB |
| `payout_*` / `rate` | сколько USDT и курс; приходят от партнёра |
| `address` / `network` | кошелёк TRC20 |
| `verification_url`, `invoice_url` | страницы KYC и оплаты на стороне партнёра |
| `error_code` | код партнёра; подпись — `Order::ERROR_CODE_LABELS` |
| `raw_payload` | последний принятый payload (jsonb) |
| `telegram_user_id` | необязательная метка из Mini App, без проверки подписи |

Суммы в БД — строки, чтобы не терять точность партнёра.

### Шкала статусов

`Order::STATUS_RANK` задаёт порядок. Входящий статус с меньшим рангом не применяется
(`apply_remote_payload!`). `SUCCESS` и `ERROR` — финальные (`terminal?`), у обоих ранг 7.
После финала `Orders::SyncStatus` больше не вызывает `orders/find`.

```
NEW → PREORDER → PENDING → KYC_PENDING → PAYIN_PENDING → PAYIN_SUCCESS → PROCESSING → SUCCESS
                                                                                      → ERROR
```

## Потоки

### Расчёт и курс

Пользователь вводит сумму. `miniapp.js` с debounce 400 мс вызывает `POST /api/precalc`.
Отдельно при загрузке — `GET /api/rate`. Оба ответа проксируются как payload партнёра,
в БД ничего не пишется.

### Создание заявки

`POST /api/orders` → `Orders::Create`:

1. Собрать `Order` (`NEW`), нормализовать телефон (`Phones::Normalize`), провалидировать и сохранить.
2. Вызвать `orders/create`. В return URL подставить локальный `id`:
   - `{APP_HOST}/orders/:id/verification-return`
   - `{APP_HOST}/orders/:id/invoice-return`
3. Записать payload (`apply_remote_payload!`) и сразу синхронизировать через `orders/find`.
4. Если партнёр вернул ошибку после локального `save!` — удалить локальную строку и пробросить `DragonTransfer::Error`.
5. Если не прошла валидация — партнёр не вызывается.

Дальше клиент открывает `verification_url` (KYC), затем `invoice_url` (оплата).
Партнёр возвращает пользователя на return URL. Оба action рендерят тот же экран заявки
и перед показом синхронизируют статус.

### Статус

Два канала, оба сходятся в `apply_remote_payload!`:

- Webhook `POST /webhooks/dragon_transfer` → `Webhooks::DragonTransfer::Process` → `Orders::ApplyWebhook`.
- Пока заявка не финальная, Mini App каждые 20 с вызывает `GET /api/orders/:id` → `Orders::Show` → `Orders::SyncStatus`.

`SyncStatus` ничего не делает, если нет `external_id` или статус финальный.

Webhook:

- ключ сверяется через `ActiveSupport::SecurityUtils.secure_compare`;
- неизвестный `external_id` — тихий успех (`200`), строка не создаётся;
- неверный ключ — `401`.

### Mini App

`app/views/miniapp/_app.html.erb` + `app/javascript/miniapp.js`.
Один и тот же partial на главной и на `/orders/:id`.
На странице заявки в `data-order` лежит начальный JSON, затем клиент перечитывает API.

`window.Telegram.WebApp` опционален: `ready` / `expand` и CSS-переменные темы.
Без Telegram форма работает как обычный сайт.

## Routing

| Метод и путь | Контроллер | Сервис |
|--------------|------------|--------|
| `GET /up` | health | — |
| `GET /` | `home#index` | — |
| `GET /orders/:id` | `orders#show` | `Orders::Show` |
| `GET /orders/:id/verification-return` | `orders#verification_return` | `Orders::Show` |
| `GET /orders/:id/invoice-return` | `orders#invoice_return` | `Orders::Show` |
| `POST /api/precalc` | `api/precalcs#create` | `Precalcs::Create` |
| `GET /api/rate` | `api/rates#show` | `Rates::Fetch` |
| `POST /api/orders` | `api/orders#create` | `Orders::Create` |
| `GET /api/orders/:id` | `api/orders#show` | `Orders::Show` |
| `POST /webhooks/dragon_transfer` | `webhooks/dragon_transfer#create` | `Webhooks::DragonTransfer::Process` |

Пользовательской аутентификации нет. JSON API доступен тому, кто открыл сайт.
Защита секрета — ключ партнёра не покидает сервер. В логах фильтруются `email`,
`phone_number`, `address`, `api_key`.

## Ошибки

`ApiErrorHandling` на `Api::BaseController`:

| Исключение | HTTP | `code` |
|------------|------|--------|
| `DragonTransfer::Error` с 4xx | тот же 4xx | код партнёра |
| прочий `DragonTransfer::Error` | 422 | код ошибки |
| `ActiveRecord::RecordInvalid`, `ArgumentError`, `ParameterMissing` | 422 | `argument_error` |
| `ActiveRecord::RecordNotFound` | 404 | `not_found` |

Тело: `{ "error", "code", "request_id" }`. `request_id` есть у ошибок партнёра.

## Деплой

Kamal (`config/deploy.yml`): Puma за Thruster, healthcheck `GET /up`,
PostgreSQL 16 как accessory, том `storage` для Active Storage.
Публичный хост и `APP_HOST` задаются там же: return URL партнёра должны совпадать
с адресом, который видит браузер. Webhook партнёра: `https://<хост>/webhooks/dragon_transfer`.
