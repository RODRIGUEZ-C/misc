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

    def string(n, name)
      define_field name, "Z#{n}", n
    end

    def array(type, name, num)
      case type
      when Symbol, String
        if @@types.has_key?(type.to_sym)
          e = @@types[type.to_sym]
          type = FieldPrototype.new(:dmy, e[0], e[1])
        else
          raise "type not defined: #{type}"
        end
      end
      klass = FieldArray.new(type, num)

      (@prototypes ||= []).push klass
      (@names ||= []).push name
      define_accessor name
    end

    def serialize(v)
      v.serialize
    end

    def define_type(typename, template_string, bytesize)
      @@types[typename.to_sym] = [template_string, bytesize]
    end

    private

    @@types = {
      :char    => ['A', 1],
      :byte    => ['C', 1],
      :int16LE => ['v', 2],
      :int32LE => ['V', 4],
    }

    def define_field(name, template, size)
      (@prototypes ||= []).push FieldPrototype.new(name, template, size)
      (@names ||= []).push name
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

    def method_missing(type, name, *args)
      if @@types.has_key?(type)
        if name.kind_of?(Array)
          array(type, name[0], name[1])
        else
          e = @@types[type]
          define_field name, e[0], e[1]
        end
      else
        # 文字列からグローバルに定義されてるクラスを探したい
        begin
          klass = eval(type.to_s)
        rescue
          raise "no type: #{type}"
        end
        if klass.kind_of?(Class) && klass.new.kind_of?(PackedStruct)
          if name.kind_of?(Array)
            array(klass, name[0], name[1])
          else
            (@prototypes ||= []).push klass
            (@names ||= []).push name
            define_accessor name
          end
        else
          raise "not type name: #{type}"
        end
      end
    end
  end

  class FieldPrototype
    def initialize(name, template, size)
      @name = name
      @template = template
      @size = size
    end

    attr_reader :name
    attr_reader :size

    def read(f)
      parse(f.read(@size))
    end

    def parse(s)
      s.unpack(@template)[0]
    end

    def serialize(val)
      [val].pack(@template)
    end
  end

  class FieldArray
    def initialize(type, num)
      @type = type
      @num = num
      @size = type.size * num
    end

    attr_reader :size

    def read(f)
      parse(f.read(@size))
    end

    def parse(s)
      elemsize = @type.size
      (0...@num).map do |i|
        @type.parse(s[i * elemsize, elemsize])
      end
    end

    def serialize(vals)
       vals.map {|val| @type.serialize(val)}.join('')
    end
  end

  def PackedStruct.size
    @prototypes.map {|proto| proto.size }.inject(0) {|sum, s| sum + s }
  end

  def PackedStruct.names
    @names
  end

  def PackedStruct.prototypes
    @prototypes
  end

  def PackedStruct.read(f)
    new(* @prototypes.map {|proto| proto.read(f) })
  end

  def initialize(*vals)
    @alist = self.class.names.zip(vals)
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
end


if $0 == __FILE__
	Test = PackedStruct.define {
		int32LE :hoge
		string 8, :fuga
	}
	test = Test.new(0x12345678, "Ruby")
	p test
	p test.serialize
end
