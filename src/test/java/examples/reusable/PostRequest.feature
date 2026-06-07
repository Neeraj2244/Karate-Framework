@Reusable
Feature: Post Request (Reusable helper)

  Background:
    * url restfulApiUrl

  Scenario: Create post
    Given path 'objects'
    And request
      """
      {
        "name": "Karate Demo Post",
        "data": {
          "type": "blog-post",
          "createdBy": "Karate DSL Author"
        }
      }
      """
    When method post
    Then status 200
