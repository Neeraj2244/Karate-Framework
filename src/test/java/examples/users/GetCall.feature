@TestCase1 @SanityTest
Feature: Get Call Users API

  Background:
    * url jsonPlaceholderUrl
    * configure retry = { count: 3, interval: 2000 }

  Scenario: Get user by id
    Given path 'users', 1
    And retry until responseStatus == 200
    When method get
    Then status 200
    And match response.name == 'Leanne Graham'
    And match response.email == 'Sincere@april.biz'
