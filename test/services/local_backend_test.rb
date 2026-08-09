require "test_helper"

class LocalBackendTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @backend = Storage::LocalBackend.new(root: @dir)
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "round-trips binary data" do
    bytes = Random.bytes(1024)
    @backend.put("some-id", bytes)
    assert_equal bytes, @backend.get("some-id")
  end

  test "handles ids containing slashes, dots and unicode" do
    ["a/b/../c", "..", "héllo wörld", "x" * 500].each do |id|
      @backend.put(id, "data-#{id}")
      assert_equal "data-#{id}".b, @backend.get(id)
    end
  end

  test "id is never used as a raw filesystem path (no traversal)" do
    @backend.put("../../etc/passwd", "safe")
    entries = Dir.glob(File.join(@dir, "**", "*"), File::FNM_DOTMATCH).select { |f| File.file?(f) }
    assert entries.all? { |f| f.start_with?(@dir) }
    assert_equal "safe".b, @backend.get("../../etc/passwd")
  end

  test "raises NotFound for unknown ids" do
    assert_raises(Storage::NotFound) { @backend.get("missing") }
  end

  test "requires a configured path" do
    assert_raises(Storage::ConfigurationError) { Storage::LocalBackend.new(root: nil) }
  end
end
