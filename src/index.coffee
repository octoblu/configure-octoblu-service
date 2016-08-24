async      = require 'async'
Etcd       = require './steps/etcd'
Vulcand    = require './steps/vulcand'
Services   = require './steps/services'
debug      = require('debug')('configure-octoblu-service')

class ConfigureService
  constructor: ({ clusters, projectName, subdomain, rootDomain }) ->
    throw new Error 'Missing projectName argument' unless projectName
    throw new Error 'Missing clusters argument' unless clusters
    throw new Error 'Missing subdomain argument' unless subdomain
    throw new Error 'Missing rootDomain argument' unless rootDomain

    @etcd = new Etcd { clusters, projectName, rootDomain, subdomain }
    @services = new Services { projectName }
    @vulcand = new Vulcand { subdomain, rootDomain, clusters, projectName }

  run: (callback) =>
    async.series [
      @etcd.configure,
      @services.configure,
      @vulcand.configure,
    ], callback

module.exports = ConfigureService
