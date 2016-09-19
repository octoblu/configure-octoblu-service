_                = require 'lodash'
colors           = require 'colors'
dashdash         = require 'dashdash'
ConfigureService = require './src'
packageJSON      = require './package.json'
debug            = require('debug')('configure-octoblu-service')

OPTIONS = [
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
    names: ['private']
    type: 'bool'
    env: 'PRIVATE_PROJECT'
    help: 'A flag for specifying a private project'
    default: false
  }
  {
    names: ['root-domain']
    type: 'string'
    env: 'ROOT_DOMAIN'
    help: '(optional) Specify the root domain to add the service to'
    default: 'octoblu.com'
  }
  {
    names: ['clusters']
    type: 'string'
    env: 'CLUSTERS'
    help: '(optional) Specify the clusters to add, separated by a ","'
    default: 'major,minor,hpe'
  }
  {
    names: ['quay-token']
    type: 'string'
    env: 'QUAY_TOKEN'
    help: 'Specify the quay bearer token. Muxblu will give you this.'
  }
  {
    names: ['deploy-state-uri']
    type: 'string'
    env: 'DEPLOY_STATE_URI'
    help: 'Specify the quay deploy state uri. Muxblu will give you this.'
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
    @parser = dashdash.createParser { options: OPTIONS }

  printHelp: (message) =>
    console.log "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{@parser.help({includeEnv: true})}"
    console.log message
    process.exit 0

  printHelpError: (error) =>
    console.error "usage: configure-octoblu-service [OPTIONS]\noptions:\n#{@parser.help({includeEnv: true})}"
    console.error colors.red error
    process.exit 1

  parseOptions: =>
    options = @parser.parse process.argv
    { help, version } = options
    { subdomain, root_domain } = options
    { project_name, clusters } = options
    { quay_token, deploy_state_uri } = options
    isPrivate = options.private

    @printHelp() if help

    @printHelp packageJSON.version if version

    @printHelpError 'Missing required parameter --subdomain, -s, or env: SUBDOMAIN' unless subdomain?
    @printHelpError 'Missing required parameter --project-name, -p, or env: PROJECT_NAME' unless project_name?
    @printHelpError 'Missing required parameter --quay-token, or env: QUAY_TOKEN' unless quay_token?
    @printHelpError 'Missing required parameter --deploy-state-uri, or env: DEPLOY_STATE_URI' unless deploy_state_uri?

    @printHelpError 'Subdomain must not include octoblu.com' if subdomain.indexOf('octoblu.com') > -1

    rootDomain = root_domain.replace /^\./, ''
    clustersArray = _.compact _.map clusters?.split(','), (cluster) =>
      return cluster?.trim()

    return {
      clusters: clustersArray,
      projectName: project_name,
      quayToken: quay_token,
      rootDomain: rootDomain,
      deployStateUri: deploy_state_uri,
      subdomain,
      isPrivate,
    }

  run: =>
    options = @parseOptions()

    debug 'Configuring', options

    configureService = new ConfigureService options
    configureService.run (error) =>
      return @die error if error?
      console.log colors.green "INSTRUCTIONS:"
      console.log 'I did some of the hard work, but you still do a few a things'
      console.log "* FIRST! Create a working service with a Dockerfile"
      console.log "* Commit everything"
      console.log "* Make sure the-stack-services && the-stack-env-production is up to date"
      console.log ""
      console.log "* Setup the Travis builds"
      console.log "* Setup the build trigger in Quay (it needs to build on git push)"
      console.log '* Make sure to update your tools'
      console.log '  - `brew update; and brew install majorsync minorsync hpesync vulcansync hpevulcansync; and brew upgrade majorsync minorsync hpesync vulcansync hpevulcansync`'
      console.log '* Sync etcd:'
      console.log "  - `majorsync load #{options.projectName}; and minorsync load #{options.projectName}; and hpesync load #{options.projectName}`"
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
      console.log "  - #{options.subdomain}.octoblu.com i.e. dualstack.service-cluster-1379831036.us-west-2.elb.amazonaws.com."
      console.log "  - #{options.subdomain}.hpe.octoblu.com i.e. service-hpe-cluster-1351431065.us-east-1.elb.amazonaws.com."

  die: (error) =>
    return process.exit(0) unless error?
    console.error 'ERROR'
    console.error error.stack
    process.exit 1

module.exports = Command
