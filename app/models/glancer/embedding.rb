# frozen_string_literal: true
module Glancer
  class Embedding < ApplicationRecord
    serialize :embedding, Array
  end
end
