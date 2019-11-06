RSpec.describe XcodeArchiveCache::BuildSettings::Loader, "#load_build_settings" do
  before(:each) do
    @executor = double
    @loader = XcodeArchiveCache::BuildSettings::Loader.new(@executor)
  end

  it "should save settings per project" do
    first_project_settings = "Build settings for action archive target first\n" \
    "  TARGETNAME = first\n" \
    "  ARCHS = armv7\n" \
    "  PATH = some path\n" \
    "Build settings for action archive target second\n" \
    "  TARGETNAME = second\n" \
    "  ARCHS = arm64\n" \
    "  PATH = some path\n"
    allow(@executor).to receive(:load_build_settings).with("first_project_path").and_return(first_project_settings)
    second_project_settings = "Build settings for action archive target first\n" \
    "  TARGETNAME = first\n" \
    "  ARCHS = armv7s\n" \
    "  PATH = some path for second project\n" \
    "Build settings for action archive target second\n" \
    "  TARGETNAME = second\n" \
    "  ARCHS = arm64\n" \
    "  PATH = some path\n"
    allow(@executor).to receive(:load_build_settings).with("second_project_path").and_return(second_project_settings)
    allow(@executor).to receive_messages(:arguments_state => "arguments_state")

    @loader.load_settings(%w(first_project_path second_project_path))

    settings_container = XcodeArchiveCache::BuildSettings::Container.new({"TARGETNAME" => "first", "ARCHS" => "armv7", "PATH" => "some path"}, {"TARGETNAME" => "first", "ARCHS" => "armv7"})
    expect(@loader.get_settings("first_project_path", "first")).to eq(settings_container)
    settings_container = XcodeArchiveCache::BuildSettings::Container.new({"TARGETNAME" => "first", "ARCHS" => "armv7s", "PATH" => "some path for second project"}, {"TARGETNAME" => "first", "ARCHS" => "armv7s"})
    expect(@loader.get_settings("second_project_path", "first")).to eq(settings_container)
  end
end
