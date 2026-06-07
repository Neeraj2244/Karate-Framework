@DataDriven @SanityTest @RegressionTest
Feature: Verify user emails from JSONPlaceholder

  Background:
    * url jsonPlaceholderUrl

  Scenario Outline: Verify user emails
    Given path 'users', <id>
    When method get
    Then status 200
    And match response.email == '<email>'

    Examples:
      | id | email              |
      | 1  | Sincere@april.biz  |
      | 2  | Shanna@melissa.tv  |
      | 3  | Nathan@yesenia.net |
