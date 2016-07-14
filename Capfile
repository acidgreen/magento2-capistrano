require 'rubygems'
require 'railsless-deploy'

# Uncomment if you are using Rails' asset pipeline
# load 'deploy/assets'
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load 'dev/tools/capistrano/lib/magento' # remove this line to skip loading any of the default tasks
