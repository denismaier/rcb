# RCB - Rake Cascading Build

Rake-based cascading build system (analogous to doit-cascade's `cbs`).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rcb-cascade'
```

Or install it yourself as:

```bash
gem install rcb-cascade
```

## Usage

Run from any directory within a cascade:

```bash
# List all tasks
rcb

# Show cascade structure
rcb --show-cascade

# Run a specific task
rcb default

# Debug mode
rcb --debug
```

## Architecture

The `rcb` command traverses upward from the current directory until it finds `.cascaderoot`:

```
article_01/source/     # Start here
       ↓
article_01/            # Found Rakefile
       ↓
volume_01/             # Found Rakefile
       ↓
journal/               # Found Rakefile
       ↓
publisher/             # Found Rakefile AND .cascaderoot → STOP
```

Files are loaded in **root-first** order, with a shared `cfg` Hash for configuration.

## Rakefile Pattern

```ruby
# cfg is available in all Rakefiles
cfg['basename'] ||= 'article'
cfg['source_format'] ||= 'docx'

desc "A build task"
task :build do
  puts "Building #{cfg['basename']}"
end
```

## Development

```bash
bundle install
bundle exec rake test
bundle exec rake rubocop
```

## License

CC0-1.0 Universal (public domain dedication). See [LICENSE](LICENSE).
