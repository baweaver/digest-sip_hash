# frozen_string_literal: true

require 'digest'
require 'digest/sip_hash/version'

module Digest
  class SipHash < Digest::Class
    DEFAULT_KEY = (0.chr * 16).freeze

    attr_accessor :key

    def initialize c_rounds = 1, d_rounds = 3, key: DEFAULT_KEY
      @c_rounds = c_rounds
      @d_rounds = d_rounds
      @key = key
      @buffer = +''
    end

    def << s
      @buffer << s
      self
    end
    alias update <<

    def reset
      @buffer.clear
      self
    end

    def finish
      sip = Sip.new @buffer, @key, @c_rounds, @d_rounds
      sip.append
      sip.finalize
    end

    class Sip
      MASK = 2 ** 64 - 1
      V0 = 'somepseu'.unpack1 'Q>'
      V1 = 'dorandom'.unpack1 'Q>'
      V2 = 'lygenera'.unpack1 'Q>'
      V3 = 'tedbytes'.unpack1 'Q>'

      def initialize buffer, key, c_rounds, d_rounds
        @buffer = buffer
        @size = @buffer.size
        @c_rounds = c_rounds
        @d_rounds = d_rounds

        k0 = key[0..7].unpack1 'Q<'
        k1 = key[8..15].unpack1 'Q<'

        @v0 = V0 ^ k0
        @v1 = V1 ^ k1
        @v2 = V2 ^ k0
        @v3 = V3 ^ k1
      end

      def append
        (@size / 8).times { |n| compress_word @buffer.slice(n * 8, 8).unpack1 'Q<' }
        compress_word complete_pending
      end

      def finalize
        @v2 ^= 2 ** 8 - 1
        @d_rounds.times { compress }
        [@v0 ^ @v1 ^ @v2 ^ @v3].pack 'Q>'
      end

      private

      def compress
        @v0 = (@v0 + @v1) & MASK
        @v1 = rotate @v1, by: 13
        @v1 ^= @v0
        @v0 = rotate @v0, by: 32
        @v2 = (@v2 + @v3) & MASK
        @v3 = rotate @v3, by: 16
        @v3 ^= @v2
        @v0 = (@v0 + @v3) & MASK
        @v3 = rotate @v3, by: 21
        @v3 ^= @v0
        @v2 = (@v2 + @v1) & MASK
        @v1 = rotate @v1, by: 17
        @v1 ^= @v2
        @v2 = rotate @v2, by: 32
      end

      def rotate n, by:
        n << by & MASK | (n >> (64 - by))
      end

      def compress_word m
        @v3 ^= m
        @c_rounds.times { compress }
        @v0 ^= m
      end

      def complete_pending
        last = (@size << 56) & MASK
        return last if @size.zero?

        r = @size % 8
        offset = @size / 8 * 8

        [0, 8, 16, 24, 32, 40, 48].each_with_index.reverse_each do |n, i|
          last |= @buffer[offset + i].ord << n if r > i
        end

        last
      end
    end
  end

  class SipHash13 < SipHash
    def initialize key: DEFAULT_KEY
      super 1, 3, key: key
    end
  end

  class SipHash24 < SipHash
    def initialize key: DEFAULT_KEY
      super 2, 4, key: key
    end
  end
end
