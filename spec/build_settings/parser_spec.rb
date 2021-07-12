RSpec.describe XcodeArchiveCache::BuildSettings::Parser, "#parse_build_settings" do
  before(:each) do
    @parser = XcodeArchiveCache::BuildSettings::Parser.new
  end

  context "parse" do
    it "should correctly parse setting name" do
      string = "SETTING = value"
      name = @parser.parse_name(string)
      expect(name).to eq("SETTING")
    end

    it "should correctly parse setting value" do
      string = "SETTING = value"
      value = @parser.parse_value(string)
      expect(value).to eq("value")
    end
  end

  context "regular expressions" do
    it "should return correct regular expression for setting entry" do
      regex = @parser.create_entry_regex("SETTING")
      expect(regex.source).to eq("\\$[({]SETTING[)}]")
    end
  end

  context "search" do
    it "should correctly find all setting names" do
      string = "${FIRST} $(SECOND) THIRD ${FOURTH} $(FOURTH)"
      entries = @parser.find_all_entries(string)
      expect(entries.map(&:name)).to eq(%w(FIRST SECOND FOURTH FOURTH))
    end
  end
end
