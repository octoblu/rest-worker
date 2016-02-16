_                 = require 'lodash'
url               = require 'url'
TriggersService   = require 'triggers-service'
debug             = require('debug')('rest-worker:queue-worker')

class QueueWorker
  constructor: ({@jobManager,@meshbluConfig}) ->
    @jobTypes =
      'triggerById': @triggerById
      'triggerByName': @triggerByName

  run: (callback) =>
    @jobManager.getRequest ['request'], (error, result) =>
      return callback error if error?
      return callback() unless result?

      {jobType,responseId} = result.metadata

      unless @jobTypes[jobType]?
        error = new Error 'Invalid Job'
        error.code = 422
        debug 'invalid job'
        return @respondWithError error, responseId, callback

      debug 'doing job', result
      @jobTypes[jobType] result, callback

  triggerById: ({metadata,rawData}, callback) =>
    {auth,flowId,triggerId,responseBaseUri} = metadata
    body = JSON.parse rawData
    triggersService = new TriggersService {meshbluConfig: auth}
    defaultPayload = @getDefaultPayload responseBaseUri, responseId
    triggersService.sendMessageById {flowId,triggerId,body,defaultPayload}, callback

  triggerByName: ({metadata,rawData}, callback) =>
    {auth,triggerName,responseId,responseBaseUri} = metadata
    body = JSON.parse rawData
    triggersService = new TriggersService {meshbluConfig: auth}

    defaultPayload = @getDefaultPayload responseBaseUri, responseId
    triggersService.sendMessageByName {triggerName,body,defaultPayload}, callback

  getDefaultPayload: (responseBaseUri, responseId) =>
    responseUrlObj = url.parse responseBaseUri || 'https://rest.octoblu.com/'
    urlObj =
      hostname: responseUrlObj.hostname
      protocol: responseUrlObj.protocol
      pathname: "/respond/#{responseId}"

    urlObj.port = responseUrlObj.port if responseUrlObj.port

    callbackUrl = url.format urlObj
    defaultPayload =
      callbackUrl: callbackUrl
      callbackMethod: 'POST'
      responseId: responseId

    return defaultPayload

  respondWithError: (error, responseId, callback) =>
    response =
      metadata:
        responseId:responseId
        code: error.code
      data: error.message
    debug 'responding with error', response
    @jobManager.createResponse 'response', response, callback

module.exports = QueueWorker
