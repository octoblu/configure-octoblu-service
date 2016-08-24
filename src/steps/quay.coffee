_       = require 'lodash'
request = require 'request'
debug   = require('debug')('configure-octoblu-service')

QUAY_BASE_URL='https://quay.io/api/v1'

class Quay
  constructor: ({ @deployinateUrl, @projectName, @isPrivate, @quayToken }) ->
    throw new Error 'Missing projectName argument' unless @projectName?
    throw new Error 'Missing deployinateUrl argument' unless @deployinateUrl?
    throw new Error 'Missing quayToken argument' unless @quayToken?

  configure: (callback) =>
    debug 'setting up quay'
    @_createRepository (error) =>
      return callback error if error?
      @_createNotification callback

  _isDeployinated: (callback) =>
    options =
      method: 'GET'
      uri: "/repository/octoblu/#{@projectName}/notification/"
      json: true

    @_request options, (error, body) =>
      return callback error if error?
      exists = _.some body.notifications, { config: { url: @deployinateUrl } }
      debug 'notifcation exists', exists
      callback null, exists

  _createNotification: (callback) =>
    debug 'create notification in quay', options
    options =
      method: 'POST'
      uri: "/repository/octoblu/#{@projectName}/notification/"
      json:
        eventConfig: {}
        title: "Deployinate"
        config:
          url: @deployinateUrl
        event: "repo_push"
        method: "webhook"

    @_isDeployinated (error, exists) =>
      return callback error if error?
      return callback null if exists
      @_request options, (error, body) =>
        return callback error if error?
        callback null

  _repositoryExists: (callback) =>
    options =
      method: 'GET'
      uri: "/repository/octoblu/#{@projectName}"
      json: true

    @_request options, (error, body, statusCode) =>
      return callback error if error?
      exists = statusCode != 404
      debug 'repo exists', exists
      callback null, exists

  _createRepository: (callback) =>
    visibility = 'public'
    visibility = 'private' if @isPrivate
    debug 'create repository in quay', options
    options =
      method: 'POST'
      uri: '/repository'
      json:
        namespace: 'octoblu'
        visibility: visibility
        repository: @projectName
        description: "Octoblu Service #{@projectName}"

    @_repositoryExists (error, exists) =>
      return callback error if error?
      return callback null if exists
      @_request options, (error, body) =>
        return callback error if error?
        callback null

  _request: ({ method, uri, json }, callback) =>
    options = {
      method,
      uri,
      baseUrl: QUAY_BASE_URL
      headers:
        Authorization: "Bearer #{@quayToken}"
      followAllRedirects: true
      json
    }
    request options, (error, response, body) =>
      return callback error, null, response.statusCode if error?
      return callback body, null, response.statusCode if response.statusCode > 499
      callback null, body, response.statusCode

module.exports = Quay