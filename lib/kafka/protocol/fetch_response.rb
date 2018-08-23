# frozen_string_literal: true

require "kafka/protocol/message_set"
require "kafka/protocol/record_batch"

module Kafka
  module Protocol

    # A response to a fetch request.
    #
    # ## API Specification
    #
    #     FetchResponse => [TopicName [Partition ErrorCode HighwaterMarkOffset MessageSetSize MessageSet]]
    #       TopicName => string
    #       Partition => int32
    #       ErrorCode => int16
    #       HighwaterMarkOffset => int64
    #       MessageSetSize => int32
    #
    class FetchResponse
      MAGIC_BYTE_OFFSET = 16
      MAGIC_BYTE_LENGTH = 1

      class FetchedPartition
        attr_reader :partition, :error_code
        attr_reader :highwater_mark_offset, :last_stable_offset, :aborted_transactions, :messages

        def initialize(partition:, error_code:, highwater_mark_offset:, last_stable_offset:, aborted_transactions:, messages:)
          @partition = partition
          @error_code = error_code
          @highwater_mark_offset = highwater_mark_offset
          @messages = messages
          @last_stable_offset = last_stable_offset
          @aborted_transactions = aborted_transactions
        end
      end

      class FetchedTopic
        attr_reader :name, :partitions

        def initialize(name:, partitions:)
          @name = name
          @partitions = partitions
        end
      end

      attr_reader :topics

      def initialize(topics: [], throttle_time_ms: 0)
        @topics = topics
        @throttle_time_ms = throttle_time_ms
      end

      def self.decode(decoder)
        throttle_time_ms = decoder.int32

        topics = decoder.array do
          topic_name = decoder.string

          partitions = decoder.array do
            partition = decoder.int32
            error_code = decoder.int16
            highwater_mark_offset = decoder.int64
            last_stable_offset = decoder.int64

            aborted_transactions = decoder.array do
              producer_id = decoder.int64
              first_offset = decoder.int64
              {
                producer_id: producer_id,
                first_offset: first_offset
              }
            end

            messages_decoder = Decoder.from_string(decoder.bytes)
            messages = []

            magic_byte = messages_decoder.peek(MAGIC_BYTE_OFFSET, MAGIC_BYTE_LENGTH)[0].to_i
            begin
              if magic_byte == RecordBatch::MAGIC_BYTE
                until messages_decoder.eof?
                  begin
                    record_batch = RecordBatch.decode(messages_decoder)
                    messages += record_batch.records
                  rescue InsufficientDataMessage
                    if messages.length > 0
                      break
                    else
                      raise
                    end
                  end
                end
              else
                message_set = MessageSet.decode(messages_decoder)
                messages = message_set.messages
              end
            rescue Kafka::Error => e
              puts "[#{topic_name}/#{partition}] Message corrupted! Error: #{e}. First offset in batch: #{messages.first&.offset || "Null"}"
            end

            FetchedPartition.new(
              partition: partition,
              error_code: error_code,
              highwater_mark_offset: highwater_mark_offset,
              last_stable_offset: last_stable_offset,
              aborted_transactions: aborted_transactions,
              messages: messages
            )
          end

          FetchedTopic.new(
            name: topic_name,
            partitions: partitions,
          )
        end

        new(topics: topics, throttle_time_ms: throttle_time_ms)
      end
    end
  end
end
