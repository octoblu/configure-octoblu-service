async      = require 'async'
Quay       = require './steps/quay'
Etcd       = require './steps/etcd'
Vulcand    = require './steps/vulcand'
Services   = require './steps/services'
debug      = require('debug')('configure-octoblu-service')

class ConfigureService
  constructor: ({ clusters, projectName, subdomain, rootDomain, deployStateUri, quayToken, isPrivate }) ->
    throw new Error 'Missing projectName argument' unless projectName?
    throw new Error 'Missing clusters argument' unless clusters?
    throw new Error 'Missing subdomain argument' unless subdomain?
    throw new Error 'Missing rootDomain argument' unless rootDomain?
    throw new Error 'Missing deployStateUri argument' unless deployStateUri?
    throw new Error 'Missing quayToken argument' unless quayToken?

    @quay = new Quay { projectName, deployStateUri, quayToken, isPrivate }
    @etcd = new Etcd { clusters, projectName, rootDomain, subdomain }
    @services = new Services { projectName }
    @vulcand = new Vulcand { subdomain, rootDomain, clusters, projectName }

  run: (callback) =>
    async.series [
      @quay.configure,
      @etcd.configure,
      @services.configure,
      @vulcand.configure,
    ], callback

module.exports = ConfigureService
