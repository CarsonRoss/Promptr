module Api
  module V1
    class HealthController < ApplicationController
      def index
        render json: { status: 'ok' }
      end
    end
  end
end


