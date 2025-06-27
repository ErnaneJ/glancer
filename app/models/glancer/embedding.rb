module Glancer
  class Embedding < ApplicationRecord
    serialize :embedding, Array
  end
end
