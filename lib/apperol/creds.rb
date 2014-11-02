module Apperol
  class Creds
    class << self
      def heroku
        instance.heroku
      end

      def github
        instance.github
      end

      def instance
        @instance ||= new
      end
    end

    def heroku
      netrc["api.heroku.com"]
    end

    def github
      netrc["api.github.com"]
    end

    def netrc
      @netrc ||= Netrc.read
    end
  end
end
