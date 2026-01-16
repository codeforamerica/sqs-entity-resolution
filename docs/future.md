# Future Enhancements

Given additional time and resources, the following enhancements and features
could be considered for future development:

- **Decoupled Build Process**: Move the Docker image build process outside of
  Terraform to a dedicated CI/CD pipeline. This would allow for more
  sophisticated build and testing processes, as well as better separation of
  concerns.
- **Improved Dashboards**: CloudWatch dashboard features are limited compared to
  other monitoring solutions. Consider integrating with a more advanced
  platform, such as Grafana or Splunk, for richer visualizations.
- **Multithreaded Consumer**: Enhance the consumer service to support
  multithreaded processing of messages, allowing each container to handle
  multiple messages concurrently.
- **Multithreaded Exporter**: The exporter, especially for delta exports, can
  take a significant amount of time to complete. Implementing multithreading
  could help reduce the overall export time.
- **Export Tracker Purging**: Implement a mechanism to purge old entries from
  the export tracking database to prevent it from growing indefinitely.
- **Export Tracker Flags**: Add additional flags to the consumer and redoer to
  control whether they should update the export tracking database. This would
  allow you to skip updating the tracker when you expect to run a full export.
- **Metadata Export**: Include some metadata about the export itself, such as
  start/end time, number of entities exported, etc., in a separate file in the
  S3 bucket alongside the export file.
- **Exporter Resume Capability**: Implement a mechanism for the exporter to
  resume from where it left off in case of failure, rather than starting over
  from the beginning.
- **Configurable Export Options**: Allow additional configuration options for
  the exporter that allows different flags be passed to the Senzing SDK.
- **Senzing Web Application**: Deploy the [Entity Search Web App][sz-web-app]
  from Senzing to provide a user interface for searching and viewing entities
  within the Senzing system.

[sz-web-app]: https://github.com/senzing-garage/entity-search-web-app
