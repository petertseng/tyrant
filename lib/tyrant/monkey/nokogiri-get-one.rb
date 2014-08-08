module Nokogiri
  module XML
    class Element
      def get_one(attr)
        stuff = xpath(attr)
        raise 'More than one ' + attr if stuff.count > 1
        stuff.count > 0 ? stuff[0].content : nil
      end
    end
  end
end
