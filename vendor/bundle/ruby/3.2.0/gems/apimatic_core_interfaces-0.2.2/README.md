# apimatic-core-interfaces

[![Gem Version](https://badge.fury.io/rb/apimatic_core_interfaces.svg)](https://badge.fury.io/rb/apimatic_core_interfaces)
[![Linting][lint-badge]][lint-url]
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Maintainability Rating][maintainability-badge]][maintainability-url]
[![Vulnerabilities][vulnerabilities-badge]][vulnerabilities-url]
[![Licence][license-badge]][license-url]

## Introduction
This project contains the abstract layer for core library ruby. The purpose of creating interfaces is to separate out the functionalities needed by ruby core library. The goal is to support scalability and feature enhancement of the core library and the SDKs along with avoiding any breaking changes by reducing tight coupling between modules through the introduction of interfaces.

## Version supported
Currently APIMatic supports  `2.6 <= Ruby version <= 3.2`  hence core-interfaces-ruby will need the same versions to be supported.

## Installation
Installation is quite simple, just execute the following command:
```
gem install apimatic_core_interfaces
```

If you'd rather install apimatic_core_interfaces using bundler, add a line for it in your Gemfile:
```
gem 'apimatic_core_interfaces'
```

## Interfaces
| Name                                                                                 | Description                                                                                       |
|--------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| [`HttpClient`](lib/apimatic-core-interfaces/client/http_client.rb)                   | To save both Request and Response after the completion of response                                |
| [`ResponseFactory`](lib/apimatic-core-interfaces/factories/response_factory.rb)      | To convert the client-adapter response into a custom HTTP response                                |
| [`Authentication`](lib/apimatic-core-interfaces/types/authentication.rb)             | To setup methods for the validation and application of the required authentication scheme         |
| [`UnionType`](lib/apimatic-core-interfaces/types/union_type.rb)                      | To setup methods for the validation, serialization and deserialization of OneOf/AnyOf union types |
| [`ApiLogger`](lib/apimatic-core-interfaces/logger/api_logger.rb) | An interface for logging API requests and responses.                                                               |
| [`Logger`](lib/apimatic-core-interfaces/logger/logger.rb) | An interface for the generic logger facade |


## Enumerations
| Name                                                                                           | Description                                                    |
|------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| [`DateTimeFormat`](lib/apimatic-core-interfaces/types/datetime_format.rb)                      | Enumeration containing different datetime formats (RFC1123, RFC3339, UNIX_TIMESTAMP)              |
| [`HttpMethod`](lib/apimatic-core-interfaces/types/http_method.rb)                              | Enumeration containing HTTP Methods (GET, PUT, POST, PATCH, DELETE, HEAD) |
| [`ArraySerializationFormat`](lib/apimatic-core-interfaces/types/array_serialization_format.rb) | Enumeration containing different array serialization formats (INDEXED, UNINDEXED, PLAIN, CSV, PSV, TSV)  |

[lint-badge]: https://github.com/apimatic/core-interfaces-ruby/actions/workflows/lint-runner.yml/badge.svg
[lint-url]: https://github.com/apimatic/core-interfaces-ruby/actions/workflows/lint-runner.yml
[maintainability-badge]: https://sonarcloud.io/api/project_badges/measure?project=apimatic_core-interfaces-ruby&metric=sqale_rating
[maintainability-url]: https://sonarcloud.io/summary/new_code?id=apimatic_core-interfaces-ruby
[vulnerabilities-badge]: https://sonarcloud.io/api/project_badges/measure?project=apimatic_core-interfaces-ruby&metric=vulnerabilities
[vulnerabilities-url]: https://sonarcloud.io/summary/new_code?id=apimatic_core-interfaces-ruby
[license-badge]: https://img.shields.io/badge/licence-MIT-blue
[license-url]: LICENSE
