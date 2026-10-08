module Phones
  class Normalize < BaseService
    def initialize(raw)
      @raw = raw
    end

    def call
      @raw.to_s.gsub(/[^\d+]/, "")
    end
  end
end
