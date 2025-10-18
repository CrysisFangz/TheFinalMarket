module CoreLibrary
  # Date Time Formats Enumeration.
  class DateTimeFormat
    # Members:
    #     HTTP_DATE_TIME: RFC 1123 Date-Time format
    #     UNIX_DATE_TIME: Unix Timestamp Format
    #     RFC3339_DATE_TIME: RFC 3339 Date-Time format

    DATE_TIME_FORMAT = [
      HTTP_DATE_TIME = 'HttpDateTime'.freeze,

      UNIX_DATE_TIME = 'UnixDateTime'.freeze,

      RFC3339_DATE_TIME = 'RFC3339DateTime'.freeze
    ].freeze
  end
end
