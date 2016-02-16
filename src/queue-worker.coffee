_                 = require 'lodash'
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
        return @respondWithError error, responseId, callback

      @jobTypes[jobType] result, callback

  triggerById: ({metadata,rawData}, callback) =>
    {auth,flowId,triggerId} = metadata
    body = JSON.parse rawData
    triggersService = new TriggersService {meshbluConfig: auth}
    triggersService.sendMessageById {flowId,triggerId,body}, callback

  triggerByName: ({metadata,rawData}, callback) =>
    {auth,triggerName,responseId} = metadata
    body = JSON.parse rawData
    triggersService = new TriggersService {meshbluConfig: auth}
    defaults =
      callbackUrl: "https://rest.octoblu.com/respond/#{responseId}"
      callbackMethod: 'POST'
      responseId: responseId
    _.extend body, defaults
    triggersService.sendMessageByName {triggerName,body}, callback

  respondWithError: (error, responseId, callback) =>
    response =
      metadata:
        responseId:responseId
        code: error.code
      data: error.message
    debug 'responding with error', response
    @jobManager.createResponse 'response', response, callback

module.exports = QueueWorker
