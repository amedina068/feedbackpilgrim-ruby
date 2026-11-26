# Contributing

Thank you for your help with the Feedback Pilgrim Ruby gem.

## Report a bug or ask for a feature

Open an issue with the bug template or the feature template. If the problem is about security, do not open an issue. Read [SECURITY.md](SECURITY.md).

## Prepare your environment

1. Install Ruby 3.2 or later.
2. Clone the repository.
3. Run `bundle install`.
4. Run `bin/rake`. All tests must pass before you change the code.

## Make a change

1. Make a branch from `main`.
2. Write a test that shows the bug or the new behavior. Make sure that the test fails.
3. Change the code until the test passes.
4. Run `bin/rake`, `bin/rubocop` and `bin/rake rbs`.
5. If you change the public API, update `sig/feedbackpilgrim.rbs`, `README.md` and `CHANGELOG.md`.
6. Open a pull request and complete the template.

## Pull request titles

The title of each pull request must follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The `pr-title` check fails when the title does not follow it.

Use one of these types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` or `revert`. The scope in parentheses is optional. Examples:

- `feat: add the testimonials resource`
- `fix(rails): load the config before the first request`
- `docs: add a webhook example to the README`

GitHub makes the release notes from the titles of the merged pull requests. A clear title gives a clear release note.

## Release

The `Release` workflow (`.github/workflows/release.yml`) builds the gem and publishes it to RubyGems with trusted publishing (OIDC). The `build` job runs the checks and builds the gem. The `publish` job runs in the `rubygems` environment and gets a short-lived API key from RubyGems. The repository has no RubyGems secret. The `rubygems` environment accepts only the `main` branch and the `v*` tags.

1. Set the new version in `lib/feedbackpilgrim/version.rb`.
2. In `CHANGELOG.md`, move the lines under `Unreleased` to a new section `## [<version>] - <date>`.
3. Open a pull request with these changes. Merge it.
4. Start the workflow: `gh workflow run release.yml --ref main`.
5. Create the GitHub release `v<version>`. Use the section of `CHANGELOG.md` as the notes.

### First release

RubyGems creates the gem at the first publish. Before the first release, do these steps:

1. Add a pending trusted publisher at <https://rubygems.org/profile/oidc/pending_trusted_publishers>: gem `feedbackpilgrim`, owner `amedina068`, repository `feedbackpilgrim-ruby`, workflow `release.yml`, environment `rubygems`.
2. Copy the ID of the RubyGems account from the same page.
3. Start the first run with this ID: `gh workflow run release.yml --ref main -f rubygems-owner=<ID>`.

## Triage

Each new issue gets the `needs-triage` label. The maintainer reads the issue, adds a type label (for example `bug`, `enhancement` or `question`) and removes `needs-triage`.

## Rules for the code

- Use the Ruby standard library. Do not add a runtime dependency.
- Use Minitest for the tests. Do not make real HTTP requests in the unit tests. Use WebMock.
- Keep the vectors in `test/fixtures` the same as the vectors of the app. The identity hash and the webhook helpers must pass each vector.
- Follow the RuboCop rules of `rubocop-rails-omakase`.
- Do not add telemetry.
- Never put a token, a secret or another key in the code, the tests or the logs.

## Rules for the text

Write the docs, the comments and the commit messages in Simplified Technical English:

- Use short sentences. A procedure step has 20 words or fewer. A description has 25 words or fewer.
- Use the active voice. Use the imperative for instructions.
- Use one word for one meaning.
- Do not use contractions or semicolons.

## Test with a different Rails version

Set `RAILS_VERSION` and update the bundle:

```sh
RAILS_VERSION="~> 7.2.0" bundle update rails
bin/rake test:rails
```

## Run the integration tests

The integration tests use a real Feedback Pilgrim instance. They only read: they list posts and tags.

```sh
FEEDBACKPILGRIM_TEST_URL=https://feedback.example.com FEEDBACKPILGRIM_TEST_TOKEN=your-token bin/rake test:integration
```
