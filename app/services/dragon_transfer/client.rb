module DragonTransfer
  class Client
    def initialize(base_url: DragonTransfer.config.base_url, api_key: DragonTransfer.config.api_key, http_client: Faraday)
      @base_url = base_url.to_s.chomp("/")
      @api_key = api_key
      @http_client = http_client
    end

    def precalc(amount:, fee_value: nil)
      body = { amount: json_amount(amount) }
      body[:fee_value] = fee_value unless fee_value.nil?
      post("/api/partners/orders/precalc", body)
    end

    def rate
      post("/api/partners/orders/rate", {})
    end

    def create(params)
      body = params.compact
      body[:amount] = json_amount(body[:amount]) if body[:amount]
      post("/api/partners/orders/create", body)
    end

    def find(id:)
      post("/api/partners/orders/find", { id: id })
    end

    private

    def post(path, body)
      response = connection.post(path) do |request|
        request.headers["X-Api-Key"] = @api_key
        request.body = body
      end
      parse_response(response)
    rescue Faraday::Error => e
      raise Error.new("Не удалось связаться с DragonTransfer: #{e.message}", code: "network_error", http_status: 502)
    end

    def parse_response(response)
      body = normalize_body(response.body)
      request_id = body["id"]
      error_object = body["payload"].is_a?(Hash) ? body["payload"] : nil
      error_object ||= body["error"] if body["error"].is_a?(Hash)

      if response.success? && body["success"]
        return body["payload"]
      end

      code = error_object&.fetch("code", nil) || "unknown"
      details = error_object&.fetch("errors", nil) || "Ошибка Partner API"
      message = format_details(details)
      http_status = response.status.zero? ? 502 : response.status

      raise Error.new(message, code: code, http_status: http_status, request_id: request_id, details: details)
    end

    def normalize_body(body)
      return body if body.is_a?(Hash)
      return {} if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      { "success" => false, "error" => { "code" => "invalid_response", "errors" => body.to_s } }
    end

    def format_details(details)
      case details
      when Hash, Array
        details.to_json
      else
        details.to_s
      end
    end

    def json_amount(amount)
      value = BigDecimal(amount.to_s)
      value.frac.zero? ? value.to_i : value.to_f
    end

    def connection
      @connection ||= @http_client.new(url: @base_url) do |faraday|
        faraday.request :json
        faraday.response :json, content_type: /\bjson$/
        faraday.options.timeout = 20
        faraday.options.open_timeout = 5
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
