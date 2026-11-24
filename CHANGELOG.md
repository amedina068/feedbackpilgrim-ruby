# Changelog

All notable changes to this project are in this file.

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Added

- `FeedbackPilgrim::Client` for one Feedback Pilgrim instance, with a bearer token, `Accept: application/json`, a timeout and retries.
- `FeedbackPilgrim.configure`, with fallbacks to `FEEDBACKPILGRIM_URL`, `FEEDBACKPILGRIM_TOKEN`, `FEEDBACKPILGRIM_IDENTITY_SECRET` and `FEEDBACKPILGRIM_WEBHOOK_SECRET`.
- `FeedbackPilgrim.sign_in_url` for `POST /api/public/v1/init`.
- Resources: posts, release notes, contacts, testimonials and tags. The gem has no delete for posts, release notes and testimonials, because the API always returns 405.
- `contacts.upsert` with `created?`, and `testimonials.approve`.
- `FeedbackPilgrim::Page` for the Laravel paginator, with `next_page` and `each_record`.
- `FeedbackPilgrim.identity_hash` for the `user_hash` of the widget.
- `FeedbackPilgrim::Webhook.valid?`, `verify` and `sign` for the `X-FeedbackPilgrim-Signature-V2` header, with a tolerance of 300 seconds and the delivery ID.
- Typed errors for 401, 403, 404, 405, 422, 429, 5xx and connection failures.
- Retries with exponential backoff and jitter. The client obeys `Retry-After`.
- Rails integration: a Railtie that reads the credentials, and the `feedbackpilgrim:install` generator.
- RBS signatures in `sig/`.
- The MIT license: `LICENSE` and `spec.license = "MIT"` in the gemspec.

### Changed

The gem now behaves the same as the JS, PHP and Python SDKs. These changes break code that uses the gem from git:

- `Webhook::Event#name` is now `Event#type`. `Event#timestamp` is now the Unix time as an Integer, not a `Time`. `Event#payload` gives the decoded body.
- `Webhook.verify` raises the reason `:timestamp` when the timestamp header is missing or is not digits. Before, it raised `:signature`. The gem checks the timestamp format before the signature.
- `Webhook.verify` raises the reason `:payload` when the body is not a JSON object after a valid signature. Before, it raised `JSON::ParserError` or `TypeError`.
- The signature check makes the header lowercase. An uppercase hex signature is now valid.
- An empty `X-FeedbackPilgrim-Delivery` header gives `delivery_id` nil.
- `Client::BEFORE_SEND` has only a DNS failure (`SocketError`), a refused connection and a connect timeout (`Net::OpenTimeout`). Before, it also had an unreachable host or network. `Client::AFTER_SEND` is gone. `Client::CONNECTION_ERRORS` has all the connection errors. The client retries a request that is not idempotent only after a 429 or a `BEFORE_SEND` error.
- `ConnectionError#before_send?` tells if the error occurred before the send.
- The client waits for `Retry-After` on a retried 5xx, as on a 429. `retry_after` moved from `RateLimitError` to `ApiError`. A negative or hexadecimal `Retry-After` is ignored.
