# Конвенции

## Services

Наследуй `BaseService`. Публичный вход — `#call`. Классовый `BaseService.call(...)`
создаёт экземпляр и вызывает `call`.

Имена: `Namespace::Action` — `Orders::Create`, `Rates::Fetch`, `Phones::Normalize`.
Вложенный сценарий webhook: `Webhooks::DragonTransfer::Process`.

```ruby
module Orders
  class Show < BaseService
    def initialize(id:, client: nil)
      @id = id
      @client = client
    end

    def call
      order = Order.find(@id)
      Orders::SyncStatus.new(order, client: client).call
    end
  end
end
```

- Зависимость от партнёра — аргумент `client:`. Не вызывать `DragonTransfer::Client.new` внутри метода, если конструктор уже принимает клиент.
- `client` в `BaseService` ленивый: свой экземпляр только когда аргумент не передали (`@client ||=`).
- Сервис возвращает запись, payload-хеш или `nil` (webhook без локальной заявки). Ошибки — исключения, не `{ error: }` из сервиса.
- Один сервис — один сценарий. Оркестрация (`Create` вызывает `SyncStatus`) допустима. HTTP-детали — нет.

## Клиент партнёра

Новый метод партнёра добавляется в `DragonTransfer::Client` и вызывает `post`.
Тело уходит JSON-ом, заголовок `X-Api-Key` ставит клиент.

Сумму в JSON готовит `json_amount`: `BigDecimal`, целое без дробной части как integer.
Параметры `create` перед отправкой проходят `compact` (nil-ключи не уходят).

Ошибка партнёра — всегда `DragonTransfer::Error`, не сырой `Faraday::Error` и не хеш.

## Модель

`Order` хранит данные и умеет применить чужой payload:

- валидации формата (email, телефон, TRC20, inclusion статуса);
- `apply_remote_payload!` — единственное место маппинга полей партнёра;
- `as_api_json` — форма JSON для Mini App;
- `error_label` — русская подпись `error_code`.

Статусы, ранги и подписи кодов — константы модели (`STATUSES`, `STATUS_RANK`,
`FINAL_STATUSES`, `ERROR_CODE_LABELS`). Новый статус партнёра добавляется в константы
и в `STATUS_LABELS` в `miniapp.js`.

Колбэки модели не создают заявку у партнёра и не ходят в сеть.

## Контроллеры

Тонкие. Strong params, вызов сервиса, `render`.

- JSON: наследники `Api::BaseController` (`wrap_parameters false`, `ApiErrorHandling`).
- HTML заявки: `OrdersController`, три action показывают один шаблон `orders/show`.
- Webhook: свой `rescue_from`, ответ без тела (`head :ok` / `head status`).

`APP_HOST` для return URL: `ENV["APP_HOST"]`, иначе `request.base_url`.
В проде переменная обязательна, иначе партнёр вернёт пользователя на внутренний хост контейнера.

Ответ API заявки — `order.as_api_json`, не сериализатор-гем.
Ответ precalc/rate — payload партнёра как есть.

Ошибки JSON:

```json
{ "error": "текст", "code": "argument_error", "request_id": null }
```

Тексты для человека — на русском. Коды — snake_case (`not_found`, `argument_error`, `not_authorized`, код партнёра).

## Mini App (JS)

Файл `app/javascript/miniapp.js`, без сборщика и без фреймворка.
Запросы только на свои пути (`/api/precalc`, `/api/rate`, `/api/orders`).

- Ошибки API читаются из `data.error`.
- Телефон и TRC20 проверяются на клиенте теми же правилами, что и модель; сервер остаётся источником истины.
- Опрос статуса — 20 с, останавливается на `order.terminal`.
- Тема Telegram применяется через CSS-переменные, только если есть `window.Telegram.WebApp`.

Stimulus-контроллеры каркаса Rails для этого UI не используются.

## База

Миграции Rails, схема в `db/schema.rb`. Первичный ключ заявки — integer.
`external_id` уникален частичным индексом `WHERE external_id IS NOT NULL`.
Часовой пояс приложения — `Europe/Moscow`.

## Тесты

Фреймворк — RSpec в `spec/`. Minitest-каталог `test/` не заводить.

Раскладка:

- `spec/services/...` — сценарий с `instance_double` клиента;
- `spec/requests/...` — HTTP, сервис подменён, если проверяется контроллер;
- `spec/models/order_spec.rb` — валидации и ранг статусов;
- `spec/factories/orders.rb` — фабрики;
- `spec/support/partner_api_helpers.rb` — `partner_payload`.

Стиль спеки:

- `# frozen_string_literal: true`
- `subject` / `let` / `context`
- `:aggregate_failures` на примерах с несколькими ожиданиями
- имена контекстов: `with success`, `when validation failed`, `when partner create failed`

Запуск: `bundle exec rspec path/to/spec.rb`.
В CI сеть к партнёру закрыта. Новая спека не должна делать реальный HTTP.

## Стиль Ruby

`rubocop-rails-omakase` (`bin/rubocop`). Не отключать копы точечно без причины.
Сервисы и контроллеры — обычные классы без лишних гем-обёрток (dry-monads, interactor).

Коммиты: conventional commits (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`).

## Секреты и логи

- Локально: `.env` (образец — `.env.example`). `.env` не коммитить.
- Прод: `.kamal/secrets` и `env.secret` в `config/deploy.yml`.
- `config/master.key` не коммитить.
- В `filter_parameter_logging` уже стоят `:email`, `:phone_number`, `:address`, `:api_key`. Новые секреты и ПДн добавлять туда же.

## Язык интерфейса

Пользовательские строки (ошибки API, подписи статусов и кодов, тексты Mini App) — русские,
рядом с местом использования: константы модели и `miniapp.js`. Отдельного `ru.yml` для них нет.
Не размазывать одну и ту же подпись статуса по контроллерам: карта статусов для UI — `STATUS_LABELS`,
для кода ошибки — `Order::ERROR_CODE_LABELS`.
