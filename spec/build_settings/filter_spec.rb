RSpec.describe XcodeArchiveCache::BuildSettings::Filter, "#filter_build_settings" do
  it "should leave all specified settings and nothing else" do
    filter = XcodeArchiveCache::BuildSettings::Filter.new
    all_settings = {"FIRST" => "first value",
                    "SECOND" => "second value",
                    "THIRD" => "third value"}
    settings_to_keep = %w(FIRST THIRD)
    filtered_settings = filter.filter(all_settings, settings_to_keep)

    expect(filtered_settings.keys).to eq(settings_to_keep)
    filtered_settings.each do |key, value|
      expect(value).to eq(all_settings[key])
    end
  end
end
