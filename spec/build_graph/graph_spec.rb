RSpec.describe XcodeArchiveCache::BuildGraph::Graph, "#graph" do
  before :each do
    @graph = XcodeArchiveCache::BuildGraph::Graph.new(nil, nil)

    first_target = Xcodeproj::Project::Object::PBXNativeTarget.new(nil, "first_node_uuid")
    @first_node = XcodeArchiveCache::BuildGraph::Node.new("first_node", first_target)
    @graph.nodes.push(@first_node)

    second_target = Xcodeproj::Project::Object::PBXNativeTarget.new(nil, "second_target_uuid")
    @second_node = XcodeArchiveCache::BuildGraph::Node.new("second_node", second_target)
    @graph.nodes.push(@second_node)
  end

  it "should find correct node given node's name" do
    expect(@graph.node_by_name("first_node")).to eq @first_node
  end

  it "should return nil if no node found by name" do
    expect(@graph.node_by_name("unknown")).to be_nil
  end
end