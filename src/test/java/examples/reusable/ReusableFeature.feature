@Reusable @RegressionTest
Feature: Reuse a feature to create and verify an object

  Background:
    * url restfulApiUrl
    * def createPost = call read('PostRequest.feature')
    * def postId = createPost.response.id

  Scenario: Verify created post
    Given path 'objects', postId
    When method get
    Then status 200
    And match response.name == 'Karate Demo Post'
    And match response.data.createdBy == 'Karate DSL Author'
