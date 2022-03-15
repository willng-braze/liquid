# frozen_string_literal: true

require 'cgi'
require 'base64'
require 'bigdecimal'

module Liquid
  module StandardFilters
    MAX_INT = (1 << 31) - 1
    HTML_ESCAPE = {
      '&' => '&amp;',
      '>' => '&gt;',
      '<' => '&lt;',
      '"' => '&quot;',
      "'" => '&#39;',
    }.freeze
    HTML_ESCAPE_ONCE_REGEXP = /["><']|&(?!([a-zA-Z]+|(#\d+));)/
    STRIP_HTML_BLOCKS       = Regexp.union(
      %r{<script.*?</script>}m,
      /<!--.*?-->/m,
      %r{<style.*?</style>}m
    )
    STRIP_HTML_TAGS = /<.*?>/m

    # Return the size of an array or of an string
    def size(input)
      input.respond_to?(:size) ? input.size : 0
    end

    # convert an input string to DOWNCASE
    #
    # @public_docs
    # @type filter
    # @title downcase
    # @summary Converts a string into lowercase.
    # @category String
    # @syntax {{ input | downcase }}
    # @return string
    def downcase(input)
      input.to_s.downcase
    end

    # convert an input string to UPCASE
    #
    # @public_docs
    # @type filter
    # @title upcase
    # @summary Converts a string into uppercase.
    # @category String
    # @syntax {{ input | upcase }}
    # @return string
    def upcase(input)
      input.to_s.upcase
    end

    # capitalize words in the input sentence
    #
    # @public_docs
    # @type filter
    # @title capitalize
    # @summary Capitalizes the first word in a string.
    # @category String
    # @syntax {{ input | capitalize }}
    # @return string
    def capitalize(input)
      input.to_s.capitalize
    end

    # @public_docs
    # @type filter
    # @title escape
    # @summary Escapes a string.
    # @category String
    # @syntax {{ input | escape }}
    # @return string
    def escape(input)
      CGI.escapeHTML(input.to_s) unless input.nil?
    end
    alias_method :h, :escape

    def escape_once(input)
      input.to_s.gsub(HTML_ESCAPE_ONCE_REGEXP, HTML_ESCAPE)
    end

    def url_encode(input)
      CGI.escape(input.to_s) unless input.nil?
    end

    def url_decode(input)
      return if input.nil?

      result = CGI.unescape(input.to_s)
      raise Liquid::ArgumentError, "invalid byte sequence in #{result.encoding}" unless result.valid_encoding?

      result
    end

    # @public_docs
    # @type filter
    # @title base64_encode
    # @summary Encodes a string into Base64.
    # @category String
    # @syntax {{ input | base64_encode }}
    # @return string
    def base64_encode(input)
      Base64.strict_encode64(input.to_s)
    end

    # @public_docs
    # @type filter
    # @title base64_decode
    # @summary Decodes a string from Base64.
    # @category String
    # @syntax {{ input | base64_decode }}
    # @return string
    def base64_decode(input)
      Base64.strict_decode64(input.to_s)
    rescue ::ArgumentError
      raise Liquid::ArgumentError, "invalid base64 provided to base64_decode"
    end

    # @public_docs
    # @type filter
    # @title base64_url_safe_encode
    # @summary Encodes a string into URL-safe Base64
    # @category String
    # @syntax {{ input | base64_url_safe_encode }}
    # @return string
    # @description
    #   To produce URL-safe Base64, this filter uses `-`` and `_`` in place of `+`` and `/``.
    def base64_url_safe_encode(input)
      Base64.urlsafe_encode64(input.to_s)
    end

    # @public_docs
    # @type filter
    # @title base64_url_safe_decode
    # @summary Decodes a string from URL-safe Base64.
    # @category String
    # @syntax {{ input | base64_url_safe_decode }}
    # @return string
    def base64_url_safe_decode(input)
      Base64.urlsafe_decode64(input.to_s)
    rescue ::ArgumentError
      raise Liquid::ArgumentError, "invalid base64 provided to base64_url_safe_decode"
    end

    def slice(input, offset, length = nil)
      offset = Utils.to_integer(offset)
      length = length ? Utils.to_integer(length) : 1

      if input.is_a?(Array)
        input.slice(offset, length) || []
      else
        input.to_s.slice(offset, length) || ''
      end
    end

    # Truncate a string down to x characters
    def truncate(input, length = 50, truncate_string = "...")
      return if input.nil?
      input_str = input.to_s
      length    = Utils.to_integer(length)

      truncate_string_str = truncate_string.to_s

      l = length - truncate_string_str.length
      l = 0 if l < 0

      input_str.length > length ? input_str[0...l].concat(truncate_string_str) : input_str
    end

    def truncatewords(input, words = 15, truncate_string = "...")
      return if input.nil?
      input = input.to_s
      words = Utils.to_integer(words)
      words = 1 if words <= 0

      wordlist = begin
        input.split(" ", words + 1)
      rescue RangeError
        raise if words + 1 < MAX_INT
        # e.g. integer #{words} too big to convert to `int'
        raise Liquid::ArgumentError, "integer #{words} too big for truncatewords"
      end
      return input if wordlist.length <= words

      wordlist.pop
      wordlist.join(" ").concat(truncate_string.to_s)
    end

    # Split input string into an array of substrings separated by given pattern.
    #
    # Example:
    #   <div class="summary">{{ post | split '//' | first }}</div>
    #
    def split(input, pattern)
      input.to_s.split(pattern.to_s)
    end

    def strip(input)
      input.to_s.strip
    end

    def lstrip(input)
      input.to_s.lstrip
    end

    def rstrip(input)
      input.to_s.rstrip
    end

    def strip_html(input)
      empty  = ''
      result = input.to_s.gsub(STRIP_HTML_BLOCKS, empty)
      result.gsub!(STRIP_HTML_TAGS, empty)
      result
    end

    # Remove all newlines from the string
    def strip_newlines(input)
      input.to_s.gsub(/\r?\n/, '')
    end

    # @public_docs
    # @type filter
    # @title join
    # @category array
    # @summary Joins the elements of an array with the character passed as the parameter. The result is a single string.
    # @syntax {{ product.tags | join: ', ' }}
    # @required_param input [array] The array to join.
    # @required_param delimiter [string] The string to join the array elements with.
    # @return string
    def join(input, glue = ' ')
      InputIterator.new(input, context).join(glue)
    end

    # @public_docs
    # @type sort
    # @title concat
    # @category array
    # @summary Sorts the elements of an array by a given attribute of an element in the array.
    # @description The order of the sorted array is case-sensitive.
    # @syntax {{ collection.products | sort: 'price' }}
    # @required_param input [array] The array to sort.
    # @optional_param property [array] The property to sort by.
    # @return output [array]
    def sort(input, property = nil)
      ary = InputIterator.new(input, context)

      return [] if ary.empty?

      if property.nil?
        ary.sort do |a, b|
          nil_safe_compare(a, b)
        end
      elsif ary.all? { |el| el.respond_to?(:[]) }
        begin
          ary.sort { |a, b| nil_safe_compare(a[property], b[property]) }
        rescue TypeError
          raise_property_error(property)
        end
      end
    end

    # Sort elements of an array ignoring case if strings
    # provide optional property with which to sort an array of hashes or drops
    def sort_natural(input, property = nil)
      ary = InputIterator.new(input, context)

      return [] if ary.empty?

      if property.nil?
        ary.sort do |a, b|
          nil_safe_casecmp(a, b)
        end
      elsif ary.all? { |el| el.respond_to?(:[]) }
        begin
          ary.sort { |a, b| nil_safe_casecmp(a[property], b[property]) }
        rescue TypeError
          raise_property_error(property)
        end
      end
    end

    # Filter the elements of an array to those with a certain property value.
    # By default the target is any truthy value.
    def where(input, property, target_value = nil)
      ary = InputIterator.new(input, context)

      if ary.empty?
        []
      elsif target_value.nil?
        ary.select do |item|
          item[property]
        rescue TypeError
          raise_property_error(property)
        rescue NoMethodError
          return nil unless item.respond_to?(:[])
          raise
        end
      else
        ary.select do |item|
          item[property] == target_value
        rescue TypeError
          raise_property_error(property)
        rescue NoMethodError
          return nil unless item.respond_to?(:[])
          raise
        end
      end
    end

    # Remove duplicate elements from an array
    # provide optional property with which to determine uniqueness
    def uniq(input, property = nil)
      ary = InputIterator.new(input, context)

      if property.nil?
        ary.uniq
      elsif ary.empty? # The next two cases assume a non-empty array.
        []
      else
        ary.uniq do |item|
          item[property]
        rescue TypeError
          raise_property_error(property)
        rescue NoMethodError
          return nil unless item.respond_to?(:[])
          raise
        end
      end
    end

    # @public_docs
    # @type reverse
    # @title concat
    # @category array
    # @summary Reverses the order of the items in an array.
    # @syntax {{ collections | reverse }}
    # @required_param input [array] The array to reverse.
    # @return output [array]
    def reverse(input)
      ary = InputIterator.new(input, context)
      ary.reverse
    end

    # @public_docs
    # @type map
    # @title concat
    # @category array
    # @summary Accepts an array element's attribute as a parameter and creates an array out of each array element's value.
    # @syntax {{ collections | map: 'title' }}
    # @required_param input [array] The array to map over.
    # @return output [array]
    def map(input, property)
      InputIterator.new(input, context).map do |e|
        e = e.call if e.is_a?(Proc)

        if property == "to_liquid"
          e
        elsif e.respond_to?(:[])
          r = e[property]
          r.is_a?(Proc) ? r.call : r
        end
      end
    rescue TypeError
      raise_property_error(property)
    end

    # Remove nils within an array
    # provide optional property with which to check for nil
    def compact(input, property = nil)
      ary = InputIterator.new(input, context)

      if property.nil?
        ary.compact
      elsif ary.empty? # The next two cases assume a non-empty array.
        []
      else
        ary.reject do |item|
          item[property].nil?
        rescue TypeError
          raise_property_error(property)
        rescue NoMethodError
          return nil unless item.respond_to?(:[])
          raise
        end
      end
    end

    # @public_docs
    # @syntax {{ string | replace: string, substring }}
    # @summary Replaces all occurrences of a string with a substring.
    # @type filter
    # @category string
    # @return string
    def replace(input, string, replacement = '')
      input.to_s.gsub(string.to_s, replacement.to_s)
    end

    # Replace the first occurrences of a string with another
    def replace_first(input, string, replacement = '')
      input.to_s.sub(string.to_s, replacement.to_s)
    end

    # Replace the last occurrences of a string with another
    def replace_last(input, string, replacement)
      input = input.to_s
      string = string.to_s
      replacement = replacement.to_s

      start_index = input.rindex(string)

      return input unless start_index

      output = input.dup
      output[start_index, string.length] = replacement
      output
    end

    # @public_docs
    # @syntax {{ string | remove: string }}
    # @summary Removes a substring.
    # @type filter
    # @category string
    # @return string
    def remove(input, string)
      replace(input, string, '')
    end

    # @public_docs
    # @syntax {{ string | remove_first: string }}
    # @summary Removes the first occurrences of a substring.
    # @type filter
    # @category string
    # @return string
    def remove_first(input, string)
      replace_first(input, string, '')
    end

    # remove the last occurences of a substring
    def remove_last(input, string)
      replace_last(input, string, '')
    end

    # add one string to another
    #
    # @public_docs
    # @type filter
    # @title append
    # @summary Appends characters to a string.
    # @category String
    # @syntax {{ string | append: to_append }}
    # @required_param to_append [string] characters to append to the original string
    # @return string
    def append(input, string)
      input.to_s + string.to_s
    end

    # @public_docs
    # @type filter
    # @title concat
    # @category array
    # @summary Concatenates (combines) an array with another array.
    # @description The resulting array contains all the elements of the original arrays. `concat` will not remove duplicate entries from the concatenated array unless you also use the uniq filter.
    # @syntax {{ product.images | last | to_img }}
    # @required_param input [array] The array to concatenate.
    def concat(input, array)
      unless array.respond_to?(:to_ary)
        raise ArgumentError, "concat filter requires an array argument"
      end
      InputIterator.new(input, context).concat(array)
    end

    # @public_docs
    # @syntax {{ string | prepend: string }}
    # @summary Prepend a string to another string.
    # @type filter
    # @category string
    # @return string
    def prepend(input, string)
      string.to_s + input.to_s
    end

    # Add <br /> tags in front of all newlines in input string
    def newline_to_br(input)
      input.to_s.gsub(/\r?\n/, "<br />\n")
    end

    # Reformat a date using Ruby's core Time#strftime( string ) -> string
    #
    #   %a - The abbreviated weekday name (``Sun'')
    #   %A - The  full  weekday  name (``Sunday'')
    #   %b - The abbreviated month name (``Jan'')
    #   %B - The  full  month  name (``January'')
    #   %c - The preferred local date and time representation
    #   %d - Day of the month (01..31)
    #   %H - Hour of the day, 24-hour clock (00..23)
    #   %I - Hour of the day, 12-hour clock (01..12)
    #   %j - Day of the year (001..366)
    #   %m - Month of the year (01..12)
    #   %M - Minute of the hour (00..59)
    #   %p - Meridian indicator (``AM''  or  ``PM'')
    #   %s - Number of seconds since 1970-01-01 00:00:00 UTC.
    #   %S - Second of the minute (00..60)
    #   %U - Week  number  of the current year,
    #           starting with the first Sunday as the first
    #           day of the first week (00..53)
    #   %W - Week  number  of the current year,
    #           starting with the first Monday as the first
    #           day of the first week (00..53)
    #   %w - Day of the week (Sunday is 0, 0..6)
    #   %x - Preferred representation for the date alone, no time
    #   %X - Preferred representation for the time alone, no date
    #   %y - Year without a century (00..99)
    #   %Y - Year with century
    #   %Z - Time zone name
    #   %% - Literal ``%'' character
    #
    #   See also: http://www.ruby-doc.org/core/Time.html#method-i-strftime
    def date(input, format)
      return input if format.to_s.empty?

      return input unless (date = Utils.to_date(input))

      date.strftime(format.to_s)
    end

    # @public_docs
    # @type filter
    # @title first
    # @category array
    # @summary Returns the first element of an array.
    # @description You can use `first` with dot notation when you need to use the filter inside a tag.
    # @syntax {{ product.images | first | to_img }}
    # @required_param input [array]
    def first(array)
      array.first if array.respond_to?(:first)
    end

    # @public_docs
    # @type filter
    # @title last
    # @category array
    # @summary Returns the last element of an array.
    # @description You can use `last` with dot notation when you need to use the filter inside a tag. Using `last` on a string returns the last character in the string.
    # @syntax {{ product.images | last | to_img }}
    # @required_param input [array]
    def last(array)
      array.last if array.respond_to?(:last)
    end

    # @public_docs
    # @syntax {{ number | abs }}
    # @summary Returns the absolute value of a number.
    # @type filter
    # @category Math
    # @return number
    # @description
    #   `abs` will also work on a string if the string only contains a number.
    def abs(input)
      result = Utils.to_number(input).abs
      result.is_a?(BigDecimal) ? result.to_f : result
    end

    # @public_docs
    # @syntax {{ number | plus: number }}
    # @summary Adds a number to an output.
    # @type filter
    # @category Math
    # @return number
    def plus(input, operand)
      apply_operation(input, operand, :+)
    end

    # @public_docs
    # @syntax {{ number | minus: number }}
    # @summary Subtracts a number from an output.
    # @type filter
    # @category Math
    # @return number
    def minus(input, operand)
      apply_operation(input, operand, :-)
    end

    # @public_docs
    # @syntax {{ number | times: number }}
    # @summary Multiplies an output by a number.
    # @type filter
    # @category Math
    # @return number
    def times(input, operand)
      apply_operation(input, operand, :*)
    end

    # @public_docs
    # @syntax {{ number | divided_by: number }}
    # @summary Divides an output by a number. The output is rounded down to the nearest integer.
    # @type filter
    # @category Math
    # @return number
    def divided_by(input, operand)
      apply_operation(input, operand, :/)
    rescue ::ZeroDivisionError => e
      raise Liquid::ZeroDivisionError, e.message
    end

    # @public_docs
    # @syntax {{ number | modulo: number }}
    # @summary Divides an output by a number and returns the remainder.
    # @type filter
    # @category Math
    # @return number
    def modulo(input, operand)
      apply_operation(input, operand, :%)
    rescue ::ZeroDivisionError => e
      raise Liquid::ZeroDivisionError, e.message
    end

    # @public_docs
    # @syntax {{ number | round }}
    # @summary Rounds the output to the nearest integer or specified number of decimals.
    # @type filter
    # @category Math
    # @return number
    def round(input, n = 0)
      result = Utils.to_number(input).round(Utils.to_number(n))
      result = result.to_f if result.is_a?(BigDecimal)
      result = result.to_i if n == 0
      result
    rescue ::FloatDomainError => e
      raise Liquid::FloatDomainError, e.message
    end

    # @public_docs
    # @syntax {{ number | ceil }}
    # @summary Rounds an output up to the nearest integer.
    # @type filter
    # @category Math
    # @return number
    def ceil(input)
      Utils.to_number(input).ceil.to_i
    rescue ::FloatDomainError => e
      raise Liquid::FloatDomainError, e.message
    end

    # @public_docs
    # @syntax {{ number | floor }}
    # @summary Rounds an output down to the nearest integer.
    # @type filter
    # @category Math
    # @return number
    def floor(input)
      Utils.to_number(input).floor.to_i
    rescue ::FloatDomainError => e
      raise Liquid::FloatDomainError, e.message
    end

    # @public_docs
    # @syntax {{ number | at_least: number }}
    # @summary Limits a number to a minimum value.
    # @type filter
    # @category Math
    # @return number
    def at_least(input, n)
      min_value = Utils.to_number(n)

      result = Utils.to_number(input)
      result = min_value if min_value > result
      result.is_a?(BigDecimal) ? result.to_f : result
    end

    # @public_docs
    # @syntax {{ number | at_most: number }}
    # @summary Limits a number to a maximum value.
    # @type filter
    # @category Math
    # @return number
    def at_most(input, n)
      max_value = Utils.to_number(n)

      result = Utils.to_number(input)
      result = max_value if max_value < result
      result.is_a?(BigDecimal) ? result.to_f : result
    end

    # Set a default value when the input is nil, false or empty
    #
    # Example:
    #    {{ product.title | default: "No Title" }}
    #
    # Use `allow_false` when an input should only be tested against nil or empty and not false.
    #
    # Example:
    #    {{ product.title | default: "No Title", allow_false: true }}
    #
    def default(input, default_value = '', options = {})
      options = {} unless options.is_a?(Hash)
      false_check = options['allow_false'] ? input.nil? : !Liquid::Utils.to_liquid_value(input)
      false_check || (input.respond_to?(:empty?) && input.empty?) ? default_value : input
    end

    private

    attr_reader :context

    def raise_property_error(property)
      raise Liquid::ArgumentError, "cannot select the property '#{property}'"
    end

    def apply_operation(input, operand, operation)
      result = Utils.to_number(input).send(operation, Utils.to_number(operand))
      result.is_a?(BigDecimal) ? result.to_f : result
    end

    def nil_safe_compare(a, b)
      result = a <=> b

      if result
        result
      elsif a.nil?
        1
      elsif b.nil?
        -1
      else
        raise Liquid::ArgumentError, "cannot sort values of incompatible types"
      end
    end

    def nil_safe_casecmp(a, b)
      if !a.nil? && !b.nil?
        a.to_s.casecmp(b.to_s)
      else
        a.nil? ? 1 : -1
      end
    end

    class InputIterator
      include Enumerable

      def initialize(input, context)
        @context = context
        @input   = if input.is_a?(Array)
          input.flatten
        elsif input.is_a?(Hash)
          [input]
        elsif input.is_a?(Enumerable)
          input
        else
          Array(input)
        end
      end

      def join(glue)
        to_a.join(glue.to_s)
      end

      def concat(args)
        to_a.concat(args)
      end

      def reverse
        reverse_each.to_a
      end

      def uniq(&block)
        to_a.uniq(&block)
      end

      def compact
        to_a.compact
      end

      def empty?
        @input.each { return false }
        true
      end

      def each
        @input.each do |e|
          e = e.respond_to?(:to_liquid) ? e.to_liquid : e
          e.context = @context if e.respond_to?(:context=)
          yield(e)
        end
      end
    end
  end

  Template.register_filter(StandardFilters)
end
