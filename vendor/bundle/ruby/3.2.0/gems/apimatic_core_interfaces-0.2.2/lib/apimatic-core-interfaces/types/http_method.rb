module CoreLibrary
  # HTTP Methods Enumeration.
  class HttpMethod
    # Members:
    #     GET: Used for the GET request.
    #     POST: Used for the POST request.
    #     PUT: Used for the PUT request.
    #     PATCH: Used for the PATCH request.
    #     DELETE: Used for the DELETE request.
    #     HEAD: Used for the HEAD request.

    HTTP_METHOD = [GET = 'GET'.freeze,
                   POST = 'POST'.freeze,
                   PUT = 'PUT'.freeze,
                   PATCH = 'PATCH'.freeze,
                   DELETE = 'DELETE'.freeze,
                   HEAD = 'HEAD'.freeze].freeze
  end
end
