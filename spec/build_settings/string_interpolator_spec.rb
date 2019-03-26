RSpec.describe XcodeArchiveCache::BuildSettings::StringInterpolator, "#interpolate_build_settings" do
  it "should correctly replace build settings with their values" do
    interpolator = XcodeArchiveCache::BuildSettings::StringInterpolator.new
    string = "${FIRST}-$(SECOND)-something-else-${THIRD}-$(FOURTH)"
    build_settings = XcodeArchiveCache::BuildSettings::Container.new({"FIRST" => "first", "SECOND" => "second"}, {})
    interpolated_string = interpolator.interpolate(string, build_settings)
    expect(interpolated_string).to eq("first-second-something-else-${THIRD}-$(FOURTH)")
  end
end
