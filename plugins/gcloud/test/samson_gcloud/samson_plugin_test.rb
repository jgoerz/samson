# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SamsonGcloud do
  describe :after_deploy do
    let(:deploy) { deploys(:succeeded_test) }

    it "tags" do
      with_env GCLOUD_IMAGE_TAGGER: 'true' do
        SamsonGcloud::ImageTagger.expects(:tag)
        Samson::Hooks.fire(:after_deploy, deploy, deploy.user)
      end
    end
  end

  describe :project_permitted_params do
    it "adds build_with_gcb" do
      params = Samson::Hooks.fire(:project_permitted_params).flatten
      params.must_include :build_with_gcb
      params.must_include :show_gcr_vulnerabilities
    end
  end

  describe :stage_permitted_params do
    it "adds block_on_gcr_vulnerabilities" do
      Samson::Hooks.fire(:stage_permitted_params).must_include :block_on_gcr_vulnerabilities
    end
  end

  describe :ensure_build_is_successful do
    def fire
      Samson::Hooks.fire(:ensure_build_is_successful, build, job, output)
    end

    let(:build) { builds(:docker_build) }
    let(:job) { jobs(:succeeded_test) }
    let(:output) { StringIO.new }

    it "does nothing when GCLOUD_IMAGE_SCANNER is disabled" do
      job.project.show_gcr_vulnerabilities = true
      fire.must_equal [true]
      output.string.must_equal ""
    end

    it "does nothing when show_gcr_vulnerabilities is disabled" do
      with_env GCLOUD_IMAGE_SCANNER: "true" do
        fire.must_equal [true]
        output.string.must_equal ""
      end
    end

    describe "with GCLOUD_IMAGE_SCANNER" do
      def expects_sleep(times)
        SamsonGcloud.unstub(:sleep)
        SamsonGcloud.expects(:sleep).times(times)
      end

      with_env GCLOUD_IMAGE_SCANNER: "true", GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj'

      before do
        job.project.show_gcr_vulnerabilities = true
        SamsonGcloud.expects(:sleep).with { raise }.never
      end

      it "shows success" do
        SamsonGcloud::ImageScanner.expects(:scan).returns SamsonGcloud::ImageScanner::SUCCESS
        fire.must_equal [true]
        output.string.must_equal "Waiting for GCR scan to finish...\nNo vulnerabilities found\n"
        build.gcr_vulnerabilities_status_id.must_equal SamsonGcloud::ImageScanner::SUCCESS
      end

      it "does not re-scan when a result was found" do
        SamsonGcloud::ImageScanner.expects(:scan).never
        build.gcr_vulnerabilities_status_id = SamsonGcloud::ImageScanner::SUCCESS
        fire.must_equal [true]
        output.string.must_equal "No vulnerabilities found\n"
        build.gcr_vulnerabilities_status_id.must_equal SamsonGcloud::ImageScanner::SUCCESS
      end

      it "shows failures" do
        SamsonGcloud::ImageScanner.expects(:scan).returns SamsonGcloud::ImageScanner::FOUND
        fire.must_equal [true]
        output.string.must_include "Vulnerabilities found, see https://"
        build.gcr_vulnerabilities_status_id.must_equal SamsonGcloud::ImageScanner::FOUND
      end

      it "does not wait when a scan is not required" do
        SamsonGcloud::ImageScanner.expects(:scan).returns SamsonGcloud::ImageScanner::WAITING
        fire.must_equal [true]
      end

      describe "when scan is required" do
        before { job.deploy.stage.block_on_gcr_vulnerabilities = true }

        it "waits until the scan is finished" do
          SamsonGcloud::ImageScanner.expects(:scan).times(3).returns(
            SamsonGcloud::ImageScanner::WAITING,
            SamsonGcloud::ImageScanner::WAITING,
            SamsonGcloud::ImageScanner::FOUND
          )
          expects_sleep 2
          fire.must_equal [false]
        end

        it "fails if waiting did not help" do
          SamsonGcloud::ImageScanner.expects(:scan).times(60).returns(SamsonGcloud::ImageScanner::WAITING)
          expects_sleep 60
          fire.must_equal [false]
        end

        it "stops the deploy when stage enforces scans" do
          SamsonGcloud::ImageScanner.expects(:scan).returns 2
          fire.must_equal [false]
          build.gcr_vulnerabilities_status_id.must_equal SamsonGcloud::ImageScanner::FOUND
        end
      end
    end
  end

  describe ".cli_options" do
    it "includes options from ENV var" do
      with_env(GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj', GCLOUD_OPTIONS: '--foo "bar baz"') do
        SamsonGcloud.cli_options.must_equal ['--foo', 'bar baz', '--account', 'acc', '--project', 'proj']
      end
    end

    it "does not include options from ENV var when not set" do
      with_env(GCLOUD_ACCOUNT: 'acc', GCLOUD_PROJECT: 'proj') do
        SamsonGcloud.cli_options.must_equal ['--account', 'acc', '--project', 'proj']
      end
    end
  end

  describe ".project" do
    it "fetches" do
      with_env GCLOUD_PROJECT: '123' do
        SamsonGcloud.project.must_equal "123"
      end
    end

    it "cannot be used to hijack commands" do
      with_env GCLOUD_PROJECT: '123; foo' do
        SamsonGcloud.project.must_equal "123\\;\\ foo"
      end
    end

    it "fails when not set since it would break commands" do
      assert_raises(KeyError) { SamsonGcloud.project }
    end
  end

  describe ".account" do
    it "fetches" do
      with_env GCLOUD_ACCOUNT: '123' do
        SamsonGcloud.account.must_equal "123"
      end
    end

    it "cannot be used to hijack commands" do
      with_env GCLOUD_ACCOUNT: '123; foo' do
        SamsonGcloud.account.must_equal "123\\;\\ foo"
      end
    end

    it "fails when not set since it would break commands" do
      assert_raises(KeyError) { SamsonGcloud.account }
    end
  end
end
