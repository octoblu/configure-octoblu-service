_                = require 'lodash'
colors           = require 'colors'
dashdash         = require 'dashdash'
ConfigureService = require './src'
packageJSON      = require './package.json'
debug            = require('debug')('configure-octoblu-service')

OPTIONS = [
  {
    names: ['root-domain', 'r']
    type: 'string'
    env: 'ROOT_DOMAIN'
    help: 'Specify the root domain to add the service to'
    default: 'octoblu.com'
  }
  {
    names: ['clusters', 'c']
    type: 'string'
    env: 'CLUSTERS'
    help: 'Specify the clusters to add, separated by a ","'
  }
  {
    names: ['project-name', 'p']
    type: 'string'
    env: 'PROJECT_NAME'
    help: 'Specify the name of the Project, or Service. It should be dasherized.'
  }
  {
    names: ['subdomain', 's']
    type: 'string'
    env: 'SUBDOMAIN'
    help: 'Specify the subdomain of the static site. For example, "connector-factory"'
  }
  {
    names: ['help', 'h']
    type: 'bool'
    help: 'Print this help and exit.'
  }
  {
    names: ['version', 'v']
    type: 'bool'
    help: 'Print the version and exit.'
  }
]

class Command
  constructor: ->
    process.on 'uncaughtException', @die

  parseOptions: =>
    parser = dashdash.createParser { options: OPTIONS }
    { help, version } = parser.parse process.argv
    { subdomain, root_domain } = parser.parse process.argv
    { project_name, clusters } = parser.parse process.argv

    if help
      console.log "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{parser.help({includeEnv: true})}"
      process.exit 0

    if version
      console.log packageJSON.version
      process.exit 0

    unless subdomain
      console.error "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{parser.help({includeEnv: true})}"
      console.error colors.red 'Missing required parameter --subdomain, -s, or env: SUBDOMAIN'
      process.exit 1

    unless project_name
      console.error "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{parser.help({includeEnv: true})}"
      console.error colors.red 'Missing required parameter --project-name, -p, or env: PROJECT_NAME'
      process.exit 1

    if subdomain.indexOf('octoblu.com') > -1
      console.error "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{parser.help({includeEnv: true})}"
      console.error colors.red 'Subdomain must not include octoblu.com'
      process.exit 1

    if subdomain.indexOf('-static') > -1
      console.error "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{parser.help({includeEnv: true})}"
      console.error colors.red 'Subdomain must not include "-static"'
      process.exit 1

    rootDomain = root_domain.replace /^\./, ''
    projectName = project_name
    clustersArray = _.compact _.map clusters?.split(','), (cluster) => return cluster?.trim()
    clustersArray = ['major', 'minor', 'hpe'] if _.isEmpty clustersArray

    return { clusters: clustersArray, projectName, subdomain, rootDomain }

  run: =>
    options = @parseOptions()
    debug 'Configuring', options
    configureService = new ConfigureService options
    configureService.run (error) =>
      return @die error if error?
      console.log 'I did some of the hard work, but you still do a few a things'
      console.log "* FIRST! Create a working service with a Dockerfile"
      console.log "* Commit everything"
      console.log "* Make sure the-stack-services && the-stack-env-production is up to date"
      console.log ""
      console.log "* Setup the Travis builds"
      console.log "* Setup the repo in Quay"
      console.log "  - `cd #{process.env.HOME}/Projects/Octoblu/#{options.projectName}`"
      console.log "  - `quayify` - make sure the webhook is setup"
      console.log '* Make sure to update your tools'
      console.log '  - `brew update; and brew install majorsync minorsync hpesync vulcansync hpevulcansync; and brew upgrade majorsync minorsync hpesync vulcansync hpevulcansync`'
      console.log '* Sync etcd:'
      console.log "  - fish:"
      console.log "    - `majorsync load #{options.projectName}`; and minorsync load #{options.projectName}`; and hpesync load #{options.projectName}"
      console.log '* Sync vulcan:'
      console.log "  - `hpevulcansync load octoblu-#{options.projectName}`"
      console.log "  - `vulcansync load octoblu-#{options.projectName}`"
      console.log "* Create services:"
      console.log " # in new tab"
      console.log "  - `fleetmux`"
      console.log "  - Create 2 instances when prompted"
      console.log "  - `cd #{process.env.HOME}/Projects/Octoblu/the-stack-services"
      console.log "  - `./scripts/run-on-services.sh 'submit,start' '*#{options.projectName}*'`"
      console.log " # in new tab"
      console.log "  - `minormux`"
      console.log "  - Create 1 instance when prompted"
      console.log "  - `cd #{process.env.HOME}/Projects/Octoblu/the-stack-services"
      console.log "  - `./scripts/run-on-services.sh 'submit,start' '*#{options.projectName}*'`"
      console.log " # in new tab"
      console.log "  - `hpemux` - you may need to update and install bin in muxblu"
      console.log "  - Create 2 instances when prompted"
      console.log "  - `cd #{process.env.HOME}/Projects/Octoblu/the-stack-services"
      console.log "  - `./scripts/run-on-services.sh 'submit,start' '*#{options.projectName}*'`"
      console.log ""
      console.log "* Commit the-stack-env-production and the-stack-services"
      console.log ""
      console.log "* Once it is all setup, point the domains to their respective clusters in Route53. (I am too scared to do it automatically)"
      console.log "  - so you'll the following domains pointed to the right service cluster"
      console.log "  - #{options.subdomain}.octoblu.com i.e. service-cluster-1379831036.us-west-2.elb.amazonaws.com"
      console.log "  - #{options.subdomain}.hpe.octoblu.com i.e. service-hpe-cluster-1351431065.us-east-1.elb.amazonaws.com"

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
