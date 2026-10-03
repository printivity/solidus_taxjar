require "spec_helper"
require "socket"

RSpec.describe "TaxJar client HTTP timeouts" do
  around do |example|
    original = SuperGood::SolidusTaxjar.http_timeouts
    example.run
  ensure
    SuperGood::SolidusTaxjar.http_timeouts = original
  end

  def build_request(client, options = {})
    Taxjar::API::Request.new(client, :post, "/v2/taxes", "tax", options)
  end

  describe "SuperGood::SolidusTaxjar::Api.default_taxjar_client" do
    it "carries the configured connect, write and read timeouts" do
      SuperGood::SolidusTaxjar.http_timeouts = {connect: 1, write: 2, read: 3}

      client = SuperGood::SolidusTaxjar::Api.default_taxjar_client

      expect(client.get_api_config("http_timeouts")).to eq(connect: 1, write: 2, read: 3)
    end

    it "ships with finite defaults" do
      expect(SuperGood::SolidusTaxjar.http_timeouts).to eq(connect: 2, write: 5, read: 8)
    end

    [
      nil,
      {connect: 2, write: 5},
      {connect: 2, write: 5, read: nil},
      {connect: 2, write: 5, read: "8"},
      {connect: 0, write: 5, read: 8}
    ].each do |bad_value|
      it "refuses to build a client when http_timeouts is #{bad_value.inspect}" do
        SuperGood::SolidusTaxjar.http_timeouts = bad_value

        expect { SuperGood::SolidusTaxjar::Api.default_taxjar_client }
          .to raise_error(ArgumentError, /http_timeouts must set positive numeric/)
      end
    end
  end

  describe "a request made through the default client" do
    let(:client) { SuperGood::SolidusTaxjar::Api.default_taxjar_client }

    it "uses the client's timeouts when the call passes none" do
      request = build_request(client)

      expect(request.instance_variable_get(:@http_timeout)).to eq(connect: 2, write: 5, read: 8)
      expect { request.send(:build_http_client) }.not_to raise_error
    end

    it "lets a timeout passed on the call win" do
      request = build_request(client, timeout: 30)

      expect(request.instance_variable_get(:@http_timeout)).to eq(write: 30, connect: 30, read: 30)
    end

    context "when TaxJar accepts the connection but never answers" do
      let!(:server) { TCPServer.new("127.0.0.1", 0) }
      let!(:silent_peer) do
        Thread.new do
          socket = server.accept
          sleep 5
          socket.close
        rescue IOError
          nil
        end
      end

      after do
        silent_peer.kill
        server.close
      end

      it "raises Taxjar::Error once the read timeout passes" do
        SuperGood::SolidusTaxjar.http_timeouts = {connect: 1, write: 1, read: 0.3}
        client.api_url = "http://127.0.0.1:#{server.addr[1]}"

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect { client.tax_for_order(to_country: "US", amount: 1, shipping: 0) }
          .to raise_error(Taxjar::Error, /timed out/i)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        expect(elapsed).to be < 3
      end
    end
  end

  describe "a request made through a client with no configured timeouts" do
    let(:client) { Taxjar::Client.new(api_key: "test_key", api_url: "https://api.taxjar.com") }

    it "keeps taxjar-ruby's own behavior" do
      request = build_request(client, timeout: 5)

      expect(request.instance_variable_get(:@http_timeout)).to eq(write: 5, connect: 5, read: 5)
    end
  end
end
