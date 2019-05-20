RSpec.describe XcodeArchiveCache::BuildGraph::Node, "#node" do
  before :each do
    @native_target = double("native_target")
    @node = XcodeArchiveCache::BuildGraph::Node.new("some_name", @native_target)
  end

  it "should say it has framework product if it actually has framework product" do
    allow(@native_target).to receive(:product_type).and_return(Xcodeproj::Constants::PRODUCT_TYPE_UTI[:framework])
    expect(@node.has_framework_product?).to be_truthy
    expect(@node.has_static_library_product?).to be_falsey
  end

  it "should say it has static library product if it actually has static library product" do
    allow(@native_target).to receive(:product_type).and_return(Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library])
    expect(@node.has_framework_product?).to be_falsey
    expect(@node.has_static_library_product?).to be_truthy
  end

  it "should return no product name if it has no build settings" do
    expect(@node.product_file_name).to be_nil
  end

  it "should return product name as defined in build_settings" do
    @node.build_settings = double
    allow(@node.build_settings).to receive(:[]) do |setting_name|
      expect(setting_name).to eq(XcodeArchiveCache::BuildSettings::FULL_PRODUCT_NAME_KEY)
      "product_file_name"
    end

    expect(@node.product_file_name).to eq("product_file_name")
  end

  it "should return name of product reference if it's a framework and no product name is defined in build settings" do
    product_reference = double("product_reference")
    allow(product_reference).to receive(:name).and_return("product_file_name")
    allow(@native_target).to receive(:product_reference).and_return(product_reference)
    allow(@native_target).to receive(:product_type).and_return(Xcodeproj::Constants::PRODUCT_TYPE_UTI[:framework])
    @node.build_settings = double("build_settings")
    allow(@node.build_settings).to receive(:[]).and_return(nil)
    expect(@node.product_file_name).to eq("product_file_name")
  end

  it "should return basename of real product path if it's not a framework and no product name is defined in build settings" do
    product_reference = double("product_reference")
    allow(product_reference).to receive(:name).and_return("some_product_file_name")
    allow(product_reference).to receive(:real_path).and_return("/some_dir/product_file_name")
    allow(@native_target).to receive(:product_reference).and_return(product_reference)
    allow(@native_target).to receive(:product_type).and_return(Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library])
    @node.build_settings = double("build_settings")
    allow(@node.build_settings).to receive(:[]).and_return(nil)
    expect(@node.product_file_name).to eq("product_file_name")
  end

  it "should return no dsym file name if has no build settings" do
    expect(@node.dsym_file_name).to be_nil
  end

  it "should return dsym file name as defined in build settings" do
    @node.build_settings = double
    allow(@node.build_settings).to receive(:[]) do |setting_name|
      expect(setting_name).to eq(XcodeArchiveCache::BuildSettings::DWARF_DSYM_FILE_NAME_KEY)
      "dsym_file_name"
    end

    expect(@node.dsym_file_name).to eq("dsym_file_name")
  end

  it "should return all transitive dependent nodes" do
    first_top_level_target = double("first_top_level_target")
    allow(first_top_level_target).to receive(:uuid).and_return("first_top_level_target")
    first_top_level_dependent = XcodeArchiveCache::BuildGraph::Node.new("first_top_level_dependent", first_top_level_target)

    second_top_level_target = double("second_top_level_target")
    allow(second_top_level_target ).to receive(:uuid).and_return("second_top_level_target ")
    second_top_level_dependent = XcodeArchiveCache::BuildGraph::Node.new("second_top_level_dependent", second_top_level_target )

    below_the_top_target = double("below_the_top")
    allow(below_the_top_target).to receive(:uuid).and_return("below_the_top_target")
    below_the_top_dependent = XcodeArchiveCache::BuildGraph::Node.new("below_the_top_dependent", below_the_top_target)
    below_the_top_dependent.dependent.push(first_top_level_dependent)
    below_the_top_dependent.dependent.push(second_top_level_dependent)

    direct_dependent_target = double("direct_dependent_target")
    allow(direct_dependent_target).to receive(:uuid).and_return("direct_dependent_target")
    direct_dependent = XcodeArchiveCache::BuildGraph::Node.new("direct_dependent", direct_dependent_target)
    direct_dependent.dependent.push(below_the_top_dependent)

    @node.dependent.push(direct_dependent)
    allow(@native_target).to receive(:uuid).and_return("node")

    all_dependent_nodes = @node.all_dependent_nodes
    expect(all_dependent_nodes.include?(first_top_level_dependent)).to be_truthy
    expect(all_dependent_nodes.include?(second_top_level_dependent)).to be_truthy
    expect(all_dependent_nodes.include?(below_the_top_dependent)).to be_truthy
    expect(all_dependent_nodes.include?(direct_dependent)).to be_truthy

    expect(all_dependent_nodes.include?(@node)).to be_falsey
  end

  it "should equal to itself" do
    allow(@native_target).to receive(:uuid).and_return("node")
    allow(@native_target).to receive(:project).and_return("project")
    expect(@node).to eq(@node)
  end

  it "should equal to node with the same target from the same project" do
    allow(@native_target).to receive(:uuid).and_return("node")
    allow(@native_target).to receive(:project).and_return("project")

    second_node = XcodeArchiveCache::BuildGraph::Node.new("node", @native_target)
    expect(@node).to eq(second_node)
  end

  it "should not equal to node with the same target uuid from other project" do
    allow(@native_target).to receive(:uuid).and_return("node")
    allow(@native_target).to receive(:project).and_return("project")

    other_target = double("other_target")
    allow(other_target).to receive(:uuid).and_return("node")
    allow(other_target).to receive(:project).and_return("other_project")
    other_node = XcodeArchiveCache::BuildGraph::Node.new("node", other_target)

    expect(@node).to_not eq(other_node)
  end

  it "should not equal to node with other target from the same project" do
    allow(@native_target).to receive(:uuid).and_return("node")
    allow(@native_target).to receive(:project).and_return("project")

    other_target = double("other_target")
    allow(other_target).to receive(:uuid).and_return("other_node")
    allow(other_target).to receive(:project).and_return("other_project")
    other_node = XcodeArchiveCache::BuildGraph::Node.new("node", other_target)
    expect(@node).to_not eq(other_node)
  end
end
