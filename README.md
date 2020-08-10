# ActiveRecord::Migration::CheckPending middleware deadlocks

This is a minimal complete verifiable example Rails app that demonstrates [an issue][0] related to deadlocks caused by the `ActiveRecord::Migration::CheckPending` middleware.

[0]: https://github.com/rails/rails/issues/40009

## Set up

```sh
./bin/rails db:setup
```

## Reproducing the issue

In one shell,

```sh
./bin/rails s
```

In another,

```sh
siege http://localhost:3000/
```

If the deadlock is reproduced successfully, the Rails server output will look like

```
Started GET "/" for 127.0.0.1 at 2020-08-10 16:01:34 -0700
Started GET "/" for 127.0.0.1 at 2020-08-10 16:01:34 -0700
Started GET "/" for 127.0.0.1 at 2020-08-10 16:01:34 -0700
Started GET "/" for 127.0.0.1 at 2020-08-10 16:01:34 -0700
Started GET "/" for 127.0.0.1 at 2020-08-10 16:01:34 -0700
```

...indicating that all five threads are stuck.

This project launches a `pry-remote` session in a separate thread on initialization. This let's us inspect the backtraces of the threads once the deadlock happens. If you attach to the pry session, you should be able to see the stuck threads:

```sh
bundle exec pry-remote --wait
```

```ruby
Thread.list.map &:backtrace
```

In a successful reproduction of the deadlock, you'll find at least one thread stuck waiting for the `CheckPending` mutex:


```ruby
 ["/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/migration.rb:570:in `synchronize'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/migration.rb:570:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/callbacks.rb:27:in `block in call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:98:in `run_callbacks'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/callbacks.rb:26:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/executor.rb:14:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/actionable_exceptions.rb:17:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/debug_exceptions.rb:29:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:132:in `call_app'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:28:in `block in call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:17:in `catch'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:17:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/show_exceptions.rb:33:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/rack/logger.rb:37:in `call_app'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/rack/logger.rb:26:in `block in call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/tagged_logging.rb:99:in `block in tagged'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/tagged_logging.rb:37:in `tagged'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/tagged_logging.rb:99:in `tagged'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/rack/logger.rb:26:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/sprockets-rails-3.2.1/lib/sprockets/rails/quiet_assets.rb:13:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/remote_ip.rb:81:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/request_id.rb:27:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/rack-2.2.3/lib/rack/method_override.rb:24:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/rack-2.2.3/lib/rack/runtime.rb:22:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/cache/strategy/local_cache_middleware.rb:29:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/executor.rb:14:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/static.rb:24:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/rack-2.2.3/lib/rack/sendfile.rb:110:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/host_authorization.rb:82:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/engine.rb:528:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/configuration.rb:228:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/server.rb:713:in `handle_request'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/server.rb:472:in `process_client'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/server.rb:328:in `block in run'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/thread_pool.rb:134:in `block in spawn_thread'"],
```


...and another thread that holds the `CheckPending` mutex, but is trying to acquire an exclusive lock on the interlock:

```ruby
 ["/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:111:in `sleep'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:111:in `wait'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:111:in `block (2 levels) in wait'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:110:in `handle_interrupt'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:110:in `block in wait'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:106:in `handle_interrupt'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:106:in `wait'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:125:in `wait_while'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/concurrency/share_lock.rb:220:in `wait_for'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/concurrency/share_lock.rb:83:in `block (2 levels) in start_exclusive'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/concurrency/share_lock.rb:187:in `yield_shares'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/concurrency/share_lock.rb:82:in `block in start_exclusive'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/2.6.0/monitor.rb:230:in `mon_synchronize'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/concurrency/share_lock.rb:77:in `start_exclusive'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/concurrency/share_lock.rb:149:in `exclusive'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/dependencies/interlock.rb:13:in `loading'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/dependencies.rb:39:in `load_interlock'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/dependencies.rb:397:in `require_or_load'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:49:in `block in require_or_load'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:17:in `allow_bootsnap_retry'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:48:in `require_or_load'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/dependencies.rb:552:in `load_missing_constant'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:61:in `block in load_missing_constant'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:17:in `allow_bootsnap_retry'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:60:in `load_missing_constant'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/dependencies.rb:213:in `const_missing'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/dependencies.rb:589:in `load_missing_constant'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:61:in `block in load_missing_constant'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:17:in `allow_bootsnap_retry'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/bootsnap-1.4.7/lib/bootsnap/load_path_cache/core_ext/active_support.rb:60:in `load_missing_constant'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/dependencies.rb:213:in `const_missing'",
  "/Users/chris.larose/dev/rails-6-check-pending-bug/config/initializers/connection_pool_stats.rb:5:in `block in report'",
  "/Users/chris.larose/dev/rails-6-check-pending-bug/config/initializers/connection_pool_stats.rb:4:in `each'",
  "/Users/chris.larose/dev/rails-6-check-pending-bug/config/initializers/connection_pool_stats.rb:4:in `report'",
  "/Users/chris.larose/dev/rails-6-check-pending-bug/config/initializers/connection_pool_stats.rb:13:in `block (2 levels) in <main>'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:427:in `instance_exec'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:427:in `block in make_lambda'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:270:in `block in simple'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:516:in `block in invoke_after'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:516:in `each'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:516:in `invoke_after'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:107:in `run_callbacks'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:824:in `_run_checkout_callbacks'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb:935:in `checkout_and_verify'"
,
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb:593:in `checkout'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb:433:in `connection'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb:1112:in `retrieve_connection'
",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/connection_handling.rb:254:in `retrieve_connection'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/connection_handling.rb:210:in `connection'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/migration.rb:594:in `connection'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/migration.rb:589:in `build_watcher'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/migration.rb:571:in `block in call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/migration.rb:570:in `synchronize'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activerecord/lib/active_record/migration.rb:570:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/callbacks.rb:27:in `block in call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/callbacks.rb:98:in `run_callbacks'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/callbacks.rb:26:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/executor.rb:14:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/actionable_exceptions.rb:17:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/debug_exceptions.rb:29:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:132:in `call_app'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:28:in `block in call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:17:in `catch'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/web-console-4.0.4/lib/web_console/middleware.rb:17:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/show_exceptions.rb:33:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/rack/logger.rb:37:in `call_app'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/rack/logger.rb:26:in `block in call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/tagged_logging.rb:99:in `block in tagged'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/tagged_logging.rb:37:in `tagged'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/tagged_logging.rb:99:in `tagged'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/rack/logger.rb:26:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/sprockets-rails-3.2.1/lib/sprockets/rails/quiet_assets.rb:13:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/remote_ip.rb:81:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/request_id.rb:27:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/rack-2.2.3/lib/rack/method_override.rb:24:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/rack-2.2.3/lib/rack/runtime.rb:22:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/activesupport/lib/active_support/cache/strategy/local_cache_middleware.rb:29:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/executor.rb:14:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/static.rb:24:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/rack-2.2.3/lib/rack/sendfile.rb:110:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/actionpack/lib/action_dispatch/middleware/host_authorization.rb:82:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/bundler/gems/rails-23a9e29d9b18/railties/lib/rails/engine.rb:528:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/configuration.rb:228:in `call'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/server.rb:713:in `handle_request'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/server.rb:472:in `process_client'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/server.rb:328:in `block in run'",
  "/Users/chris.larose/.asdf/installs/ruby/2.6.1/lib/ruby/gems/2.6.0/gems/puma-4.3.5/lib/puma/thread_pool.rb:134:in `block in spawn_thread'"],
```
