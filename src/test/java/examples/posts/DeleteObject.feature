Feature: Delete Object Helper

  Scenario: DELETE /objects/{id}
    Given url restfulApiUrl
    And path 'objects', objectId
    When method delete
    * def deleteStatus = responseStatus
    And match responseStatus == '#? _ == 200 || _ == 404'
