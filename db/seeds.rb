# frozen_string_literal: true

if ENV['SETUP_USE_CUSTOM'].nil?

  prod_env = Environment.create!(
    name: 'Production',
    production: true
  )
  Environment.create!(name: 'Staging')
  Environment.create!(name: 'Master')

  prod = DeployGroup.create!(
    name: 'Production',
    environment: prod_env
  )

  project = Project.create!(
    name: "Example-project",
    repository_url: "https://github.com/samson-test-org/example-project.git"
  )

  project.stages.create!(
    name: "Production",
    deploy_groups: [prod]
  )

  user = User.create!(
    name: "Mr. Seed",
    email: "seed@example.com",
    external_id: "123"
  )

  project.releases.create!(
    commit: "1234" * 10,
    author: user
  )

else

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

  data = YAML.safe_load(File.read('db/seeds.custom.yml'))

  # Load projects, and their stages and commands.
  if data.key?('projects')
    data['projects'].each do |project|
      p_obj = Project.create!(
        name: project['name'],
        repository_url: project['repository_url']
      )

      if project.key?('stages')
        project['stages'].each do |stage|
          p_obj.stages.create!(
            name: stage['name'],
            production: stage['production'],
            cancel_queued_deploys: stage['cancel_queued_deploys']
          )
        end
      end

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

  # Global Commands
  if data.key?('commands')
    data['commands'].each do |command|
      Command.create!(
          command: command['command']
      )
    end
  end

end
