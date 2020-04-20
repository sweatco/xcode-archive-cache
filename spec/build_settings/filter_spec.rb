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

  it "should strip paths from specified settings" do
    filter = XcodeArchiveCache::BuildSettings::Filter.new
    all_settings = {
        "OTHER_CFLAGS" => "-DSOMETHING -DSOMETHING_ELSE=9000 -fmodule-map-file=/some/path/to/some.modulemap -iquote \"/some path\" -I \"another path\" -L \"one more path\" -F \"path again\" -isystem \"here we go\"",
        "OTHER_SWIFT_FLAGS" => "-DSOMETHING -DSOMETHING_ELSE=9000 -fmodule-map-file=/some/path/to/some.modulemap -iquote \"-D\" \"COCOAPODS\"",
        "OTHER_CPLUSPLUSFLAGS" => "-fmodule-map-file=/some/path/to/some.modulemap"
    }

    filtered_settings = filter.filter(all_settings)

    expect(filtered_settings["OTHER_CFLAGS"]).to eq("-DSOMETHING -DSOMETHING_ELSE=9000")
    expect(filtered_settings["OTHER_SWIFT_FLAGS"]).to eq("-DSOMETHING -DSOMETHING_ELSE=9000 -D COCOAPODS")
    expect(filtered_settings["OTHER_CPLUSPLUSFLAGS"]).to eq("")
  end
end
