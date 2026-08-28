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

# Show cascade traversal + load order
rcb --debug list

# Run a specific task
rcb default

# Debug mode
rcb --debug
```

## Architecture

The `rcb` command traverses upward from the current directory until it finds `.rcbroot`:

```
article_01/source/     # Start here
       ↓
article_01/            # Found Rakefile
       ↓
volume_01/             # Found Rakefile
       ↓
journal/               # Found Rakefile
       ↓
publisher/             # Found Rakefile AND .rcbroot → STOP
```

Files are loaded in **root-first** order, with a shared `CFG` Hash for configuration.

## Rakefile Pattern

```ruby
# CFG is available in all Rakefiles
CFG['basename'] ||= 'article'
CFG['source_format'] ||= 'docx'

desc "A build task"
task :build do
  puts "Building #{CFG['basename']}"
end
```

## Development

```bash
bundle install
bundle exec rake test
```

To run RCB from the working tree without `gem install`, use the in-repo
`rcb-dev` / `rcb-dev.bat` wrapper at the repo root — see
[`docs/setup.md`](../docs/setup.md).

## License

CC0-1.0 Universal (public domain dedication). See [LICENSE](LICENSE).
