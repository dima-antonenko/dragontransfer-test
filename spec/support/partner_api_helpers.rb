# frozen_string_literal: true

module PartnerApiHelpers
  def partner_payload(overrides = {})
    {
      'id' => '0e2c6a1e-6f0b-4a7e-9a3d-5f1e2b3c4d5e',
      'status' => 'PENDING',
      'address' => 'TGSaGfJr7ecCQG2PYNa72CnXgScmntHS62',
      'network' => 'TRC20',
      'payin_amount' => '5000.0',
      'payin_currency' => 'RUB',
      'payout_amount' => '55.76',
      'payout_currency' => 'USDT',
      'rate' => '0.011152',
      'invoice_url' => nil,
      'invoice_expires_at' => nil,
      'verification_url' => 'https://test.dragontransfer.online/kyc/0e2c6a1e-6f0b-4a7e-9a3d-5f1e2b3c4d5e',
      'verification_expires_at' => '2026-10-08 13:00:00',
      'error_code' => nil
    }.merge(overrides)
  end
end
