describe IosDeployKit do
  describe IosDeployKit::ItunesTransporter, new: true do
    before do
      @app = IosDeployKit::App.new(284882215, 'com.facebook.Facebook')
    end

    describe "#download", felix: true do
      it "throws an exception when invalid parameter is given" do
        expect {
          IosDeployKit::ItunesTransporter.new.download(123)
        }.to raise_error "No valid IosDeployKit::App given"
      end

      it "downloads the package" do
        expect {
          IosDeployKit::ItunesTransporter.new("email@email.com", "login").download(@app).should eq(true)
        }.to raise_error(/.*This Apple ID has been locked for security reasons.*/)
      end

      it "works with correct inputs" do
        @app.apple_id = 794902327
        IosDeployKit::ItunesTransporter.new.download(@app).should eq(true)
      end
    end
  end
end