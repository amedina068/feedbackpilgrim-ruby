# Feedback Pilgrim for Ruby

A Ruby client for the Feedback Pilgrim API, with a Rails integration.

Feedback Pilgrim is a self-hosted app for feedback, roadmaps, release notes and testimonials. You run your own instance, so each client talks to the instance URL that you give it. The gem uses the Ruby standard library only. It has no runtime dependencies and sends no telemetry.

```ruby
post = FeedbackPilgrim.posts.create(title: "Add dark mode", content: "Please add a dark theme.")
user_hash = FeedbackPilgrim.identity_hash(current_user.email)
event = FeedbackPilgrim::Webhook.verify(request.raw_post, request.headers)
```

## Install

Add the gem to your Gemfile:

```ruby
gem "feedbackpilgrim", github: "amedina068/feedbackpilgrim-ruby"
```

Then run `bundle install`.

The gem is not on RubyGems. Bundler installs it from GitHub. The repository is private, so you need read access and git credentials for GitHub.

## Quick start

1. In your Feedback Pilgrim instance, go to **Settings → API Tokens**. Make a token.
2. Configure the client:

   ```ruby
   require "feedbackpilgrim"

   FeedbackPilgrim.configure do |config|
     config.url   = "https://feedback.example.com"
     config.token = ENV["FEEDBACKPILGRIM_TOKEN"]
   end
   ```

3. Read the posts:

   ```ruby
   FeedbackPilgrim.posts.list(status: "pending").each do |post|
     puts post.title
   end
   ```

## Configuration

| Setting           | Default | Environment variable              | Description |
|-------------------|---------|-----------------------------------|-------------|
| `url`             | none    | `FEEDBACKPILGRIM_URL`             | The URL of your instance (its `APP_URL`), for example `https://feedback.example.com`. The client adds `/api/public/v1`. |
| `token`           | none    | `FEEDBACKPILGRIM_TOKEN`           | The API token, `<id>|<random>`. The client sends it as `Authorization: Bearer`. |
| `identity_secret` | none    | `FEEDBACKPILGRIM_IDENTITY_SECRET` | The identity secret of the client. Only `FeedbackPilgrim.identity_hash` uses it. |
| `webhook_secret`  | none    | `FEEDBACKPILGRIM_WEBHOOK_SECRET`  | The signing secret of your webhook. Only the webhook helpers use it. |
| `timeout`         | `30`    |                                   | The seconds to wait for a connection and for a response. |
| `max_retries`     | `2`     |                                   | The retries after a failed request. `0` turns retries off. |

A token belongs to one client (project) of the instance. It has all abilities and does not expire. Keep it on your server.

The client always sends `Accept: application/json`. Without this header, the API can return an error as a redirect to `/login` or as an HTML page.

`FeedbackPilgrim.posts` and the other module methods use the default client. To talk to more than one instance or client, make a client for each one:

```ruby
client = FeedbackPilgrim::Client.new(url: "https://feedback.example.com", token: ENV["FEEDBACKPILGRIM_TOKEN"], timeout: 10)
client.tags.list
```

`FeedbackPilgrim.configure` makes a new default client. `FeedbackPilgrim.reset!` also drops the default client, so the next call builds it again from `FeedbackPilgrim.config`:

```ruby
FeedbackPilgrim.config.timeout = 10
FeedbackPilgrim.reset!
```

## Usage

Each call returns a `FeedbackPilgrim::Record`. Read a field as a method or with `[]`:

```ruby
post = FeedbackPilgrim.posts.find(1)
post.title        # => "Add dark mode"
post[:title]      # => "Add dark mode"
post.key?(:stage) # => false
post.to_h         # => { "id" => 1, "title" => "Add dark mode", ... }
```

