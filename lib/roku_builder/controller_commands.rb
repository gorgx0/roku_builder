# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Commands that the controller uses to interface with the rest of the gem.
  class ControllerCommands

    # Provides a hash of all of the options needed to run simple commands via
    # the simple_command method
    # @return [Hash] options to run simple commands
    def self.simple_commands
      {
        key: { klass: Keyer, method: :rekey, config_key: :key },
        genkey: { klass: Keyer, method: :genkey, config_key: :genkey },
        screencapture: { klass: Inspector, method: :screencapture, config_key: :screencapture_config,
          failure: FAILED_SCREENCAPTURE },
        applist: {klass: Linker, method: :list},
        profile: {klass: Profiler, method: :run, config_key: :profiler_config}
      }
    end
    # Run Package
    # @param options [Hash] user options
    # @param config [Conifg] config object
    # @return [Integer] Success or Failure Code
    def self.package(options:, config:)
      loader_config = config.parsed[:device_config].dup
      loader_config[:init_params] = config.parsed[:init_params][:loader]
      keyer = Keyer.new(**config.parsed[:device_config])
      stager = Stager.new(**config.parsed[:stage_config])
      loader = Loader.new(**loader_config)
      packager = Packager.new(**config.parsed[:device_config])
      Logger.instance.warn "Packaging working directory" if options[:working]
      if stager.stage
        # Sideload #
        code, build_version = loader.sideload(**config.parsed[:sideload_config])
        return code unless code == SUCCESS
        # Key #
        _success = keyer.rekey(**config.parsed[:key])
        # Package #
        options[:build_version] = build_version
        config.update
        success = packager.package(**config.parsed[:package_config])
        Logger.instance.info "Signing Successful: #{config.parsed[:package_config][:out_file]}" if success
        return FAILED_SIGNING unless success
        # Inspect #
        if options[:inspect]
          inspect_package(config: config)
        end
      end
      stager.unstage
      Logger.instance.info "App Packaged; staged using #{stager.method}"
      SUCCESS
    end
    def self.test(options:, config:)
      device_config = config.parsed[:device_config].dup
      device_config[:init_params] = config.parsed[:init_params][:tester]
      stager = Stager.new(**config.parsed[:stage_config])
      if stager.stage
        tester = Tester.new(**device_config)
        tester.run_tests(**config.parsed[:test_config])
      end
      stager.unstage
      SUCCESS
    end

    # Run update
    # @param config [Config] config object
    # @return [Integer] Success or Failure Code
    def self.update(config:)
      ### Update ###
      stager = Stager.new(**config.parsed[:stage_config])
      if stager.stage
        manifest = Manifest.new(config: config)
        old_version = manifest.build_version
        manifest.increment_build_version
        new_version = manifest.build_version
        Logger.instance.info "Update build version from:\n#{old_version}\nto:\n#{new_version}"
      end
      stager.unstage
      SUCCESS
    end

    # Run Deeplink
    # @param options [Hash] user options
    # @param config [Config] config object
    def self.deeplink(options:, config:)
      if options.has_source?
        sideload(options: options, config: config)
      end

      linker = Linker.new(config.parsed[:device_config])
      if linker.launch(config.parsed[:deeplink_config])
        Logger.instance.info "Deeplinked into app"
        return SUCCESS
      else
        return FAILED_DEEPLINKING
      end
    end
  end
end
