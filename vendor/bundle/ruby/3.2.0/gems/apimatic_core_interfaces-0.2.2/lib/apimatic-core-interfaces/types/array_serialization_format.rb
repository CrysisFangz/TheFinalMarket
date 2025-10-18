module CoreLibrary
  # All Array Serialization Formats.
  class ArraySerializationFormat
    # Members:
    #     UN_INDEXED: Used for serializing array elements in the un-indexed format.
    #     INDEXED: Used for serializing array elements in the indexed format.
    #     PLAIN: Used for serializing array elements in the plain format.
    #     CSV: Used for serializing array elements in the comma separated format.
    #     TSV: Used for serializing array elements in the tab separated format.
    #     PSV: Used for serializing array elements in the pipe separated format.

    ARRAY_SERIALIZATION_FORMAT = [UN_INDEXED = 'un-indexed'.freeze,
                                  INDEXED = 'indexed'.freeze,
                                  PLAIN = 'plain'.freeze,
                                  CSV = 'csv'.freeze,
                                  TSV = 'tsv'.freeze,
                                  PSV = 'psv'.freeze].freeze
  end
end
