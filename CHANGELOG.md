# Changelog for v1.0

Multiverse is completely redesigned to work on top of adapters.

Default adapter is `Multiverse.Adapters.ISODate` which works similarly to the old Multiverse behaviour.

# Changelog for v1.1

`Multiverse.Adapters.ISODate` now does not apply changes occurred on a date/version specified by an API consumer. Since we expect that user would sett API docs that already include latest changes on that day.
