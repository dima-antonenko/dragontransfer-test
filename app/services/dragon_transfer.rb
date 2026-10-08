module DragonTransfer
  Config = Struct.new(:base_url, :api_key, keyword_init: true)

  def self.config
    @config ||= Config.new(
      base_url: ENV.fetch("DRAGONTRANSFER_BASE_URL", "https://test.dragontransfer.online"),
      api_key: ENV.fetch("DRAGONTRANSFER_API_KEY", "")
    )
  end

  def self.reset_config!
    @config = nil
  end

  def self.valid_api_key?(value)
    expected = config.api_key.to_s
    return false if expected.blank? || value.blank?
    return false if expected.bytesize != value.to_s.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, value.to_s)
  end
end
