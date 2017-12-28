# frozen_string_literal: true
module SamsonGcloud
  class ImageBuilder
    class << self
      def build_image(dir, build, executor, tag_as_latest:, cache_from:)
        prefix = "gcr.io/#{SamsonGcloud.project}/samson"
        fake_registry = OpenStruct.new(base: prefix)
        base = build.project.docker_repo(fake_registry, build.dockerfile)
        tags = [build.git_sha]
        tags << "latest" if tag_as_latest
        tag_arguments = tags.map { |t| "'--tag', '#{base}:#{t}'" }.join(", ")
        tag_list = tags.map { |t| "- '#{t}'" }.join("\n")

        # build would fail on image that does not exist, so we check before pulling
        if cache_from
          if image_exists_in_gcloud?(cache_from)
            cache_pull = "\n" + <<~YAML.strip
              - name: 'gcr.io/cloud-builders/docker'
                args: ['pull', '#{cache_from}']
            YAML
            cache_options = ", '--cache-from', '#{cache_from}'"
          else
            executor.output.puts "Image #{cache_from} not found in gcr, not using cache."
          end
        end

        config = "#{dir}/cloudbuild.yml" # inside of the directory or we get 'Could not parse into a message'

        File.write(config, <<~YAML)
          steps:#{cache_pull}
          - name: 'gcr.io/cloud-builders/docker'
            args: [ 'build', #{tag_arguments}, '--file', '#{build.dockerfile}'#{cache_options}, '.' ]
          images:
          - '#{base}'
          tags:
          #{tag_list}
        YAML

        command = [
          "gcloud", *SamsonGcloud.container_in_beta, "container", "builds", "submit", ".",
          "--timeout", executor.timeout, "--config", config, *SamsonGcloud.cli_options
        ]

        return unless executor.execute(
          "cd #{dir.shellescape}",
          command.shelljoin
        )

        log = executor.output.to_s
        build.external_url = log[/Logs are permanently available at \[(.*?)\]/, 1]
        return unless digest = log[/digest: (\S+:\S+)/, 1]
        "#{base}@#{digest}"
      end

      private

      # NOTE: not using executor since it does not return output
      def image_exists_in_gcloud?(repo_digest)
        image, digest = repo_digest.split('@')
        output = Samson::CommandExecutor.execute(
          "gcloud", "container", "images", "list-tags", image,
          "--format", "get(digest)", "--filter", "digest=#{digest}", *SamsonGcloud.cli_options,
          timeout: 10
        ).last
        output.strip == digest
      end
    end
  end
end
