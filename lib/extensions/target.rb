module TargetEqualityCheck
  # @return [String]
  #
  def equatable_identifier
    uuid + display_name
  end
end

module BuildConfigurationSearch
  # @param [String] configuration_name
  #
  # @return [Xcodeproj::Project::Object::XCBuildConfiguration]
  #
  def find_build_configuration(configuration_name)
    build_configuration = build_configurations
                            .select { |configuration| configuration.name == configuration_name }
                            .first
    unless build_configuration
      raise Informative, "#{configuration_name} build configuration not found on target #{display_name}"
    end

    build_configuration
  end
end

module SchellScriptBuildPhaseSearch
  # @param [XcodeArchiveCache::BuildSettings::StringInterpolator] build_settings_interpolator
  # @param [XcodeArchiveCache::BuildSettings::Container] build_settings
  # @param [String] script_name
  #
  # @return [String]
  #
  def find_script(build_settings_interpolator, build_settings, script_name)
    shell_script_build_phases.each do |phase|
      if phase.display_name == script_name
        return build_settings_interpolator.interpolate(phase.shell_script, build_settings)
                    .gsub(/^"|"$/, "")
                    .strip
      end
    end

    nil
  end
end

class Xcodeproj::Project::Object::PBXAggregateTarget
  include XcodeArchiveCache::Logs
  include TargetEqualityCheck
  include BuildConfigurationSearch
  include SchellScriptBuildPhaseSearch
end

class Xcodeproj::Project::Object::PBXNativeTarget
  include XcodeArchiveCache::Logs
  include TargetEqualityCheck
  include BuildConfigurationSearch
  include SchellScriptBuildPhaseSearch
end
