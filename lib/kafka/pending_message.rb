# frozen_string_literal: true

module Kafka
  class PendingMessage
    attr_reader :value, :key, :topic, :partition, :partition_key, :create_time, :bytesize, :headers

    def initialize(value, key, topic, partition, partition_key, create_time, headers)
      @value = value
      @key = key
      @topic = topic
      @partition = partition
      @partition_key = partition_key
      @create_time = create_time
      @headers = headers
      @bytesize = key.to_s.bytesize + value.to_s.bytesize
    end

    def ==(other)
      @value == other.value &&
        @key == other.key &&
        @topic == other.topic &&
        @partition == other.partition &&
        @partition_key == other.partition_key &&
        @create_time == other.create_time &&
        @bytesize == other.bytesize
    end
  end
end
