module Apperol
  class AppJson
    def initialize(file_path = 'app.json')
      @file_path = file_path
    end

    def env
      __json__["env"].map do |key, definition|
        AppJson::Env.new(key, definition)
      end
    end

    def __json__
      @__json__ ||= JSON.parse(File.read(@file_path))
    end

    class Env
      attr_reader :key, :definition
      def initialize(key, definition)
        @key = key
        @definition = definition
      end

      def value
        definition.is_a?(String) ? definition : definition["value"]
      end

      def description
        definition.is_a?(String) ? key : definition["description"]
      end

      def generator
        definition.is_a?(String) ? nil: definition["generator"]
      end

      def use_generator?
        generator
      end

      def needs_value?
        required? && !has_value?
      end

      def has_value?
        !(value.nil? || value.strip.empty?)
      end

      def required?
        definition.is_a?(String) ||
        definition["required"].nil? ||
        definition["required"]
      end
    end
  end
end
