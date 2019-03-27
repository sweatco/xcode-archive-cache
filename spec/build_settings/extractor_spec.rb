RSpec.describe XcodeArchiveCache::BuildSettings::Extractor, "#extract_build_settings" do
  before(:each) do
    @extractor = XcodeArchiveCache::BuildSettings::Extractor.new
  end

  it "should correctly behave when no input given" do
    expect(@extractor.extract_per_target("")).to eq(Hash.new)
  end

  it "should correctly extract settings for each target" do
    input = "Build settings for action archive target first\n" \
    "  TARGETNAME = first\n" \
    "  SETTING = setting value\n" \
    "  ANOTHER_SETTING = another setting value\n" \
    "Build settings for action archive target second\n" \
    "  TARGETNAME = second\n" \
    "  SETTING = setting value for second\n" \
    "  ANOTHER_SETTING = another setting value for second\n"

    per_target_settings = @extractor.extract_per_target(input)

    # expect(per_target_settings["first"]).to eq()
  end
end