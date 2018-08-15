# Capistrano deployment tool for Magento 2 #

## Prerequisites ##
You must have the following installed on your local:

* Composer
* Ruby - atleast version 2.0.
* Capistrano version 2.15.5
* gems (railsless-deploy and steps)

Please refer to the following link on how to setup the above software on your machine:
Please see [wiki] for more information about the installation.

## Installation ##

#### Step 1: 
Run the following command on the root of your project

```

   composer require --dev acidgreen/magento2-capistrano

```
Capistrano will be installed to dev/tools/capistrano and the main file Capfile will be added to the root of the project. Make sure you add Capfile to your projects .gitignore file to exclude it from your repository.

#### Step 2: 
Configure Capistrano deployer for your project. You can find the capistrano source in dev/tools/capistrano directory of your Magento 2 project. Configure the following:
1. dev/tools/capistrano/config/deploy.rb - This contains general settings for your capistrano including the project's git/bitbucket repository. There is a sample deploy.rb.sample that you can copy and use as template.
2. stage configurations under dev/tools/capistrano/config/deploy/, you can copy dev.rb.sample as template for your deployment to your target environment ie dev.rb, staging.rb, production.rb.

#### Step 3:
Once you have configured and tested your capistrano deployer for your project, you can start adding the configuration resources you have created to the project's repository, you can run the command below to add these resources:

```
#!sh
$ git add dev/tools/capistrano/config
```
note that there is a .gitignore file under dev/tools/capistrano so only the configuration resources you created should be added. Also as per mentioned in step 3, don't forget to add your updated .gitignore file to your project repository. 


## Usage ##
See wiki