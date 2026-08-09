require "test_helper"

# The FTP backend accepts an injectable connection factory, so the tests
# drive it with an in-memory fake that mimics Net::FTP's binary
# store/retrieve interface (including 550 -> Net::FTPPermError).
class FtpBackendTest < ActiveSupport::TestCase
  class FakeFtp
    attr_reader :files, :dirs

    def initialize(shared)
      @shared = shared
    end

    def mkdir(dir)
      raise Net::FTPPermError, "550 exists" if @shared[:dirs].include?(dir)
      @shared[:dirs] << dir
    end

    def storbinary(cmd, io, _blocksize)
      path = cmd.sub("STOR ", "")
      @shared[:files][path] = io.read
    end

    def retrbinary(cmd, _blocksize)
      path = cmd.sub("RETR ", "")
      raise Net::FTPPermError, "550 #{path}: No such file" unless @shared[:files].key?(path)
      yield @shared[:files][path]
    end

    def close; end
  end

  setup do
    @shared = { files: {}, dirs: [] }
    @backend = Storage::FtpBackend.new(
      host: "ftp.example.com", user: "u", password: "p",
      base_dir: "simple_drive",
      ftp_factory: -> { FakeFtp.new(@shared) }
    )
  end

  test "round-trips binary data" do
    bytes = Random.bytes(256)
    @backend.put("ftp-id", bytes)
    assert_equal bytes, @backend.get("ftp-id")
  end

  test "stores files under base_dir with digest names" do
    @backend.put("weird/../id", "x")
    path = @shared[:files].keys.first
    assert_match %r{\Asimple_drive/\h{64}\z}, path
  end

  test "creates the base directory once and tolerates it existing" do
    @backend.put("a", "1")
    @backend.put("b", "2")
    assert_equal ["simple_drive"], @shared[:dirs]
  end

  test "maps missing files to Storage::NotFound" do
    assert_raises(Storage::NotFound) { @backend.get("missing") }
  end

  test "requires a host" do
    assert_raises(Storage::ConfigurationError) do
      Storage::FtpBackend.new(host: nil, user: "u", password: "p")
    end
  end
end
