

@TestCase1 
Feature: Get Call Users API


  Background: 
    * url 'https://jsonplaceholder.typicode.com'

  Scenario: Get user by id
    Given path 'users', 1
    When method get
    Then status 200
    And match response.name == 'Leanne Graham'
    And match response.email == 'Sincere@april.biz'




Feature: POST Method For Post Createion API With Incorrect Data

Scenario: Create post
  Given url 'https://api.restful-api.dev/objects'
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


Feature: POST Method For Post Createion API But Correct Data

Scenario: Create post
  Given url 'https://api.restful-api.dev/objects'
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