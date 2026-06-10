function fn() {

  // ── Helper: read env var, fall back to a default, never hardcode secrets ──
  function env(name, defaultValue) {
    var value = java.lang.System.getenv(name);
    return (value != null && value != '') ? value : (defaultValue || '');
  }

  // ── Dynamic token via callSingle ──────────────────────────────────────────
  // Runs ONCE per suite — even with parallel(5), all threads share one token.
  // Falls back to public dummyjson test credentials when env vars are absent.
  var loginResult = karate.callSingle('classpath:examples/auth/Login.feature', {
    loginUrl : 'https://dummyjson.com/auth/login',
    username : env('DUMMY_JSON_USERNAME', 'emilys'),
    password : env('DUMMY_JSON_PASSWORD', 'emilyspass')
  });

  var config = {
    // Base URLs — non-sensitive, safe to keep here
    baseUrl            : env('BASE_URL',             'http://localhost:8080'),
    jsonPlaceholderUrl : env('JSON_PLACEHOLDER_URL', 'https://jsonplaceholder.typicode.com'),
    restfulApiUrl      : env('RESTFUL_API_URL',      'https://api.restful-api.dev'),
    httpBingoUrl       : env('HTTP_BINGO_URL',       'https://httpbingo.org'),
    dummyJsonUrl       : env('DUMMY_JSON_URL',       'https://dummyjson.com'),
    graphqlUrl         : env('GRAPHQL_URL',          'https://graphqlzero.almansi.me/api'),

    // Static credentials — values must come from environment variables only
    authToken    : env('AUTH_TOKEN'),        // e.g. Bearer token
    apiKey       : env('API_KEY'),           // e.g. X-API-Key header value
    clientId     : env('CLIENT_ID'),         // OAuth client id
    clientSecret : env('CLIENT_SECRET'),     // OAuth client secret

    // Dynamic token from DummyJSON — generated once per suite run via callSingle
    dummyJsonToken        : loginResult.accessToken,
    dummyJsonRefreshToken : loginResult.refreshToken
  };

  // Set auth headers globally — every feature inherits these automatically
  if (config.authToken) {
    karate.configure('headers', {
      'Authorization' : 'Bearer ' + config.authToken,
      'X-API-Key'     : config.apiKey
    });
  }

  return config;
}
