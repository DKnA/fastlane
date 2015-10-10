describe Fastlane do
  describe Fastlane::FastFile do
    describe "#initialize" do
      it "raises an error if file does not exist" do
        expect do
          Fastlane::FastFile.new('./spec/fixtures/fastfiles/fastfileNotHere')
        end.to raise_exception "Could not find Fastfile at path './spec/fixtures/fastfiles/fastfileNotHere'".red
      end

      it "raises an error if unknow method is called" do
        expect do
          Fastlane::FastFile.new('./spec/fixtures/fastfiles/FastfileInvalid')
        end.to raise_exception "Could not find action or lane 'laneasdf'. Check out the README for more details: https://github.com/KrauseFx/fastlane".red
      end
    end

    describe "#is_platform_block?" do
      before do
        @ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/FastfileGrouped')
      end

      it "return true if it's a platform" do
        expect(@ff.is_platform_block? 'mac').to eq(true)
      end

      it "return true if it's a platform" do
        expect(@ff.is_platform_block? 'test').to eq(false)
      end

      it "raises an exception if key doesn't exist at all" do
        expect do
          @ff.is_platform_block? "asdf"
        end.to raise_error("Could not find 'asdf'. Available lanes: test, anotherroot, mac beta, ios beta, ios release, android beta, android witherror, android unsupported_action".red)
      end
    end

    describe "#lane_name" do
      before do
        @ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/Fastfile1')
      end

      it "raises an error if block is missing" do
        expect do
          @ff.lane("my_name")
        end.to raise_exception "You have to pass a block using 'do' for lane 'my_name'. Make sure you read the docs on GitHub.".red
      end

      it "takes the block and lane name" do
        @ff.lane :my_name do
        end
      end

      it "raises an error if name contains spaces" do
        expect do
          @ff.lane :"my name" do
          end
        end.to raise_error "lane name must not contain any spaces".red
      end

      it "raises an error if the name is on a black list" do
        expect do
          @ff.lane :run do
          end
        end.to raise_error "Name 'run' is already taken"
      end

      it "raises an error if name is not a symbol" do
        expect do
          @ff.lane "string" do
          end
        end.to raise_error "lane name must start with :".red
      end
    end

    describe "Grouped fastlane for different platforms" do
      before do
        FileUtils.rm_rf('/tmp/fastlane/')

        @ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/FastfileGrouped')
      end

      it "calls a block for a given platform (mac - beta)" do
        @ff.runner.execute('beta', 'mac')

        expect(File.exist?('/tmp/fastlane/mac_beta.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/before_all_android.txt')).to eq(false)
        expect(File.exist?('/tmp/fastlane/before_all.txt')).to eq(true)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::LANE_NAME]).to eq("mac beta")
      end

      it "calls a block for a given platform (android - beta)" do
        @ff.runner.execute('beta', 'android')

        expect(File.exist?('/tmp/fastlane/android_beta.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/before_all_android.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/after_all_android.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/before_all.txt')).to eq(true)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::LANE_NAME]).to eq("android beta")
      end

      it "calls all error blocks if multiple are given (android - witherror)" do
        expect do
          @ff.runner.execute('witherror', 'android')
        end.to raise_error 'my exception'

        expect(File.exist?('/tmp/fastlane/before_all_android.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/after_all_android.txt')).to eq(false)
        expect(File.exist?('/tmp/fastlane/android_error.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/error.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/before_all.txt')).to eq(true)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::PLATFORM_NAME]).to eq(:android)
      end

      it "allows calls without a platform (nil - anotherroot)" do
        @ff.runner.execute('anotherroot')

        expect(File.exist?('/tmp/fastlane/before_all_android.txt')).to eq(false)
        expect(File.exist?('/tmp/fastlane/after_all_android.txt')).to eq(false)
        expect(File.exist?('/tmp/fastlane/android_error.txt')).to eq(false)
        expect(File.exist?('/tmp/fastlane/error.txt')).to eq(false)
        expect(File.exist?('/tmp/fastlane/before_all.txt')).to eq(true)
        expect(File.exist?('/tmp/fastlane/another_root.txt')).to eq(true)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::LANE_NAME]).to eq("anotherroot")
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::PLATFORM_NAME]).to eq(nil)
      end

      it "raises an exception if unsupported action is called in unsupported platform" do
        expect do
          @ff.runner.execute('unsupported_action', 'android')
        end.to raise_error "Action 'frameit' doesn't support required operating system 'android'.".red
      end
    end

    describe "Different Fastfiles" do
      it "execute different envs" do
        FileUtils.rm_rf('/tmp/fastlane/')
        FileUtils.mkdir_p('/tmp/fastlane/')

        ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/Fastfile1')
        ff.runner.execute(:deploy)
        expect(File.exist?('/tmp/fastlane/before_all')).to eq(true)
        expect(File.exist?('/tmp/fastlane/deploy')).to eq(true)
        expect(File.exist?('/tmp/fastlane/test')).to eq(false)
        expect(File.exist?('/tmp/fastlane/after_all')).to eq(true)
        expect(File.read("/tmp/fastlane/after_all")).to eq("deploy")

        ff.runner.execute(:test)
        expect(File.exist?('/tmp/fastlane/test')).to eq(true)
      end

      describe "supports switching lanes" do
        it "use case 1: passing parameters to another lane and getting the result" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          ff.runner.execute(:lane1, :ios)

          expect(File.read("/tmp/deliver_result.txt")).to eq("Lane 2 + parameter")
        end

        it "properly tracks the lane switches" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          ff.runner.execute(:lane1, :ios)

          expect(ff.collector.launches).to eq({
            lane_switch: 1
          })

          expect(Fastlane::ActionCollector.new.is_official?(:lane_switch)).to eq(true)
        end

        it "use case 2: passing no parameter to a lane that takes parameters" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          ff.runner.execute(:lane3, :ios)

          expect(File.read("/tmp/deliver_result.txt")).to eq("Lane 2 + ")
        end

        it "use case 3: Calling a lane directly which takes parameters" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          ff.runner.execute(:lane4, :ios)

          expect(File.read("/tmp/deliver_result.txt")).to eq("{}")
        end

        it "use case 4: Passing parameters to another lane" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          ff.runner.execute(:lane5, :ios)

          expect(File.read("/tmp/deliver_result.txt")).to eq("{:key=>:value}")
        end

        it "use case 5: Calling a method outside of the current platform" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          ff.runner.execute(:call_general_lane, :ios)

          expect(File.read("/tmp/deliver_result.txt")).to eq("{:random=>:value}")
        end

        it "calling a lane that doesn't exist" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          expect do
            ff.runner.execute(:invalid, :ios)
          end.to raise_error "Could not find action or lane 'wrong_platform'. Check out the README for more details: https://github.com/KrauseFx/fastlane".red
        end

        it "raises an exception when not passing a hash" do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/SwitcherFastfile')
          expect do
            ff.runner.execute(:invalid_parameters, :ios)
          end.to raise_error "Parameters for a lane must always be a hash".red
        end
      end

      it "collects the lane description for documentation" do
        ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/Fastfile1')
        ff.runner.execute(:deploy)

        expect(ff.runner.lanes[nil][:deploy].description).to eq(["My Deploy", "description"])
        expect(ff.runner.lanes[:mac][:specific].description).to eq(["look at my mac, my mac is amazing"])
      end

      it "execute different envs with lane in before block" do
        FileUtils.rm_rf('/tmp/fastlane/')
        FileUtils.mkdir_p('/tmp/fastlane/')

        ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/Fastfile2')
        ff.runner.execute(:deploy)
        expect(File.exist?('/tmp/fastlane/before_all_deploy')).to eq(true)
        expect(File.exist?('/tmp/fastlane/deploy')).to eq(true)
        expect(File.exist?('/tmp/fastlane/test')).to eq(false)
        expect(File.exist?('/tmp/fastlane/after_all')).to eq(true)
        expect(File.read("/tmp/fastlane/after_all")).to eq("deploy")

        ff.runner.execute(:test)
        expect(File.exist?('/tmp/fastlane/test')).to eq(true)
      end

      it "automatically converts invalid quotations" do
        ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/FastfileInvalidQuotation')
        # No exception :)
      end

      it "properly shows an error message when there is a syntax error in the Fastfile" do
        expect do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/FastfileSytnaxError')
        end.to raise_error("Syntax error in your Fastfile on line 17: spec/fixtures/fastfiles/FastfileSytnaxError:17: syntax error, unexpected keyword_end, expecting ')'".red)
      end

      it "properly shows an error message when there is a syntax error in the Fastfile from string" do
        expect do
          ff = Fastlane::FastFile.new.parse("lane :test do
            cases = [:abc,
          end")
        end.to raise_error("Syntax error in your Fastfile on line 3: (eval):3: syntax error, unexpected keyword_end, expecting ']'
          end
             ^".red)
      end

      it "properly shows an error message when there is a syntax error in the imported Fastfile" do
        ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/Fastfile')
        expect do
          ff.import('./FastfileSytnaxError')
        end.to raise_error("Syntax error in your Fastfile on line 17: spec/fixtures/fastfiles/FastfileSytnaxError:17: syntax error, unexpected keyword_end, expecting ')'".red)
      end

      it "raises an error if lane is not available" do
        ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/Fastfile1')
        expect do
          ff.runner.execute(:not_here)
        end.to raise_exception("Could not find lane 'not_here'. Available lanes: test, deploy, error_causing_lane, mac specific".red)
      end

      it "raises an error if the lane name contains spaces" do
        expect do
          ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/FastfileInvalidName')
        end.to raise_error "lane name must not contain any spaces".red
      end

      it "runs pod install" do
        result = Fastlane::FastFile.new.parse("lane :test do
          cocoapods
        end").runner.execute(:test)

        expect(result).to eq("pod install")
      end

      it "calls the error block when an error occurs" do
        FileUtils.rm_rf('/tmp/fastlane/')
        FileUtils.mkdir_p('/tmp/fastlane/')

        ff = Fastlane::FastFile.new('./spec/fixtures/fastfiles/Fastfile1')
        expect do
          ff.runner.execute(:error_causing_lane)
        end.to raise_exception("divided by 0")

        expect(File.exist?('/tmp/fastlane/before_all')).to eq(true)
        expect(File.exist?('/tmp/fastlane/deploy')).to eq(false)
        expect(File.exist?('/tmp/fastlane/test')).to eq(false)
        expect(File.exist?('/tmp/fastlane/after_all')).to eq(false)
        expect(File.exist?('/tmp/fastlane/error')).to eq(true)

        expect(File.read("/tmp/fastlane/error")).to eq("error_causing_lane")
      end

      it "raises an error if one lane is defined multiple times" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
          end
          lane :test do
          end")
        end.to raise_exception "Lane 'test' was defined multiple times!".red
      end
    end
  end
end
