@GraphQL @RegressionTest
Feature: GraphQL — Query Variables

  # Covers: named queries, $variable syntax, variables object, complex nested variables
  # Variables keep query structure fixed and data dynamic — the GraphQL-native way to parameterize

  Background:
    * url graphqlUrl

  Scenario: Fetch user by ID using query variable
    Given text query =
      """
      query GetUser($id: ID!) {
        user(id: $id) {
          id
          name
          email
        }
      }
      """
    And def variables = { id: '1' }
    And request { query: '#(query)', variables: '#(variables)' }
    When method POST
    Then status 200
    And match response.errors == '#notpresent'
    And match response.data.user.id    == '1'
    And match response.data.user.name  == 'Leanne Graham'
    And match response.data.user.email == 'Sincere@april.biz'

  Scenario: Fetch paginated posts using nested variables
    Given text query =
      """
      query GetPosts($options: PageQueryOptions) {
        posts(options: $options) {
          data {
            id
            title
          }
          meta {
            totalCount
          }
        }
      }
      """
    And def variables = { options: { paginate: { page: 1, limit: 3 } } }
    And request { query: '#(query)', variables: '#(variables)' }
    When method POST
    Then status 200
    And match response.errors == '#notpresent'
    And match response.data.posts.data          == '#[3]'
    And match response.data.posts.meta.totalCount == '#number'
    And match each response.data.posts.data     == { id: '#string', title: '#string' }

  Scenario: Create post using mutation variables
    Given text query =
      """
      mutation CreatePost($input: CreatePostInput!) {
        createPost(input: $input) {
          id
          title
          body
        }
      }
      """
    And def variables =
      """
      {
        "input": {
          "title": "Karate Variables Mutation",
          "body":  "Using $variables instead of inline values"
        }
      }
      """
    And request { query: '#(query)', variables: '#(variables)' }
    When method POST
    Then status 200
    And match response.errors                == '#notpresent'
    And match response.data.createPost.id    == '#string'
    And match response.data.createPost.title == 'Karate Variables Mutation'
