require "test_helper"

class SigV4Test < ActiveSupport::TestCase
  # Official AWS Signature Version 4 example request from the AWS
  # documentation ("Create a signed AWS API request", IAM ListUsers).
  # Reproducing the documented signature verifies the signer end to end:
  # canonical request, string-to-sign, key derivation and final HMAC.
  test "reproduces the documented AWS SigV4 example signature" do
    signer = Storage::SigV4.new(
      access_key_id: "AKIDEXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
      region: "us-east-1",
      service: "iam"
    )

    headers = signer.sign(
      method: "GET",
      host: "iam.amazonaws.com",
      path: "/",
      query: { "Action" => "ListUsers", "Version" => "2010-05-08" },
      headers: { "content-type" => "application/x-www-form-urlencoded; charset=utf-8" },
      payload: "",
      time: Time.utc(2015, 8, 30, 12, 36, 0)
    )

    expected = "AWS4-HMAC-SHA256 " \
      "Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, " \
      "SignedHeaders=content-type;host;x-amz-date, " \
      "Signature=5d672d79c15b13162d9279b0855cfba6789a8edb4c82c400e06b5924a6f2b5d7"

    assert_equal expected, headers["authorization"]
    assert_equal "20150830T123600Z", headers["x-amz-date"]
  end

  test "uri_encode percent-encodes everything except unreserved characters" do
    assert_equal "a-b_c.d~e", Storage::SigV4.uri_encode("a-b_c.d~e")
    assert_equal "docs%2Fh%C3%A9llo%20world", Storage::SigV4.uri_encode("docs/héllo world")
  end

  test "s3 requests include x-amz-content-sha256 in signed headers" do
    signer = Storage::SigV4.new(
      access_key_id: "k", secret_access_key: "s", region: "us-east-1", service: "s3"
    )
    headers = signer.sign(method: "PUT", host: "example.com", path: "/b/o", payload: "hi")

    assert_equal Digest::SHA256.hexdigest("hi"), headers["x-amz-content-sha256"]
    assert_includes headers["authorization"], "x-amz-content-sha256"
  end
end
