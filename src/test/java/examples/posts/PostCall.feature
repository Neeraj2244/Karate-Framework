@IntentionalFailure
Feature: POST Method For Post Creation API With Incorrect Data

  Background:
    * url restfulApiUrl

  @TestCase2
  Scenario: Create post with incorrect data
    Given path 'objects'
    And request
      """
      {
        "name": "Karate Demo Post",
        "data": {
          "type": "blog-post",
          "createdBy": "Karate DSL"
        }
      }
      """
    When method post
    Then status 200
    And match response.name == 'Karate Demo Post'
    And match response.id == '#string'
    And match response.data.type == 'blog-post'
    And match response.data.createdBy == 'Karate DSL Author'


   @TestCase3 @SanityTest @RegressionTest
  Scenario: Create post with correct data
    Given path 'objects'
    And request
      """
      {
        "name": "Karate Demo Post",
        "data": {
          "type": "blog-post",
          "createdBy": "Karate DSL"
        }
      }
      """
    When method post
    Then status 200
    And match response.name == 'Karate Demo Post'
    And match response.id == '#string'
    And match response.data.type == 'blog-post'
    And match response.data.createdBy == 'Karate DSL'
