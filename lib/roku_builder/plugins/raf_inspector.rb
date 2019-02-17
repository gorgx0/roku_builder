# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  class RafInspector
    RAF_INTERFACE_INITIALIZATION_PATTERN = /roku_ads\(\)/i
    LIBRARY_IMPORT_PATTERN = /\s*library\s*"roku_ads.brs"\s*/i

    def initialize(config:, dir:)
      @config = config
      @dir = dir
      @has_raf_interface_initialization = false
      @interface_location = {}
      @has_library_import = false
      @import_location = {}
      @has_manifest_entry = false
      @manifest_location = {path: "manifest"}
    end

    def inspect_line(line:, file:, line_number:)
      unless @has_raf_interface_initialization
        @has_raf_interface_initialization = !!RAF_INTERFACE_INITIALIZATION_PATTERN.match(line)
        if @has_raf_interface_initialization
          @interface_location = {path: file, line: line_number}
        end
      end
      unless @has_library_import
        @has_library_import = !!LIBRARY_IMPORT_PATTERN.match(line)
        if @has_library_import
          @import_location = {path: file, line: line_number}
        end
      end
    end

    def inspect_manifest(attributes:, line_numbers:)
      if attributes[:bs_libs_required] and attributes[:bs_libs_required].downcase == "roku_ads_lib"
        @has_manifest_entry = true
        @manifest_location[:line] = line_numbers[:bs_libs_required]
      end
    end

    def run(inspector_config)
      @warnings = []
      @inspector_config = inspector_config
      if @has_raf_interface_initialization and !@has_library_import
        add_warning(warning: :rafConstructorPresentImportMissing, location: @interface_location)
      end
      if @has_raf_interface_initialization and !@has_manifest_entry
        add_warning(warning: :rafConstructorPresentManifestMissing, location: @interface_location)
      end
      if !@has_raf_interface_initialization and @has_manifest_entry
        add_warning(warning: :rafConstructorMissingManifestPresent, location: @manifest_location)
      end
      if @has_manifest_entry and !@has_library_import
        add_warning(warning: :rafManifestPresentImportMissing, location: @manifest_location)
      end
      if !@has_raf_interface_initialization and @has_library_import
        add_warning(warning: :rafConstructorMissingImportPresent, location: @import_location)
      end
      if @has_raf_interface_initialization and @has_library_import and @has_manifest_entry
        add_warning(warning: :rafProperIntegration, location: @import_location)
      end
      @warnings
    end

    private

    def add_warning(warning:, location:)
      @warnings.push(@inspector_config[warning].deep_dup)
      @warnings.last[:path] = location[:path]
      @warnings.last[:line] = location[:line]
    end
  end
end