The ID of each record is an integer. A list returns a `FeedbackPilgrim::Page`. Read [Pagination](#pagination).

An update sends only the fields that you give. The client uses `PATCH`. A `tags` list replaces all the tags of the record. Give the tag IDs.

### Sign in a contact

`sign_in_url` creates or updates the contact with this email. It returns a sign-in link for the public site of the client. The link is valid for 24 hours. Give it only to that contact.

```ruby
url = FeedbackPilgrim.sign_in_url(email: current_user.email, name: current_user.name, mrr: 99.99, custom_fields: { plan: "pro" })
redirect_to url, allow_other_host: true
```

If the API gets no contact email, it returns `[]`, and `sign_in_url` returns `nil`. It does not raise an error.

### Posts

```ruby
page = FeedbackPilgrim.posts.list(status: "in_progress", tag: "feature", published: true, sort_by: "updated_at", per_page: 50)
post = FeedbackPilgrim.posts.find(1)
post = FeedbackPilgrim.posts.create(title: "Add dark mode", content: "Please add a dark theme.", board_id: 1, tags: [1, 2])
post = FeedbackPilgrim.posts.update(1, status: "completed")
```

- `status` is `pending`, `in_progress` or `completed`.
- `tag` is the exact title of a tag.
- Without `board_id`, a new post goes on the first board of the client.
- A new status moves the post to the first stage of that type. The app then sends the same emails, webhooks and Slack message as the dashboard.
- `find` also returns the comments of the post.
- The API cannot delete a post.

### Release notes

```ruby
page = FeedbackPilgrim.release_notes.list(published: false)
note = FeedbackPilgrim.release_notes.find(1)
note = FeedbackPilgrim.release_notes.create(title: "Version 2.1.0", content: "## New\n- Dark mode", published: true)
note = FeedbackPilgrim.release_notes.update(1, published: false)
```

- `content` is Markdown.
- Without `published: true`, a new note is a draft. The owner of the token is the author.
- `published: true` keeps a publication date that exists. `published: false` makes the note a draft again.
- The API cannot delete a release note.

### Contacts

```ruby
page = FeedbackPilgrim.contacts.list(search: "jane", sort_by: "mrr")
contact = FeedbackPilgrim.contacts.find(7)
contact = FeedbackPilgrim.contacts.upsert(email: "jane@example.com", name: "Jane Smith", mrr: 149.99, custom_fields: { plan: "pro" })
contact = FeedbackPilgrim.contacts.update(7, name: "Jane S.", ltv: 1800)
```

`upsert` creates the contact, or updates the contact that has this email. `created?` tells you which:

```ruby
contact.created? # => true for a new contact (HTTP 201), false for an update (HTTP 200)
```

Custom fields:

- The contacts operations return each custom field as a field of the record: `contact.plan`.
- A contact inside another record, for example `post.contact`, has the custom fields as one JSON string: `JSON.parse(post.contact.metadata)`.
- `upsert` merges `custom_fields` with the custom fields that the contact has. The custom fields can have 50 keys, 3 levels and 16 KB at most. A key cannot start with `pilgrim_`.
- `update` cannot change custom fields. Use `upsert` with the email of the contact.
- The API cannot delete a contact.

### Testimonials

```ruby
page = FeedbackPilgrim.testimonials.list(approved: true, rating: 5)
testimonial = FeedbackPilgrim.testimonials.find(1)
testimonial = FeedbackPilgrim.testimonials.create(description: "The roadmap keeps our customers in the loop.", username: "jane_doe", rating: 5, contact_id: 7)
testimonial = FeedbackPilgrim.testimonials.update(1, rating: 4)
testimonial = FeedbackPilgrim.testimonials.approve(1)
```

- Without `approved: true`, `list` returns only the pending testimonials. `approved: false` also returns the pending testimonials.
- A new testimonial is pending.
- `approve` sets `approved_at` to the current time. Give `at:` for another time. `update(1, approved_at: time)` does the same.
- The API cannot delete a testimonial.

### Tags

```ruby
page = FeedbackPilgrim.tags.list(search: "feat")
tag = FeedbackPilgrim.tags.create(title: "feature")
tag = FeedbackPilgrim.tags.update(1, title: "enhancement")
FeedbackPilgrim.tags.delete(1)
```

- A title is unique in the client.
- `list` orders the tags by title and gives `posts_count` and `contacts_count`.
- `delete` removes the tag from each post, release note and contact. Then it deletes the tag and returns `nil`.

## Identity hash

The widget proves the email of the signed-in user with `user_hash`. Make the hash on your server:

```ruby
user_hash = FeedbackPilgrim.identity_hash(current_user.email)
user_hash = FeedbackPilgrim.identity_hash(current_user.email, secret: other_client_secret)
```

- The hash is the HMAC-SHA256 hex digest of the normalized email, with the identity secret as the key.
- The gem normalizes the email like PHP `strtolower(trim($email))`. It removes spaces, `\t`, `\n`, `\r`, `\0` and `\v` at both ends. It changes only the ASCII letters `A` to `Z` to lowercase.
- The identity secret is a setting of the client. It is not the API token.

> **Warning:** Make the hash on the server only. Never put the identity secret in browser code.

Give the hash to the widget script in your view. The secret stays on the server.

## Webhooks

The app signs each webhook delivery with the signing secret of the webhook. It sends these headers:

| Header | Value |
|--------|-------|
| `X-FeedbackPilgrim-Event` | `post.created`, `post.status_changed` or `post.completed` |
| `X-FeedbackPilgrim-Delivery` | A UUID. Each retry of a delivery sends the same UUID. |
| `X-FeedbackPilgrim-Timestamp` | The Unix time of the attempt, in seconds |
| `X-FeedbackPilgrim-Signature-V2` | The HMAC-SHA256 hex digest of `<timestamp>.<raw body>` |

The gem verifies the V2 signature only. The app also sends the deprecated `X-FeedbackPilgrim-Signature` header for one more release. The gem ignores it.

`verify` returns a `FeedbackPilgrim::Webhook::Event`, or raises `FeedbackPilgrim::WebhookVerificationError`:

```ruby
event = FeedbackPilgrim::Webhook.verify(request.raw_post, request.headers)
event.type         # => "post.status_changed"
event.data.title   # => "Export to CSV/Excel"
event.data.stage   # => a Record with id, name and type, or nil
event.payload      # => the decoded body, a Hash
event.timestamp    # => 1763456789, the Unix time as an Integer
event.delivery_id  # => "0b6c4c1e-8b4a-4f8e-9d55-3a1f0c2e7d10", or nil
```

If the `X-FeedbackPilgrim-Delivery` header is missing, the verification passes and `delivery_id` is `nil`. Older instances do not send this header.

`verify` does the checks in this order. The first check that fails gives `WebhookVerificationError#reason`:

1. `:timestamp`: the timestamp header is missing or has a character that is not a digit.
2. `:signature`: the signature header is missing or does not match the timestamp and the raw body.
3. `:timestamp`: the timestamp is outside the tolerance.
4. `:payload`: the body is not a JSON object.

`valid?` takes the header values and returns `true` or `false`:

```ruby
FeedbackPilgrim::Webhook.valid?(
  request.raw_post,
  signature: request.headers["X-FeedbackPilgrim-Signature-V2"],
  timestamp: request.headers["X-FeedbackPilgrim-Timestamp"]
)
```

`sign` makes a signature. Use it to test your receiver:

```ruby
signature = FeedbackPilgrim::Webhook.sign(Time.now.to_i, body, ENV["FEEDBACKPILGRIM_WEBHOOK_SECRET"])
```

Rules:

- Give the raw body. Do not parse the JSON and encode it again. The app escapes `/` as `\/` and each character that is not ASCII as `\uXXXX`, so a body encoded again has other bytes.
- The helpers reject a timestamp that is more than 300 seconds from the current time. Give `tolerance:` to change the limit, for example `tolerance: 600`.
- The helpers read the secret from `webhook_secret`. Give `secret:` to use another secret.
- The helpers make the signature header lowercase, then compare the signatures in constant time. An uppercase hex signature is valid.
- `WebhookVerificationError#reason` is `:timestamp`, `:signature` or `:payload`.
- The gem does not store delivery IDs. To drop a repeated delivery, store each `delivery_id` that you processed.

## Errors

Each error is a `FeedbackPilgrim::Error`.

| Error | Cause |
|-------|-------|
| `ConfigurationError` | The `url`, the `token` or a secret is missing. |
| `ConnectionError` | The connection failed, timed out, or had a TLS error. `cause` gives the original error. `before_send?` is true when the server did not get the request. |
| `AuthenticationError` | HTTP 401. The token is missing or wrong, or its user is deactivated. |
| `AuthorizationError` | HTTP 403. The REST API does not return it today. |
| `NotFoundError` | HTTP 404. The client of the token has no record with this ID. |
| `MethodNotAllowedError` | HTTP 405. The API does not support the operation. |
| `ValidationError` | HTTP 422. `errors` gives the messages for each field. |
| `RateLimitError` | HTTP 429. `retry_after` gives the seconds to wait. Each `ApiError` has `retry_after`. |
| `ServerError` | HTTP 500 or more. |
| `ApiError` | Another status. All the HTTP errors above are `ApiError`. |
| `WebhookVerificationError` | A webhook delivery is not valid. `reason` is `:timestamp`, `:signature` or `:payload`. |

Each `ApiError` has `status`, `body` and `message`. The message comes from the `message` or the `error` field of the body.

```ruby
begin
  FeedbackPilgrim.posts.create(title: "", content: "Please add a dark theme.")
rescue FeedbackPilgrim::ValidationError => error
  error.status          # => 422
  error.errors["title"] # => ["The title field is required."]
rescue FeedbackPilgrim::RateLimitError => error
  error.retry_after     # => 42
end
```

## Retries

The client retries a failed request `max_retries` times. The wait between attempts is an exponential backoff with jitter: about 0.5, 1, 2, 4 and 8 seconds.

| Failure | GET, PATCH and DELETE | POST |
|---------|-----------------------|------|
| 429 | Retry | Retry |
| 5xx | Retry | No retry |
| DNS failure, refused connection or connect timeout | Retry | Retry |
| Read timeout, reset or other connection error | Retry | No retry |

- The default is 2 retries.
- If a retried response has `Retry-After` (whole seconds or an HTTP date), the client waits that time. If `Retry-After` is more than 60 seconds, the client does not retry. It raises the error.
- `contacts.upsert` is a POST, but a repeated request leaves the same contact. The client retries it like a PATCH.
- `sign_in_url` makes a new link for each call, so the client does not retry it after a 5xx, a read timeout or a reset.
- `ConnectionError#before_send?` is true for a DNS failure (`SocketError`), a refused connection (`Errno::ECONNREFUSED`) and a connect timeout (`Net::OpenTimeout`). The server did not get the request, so the client retries every request after these errors.
- The JS, PHP and Python SDKs use the same retry rules.
- Each user can make 120 requests each minute. All the tokens of the user share this limit.

## Pagination

A list returns one `FeedbackPilgrim::Page`. The API returns a Laravel paginator. `per_page` is 1 to 100. The default is 15.

```ruby
page = FeedbackPilgrim.posts.list(per_page: 100)
page.records          # => an Array of Records
page.each { |post| puts post.title }
page.meta.total       # => 230
page.meta.last_page   # => 3
page.next_page?       # => true
page = page.next_page # => the next Page, with the same filters
page = FeedbackPilgrim.posts.list(per_page: 100, page: 3)
```

`meta` holds each field of the paginator except `data`: `current_page`, `last_page`, `per_page`, `total`, `next_page_url` and more.

`each_record` reads all the pages:

```ruby
FeedbackPilgrim.contacts.list(per_page: 100).each_record do |contact|
  puts contact.email
end
```

Without a block, `each_record` returns an `Enumerator`. The Enumerator reads the next page only when it needs it:

```ruby
FeedbackPilgrim.posts.list(per_page: 100).each_record.find { |post| post.title == "Add dark mode" }
```

## Rails

The gem has a Railtie. Rails loads it when you add the gem to the Gemfile.

### Credentials

The Railtie reads `Rails.application.credentials.feedbackpilgrim`:

```sh
bin/rails credentials:edit
```

```yaml
feedbackpilgrim:
  url: https://feedback.example.com
  token: your-api-token
  identity_secret: your-identity-secret
  webhook_secret: your-webhook-signing-secret
```

An initializer that calls `FeedbackPilgrim.configure` runs after the Railtie. Its values replace the credentials.

### Generator

```sh
bin/rails generate feedbackpilgrim:install
```

The generator writes `config/initializers/feedbackpilgrim.rb`. Change `timeout` and `max_retries` there.

### Webhooks in a controller

```ruby
# config/routes.rb
post "/webhooks/feedbackpilgrim" => "feedbackpilgrim_webhooks#create"

# app/controllers/feedbackpilgrim_webhooks_controller.rb
class FeedbackpilgrimWebhooksController < ActionController::API
  def create
    event = FeedbackPilgrim::Webhook.verify(request.raw_post, request.headers)

    # Older instances send no delivery ID.
    if event.delivery_id.nil? || ProcessedDelivery.create_or_find_by(delivery_id: event.delivery_id).previously_new_record?
      PostChangedJob.perform_later(event.type, event.data.to_h)
    end

    head :ok
  rescue FeedbackPilgrim::WebhookVerificationError
    head :bad_request
  end
end
```

`ProcessedDelivery` and `PostChangedJob` are examples from your app. The gem does not add them.

## Supported versions

- Ruby 3.2, 3.3 and 3.4
- Rails 7.2, 8.0 and 8.1 (optional)
- Feedback Pilgrim with the `/api/public/v1` API

## Development

```sh
bundle install
bin/rake           # the unit tests, the Rails tests and the integration tests
bin/rubocop
bin/rake rbs       # validates the type signatures in sig/
```

The integration tests run only when `FEEDBACKPILGRIM_TEST_URL` and `FEEDBACKPILGRIM_TEST_TOKEN` are set. They only read: they list posts and tags.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the rules. Report security problems as written in [SECURITY.md](SECURITY.md).

## License

MIT. Read [LICENSE](LICENSE). The Feedback Pilgrim app has its own license.
