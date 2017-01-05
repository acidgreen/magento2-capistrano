#ssh_options[:forward_agent] = true
default_run_options[:pty] = true  # Must be set for the password prompt 

set :composer_bin, "composer"
set :php_bin, "php"
# Instead of updating the composer_bin and php_bin variables above, another way is to configure env PATHs as per below example
#default_environment["PATH"] = "/home/user/bin:/opt/remi/php56/root/usr/bin:/opt/remi/php56/root/usr/sbin${PATH:+:${PATH}}"
#default_environment["LD_LIBRARY_PATH"] = "/home/user/bin:/opt/remi/php56/root/usr/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# from git to work
set :application, "{put_application_name}"
set :repository,  "git@bitbucket.org:acidgreen/{project}.git"
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`
set :scm, :git
set :use_sudo, false
set :group_writable, true

set :keep_releases, 2
set :stage_dir, "dev/tools/capistrano/config/deploy"

set :app_symlinks, ["/pub/media", "/pub/static/_cache", "/var/backups", "/var/composer_home", "/var/importexport", "/var/import_history", "/var/log", "/var/session", "/var/report", "/var/support", "/var/export"]
set :app_shared_dirs, ["/app/etc/", "/pub/media", "/pub/static/_cache", "/var/backups", "/var/composer_home", "/var/importexport", "/var/import_history", "/var/log", "/var/session", "/var/report", "/var/support", "/var/export"]
set :app_shared_files, ["/app/etc/config.php","/app/etc/env.php", "/var/varnish.vcl", "/var/default.vcl"]

set :ensure_folders, ["/var","/pub/static"]
set :cleanup_files, [];

set :stages, %w(dev staging production)
set :default_stage, "dev"

set :composer_install_options, "--no-dev"
set :magento_deploy_maintenance, false
_cset(:whitelisted_ips)     {%w(220.244.29.70 121.97.16.114 58.69.143.1 180.232.105.194 112.199.110.130 112.199.110.140 119.93.249.156 119.93.179.15 202.78.101.222 114.108.245.51)}

# Post deployment commands
set :post_deployment_commands, []

load 'dev/tools/capistrano/config/deploy'
require 'capistrano/ext/multistage'

def remote_file_exists?(full_path)
  'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
end


# we will ask which tag to deploy; default = latest
# http://nathanhoad.net/deploy-from-a-git-tag-with-capistrano
set :branch do
    Capistrano::CLI.ui.say "    Retrieving available branches and tags...\n\n"
    branches, tags = [], []
    `git ls-remote #{repository}`.split("\n").each { |branch_tag|
        tags.push branch_tag if branch_tag.include? "refs/tags/"
        branches.push branch_tag if branch_tag.include? "refs/heads/"
    }

    if not tags.empty? then
        Capistrano::CLI.ui.say "    Available TAGS:\n\t "
        tags.each { |tag|
            next if tag.end_with? "^{}"
            Capistrano::CLI.ui.say "#{tag.split('refs/tags/').last}  "
        }
        Capistrano::CLI.ui.say "\n"
    end

    if not branches.empty? then
        Capistrano::CLI.ui.say "    Available BRANCHES:\n"
        branches.each { |branch|
            Capistrano::CLI.ui.say "\t- #{branch.split('refs/heads/').last}\n"
        }
        Capistrano::CLI.ui.say "\n"
    end

    tag = Capistrano::CLI.ui.ask "*** Please specify the branch or tag to deploy: "
    abort "Branch/tag identifier required; aborting deployment." if tag.empty?
    tag
end unless exists?(:branch)

