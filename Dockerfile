FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libsqlite3-dev sqlite3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["sh", "-c", "bin/rails db:prepare && bin/rails server -b 0.0.0.0"]
