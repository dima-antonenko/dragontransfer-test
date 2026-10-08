class Order < ApplicationRecord
  TRC20_ADDRESS = /\AT[1-9A-HJ-NP-Za-km-z]{33}\z/
  PHONE = /\A\+?\d{10,15}\z/

  STATUSES = %w[
    NEW
    PREORDER
    PENDING
    KYC_PENDING
    PAYIN_PENDING
    PAYIN_SUCCESS
    PROCESSING
    SUCCESS
    ERROR
  ].freeze

  STATUS_RANK = {
    "NEW" => 0,
    "PREORDER" => 1,
    "PENDING" => 2,
    "KYC_PENDING" => 3,
    "PAYIN_PENDING" => 4,
    "PAYIN_SUCCESS" => 5,
    "PROCESSING" => 6,
    "SUCCESS" => 7,
    "ERROR" => 7
  }.freeze

  FINAL_STATUSES = %w[SUCCESS ERROR].freeze

  ERROR_CODE_LABELS = {
    "CANCELLED_PREORDER_TIMEOUT" => "Истёк срок подтверждения предзаявки",
    "CANCELLED_ANTIFROD" => "Заявка отменена антифрод-системой",
    "CANCELLED_KYC_BOARDING" => "Не удалось завести клиента в верификацию",
    "CANCELLED_KYC_USER" => "Клиент не прошёл верификацию личности",
    "INPUT_SERVICE_NOT_FOUND" => "Сервис не найден",
    "INPUT_SYMBOL_NOT_SUPPORTED" => "Валютная пара не поддерживается",
    "INPUT_AMOUNT_BELOW_MIN" => "Сумма ниже минимально допустимой",
    "INPUT_AMOUNT_ABOVE_MAX" => "Сумма выше максимально допустимой",
    "INPUT_USER_NOT_SUBSCRIBED" => "Пользователь не подписан на сервис",
    "INPUT_SERVICE_INACTIVE" => "Сервис временно неактивен",
    "INPUT_GATE_VALIDATION_ERROR" => "Ошибка валидации параметров на стороне шлюза",
    "INPUT_FAILSAFE_DEVIATION" => "Отклонение курса превысило порог защиты",
    "PAYIN_VALIDATION_ERROR" => "Запрос на оплату не прошёл валидацию",
    "PAYIN_API_ERROR" => "Ошибка внешнего провайдера оплаты",
    "PAYIN_INVOICE_EXPIRED" => "Истёк срок оплаты счёта",
    "PAYIN_INVOICE_REJECTED" => "Счёт на оплату отклонён",
    "PAYIN_STATUS_CHECK_ERROR" => "Ошибка проверки статуса платежа",
    "PAYIN_UNEXPECTED_ERROR" => "Непредвиденная ошибка оплаты",
    "PAYOUT_VALIDATION_ERROR" => "Запрос на выплату не прошёл валидацию",
    "PAYOUT_API_ERROR" => "Ошибка внешнего провайдера выплаты",
    "PAYOUT_REJECTED" => "Выплата отклонена провайдером",
    "PAYOUT_NO_EXTERNAL_ID" => "Выплата выполнена без внешнего идентификатора",
    "PAYOUT_CONFIRM_ERROR" => "Ошибка подтверждения выплаты",
    "PAYOUT_RECIPIENT_CHECK_FAILED" => "Не прошла проверка получателя",
    "PAYOUT_UNEXPECTED_ERROR" => "Непредвиденная ошибка выплаты",
    "INTERNAL_GATE_NOT_FOUND" => "Не найден подходящий шлюз",
    "INTERNAL_STATE_SWITCH_ERROR" => "Ошибка смены состояния заявки",
    "INTERNAL_GATE_ROUTE_NOT_FOUND" => "Не найдена конфигурация маршрутизации",
    "INTERNAL_PROCESSOR_ERROR" => "Ошибка внутреннего обработчика заявок",
    "INTERNAL_FAILSAFE_PRECALC_FAILED" => "Сбой защитного предрасчёта курса",
    "INTERNAL_KYC_USER_ERROR" => "Внутренняя ошибка поиска клиента для верификации",
    "INTERNAL_KYC_API_ERROR" => "Ошибка API провайдера верификации",
    "INTERNAL_ERROR" => "Внутренняя ошибка сервиса",
    "INTERNAL_KYC_EXPIRED" => "Истёк срок прохождения верификации"
  }.freeze

  validates :status, inclusion: { in: STATUSES }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true
  validates :phone_number, presence: true, format: { with: PHONE }
  validates :address, presence: true, format: { with: TRC20_ADDRESS }
  validates :payin_amount, presence: true

  def terminal?
    FINAL_STATUSES.include?(status)
  end

  def error_label
    return if error_code.blank?

    ERROR_CODE_LABELS[error_code] || error_code
  end

  def apply_remote_payload!(payload)
    incoming_status = payload["status"].to_s
    return self if stale_status?(incoming_status)

    self.external_id = payload["id"] if payload["id"].present?
    self.status = incoming_status if incoming_status.present?
    self.address = payload["address"] if payload["address"].present?
    self.network = payload["network"]
    self.payin_amount = payload["payin_amount"].to_s if payload["payin_amount"].present?
    self.payin_currency = payload["payin_currency"]
    self.payout_amount = payload["payout_amount"].to_s if payload["payout_amount"].present?
    self.payout_currency = payload["payout_currency"]
    self.rate = payload["rate"].to_s if payload["rate"].present?
    self.invoice_url = payload["invoice_url"]
    self.invoice_expires_at = parse_remote_time(payload["invoice_expires_at"])
    self.verification_url = payload["verification_url"]
    self.verification_expires_at = parse_remote_time(payload["verification_expires_at"])
    self.error_code = payload["error_code"]
    self.raw_payload = payload
    self
  end

  def as_api_json
    {
      id: id,
      external_id: external_id,
      status: status,
      email: email,
      full_name: full_name,
      phone_number: phone_number,
      address: address,
      network: network,
      payin_amount: payin_amount,
      payin_currency: payin_currency,
      payout_amount: payout_amount,
      payout_currency: payout_currency,
      rate: rate,
      invoice_url: invoice_url,
      invoice_expires_at: invoice_expires_at,
      verification_url: verification_url,
      verification_expires_at: verification_expires_at,
      error_code: error_code,
      error_label: error_label,
      terminal: terminal?
    }
  end

  private

  def stale_status?(incoming_status)
    return false if incoming_status.blank?

    current_rank = STATUS_RANK.fetch(status, 0)
    incoming_rank = STATUS_RANK.fetch(incoming_status, 0)
    incoming_rank < current_rank
  end

  def parse_remote_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  end
end
