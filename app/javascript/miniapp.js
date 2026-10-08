const STATUS_LABELS = {
  NEW: "Черновик",
  PREORDER: "Ожидает подтверждения",
  PENDING: "Заявка создана",
  KYC_PENDING: "Нужна верификация",
  PAYIN_PENDING: "Ожидается оплата",
  PAYIN_SUCCESS: "Оплата получена",
  PROCESSING: "Идёт перевод USDT",
  SUCCESS: "USDT отправлены",
  ERROR: "Ошибка"
}

const csrfToken = () => document.querySelector('meta[name="csrf-token"]')?.content

const $ = (id) => document.getElementById(id)

const telegram = window.Telegram?.WebApp
let currentOrder = null
let pollTimer = null

function initTelegram() {
  if (!telegram) return
  telegram.ready()
  telegram.expand()
  const params = telegram.themeParams || {}
  const root = document.documentElement
  if (params.bg_color) root.style.setProperty("--bg", params.bg_color)
  if (params.text_color) root.style.setProperty("--text", params.text_color)
  if (params.hint_color) root.style.setProperty("--muted", params.hint_color)
  if (params.button_color) root.style.setProperty("--accent", params.button_color)
  if (params.button_text_color) root.style.setProperty("--accent-text", params.button_text_color)
  if (params.secondary_bg_color) root.style.setProperty("--card", params.secondary_bg_color)
}

function setText(id, text) {
  const node = $(id)
  if (node) node.textContent = text
}

function setHidden(id, hidden) {
  const node = $(id)
  if (node) node.hidden = hidden
}

function showError(id, message) {
  const node = $(id)
  if (!node) return
  if (!message) {
    node.hidden = true
    node.textContent = ""
    return
  }
  node.hidden = false
  node.textContent = message
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken()
    },
    ...options
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new Error(data.error || "Не удалось выполнить запрос")
  }
  return data
}

function debounce(fn, wait) {
  let timer
  return (...args) => {
    clearTimeout(timer)
    timer = setTimeout(() => fn(...args), wait)
  }
}

async function refreshQuote() {
  const amount = $("amount").value.trim()
  showError("quote-error", "")
  if (!amount || Number(amount) <= 0) {
    setText("quote", "Введите сумму, чтобы увидеть, сколько USDT вы получите.")
    return
  }

  try {
    const payload = await api("/api/precalc", {
      method: "POST",
      body: JSON.stringify({ amount })
    })
    setText(
      "quote",
      `За ${payload.payin_amount} ${payload.payin_currency} вы получите ${payload.payout_amount} ${payload.payout_currency}`
    )
  } catch (error) {
    setText("quote", "Не удалось получить расчёт")
    showError("quote-error", error.message)
  }
}

async function refreshRate() {
  try {
    const payload = await api("/api/rate")
    setText("rate", `Текущий курс: 1 RUB ≈ ${payload.rate} USDT`)
  } catch {
    setText("rate", "")
  }
}

function telegramUserId() {
  return telegram?.initDataUnsafe?.user?.id || null
}

function renderOrder(order) {
  currentOrder = order
  $("status-card").hidden = false
  $("status-badge").textContent = STATUS_LABELS[order.status] || order.status
  $("status-badge").dataset.status = order.status
  setText("fact-payin", order.payin_amount ? `${order.payin_amount} ${order.payin_currency || "RUB"}` : "—")
  setText("fact-payout", order.payout_amount ? `${order.payout_amount} ${order.payout_currency || "USDT"}` : "—")
  setText("fact-rate", order.rate || "—")
  setText("fact-address", order.address || "—")
  showError("status-error", order.error_label || "")

  const canKyc = Boolean(order.verification_url) && !order.terminal && order.status !== "SUCCESS"
  const canPay = Boolean(order.invoice_url) && ["PAYIN_PENDING", "KYC_PENDING", "PENDING", "PAYIN_SUCCESS"].includes(order.status)
  $("kyc-btn").hidden = !canKyc
  $("pay-btn").hidden = !(canPay && order.status !== "KYC_PENDING")
  if (order.status === "PAYIN_PENDING") $("pay-btn").hidden = false

  if (order.terminal) {
    stopPolling()
  } else {
    startPolling()
  }
}

function openExternal(url) {
  if (!url) return
  window.location.assign(url)
}

function startPolling() {
  if (pollTimer) return
  pollTimer = setInterval(() => {
    if (currentOrder?.id) loadOrder(currentOrder.id)
  }, 20000)
}

function stopPolling() {
  clearInterval(pollTimer)
  pollTimer = null
}

async function loadOrder(id) {
  const order = await api(`/api/orders/${id}`)
  renderOrder(order)
}

function validateForm() {
  const phone = $("phone_number").value.replace(/[^\d+]/g, "")
  const address = $("address").value.trim()
  if (!/^\+?\d{10,15}$/.test(phone)) {
    throw new Error("Укажите телефон в международном формате, например 79990000000")
  }
  if (!/^T[1-9A-HJ-NP-Za-km-z]{33}$/.test(address)) {
    throw new Error("Адрес USDT должен быть в сети TRC20 и начинаться с T")
  }
}

async function submitOrder(event) {
  event.preventDefault()
  showError("form-error", "")
  const button = $("submit-btn")
  button.disabled = true

  try {
    validateForm()
    const order = await api("/api/orders", {
      method: "POST",
      body: JSON.stringify({
        amount: $("amount").value.trim(),
        full_name: $("full_name").value.trim(),
        email: $("email").value.trim(),
        phone_number: $("phone_number").value.trim(),
        address: $("address").value.trim(),
        telegram_user_id: telegramUserId()
      })
    })
    window.history.replaceState({}, "", `/orders/${order.id}`)
    renderOrder(order)
    if (order.verification_url) openExternal(order.verification_url)
  } catch (error) {
    showError("form-error", error.message)
  } finally {
    button.disabled = false
  }
}

function boot() {
  initTelegram()
  $("amount").addEventListener("input", debounce(refreshQuote, 400))
  $("order-form").addEventListener("submit", submitOrder)
  $("kyc-btn").addEventListener("click", () => openExternal(currentOrder?.verification_url))
  $("pay-btn").addEventListener("click", () => openExternal(currentOrder?.invoice_url))
  $("refresh-btn").addEventListener("click", () => currentOrder?.id && loadOrder(currentOrder.id))

  refreshQuote()
  refreshRate()

  const root = $("miniapp")
  const existing = root.dataset.order
  if (existing) {
    try {
      renderOrder(JSON.parse(existing))
      loadOrder(root.dataset.orderId)
    } catch {
      /* ignore invalid bootstrap payload */
    }
  }
}

document.addEventListener("DOMContentLoaded", boot)
