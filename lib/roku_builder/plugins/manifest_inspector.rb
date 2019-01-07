# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class ManifestInspector
    def initialize(config:, dir:, raf:)
      @config = config
      @dir = dir
      @raf_inspector = raf
    end

    def run(inspector_config)
      @warnings = []
      @attributes = {}
      @line_numbers = {}
      @inspector_config = inspector_config
      manifest = File.join(@config.root_dir, "manifest")
      unless File.exist?(manifest)
        add_warning(warning: :packageManifestFile)
      else
        File.open(manifest) do |file|
          current_line = 0
          file.readlines.each do |line|
            current_line += 1
            parts = line.split("=")
            key = parts.shift.to_sym
            if @attributes[key]
              add_warning(warning: :manifestDuplicateAttribute, key: key, line: current_line)
            else
              value = parts.join("=").chomp
              if !value or value == ""
                add_warning(warning: :manifestEmptyValue, key: key, line: current_line)
              else
                @attributes[key] = value
                @line_numbers[key] = current_line
              end
            end
          end
        end
        manifest_attributes.each_pair do |key, attribute_config|
          if @attributes[key]
            if attribute_config[:deprecated]
              add_warning(warning: :manifestDeprecatedAttribute, key: key)
            end
            if attribute_config[:validations]
              attribute_config[:validations].each_pair do |type, value|
                case type
                when :integer
                  unless "%0#{@attributes[key].length}i" % @attributes[key].to_i == @attributes[key]
                    add_warning(warning: :manifestInvalidValue, key: key)
                  end
                when :float
                  unless @attributes[key].to_f.to_s == @attributes[key]
                    add_warning(warning: :manifestInvalidValue, key: key)
                  end
                when :boolean
                  unless ["false", "true"].include? @attributes[key]
                    add_warning(warning: :manifestInvalidValue, key: key)
                  end
                when :non_negative
                  unless @attributes[key].to_f >= 0
                    add_warning(warning: :manifestInvalidValue, key: key)
                  end
                when :not_equal
                  if value.include? @attributes[key]
                    add_warning(warning: :manifestInvalidValue, key: key)
                  end
                when :equals
                  unless value.include? @attributes[key]
                    add_warning(warning: :manifestInvalidValue, key: key)
                  end
                when :starts_with
                  unless @attributes[key].start_with? value
                    add_warning(warning: :manifestInvalidValue, key: key)
                  end
                else
                  raise ImplementationError, "Unknown Validation #{type}"
                end
              end
            end
            if attribute_config[:notify]
              attribute_config[:notify].each do |regexp|
                if /#{regexp}/ =~ @attributes[key]
                  add_warning(warning: :manifestHasValue, key: key)
                  break
                end
              end
            end
            if attribute_config[:isResource]
              path = File.join(@dir, @attributes[key].gsub("pkg:/", ""))
              unless File.exist?(path)
                mapping = {"{0}": @attributes[key], "{1}": key }
                add_warning(warning: :manifestMissingFile, key: key, mapping: mapping)
              else
                if attribute_config[:resolution]
                  size = ImageSize.path(path).size
                  target = ImageSize::Size.new(attribute_config[:resolution])
                  unless size == target
                    mapping = {
                      "{0}": @attributes[key],
                      "{1}": key,
                      "{2}": size,
                      "{3}": target
                    }
                    add_warning(warning: :manifestIncorrectImageResolution, key: key, mapping: mapping)
                  end
                end
              end
            end
          elsif attribute_config[:required]
            add_warning(warning: :manifestMissingAttribute, key: key)
          end
          @raf_inspector.inspect_manifest(attributes: @attributes, line_numbers: @line_numbers)
        end
      end
      @warnings
    end

    private

    def manifest_attributes
      file = File.join(File.dirname(__FILE__), "manifest_attributes.json")
      JSON.parse(File.open(file).read, {symbolize_names: true})
    end

    def add_warning(warning:, key: nil, mapping: nil, line: nil)
      @warnings.push(@inspector_config[warning].deep_dup)
      @warnings.last[:path] = "manifest"
      if line
        @warnings.last[:line] = line
      elsif @line_numbers[key]
        @warnings.last[:line] = @line_numbers[key]
      end
      if mapping
        mapping.each_pair do |map, value|
          @warnings.last[:message].gsub!(map.to_s, value.to_s)
        end
      elsif key
        @warnings.last[:message].gsub!("{0}", key.to_s)
        if @attributes[key]
          @warnings.last[:message].gsub!("{1}", @attributes[key])
        end
      end
    end
  end
end
