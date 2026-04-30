# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PluginRoutes do
  describe '.add_after_reload_routes' do
    after do
      # Clean up the class variable to avoid polluting other tests
      described_class.class_variable_set(:@@_after_reload, []) # rubocop:disable Style/ClassVars
    end

    it 'accepts a Proc' do
      callable = proc { 'hello' }
      expect { described_class.add_after_reload_routes(callable) }.not_to raise_error
    end

    it 'accepts a Lambda' do
      callable = -> { 'hello' }
      expect { described_class.add_after_reload_routes(callable) }.not_to raise_error
    end

    it 'raises ArgumentError for a String' do
      expect { described_class.add_after_reload_routes('puts "hello"') }
        .to raise_error(ArgumentError, /callable/)
    end
  end

  describe '.reload' do
    it 'calls each registered callable' do
      callback = instance_double(Proc)
      described_class.class_variable_set(:@@_after_reload, [callback]) # rubocop:disable Style/ClassVars

      allow(Rails.application).to receive(:reload_routes!)
      expect(callback).to receive(:call)

      described_class.reload

      # Clean up
      described_class.class_variable_set(:@@_after_reload, []) # rubocop:disable Style/ClassVars
    end
  end
end
