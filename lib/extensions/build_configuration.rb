module XCConfigExtensions
  # @return [Bool]
  #
  def has_xcconfig?
    base_configuration_reference != nil
  end

  # @return [String]
  #
  def get_xcconfig_path
    base_configuration_reference.real_path
  end
end

module ProjectDir
  # @return [String]
  #
  def get_project_dir
    File.dirname(project.path)
  end
end

class Xcodeproj::Project::Object::XCBuildConfiguration
  include XCConfigExtensions
  include ProjectDir
end
