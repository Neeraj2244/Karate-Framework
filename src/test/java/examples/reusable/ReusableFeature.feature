@Reusable @RegressionTest
Feature: Reuse a feature to create and verify an object

  Background:
    * url restfulApiUrl
    * def createPost = call read('PostRequest.feature')
    * def postId = createPost.response.id
    * def createdId = postId
    * configure afterScenario = function() { var id = karate.get('createdId'); if (id != null) { karate.log('[TEARDOWN] Deleting reusable-test object id: ' + id); karate.call('classpath:examples/posts/DeleteObject.feature', { objectId: id }); } }

  Scenario: Verify created post
    Given path 'objects', postId
    When method get
    Then status 200
    And match response.name == 'Karate Demo Post'
    And match response.data.createdBy == 'Karate DSL Author'
