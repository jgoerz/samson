# frozen_string_literal: true
puts "Seeding with custom data"

# Sample data that would load the default above. (it's not quite identical)
# ---
# projects:
#   - name: "Production"
#     repository_url: "https://github.com/samson-test-org/example-project.git"
#     stages:
#       - name: "Production"
#         production: true
# users:
#   - name: "Mr. Seed"
#     email: "seed@example.com"
#     external_id: "123"

data = YAML.safe_load(File.read('custom/seeds.yml'))

# Global Commands
if data.key?('commands')
  data['commands'].each_with_index do |command, index|
    cmd = Command.create!(
        command: command['command']
    )
    data['commands'][index]['id'] = cmd.id
  end
end

# Load projects, and their stages and commands.
if data.key?('projects')
  data['projects'].each do |project|
    p_obj = Project.create!(
      name: project['name'],
      repository_url: project['repository_url'],
      permalink: project['permalink']
    )
    project['id'] = p_obj.id

    if project.key?('stages')
      project['stages'].each do |stage|
        s_obj = p_obj.stages.create!(
          name: stage['name'],
          production: stage['production'],
          cancel_queued_deploys: stage['cancel_queued_deploys'],
          permalink: stage['permalink']
        )
        stage['id'] = s_obj.id

        if stage.key?('webhooks')
          webhooks = stage['webhooks']
          webhooks.each do |webhook|
            Webhook.create!(
              project_id: p_obj.id,
              stage_id: s_obj.id,
              branch: webhook['branch'],
              source: webhook['source']
            )
          end
        end

        if stage.key?('notify_slack') && stage['notify_slack'] == true
          SlackWebhook.create!(
            webhook_url: 'https://hooks.slack.com/services/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',
            stage_id: s_obj.id,
            before_deploy: true,
            after_deploy: true
          )
        end

        # Create default stage scripts, basically a join table of stages and commands with position
        # parameter to show sequence of commands.  There are currently 8 steps to each sequence if
        # they use _all_ the "template" commands.
        if stage.key?('do_stage_commands') && stage['do_stage_commands'] != false
          position = 1
          1.upto(7) do |meta_order|
            result = data['commands'].select{|c| c["meta_order"] == meta_order}

            if result.count == 0
              raise StandardError.new("No commands in seeds file with 'meta_order' field?")

            elsif result.count == 1
              StageCommand.create!(command_id: result.first['id'], stage: s_obj, position: position)

            else
              cmd = nil
              if result.first['meta_env'] =~ /^branch,/ # Super ewww!
                cmd = result.select do |c| 
                  not_used, *branches = *c['meta_env'].split(',') 
                  branches.any? do |branch|
                    "#{stage['cmd_meta_env']}" =~ Regexp.new("#{branch}|#{branch}-utllity")
                  end
                end
                cmd = cmd.first
              else
                cmd = result.select{|c| c['meta_env'] == stage['cmd_meta_env']}.first
              end
              cmd = cmd.nil? ? {} : cmd

              StageCommand.create!(command_id: cmd['id'], stage: s_obj, position: position)
            end

            position += 1
          end
        end # stage_commands

      end # stages
    end # stages exist

    # per project commands
    if project.key?('commands')
      project['commands'].each do |command|
        p_obj.commands.create!(
          command: command['command']
        )
      end
    end
  end
end

# Handle slack webhooks, need references to project_id and stage_id.
if data.key?('projects')
  data['projects'].each do |project|
    stages_w_pipelines = project['stages'].select do |stage|
      if stage.key?('pipelines')
        true
      else
        false
      end
    end

    stages_w_pipelines.each do |stage|
      s_obj = Stage.find(stage['id'])
      followers = []
      stage['pipelines'].each do |next_stage_name|
        follower = project['stages'].detect{|s| s['name'] == next_stage_name}
        followers << follower['id'] if follower
      end
      s_obj.next_stage_ids = followers
      s_obj.save!
    end
  end
end


# external_id follows this format:
# AUTH_MODULE-IDENTIFIER
# example gitlab: gitlab-123
# example ldap: ldap-CN=Mr. Seed,OU=Employees,...
# role_id: (see app/models/role.rb for appropriate values)
if data.key?('users')
  data['users'].each do |user|
    User.create!(
      time_format: user['time_format'],
      role_id: user['role_id'],
      name: user['name'],
      email: user['email'],
      external_id: user['external_id']
    )
  end
end


