class DataExportPresenter
  def initialize(data_export)
    @data_export = data_export
  end

  def as_json(options = {})
    {
      id: @data_export.id,
      export_type: @data_export.export_type,
      status: @data_export.status,
      file_name: @data_export.file_name,
      file_path: @data_export.file_path,
      expires_at: @data_export.expires_at,
      created_at: @data_export.created_at,
      updated_at: @data_export.updated_at,
      download_url: @data_export.download_url,
      ready: @data_export.ready?,
      expired: @data_export.expired?,
      user_id: @data_export.user_id
    }
  end

  def to_json(options = {})
    as_json(options).to_json
  end
end