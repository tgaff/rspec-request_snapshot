RSpec.describe Rspec::RequestSnapshot do
  it "has a version number" do
    expect(Rspec::RequestSnapshot::VERSION).not_to be nil
  end

  describe "snapshot matching" do
    context "when snapshot does not exist" do
      let(:snapshot_path) { File.join(Dir.pwd, RSpec.configuration.request_snapshots_dir, "temp.json") }

      after { FileUtils.rm(snapshot_path) }

      it "creates a new snapshot file" do
        expect({ a: 1 }.to_json).to match_snapshot("temp")
        expect(File.exist?(snapshot_path)).to be_truthy
      end
    end

    context "when snapshot exists" do
      it "matches snapshot from the file" do
        expect({ sample: "value" }.to_json).to match_snapshot("api/file")
      end

      it "does not match when snapshot file content is different" do
        expect({ sample: "other value" }.to_json).not_to match_snapshot("api/file")
      end

      context "with nested nodes" do
        it "matches snapshot from the file" do
          json = { nested: { level: { sample: "value", sample2: "value2" } } }.to_json
          expect(json).to match_snapshot("api/nested")
        end

        it "does not match when snapshot file content is different" do
          json = { nested: { level: { sample: "value", sample3: "value2" } } }.to_json
          expect(json).not_to match_snapshot("api/nested")
        end
      end
    end
  end

  describe "dynamic attributes" do
    it "ignores default dynamic attributes" do
      json = { id: 99, created_at: false, updated_at: Time.now }.to_json
      expect(json).to match_snapshot("api/dynamic_attributes")
    end

    it "ignores passed dynamic attributes" do
      json = { custom: "different value from snapshot" }.to_json
      expect(json).to match_snapshot("api/custom_dynamic_attributes", dynamic_attributes: %w(custom))
    end

    it "ignores nodes inside object arrays" do
      json = { objects: [{ id: 10, value: "value 10" }, { id: 22, value: "value 20" }] }.to_json
      expect(json).to match_snapshot("api/array_dynamic_attributes", dynamic_attributes: %w(id))
    end
  end

  describe "ordering" do
    it "ignores ordering for nodes that are in ignore_order" do
      json = { id: 100, values: { ordered: [1, 2, 3], unordered: [8, 3, 7] } }.to_json
      expect(json).to match_snapshot("api/ordering", ignore_order: %w(unordered))
    end

    it "does not match if ordering is different and we dont ignore" do
      json = { id: 100, values: { ordered: [1, 2, 3], unordered: [8, 3, 7] } }.to_json
      expect(json).not_to match_snapshot("api/ordering")
    end

    it "ignores ordering for object arrays" do
      json = { objects: [{ id: 20, value: "value 20" }, { id: 10, value: "value 10" }] }.to_json
      expect(json).to match_snapshot("api/ordering_objects", ignore_order: %w(objects))
    end

    context "when setting ignore_order configuration" do
      before { RSpec.configuration.request_snapshots_ignore_order = %w(unordered) }
      after { RSpec.configuration.request_snapshots_ignore_order = %w() }

      it "ignores ordering for nodes that are in ignore_order" do
        json = { id: 100, values: { ordered: [1, 2, 3], unordered: [8, 3, 7] } }.to_json
        expect(json).to match_snapshot("api/ordering")
      end
    end
  end

  describe "complex scenarios" do
    let(:complex_json) do
      {
        data: {
          books: [{ id: 22, name: "two" }, { id: 11, name: "one" }],
          value: "value"
        },
        objects: [
          {
            pens: [
              { id: 40, name: "one", prices: [1, 3, 2] },
              { id: 50, name: "two", prices: [7, 5, 6] }
            ],
            computers: [
              {
                id: 10,
                name: "computer two",
                pieces: [
                  { id: 10, name: "one", prices: [11, 12, 13] },
                  { id: 20, name: "two", prices: [14, 15, 16] },
                  { id: 30, name: "three", prices: [17, 18, 19] }
                ]
              },
              {
                id: 20,
                name: "computer one",
                pieces: [
                  { id: 20, name: "one", prices: [1, 3, 2] },
                  { id: 10, name: "two", prices: [4, 5, 6] },
                  { id: 30, name: "three", prices: [9, 8, 7] }
                ]
              }
            ]
          }
        ]
      }.to_json
    end

    it "matches snapshot for a complex scenario" do
      expect(complex_json).to match_snapshot(
        "api/complex_json", dynamic_attributes: %w(id), ignore_order: %w(books computers prices)
      )
    end
  end

  describe "text format" do
    before(:all) { RSpec.configuration.request_snapshots_default_format = :text }
    after(:all) { RSpec.configuration.request_snapshots_default_format = :json }

    let(:sample_text) { "XX alpha=beta XX gamma=epsilon XX beta=beta" }

    it "matches basic text" do
      expect(sample_text).to match_snapshot("api/basic_text", format: :text)
    end

    describe "exclusions" do
      it "matches with exclusions" do
        expect(sample_text.gsub("beta", "beeeeeeta")).to match_snapshot("api/basic_text", excluding: [/be+ta/])
      end

      it "matches with multiple exclusions" do
        expected = sample_text.gsub("beta", "beeeeeeta").gsub("alpha", "alph")
        expect(expected).to match_snapshot("api/basic_text", excluding: [/be+ta/, /alpha?/])
      end

      it "matches when exclusions are not found" do # is this desired, or better to raise?
        expect(sample_text).to match_snapshot("api/basic_text", excluding: [/asdf/])
      end

      it "matches with a single non-array exclusion" do
        expect(sample_text.gsub("beta", "beeeeeeta")).to match_snapshot("api/basic_text", excluding: /be+ta/)
      end

      it "fails when the exclusions don't excluding the differing segment" do
        expect(sample_text.gsub("alpha", "alppppppha")).not_to match_snapshot("api/basic_text", excluding: [/be+ta/])
      end

      context "when setting a config level request_snapshots_text_excluding setting" do
        before { RSpec.configuration.request_snapshots_text_excluding = [/be+ta/] }
        after { RSpec.configuration.request_snapshots_text_excluding = [] }

        it "matches with exclusions" do
          expect(sample_text.gsub("beta", "beeeeeeta")).to match_snapshot("api/basic_text")
        end
      end
    end
  end

  describe "format" do
    let(:sample_text) { "My text test" }

    it "matches snapshot with text format" do
      expect(sample_text).to match_snapshot("api/text", format: :text)
    end

    it "defaults to json format when not specified" do
      expect(RSpec.configuration.request_snapshots_default_format).to eq :json
    end

    context ":text format" do
      before { RSpec.configuration.request_snapshots_default_format = :text }
      after { RSpec.configuration.request_snapshots_default_format = :json }

      it "matches text without passing the format argument" do
        expect(sample_text).to match_snapshot("api/text")
      end
    end
  end
end
