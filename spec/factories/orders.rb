# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    email { 'ivan@example.com' }
    full_name { 'Иван Иванов Иванович' }
    phone_number { '79990000000' }
    address { 'TGSaGfJr7ecCQG2PYNa72CnXgScmntHS62' }
    payin_amount { '5000.0' }
    payin_currency { 'RUB' }
    payout_amount { '55.76' }
    payout_currency { 'USDT' }
    status { 'PENDING' }
    sequence(:external_id) { |n| format('0e2c6a1e-6f0b-4a7e-9a3d-%012d', n) }
    network { 'TRC20' }
    raw_payload { {} }

    trait :new_local do
      status { 'NEW' }
      external_id { nil }
    end

    trait :kyc_pending do
      status { 'KYC_PENDING' }
      verification_url { 'https://test.dragontransfer.online/kyc/example' }
    end

    trait :success do
      status { 'SUCCESS' }
    end

    trait :error do
      status { 'ERROR' }
      error_code { 'CANCELLED_KYC_USER' }
    end
  end
end
