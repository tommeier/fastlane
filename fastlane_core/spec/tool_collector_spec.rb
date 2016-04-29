describe FastlaneCore::ToolCollector do
  let(:collector) { FastlaneCore::ToolCollector.new }

  it "keeps track of what tools get invoked" do
    collector.did_launch_action(:scan)

    expect(collector.launches[:scan]).to eq(1)
  end

  it "does not keep track of tools which are not official" do
    collector.did_launch_action(:blah)

    expect(collector.launches[:blah]).to be_nil
  end

  it "tracks which official tool raises an error" do
    collector.did_raise_error(:scan)

    expect(collector.error).to eq(:scan)
  end

  it "does not track which unofficial tools that raise an error" do
    collector.did_raise_error(:blah)

    expect(collector.error).to be_nil
  end

  it "posts the collected data when finished" do
    collector.did_launch_action(:gym)
    collector.did_launch_action(:scan)
    collector.did_raise_error(:scan)
    url = collector.did_finish

    form = Hash[URI.decode_www_form(url.split("?")[1])]
    form["steps"] = JSON.parse form["steps"]

    expect(form["steps"]["gym"]).to eq(1)
    expect(form["steps"]["scan"]).to eq(1)
    expect(form["error"]).to eq("scan")
  end
end
