@GraphQL @RegressionTest @DataDriven
Feature: GraphQL — Data-Driven Testing

  # Covers: Scenario Outline with <placeholder> injected directly into GraphQL query text
  # The <placeholder> syntax works inside text blocks exactly like REST Scenario Outlines

  Background:
    * url graphqlUrl

  Scenario Outline: Fetch users by ID and verify email
    Given text query =
      """
      {
        user(id: "<userId>") {
          id
          name
          email
        }
      }
      """
    And request { query: '#(query)' }
    When method POST
    Then status 200
    And match response.errors          == '#notpresent'
    And match response.data.user.id    == '<userId>'
    And match response.data.user.email == '<email>'

    Examples:
      | userId | email              |
      | 1      | Sincere@april.biz  |
      | 2      | Shanna@melissa.tv  |
      | 3      | Nathan@yesenia.net |

  Scenario Outline: Fetch post by ID and verify title
    Given text query =
      """
      {
        post(id: "<postId>") {
          id
          title
        }
      }
      """
    And request { query: '#(query)' }
    When method POST
    Then status 200
    And match response.errors        == '#notpresent'
    And match response.data.post.id  == '<postId>'
    And match response.data.post.title contains '<titleContains>'

    Examples:
      | postId | titleContains |
      | 1      | sunt          |
      | 2      | qui           |
      | 3      | ea            |
