@ignore
Feature: Delete Object Helper
  # Called exclusively via karate.call() from PostCall.feature's afterScenario hook.
  # Accepts: restfulApiUrl, objectId as arguments.
  # @ignore prevents the parallel/all runner from picking this up as a standalone test.

  Scenario: DELETE /objects/{id}
    Given url restfulApiUrl
    And path 'objects', objectId
    When method delete
    * def deleteStatus = responseStatus
    And match responseStatus == '#? _ == 200 || _ == 404'
