

CREATE OR REPLACE API INTEGRATION github_integration
 API_PROVIDER = git_https_api
 API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE
  ALLOWED_AUTHENTICATION_SECRETS = (github_token);


CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_LEARNING_DB.PUBLIC.snowflake_repo
  API_INTEGRATION = github_integration
  ORIGIN = 'https://github.com/murillowilmar1/Snowfake-Repo.git';
