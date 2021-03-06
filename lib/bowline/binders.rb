module Bowline
  module Binders
    class Base
      class << self
        # See Bowline::js
        def js
          Bowline::js
        end
      
        # Equivalent of the 'jQuery' function
        def jquery
          @@jquery ||= JQuery.new
        end
      
        # See the Observer class
        def observer
          @observer ||= Observer.new
        end
        
        # See Bowline::logger
        def logger
          Bowline::logger
        end
      
        # See Bowline::show_view
        def show_view(*args)
          Bowline::show_view(*args)
        end
        
        def params
          @params
        end
        
        def params=(p) #:nodoc:
          case p
          when String
            # Params comes in a string (since it's a
            # serialized form) - we need to make it into
            # a nestled hash. Stolen from Ramaze
            m = proc {|_,o,n|o.merge(n,&m)}
            @params = params.inject({}) do |hash, (key, value)|
              parts = key.split(/[\]\[]+/)
              hash.merge(parts.reverse.inject(value) { |x, i| {i => x} }, &m) 
            end
          else
            @params = p
          end
        end
        
        def elements
          @elements
        end
        
        def setup(d) #:nodoc:
          @elements ||= []
          @elements << d
          self.item_sync!
        end
        
        def trigger(event, data = nil)
          @elements ||= []
          @elements.map {|e| 
            e.trigger(format_event(event), data) 
          }
        end
        
        def loading(&block)
          trigger(:loading, true)
          yield
          trigger(:loading, false)
        end
      
        def instance(el) #:nodoc:
          self.new(el).method(:send)
        end

        def inherited(child) #:nodoc:
          return if self == Bowline::Binders::Base
          return if child == Bowline::Binders::Singleton
          return if child == Bowline::Binders::Collection
          name = child.name.underscore
          name = name.split('/').last
          js.send("bowline_#{name}_setup=",    child.method(:setup))
          js.send("bowline_#{name}_instance=", child.method(:instance))
          js.send("bowline_#{name}=",          child.method(:send))
        end
        
        def format_event(name) #:nodoc:
          name.is_a?(Array) ? 
            name.join('.') : 
              name.to_s
        end
      end
    
      attr_reader :element
      attr_reader :item
    
      def initialize(element, *args) #:nodoc:
        # jQuery element
        @element = element
        # Calling chain.js 'item' function
        @item    = element.item()
        if @item
          # If possible, find Ruby object
          @item = self.class.find(@item._id.to_i)
        end
      end

      # Trigger jQuery events on this element
      def trigger(event, data = nil)
        self.element.trigger(
          self.class.format_event(event), 
          data
        )
      end
    
      # Raw DOM element
      def dom
        self.element[0]
      end
    
      # Shortcut methods
    
      # See self.class.show_view
      def show_view(*args)
        self.class.show_view(*args)
      end
    
      # See self.class.js
      def js
        self.class.js
      end
      alias :page :js
    
      # See self.class.jquery
      def jquery
        self.class.jquery
      end
    
      # See self.class.observer
      def observer
        self.class.observer
      end
      
      # See self.class.logger
      def logger
        self.class.logger
      end
    
      private
        # This is just a unique identifier
        # for the item - and isn't
        # used in the dom
        def item_id
          if item.respond_to?(:dom_id)
            item.dom_id
          else
            [
              item.id, 
              self.class.name.underscore
            ].join("_")
          end
        end
    end
  end
end