namespace :magento do
  
    set :cold_deploy, false

    namespace :file do 
        desc <<-DESC
            test existence of missing file
        DESC
        task :exists do
            # puts "in exists #{checkFileExistPath}"
            if remote_file_exists?(checkFileExistPath)
                set :isFileMissing, false
            else 
                set :isFileMissing, true
            end
            # puts "in exists and isFileMissing is #{isFileMissing}"
        end
    end

    desc <<-DESC
        Prepares one or more servers for deployment of Magento2. Before you can use any \
        of the Capistrano deployment tasks with your project, you will need to \
        make sure all of your servers have been prepared with `cap deploy:setup'. When \
        you add a new server to your cluster, you can easily run the setup task \
        on just that server by specifying the HOSTS environment variable:

        $ cap HOSTS=new.server.com magento2:setup

        It is safe to run this task on servers that have already been set up; it \
        will not destroy any deployed revisions or data.

        With :web roles
    DESC
    task :setup, :roles => :web, :except => { :no_release => true } do
        if app_shared_dirs 
            app_shared_dirs.each { |link| run "#{try_sudo} mkdir -p #{shared_path}#{link} && chmod 755 #{shared_path}#{link}"}
        end
        if app_shared_files
            app_shared_files.each { |link| run "#{try_sudo} touch #{shared_path}#{link} && chmod 755 #{shared_path}#{link}" }
        end
    end


    desc <<-DESC
        Touches up the released code. This is called by update_code \
        after the basic deploy finishes. 

        Any directories deployed from the SCM are first removed and then replaced with \
        symlinks to the same directories within the shared location.

        With :web roles
    DESC
    task :finalize_update, :roles => :web, :except => { :no_release => true } do
        # Add latest revision id to .git-ftp.log for Bitbucket Pipelines deployment via git ftp
        run "echo #{latest_revision} > #{latest_release}/.git-ftp.log"

        if ensure_folders
            # Create folders required by Magento 2
            ensure_folders.each { |dir| run "#{try_sudo} mkdir -p #{latest_release}#{dir} && chmod 755 #{latest_release}#{dir};"}
        end
        if app_symlinks
            # Remove the contents of the shared directories if they were deployed from SCM
            app_symlinks.each { |link| run "#{try_sudo} rm -rf #{latest_release}#{link}" }
            # Add symlinks the directoris in the shared location
            app_symlinks.each { |link| run "ln -nfs #{shared_path}#{link} #{latest_release}#{link}" }
        end

        if app_shared_files
            # Remove the contents of the shared directories if they were deployed from SCM
            app_shared_files.each { |link| run "#{try_sudo} rm -rf #{latest_release}/#{link}" }
            # Add symlinks the directoris in the shared location
            app_shared_files.each { |link| run "ln -s #{shared_path}#{link} #{latest_release}#{link}" }
        end
        
    end 

    desc <<-DESC
        Ensure to set up all folders and file permissions correctly - With :web roles
    DESC
    task :security, :roles => :web do
        if cleanup_files
            # Cleanup files
            cleanup_files.each { |file| run "#{try_sudo} rm -f #{latest_release}#{file};"}
        end
        # Re-setup file symlinks that has been overwritten by composer
        if app_shared_files
            # Remove the contents of the shared directories if they were deployed from SCM
            app_shared_files.each { |link| run "#{try_sudo} rm -rf #{latest_release}/#{link}" }
            # Add symlinks the directoris in the shared location
            app_shared_files.each { |link| run "ln -s #{shared_path}#{link} #{latest_release}#{link}" }
        end
        run "cd #{latest_release} && find . -type d -exec chmod 775 {} \\;"
        run "cd #{latest_release} && find . -type f -exec chmod 664 {} \\;"
    end

    task :set_cold_deploy, :roles => :web, :except => { :no_release => true } do
        set :cold_deploy, true
    end

    desc <<-DESC
        @deprecated, use task :update
        Install Magento 2 dependencies and run compilation and asset deployment
    DESC
    task :install_dependencies, :roles => :web, :except => { :no_release => true } do
        if !cold_deploy
            run "cd #{latest_release} && #{composer_bin} install --no-dev;"
            run "cd #{latest_release} && #{php_bin} bin/magento setup:upgrade --keep-generated;"
            run "cd #{latest_release} && #{php_bin} bin/magento setup:di:compile$(awk 'BEGIN {FS=\" ?= +\"}{if($1==\"multi-tenant\"){if($2==\"true\"){print \"-multi-tenant\"}}}' .capistrano/config)"
            run "cd #{latest_release} && #{php_bin} bin/magento setup:static-content:deploy $(awk 'BEGIN {FS=\" ?= +\"}{if($1==\"lang\"){print $2}}' .capistrano/config) | grep -v '\\.'"
        end
    end

    desc <<-DESC
        @deprecated, use task :update
        Install Magento 2 dependencies and run compilation and asset deployment
    DESC
    task :update, :roles => :web, :except => { :no_release => true } do
        if !cold_deploy
            magento.composer_install
            magento.di_compile
            magento.static_content_deploy
            magento.security
            magento.setup_upgrade
        end
    end

    desc <<-DESC
        Install Magento 2 dependencies and run compilation and asset deployment
    DESC
    task :composer_install, :roles => :web, :except => { :no_release => true } do
        run "cd #{latest_release} && #{composer_bin} install #{composer_install_options};"
    end

    desc <<-DESC
        Run Magento 2 setup:db-schema:upgrade and setup:db-data:upgrade, it is not recommended to run setup:upgrade
    DESC
    task :setup_upgrade, :roles => :db, :only => {:primary => true},  :except => { :no_release => true } do
        puts "Performing Magento setup upgrade"
        magento.disable_web if fetch(:magento_deploy_maintenance)
        run "cd #{latest_release} && #{php_bin} bin/magento setup:upgrade"
        magento.enable_web if fetch(:magento_deploy_maintenance)
    end

    desc <<-DESC
        Run Magento 2 DI compilation
    DESC
    task :di_compile, :roles => :web, :except => { :no_release => true } do
        run "cd #{latest_release} && #{php_bin} bin/magento setup:di:compile$(awk 'BEGIN {FS=\" ?= +\"}{if($1==\"multi-tenant\"){if($2==\"true\"){print \"-multi-tenant\"}}}' .capistrano/config)"
    end

    desc <<-DESC
        Run Magento 2 static content deployment
    DESC
    task :static_content_deploy, :roles => :web, :except => { :no_release => true } do
        run "cd #{latest_release} && touch pub/static/deployed_version.txt"
        run "cd #{latest_release} && #{php_bin} bin/magento setup:static-content:deploy $(awk 'BEGIN {FS=\" ?= +\"}{if($1==\"lang\"){print $2}}' .capistrano/config) | grep -v '\\.'"
    end

    desc <<-DESC
        Disable the website by creating a maintenance.flag file
        All web requests will be redirected to a 503 page if the visitor ip address is not within a list of known ip addresses
        as defined by :whitelisted_ips array

        With :web roles
    DESC
    task :disable_web, :roles => :web do
        puts "Hiding the site from the public"
        
        #IP Whitelisting
        ip_whitelist_param = ''
        whitelisted_ips.each do |ip|
           ip_whitelist_param = ip_whitelist_param + " --ip=" + ip
        end
        run "#{php_bin} #{current_path}/bin/magento maintenance:enable #{ip_whitelist_param}"
    end

    desc <<-DESC
        Remove the maintenance.flag file which will re-open the website to all ip addresses

        With :web roles
    DESC
    task :enable_web, :roles => :web do
        puts "Enabling the site to the public"
        run "#{php_bin} #{current_path}/bin/magento maintenance:disable"
    end

    desc <<-DESC
        Check if the site is currently under maintenance (not publicly available)
        If so, then warn the deployer and ask to confirm what action to take
    DESC
    task :checksiteavailability, :roles => :web do
        # check current status
        set :isFileMissing, false
        set :checkFileExistPath, "#{current_path}/var/.maintenance.flag"
        # Run the task which will set :isFileMissing to true of false
        magento.file.exists

        if !isFileMissing
            # Default value is NO
            default_userCommand = 'ABORT'

            puts "Site is currently on maintenance mode.\n"
            puts " - Enter CONTINUE to deploy as per GIT repository content.\n"
            puts " - Enter ABORT to abort (to deploy and keep the site hidden run cap #{stage} deploy mage:disable_web )\n"

            userCommand = Capistrano::CLI.ui.ask "Enter your command here:"
            userCommand = default_userCommand if userCommand.empty?

            abortMsg = "Aborting. Please see https://acidgreen.atlassian.net/wiki/display/DG/4.+Tasks+available for more details."

            case "#{userCommand}"
                when "CONTINUE" then puts "Continuing and deploying as per GIT respository content"
                when "ABORT"       then abort abortMsg
                else abort abortMsg
            end
        end
    end

    task :ensure_robots, :roles => :web do
        desc <<-DESC
            Ensure robots.txt is present in webroot, otherwise copy from the previous release.
        DESC
        set :isFileMissing, false
        set :checkFileExistPath, "#{latest_release}/robots.txt"

        # Run the task which will set :isFileMissing to true of false
        magento.file.exists

        if isFileMissing
            set :isFileMissing, false
            set :checkFileExistPath, "#{current_path}/robots.txt"
            magento.file.exists
            if !isFileMissing
                # Copy generated robots.txt from previous release to new release
                run "cp #{current_path}/robots.txt #{latest_release}/robots.txt"
                run "ln -s #{current_path}/robots.txt #{current_path}/pub/robots.txt"
            end
        end
    end

    desc <<-DESC
        Flush Magento 2 Cache
        With :web roles
    DESC
    task :flush_cache, :roles => :web do
        puts "Flush Magento Cache"
        run "#{php_bin} -f #{current_path}/bin/magento cache:flush"
    end

    desc <<-DESC
            Execute post deployment commands
        DESC
        task :run_post_deployment_commands do
            if not post_deployment_commands.empty? then
                puts "RUNNING POST DEPLOYMENT COMMANDS"
                post_deployment_commands.each { |command|
                    run "#{command}"
                }
            end
        end unless exists?(:run_post_deployment_commands)
    
end

after  'deploy:setup',                  'magento:setup'
after  'deploy:finalize_update',        'magento:finalize_update'
before 'deploy:cold',                   'magento:set_cold_deploy'
after  'deploy',                        'magento:ensure_robots'
after  'deploy:finalize_update',        'magento:update' 
#after  'magento:security',              'magento:checksiteavailability'
after  'deploy:update',                 'deploy:cleanup'
after  'deploy',                        'magento:run_post_deployment_commands' # Run post deployment commands
after  'deploy:rollback',               'magento:run_post_deployment_commands' # Run post deployment commands
