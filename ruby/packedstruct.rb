# $Id: dbf.rb,v 1.9 2006/02/12 22:02:54 aamine Exp $
#
# Copyright (c) 2005,2006 yrock
# 
# This program is free software.
# You can distribute/modify this program under the terms of the Ruby License.
#
# 2006-02-11 refactored by Minero Aoki

# 2008 modified by mokehehe
#		add default value

  class PackedStruct
    class << PackedStruct
      def define(&block)
        c = Class.new(self)
        def c.inherited(subclass)
          proto = @prototypes
          subclass.instance_eval {
            @prototypes = proto
          }
        end
        c.module_eval(&block)
        c
      end

      def char(name, val=?\00)
        define_field name, 'A', 1, val
      end

      def byte(name, val=0)
        define_field name, 'C', 1, val
      end

      def int16LE(name, val=0)
        define_field name, 'v', 2, val
      end

      def int32LE(name, val=0)
        define_field name, 'V', 4, val
      end

      def string(n, name, val="")
        define_field name, "Z#{n}", n, val
      end


      # ’Ç‰Á‚ÌŒ^
      def int(name, val=0)
        int32LE(name, val)
      end

      def short(name, val=0)
        int16LE(name, val)
      end

      def UINT(name, val=0)
        int32LE(name, val)
      end

      def pointer(name, val=nil)
        define_field name, "P", 4, val
      end

      def LPSTR(name, val=nil)
        pointer(name, val)
      end

      def LPARAM(name, val=nil)
        int32LE(name, val)
      end

      def PUINT(name, val=nil)
        pointer(name, val)
      end

      def WORD(name, val=nil)
        int16LE(name, val)
      end

      def DWORD(name, val=nil)
        int32LE(name, val)
      end

      def LONG(name, val=nil)
        int32LE(name, val)
      end

    private

      def define_field(name, template, size, default_value)
        (@prototypes ||= []).push FieldPrototype.new(name, template, size, default_value)
        define_accessor name
      end

      def define_accessor(name)
        module_eval(<<-End, __FILE__, __LINE__ + 1)
          def #{name}
            self['#{name}']
          end

          def #{name}=(val)
            self['#{name}'] = val
          end
        End
      end
    end

    class FieldPrototype
      def initialize(name, template, size, default_value)
        @name = name
        @template = template
        @size = size
        @default_value = default_value
      end

      attr_reader :name
      attr_reader :size
      attr_reader :default_value

      def read(f)
        parse(f.read(@size))
      end

      def parse(s)
        s.unpack(@template)[0]
      end

      def serialize(val)
        tmpl = @template
        case tmpl
        when 'v', 'V'
			val = 0 if val == nil
        end
        [val].pack(tmpl)
      end
    end

    def PackedStruct.size
      @prototypes.map {|proto| proto.size }.inject(0) {|sum, s| sum + s }
    end

    def PackedStruct.names
      @prototypes.map {|proto| proto.name }
    end

    def PackedStruct.prototypes
      @prototypes
    end

    def PackedStruct.default_values
      @prototypes.map {|proto| proto.default_value }
    end

    def PackedStruct.read(f)
      new(* @prototypes.map {|proto| proto.read(f) })
    end

    def initialize(*vals)
      v = vals
      arg_num = vals.size
      n = self.class.prototypes.size
      if arg_num < n
        v = v + self.class.default_values[arg_num, n - arg_num]
      end
      @alist = self.class.names.zip(v)
    end

    def inspect
      "\#<#{self.class} #{@alist.map {|n,v| "#{n}=#{v.inspect}" }.join(' ')}>"
    end

    def [](name)
      k, v = @alist.assoc(name.to_s.intern)
      raise ArgumentError, "no such field: #{name}" unless k
      v
    end

    def []=(name, val)
      a = @alist.assoc(name.to_s.intern)
      raise ArgumentError, "no such field: #{name}" unless a
      a[1] = val
    end

    def serialize
      self.class.prototypes.zip(@alist.map {|_, val| val })\
          .map {|proto, val| proto.serialize(val) }.join('')
    end




    def pack
      serialize
    end

    def size
      self.class.size
    end



	class StringStream
		def initialize(str)
			@str = str
			@idx = 0
		end
	
		def read(size)
			unless eof?
				idx = @idx
				@idx += size
				@str[idx, size]
			else
				""
			end
		end
	
		def eof?
			@idx >= @str.length
		end
	end

    def PackedStruct.unpack(str)
      f = StringStream.new(str)
      read(f)
    end
  end
