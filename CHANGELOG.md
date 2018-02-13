# Changelog for v1.0

Multiverse is completely redesigned to work on top of adapters.

Default adapter is `Multiverse.Adapters.ISODate` which works similarly to the old Multiverse behaviour.

# Changelog for v1.1

* `Multiverse.Adapters.ISODate` now does not apply changes occurred on a date/version specified by an API consumer. Since we expect that user would sett API docs that already include latest changes on that day.

# Changelog for v2.0

* `Multiverse.Adapters.ISODate` now now requires a `default_version` config. By introducing it we want to make sure that developers that integrate Multiverse are fully aware of the default behaviour, which should be picked according to current API clients demands.
* Runtime execution performance should be slightly better because we won't traverse all gates on each request.
