require 'rd/rdfmt'
require 'rd/visitor'
require 'rd/version'
require 'rd/rd2html-lib'

module Redmine
  module RDFormatting
    FILTERS = [
    ].freeze

    class RestrictedHTMLVisitor < RD::RD2HTMLVisitor
      def apply_to_DocumentElement(element, content)
        content.join
      end
      def apply_to_RefToElement(element, content)
        content = content.join("")
        if anchor = refer(element)
          content = content.sub(/^function#/, "")
          %Q[<a href="\##{anchor}">#{content}</a>]
        else
          label = element.to_label
          case label
          when /\A[\w_-]+\z/
            %Q[<a href="#{label}">#{meta_char_escape(content)}</a>]
          else
            label = hyphen_escape(element.to_label)
            %Q[<!-- Reference, RDLabel "#{label}" doesn't exist -->] +
             %Q[<em class="label-not-found">#{content}</em><!-- Reference end -->]
          end
        end
      end
    end
    def self.to_html(text, options = {}, &block)
      visitor = RestrictedHTMLVisitor.new
      src = text.split(/^/)
      if src.find{|i| /\S/ === i } and !src.find{|i| /^=begin\b/ === i }
        src.unshift("=begin\n").push("=end\n")
      end

      include_path = [RD::RDTree.tmp_dir]
      tree = RD::RDTree.new(src, include_path, nil)
      FILTERS.each do |part_name, filter|
        tree.filter[part_name] = filter
      end
  
      # parse
      tree.parse
      visitor.charcode = "utf8"
      visitor.visit(tree)
    rescue Racc::ParseError => e
      return "<pre>#{e.message}</pre>"
    end
  end
end
