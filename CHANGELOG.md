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
