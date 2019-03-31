RSpec.describe XcodeArchiveCache::BuildSettings::Extractor, "#extract_build_settings" do
  before(:each) do
    @extractor = XcodeArchiveCache::BuildSettings::Extractor.new
    @input =     input = "Build settings for action archive target first\n" \
    "  TARGETNAME = first\n" \
    "  SETTING = setting value\n" \
    "  ANOTHER_SETTING = another setting value\n" \
    "Build settings for action archive target second\n" \
    "  TARGETNAME = second\n" \
    "  SETTING = setting value for second\n" \
    "  ANOTHER_SETTING = another setting value for second\n"

    filter = double
    real_filter = XcodeArchiveCache::BuildSettings::Filter.new
    @settings_to_keep = %w(TARGETNAME SETTING)
    allow(filter).to receive(:filter) {|build_settings, _| real_filter.filter(build_settings, @settings_to_keep)}
    allow(@extractor).to receive(:filter).and_return(filter)

  end

  it "should correctly behave when no input given" do
    expect(@extractor.extract_per_target("")).to eq(Hash.new)
  end

  it "should correctly extract settings for each target" do
    per_target_settings = @extractor.extract_per_target(@input)
    expect(per_target_settings.keys).to eq(%w(first second))

    all_setting_names = %w(TARGETNAME SETTING ANOTHER_SETTING)
    first_target_settings = per_target_settings["first"]
    expect(first_target_settings["TARGETNAME"]).to eq("first")
    expect(first_target_settings["SETTING"]).to eq("setting value")
    expect(first_target_settings["ANOTHER_SETTING"]).to eq("another setting value")
    expect(first_target_settings.all.keys).to eq(all_setting_names)

    second_target_settings = per_target_settings["second"]
    expect(second_target_settings["TARGETNAME"]).to eq("second")
    expect(second_target_settings["SETTING"]).to eq("setting value for second")
    expect(second_target_settings["ANOTHER_SETTING"]).to eq("another setting value for second")
    expect(second_target_settings.all.keys).to eq(all_setting_names)
  end

  it "should correctly filter out extra settings for each target" do
    per_target_settings = @extractor.extract_per_target(@input)

    first_target_settings = per_target_settings["first"]
    filtered_settings = first_target_settings.filtered
    expect(filtered_settings.keys).to eq(@settings_to_keep)

    second_target_settings = per_target_settings["second"]
    filtered_settings = second_target_settings.filtered
    expect(filtered_settings.keys).to eq(@settings_to_keep)
  end
end