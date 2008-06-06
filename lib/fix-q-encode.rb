require "action_mailer/quoting"
module ActionMailer
  module Quoting #:nodoc:
    undef quoted_printable_encode

    def quoted_printable_encode(character)
      result = ""
      character.each_byte { |b| result << "=%02X" % b }
      result
    end

  end
end

